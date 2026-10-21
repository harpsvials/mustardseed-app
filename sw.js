/* ===== mustardseed Service Worker：App 内 GitHub 在线内容更新 =====
   策略：stale-while-revalidate（统一）
   - 命中缓存：立即返回缓存，同时后台从远程源拉最新并更新缓存 → 下次打开即新版
   - 未命中缓存：不等待远程，立即返回本地内置快照，同时后台拉远程并缓存 → 打开永远快、永不失败
   - 远程源顺序：官网 zhuzhouchurch.com（部署即最新）→ jsDelivr GitHub CDN → raw.githubusercontent
   - 每源限时 3 秒（Promise.race，不依赖 AbortController）
   说明：mp3 等媒体不经过缓存（直接用本地内置）；网页端不注册本脚本，仅 App 内 WebView 使用
*/
'use strict';

var CACHE = 'ms-content-v1';
var REMOTE_BASES = [
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

/* 后台刷新：拉远程最新版写入缓存，失败静默（不影响当前页面） */
function refresh(cache, req, path){
  fetchRemote(path).then(function(r){
    if (r && r.ok) return cache.put(req, r.clone());
  }).catch(function(){});
}

async function handle(req, url){
  try {
    var cache = await caches.open(CACHE);
    var cached = await cache.match(req);
    if (cached) { refresh(cache, req, url.pathname); return cached; }
    /* 未命中：立即返回本地内置（不等待远程），后台补远程缓存 → 下次打开即新内容 */
    refresh(cache, req, url.pathname);
    return fetch(req);
  } catch (err) {
    return fetch(req);   /* 任何意外：直通本地，绝不阻断页面 */
  }
}
