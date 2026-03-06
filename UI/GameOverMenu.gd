extends Control

signal restart_game
signal goto_menu

@onready var panel = $Panel
@onready var title_label = $Panel/VBoxContainer/TitleLabel
@onready var score_label = $Panel/VBoxContainer/ScoreLabel
@onready var restart_button = $Panel/VBoxContainer/RestartButton
@onready var menu_button = $Panel/VBoxContainer/MenuButton


func _ready():
	update_ui_texts()
	restart_button.pressed.connect(_on_restart_button_pressed)
	menu_button.pressed.connect(_on_menu_button_pressed)

func show_menu():
	# 显示菜单（带动画）
	show()
	if panel:
		panel.modulate.a = 0.0
		panel.scale = Vector2(0.92, 0.92)
	
	var tween = create_tween()
	tween.set_parallel(true)
	if panel:
		tween.tween_property(panel, "modulate:a", 1.0, UITheme.ANIM_DURATION_NORMAL).set_ease(Tween.EASE_OUT)
		tween.tween_property(panel, "scale", Vector2(1.0, 1.0), UITheme.ANIM_DURATION_NORMAL).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

func update_ui_texts():
	if title_label:
		title_label.text = tr("UI_GAMEOVER_TITLE")
	if restart_button:
		restart_button.text = tr("UI_GAMEOVER_RESTART")
	if menu_button:
		menu_button.text = tr("UI_GAMEOVER_MENU")

func set_score(score: int, lines: int):
	if score_label:
		score_label.text = tr("UI_GAMEOVER_SCORE") % score + "\n" + tr("UI_GAMEOVER_LINES") % lines

func set_result(victory: bool, score: int, lines: int):
	# 设置结算结果（胜利/失败）
	if victory:
		if title_label:
			title_label.text = tr("UI_TITLE_VICTORY")
			title_label.add_theme_color_override("font_color", Color(0.2, 0.9, 0.4))
	else:
		if title_label:
			title_label.text = tr("UI_GAMEOVER_TITLE")
			title_label.add_theme_color_override("font_color", Color(1, 0.2, 0.2))
	set_score(score, lines)

func _on_restart_button_pressed():
	restart_game.emit()

func _on_menu_button_pressed():
	goto_menu.emit()

func _input(event):
	# 当菜单显示时处理键盘输入
	if not visible:
		return
	
	if event.is_action_pressed("ui_accept"):  # Enter键 - 重新开始
		_on_restart_button_pressed()
		var tree = get_tree()
		if tree and tree.root:
			tree.root.set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):  # ESC键 - 返回菜单
		_on_menu_button_pressed()
		var tree = get_tree()
		if tree and tree.root:
			tree.root.set_input_as_handled()
