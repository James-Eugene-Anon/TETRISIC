extends Node

# 全局设置
var current_language = "zh"
var current_resolution_index = 0
var lyric_mode_enabled = false  # 是否启用歌词模式
var classic_difficulty = 0  # 经典模式难度: 0=简单, 1=普通, 2=困难
var selected_song = {}  # 选中的歌曲信息
var music_volume = 0.8  # 音乐音量 (0.0 - 1.0)
var sfx_volume = 0.8    # 音效音量 (0.0 - 1.0)
var song_scores = {}    # 歌曲最高分记录 {"song_name": {"score": int, "lines": int}}
var classic_scores = {} # 经典模式最高分 {"easy": {...}, "normal": {...}, "hard": {...}}

# 装备系统 - 每个分类只能装备一个
var equipment_universal_faulty_amplifier = false  # 通用：故障的计分增幅器
var equipment_universal_rift_meter = false        # 通用：裂隙仪
var equipment_classic_special_block = false       # 经典模式：特殊方块生成器
var equipment_classic_snake_virus = false         # 经典模式：贪吃蛇病毒
var equipment_song_none = false                   # 歌曲模式：暂无装备
var equipment_song_beat_calibrator = false        # 歌曲模式：节拍校对器

# 网络设置
var online_mode = true  # 是否启用联网功能（离线/在线）
var music_lyric_app_path = ""  # MusicLyricApp 可执行文件路径

const SAVE_FILE_PATH = "user://song_scores.save"
const CLASSIC_SAVE_PATH = "user://classic_scores.save"

# 支持的分辨率
var resolutions = [
	Vector2i(800, 600),    # 默认
	Vector2i(1024, 768),   # 1.28x
	Vector2i(1280, 960),   # 1.6x
	Vector2i(1600, 1200)   # 2.0x
]

var resolution_names = {
	"zh": ["小 (800x600)", "中 (1024x768)", "大 (1280x960)", "超大 (1600x1200)"],
	"en": ["Small (800x600)", "Medium (1024x768)", "Large (1280x960)", "X-Large (1600x1200)"]
}

# 窗口模式
var is_fullscreen = false

# 游戏信息
var game_info = {
	"zh": {
		"title": "俄罗斯方块",
		"version": "版本 Alpha 0.0.2",
		"author": "作者: James-Eugene-Anon",
		"description": "经典俄罗斯方块游戏\n支持歌词显示功能",
		"controls": "← → 移动方块\n↑ 旋转方块\n↓ 快速下降\nEnter 硬降落\nEsc 暂停/菜单",
		"disclaimer": "免责声明：\n本游戏仅供娱乐使用。歌曲模式中的音乐和歌词\n文件版权归各自原作者所有。请仅使用您合法\n拥有的音乐和歌词文件。游戏开发者不对\n用户上传或使用的任何内容承担责任。"
	},
	"en": {
		"title": "Tetris",
		"version": "Version 1.0",
		"author": "Author: James-Eugene-Anon",
		"description": "Classic Tetris Game\nWith Lyrics Display Feature",
		"controls": "← → Move Piece\n↑ Rotate Piece\n↓ Soft Drop\nEnter Hard Drop\nEsc Pause/Menu",
		"disclaimer": "Disclaimer:\nThis game is for entertainment purposes only. Music and lyrics\nused in Song Mode are copyrighted by their respective owners.\nPlease only use music and lyrics files that you legally own.\nThe game developer is not responsible for any content\nuploaded or used by users."
	}
}

func get_resolution_name() -> String:
	if is_fullscreen:
		var screen_size = DisplayServer.screen_get_size()
		if current_language == "zh":
			return "全屏 (" + str(screen_size.x) + "x" + str(screen_size.y) + ")"
		else:
			return "Fullscreen (" + str(screen_size.x) + "x" + str(screen_size.y) + ")"
	return resolution_names[current_language][current_resolution_index]

func set_resolution(index: int):
	current_resolution_index = index
	var new_size = resolutions[index]
	# 确保退出全屏/最大化模式
	if is_fullscreen:
		is_fullscreen = false
		get_window().mode = Window.MODE_WINDOWED
	get_window().size = new_size
	# 居中窗口
	_center_window()

func set_fullscreen(enabled: bool):
	is_fullscreen = enabled
	if enabled:
		get_window().mode = Window.MODE_FULLSCREEN
	else:
		get_window().mode = Window.MODE_WINDOWED
		get_window().size = resolutions[current_resolution_index]
		_center_window()

