extends RefCounted
class_name MainUIController

## 主界面UI控制器 - 封装Main.gd中的UI逻辑

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

var main: Node = null
var beat_rating_display_timer: float = 0.0
var last_beat_display_text: String = ""
var last_beat_display_color: Color = Color.WHITE

func _init(main_ref: Node):
	main = main_ref

func setup_ui():
	if main.game_over_label:
		main.game_over_label.hide()
	if main.pause_menu:
		main.pause_menu.hide()
	if main.game_over_menu:
		main.game_over_menu.hide()
	if main.song_complete_menu:
		main.song_complete_menu.hide()
	if main.combo_label:
		main.combo_label.text = ""
	update_ui_texts()
	
	# 连接菜单信号
	if main.pause_menu:
		main.pause_menu.resume_game.connect(main._on_resume_game)
		main.pause_menu.restart_game.connect(main._on_restart_game)
		main.pause_menu.end_game.connect(main._on_end_game)
		main.pause_menu.goto_options.connect(main._on_goto_options)
		main.pause_menu.goto_menu.connect(main._on_goto_menu)
	if main.game_over_menu:
		main.game_over_menu.restart_game.connect(main._on_restart_game)
		main.game_over_menu.goto_menu.connect(main._on_goto_menu)
	if main.song_complete_menu:
		main.song_complete_menu.restart_game.connect(main._on_restart_game)
		main.song_complete_menu.select_song.connect(main._on_select_song)
		main.song_complete_menu.goto_menu.connect(main._on_goto_menu)

func update_ui_texts():
	var texts = TEXTS[Global.current_language]
	if main.score_label:
		main.score_label.text = texts["score"] + "0"
	if main.lines_label:
		main.lines_label.text = texts["lines"] + "0"
	if main.next_label:
		main.next_label.text = texts["next"]
	if main.game_over_label:
		main.game_over_label.text = texts["game_over"]
	if main.controls_label:
		main.controls_label.text = texts["controls"]
	
	# 根据模式选择计分规则文本
	if Global.lyric_mode_enabled:
		if main.scoring_label:
			main.scoring_label.text = texts["scoring_song"]
	else:
		if main.scoring_label:
			if Global.classic_difficulty == 0:
				main.scoring_label.text = texts["scoring_easy"]
			elif Global.classic_difficulty == 2:
				main.scoring_label.text = texts["scoring_hard"]
			else:
				main.scoring_label.text = texts["scoring_full"]
	
	update_equipment_display()

func update_rift_meter_display():
	if not main.rift_meter_label:
		return
	if main.game_mode and main.game_mode.paused:
		main.rift_meter_label.text = ""
		return
	if not main.game_mode or not main.game_mode.equipment_system.is_equipped(EquipmentSystem.EquipmentType.RIFT_METER):
		main.rift_meter_label.text = ""
		return
	
	var cooldown = main.game_mode.equipment_system.get_rift_meter_cooldown()
	if cooldown > 0:
		var cooldown_text = "裂隙仪: %.1fs" % cooldown if Global.current_language == "zh" else "Rift: %.1fs" % cooldown
		main.rift_meter_label.text = cooldown_text
		main.rift_meter_label.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75, 1))
	else:
		var ready_text = "裂隙仪: 按C" if Global.current_language == "zh" else "Rift: Press C"
		main.rift_meter_label.text = ready_text
		main.rift_meter_label.add_theme_color_override("font_color", Color(0.3, 0.9, 1.0, 1))

