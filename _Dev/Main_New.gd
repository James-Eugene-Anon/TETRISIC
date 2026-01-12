extends Node2D

## 主游戏控制器 - 使用面向对象架构

# 游戏模式控制器
var game_mode: BaseGameModeController = null
var renderer: GameRenderer = null
var input_handler: InputHandler = null

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
	# 初始化组件
	setup_components()
	setup_ui()
	
	# 设置窗口大小
	get_window().size = Global.resolutions[Global.current_resolution_index]
	
	# 启动对应模式
	if Global.lyric_mode_enabled:
		start_lyric_mode()
	else:
		start_classic_mode()

func setup_components():
	"""初始化核心组件"""
	# 创建输入处理器
	input_handler = InputHandler.new()
	add_child(input_handler)
	
	# 创建渲染器
	renderer = GameRenderer.new()
	add_child(renderer)
	
	# 连接输入信号
	input_handler.move_left.connect(_on_move_left)
	input_handler.move_right.connect(_on_move_right)
	input_handler.move_down.connect(_on_move_down)
	input_handler.rotate.connect(_on_rotate)
	input_handler.hard_drop.connect(_on_hard_drop)
	input_handler.pause_toggle.connect(_on_pause_toggle)

func setup_ui():
	"""设置UI"""
	game_over_label.hide()
	pause_menu.hide()
	game_over_menu.hide()
	update_ui_texts()
	
	# 连接菜单信号
	pause_menu.resume_game.connect(_on_resume_game)
	pause_menu.goto_options.connect(_on_goto_options)
	pause_menu.goto_menu.connect(_on_goto_menu)
	game_over_menu.restart_game.connect(_on_restart_game)
	game_over_menu.goto_menu.connect(_on_goto_menu)
	music_player.finished.connect(_on_music_finished)

func start_classic_mode():
	"""启动经典模式"""
	print("=== 进入经典模式 ===")
	
	game_mode = ClassicModeController.new()
	add_child(game_mode)
	game_mode.initialize()
	
	# 连接游戏模式信号
	game_mode.game_over_signal.connect(_on_game_over)
	game_mode.score_changed.connect(_on_score_changed)
	game_mode.lines_changed.connect(_on_lines_changed)
	
	# 设置渲染器
	renderer.set_lyric_mode(false)
	
	# UI设置
	chinese_lyric_label.hide()
	scoring_label.show()
	
	# 加载BGM
	var bgm = load("res://musics/bgm/货郎8bit(Коробейники).mp3")
	if bgm:
		music_player.stream = bgm
		music_player.volume_db = -8
		music_player.play()
		print("经典模式背景音乐已加载")

func start_lyric_mode():
	"""启动歌词模式"""
	print("=== 进入歌曲模式 ===")
	
	# 如果没有选择歌曲，使用默认歌曲
	if Global.selected_song.is_empty():
		Global.selected_song = {
			"name": "Masked bitcH",
			"artist": "ギガP feat. GUMI",
			"music_file": "res://musics/ギガP GUMI - Masked bitcH.mp3",
			"lyric_file": "res://musics/lyrics/Masked bitcH.lrc"
		}
	
	game_mode = LyricModeController.new()
	add_child(game_mode)
	
	# 加载歌曲
	game_mode.load_song(Global.selected_song)
	game_mode.start_song()
	
	# 连接游戏模式信号
	game_mode.game_over_signal.connect(_on_game_over)
	game_mode.score_changed.connect(_on_score_changed)
	game_mode.lines_changed.connect(_on_lines_changed)
	game_mode.lyric_changed.connect(_on_lyric_changed)
	
	# 设置渲染器
	renderer.set_lyric_mode(true)
	
	# UI设置
	scoring_label.hide()
	chinese_lyric_label.show()
	chinese_lyric_label.text = "中文翻译:\n准备开始..."
	
	# 加载音乐
	var music = load(Global.selected_song["music_file"])
	if music:
		music_player.stream = music
		music_player.play()
		print("音乐加载成功: ", Global.selected_song["name"])

