extends Node
# Python桥接器 - 连接GDScript和Python歌词处理模块

# 注意: Godot 4.x需要使用GDExtension或其他方式调用Python
# 这里提供两种方案:
# 方案1: 使用命令行调用Python脚本
# 方案2: 使用HTTP服务器(Python后台运行)

class_name LyricPythonBridge

var use_python = true  # 是否使用Python处理
var python_path = "python"  # Python解释器路径
var script_path = "res://Systems/Audio/lyric_processor.py"

# 缓存数据
var cached_lyrics = []
var cached_lyric_blocks = []
var is_chinese_song = false  # 标记整首歌是否是中文歌曲

func parse_lrc_file(file_path: String) -> Dictionary:
	"""
	解析LRC文件
	返回: {"lyrics": Array, "total_chars": int, "lyric_blocks": Array}
	"""
	if not use_python:
		# 降级到GDScript实现
		return _parse_lrc_fallback(file_path)
	
	# 方案1: 使用命令行调用Python (简单但较慢)
	var result = _call_python_cli("parse_lrc", {"file_path": file_path})
	
	if result.has("error"):
		return _parse_lrc_fallback(file_path)
	
	cached_lyrics = result.lyrics
	cached_lyric_blocks = result.lyric_blocks
	
	return result

func get_next_piece_info(current_index: int) -> Dictionary:
	"""
	获取下一个方块信息
	返回: {"shape": String, "size": int, "chars": Array, "new_index": int, "sentence_length": int}
	"""
	if not use_python or cached_lyric_blocks.is_empty():
		# 降级到GDScript实现
		return _get_next_piece_fallback(current_index)
	
	var result = _call_python_cli("get_next_piece", {"current_index": current_index})
	
	if result.has("error"):
		return _get_next_piece_fallback(current_index)
	
	return result

func predict_next_shape(current_index: int) -> String:
	"""预测下一个方块形状"""
	if not use_python or cached_lyric_blocks.is_empty():
		return _predict_next_fallback(current_index)
	
	var result = _call_python_cli("predict_next", {"current_index": current_index})
	
	if result.has("error"):
		return _predict_next_fallback(current_index)
	
	return result.get("shape", "")

# ============ 内部实现 ============

func _call_python_cli(function: String, params: Dictionary) -> Dictionary:
	"""
	通过命令行调用Python脚本
	注意: 这是临时方案,性能较差,建议后续改用GDExtension或HTTP服务
	"""
	var json_params = JSON.stringify(params)
	var cmd_args = [script_path.replace("res://", ProjectSettings.globalize_path("res://")), 
					function, json_params]
	
	var output = []
	var exit_code = OS.execute(python_path, cmd_args, output, true, false)
	
	if exit_code != 0:
		return {"error": "Python执行失败,退出码: " + str(exit_code)}
	
	if output.is_empty():
		return {"error": "Python无输出"}
	
	var json = JSON.new()
	var parse_result = json.parse(output[0])
	
	if parse_result != OK:
		return {"error": "JSON解析失败: " + output[0]}
	
	return json.get_data()

# ============ GDScript降级实现 ============

