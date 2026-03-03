extends Control

## Roguelike失败界面 - 独立TSCN场景

signal return_to_menu


@onready var title_label = $Panel/VBox/TitleLabel
@onready var hint_label = $HintLabel

func _ready():
	hide()

func show_screen():
	update_texts()
	show()

func update_texts():
	if title_label:
		title_label.text = tr("UI_ROGUEDEFEAT_TITLE")
	if hint_label:
		hint_label.text = tr("UI_HINT_PRESS_ENTER_FOR_MENU")

func _input(event: InputEvent):
	if not visible:
		return
	if event.is_action_pressed("ui_accept"):
		return_to_menu.emit()
		get_viewport().set_input_as_handled()
