extends Node2D

## 主游戏控制器

# 游戏模式控制器
var game_mode: BaseGameModeController = null
var renderer: GameRenderer = null
var input_handler: InputHandler = null
var music_visualizer: MusicVisualizer = null

# UI节点
@onready var score_label = $UI/ScoreLabel
@onready var lines_label = $UI/LinesLabel
@onready var next_label = $UI/NextLabel
@onready var combo_label = $UI/ComboLabel
@onready var game_over_label = $UI/GameOverLabel
@onready var controls_label = $UI/ControlsLabel
@onready var scoring_label = $UI/ScoringLabel
@onready var pause_menu = $UI/PauseMenu
@onready var game_over_menu = $UI/GameOverMenu
@onready var song_complete_menu = $UI/SongCompleteMenu
@onready var chinese_lyric_label = $UI/ChineseLyricLabel
@onready var rift_meter_label = $UI/RiftMeterLabel
@onready var beat_calibrator_label = $UI/BeatCalibratorLabel
@onready var music_player = $MusicPlayer

func _ready():
	# 初始化组件
	setup_components()
	setup_ui()
	
	# 连接音乐播放器完成信号
	music_player.finished.connect(_on_music_finished)
	print("[初始化] 音乐播放器finished信号已连接到_on_music_finished")
	
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
	song_complete_menu.hide()
	combo_label.text = ""  # 初始化连击标签
	update_ui_texts()
	
	# 连接菜单信号
	pause_menu.resume_game.connect(_on_resume_game)
	pause_menu.restart_game.connect(_on_restart_game)
	pause_menu.goto_options.connect(_on_goto_options)
	pause_menu.goto_menu.connect(_on_goto_menu)
	game_over_menu.restart_game.connect(_on_restart_game)
	game_over_menu.goto_menu.connect(_on_goto_menu)
	song_complete_menu.restart_game.connect(_on_restart_game)
	song_complete_menu.select_song.connect(_on_select_song)
	song_complete_menu.goto_menu.connect(_on_goto_menu)

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
	game_mode.combo_changed.connect(_on_combo_changed)
	game_mode.special_block_effect.connect(_on_special_block_effect)
	game_mode.snake_mode_changed.connect(_on_snake_mode_changed)
	
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
	
	# 创建音乐可视化背景
	_setup_music_visualizer()
	
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
	game_mode.combo_changed.connect(_on_combo_changed)
	game_mode.lyric_changed.connect(_on_lyric_changed)
	game_mode.all_blocks_placed.connect(_on_all_blocks_placed)
	game_mode.beat_rating_changed.connect(_on_beat_rating_changed)
	
	# 设置渲染器
	renderer.set_lyric_mode(true)
	
	# UI设置
	scoring_label.show()  # 歌词模式也显示计分规则
	chinese_lyric_label.show()
	chinese_lyric_label.z_index = -1  # 确保在暂停菜单下方
	# 加载歌词后根据是否中文歌曲更新标签
	chinese_lyric_label.text = "中文歌词:\n准备开始..." if game_mode.is_chinese_song else "中文翻译:\n准备开始..."
	
	# 加载音乐
	var music = load(Global.selected_song["music_file"])
	if music:
		music_player.stream = music
		music_player.play()
		# 设置歌曲时长到游戏模式
		game_mode.song_duration = music_player.stream.get_length()
		print("音乐加载成功: ", Global.selected_song["name"])
		print("[音乐播放器] stream已设置，开始播放")
		print("[音乐播放器] 音乐长度: ", game_mode.song_duration)
	else:
		print("[错误] 无法加载音乐: ", Global.selected_song["music_file"])

func _process(delta):
	if game_mode == null:
		return
	
	# 更新游戏逻辑
	game_mode.update(delta)
	
	# 更新裂隙仪冷却（只有未暂停时才更新）
	if game_mode.equipment_system and not game_mode.paused:
		game_mode.equipment_system.update_rift_meter(delta)
	
	# 更新裂隙仪冷却显示（暂停时隐藏）
	_update_rift_meter_display()
	
	# 更新贪吃蛇（如果在贪吃蛇模式）
	if game_mode is ClassicModeController and game_mode.is_snake_mode:
		game_mode.update_snake(delta)
	
	# 更新节拍评价显示计时器
	if renderer:
		renderer.update_beat_timer(delta)
	
	# 更新节拍评价显示计时器
	if beat_rating_display_timer > 0:
		beat_rating_display_timer -= delta
	
	# 更新渲染器
	update_renderer()
	
	# 更新节拍校对器显示
	_update_beat_calibrator_display()

