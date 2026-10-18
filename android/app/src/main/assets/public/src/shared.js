/*! shared.js — mustardseed 全站公共脚本（小苗注入 + 语言切换 + 朗读 + 背景音乐）
 * 用法：在每个页面 I18N 字典脚本之后引入：
 *   根目录页面：<script src="shared.js"></script>
 *   子目录页面：<script src="../shared.js"></script>
 * 可选配置（在引入 shared.js 之前声明）：
 *   window.RD_SEL = ['.para']             —— 朗读条页面的朗读选区（默认 ['.para']）
 */

/* ===== 1. 嫩芽小苗：自动注入 .sprout 容器 ===== */
(function(){
  var svg = `<svg viewBox="0 0 140 150" role="img">
        <defs>
          <radialGradient id="glow" cx="50%" cy="42%" r="50%">
            <stop offset="0%" stop-color="#E0AE33" stop-opacity=".20"/>
            <stop offset="100%" stop-color="#E0AE33" stop-opacity="0"/>
          </radialGradient>
        </defs>
        <circle cx="70" cy="62" r="52" fill="url(#glow)"/>
        <path d="M36 130 Q70 113 104 130 Z" fill="rgba(143,191,95,.14)"/>
        <path d="M38 129 Q70 114 102 129" stroke="rgba(143,191,95,.55)" stroke-width="2.4" fill="none" stroke-linecap="round"/>
        <g class="sprout-sway">
          <path d="M70 120 C 72 98 62 86 68 66" stroke="var(--sprout)" stroke-width="3.2" fill="none" stroke-linecap="round"/>
          <path d="M68 66 C 50 61 36 49 32 32 C 51 35 63 48 68 66 Z" fill="rgba(143,191,95,.92)"/>
          <path d="M68 66 C 84 60 97 45 103 28 C 86 31 72 46 68 66 Z" fill="rgba(143,191,95,.78)"/>
          <path d="M67 63 C 56 57 46 45 38 35" stroke="rgba(22,40,28,.4)" stroke-width="1.4" fill="none" stroke-linecap="round"/>
          <path d="M69 63 C 79 55 89 42 95 31" stroke="rgba(22,40,28,.3)" stroke-width="1.4" fill="none" stroke-linecap="round"/>
          <circle cx="68" cy="63" r="3.4" fill="#A8D17B"/>
        </g>
      </svg>`;
  var els = document.querySelectorAll('.sprout');
  for(var i=0;i<els.length;i++){
    if(!els[i].querySelector('svg')) els[i].innerHTML = svg;
  }
})();

/* ===== 2. 站点头部：文字 logo + 语言切换链接（统一注入；每种语言独立 URL /<lang>/） ===== */
(function(){
  /* logo 文字（品牌名不随语言变化） */
  var logo = document.getElementById('siteLogo');
  if(logo && !logo.firstChild) logo.innerHTML = 'mustard<span class="dot">·</span>seed';
  var LANGS = [
    ['zh-CN','简体中文','简体'],
    ['zh-Hant','繁體中文','繁體'],
    ['en','English','EN'],
    ['fr','Français','FR'],
    ['it','Italiano','IT'],
    ['ja','日本語','日本語'],
    ['ko','한국어','한국어']
  ];
  /* 当前语言与相对路径（URL 首段为语言码时剥离；file:// 下从路径尾部语言目录段推断） */
  var cur = 'zh-CN';
  var mm = (location.pathname || '/').match(/^\/(zh-CN|zh-Hant|en|fr|it|ja|ko)(\/|$)/);
  if(mm) cur = mm[1];
  else if(location.protocol === 'file:'){
    var pm = (location.pathname || '').match(/\/(zh-CN|zh-Hant|en|fr|it|ja|ko)\/[^\/]+\.html$/);
    if(pm) cur = pm[1];
  }
  /* 资源基准（shared.js 位于 src/，回到项目根） */
  var sc = document.currentScript && document.currentScript.src;
  var base = sc ? sc.substring(0, sc.lastIndexOf('/') + 1) : '';
  base = base.replace(/(^|\/)src\/$/, '$1');
  var basePath = decodeURIComponent(new URL(base, location.href).pathname).replace(/\/$/, '');
  var rel = decodeURIComponent(location.pathname || '/');
  if(basePath && rel.indexOf(basePath) === 0) rel = rel.slice(basePath.length);
  rel = rel.replace(/^\/(zh-CN|zh-Hant|en|fr|it|ja|ko)(?=\/)/, '') || '/';
  var bar = document.getElementById('langBar');
  if(!bar || bar.querySelector('.lang-btn')) return;
  var html = '';
  for(var i=0;i<LANGS.length;i++){
    var href = (LANGS[i][0] === 'zh-CN') ? base.replace(/\/$/, '') + rel : base + LANGS[i][0] + rel;   /* 简体中文为根路径，无 /zh-CN/ 目录 */
    var act = (LANGS[i][0] === cur) ? ' is-active' : '';
    html += '<a class="lang-btn' + act + '" data-lang="' + LANGS[i][0] + '" href="' + href + '" aria-label="' + LANGS[i][1] + '">' + LANGS[i][2] + '</a>';
  }
  bar.innerHTML = html;
})();

