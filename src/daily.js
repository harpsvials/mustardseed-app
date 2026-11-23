// —— 每日内容自动抓取（Cloudflare Cron） ——
// 为什么放在这里：GitHub Actions 的 schedule 是「尽力而为」，高负载时会被延迟
// 甚至整趟丢弃（2026-11-10 就漏了 05:30 那次），不适合当作每日内容的生产者。
// 这里用 Worker 的 Cron Trigger 抓《活泼的生命》当日页与 RPG 每日经文，
// 结果写进 KV；/api/data、/api/asset 优先读 KV，读不到再回源 GitHub。
import { Converter } from 'opencc-js/t2cn';

const UA =
  'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) ' +
  'AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0 Safari/537.36';

const QT_URL = 'https://www.duranno.tw/livinglife/index.php/daily';
// CGN 中文台「活潑的生命」官方播放列表：每天一集，前一日 23:00（北京）发布，
// 标题带 8 位日期，描述里有「主題」「經文」两行。2026-11 起 duranno 站点维护，
// 该列表成为主源，duranno 退为备源。
const YT_PLAYLIST_ID = 'PLUkEOfQnxIpEMVHWNpAh5LWxQJB1vZcOh';
const YT_RSS = `https://www.youtube.com/feeds/videos.xml?playlist_id=${YT_PLAYLIST_ID}`;
const RPG_CATEGORY = 'https://www.rpg-move.tw/category/rpg-daily/';
const RPG_UPLOAD = 'https://www.rpg-move.tw/wp-content/uploads/';
// 图片绝对地址走 workers.dev 预览域：www 域对非浏览器请求会返回 CF 挑战页（403）
const ASSET_BASE = 'https://mustardseed.harps-vials.workers.dev';
const KEEP_DAYS = 7;
const WEEKDAYS = ['星期一', '星期二', '星期三', '星期四', '星期五', '星期六', '星期日'];

const toCN = Converter({ from: 't', to: 'cn' });
const simplify = (s) => toCN(s || '');
// 写入新的一天时，把上一天原样收进 prev，供网页/App 回看；只留两层，避免越滚越大
const withoutPrev = (o) => {
  if (!o || typeof o !== 'object') return null;
  const { prev, ...rest } = o;
  return rest;
};


// —— 北京时间 ——
const pad = (n) => String(n).padStart(2, '0');
function tpe() {
  return new Date(Date.now() + 8 * 3600 * 1000);
}
function tpeDate() {
  const d = tpe();
  return `${d.getUTCFullYear()}-${pad(d.getUTCMonth() + 1)}-${pad(d.getUTCDate())}`;
}
function tpeStamp() {
  const d = tpe();
  return `${d.getUTCFullYear()}-${pad(d.getUTCMonth() + 1)}-${pad(d.getUTCDate())} ${pad(d.getUTCHours())}:${pad(d.getUTCMinutes())}`;
}
function tpeLabel() {
  const d = tpe();
  return `${d.getUTCFullYear()}年${d.getUTCMonth() + 1}月${d.getUTCDate()}日 ${pad(d.getUTCHours())}:${pad(d.getUTCMinutes())}`;
}

// —— 抓取与文本处理 ——
async function fetchText(url) {
  const res = await fetch(url, {
    headers: { 'User-Agent': UA, Accept: 'text/html,application/xhtml+xml' },
    signal: AbortSignal.timeout(20000)
  });
  if (!res.ok) throw new Error(`HTTP ${res.status} ${url}`);
  return await res.text();
}

async function fetchBinary(url) {
  const res = await fetch(url, {
    headers: { 'User-Agent': UA, Accept: 'image/jpeg,*/*' },
    signal: AbortSignal.timeout(30000)
  });
  if (!res.ok) return null;
  const buf = await res.arrayBuffer();
  return buf.byteLength ? buf : null;
}

const ENTITIES = { amp: '&', lt: '<', gt: '>', quot: '"', '#39': "'", nbsp: ' ' };
function decodeEntities(s) {
  return s.replace(/&(#x?[0-9a-fA-F]+|[a-zA-Z]+);/g, (m, code) => {
    if (code[0] === '#') {
      const n = code[1] === 'x' ? parseInt(code.slice(2), 16) : parseInt(code.slice(1), 10);
      return Number.isFinite(n) ? String.fromCodePoint(n) : m;
    }
    return ENTITIES[code.toLowerCase()] ?? m;
  });
}

