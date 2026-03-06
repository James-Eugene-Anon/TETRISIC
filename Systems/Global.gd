extends Node

# 全局设置
var current_language = "zh"
var current_resolution_index = 0
var lyric_mode_enabled = false  # 是否启用歌词模式
var classic_difficulty = 0  # 经典模式难度: 0=简单, 1=普通, 2=困难
var selected_song = {}  # 选中的歌曲信息
var music_volume = 0.8  # 音乐音量 (0.0 - 1.0)
var sfx_volume = 0.8    # 音效音量 (0.0 - 1.0)
var bgm_enabled = true  # 是否播放背景音乐（经典/Rogue模式）
var play_music_when_unfocused = false  # 窗口未置顶时是否播放音乐
var _session_start_time: float = -1.0  # 当前会话开始时间（unix 时间戳）
var song_scores = {}    # 歌曲最高分记录 {"song_name": {"score": int, "lines": int}}
var classic_scores = {} # 经典模式最高分 {"easy": {...}, "normal": {...}, "hard": {...}}
const BASE_RES = Vector2i(800, 600) # 基准分辨率

# 当前游戏模式（用于判断BGM按钮是否可用）
enum GameMode { MAIN_MENU, CLASSIC, ROGUE, SONG }
var current_game_mode: GameMode = GameMode.MAIN_MENU

# BGM路径
const BGM_PATH = "res://musics/bgm/Коробейники.mp3"

# 装备系统 - 每个分类只能装备一个
var equipment_universal_faulty_amplifier = false  # 通用：故障增幅器
var equipment_universal_rift_meter = false        # 通用：裂隙仪
var equipment_universal_capacity_disk = false     # 通用：扩容磁盘（12x24网格）
var equipment_classic_special_block = false       # 经典模式：特殊方块生成器
var equipment_classic_snake_virus = false         # 经典模式：贪吃蛇病毒
var equipment_song_none = false                   # 歌曲模式：暂无装备（废弃）
var equipment_song_beat_calibrator = false        # 歌曲模式：节拍校对器
var equipment_song_hearts_melody = false          # 歌曲模式：心之旋律（禁用节拍同步，最终得分×0.85）

# 网络设置
var online_mode = true  # 是否启用联网功能（离线/在线）
var music_lyric_app_path = ""  # MusicLyricApp 可执行文件路径
var lyric_search_retry_count = 3  # 歌词候选额外检查次数 X（0~10）

# 旧版全局文件路径已由 SaveManager 负责迁移，运行期统一通过账号存储
const SETTINGS_KEYS = {
	"language": "language",
	"resolution_index": "resolution_index",
	"is_fullscreen": "is_fullscreen",
	"music_volume": "music_volume",
	"sfx_volume": "sfx_volume",
	"online_mode": "online_mode",
	"lyric_search_retry_count": "lyric_search_retry_count",
	"bgm_enabled": "bgm_enabled",
	"play_music_when_unfocused": "play_music_when_unfocused"
}

# 支持的分辨率
var resolutions = [
	Vector2i(2560, 1440),
	Vector2i(2304, 1440),
	Vector2i(2160, 1440),
	Vector2i(2048, 1152),
	Vector2i(1920, 1440),
	Vector2i(1920, 1280),
	Vector2i(1920, 1200),
	Vector2i(1920, 1080),
	Vector2i(2560, 1080),
	Vector2i(1600, 900),
	Vector2i(1366, 768),
	Vector2i(1280, 720),
	Vector2i(720, 480),
	Vector2i(1600, 1200),
	Vector2i(1280, 1024),
	Vector2i(1280, 960),
	Vector2i(1024, 768),
	Vector2i(800, 600)
]

# 游戏信息（title/disclaimer/thanks 已迁移至翻译CSV，此处仅保留代码引用的 version 和 author）
var game_info = {
	"zh": {
		"version": "版本 Alpha 0.1.1",
		"author": "作者: James-Eugene-Anon"
	},
	"en": {
		"version": "Version Alpha 0.1.1",
		"author": "Author: James-Eugene-Anon"
	}
}

var is_fullscreen: bool = 0  # 0: 窗口化, 1: 全屏

