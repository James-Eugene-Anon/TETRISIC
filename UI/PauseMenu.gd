extends Control

@onready var panel = $Panel
@onready var resume_button = $Panel/VBox/ResumeButton
@onready var restart_button = $Panel/VBox/RestartButton
@onready var options_button = $Panel/VBox/OptionsButton
@onready var menu_button = $Panel/VBox/MenuButton
@onready var title_label = $Panel/VBox/TitleLabel

const TEXTS = {
	"zh": {
		"title": "游戏暂停",
		"resume": "恢复游戏",
		"restart": "重新开始",
		"options": "选项",
		"menu": "返回主菜单"
	},
	"en": {
		"title": "Game Paused",
		"resume": "Resume Game",
		"restart": "Restart",
		"options": "Options", 
		"menu": "Main Menu"
	}
}

signal resume_game
signal restart_game
signal goto_options
signal goto_menu

func _ready():
	update_ui_texts()
	resume_button.pressed.connect(_on_resume_button_pressed)
	restart_button.pressed.connect(_on_restart_button_pressed)
	options_button.pressed.connect(_on_options_button_pressed)
	menu_button.pressed.connect(_on_menu_button_pressed)

func show_menu():
	"""显示菜单（带动画）"""
	show()  # 调用父类的show方法
	panel.modulate.a = 0.0
	panel.scale = Vector2(0.95, 0.95)
	
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(panel, "modulate:a", 1.0, 0.15).set_ease(Tween.EASE_OUT)
	tween.tween_property(panel, "scale", Vector2(1.0, 1.0), 0.15).set_ease(Tween.EASE_OUT)

func update_ui_texts():
	var texts = TEXTS[Global.current_language]
	title_label.text = texts["title"]
	resume_button.text = texts["resume"]
	restart_button.text = texts["restart"]
	options_button.text = texts["options"]
	menu_button.text = texts["menu"]

func _on_resume_button_pressed():
	resume_game.emit()

func _on_restart_button_pressed():
	restart_game.emit()

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
