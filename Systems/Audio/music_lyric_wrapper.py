#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
MusicLyricApp CLI Wrapper
用于 Godot 集成的命令行包装器
"""
import sys
import os
import subprocess
import time
import argparse
import json
import urllib.request
import urllib.parse

def _http_get(url, headers=None, timeout=10):
    req = urllib.request.Request(url, headers=headers or {})
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        return resp.read().decode('utf-8', errors='ignore')


def _search_song_candidates(keyword, limit=10):
    query = urllib.parse.quote(keyword)
    url = f"https://music.163.com/api/search/get?s={query}&type=1&limit={max(1, int(limit))}&offset=0"
    headers = {
        "User-Agent": "Mozilla/5.0",
        "Referer": "https://music.163.com/",
    }
    data = _http_get(url, headers=headers)
    payload = json.loads(data)
    result = payload.get("result", {})
    songs = result.get("songs", [])
    if not songs:
        return []
    return songs


def _normalize_text(text):
    if text is None:
        return ""
    s = str(text).strip().lower()
    for ch in [" ", "\t", "-", "_", "·", ".", "，", ",", "（", "）", "(", ")", "[", "]", "【", "】", "'", '"', "!", "?", "。", "、", "/", "\\", "|", ":", "："]:
        s = s.replace(ch, "")
    return s


def _extract_candidate_artist(candidate):
    artists = candidate.get("artists", []) if isinstance(candidate, dict) else []
    names = [a.get("name", "") for a in artists if isinstance(a, dict)]
    return " ".join([n for n in names if n]).strip()


def _extract_candidate_album(candidate):
    album = candidate.get("album", {}) if isinstance(candidate, dict) else {}
    if isinstance(album, dict):
        return str(album.get("name", "")).strip()
    return ""


def _candidate_score(candidate, song_name, artist, album, keyword, target_duration_sec=0.0):
    cand_name = _normalize_text(candidate.get("name", ""))
    cand_artist = _normalize_text(_extract_candidate_artist(candidate))
    cand_album = _normalize_text(_extract_candidate_album(candidate))
    target_song = _normalize_text(song_name)
    target_artist = _normalize_text(artist)
    target_album = _normalize_text(album)
    target_keyword = _normalize_text(keyword)

    score = 0
    if target_song and cand_name == target_song:
        score += 100
    elif target_song and target_song in cand_name:
        score += 60
    elif target_song and cand_name in target_song:
        score += 40

    if target_artist and cand_artist == target_artist:
        score += 80
    elif target_artist and target_artist in cand_artist:
        score += 50

    if target_album and cand_album == target_album:
        score += 70
    elif target_album and target_album in cand_album:
        score += 35

    if target_keyword:
        merged = cand_artist + cand_name
        if target_keyword == merged:
            score += 30
        elif target_keyword in merged:
            score += 15

    # 时长匹配：候选API返回的 duration 单位为毫秒
    if target_duration_sec > 0:
        cand_duration_ms = candidate.get("duration", 0)
        if cand_duration_ms > 0:
            cand_duration_sec = cand_duration_ms / 1000.0
            diff_ratio = abs(cand_duration_sec - target_duration_sec) / max(target_duration_sec, 1.0)
            if diff_ratio <= 0.03:        # 时长误差 ≤3%：高度吻合
                score += 60
            elif diff_ratio <= 0.08:     # 误差 ≤8%
                score += 30
            elif diff_ratio <= 0.15:     # 误差 ≤15%
                score += 10
            else:                        # 时长相差太大：很可能是不同版本
                score -= 40

    # 微小偏好：非翻唱/伴奏关键词
    lowered_name = str(candidate.get("name", "")).lower()
    if any(k in lowered_name for k in ["伴奏", "instrumental", "karaoke", "纯音乐"]):
        score -= 20
    return score


def _is_instrumental_placeholder(lyrics):
    text = (lyrics or "").strip()
    if not text:
        return True
    lowered = text.lower()
    placeholder_tokens = [
        "纯音乐",
        "请欣赏",
        "instrumental",
        "no lyrics",
        "无歌词",
        "暂无歌词",
        "此歌曲为没有填词的纯音乐",
    ]
    if any(token in lowered for token in placeholder_tokens):
        # 若命中占位词，排除作词/作曲等元信息后再判断是否仍无有效歌词
        import re
        timed_lines = re.findall(r"\[\d{1,2}:\d{1,2}(?:\.\d{1,2})?\]([^\n\r]*)", text)
        raw_non_empty = [ln.strip() for ln in timed_lines if ln.strip()]

        def _is_credit_line(line_text):
            # TGCC 结构化检测：短文本头+冒号/斜杠+内容 → 信用行
            s = line_text.strip()
            if len(s) > 50 or len(s) < 3:
                return False
            # 括号包裹的短文本标记
            if (s.startswith("(") and s.endswith(")")) or \
               (s.startswith("\uff08") and s.endswith("\uff09")) or \
               (s.startswith("\u3010") and s.endswith("\u3011")):
                inner = s[1:-1].strip()
                if inner and len(inner) <= 8:
                    return True
            # 角色-冒号模式
            import re as _re
            m = _re.match(r'^(.{1,10})[:：/／](.+)$', s)
            if m:
                head, tail = m.group(1).strip(), m.group(2).strip()
                if 1 <= len(head) <= 10 and 0 < len(tail) <= 25:
                    if not any(tail.endswith(e) for e in ["。","？","！","…","!","?","~"]):
                        return True
            return False

        content_lines = [ln for ln in raw_non_empty if not _is_credit_line(ln)]
        non_placeholder_content = [
            ln for ln in content_lines
            if not any(token in ln.lower() for token in placeholder_tokens)
        ]
        if len(non_placeholder_content) == 0:
            return True
    return False


def _fetch_lyrics(song_id):
    """获取歌词，同时获取翻译并合并为带翻译的LRC格式"""
    url = f"https://music.163.com/api/song/lyric?os=pc&id={song_id}&lv=-1&kv=-1&tv=-1"
    headers = {
        "User-Agent": "Mozilla/5.0",
        "Referer": "https://music.163.com/",
    }
    data = _http_get(url, headers=headers)
    payload = json.loads(data)
    
    # 获取原歌词
    lrc = payload.get("lrc", {})
    original_lyric = lrc.get("lyric", "").strip()
    
    # 获取翻译歌词 (tlyric)
    tlyric = payload.get("tlyric", {})
    translated_lyric = tlyric.get("lyric", "").strip()
    
    if not original_lyric:
        return ""
    
    # 如果没有翻译，直接返回原歌词
    if not translated_lyric:
        return original_lyric
    
    # 合并原歌词和翻译歌词，按相同时间戳配对
    return _merge_lyrics_with_translation(original_lyric, translated_lyric)


def _parse_lrc_line(line):
    """解析单行LRC，返回(时间戳, 文本)或None"""
    import re
    match = re.match(r'\[(\d+):(\d+\.?\d*)\](.*)', line)
    if match:
        minutes = int(match.group(1))
        seconds = float(match.group(2))
        text = match.group(3).strip()
        time_sec = minutes * 60 + seconds
        return (time_sec, text)
    return None


def _merge_lyrics_with_translation(original, translated):
    """将原歌词和翻译歌词合并，使用相同时间戳，翻译行加/前缀"""
    # 解析原歌词
    orig_lines = {}
    meta_lines = []
    for line in original.split('\n'):
        line = line.strip()
        if not line:
            continue
        parsed = _parse_lrc_line(line)
        if parsed:
            time_sec, text = parsed
            if text:  # 忽略空文本
                orig_lines[time_sec] = text
        elif line.startswith('[') and ':' in line and not line[1].isdigit():
            # 元数据行如 [ar:Artist]
            meta_lines.append(line)
    
    # 解析翻译歌词
    trans_lines = {}
    for line in translated.split('\n'):
        line = line.strip()
        if not line:
            continue
        parsed = _parse_lrc_line(line)
        if parsed:
            time_sec, text = parsed
            if text:  # 忽略空文本
                trans_lines[time_sec] = text
    
    # 合并输出：先元数据，再按时间戳排序的歌词
    result = []
    result.extend(meta_lines)
    
    # 获取所有时间戳
    all_times = sorted(set(orig_lines.keys()) | set(trans_lines.keys()))
    
    for time_sec in all_times:
        minutes = int(time_sec // 60)
        seconds = time_sec % 60
        time_str = f"[{minutes:02d}:{seconds:05.2f}]"
        
        # 原歌词行
        if time_sec in orig_lines:
            result.append(f"{time_str}{orig_lines[time_sec]}")
        
        # 翻译行（如果存在），以/开头
        if time_sec in trans_lines:
            result.append(f"{time_str}/{trans_lines[time_sec]}")
    
    return '\n'.join(result)


def _try_http_lyric(keyword, output_path, song_name="", artist="", album="", max_checks=1, target_duration_sec=0.0):
    try:
        candidates = _search_song_candidates(keyword, limit=12)
        if not candidates:
            return False

        # 按评分降序排列候选（歌手/歌名精确度 + 时长匹配）
        candidates.sort(
            key=lambda c: _candidate_score(c, song_name, artist, album, keyword, target_duration_sec),
            reverse=True
        )

        # 检查排序后前 N 条（N = X + 1, 1~11）
        checks = max(1, min(int(max_checks), 11, len(candidates)))
        for candidate in candidates[:checks]:
            song_id = candidate.get("id")
            if not song_id:
                continue
            lyrics = _fetch_lyrics(song_id)
            if not lyrics:
                continue
            if _is_instrumental_placeholder(lyrics):
                continue

            output_dir = os.path.dirname(output_path)
            if output_dir and not os.path.exists(output_dir):
                os.makedirs(output_dir)
            with open(output_path, "w", encoding="utf-8") as f:
                f.write(lyrics)
            return True

        return False
    except Exception as e:
        print(f"HTTP歌词获取失败: {e}", file=sys.stderr)
        return False


def search_and_download(app_path, keyword, output_path, song_name="", artist="", album="", max_checks=1, target_duration_sec=0.0):
    """
    调用 MusicLyricApp 搜索并下载歌词
    
    Args:
        app_path: MusicLyricApp 可执行文件路径
        keyword: 搜索关键词（歌曲名或"艺术家 歌曲名"）
        output_path: 输出LRC文件路径
        album: 专辑名（用于候选排序）
        target_duration_sec: 音频文件时长（秒），用于精确匹配版本，0 表示忽略
    
    Returns:
        bool: 是否成功
    """
    # 优先使用在线API，避免GUI弹窗
    if _try_http_lyric(keyword, output_path, song_name=song_name, artist=artist, album=album, max_checks=max_checks, target_duration_sec=target_duration_sec):
        print(f"成功: 歌词已保存到 {output_path}")
        return True

    if not app_path or not os.path.exists(app_path):
        print("错误: 在线API失败且未配置 MusicLyricApp", file=sys.stderr)
        return False
    
    # 确保输出目录存在
    output_dir = os.path.dirname(output_path)
    if output_dir and not os.path.exists(output_dir):
        os.makedirs(output_dir)
    
    try:
        # 由于这是GUI应用，我们需要特殊处理
        # 使用无窗口模式启动
        startupinfo = subprocess.STARTUPINFO()
        startupinfo.dwFlags |= subprocess.STARTF_USESHOWWINDOW
        startupinfo.wShowWindow = 0  # SW_HIDE
        
        # 构建命令行参数
        # 注意：这里假设程序支持某种CLI模式，如果不支持，需要其他方法
        cmd = [
            app_path,
            '--keyword', keyword,
            '--output', output_path,
            '--format', 'lrc',
            '--encoding', 'utf8',
            '--provider', 'netease'  # 网易云音乐
        ]
        
        print(f"执行命令: {' '.join(cmd)}")
        
        # 执行命令（30秒超时）
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=30,
            startupinfo=startupinfo
        )
        
        print(f"退出码: {result.returncode}")
        if result.stdout:
            print(f"标准输出: {result.stdout}")
        if result.stderr:
            print(f"标准错误: {result.stderr}", file=sys.stderr)
        
        # 等待文件生成
        for _ in range(10):  # 最多等待5秒
            if os.path.exists(output_path):
                # 检查文件是否有内容
                if os.path.getsize(output_path) > 0:
                    print(f"成功: 歌词已保存到 {output_path}")
                    return True
            time.sleep(0.5)
        
        print("错误: 未生成歌词文件", file=sys.stderr)
        return False
        
    except subprocess.TimeoutExpired:
        print("错误: 执行超时", file=sys.stderr)
        return False
    except Exception as e:
        print(f"错误: {e}", file=sys.stderr)
        return False

def main():
    parser = argparse.ArgumentParser(description='MusicLyricApp CLI Wrapper')
    parser.add_argument('--app', required=True, help='MusicLyricApp 可执行文件路径')
    parser.add_argument('--keyword', required=True, help='搜索关键词')
    parser.add_argument('--output', required=True, help='输出LRC文件路径')
    parser.add_argument('--song', default='', help='歌曲名（用于候选排序）')
    parser.add_argument('--artist', default='', help='歌手名（用于候选排序）')
    parser.add_argument('--album', default='', help='专辑名（用于候选排序）')
    parser.add_argument('--max-checks', type=int, default=1, help='按结果顺序最多检查前N条（1~11）')
    parser.add_argument('--duration', type=float, default=0.0, help='音频时长（秒），用于版本精确匹配，0表示忽略')
    
    args = parser.parse_args()
    
    success = search_and_download(
        args.app,
        args.keyword,
        args.output,
        song_name=args.song,
        artist=args.artist,
        album=args.album,
        max_checks=args.max_checks,
        target_duration_sec=args.duration,
    )
    sys.exit(0 if success else 1)

if __name__ == '__main__':
    main()
