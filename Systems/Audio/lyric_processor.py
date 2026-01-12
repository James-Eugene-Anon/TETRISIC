#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
歌词处理模块 - 处理歌词解析、断句和方块生成逻辑
用于减少GDScript文件的复杂度
"""

import re
from typing import List, Dict, Tuple, Optional
from dataclasses import dataclass


@dataclass
class LyricLine:
    """歌词行数据结构"""
    time: float
    japanese: str
    chinese: str


class LyricProcessor:
    """歌词处理器 - 负责LRC解析和智能断句"""
    
    # 方块形状定义 (格子数 -> 形状名称列表)
    SHAPE_MAP = {
        1: ["DOT"],
        2: ["I2"],
        3: ["I3"],
        4: ["I", "O", "T", "S", "Z", "J", "L"],  # 经典7个4格方块
        5: ["PLUS"],
        6: ["L6"],
        7: ["T7"]
    }
    
    def __init__(self):
        self.lyrics: List[LyricLine] = []
        self.lyric_blocks: List[str] = []  # 包含所有字符和\n分隔符
        
    def parse_lrc_file(self, file_path: str) -> Tuple[List[LyricLine], int]:
        """
        解析LRC文件
        返回: (歌词列表, 总字符数)
        """
        self.lyrics.clear()
        self.lyric_blocks.clear()
        
        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                lines = f.readlines()
        except Exception as e:
            print(f"读取LRC文件失败: {e}")
            return [], 0
        
        pattern = re.compile(r'\[(\d+):(\d+\.\d+)\](.+)')
        
        for line in lines:
            line = line.strip()
            match = pattern.match(line)
            
            if match:
                minutes = int(match.group(1))
                seconds = float(match.group(2))
                text = match.group(3)
                
                time = minutes * 60 + seconds
                
                # 检查是否是中文翻译行
                if text.startswith('/'):
                    chinese_text = text[1:].strip()
                    if self.lyrics:
                        # 更新上一行的中文翻译
                        self.lyrics[-1].chinese = chinese_text
                else:
                    # 新的日文歌词行
                    japanese_text = text.strip()
                    self.lyrics.append(LyricLine(
                        time=time,
                        japanese=japanese_text,
                        chinese=""
                    ))
        
        # 构建lyric_blocks (所有字符 + \n句子分隔符)
        for lyric_line in self.lyrics:
            for char in lyric_line.japanese:
                self.lyric_blocks.append(char)
            if lyric_line.japanese:
                self.lyric_blocks.append("\n")  # 句子边界标记
        
        total_chars = len(self.lyric_blocks)
        return self.lyrics, total_chars
    
    def get_next_piece_info(self, current_index: int) -> Dict:
        """
        智能计算下一个方块的信息
        返回: {
            "shape": str,        # 形状名称
            "size": int,         # 格子数
            "chars": List[str],  # 包含的字符
            "new_index": int     # 更新后的索引
        }
        """
        # 跳过换行符和空格
        while current_index < len(self.lyric_blocks) and \
              self.lyric_blocks[current_index] in ["\n", " "]:
            current_index += 1
        
        remaining_chars = len(self.lyric_blocks) - current_index
        
        if remaining_chars <= 0:
            return {
                "shape": "",
                "size": 0,
                "chars": [],
                "new_index": current_index
            }
        
        # 找到当前句子的结束位置
        sentence_end = current_index
        space_positions = []  # 记录句内空格位置 (相对位置)
        
        for i in range(remaining_chars):
            char = self.lyric_blocks[current_index + i]
            if char == "\n":
                sentence_end = current_index + i
                break
            elif char == " ":
                space_positions.append(i)
            sentence_end = current_index + i + 1
        
        sentence_length = sentence_end - current_index
        piece_size = 0
        
        # 断句策略: 优先4-6格, 在空格处断开保持词完整性
        if sentence_length <= 6:
            # 整句不超过6格,直接使用整句
            piece_size = sentence_length
        elif sentence_length >= 7:
            # 长句子: 优先在空格处断开,生成4-6格方块
            ideal_space_found = False
            
            # 策略1: 精确匹配4-6格内的空格(最优)
            for pos in space_positions:
                if 4 <= pos <= 6:
                    piece_size = pos
                    ideal_space_found = True
                    break
            
            # 策略2: 如果没有4-6格空格,找2-3格的空格(保持词完整)
            if not ideal_space_found:
                for pos in space_positions:
                    if 2 <= pos <= 3:
                        piece_size = pos
                        ideal_space_found = True
                        break
            
            # 策略3: 都没有合适空格,按概率生成,但尽量贴近空格
            if not ideal_space_found:
                import random
                rand = random.randint(0, 99)
                
                if rand < 60:  # 60%概率4格
                    target_size = 4
                elif rand < 85:  # 25%概率5格
                    target_size = 5
                else:  # 15%概率6格
                    target_size = 6
                
                # 寻找最接近目标大小的空格
                best_space = -1
                min_diff = 999
                for pos in space_positions:
                    diff = abs(pos - target_size)
                    if diff < min_diff and pos >= 2:  # 至少2格保证词完整
                        min_diff = diff
                        best_space = pos
                
                piece_size = best_space if best_space > 0 else target_size
        
        # 确保不超过句子长度
        piece_size = min(piece_size, sentence_length)
        
        # 根据大小选择形状
        shape = self._select_shape(piece_size)
        
        # 提取字符
        chars = []
        for i in range(piece_size):
            if current_index + i < len(self.lyric_blocks):
                chars.append(self.lyric_blocks[current_index + i])
        
        new_index = current_index + piece_size
        
        return {
            "shape": shape,
            "size": piece_size,
            "chars": chars,
            "new_index": new_index,
            "sentence_length": sentence_length
        }
    
    def _select_shape(self, size: int) -> str:
        """根据大小选择形状"""
        import random
        
        if size > 7:
            size = 7
        elif size < 1:
            size = 1
        
        shapes = self.SHAPE_MAP.get(size, ["DOT"])
        return random.choice(shapes)
    
    def predict_next_shape(self, current_index: int) -> str:
        """预测下一个方块的形状(用于预览框)"""
        # 跳过空格和换行
        next_start = current_index
        while next_start < len(self.lyric_blocks) and \
              self.lyric_blocks[next_start] in ["\n", " "]:
            next_start += 1
        
        if next_start >= len(self.lyric_blocks):
            return ""
        
        # 找到下一句的长度
        next_sentence_end = next_start
        for i in range(len(self.lyric_blocks) - next_start):
            char = self.lyric_blocks[next_start + i]
            if char == "\n":
                next_sentence_end = next_start + i
                break
            next_sentence_end = next_start + i + 1
        
        next_sentence_len = next_sentence_end - next_start
        
        # 预测下一个方块大小(简化)
        import random
        
        if next_sentence_len <= 6:
            next_size = next_sentence_len
        else:
            rand = random.randint(0, 99)
            if rand < 60:
                next_size = 4
            elif rand < 85:
                next_size = 5
            else:
                next_size = 6
        
        return self._select_shape(next_size)


# GDScript接口函数 (通过Godot的Python绑定调用)
_processor = LyricProcessor()


def parse_lrc(file_path: str) -> dict:
    """
    供GDScript调用的LRC解析函数
    返回: {"lyrics": [...], "total_chars": int, "lyric_blocks": [...]}
    """
    lyrics, total_chars = _processor.parse_lrc_file(file_path)
    
    return {
        "lyrics": [
            {"time": l.time, "japanese": l.japanese, "chinese": l.chinese}
            for l in lyrics
        ],
        "total_chars": total_chars,
        "lyric_blocks": _processor.lyric_blocks.copy()
    }


def get_next_piece(current_index: int) -> dict:
    """供GDScript调用的方块生成函数"""
    return _processor.get_next_piece_info(current_index)


def predict_next(current_index: int) -> str:
    """供GDScript调用的预测函数"""
    return _processor.predict_next_shape(current_index)


if __name__ == "__main__":
    # 测试代码
    print("歌词处理模块测试")
    processor = LyricProcessor()
    
    # 模拟测试数据
    test_data = "ああもう 本当 鬱陶しいなあ"
    processor.lyric_blocks = list(test_data) + ["\n"]
    
    index = 0
    while index < len(processor.lyric_blocks):
        info = processor.get_next_piece_info(index)
        if info["size"] == 0:
            break
        print(f"方块: {info['shape']} ({info['size']}格) - 字符: {''.join(info['chars'])}")
        index = info["new_index"]
