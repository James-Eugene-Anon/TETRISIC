extends Control

signal restart_game
signal goto_menu

@onready var panel = $Panel
@onready var title_label = $Panel/VBoxContainer/TitleLabel
@onready var score_label = $Panel/VBoxContainer/ScoreLabel
@onready var restart_button = $Panel/VBoxContainer/RestartButton
@onready var menu_button = $Panel/VBoxContainer/MenuButton

var TEXTS = {
	"zh": {
		"title": "游戏结束",
		"score": "分数: %d",
		"lines": "消除行数: %d",
		"restart": "重新开始",
		"menu": "主菜单"
	},
	"en": {
		"title": "Game Over",
		"score": "Score: %d",
		"lines": "Lines: %d",
		"restart": "Restart",
		"menu": "Main Menu"
	}
}

func _ready():
	update_ui_texts()
	restart_button.pressed.connect(_on_restart_button_pressed)
	menu_button.pressed.connect(_on_menu_button_pressed)

func show_menu():
	"""显示菜单（带动画）"""
	show()  # 调用父类的show方法
	panel.modulate.a = 0.0
	panel.scale = Vector2(0.95, 0.95)
	
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(panel, "modulate:a", 1.0, 0.25).set_ease(Tween.EASE_OUT)
	tween.tween_property(panel, "scale", Vector2(1.0, 1.0), 0.25).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

func update_ui_texts():
	var lang = Global.current_language
	title_label.text = TEXTS[lang]["title"]
	restart_button.text = TEXTS[lang]["restart"]
	menu_button.text = TEXTS[lang]["menu"]

func set_score(score: int, lines: int):
	var lang = Global.current_language
	score_label.text = TEXTS[lang]["score"] % score + "\n" + TEXTS[lang]["lines"] % lines

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

		get_tree().root.set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):  # ESC键 - 返回菜单
		_on_menu_button_pressed()
		get_tree().root.set_input_as_handled()