func _update_rift_meter_display():
	"""更新裂隙仪冷却显示"""
	if not rift_meter_label:
		return
	
	# 暂停时隐藏裂隙仪显示
	if game_mode and game_mode.paused:
		rift_meter_label.text = ""
		return
	
	# 只有装备了裂隙仪才显示
	if not game_mode or not game_mode.equipment_system.is_equipped(EquipmentSystem.EquipmentType.RIFT_METER):
		rift_meter_label.text = ""
		return
	
	var cooldown = game_mode.equipment_system.get_rift_meter_cooldown()
	if cooldown > 0:
		# 显示冷却中（浅灰色）
		var cooldown_text = "裂隙仪: %.1fs" % cooldown if Global.current_language == "zh" else "Rift: %.1fs" % cooldown
		rift_meter_label.text = cooldown_text
		rift_meter_label.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75, 1))  # 浅灰色表示冷却中
	else:
		# 可以使用
		var ready_text = "裂隙仪: 按S" if Global.current_language == "zh" else "Rift: Press S"
		rift_meter_label.text = ready_text
		rift_meter_label.add_theme_color_override("font_color", Color(0.3, 0.9, 1.0, 1))  # 青色表示就绪

# 节拍评价显示状态
var beat_rating_display_timer: float = 0.0
var last_beat_display_text: String = ""
var last_beat_display_color: Color = Color.WHITE

func _update_beat_calibrator_display():
	"""更新节拍校对器状态显示"""
	if not beat_calibrator_label:
		return
	
	# 只在歌曲模式且装备了节拍校对器时显示
	if not game_mode is LyricModeController:
		beat_calibrator_label.text = ""
		return
	
	# 暂停时隐藏
	if game_mode.paused:
		beat_calibrator_label.text = ""
		return
	
	if not game_mode.equipment_system.is_equipped(EquipmentSystem.EquipmentType.BEAT_CALIBRATOR):
		beat_calibrator_label.text = ""
		return
	
	# 如果有最近的评价显示，保持显示
	if beat_rating_display_timer > 0:
		beat_calibrator_label.text = last_beat_display_text
		beat_calibrator_label.add_theme_color_override("font_color", last_beat_display_color)
	else:
		# 没有评价时显示等待状态
		var combo = game_mode.equipment_system.get_beat_combo()
		var status_text = "♪ 节拍校对器" if Global.current_language == "zh" else "♪ Beat Calibrator"
		if combo > 0:
			status_text += " x" + str(combo)
		beat_calibrator_label.text = status_text
		beat_calibrator_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2, 1))

func update_renderer():
	"""更新渲染器状态"""
	if renderer == null or game_mode == null:
		return
	
	renderer.set_grid_manager(game_mode.grid_manager)
	renderer.set_current_piece(game_mode.current_piece)
	renderer.set_next_piece_data(game_mode.next_piece_data)
	
	# 歌词模式设置方块颜色
	if game_mode is LyricModeController:
		var current_color = game_mode.get_piece_color()
		var next_color = game_mode.get_next_piece_color()
		renderer.set_lyric_piece_colors(current_color, next_color)
		renderer.set_special_block_info(Color.TRANSPARENT, "")  # 歌词模式无特殊方块
		renderer.set_next_special_block_info(Color.TRANSPARENT, "")  # 歌词模式无特殊方块
		renderer.set_snake_info([], false, false)  # 歌词模式无贪吃蛇
	elif game_mode is ClassicModeController:
		# 经典模式处理当前特殊方块
		if game_mode.is_special_block and game_mode.special_block_type >= 0:
			var color = game_mode.equipment_system.get_special_block_color(game_mode.special_block_type)
			var symbol = game_mode.equipment_system.get_special_block_symbol(game_mode.special_block_type)
			renderer.set_special_block_info(color, symbol)
		else:
			renderer.set_special_block_info(Color.TRANSPARENT, "")
		
		# 经典模式处理下一个特殊方块预览
		if game_mode.next_is_special_block and game_mode.next_special_block_type >= 0:
			var next_color = game_mode.equipment_system.get_special_block_color(game_mode.next_special_block_type)
			var next_symbol = game_mode.equipment_system.get_special_block_symbol(game_mode.next_special_block_type)
			renderer.set_next_special_block_info(next_color, next_symbol)
		else:
			renderer.set_next_special_block_info(Color.TRANSPARENT, "")
		
		# 处理贪吃蛇
		if game_mode.is_snake_mode and game_mode.snake_controller:
			renderer.set_snake_info(game_mode.snake_controller.get_body_positions(), true, false)
		else:
			renderer.set_snake_info([], false, game_mode.next_is_snake)
	
	renderer.queue_redraw()

