extends Control

@onready var panel = $Panel
@onready var resume_button = $Panel/VBox/ResumeButton
@onready var restart_button = $Panel/VBox/RestartButton
@onready var end_game_button = $Panel/VBox/EndGameButton
@onready var options_button = $Panel/VBox/OptionsButton
@onready var menu_button = $Panel/VBox/MenuButton
@onready var title_label = $Panel/VBox/TitleLabel


signal resume_game
signal restart_game
signal end_game
signal goto_options
signal goto_menu

func _ready():
	update_ui_texts()
	resume_button.pressed.connect(_on_resume_button_pressed)
	restart_button.pressed.connect(_on_restart_button_pressed)
	end_game_button.pressed.connect(_on_end_game_button_pressed)
	options_button.pressed.connect(_on_options_button_pressed)
	menu_button.pressed.connect(_on_menu_button_pressed)

func show_menu():
	# 显示菜单（带动画）
	show()
	panel.modulate.a = 0.0
	panel.scale = Vector2(0.92, 0.92)
	
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(panel, "modulate:a", 1.0, UITheme.ANIM_DURATION_NORMAL).set_ease(Tween.EASE_OUT)
	tween.tween_property(panel, "scale", Vector2(1.0, 1.0), UITheme.ANIM_DURATION_NORMAL).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

func update_ui_texts():
	title_label.text = tr("UI_TITLE_GAME_PAUSED")
	resume_button.text = tr("UI_PAUSE_RESUME")
	restart_button.text = tr("UI_PAUSE_RESTART")
	end_game_button.text = tr("UI_PAUSE_END_GAME")
	options_button.text = tr("UI_PAUSE_OPTIONS")
	menu_button.text = tr("UI_PAUSE_MENU")

func _on_resume_button_pressed():
	resume_game.emit()

func _on_restart_button_pressed():
	restart_game.emit()

func _on_end_game_button_pressed():
	end_game.emit()

func _on_options_button_pressed():
	goto_options.emit()

func _on_menu_button_pressed():
	goto_menu.emit()

func _input(event):
	# 当菜单显示时处理键盘输入
	if not visible:
		return
	
	if event.is_action_pressed("ui_cancel"):  # ESC键 - 恢复游戏
		_on_resume_button_pressed()
		get_tree().root.set_input_as_handled()
