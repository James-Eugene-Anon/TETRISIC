extends Node
# Python桥接器 - 连接GDScript和Python歌词处理模块

class_name LyricPythonBridge

var use_python = true  # 是否使用Python处理（默认关闭以避免平台外部调用导致的窗口闪烁）
var python_path = "python"  # Python解释器路径
var script_path = "res://Systems/Audio/lyric_processor.py"

# 缓存数据
var cached_lyrics = []
var cached_lyric_blocks = []
var cached_line_starts = []  # 每行歌词在lyric_blocks中的起始索引
var is_chinese_song = false  # 标记整首歌是否是中文歌曲

# 常见间奏/纯音乐标识（仅当整行是标识时才过滤）
var INTERLUDE_KEYWORDS = [
	"music",
	"instrumental",
	"intro",
	"interlude",
	"bridge",
	"solo",
	"break"
]

var CREDIT_KEYWORDS = [
	"作词", "作曲", "作詞", "作曲", "词曲", "詞曲",
	"作词作曲", "作曲作词", "编曲", "編曲",
	"演唱", "歌手", "原唱", "原作"
]

func parse_lrc_file(file_path: String) -> Dictionary:
	# 解析LRC文件
	# 优先尝试Python解析，失败则降级到GDScript
	var result = {}
	
	if use_python:
		# 将 res:// 路径转换为全局文件系统路径供 Python 使用
		var global_path = file_path
		if file_path.begins_with("res://"):
			global_path = ProjectSettings.globalize_path(file_path)
		result = _call_python_cli("parse_lrc", {"file_path": global_path})
	
	if not use_python or result.has("error") or result.get("lyrics", []).is_empty():
		if use_python and result.has("error"):
			print("[Python解析失败] ", result.get("error"), " -> 尝试GDScript降级解析")
		else:
			print("[Python解析] 结果为空或未启用 -> 尝试GDScript降级解析")
		
		# 降级到GDScript实现
		result = _parse_lrc_fallback(file_path)
	
	cached_lyrics = result.get("lyrics", [])
	cached_lyric_blocks = result.get("lyric_blocks", [])
	cached_line_starts = result.get("line_starts", [])
	is_chinese_song = result.get("is_chinese_song", false)
	return result

func get_next_piece_info(current_index: int) -> Dictionary:
	# 方块生成统一在GDScript侧，避免与Python重复
	if cached_lyric_blocks.is_empty():
		return {"shape": "", "size": 0, "chars": [], "new_index": current_index, "sentence_length": 0}
	return _get_next_piece_from_cache(current_index)

func predict_next_shape(current_index: int) -> String:
	if cached_lyric_blocks.is_empty():
		return ""
	return _predict_next_from_cache(current_index)

# ============ 内部实现 ============

func _empty_result(error_code: String) -> Dictionary:
	cached_lyrics = []
	cached_lyric_blocks = []
	cached_line_starts = []
	is_chinese_song = false
	return {
		"lyrics": [],
		"total_chars": 0,
		"lyric_blocks": [],
		"line_starts": [],
		"is_chinese_song": false,
		"extracted_artist": "",
		"error": error_code
	}

