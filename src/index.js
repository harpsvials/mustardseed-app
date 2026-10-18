// mustardseed 网站 — Worker 入口
// 1) /api/comments — 留言接口（GET 读取 / POST 发表），数据存 Cloudflare D1
// 2) 其余请求全部转交静态资源托管（[assets]），含自定义 404

/* ==================== 兜底 404 页面 ====================
 * 与仓库根目录 404.html 内容同步（修改 404.html 后请同步更新此常量），
 * 资源位于 src/：/src/site.css /src/shared.js /src/i18n.js /favicon.ico /mp3/Alleluia.mp3 /index.html */
const NOT_FOUND_HTML = `<!DOCTYPE html>
<html lang="zh-CN">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
<meta name="theme-color" content="#16281C">
<title>404 · mustardseed</title>
<link rel="icon" href="/favicon.ico">
<link rel="stylesheet" href="https://miaoda.feishu.cn/fonts/css2?family=Noto+Serif+SC:wght@400;600;700&amp;family=Noto+Sans+SC:wght@300;400;500&amp;family=Noto+Sans:wght@300;400;500&amp;family=Noto+Serif:wght@400;600;700&amp;family=Noto+Sans+JP:wght@300;400;500;700&amp;family=Noto+Sans+KR:wght@300;400;500;700&amp;display=swap">
<link rel="stylesheet" href="/src/site.css">
</head>
<body class="page-404 no-chap">
<div class="page">

  <!-- ===== 顶部：文字 logo + 语言切换 ===== -->
  <header class="site-header">
    <span class="logo" id="siteLogo"></span>
    <div class="lang-bar" id="langBar" role="group" data-i18n-aria="lang.label" aria-label="语言">
      </div>
  </header>

  <!-- ===== 404 主体 ===== -->
  <section class="nf-hero">
    <div class="sprout" aria-hidden="true"></div>
    <span class="nf-code" aria-hidden="true">404</span>
    <h1 data-i18n="404.title">页面不存在</h1>
    <p class="nf-desc" data-i18n="404.desc">您访问的页面可能已被移除或网址有误，请检查链接，或使用下方导航进入其他页面。</p>
    <a class="home-btn" href="/index.html" data-i18n="404.home">返回主页</a>
    <div class="hero-rule"></div>
  </section>

  <!-- ===== 联系合作 ===== -->
  <div class="contact-row">
    <a class="contact-link" href="mailto:xiaodongdaniel@icloud.com" data-i18n-aria="contact.label" aria-label="联系合作">
      <span class="contact-ic"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round"><rect x="3.5" y="5.5" width="17" height="13" rx="2"/><path d="M4 7l8 6 8-6"/></svg></span>
      <span data-i18n="contact.label">联系合作</span>
    </a>
  <div class="ms-player" id="msPlayer">
    <div class="ms-chip">
      <span class="ms-name">Alleluia</span>
      <span class="ms-time" id="msTime">0:00</span>
    </div>
    <button class="ms-btn" id="msPlay" data-i18n-aria="ms.play" aria-label="播放背景音乐">
            <span class="ms-btn-inner">
        <svg class="ms-ic-play" viewBox="0 0 24 24"><path d="M12 3v10.55A4 4 0 1 0 14 17V7h4V3h-6z" fill="currentColor"/></svg>
        <svg class="ms-ic-pause" viewBox="0 0 24 24" style="display:none"><path d="M6.5 4.5h4v15h-4zM13.5 4.5h4v15h-4z" fill="currentColor"/></svg>
      </span>
    </button>
  </div>
  </div>

  <!-- ===== 站点主导航 ===== -->
  <nav class="site-nav" data-i18n-aria="nav.aria" aria-label="站点导航" id="siteNav"></nav>

  <!-- ===== 朗读条：固定于主导航与正文之间（非悬浮） ===== -->
  <div class="rd-strip" id="rdBar" role="region" data-i18n-aria="rd.control" aria-label="朗读控制">
    <button class="rd-btn" id="rdBtn" data-i18n-aria="rd.play" aria-label="朗读全文">
      <svg class="ic-play" viewBox="0 0 24 24"><path d="M7 4.6v14.8L20 12z" fill="currentColor"/></svg>
      <svg class="ic-pause" viewBox="0 0 24 24" style="display:none"><path d="M6.5 4.5h4v15h-4zM13.5 4.5h4v15h-4z" fill="currentColor"/></svg>
    </button>
    <div class="rd-info">
      <span class="rd-title" data-i18n="rd.title">朗读全文</span>
    </div>
    <button class="rd-set" id="rdSet" data-i18n-aria="rd.set" aria-label="朗读设置" aria-expanded="false">
      <svg viewBox="0 0 24 24"><path d="M19.14 12.94c.04-.3.06-.61.06-.94 0-.32-.02-.64-.07-.94l2.03-1.58a.49.49 0 0 0 .12-.61l-1.92-3.32a.49.49 0 0 0-.59-.22l-2.39.96c-.5-.38-1.03-.7-1.62-.94l-.36-2.54a.48.48 0 0 0-.48-.41h-3.84c-.24 0-.43.17-.47.41l-.36 2.54c-.59.24-1.13.57-1.62.94l-2.39-.96c-.22-.08-.47 0-.59.22L2.74 8.87c-.12.21-.08.47.12.61l2.03 1.58c-.05.3-.07.63-.07.94s.02.64.07.94l-2.03 1.58a.49.49 0 0 0-.12.61l1.92 3.32c.12.22.37.29.59.22l2.39-.96c.5.38 1.03.7 1.62.94l.36 2.54c.05.24.24.41.48.41h3.84c.24 0 .44-.17.47-.41l.36-2.54c.59-.24 1.13-.56 1.62-.94l2.39.96c.22.08.47 0 .59-.22l1.92-3.32c.12-.22.07-.47-.12-.61l-2.01-1.58zM12 15.6A3.6 3.6 0 1 1 12 8.4a3.6 3.6 0 0 1 0 7.2z" fill="currentColor"/></svg>
    </button>
    <div class="rd-panel" id="rdSettings">
      <div class="rd-row">
        <span class="rd-row-label" data-i18n="rd.rate">语速</span>
        <input class="rd-slider" id="rdRate" type="range" min="0.5" max="1.5" step="0.05" value="1.15" data-i18n-aria="rd.rate" aria-label="语速">
        <span class="rd-val" id="rdRateVal">1.15</span>
      </div>
      <div class="rd-row">
        <span class="rd-row-label" data-i18n="rd.pitch">音调</span>
        <input class="rd-slider" id="rdPitch" type="range" min="0.5" max="1.5" step="0.05" value="1" data-i18n-aria="rd.pitch" aria-label="音调">
        <span class="rd-val" id="rdPitchVal">1.00</span>
      </div>
      <div class="rd-row">
        <span class="rd-row-label" data-i18n="rd.voice">语音</span>
        <button class="rd-voice" id="rdVoiceName" aria-label="切换语音">系统默认</button>
      </div>
    </div>
  </div>

  <footer>mustard<span class="seed">·</span>seed — <span data-i18n="footer.tag">让每个分享都像种子，落进土壤</span></footer>

</div>

  <audio id="msAudio" src="/mp3/Alleluia.mp3" preload="metadata" loop></audio>

<script>
/* ===== 语言字典（全站统一结构：键名约定见各页 data-i18n 属性） ===== */
window.I18N = {
'zh-CN':{
  'title':'404 · mustardseed',
  'lang.label':'语言',
  'nav.aria':'站点导航',
  'nav.home':'主页','nav.sermons':'讲道','nav.discussion':'讨论','nav.testimonies':'见证','nav.guestbook':'留言','nav.prayer':'祷告墙','nav.about':'关于','contact.label':'联系合作',
  '404.title':'页面不存在',
  '404.desc':'您访问的页面可能已被移除或网址有误，请检查链接，或使用下方导航进入其他页面。',
  '404.home':'返回主页',
  'footer.tag':'让每个分享都像种子，落进土壤',
  'ms.play':'播放背景音乐','ms.pause':'暂停背景音乐'
},
'zh-Hant':{
  'title':'404 · mustardseed',
  'lang.label':'語言',
  'nav.aria':'站點導航',
  'nav.home':'主頁','nav.sermons':'講道','nav.discussion':'討論','nav.testimonies':'見證','nav.guestbook':'留言','nav.prayer':'禱告牆','nav.about':'關於','contact.label':'聯繫合作',
  '404.title':'頁面不存在',
  '404.desc':'您訪問的頁面可能已被移除或網址有誤，請檢查連結，或使用下方導航進入其他頁面。',
  '404.home':'返回主頁',
  'footer.tag':'讓每個分享都像種子，落進土壤',
  'ms.play':'播放背景音樂','ms.pause':'暫停背景音樂'
},
'en':{
  'title':'404 · mustardseed',
  'lang.label':'Language',
  'nav.aria':'Site navigation',
  'nav.home':'Home','nav.sermons':'Sermons','nav.discussion':'Discussion','nav.testimonies':'Testimonies','nav.guestbook':'Guestbook','nav.prayer':'Prayer Wall','nav.about':'About Us','contact.label':'Contact & Partner',
  '404.title':'Page not found',
  '404.desc':'The page you are looking for may have been moved or the address may be incorrect. Please check the link, or use the navigation below to explore the site.',
  '404.home':'Back to Home',
  'footer.tag':'May every sharing fall like a seed into the soil',
  'ms.play':'Play background music','ms.pause':'Pause background music'
},
'fr':{
  'title':'404 · mustardseed',
  'lang.label':'Langue',
  'nav.aria':'Navigation du site',
  'nav.home':'Accueil','nav.sermons':'Prédications','nav.discussion':'Discussion','nav.testimonies':'Témoignages','nav.guestbook':"Livre d'or",'nav.prayer':'Mur de prière','nav.about':'À propos','contact.label':'Contact & Partenariat',
  '404.title':'Page introuvable',
  '404.desc':'La page que vous cherchez a peut-être été déplacée ou l\\u2019adresse est incorrecte. Vérifiez le lien, ou utilisez la navigation ci-dessous pour explorer le site.',
  '404.home':'Retour à l\\u2019accueil',
  'footer.tag':'Que chaque partage tombe comme une graine dans la terre',
  'ms.play':'Lire la musique de fond','ms.pause':'Mettre la musique en pause'
},
'it':{
  'title':'404 · mustardseed',
  'lang.label':'Lingua',
  'nav.aria':'Navigazione del sito',
  'nav.home':'Home','nav.sermons':'Prediche','nav.discussion':'Discussione','nav.testimonies':'Testimonianze','nav.guestbook':'Registro ospiti','nav.prayer':'Muro di preghiera','nav.about':'Chi siamo','contact.label':'Contatti & Collaborazione',
  '404.title':'Pagina non trovata',
  '404.desc':'La pagina che cerchi potrebbe essere stata spostata o l\\u2019indirizzo potrebbe essere errato. Controlla il link oppure usa la navigazione qui sotto per esplorare il sito.',
  '404.home':'Torna alla home',
  'footer.tag':'Che ogni condivisione cada come un seme nel terreno',
  'ms.play':'Riproduci la musica di sottofondo','ms.pause':'Metti in pausa la musica'
},
'ja':{
  'title':'404 · mustardseed',
  'lang.label':'言語',
  'nav.aria':'サイトナビゲーション',
  'nav.home':'ホーム','nav.sermons':'説教','nav.discussion':'交流','nav.testimonies':'証し','nav.guestbook':'ゲストブック','nav.prayer':'祈りの壁','nav.about':'私たちについて','contact.label':'連絡・協力',
  '404.title':'ページが見つかりません',
  '404.desc':'お探しのページは移動されたか、URL が正しくない可能性があります。リンクをご確認いただくか、下のナビゲーションから他のページへお進みください。',
  '404.home':'ホームに戻る',
  'footer.tag':'すべての分かち合いが、種のように土に落ちますように',
  'ms.play':'BGMを再生','ms.pause':'BGMを一時停止'
},
'ko':{
  'title':'404 · mustardseed',
  'lang.label':'언어',
  'nav.aria':'사이트 내비게이션',
  'nav.home':'홈','nav.sermons':'설교','nav.discussion':'교제','nav.testimonies':'간증','nav.guestbook':'방명록','nav.prayer':'기도의 벽','nav.about':'소개','contact.label':'연락 및 협력',
  '404.title':'페이지를 찾을 수 없습니다',
  '404.desc':'찾으시는 페이지가 이동되었거나 주소가 올바르지 않을 수 있습니다. 링크를 확인하시거나 아래 탐색 메뉴를 이용해 다른 페이지로 이동해 주세요.',
  '404.home':'홈으로 돌아가기',
  'footer.tag':'모든 나눔이 씨앗처럼 흙에 떨어지기를',
  'ms.play':'배경 음악 재생','ms.pause':'배경 음악 일시정지'
}
};
</script><script src="/src/i18n.js"></script><script>window.RD_SEL = ['.nf-desc'];</script><script src="/src/shared.js"></script>
</body>
</html>
`;

