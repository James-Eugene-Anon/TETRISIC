extends Control

## Roguelike篝火休息界面 - 独立TSCN场景

signal rest_confirmed


@onready var title_label = $Panel/VBox/TitleLabel
@onready var preview_label = $Panel/VBox/PreviewLabel
@onready var hint_label = $Panel/VBox/HintLabel

func _ready():
	hide()

func show_screen(current_hp: int, max_hp: int):
	update_texts(current_hp, max_hp)
	show()

func update_texts(current_hp: int = 0, max_hp: int = 0):
	if title_label:
		title_label.text = tr("UI_ROGUEREST_TITLE")
	if preview_label:
		preview_label.text = tr("UI_ROGUEREST_PREVIEW") % [current_hp, max_hp]
	if hint_label:
		hint_label.text = tr("UI_HINT_PRESS_ENTER_TO_REST")

func _input(event: InputEvent):
	if not visible:
		return
	if event.is_action_pressed("ui_accept"):
		rest_confirmed.emit()
		get_viewport().set_input_as_handled()