function toLines(html) {
  let body = html
    .replace(/<script[\s\S]*?<\/script>/gi, ' ')
    .replace(/<style[\s\S]*?<\/style>/gi, ' ')
    .replace(/<[^>]+>/g, '\n');
  body = decodeEntities(body);
  return body.split('\n').map((l) => l.trim()).filter(Boolean);
}

// 原页用「★」「-->」这类纯符号行做分隔，不能当正文
function isNoise(line) {
  const s = (line || '').trim();
  if (!s) return true;
  if (['-->', '—>', '->'].includes(s)) return true;
  return !s.replace(/[★☆·•●○◆◇※\-–—_=~～\s]+/g, '');
}

const tidy = (s) =>
  simplify(s)
    .replace(/\u223c|\u007e/g, '～')
    .replace(/\u200b/g, '')
    .replace(/\u00a0/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();

function parseQT(lines) {
  let date = null;
  for (const ln of lines) {
    const m = ln.match(/(\d{4})\s*年\s*(\d{1,2})\s*月\s*(\d{1,2})\s*日/);
    if (m) {
      date = `${m[1]}-${pad(m[2])}-${pad(m[3])}`;
      break;
    }
  }
  if (!date) throw new Error('找不到日期行');

  const after = (marker, stops, max = 4) => {
    for (let i = 0; i < lines.length; i++) {
      if (!lines[i].includes(marker)) continue;
      const tail = lines[i].split(marker)[1].trim().replace(/^[★：:\s]+/, '');
      const out = tail && !isNoise(tail) ? [tail] : [];
      for (const nxt of lines.slice(i + 1)) {
        if (stops.some((s) => nxt.includes(s))) break;
        if (isNoise(nxt)) continue;
        out.push(nxt);
        if (out.length >= max) break;
      }
      return out;
    }
    throw new Error(`找不到锚点：${marker}`);
  };

  const topicLines = after('今天的主題', ['經文範圍', '經文摘要', '經文內容']);
  const readingLines = after('經文範圍', ['經文摘要', '經文內容', '全心禱告', '全年讀經']);
  if (!topicLines.length || !readingLines.length) throw new Error('主题或经文范围为空');

  const topic = tidy(topicLines[0]);
  const subtitle = topicLines.length > 1 ? tidy(topicLines[1]) : '';
  const reading = tidy(readingLines[0]);
  for (const bad of ['今天的詩歌', '今天的主題', '經文範圍']) {
    if (topic.includes(bad) || reading.includes(bad)) throw new Error('字段混入了锚点文本');
  }

  const d = new Date(date + 'T00:00:00Z');
  return {
    date,
    dateLabel: `${d.getUTCFullYear()}年${d.getUTCMonth() + 1}月${d.getUTCDate()}日`,
    weekday: WEEKDAYS[d.getUTCDay() === 0 ? 6 : d.getUTCDay() - 1],
    topic,
    subtitle,
    reading,
    sourceUrl: CGN_YT
  };
}

// —— YouTube 播放列表解析 ——
function decodeXml(s) {
  return decodeEntities(s.replace(/<!\[CDATA\[([\s\S]*?)\]\]>/g, '$1'));
}

function parseYTFeed(xml) {
  const out = [];
  for (const m of xml.matchAll(/<entry>([\s\S]*?)<\/entry>/g)) {
    const e = m[1];
    out.push({
      id: (e.match(/<yt:videoId>([^<]*)<\/yt:videoId>/) || [])[1] || '',
      title: decodeXml((e.match(/<title[^>]*>([\s\S]*?)<\/title>/) || [])[1] || ''),
      published: (e.match(/<published>([^<]*)<\/published>/) || [])[1] || '',
      desc: decodeXml((e.match(/<media:description[^>]*>([\s\S]*?)<\/media:description>/) || [])[1] || '')
    });
  }
  return out;
}

// 标题里的 8 位日期优先，其次描述里的「2026年11月12日」
function pickYTEntry(entries, date) {
  const want = date.replace(/-/g, '');
  for (const e of entries) {
    const m = e.title.match(/20\d{6}/);
    if (m && m[0] === want) return e;
  }
  for (const e of entries) {
    const m = e.desc.match(/(\d{4})\s*年\s*(\d{1,2})\s*月\s*(\d{1,2})\s*日/);
    if (m && `${m[1]}-${pad(m[2])}-${pad(m[3])}` === date) return e;
  }
  return null;
}

function normalizeReading(s) {
  return simplify(s)
    .replace(/\s+/g, '')
    .replace(/:/g, '：')
    .replace(/[~〜–—]/g, '～');
}

function parseYTVideo(entry, date) {
  const d = new Date(date + 'T00:00:00Z');

  // 描述里「-主題 ：公平與公義 如江河般湧流的生活」
  let topic = '';
  const mt = entry.desc.match(/主\s*題\s*[：:]\s*(.+)/);
  if (mt) topic = tidy(mt[1]);
  if (!topic) {
    topic = tidy(entry.title.replace(/^\[[^\]]*\]\s*/, '').replace(/20\d{6}\s*/, '').replace(/\([^)]*\)\s*$/, ''));
  }

  // 描述里「-經文 ：阿摩司書 5:18~27」，退而取标题末尾括号
  let reading = '';
  const mr = entry.desc.match(/經\s*文\s*[：:]\s*(.+)/);
  if (mr) reading = normalizeReading(mr[1]);
  if (!reading) {
    const pr = entry.title.match(/\(([^)]+)\)\s*$/);
    if (pr) reading = normalizeReading(pr[1]);
  }

  return {
    date,
    dateLabel: `${d.getUTCFullYear()}年${d.getUTCMonth() + 1}月${d.getUTCDate()}日`,
    weekday: WEEKDAYS[d.getUTCDay() === 0 ? 6 : d.getUTCDay() - 1],
    topic,
    subtitle: '',
    reading,
    sourceUrl: `https://www.youtube.com/watch?v=${entry.id}`,
    sourceName: simplify('CGN中文台·活潑的生命')
  };
}