func _call_python_cli(function: String, params: Dictionary) -> Dictionary:
	# 通过命令行调用Python脚本
	# 为避免Windows命令行参数编码问题，将JSON写入临时文件
	var json_params = JSON.stringify(params)
	var script_global = script_path.replace("res://", ProjectSettings.globalize_path("res://"))
	# 检查脚本文件是否存在（兼容 Godot 4）
	if not FileAccess.file_exists(script_global):
		return {"error": "脚本未找到: " + script_global}

	# 创建临时参数文件
	var temp_dir = OS.get_user_data_dir()
	var temp_param_file = temp_dir.path_join("_lrc_params.json")
	var param_file = FileAccess.open(temp_param_file, FileAccess.WRITE)
	if param_file == null:
		return {"error": "无法创建临时参数文件"}
	param_file.store_string(json_params)
	param_file.close()

	var json = JSON.new()
	# 在 Windows/不同环境下尝试多个可执行名
	var candidates = [python_path, "python", "python3", "py"]
	var last_err_output = ""
	for exe in candidates:
		if exe == null or exe == "":
			continue
		# 使用 --params-file 传递参数文件路径
		var cmd_args = [script_global, function, "--params-file", temp_param_file]
		var output = []
		# read_stderr=true 以便捕获错误信息用于调试
		var exit_code = OS.execute(exe, cmd_args, output, true, true)
		if exit_code != 0:
			# 合并 stderr/输出行以便调试
			var _builder = ""
			for _ln in output:
				_builder += str(_ln) + "\n"
			last_err_output = _builder.strip_edges()
			# 尝试下一个可执行文件
			continue
		if output.is_empty():
			return {"error": "Python无输出"}
		# 合并可能的多行输出为单一字符串再解析
		var full_output = ""
		for _ln in output:
			full_output += str(_ln) + "\n"
		full_output = full_output.strip_edges()
		var parse_result = json.parse(full_output)
		if parse_result != OK:
			# 记下原始输出便于排查
			return {"error": "JSON解析失败: " + full_output}
		return json.get_data()

	# 如果所有候选可执行文件都失败，返回最后的错误输出
	if last_err_output != "":
		return {"error": "Python执行失败,输出: " + last_err_output}
	return {"error": "无法执行Python解析器"}

# ============ GDScript降级实现 ============

