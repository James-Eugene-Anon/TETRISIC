extends Node2D

const LyricsParser = preload("res://LyricsParser.gd")

# Python桥接器实例
var python_bridge = null

# 游戏配置
const GRID_WIDTH = 10
const GRID_HEIGHT = 20
const CELL_SIZE = 28
const FALL_SPEED = 1.0  # 秒
const LOCK_DELAY = 0.003  # 方块固定延迟（3毫秒）
const GRID_OFFSET_X = 20
const GRID_OFFSET_Y = 20
const REPEAT_DELAY = 0.15  # 按键重复延迟
const REPEAT_RATE = 0.05   # 按键重复速率

# 方块形状定义 (包含所有旋转状态)
const SHAPES = {
	"I": [
		[Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1)],
		[Vector2i(2, 0), Vector2i(2, 1), Vector2i(2, 2), Vector2i(2, 3)],
		[Vector2i(0, 2), Vector2i(1, 2), Vector2i(2, 2), Vector2i(3, 2)],
		[Vector2i(1, 0), Vector2i(1, 1), Vector2i(1, 2), Vector2i(1, 3)]
	],
	"O": [
		[Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]
	],
	"T": [
		[Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1)],
		[Vector2i(1, 0), Vector2i(1, 1), Vector2i(2, 1), Vector2i(1, 2)],
		[Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(1, 2)],
		[Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(1, 2)]
	],
	"S": [
		[Vector2i(1, 0), Vector2i(2, 0), Vector2i(0, 1), Vector2i(1, 1)],
		[Vector2i(1, 0), Vector2i(1, 1), Vector2i(2, 1), Vector2i(2, 2)],
		[Vector2i(1, 1), Vector2i(2, 1), Vector2i(0, 2), Vector2i(1, 2)],
		[Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(1, 2)]
	],
	"Z": [
		[Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(2, 1)],
		[Vector2i(2, 0), Vector2i(1, 1), Vector2i(2, 1), Vector2i(1, 2)],
		[Vector2i(0, 1), Vector2i(1, 1), Vector2i(1, 2), Vector2i(2, 2)],
		[Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(0, 2)]
	],
	"J": [
		[Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1)],
		[Vector2i(1, 0), Vector2i(2, 0), Vector2i(1, 1), Vector2i(1, 2)],
		[Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(2, 2)],
		[Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 2), Vector2i(1, 2)]
	],
	"L": [
		[Vector2i(2, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1)],
		[Vector2i(1, 0), Vector2i(1, 1), Vector2i(1, 2), Vector2i(2, 2)],
		[Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(0, 2)],
		[Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(1, 2)]
	],
	# 5格方块 - 十字形（4个旋转状态）
	"PLUS": [
		[Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(1, 2)],
		[Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(1, 2)],
		[Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(1, 2)],
		[Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(1, 2)]
	],
	# 5格方块 - T形加长（4个旋转状态，真正90度旋转）
	"T5": [
		[Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(1, 1), Vector2i(1, 2)],  # T形: 横3竖2
		[Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2), Vector2i(1, 1), Vector2i(2, 1)],  # 90度: 竖3横2
		[Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 2), Vector2i(1, 2), Vector2i(2, 2)],  # 180度: 横3竖2
		[Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 0), Vector2i(2, 1), Vector2i(2, 2)]   # 270度: 竖3横2
	],
	# 5格方块 - L形变体（4个旋转状态，真正90度旋转）
	"L5": [
		[Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2), Vector2i(1, 2), Vector2i(2, 2)],  # L形: 竖3横3
		[Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(0, 1), Vector2i(0, 2)],  # 90度
		[Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(2, 1), Vector2i(2, 2)],  # 180度
		[Vector2i(2, 0), Vector2i(2, 1), Vector2i(0, 2), Vector2i(1, 2), Vector2i(2, 2)]   # 270度
	],
	# 5格方块 - 反向L形（4个旋转状态，真正90度旋转）
	"L5R": [
		[Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(2, 1), Vector2i(2, 2)],  # 反L: 横3竖3
		[Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2), Vector2i(1, 2), Vector2i(2, 2)],  # 90度
		[Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2), Vector2i(1, 0), Vector2i(2, 0)],  # 180度
		[Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(0, 1), Vector2i(0, 2)]   # 270度
	],
	# 6格方块 - L形加长（4个旋转状态，真正90度旋转）
	"L6": [
		[Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2), Vector2i(1, 2), Vector2i(2, 2), Vector2i(3, 2)],  # ┌: 竖桒3+横桒4
		[Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(0, 1), Vector2i(0, 2), Vector2i(0, 3)],  # ┐: 90度旋转
		[Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0), Vector2i(3, 1), Vector2i(3, 2)],  # ┘: 180度旋转
		[Vector2i(2, 0), Vector2i(2, 1), Vector2i(2, 2), Vector2i(2, 3), Vector2i(0, 3), Vector2i(1, 3)]   # └: 270度旋转
	],
	# 6格方块 - 2x3矩形（2个旋转状态）
	"RECT": [
		[Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(0, 2), Vector2i(1, 2)],  # 2x3竖向
		[Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1)]   # 3x2横向
	],
	# 7格方块 - T形加长（4个旋转状态，保持凸字型，围绕中心旋转）
	"T7": [
		# 凸形: 上1+中3+下3
		[Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(0, 2), Vector2i(1, 2), Vector2i(2, 2)],
		# 右凸: 90度旋转，左档1+中3+右3
		[Vector2i(0, 1), Vector2i(1, 0), Vector2i(1, 1), Vector2i(1, 2), Vector2i(2, 0), Vector2i(2, 1), Vector2i(2, 2)],
		# 凹形: 180度旋转
		[Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(1, 2)],
		# 左凸: 270度旋转，工3+中3+右1
		[Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2), Vector2i(1, 0), Vector2i(1, 1), Vector2i(1, 2), Vector2i(2, 1)]
	],
	# 1格方块 - 单格
	"DOT": [
		[Vector2i(0, 0)]
	],
	# 2格方块 - 横条（2个旋转状态，围绕中心旋转）
	"I2": [
		[Vector2i(0, 0), Vector2i(1, 0)],  # 横向
		[Vector2i(0, 0), Vector2i(0, 1)]   # 竖向
	],
	# 3格方块 - 横条（2个旋转状态，围绕中间格旋转）
	"I3": [
		[Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)],  # 横向
		[Vector2i(1, 0), Vector2i(1, 1), Vector2i(1, 2)]   # 竖向（中心在第2格）
	]
}