func _parse_lrc_fallback(file_path: String) -> Dictionary:
	"""GDScript降级实现 - LRC解析"""
	var lyrics = []
	var lyric_blocks = []
	var extracted_artists = []  # 从元数据行提取的艺术家信息
	
	var file = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		print("无法打开LRC文件: ", file_path)
		return {"lyrics": [], "total_chars": 0, "lyric_blocks": [], "extracted_artist": "", "is_chinese_song": false}
	
	var pattern = RegEx.new()
	pattern.compile("\\[(\\d+):(\\d+\\.\\d+)\\](.+)")
	
	# 元数据标签正则
	var metadata_pattern = RegEx.new()
	metadata_pattern.compile("^\\[(ar|ti|al|by|offset|tool|ve|re):")
	
	# 读取所有行
	var all_lines = []
	while not file.eof_reached():
		var line = file.get_line().strip_edges()
		if not line.is_empty():
			all_lines.append(line)
	file.close()
	
	# 第一遍：收集所有带时间戳的行，区分日文原文和中文翻译
	var japanese_lyrics = {}  # 时间 -> 日文文本
	var chinese_lyrics = {}   # 时间 -> 中文文本
	var seen_times = {}       # 用于检测重复时间戳（翻译标记）
	
	# 统计日语和中文歌词行数，用于判断歌曲语言
	var japanese_line_count = 0
	var chinese_line_count = 0
	
	for line in all_lines:
		# 跳过元数据标签
		if metadata_pattern.search(line):
			continue
		
		var result = pattern.search(line)
		if result:
			var minutes = int(result.get_string(1))
			var seconds = float(result.get_string(2))
			var text = result.get_string(3).strip_edges()
			var time = minutes * 60 + seconds
			
			# 过滤元数据内容：作词、作曲、编曲等 - 但同时提取为艺术家信息
			var artist_info = _extract_artist_info(text)
			if not artist_info.is_empty():
				extracted_artists.append(artist_info)
				continue  # 仍然从歌词中过滤掉
			
			# 过滤空文本
			if text.is_empty():
				continue
			
			# 检测语言并分类
			if seen_times.has(time):
				# 相同时间戳第二次出现，视为翻译
				chinese_lyrics[time] = text
				chinese_line_count += 1
			else:
				# 第一次出现的时间戳
				seen_times[time] = true
				# 检测是否主要是中文（CJK统一汉字范围）
				if _is_mostly_chinese(text):
					chinese_lyrics[time] = text
					chinese_line_count += 1
				else:
					japanese_lyrics[time] = text
					japanese_line_count += 1
	
	# 判断是否是中文歌曲：如果大部分歌词都是中文（没有假名），则认为是中文歌曲
	is_chinese_song = (chinese_line_count > japanese_line_count * 2) or \
					  (japanese_line_count == 0 and chinese_line_count > 0)
	
	print("[LRC解析] 日文行数: ", japanese_line_count, " 中文行数: ", chinese_line_count, " 是中文歌曲: ", is_chinese_song)
	
	# 如果是中文歌曲，交换处理逻辑
	if is_chinese_song:
		# 中文歌曲：使用中文歌词作为主歌词，用于生成方块和两个显示区
		japanese_lyrics = chinese_lyrics.duplicate()
		# 中文翻译保持和主歌词一样
	
	# 合并日文和中文
	var times = japanese_lyrics.keys()
	times.sort()
	
	for time in times:
		var japanese = japanese_lyrics[time]
		var chinese = chinese_lyrics.get(time, "")
		
		lyrics.append({
			"time": time,
			"japanese": japanese,
			"chinese": chinese
		})
		
		print("[LRC解析] 时间:", time, " 日文:", japanese, " 中文:", chinese)
	
	# 构建lyric_blocks：智能断词
	for lyric_line in lyrics:
		var japanese = lyric_line.japanese
		# 使用智能断词
		var word_breaks = _get_word_breaks(japanese)
		
		for word_idx in range(word_breaks.size()):
			var word = word_breaks[word_idx]
			# 添加词语中的每个字符（过滤标点符号和无效Unicode）
			# 特殊处理：英文字母和数字每2个合并为1格
			var pending_alphanumeric = ""  # 缓存待合并的英数字符
			
			for i in range(word.length()):
				var char = word[i]
				var code = word.unicode_at(i)
				
				# 跳过无效的Unicode字符（代理对等）
				if code >= 0xD800 and code <= 0xDFFF:
					continue
				if code == 0 or code > 0x10FFFF:
					continue
				
				# 过滤常见标点
				if _is_punctuation(char):
					# 在遇到标点前，先处理待合并的英数字符
					if not pending_alphanumeric.is_empty():
						lyric_blocks.append(pending_alphanumeric)
						pending_alphanumeric = ""
					continue
				
				# 检查是否是英文字母或数字
				if _is_alphanumeric(code):
					pending_alphanumeric += char
					# 每2个英数字符合并为1格
					if pending_alphanumeric.length() >= 2:
						lyric_blocks.append(pending_alphanumeric)
						pending_alphanumeric = ""
				else:
					# 非英数字符，先处理待合并的
					if not pending_alphanumeric.is_empty():
						lyric_blocks.append(pending_alphanumeric)
						pending_alphanumeric = ""
					lyric_blocks.append(char)
			
			# 处理词语结束时剩余的英数字符
			if not pending_alphanumeric.is_empty():
				lyric_blocks.append(pending_alphanumeric)
			
			# 词语之间用\n分隔（最后一个词除外）
			if word_idx < word_breaks.size() - 1:
				lyric_blocks.append("\n")
		# 每行结束加\n
		if not japanese.is_empty():
			lyric_blocks.append("\n")
	
	cached_lyrics = lyrics
	cached_lyric_blocks = lyric_blocks
	
	# 合并提取的艺术家信息
	var extracted_artist = ""
	if extracted_artists.size() > 0:
		extracted_artist = " / ".join(extracted_artists)
	
	print("[LRC解析] 共解析 ", lyrics.size(), " 行歌词，", lyric_blocks.size(), " 个字符块")
	if not extracted_artist.is_empty():
		print("[LRC解析] 提取艺术家信息: ", extracted_artist)
	
	return {
		"lyrics": lyrics,
		"total_chars": lyric_blocks.size(),
		"lyric_blocks": lyric_blocks,
		"extracted_artist": extracted_artist,
		"is_chinese_song": is_chinese_song
	}