func _parse_lrc_fallback(file_path: String) -> Dictionary:
	# GDScript降级实现 - LRC解析
	var lyrics = []
	var lyric_blocks = []
	var extracted_artists = []  # 从元数据行提取的艺术家信息
	
	# 支持 res:// 路径（转换为实际文件系统路径）
	var real_path = file_path
	if real_path.begins_with("res://"):
		real_path = ProjectSettings.globalize_path(real_path)

	var file = FileAccess.open(real_path, FileAccess.READ)
	if file == null:
		print("无法打开LRC文件: ", real_path, " (原路径:", file_path, ")")
		return {"lyrics": [], "total_chars": 0, "lyric_blocks": [], "extracted_artist": "", "is_chinese_song": false}

	var pattern = RegEx.new()
	pattern.compile("\\[(\\d+):(\\d+\\.\\d+)\\](.+)")

	# 元数据标签正则
	var metadata_pattern = RegEx.new()
	metadata_pattern.compile("^\\[(ar|ti|al|by|offset|tool|ve|re):")

	# 读取所有行（使用 eof 检测，兼容备份实现）
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
	
	# 简短调试：打印前 20 行的匹配情况（帮助排查解析问题）
	for li in range(min(all_lines.size(), 20)):
		var debug_line = all_lines[li]
		var m = pattern.search(debug_line)
		if m:
			print("[LRC调试] 第", li, "行 匹配时间戳 ->", debug_line)
		else:
			if metadata_pattern.search(debug_line):
				print("[LRC调试] 第", li, "行 元数据行 ->", debug_line)
			else:
				print("[LRC调试] 第", li, "行 未匹配 ->", debug_line)

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
				print("[LRC调试] 时间:", time, " 行被识别为艺术家信息 ->", text)
				continue  # 仍然从歌词中过滤掉

			# 过滤空文本
			if text.is_empty():
				print("[LRC调试] 时间:", time, " 行为空，跳过")
				continue

			# 检测语言并分类
			if seen_times.has(time):
				# 相同时间戳第二次出现，视为翻译
				if _is_translation_credit(text):
					print("[LRC调试] 时间:", time, " 行被识别为翻译署名/信用，跳过 ->", text)
					continue
				if _is_interlude_marker(text):
					print("[LRC调试] 时间:", time, " 行被识别为间奏标记，跳过 ->", text)
					continue
				if _is_credit_line(text):
					print("[LRC调试] 时间:", time, " 行被识别为信用行，跳过 ->", text)
					continue
				chinese_lyrics[time] = text
				chinese_line_count += 1
				print("[LRC调试] 时间:", time, " 作为 翻译 添加 ->", text)
			else:
				# 第一次出现的时间戳
				seen_times[time] = true
				# 先检查是否是元数据/间奏/署名行（所有语言通用）
				if _is_interlude_marker(text) or _is_credit_line(text) or _is_translation_credit(text):
					print("[LRC调试] 时间:", time, " 行被识别为元数据/间奏/信用，跳过 ->", text)
					continue
				# 检测是否主要是中文（CJK统一汉字范围，无假名）
				if _is_mostly_chinese(text):
					chinese_lyrics[time] = text
					chinese_line_count += 1
					print("[LRC调试] 时间:", time, " 作为 中文 主歌词 添加 ->", text)
				else:
					# 英文/日文/其他语言都作为主歌词
					japanese_lyrics[time] = text
					japanese_line_count += 1
					print("[LRC调试] 时间:", time, " 作为 主歌词(英语/日语/其他) 添加 ->", text)
	
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

	# 如果在复杂分类逻辑下没有解析到任何行，尝试简单回退解析：将所有带时间戳的行直接作为主歌词（去掉翻译前缀/斜杠）
	if japanese_lyrics.keys().size() == 0 and chinese_lyrics.keys().size() == 0:
		print("[LRC回退] 复杂解析未识别到歌词行，尝试简单回退解析所有时间戳行")
		for line in all_lines:
			if metadata_pattern.search(line):
				continue
			var m = pattern.search(line)
			if m:
				var min = int(m.get_string(1))
				var sec = float(m.get_string(2))
				var txt = m.get_string(3).strip_edges()
				# 去掉翻译前缀如 "/"
				if txt.begins_with("/"):
					txt = txt.substr(1).strip_edges()
				var t = min * 60 + sec
				japanese_lyrics[t] = txt
				japanese_line_count += 1

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
	var line_starts = []  # 记录每行歌词在lyric_blocks中的起始索引
	for lyric_line in lyrics:
		line_starts.append(lyric_blocks.size())  # 记录本行起始位置
		var japanese = lyric_line.japanese
		# 英文句子切分（避免跨句分词）
		var sentences = _split_english_sentences(japanese)
		
		for s_idx in range(sentences.size()):
			var sentence = sentences[s_idx]
			# 使用智能断词
			var word_breaks = _get_word_breaks(sentence)
			
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
			# 句子结束加\n
			if not sentence.is_empty():
				lyric_blocks.append("\n")
				# 添加额外换行符作为句子强分隔
				lyric_blocks.append("\n")
	
	cached_lyrics = lyrics
	cached_lyric_blocks = lyric_blocks
	cached_line_starts = line_starts
	
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
		"line_starts": line_starts,
		"extracted_artist": extracted_artist,
		"is_chinese_song": is_chinese_song
	}

func _is_metadata_line(text: String) -> bool:
	# 检查是否是元数据行（仅在行首匹配，或关键词后紧跟分隔符）
	# 避免误删歌词内容中包含关键词的行
	var t = text.strip_edges()
	
	# 关键词+分隔符模式（如"作词：xxx"、"作曲:xxx"）
	var metadata_patterns = [
		"作词", "作曲", "编曲", "混音", "制作人", "填词", "监制",
		"翻译", "翻譯", "译者", "譯者", "演唱", "歌手"
	]
	var separators = ["：", ":", "／", "/", "　", " "]
	
	for keyword in metadata_patterns:
		# 必须在行首（或只有空白在前面）
		var idx = t.find(keyword)
		if idx == 0 or (idx > 0 and idx <= 2 and t.substr(0, idx).strip_edges().is_empty()):
			# 关键词后必须紧跟分隔符或结尾
			var after_keyword = t.substr(idx + keyword.length())
			if after_keyword.is_empty():
				return true
			for sep in separators:
				if after_keyword.begins_with(sep):
					return true
	
	# "by." 系列检查（必须在行首）
	var by_patterns = ["by.", "By.", "BY.", "by:", "By:", "BY:"]
	for pattern in by_patterns:
		if t.begins_with(pattern):
			return true
	
	return false