/* ===== 3. i18n 语言核心（URL 权威：/<lang>/ 决定当前语言；静态化页面无需本地改写） ===== */
(function(){
  var LANGS = ['zh-CN','zh-Hant','en','fr','it','ja','ko'];
  window.__langHooks = window.__langHooks || [];
  var cur = 'zh-CN';
  var mm = (location.pathname || '/').match(/^\/(zh-CN|zh-Hant|en|fr|it|ja|ko)(\/|$)/);
  if(mm) cur = mm[1];
  else if(location.protocol === 'file:'){
    var pm = (location.pathname || '').match(/\/(zh-CN|zh-Hant|en|fr|it|ja|ko)\/[^\/]+\.html$/);
    if(pm) cur = pm[1];
  }
  function apply(){
    var d = window.I18N[cur] || window.I18N['zh-CN'];
    document.documentElement.lang = cur;
    if(d.title) document.title = d.title;
    var i, els = document.querySelectorAll('[data-i18n]');
    for(i=0;i<els.length;i++){ var k=els[i].getAttribute('data-i18n'); if(d[k]!=null) els[i].textContent=d[k]; }
    els = document.querySelectorAll('[data-i18n-html]');
    for(i=0;i<els.length;i++){ var k=els[i].getAttribute('data-i18n-html'); if(d[k]!=null) els[i].innerHTML=d[k]; }
    els = document.querySelectorAll('[data-i18n-aria]');
    for(i=0;i<els.length;i++){ var k=els[i].getAttribute('data-i18n-aria'); if(d[k]!=null) els[i].setAttribute('aria-label',d[k]); }
    els = document.querySelectorAll('.lang-btn');
    for(i=0;i<els.length;i++){ els[i].classList.toggle('is-active', els[i].getAttribute('data-lang')===cur); }
    if(window.__rdRebuild) window.__rdRebuild();
    for(i=0;i<window.__langHooks.length;i++){ try{ window.__langHooks[i](cur,d); }catch(e){} }
  }
  /* 语言切换由 /<lang>/ URL 跳转完成（上方 §2 生成 <a> 链接），此处不再本地改写 */
  window.__lang = { get:function(){ return cur; }, apply:apply };
  apply();
})();

