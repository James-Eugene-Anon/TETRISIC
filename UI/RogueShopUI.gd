extends Control
class_name RogueShopUI

## 像素风格商店UI - 杀戮尖塔风格卡片式布局
## 全部通过 _draw() 自定义绘制，不依赖 TSCN 子节点

signal stat_purchased(stat_key: String)
signal equip_purchased(slot_index: int)
signal close_requested
signal toggle_equipment_requested

const UI_FONT = preload(Config.PATHS_FONT_DEFAULT)

# 商店数据
var gold: int = 0
var stat_items: Dictionary = {}  # {stat_key: {label, price, can_afford, free}}
var equip_items: Array = []       # [{label, price, sold, can_afford, free}]

# 交互状态
var selected_index: int = 0  # 0-3: stat, 4-6: equip
var hovered_index: int = -1
var pending_confirmation: bool = false  # 鼠标点击是否等待二次确认
var card_rects: Array = []  # 所有可点击卡片的Rect2

const TEXT_KEYS = {
	"title": "UI_ROGUESHOP_TITLE",
	"gold": "UI_ROGUESHOP_GOLD",
	"free": "UI_ROGUESHOP_FREE",
	"sold": "UI_ROGUESHOP_SOLD",
	"hint": "UI_ROGUESHOP_HINT",
	"stat_header": "UI_ROGUESHOP_STAT_HEADER",
	"equip_header": "UI_ROGUESHOP_EQUIP_HEADER",
	"potion": "UI_ROGUESHOP_POTION",
	"potion_unavailable": "UI_ROGUESHOP_POTION_UNAVAILABLE",
	"equip_empty": "UI_ROGUESHOP_EQUIP_EMPTY",
	"gold_price_fmt": "UI_ROGUESHOPUI_GOLD_PRICE_FMT"
}

# 像素风配色
const COL_BG = Color(0.06, 0.05, 0.10, 0.95)
const COL_PANEL = Color(0.12, 0.10, 0.18)
const COL_CARD = Color(0.16, 0.14, 0.22)
const COL_CARD_HOVER = Color(0.22, 0.19, 0.30)
const COL_CARD_SELECTED = Color(0.28, 0.24, 0.38)
const COL_BORDER = Color(0.45, 0.40, 0.55)
const COL_BORDER_GOLD = Color(0.85, 0.75, 0.35)
const COL_BORDER_SOLD = Color(0.35, 0.30, 0.30)
const COL_TEXT = Color(0.90, 0.88, 0.85)
const COL_TEXT_DIM = Color(0.55, 0.50, 0.50)
const COL_GOLD = Color(1.0, 0.85, 0.25)
const COL_FREE = Color(0.40, 0.85, 0.40)
const COL_SOLD = Color(0.50, 0.40, 0.40)
const COL_HP = Color(0.85, 0.30, 0.30)
const COL_MAXHP = Color(0.90, 0.45, 0.55)
const COL_ATK = Color(0.90, 0.60, 0.20)
const COL_DEF = Color(0.35, 0.65, 0.90)
const COL_EQUIP = Color(0.70, 0.55, 0.90)

func _ready():
	mouse_filter = MOUSE_FILTER_STOP

func _t(key: String) -> String:
	var translation_key = TEXT_KEYS.get(key, "")
	if translation_key == "":
		return key
	return tr(translation_key)

# ===== 外部接口（保持与RoguelikeMap兼容） =====

func set_gold(amount: int):
	gold = amount
	queue_redraw()

func set_stat_button(stat_key: String, label: String, price: int, can_afford: bool, free: bool) -> void:
	stat_items[stat_key] = {"label": label, "price": price, "can_afford": can_afford, "free": free}
	queue_redraw()

func set_equip_button(slot_index: int, label: String, price: int, sold: bool, can_afford: bool, free: bool) -> void:
	while equip_items.size() <= slot_index:
		equip_items.append({"label": _t("equip_empty"), "price": 0, "sold": true, "can_afford": false, "free": false})
	equip_items[slot_index] = {"label": label, "price": price, "sold": sold, "can_afford": can_afford, "free": free}
	queue_redraw()

# ===== 绘制 =====