# 方块颜色
const COLORS = {
	"I": Color.CYAN,
	"O": Color.YELLOW,
	"T": Color.MAGENTA,
	"S": Color.GREEN,
	"Z": Color.RED,
	"J": Color.BLUE,
	"L": Color.ORANGE,
	"PLUS": Color.PURPLE,
	"T5": Color.MEDIUM_PURPLE,
	"L5": Color.DARK_SALMON,
	"L5R": Color.LIGHT_CORAL,
	"L6": Color.PINK,
	"RECT": Color.LIGHT_SKY_BLUE,
	"T7": Color.DEEP_PINK,
	"DOT": Color.WHITE,
	"I2": Color.LIGHT_BLUE,
	"I3": Color.LIGHT_GREEN
}

# 多语言支持
const TEXTS = {
	"zh": {
		"score": "分数: ",
		"lines": "行数: ",
		"next": "下一个:",
		"game_over": "游戏结束！\n按 Enter 重新开始",
		"paused": "游戏暂停\n按 P 继续",
		"controls": "控制:\n← → 移动\n↑ 旋转\n↓ 快速下降\nEnter 硬降落\nEsc 暂停游戏",
		"scoring": "计分规则:\n1行 = 100分\n2行 = 300分\n3行 = 500分\n4行 = 800分"
	},
	"en": {
		"score": "Score: ",
		"lines": "Lines: ",
		"next": "Next:",
		"game_over": "Game Over!\nPress Enter to Restart",
		"paused": "PAUSED\nPress P to Continue",
		"controls": "Controls:\n← → Move\n↑ Rotate\n↓ Soft Drop\nEnter Hard Drop\nEsc Pause",
		"scoring": "Scoring:\n1 Line = 100pts\n2 Lines = 300pts\n3 Lines = 500pts\n4 Lines = 800pts"
	}
}

# 游戏状态
var grid = []  # 游戏网格 (存储颜色)
var grid_chars = []  # 歌词网格 (存储字符)
var current_piece = null  # 当前方块
var current_shape = ""  # 当前形状类型
var current_rotation = 0  # 当前旋转状态
var current_pos = Vector2i(0, 0)  # 当前位置
var next_shape = ""  # 下一个方块类型
var fall_timer = 0.0
var lock_timer = 0.0  # 方块锁定计时器
var is_locking = false  # 是否正在锁定倒计时
var score = 0
var lines_cleared_total = 0
var game_over = false
var paused = false

# 按键重复相关
var key_timers = {}
var keys_pressed = {}

