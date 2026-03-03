extends Control
class_name RelicSelectionUI

## 装备选择界面 - 战斗胜利后选择或放弃装备（重构版）

signal relic_selected(relic_type: int)
signal relic_skipped

const UI_FONT = preload(Config.PATHS_FONT_DEFAULT)

# 可选装备
var available_relics: Array = []
var selected_index: int = 0
var is_three_choice: bool = false  # 是否为3选1模式
var equipment_system: EquipmentSystem = EquipmentSystem.new()
var runtime_relic_info: Dictionary = {}

# TSCN节点引用
@onready var title_label = $Panel/VBox/TitleLabel
@onready var hint_label = $Panel/VBox/HintLabel
@onready var card_panels = [
	$Panel/VBox/Cards/Card1,
	$Panel/VBox/Cards/Card2,
	$Panel/VBox/Cards/Card3
]
@onready var card_icons = [
	$Panel/VBox/Cards/Card1/VBox/IconLabel,
	$Panel/VBox/Cards/Card2/VBox/IconLabel,
	$Panel/VBox/Cards/Card3/VBox/IconLabel
]
@onready var card_names = [
	$Panel/VBox/Cards/Card1/VBox/NameLabel,
	$Panel/VBox/Cards/Card2/VBox/NameLabel,
	$Panel/VBox/Cards/Card3/VBox/NameLabel
]
@onready var card_descs = [
	$Panel/VBox/Cards/Card1/VBox/DescLabel,
	$Panel/VBox/Cards/Card2/VBox/DescLabel,
	$Panel/VBox/Cards/Card3/VBox/DescLabel
]

# 装备信息 - 与EquipmentSystem保持一致
const RELIC_INFO = {
	EquipmentSystem.EquipmentType.DOWNCLOCK_SOFTWARE: {
		"name_key": "UI_RELIC_NAME_DOWNCLOCK",
		"desc_key": "UI_RELIC_DESC_DOWNCLOCK",
		"color": Color(0.4, 0.5, 0.9),
		"icon": "CLOCK"
	},
	EquipmentSystem.EquipmentType.FAULTY_SCORE_AMPLIFIER: {
		"name_key": "UI_RELIC_NAME_FAULTY_AMP",
		"desc_key": "UI_RELIC_DESC_FAULTY_AMP",
		"color": Color(0.9, 0.6, 0.2),
		"icon": "AMP"
	},
	EquipmentSystem.EquipmentType.RIFT_METER: {
		"name_key": "UI_RELIC_NAME_RIFT_METER",
		"desc_key": "UI_RELIC_DESC_RIFT_METER",
		"color": Color(0.4, 0.7, 0.9),
		"icon": "RIFT"
	},
	EquipmentSystem.EquipmentType.IRON_SWORD: {
		"name_key": "UI_RELIC_NAME_IRON_SWORD",
		"desc_key": "UI_RELIC_DESC_IRON_SWORD",
		"color": Color(0.8, 0.5, 0.2),
		"icon": "SWORD"
	},
	EquipmentSystem.EquipmentType.IRON_SHIELD: {
		"name_key": "UI_RELIC_NAME_IRON_SHIELD",
		"desc_key": "UI_RELIC_DESC_IRON_SHIELD",
		"color": Color(0.5, 0.6, 0.8),
		"icon": "SHIELD"
	}
}

func _ready():
	_load_relic_info_from_data()
	hide()

func _load_relic_info_from_data() -> void:
	# 优先从ResourceDB读取Rogue装备池，避免硬编码与Data脱节
	runtime_relic_info.clear()
	if not Engine.has_singleton("ResourceDB"):
		return
	var db = Engine.get_singleton("ResourceDB")
	if not db or not db.has_method("get_relics_by_kind"):
		return
	var relic_rows: Array[Dictionary] = db.get_relics_by_kind("equipment_relic")
	for row in relic_rows:
		var equip_type = int(row.get("equipment_type", -1))
		if equip_type < 0:
			continue
		var color_arr = row.get("color", [])
		var color = Color(0.5, 0.5, 0.6)
		if color_arr is Array and color_arr.size() >= 3:
			color = Color(float(color_arr[0]), float(color_arr[1]), float(color_arr[2]))
		runtime_relic_info[equip_type] = {
			"name": {
				"zh": row.get("name", tr("UI_RELIC_UNKNOWN")),
				"en": row.get("name_en", row.get("name", tr("UI_RELIC_UNKNOWN")))
			},
			"description": {
				"zh": row.get("description", ""),
				"en": row.get("description_en", row.get("description", ""))
			},
			"color": color,
			"icon": row.get("icon", "?")
		}