func get_resolution_name() -> String:
	var current_size = get_window().size
	# 全屏时在显示上固定为系统屏幕分辨率
	if is_fullscreen:
		current_size = DisplayServer.screen_get_size()
	# 检查是否匹配预设分辨率
	var match_index = -1
	for i in range(resolutions.size()):
		if resolutions[i] == current_size:
			match_index = i
			break
	
	if match_index != -1:
		current_resolution_index = match_index # 同步索引
		return get_resolution_label(match_index)
	else:
		return tr("UI_RESOLUTION_CUSTOM_FMT") % [current_size.x, current_size.y]

func get_resolution_label(index: int) -> String:
	if index < 0 or index >= resolutions.size():
		return tr("UI_RESOLUTION_CUSTOM_FMT") % [0, 0]
	var res = resolutions[index]
	return tr("UI_RESOLUTION_FMT") % [res.x, res.y]

func set_resolution(index: int):
	if index < 0 or index >= resolutions.size():
		return
		
	if is_fullscreen:
		current_resolution_index = _get_max_resolution_index()
		_apply_fullscreen_scale(get_window())
		_save_setting(SETTINGS_KEYS.resolution_index, current_resolution_index)
		return
		
	current_resolution_index = index
	var new_size = resolutions[index]
	
	var window = get_window()
	if !is_fullscreen:
		window.size = new_size
		_center_window()
	else:
		_apply_fullscreen_scale(window)
		
	_save_setting(SETTINGS_KEYS.resolution_index, current_resolution_index)

func set_window_mode(index: int):
	is_fullscreen = index
	var window = get_window()
	
	match index:
		0: # 窗口化
			window.mode = Window.MODE_WINDOWED
			window.borderless = false
			is_fullscreen = false
			window.size = resolutions[current_resolution_index]
			_center_window()
			_apply_windowed_scale(window)
		1: # 全屏（原“无边框窗口”行为）
			# 使用屏幕原生全屏显示，保留先前无边框的缩放处理
			window.mode = Window.MODE_FULLSCREEN
			window.borderless = true
			is_fullscreen = true
			_apply_fullscreen_scale(window)
			
	_save_setting("is_fullscreen", is_fullscreen)
	_save_setting(SETTINGS_KEYS.is_fullscreen, is_fullscreen)

func toggle_fullscreen():
	if is_fullscreen:
		set_window_mode(0)
	else:
		set_window_mode(1)

func set_fullscreen(enabled: bool):
	if enabled:
		set_window_mode(1)
	else:
		set_window_mode(0)
		
func round_to(value: float, decimals: int) -> float:
	var factor = pow(10.0, decimals)
	return round(value * factor) / factor
	
func _apply_fullscreen_scale(window: Window) -> void:
	# 全屏模式：重置为项目默认设置，UI自适应缩放
	window.content_scale_factor = 1
	window.content_scale_size = BASE_RES  # 重置为项目基础分辨率
	window.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND

func _apply_windowed_scale(window: Window) -> void:
	# 窗口模式：重置为项目默认设置
	window.content_scale_factor = 1  
	window.content_scale_size = BASE_RES  # 重置为项目基础分辨率
	window.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND

func _get_max_resolution_index() -> int:
	var max_index = 0
	var max_area = 0
	for i in range(resolutions.size()):
		var area = resolutions[i].x * resolutions[i].y
		if area > max_area:
			max_area = area
			max_index = i
	return max_index

func _center_window():
	# 将窗口居中显示
	var screen_size = DisplayServer.screen_get_size()
	var window_size = get_window().size
	var pos = (screen_size - window_size) / 2
	get_window().position = pos

func switch_language(index: int):
	# index: 0 = en, 1 = zh
	match index:
		0: current_language = "en"
		1: current_language = "zh"
		_: return

	_save_setting(SETTINGS_KEYS.language, current_language)
	_apply_language()

func _apply_language() -> void:
	# 确保 Godot 翻译系统使用与 current_language 一致的本地化键
	TranslationServer.set_locale(current_language)

	# 加载 translations/translation.csv 并注册运行时翻译资源
	_load_runtime_translations()

func _split_csv_line(line: String) -> Array:
	var cols = []
	var cur = ""
	var in_quote = false
	var i = 0
	while i < line.length():
		var ch = line[i]
		if ch == '"':
			in_quote = not in_quote
		elif ch == ',' and not in_quote:
			cols.append(cur)
			cur = ""
		else:
			cur += ch
		i += 1
	cols.append(cur)
	return cols