# 歌词系统
var lyrics: Array[LyricsParser.LyricLine] = []
var current_lyric_index = 0
var lyric_blocks: Array = []  # 当前歌词的文字方块 (普通Array，兼容Python桥接器)
var current_lyric_char_index = 0  # 当前歌词的字符索引
var current_lyric_chars: Array = []  # 当前方块的字符数组
var next_piece_chars: Array = []  # 下一个方块的字符数组（缓存）
var next_piece_index = 0  # 下一个方块的索引位置（缓存）
var current_chinese_lyric = ""  # 当前显示的中文歌词
var lyric_mode = false  # 是否启用歌词模式
var music_time = 0.0  # 当前音乐播放时间

# UI节点
@onready var score_label = $UI/ScoreLabel
@onready var lines_label = $UI/LinesLabel
@onready var next_label = $UI/NextLabel
@onready var game_over_label = $UI/GameOverLabel
@onready var controls_label = $UI/ControlsLabel
@onready var scoring_label = $UI/ScoringLabel
@onready var pause_menu = $UI/PauseMenu
@onready var game_over_menu = $UI/GameOverMenu
@onready var chinese_lyric_label = $UI/ChineseLyricLabel
@onready var music_player = $MusicPlayer

func _ready():
	# 初始化Python桥接器
	var LyricPythonBridge = load("res://LyricPythonBridge.gd")
	python_bridge = LyricPythonBridge.new()
	
	initialize_grid()
	game_over_label.hide()
	pause_menu.hide()
	game_over_menu.hide()
	update_ui_texts()
	
	# 连接暂停菜单信号
	pause_menu.resume_game.connect(_on_resume_game)
	pause_menu.goto_options.connect(_on_goto_options)
	pause_menu.goto_menu.connect(_on_goto_menu)
	
	# 连接游戏失败菜单信号
	game_over_menu.restart_game.connect(_on_restart_game)
	game_over_menu.goto_menu.connect(_on_goto_menu)
	
	# 连接音乐播放完成信号（用于BGM循环）
	music_player.finished.connect(_on_music_finished)
	
	# 设置窗口大小
	get_window().size = Global.resolutions[Global.current_resolution_index]
	
	# 检查是否启用歌曲模式
	if Global.lyric_mode_enabled:
		print("=== 进入歌曲模式 ===")
		load_lyrics()
		start_lyric_mode()
		# 歌曲模式下不生成下一个方块预览
	else:
		print("=== 进入经典模式 ===")
		chinese_lyric_label.hide()
		scoring_label.show()  # 经典模式显示计分规则
		# 加载经典模式背景音乐
		var bgm = load("res://musics/bgm/货郎8bit(Коробейники).mp3")
		if bgm:
			music_player.stream = bgm
			music_player.volume_db = -8  # 降低音量（-8dB约为原音量的40%）
			music_player.play()
			print("经典模式背景音乐已加载")
		generate_next_piece()
		spawn_new_piece()

# 监听音乐播放完成信号以实现循环
func _on_music_finished():
	if not lyric_mode and music_player.stream:
		# 经典模式下循环播放BGM
		music_player.play()

func update_ui_texts():
	var texts = TEXTS[Global.current_language]
	score_label.text = texts["score"] + str(score)
	lines_label.text = texts["lines"] + str(lines_cleared_total)
	next_label.text = texts["next"]
	game_over_label.text = texts["game_over"]
	controls_label.text = texts["controls"]
	scoring_label.text = texts["scoring"]

func load_lyrics():
	# 如果没有选择歌曲，使用默认歌曲
	if Global.selected_song.is_empty():
		Global.selected_song = {
			"name": "Masked bitcH",
			"artist": "ギガP feat. GUMI",
			"music_file": "res://musics/ギガP GUMI - Masked bitcH.mp3",
			"lyric_file": "res://musics/lyrics/Masked bitcH.lrc"
		}
	
	# 使用Python桥接器加载歌词文件
	var lyric_path = Global.selected_song["lyric_file"]
	var result = python_bridge.parse_lrc_file(lyric_path)
	
	# 转换为LyricLine数组
	lyrics.clear()
	for lyric_data in result.get("lyrics", []):
		var lyric_line = LyricsParser.LyricLine.new(
			lyric_data.get("time", 0.0),
			lyric_data.get("japanese", ""),
			lyric_data.get("chinese", "")
		)
		lyrics.append(lyric_line)
	
	# 获取lyric_blocks并同步到桥接器缓存
	lyric_blocks = result.get("lyric_blocks", [])
	python_bridge.cached_lyric_blocks = lyric_blocks
	
	print("加载了 ", lyrics.size(), " 行歌词")
	print("总歌词字符数: ", lyric_blocks.size())
	
	# 加载音乐文件
	var music_path = Global.selected_song["music_file"]
	var music = load(music_path)
	if music:
		music_player.stream = music
		print("音乐加载成功: ", Global.selected_song["name"])
	else:
		push_error("无法加载音乐: " + music_path)