func _input(event):
	if game_mode == null:
		return
	
	var is_game_over = game_mode.game_over
	var is_paused = game_mode.paused
	
	# 处理贪吃蛇输入（如果在贪吃蛇模式）
	if game_mode is ClassicModeController and game_mode.is_snake_mode:
		if not is_game_over and not is_paused:
			game_mode.handle_snake_input(event)
		# 贪吃蛇模式下只处理暂停
		if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
			_on_pause_toggle()
		return
	
	# 处理裂隙仪输入（按S键）
	if event is InputEventKey and event.pressed and event.keycode == KEY_S:
		if not is_game_over and not is_paused:
			if game_mode.equipment_system.try_activate_rift_meter(game_mode.grid_manager):
				# 显示裂隙仪效果
				combo_label.text = "裂隙仪!" if Global.current_language == "zh" else "Rift!"
				combo_label.add_theme_color_override("font_color", Color(0.3, 0.9, 1.0, 1.0))
				combo_label.scale = Vector2(1.5, 1.5)
				var tween = create_tween()
				tween.tween_property(combo_label, "scale", Vector2(1.0, 1.0), 0.3).set_ease(Tween.EASE_OUT)
				await get_tree().create_timer(1.0).timeout
				if combo_label.text.contains("裂隙仪") or combo_label.text.contains("Rift"):
					combo_label.text = ""
	
	if input_handler:
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

func _on_combo_changed(combo_count: int):
	"""连击数变化回调"""
	if combo_count >= 2:
		# 显示连击
		if Global.current_language == "zh":
			combo_label.text = str(combo_count) + " 连击！"
		else:
			combo_label.text = str(combo_count) + " Combo!"
		
		# 根据连击数设置颜色
		if combo_count > 10:
			combo_label.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2, 1.0))  # 红色
		elif combo_count >= 5:
			combo_label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.1, 1.0))  # 橙色
		else:
			combo_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2, 1.0))  # 黄色
		
		# 连击动画效果
		combo_label.scale = Vector2(1.3, 1.3)
		var tween = create_tween()
		tween.tween_property(combo_label, "scale", Vector2(1.0, 1.0), 0.2).set_ease(Tween.EASE_OUT)
	else:
		# 连击中断，清空显示
		combo_label.text = ""

func _on_special_block_effect(effect_type: String, position: Vector2i, destroyed: int):
	"""特殊方块效果触发回调"""
	var effect_names = {"BOMB": "💣炸弹", "LASER_H": "━横激光", "LASER_V": "┃纵激光"}
	var effect_name = effect_names.get(effect_type, effect_type)
	
	# 临时显示特效信息在连击标签位置
	combo_label.text = effect_name + "! +" + str(destroyed * 5)
	combo_label.add_theme_color_override("font_color", Color(1.0, 0.5, 0, 1.0))  # 橙色
	combo_label.scale = Vector2(1.5, 1.5)
	var tween = create_tween()
	tween.tween_property(combo_label, "scale", Vector2(1.0, 1.0), 0.3).set_ease(Tween.EASE_OUT)
	
	# 1.5秒后清除
	await get_tree().create_timer(1.5).timeout
	if combo_label.text.contains(effect_name):
		combo_label.text = ""

func _on_snake_mode_changed(is_snake: bool):
	"""贪吃蛇模式变化回调"""
	if is_snake:
		combo_label.text = "🐍贪吃蛇!" if Global.current_language == "zh" else "🐍Snake!"
		combo_label.add_theme_color_override("font_color", Color(0.4, 0.9, 0.4, 1.0))  # 绿色
		combo_label.scale = Vector2(1.5, 1.5)
		var tween = create_tween()
		tween.tween_property(combo_label, "scale", Vector2(1.0, 1.0), 0.3).set_ease(Tween.EASE_OUT)