async function updateQT(env) {
  const kv = env.MUSTARDSEED_DATA;
  if (!kv) return 'no-kv';
  const today = tpeDate();
  let data = null;
  let note = '';

  // 主源：CGN 中文台 YouTube 播放列表（RSS，无需 key）
  try {
    const entries = parseYTFeed(await fetchText(YT_RSS));
    const hit = pickYTEntry(entries, today);
    if (hit) data = parseYTVideo(hit, today);
    else note = `yt 无 ${today}（最新 ${entries[0]?.title.slice(0, 28) || '空'}）`;
  } catch (e) {
    note = `yt-fail ${e.message}`;
  }

  // 备源：duranno 每日页（站点维护期间多半仍是旧日期，命中当天才用）
  if (!data) {
    try {
      const d = parseQT(toLines(await fetchText(QT_URL)));
      if (d.date === today) data = d;
      else note += ` | duranno 仍是 ${d.date}`;
    } catch (e) {
      note += ` | duranno-fail ${e.message}`;
    }
  }

  if (!data || !data.topic) return `qt-skip: ${note || '当天内容为空'}`;

  let prev = null;
  const prevRaw = await kv.get('qt-data.json');
  if (prevRaw) {
    try {
      prev = JSON.parse(prevRaw);
      if (
        prev.date === data.date &&
        prev.topic === data.topic &&
        prev.subtitle === data.subtitle &&
        prev.reading === data.reading
      ) {
        return 'qt-unchanged';
      }
    } catch (_) {}
  }

  // 保留前一天，最多两天；同一天重跑时沿用已有的 prev，避免把昨天冲掉
  if (prev) {
    const lastDay = withoutPrev(prev);
    data.prev = lastDay && lastDay.date !== data.date ? lastDay : prev.prev || null;
    if (!data.prev) delete data.prev;
  }

  data.updated = tpeStamp();
  data.updatedLabel = tpeLabel();
  await kv.put('qt-data.json', JSON.stringify(data, null, 2) + '\n');
  return `qt-ok: ${data.dateLabel} ${data.topic}｜${data.reading}`;
}

