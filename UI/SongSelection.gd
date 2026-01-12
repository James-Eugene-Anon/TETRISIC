extends Control

@onready var title_label = $TitleLabel
@onready var song_list = $LeftPanel/VBox/ScrollContainer/SongList
@onready var refresh_button = $LeftPanel/VBox/RefreshButton
@onready var import_button = $LeftPanel/VBox/ImportButton
@onready var back_button = $LeftPanel/VBox/BackButton
@onready var bubble_container = $BubbleContainer
@onready var detail_panel = $BubbleContainer/RightPanel
@onready var bubble_arrow = $BubbleContainer/BubbleArrow
@onready var detail_song_name = $BubbleContainer/RightPanel/VBox/SongName
@onready var detail_artist = $BubbleContainer/RightPanel/VBox/ArtistLabel
@onready var detail_composer = $BubbleContainer/RightPanel/VBox/ComposerLabel
@onready var detail_album = $BubbleContainer/RightPanel/VBox/AlbumLabel
@onready var detail_high_score = $BubbleContainer/RightPanel/VBox/HighScoreLabel
@onready var search_lyric_button = $BubbleContainer/RightPanel/VBox/SearchLyricButton
@onready var start_button = $BubbleContainer/RightPanel/VBox/StartButton

var selected_song_index = -1
var song_buttons: Array = []
var lyric_service: MusicLyricAppIntegration

const TEXTS = {
	"zh": {
		"title": "选择歌曲",
		"refresh": "刷新歌曲列表",
		"import": "导入本地歌曲",
		"import_file": "导入文件",
		"import_folder": "导入文件夹",
		"back": "返回",
		"search_lyric": "搜索在线歌词",
		"searching": "搜索中...",
		"lyric_found": "已找到歌词",
		"lyric_not_found": "未找到歌词"
	},
	"en": {
		"title": "Select Song",
		"refresh": "Refresh Song List",
		"import": "Import Local Song",
		"import_file": "Import File",
		"import_folder": "Import Folder",
		"back": "Back",
		"search_lyric": "Search Online Lyrics",
		"searching": "Searching...",
		"lyric_found": "Lyrics Found",
		"lyric_not_found": "Lyrics Not Found"
	}
}

# 歌曲列表
var songs = []
var import_menu: PanelContainer
var import_file_btn: Button
var import_folder_btn: Button

func _ready():
	lyric_service = MusicLyricAppIntegration.new()
	add_child(lyric_service)
	
	# 设置 MusicLyricApp 路径（可以在 Global 中配置）
	var app_path = Global.get("music_lyric_app_path")
	if app_path:
		lyric_service.set_app_path(app_path)
	else:
		# 默认路径（可根据实际情况调整）
		lyric_service.set_app_path("d:/Desktop/工具图标/MusicLyricApp-v7.2-win-x64/MusicLyricApp-v7.2-win-x64.exe")
	
	_setup_import_menu() # 先初始化菜单，因为update_ui_texts需要用到它
	update_ui_texts()
	scan_songs()  # 自动扫描歌曲
	populate_song_list()
	bubble_container.visible = false  # 初始隐藏气泡
	refresh_button.pressed.connect(_on_refresh_button_pressed)
	import_button.pressed.connect(_on_import_button_pressed)
	back_button.pressed.connect(_on_back_button_pressed)
	start_button.pressed.connect(_on_start_button_pressed)
	search_lyric_button.pressed.connect(_on_search_lyric_button_pressed)

func _setup_import_menu():
	"""初始化自定义导入菜单"""
	import_menu = PanelContainer.new()
	import_menu.visible = false
	
	# 样式设置
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.1, 0.95)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(1, 1, 1, 0.5)
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_right = 5
	style.corner_radius_bottom_left = 5
	import_menu.add_theme_stylebox_override("panel", style)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 5)
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_top", 5)
	margin.add_theme_constant_override("margin_bottom", 5)
	margin.add_theme_constant_override("margin_left", 5)
	margin.add_theme_constant_override("margin_right", 5)
	
	import_file_btn = _create_menu_button("import_file")
	import_folder_btn = _create_menu_button("import_folder")
	
	import_file_btn.pressed.connect(func(): _on_import_menu_action(0))
	import_folder_btn.pressed.connect(func(): _on_import_menu_action(1))
	
	vbox.add_child(import_file_btn)
	vbox.add_child(import_folder_btn)
	margin.add_child(vbox)
	import_menu.add_child(margin)
	
	add_child(import_menu)

