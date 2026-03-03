#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
简化TGCC调试入口：
python tgcc_parser.py <lrc_path>
"""

import json
import sys
from lyric_processor import parse_lrc


def main() -> int:
    if len(sys.argv) < 2:
        print("Usage: python tgcc_parser.py <lrc_path>")
        return 1

    lrc_path = sys.argv[1]
    result = parse_lrc(lrc_path)

    print("=== TGCC 简化版解析结果 ===")
    print(f"lyrics: {len(result.get('lyrics', []))} 行")
    print(f"is_chinese_song: {result.get('is_chinese_song', False)}")
    print(f"extracted_artist: {result.get('extracted_artist', '')}")

    print("\n--- 前10行歌词 ---")
    for item in result.get("lyrics", [])[:10]:
        t = item.get("time", 0.0)
        jp = item.get("japanese", "")
        cn = item.get("chinese", "")
        print(f"[{t:07.2f}] {jp}")
        if cn:
            print(f"          CN: {cn}")

    print("\n--- 原始JSON（节选） ---")
    slim = {
        "lyrics_preview": result.get("lyrics", [])[:5],
        "line_starts_preview": result.get("line_starts", [])[:8],
        "total_chars": result.get("total_chars", 0),
    }
    print(json.dumps(slim, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