function parseRPGPost(url, html) {
  const text = html.replace(/<[^>]+>/g, ' ');
  const m = text.match(/日期\s*[・·:：]?\s*(\d{4})-(\d{2})-(\d{2})/);
  if (!m) return null;
  const date = `${m[1]}-${m[2]}-${m[3]}`;
  const mmdd = m[2] + m[3];

  const verseCands = [`${RPG_UPLOAD}daily_${mmdd}-1.jpg`];
  const versePat = new RegExp(`https://www\\.rpg-move\\.tw/wp-content/uploads/daily_${mmdd}-1(?:-[^"') ]*)?\\.jpg`, 'g');
  for (const c of html.match(versePat) || []) {
    if (!verseCands.includes(c)) verseCands.push(c);
  }

  let prayerUrl = null;
  const prayerPat = new RegExp(`https://www\\.rpg-move\\.tw/wp-content/uploads/daily_${mmdd}-2(?:-[^"') ]*)?\\.jpg`, 'g');
  for (const c of html.match(prayerPat) || []) {
    if (/-\d+x\d+\.jpg$/.test(c)) continue;
    prayerUrl = c;
    break;
  }
  if (!prayerUrl) return null;

  let title = '';
  const mt = html.match(/<title>([\s\S]*?)<\/title>/i);
  if (mt) title = decodeEntities(mt[1]).replace(/\s+/g, ' ').split(/[|｜]/)[0].trim();

  return { date, verseCands, prayerUrl, sourceUrl: url, title: simplify(title) || '每日經文' };
}

// 图片一律指向站内 /api/asset：App 与网页都走同域，不依赖 github.io
function normalizeItem(it) {
  if (it.verseImage) it.verseImageUrl = `${ASSET_BASE}/api/asset?p=images/rpg/${it.verseImage}`;
  if (it.prayerImage) it.prayerImageUrl = `${ASSET_BASE}/api/asset?p=images/rpg/${it.prayerImage}`;
  return it;
}

async function updateRPG(env) {
  const kv = env.MUSTARDSEED_DATA;
  if (!kv) return 'no-kv';

  let cat;
  try {
    cat = await fetchText(RPG_CATEGORY);
  } catch (e) {
    return `rpg-cat-fail: ${e.message}`;
  }

  const links = [];
  for (const m of cat.matchAll(/href="(https?:\/\/www\.rpg-move\.tw\/daily\d+\/)"/g)) {
    if (!links.includes(m[1])) links.push(m[1]);
  }
  if (!links.length) return 'rpg-fail: 分类页没有文章链接';

  const today = tpeDate();
  const earliest = new Date(new Date(today + 'T00:00:00Z').getTime() - KEEP_DAYS * 86400000)
    .toISOString()
    .slice(0, 10);

  let prev = null;
  const prevRaw = await kv.get('rpg-data.json');
  if (prevRaw) {
    try { prev = JSON.parse(prevRaw); } catch (_) {}
  }
  const prevItems = new Map((prev?.items || []).map((it) => [it.date, it]));

  const items = new Map();
  for (const url of links.slice(0, 8)) {
    let html;
    try { html = await fetchText(url); } catch (_) { continue; }
    const parsed = parseRPGPost(url, html);
    if (!parsed) continue;
    if (parsed.date > today || parsed.date < earliest) continue;

    const base = 'daily_' + parsed.date.replace(/-/g, '');
    const verseName = `${base}-1.jpg`;
    const prayerName = `${base}-2.jpg`;
    const item = {
      date: parsed.date,
      dateLabel: `${+parsed.date.slice(0, 4)}年${+parsed.date.slice(5, 7)}月${+parsed.date.slice(8, 10)}日`,
      weekday: WEEKDAYS[new Date(parsed.date + 'T00:00:00Z').getUTCDay() === 0 ? 6 : new Date(parsed.date + 'T00:00:00Z').getUTCDay() - 1],
      verseImage: '',
      verseImageUrl: '',
      prayerImage: '',
      prayerImageUrl: '',
      sourceUrl: parsed.sourceUrl,
      title: parsed.title
    };

    for (const cand of parsed.verseCands) {
      const buf = await fetchBinary(cand);
      if (buf && buf.byteLength >= 15000) {
        await kv.put(`images/rpg/${verseName}`, buf, { metadata: { contentType: 'image/jpeg' } });
        item.verseImage = verseName;
        item.verseImageUrl = `${ASSET_BASE}/api/asset?p=images/rpg/${verseName}`;
        break;
      }
    }
    const pb = await fetchBinary(parsed.prayerUrl);
    if (pb && pb.byteLength >= 15000) {
      await kv.put(`images/rpg/${prayerName}`, pb, { metadata: { contentType: 'image/jpeg' } });
      item.prayerImage = prayerName;
      item.prayerImageUrl = `${ASSET_BASE}/api/asset?p=images/rpg/${prayerName}`;
    }
    if (item.verseImage || item.prayerImage) items.set(parsed.date, item);
  }

  // 抓不到的近 7 天沿用旧条目，避免清单被清空
  for (const [date, it] of prevItems) {
    if (items.has(date) || date < earliest || date > today) continue;
    items.set(date, it);
  }
  const keep = [...items.values()]
    .map(normalizeItem)
    .sort((a, b) => (a.date < b.date ? 1 : -1))
    .slice(0, KEEP_DAYS);
  const signature = keep.map((i) => `${i.date}${i.verseImageUrl}${i.prayerImageUrl}`).join('|');
  const prevSig = (prev?.items || [])
    .slice(0, KEEP_DAYS)
    .map((i) => `${i.date}${i.verseImageUrl}${i.prayerImageUrl}`)
    .join('|');

  if (prev && signature === prevSig && keep.length) {
    // 清单没变：不重复写，省掉无意义变更
  } else {
    await kv.put(
      'rpg-data.json',
      JSON.stringify(
        {
          updated: tpeStamp(),
          updatedLabel: tpeLabel(),
          sourceUrl: RPG_CATEGORY,
          keepDays: KEEP_DAYS,
          items: keep
        },
        null,
        2
      ) + '\n'
    );
  }

  // 清理超过保留期的图片
  const wanted = new Set(keep.flatMap((i) => [i.verseImage, i.prayerImage]).filter(Boolean));
  try {
    const listed = await kv.list({ prefix: 'images/rpg/' });
    for (const k of listed.keys) {
      const name = k.name.slice('images/rpg/'.length);
      if (!wanted.has(name)) await kv.delete(k.name);
    }
  } catch (_) {}

  return `rpg-ok: ${keep.length} 天，最新 ${keep[0]?.date || '无'}`;
}