func start_lyric_mode():
	# 启动歌词模式
	lyric_mode = true
	current_lyric_index = 0
	current_lyric_char_index = 0
	current_chinese_lyric = "准备开始..."
	music_time = 0.0
	
	print("=== 启动歌曲模式 ===")
	print("歌曲: ", Global.selected_song.get("name", "未知"))
	print("歌词行数: ", lyrics.size())
	print("总歌词字符数: ", lyric_blocks.size())
	print("桥接器缓存字符数: ", python_bridge.cached_lyric_blocks.size())
	
	# 打印前几个字符用于调试
	if lyric_blocks.size() > 0:
		var preview = ""
		for i in range(min(20, lyric_blocks.size())):
			var char = lyric_blocks[i]
			if char == "\n":
				preview += "[换行]"
			else:
				preview += char
		print("歌词预览: ", preview)
	
	# 播放音乐
	if music_player.stream:
		music_player.play()
		print("开始播放音乐，时长: ", music_player.stream.get_length(), "秒")
	else:
		print("错误: 音乐流未加载")
	
	# 隐藏计分规则，显示中文歌词
	scoring_label.hide()
	chinese_lyric_label.show()
	chinese_lyric_label.text = "中文翻译:\n准备开始..."
	print("中文歌词将显示在计分规则位置")
	
	# 生成第一个歌词方块
	spawn_lyric_piece()

func initialize_grid():
	# 初始化空网格
	grid = []
	grid_chars = []
	for y in range(GRID_HEIGHT):
		var row = []
		var char_row = []
		for x in range(GRID_WIDTH):
			row.append(null)
			char_row.append("")
		grid.append(row)
		grid_chars.append(char_row)

func generate_next_piece():
	# 生成下一个方块类型（经典模式只用7种4格方块）
	var classic_shapes = ["I", "O", "T", "S", "Z", "J", "L"]
	next_shape = classic_shapes[randi() % classic_shapes.size()]

func spawn_new_piece():
	# 如果是歌词模式
	if lyric_mode:
		# 如果还有歌词字符未使用，生成歌词方块
		if current_lyric_char_index < lyric_blocks.size():
			spawn_lyric_piece()
			var chars_left = lyric_blocks.size() - current_lyric_char_index
			print("生成歌词方块 [", current_lyric_char_index, "/", lyric_blocks.size(), "], 剩余: ", chars_left)
			return
		else:
			# 所有歌词用完了
			print("所有歌词已显示完毕")
			current_piece = null
		return
	
	# 经典模式：使用之前生成的下一个方块
	current_shape = next_shape
	current_rotation = 0
	current_pos = Vector2i(GRID_WIDTH / 2 - 2, 0)
	current_piece = SHAPES[current_shape][current_rotation]
	
	# 重置锁定状态
	is_locking = false
	lock_timer = 0.0
	
	# 生成新的下一个方块
	generate_next_piece()
	
	# 检查游戏是否结束
	if not can_place_piece(current_pos, current_piece):
		game_over = true
		show_game_over_menu()

func spawn_lyric_piece():
	# 第一次调用：使用缓存的next_piece_chars作为当前方块
	if next_piece_chars.size() > 0 and not next_shape.is_empty():
		# 使用预览的方块作为当前方块
		current_shape = next_shape
		current_lyric_chars = next_piece_chars.duplicate()
		# 重要：直接使用缓存的next_piece_index，不要重新计算
		current_lyric_char_index = next_piece_index
		print("[spawn] 使用预览方块: ", current_shape, " - 字符: ", current_lyric_chars, " 索引:", current_lyric_char_index)
	else:
		# 首次调用或没有预览，生成新方块
		var piece_info = python_bridge.get_next_piece_info(current_lyric_char_index)
		if piece_info.get("size", 0) == 0:
			current_piece = null
			next_shape = ""
			current_lyric_chars = []
			next_piece_chars = []
			return
		current_shape = piece_info.get("shape", "")
		current_lyric_chars = piece_info.get("chars", [])
		current_lyric_char_index = piece_info.get("new_index", current_lyric_char_index)
		print("[spawn] 生成新方块: ", current_shape, " - 字符: ", current_lyric_chars)
	
	current_rotation = 0
	current_pos = Vector2i(GRID_WIDTH / 2 - 2, 0)
	current_piece = SHAPES[current_shape][0]
	
	# 生成下一个预览方块
	var next_info = python_bridge.get_next_piece_info(current_lyric_char_index)
	if next_info.get("size", 0) > 0:
		next_shape = next_info.get("shape", "")
		next_piece_chars = next_info.get("chars", [])
		next_piece_index = next_info.get("new_index", current_lyric_char_index)  # 缓存索引
		print("[spawn] 预览下一个: ", next_shape, " - 字符: ", next_piece_chars, " 索引:", next_piece_index)
	else:
		next_shape = ""
		next_piece_chars = []
	
	# 重置锁定状态
	is_locking = false
	lock_timer = 0.0
	
	# 检查游戏是否结束
	if not can_place_piece(current_pos, current_piece):
		game_over = true
		show_game_over_menu()