func _load_runtime_translations() -> void:
	var path = "res://translations/translation.csv"
	if not FileAccess.file_exists(path):
		print("[Global] translation.csv not found: ", path)
		return
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		print("[Global] cannot open translation.csv")
		return
	var text = file.get_as_text()
	file.close()
	# 读取原始文本并逐行解析 CSV（支持带引号的字段）
	var lines = text.split("\n")
	if lines.size() <= 1:
		return
	# 假定表头: key,en,zh
	var header = lines[0].strip_edges()
	var locale_index = -1
	var headers = header.split(",")
	for i in range(headers.size()):
		if headers[i].strip_edges() == current_language:
			locale_index = i
			break
	if locale_index == -1:
		# 回退：若未找到列名，则按常见位置映射（1=en, 2=zh）
		locale_index = 2 if current_language == "zh" else 1

	var translation = Translation.new()
	# 若 Translation 资源支持则设置其 locale
	if translation.has_method("set_locale"):
		translation.set_locale(current_language)

	# 使用顶层的 _split_csv_line 解析 CSV 行（支持引号内逗号）

	for i in range(1, lines.size()):
		var line = lines[i]
		if line.strip_edges() == "":
			continue
		var cols = _split_csv_line(line)
		if cols.size() < 2:
			continue
		var key = cols[0].strip_edges()
		var value = ""
		if locale_index >= 0 and locale_index < cols.size():
			value = cols[locale_index].strip_edges()
		else:
			# 回退到常规列位置（en 在第1列，zh 在第2列）
			value = cols[2].strip_edges() if cols.size() > 2 else (cols[1].strip_edges() if cols.size() > 1 else "")

		# 将文本中的 "\\n" 转为实际换行，便于显示多行文本
		var v = value.replace("\\n", "\n")

		# 转义百分号以避免后续格式化报错
		v = v.replace("%%d", "%d")
		v = v.replace("%%s", "%s")
		v = v.replace("%%.1f", "%.1f")
		v = v.replace("%%.2f", "%.2f")

		# 添加消息到翻译资源
		if key != "" and v != "":
			if translation.has_method("add_message"):
				translation.add_message(key, v)
			else:
				translation[key] = v

	# 向引擎注册该翻译资源
	TranslationServer.add_translation(translation)

func set_music_volume(volume: float):
	music_volume = clamp(volume, 0.0, 1.0)
	# 指数曲线：平方映射使滑块中段感知更自然
	# 75%→-5dB, 50%→-12dB, 25%→-24dB（对比线性：75%→-2.5dB, 25%→-12dB）
	var adjusted = music_volume * music_volume
	var db = linear_to_db(adjusted) if adjusted > 0 else -80
	var bus_idx = AudioServer.get_bus_index("Music")
	if bus_idx >= 0:
		AudioServer.set_bus_volume_db(bus_idx, db)
	else:
		# Music总线不存在时回退到Master总线（不应发生，但作为保障）
		push_warning("[Global] Music总线不存在，回退到Master总线")
		AudioServer.set_bus_volume_db(0, db)
	_save_setting(SETTINGS_KEYS.music_volume, music_volume)

func set_sfx_volume(volume: float):
	sfx_volume = clamp(volume, 0.0, 1.0)
	var adjusted = sfx_volume * sfx_volume
	var db = linear_to_db(adjusted) if adjusted > 0 else -80
	var bus_idx = AudioServer.get_bus_index("SFX")
	if bus_idx >= 0:
		AudioServer.set_bus_volume_db(bus_idx, db)
	else:
		push_warning("[Global] SFX总线不存在")
	_save_setting(SETTINGS_KEYS.sfx_volume, sfx_volume)

func set_online_mode(enabled: bool):
	online_mode = enabled
	_save_setting(SETTINGS_KEYS.online_mode, online_mode)

func set_lyric_search_retry_count(value: int):
	lyric_search_retry_count = clamp(value, 0, 10)
	_save_setting(SETTINGS_KEYS.lyric_search_retry_count, lyric_search_retry_count)

func set_bgm_enabled(enabled: bool):
	bgm_enabled = enabled
	_save_setting(SETTINGS_KEYS.bgm_enabled, bgm_enabled)

func set_play_music_when_unfocused(enabled: bool):
	play_music_when_unfocused = enabled
	_save_setting(SETTINGS_KEYS.play_music_when_unfocused, play_music_when_unfocused)

func get_game_info() -> Dictionary:
	return game_info[current_language]