func _process(delta):
	if game_mode == null:
		return
	
	# 更新游戏逻辑
	game_mode.update(delta)
	
	# 检查歌曲模式是否完成
	if game_mode is LyricModeController:
		if not music_player.playing and game_mode.is_song_complete():
			if not game_mode.game_over and not game_mode.paused:
				show_song_complete_menu()
	
	# 更新渲染器
	update_renderer()
	queue_redraw()

func update_renderer():
	"""更新渲染器状态"""
	if renderer == null or game_mode == null:
		return
	
	renderer.set_grid_manager(game_mode.grid_manager)
	renderer.set_current_piece(game_mode.current_piece)
	renderer.set_next_piece_data(game_mode.next_piece_data)

func _draw():
	if renderer:
		renderer._draw()

func _input(event):
	if input_handler:
		var is_game_over = game_mode.game_over if game_mode else false
		var is_paused = game_mode.paused if game_mode else false
		input_handler.handle_input(event, is_game_over, is_paused)

# 输入信号处理
func _on_move_left():
	if game_mode:
		game_mode.move_piece(Vector2i(-1, 0))

func _on_move_right():
	if game_mode:
		game_mode.move_piece(Vector2i(1, 0))

func _on_move_down():
	if game_mode:
		game_mode.move_piece(Vector2i(0, 1))

func _on_rotate():
	if game_mode:
		game_mode.rotate_piece()

func _on_hard_drop():
	if game_mode:
		game_mode.hard_drop()

func _on_pause_toggle():
	toggle_pause()

# 游戏模式信号处理
func _on_game_over():
	show_game_over_menu()

func _on_score_changed(score: int):
	score_label.text = TEXTS[Global.current_language]["score"] + str(score)

func _on_lines_changed(lines: int):
	lines_label.text = TEXTS[Global.current_language]["lines"] + str(lines)

func _on_lyric_changed(japanese: String, chinese: String):
	if chinese_lyric_label:
		chinese_lyric_label.text = "中文翻译:\n" + chinese

# UI相关
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

func update_ui_texts():
	var texts = TEXTS[Global.current_language]
	score_label.text = texts["score"] + "0"
	lines_label.text = texts["lines"] + "0"
	next_label.text = texts["next"]
	game_over_label.text = texts["game_over"]
	controls_label.text = texts["controls"]
	scoring_label.text = texts["scoring"]

func toggle_pause():
	if game_mode == null:
		return
	
	game_mode.toggle_pause()
	
	if game_mode.paused:
		pause_menu.show()
		pause_menu.update_ui_texts()
		score_label.hide()
		lines_label.hide()
		next_label.hide()
		controls_label.hide()
		scoring_label.hide()
		if music_player.playing:
			music_player.stream_paused = true
	else:
		pause_menu.hide()
		score_label.show()
		lines_label.show()
		next_label.show()
		controls_label.show()
		scoring_label.show()
		if music_player.stream_paused:
			music_player.stream_paused = false

func show_game_over_menu():
	if game_mode == null:
		return
	
	game_over_menu.show()
	game_over_menu.update_ui_texts()
	game_over_menu.set_score(game_mode.score, game_mode.lines_cleared_total)
	
	score_label.hide()
	lines_label.hide()
	next_label.hide()
	controls_label.hide()
	scoring_label.hide()
	chinese_lyric_label.hide()
	
	if music_player.playing:
		music_player.stop()

func show_song_complete_menu():
	game_mode.paused = true
	pause_menu.show()
	pause_menu.update_ui_texts()
	
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
	get_tree().reload_current_scene()

func _on_goto_options():
	pause_menu.hide()
	var options_scene = load("res://OptionsMenu.tscn")
	var options_instance = options_scene.instantiate()
	options_instance.set_meta("from_game", true)
	options_instance.tree_exited.connect(_on_options_closed)
	get_tree().root.add_child(options_instance)

func _on_options_closed():
	if game_mode and game_mode.paused:
		pause_menu.show()
		pause_menu.update_ui_texts()
		update_ui_texts()

func _on_goto_menu():
	get_tree().change_scene_to_file("res://MainMenu.tscn")

func _on_music_finished():
	if game_mode is ClassicModeController and music_player.stream:
		music_player.play()
