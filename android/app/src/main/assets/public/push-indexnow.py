#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""IndexNow 推送脚本 — 将 sitemap.xml 中的全部 URL 推送给 Bing / Yandex / Naver 等搜索引擎。

用法：
  1. 确保 indexnow-<密钥>.txt 已上传并部署（能通过 https://www.zhuzhouchurch.com/<密钥>.txt 访问）
  2. 在本目录运行：python3 push-indexnow.py
"""
import json, re, sys, urllib.request, urllib.error

HOST = "www.zhuzhouchurch.com"
KEY = "d83978dedbee48f1955a956f0dc3a604"          # 与 indexnow-<KEY>.txt 一致
KEYLOC = "https://%s/%s.txt" % (HOST, KEY)
SITEMAP = "sitemap.xml"

def main():
    try:
        sm = open(SITEMAP, encoding="utf-8").read()
    except FileNotFoundError:
        sys.exit("找不到 sitemap.xml，请在项目根目录运行本脚本")
    urls = re.findall(r"<loc>([^<]+)</loc>", sm)
    if not urls:
        sys.exit("sitemap.xml 中没有解析到 URL")
    print("从 sitemap.xml 读取到 %d 个 URL" % len(urls))

    payload = json.dumps({
        "host": HOST,
        "key": KEY,
        "keyLocation": KEYLOC,
        "urlList": urls,
    }).encode("utf-8")

    req = urllib.request.Request(
        "https://api.indexnow.org/indexnow",
        data=payload,
        headers={"Content-Type": "application/json; charset=utf-8"},
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=60) as resp:
            print("推送成功（HTTP %d），%d 个 URL 已通知搜索引擎" % (resp.status, len(urls)))
    except urllib.error.HTTPError as e:
        print("推送失败（HTTP %d）：" % e.code)
        print(e.read().decode("utf-8", "ignore")[:800])
        print("常见原因：密钥文件尚未部署，或 keyLocation 无法访问。")
    except Exception as e:
        print("推送出错：", e)

if __name__ == "__main__":
    main()