func load_song_scores():
	if SaveManager and SaveManager.has_method("load_account_song_scores"):
		song_scores = SaveManager.load_account_song_scores()
		print("从账号加载了 ", song_scores.size(), " 首歌曲最高分")
	else:
		song_scores = {}

func save_song_scores():
	if SaveManager and SaveManager.has_method("save_account_song_scores"):
		if SaveManager.save_account_song_scores(song_scores):
			print("保存了 ", song_scores.size(), " 首歌曲的最高分")
		else:
			print("保存最高分文件失败")
	# 同步到 GameDB（兼容性保留，非关键路径）
	if GameDB:
		GameDB.set_table("song_scores", song_scores)

func update_song_score(song_name: String, score: int, lines: int):
	# 更新歌曲最高分
	if not song_scores.has(song_name) or song_scores[song_name]["score"] < score:
		song_scores[song_name] = {"score": score, "lines": lines}
		save_song_scores()
		print("更新 ", song_name, " 的最高分: ", score)
		return true
	return false

func get_song_score(song_name: String) -> Dictionary:
	# 获取歌曲最高分
	if song_scores.has(song_name):
		return song_scores[song_name]
	return {"score": 0, "lines": 0}

func _ready():
	if SaveManager and SaveManager.has_method("ensure_accounts_ready"):
		SaveManager.ensure_accounts_ready()
	_load_persistent_settings()
	_apply_language()
	load_song_scores()
	load_classic_scores()
	_apply_window_settings_after_load()
	_session_start_time = Time.get_unix_time_from_system()
	# 允许用户调整窗口大小（含最大化），不再强制锁定
	# 确保音频总线已正确加载并应用初始音量（延迟一帧，等待引擎加载bus_layout）
	call_deferred("_init_audio_buses")

func _save_setting(key: String, value) -> void:
	var settings_data = _collect_settings_dict()
	settings_data[key] = value
	if SaveManager and SaveManager.has_method("save_account_settings"):
		SaveManager.save_account_settings(settings_data)

func _load_setting(key: String, default_value):
	var defaults = {key: default_value}
	if SaveManager and SaveManager.has_method("load_account_settings"):
		var loaded = SaveManager.load_account_settings(defaults)
		return loaded.get(key, default_value)
	return default_value

func _collect_settings_dict() -> Dictionary:
	return {
		SETTINGS_KEYS.language: current_language,
		SETTINGS_KEYS.resolution_index: current_resolution_index,
		SETTINGS_KEYS.is_fullscreen: is_fullscreen,
		SETTINGS_KEYS.music_volume: music_volume,
		SETTINGS_KEYS.sfx_volume: sfx_volume,
		SETTINGS_KEYS.online_mode: online_mode,
		SETTINGS_KEYS.lyric_search_retry_count: lyric_search_retry_count,
		SETTINGS_KEYS.bgm_enabled: bgm_enabled,
		SETTINGS_KEYS.play_music_when_unfocused: play_music_when_unfocused
	}

func _load_persistent_settings() -> void:
	var defaults = _collect_settings_dict()
	var loaded: Dictionary = defaults
	if SaveManager and SaveManager.has_method("load_account_settings"):
		loaded = SaveManager.load_account_settings(defaults)
	current_language = str(loaded.get(SETTINGS_KEYS.language, current_language))
	current_resolution_index = clamp(int(loaded.get(SETTINGS_KEYS.resolution_index, current_resolution_index)), 0, resolutions.size() - 1)
	is_fullscreen = bool(loaded.get(SETTINGS_KEYS.is_fullscreen, is_fullscreen))
	music_volume = float(loaded.get(SETTINGS_KEYS.music_volume, music_volume))
	sfx_volume = float(loaded.get(SETTINGS_KEYS.sfx_volume, sfx_volume))
	online_mode = bool(loaded.get(SETTINGS_KEYS.online_mode, online_mode))
	lyric_search_retry_count = clamp(int(loaded.get(SETTINGS_KEYS.lyric_search_retry_count, lyric_search_retry_count)), 0, 10)
	bgm_enabled = bool(loaded.get(SETTINGS_KEYS.bgm_enabled, bgm_enabled))
	play_music_when_unfocused = bool(loaded.get(SETTINGS_KEYS.play_music_when_unfocused, play_music_when_unfocused))

