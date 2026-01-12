extends Node

class_name LyricsParser

# 歌词行数据结构
class LyricLine:
	var time: float  # 秒
	var japanese: String
	var chinese: String
	
	func _init(t: float, jp: String, cn: String = ""):
		time = t
		japanese = jp
		chinese = cn

# 解析LRC文件
static func parse_lrc(file_path: String) -> Array[LyricLine]:
	var lyrics: Array[LyricLine] = []
	var file = FileAccess.open(file_path, FileAccess.READ)
	
	if not file:
		push_error("无法打开歌词文件: " + file_path)
		return lyrics
	
	var japanese_lines = {}
	var chinese_lines = {}
	
	# 读取所有行
	while not file.eof_reached():
		var line = file.get_line().strip_edges()
		if line.is_empty():
			continue
		
		# 解析时间戳和歌词
		var parsed = parse_line(line)
		if parsed.is_empty():
			continue
		
		var time = parsed["time"]
		var text = parsed["text"]
		
		# 区分日语和中文（中文以"/"开头）
		if text.begins_with("/"):
			chinese_lines[time] = text.substr(1).strip_edges()
		else:
			japanese_lines[time] = text
	
	file.close()
	
	# 合并日语和中文
	for time in japanese_lines.keys():
		var jp_text = japanese_lines[time]
		var cn_text = chinese_lines.get(time, "")
		lyrics.append(LyricLine.new(time, jp_text, cn_text))
	
	# 按时间排序
	lyrics.sort_custom(func(a, b): return a.time < b.time)
	
	return lyrics

# 解析单行歌词
static func parse_line(line: String) -> Dictionary:
	var regex = RegEx.new()
	regex.compile("\\[(\\d+):(\\d+\\.\\d+)\\](.+)")
	var result = regex.search(line)
	
	if not result:
		return {}
	
	var minutes = result.get_string(1).to_int()
	var seconds = result.get_string(2).to_float()
	var text = result.get_string(3).strip_edges()
	
	var time = minutes * 60.0 + seconds
	
	return {"time": time, "text": text}

# 将文本转换为方块字符（每个字符一个方块）
static func text_to_blocks(text: String) -> Array[String]:
	var blocks: Array[String] = []
	for i in range(text.length()):
		var char = text[i]
		# 保留所有字符（包括空格，用于断句）
		blocks.append(char)
	return blocks