func toggle_fullscreen():
	set_fullscreen(!is_fullscreen)

func _center_window():
	# 将窗口居中显示
	var screen_size = DisplayServer.screen_get_size()
	var window_size = get_window().size
	var pos = (screen_size - window_size) / 2
	get_window().position = pos

func switch_language():
	current_language = "en" if current_language == "zh" else "zh"

func set_music_volume(volume: float):
	music_volume = clamp(volume, 0.0, 1.0)
	# 转换为分贝 (dB): -80dB 到 0dB
	var db = linear_to_db(music_volume) if music_volume > 0 else -80
	var bus_idx = AudioServer.get_bus_index("Music")
	if bus_idx >= 0:
		AudioServer.set_bus_volume_db(bus_idx, db)

func set_sfx_volume(volume: float):
	sfx_volume = clamp(volume, 0.0, 1.0)
	var db = linear_to_db(sfx_volume) if sfx_volume > 0 else -80
	var bus_idx = AudioServer.get_bus_index("SFX")
	if bus_idx >= 0:
		AudioServer.set_bus_volume_db(bus_idx, db)

func get_game_info() -> Dictionary:
	return game_info[current_language]

func load_song_scores():
	"""加载歌曲最高分记录"""
	if FileAccess.file_exists(SAVE_FILE_PATH):
		var file = FileAccess.open(SAVE_FILE_PATH, FileAccess.READ)
		if file:
			var json_string = file.get_as_text()
			file.close()
			var json = JSON.new()
			var parse_result = json.parse(json_string)
			if parse_result == OK:
				song_scores = json.data
				print("加载了 ", song_scores.size(), " 首歌曲的最高分")
			else:
				print("解析最高分文件失败")
				song_scores = {}
	else:
		song_scores = {}
		print("没有找到最高分文件，创建新记录")

func save_song_scores():
	"""保存歌曲最高分记录"""
	var file = FileAccess.open(SAVE_FILE_PATH, FileAccess.WRITE)
	if file:
		var json_string = JSON.stringify(song_scores)
		file.store_string(json_string)
		file.close()
		print("保存了 ", song_scores.size(), " 首歌曲的最高分")
	else:
		print("保存最高分文件失败")

func update_song_score(song_name: String, score: int, lines: int):
	"""更新歌曲最高分"""
	if not song_scores.has(song_name) or song_scores[song_name]["score"] < score:
		song_scores[song_name] = {"score": score, "lines": lines}
		save_song_scores()
		print("更新 ", song_name, " 的最高分: ", score)
		return true
	return false

func get_song_score(song_name: String) -> Dictionary:
	"""获取歌曲最高分"""
	if song_scores.has(song_name):
		return song_scores[song_name]
	return {"score": 0, "lines": 0}

func _ready():
	load_song_scores()
	load_classic_scores()
	# 禁止窗口大小调整（但允许全屏）
	get_window().unresizable = true

func load_classic_scores():
	"""加载经典模式最高分记录"""
	if FileAccess.file_exists(CLASSIC_SAVE_PATH):
		var file = FileAccess.open(CLASSIC_SAVE_PATH, FileAccess.READ)
		if file:
			var json_string = file.get_as_text()
			file.close()
			var json = JSON.new()
			var parse_result = json.parse(json_string)
			if parse_result == OK:
				classic_scores = json.data
				print("加载了经典模式最高分")
			else:
				classic_scores = {}
	else:
		classic_scores = {}
		print("没有找到经典模式最高分文件")

func save_classic_scores():
	"""保存经典模式最高分记录"""
	var file = FileAccess.open(CLASSIC_SAVE_PATH, FileAccess.WRITE)
	if file:
		var json_string = JSON.stringify(classic_scores)
		file.store_string(json_string)
		file.close()
		print("保存了经典模式最高分")

func update_classic_score(difficulty: int, score: int, lines: int) -> bool:
	"""更新经典模式最高分"""
	var key = ["easy", "normal", "hard", "cruel"][difficulty]
	if not classic_scores.has(key) or classic_scores[key]["score"] < score:
		classic_scores[key] = {"score": score, "lines": lines}
		save_classic_scores()
		print("更新 ", key, " 难度最高分: ", score)
		return true
	return false

func get_classic_score(difficulty: int) -> Dictionary:
	"""获取经典模式最高分"""
	var key = ["easy", "normal", "hard", "cruel"][difficulty]
	if classic_scores.has(key):
		return classic_scores[key]
	return {"score": 0, "lines": 0}