/* ===== 4. 站点导航：统一注入 7 个主导航链接（全部可点击，当前页高亮） ===== */
(function(){
  var NAV = [
    ['nav.home',    'index.html',                          '主页'],
    ['nav.sermons', 'sermons.html',                        '讲道'],
    ['nav.discussion', 'discussion.html',                  '讨论'],
    ['nav.testimonies', 'testimonies.html',                '见证'],
    ['nav.guestbook', 'guestbook.html',                    '留言'],
    ['nav.prayer',   'prayer.html',                        '祷告墙'],
    ['nav.about',    'about.html',                         '关于']
  ];
  var nav = document.getElementById('siteNav');
  if(!nav) return;
  var sc = document.currentScript && document.currentScript.src;
  var base = sc ? sc.substring(0, sc.lastIndexOf('/') + 1) : '';
  base = base.replace(/(^|\/)src\/$/, '$1');   /* shared.js 位于 src/，资源基准回到项目根 */
  var lang = (window.__lang && window.__lang.get()) || 'zh-CN';   /* 导航指向当前语言版本 */
  var curPath = decodeURIComponent((location.pathname || '/').split('#')[0]).replace(/\/+$/, '') || '/';
  var curFile = curPath.split('/').pop() || '';
  var basePath = decodeURIComponent(new URL(base + lang + '/', location.href).pathname).replace(/\/+$/, '') || '/';
  var MAIN = { 'index.html':0, 'sermons.html':1, 'discussion.html':2, 'testimonies.html':3, 'guestbook.html':4, 'prayer.html':5, 'about.html':6 };
  var activeIdx = -1;
  /* 优先按导航 href 匹配当前路径（兼容：根路径、子目录部署、无 .html 的 clean URL） */
  for(var i=0;i<NAV.length;i++){
    var navHref = (lang === 'zh-CN') ? base + NAV[i][1] : base + lang + '/' + NAV[i][1];   /* 简体中文导航指向根路径 */
    var hp = decodeURIComponent(new URL(navHref, location.href).pathname).replace(/\/+$/, '');
    if(curPath === hp || curPath === hp.replace(/\.html$/, '')){ activeIdx = i; break; }
  }
  if(activeIdx < 0){
    if(curPath === '/' || curPath === basePath || curFile === 'index.html' || curFile === 'index') activeIdx = 0;   /* 根路径视为主页 */
    else if(curFile === '404.html' || curFile === '404') activeIdx = -1;
    else if(MAIN[curFile] !== undefined) activeIdx = MAIN[curFile];
    else activeIdx = 1;  /* 讲道文字稿页面默认高亮「讲道文字」 */
  }
  var d = (window.I18N && window.__lang && window.I18N[window.__lang.get()]) || (window.I18N && window.I18N['zh-CN']) || {};
  var html = '';
  for(var i=0;i<NAV.length;i++){
    var k = NAV[i][0];
    var href = (lang === 'zh-CN') ? base + NAV[i][1] : base + lang + '/' + NAV[i][1];   /* 简体中文为根路径 */
    var name = (d[k] != null) ? d[k] : NAV[i][2];
    var active = (i === activeIdx) ? ' is-current' : '';
    html += '<a class="site-link' + active + '" href="' + href + '" data-i18n="' + k + '">' + name + '</a>';
  }
  nav.innerHTML = html;
  var foot = document.getElementById('siteNavFoot');
  if(foot) foot.innerHTML = html;   /* 页脚导航与顶部共用一套注入 */
})();