func update_equipment_display():
	if not main.equipment_label:
		return
	
	# 动态查询装备系统，自动检测已装备的装备
	# Fallback: 如果game_mode未初始化，直接查询Global标志（兼容启动阶段）
	if not main.game_mode or not main.game_mode.equipment_system:
		_update_equipment_display_fallback()
		return
	
	var equip_system = main.game_mode.equipment_system
	var is_zh = Global.current_language == "zh"
	var equipped_list = []
	
	# 定义装备名称映射（支持中英文）
	var equipment_names = {
		EquipmentSystem.EquipmentType.SPECIAL_BLOCK_GENERATOR: {"zh": "特殊方块生成器", "en": "Special Block"},
		EquipmentSystem.EquipmentType.FAULTY_SCORE_AMPLIFIER: {"zh": "故障增幅器", "en": "Faulty Amp"},
		EquipmentSystem.EquipmentType.RIFT_METER: {"zh": "裂隙仪", "en": "Rift Meter"},
		EquipmentSystem.EquipmentType.CAPACITY_DISK: {"zh": "扩容磁盘", "en": "Capacity Disk"},
		EquipmentSystem.EquipmentType.SNAKE_VIRUS: {"zh": "贪吃蛇病毒", "en": "Snake Virus"},
		EquipmentSystem.EquipmentType.BEAT_CALIBRATOR: {"zh": "节拍校对器", "en": "Beat Calibrator"},
		EquipmentSystem.EquipmentType.HEARTS_MELODY: {"zh": "心之旋律", "en": "Heart's Melody"},
		EquipmentSystem.EquipmentType.DOWNCLOCK_SOFTWARE: {"zh": "降频软件", "en": "Downclock"},
		EquipmentSystem.EquipmentType.IRON_SWORD: {"zh": "铁剑", "en": "Iron Sword"},
		EquipmentSystem.EquipmentType.IRON_SHIELD: {"zh": "铁盾", "en": "Iron Shield"}
	}
	
	# 遍历所有装备类型，检查是否已装备
	for equip_type in equipment_names.keys():
		if equip_system.is_equipped(equip_type):
			var names = equipment_names[equip_type]
			var display_name = names.get("zh" if is_zh else "en", "Unknown")
			
			# 根据模式过滤装备
			var category = equip_system.get_equipment_category(equip_type)
			var should_show = false
			
			if Global.current_game_mode == Global.GameMode.SONG or Global.lyric_mode_enabled:
				# 歌曲模式：显示通用装备和歌曲装备
				if category == EquipmentSystem.EquipmentCategory.UNIVERSAL or category == EquipmentSystem.EquipmentCategory.SONG:
					should_show = true
			elif Global.current_game_mode == Global.GameMode.ROGUE:
				# Rogue模式：显示所有装备（通用+Roguelike专属）
				if category == EquipmentSystem.EquipmentCategory.UNIVERSAL or category == EquipmentSystem.EquipmentCategory.ROGUELIKE:
					should_show = true
			else:
				# 经典模式：显示通用装备和经典装备
				if category == EquipmentSystem.EquipmentCategory.UNIVERSAL or category == EquipmentSystem.EquipmentCategory.CLASSIC:
					should_show = true
			
			if should_show:
				equipped_list.append(display_name)
	
	if equipped_list.size() == 0:
		main.equipment_label.text = ""
		return
	
	# 显示所有装备（不再限制数量）
	var header = "[装备]" if is_zh else "[Equip]"
	var display_text = header
	for equip_name in equipped_list:
		display_text += "\n- " + equip_name
	main.equipment_label.text = display_text

func _update_equipment_display_fallback():
	# Fallback显示逻辑：直接查询Global标志（用于game_mode未初始化时）
	var is_zh = Global.current_language == "zh"
	var equipped_list = []
	
	if Global.current_game_mode == Global.GameMode.SONG or Global.lyric_mode_enabled:
		# 歌曲模式
		if Global.equipment_universal_faulty_amplifier:
			equipped_list.append("故障增幅器" if is_zh else "Faulty Amp")
		if Global.equipment_universal_rift_meter:
			equipped_list.append("裂隙仪" if is_zh else "Rift Meter")
		if Global.equipment_universal_capacity_disk:
			equipped_list.append("扩容磁盘" if is_zh else "Capacity Disk")
		if Global.equipment_song_hearts_melody:
			equipped_list.append("心之旋律" if is_zh else "Heart's Melody")
		if Global.equipment_song_beat_calibrator:
			equipped_list.append("节拍校对器" if is_zh else "Beat Calibrator")
	else:
		# 经典模式
		if Global.equipment_universal_faulty_amplifier:
			equipped_list.append("故障增幅器" if is_zh else "Faulty Amp")
		if Global.equipment_universal_rift_meter:
			equipped_list.append("裂隙仪" if is_zh else "Rift Meter")
		if Global.equipment_universal_capacity_disk:
			equipped_list.append("扩容磁盘" if is_zh else "Capacity Disk")
		if Global.equipment_classic_special_block:
			equipped_list.append("特殊方块生成器" if is_zh else "Special Block")
		if Global.equipment_classic_snake_virus:
			equipped_list.append("贪吃蛇病毒" if is_zh else "Snake Virus")
	
	if equipped_list.size() == 0:
		main.equipment_label.text = ""
		return
	
	var header = "[装备]" if is_zh else "[Equip]"
	var display_text = header
	for equip_name in equipped_list:
		display_text += "\n- " + equip_name
	main.equipment_label.text = display_text