func _is_metadata_line(text: String) -> bool:
	"""检查是否是元数据行"""
	var metadata_keywords = ["作词", "作曲", "编曲", "混音", "制作人", "填词", "监制", 
							 "by.", "By.", "BY.", "翻译", "翻譯", "译者", "譯者"]
	for keyword in metadata_keywords:
		if text.contains(keyword):
			return true
	return false

func _extract_artist_info(text: String) -> String:
	"""从元数据行提取艺术家信息（作词/作曲/编曲/演唱）"""
	# 定义要提取的标签及其优先级（演唱 > 作词/作曲）
	var artist_keywords = {
		"演唱": "演唱",
		"歌手": "演唱", 
		"主唱": "主唱",
		"vocal": "vocal",
		"Vocal": "vocal",
		"作词": "作词",
		"作詞": "作词",
		"填词": "填词",
		"填詞": "填词",
		"作曲": "作曲",
		"编曲": "编曲",
		"編曲": "编曲"
	}
	
	for keyword in artist_keywords.keys():
		if text.contains(keyword):
			# 提取冒号/分号后的内容作为艺术家名
			var separators = ["：", ":", "／", "/", "　"]
			for sep in separators:
				var idx = text.find(sep)
				if idx >= 0:
					var artist_name = text.substr(idx + 1).strip_edges()
					if not artist_name.is_empty():
						var label = artist_keywords[keyword]
						return label + ": " + artist_name
			# 如果没有分隔符，返回整行
			return text
	
	return ""

func _is_mostly_chinese(text: String) -> bool:
	"""检测文本是否主要是中文"""
	var chinese_count = 0
	var japanese_kana_count = 0
	var total_cjk = 0
	
	for i in range(text.length()):
		var code = text.unicode_at(i)
		# CJK统一汉字范围 (0x4E00-0x9FFF)
		if code >= 0x4E00 and code <= 0x9FFF:
			total_cjk += 1
			chinese_count += 1  # 先假设是中文
		# 平假名范围 (0x3040-0x309F)
		elif code >= 0x3040 and code <= 0x309F:
			japanese_kana_count += 1
		# 片假名范围 (0x30A0-0x30FF)
		elif code >= 0x30A0 and code <= 0x30FF:
			japanese_kana_count += 1
	
	# 如果有假名，肯定是日文
	if japanese_kana_count > 0:
		return false
	# 如果全是汉字且没有假名，可能是中文翻译
	if total_cjk > 0 and japanese_kana_count == 0:
		return true
	return false

