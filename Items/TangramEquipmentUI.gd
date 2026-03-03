extends Control
class_name TangramEquipmentUI

## 七巧板装备UI - Rogue模式专用
## 装备以俄罗斯方块形式呈现，需手动放入7x7网格中
## 支持鼠标拖拽放置/移除 + 悬停信息弹窗

const CELL_SIZE: int = 18  # 每个格子的大小（7x7需要更小的格子）
const GRID_WIDTH: int = 7  # 网格宽度
const GRID_HEIGHT: int = 7  # 网格高度
const UI_FONT = preload("res://fonts/FUSION-PIXEL-12PX-MONOSPACED-ZH_HANS.OTF")

# 装备形状定义（相对坐标列表）
const EQUIPMENT_SHAPES: Dictionary = {
	"iron_sword": {
		# 铁剑：倒✝形（剑刃+护手），6格
		"shape": [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(1, 2), Vector2i(1, 3)],
		"color": Color(0.85, 0.55, 0.2, 1.0),
		"icon": "⚔"
	},
	"iron_shield": {
		# 铁盾：甲形（盾牌轮廓），7格
		"shape": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(1, 2)],
		"color": Color(0.5, 0.6, 0.85, 1.0),
		"icon": "🛡"
	},
	"downclock_software": {
		# 降频软件：横条-形（减速/降频），3格
		"shape": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)],
		"color": Color(0.2, 0.6, 1.0, 1.0),
		"icon": "⏱"
	},
	"faulty_score_amplifier": {
		# 故障增幅器：+形（增幅/扩展），5格
		"shape": [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(1, 2)],
		"color": Color(0.9, 0.6, 0.2, 1.0),
		"icon": "⚡"
	},
	"rift_meter": {
		# 裂隙仪：90°旋转=形（平行裂缝），4格
		"shape": [Vector2i(0, 0), Vector2i(2, 0), Vector2i(0, 1), Vector2i(2, 1)],
		"color": Color(0.3, 0.85, 0.95, 1.0),
		"icon": "◇"
	}
}

# 装备ID到EquipmentSystem.EquipmentType的映射
const EQUIPMENT_TYPE_MAP: Dictionary = {
	"iron_sword": 9,
	"iron_shield": 10,
	"downclock_software": 7,
	"faulty_score_amplifier": 2,
	"rift_meter": 3,
}

static func equipment_type_to_id(equip_type: int) -> String:
	for id in EQUIPMENT_TYPE_MAP:
		if EQUIPMENT_TYPE_MAP[id] == equip_type:
			return id
	return ""

# 多语言文本
const TEXTS: Dictionary = {
	"zh": {
		"title": "装备栏",
		"empty_slot": "空",
		"iron_sword": "铁剑",
		"iron_sword_desc": "攻击力+5",
		"iron_shield": "铁盾",
		"iron_shield_desc": "每次防御额外+5护甲",
		"downclock_software": "降频软件",
		"downclock_software_desc": "敌人行为冷却×110%",
		"faulty_score_amplifier": "故障增幅器",
		"faulty_score_amplifier_desc": "初始攻防+15%\n下落速度+5%",
		"rift_meter": "裂隙仪",
		"rift_meter_desc": "每45秒可消除指定一整行",
		"bag_header": "背包",
		"equipped_header": "已装备",
		"drag_hint": "拖拽到网格放置，R旋转",
		"info_hint": "悬停查看装备信息",
		"close_hint": "ESC 关闭"
	},
	"en": {
		"title": "Equipment",
		"empty_slot": "Empty",
		"iron_sword": "Iron Sword",
		"iron_sword_desc": "ATK +5",
		"iron_shield": "Iron Shield",
		"iron_shield_desc": "DEF +5 armor per line",
		"downclock_software": "Downclock",
		"downclock_software_desc": "Enemy cooldown ×110%",
		"faulty_score_amplifier": "Faulty Amp",
		"faulty_score_amplifier_desc": "Base ATK/DEF +15%\nSpeed +5%",
		"rift_meter": "Rift Meter",
		"rift_meter_desc": "Clear a row every 45s",
		"bag_header": "Bag",
		"equipped_header": "Equipped",
		"drag_hint": "Drag to grid, R to rotate",
		"info_hint": "Hover for info",
		"close_hint": "ESC Close"
	}
}

# 装备栏网格（true表示被占用）
var grid: Array = []  # 7x7网格

# 已放置的装备
var placed_equipment: Array = []  # [{id, position: Vector2i, shape: Array, rotation: int}]

