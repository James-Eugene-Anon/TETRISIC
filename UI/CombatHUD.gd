extends Control

## 战斗HUD - 回合信息、模式指示、操作说明、连击显示


@onready var turn_label = $TurnInfoPanel/VBox/TurnLabel
@onready var timer_label = $TurnInfoPanel/VBox/TimerLabel
@onready var mode_label = $CombatModePanel/VBox/ModeLabel
@onready var mode_hint_label = $CombatModePanel/VBox/ModeHintLabel
@onready var controls_label = $ControlsLabel
@onready var combo_label = $ComboLabel
@onready var credit_label = $CreditLabel
@onready var combat_mode_panel = $CombatModePanel

func _ready():
	update_controls_text()

func update_turn_info(turn_number: int, turn_timer: float):
	if turn_label:
		turn_label.text = tr("UI_COMBATHUD_TURN") % turn_number
	if timer_label:
		timer_label.text = tr("UI_COMBATHUD_TIMER") % turn_timer
		# 变色：低于5秒红色，低于10秒橙色
		if turn_timer < 5:
			timer_label.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3, 1))
		elif turn_timer < 10:
			timer_label.add_theme_color_override("font_color", Color(1.0, 0.7, 0.2, 1))
		else:
			timer_label.add_theme_color_override("font_color", Color(0.75, 0.75, 0.80, 1))

func update_combat_mode(is_attack: bool):
	if mode_label:
		mode_label.text = tr("UI_COMBATHUD_ATTACK_MODE") if is_attack else tr("UI_COMBATHUD_DEFEND")
		var color = Color(0.9, 0.3, 0.3, 1) if is_attack else Color(0.4, 0.7, 0.9, 1)
		mode_label.add_theme_color_override("font_color", color)
	if mode_hint_label:
		mode_hint_label.text = tr("UI_COMBATHUD_MODE_HINT")
	# 面板边框颜色
	if combat_mode_panel:
		var style = combat_mode_panel.get_theme_stylebox("panel").duplicate()
		style.border_color = Color(0.9, 0.3, 0.3, 1) if is_attack else Color(0.4, 0.7, 0.9, 1)
		combat_mode_panel.add_theme_stylebox_override("panel", style)

func update_combo(combo_count: int):
	if combo_label == null:
		return
	if combo_count > 1:
		combo_label.text = tr("UI_COMBATHUD_COMBO") % combo_count
		if combo_count <= 5:
			combo_label.add_theme_color_override("font_color", Color(0.95, 0.85, 0.35))
		elif combo_count <= 10:
			combo_label.add_theme_color_override("font_color", Color(0.95, 0.65, 0.25))
		else:
			combo_label.add_theme_color_override("font_color", Color(0.9, 0.4, 0.35))
	else:
		combo_label.text = ""
func update_controls_text():
	if controls_label == null:
		return
	controls_label.text = tr("UI_COMBATHUD_CONTROLS")