func _is_punctuation(char: String) -> bool:
	"""检查是否是标点符号"""
	var punctuations = ["?", "!", ",", ".", "。", "，", "？", "！", "、", "：", ":", 
						";", "；", "(", ")", "（", "）", "~", "～", "-", "—", "―", "─", "━",
						"ー", "－", "‐", "‑", "‒", "–", "_", "＿",  # 各种横杠/破折号/长音符
						"'", '"', "「", "」", "『", "』", "…", "•", "·", "◆", "◇", "●", "○", 
						"※", "▶", "▲", "▼", "→", "←", "↑", "↓", " ", "　", "/", "\\", 
						"@", "#", "$", "%", "^", "&", "*", "+", "=", "[", "]", "{", "}", 
						"<", ">", "|", "`", "♪", "♫", "★", "☆", "♥", "♡"]
	return char in punctuations

func _is_alphanumeric(code: int) -> bool:
	"""检查是否是英文字母或数字"""
	# 数字 0-9
	if code >= 0x30 and code <= 0x39:
		return true
	# 大写字母 A-Z
	if code >= 0x41 and code <= 0x5A:
		return true
	# 小写字母 a-z
	if code >= 0x61 and code <= 0x7A:
		return true
	# 全角数字 ０-９
	if code >= 0xFF10 and code <= 0xFF19:
		return true
	# 全角大写字母 Ａ-Ｚ
	if code >= 0xFF21 and code <= 0xFF3A:
		return true
	# 全角小写字母 ａ-ｚ
	if code >= 0xFF41 and code <= 0xFF5A:
		return true
	return false

func _get_word_breaks(text: String) -> Array:
	"""智能断词 - 根据语言特性分割词语"""
	var words = []
	
	# 首先按空格分割（用于有明确空格分隔的歌词）
	var space_parts = text.split(" ", false)
	
	for part in space_parts:
		if part.is_empty():
			continue
		
		# 对每个部分进行智能断词
		var sub_words = _segment_japanese_text(part)
		words.append_array(sub_words)
	
	return words

func _segment_japanese_text(text: String) -> Array:
	"""日语文本分词
	策略：
	1. 检测平假名/片假名/汉字的边界
	2. 连续的平假名视为一个词（助词、助动词）
	3. 汉字+跟随的平假名视为一个词（汉字词干+假名活用）
	4. 片假名序列视为外来词
	"""
	var segments = []
	var current_segment = ""
	var current_type = ""  # "kanji", "hiragana", "katakana", "other"
	
	for i in range(text.length()):
		var char = text[i]
		var code = text.unicode_at(i)
		
		# 跳过无效的Unicode字符（代理对等）
		if code >= 0xD800 and code <= 0xDFFF:
			# 这是代理对，跳过
			continue
		if code == 0 or code > 0x10FFFF:
			# 无效的Unicode码点
			continue
		
		var char_type = _get_char_type(code)
		
		# 跳过标点
		if _is_punctuation(char):
			if not current_segment.is_empty():
				segments.append(current_segment)
				current_segment = ""
				current_type = ""
			continue
		
		if current_type.is_empty():
			# 开始新段
			current_segment = char
			current_type = char_type
		elif char_type == current_type:
			# 同类型字符，继续累积
			current_segment += char
		elif current_type == "kanji" and char_type == "hiragana":
			# 汉字后跟平假名：可能是送假名，继续累积
			current_segment += char
			# 但如果平假名太长（超过4个），可能是新词
			var hiragana_count = 0
			for j in range(current_segment.length()):
				var c = current_segment.unicode_at(j)
				if c >= 0x3040 and c <= 0x309F:
					hiragana_count += 1
			if hiragana_count > 4:
				# 可能是助词，分开
				segments.append(current_segment)
				current_segment = ""
				current_type = ""
		elif current_type == "hiragana" and char_type == "kanji":
			# 平假名后接汉字：新词开始
			segments.append(current_segment)
			current_segment = char
			current_type = char_type
		elif current_type == "katakana" and char_type != "katakana":
			# 片假名结束
			segments.append(current_segment)
			current_segment = char
			current_type = char_type
		elif char_type == "katakana" and current_type != "katakana":
			# 片假名开始
			if not current_segment.is_empty():
				segments.append(current_segment)
			current_segment = char
			current_type = char_type
		else:
			# 其他情况：不同类型，分开
			if not current_segment.is_empty():
				segments.append(current_segment)
			current_segment = char
			current_type = char_type
	
	# 添加最后一个段
	if not current_segment.is_empty():
		segments.append(current_segment)
	
	# 后处理：合并过短的段（小于2字符的平假名可能是助词，与前词合并）
	var final_segments = []
	for seg in segments:
		if final_segments.size() > 0 and seg.length() <= 2:
			# 检查是否是常见助词
			if _is_common_particle(seg):
				# 助词可以独立，也可以与前词合并
				# 这里选择独立，保持词的完整性
				final_segments.append(seg)
			else:
				final_segments.append(seg)
		else:
			final_segments.append(seg)
	
	return final_segments

