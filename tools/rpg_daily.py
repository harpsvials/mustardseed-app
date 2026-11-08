#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""RPG 每日經文：每天两张卡片图（经文卡 + 祷告卡），保留最近 7 天。

来源：https://www.rpg-move.tw/category/rpg-daily/
- 分类页列出最新几篇，每篇形如 /daily1108/
- 单篇页里有「日期・2026-11-08」
- 正文是两张图：
    daily_MMDD-1.jpg  经文卡（主视觉 / og:image，卡面是圣经节选 + 出处）
    daily_MMDD-2.jpg  告白卡（正文那张，默想 + 祷告）
- 不 OCR，只存图 + 日期 + 原页链接

输出：
- images/rpg/daily_YYYYMMDD-1.jpg / -2.jpg
- rpg-data.json
"""

import json
import os
import re
import subprocess
import sys
from datetime import date, datetime, timedelta, timezone

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
DATA_PATH = os.path.join(ROOT, 'rpg-data.json')
IMG_DIR = os.path.join(ROOT, 'images', 'rpg')
CATEGORY_URL = 'https://www.rpg-move.tw/category/rpg-daily/'
UA = ('Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) '
      'AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0 Safari/537.36')
KEEP_DAYS = 7
PAGES_URL = 'https://harpsvials.github.io/mustardseed-app/images/rpg/'
WEEKDAYS = ['星期一', '星期二', '星期三', '星期四', '星期五', '星期六', '星期日']


def fetch(url, binary=False):
    """优先系统 curl（可控 UA、超时），失败回退 urllib。"""
    try:
        cmd = ['curl', '-sSL', '--fail', '--max-time', '40', '-A', UA, url]
        out = subprocess.run(cmd, capture_output=True, timeout=60)
        if out.returncode == 0 and out.stdout:
            return out.stdout if binary else out.stdout.decode('utf-8', 'replace')
    except Exception:
        pass
    try:
        import urllib.request
        req = urllib.request.Request(url, headers={'User-Agent': UA})
        with urllib.request.urlopen(req, timeout=40) as r:
            raw = r.read()
            return raw if binary else raw.decode('utf-8', 'replace')
    except Exception as e:
        print('fetch failed:', url, e, file=sys.stderr)
        return None


def to_simplified(text):
    try:
        from opencc import OpenCC
        return OpenCC('t2s').convert(text)
    except Exception:
        return text


def download(url, path, min_bytes=15000):
    """下载到 path；已存在且大小正常则跳过。成功返回 True。"""
    if os.path.exists(path) and os.path.getsize(path) >= min_bytes:
        return True
    raw = fetch(url, binary=True)
    if not raw or len(raw) < min_bytes:
        return False
    with open(path, 'wb') as f:
        f.write(raw)
    return True


def parse_post(url, html):
    """返回 {date, verseCands, prayerUrl, sourceUrl, title} 或 None。"""
    text = re.sub(r'<[^>]+>', ' ', html)
    m = re.search(r'日期\s*[・·:：]?\s*(\d{4})-(\d{2})-(\d{2})', text)
    if not m:
        return None
    d = date(int(m.group(1)), int(m.group(2)), int(m.group(3)))
    mmdd = d.strftime('%m%d')
    up = 'https://www.rpg-move.tw/wp-content/uploads/'

    # 经文卡：页面里给的可能是带 -e<时间戳> 的编辑版，先试原图 daily_MMDD-1.jpg
    verse_cands = [up + 'daily_%s-1.jpg' % mmdd]
    pat = r'https://www\.rpg-move\.tw/wp-content/uploads/daily_%s-1(?:-[^"\') ]*)?\.jpg' % mmdd
    for c in re.findall(pat, html):
        if c not in verse_cands:
            verse_cands.append(c)

    # 祷告卡：正文那张 -2，排除 -768x523 之类缩放版
    prayer = None
    pat = r'https://www\.rpg-move\.tw/wp-content/uploads/daily_%s-2(?:-[^"\') ]*)?\.jpg' % mmdd
    for c in re.findall(pat, html):
        if re.search(r'-\d+x\d+\.jpg$', c):
            continue
        prayer = c
        break
    if not prayer:
        return None

    title = ''
    mt = re.search(r'<title>(.*?)</title>', html, re.S)
    if mt:
        title = re.split(r'[|｜]', re.sub(r'\s+', ' ', mt.group(1)).strip())[0].strip()

    return {'date': d, 'verseCands': verse_cands, 'prayerUrl': prayer,
            'sourceUrl': url, 'title': to_simplified(title) or '每日經文'}


def main():
    cat = fetch(CATEGORY_URL)
    if not cat:
        print('分类页抓取失败', file=sys.stderr)
        return 1

    links = []
    for href in re.findall(r'href="(https?://www\.rpg-move\.tw/daily\d+/)"', cat):
        if href not in links:
            links.append(href)
    if not links:
        print('分类页里没有找到当日文章链接', file=sys.stderr)
        return 1

    os.makedirs(IMG_DIR, exist_ok=True)

    old = {}
    prev_updated = prev_label = None
    prev_items = None
    if os.path.exists(DATA_PATH):
        try:
            with open(DATA_PATH, encoding='utf-8') as f:
                prev = json.load(f)
            prev_updated, prev_label = prev.get('updated'), prev.get('updatedLabel')
            prev_items = [(i.get('date'), i.get('verseImage'), i.get('prayerImage'))
                          for i in prev.get('items', [])]
            for it in prev.get('items', []):
                if it.get('date'):
                    old[it['date']] = it
        except Exception:
            prev_items = None

    today_tpe = (datetime.now(timezone.utc) + timedelta(hours=8)).date()
    earliest = today_tpe - timedelta(days=KEEP_DAYS)
    items = {}

    for url in links[:8]:
        html = fetch(url)
        if not html:
            continue
        parsed = parse_post(url, html)
        if not parsed:
            continue
        d = parsed['date']
        if d > today_tpe or d < earliest:
            continue

        base = 'daily_%s' % d.strftime('%Y%m%d')
        verse_name, prayer_name = base + '-1.jpg', base + '-2.jpg'
        verse_path = os.path.join(IMG_DIR, verse_name)
        prayer_path = os.path.join(IMG_DIR, prayer_name)

        verse_ok = False
        for u in parsed['verseCands']:
            if download(u, verse_path):
                verse_ok = True
                break
        if not verse_ok:
            print('经文卡下载失败:', parsed['verseCands'][0], file=sys.stderr)
        prayer_ok = download(parsed['prayerUrl'], prayer_path)
        if not prayer_ok:
            print('祷告卡下载失败:', parsed['prayerUrl'], file=sys.stderr)
        if not verse_ok and not prayer_ok:
            continue

        items[d.isoformat()] = {
            'date': d.isoformat(),
            'dateLabel': '%d年%d月%d日' % (d.year, d.month, d.day),
            'weekday': WEEKDAYS[d.weekday()],
            'verseImage': verse_name if verse_ok else '',
            'verseImageUrl': (PAGES_URL + verse_name) if verse_ok else '',
            'prayerImage': prayer_name if prayer_ok else '',
            'prayerImageUrl': (PAGES_URL + prayer_name) if prayer_ok else '',
            'sourceUrl': parsed['sourceUrl'],
            'title': parsed['title'],
        }

    # 已有的近 7 天条目继续保留（避免某天抓不到时把清单清空）
    for d_str, it in old.items():
        try:
            d = date.fromisoformat(d_str)
        except Exception:
            continue
        if not (earliest <= d <= today_tpe) or d_str in items:
            continue
        files = [it.get('verseImage'), it.get('prayerImage'), it.get('image')]
        if not any(f and os.path.exists(os.path.join(IMG_DIR, f)) for f in files):
            continue
        verse = it.get('verseImage') or ''
        prayer = it.get('prayerImage') or it.get('image') or ''
        items[d_str] = {
            'date': d_str,
            'dateLabel': it.get('dateLabel', ''),
            'weekday': it.get('weekday', ''),
            'verseImage': verse,
            'verseImageUrl': it.get('verseImageUrl') or ((PAGES_URL + verse) if verse else ''),
            'prayerImage': prayer,
            'prayerImageUrl': it.get('prayerImageUrl') or it.get('imageUrl') or ((PAGES_URL + prayer) if prayer else ''),
            'sourceUrl': it.get('sourceUrl', ''),
            'title': it.get('title', '每日經文'),
        }

    keep = sorted(items.values(), key=lambda x: x['date'], reverse=True)[:KEEP_DAYS]

    # 清掉不在保留范围内的图片
    names = set()
    for it in keep:
        for key in ('verseImage', 'prayerImage'):
            if it.get(key):
                names.add(it[key])
    for f in os.listdir(IMG_DIR):
        if f.lower().endswith('.jpg') and f not in names:
            os.remove(os.path.join(IMG_DIR, f))

    signature = [(i['date'], i.get('verseImage'), i.get('prayerImage')) for i in keep]
    if prev_items == signature and prev_updated:
        # 清单没变就沿用上次更新时间，避免每趟都产生一次无意义提交
        updated, updated_label = prev_updated, prev_label
    else:
        now_tpe = datetime.now(timezone.utc) + timedelta(hours=8)
        updated = now_tpe.strftime('%Y-%m-%d %H:%M')
        updated_label = '%d年%d月%d日 %s' % (now_tpe.year, now_tpe.month,
                                            now_tpe.day, now_tpe.strftime('%H:%M'))

    data = {
        'updated': updated,
        'updatedLabel': updated_label,
        'sourceUrl': CATEGORY_URL,
        'keepDays': KEEP_DAYS,
        'items': keep,
    }
    with open(DATA_PATH, 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
        f.write('\n')

    print('RPG 每日经文：%d 天，最新 %s，经文卡 %d 张' % (
        len(keep), keep[0]['date'] if keep else '无',
        sum(1 for i in keep if i.get('verseImage'))))
    return 0


if __name__ == '__main__':
    sys.exit(main())