func _draw():
	var vp = get_viewport_rect().size
	card_rects.clear()
	
	# 全屏半透明遮罩
	draw_rect(Rect2(Vector2.ZERO, vp), COL_BG, true)
	
	# 主面板
	var panel_w = min(560.0, vp.x - 40)
	var panel_h = min(480.0, vp.y - 40)
	var panel_pos = Vector2((vp.x - panel_w) / 2, (vp.y - panel_h) / 2)
	var panel_rect = Rect2(panel_pos, Vector2(panel_w, panel_h))
	
	# 面板背景 + 双重像素边框
	draw_rect(panel_rect, COL_PANEL, true)
	draw_rect(Rect2(panel_pos - Vector2(2, 2), Vector2(panel_w + 4, panel_h + 4)), COL_BORDER, false, 2)
	draw_rect(Rect2(panel_pos - Vector2(4, 4), Vector2(panel_w + 8, panel_h + 8)), Color(COL_BORDER, 0.4), false, 1)
	
	# 标题栏
	var title_h = 40.0
	draw_rect(Rect2(panel_pos, Vector2(panel_w, title_h)), Color(0.08, 0.06, 0.14), true)
	draw_line(panel_pos + Vector2(0, title_h), panel_pos + Vector2(panel_w, title_h), COL_BORDER, 2)
	
	# 标题文字
	draw_string(UI_FONT, panel_pos + Vector2(panel_w / 2 - 30, 28), _t("title"),
		HORIZONTAL_ALIGNMENT_CENTER, 60, 20, COL_GOLD)
	
	# 金币显示
	var gold_text = tr("UI_ROGUELIKEMAP_VAR_NUM") % [_t("gold"), gold]
	draw_string(UI_FONT, panel_pos + Vector2(panel_w - 140, 28), gold_text,
		HORIZONTAL_ALIGNMENT_RIGHT, 130, 14, COL_GOLD)
	# 金币图标（像素小方块）
	draw_rect(Rect2(panel_pos + Vector2(panel_w - 148, 18), Vector2(8, 8)), COL_GOLD, true)
	
	var content_y = panel_pos.y + title_h + 12
	var left_x = panel_pos.x + 16
	var right_x = panel_pos.x + panel_w / 2 + 8
	var col_w = panel_w / 2 - 24
	
	# ===== 左列：属性升级 =====
	draw_string(UI_FONT, Vector2(left_x, content_y + 12), _t("stat_header"),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 12, COL_TEXT_DIM)
	content_y += 24
	
	var stat_keys = ["hp", "max_hp", "atk", "def"]
	var stat_colors = [COL_HP, COL_MAXHP, COL_ATK, COL_DEF]
	var stat_icons = ["♥", "♥+", "⚔", "🛡"]
	
	for i in range(stat_keys.size()):
		var key = stat_keys[i]
		var info = stat_items.get(key, {"label": key, "price": 0, "can_afford": false, "free": false})
		var card_rect = Rect2(Vector2(left_x, content_y), Vector2(col_w, 50))
		card_rects.append(card_rect)
		_draw_stat_card(card_rect, info, stat_colors[i], stat_icons[i], i)
		content_y += 56
	
	# ===== 右列：装备 =====
	content_y = panel_pos.y + title_h + 12
	draw_string(UI_FONT, Vector2(right_x, content_y + 12), _t("equip_header"),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 12, COL_TEXT_DIM)
	content_y += 24
	
	for i in range(min(equip_items.size(), 3)):
		var info = equip_items[i]
		var card_rect = Rect2(Vector2(right_x, content_y), Vector2(col_w, 50))
		card_rects.append(card_rect)
		_draw_equip_card(card_rect, info, i + 4)
		content_y += 56
	
	# 药水卡片（禁用）
	content_y += 8
	var potion_rect = Rect2(Vector2(right_x, content_y), Vector2(col_w, 44))
	_draw_potion_card(potion_rect)
	
	# 底部提示
	var hint_y = panel_pos.y + panel_h - 20
	draw_string(UI_FONT, Vector2(panel_pos.x + 16, hint_y), _t("hint"),
		HORIZONTAL_ALIGNMENT_LEFT, int(panel_w - 32), 11, COL_TEXT_DIM)