func _get_char_type(code: int) -> String:
	"""获取字符类型"""
	# 平假名 (0x3040-0x309F)
	if code >= 0x3040 and code <= 0x309F:
		return "hiragana"
	# 片假名 (0x30A0-0x30FF)
	if code >= 0x30A0 and code <= 0x30FF:
		return "katakana"
	# 片假名扩展 (0x31F0-0x31FF)
	if code >= 0x31F0 and code <= 0x31FF:
		return "katakana"
	# CJK统一汉字 (0x4E00-0x9FFF)
	if code >= 0x4E00 and code <= 0x9FFF:
		return "kanji"
	# 其他
	return "other"

func _is_common_particle(text: String) -> bool:
	"""检查是否是常见日语助词"""
	var particles = ["は", "が", "を", "に", "で", "と", "の", "へ", "から", "まで", 
					 "より", "ね", "よ", "な", "か", "も", "だ", "です", "ます"]
	return text in particles

func _get_next_piece_fallback(current_index: int) -> Dictionary:
	"""GDScript降级实现 - 方块生成（智能断词版）"""
	# 跳过换行符
	while current_index < cached_lyric_blocks.size() and \
		  cached_lyric_blocks[current_index] == "\n":
		current_index += 1
	
	var remaining_chars = cached_lyric_blocks.size() - current_index
	
	if remaining_chars <= 0:
		return {"shape": "", "size": 0, "chars": [], "new_index": current_index}
	
	# 收集当前句子的所有非换行字符，并记录词语边界
	var sentence_chars = []
	var word_boundaries = []  # 记录词语结束位置（\n之前的位置）
	
	for i in range(remaining_chars):
		var char = cached_lyric_blocks[current_index + i]
		if char == "\n":
			# 记录词语边界
			if sentence_chars.size() > 0:
				word_boundaries.append(sentence_chars.size())
			# 检测句子结束（连续\n或句末\n）
			if i + 1 < remaining_chars:
				var next_char = cached_lyric_blocks[current_index + i + 1]
				if next_char == "\n":
					break  # 连续\n，句子结束
			else:
				break  # 到达末尾
		else:
			sentence_chars.append(char)
	
	var sentence_length = sentence_chars.size()
	if sentence_length == 0:
		return {"shape": "", "size": 0, "chars": [], "new_index": current_index + 1}
	
	# 智能选择方块大小
	var piece_size = _select_piece_size_smart(sentence_length, word_boundaries)
	
	# 选择形状
	var shape = _select_shape_fallback(piece_size)
	
	# 提取实际字符
	var chars = []
	var actual_piece_size = min(piece_size, sentence_chars.size())
	for i in range(actual_piece_size):
		chars.append(sentence_chars[i])
	
	# 计算新索引：跳过已使用的字符和对应的\n
	var temp_index = current_index
	var chars_counted = 0
	while chars_counted < actual_piece_size and temp_index < cached_lyric_blocks.size():
		if cached_lyric_blocks[temp_index] != "\n":
			chars_counted += 1
		temp_index += 1
	
	print("[方块生成] 形状:", shape, " 格数:", piece_size, " 字符:", chars, " 词边界:", word_boundaries)
	
	return {
		"shape": shape,
		"size": piece_size,
		"chars": chars,
		"new_index": temp_index,
		"sentence_length": sentence_length
	}

