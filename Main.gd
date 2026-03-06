extends Node2D

## 主游戏控制器

# 游戏模式控制器
var game_mode: BaseGameModeController = null
var renderer: GameRenderer = null
var input_handler: InputHandler = null
var music_visualizer: MusicVisualizer = null
var ui_controller: MainUIController = null
var mode_starter: GameModeStarter = null

var background_layer: CanvasLayer = null
var background_rect: ColorRect = null

# 窗口焦点状态缓存（用于后台音乐处理）
var _last_window_focused: bool = true
var _background_paused: bool = false
const BASE_FRAME_SIZE := Vector2(800, 600)

# UI节点 - HUD标签通过GameHUD子场景访问
@onready var score_label = $UI/GameHUD/ScoreLabel
@onready var lines_label = $UI/GameHUD/LinesLabel
@onready var next_label = $UI/GameHUD/NextLabel
@onready var combo_label = $UI/GameHUD/ComboLabel
@onready var game_over_label = $UI/GameOverLabel
@onready var controls_label = $UI/GameHUD/ControlsLabel
@onready var scoring_label = $UI/GameHUD/ScoringLabel
@onready var pause_menu = $UI/PauseMenu
@onready var game_over_menu = $UI/GameOverMenu
@onready var song_complete_menu = $UI/SongCompleteMenu
@onready var chinese_lyric_label = $UI/GameHUD/ChineseLyricLabel
@onready var rift_meter_label = $UI/GameHUD/RiftMeterLabel
@onready var beat_calibrator_label = $UI/GameHUD/BeatCalibratorLabel
@onready var equipment_label = $UI/GameHUD/EquipmentLabel
@onready var music_player = $MusicPlayer

func _get_game_frame_offset() -> Vector2:
	var viewport_size = get_viewport().get_visible_rect().size
	return (viewport_size - BASE_FRAME_SIZE) * 0.5

func _apply_centered_game_frame_layout() -> void:
	var fo = _get_game_frame_offset()
	# Node2D 渲染器跟随帧偏移
	if renderer:
		renderer.position = fo
	# GameHUD 从全屏 anchor 切换为固定 800×600 块，子标签的绝对坐标就因此随帧偏移
	var game_hud = get_node_or_null("UI/GameHUD")
	if game_hud is Control:
		game_hud.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT, false)
		game_hud.size = BASE_FRAME_SIZE
		game_hud.position = fo
	# GameOverLabel 是 CanvasLayer 直接子节点，需单独偏移
	if game_over_label:
		game_over_label.position = fo + Vector2(200.0, 250.0)
	# PauseMenu/GameOverMenu/SongCompleteMenu 用屏幕 anchor 自行居中，不需移动

func _ready():
	# 初始化组件
	setup_components()
	ui_controller = MainUIController.new(self)
	mode_starter = GameModeStarter.new(self)
	setup_ui()
	# 绑定音乐总线，确保音量设置影响所有模式
	if music_player:
		music_player.bus = "Music"
		Global.set_music_volume(Global.music_volume)
	
	# 初始化窗口焦点状态
	_last_window_focused = _is_window_focused()
	
	# 连接音乐播放器完成信号
	music_player.finished.connect(_on_music_finished)
	print("[初始化] 音乐播放器finished信号已连接到_on_music_finished")
	_apply_centered_game_frame_layout()
	# 监听视口尺寸变化，确保每次窗口缩放都重新居中
	get_viewport().size_changed.connect(func():
		call_deferred("_apply_centered_game_frame_layout")
		call_deferred("_update_background_size")
	)
	
	# 应用窗口模式与尺寸（保持用户当前窗口模式）
	Global.set_window_mode(Global.window_mode_index)
	
	# 监听窗口焦点变化（用于后台暂停音乐）
	var window = get_window()
	if window:
		window.focus_entered.connect(_on_window_focus_entered)
		window.focus_exited.connect(_on_window_focus_exited)
	
	# 启动对应模式
	if Global.lyric_mode_enabled:
		start_lyric_mode()
	else:
		start_classic_mode()

func setup_components():
	# 初始化核心组件
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
	if ui_controller:
		ui_controller.setup_ui()

func start_classic_mode():
	if mode_starter:
		mode_starter.start_classic_mode()

func start_lyric_mode():
	if mode_starter:
		mode_starter.start_lyric_mode()