func _create_menu_button(text_key: String) -> Button:
	var btn = Button.new()
	btn.flat = true
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	var font = load("res://fonts/FUSION-PIXEL-12PX-MONOSPACED-ZH_HANS.OTF")
	btn.add_theme_font_override("font", font)
	btn.add_theme_font_size_override("font_size", 16)
	return btn

func scan_songs():
	"""自动扫描musics文件夹下的mp3文件和对应的lrc歌词文件"""
	songs.clear()
	
	# 扫描内置歌曲目录
	_scan_music_directory("res://musics/", "res://musics/lyrics/")
	
	# 扫描用户导入的歌曲目录
	var user_music_dir = OS.get_user_data_dir() + "/imported_songs/"
	var user_lyric_dir = OS.get_user_data_dir() + "/imported_songs/lyrics/"
	if DirAccess.dir_exists_absolute(user_music_dir):
		_scan_music_directory(user_music_dir, user_lyric_dir)
	
	# 按歌曲名排序
	songs.sort_custom(func(a, b): return a["name"] < b["name"])
	print("[歌曲扫描] 共找到 ", songs.size(), " 首歌曲")

func _scan_music_directory(music_dir: String, lyric_dir: String):
	"""扫描指定目录下的音乐文件"""
	var dir = DirAccess.open(music_dir)
	if not dir:
		return
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		# 只处理mp3/ogg文件（跳过.import文件）
		var is_audio = (file_name.ends_with(".mp3") or file_name.ends_with(".ogg")) and not file_name.ends_with(".import")
		if is_audio:
			var base_name = file_name.get_basename()
			
			# 尝试提取歌曲名和艺术家
			var artist = ""
			var song_name = base_name
			
			# 如果文件名包含 " - "，分离艺术家和歌名
			if " - " in base_name:
				var parts = base_name.split(" - ", false, 1)  # 只分割一次
				if parts.size() >= 2:
					artist = parts[0]
					song_name = parts[1]
			
			# 清理歌曲名（去除括号内容如 "(feat. xxx)"）
			var clean_song_name = song_name
			var paren_pos = clean_song_name.find("(")
			if paren_pos > 0:
				clean_song_name = clean_song_name.substr(0, paren_pos).strip_edges()
			
			# 查找对应的lrc文件（先尝试完整名，再尝试清理后的名）
			var lrc_file = lyric_dir + song_name + ".lrc"
			if not FileAccess.file_exists(lrc_file):
				lrc_file = lyric_dir + clean_song_name + ".lrc"
			if not FileAccess.file_exists(lrc_file):
				lrc_file = lyric_dir + base_name + ".lrc"
			
			# 即使没有LRC文件也添加歌曲
			var final_lrc_path = lrc_file if FileAccess.file_exists(lrc_file) else ""
			
			songs.append({
				"name": song_name,
				"display_name": clean_song_name,
				"artist": artist if artist != "" else "Unknown Artist",
				"music_file": music_dir + file_name,
				"lyric_file": final_lrc_path,
				"base_name": base_name  # 保存原始文件基础名，用于保存歌词
			})
			
			if final_lrc_path != "":
				print("[歌曲扫描] 找到: ", song_name, " -> ", final_lrc_path)
			else:
				print("[歌曲扫描] 未找到LRC: ", song_name, " (已添加无歌词版本)")
		
		file_name = dir.get_next()
	
	dir.list_dir_end()

func update_ui_texts():
	var texts = TEXTS[Global.current_language]
	title_label.text = texts["title"]
	refresh_button.text = texts["refresh"]
	import_button.text = texts["import"]
	back_button.text = texts["back"]
	search_lyric_button.text = texts["search_lyric"]
	
	if import_file_btn:
		import_file_btn.text = texts["import_file"]
	if import_folder_btn:
		import_folder_btn.text = texts["import_folder"]

func populate_song_list():
	# 清空现有项
	for child in song_list.get_children():
		child.queue_free()
	song_buttons.clear()
	
	# 添加歌曲按钮
	for i in range(songs.size()):
		var song = songs[i]
		var button = Button.new()
		button.text = song["name"] + "\n" + song["artist"]
		button.custom_minimum_size = Vector2(300, 60)
		
		# 加载字体
		var font = load("res://fonts/FUSION-PIXEL-12PX-MONOSPACED-ZH_HANS.OTF")
		button.add_theme_font_override("font", font)
		button.add_theme_font_size_override("font_size", 16)
		
		# 连接信号，使用lambda捕获索引
		var song_index = i
		button.pressed.connect(func(): _on_song_selected(song_index))
		
		song_list.add_child(button)
		song_buttons.append(button)

