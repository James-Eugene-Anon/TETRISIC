extends RefCounted
class_name GameModeStarter

## 游戏模式启动器 - 负责Classic/Song模式初始化与信号连接

var main: Node = null

func _init(main_ref: Node):
	main = main_ref

func start_classic_mode():
	print("=== 进入经典模式 ===")
	main.game_mode = ClassicModeController.new()
	main.add_child(main.game_mode)
	main.game_mode.initialize()
	
	main.game_mode.game_over_signal.connect(main._on_game_over)
	main.game_mode.score_changed.connect(main.ui_controller.on_score_changed)
	main.game_mode.lines_changed.connect(main.ui_controller.on_lines_changed)
	main.game_mode.combo_changed.connect(main.ui_controller.on_combo_changed)
	main.game_mode.special_block_effect.connect(main._on_special_block_effect)
	main.game_mode.snake_mode_changed.connect(main.ui_controller.on_snake_mode_changed)
	
	if main.renderer:
		main.renderer.set_lyric_mode(false)
	main._setup_plain_background()
	if main.chinese_lyric_label:
		main.chinese_lyric_label.hide()
	if main.scoring_label:
		main.scoring_label.show()
	Global.current_game_mode = Global.GameMode.CLASSIC
	
	if Global.bgm_enabled:
		main._start_bgm()
	else:
		print("BGM已禁用")

func start_lyric_mode():
	print("=== 进入歌曲模式 ===")
	Global.current_game_mode = Global.GameMode.SONG
	main._stop_bgm()
	main._setup_music_visualizer()
	
	if Global.selected_song.is_empty():
		Global.selected_song = {
			"name": "Masked bitcH",
			"artist": "ギガP feat. GUMI",
			"music_file": "res://musics/ギガP GUMI - Masked bitcH.mp3",
			"lyric_file": "res://musics/lyrics/Masked bitcH.lrc"
		}
	
	main.game_mode = LyricModeController.new()
	main.add_child(main.game_mode)
	main.game_mode.load_song(Global.selected_song)
	main.game_mode.start_song()
	
	main.game_mode.game_over_signal.connect(main._on_game_over)
	main.game_mode.score_changed.connect(main.ui_controller.on_score_changed)
	main.game_mode.lines_changed.connect(main.ui_controller.on_lines_changed)
	main.game_mode.combo_changed.connect(main.ui_controller.on_combo_changed)
	main.game_mode.lyric_changed.connect(func(_jp, cn): main.ui_controller.on_lyric_changed(cn))
	main.game_mode.all_blocks_placed.connect(main._on_all_blocks_placed)
	main.game_mode.beat_rating_changed.connect(func(_rating, text, color, beat_combo): main.ui_controller.on_beat_rating_changed(text, color, beat_combo))
	
	if main.renderer:
		main.renderer.set_lyric_mode(true)
	if main.scoring_label:
		main.scoring_label.show()
	if main.chinese_lyric_label:
		main.chinese_lyric_label.show()
		main.chinese_lyric_label.z_index = -1
		main.chinese_lyric_label.text = "中文歌词:\n准备开始..." if main.game_mode.is_chinese_song else "中文翻译:\n准备开始..."
	
	var music_path = Global.selected_song["music_file"]
	var music = main._load_audio_file(music_path)
	if music:
		main.music_player.stream = music
		main.music_player.play()
		main.game_mode.song_duration = main.music_player.stream.get_length()
		print("音乐加载成功: ", Global.selected_song["name"])
		print("[音乐播放器] stream已设置，开始播放")
		print("[音乐播放器] 音乐长度: ", main.game_mode.song_duration)
	else:
		print("[错误] 无法加载音乐: ", music_path)