func update_beat_calibrator_display():
	if not main.beat_calibrator_label:
		return
	if not main.game_mode is LyricModeController:
		main.beat_calibrator_label.text = ""
		return
	if main.game_mode.paused:
		main.beat_calibrator_label.text = ""
		return
	if main.game_mode.equipment_system and main.game_mode.equipment_system.is_hearts_melody_active():
		beat_rating_display_timer = 0.0
		main.beat_calibrator_label.text = ""
		return
	
	if beat_rating_display_timer > 0:
		main.beat_calibrator_label.text = last_beat_display_text
		main.beat_calibrator_label.add_theme_color_override("font_color", last_beat_display_color)
	else:
		var combo = main.game_mode.equipment_system.get_beat_combo()
		var is_zh = Global.current_language == "zh"
		var status_text = ("♪ 对准节拍落块" if is_zh else "♪ Drop on Beat")
		if combo > 0:
			status_text += " [" + str(combo) + "]"
		main.beat_calibrator_label.text = status_text
		main.beat_calibrator_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8, 1))

func update_beat_timers(delta: float):
	if beat_rating_display_timer > 0:
		beat_rating_display_timer -= delta

func show_rift_triggered() -> void:
	if not main.combo_label:
		return
	main.combo_label.text = "裂隙仪!" if Global.current_language == "zh" else "Rift!"
	main.combo_label.add_theme_color_override("font_color", Color(0.3, 0.9, 1.0, 1.0))
	main.combo_label.scale = Vector2(1.5, 1.5)
	var tween = main.create_tween()
	tween.tween_property(main.combo_label, "scale", Vector2(1.0, 1.0), 0.3).set_ease(Tween.EASE_OUT)
	await main.get_tree().create_timer(1.0).timeout
	if main.combo_label.text.contains("裂隙仪") or main.combo_label.text.contains("Rift"):
		main.combo_label.text = ""

func on_score_changed(score: int):
	if main.score_label:
		main.score_label.text = TEXTS[Global.current_language]["score"] + str(score)

func on_lines_changed(lines: int):
	if main.lines_label:
		main.lines_label.text = TEXTS[Global.current_language]["lines"] + str(lines)

func on_combo_changed(combo_count: int):
	if main.combo_label == null:
		return
	if combo_count >= 2:
		main.combo_label.text = (str(combo_count) + " 连击！") if Global.current_language == "zh" else (str(combo_count) + " Combo!")
		if combo_count <= 5:
			main.combo_label.add_theme_color_override("font_color", Color(0.95, 0.85, 0.35, 1.0))
		elif combo_count <= 10:
			main.combo_label.add_theme_color_override("font_color", Color(0.95, 0.65, 0.25, 1.0))
		else:
			main.combo_label.add_theme_color_override("font_color", Color(0.9, 0.4, 0.35, 1.0))
		main.combo_label.scale = Vector2(1.3, 1.3)
		var tween = main.create_tween()
		tween.tween_property(main.combo_label, "scale", Vector2(1.0, 1.0), 0.2).set_ease(Tween.EASE_OUT)
	else:
		main.combo_label.text = ""

func on_special_block_effect(effect_type: String, destroyed: int):
	if main.combo_label == null:
		return
	var effect_names = {"BOMB": "💣炸弹", "LASER_H": "━横激光", "LASER_V": "┃纵激光"}
	var effect_name = effect_names.get(effect_type, effect_type)
	main.combo_label.text = effect_name + "! +" + str(destroyed * 5)
	main.combo_label.add_theme_color_override("font_color", Color(1.0, 0.5, 0, 1.0))
	main.combo_label.scale = Vector2(1.5, 1.5)
	var tween = main.create_tween()
	tween.tween_property(main.combo_label, "scale", Vector2(1.0, 1.0), 0.3).set_ease(Tween.EASE_OUT)
	main.get_tree().create_timer(1.5).timeout.connect(func():
		if main.combo_label and main.combo_label.text.contains(effect_name):
			main.combo_label.text = ""
	)

func on_snake_mode_changed(is_snake: bool):
	if not is_snake or main.combo_label == null:
		return
	main.combo_label.text = "贪吃蛇!" if Global.current_language == "zh" else "Snake!"
	main.combo_label.add_theme_color_override("font_color", Color(0.4, 0.9, 0.4, 1.0))
	main.combo_label.scale = Vector2(1.5, 1.5)
	var tween = main.create_tween()
	tween.tween_property(main.combo_label, "scale", Vector2(1.0, 1.0), 0.3).set_ease(Tween.EASE_OUT)