func _draw_stat_card(rect: Rect2, info: Dictionary, accent: Color, icon: String, index: int):
	var is_selected = (index == selected_index)
	var is_hovered = (index == hovered_index)
	var is_free = info.get("free", false)
	var can_afford = info.get("can_afford", false) or is_free
	
	# 卡片背景
	var bg = COL_CARD_SELECTED if is_selected else (COL_CARD_HOVER if is_hovered else COL_CARD)
	draw_rect(rect, bg, true)
	
	# 边框
	var border_col = COL_BORDER_GOLD if is_selected else (accent if can_afford else COL_BORDER)
	var border_w = 2.0 if is_selected else 1.0
	draw_rect(rect, border_col, false, border_w)
	
	# 左侧彩色条
	draw_rect(Rect2(rect.position, Vector2(4, rect.size.y)), accent, true)
	
	# 图标
	draw_string(UI_FONT, rect.position + Vector2(12, 20), icon,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 14, accent)
	
	# 属性名称
	var label = info.get("label", "")
	var text_col = COL_TEXT if can_afford else COL_TEXT_DIM
	draw_string(UI_FONT, rect.position + Vector2(30, 20), label,
		HORIZONTAL_ALIGNMENT_LEFT, int(rect.size.x - 40), 13, text_col)
	
	# 价格行
	var price = info.get("price", 0)
	var price_text = _t("free") if is_free else _t("gold_price_fmt") % price
	var price_col = COL_FREE if is_free else (COL_GOLD if can_afford else COL_SOLD)
	draw_string(UI_FONT, rect.position + Vector2(30, 40), price_text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 12, price_col)
	
	# 选中箭头指示
	if is_selected:
		var arrow_x = rect.position.x - 10
		var arrow_y = rect.position.y + rect.size.y / 2
		var pts = PackedVector2Array([
			Vector2(arrow_x, arrow_y - 5),
			Vector2(arrow_x + 7, arrow_y),
			Vector2(arrow_x, arrow_y + 5)
		])
		draw_colored_polygon(pts, COL_GOLD)

func _draw_equip_card(rect: Rect2, info: Dictionary, index: int):
	var is_selected = (index == selected_index)
	var is_hovered = (index == hovered_index)
	var is_sold = info.get("sold", false)
	var is_free = info.get("free", false)
	var can_afford = (info.get("can_afford", false) or is_free) and not is_sold
	
	# 卡片背景
	var bg = COL_CARD_SELECTED if is_selected else (COL_CARD_HOVER if is_hovered else COL_CARD)
	if is_sold:
		bg = Color(0.10, 0.09, 0.12)
	draw_rect(rect, bg, true)
	
	# 边框
	var border_col = COL_BORDER_GOLD if is_selected else (COL_EQUIP if can_afford else COL_BORDER_SOLD)
	var border_w = 2.0 if is_selected else 1.0
	draw_rect(rect, border_col, false, border_w)
	
	# 左侧彩色条
	draw_rect(Rect2(rect.position, Vector2(4, rect.size.y)), COL_EQUIP if not is_sold else COL_SOLD, true)
	
	# 装备名称
	var label = info.get("label", "---")
	var text_col = COL_TEXT if can_afford else COL_TEXT_DIM
	if is_sold:
		text_col = COL_SOLD
	draw_string(UI_FONT, rect.position + Vector2(12, 20), label,
		HORIZONTAL_ALIGNMENT_LEFT, int(rect.size.x - 20), 13, text_col)
	
	# 价格/状态行
	if is_sold:
		draw_string(UI_FONT, rect.position + Vector2(12, 40), _t("sold"),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 12, COL_SOLD)
		# 售罄划线
		var line_y = rect.position.y + rect.size.y / 2
		draw_line(rect.position + Vector2(8, rect.size.y / 2), 
			rect.position + Vector2(rect.size.x - 8, rect.size.y / 2), COL_SOLD, 1)
	else:
		var price = info.get("price", 0)
		var price_text = _t("free") if is_free else _t("gold_price_fmt") % price
		var price_col = COL_FREE if is_free else (COL_GOLD if can_afford else COL_SOLD)
		draw_string(UI_FONT, rect.position + Vector2(12, 40), price_text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 12, price_col)
	
	# 选中箭头
	if is_selected:
		var arrow_x = rect.position.x - 10
		var arrow_y = rect.position.y + rect.size.y / 2
		var pts = PackedVector2Array([
			Vector2(arrow_x, arrow_y - 5),
			Vector2(arrow_x + 7, arrow_y),
			Vector2(arrow_x, arrow_y + 5)
		])
		draw_colored_polygon(pts, COL_GOLD)