# 未放置的装备（背包）
var inventory: Array = []  # [String] 装备ID列表

# ===== 鼠标拖拽状态 =====
var dragging: bool = false
var drag_equip_id: String = ""
var drag_rotation: int = 0
var drag_from_grid: bool = false   # 是否从网格上拖起
var drag_mouse_pos: Vector2 = Vector2.ZERO

# ===== 悬停信息弹窗 =====
var hover_equip_id: String = ""      # 当前悬停的装备ID
var hover_timer: float = 0.0         # 悬停计时

# ===== 键盘放置（兼容） =====
var placement_mode: bool = false
var cursor_position: Vector2i = Vector2i(0, 0)
var cursor_equipment: String = ""
var cursor_rotation: int = 0
var inventory_cursor: int = 0

# 浏览模式（保留兼容接口，实际不再使用）
var browse_mode: bool = false
var browse_index: int = 0

# UI状态
var is_visible: bool = false

# 绘制偏移（_draw中动态计算）
var grid_offset: Vector2 = Vector2.ZERO
var panel_pos: Vector2 = Vector2.ZERO
var panel_size: Vector2 = Vector2.ZERO

# 物品卡片的屏幕矩形（用于鼠标点击/拖拽检测）
var inv_card_rects: Array = []      # [{rect: Rect2, id: String}]
var placed_card_rects: Array = []   # [{rect: Rect2, id: String}]

signal equipment_changed(equipped_list: Array)
signal placement_completed

func _ready():
	_init_grid()

func _init_grid():
	grid.clear()
	for y in range(GRID_HEIGHT):
		var row: Array = []
		for x in range(GRID_WIDTH):
			row.append(false)
		grid.append(row)
	placed_equipment.clear()
	inventory.clear()

func _t(key: String) -> String:
	var lang: String = Global.current_language if Global.current_language in TEXTS else "zh"
	return TEXTS[lang].get(key, key)

func show_ui():
	is_visible = true
	placement_mode = false
	browse_mode = false
	dragging = false
	show()
	queue_redraw()

func hide_ui():
	is_visible = false
	placement_mode = false
	browse_mode = false
	dragging = false
	hide()

func add_to_inventory(equip_id: String):
	if not equip_id in EQUIPMENT_SHAPES:
		return
	if has_equipment(equip_id):
		return
	if inventory.has(equip_id):
		return
	inventory.append(equip_id)
	queue_redraw()

func start_placement(equip_id: String):
	if not equip_id in EQUIPMENT_SHAPES:
		return
	cursor_equipment = equip_id
	cursor_position = Vector2i(0, 0)
	cursor_rotation = 0
	placement_mode = true
	dragging = false
	queue_redraw()

func _get_rotated_shape(equip_id: String, rotation: int) -> Array:
	if not equip_id in EQUIPMENT_SHAPES:
		return []
	var base_shape: Array = EQUIPMENT_SHAPES[equip_id]["shape"]
	var rot_steps := ((rotation % 4) + 4) % 4
	if rot_steps == 0:
		return base_shape.duplicate()

	# 裂隙仪是“稀疏平行线”形状，若使用几何中心+四舍五入会把中间空隙放大为2格。
	# 对该装备使用离散原点旋转，确保空隙稳定为1格。
	if equip_id == "rift_meter":
		var rift_rotated: Array = []
		for cell in base_shape:
			var rc: Vector2i = cell
			for _r in range(rot_steps):
				rc = Vector2i(-rc.y, rc.x)
			rift_rotated.append(rc)
		var rift_min_x: int = 999
		var rift_min_y: int = 999
		for cell in rift_rotated:
			rift_min_x = min(rift_min_x, cell.x)
			rift_min_y = min(rift_min_y, cell.y)
		var rift_normalized: Array = []
		for cell in rift_rotated:
			rift_normalized.append(Vector2i(cell.x - rift_min_x, cell.y - rift_min_y))
		return rift_normalized

	# 以形状几何中心（格子中心的平均值）为旋转中心做近似旋转
	var center := Vector2.ZERO
	for cell in base_shape:
		center += Vector2(float(cell.x) + 0.5, float(cell.y) + 0.5)
	center /= float(base_shape.size())

	var rotated: Array = []
	var used := {}
	for cell in base_shape:
		var p := Vector2(float(cell.x) + 0.5, float(cell.y) + 0.5) - center
		var q := p
		for _i in range(rot_steps):
			q = Vector2(-q.y, q.x)
		q += center
		var gx := int(round(q.x - 0.5))
		var gy := int(round(q.y - 0.5))
		var key := str(gx) + "," + str(gy)
		if not used.has(key):
			used[key] = true
			rotated.append(Vector2i(gx, gy))

	# 极端四舍五入冲突时，回退到原有原点旋转，保证格子数不丢
	if rotated.size() != base_shape.size():
		rotated.clear()
		for cell in base_shape:
			var rc: Vector2i = cell
			for _r in range(rot_steps):
				rc = Vector2i(-rc.y, rc.x)
			rotated.append(rc)

	var min_x: int = 999
	var min_y: int = 999
	for cell in rotated:
		min_x = min(min_x, cell.x)
		min_y = min(min_y, cell.y)
	var normalized: Array = []
	for cell in rotated:
		normalized.append(Vector2i(cell.x - min_x, cell.y - min_y))
	return normalized

