extends Control

signal restart_game
signal select_song
signal goto_menu

@onready var panel = $Panel
@onready var title_label = $Panel/VBox/TitleLabel
@onready var score_label = $Panel/VBox/ScoreLabel
@onready var new_record_label = $Panel/VBox/NewRecordLabel
@onready var restart_button = $Panel/VBox/RestartButton
@onready var select_song_button = $Panel/VBox/SelectSongButton
@onready var menu_button = $Panel/VBox/MenuButton


# 是否是正常完成（用于区分主动结束和歌曲自然完成）
var is_natural_complete: bool = true

func _ready():
	update_ui_texts()
	restart_button.pressed.connect(_on_restart_button_pressed)
	select_song_button.pressed.connect(_on_select_song_button_pressed)
	menu_button.pressed.connect(_on_menu_button_pressed)

func show_menu():
	# 显示菜单（带动画）
	show()
	panel.modulate.a = 0.0
	panel.scale = Vector2(0.95, 0.95)
	
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(panel, "modulate:a", 1.0, 0.25).set_ease(Tween.EASE_OUT)
	tween.tween_property(panel, "scale", Vector2(1.0, 1.0), 0.25).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

func update_ui_texts():
	if is_natural_complete:
		title_label.text = tr("UI_SONGCOMPLETE_TITLE")
		title_label.add_theme_color_override("font_color", Color(0.2, 0.9, 0.4))  # 绿色
		if panel:
			var panel_style = UITheme.create_panel_style(UITheme.BG_MEDIUM,
				UITheme.ACCENT_SUCCESS, UITheme.BORDER_NORMAL, UITheme.CORNER_LG)
			panel.add_theme_stylebox_override("panel", panel_style)
	else:
		title_label.text = tr("UI_SONGCOMPLETE_TITLE_ENDED")
		title_label.add_theme_color_override("font_color", Color(1, 0.2, 0.2))  # 红色
		if panel:
			var panel_style = UITheme.create_panel_style(UITheme.BG_MEDIUM,
				UITheme.ACCENT_DANGER, UITheme.BORDER_NORMAL, UITheme.CORNER_LG)
			panel.add_theme_stylebox_override("panel", panel_style)
	restart_button.text = tr("UI_COMMON_RESTART")
	select_song_button.text = tr("UI_TITLE_SELECT_SONG")
	menu_button.text = tr("UI_COMMON_MAIN_MENU")

func set_natural_complete(natural: bool):
	# 设置是否是自然完成
	is_natural_complete = natural
	update_ui_texts()

func set_score(score: int, lines: int, is_new_record: bool = false):
	var text = tr("UI_SONGCOMPLETE_SCORE") % score + "\n" + tr("UI_SONGCOMPLETE_LINES") % lines
	
	# 获取最高分
	if Global.selected_song.has("name"):
		var high_score_data = Global.get_song_score(Global.selected_song["name"])
		text += "\n\n" + tr("UI_SONGCOMPLETE_HIGH_SCORE") % high_score_data["score"]
		text += "\n" + tr("UI_SONGCOMPLETE_HIGH_LINES") % high_score_data["lines"]
	
	# 新纪录提示
	if new_record_label:
		new_record_label.visible = is_new_record
		new_record_label.text = tr("UI_SONGCOMPLETE_NEW_RECORD") if is_new_record else ""
	
	score_label.text = text

func _on_restart_button_pressed():
	restart_game.emit()

func _on_select_song_button_pressed():
	select_song.emit()

func _on_menu_button_pressed():
	goto_menu.emit()

func _input(event):
	# 当菜单显示时处理键盘输入
	if not visible:
		return
	
	if event.is_action_pressed("ui_accept"):  # Enter键 - 重新开始
		_on_restart_button_pressed()
		get_tree().root.set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):  # ESC键 - 返回菜单
		_on_menu_button_pressed()
		get_tree().root.set_input_as_handled()
