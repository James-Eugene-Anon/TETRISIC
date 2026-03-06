#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
歌词处理模块（简化 TGCC 版）

目标：
- 按 timestamp 分组（group）而不是逐行硬筛
- 使用结构特征 + 轻量脚本检测 + 上下文块规则分类
- 默认输出主歌词（LYRIC_PRIMARY）并可并行带翻译
"""

from __future__ import annotations

import json
import re
import sys
from dataclasses import dataclass, field
from pathlib import Path
from typing import Dict, List, Optional, Tuple


@dataclass
class LyricLine:
    time: float
    japanese: str
    chinese: str


@dataclass
class GroupLine:
    text_raw: str
    text_clean: str
    script: str
    explicit_translation: bool


@dataclass
class TimeGroup:
    time: float
    order: int
    lines: List[GroupLine] = field(default_factory=list)
    label: str = "UNKNOWN"  # LYRIC_PRIMARY / TRANSLATION / CREDIT / TITLE / NOISE / UNKNOWN


class LyricProcessor:
    SHAPE_MAP = {
        1: ["DOT"],
        2: ["I2"],
        3: ["I3"],
        4: ["I", "O", "T", "S", "Z", "J", "L"],
        5: ["PLUS"],
        6: ["L6"],
        7: ["T7"],
    }

    # --- TGCC 结构化检测：不依赖关键词黑名单 ---
    # 核心原理: role-colon pattern  head(1-10字符) + 冒号 + content
    # 任何语言的信用行都匹配这个结构。

    # 多语种 role-like pattern（简化版）
    ROLE_COLON_RE = re.compile(r"^\s*[\w\u0080-\uffff\s]{1,12}[:：]\s*.+$", re.UNICODE)
    EMBEDDED_TAG_RE = re.compile(r"^\[(ar|ti|al|by|offset|tool|ve|re):", re.IGNORECASE)
    TIMESTAMP_RE = re.compile(r"[\[(](\d{1,2}):(\d{1,2}(?:\.\d{1,3})?)[\])]")

    def __init__(self):
        self.lyrics: List[LyricLine] = []
        self.lyric_blocks: List[str] = []

    # -------------------- 基础工具 --------------------
    @staticmethod
    def _safe_float(v: str) -> float:
        try:
            return float(v)
        except Exception:
            return 0.0

    def _normalize_line(self, line: str) -> str:
        if not line:
            return ""
        t = line.replace("\ufeff", "").replace("：", "：").strip()
        return t

    def _extract_timestamps_and_text(self, line: str) -> Tuple[List[float], str]:
        # 支持多时间戳：[00:12.34][00:14.00]text 或 (00:12)text
        matches = list(self.TIMESTAMP_RE.finditer(line))
        if not matches:
            return [], ""

        times: List[float] = []
        for m in matches:
            mm = int(m.group(1))
            ss = self._safe_float(m.group(2))
            times.append(mm * 60 + ss)

        text_start = matches[-1].end()
        text = line[text_start:].strip()
        return times, text

    def _script_profile(self, text: str) -> Dict[str, int]:
        profile = {"latin": 0, "han": 0, "hiragana": 0, "katakana": 0, "other": 0}
        for ch in text:
            cp = ord(ch)
            if (0x41 <= cp <= 0x5A) or (0x61 <= cp <= 0x7A):
                profile["latin"] += 1
            elif 0x4E00 <= cp <= 0x9FFF:
                profile["han"] += 1
            elif 0x3040 <= cp <= 0x309F:
                profile["hiragana"] += 1
            elif 0x30A0 <= cp <= 0x30FF:
                profile["katakana"] += 1
            else:
                profile["other"] += 1
        return profile

    def _dominant_script(self, text: str) -> str:
        p = self._script_profile(text)
        if p["hiragana"] + p["katakana"] > 0:
            return "jp"
        if p["han"] > 0 and p["latin"] == 0:
            return "han"
        if p["latin"] > 0 and p["han"] == 0:
            return "latin"
        if p["han"] > 0 and p["latin"] > 0:
            return "mixed"
        return "other"


    def _is_parenthesized_role(self, text: str) -> bool:
        """TGCC 结构化检测：括号包裹的短文本标记
        不依赖关键词黑名单，只要结构上是 "括号包裹的短文本" 就是标记"""
        t = text.strip()
        if len(t) > 25 or len(t) < 3:
            return False
        inner = ""
        if (t.startswith("(") and t.endswith(")")) or \
           (t.startswith("\uff08") and t.endswith("\uff09")) or \
           (t.startswith("\u3010") and t.endswith("\u3011")) or \
           (t.startswith("[") and t.endswith("]")) or \
           (t.startswith("\u3014") and t.endswith("\u3015")):
            inner = t[1:-1].strip()
        else:
            return False
        if not inner:
            return False
        # 结构特征：内容短(≤8字符) → 角色/标记，不是歌词
        return len(inner) <= 8

    def _is_role_colon(self, text: str) -> bool:
        """TGCC 核心：结构化角色-冒号检测
        模式：短文本头(1-10字符) + 冒号 + 名字/短内容
        不依赖关键词黑名单，而是通过结构特征判断"""
        t = text.strip()
        if len(t) > 60:
            return False
        if not self.ROLE_COLON_RE.match(t):
            return False
        parts = re.split(r"[:：]", t, maxsplit=1)
        if len(parts) < 2:
            return False
        head = parts[0].strip()
        tail = parts[1].strip()
        # 头部短(1-10字符) → 结构匹配
        if len(head) < 1 or len(head) > 10:
            return False
        if not tail:
            return False
        # 排除歌词假阳性：尾部含句末标点
        for ending in ["。", "？", "！", "…", "!", "?", "~", "～"]:
            if tail.endswith(ending):
                return False
        # 尾部过长 → 更像歌词
        if len(tail) > 25:
            return False
        return True

    def _is_embedded_lrc_tag(self, text: str) -> bool:
        return bool(self.EMBEDDED_TAG_RE.search(text.strip()))

    def _strip_translation_prefix(self, text: str) -> Tuple[str, bool]:
        t = text.strip()
        if t.startswith("//"):
            return t[2:].strip(), True
        if t.startswith("/") and len(t) > 1:
            return t[1:].strip(), True
        return t, False

    def _file_title_similarity(self, text: str, file_stem: str) -> float:
        # 非 NLP，轻量词重叠分数
        if not text or not file_stem:
            return 0.0
        tx = re.sub(r"[^\w\u4e00-\u9fff]+", " ", text.lower()).split()
        fs = re.sub(r"[^\w\u4e00-\u9fff]+", " ", file_stem.lower()).split()
        if not tx or not fs:
            return 0.0
        a, b = set(tx), set(fs)
        inter = len(a & b)
        union = max(1, len(a | b))
        return inter / union

    def _looks_like_file_title(self, text: str, file_stem: str) -> bool:
        t = re.sub(r"[^\w\u4e00-\u9fff]+", "", text.lower())
        s = re.sub(r"[^\w\u4e00-\u9fff]+", "", file_stem.lower())
        if not t or not s:
            return False
        return len(t) <= 20 and t in s

    def _normalize_primary_text(self, text: str, has_translation_line: bool) -> str:
        t = text.strip()
        if has_translation_line and t.endswith(("/", "／")):
            t = t[:-1].rstrip()
        return t

    # -------------------- 简化 TGCC 主流程 --------------------
    def _build_groups(self, file_path: str) -> List[TimeGroup]:
        groups: Dict[float, TimeGroup] = {}
        order_seq: List[float] = []
        order = 0

        with open(file_path, "r", encoding="utf-8", errors="ignore") as f:
            for raw in f:
                line = self._normalize_line(raw)
                if not line:
                    continue

                # 跳过独立元数据 [ar:xx]
                if self.EMBEDDED_TAG_RE.match(line):
                    continue

                times, text = self._extract_timestamps_and_text(line)
                if not times:
                    continue

                if self._is_embedded_lrc_tag(text):
                    continue

                text2, explicit_translation = self._strip_translation_prefix(text)
                if not text2:
                    continue

                script = self._dominant_script(text2)
                gl = GroupLine(
                    text_raw=text,
                    text_clean=text2,
                    script=script,
                    explicit_translation=explicit_translation,
                )

                for ts in times:
                    if ts not in groups:
                        groups[ts] = TimeGroup(time=ts, order=order)
                        order_seq.append(ts)
                        order += 1
                    groups[ts].lines.append(gl)

        return [groups[t] for t in sorted(order_seq)]

    def _detect_main_script(self, groups: List[TimeGroup]) -> str:
        score = {"jp": 0, "han": 0, "latin": 0, "mixed": 0, "other": 0}
        for g in groups:
            for ln in g.lines:
                if ln.explicit_translation:
                    continue
                if self._is_role_colon(ln.text_clean) or self._is_parenthesized_role(ln.text_clean):
                    continue
                score[ln.script] = score.get(ln.script, 0) + 1
        return max(score.items(), key=lambda kv: kv[1])[0]

    def _classify_group(self, group: TimeGroup, main_script: str, file_stem: str) -> Tuple[str, Optional[str], Optional[str], List[str]]:
        # 返回: (label, primary_text, translation_text, extracted_credits)
        extracted_credits: List[str] = []

        candidates_primary: List[Tuple[float, str]] = []
        candidates_trans: List[Tuple[float, str]] = []
        role_count = 0
        title_like_count = 0
        has_translation_line = any(ln.explicit_translation for ln in group.lines)

        for ln in group.lines:
            t = ln.text_clean
            if not t:
                continue

            if self._is_parenthesized_role(t):
                role_count += 1
                extracted_credits.append(t)
                continue

            if self._is_role_colon(t):
                role_count += 1
                extracted_credits.append(t)
                continue

            # title-like: 短 + 与文件名相似 + 靠前时间更可能是标题/噪音
            sim = self._file_title_similarity(t, file_stem)
            if (
                len(t) <= 20
                and group.time <= 60.0
                and (sim >= 0.45 or self._looks_like_file_title(t, file_stem))
            ):
                title_like_count += 1
                continue

            # 单字符“翻译残片”过滤（如 /P）
            if len(t) <= 1 and ln.explicit_translation:
                continue

            # 评分：脚本接近主脚本则更偏 primary
            score_primary = 0.0
            if ln.script == main_script:
                score_primary += 2.0
            if main_script == "jp" and ln.script in ("han", "mixed"):
                score_primary -= 0.5

            # 明显翻译 marker 提升 translation 分
            score_trans = 0.0
            if ln.explicit_translation:
                score_trans += 2.5
            if ln.script != main_script and ln.script in ("han", "mixed", "latin", "jp"):
                score_trans += 0.8

            if not ln.explicit_translation:
                candidates_primary.append((score_primary, t))
            candidates_trans.append((score_trans, t))

        if role_count > 0 and not candidates_primary:
            return "CREDIT", None, None, extracted_credits

        if title_like_count > 0 and not candidates_primary:
            return "TITLE", None, None, extracted_credits

        if not candidates_primary:
            return "NOISE", None, None, extracted_credits

        primary = sorted(candidates_primary, key=lambda x: x[0], reverse=True)[0][1]
        primary = self._normalize_primary_text(primary, has_translation_line)
        translation = ""
        if len(candidates_trans) >= 2 or any(sc >= 2.0 for sc, _ in candidates_trans):
            tr_sorted = sorted(candidates_trans, key=lambda x: x[0], reverse=True)
            for _, t in tr_sorted:
                if t != primary:
                    translation = t
                    break

        return "LYRIC_PRIMARY", primary, translation, extracted_credits

    def parse_lrc_file(self, file_path: str) -> Tuple[List[LyricLine], int, List[int], bool, List[str]]:
        self.lyrics.clear()
        self.lyric_blocks.clear()

        fp = Path(file_path)
        groups = self._build_groups(file_path)
        if not groups:
            return [], 0, [], False, []

        main_script = self._detect_main_script(groups)
        extracted_credits: List[str] = []

        # 初始分类
        interim: List[Tuple[TimeGroup, str, Optional[str], Optional[str]]] = []
        for g in groups:
            label, primary, trans, credits = self._classify_group(g, main_script, fp.stem)
            extracted_credits.extend(credits)
            g.label = label
            interim.append((g, label, primary, trans))

        # 上下文块修正：连续 role/title/noise 在开头集中出现视为 meta block
        # 避免把开头短句标题误当歌词（如 Cyclone/）
        meta_window = 0
        for g, label, _, _ in interim:
            if g.time > 55.0:
                break
            if label in ("CREDIT", "TITLE", "NOISE"):
                meta_window += 1
            else:
                if meta_window >= 2:
                    break
                meta_window = 0

        # 构建输出歌词
        for g, label, primary, trans in interim:
            if label != "LYRIC_PRIMARY" or not primary:
                continue

            # 防御性：过短且靠前并且与文件名接近，丢弃
            if g.time <= 50.0 and len(primary) <= 12 and self._file_title_similarity(primary, fp.stem) >= 0.6:
                continue

            self.lyrics.append(LyricLine(time=g.time, japanese=primary, chinese=trans or ""))

        self.lyrics.sort(key=lambda x: x.time)

        # 是否中文主歌（用于 UI 处理）
        jp_like = 0
        cn_like = 0
        for l in self.lyrics:
            script = self._dominant_script(l.japanese)
            if script == "jp":
                jp_like += 1
            elif script in ("han", "mixed"):
                cn_like += 1
        is_chinese_song = cn_like > jp_like * 2 and cn_like > 0

        # 构建 lyric_blocks + line_starts
        line_starts: List[int] = []
        for ln in self.lyrics:
            line_starts.append(len(self.lyric_blocks))
            blocks = self._text_to_blocks(ln.japanese)
            self.lyric_blocks.extend(blocks)
            self.lyric_blocks.append("\n")
            self.lyric_blocks.append("\n")

        # credit 去重
        dedup_credits: List[str] = []
        seen = set()
        for c in extracted_credits:
            cc = c.strip()
            if cc and cc not in seen:
                seen.add(cc)
                dedup_credits.append(cc)

        return self.lyrics, len(self.lyric_blocks), line_starts, is_chinese_song, dedup_credits

    # -------------------- 方块相关 --------------------
    def _text_to_blocks(self, text: str) -> List[str]:
        # 简化：保留字符，过滤常见标点，英数字每2字符合并
        punct = set(["?", "!", ",", ".", "。", "，", "？", "！", "、", "：", ":", ";", "；", "(", ")", "（", "）", "~", "～", "-", "—", "―", "ー", "_", "'", '"', "「", "」", "『", "』", "…", "•", "·", "◆", "◇", "●", "○", "※", "▶", "▲", "▼", "→", "←", "↑", "↓", " ", "　", "\\", "@", "#", "$", "%", "^", "&", "*", "+", "=", "[", "]", "{", "}", "<", ">", "|", "`", "♪", "♫", "★", "☆", "♥", "♡"])
        out: List[str] = []
        pending = ""
        for ch in text:
            if ch in punct:
                if pending:
                    out.append(pending)
                    pending = ""
                continue
            if re.fullmatch(r"[A-Za-z0-9]", ch):
                pending += ch
                if len(pending) >= 2:
                    out.append(pending)
                    pending = ""
            else:
                if pending:
                    out.append(pending)
                    pending = ""
                out.append(ch)
        if pending:
            out.append(pending)
        return out



# -------- GDScript 接口 --------
_processor = LyricProcessor()


def parse_lrc(file_path: str) -> dict:
    lyrics, total_chars, line_starts, is_chinese_song, credits = _processor.parse_lrc_file(file_path)
    return {
        "lyrics": [{"time": l.time, "japanese": l.japanese, "chinese": l.chinese} for l in lyrics],
        "total_chars": total_chars,
        "lyric_blocks": _processor.lyric_blocks.copy(),
        "line_starts": line_starts,
        "is_chinese_song": is_chinese_song,
        "extracted_artist": " / ".join(credits),
    }




# -------- CLI --------
def _fail(msg: str) -> None:
    print(json.dumps({"error": msg}, ensure_ascii=False))


def main() -> None:
    # 兼容多种调用方式：
    # python lyric_processor.py <function> <json_params>
    # python lyric_processor.py <function> --params-file <path>
    if len(sys.argv) < 3:
        _fail("usage: lyric_processor.py <parse_lrc> <json_params|--params-file path>")
        return

    fn = sys.argv[1].strip()
    
    # 支持从文件读取参数（避免Windows命令行编码问题）
    if sys.argv[2] == "--params-file" and len(sys.argv) >= 4:
        param_file = sys.argv[3]
        try:
            with open(param_file, "r", encoding="utf-8") as f:
                raw = f.read()
        except Exception as e:
            _fail(f"cannot_read_param_file: {e}")
            return
    else:
        raw = sys.argv[2]

    try:
        params = json.loads(raw)
    except Exception:
        _fail("invalid_json_params")
        return

    try:
        if fn == "parse_lrc":
            path = params.get("file_path", "")
            if not path:
                _fail("missing_file_path")
                return
            out = parse_lrc(path)
            print(json.dumps(out, ensure_ascii=False))
            return

        _fail("unsupported_function")
    except Exception as exc:
        _fail(f"exception: {exc}")


if __name__ == "__main__":
    main()