func can_place_equipment(equip_id: String, pos: Vector2i, rotation: int = 0) -> bool:
	var shape: Array = _get_rotated_shape(equip_id, rotation)
	if shape.is_empty():
		return false
	for cell in shape:
		var x: int = pos.x + cell.x
		var y: int = pos.y + cell.y
		if x < 0 or x >= GRID_WIDTH or y < 0 or y >= GRID_HEIGHT:
			return false
		if grid[y][x]:
			return false
	return true

func auto_place_equipment(equip_id: String) -> bool:
	if not equip_id in EQUIPMENT_SHAPES:
		return false
	if has_equipment(equip_id):
		return true
	for rot in range(4):
		for y in range(GRID_HEIGHT):
			for x in range(GRID_WIDTH):
				if can_place_equipment(equip_id, Vector2i(x, y), rot):
					return place_equipment(equip_id, Vector2i(x, y), rot)
	if not inventory.has(equip_id):
		inventory.append(equip_id)
	return false

func get_equipped_types() -> Array:
	var types: Array = []
	for equip in placed_equipment:
		if EQUIPMENT_TYPE_MAP.has(equip.id):
			types.append(EQUIPMENT_TYPE_MAP[equip.id])
	return types

func place_equipment(equip_id: String, pos: Vector2i, rotation: int = 0) -> bool:
	if not can_place_equipment(equip_id, pos, rotation):
		return false
	var shape: Array = _get_rotated_shape(equip_id, rotation)
	for cell in shape:
		grid[pos.y + cell.y][pos.x + cell.x] = true
	placed_equipment.append({
		"id": equip_id,
		"position": pos,
		"shape": shape,
		"rotation": rotation
	})
	var inv_idx: int = inventory.find(equip_id)
	if inv_idx >= 0:
		inventory.remove_at(inv_idx)
	_emit_equipment_changed()
	queue_redraw()
	return true

func remove_equipment(equip_id: String) -> bool:
	for i in range(placed_equipment.size() - 1, -1, -1):
		var equip: Dictionary = placed_equipment[i]
		if equip.id == equip_id:
			for cell in equip.shape:
				grid[equip.position.y + cell.y][equip.position.x + cell.x] = false
			placed_equipment.remove_at(i)
			if not inventory.has(equip_id):
				inventory.append(equip_id)
			_emit_equipment_changed()
			queue_redraw()
			return true
	return false

func has_equipment(equip_id: String) -> bool:
	for equip in placed_equipment:
		if equip.id == equip_id:
			return true
	return false

func get_equipped_list() -> Array:
	var result: Array = []
	for equip in placed_equipment:
		result.append(equip.id)
	return result

func _emit_equipment_changed():
	equipment_changed.emit(get_equipped_list())

# ===== 鼠标坐标 → 网格坐标 =====
func _mouse_to_grid(mouse_pos: Vector2) -> Vector2i:
	var local: Vector2 = mouse_pos - grid_offset
	var gx: int = int(floor(local.x / CELL_SIZE))
	var gy: int = int(floor(local.y / CELL_SIZE))
	return Vector2i(gx, gy)

func _is_over_grid(mouse_pos: Vector2) -> bool:
	var gp: Vector2i = _mouse_to_grid(mouse_pos)
	return gp.x >= 0 and gp.x < GRID_WIDTH and gp.y >= 0 and gp.y < GRID_HEIGHT

func _get_equip_at_grid(gx: int, gy: int) -> String:
	## 返回占据该格子的装备ID
	for equip in placed_equipment:
		for cell in equip.shape:
			if equip.position.x + cell.x == gx and equip.position.y + cell.y == gy:
				return equip.id
	return ""