func _process(delta):
	if game_mode == null:
		return
	
	# 更新游戏逻辑
	game_mode.update(delta)
	
	# 更新裂隙仪冷却（只有未暂停时才更新）
	if game_mode.equipment_system and not game_mode.paused:
		game_mode.equipment_system.update_rift_meter(delta)
	
	# 更新裂隙仪冷却显示（暂停时隐藏）
	if ui_controller:
		ui_controller.update_rift_meter_display()
	
	# 更新贪吃蛇（如果在贪吃蛇模式）
	if game_mode is ClassicModeController and game_mode.is_snake_mode:
		game_mode.update_snake(delta)
	
	# 更新节拍评价显示计时器
	if renderer:
		renderer.update_beat_timer(delta)
	
	# 更新节拍评价显示计时器
	if ui_controller:
		ui_controller.update_beat_timers(delta)
	
	# 更新渲染器
	update_renderer()
	
	# 更新节拍校对器显示
	if ui_controller:
		ui_controller.update_beat_calibrator_display()

	# 轮询窗口焦点，保证后台音乐可靠暂停/恢复
	_poll_focus_state()

func _update_rift_meter_display():
	if ui_controller:
		ui_controller.update_rift_meter_display()

func _update_equipment_display():
	if ui_controller:
		ui_controller.update_equipment_display()


func _update_beat_calibrator_display():
	if ui_controller:
		ui_controller.update_beat_calibrator_display()

func update_renderer():
	# 更新渲染器状态
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
	
	# 处理裂隙仪输入（按C键）
	if event is InputEventKey and event.pressed and event.keycode == KEY_C:
		if not is_game_over and not is_paused:
			if game_mode.equipment_system.try_activate_rift_meter(game_mode.grid_manager):
				if ui_controller:
					await ui_controller.show_rift_triggered()
	
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
	if ui_controller:
		ui_controller.on_score_changed(score)

func _on_lines_changed(lines: int):
	if ui_controller:
		ui_controller.on_lines_changed(lines)

func _on_combo_changed(combo_count: int):
	if ui_controller:
		ui_controller.on_combo_changed(combo_count)

func _on_special_block_effect(effect_type: String, position: Vector2i, destroyed: int):
	if ui_controller:
		ui_controller.on_special_block_effect(effect_type, destroyed)

func _on_snake_mode_changed(is_snake: bool):
	if ui_controller:
		ui_controller.on_snake_mode_changed(is_snake)

func _on_beat_rating_changed(rating: int, text: String, color: Color, beat_combo: int):
	print("[Main] 收到节拍评价: ", text, " 连击: ", beat_combo)
	if ui_controller:
		ui_controller.on_beat_rating_changed(text, color, beat_combo)

func _on_lyric_changed(japanese: String, chinese: String):
	if ui_controller:
		ui_controller.on_lyric_changed(chinese)

func _on_all_blocks_placed():
	# 所有歌词方块已落完
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

func update_ui_texts():
	if ui_controller:
		ui_controller.update_ui_texts()

func toggle_pause():
	if game_mode == null:
		return
	
	game_mode.toggle_pause()
	
	if game_mode.paused:
		pause_menu.show_menu()
		pause_menu.update_ui_texts()
		# 暂停时不隐藏UI，保持可见（有半透明遮罩）
		# BGM（经典/Rogue）保持播放，歌曲模式才暂停流
		if not _is_bgm_stream() and music_player.playing:
			music_player.stream_paused = true
	else:
		pause_menu.hide()
		if _is_bgm_stream():
			_refresh_bgm_state()
		elif music_player.stream_paused:
			music_player.stream_paused = false

func show_game_over_menu():
	if ui_controller:
		ui_controller.show_game_over_menu()

func show_song_complete_menu(is_natural_complete: bool = true):
	if ui_controller:
		ui_controller.show_song_complete_menu(is_natural_complete)

# ===== BGM控制函数 =====

func _notification(what):
	if what == NOTIFICATION_WM_SIZE_CHANGED:
		call_deferred("_apply_centered_game_frame_layout")
	if what == NOTIFICATION_APPLICATION_FOCUS_IN or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		# 延迟处理，确保焦点状态已更新
		call_deferred("_handle_focus_music")
		call_deferred("_refresh_bgm_state")

func _on_window_focus_entered():
	# 兜底：窗口焦点进入时同步音乐状态
	call_deferred("_handle_focus_music")
	call_deferred("_refresh_bgm_state")

func _on_window_focus_exited():
	# 兜底：窗口焦点离开时同步音乐状态
	call_deferred("_handle_focus_music")
	call_deferred("_refresh_bgm_state")