func on_beat_rating_changed(text: String, color: Color, beat_combo: int):
	if main.renderer:
		main.renderer.set_beat_rating_info(text, color, beat_combo)
	beat_rating_display_timer = 1.5
	var status_text = text
	if beat_combo > 0:
		status_text += " x" + str(beat_combo)
	last_beat_display_text = status_text
	last_beat_display_color = color

func on_lyric_changed(chinese: String):
	if main.chinese_lyric_label:
		var label_text = "中文歌词:\n" if main.game_mode.is_chinese_song else "中文翻译:\n"
		main.chinese_lyric_label.text = label_text + chinese

func show_game_over_menu():
	if main.game_mode == null:
		return
	if main.game_mode is ClassicModeController:
		var updated = Global.update_classic_score(Global.classic_difficulty, main.game_mode.score, main.game_mode.lines_cleared_total)
		if updated:
			print("[经典模式] 新纪录！已更新最高分")
	if main.game_over_menu:
		main.game_over_menu.show()
		main.game_over_menu.update_ui_texts()
		main.game_over_menu.set_score(main.game_mode.score, main.game_mode.lines_cleared_total)
	if main.score_label:
		main.score_label.hide()
	if main.lines_label:
		main.lines_label.hide()
	if main.next_label:
		main.next_label.hide()
	if main.controls_label:
		main.controls_label.hide()
	if main.scoring_label:
		main.scoring_label.hide()
	if main.chinese_lyric_label:
		main.chinese_lyric_label.hide()
	if main.combo_label:
		main.combo_label.text = ""
	if main.music_player and main.music_player.playing:
		main.music_player.stop()

func show_song_complete_menu(is_natural_complete: bool = true):
	if main.game_mode == null:
		print("[歌曲完成] 错误: game_mode为null")
		return
	print("[歌曲完成] 显示歌曲完成菜单, 自然完成: ", is_natural_complete)
	print("  - 当前分数: ", main.game_mode.score)
	print("  - 消除行数: ", main.game_mode.lines_cleared_total)
	var is_new_record = false
	if Global.selected_song.has("name"):
		var song_name = Global.selected_song["name"]
		is_new_record = Global.update_song_score(song_name, main.game_mode.score, main.game_mode.lines_cleared_total)
		if is_new_record:
			print("  - 新级录！已更新最高分")
	main.game_mode.paused = true
	if main.song_complete_menu:
		main.song_complete_menu.set_natural_complete(is_natural_complete)
		main.song_complete_menu.show()
		main.song_complete_menu.update_ui_texts()
		main.song_complete_menu.set_score(main.game_mode.score, main.game_mode.lines_cleared_total, is_new_record)
	if main.score_label:
		main.score_label.hide()
	if main.lines_label:
		main.lines_label.hide()
	if main.next_label:
		main.next_label.hide()
	if main.controls_label:
		main.controls_label.hide()
	if main.scoring_label:
		main.scoring_label.hide()
	if main.chinese_lyric_label:
		main.chinese_lyric_label.hide()
	if main.combo_label:
		main.combo_label.text = ""
	if main.music_player and main.music_player.playing:
		main.music_player.stop()
	print("歌曲已完成！")

func on_options_opened():
	if main.score_label:
		main.score_label.hide()
	if main.lines_label:
		main.lines_label.hide()
	if main.next_label:
		main.next_label.hide()
	if main.controls_label:
		main.controls_label.hide()
	if main.scoring_label:
		main.scoring_label.hide()
	if main.chinese_lyric_label:
		main.chinese_lyric_label.hide()
	if main.combo_label:
		main.combo_label.hide()
	if main.equipment_label:
		main.equipment_label.hide()
	if main.beat_calibrator_label:
		main.beat_calibrator_label.hide()
	if main.rift_meter_label:
		main.rift_meter_label.hide()

func on_options_closed():
	if main.game_mode and main.game_mode.paused:
		if main.score_label:
			main.score_label.show()
		if main.lines_label:
			main.lines_label.show()
		if main.next_label:
			main.next_label.show()
		if main.controls_label:
			main.controls_label.show()
		if main.scoring_label:
			main.scoring_label.show()
		if main.combo_label:
			main.combo_label.show()
		if main.equipment_label:
			main.equipment_label.show()
		if main.beat_calibrator_label:
			main.beat_calibrator_label.show()
		if main.rift_meter_label:
			main.rift_meter_label.show()
		if main.game_mode is LyricModeController and main.chinese_lyric_label:
			main.chinese_lyric_label.show()
		elif main.chinese_lyric_label:
			main.chinese_lyric_label.hide()
		if main.pause_menu:
			main.pause_menu.show_menu()
			main.pause_menu.update_ui_texts()
		update_ui_texts()
