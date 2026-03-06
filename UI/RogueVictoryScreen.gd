extends Control

## Roguelike胜利界面 - 独立TSCN场景

signal return_to_menu


const COLOR_WIN = Color(0.3, 0.9, 0.5, 1)   # 胜利绿色
const COLOR_LOSE = Color(0.9, 0.25, 0.2, 1)  # 失败/退出红色

@onready var panel_node = $Panel

@onready var title_label = $Panel/VBox/TitleLabel
@onready var stats_header_label = $Panel/VBox/StatsHeaderLabel
@onready var lines_label = $Panel/VBox/LinesLabel
@onready var relics_label = $Panel/VBox/RelicsLabel
@onready var gold_label = $Panel/VBox/GoldLabel if has_node("Panel/VBox/GoldLabel") else null
@onready var score_sep_label = $Panel/VBox/ScoreSepLabel if has_node("Panel/VBox/ScoreSepLabel") else null
@onready var score_label = $Panel/VBox/ScoreLabel if has_node("Panel/VBox/ScoreLabel") else null
@onready var hint_label = $Panel/VBox/HintLabel

func _ready():
	hide()

func show_screen(total_lines: int = 0, relics_count: int = 0, gold: int = 0, is_victory: bool = true):
	update_texts(total_lines, relics_count, gold, is_victory)
	show()

func update_texts(total_lines: int = 0, relics_count: int = 0, gold: int = 0, is_victory: bool = true):
	var accent_color = COLOR_WIN if is_victory else COLOR_LOSE
	# 标题颜色与文本
	if title_label:
		title_label.text = tr("UI_ROGUEVICTORY_TITLE_WIN") if is_victory else tr("UI_ROGUEVICTORY_TITLE_LOSE")
		title_label.add_theme_color_override("font_color", accent_color)
	# 面板边框颜色
	if panel_node:
		var style = panel_node.get_theme_stylebox("panel")
		if style is StyleBoxFlat:
			var s = style.duplicate() as StyleBoxFlat
			s.border_color = accent_color
			panel_node.add_theme_stylebox_override("panel", s)
	if stats_header_label:
		stats_header_label.text = tr("UI_ROGUEVICTORY_STATS_HEADER")
	if lines_label:
		lines_label.text = tr("UI_ROGUEVICTORY_LINES") % total_lines
	if relics_label:
		relics_label.text = tr("UI_ROGUEVICTORY_RELICS") % relics_count
	if gold_label:
		gold_label.text = tr("UI_ROGUEVICTORY_GOLD") % gold
	
	# 分数折算（整体参数折半）: 消行×50 + 装备×100 + 金币×5
	var score_lines: int = total_lines * 50
	var score_relics: int = relics_count * 100
	var score_gold: int = gold * 5
	var total_score: int = score_lines + score_relics + score_gold
	
	if score_sep_label:
		score_sep_label.text = tr("UI_ROGUEVICTORY_SCORE_HEADER")
	if score_label:
		score_label.text = tr("UI_ROGUEVICTORYSCREEN_VAR_NVAR_NVAR_NVAR") % [
			tr("UI_ROGUEVICTORY_SCORE_LINES") % [total_lines, score_lines],
			tr("UI_ROGUEVICTORY_SCORE_RELICS") % [relics_count, score_relics],
			tr("UI_ROGUEVICTORY_SCORE_GOLD") % [gold, score_gold],
			tr("UI_ROGUEVICTORY_SCORE_TOTAL") % total_score
		]
	
	if hint_label:
		hint_label.text = tr("UI_HINT_PRESS_ENTER_FOR_MENU")

func _input(event: InputEvent):
	if not visible:
		return
	if event.is_action_pressed("ui_accept"):
		return_to_menu.emit()
	#	get_viewport().set_input_as_handled()