func _handle_focus_music():
	# 后台播放关闭时：进入后台暂停，回前台恢复
	if not Global.play_music_when_unfocused and not _is_window_focused():
		# 歌曲模式：后台暂停游戏逻辑
		if Global.current_game_mode == Global.GameMode.SONG and game_mode and not game_mode.paused:
			game_mode.paused = true
			_background_paused = true
		if music_player.playing:
			music_player.stream_paused = true
		return

	# 回到前台：根据当前模式恢复音乐
	if music_player.stream_paused:
		# 暂停/设置界面不恢复
		if game_mode and game_mode.paused:
			# 如果是后台触发的暂停，恢复
			if _background_paused:
				game_mode.paused = false
				_background_paused = false
			else:
				return
		if pause_menu and pause_menu.visible:
			return
		if _is_options_open():
			return
		# BGM只在允许的模式恢复；歌曲模式则直接恢复
		if _is_bgm_stream():
			if _should_play_bgm():
				music_player.stream_paused = false
				if not music_player.playing:
					music_player.play()
		else:
			music_player.stream_paused = false
			if not music_player.playing:
				music_player.play()

func _is_bgm_stream() -> bool:
	return music_player.stream and music_player.stream.resource_path == Global.BGM_PATH

func _is_options_open() -> bool:
	for child in get_tree().root.get_children():
		if child.name == "OptionsMenu":
			return true
	return false

func _should_play_bgm() -> bool:
	if not Global.bgm_enabled:
		return false
	if Global.current_game_mode == Global.GameMode.SONG:
		return false
	if not Global.play_music_when_unfocused and not _is_window_focused():
		return false
	if game_mode and game_mode.paused:
		return false
	if pause_menu and pause_menu.visible:
		return false
	if _is_options_open():
		return false
	return true

func _refresh_bgm_state():
	if _should_play_bgm():
		_start_bgm()
	else:
		# 后台播放关闭时：进入后台暂停而非停止
		if not Global.play_music_when_unfocused and not _is_window_focused() and _is_bgm_stream():
			if music_player.playing:
				music_player.stream_paused = true
		else:
			_stop_bgm()

func _is_window_focused() -> bool:
	var window = get_window()
	if window:
		return window.has_focus()
	return true

func _poll_focus_state():
	var focused = _is_window_focused()
	if focused == _last_window_focused:
		return
	_last_window_focused = focused
	call_deferred("_handle_focus_music")
	call_deferred("_refresh_bgm_state")

func _start_bgm():
	# 播放背景音乐
	# 不再检查条件，由_refresh_bgm_state()负责判断
	var bgm = load(Global.BGM_PATH)
	if bgm:
		if music_player.stream != bgm:
			music_player.stream = bgm
		music_player.volume_db = 0
		music_player.stream_paused = false
		if not music_player.playing:
			music_player.play()
		print("背景音乐已加载并播放")
	else:
		print("警告: 无法加载BGM文件 - " + Global.BGM_PATH)

func _stop_bgm():
	# 停止背景音乐
	if _is_bgm_stream():
		music_player.stream_paused = false
		music_player.stop()
		print("背景音乐已停止")

func on_bgm_setting_changed(enabled: bool):
	# BGM设置变更回调 - 由OptionsMenu调用
	print("BGM设置变更: ", enabled)
	# 仅在经典模式或Rogue模式时响应
	if Global.current_game_mode == Global.GameMode.CLASSIC or Global.current_game_mode == Global.GameMode.ROGUE:
		_refresh_bgm_state()

func _on_music_finished():
	# 音乐播放完成回调
	print("[音乐完成] 音乐播放结束")
	
	# 经典模式：循环播放BGM
	if game_mode is ClassicModeController and music_player.stream:
		if _should_play_bgm():
			music_player.play()
			print("[经典模式] BGM循环播放")
		else:
			_stop_bgm()
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

func _persist_current_run_score() -> void:
	if game_mode == null:
		return
	if game_mode is ClassicModeController:
		var classic_updated = Global.update_classic_score(
			Global.classic_difficulty,
			game_mode.score,
			game_mode.lines_cleared_total
		)
		if classic_updated:
			print("[经典模式] 新纪录！已更新最高分")
	elif game_mode is LyricModeController:
		var song_data = Global.selected_song
		if song_data and song_data.has("name"):
			var song_updated = Global.update_song_score(
				song_data["name"],
				game_mode.score,
				game_mode.lines_cleared_total
			)
			if song_updated:
				print("[歌词模式] 新纪录！已更新最高分")

func _on_end_game():
	# 主动结束游戏并进入结算
	if game_mode == null:
		return
	
	# 隐藏暂停菜单
	pause_menu.hide()
	game_mode.paused = false
	
	# 标记游戏结束
	game_mode.game_over = true
	
	# 保存分数
	_persist_current_run_score()
	
	# 停止音乐
	if music_player.playing:
		music_player.stop()
	
	# 显示结算界面
	if game_mode is LyricModeController:
		show_song_complete_menu(false)  # 主动结束，不是自然完成
	else:
		show_game_over_menu()

