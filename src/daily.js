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
const RPG_CATEGORY = 'https://www.rpg-move.tw/category/rpg-daily/';
const RPG_UPLOAD = 'https://www.rpg-move.tw/wp-content/uploads/';
const SITE = 'https://www.zhuzhouchurch.com';
const KEEP_DAYS = 7;
const WEEKDAYS = ['星期一', '星期二', '星期三', '星期四', '星期五', '星期六', '星期日'];

const toCN = Converter({ from: 't', to: 'cn' });
const simplify = (s) => toCN(s || '');

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
    sourceUrl: QT_URL
  };
}

async function updateQT(env) {
  const kv = env.MUSTARDSEED_DATA;
  if (!kv) return 'no-kv';
  let data;
  try {
    data = parseQT(toLines(await fetchText(QT_URL)));
  } catch (e) {
    return `qt-fail: ${e.message}`;
  }
  // 对方站点还没换当天内容时，不写入，留给下个时间点重试
  if (data.date !== tpeDate()) return `qt-skip: 站点仍是 ${data.date}`;

  const prevRaw = await kv.get('qt-data.json');
  if (prevRaw) {
    try {
      const prev = JSON.parse(prevRaw);
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

  data.updated = tpeStamp();
  data.updatedLabel = tpeLabel();
  await kv.put('qt-data.json', JSON.stringify(data, null, 2) + '\n');
  return `qt-ok: ${data.dateLabel} ${data.topic}`;
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
        item.verseImageUrl = `${SITE}/api/asset?p=images/rpg/${verseName}`;
        break;
      }
    }
    const pb = await fetchBinary(parsed.prayerUrl);
    if (pb && pb.byteLength >= 15000) {
      await kv.put(`images/rpg/${prayerName}`, pb, { metadata: { contentType: 'image/jpeg' } });
      item.prayerImage = prayerName;
      item.prayerImageUrl = `${SITE}/api/asset?p=images/rpg/${prayerName}`;
    }
    if (item.verseImage || item.prayerImage) items.set(parsed.date, item);
  }

  // 抓不到的近 7 天沿用旧条目，避免清单被清空
  for (const [date, it] of prevItems) {
    if (items.has(date) || date < earliest || date > today) continue;
    items.set(date, it);
  }

  const keep = [...items.values()].sort((a, b) => (a.date < b.date ? 1 : -1)).slice(0, KEEP_DAYS);
  const signature = keep.map((i) => `${i.date}${i.verseImage}${i.prayerImage}`).join('|');
  const prevSig = (prev?.items || [])
    .slice(0, KEEP_DAYS)
    .map((i) => `${i.date}${i.verseImage}${i.prayerImage}`)
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

export async function updateDaily(env) {
  const results = await Promise.allSettled([updateQT(env), updateRPG(env)]);
  return results.map((r) => (r.status === 'fulfilled' ? r.value : `error: ${r.reason}`));
}
