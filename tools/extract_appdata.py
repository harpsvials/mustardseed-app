#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
extract_appdata.py — 从静态站（根=zh-CN / en/）提取中英双语结构化内容，生成 appdata/appdata.json。
供 Flutter 原生 App 内置 + GitHub 远程更新使用（改 GitHub → App 打开自动拉取 → 不用重装）。
运行：python3 tools/extract_appdata.py
"""
import re
import json
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# ---------- 工具 ----------

def read(path):
    return open(path, encoding='utf-8').read()


def get_main(s):
    m = re.search(r'<main[^>]*>(.*?)</main>', s, re.S)
    if m:
        return m.group(1)
    # 无 <main> 的页面（如 discussion）：回退到 <body> 内容
    b = re.search(r'<body[^>]*>(.*?)</body>', s, re.S)
    return b.group(1) if b else s


def strip_tags(html):
    html = re.sub(r'<br\s*/?>', '\n', html)
    html = re.sub(r'<[^>]+>', '', html)
    return html.strip()


def inner_of(tag, block):
    """返回 <tag ...>...</tag> 的内部 HTML（首个匹配）。"""
    m = re.search(r'<' + tag + r'\b[^>]*>(.*?)</' + tag + r'>', block, re.S)
    return m.group(1) if m else ''


def attr(block, name, tag='[a-z0-9]+'):
    m = re.search(r'<' + tag + r'\b[^>]*' + name + r'="([^"]*)"', block)
    return m.group(1) if m else ''


def i18n_key(block):
    m = re.search(r'data-i18n(?:-html)?="([^"]+)"', block)
    return m.group(1) if m else ''


def split_verse(html):
    """把 '经文文本<small>出处</small>' 拆成 {text, ref}。"""
    m = re.search(r'^(.*?)<small>(.*?)</small>\s*$', html, re.S)
    if m:
        return strip_tags(m.group(1)), m.group(2).strip()
    return strip_tags(html), ''


def js_i18n(s):
    """解析页面内嵌 window.I18N JSON（兜底补充 DOM 中未渲染的键）。"""
    m = re.search(r'window\.I18N\s*=\s*(\{.*?\})\s*;\s*</script>', s, re.S)
    if not m:
        return {}
    txt = m.group(1)
    try:
        data = json.loads(txt)
        for v in data.values():
            if isinstance(v, dict):
                return v
        return {}
    except Exception:
        out = {}
        for km in re.finditer(r'"([^"\\]+)":\s*"((?:[^"\\]|\\.)*)"', txt):
            out[km.group(1)] = km.group(2)
        return out


def common_js(s, lang):
    """解析 i18n.js 的 window.I18N_COMMON = {'zh-CN':{...}}（单引号 JS）。"""
    m = re.search(r'window\.I18N_COMMON\s*=\s*(\{.*?\});', s, re.S)
    if not m:
        return {}
    body = m.group(1)
    lm = re.search(r"'" + lang + r"'\s*:\s*(\{.*?\})\s*[,}]", body, re.S)
    if not lm:
        return {}
    out = {}
    for km in re.finditer(r"'([^']+)'\s*:\s*'((?:[^'\\]|\\.)*)'", lm.group(1)):
        out[km.group(1)] = km.group(2)
    return out


def walk_keys(main_html, tags=('h1', 'h2', 'h3', 'h4', 'p', 'li', 'span', 'a', 'div')):
    """按 DOM 顺序收集 {key: innerHTML}（针对不嵌套的目标标签）。"""
    out = []
    for t in tags:
        pass
    # 用通用非贪婪匹配，按出现顺序
    pat = re.compile(
        r'<([a-z0-9]+)\b[^>]*data-i18n(?:-html)?="([^"]+)"[^>]*>(.*?)</\1>', re.S)
    for m in pat.finditer(main_html):
        out.append({'key': m.group(2), 'html': m.group(3).strip()})
    return out


def sections(main_html):
    """讲道详情/关于等页面：返回 [{id, html}]，按 DOM 顺序。"""
    out = []
    for m in re.finditer(
            r'<section\b([^>]*)>(.*?)</section>', main_html, re.S):
        attrs, body = m.group(1), m.group(2)
        mid = re.search(r'id="([^"]+)"', attrs)
        out.append({'id': mid.group(1) if mid else '', 'html': body})
    return out


def verse_block(block):
    """blockquote.verse → {label, text}（HTML 文本）。"""
    lab = re.search(r'<div class="verse-label"[^>]*>(.*?)</div>', block, re.S)
    txt = re.search(r'<p class="verse-text"[^>]*>(.*?)</p>', block, re.S)
    return {
        'label': lab.group(1).strip() if lab else '',
        'text': txt.group(1).strip() if txt else '',
    }


def parse_sermon_body(main_html):
    """讲道详情正文 → [{type:chapter, id, title, blocks:[{type:p|verse, ...}]}]"""
    chapters = []
    # 宽容匹配：class="chapter" 与 id 属性顺序不固定
    for m in re.finditer(
            r'<section\b[^>]*class="chapter"[^>]*>(.*?)</section>',
            main_html, re.S):
        open_tag = m.group(0)
        mid = re.search(r'id="([^"]+)"', open_tag)
        body = m.group(1)
        cid = mid.group(1) if mid else ''
        blocks = []
        # 段落
        for pm in re.finditer(
                r'<p class="para"[^>]*data-i18n-html="([^"]+)"[^>]*>(.*?)</p>',
                body, re.S):
            blocks.append({'type': 'p', 'key': pm.group(1),
                           'html': pm.group(2).strip()})
        # 经文
        for vm in re.finditer(r'<blockquote class="verse"[^>]*>(.*?)</blockquote>',
                              body, re.S):
            vb = verse_block(vm.group(1))
            blocks.append({'type': 'verse', 'label': vb['label'],
                           'text': vb['text']})
        # 章节内嵌问题（如 talk 章）
        for qm in re.finditer(r'<p class="question-text"[^>]*>(.*?)</p>',
                              body, re.S):
            blocks.append({'type': 'question',
                           'text': strip_tags(qm.group(1))})
        # 标题
        t = re.search(r'<h2 class="chapter-title"[^>]*data-i18n="([^"]+)"[^>]*>(.*?)</h2>',
                      body, re.S)
        chapters.append({
            'id': cid,
            'titleKey': t.group(1) if t else '',
            'title': t.group(2).strip() if t else '',
            'blocks': blocks,
        })
    # 独立问题块；若无（问题在 talk 章内），回退到含 question-text 的章节
    q = re.search(r'<div class="question"[^>]*>(.*?)</div>', main_html, re.S)
    questions = None
    if q:
        qb = q.group(1)
        def qpart(cls, key=None):
            mm = re.search(r'<' + cls + r'\b[^>]*>(.*?)</' + cls + r'>', qb, re.S)
            return mm.group(1).strip() if mm else ''
        qtexts = re.findall(r'<p class="question-text"[^>]*>(.*?)</p>', qb, re.S)
        questions = {
            'tag': qpart('span'),
            'title': qpart('h2'),
            'text': '\n'.join(strip_tags(x) for x in qtexts) or qpart('p'),
        }
    elif chapters:
        for ch in reversed(chapters):
            qb2 = [b for b in ch['blocks'] if b['type'] == 'question']
            if qb2:
                questions = {
                    'tag': '',
                    'title': '',
                    'text': '\n'.join(b['text'] for b in qb2),
                }
                break
    return chapters, questions


def parse_sermon_list(main_html):
    """讲道列表页 → [{key, slug, no, title, verse, summary, tags:[4]}] 按显示顺序（DOM 直提）。"""
    cards = []
    for m in re.finditer(r'<article class="sermon-card"[^>]*>(.*?)</article>',
                         main_html, re.S):
        body = m.group(1)
        key = ''
        km = re.search(r'data-i18n="(item\.\d+\.no)"', body)
        if km:
            key = km.group(1).split('.')[1]
        slug = ''
        lm = re.search(r'class="sermon-link" href="sermons/([^"]+)"', body)
        if lm:
            slug = lm.group(1)
        no = ''
        nm = re.search(r'class="sermon-no"[^>]*>(.*?)</div>', body, re.S)
        if nm:
            no = strip_tags(nm.group(1))
        title = ''
        tm = re.search(r'class="sermon-title"[^>]*>(.*?)</h2>', body, re.S)
        if tm:
            title = strip_tags(tm.group(1))
        verse = ''
        vm = re.search(r'class="sermon-verse"[^>]*>(.*?)</p>', body, re.S)
        if vm:
            verse = vm.group(1).strip()
        summary = ''
        sm = re.search(r'class="sermon-summary"[^>]*>(.*?)</p>', body, re.S)
        if sm:
            summary = strip_tags(sm.group(1))
        tags = [t.strip() for t in re.findall(
            r'<span class="tag"[^>]*>(.*?)</span>', body, re.S)]
        cards.append({'key': key, 'slug': slug, 'no': no,
                      'title': title, 'verse': verse,
                      'summary': summary, 'tags': tags})
    return cards


def parse_home_cards(main_html):
    """首页 nav-card → [{href, titleKey, summaryKey}] 按 DOM 顺序。"""
    cards = []
    for m in re.finditer(r'<a class="nav-card" href="([^"]+)"[^>]*>(.*?)</a>',
                         main_html, re.S):
        href, body = m.group(1), m.group(2)
        title = re.search(r'class="nav-title" data-i18n="([^"]+)"', body)
        summ = re.search(r'class="nav-summary" data-i18n="([^"]+)"', body)
        no = re.search(r'class="nav-no">([^<]+)<', body)
        cards.append({
            'href': href,
            'no': no.group(1).strip() if no else '',
            'titleKey': title.group(1) if title else '',
            'summaryKey': summ.group(1) if summ else '',
        })
    return cards


def parse_topics(main_html):
    """讨论页 topic-card → [{labelKey, q, promptKey, hints:[...]}]（q 为 DOM 文本）"""
    topics = []
    for m in re.finditer(r'<section class="topic-card[^"]*"[^>]*>(.*?)</section>',
                         main_html, re.S):
        body = m.group(1)
        lab = re.search(r'class="card-label" data-i18n="([^"]+)"', body)
        q = re.search(r'<h2[^>]*>(.*?)</h2>', body, re.S)
        pr = re.search(r'class="prompt" data-i18n="([^"]+)"', body)
        hints = re.findall(r'<li data-i18n="([^"]+)"', body)
        topics.append({
            'labelKey': lab.group(1) if lab else '',
            'q': strip_tags(q.group(1)) if q else '',
            'promptKey': pr.group(1) if pr else '',
            'hintKeys': hints,
        })
    return topics


def parse_testimonies(full_html):
    """见证页：chap-nav 顺序（整页查找）+ p.<id>.N 数字排序。"""
    order = re.findall(r'href="#([^"]+)" data-i18n="(chap\.[^"]+)"', full_html)
    if not order:
        order = [(b, a) for a, b in re.findall(
            r'data-i18n="(chap\.[^"]+)" href="#([^"]+)"', full_html)]
    return order


# ---------- 语言 ----------

def build_lang(lang_dir, is_en):
    """返回该语言下的 {page: {'main_html', 'i18n': {key: value}}}"""
    root = os.path.join(ROOT, lang_dir) if lang_dir else ROOT
    pages = {}
    for name in ['index', 'sermons', 'discussion', 'testimonies',
                 'about', 'privacy', 'guestbook', 'prayer', 'testify']:
        path = os.path.join(root, name + '.html')
        if not os.path.exists(path):
            continue
        s = read(path)
        main_html = get_main(s)
        # i18n: 从 main 内 DOM 顺序收集（key → 内层 HTML）
        entries = walk_keys(main_html)
        i18n = {}
        order = []
        for e in entries:
            if e['key'] not in i18n:
                i18n[e['key']] = e['html']
                order.append(e['key'])
        # 附加 head/尾部（如 q.tag 等在 main 外）→ 从整页再扫一遍
        extra = walk_keys(s)
        for e in extra:
            if e['key'] not in i18n:
                i18n[e['key']] = e['html']
                order.append(e['key'])
        pages[name] = {'main': main_html, 'i18n': i18n, 'order': order}
    # 讲道详情
    pages['sermon-details'] = {}
    det_dir = os.path.join(root, 'sermons') if lang_dir else os.path.join(ROOT, 'sermons')
    for fn in sorted(os.listdir(det_dir)):
        if not fn.endswith('.html'):
            continue
        s = read(os.path.join(det_dir, fn))
        main_html = get_main(s)
        chapters, questions = parse_sermon_body(main_html)
        pages['sermon-details'][fn] = {
            'main': main_html,
            'chapters': chapters,
            'questions': questions,
        }
    return pages


# ---------- 主流程 ----------

def main():
    zh = build_lang('', False)
    en = build_lang('en', True)

    # 1) 公共 UI 键（语言切换/播放器/留言/通知等）——从 guestbook 等页面 head 区抓公共键
    #    简单起见：从 en/index 的 order 里找公共 nav/contact/footer 键
    def pick(pages, page, key, fallback=''):
        v = pages.get(page, {}).get('i18n', {}).get(key, '')
        return v or fallback

    def duet(zhp, enp, *keys):
        def take(p, k):
            return p.get('i18n', {}).get(k, '')
        return {'zh': '\n'.join(take(zhp, k) for k in keys),
                'en': '\n'.join(take(enp, k) for k in keys)}

    appdata = {
        'meta': {
            'version': '0.1.0',
            'langs': ['zh', 'en'],
            'generated': '2026-10-23',
        },
        'ui': {},
        'home': {},
        'nav': {},
        'footer': {},
        'sermons': {},
        'discussion': {},
        'testimonies': {},
        'about': {},
        'privacy': {},
        'guestbook': {},
        'prayer': {},
        'testify': {},
    }

    # --- 首页 ---
    zh_cards = parse_home_cards(zh['index']['main'])
    en_cards = parse_home_cards(en['index']['main'])
    cards = []
    for zc, ec in zip(zh_cards, en_cards):
        cards.append({
            'href': zc['href'],
            'no': zc['no'],
            'titleKey': zc['titleKey'],
            'title': duet(zh['index'], en['index'], zc['titleKey']),
            'summary': duet(zh['index'], en['index'], zc['summaryKey']),
        })
    appdata['home'] = {
        'heroTitle': duet(zh['index'], en['index'], 'hero.title'),
        'heroSub': duet(zh['index'], en['index'], 'hero.sub'),
        'cards': cards,
    }

    # --- 底部导航/UI 公共文案（zh 来自 i18n.js 公共字典，en 来自页面内嵌 I18N） ---
    z_common = common_js(read(os.path.join(ROOT, 'src', 'i18n.js')), 'zh-CN')
    e_common = js_i18n(read(os.path.join(ROOT, 'en', 'index.html')))
    for key in ['nav.home', 'nav.sermons', 'nav.testimonies', 'nav.discussion',
                'nav.guestbook', 'nav.prayer', 'nav.about', 'nav.testify',
                'footer.tag', 'footer.privacy', 'contact.label',
                'lang.label', 'gb.section', 'gb.submit', 'gb.loading',
                'gb.empty', 'gb.count', 'gb.name.label', 'gb.name.placeholder',
                'gb.content.label', 'gb.content.placeholder', 'gb.hint',
                'gb.err.name', 'gb.err.content', 'gb.err.send', 'gb.err.load',
                'gb.err.blocked', 'gb.ok', 'gb.foot', 'ms.play', 'ms.pause',
                'ms.list']:
        appdata['ui'][key] = {
            'zh': z_common.get(key, ''),
            'en': e_common.get(key, ''),
        }
    # nav 短键（供 Flutter Tab 直接引用）：公共字典优先，DOM 文本兜底
    for key in ['nav.home', 'nav.sermons', 'nav.testimonies', 'nav.discussion',
                'nav.guestbook', 'nav.prayer', 'nav.about', 'nav.testify']:
        short = key.split('.')[1]
        appdata['nav'][short] = {
            'zh': z_common.get(key) or zh['index']['i18n'].get(key, ''),
            'en': e_common.get(key) or en['index']['i18n'].get(key, ''),
        }
    appdata['footer'] = {
        'tag': {'zh': z_common.get('footer.tag', ''),
                'en': e_common.get('footer.tag', '')},
        'privacy': {'zh': z_common.get('footer.privacy', ''),
                    'en': e_common.get('footer.privacy', '')},
    }
    # 首页卡片标题：以公共字典为准（网页实际渲染值），页面 DOM 文本为备
    for c in cards:
        dom = c['title']
        tk = c['titleKey']
        c['title'] = {
            'zh': z_common.get(tk) or dom['zh'],
            'en': e_common.get(tk) or dom['en'],
        }
    appdata['home']['cards'] = cards

    # --- 讲道 ---
    zh_list = parse_sermon_list(zh['sermons']['main'])
    en_list = parse_sermon_list(en['sermons']['main'])
    sermons = []
    zdet = zh['sermon-details']
    edet = en['sermon-details']
    for i, (zc, ec) in enumerate(zip(zh_list, en_list), start=1):
        key = zc['key']
        slug = zc['slug']
        title = {'zh': zc['title'], 'en': ec['title']}
        verse = {'zh': zc['verse'], 'en': ec['verse']}
        zt, zref = split_verse(zc['verse'])
        et, eref = split_verse(ec['verse'])
        verseText = {'zh': zt, 'en': et}
        verseRef = zref or eref
        summary = {'zh': zc['summary'], 'en': ec['summary']}
        tags = [{'zh': t, 'en': e} for t, e in zip(zc['tags'], ec['tags'])]
        # 详情正文：按章节 id 对齐，缺英文时留空
        zch = zdet.get(slug, {}).get('chapters', [])
        ech = edet.get(slug, {}).get('chapters', [])
        en_by_id = {c['id']: c for c in ech}
        body = []
        for zc_h in zch:
            ec_h = en_by_id.get(zc_h['id'])
            blocks = []
            for zb in zc_h['blocks']:
                eb = None
                if ec_h:
                    for cand in ec_h['blocks']:
                        if cand['type'] == zb['type']:
                            eb = cand
                            ec_h['blocks'].remove(cand)
                            break
                if zb['type'] == 'p':
                    blocks.append({'type': 'p',
                                   'zh': strip_tags(zb['html']),
                                   'en': strip_tags(eb['html']) if eb else ''})
                elif zb['type'] == 'question':
                    blocks.append({'type': 'question',
                                   'zh': strip_tags(zb['text']),
                                   'en': strip_tags(eb['text']) if eb else ''})
                else:
                    blocks.append({'type': 'verse',
                                   'zh': {'label': strip_tags(zb['label']),
                                          'text': strip_tags(zb['text'])},
                                   'en': {'label': strip_tags(eb['label']) if eb else '',
                                          'text': strip_tags(eb['text']) if eb else ''}})
            body.append({
                'id': zc_h['id'],
                'title': {'zh': strip_tags(zc_h['title']),
                          'en': strip_tags(ec_h['title']) if ec_h else ''},
                'blocks': blocks,
            })
        zq = zdet.get(slug, {}).get('questions')
        eq = edet.get(slug, {}).get('questions')
        if zq and eq:
            questions = {
                'tag': {'zh': zq['tag'], 'en': eq['tag']},
                'title': {'zh': zq['title'], 'en': eq['title']},
                'text': {'zh': zq['text'], 'en': eq['text']},
            }
        sermons.append({
            'id': key,
            'no': i,
            'slug': slug,
            'title': title,
            'verse': verse,
            'verseText': verseText,
            'verseRef': verseRef,
            'summary': summary,
            'tags': tags,
            'body': body,
            'questions': questions,
        })
    appdata['sermons'] = {
        'heroTitle': duet(zh['sermons'], en['sermons'], 'hero.title'),
        'heroSub': duet(zh['sermons'], en['sermons'], 'hero.sub'),
        'list': sermons,
    }

    # --- 讨论 ---
    ztopics = parse_topics(zh['discussion']['main'])
    etopics = parse_topics(en['discussion']['main'])
    topics = []
    for zt, et in zip(ztopics, etopics):
        topics.append({
            'label': duet(zh['discussion'], en['discussion'], zt['labelKey']),
            'q': {'zh': zt['q'], 'en': et['q']},
            'prompt': duet(zh['discussion'], en['discussion'], zt['promptKey']),
            'hints': [duet(zh['discussion'], en['discussion'], h)
                      for h in zt['hintKeys']],
        })
    appdata['discussion'] = {
        'heroTitle': duet(zh['discussion'], en['discussion'], 'hero.title'),
        'heroSub': duet(zh['discussion'], en['discussion'], 'hero.sub'),
        'topics': topics,
    }

    # --- 见证 ---
    zorder = parse_testimonies(read(os.path.join(ROOT, 'testimonies.html')))
    eorder = parse_testimonies(read(os.path.join(ROOT, 'en', 'testimonies.html')))
    periods = []
    for (zid, zkey), (eid, ekey) in zip(zorder, eorder):
        zhp = zh['testimonies']['i18n']
        enp = en['testimonies']['i18n']
        period = {'id': zid,
                  'period': {'zh': zhp.get(f'tl.{zid}.period', ''),
                             'en': enp.get(f'tl.{zid}.period', '')},
                  'sub': {'zh': zhp.get(f'tl.{zid}.sub', ''),
                          'en': enp.get(f'tl.{zid}.sub', '')},
                  'paras': []}
        # 段落：p.<id>.N 按 N 排序
        zparas = sorted(
            [(k, v) for k, v in zhp.items() if k.startswith(f'p.{zid}.')],
            key=lambda kv: int(kv[0].rsplit('.', 1)[1]))
        for zk, zv in zparas:
            n = zk.rsplit('.', 1)[1]
            ev = enp.get(f'p.{zid}.{n}', '')
            period['paras'].append({'zh': zv, 'en': ev})
        periods.append(period)
    appdata['testimonies'] = {
        'heroTitle': duet(zh['testimonies'], en['testimonies'], 'hero.title'),
        'heroSub': duet(zh['testimonies'], en['testimonies'], 'hero.sub'),
        'periods': periods,
    }

    # --- 关于 / 隐私 / 见证留言引导 ---
    def page_sections(zhp, enp, page):
        zsecs = sections(zhp[page]['main'])
        esecs = sections(enp[page]['main'])
        out = []
        for zs, es in zip(zsecs, esecs):
            zkeys = walk_keys(zs['html'])
            ekeys = walk_keys(es['html'])
            block = {'id': zs['id'], 'blocks': []}
            for zk, ek in zip(zkeys, ekeys):
                block['blocks'].append({
                    'key': zk['key'],
                    'zh': strip_tags(zk['html']),
                    'en': strip_tags(ek['html']),
                })
            out.append(block)
        return out

    appdata['about'] = {
        'heroTitle': duet(zh['about'], en['about'], 'hero.title'),
        'heroSub': duet(zh['about'], en['about'], 'hero.sub'),
        'sections': page_sections(zh, en, 'about'),
    }
    appdata['privacy'] = {
        'heroTitle': duet(zh['privacy'], en['privacy'], 'hero.title'),
        'heroSub': duet(zh['privacy'], en['privacy'], 'hero.sub'),
        'sections': page_sections(zh, en, 'privacy'),
    }
    appdata['guestbook'] = {
        'heroTitle': duet(zh['guestbook'], en['guestbook'], 'hero.title'),
        'heroSub': duet(zh['guestbook'], en['guestbook'], 'hero.sub'),
    }
    appdata['prayer'] = {
        'heroTitle': duet(zh['prayer'], en['prayer'], 'hero.title'),
        'heroSub': duet(zh['prayer'], en['prayer'], 'hero.sub'),
    }
    appdata['testify'] = {
        'heroTitle': duet(zh['testify'], en['testify'], 'hero.title'),
        'heroSub': duet(zh['testify'], en['testify'], 'hero.sub'),
        'text': duet(zh['testify'], en['testify'], 'p.lead', 'p.lead2'),
    }

    out = os.path.join(ROOT, 'appdata', 'appdata.json')
    with open(out, 'w', encoding='utf-8') as f:
        json.dump(appdata, f, ensure_ascii=False, indent=1)
    print('生成', out)
    print('sermons:', len(appdata['sermons']['list']))
    print('topics:', len(appdata['discussion']['topics']))
    print('periods:', len(appdata['testimonies']['periods']))
    print('about sections:', len(appdata['about']['sections']))
    print('privacy sections:', len(appdata['privacy']['sections']))

if __name__ == '__main__':
    main()