func _extract_artist_info(text: String) -> String:
	# 从元数据行提取艺术家信息（作词/作曲/编曲/演唱）
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
	# 检测文本是否主要是中文
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

func _normalize_marker_text(text: String) -> String:
	# 恢复旧版本简单逻辑：仅移除首尾括号
	var t = text.strip_edges()
	var re = RegEx.new()
	re.compile("^[\\[\\(（【<]+")
	t = re.sub(t, "", true)
	re.compile("[\\]\\)）】>]+$")
	t = re.sub(t, "", true)
	return t.strip_edges()

func _has_kana_or_hanzi(text: String) -> bool:
	for i in range(text.length()):
		var code = text.unicode_at(i)
		# 平假名 (0x3040-0x309F)
		if code >= 0x3040 and code <= 0x309F: return true
		# 片假名 (0x30A0-0x30FF)
		if code >= 0x30A0 and code <= 0x30FF: return true
		# CJK统一汉字 (0x4E00-0x9FFF)
		if code >= 0x4E00 and code <= 0x9FFF: return true
	return false

func _is_interlude_marker(text: String) -> bool:
	# 恢复旧版本的严格逻辑
	var t = _normalize_marker_text(text)
	# 纯空或只包含标点/括号的视为间奏标记
	if t.is_empty():
		return true
	# 超过15个字符就绝不是间奏标签（间奏标签通常很短如 "intro" "solo"）
	if t.length() > 15:
		return false
	# 必须全是英文字母/空格，且完全匹配关键词列表
	var re = RegEx.new()
	re.compile("^[A-Za-z ]+$")
	if re.search(t) and INTERLUDE_KEYWORDS.has(t.to_lower()):
		return true
	return false

func _is_translation_credit(text: String) -> bool:
	var t = text.strip_edges()
	if t.length() > 40:
		return false
	var lower = t.to_lower()
	var has_keyword = t.find("翻译") >= 0 or t.find("翻譯") >= 0 or t.find("译") >= 0 or lower.find("translation") >= 0 or lower.find("translator") >= 0
	if not has_keyword:
		return false
	var looks_like_credit = t.find(":") >= 0 or t.find("：") >= 0 or lower.find(" by ") >= 0 or t.begins_with("-") or t.begins_with("—") or t.begins_with("–") or t.begins_with("【") or t.begins_with("[") or t.begins_with("(") or t.begins_with("（")
	return looks_like_credit

func _is_credit_line(text: String) -> bool:
	var t = text.strip_edges()
	if t.length() > 40:
		return false
	if t.find(":") < 0 and t.find("：") < 0 and t.find("/") < 0 and t.find("／") < 0:
		return false
	for kw in CREDIT_KEYWORDS:
		if t.begins_with(kw):
			return true
	for kw in CREDIT_KEYWORDS:
		var idx = t.find(kw)
		if idx >= 0 and idx <= 2:
			return true
	return false

# ============ 方块生成 ============