func _draw_potion_card(rect: Rect2):
	# 药水卡片（始终禁用）
	draw_rect(rect, Color(0.10, 0.09, 0.12), true)
	draw_rect(rect, COL_BORDER_SOLD, false, 1)
	draw_rect(Rect2(rect.position, Vector2(4, rect.size.y)), COL_SOLD, true)
	var text = tr("UI_ROGUESHOPUI_VAR_VAR") % [_t("potion"), _t("potion_unavailable")]
	draw_string(UI_FONT, rect.position + Vector2(12, 28), text,
		HORIZONTAL_ALIGNMENT_LEFT, int(rect.size.x - 20), 12, COL_SOLD)

# ===== 输入处理 =====

func _get_max_index() -> int:
	return 3 + equip_items.size()  # 4 stats + N equips

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	
	if event.is_action_pressed("ui_cancel"):
		close_requested.emit()
		get_viewport().set_input_as_handled()
		return
	
	if event is InputEventKey and event.pressed and event.keycode == KEY_E:
		toggle_equipment_requested.emit()
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("ui_left"):
		_move_horizontal(-1)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_right"):
		_move_horizontal(1)
		get_viewport().set_input_as_handled()
		return
	
	if event.is_action_pressed("ui_up"):
		selected_index = max(0, selected_index - 1)
		pending_confirmation = false  # 切换选项时清除确认状态
		queue_redraw()
		get_viewport().set_input_as_handled()
		return
	
	if event.is_action_pressed("ui_down"):
		selected_index = min(_get_max_index(), selected_index + 1)
		pending_confirmation = false  # 切换选项时清除确认状态
		queue_redraw()
		get_viewport().set_input_as_handled()
		return
	
	if event.is_action_pressed("ui_accept"):
		_confirm_purchase()
		pending_confirmation = false  # 键盘Enter直接购买，不需二次确认
		get_viewport().set_input_as_handled()
		return

func _gui_input(event: InputEvent) -> void:
	if not visible:
		return

	# 鼠标点击
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		for i in range(card_rects.size()):
			if card_rects[i].has_point(event.position):
				if selected_index == i and pending_confirmation:
					# 第二次点击同一卡片 → 确认购买
					_confirm_purchase()
					pending_confirmation = false
					queue_redraw()
				else:
					# 第一次点击 → 选中卡片，等待二次确认
					selected_index = i
					pending_confirmation = true
					queue_redraw()
				get_viewport().set_input_as_handled()
				return

	# 鼠标悬停
	if event is InputEventMouseMotion:
		hovered_index = -1
		for i in range(card_rects.size()):
			if card_rects[i].has_point(event.position):
				hovered_index = i
				break
		queue_redraw()

func _move_horizontal(dir: int) -> void:
	var equip_count = equip_items.size()
	if dir > 0 and selected_index <= 3:
		if equip_count <= 0:
			return
		var row = min(selected_index, equip_count - 1)
		selected_index = 4 + row
		queue_redraw()
		return
	if dir < 0 and selected_index >= 4:
		var row_left = min(selected_index - 4, 3)
		selected_index = row_left
		queue_redraw()

func _confirm_purchase():
	var stat_keys = ["hp", "max_hp", "atk", "def"]
	if selected_index >= 0 and selected_index < 4:
		# 属性购买
		var key = stat_keys[selected_index]
		stat_purchased.emit(key)
	elif selected_index >= 4:
		# 装备购买
		var equip_idx = selected_index - 4
		if equip_idx < equip_items.size():
			equip_purchased.emit(equip_idx)