# ===== 输入处理 =====
func _input(event: InputEvent):
	if not is_visible or not visible:
		return

	# ESC / E 关闭
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE or event.keycode == KEY_E:
			if dragging:
				_cancel_drag()
			else:
				hide_ui()
				placement_completed.emit()
			get_viewport().set_input_as_handled()
			return
		# R / Z 旋转
		if event.keycode == KEY_R or event.keycode == KEY_Z:
			if dragging:
				drag_rotation = (drag_rotation + 1) % 4
				queue_redraw()
				get_viewport().set_input_as_handled()
				return
			elif placement_mode:
				cursor_rotation = (cursor_rotation + 1) % 4
				queue_redraw()
				get_viewport().set_input_as_handled()
				return

	# 键盘放置模式（保留基本兼容）
	if placement_mode and not dragging:
		_handle_keyboard_placement(event)
		return

	# 鼠标事件
	if event is InputEventMouseButton:
		_handle_mouse_button(event)
	elif event is InputEventMouseMotion:
		_handle_mouse_motion(event)

func _handle_mouse_button(event: InputEventMouseButton):
	var pos: Vector2 = event.position

	if event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			# 左键按下：开始拖拽
			if dragging:
				_try_drop(pos)
				return

			# 检查是否点击了背包物品卡片
			for card in inv_card_rects:
				if card.rect.has_point(pos):
					_start_drag(card.id, false, pos)
					get_viewport().set_input_as_handled()
					return

			# 检查是否点击了网格上的装备
			if _is_over_grid(pos):
				var gp: Vector2i = _mouse_to_grid(pos)
				var eid: String = _get_equip_at_grid(gp.x, gp.y)
				if not eid.is_empty():
					remove_equipment(eid)
					# remove_equipment 将其放回 inventory，拖拽时从 inventory 取出
					var idx: int = inventory.find(eid)
					if idx >= 0:
						inventory.remove_at(idx)
					_start_drag(eid, true, pos)
					get_viewport().set_input_as_handled()
					return

			# 检查是否点击了已放置列表卡片（也从网格拿起）
			for card in placed_card_rects:
				if card.rect.has_point(pos):
					var eid2: String = card.id
					remove_equipment(eid2)
					var idx2: int = inventory.find(eid2)
					if idx2 >= 0:
						inventory.remove_at(idx2)
					_start_drag(eid2, true, pos)
					get_viewport().set_input_as_handled()
					return
		else:
			# 左键释放
			if dragging:
				_try_drop(pos)
				get_viewport().set_input_as_handled()
				return

	elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		# 右键：旋转拖拽中装备
		if dragging:
			drag_rotation = (drag_rotation + 1) % 4
			queue_redraw()
			get_viewport().set_input_as_handled()

func _handle_mouse_motion(event: InputEventMouseMotion):
	drag_mouse_pos = event.position
	if dragging:
		queue_redraw()
		get_viewport().set_input_as_handled()
		return

	_update_hover_at(event.position)

func _start_drag(equip_id: String, from_grid: bool, mouse_pos: Vector2 = Vector2.INF):
	dragging = true
	drag_equip_id = equip_id
	drag_from_grid = from_grid
	drag_rotation = 0
	if mouse_pos == Vector2.INF:
		drag_mouse_pos = get_viewport().get_mouse_position()
	else:
		drag_mouse_pos = mouse_pos
	queue_redraw()

func _cancel_drag():
	if dragging and not drag_equip_id.is_empty():
		if not inventory.has(drag_equip_id):
			inventory.append(drag_equip_id)
	dragging = false
	drag_equip_id = ""
	queue_redraw()

func _try_drop(pos: Vector2):
	if not dragging or drag_equip_id.is_empty():
		dragging = false
		return

	if _is_over_grid(pos):
		var gp: Vector2i = _mouse_to_grid(pos)
		var shape: Array = _get_rotated_shape(drag_equip_id, drag_rotation)
		var co: Vector2i = _get_shape_center_offset(shape)
		var place_pos := Vector2i(gp.x - co.x, gp.y - co.y)

		if can_place_equipment(drag_equip_id, place_pos, drag_rotation):
			place_equipment(drag_equip_id, place_pos, drag_rotation)
			dragging = false
			drag_equip_id = ""
			print("[七巧板] 鼠标放置装备到 (%d,%d)" % [place_pos.x, place_pos.y])
			return

	# 放不下 → 放回背包
	_cancel_drag()