func _on_song_selected(index: int):
	selected_song_index = index
	var song = songs[index]
	
	# 从MP3文件读取元数据
	var mp3_metadata = parse_mp3_metadata(song["music_file"])
	
	# 解析歌词文件获取元数据（作为备用）
	var lrc_metadata = parse_lrc_metadata(song["lyric_file"])
	
	# 优先使用MP3元数据，如果不存在则使用LRC元数据
	var title = mp3_metadata.get("title", lrc_metadata.get("title", song["name"]))
	var artist = mp3_metadata.get("artist", lrc_metadata.get("artist", "Null"))
	var composer = lrc_metadata.get("composer", "Null")  # 作曲信息通常在LRC中
	var album = mp3_metadata.get("album", lrc_metadata.get("album", "Null"))
	
	# 更新详情面板
	detail_song_name.text = title
	detail_artist.text = "艺术家: " + artist
	detail_composer.text = "作曲: " + composer
	detail_album.text = "专辑: " + album
	
	# 获取最高分
	var high_score_data = Global.get_song_score(song["name"])
	detail_high_score.text = "最高分: %d (消除行数: %d)" % [high_score_data["score"], high_score_data["lines"]]
	
	# 检查是否有歌词，如果没有则显示搜索按钮
	if song["lyric_file"] == "":
		search_lyric_button.visible = true
		search_lyric_button.disabled = false
		search_lyric_button.text = TEXTS[Global.current_language]["search_lyric"]
	else:
		search_lyric_button.visible = false
	
	# 更新气泡箭头位置指向选中的按钮
	_update_bubble_position(index)
	
	# 显示气泡（带动画）
	_show_bubble()

func _update_bubble_position(index: int):
	"""更新气泡箭头位置，使其指向选中的按钮"""
	if index < song_buttons.size():
		var button = song_buttons[index]
		var button_center_y = button.global_position.y + button.size.y / 2
		var bubble_global_y = bubble_container.global_position.y
		var arrow_local_y = button_center_y - bubble_global_y
		
		# 更新箭头位置
		bubble_arrow.polygon = PackedVector2Array([
			Vector2(-20, arrow_local_y),
			Vector2(0, arrow_local_y - 15),
			Vector2(0, arrow_local_y + 15)
		])