export default {
  async fetch(request, env, ctx) {
    const url = new URL(request.url);

    // —— 留言接口 ——
    if (url.pathname === '/api/comments') {
      if (request.method === 'GET') return getComments(env, url);
      if (request.method === 'POST') return addComment(request, env);
      return json({ ok: false, error: 'method-not-allowed' }, 405);
    }
    // —— 祷告墙接口 ——
    if (url.pathname === '/api/prayers') {
      if (request.method === 'GET') return getPrayers(env);
      if (request.method === 'POST') return addPrayer(request, env);
      return json({ ok: false, error: 'method-not-allowed' }, 405);
    }
    if (url.pathname.startsWith('/api/')) {
      return json({ ok: false, error: 'not-found' }, 404);
    }

    // —— 静态资源（index.html / sermons/ / 404 等） ——
    // 防御：ASSETS 缺失或异常时绝不抛错（否则 Cloudflare 显示 Error 1101），
    // 一律回退为渲染 404.html 或纯文本 404
    const notFound = async function () {
      return new Response(NOT_FOUND_HTML, {
        status: 404,
        headers: { 'Content-Type': 'text/html; charset=utf-8' }
      });
    };

    if (!env.ASSETS || typeof env.ASSETS.fetch !== 'function') {
      return notFound();
    }
    try {
      const res = await env.ASSETS.fetch(request);
      // 资源不存在时显式渲染 404.html（兼容 Pages / Workers 两种部署的 404 差异）
      if (res.status === 404 && url.pathname !== '/404.html') {
        return notFound();
      }
      return res;
    } catch (e) {
      return notFound();
    }
  }
};