func can_place_piece(pos: Vector2i, piece: Array) -> bool:
	# 检查方块是否可以放置在指定位置
	for cell in piece:
		var x = pos.x + cell.x
		var y = pos.y + cell.y
		
		# 检查边界
		if x < 0 or x >= GRID_WIDTH or y >= GRID_HEIGHT:
			return false
		
		# 检查是否与已有方块重叠
		if y >= 0 and grid[y][x] != null:
			return false
	
	return true

func place_piece():
	# 将方块固定到网格
	var piece_color = Color.WHITE if lyric_mode else COLORS[current_shape]
	
	var cell_index = 0
	for cell in current_piece:
		var x = current_pos.x + cell.x
		var y = current_pos.y + cell.y
		if y >= 0:
			grid[y][x] = piece_color
			# 如果是歌词模式，保存字符（从current_lyric_chars获取）
			if lyric_mode and cell_index < current_lyric_chars.size():
				grid_chars[y][x] = current_lyric_chars[cell_index]
		cell_index += 1
	
	# 检查并清除完整的行
	clear_lines()
	
	# 生成新方块
	spawn_new_piece()

func clear_lines():
	# 清除完整的行
	var lines_cleared = 0
	var y = GRID_HEIGHT - 1
	
	while y >= 0:
		var is_full = true
		for x in range(GRID_WIDTH):
			if grid[y][x] == null:
				is_full = false
				break
		
		if is_full:
			lines_cleared += 1
			# 移除当前行
			grid.remove_at(y)
			grid_chars.remove_at(y)
			# 在顶部添加新的空行
			var new_row = []
			var new_char_row = []
			for x in range(GRID_WIDTH):
				new_row.append(null)
				new_char_row.append("")
			grid.insert(0, new_row)
			grid_chars.insert(0, new_char_row)
			# 不递减y，因为上面的行已经下移了
		else:
			y -= 1
	
	# 更新分数和统计
	if lines_cleared > 0:
		lines_cleared_total += lines_cleared
		# 计分规则：1行=100，2行=300，3行=500，4行=800
		var line_scores = [0, 100, 300, 500, 800]
		score += line_scores[min(lines_cleared, 4)]
		update_ui_texts()

func move_piece(direction: Vector2i) -> bool:
	# 移动方块
	if current_piece == null:
		return false
	
	var new_pos = current_pos + direction
	if can_place_piece(new_pos, current_piece):
		current_pos = new_pos
		# 移动成功时重置锁定计时器
		if direction.y == 1:  # 如果是向下移动
			is_locking = false
			lock_timer = 0.0
		return true
	return false

func rotate_piece():
	# 旋转方块 - 使用预定义的旋转状态
	if current_piece == null:
		return
	
	# 只有O和DOT不能旋转（对称形状）
	if current_shape == "O" or current_shape == "DOT":
		return
	
	# PLUS是对称的，不需要旋转
	if current_shape == "PLUS":
		return
	
	var new_rotation = (current_rotation + 1) % SHAPES[current_shape].size()
	var rotated_piece = SHAPES[current_shape][new_rotation]
	
	# 尝试在当前位置旋转
	if can_place_piece(current_pos, rotated_piece):
		current_rotation = new_rotation
		current_piece = rotated_piece
		is_locking = false
		lock_timer = 0.0
		return
	
	# 智能墙踢：根据方块大小调整尝试范围
	var kick_offsets = []
	
	# 计算方块占据的最大宽度和高度
	var max_x = 0
	var max_y = 0
	for cell in rotated_piece:
		max_x = max(max_x, cell.x)
		max_y = max(max_y, cell.y)
	
	# 根据大小设置墙踢范围
	if max_x <= 2 and max_y <= 2:  # 小方块 (2x2区域内)
		kick_offsets = [Vector2i(-1, 0), Vector2i(1, 0)]  # 只尝试左右
	elif max_x <= 3 and max_y <= 3:  # 中型方块 (3x3区域)
		kick_offsets = [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(-2, 0), Vector2i(2, 0)]  # 左右2格
	else:  # 大型方块 (4x4或更大)
		kick_offsets = [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(-2, 0), Vector2i(2, 0), Vector2i(0, -1)]  # 加上向上
	
	for offset in kick_offsets:
		if can_place_piece(current_pos + offset, rotated_piece):
			current_pos += offset
			current_rotation = new_rotation
			current_piece = rotated_piece
			is_locking = false
			lock_timer = 0.0
			return