func _get_shape_center_offset(shape: Array) -> Vector2i:
	if shape.is_empty():
		return Vector2i.ZERO
	var cx: int = 0
	var cy: int = 0
	for cell in shape:
		cx += cell.x
		cy += cell.y
	return Vector2i(cx / shape.size(), cy / shape.size())

func _handle_keyboard_placement(event: InputEvent):
	if event.is_action_pressed("ui_left"):
		cursor_position.x = max(0, cursor_position.x - 1)
		queue_redraw()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_right"):
		cursor_position.x = min(GRID_WIDTH - 1, cursor_position.x + 1)
		queue_redraw()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_up"):
		cursor_position.y = max(0, cursor_position.y - 1)
		queue_redraw()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_down"):
		cursor_position.y = min(GRID_HEIGHT - 1, cursor_position.y + 1)
		queue_redraw()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			if can_place_equipment(cursor_equipment, cursor_position, cursor_rotation):
				place_equipment(cursor_equipment, cursor_position, cursor_rotation)
				placement_mode = false
				if inventory.size() > 0:
					start_placement(inventory[0])
				else:
					placement_completed.emit()
			get_viewport().set_input_as_handled()

func _process(delta: float):
	if not is_visible:
		return
	if not dragging:
		_update_hover_at(get_viewport().get_mouse_position())
	if not hover_equip_id.is_empty():
		hover_timer += delta

func _update_hover_at(pos: Vector2) -> void:
	var new_hover: String = ""
	for card in inv_card_rects:
		if card.rect.has_point(pos):
			new_hover = card.id
			break
	if new_hover.is_empty():
		for card in placed_card_rects:
			if card.rect.has_point(pos):
				new_hover = card.id
				break
	if new_hover.is_empty() and _is_over_grid(pos):
		var gp: Vector2i = _mouse_to_grid(pos)
		new_hover = _get_equip_at_grid(gp.x, gp.y)

	if new_hover != hover_equip_id:
		hover_equip_id = new_hover
		hover_timer = 0.0
		queue_redraw()

# ===== 绘制 =====
func _draw():
	if not is_visible:
		return

	var vp_size: Vector2 = get_viewport_rect().size

	# 全屏半透明遮罩（略带紫色调）
	draw_rect(Rect2(Vector2.ZERO, vp_size), Color(0.02, 0.01, 0.06, 0.7))

	# 居中面板
	var pw: float = 340.0
	var ph: float = 440.0
	panel_pos = Vector2((vp_size.x - pw) * 0.5, (vp_size.y - ph) * 0.5)
	panel_size = Vector2(pw, ph)

	# 面板背景 + 像素风双重边框
	draw_rect(Rect2(panel_pos, panel_size), Color(0.08, 0.07, 0.13, 0.97))
	draw_rect(Rect2(panel_pos - Vector2(2, 2), panel_size + Vector2(4, 4)), Color(0.55, 0.45, 0.70), false, 2.0)
	draw_rect(Rect2(panel_pos - Vector2(4, 4), panel_size + Vector2(8, 8)), Color(0.35, 0.28, 0.50, 0.5), false, 1.0)
	
	# 标题栏背景
	var title_bar_h = 30.0
	draw_rect(Rect2(panel_pos, Vector2(pw, title_bar_h)), Color(0.12, 0.10, 0.20))
	draw_line(panel_pos + Vector2(0, title_bar_h), panel_pos + Vector2(pw, title_bar_h),
		Color(0.55, 0.45, 0.70), 2.0)

	# 标题文字
	draw_string(UI_FONT, panel_pos + Vector2(10, 22), _t("title"),
		HORIZONTAL_ALIGNMENT_LEFT, int(pw - 20), 14, Color(0.90, 0.85, 1.0))

	# 网格
	var grid_total_w: float = GRID_WIDTH * CELL_SIZE
	grid_offset = panel_pos + Vector2((pw - grid_total_w) * 0.5, 38)
	_draw_grid()

	# 已放置装备
	_draw_placed_equipment()

	# 键盘放置预览
	if placement_mode and not cursor_equipment.is_empty() and not dragging:
		_draw_keyboard_preview()

	# 鼠标拖拽预览
	if dragging and not drag_equip_id.is_empty():
		_draw_drag_preview()

	# 面板下方：物品列表
	_draw_item_lists()

	# 悬停信息弹窗
	if not hover_equip_id.is_empty() and hover_timer > 0.15 and not dragging:
		_draw_tooltip()

	# 底部提示
	_draw_hints()