func _show_bubble():
	"""显示气泡（带动画）"""
	if not bubble_container.visible:
		bubble_container.visible = true
		bubble_container.modulate.a = 0.0
		bubble_container.scale = Vector2(0.9, 0.9)
		
		var bubble_tween = create_tween()
		bubble_tween.set_parallel(true)
		bubble_tween.tween_property(bubble_container, "modulate:a", 1.0, 0.2).set_ease(Tween.EASE_OUT)
		bubble_tween.tween_property(bubble_container, "scale", Vector2(1.0, 1.0), 0.2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

func parse_mp3_metadata(file_path: String) -> Dictionary:
	"""从MP3文件读取元数据（ID3v2标签）"""
	var metadata = {}
	
	# 将 res:// 路径转换为实际文件路径
	var actual_path = ProjectSettings.globalize_path(file_path)
	
	var file = FileAccess.open(actual_path, FileAccess.READ)
	if not file:
		# 尝试直接使用原路径
		file = FileAccess.open(file_path, FileAccess.READ)
		if not file:
			print("[MP3解析] 无法打开文件: ", file_path)
			return metadata
	
	# 检查ID3v2标签
	var header = file.get_buffer(3)
	if header.get_string_from_utf8() == "ID3":
		# 读取版本和标志
		var version_major = file.get_8()
		var version_minor = file.get_8()
		var flags = file.get_8()
		
		# 读取标签大小（syncsafe integer）
		var size_bytes = file.get_buffer(4)
		var tag_size = (size_bytes[0] << 21) | (size_bytes[1] << 14) | (size_bytes[2] << 7) | size_bytes[3]
		
		print("[MP3解析] ID3v2.", version_major, ".", version_minor, " 标签大小: ", tag_size)
		
		# 解析帧
		var bytes_read = 0
		while bytes_read < tag_size - 10:
			if file.eof_reached():
				break
			
			# 读取帧ID（4字节）
			var frame_id_bytes = file.get_buffer(4)
			if frame_id_bytes.size() < 4:
				break
			var frame_id = frame_id_bytes.get_string_from_ascii()
			
			# 检查是否是填充（全0）
			if frame_id_bytes[0] == 0:
				break
			
			# 读取帧大小（4字节，ID3v2.4使用syncsafe，v2.3不使用）
			var frame_size_bytes = file.get_buffer(4)
			var frame_size: int
			if version_major >= 4:
				frame_size = (frame_size_bytes[0] << 21) | (frame_size_bytes[1] << 14) | (frame_size_bytes[2] << 7) | frame_size_bytes[3]
			else:
				frame_size = (frame_size_bytes[0] << 24) | (frame_size_bytes[1] << 16) | (frame_size_bytes[2] << 8) | frame_size_bytes[3]
			
			# 读取帧标志（2字节）
			file.get_buffer(2)
			
			bytes_read += 10
			
			if frame_size <= 0 or frame_size > tag_size:
				break
			
			# 读取帧数据
			var frame_data = file.get_buffer(frame_size)
			bytes_read += frame_size
			
			# 解析常见帧
			var text_value = _parse_id3_text_frame(frame_data)
			
			match frame_id:
				"TPE1":  # 艺术家
					if text_value != "":
						metadata["artist"] = text_value
				"TPE2":  # 专辑艺术家
					if text_value != "" and not metadata.has("artist"):
						metadata["artist"] = text_value
				"TALB":  # 专辑
					if text_value != "":
						metadata["album"] = text_value
				"TCOM":  # 作曲
					if text_value != "":
						metadata["composer"] = text_value
	
	file.close()
	
	if metadata.size() > 0:
		print("[MP3解析] 读取到元数据: ", metadata)
	
	return metadata

func _parse_id3_text_frame(data: PackedByteArray) -> String:
	"""解析ID3文本帧"""
	if data.size() < 2:
		return ""
	
	var encoding = data[0]
	var text_data = data.slice(1)
	
	# 对于UTF-16编码，空字符是两个字节的0，需要特殊处理
	if encoding == 1 or encoding == 2:
		# UTF-16：移除末尾的双字节空字符（确保是对齐的双字节0x00 0x00）
		while text_data.size() >= 2:
			var last_idx = text_data.size() - 1
			if text_data[last_idx] == 0 and text_data[last_idx - 1] == 0:
				text_data = text_data.slice(0, last_idx - 1)
			else:
				break
	else:
		# 其他编码：移除末尾的单字节空字符
		while text_data.size() > 0 and text_data[text_data.size() - 1] == 0:
			text_data = text_data.slice(0, text_data.size() - 1)
	
	match encoding:
		0:  # ISO-8859-1 (Latin-1)
			return text_data.get_string_from_ascii()
		1:  # UTF-16 with BOM
			return _decode_utf16(text_data)
		2:  # UTF-16BE without BOM
			return _decode_utf16be(text_data)
		3:  # UTF-8
			return text_data.get_string_from_utf8()
	
	return text_data.get_string_from_utf8()

func _decode_utf16(data: PackedByteArray) -> String:
	"""解码UTF-16字符串（带BOM）"""
	if data.size() < 2:
		return ""
	
	# 检查BOM
	var big_endian = false
	var start = 0
	if data[0] == 0xFE and data[1] == 0xFF:
		big_endian = true
		start = 2
	elif data[0] == 0xFF and data[1] == 0xFE:
		big_endian = false
		start = 2
	
	return _decode_utf16_data(data.slice(start), big_endian)

func _decode_utf16be(data: PackedByteArray) -> String:
	"""解码UTF-16BE字符串"""
	return _decode_utf16_data(data, true)

func _decode_utf16_data(data: PackedByteArray, big_endian: bool) -> String:
	"""解码UTF-16数据，支持代理对（surrogate pairs）"""
	var result = ""
	var i = 0
	while i + 1 < data.size():
		var code: int
		if big_endian:
			code = (data[i] << 8) | data[i + 1]
		else:
			code = data[i] | (data[i + 1] << 8)
		
		# 只有连续两个完整的null双字节才结束，单个0x00字节不算（因为ASCII在UTF-16中高位是0）
		if code == 0:
			break
		
		# 处理UTF-16代理对 (用于编码 U+10000 以上的字符)
		if code >= 0xD800 and code <= 0xDBFF:
			# 高位代理，需要读取低位代理
			if i + 3 < data.size():
				var low_code: int
				if big_endian:
					low_code = (data[i + 2] << 8) | data[i + 3]
				else:
					low_code = data[i + 2] | (data[i + 3] << 8)
				
				if low_code >= 0xDC00 and low_code <= 0xDFFF:
					# 有效的代理对，计算实际Unicode码点
					var actual_code = 0x10000 + ((code - 0xD800) << 10) + (low_code - 0xDC00)
					result += char(actual_code)
					i += 4
					continue
			# 无效的代理对，跳过
			i += 2
			continue
		elif code >= 0xDC00 and code <= 0xDFFF:
			# 孤立的低位代理，跳过
			i += 2
			continue
		
		result += char(code)
		i += 2
	
	return result

func parse_lrc_metadata(file_path: String) -> Dictionary:
	"""解析LRC文件的元数据标签"""
	var metadata = {}
	var extracted_artists = []  # 从歌词内容提取的艺术家信息
	
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		return metadata
	
	# 时间戳正则
	var time_pattern = RegEx.new()
	time_pattern.compile("^\\[(\\d+):(\\d+\\.\\d+)\\](.+)")
	
	# 读取文件查找元数据
	while not file.eof_reached():
		var line = file.get_line().strip_edges()
		
		# 检查各种元数据标签
		if line.begins_with("[ar:"):
			metadata["artist"] = line.substr(4, line.length() - 5)
		elif line.begins_with("[ti:"):
			metadata["title"] = line.substr(4, line.length() - 5)
		elif line.begins_with("[al:"):
			metadata["album"] = line.substr(4, line.length() - 5)
		elif line.begins_with("[by:"):
			metadata["by"] = line.substr(4, line.length() - 5)
		else:
			# 检查带时间戳的元数据行（歌词内容中的艺术家信息）
			var result = time_pattern.search(line)
			if result:
				var text = result.get_string(3).strip_edges()
				var artist_info = _extract_lrc_artist_info(text)
				if not artist_info.is_empty():
					extracted_artists.append(artist_info)
	
	file.close()
	
	# 如果artist为空或为默认值，使用提取的艺术家信息
	if extracted_artists.size() > 0:
		if not metadata.has("artist") or metadata["artist"].is_empty() or metadata["artist"] == "Null":
			metadata["artist"] = " / ".join(extracted_artists)
		# 同时提取作曲等信息
		for info in extracted_artists:
			if info.begins_with("作曲:") and not metadata.has("composer"):
				metadata["composer"] = info.substr(3).strip_edges()
			elif info.begins_with("作词:") and not metadata.has("lyricist"):
				metadata["lyricist"] = info.substr(3).strip_edges()
			elif info.begins_with("编曲:") and not metadata.has("arranger"):
				metadata["arranger"] = info.substr(3).strip_edges()
	
	return metadata

func _extract_lrc_artist_info(text: String) -> String:
	"""从歌词行提取艺术家信息"""
	var artist_keywords = ["演唱", "歌手", "主唱", "vocal", "Vocal", "作词", "作詞", 
						   "填词", "填詞", "作曲", "编曲", "編曲"]
	
	for keyword in artist_keywords:
		if text.contains(keyword):
			# 提取冒号后的内容
			var separators = ["：", ":", "／", "/"]
			for sep in separators:
				var idx = text.find(sep)
				if idx >= 0:
					var artist_name = text.substr(idx + 1).strip_edges()
					if not artist_name.is_empty():
						# 对于演唱/歌手，直接返回名字
						if keyword in ["演唱", "歌手", "主唱", "vocal", "Vocal"]:
							return artist_name
						# 对于其他类型，加上标签
						return keyword + ": " + artist_name
	return ""

func _on_start_button_pressed():
	"""点击开始按钮进入游戏"""
	if selected_song_index >= 0:
		Global.selected_song = songs[selected_song_index]
		Global.lyric_mode_enabled = true
		get_tree().change_scene_to_file("res://Main.tscn")

func _on_refresh_button_pressed():
	"""刷新歌曲列表"""
	scan_songs()
	populate_song_list()

func _on_back_button_pressed():
	get_tree().change_scene_to_file("res://UI/MainMenu.tscn")

func _on_search_lyric_button_pressed():
	"""点击搜索歌词按钮"""
	if selected_song_index < 0:
		return
	
	# 检查工具是否可用
	if not lyric_service.is_available():
		search_lyric_button.text = "工具未配置" if Global.current_language == "zh" else "Tool Not Configured"
		await get_tree().create_timer(2.0).timeout
		search_lyric_button.text = TEXTS[Global.current_language]["search_lyric"]
		return
		
	var song = songs[selected_song_index]
	search_lyric_button.disabled = true
	search_lyric_button.text = TEXTS[Global.current_language]["searching"]
	
	# 搜索歌词
	var result = await lyric_service.search_and_download_lyrics(song["name"], song["artist"])
	
	if result.success:
		# 保存歌词文件 - 使用原始文件基础名保持一致性
		var music_path = song["music_file"]
		var file_base_name = song.get("base_name", song["name"])  # 使用原始基础名
		var lrc_path = ""
		
		# 根据音乐文件位置决定歌词保存位置
		if music_path.begins_with("res://musics/"):
			lrc_path = "res://musics/lyrics/" + file_base_name + ".lrc"
		elif music_path.begins_with(OS.get_user_data_dir() + "/imported_songs/"):
			lrc_path = OS.get_user_data_dir() + "/imported_songs/lyrics/" + file_base_name + ".lrc"
		else:
			# 默认放在同级目录下的lyrics文件夹
			var base_dir = music_path.get_base_dir()
			var lrc_dir = base_dir + "/lyrics"
			DirAccess.make_dir_recursive_absolute(lrc_dir)
			lrc_path = lrc_dir + "/" + file_base_name + ".lrc"
		
		# 确保目录存在
		DirAccess.make_dir_recursive_absolute(lrc_path.get_base_dir())
		
		var file = FileAccess.open(lrc_path, FileAccess.WRITE)
		if file:
			file.store_string(result.lyrics)
			file.close()
			
			# 更新歌曲信息
			song["lyric_file"] = lrc_path
			songs[selected_song_index] = song
			
			# 更新UI
			search_lyric_button.text = TEXTS[Global.current_language]["lyric_found"]
			await get_tree().create_timer(1.0).timeout
			search_lyric_button.visible = false
			
			# 重新选择当前歌曲以刷新详情
			_on_song_selected(selected_song_index)
		else:
			search_lyric_button.text = "保存失败"
			await get_tree().create_timer(2.0).timeout
			search_lyric_button.disabled = false
			search_lyric_button.text = TEXTS[Global.current_language]["search_lyric"]
	else:
		search_lyric_button.text = TEXTS[Global.current_language]["lyric_not_found"]
		await get_tree().create_timer(2.0).timeout
		search_lyric_button.disabled = false
		search_lyric_button.text = TEXTS[Global.current_language]["search_lyric"]

# ============ 导入本地歌曲功能 ============

func _on_import_button_pressed():
	"""点击导入按钮 - 显示导入选项菜单"""
	# 切换菜单显示状态
	import_menu.visible = not import_menu.visible
	
	if import_menu.visible:
		# 设置菜单位置在按钮旁边
		var btn_pos = import_button.global_position
		var btn_size = import_button.size
		import_menu.global_position = Vector2(btn_pos.x + btn_size.x + 10, btn_pos.y)

func _on_import_menu_action(id: int):
	"""处理导入菜单选择"""
	import_menu.visible = false
	
	var title = ""
	var mode = DisplayServer.FILE_DIALOG_MODE_OPEN_FILE
	var filters = PackedStringArray(["*.mp3, *.ogg, *.wav ; Audio Files"])
	
	if id == 0: # Import File
		title = "选择音乐文件" if Global.current_language == "zh" else "Select Music File"
		mode = DisplayServer.FILE_DIALOG_MODE_OPEN_FILE
	elif id == 1: # Import Folder
		title = "选择音乐文件夹" if Global.current_language == "zh" else "Select Music Folder"
		mode = DisplayServer.FILE_DIALOG_MODE_OPEN_DIR
		filters = PackedStringArray([]) # 文件夹选择不需要过滤器
	
	DisplayServer.file_dialog_show(
		title,
		"",
		"",
		false,
		mode,
		filters,
		_on_native_file_selected
	)

func _on_native_file_selected(status: bool, selected_paths: PackedStringArray, selected_filter_index: int):
	"""系统文件选择回调"""
	if not status or selected_paths.is_empty():
		return
	
	var path = selected_paths[0]
	
	# 检查是文件还是文件夹
	if DirAccess.dir_exists_absolute(path):
		_import_folder(path)
	else:
		_import_single_file(path)

func _import_folder(path: String):
	"""导入文件夹中的所有音频文件"""
	var dir = DirAccess.open(path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		var imported_count = 0
		
		while file_name != "":
			if not dir.current_is_dir():
				var ext = file_name.get_extension().to_lower()
				if ext in ["mp3", "ogg", "wav"]:
					var full_path = path.path_join(file_name)
					if _import_single_file(full_path, false): # false = don't show individual success messages
						imported_count += 1
			file_name = dir.get_next()
		
		if imported_count > 0:
			var msg = "成功导入 %d 首歌曲" % imported_count if Global.current_language == "zh" else "Imported %d songs" % imported_count
			_show_import_message(msg, true)
			scan_songs()
			populate_song_list()
		else:
			var msg = "未找到支持的音频文件" if Global.current_language == "zh" else "No supported audio files found"
			_show_import_message(msg, false)

func _import_single_file(music_path: String, show_message: bool = true) -> bool:
	"""导入单个音乐文件"""
	# 尝试查找同名歌词文件
	var base_path = music_path.get_basename()
	var lyric_path = base_path + ".lrc"
	
	if not FileAccess.file_exists(lyric_path):
		lyric_path = "" # 无歌词
	
	return _import_song_files(music_path, lyric_path, show_message)

func _import_song_files(music_path: String, lyric_path: String, show_message: bool = true) -> bool:
	"""导入音乐和歌词文件"""
	# 获取用户目录下的音乐文件夹
	var user_music_dir = OS.get_user_data_dir() + "/imported_songs/"
	var user_lyric_dir = OS.get_user_data_dir() + "/imported_songs/lyrics/"
	
	# 确保目录存在
	DirAccess.make_dir_recursive_absolute(user_music_dir)
	DirAccess.make_dir_recursive_absolute(user_lyric_dir)
	
	# 获取文件名
	var music_filename = music_path.get_file()
	var base_name = music_filename.get_basename()  # 去掉扩展名
	
	# 复制音乐文件
	var music_dest = user_music_dir + music_filename
	var music_result = _copy_file(music_path, music_dest)
	
	# 复制歌词文件（如果有）
	var lyric_result = true
	if not lyric_path.is_empty():
		var lyric_filename = base_name + ".lrc"
		var lyric_dest = user_lyric_dir + lyric_filename
		lyric_result = _copy_file(lyric_path, lyric_dest)
	
	if music_result:
		print("[导入] 成功导入: ", base_name)
		if show_message:
			_show_import_message("导入成功: " + base_name if Global.current_language == "zh" else "Imported: " + base_name, true)
			# 刷新歌曲列表
			scan_songs()
			populate_song_list()
		return true
	else:
		if show_message:
			var error_msg = "导入失败" if Global.current_language == "zh" else "Import failed"
			_show_import_message(error_msg, false)
		print("[导入] 失败: 音乐=", music_result)
		return false

func _copy_file(source: String, destination: String) -> bool:
	"""复制文件"""
	var source_file = FileAccess.open(source, FileAccess.READ)
	if not source_file:
		print("[导入] 无法打开源文件: ", source)
		return false
	
	var content = source_file.get_buffer(source_file.get_length())
	source_file.close()
	
	var dest_file = FileAccess.open(destination, FileAccess.WRITE)
	if not dest_file:
		print("[导入] 无法创建目标文件: ", destination)
		return false
	
	dest_file.store_buffer(content)
	dest_file.close()
	return true

func _show_import_message(message: String, success: bool):
	"""显示导入结果消息"""
	# 创建一个临时标签显示消息
	var label = Label.new()
	label.text = message
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", Color.GREEN if success else Color.RED)
	label.add_theme_font_size_override("font_size", 18)
	
	var font = load("res://fonts/FUSION-PIXEL-12PX-MONOSPACED-ZH_HANS.OTF")
	label.add_theme_font_override("font", font)
	
	# 设置位置（屏幕底部中央）
	label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	label.position.y -= 50
	
	add_child(label)
	
	# 2秒后淡出消失
	var tween = create_tween()
	tween.tween_interval(1.5)
	tween.tween_property(label, "modulate:a", 0.0, 0.5)
	tween.tween_callback(label.queue_free)