func toggle_pause():
	paused = !paused
	if paused:
		pause_menu.show()
		pause_menu.update_ui_texts()
		# 隐藏游戏UI元素
		score_label.hide()
		lines_label.hide()
		next_label.hide()
		controls_label.hide()
		scoring_label.hide()
		# 暂停音乐（经典模式和歌词模式都暂停）
		if music_player.playing:
			music_player.stream_paused = true
	else:
		pause_menu.hide()
		# 显示游戏UI元素
		score_label.show()
		lines_label.show()
		next_label.show()
		controls_label.show()
		scoring_label.show()
		# 恢复音乐（经典模式和歌词模式都恢复）
		if music_player.stream_paused:
			music_player.stream_paused = false

func show_game_over_menu():
	game_over_menu.show()
	game_over_menu.update_ui_texts()
	game_over_menu.set_score(score, lines_cleared_total)
	# 隐藏游戏UI元素
	score_label.hide()
	lines_label.hide()
	next_label.hide()
	controls_label.hide()
	scoring_label.hide()
	chinese_lyric_label.hide()
	# 停止音乐
	if lyric_mode and music_player.playing:
		music_player.stop()

func show_song_complete_menu():
	# 歌曲完成界面（类似暂停界面）
	paused = true
	pause_menu.show()
	pause_menu.update_ui_texts()
	# 隐藏游戏UI元素
	score_label.hide()
	lines_label.hide()
	next_label.hide()
	controls_label.hide()
	scoring_label.hide()
	chinese_lyric_label.hide()
	print("歌曲已完成！")

func _on_resume_game():
	toggle_pause()

func _on_restart_game():
	restart_game()

func _on_goto_options():
	# 暂停状态下进入选项,使用弹出层而不是切换场景
	pause_menu.hide()  # 隐藏暂停菜单
	var options_scene = load("res://OptionsMenu.tscn")
	var options_instance = options_scene.instantiate()
	options_instance.set_meta("from_game", true)  # 标记来自游戏
	options_instance.tree_exited.connect(_on_options_closed)  # 连接关闭信号
	get_tree().root.add_child(options_instance)

func _on_options_closed():
	# 从设置返回游戏时
	if paused:
		pause_menu.show()  # 重新显示暂停菜单
		pause_menu.update_ui_texts()  # 更新暂停菜单文本(语言可能改变)
		update_ui_texts()  # 更新游戏UI文本(虽然隐藏,但保持最新)

func hard_drop():
	# 硬降落（不加分）
	while move_piece(Vector2i(0, 1)):
		pass
	place_piece()
	is_locking = false
	lock_timer = 0.0

func _on_goto_menu():
	get_tree().change_scene_to_file("res://MainMenu.tscn")

func return_to_menu():
	# 返回主菜单
	get_tree().change_scene_to_file("res://MainMenu.tscn")

func restart_game():
	# 重新开始游戏
	# 不重置lyric_mode_enabled，保持当前模式
	get_tree().reload_current_scene()

func _process(delta):
	if paused:
		return
	
	# 更新歌词系统（仅更新中文歌词显示）
	if lyric_mode:
		if music_player.playing:
			music_time = music_player.get_playback_position()
			update_lyrics()
		else:
			# 即使音乐未播放,也要更新时间(例如初始化阶段)
			music_time += delta
			update_lyrics()
	
	# 检查歌曲是否播放完毕且所有歌词已下落
	if lyric_mode and not music_player.playing and current_piece == null and current_lyric_char_index >= lyric_blocks.size():
		if not game_over and not paused:
			show_song_complete_menu()
	
	# 处理按键重复
	handle_key_repeat(delta)
	
	# 自动下落（只在有活动方块时，且游戏未结束）
	if not game_over and current_piece != null:
		fall_timer += delta
		if fall_timer >= FALL_SPEED:
			fall_timer = 0.0
			if not move_piece(Vector2i(0, 1)):
				# 无法下落，开始锁定倒计时
				if not is_locking:
					is_locking = true
					lock_timer = 0.0
	
		# 处理方块锁定
		if is_locking:
			lock_timer += delta
			if lock_timer >= LOCK_DELAY:
				place_piece()
				is_locking = false
				lock_timer = 0.0
	
	# 重绘
	queue_redraw()