func _on_restart_game():
	get_tree().reload_current_scene()

func _on_select_song():
	get_tree().change_scene_to_file("res://UI/SongSelection.tscn")

func _on_goto_options():
	pause_menu.hide()
	if ui_controller:
		ui_controller.on_options_opened()
	
	var options_scene = load("res://UI/OptionsMenu.tscn")
	var options_instance = options_scene.instantiate()
	options_instance.set_meta("from_game", true)
	options_instance.tree_exited.connect(_on_options_closed)
	get_tree().root.add_child(options_instance)

func _on_options_closed():
	if ui_controller:
		ui_controller.on_options_closed()

func _on_goto_menu():
	# 局中主动返回主菜单也需要结算当前分数
	_persist_current_run_score()

	# 清理音乐可视化
	if music_visualizer:
		music_visualizer.queue_free()
		music_visualizer = null
	# 退出到主菜单时重置游戏模式
	Global.current_game_mode = Global.GameMode.MAIN_MENU
	get_tree().change_scene_to_file("res://UI/MainMenu.tscn")

func _setup_music_visualizer():
	# 设置音乐可视化背景
	print("[MusicVisualizer] 开始设置音乐可视化...")
	
	if music_visualizer != null:
		print("[MusicVisualizer] 已存在，跳过")
		return
	
	_ensure_background_layer()
	
	# 创建可视化器
	music_visualizer = MusicVisualizer.new()
	music_visualizer.name = "MusicVisualizer"
	music_visualizer.position = Vector2.ZERO
	music_visualizer.size = background_rect.size
	background_layer.add_child(music_visualizer)
	
	print("[MusicVisualizer] 音乐可视化背景已创建，大小: ", music_visualizer.size)

func _setup_plain_background():
	_ensure_background_layer()
	if music_visualizer:
		music_visualizer.queue_free()
		music_visualizer = null
	_update_background_size()

func _ensure_background_layer():
	if background_layer:
		return
	background_layer = CanvasLayer.new()
	background_layer.name = "BackgroundLayer"
	background_layer.layer = -1
	add_child(background_layer)
	
	background_rect = ColorRect.new()
	background_rect.name = "BackgroundRect"
	background_rect.color = Color(0.08, 0.08, 0.15, 1.0)
	background_rect.position = Vector2.ZERO
	background_rect.size = get_viewport().get_visible_rect().size
	background_layer.add_child(background_rect)

func _update_background_size():
	if not background_rect:
		return
	var viewport_size = get_viewport().get_visible_rect().size
	background_rect.size = viewport_size
	if music_visualizer:
		music_visualizer.size = viewport_size

func _load_audio_file(path: String) -> AudioStream:
	# 加载音频文件，支持res://和绝对路径
	if path.begins_with("res://"):
		# 资源路径，使用load()
		return load(path) as AudioStream
	else:
		# 绝对路径或user://路径，需要手动加载
		var actual_path = path
		if path.begins_with("user://"):
			actual_path = ProjectSettings.globalize_path(path)
		
		# 检查文件是否存在
		if not FileAccess.file_exists(actual_path):
			print("[音频加载] 文件不存在: ", actual_path)
			return null
		
		# 根据扩展名选择加载方式
		var ext = actual_path.get_extension().to_lower()
		
		if ext == "mp3":
			var file = FileAccess.open(actual_path, FileAccess.READ)
			if file == null:
				print("[音频加载] 无法打开文件: ", actual_path)
				return null
			var audio_stream = AudioStreamMP3.new()
			audio_stream.data = file.get_buffer(file.get_length())
			file.close()
			print("[音频加载] 成功加载MP3: ", actual_path)
			return audio_stream
		elif ext == "ogg":
			# OGG需要使用不同的加载方式
			var file = FileAccess.open(actual_path, FileAccess.READ)
			if file == null:
				print("[音频加载] 无法打开文件: ", actual_path)
				return null
			var audio_stream = AudioStreamOggVorbis.load_from_buffer(file.get_buffer(file.get_length()))
			file.close()
			print("[音频加载] 成功加载OGG: ", actual_path)
			return audio_stream
		elif ext == "wav":
			# WAV使用类似方式
			var file = FileAccess.open(actual_path, FileAccess.READ)
			if file == null:
				print("[音频加载] 无法打开文件: ", actual_path)
				return null
			var audio_stream = AudioStreamWAV.new()
			# WAV格式比较复杂，暂不支持
			print("[音频加载] WAV格式暂不支持动态加载")
			file.close()
			return null
		else:
			print("[音频加载] 不支持的格式: ", ext)
			return null