func _get_runtime_relic_info() -> Dictionary:
	if not runtime_relic_info.is_empty():
		return runtime_relic_info
	return RELIC_INFO

func show_single_relic():
	# 显示单个随机装备（可获取或放弃）
	is_three_choice = false
	available_relics.clear()
	
	var pool = _get_relic_pool()
	pool.shuffle()
	available_relics.append(pool[0])
	selected_index = 0
	
	if title_label:
		title_label.text = tr("UI_RELIC_FOUND_TITLE")
	if hint_label:
		hint_label.text = tr("UI_RELIC_FOUND_HINT")
	show()
	_refresh_cards()

func show_three_choice():
	# 显示3选1装备
	is_three_choice = true
	available_relics.clear()
	
	var pool = _get_relic_pool()
	pool.shuffle()
	for i in range(min(3, pool.size())):
		available_relics.append(pool[i])
	selected_index = 0
	
	if title_label:
		title_label.text = tr("UI_RELIC_CHOOSE_TITLE")
	if hint_label:
		hint_label.text = tr("UI_RELIC_CHOOSE_HINT")
	show()
	_refresh_cards()

func _refresh_cards():
	var lang = Global.current_language if Global.current_language in ["zh", "en"] else "zh"
	var info_table = _get_runtime_relic_info()
	for i in range(card_panels.size()):
		var panel = card_panels[i]
		var icon_label = card_icons[i]
		var name_label = card_names[i]
		var desc_label = card_descs[i]
		
		if i >= available_relics.size():
			panel.hide()
			continue
		
		var relic_type = available_relics[i]
		var info = info_table.get(relic_type, {})
		var name_text = ""
		var desc_text = ""
		if info.has("name_key"):
			name_text = tr(info.get("name_key", "UI_RELIC_UNKNOWN"))
		elif info.has("name"):
			name_text = info.get("name", {}).get(lang, tr("UI_RELIC_UNKNOWN"))
		else:
			name_text = tr("UI_RELIC_UNKNOWN")
		if info.has("desc_key"):
			desc_text = tr(info.get("desc_key", ""))
		elif info.has("description"):
			desc_text = info.get("description", {}).get(lang, "")
		var icon_text = info.get("icon", "?")
		var base_color = info.get("color", Color(0.5, 0.5, 0.6))
		
		panel.show()
		if icon_label:
			icon_label.text = icon_text
		if name_label:
			name_label.text = name_text
		if desc_label:
			desc_label.text = desc_text
		
		_set_card_style(panel, base_color, i == selected_index)

func _set_card_style(panel: Panel, base_color: Color, is_selected: bool):
	if panel == null:
		return
	var style = StyleBoxFlat.new()
	var bg = UITheme.BG_PANEL if not is_selected else Color(
		UITheme.BG_PANEL.r + 0.05,
		UITheme.BG_PANEL.g + 0.05,
		UITheme.BG_PANEL.b + 0.08,
		1.0
	)
	style.bg_color = bg
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = base_color if is_selected else UITheme.BORDER_MEDIUM
	panel.add_theme_stylebox_override("panel", style)
	panel.modulate = Color(1, 1, 1, 1) if is_selected else Color(0.9, 0.9, 0.95, 1)

func _input(event: InputEvent):
	if not visible:
		return
	if available_relics.is_empty():
		return
	
	if event.is_action_pressed("ui_left"):
		selected_index = max(0, selected_index - 1)
		_refresh_cards()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_right"):
		selected_index = min(available_relics.size() - 1, selected_index + 1)
		_refresh_cards()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept"):
		_confirm_selection()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel") and not is_three_choice:
		_skip_relic()
		get_viewport().set_input_as_handled()

func _confirm_selection():
	if available_relics.is_empty():
		return
	var selected_relic = available_relics[selected_index]
	hide()
	relic_selected.emit(selected_relic)

func _skip_relic():
	hide()
	relic_skipped.emit()

func _get_relic_pool() -> Array:
	var pool: Array = []
	var info_table = _get_runtime_relic_info()
	for relic_type in info_table.keys():
		var category = equipment_system.get_equipment_category(relic_type)
		if category == EquipmentSystem.EquipmentCategory.CLASSIC:
			continue
		if category == EquipmentSystem.EquipmentCategory.SONG:
			continue
		pool.append(relic_type)
	if pool.is_empty():
		pool.append(EquipmentSystem.EquipmentType.DOWNCLOCK_SOFTWARE)
	return pool