func _draw_grid():
	# 网格外边框（像素风）
	var grid_rect = Rect2(grid_offset - Vector2(2, 2), 
		Vector2(GRID_WIDTH * CELL_SIZE + 4, GRID_HEIGHT * CELL_SIZE + 4))
	draw_rect(grid_rect, Color(0.45, 0.38, 0.60), false, 2.0)
	
	for y in range(GRID_HEIGHT):
		for x in range(GRID_WIDTH):
			var cell_rect := Rect2(
				grid_offset + Vector2(x * CELL_SIZE, y * CELL_SIZE),
				Vector2(CELL_SIZE, CELL_SIZE))
			# 棋盘格交替色（像素风格）
			var checker = (x + y) % 2 == 0
			var bg := Color(0.16, 0.15, 0.22) if checker else Color(0.13, 0.12, 0.19)
			if grid[y][x]:
				bg = Color(0.10, 0.10, 0.15)

			# 拖拽中高亮目标区域
			if dragging and _is_over_grid(drag_mouse_pos):
				var gp: Vector2i = _mouse_to_grid(drag_mouse_pos)
				var shape: Array = _get_rotated_shape(drag_equip_id, drag_rotation)
				var co: Vector2i = _get_shape_center_offset(shape)
				var pp := Vector2i(gp.x - co.x, gp.y - co.y)
				for cell in shape:
					if pp.x + cell.x == x and pp.y + cell.y == y:
						var can_pl: bool = can_place_equipment(drag_equip_id, pp, drag_rotation)
						bg = Color(0.2, 0.55, 0.2, 0.85) if can_pl else Color(0.55, 0.2, 0.2, 0.85)

			draw_rect(cell_rect, bg)
			draw_rect(cell_rect, Color(0.30, 0.28, 0.40, 0.7), false, 1.0)

func _draw_placed_equipment():
	for equip in placed_equipment:
		var equip_data: Dictionary = EQUIPMENT_SHAPES.get(equip.id, {})
		if equip_data.is_empty():
			continue
		var color: Color = equip_data["color"]
		var is_hover: bool = equip.id == hover_equip_id and not dragging
		if is_hover:
			color = color.lightened(0.3)
		for cell in equip.shape:
			var x: int = equip.position.x + cell.x
			var y: int = equip.position.y + cell.y
			var cr := Rect2(
				grid_offset + Vector2(x * CELL_SIZE + 1, y * CELL_SIZE + 1),
				Vector2(CELL_SIZE - 2, CELL_SIZE - 2))
			draw_rect(cr, color)
			# 像素风内高光（左上亮边）
			var hl := color.lightened(0.25)
			hl.a = 0.5
			draw_line(cr.position, cr.position + Vector2(cr.size.x, 0), hl, 1.0)
			draw_line(cr.position, cr.position + Vector2(0, cr.size.y), hl, 1.0)
			# 右下暗边
			var sh := color.darkened(0.3)
			sh.a = 0.6
			draw_line(cr.position + Vector2(0, cr.size.y), cr.position + cr.size, sh, 1.0)
			draw_line(cr.position + Vector2(cr.size.x, 0), cr.position + cr.size, sh, 1.0)

func _draw_keyboard_preview():
	var shape: Array = _get_rotated_shape(cursor_equipment, cursor_rotation)
	var can_pl: bool = can_place_equipment(cursor_equipment, cursor_position, cursor_rotation)
	var pcolor: Color = Color(0.3, 1.0, 0.3, 0.5) if can_pl else Color(1.0, 0.3, 0.3, 0.4)
	for cell in shape:
		var x: int = cursor_position.x + cell.x
		var y: int = cursor_position.y + cell.y
		if x >= 0 and x < GRID_WIDTH and y >= 0 and y < GRID_HEIGHT:
			var cr := Rect2(
				grid_offset + Vector2(x * CELL_SIZE + 1, y * CELL_SIZE + 1),
				Vector2(CELL_SIZE - 2, CELL_SIZE - 2))
			draw_rect(cr, pcolor)

