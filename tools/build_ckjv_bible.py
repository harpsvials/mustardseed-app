# -*- coding: utf-8 -*-
"""把《中文英王钦定本》(ckjv.asia, CC BY-SA 3.0) 的 ckjv.js 转成本站用的分卷 JSON。

用法：python3 tools/build_ckjv_bible.py /tmp/ckjv.js
产物：
  bible/ckjv/index.json        书卷全名 → {n, file}
  bible/ckjv/<n>.json          逐章逐节的经文
"""
import json
import os
import re
import sys

BOOKS = [
    '创世记', '出埃及记', '利未记', '民数记', '申命记', '约书亚记', '士师记', '路得记',
    '撒母耳记上', '撒母耳记下', '列王纪上', '列王纪下', '历代志上', '历代志下',
    '以斯拉记', '尼希米记', '以斯帖记', '约伯记', '诗篇', '箴言', '传道书', '雅歌',
    '以赛亚书', '耶利米书', '耶利米哀歌', '以西结书', '但以理书', '何西阿书', '约珥书',
    '阿摩司书', '俄巴底亚书', '约拿书', '弥迦书', '那鸿书', '哈巴谷书', '西番雅书',
    '哈该书', '撒迦利亚书', '玛拉基书', '马太福音', '马可福音', '路加福音', '约翰福音',
    '使徒行传', '罗马书', '哥林多前书', '哥林多后书', '加拉太书', '以弗所书', '腓立比书',
    '歌罗西书', '帖撒罗尼迦前书', '帖撒罗尼迦后书', '提摩太前书', '提摩太后书', '提多书',
    '腓利门书', '希伯来书', '雅各书', '彼得前书', '彼得后书', '约翰一书', '约翰二书',
    '约翰三书', '犹大书', '启示录',
]

# 页面上可能出现的简称/别名
ALIAS = {
    '林前': '哥林多前书', '林后': '哥林多后书', '林後': '哥林多后书',
    '帖前': '帖撒罗尼迦前书', '帖后': '帖撒罗尼迦后书', '帖後': '帖撒罗尼迦后书',
    '提前': '提摩太前书', '提后': '提摩太后书', '提後': '提摩太后书',
    '彼前': '彼得前书', '彼后': '彼得后书', '彼後': '彼得后书',
    '约一': '约翰一书', '约二': '约翰二书', '约三': '约翰三书',
    '撒上': '撒母耳记上', '撒下': '撒母耳记下', '王上': '列王纪上', '王下': '列王纪下',
    '代上': '历代志上', '代下': '历代志下', '诗': '诗篇', '箴': '箴言', '传': '传道书',
    '赛': '以赛亚书', '耶': '耶利米书', '哀': '耶利米哀歌', '结': '以西结书',
    '但': '但以理书', '何': '何西阿书', '珥': '约珥书', '摩': '阿摩司书',
    '俄': '俄巴底亚书', '拿': '约拿书', '弥': '弥迦书', '鸿': '那鸿书',
    '哈': '哈巴谷书', '番': '西番雅书', '该': '哈该书', '亚': '撒迦利亚书',
    '玛': '玛拉基书', '太': '马太福音', '可': '马可福音', '路': '路加福音',
    '约': '约翰福音', '徒': '使徒行传', '罗': '罗马书', '加': '加拉太书',
    '弗': '以弗所书', '腓': '腓立比书', '西': '歌罗西书', '多': '提多书',
    '门': '腓利门书', '来': '希伯来书', '雅': '雅各书', '犹': '犹大书', '启': '启示录',
    '创': '创世记', '出': '出埃及记', '利': '利未记', '民': '民数记', '申': '申命记',
    '书': '约书亚记', '士': '士师记', '得': '路得记', '拉': '以斯拉记',
    '尼': '尼希米记', '斯': '以斯帖记', '伯': '约伯记',
}

ABBR = ['创', '出', '利', '民', '申', '书', '士', '得', '撒上', '撒下', '王上', '王下',
        '代上', '代下', '拉', '尼', '斯', '伯', '诗', '箴', '传', '歌', '赛', '耶',
        '哀', '结', '但', '何', '珥', '摩', '俄', '拿', '弥', '鸿', '哈', '番', '该',
        '亚', '玛', '太', '可', '路', '约', '徒', '罗', '林前', '林後', '加', '弗',
        '腓', '西', '帖前', '帖後', '提前', '提後', '多', '门', '来', '雅', '彼前',
        '彼後', '约一', '约二', '约三', '犹', '启']


def clean(text):
    """去掉译者标注：<HY>原文（English）</HY> 保留中文、舍掉括注英文。"""
    text = re.sub(r'<HY>(.*?)</HY>', lambda m: re.sub(r'（[^）]*）', '', m.group(1)), text)
    text = re.sub(r'<[^>]+>', '', text)
    return re.sub(r'\s+', ' ', text).strip()


def main(src_path):
    raw = open(src_path, encoding='utf-8-sig').read()
    items = re.findall(r'"([^"]*)"', raw)
    pat = re.compile(r'^([^\d:]+)(\d+):(\d+)\s+(.*)$')

    books = {}
    for it in items:
        m = pat.match(it)
        if not m:
            continue
        books.setdefault(m.group(1), {}).setdefault(int(m.group(2)), {})[int(m.group(3))] = clean(m.group(4))

    out_dir = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), 'bible', 'ckjv')
    os.makedirs(out_dir, exist_ok=True)

    index = {'version': '中文英王钦定本', 'source': 'https://www.ckjv.asia', 'license': 'CC BY-SA 3.0', 'books': {}}
    total = 0
    for i, abbr in enumerate(ABBR, start=1):
        name = BOOKS[i - 1]
        chapters = books.get(abbr)
        if not chapters:
            print('缺少书卷:', abbr, name)
            continue
        data = {str(c): {str(v): t for v, t in sorted(ch.items())} for c, ch in sorted(chapters.items())}
        path = os.path.join(out_dir, '%02d.json' % i)
        with open(path, 'w', encoding='utf-8') as f:
            json.dump(data, f, ensure_ascii=False, separators=(',', ':'))
        index['books'][name] = {'n': i, 'file': '%02d.json' % i, 'chapters': len(data),
                                'verses': sum(len(ch) for ch in data.values())}
        total += index['books'][name]['verses']

    index['books'].update({k: index['books'][v] for k, v in ALIAS.items() if v in index['books']})
    with open(os.path.join(out_dir, 'index.json'), 'w', encoding='utf-8') as f:
        json.dump(index, f, ensure_ascii=False, indent=1, separators=(',', ': '))

    size = sum(os.path.getsize(os.path.join(out_dir, f)) for f in os.listdir(out_dir))
    print('书卷:', len(BOOKS), '节数:', total, '总体积:', round(size / 1024 / 1024, 2), 'MB')


if __name__ == '__main__':
    main(sys.argv[1] if len(sys.argv) > 1 else '/tmp/ckjv.js')
