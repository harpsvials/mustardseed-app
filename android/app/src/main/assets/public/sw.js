/* ===== mustardseed Service Worker：App 内 GitHub 在线内容更新 =====
   策略：stale-while-revalidate（统一）
   - 命中缓存：立即返回缓存，同时后台从远程源拉最新并更新缓存 → 完成后通知页面自动刷新，当次打开即新版
   - 未命中缓存：在线优先，先等远程拉最新（限时 4 秒）写缓存并返回；远程不可用再回本地内置 → 新文件首次即可打开
   - 远程源顺序：GitHub Pages（每次 push 自动部署、不重定向、大陆可访问）→ 官网 zhuzhouchurch.com（部署即最新）→ jsDelivr GitHub CDN → raw.githubusercontent（兜底）
   - 每源限时 3 秒（Promise.race，不依赖 AbortController）
   说明：mp3 等媒体不经过缓存（直接用本地内置）；网页端不注册本脚本，仅 App 内 WebView 使用
*/
'use strict';

var CACHE = 'ms-content-v2';
var REMOTE_BASES = [
  'https://harpsvials.github.io/mustardseed-app',
  'https://zhuzhouchurch.com',
  'https://cdn.jsdelivr.net/gh/harpsvials/mustardseed-app@main',
  'https://raw.githubusercontent.com/harpsvials/mustardseed-app/main'
];
var CACHEABLE = /\.(html?|css|js|json|png|jpe?g|svg|webp|ico|gif|woff2?)$/i;

self.addEventListener('install', function(e){
  self.skipWaiting();
});

self.addEventListener('activate', function(e){
  e.waitUntil((async function(){
    var keys = await caches.keys();
    await Promise.all(keys.filter(function(k){ return k !== CACHE; }).map(function(k){ return caches.delete(k); }));
    await self.clients.claim();
  })());
});

self.addEventListener('fetch', function(e){
  var req = e.request;
  if (req.method !== 'GET') return;
  var url = new URL(req.url);
  if (url.origin !== self.location.origin) return;      /* 只处理本机 WebView 请求 */
  if (url.pathname.indexOf('/sw.js') !== -1) return;   /* 不缓存自身 */
  if (!CACHEABLE.test(url.pathname)) return;           /* 媒体/其他资源直通本地内置 */
  e.respondWith(handle(req, url));
});

function remotes(path){
  var out = [];
  for (var i = 0; i < REMOTE_BASES.length; i++) out.push(REMOTE_BASES[i] + path);
  return out;
}

function timeoutFetch(url, ms){
  return Promise.race([
    fetch(url, { mode: 'cors', cache: 'no-store' }),
    new Promise(function(res, rej){
      setTimeout(function(){ rej(new Error('timeout ' + url)); }, ms || 3000);
    })
  ]);
}

async function fetchRemote(path){
  var urls = remotes(path);
  var lastErr = null;
  for (var i = 0; i < urls.length; i++){
    try {
      var r = await timeoutFetch(urls[i]);
      if (r.ok) return r;
      lastErr = new Error('bad status ' + r.status);
    } catch (err) { lastErr = err; }
  }
  throw lastErr || new Error('all remote failed');
}

/* 后台刷新：拉远程最新版写入缓存，成功后广播“内容已更新”给所有打开的页面
   （页面收到后自动重载，一次打开即可看到最新内容）；失败静默 */
function refresh(cache, req, path){
  fetchRemote(path).then(function(r){
    if (r && r.ok) return cache.put(req, normalize(r, path).clone()).then(function(){
      self.clients.matchAll({ includeUncontrolled: true }).then(function(list){
        for (var i = 0; i < list.length; i++){
          list[i].postMessage({ type: 'MS_UPDATE', path: path });
        }
      });
    });
  }).catch(function(){});
}

/* Content-Type 归一化：raw.githubusercontent 等源把 .html/.css/.js 返回 text/plain，
   直接缓存会让页面把 HTML 当源代码显示；按扩展名重建正确的 Content-Type */
var MIME = {
  '.html':'text/html; charset=utf-8', '.htm':'text/html; charset=utf-8',
  '.css':'text/css; charset=utf-8',
  '.js':'application/javascript; charset=utf-8', '.mjs':'application/javascript; charset=utf-8',
  '.json':'application/json; charset=utf-8',
  '.svg':'image/svg+xml', '.png':'image/png', '.jpg':'image/jpeg', '.jpeg':'image/jpeg',
  '.webp':'image/webp', '.ico':'image/x-icon', '.gif':'image/gif', '.woff2':'font/woff2'
};
function normalize(r, path){
  var m = path.match(/\.([a-zA-Z0-9]+)$/);
  if (!m) return r;
  var want = MIME['.' + m[1].toLowerCase()];
  if (!want) return r;
  var got = (r.headers.get('content-type') || '').toLowerCase().split(';')[0].trim();
  if (got === want.split(';')[0].trim()) return r;   /* 类型已正确，直接用 */
  try {
    var h = new Headers(r.headers);
    h.set('Content-Type', want);
    return new Response(r.body, { status: r.status, statusText: r.statusText, headers: h });
  } catch (e) { return r; }
}

async function handle(req, url){
  try {
    var cache = await caches.open(CACHE);
    var cached = await cache.match(req);
    if (cached) { refresh(cache, req, url.pathname); return cached; }
    /* 未命中：在线优先——先等远程拉最新（总限时 4 秒）写缓存并返回；
       远程不可用再回本地内置快照，绝不阻断页面 */
    var waited = Promise.race([
      fetchRemote(url.pathname),
      new Promise(function(res, rej){
        setTimeout(function(){ rej(new Error('remote slow')); }, 4000);
      })
    ]);
    try {
      var r = await waited;
      if (r && r.ok){
        var resp = normalize(r, url.pathname);
        cache.put(req, resp.clone());
        return resp;
      }
    } catch (e) {}
    return fetch(req);
  } catch (err) {
    return fetch(req);   /* 任何意外：直通本地，绝不阻断页面 */
  }
}