func _on_beat_rating_changed(rating: int, text: String, color: Color, beat_combo: int):
	"""节拍评价变化回调"""
	print("[Main] 收到节拍评价: ", text, " 连击: ", beat_combo)
	renderer.set_beat_rating_info(text, color, beat_combo)
	
	# 设置评价显示状态
	beat_rating_display_timer = 1.5  # 显示1.5秒
	var status_text = text
	if beat_combo > 0:
		status_text += " x" + str(beat_combo)
	last_beat_display_text = status_text
	last_beat_display_color = color

func _on_lyric_changed(japanese: String, chinese: String):
	if chinese_lyric_label:
		# 根据是否是中文歌曲选择显示标签
		var label_text = "中文歌词:\n" if game_mode.is_chinese_song else "中文翻译:\n"
		chinese_lyric_label.text = label_text + chinese

func _on_all_blocks_placed():
	"""所有歌词方块已落完"""
	print("[Main] 收到方块落完信号")
	print("  - 音乐是否播放中: ", music_player.playing)
	print("  - 游戏是否结束: ", game_mode.game_over)
	print("  - 游戏是否暂停: ", game_mode.paused)
	
	# 玩家已死亡或已暂停，不处理
	if game_mode.game_over or game_mode.paused:
		print("[Main] 玩家已死亡或已暂停，不处理完成信号")
		return
	
	# 记录方块落完时间
	game_mode.add_early_completion_bonus()  # 现在只记录时间
	
	# 检查音乐是否还在播放
	if music_player.playing:
		print("[Main] 方块在音乐结束前落完，等待音乐结束计算奖励")
		# 标记方块已落完，等待音乐结束
		game_mode.set_meta("blocks_finished_early", true)
	else:
		# 音乐已结束，记录音乐结束时间并应用奖励
		print("[Main] 音乐已结束且方块落完，计算奖励并显示完成菜单")
		if game_mode.music_complete_time < 0:
			game_mode.set_music_complete_time(game_mode.music_time)
		game_mode.apply_completion_bonus()
		show_song_complete_menu()

# UI相关
const TEXTS = {
	"zh": {
		"score": "分数: ",
		"lines": "行数: ",
		"next": "下一个:",
		"game_over": "游戏结束！\n按 Enter 重新开始",
		"paused": "游戏暂停\n按 P 继续",
		"controls": "控制:\n← → 移动\n↑ 旋转\n↓ 快速下降\nEnter 硬降落\nEsc 暂停游戏",
		"scoring_easy": "计分规则:\n1行 = 100分\n2行 = 200分\n3行 = 400分\n4行 = 700分\n\n连击加分:\n连续消除时\n+原始分×10×连击数",
		"scoring_full": "计分规则:\n1行=100 2行=200\n3行=400 4行=700\n5行=1200 6行=2000\n7行=4000\n\n连击加分:\n连续消除时\n+原始分×10×连击数",
		"scoring_hard": "计分规则:\n1行=100 2行=200\n3行=400 4行=700\n5行=1200 6行=2000\n7行=4000\n\n连击: +原始分×10×连击数\n\n困难规则:\n每2500分减少0.5ms固定时间",
		"scoring_song": "计分规则:\n1行=100 2行=200\n3行=400 4行=700\n5行=1200 6行=2000\n7行=4000\n\n连击: +原始分×10×连击数\n\n完成奖励:\n落块时间与歌词结束\n差值在容许范围内:\n+233分，否则扣分"
	},
	"en": {
		"score": "Score: ",
		"lines": "Lines: ",
		"next": "Next:",
		"game_over": "Game Over!\nPress Enter to Restart",
		"paused": "PAUSED\nPress P to Continue",
		"controls": "Controls:\n← → Move\n↑ Rotate\n↓ Soft Drop\nEnter Hard Drop\nEsc Pause",
		"scoring_easy": "Scoring:\n1 Line = 100pts\n2 Lines = 200pts\n3 Lines = 400pts\n4 Lines = 700pts\n\nCombo Bonus:\nConsecutive clears\n+Base×10×Combo",
		"scoring_full": "Scoring:\n1-4: 100/200/400/700\n5-7: 1200/2000/4000\n\nCombo Bonus:\nConsecutive clears\n+Base×10×Combo",
		"scoring_hard": "Scoring:\n1-4: 100/200/400/700\n5-7: 1200/2000/4000\n\nCombo: +Base×10×N\n\nHard Rule:\n-0.5ms lock time\nper 2500pts",
		"scoring_song": "Scoring:\n1-4: 100/200/400/700\n5-7: 1200/2000/4000\n\nCombo: +Base×10×N\n\nCompletion:\nFinish within tolerance\n+233pts, else penalty"
	}
}