/* ==================== D1 数据表（自动建表，幂等） ==================== */
let tableReady = false;

async function ensureTable(env) {
  if (tableReady) return;
  await env.DB.prepare(
    `CREATE TABLE IF NOT EXISTS comments (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      content TEXT NOT NULL,
      created_at TEXT NOT NULL DEFAULT (datetime('now'))
    )`
  ).run();
  /* 兼容旧表：补充 page 标签列（默认 guestbook，即留言板页） */
  const { results } = await env.DB.prepare('PRAGMA table_info(comments)').all();
  const hasPage = (results || []).some(function(c){ return c.name === 'page'; });
  if (!hasPage) {
    await env.DB.prepare(`ALTER TABLE comments ADD COLUMN page TEXT NOT NULL DEFAULT 'guestbook'`).run();
  }
  tableReady = true;
}

/* ==================== GET：留言列表（按 page 标签过滤，最新在前，最多 100 条） ==================== */
async function getComments(env, url) {
  await ensureTable(env);
  const page = url ? (url.searchParams.get('page') || '').slice(0, 30) : '';
  let rows;
  if (page) {
    const { results } = await env.DB.prepare(
      'SELECT id, name, content, page, created_at FROM comments WHERE page = ? ORDER BY id DESC LIMIT 100'
    ).bind(page).all();
    rows = results;
  } else {
    const { results } = await env.DB.prepare(
      'SELECT id, name, content, page, created_at FROM comments ORDER BY id DESC LIMIT 100'
    ).all();
    rows = results;
  }
  return json({ ok: true, items: rows || [] });
}