// —— 英文 QT 的「默想 / 写给神的信」：抓当天英文页，用 Workers AI 译成简体中文 ——
// 英文站内容由 reload_default1.asp 按服务器当天日期返回（默认页会被 CDN 缓存成旧日期）。
const QT_EN_URL = 'https://www.duranno.com/livinglife/qt/reload_default1.asp';
// 主题与经文范围仍取自 CGN 中文台「活潑的生命」
const CGN_YT = 'https://www.youtube.com/@CGNChinese_%E6%B4%BB%E6%BD%91%E7%9A%84%E7%94%9F%E5%91%BD';
// 默想与祷文实际译自英文 QT 网站 Duranno「Living Life」，来源标注须指向该站
const QT_EN_HOME = 'https://www.duranno.com/livinglife/qt/';
// 先 Qwen（中文更自然），失败再退 Llama 3.3
const AI_MODELS = ['@cf/qwen/qwen3.8-27b', '@cf/meta/llama-3.3-70b-instruct-fp8-fast'];
// 译文规则改动时+1：KV 里旧版本会自动重译一次
const REFLECTION_PROMPT_VERSION = 3;

// 英文书卷名 → 中文（与 qt-data.json 的 reading 对齐，用来校验当天英文页与中文主题同章）
const EN_BOOK_ZH = {
  Genesis: '创世记', Exodus: '出埃及记', Leviticus: '利未记', Numbers: '民数记',
  Deuteronomy: '申命记', Joshua: '约书亚记', Judges: '士师记', Ruth: '路得记',
  '1 Samuel': '撒母耳记上', '2 Samuel': '撒母耳记下', '1 Kings': '列王纪上',
  '2 Kings': '列王纪下', '1 Chronicles': '历代志上', '2 Chronicles': '历代志下',
  Ezra: '以斯拉记', Nehemiah: '尼希米记', Esther: '以斯帖记', Job: '约伯记',
  Psalms: '诗篇', Psalm: '诗篇', Proverbs: '箴言', Ecclesiastes: '传道书',
  'Song of Songs': '雅歌', Isaiah: '以赛亚书', Jeremiah: '耶利米书',
  Lamentations: '耶利米哀歌', Ezekiel: '以西结书', Daniel: '但以理书',
  Hosea: '何西阿书', Joel: '约珥书', Amos: '阿摩司书', Obadiah: '俄巴底亚书',
  Jonah: '约拿书', Micah: '弥迦书', Nahum: '那鸿书', Habakkuk: '哈巴谷书',
  Zephaniah: '西番雅书', Haggai: '哈该书', Zechariah: '撒迦利亚书', Malachi: '玛拉基书',
  Matthew: '马太福音', Mark: '马可福音', Luke: '路加福音', John: '约翰福音',
  Acts: '使徒行传', Romans: '罗马书', '1 Corinthians': '哥林多前书',
  '2 Corinthians': '哥林多后书', Galatians: '加拉太书', Ephesians: '以弗所书',
  Philippians: '腓立比书', Colossians: '歌罗西书', '1 Thessalonians': '帖撒罗尼迦前书',
  '2 Thessalonians': '帖撒罗尼迦后书', '1 Timothy': '提摩太前书',
  '2 Timothy': '提摩太后书', Titus: '提多书', Philemon: '腓利门书',
  Hebrews: '希伯来书', James: '雅各书', '1 Peter': '彼得前书', '2 Peter': '彼得后书',
  '1 John': '约翰一书', '2 John': '约翰二书', '3 John': '约翰三书',
  Jude: '犹大书', Revelation: '启示录'
};