func _get_next_piece_from_cache(current_index: int) -> Dictionary:
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
	
	# 防止单格方块：如果句子只有1个块但该块包含2+字符（合并的英数对如"OK"），拆分回单字符
	if sentence_length == 1 and sentence_chars[0].length() >= 2:
		var merged = sentence_chars[0]
		sentence_chars = []
		for ci in range(merged.length()):
			sentence_chars.append(merged[ci])
		sentence_length = sentence_chars.size()
	
	# 绝对禁止单格方块（DOT）：如果句子只有1个字符，从下一个句子借一个字符合并
	if sentence_length == 1:
		# 找到当前单字符在cached_lyric_blocks中的结束位置
		var scan_pos = current_index
		var found_chars = 0
		while scan_pos < cached_lyric_blocks.size() and found_chars < 1:
			if cached_lyric_blocks[scan_pos] != "\n":
				found_chars += 1
			scan_pos += 1
		# 跳过分隔符\n
		while scan_pos < cached_lyric_blocks.size() and cached_lyric_blocks[scan_pos] == "\n":
			scan_pos += 1
		# 从下一句借一个字符
		if scan_pos < cached_lyric_blocks.size() and cached_lyric_blocks[scan_pos] != "\n":
			sentence_chars.append(cached_lyric_blocks[scan_pos])
			sentence_length = 2
			print("[单格合并] 将单字符'", sentence_chars[0], "'与下一句'", sentence_chars[1], "'合并为I2")
		else:
			# 完全没有下一个字符（歌曲最后一个字），填充♪符号
			sentence_chars.append("♪")
			sentence_length = 2
			print("[单格合并] 歌曲末尾单字符'", sentence_chars[0], "'填充♪合并为I2")
	
	# 智能选择方块大小
	var piece_size = _select_piece_size_smart(sentence_length, word_boundaries)

	# 1格方块绝对禁止：强制最小为2格
	if piece_size == 1:
		piece_size = 2
	
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
	# 智能选择方块大小
	# 策略：
	# 1. 保证在词语边界切割，绝不切断单词
	# 2. 短句（<=7字符）：优先选择较大的词语组合，略微降低小方块概率
	# 3. 长句：按概率选择目标大小，然后找最近的词语边界
	
	if sentence_length <= 3:
		# 很短的句子，直接使用全部
		return sentence_length
	
	if sentence_length <= 7:
		# 短句：按词语边界切割，倾向于选择较大组合
		if word_boundaries.size() > 0:
			# 找到最大的可用边界（不超过句子长度）
			var max_boundary = -1
			for b in word_boundaries:
				if b <= sentence_length and b > max_boundary:
					max_boundary = b
			
			if max_boundary > 0:
				# 略微降低小方块的生成概率：
				# 2格方块：4.5%概率改用更大组合（如整句）
				# 3格方块：1.2%概率改用更大组合
				if max_boundary == 2 and randf() < 0.045:
					# 尝试找更大的组合，如果没有就用整句
					return sentence_length
				elif max_boundary == 3 and randf() < 0.012:
					return sentence_length
				else:
					return max_boundary
		
		# 没有词语边界，使用整句
		return sentence_length
	
	# 长句（>7格）：随机选择目标大小，然后在词语边界中找最接近的
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
	
	# 如果有词语边界，找最接近target的边界
	if word_boundaries.size() > 0:
		var best_boundary = -1
		var min_diff = 999
		
		for boundary in word_boundaries:
			# 只考虑合理范围的边界（2-7格）
			if boundary < 2 or boundary > 7:
				continue
			
			var diff = abs(boundary - target_size)
			
			# 对于小边界，增加一点"惩罚"（使其不太容易被选中）
			if boundary == 2:
				diff += 0.5  # 略微增加偏差，降低被选中概率
			elif boundary == 3:
				diff += 0.15
			
			if diff < min_diff:
				min_diff = diff
				best_boundary = boundary
		
		# 如果找到合适的边界（考虑了惩罚后的偏差），使用边界
		if best_boundary > 0 and min_diff <= 2.5:
			return best_boundary
		
		# 如果第一个词就比目标大，考虑使用它
		if word_boundaries.size() > 0 and word_boundaries[0] > target_size and word_boundaries[0] <= 7:
			return word_boundaries[0]
	
	# 没有合适边界，使用目标大小（但不超过句子长度和7）
	return min(target_size, min(sentence_length, 7))

