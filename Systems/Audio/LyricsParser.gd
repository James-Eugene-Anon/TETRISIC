extends Node

class_name LyricsParser

# 歌词行数据结构（仅数据容器，不含解析逻辑）
class LyricLine:
	var time: float  # 秒
	var japanese: String
	var chinese: String
	
	func _init(t: float, jp: String, cn: String = ""):
		time = t
		japanese = jp
		chinese = cn