/* ===== 5. 朗读条：播放/暂停 + 高亮跟读（SEL 由 window.RD_SEL 参数化） ===== */
(function(){
  /* 朗读设置面板开关：独立于朗读引擎立即绑定，任何情况下都可点开 */
  function bindSet(){
    var bar = document.getElementById('rdBar'), setBtn = document.getElementById('rdSet');
    if(setBtn && bar && !setBtn.__bound){
      setBtn.__bound = true;
      setBtn.addEventListener('click', function(){
        var open = bar.classList.toggle('open');
        setBtn.setAttribute('aria-expanded', open ? 'true' : 'false');
      });
    }
  }
  if(document.readyState === 'loading'){ document.addEventListener('DOMContentLoaded', bindSet); }
  else { bindSet(); }

  function rdMain(){
  try{
  var SEL = window.RD_SEL || ['.para'];
  /* 原生 TTS 桥（Android App 内）：WebView 的 speechSynthesis 不可用，改用原生朗读 */
  var nativeTTS = !!(window.AndroidTTS && window.AndroidTTS.isReady());
  if(!('speechSynthesis' in window) && !nativeTTS) return;
  var syn = window.speechSynthesis;
  var curUttId = '';
  if(nativeTTS){
    window.__ttsCb = function(ev, id){
      if(id && id !== curUttId) return;
      if((ev === 'done' || ev === 'error') && state === 'playing'){ speakFrom(idx + 1); }
    };
  }
  var btn = document.getElementById('rdBtn');
  if(!btn) return;
  var segs = [], total = 0, idx = -1, playing = false;
  var prog = document.getElementById('rdProg');
  var icPlay = btn.querySelector('.ic-play'), icPause = btn.querySelector('.ic-pause');
  var rateEl = document.getElementById('rdRate'), pitchEl = document.getElementById('rdPitch');
  var rateVal = document.getElementById('rdRateVal'), pitchVal = document.getElementById('rdPitchVal');
  var voiceName = document.getElementById('rdVoiceName');
  var bar = document.getElementById('rdBar'), setBtn = document.getElementById('rdSet');
  var LANG_BCP = {'zh-CN':'zh-CN','zh-Hant':'zh-TW',en:'en-US',fr:'fr-FR',it:'it-IT',ja:'ja-JP',ko:'ko-KR'};
  var curVoices = [], voiceIdx = 0;
  function esc(s){ return s.replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;'); }
  function clearHL(){ for(var i=0;i<segs.length;i++) segs[i].classList.remove('rd-active'); }
  function rebuild(){
    segs = [];
    var nodes = document.querySelectorAll(SEL.join(','));
    for(var n=0;n<nodes.length;n++){
      var el = nodes[n];
      var text = el.textContent.replace(/\s+/g,' ').trim();
      if(!text) continue;
      var parts = text.match(/[^。！？；.!?]+[。！？；.!?]?/g) || [text];
      var strongs = [];
      el.querySelectorAll('strong').forEach(function(st){ var t=st.textContent.trim(); if(t) strongs.push(t); });
      var frag = document.createDocumentFragment();
      parts.forEach(function(s){
        var sp = document.createElement('span');
        sp.className = 'rd-seg';
        var h = esc(s);
        strongs.forEach(function(st){
          var e = esc(st);
          if(h.indexOf(e) !== -1) h = h.split(e).join('<strong>'+e+'</strong>');
        });
        sp.innerHTML = h;
        frag.appendChild(sp);
        segs.push(sp);
      });
      el.innerHTML = '';
      el.appendChild(frag);
    }
    total = segs.length;
    if(!total){ btn.style.display = 'none'; return; }
    btn.style.display = '';
    if(prog) prog.textContent = '0 / ' + total;
    clearHL();
    if(idx >= total) idx = -1;
  }
  function langPrefix(){ return (window.__lang.get() || 'zh-CN').split('-')[0]; }
  function pickVoices(){
    if(nativeTTS){ if(voiceName) voiceName.textContent = (window.I18N[window.__lang.get()] || window.I18N['zh-CN'])['rd.voice.default']; return; }
    var prefix = langPrefix();
    var vs = syn.getVoices();
    var m = [];
    for(var i=0;i<vs.length;i++){ if(vs[i].lang && vs[i].lang.toLowerCase().indexOf(prefix)===0) m.push(vs[i]); }
    curVoices = m;
    var d = window.I18N[window.__lang.get()] || window.I18N['zh-CN'];
    if(voiceName) voiceName.textContent = curVoices.length ? curVoices[voiceIdx % curVoices.length].name : d['rd.default'];
  }
  pickVoices();
  if(syn.onvoiceschanged !== undefined) syn.onvoiceschanged = pickVoices;
  function curVoice(){ return curVoices.length ? curVoices[voiceIdx % curVoices.length] : null; }
  function restartIfPlaying(){ if(state !== 'idle' && idx !== -1){ var i = idx; stopAll(); speakFrom(i); } }
  if(setBtn && bar){
    setBtn.addEventListener('click', function(){
      var open = bar.classList.toggle('open');
      setBtn.setAttribute('aria-expanded', open ? 'true' : 'false');
    });
  }
  if(voiceName){
    voiceName.addEventListener('click', function(){
      if(nativeTTS || !curVoices.length) return;
      voiceIdx = (voiceIdx + 1) % curVoices.length;
      voiceName.textContent = curVoices[voiceIdx].name;
      restartIfPlaying();
    });
  }
  function mark(i){
    clearHL();
    segs[i].classList.add('rd-active');
    try{ segs[i].scrollIntoView({block:'center', behavior:'smooth'}); }catch(e){ segs[i].scrollIntoView(); }
    if(prog) prog.textContent = (i + 1) + ' / ' + total;
  }
  var state = 'idle';          /* idle 未朗读 | playing 播放中 | paused 已暂停 */
  var lastCancel = 0;
  function setBtnUI(){
    if(state === 'playing'){ icPlay.style.display = 'none'; icPause.style.display = ''; }
    else { icPlay.style.display = ''; icPause.style.display = 'none'; }
  }
  function stopAll(){
    if(nativeTTS){ try{ window.AndroidTTS.stop(); }catch(e){} }
    else { try{ syn.cancel(); }catch(e){} }
    lastCancel = Date.now();
    state = 'idle';
    setBtnUI();
  }
  function speakFrom(i){
    if(i >= total){
      stopAll(); clearHL(); idx = -1;
      if(prog) prog.textContent = '0 / ' + total;
      return;
    }
    idx = i; mark(i);
    if(nativeTTS){
      state = 'playing';
      setBtnUI();
      var rate = rateEl ? (+rateEl.value) : 1.15;
      var pitch = pitchEl ? (+pitchEl.value) : 1;
      curUttId = 'u' + Date.now();
      try{ window.AndroidTTS.speak(segs[i].textContent, LANG_BCP[window.__lang.get()] || 'zh-CN', rate, pitch); }catch(e){}
      return;
    }
    var u = new SpeechSynthesisUtterance(segs[i].textContent);
    var v = curVoice(); if(v) u.voice = v;
    u.lang = LANG_BCP[window.__lang.get()] || 'zh-CN';
    u.rate = rateEl ? (+rateEl.value) : 1.15;
    u.pitch = pitchEl ? (+pitchEl.value) : 1;
    u.onend = function(){ if(state === 'playing') speakFrom(idx + 1); };
    u.onerror = function(){ if(state === 'playing') speakFrom(idx + 1); };
    state = 'playing';
    setBtnUI();
    var wait = 180 - (Date.now() - lastCancel);
    if(wait > 0){ setTimeout(function(){ syn.speak(u); }, wait); }
    else { syn.speak(u); }
  }
  btn.addEventListener('click', function(){
    if(state === 'idle'){
      if(idx === -1) idx = 0;
      speakFrom(idx);
    } else if(state === 'playing'){
      if(nativeTTS){ stopAll(); clearHL(); idx = -1; return; }   /* 原生 TTS 无暂停，播放中点击=停止 */
      try{ syn.pause(); }catch(e){ stopAll(); }
      state = 'paused';
      setBtnUI();
    } else {
      try{ syn.resume(); state = 'playing'; setBtnUI(); }catch(e){ state = 'idle'; setBtnUI(); }
    }
  });
  /* 「朗读全文」文字与播放按钮同功能：点击文字等价于点击播放/暂停键 */
  var titleEl = document.querySelector('.rd-info .rd-title');
  if(titleEl) titleEl.addEventListener('click', function(e){ e.preventDefault(); btn.click(); });
  if(rateEl && rateVal) rateEl.addEventListener('input', function(){ rateVal.textContent = (+rateEl.value).toFixed(2); restartIfPlaying(); });
  if(pitchEl && pitchVal) pitchEl.addEventListener('input', function(){ pitchVal.textContent = (+pitchEl.value).toFixed(2); restartIfPlaying(); });
  window.__rdRebuild = rebuild;
  window.__langHooks.push(function(cur, d){
    voiceIdx = 0; pickVoices();
    var wasPlaying = state !== 'idle';
    stopAll();
    rebuild();
    if(wasPlaying){ idx = 0; speakFrom(0); }
    else { idx = -1; if(prog) prog.textContent = '0 / ' + total; }
  });
  rebuild();
  }catch(e){}
  }
  function boot(){
    if(document.readyState === 'loading'){ document.addEventListener('DOMContentLoaded', rdMain); }
    else { rdMain(); }
  }
  /* 原生 TTS 初始化是异步的：等待就绪后再初始化朗读，避免误判为浏览器语音路径（WebView 里无声） */
  if(window.AndroidTTS){
    var _tries = 0;
    (function wait(){
      try{ if(window.AndroidTTS.isReady()){ boot(); return; } }catch(e){}
      if(++_tries < 60){ setTimeout(wait, 200); } else { boot(); }
    })();
  } else { boot(); }
})();

/* ===== 5.1 支持与合作：App 内 mailto 不可用 → 点击复制邮箱 ===== */
(function(){
  var contact = document.querySelector('.contact-link');
  if(!contact) return;
  contact.addEventListener('click', function(e){
    /* 浏览器保留 mailto 原生行为；仅原生 App（WebView）内改为复制邮箱 */
    if(!(window.Capacitor && window.Capacitor.isNativePlatform())) return;
    e.preventDefault();
    var mail = (contact.getAttribute('href') || '').replace(/^mailto:/i, '');
    if(!mail) return;
    var done = false;
    try{
      var ta = document.createElement('textarea');
      ta.value = mail;
      ta.setAttribute('readonly', '');
      ta.style.position = 'fixed';
      ta.style.opacity = '0';
      document.body.appendChild(ta);
      ta.select();
      done = document.execCommand('copy');
      document.body.removeChild(ta);
    }catch(err){ done = false; }
    if(!done && navigator.clipboard && navigator.clipboard.writeText){
      navigator.clipboard.writeText(mail).catch(function(){});
      done = true;
    }
    var d = (window.I18N && window.__lang && window.I18N[window.__lang.get()]) || (window.I18N && window.I18N['zh-CN']) || {};
    var msg = (d['contact.copied'] || '邮箱已复制') + '：' + mail;
    var t = document.createElement('div');
    t.className = 'rd-toast';
    t.setAttribute('role', 'status');
    t.textContent = msg;
    document.body.appendChild(t);
    setTimeout(function(){ t.classList.add('show'); }, 10);
    setTimeout(function(){
      t.classList.remove('show');
      setTimeout(function(){ if(t.parentNode) t.parentNode.removeChild(t); }, 400);
    }, 2600);
  });
})();

/* ===== 6. 背景音乐播放器：悬浮播放列表（多曲目，点选任意曲目均单曲循环） ===== */
(function(){
  /* 脚本顶层同步执行时 currentScript 有效；延迟执行（DOMContentLoaded）时回退到 DOM 查询 */
  var sc = document.currentScript && document.currentScript.src;
  if(!sc){
    var s = document.querySelector('script[src$="shared.js"]');
    if(s) sc = s.src;
  }
  var base = sc ? sc.substring(0, sc.lastIndexOf('/') + 1) : '';
  base = base.replace(/(^|\/)src\/$/, '$1');   /* shared.js 位于 src/，资源基准回到项目根 */
  base = new URL(base, location.href).href;   /* 规范化子目录 ../ 前缀 */
  function msMain(){
    var a = document.getElementById('msAudio');
    if(!a) return;
    var pl = document.getElementById('msPlayer');
    var btn = document.getElementById('msPlay');
    var tm = document.getElementById('msTime');
    if(!pl || !btn) return;
    /* 播放列表（按顺序；单曲循环由 audio 元素 loop 属性保证） */
    var TRACKS = [
      { file: 'mp3/Alleluia.mp3',                      name: 'Alleluia' },
      { file: 'mp3/Healing In Your Presence.mp3',      name: 'Healing In Your Presence' }
    ];
    var cur = 0, playing = false, listOpen = false;
    var icPlay = btn.querySelector('.ms-ic-play'), icPause = btn.querySelector('.ms-ic-pause');
    var nameEl = pl.querySelector('.ms-name');
    var listEl = document.createElement('div');
    listEl.className = 'ms-list';
    listEl.setAttribute('role', 'listbox');
    var html = '';
    for(var i=0;i<TRACKS.length;i++){
      html += '<button type="button" class="ms-item" data-i="' + i + '" role="option" aria-label="' + TRACKS[i].name + '">' +
        '<span class="ms-item-name">' + TRACKS[i].name + '</span>' +
        '<span class="ms-item-ic"><svg viewBox="0 0 24 24"><path d="M8 5v14l11-7z" fill="currentColor"/></svg></span>' +
        '</button>';
    }
    listEl.innerHTML = html;
    listEl.hidden = true;   /* 初始收起 */
    pl.appendChild(listEl);
    var itemEls = listEl.querySelectorAll('.ms-item');
    function fmt(s){
      s = Math.floor(s || 0);
      var m = Math.floor(s / 60), ss = s % 60;
      return m + ':' + (ss < 10 ? '0' : '') + ss;
    }
    function lbl(p){
      var d = (window.I18N && window.__lang && window.I18N[window.__lang.get()]) || (window.I18N && window.I18N['zh-CN']) || {};
      return d[p ? 'ms.pause' : 'ms.play'];
    }
    function setPlaying(p){
      playing = p;
      if(p) pl.classList.add('playing'); else pl.classList.remove('playing');
      /* 播放中显示暂停图标，停止时恢复音符图标 */
      icPlay.style.display = p ? 'none' : '';
      icPause.style.display = p ? '' : 'none';
      btn.setAttribute('aria-label', lbl(p));
      for(var k=0;k<itemEls.length;k++){
        itemEls[k].classList.toggle('is-playing', p && k === cur);
      }
    }
    function setCur(i){
      cur = i;
      if(nameEl) nameEl.textContent = TRACKS[i].name;
      for(var k=0;k<itemEls.length;k++){
        itemEls[k].classList.toggle('is-active', k === i);
        itemEls[k].setAttribute('aria-selected', k === i ? 'true' : 'false');
      }
    }
    function playTrack(i){
      if(i === cur && playing){ a.pause(); return; }
      if(i !== cur){
        a.src = base + TRACKS[i].file;
        a.load();
        setCur(i);
      }
      var pr = a.play();
      if(pr && pr.catch) pr.catch(function(){});
    }
    function setListOpen(open){
      listOpen = open;
      pl.classList.toggle('list-open', open);
      listEl.hidden = !open;
      btn.setAttribute('aria-expanded', open ? 'true' : 'false');
      if(open) btn.setAttribute('aria-label', (window.I18N && window.I18N[window.__lang.get()] && window.I18N[window.__lang.get()]['ms.list']) || '选择音乐');
      else btn.setAttribute('aria-label', lbl(playing));
    }
    btn.addEventListener('click', function(e){
      e.stopPropagation();
      setListOpen(!listOpen);
    });
    for(var q=0;q<itemEls.length;q++){
      (function(idx, el){
        el.addEventListener('click', function(){
          playTrack(idx);
          setListOpen(false);
        });
      })(q, itemEls[q]);
    }
    document.addEventListener('click', function(e){
      if(listOpen && !pl.contains(e.target)) setListOpen(false);
    });
    a.addEventListener('play', function(){ setPlaying(true); });
    a.addEventListener('pause', function(){ setPlaying(false); });
    a.addEventListener('timeupdate', function(){
      if(tm) tm.textContent = fmt(a.currentTime);
      var pct = a.duration ? (a.currentTime / a.duration * 100) : 0;
      btn.style.setProperty('--p', pct.toFixed(2));
    });
    if(document.querySelector('.rd-bar')) pl.classList.add('pos-up');
    window.__langHooks.push(function(){
      btn.setAttribute('aria-label', listOpen
        ? ((window.I18N && window.I18N[window.__lang.get()] && window.I18N[window.__lang.get()]['ms.list']) || '选择音乐')
        : lbl(playing));
    });
    setCur(cur);
  }
  if(document.readyState === 'loading'){ document.addEventListener('DOMContentLoaded', msMain); }
  else { msMain(); }
})();

/* ===== 7. 敏感词检测（留言过滤：色情/暴力/辱骂），供各页留言组件调用 ===== */
window.__hasBlocked = (function(){
  var WORDS = ['色情','淫秽','裸聊','约炮','嫖娼','卖淫','援交','一夜情','三级片','杀人','砍人','爆炸','炸弹','枪杀','恐怖袭击','血腥','分尸','傻逼','傻b','傻比','蠢货','废物','混蛋','王八蛋','贱人','贱货','去死','妈的','他妈的','操你','滚蛋','智障','脑残','fuck','bitch','shit','asshole','bastard','damn','idiot','广告','加微信','加vx','加qq','微信二维码','扫码','代购','微商','刷单','营销','招商','加盟','批发','低价出售','投资理财','博彩','办证','代开发票'];
  return function(text){
    var t = String(text == null ? '' : text).toLowerCase();
    for (var i = 0; i < WORDS.length; i++) {
      if (t.indexOf(WORDS[i]) !== -1) return true;
    }
    return false;
  };
})();

/* ===== 8. 通用留言组件：自动初始化所有带 data-gb-page 的 .gb-section（讲道文字稿页使用） ===== */
(function(){
  var secs = document.querySelectorAll('.gb-section[data-gb-page]');
  if (!secs.length) return;
  function dict(){ return (window.I18N && window.__lang && window.I18N[window.__lang.get()]) || {}; }
  function showMsg(msgEl, text, isErr){
    msgEl.textContent = text;
    msgEl.className = 'gb-msg' + (isErr ? ' err' : '');
    msgEl.style.display = 'block';
  }
  function fmtTime(t){
    var d = new Date(String(t).indexOf('Z') < 0 ? t + 'Z' : t);
    if (isNaN(d)) return String(t);
    function p(n){ return (n < 10 ? '0' : '') + n; }
    return d.getFullYear() + '-' + p(d.getMonth()+1) + '-' + p(d.getDate()) + ' ' + p(d.getHours()) + ':' + p(d.getMinutes());
  }
  function init(sec){
    var page = sec.getAttribute('data-gb-page') || 'sermon';
    var form = sec.querySelector('.gb-form');
    var list = sec.querySelector('.gb-list');
    if (!form || !list) return;
    var nameEl = sec.querySelector('.gb-input');
    var contentEl = sec.querySelector('.gb-textarea');
    var msgEl = sec.querySelector('.gb-msg');
    var submitBtn = sec.querySelector('.gb-submit');
    var state = { items: null, failed: false };
    function render(items){
      list.innerHTML = '';
      if (!items || !items.length) {
        var li = document.createElement('li');
        li.className = 'gb-empty';
        li.textContent = dict()['gb.empty'] || '还没有留言，来做第一个分享的人吧';
        list.appendChild(li);
        return;
      }
      for (var i = 0; i < items.length; i++) {
        var it = items[i];
        var li = document.createElement('li');
        li.className = 'gb-item';
        var top = document.createElement('div');
        top.className = 'gb-top';
        var nm = document.createElement('span');
        nm.className = 'gb-name';
        nm.textContent = it.name;
        var tm = document.createElement('span');
        tm.className = 'gb-time';
        tm.textContent = fmtTime(it.created_at);
        top.appendChild(nm); top.appendChild(tm);
        var ct = document.createElement('div');
        ct.className = 'gb-content';
        ct.textContent = it.content;   /* textContent 渲染，天然防 XSS */
        li.appendChild(top); li.appendChild(ct);
        list.appendChild(li);
      }
    }
    function renderErr(){
      list.innerHTML = '';
      var li = document.createElement('li');
      li.className = 'gb-empty';
      li.textContent = dict()['gb.err.load'] || '留言加载失败，请稍后再试';
      list.appendChild(li);
    }
    function load(){
      state.failed = false;
      fetch('/api/comments?page=' + encodeURIComponent(page), { cache: 'no-store' })
        .then(function(r){ if (!r.ok) throw new Error('http'); return r.json(); })
        .then(function(d){
          if (!d.ok) throw new Error('api');
          state.items = d.items || [];
          render(state.items);
        })
        .catch(function(){ state.failed = true; renderErr(); });
    }
    form.addEventListener('submit', function(e){
      e.preventDefault();
      var D = dict();
      var name = nameEl.value.trim();
      var content = contentEl.value.trim();
      if (!name) { showMsg(msgEl, D['gb.err.name'] || '请填写昵称', true); return; }
      if (!content) { showMsg(msgEl, D['gb.err.content'] || '请填写留言内容', true); return; }
      if (window.__hasBlocked && (window.__hasBlocked(name) || window.__hasBlocked(content))) {
        showMsg(msgEl, D['gb.err.blocked'] || '留言包含不当内容，请修改后重试', true);
        return;
      }
      showMsg(msgEl, D['gb.sending'] || '发送中…', false);
      submitBtn.disabled = true;
      fetch('/api/comments', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ name: name, content: content, page: page })
      })
        .then(function(r){ return r.json(); })
        .then(function(d){
          if (d.ok) {
            contentEl.value = '';
            showMsg(msgEl, D['gb.ok'] || '留言已发出，感谢你的分享', false);
            load();
          } else if (d.error === 'blocked') {
            showMsg(msgEl, D['gb.err.blocked'] || '留言包含不当内容，请修改后重试', true);
          } else {
            showMsg(msgEl, D['gb.err.send'] || '发送失败，请稍后再试', true);
          }
          submitBtn.disabled = false;
        })
        .catch(function(){
          showMsg(msgEl, D['gb.err.send'] || '发送失败，请稍后再试', true);
          submitBtn.disabled = false;
        });
    });
    (window.__langHooks = window.__langHooks || []).push(function(cur, d){
      if (nameEl) nameEl.placeholder = d['gb.name.placeholder'] || nameEl.placeholder;
      if (contentEl) contentEl.placeholder = d['gb.content.placeholder'] || contentEl.placeholder;
      if (state.failed) renderErr();
      else if (state.items) render(state.items);
    });
    load();
  }
  for (var i = 0; i < secs.length; i++) init(secs[i]);
})();

/* 吸顶高度自适应：语言切换导致导航按钮换行为两行时，朗读条/段落导航吸顶跟随导航实际高度 */
(function(){
  function syncStickyTops(){
    var nav = document.querySelector('.site-nav');
    if(!nav) return;
    var h = Math.round(nav.getBoundingClientRect().height);
    document.documentElement.style.setProperty('--nav-h', h + 'px');
  }
  if(document.readyState === 'loading'){
    document.addEventListener('DOMContentLoaded', function(){ setTimeout(syncStickyTops, 60); });
  } else {
    setTimeout(syncStickyTops, 60);
  }
  window.addEventListener('load', syncStickyTops);
  window.addEventListener('resize', syncStickyTops);
  /* 语言切换后按钮文字变化可能导致导航换行，同步刷新吸顶高度 */
  if(window.__langHooks){ window.__langHooks.push(function(){ setTimeout(syncStickyTops, 80); }); }
})();
