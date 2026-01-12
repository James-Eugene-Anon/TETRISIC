extends Control

signal restart_game
signal select_song
signal goto_menu

@onready var panel = $Panel
@onready var title_label = $Panel/VBox/TitleLabel
@onready var score_label = $Panel/VBox/ScoreLabel
@onready var restart_button = $Panel/VBox/RestartButton
@onready var select_song_button = $Panel/VBox/SelectSongButton
@onready var menu_button = $Panel/VBox/MenuButton

var TEXTS = {
	"zh": {
		"title": "歌曲完成！",
		"score": "分数: %d",
		"lines": "消除行数: %d",
		"high_score": "最高分: %d",
		"high_lines": "最高消除: %d",
		"new_record": "🎉 新纪录！",
		"restart": "重新开始",
		"select_song": "选择歌曲",
		"menu": "主菜单"
	},
	"en": {
		"title": "Song Complete!",
		"score": "Score: %d",
		"lines": "Lines: %d",
		"high_score": "High Score: %d",
		"high_lines": "High Lines: %d",
		"new_record": "🎉 New Record!",
		"restart": "Restart",
		"select_song": "Select Song",
		"menu": "Main Menu"
	}
}

func _ready():
	update_ui_texts()
	restart_button.pressed.connect(_on_restart_button_pressed)
	select_song_button.pressed.connect(_on_select_song_button_pressed)
	menu_button.pressed.connect(_on_menu_button_pressed)

func show_menu():
	"""显示菜单（带动画）"""
	show()
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
	select_song_button.text = TEXTS[lang]["select_song"]
	menu_button.text = TEXTS[lang]["menu"]

func set_score(score: int, lines: int, is_new_record: bool = false):
	var lang = Global.current_language
	var text = TEXTS[lang]["score"] % score + "\n" + TEXTS[lang]["lines"] % lines
	
	# 获取最高分
	if Global.selected_song.has("name"):
		var high_score_data = Global.get_song_score(Global.selected_song["name"])
		text += "\n\n" + TEXTS[lang]["high_score"] % high_score_data["score"]
		text += "\n" + TEXTS[lang]["high_lines"] % high_score_data["lines"]
	
	# 新纪录提示
	if is_new_record:
		text += "\n\n" + TEXTS[lang]["new_record"]
	
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