func update_ui_texts():
	var texts = TEXTS[Global.current_language]
	score_label.text = texts["score"] + "0"
	lines_label.text = texts["lines"] + "0"
	next_label.text = texts["next"]
	game_over_label.text = texts["game_over"]
	controls_label.text = texts["controls"]
	
	# 根据模式选择计分规则文本
	if Global.lyric_mode_enabled:
		# 歌词模式
		scoring_label.text = texts["scoring_song"]
	else:
		# 经典模式
		if Global.classic_difficulty == 0:
			# 简单模式
			scoring_label.text = texts["scoring_easy"]
		elif Global.classic_difficulty == 2:
			# 困难模式
			scoring_label.text = texts["scoring_hard"]
		else:
			# 普通模式
			scoring_label.text = texts["scoring_full"]

func toggle_pause():
	if game_mode == null:
		return
	
	game_mode.toggle_pause()
	
	if game_mode.paused:
		pause_menu.show_menu()
		pause_menu.update_ui_texts()
		# 暂停时不隐藏UI，保持可见（有半透明遮罩）
		if music_player.playing:
			music_player.stream_paused = true
	else:
		pause_menu.hide()
		if music_player.stream_paused:
			music_player.stream_paused = false

func show_game_over_menu():
	if game_mode == null:
		return
	
	# 经典模式：保存最高分
	if game_mode is ClassicModeController:
		var updated = Global.update_classic_score(Global.classic_difficulty, game_mode.score, game_mode.lines_cleared_total)
		if updated:
			print("[经典模式] 新纪录！已更新最高分")
	
	game_over_menu.show()
	game_over_menu.update_ui_texts()
	game_over_menu.set_score(game_mode.score, game_mode.lines_cleared_total)
	
	score_label.hide()
	lines_label.hide()
	next_label.hide()
	controls_label.hide()
	scoring_label.hide()
	chinese_lyric_label.hide()
	combo_label.text = ""  # 清空连击显示
	
	if music_player.playing:
		music_player.stop()

func show_song_complete_menu():
	if game_mode == null:
		print("[歌曲完成] 错误: game_mode为null")
		return
	
	print("[歌曲完成] 显示歌曲完成菜单")
	print("  - 当前分数: ", game_mode.score)
	print("  - 消除行数: ", game_mode.lines_cleared_total)
	
	# 保存最高分
	var is_new_record = false
	if Global.selected_song.has("name"):
		var song_name = Global.selected_song["name"]
		is_new_record = Global.update_song_score(song_name, game_mode.score, game_mode.lines_cleared_total)
		if is_new_record:
			print("  - 新纪录！已更新最高分")
		
	game_mode.paused = true
	song_complete_menu.show()
	song_complete_menu.update_ui_texts()
	song_complete_menu.set_score(game_mode.score, game_mode.lines_cleared_total, is_new_record)
	
	# 隐藏游戏UI元素
	score_label.hide()
	lines_label.hide()
	next_label.hide()
	controls_label.hide()
	scoring_label.hide()
	chinese_lyric_label.hide()
	combo_label.text = ""  # 清空连击显示
	
	if music_player.playing:
		music_player.stop()
	
	print("歌曲已完成！")