func _select_shape_fallback(size: int) -> String:
	# 根据大小选择形状
	var shape_map = {
		1: ["I2"],  # 单格方块已禁止，安全回退为I2
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
	var selected = shapes[randi() % shapes.size()]
	
	# 额外降低PLUS方块概率（0.3%概率重新随机）
	if selected == "PLUS" and randf() < 0.003:
		var non_plus = shapes.filter(func(s): return s != "PLUS")
		if non_plus.size() > 0:
			selected = non_plus[randi() % non_plus.size()]
	
	return selected

func _predict_next_from_cache(current_index: int) -> String:
	# 预测下一个方块形状
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
		if next_size == 1 and next_sentence_len >= 2:
			next_size = 2
	else:
		var rand = randi() % 100
		if rand < 60:
			next_size = 4
		elif rand < 85:
			next_size = 5
		else:
			next_size = 6
	
	return _select_shape_fallback(next_size)

func _is_punctuation(char: String) -> bool:
	# 检查是否是标点符号
	var punctuations = ["?", "!", ",", ".", "。", "，", "？", "！", "、", "：", ":", 
						";", "；", "(", ")", "（", "）", "~", "～", "-", "—", "―", "─", "━",
						"ー", "－", "‐", "‑", "‒", "–", "_", "＿",  # 各种横杠/破折号/长音符
						"'", '"', "「", "」", "『", "』", "…", "•", "·", "◆", "◇", "●", "○", 
						"※", "▶", "▲", "▼", "→", "←", "↑", "↓", " ", "　", "/", "\\", 
						"@", "#", "$", "%", "^", "&", "*", "+", "=", "[", "]", "{", "}", 
						"<", ">", "|", "`", "♪", "♫", "★", "☆", "♥", "♡"]
	return char in punctuations

func _is_alphanumeric(code: int) -> bool:
	# 检查是否是英文字母或数字
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
	# 智能断词 - 根据语言特性分割词语
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
	# 日语文本分词
	# 策略：
	# 1. 检测平假名/片假名/汉字的边界
	# 2. 连续的平假名视为一个词（助词、助动词）
	# 3. 汉字+跟随的平假名视为一个词（汉字词干+假名活用）
	# 4. 片假名序列视为外来词
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
	# 获取字符类型
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
	# 检查是否是常见日语助词
	var particles = ["は", "が", "を", "に", "で", "と", "の", "へ", "から", "まで", 
					 "より", "ね", "よ", "な", "か", "も", "だ", "です", "ます"]
	return text in particles

func _has_english_letters(text: String) -> bool:
	for i in range(text.length()):
		var code = text.unicode_at(i)
		if (code >= 0x41 and code <= 0x5A) or (code >= 0x61 and code <= 0x7A):
			return true
	return false

func _split_english_sentences(text: String) -> Array:
	# 英文句子切分，避免跨句生成方块
	if text.is_empty():
		return []
	if not _has_english_letters(text):
		return [text]
	
	var re = RegEx.new()
	re.compile("[.!?]+\\s+")
	var trimmed = text.strip_edges()
	var matches = re.search_all(trimmed)
	var result: Array = []
	var last_index = 0
	for m in matches:
		var start_idx = m.get_start()
		if start_idx > last_index:
			var part = trimmed.substr(last_index, start_idx - last_index)
			var cleaned = part.strip_edges()
			if cleaned.ends_with(".") or cleaned.ends_with("!") or cleaned.ends_with("?"):
				cleaned = cleaned.substr(0, cleaned.length() - 1)
				cleaned = cleaned.strip_edges()
			if not cleaned.is_empty():
				result.append(cleaned)
		last_index = m.get_end()
	
	if last_index < trimmed.length():
		var tail = trimmed.substr(last_index)
		var cleaned_tail = tail.strip_edges()
		if cleaned_tail.ends_with(".") or cleaned_tail.ends_with("!") or cleaned_tail.ends_with("?"):
			cleaned_tail = cleaned_tail.substr(0, cleaned_tail.length() - 1)
			cleaned_tail = cleaned_tail.strip_edges()
		if not cleaned_tail.is_empty():
			result.append(cleaned_tail)
	
	if result.is_empty() and not trimmed.is_empty():
		result.append(trimmed)
	return result