func _apply_window_settings_after_load() -> void:
	var window = get_window()
	if not window:
		return
	if is_fullscreen:
		window.mode = Window.MODE_FULLSCREEN
		window.borderless = true
		_apply_fullscreen_scale(window)
	else:
		window.mode = Window.MODE_WINDOWED
		window.borderless = false
		current_resolution_index = clamp(current_resolution_index, 0, resolutions.size() - 1)
		window.size = resolutions[current_resolution_index]
		_center_window()
		_apply_windowed_scale(window)

func _init_audio_buses():
	# 如果Music总线不存在（可能因为初始化时序），加载或重建总线布局
	var music_idx = AudioServer.get_bus_index("Music")
	if music_idx < 0:
		var bus_layout = load("res://Systems/Audio/default_bus_layout.tres")
		if bus_layout:
			AudioServer.set_bus_layout(bus_layout)
		else:
			# 兜底：手动创建 Music/SFX 总线
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, "Music")
			AudioServer.set_bus_send(AudioServer.bus_count - 1, "Master")
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, "SFX")
			AudioServer.set_bus_send(AudioServer.bus_count - 1, "Master")
	# 应用初始音量
	set_music_volume(music_volume)
	set_sfx_volume(sfx_volume)

func load_classic_scores():
	if SaveManager and SaveManager.has_method("load_account_classic_scores"):
		classic_scores = SaveManager.load_account_classic_scores()
		print("从账号加载了经典模式最高分")
	else:
		classic_scores = {}

func save_classic_scores():
	if SaveManager and SaveManager.has_method("save_account_classic_scores"):
		if SaveManager.save_account_classic_scores(classic_scores):
			print("保存了经典模式最高分")
		else:
			print("保存经典模式最高分失败")
	# 同步到 GameDB（兼容性保留，非关键路径）
	if GameDB:
		GameDB.set_table("classic_scores", classic_scores)

func update_classic_score(difficulty: int, score: int, lines: int) -> bool:
	# 更新经典模式最高分
	var key = ["easy", "normal", "hard", "cruel"][difficulty]
	if not classic_scores.has(key) or classic_scores[key]["score"] < score:
		classic_scores[key] = {"score": score, "lines": lines}
		save_classic_scores()
		print("更新 ", key, " 难度最高分: ", score)
		return true
	return false

func get_classic_score(difficulty: int) -> Dictionary:
	# 获取经典模式最高分
	var key = ["easy", "normal", "hard", "cruel"][difficulty]
	if classic_scores.has(key):
		return classic_scores[key]
	return {"score": 0, "lines": 0}

func get_account_profiles() -> Array[Dictionary]:
	if SaveManager and SaveManager.has_method("get_accounts"):
		return SaveManager.get_accounts()
	return []

func get_current_account_profile() -> Dictionary:
	if SaveManager and SaveManager.has_method("get_current_account"):
		return SaveManager.get_current_account()
	return {}

func create_account_profile(name: String) -> Dictionary:
	if SaveManager and SaveManager.has_method("create_account"):
		return SaveManager.create_account(name)
	return {"success": false, "error": "save_manager_missing"}

func rename_account_profile(account_id: String, new_name: String) -> Dictionary:
	if SaveManager and SaveManager.has_method("rename_account"):
		return SaveManager.rename_account(account_id, new_name)
	return {"success": false, "error": "save_manager_missing"}

func delete_account_profile(account_id: String) -> Dictionary:
	if SaveManager and SaveManager.has_method("delete_account"):
		return SaveManager.delete_account(account_id)
	return {"success": false, "error": "save_manager_missing"}

func switch_account_profile(account_id: String) -> bool:
	if not (SaveManager and SaveManager.has_method("set_current_account")):
		return false
	_flush_play_time()
	if not SaveManager.set_current_account(account_id):
		return false
	_session_start_time = Time.get_unix_time_from_system()
	_load_persistent_settings()
	_apply_language()
	_apply_window_settings_after_load()
	load_song_scores()
	load_classic_scores()
	call_deferred("_init_audio_buses")
	return true

func _flush_play_time() -> void:
	# 将本次会话的游玩时长写入当前账号存档
	if _session_start_time < 0.0:
		return
	var now = Time.get_unix_time_from_system()
	var elapsed = int(now - _session_start_time)
	if elapsed > 0 and SaveManager and SaveManager.has_method("add_current_account_play_seconds"):
		SaveManager.add_current_account_play_seconds(elapsed)
	_session_start_time = now  # 重置，避免重复计入

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_flush_play_time()
		get_tree().quit()