func _on_music_finished():
	"""音乐播放完成回调"""
	print("[音乐完成] 音乐播放结束")
	
	# 经典模式：循环播放BGM
	if game_mode is ClassicModeController and music_player.stream:
		music_player.play()
		print("[经典模式] BGM循环播放")
	# 歌词模式：检查是否满足完成条件
	elif game_mode is LyricModeController:
		print("[歌词模式] 音乐结束，检查完成条件:")
		print("  - game_over: ", game_mode.game_over)
		print("  - paused: ", game_mode.paused)
		print("  - 方块已落完: ", game_mode.is_song_complete())
		print("  - 提前完成标记: ", game_mode.has_meta("blocks_finished_early"))
		
		# 记录音乐结束时间
		game_mode.set_music_complete_time(game_mode.music_time)
		
		# 条件：玩家存活 + 未暂停
		if not game_mode.game_over and not game_mode.paused:
			# 如果方块已提前完成或现在完成，计算奖励并显示完成菜单
			if game_mode.has_meta("blocks_finished_early") or game_mode.is_song_complete():
				print("[歌曲完成] 满足所有条件，计算奖励并显示完成菜单")
				# 如果方块落完时间未记录，现在记录
				if game_mode.blocks_complete_time < 0:
					game_mode.blocks_complete_time = game_mode.music_time
				game_mode.apply_completion_bonus()
				show_song_complete_menu()
			else:
				print("[歌曲完成] 方块未落完，等待完成...")
				# 标记音乐已结束
				game_mode.set_meta("music_finished", true)
		else:
			print("[歌曲完成] 玩家已死亡或已暂停")

func _on_resume_game():
	toggle_pause()

func _on_restart_game():
	get_tree().reload_current_scene()

func _on_select_song():
	get_tree().change_scene_to_file("res://UI/SongSelection.tscn")

func _on_goto_options():
	pause_menu.hide()
	
	# 隐藏所有游戏UI元素
	score_label.hide()
	lines_label.hide()
	next_label.hide()
	controls_label.hide()
	scoring_label.hide()
	chinese_lyric_label.hide()
	
	var options_scene = load("res://UI/OptionsMenu.tscn")
	var options_instance = options_scene.instantiate()
	options_instance.set_meta("from_game", true)
	options_instance.tree_exited.connect(_on_options_closed)
	get_tree().root.add_child(options_instance)

func _on_options_closed():
	if game_mode and game_mode.paused:
		# 恢复游戏UI元素
		score_label.show()
		lines_label.show()
		next_label.show()
		controls_label.show()
		scoring_label.show()  # 所有模式都显示计分规则
		
		# 根据模式显示对应的UI
		if game_mode is LyricModeController:
			chinese_lyric_label.show()
		else:
			chinese_lyric_label.hide()
		
		pause_menu.show_menu()
		pause_menu.update_ui_texts()
		update_ui_texts()

func _on_goto_menu():
	# 清理音乐可视化
	if music_visualizer:
		music_visualizer.queue_free()
		music_visualizer = null
	get_tree().change_scene_to_file("res://UI/MainMenu.tscn")

func _setup_music_visualizer():
	"""设置音乐可视化背景"""
	print("[MusicVisualizer] 开始设置音乐可视化...")
	
	if music_visualizer != null:
		print("[MusicVisualizer] 已存在，跳过")
		return
	
	# 获取视口大小
	var viewport_size = get_viewport().get_visible_rect().size
	print("[MusicVisualizer] 视口大小: ", viewport_size)
	
	# 创建一个CanvasLayer来确保在最底层
	var bg_layer = CanvasLayer.new()
	bg_layer.name = "VisualizerLayer"
	bg_layer.layer = -1  # 在其他UI层之下
	add_child(bg_layer)
	print("[MusicVisualizer] CanvasLayer已添加")
	
	# 添加背景色
	var bg_color = ColorRect.new()
	bg_color.name = "VisualizerBG"
	bg_color.color = Color(0.08, 0.08, 0.15, 1.0)  # 深蓝色背景
	bg_color.position = Vector2.ZERO
	bg_color.size = viewport_size
	bg_layer.add_child(bg_color)
	print("[MusicVisualizer] 背景色已添加，大小: ", bg_color.size)
	
	# 创建可视化器
	music_visualizer = MusicVisualizer.new()
	music_visualizer.name = "MusicVisualizer"
	music_visualizer.position = Vector2.ZERO
	music_visualizer.size = viewport_size
	bg_layer.add_child(music_visualizer)
	
	print("[MusicVisualizer] 音乐可视化背景已创建，大小: ", music_visualizer.size)