func _draw_drag_preview():
	## 在鼠标位置绘制拖拽中的装备形状
	var equip_data: Dictionary = EQUIPMENT_SHAPES.get(drag_equip_id, {})
	if equip_data.is_empty():
		return
	var shape: Array = _get_rotated_shape(drag_equip_id, drag_rotation)
	var color: Color = equip_data["color"]
	color.a = 0.7
	var co: Vector2i = _get_shape_center_offset(shape)
	for cell in shape:
		var px: float = drag_mouse_pos.x + (cell.x - co.x) * CELL_SIZE - CELL_SIZE * 0.5
		var py: float = drag_mouse_pos.y + (cell.y - co.y) * CELL_SIZE - CELL_SIZE * 0.5
		draw_rect(Rect2(Vector2(px, py), Vector2(CELL_SIZE - 1, CELL_SIZE - 1)), color)

func _draw_item_lists():
	## 绘制面板下方的背包 + 已装备列表（像素风卡片）
	var info_x: float = panel_pos.x + 10
	var max_w: int = int(panel_size.x - 20)
	var cur_y: float = grid_offset.y + GRID_HEIGHT * CELL_SIZE + 10

	inv_card_rects.clear()
	placed_card_rects.clear()

	# 背包标题（带装饰线）
	if inventory.size() > 0:
		var header_text := _t("bag_header")
		draw_string(UI_FONT, Vector2(info_x + 2, cur_y + 10), header_text,
			HORIZONTAL_ALIGNMENT_LEFT, max_w, 10, Color(0.90, 0.78, 0.45))
		var header_w = UI_FONT.get_string_size(header_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
		draw_line(Vector2(info_x + header_w + 8, cur_y + 7),
			Vector2(info_x + max_w, cur_y + 7), Color(0.45, 0.38, 0.25, 0.5), 1.0)
		cur_y += 16
		for i in range(inventory.size()):
			var eid: String = inventory[i]
			var edata: Dictionary = EQUIPMENT_SHAPES.get(eid, {})
			var card_rect := Rect2(Vector2(info_x, cur_y), Vector2(max_w, 22))
			inv_card_rects.append({"rect": card_rect, "id": eid})

			var is_hover: bool = hover_equip_id == eid and not dragging
			var card_bg := Color(0.14, 0.13, 0.20) if not is_hover else Color(0.22, 0.20, 0.32)
			draw_rect(card_rect, card_bg)
			# 左侧装备颜色条
			var dot_color: Color = edata.get("color", Color.GRAY)
			draw_rect(Rect2(Vector2(info_x, cur_y), Vector2(3, 22)), dot_color)
			# 像素风边框
			var border_col := Color(0.55, 0.45, 0.70, 0.6) if is_hover else Color(0.35, 0.30, 0.45, 0.5)
			draw_rect(card_rect, border_col, false, 1.0)
			# 装备小图标方块
			draw_rect(Rect2(Vector2(info_x + 8, cur_y + 5), Vector2(12, 12)), dot_color)
			draw_rect(Rect2(Vector2(info_x + 8, cur_y + 5), Vector2(12, 12)),
				dot_color.lightened(0.3), false, 1.0)
			draw_string(UI_FONT, Vector2(info_x + 26, cur_y + 16), _t(eid),
				HORIZONTAL_ALIGNMENT_LEFT, max_w - 30, 10, Color(0.88, 0.82, 0.68))
			cur_y += 24

	# 已装备列表
	if placed_equipment.size() > 0:
		cur_y += 4
		var eq_header := _t("equipped_header")
		draw_string(UI_FONT, Vector2(info_x + 2, cur_y + 10), eq_header,
			HORIZONTAL_ALIGNMENT_LEFT, max_w, 10, Color(0.45, 0.85, 0.55))
		var eq_hw = UI_FONT.get_string_size(eq_header, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
		draw_line(Vector2(info_x + eq_hw + 8, cur_y + 7),
			Vector2(info_x + max_w, cur_y + 7), Color(0.25, 0.50, 0.30, 0.5), 1.0)
		cur_y += 16
		for equip in placed_equipment:
			var edata: Dictionary = EQUIPMENT_SHAPES.get(equip.id, {})
			var card_rect := Rect2(Vector2(info_x, cur_y), Vector2(max_w, 22))
			placed_card_rects.append({"rect": card_rect, "id": equip.id})

			var is_hover: bool = hover_equip_id == equip.id and not dragging
			var card_bg := Color(0.10, 0.17, 0.14) if not is_hover else Color(0.16, 0.26, 0.20)
			draw_rect(card_rect, card_bg)
			# 左侧绿色已装备条
			draw_rect(Rect2(Vector2(info_x, cur_y), Vector2(3, 22)), Color(0.3, 0.75, 0.4))
			var border_col := Color(0.35, 0.65, 0.45, 0.6) if is_hover else Color(0.25, 0.45, 0.30, 0.5)
			draw_rect(card_rect, border_col, false, 1.0)
			# 已装备小图标
			var dot_color: Color = edata.get("color", Color.GRAY)
			draw_rect(Rect2(Vector2(info_x + 8, cur_y + 5), Vector2(12, 12)), dot_color)
			draw_rect(Rect2(Vector2(info_x + 8, cur_y + 5), Vector2(12, 12)),
				Color(0.3, 0.8, 0.4, 0.5), false, 1.0)
			draw_string(UI_FONT, Vector2(info_x + 26, cur_y + 16), "✓ " + _t(equip.id),
				HORIZONTAL_ALIGNMENT_LEFT, max_w - 30, 10, Color(0.55, 0.90, 0.60))
			cur_y += 24

	elif inventory.size() == 0:
		draw_string(UI_FONT, Vector2(info_x, cur_y + 10), _t("empty_slot"),
			HORIZONTAL_ALIGNMENT_LEFT, max_w, 10, Color(0.40, 0.38, 0.48))

func _draw_tooltip():
	## 在鼠标旁绘制像素风装备信息弹窗
	var desc_key: String = hover_equip_id + "_desc"
	var name_text: String = _t(hover_equip_id)
	var desc_text: String = _t(desc_key)
	var edata: Dictionary = EQUIPMENT_SHAPES.get(hover_equip_id, {})
	var icon_text: String = edata.get("icon", "")

	var tip_w: float = 170.0
	var tip_h: float = 60.0
	var mouse_pos: Vector2 = get_viewport().get_mouse_position()
	var tip_pos := Vector2(mouse_pos.x + 16, mouse_pos.y - 10)
	# 防止溢出屏幕
	var vp: Vector2 = get_viewport_rect().size
	if tip_pos.x + tip_w > vp.x:
		tip_pos.x = mouse_pos.x - tip_w - 8
	if tip_pos.y + tip_h > vp.y:
		tip_pos.y = vp.y - tip_h - 4

	# 双重像素风边框
	draw_rect(Rect2(tip_pos - Vector2(2, 2), Vector2(tip_w + 4, tip_h + 4)),
		Color(0.50, 0.42, 0.65, 0.4), false, 1.0)
	draw_rect(Rect2(tip_pos, Vector2(tip_w, tip_h)), Color(0.06, 0.05, 0.10, 0.97))
	draw_rect(Rect2(tip_pos, Vector2(tip_w, tip_h)), Color(0.55, 0.45, 0.70), false, 2.0)
	# 顶部装备颜色装饰条
	var ecolor: Color = edata.get("color", Color.WHITE)
	draw_rect(Rect2(tip_pos + Vector2(2, 2), Vector2(tip_w - 4, 3)), ecolor.darkened(0.2))

	draw_string(UI_FONT, tip_pos + Vector2(8, 20), icon_text + " " + name_text,
		HORIZONTAL_ALIGNMENT_LEFT, int(tip_w - 16), 12, ecolor)
	draw_string(UI_FONT, tip_pos + Vector2(8, 40), desc_text,
		HORIZONTAL_ALIGNMENT_LEFT, int(tip_w - 16), 10, Color(0.70, 0.68, 0.80))

func _draw_hints():
	# 底部提示栏（带半透明背景条）
	var bar_h: float = 22.0
	var bar_y: float = panel_pos.y + panel_size.y - bar_h
	draw_rect(Rect2(Vector2(panel_pos.x, bar_y), Vector2(panel_size.x, bar_h)),
		Color(0.05, 0.04, 0.10, 0.8))
	draw_line(Vector2(panel_pos.x, bar_y), Vector2(panel_pos.x + panel_size.x, bar_y),
		Color(0.45, 0.38, 0.60, 0.6), 1.0)

	var hint_y: float = bar_y + 15
	var hint_x: float = panel_pos.x + 10
	var max_w: int = int(panel_size.x - 20)
	var hint_parts: Array = []

	if dragging:
		hint_parts.append(_t("drag_hint"))
	elif inventory.size() > 0 or placed_equipment.size() > 0:
		hint_parts.append(_t("info_hint"))
	hint_parts.append(_t("close_hint"))

	draw_string(UI_FONT, Vector2(hint_x, hint_y), " | ".join(hint_parts),
		HORIZONTAL_ALIGNMENT_LEFT, max_w, 10, Color(0.60, 0.55, 0.72))