func _select_piece_size_smart(sentence_length: int, word_boundaries: Array) -> int:
	"""智能选择方块大小
	策略：
	1. 短句（<=7字符）：尽量按词语边界断开，或整句
	2. 长句：按概率选择目标大小，然后找最近的词语边界
	3. 保持方块比例：75%生成4格，22%生成5格，2.6%生成6格，0.4%生成7格
	"""
	
	if sentence_length <= 3:
		# 很短的句子，直接使用全部
		return sentence_length
	
	if sentence_length <= 7:
		# 短句：优先按词语边界断开
		if word_boundaries.size() > 0:
			# 找一个合适的边界点
			for boundary in word_boundaries:
				if boundary >= 3 and boundary <= sentence_length:
					return boundary
		# 没有合适边界，使用整句
		return sentence_length
	
	# 长句：按概率选择目标大小
	var rand = randi() % 1000
	var target_size: int
	if rand < 750:
		target_size = 4  # 75%
	elif rand < 970:
		target_size = 5  # 22%
	elif rand < 996:
		target_size = 6  # 2.6%
	else:
		target_size = 7  # 0.4%
	
	# 如果有词语边界，尝试找最近的边界
	if word_boundaries.size() > 0:
		var best_boundary = -1
		var min_diff = 999
		
		for boundary in word_boundaries:
			# 边界必须在合理范围内（2-7）
			if boundary < 2 or boundary > 7:
				continue
			
			var diff = abs(boundary - target_size)
			if diff < min_diff:
				min_diff = diff
				best_boundary = boundary
		
		# 如果找到合适的边界，且偏差不超过2，使用边界
		if best_boundary > 0 and min_diff <= 2:
			return best_boundary
		
		# 如果目标大小小于最小边界，考虑合并词语
		if word_boundaries.size() > 0 and word_boundaries[0] > target_size:
			# 第一个词就比目标大，使用第一个词
			if word_boundaries[0] <= 7:
				return word_boundaries[0]
	
	# 没有合适边界或偏差太大，使用目标大小（但不超过句子长度和7）
	return min(target_size, min(sentence_length, 7))

func _select_shape_fallback(size: int) -> String:
	"""根据大小选择形状"""
	var shape_map = {
		1: ["DOT"],
		2: ["I2"],
		3: ["I3", "L3"],  # 添加L3小L形状
		4: ["I", "O", "T", "S", "Z", "J", "L"],
		5: ["I5", "PLUS", "T5", "L5", "L5R"],  # 添加I5和5格变体
		6: ["I6", "L6", "RECT"],  # 添加I6和6格形状
		7: ["I7", "T7", "BIG_T"]  # 添加I7和7格形状
	}
	
	if size > 7:
		size = 7
	elif size < 1:
		size = 1
	
	var shapes = shape_map.get(size, ["DOT"])
	return shapes[randi() % shapes.size()]

func _predict_next_fallback(current_index: int) -> String:
	"""预测下一个方块形状"""
	var next_start = current_index
	while next_start < cached_lyric_blocks.size() and \
		  (cached_lyric_blocks[next_start] == "\n" or \
		   cached_lyric_blocks[next_start] == " "):
		next_start += 1
	
	if next_start >= cached_lyric_blocks.size():
		return ""
	
	var next_sentence_end = next_start
	for i in range(cached_lyric_blocks.size() - next_start):
		var char = cached_lyric_blocks[next_start + i]
		if char == "\n":
			next_sentence_end = next_start + i
			break
		next_sentence_end = next_start + i + 1
	
	var next_sentence_len = next_sentence_end - next_start
	
	var next_size = 4
	if next_sentence_len <= 6:
		next_size = next_sentence_len
	else:
		var rand = randi() % 100
		if rand < 60:
			next_size = 4
		elif rand < 85:
			next_size = 5
		else:
			next_size = 6
	
	return _select_shape_fallback(next_size)