func handle_key_repeat(delta):
	# 处理按键重复逻辑
	for key in key_timers.keys():
		if keys_pressed.get(key, false):
			key_timers[key] -= delta
			if key_timers[key] <= 0:
				# 执行重复动作
				match key:
					"left":
						move_piece(Vector2i(-1, 0))
					"right":
						move_piece(Vector2i(1, 0))
					"down":
						move_piece(Vector2i(0, 1))
				key_timers[key] = REPEAT_RATE

func update_lyrics():
	# 更新中文歌词显示（根据时间轴）
	if current_lyric_index >= lyrics.size():
		return
	
	var current_lyric = lyrics[current_lyric_index]
	
	# 检查是否到达新歌词的时间
	if music_time >= current_lyric.time:
		# 更新中文歌词显示（如果有中文就显示中文，否则显示日文）
		if not current_lyric.chinese.is_empty():
			current_chinese_lyric = current_lyric.chinese
		else:
			current_chinese_lyric = current_lyric.japanese
		
		# 更新Label显示
		if chinese_lyric_label:
			chinese_lyric_label.text = "中文翻译:\n" + current_chinese_lyric
		
		print("=== 新歌词 [", current_lyric_index, "] ===")
		print("时间: ", current_lyric.time, "s")
		print("日文: ", current_lyric.japanese)
		print("中文: ", current_lyric.chinese)
		
		# 移动到下一行歌词
		current_lyric_index += 1

func _input(event):
	# 游戏结束或暂停时，只处理菜单相关输入，不处理游戏操作
	if game_over or paused:
		return
	
	if event.is_action_pressed("ui_cancel"):  # ESC键
		toggle_pause()
		return
	
	# 处理按键按下
	if event.is_action_pressed("ui_left"):
		move_piece(Vector2i(-1, 0))
		keys_pressed["left"] = true
		key_timers["left"] = REPEAT_DELAY
	elif event.is_action_released("ui_left"):
		keys_pressed["left"] = false
	
	elif event.is_action_pressed("ui_right"):
		move_piece(Vector2i(1, 0))
		keys_pressed["right"] = true
		key_timers["right"] = REPEAT_DELAY
	elif event.is_action_released("ui_right"):
		keys_pressed["right"] = false
	
	elif event.is_action_pressed("ui_down"):
		move_piece(Vector2i(0, 1))
		keys_pressed["down"] = true
		key_timers["down"] = REPEAT_DELAY
	elif event.is_action_released("ui_down"):
		keys_pressed["down"] = false
	
	elif event.is_action_pressed("ui_up"):
		rotate_piece()
	
	elif event.is_action_pressed("ui_accept"):  # Enter键硬降落
		hard_drop()

