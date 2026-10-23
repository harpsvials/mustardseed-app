#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""重建 en 详情页《救主耶稣也是主、更是君王！》的 main 章节 DOM。
   en 页面 DOM 结构错乱（章节内容错位/缺 3 章/标签错误），但内嵌 I18N 字典翻译完整。
   以 zh 页面的章节结构为模板，从 en I18N 取译文，重建 6 章 + 思考题块。
   运行：cd <仓库根> && python3 tools/rebuild_sermon10_en.py
"""
import json, os, re, html as ihtml

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ZH = os.path.join(ROOT, 'sermons', '救主耶稣也是主、更是君王！.html')
EN = os.path.join(ROOT, 'en', 'sermons', '救主耶稣也是主、更是君王！.html')


def esc(s):
    return ihtml.escape(s, quote=True)


def parse_zh_structure(main_html):
    """从 zh 页面提取章节结构：id + blocks 键名列表。"""
    chs = []
    for m in re.finditer(r'<section\b[^>]*class="chapter"[^>]*>(.*?)</section>',
                         main_html, re.S):
        body = m.group(1)
        cid = re.search(r'id="([^"]+)"', m.group(0))
        cid = cid.group(1) if cid else ''
        tk = re.search(r'data-i18n="(t\.[^"]+)"', body)
        tk = tk.group(1) if tk else ''
        blocks = []
        # para 键
        for pm in re.finditer(r'<p class="para"[^>]*data-i18n-html="([^"]+)"', body):
            blocks.append(('p', pm.group(1)))
        # verse 键
        for vm in re.finditer(r'<div class="verse-label"[^>]*data-i18n="([^"]+)"', body):
            vk = vm.group(1)
            blocks.append(('v', vk))
        # question-text 键
        for qm in re.finditer(r'<p class="question-text"[^>]*data-i18n="([^"]+)"', body):
            blocks.append(('q', qm.group(1)))
        chs.append({'id': cid, 'titleKey': tk, 'blocks': blocks})
    # 独立 questions 块键
    qk = re.search(r'<div class="question"[^>]*>(.*?)</div>', main_html, re.S)
    qkeys = {'tag': '', 'title': '', 'texts': []}
    if qk:
        qb = qk.group(1)
        t = re.search(r'<span[^>]*data-i18n="([^"]+)"', qb)
        qkeys['tag'] = t.group(1) if t else ''
        t = re.search(r'<h2[^>]*data-i18n="([^"]+)"', qb)
        qkeys['title'] = t.group(1) if t else ''
        qkeys['texts'] = re.findall(r'<p class="question-text"[^>]*data-i18n="([^"]+)"', qb)
    return chs, qkeys


def main():
    zh = open(ZH, encoding='utf-8').read()
    en = open(EN, encoding='utf-8').read()

    zmain = re.search(r'<main[^>]*>(.*?)</main>', zh, re.S).group(1)
    chs, qkeys = parse_zh_structure(zmain)

    m = re.search(r'window\.I18N\s*=\s*(\{.*?\})\s*;\s*</script>', en, re.S)
    i18n = json.loads(m.group(1))
    d = i18n.get('en', i18n)

    def val(k):
        return d.get(k, '')

    # 重建章节
    parts = []
    for ch in chs:
        parts.append('      <!-- ===== %s ===== -->' % ch['id'])
        parts.append('      <section class="chapter" id="%s">' % ch['id'])
        if ch['titleKey']:
            parts.append('        <h2 class="chapter-title" data-i18n="%s">%s</h2>'
                         % (ch['titleKey'], esc(val(ch['titleKey']))))
        for bt, key in ch['blocks']:
            if bt == 'p':
                parts.append('        <p class="para" data-i18n-html="%s">%s</p>'
                             % (key, val(key)))
            elif bt == 'v':
                vkey = key.replace('.label', '')
                parts.append('        <blockquote class="verse">')
                parts.append('          <div class="verse-label" data-i18n="%s.label">%s</div>'
                             % (vkey, esc(val(vkey + '.label'))))
                parts.append('          <p class="verse-text" data-i18n="%s.text">%s</p>'
                             % (vkey, val(vkey + '.text')))
                parts.append('        </blockquote>')
            elif bt == 'q':
                parts.append('        <p class="question-text" data-i18n="%s">%s</p>'
                             % (key, esc(val(key))))
        # 章节内嵌独立思考题块（zh 的 question 章内 <div class="question" id="q">）
        zb = re.search(r'<section[^>]*id="%s"[^>]*>(.*?)</section>' % ch['id'],
                       zmain, re.S)
        qdiv = re.search(r'<div class="question"[^>]*>(.*?)</div>',
                         zb.group(1), re.S) if zb else None
        if qdiv:
            qb = qdiv.group(1)
            qt = re.search(r'<span[^>]*data-i18n="([^"]+)"', qb)
            qh = re.search(r'<h2[^>]*data-i18n="([^"]+)"', qb)
            qp = re.search(r'<p class="question-text"[^>]*data-i18n-html="([^"]+)"', qb)
            parts.append('        <div class="question" id="q">')
            if qt:
                parts.append('          <span class="question-tag" data-i18n="%s">%s</span>'
                             % (qt.group(1), esc(val(qt.group(1)))))
            if qh:
                parts.append('          <h2 data-i18n="%s">%s</h2>'
                             % (qh.group(1), esc(val(qh.group(1)))))
            if qp:
                parts.append('          <p class="question-text" data-i18n-html="%s">%s</p>'
                             % (qp.group(1), val(qp.group(1))))
            parts.append('        </div>')
        parts.append('      </section>')
    new_chapters = '\n'.join(parts)

    # 章节内嵌思考题块已在章节内重建，无需 main 级块

    # 替换 en main
    emain_old = re.search(r'<main[^>]*>(.*?)</main>', en, re.S).group(1)
    # main 前缀（到第一个 chapter 前）
    start = re.search(r'<section\b[^>]*class="chapter"', emain_old)
    prefix_end = start.start() if start else len(emain_old)
    # main 后缀（最后一个章节 </section> 之后）
    last = list(re.finditer(r'</section>', emain_old))[-1]
    suffix = emain_old[last.end():]
    new_main = emain_old[:prefix_end] + new_chapters + suffix

    en2 = en.replace(emain_old, new_main)
    open(EN, 'w', encoding='utf-8').write(en2)
    print('章节:', [ch['id'] for ch in chs])
    print('questions 块键:', qkeys)
    print('重建完成，写回', EN)


if __name__ == '__main__':
    main()