/* ==================== POST：发表留言（校验 + 防 XSS） ==================== */
async function addComment(request, env) {
  await ensureTable(env);

  let body;
  try { body = await request.json(); } catch (e) {
    return json({ ok: false, error: 'bad-json' }, 400);
  }

  const name = clean(body && body.name || '').slice(0, 20);
  const content = clean(body && body.content || '').slice(0, 500);
  const page = clean(body && body.page || 'guestbook').slice(0, 30);
  if (!name)  return json({ ok: false, error: 'name-required' }, 400);
  if (!content) return json({ ok: false, error: 'content-required' }, 400);
  if (hasBlocked(name) || hasBlocked(content)) {
    return json({ ok: false, error: 'blocked' }, 400);
  }

  const { meta } = await env.DB.prepare(
    'INSERT INTO comments (name, content, page) VALUES (?, ?, ?)'
  ).bind(name, content, page).run();

  return json({ ok: true, id: meta.last_row_id });
}

/* ==================== 祷告墙：独立 D1（PRAYER_DB） ==================== */
let prayerTableReady = false;

async function ensurePrayerTable(env) {
  if (prayerTableReady) return;
  await env.PRAYER_DB.prepare(
    `CREATE TABLE IF NOT EXISTS prayers (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      content TEXT NOT NULL,
      created_at TEXT NOT NULL DEFAULT (datetime('now'))
    )`
  ).run();
  prayerTableReady = true;
}

