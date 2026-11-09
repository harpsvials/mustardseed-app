#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""抓取推喇奴书房《活泼的生命》当日页，抽取「今天的主题」与「经文范围」，
转简体后写入仓库根目录 qt-data.json。

只取这两项字段，不搬运诗歌、摘要与经文全文；页面另标来源并回链原页。
解析失败时以非零退出码结束，由 GitHub Actions 报警，并保留上一份数据。
"""

import sys
import re
import json
import html
import datetime
import urllib.request
from pathlib import Path

SOURCE_URL = "https://www.duranno.tw/livinglife/index.php/daily"
ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "qt-data.json"

UA = (
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
    "AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0 Safari/537.36"
)

WEEKDAYS = ["星期一", "星期二", "星期三", "星期四", "星期五", "星期六", "星期日"]


def fetch() -> str:
    """优先用 curl（某些环境的 python 证书链缺少 SKI，会验不过对方证书）。"""
    import shutil
    import subprocess

    if shutil.which("curl"):
        out = subprocess.run(
            ["curl", "-sSL", "--fail", "--max-time", "40", "-A", UA, SOURCE_URL],
            capture_output=True,
            check=False,
        )
        if out.returncode == 0 and out.stdout:
            return out.stdout.decode("utf-8", errors="replace")
        raise RuntimeError(f"curl 抓取失败，返回码 {out.returncode}")

    req = urllib.request.Request(SOURCE_URL, headers={"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=30) as resp:
        raw = resp.read()
    return raw.decode("utf-8", errors="replace")


def to_lines(raw_html: str) -> list[str]:
    """去标签、反转义，得到按行排列的纯文本。"""
    body = re.sub(r"<script[\s\S]*?</script>", " ", raw_html, flags=re.I)
    body = re.sub(r"<style[\s\S]*?</style>", " ", body, flags=re.I)
    body = re.sub(r"<[^>]+>", "\n", body)
    body = html.unescape(body)
    return [ln.strip() for ln in body.split("\n") if ln.strip()]


def simplify(text: str) -> str:
    try:
        import opencc
    except ImportError:
        # 缺失依赖时退回原样，不让整条流水线静默失败
        print("warn: opencc 未安装，保留原文", file=sys.stderr)
        return text
    return opencc.OpenCC("t2s").convert(text)


def tidy(text: str) -> str:
    text = text.replace("\u223c", "\uff5e").replace("~", "\uff5e")  # ∼ / ~ -> ～
    text = text.replace("\u200b", "").replace("\xa0", " ")
    return re.sub(r"\s+", " ", text).strip()


def parse(lines: list[str]) -> dict:
    # 日期：形如「2026 年 11 月 8 日」
    date = None
    for ln in lines:
        m = re.search(r"(\d{4})\s*年\s*(\d{1,2})\s*月\s*(\d{1,2})\s*日", ln)
        if m:
            date = datetime.date(int(m.group(1)), int(m.group(2)), int(m.group(3)))
            break
    if not date:
        raise ValueError("找不到日期行")

    def is_noise(ln: str) -> bool:
        """原页用「★」「-->」这类纯符号行做分隔，不能当成正文。"""
        s = ln.strip()
        if not s:
            return True
        if s in ("-->", "—>", "->"):
            return True
        # 去掉符号与空白后什么都不剩，就是分隔行
        return not re.sub(r"[★☆·•●○◆◇※\-–—_=~～\s]+", "", s)

    def after(marker: str, stop: list[str], max_lines: int = 4) -> list[str]:
        for i, ln in enumerate(lines):
            if marker in ln:
                # 同一行可能跟着内容，例如「今天的主題 悲慘的審判」
                tail = ln.split(marker, 1)[1].strip(" ★：:")
                out = [tail] if tail and not is_noise(tail) else []
                for nxt in lines[i + 1 :]:
                    if any(s in nxt for s in stop):
                        break
                    if is_noise(nxt):
                        continue
                    out.append(nxt)
                    if len(out) >= max_lines:
                        break
                return out
        raise ValueError(f"找不到锚点：{marker}")

    topic_lines = after("今天的主題", ["經文範圍", "經文摘要", "經文內容"])
    reading_lines = after("經文範圍", ["經文摘要", "經文內容", "全心禱告", "全年讀經"])

    if not topic_lines or not reading_lines:
        raise ValueError("主题或经文范围为空")

    topic = tidy(simplify(topic_lines[0]))
    subtitle = tidy(simplify(topic_lines[1])) if len(topic_lines) > 1 else ""
    reading = tidy(simplify(reading_lines[0]))

    # 兜底：日期后紧跟的「今天的诗歌」不应混入
    for bad in ("今天的詩歌", "今天的主題", "經文範圍"):
        if bad in topic or bad in reading:
            raise ValueError("字段混入了锚点文本")

    return {
        "date": date.isoformat(),
        "dateLabel": f"{date.year}年{date.month}月{date.day}日",
        "weekday": WEEKDAYS[date.weekday()],
        "topic": topic,
        "subtitle": subtitle,
        "reading": reading,
        "sourceUrl": SOURCE_URL,
    }


def main() -> int:
    try:
        raw = fetch()
        data = parse(to_lines(raw))
    except Exception as exc:  # noqa: BLE001 - 任何解析异常都要让工作流失败
        print(f"抓取或解析失败：{exc}", file=sys.stderr)
        return 1

    tpe = datetime.datetime.now(datetime.timezone(datetime.timedelta(hours=8)))
    data["updated"] = tpe.strftime("%Y-%m-%d %H:%M")
    data["updatedLabel"] = f"{tpe.year}年{tpe.month}月{tpe.day}日 {tpe:%H:%M}"

    # 对方站点还没换当天内容时，不要拿昨天的数据冒充今天，留给下一次定时重试
    if data["date"] != tpe.date().isoformat():
        print(f"对方站点仍是 {data['dateLabel']}，尚未更新到今天，本次不写入", file=sys.stderr)
        return 0

    OUT.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"已写入 {OUT.name}：{data['dateLabel']} · {data['topic']} · {data['reading']}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