func _draw():
	# 绘制网格背景
	var grid_rect = Rect2(GRID_OFFSET_X, GRID_OFFSET_Y, GRID_WIDTH * CELL_SIZE, GRID_HEIGHT * CELL_SIZE)
	draw_rect(grid_rect, Color(0.1, 0.1, 0.1))
	
	# 绘制网格边框
	draw_rect(grid_rect, Color.WHITE, false, 2)
	
	# 绘制网格线
	for x in range(1, GRID_WIDTH):
		draw_line(
			Vector2(GRID_OFFSET_X + x * CELL_SIZE, GRID_OFFSET_Y),
			Vector2(GRID_OFFSET_X + x * CELL_SIZE, GRID_OFFSET_Y + GRID_HEIGHT * CELL_SIZE),
			Color(0.3, 0.3, 0.3)
		)
	for y in range(1, GRID_HEIGHT):
		draw_line(
			Vector2(GRID_OFFSET_X, GRID_OFFSET_Y + y * CELL_SIZE),
			Vector2(GRID_OFFSET_X + GRID_WIDTH * CELL_SIZE, GRID_OFFSET_Y + y * CELL_SIZE),
			Color(0.3, 0.3, 0.3)
		)
	
	# 绘制已固定的方块
	var font = load("res://fonts/FUSION-PIXEL-12PX-MONOSPACED-ZH_HANS.OTF")
	for y in range(GRID_HEIGHT):
		for x in range(GRID_WIDTH):
			if grid[y][x] != null:
				if lyric_mode:
					# 歌词模式：绘制白色文字（上移3像素）
					if not grid_chars[y][x].is_empty():
						var char_text = grid_chars[y][x]
						var font_size = 24
						var string_size = font.get_string_size(char_text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
						var text_pos = Vector2(
							GRID_OFFSET_X + x * CELL_SIZE + (CELL_SIZE - string_size.x) / 2,
							GRID_OFFSET_Y + y * CELL_SIZE + (CELL_SIZE + string_size.y) / 2 - 5
						)
						draw_string(font, text_pos, char_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)
					else:
						# 经典模式：绘制彩色方块
						draw_rect(
							Rect2(
								GRID_OFFSET_X + x * CELL_SIZE + 1, 
								GRID_OFFSET_Y + y * CELL_SIZE + 1, 
								CELL_SIZE - 2, 
								CELL_SIZE - 2
							),
							grid[y][x]
						)
	
	# 绘制当前方块
	if current_piece != null and not paused:
		if lyric_mode:
			# 歌词模式：只绘制文字，不绘制方块背景
			var cell_index = 0
			for cell in current_piece:
				var x = current_pos.x + cell.x
				var y = current_pos.y + cell.y
				if y >= 0 and x >= 0 and x < GRID_WIDTH and y < GRID_HEIGHT:
					if cell_index < current_lyric_chars.size():
						var char_text = current_lyric_chars[cell_index]
						if char_text != "\n":  # 只跳过换行
							var font_size = 24
							# 计算文字居中位置（上移3像素）
							var string_size = font.get_string_size(char_text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
							var text_pos = Vector2(
								GRID_OFFSET_X + x * CELL_SIZE + (CELL_SIZE - string_size.x) / 2,
								GRID_OFFSET_Y + y * CELL_SIZE + (CELL_SIZE + string_size.y) / 2 - 5
							)
							# 白色文字
							draw_string(font, text_pos, char_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)
				cell_index += 1
		else:
			# 经典模式：绘制彩色方块
			for cell in current_piece:
				var x = current_pos.x + cell.x
				var y = current_pos.y + cell.y
				if y >= 0 and x >= 0 and x < GRID_WIDTH and y < GRID_HEIGHT:
					draw_rect(
						Rect2(
							GRID_OFFSET_X + x * CELL_SIZE + 1, 
							GRID_OFFSET_Y + y * CELL_SIZE + 1, 
							CELL_SIZE - 2, 
							CELL_SIZE - 2
						),
						COLORS[current_shape]
					)
	
	# 绘制下一个方块预览
	if not paused:
		draw_next_piece_preview()

func draw_next_piece_preview(): # 预览方块
	var preview_x = GRID_OFFSET_X + GRID_WIDTH * CELL_SIZE + 30
	var preview_y = 160 
	var preview_size = 20
	var font = load("res://fonts/FUSION-PIXEL-12PX-MONOSPACED-ZH_HANS.OTF")
	
	# 经典模式和歌曲模式都显示预览方块
	draw_rect(Rect2(preview_x - 15, preview_y - 15, 95, 95), Color(0.2, 0.2, 0.2))
	draw_rect(Rect2(preview_x - 15, preview_y - 15, 95, 95), Color.WHITE, false, 1)
	
	if not lyric_mode:
		# 经典模式：绘制下一个方块
		var next_piece = SHAPES[next_shape][0]
		for cell in next_piece:
			draw_rect(
				Rect2(
					preview_x + cell.x * preview_size, 
					preview_y + cell.y * preview_size, 
					preview_size - 1, 
					preview_size - 1
				),
				COLORS[next_shape]
			)
	else:
		# 歌词模式：显示下一个歌词方块预览
		if not next_shape.is_empty():
			var next_piece = SHAPES[next_shape][0]
			
			# 绘制下一个方块的文字（使用缓存的next_piece_chars）
			var cell_idx = 0
			for cell in next_piece:
				if cell_idx < next_piece_chars.size():
					var char_text = next_piece_chars[cell_idx]
					if char_text != "\n":  # 跳过换行
						var preview_font_size = 16
						var string_size = font.get_string_size(char_text, HORIZONTAL_ALIGNMENT_CENTER, -1, preview_font_size)
						var text_pos = Vector2(
							preview_x + cell.x * preview_size + (preview_size - string_size.x) / 2,
							preview_y + cell.y * preview_size + (preview_size + string_size.y) / 2 - 3
						)
						draw_string(font, text_pos, char_text, HORIZONTAL_ALIGNMENT_LEFT, -1, preview_font_size, Color.WHITE)
				cell_idx += 1
		else:
			# 没有下一个方块了，显示歌曲完成
			var hint_text = "歌曲\n完成"
			var text_pos = Vector2(preview_x + 15, preview_y + 35)
			draw_string(font, text_pos, hint_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.5, 1, 0.5))