async function getPrayers(env) {
  await ensurePrayerTable(env);
  const { results } = await env.PRAYER_DB.prepare(
    'SELECT id, name, content, created_at FROM prayers ORDER BY id DESC LIMIT 100'
  ).all();
  return json({ ok: true, items: results || [] });
}

async function addPrayer(request, env) {
  await ensurePrayerTable(env);

  let body;
  try { body = await request.json(); } catch (e) {
    return json({ ok: false, error: 'bad-json' }, 400);
  }

  const name = clean(body && body.name || '').slice(0, 20);
  const content = clean(body && body.content || '').slice(0, 500);
  if (!name)  return json({ ok: false, error: 'name-required' }, 400);
  if (!content) return json({ ok: false, error: 'content-required' }, 400);
  if (hasBlocked(name) || hasBlocked(content)) {
    return json({ ok: false, error: 'blocked' }, 400);
  }

  const { meta } = await env.PRAYER_DB.prepare(
    'INSERT INTO prayers (name, content) VALUES (?, ?)'
  ).bind(name, content).run();

  return json({ ok: true, id: meta.last_row_id });
}

/* ==================== 工具 ==================== */
// 敏感词检测（色情/暴力/辱骂），命中即拒绝
const BLOCKED = ['色情','淫秽','裸聊','约炮','嫖娼','卖淫','援交','一夜情','三级片','杀人','砍人','爆炸','炸弹','枪杀','恐怖袭击','血腥','分尸','傻逼','傻b','傻比','蠢货','废物','混蛋','王八蛋','贱人','贱货','去死','妈的','他妈的','操你','滚蛋','智障','脑残','fuck','bitch','shit','asshole','bastard','damn','idiot','广告','加微信','加vx','加qq','微信二维码','扫码','代购','微商','刷单','营销','招商','加盟','批发','低价出售','投资理财','博彩','办证','代开发票'];
function hasBlocked(text) {
  const t = String(text == null ? '' : text).toLowerCase();
  return BLOCKED.some(function (w) { return t.indexOf(w) !== -1; });
}

// HTML 转义，防止 XSS 注入
function clean(s) {
  return String(s == null ? '' : s).replace(/[&<>"']/g, function (c) {
    return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c];
  }).trim();
}

function json(data, status) {
  return new Response(JSON.stringify(data), {
    status: status || 200,
    headers: {
      'Content-Type': 'application/json; charset=utf-8',
      'Cache-Control': 'no-store'
    }
  });
}
