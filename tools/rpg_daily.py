#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""RPG 每日經文：只抓当天卡片图片，保留最近 7 天。

来源：https://www.rpg-move.tw/category/rpg-daily/
- 分类页列出最新 6 篇，每篇形如 /daily1108/
- 单篇页里有 日期・2026-11-08 与图片 wp-content/uploads/daily_1108-2.jpg
- 正文只在图片里，不 OCR，只存图 + 日期 + 原页链接

输出：
- images/rpg/daily_YYYYMMDD.jpg   最近 7 天的卡片
- rpg-data.json                   清单（供网页与 App 读取）
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


def iso_date(y, m, d):
    return date(y, m, d).isoformat()


def parse_post(url, html):
    """返回 {date, image, sourceUrl, title} 或 None。"""
    text = re.sub(r'<[^>]+>', ' ', html)
    m = re.search(r'日期\s*[・·:：]?\s*(\d{4})-(\d{2})-(\d{2})', text)
    if not m:
        return None
    d = iso_date(int(m.group(1)), int(m.group(2)), int(m.group(3)))

    imgs = re.findall(r'src="([^"]*?/uploads/daily_[^"]*?\.jpg)"', html)
    if not imgs:
        imgs = re.findall(r'url\(([^)]*?/uploads/daily_[^)]*?\.jpg)\)', html)
    if not imgs:
        return None
    # 优先不成 -1 缩略图后缀的原图（-2 或直接 daily_MMDD.jpg）
    full = [u for u in imgs if '-1' not in os.path.basename(u)] or imgs
    image_url = full[0]

    title = ''
    mt = re.search(r'<title>(.*?)</title>', html, re.S)
    if mt:
        title = re.split(r'[|｜]', re.sub(r'\s+', ' ', mt.group(1)).strip())[0].strip()
    if not title:
        mt = re.search(r'每日經文\s*\d{4}', text)
        title = mt.group(0) if mt else ''

    return {'date': d, 'imageUrl': image_url, 'sourceUrl': url,
            'title': to_simplified(title)}


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
    if os.path.exists(DATA_PATH):
        try:
            with open(DATA_PATH, encoding='utf-8') as f:
                for it in json.load(f).get('items', []):
                    if it.get('date'):
                        old[it['date']] = it
        except Exception:
            old = {}

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
        d = date.fromisoformat(parsed['date'])
        if d > today_tpe or d < earliest:
            continue

        name = 'daily_%s.jpg' % d.strftime('%Y%m%d')
        path = os.path.join(IMG_DIR, name)
        if not os.path.exists(path) or os.path.getsize(path) < 20000:
            raw = fetch(parsed['imageUrl'], binary=True)
            if not raw or len(raw) < 20000:
                print('图片下载失败:', parsed['imageUrl'], file=sys.stderr)
                continue
            with open(path, 'wb') as f:
                f.write(raw)

        items[parsed['date']] = {
            'date': parsed['date'],
            'dateLabel': '%d年%d月%d日' % (d.year, d.month, d.day),
            'weekday': WEEKDAYS[d.weekday()],
            'image': name,
            'imageUrl': PAGES_URL + name,
            'sourceUrl': parsed['sourceUrl'],
            'title': parsed['title'] or '每日经文',
        }

    # 已有的近 7 天条目继续保留（避免某天抓不到时把清单清空）
    for d_str, it in old.items():
        try:
            d = date.fromisoformat(d_str)
        except Exception:
            continue
        if earliest <= d <= today_tpe and d_str not in items:
            if os.path.exists(os.path.join(IMG_DIR, it.get('image', ''))):
                items[d_str] = it

    keep = sorted(items.values(), key=lambda x: x['date'], reverse=True)[:KEEP_DAYS]

    # 清掉不在保留范围内的图片
    names = {it['image'] for it in keep}
    for f in os.listdir(IMG_DIR):
        if f.lower().endswith('.jpg') and f not in names:
            os.remove(os.path.join(IMG_DIR, f))

    # 清单与上次完全一致时，沿用上次的更新时间，避免每趟都产生一次无意义提交
    prev_updated = prev_label = None
    if os.path.exists(DATA_PATH):
        try:
            prev = json.load(open(DATA_PATH, encoding='utf-8'))
            prev_updated, prev_label = prev.get('updated'), prev.get('updatedLabel')
            prev_items = [(i.get('date'), i.get('image')) for i in prev.get('items', [])]
        except Exception:
            prev_items = None
    else:
        prev_items = None
    if prev_items == [(i['date'], i['image']) for i in keep] and prev_updated:
        data = {
            'updated': prev_updated,
            'updatedLabel': prev_label,
            'sourceUrl': CATEGORY_URL,
            'keepDays': KEEP_DAYS,
            'items': keep,
        }
    else:
        now_tpe = datetime.now(timezone.utc) + timedelta(hours=8)
        data = {
            'updated': now_tpe.strftime('%Y-%m-%d %H:%M'),
            'updatedLabel': '%d年%d月%d日 %s' % (now_tpe.year, now_tpe.month,
                                                now_tpe.day, now_tpe.strftime('%H:%M')),
            'sourceUrl': CATEGORY_URL,
            'keepDays': KEEP_DAYS,
            'items': keep,
        }
    with open(DATA_PATH, 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
        f.write('\n')

    print('RPG 每日经文：%d 天，最新 %s' % (
        len(keep), keep[0]['date'] if keep else '无'))
    return 0


if __name__ == '__main__':
    sys.exit(main())