function plainText(s) {
  return decodeEntities(String(s).replace(/<br\s*\/?>/gi, ' ').replace(/<[^>]+>/g, ' '))
    .replace(/\u00a0/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

/// 从英文 QT 片段里取出标题、经文范围、默想分节与祷文
function parseEnQT(html) {
  const mDate = html.match(/videoNowDate\s*=\s*"(\d{4}-\d{2}-\d{2})"/);
  const mTitle = html.match(/class="title"><a[^>]*>([\s\S]*?)<\/a>/);
  const mRead = html.match(/class="sub_title">([\s\S]*?)<\/div>/);
  if (!mDate || !mTitle || !mRead) throw new Error('en-qt-structure');

  const iRefl = html.indexOf('<!-- Reflection-->');
  const iLetter = html.indexOf('<!--  Letter to God -->');
  const reflPart = iRefl >= 0 && iLetter > iRefl ? html.slice(iRefl, iLetter) : '';
  const iLbl = html.indexOf('Letter to God');
  const letterPart = iLbl >= 0 ? html.slice(iLbl) : '';

  const mReflCon = reflPart.match(/<div class="con">([\s\S]*?)<\/div>/);
  const mLetterCon = letterPart.match(/<div class="con"[^>]*>([\s\S]*?)<\/div>/);
  if (!mReflCon || !mLetterCon) throw new Error('en-qt-content');

  const blocks = mReflCon[1]
    .split(/<br\s*\/?>\s*<br\s*\/?>/i)
    .map(plainText)
    .filter(Boolean);

  const headingRe = /^(.{1,80}?)\s*\((\d+)\s*:\s*(\d+)\s*[–\-—~]\s*(\d+)\)$/;
  const cueRe = /^(Think|Reflect|What|How|Consider|Do you|Have you|In what|Where|Why|When|Ask|Is there|Can you|Take a moment)/i;

  const sections = [];
  for (let i = 0; i < blocks.length; i++) {
    const b = blocks[i];
    const isHeading = headingRe.test(b) ||
      (b.length <= 60 && !/[.?!]$/.test(b) && i + 1 < blocks.length && blocks[i + 1].length > b.length);
    if (isHeading) {
      sections.push({ heading: b, paragraphs: [], question: '' });
      continue;
    }
    if (!sections.length) continue;
    const cur = sections[sections.length - 1];
    if ((cueRe.test(b) || b.endsWith('?')) && !cur.question) cur.question = b;
    else cur.paragraphs.push(b);
  }

  const letter = plainText(mLetterCon[1].replace(/Amen\s*\(\d+\)/i, '')).trim();
  const reflectionText = blocks.join(' ');

  return {
    date: mDate[1],
    title: plainText(mTitle[1]),
    reading: plainText(mRead[1]),
    sections: sections.filter((s) => s.heading),
    letter,
    chars: reflectionText.length + letter.length
  };
}

async function fetchEnQT() {
  const res = await fetch(QT_EN_URL, {
    method: 'POST',
    headers: {
      'User-Agent': UA,
      'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
      'X-Requested-With': 'XMLHttpRequest',
      Accept: 'text/html, */*; q=0.01'
    },
    body: 'OD=' + tpeDate().replace(/-/g, ''),
    signal: AbortSignal.timeout(25000)
  });
  if (!res.ok) throw new Error(`HTTP ${res.status}`);
  return await res.text();
}

function pickAiText(r) {
  if (!r) return '';
  if (typeof r.response === 'string') return r.response;
  const c = r.choices && r.choices[0];
  if (c) {
    if (typeof c.text === 'string') return c.text;
    if (c.message && typeof c.message.content === 'string') return c.message.content;
  }
  return '';
}

function parseJsonLoose(text) {
  let s = String(text || '').trim();
  s = s.replace(/^```(?:json)?/i, '').replace(/```$/m, '').trim();
  const i = s.indexOf('{');
  const j = s.lastIndexOf('}');
  if (i < 0 || j <= i) return null;
  try {
    return JSON.parse(s.slice(i, j + 1));
  } catch (_) {
    return null;
  }
}

// 统一中文里的经文章节写法：(2:1–4) → （2：1～4）
function normalizeZhRef(s) {
  return String(s || '')
    .replace(/[（(]\s*(\d+)\s*[:：]\s*(\d+)\s*[–\-—~～]\s*(\d+)\s*[）)]/g, '（$1：$2～$3）')
    .replace(/[（(]\s*(\d+)\s*[:：]\s*(\d+)\s*[）)]/g, '（$1：$2）')
    .replace(/\s+（/g, '（')
    .replace(/\s+([，。；：？！）])/g, '$1')
    .replace(/\s{2,}/g, ' ')
    .replace(/祢/g, '你')
    .replace(/在爱中说真话|以爱说真理|用爱说真理/g, '用爱心说诚实话')
    .trim();
}

async function translateReflection(env, en) {
  const payload = {
    title: en.title,
    sections: en.sections.map((s) => ({
      heading: s.heading,
      paragraphs: s.paragraphs,
      question: s.question
    })),
    letter: en.letter
  };
  const system =
    '你是专业的英文到简体中文译者，翻译基督教灵修文字：忠于原意、语气庄重、通顺自然，避免直译腔。' +
    '用词按本站习惯：God→神，Lord→主，prayer→祷告（不写「祈祷」），forgive→赦免，repent→悔改，' +
    'church→教会，Spirit→圣灵，grace→恩典，salvation→救恩，reconciliation→和好，' +
    'speak the truth in love→用爱心说诚实话，remember→记得（不写「记念」），opportunity→机会（不写「契机」）。' +
    '称呼神时用「你」，不用「祢」。标题必须完整译出原标题的全部意思，不得省略词，例如 The Hard Work of Reconciliation→和好的艰辛之路；小标题按上面的对照表，不得另创说法；letter 要像自然的中文祷告，避免英文语序和「以及」「并且」这类生硬连接。只输出 JSON。';
  const user =
    '把下面的英文灵修材料翻译成简体中文，只输出一个 JSON，字段与输入一致：' +
    'title、sections[{heading,paragraphs,question}]、letter；不要解释、不要代码块、不要额外文字。' +
    '小标题里的经文章节括号照原样保留；某节没有问题就把 question 留空字符串。\n\n' +
    JSON.stringify(payload, null, 1);

  for (const model of AI_MODELS) {
    for (let attempt = 0; attempt < 2; attempt++) {
      try {
        const r = await env.AI.run(model, {
          messages: [
            { role: 'system', content: system },
            { role: 'user', content: user }
          ],
          max_tokens: 1600,
          temperature: 0,
          chat_template_kwargs: { enable_thinking: false }
        });
        const obj = parseJsonLoose(pickAiText(r));
        if (!obj || !Array.isArray(obj.sections)) continue;
        if (obj.sections.length !== payload.sections.length) continue;
        const sections = payload.sections.map((src, i) => {
          const t = obj.sections[i] || {};
          return {
            heading: normalizeZhRef(t.heading || src.heading),
            paragraphs: (Array.isArray(t.paragraphs) ? t.paragraphs : [])
              .map((p) => String(p).replace(/\s+/g, ' ').trim())
              .filter(Boolean),
            question: normalizeZhRef(t.question || '')
          };
        });
        if (sections.some((s) => !s.paragraphs.length)) continue;
        return {
          title: normalizeZhRef(obj.title || ''),
          sections,
          letter: String(obj.letter || '').replace(/\s+/g, ' ').trim(),
          model
        };
      } catch (_) {}
    }
  }
  throw new Error('translate-failed');
}

async function updateReflection(env) {
  const kv = env.MUSTARDSEED_DATA;
  if (!kv) return 'reflection: no-kv';
  if (!env.AI || typeof env.AI.run !== 'function') return 'reflection: no-ai';

  const today = tpeDate();
  let qt = null;
  try {
    const raw = await kv.get('qt-data.json', 'text');
    if (raw) qt = JSON.parse(raw);
  } catch (_) {}
  if (!qt || !qt.reading) return 'reflection: qt-missing';

  let en;
  try {
    en = parseEnQT(await fetchEnQT());
  } catch (e) {
    return `reflection-skip: en-fail ${e.message}`;
  }
  if (en.date !== today) return `reflection-skip: en 仍是 ${en.date}`;
  if (!en.sections.length || !en.letter) return 'reflection-skip: en 内容为空';

  // 英文页与中文主题必须同章，否则宁可不写（避免「哥林多后书」配「阿摩司书」的默想）
  const enM = en.reading.match(/^(.*?)\s*(\d+)\s*:\s*(\d+)/);
  const zhM = String(qt.reading).match(/^(.+?)(\d+)[：:](\d+)/);
  if (enM && zhM) {
    const enBook = EN_BOOK_ZH[enM[1].trim()];
    const sameBook = enBook === zhM[1].trim();
    const sameChapter = Number(enM[2]) === Number(zhM[2]);
    if (!sameBook || !sameChapter) {
      // 英文站偶尔把书卷标错（如 2 Corinthians 标成 2 Chronicles），
      // 此时用默想小节标题里的「章:节」复核：全部落在同一章、且含中文经文的起始节，才继续。
      const refs = [...en.sections.map((s) => String(s.heading || '')).join(' ').matchAll(/(\d+)\s*:\s*(\d+)/g)]
        .map((m) => [Number(m[1]), Number(m[2])]);
      const zhCh = Number(zhM[2]);
      const zhV = Number(zhM[3]);
      const headingsAgree = refs.length > 0 && refs.every(([ch]) => ch === zhCh) && refs.some(([, v]) => v === zhV);
      if (!headingsAgree) {
        return `reflection-skip: 不同章（en ${en.reading} / zh ${qt.reading}）`;
      }
    }
  }

  let prev = null;
  try {
    prev = JSON.parse(await kv.get('qt-reflection.json', 'text'));
  } catch (_) {}
  if (prev && prev.date === today && prev.locked === true) {
    return 'reflection-locked';
  }
  if (
    prev &&
    prev.date === today &&
    prev.sourceTitle === en.title &&
    prev.enChars === en.chars &&
    prev.promptVersion === REFLECTION_PROMPT_VERSION
  ) {
    return 'reflection-unchanged';
  }

  let zh;
  try {
    zh = await translateReflection(env, en);
  } catch (e) {
    return `reflection-skip: ${e.message}`;
  }

  const data = {
    date: today,
    dateLabel: tpeLabelDate(today),
    title: zh.title || '',
    titleEn: en.title,
    sourceUrl: QT_EN_HOME,
    sourceLabel: 'Duranno · Living Life（英文 QT）',
    sourceReading: en.reading,
    enChars: en.chars,
    reflection: zh.sections,
    letter: zh.letter,
    updated: tpeStamp(),
    updatedLabel: tpeLabel(),
    model: zh.model,
    promptVersion: REFLECTION_PROMPT_VERSION
  };
  // 与灵修正文一样，保留前一天的默想，页面可切到昨天
  if (prev) {
    const lastDay = withoutPrev(prev);
    data.prev = lastDay && lastDay.date !== data.date ? lastDay : prev.prev || null;
    if (!data.prev) delete data.prev;
  }
  await kv.put('qt-reflection.json', JSON.stringify(data, null, 2) + '\n');
  return `reflection-ok: ${today} ${zh.sections.length} 段｜${zh.model}`;
}

function tpeLabelDate(ymd) {
  const [y, m, d] = String(ymd).split('-').map(Number);
  return `${y}年${m}月${d}日`;
}

export async function updateDaily(env) {
  const qt = await updateQT(env);
  const results = await Promise.allSettled([updateRPG(env), updateReflection(env)]);
  const tails = results.map((r) => (r.status === 'fulfilled' ? r.value : `error: ${r.reason}`));
  return [qt, ...tails];
}

// 仅供本地解析测试使用（Worker 运行时不引用）
export const __internal = { parseYTFeed, pickYTEntry, parseYTVideo, normalizeReading, parseQT, parseEnQT };
