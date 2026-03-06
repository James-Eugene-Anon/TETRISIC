extends Control
class_name RoguelikeMap

## Roguelike地图主界面
## 演示模式：9段随机分层地图（开始->战斗1->随机/宝箱->商店->战斗2分支->随机事件->神秘人->篝火->Boss）
## 正式Rogue模式：暂为占位符（后续接入独立状态机与内容池）

const UI_FONT = preload(Config.PATHS_FONT_DEFAULT)
const PauseMenuScene = preload(Config.PATHS_SCENE_PAUSE_MENU)
const ROGUE_CONFIG_PATH = "res://Data/Roguelike/rogue_config.json"

# 临时开关：当前仅实现“Rogue演示模式”随机分段图
const USE_DEMO_ROGUE_MODE := true

# 地图节点类型
enum NodeType {
	START,
	COMBAT,
	BOSS,
	REST,
	SHOP,
	EVENT,
	TREASURE_CHEST,
}

# 游戏状态
enum GameState {
	MAP,
	COMBAT,
	REST,
	SHOP,
	EVENT,
	VICTORY,
	DEFEAT,
}

var current_state: int = GameState.MAP
var is_paused: bool = false
var _rogue_is_true_victory: bool = false

var map_input_lock_timer: float = 0.0

# 图结构
var map_nodes: Array[Dictionary] = []
var map_layers: Array[Array] = []
var node_index: Dictionary = {}
var map_edges: Dictionary = {}
var current_node_id: int = -1
var active_node_id: int = -1
var selectable_next_ids: Array[int] = []
var selected_next_index: int = 0
var _next_node_id_seed: int = 0
var map_scroll_offset: float = 0.0
const MAP_SCROLL_STEP := 60.0

# 滚动条交互状态
var _scrollbar_track_rect: Rect2 = Rect2()
var _scrollbar_thumb_rect: Rect2 = Rect2()
var _scrollbar_dragging: bool = false
var _scrollbar_drag_offset_x: float = 0.0

# 玩家持久数据（跨战斗）
var player_health: int = 300
var player_max_health: int = 300
var player_gold: int = 13
var collected_relics: Array = []
var total_lines_cleared: int = 0

# 事件系统状态
var event_blood_item_chance: float = 0.25
var event_item_counts: Dictionary = {}
var event_random_item_pool: Array[Dictionary] = []
var current_event_data: Dictionary = {}

# 商店系统
var shop_stat_buys: Dictionary = {"hp": 0, "max_hp": 0, "atk": 0, "def": 0}
var shop_first_hp_free: bool = true
var shop_hp_free_available: bool = true
var shop_first_item_free: bool = true
var shop_ui: RogueShopUI = null
var shop_stat_items: Dictionary = {}
var shop_equip_items: Array = []

# 七巧板装备系统
var tangram_equipment: TangramEquipmentUI = null
var tangram_equipped_list: Array = []

var wave_configs: Array = []
var wave_id_to_index: Dictionary = {}
var shop_stat_base_prices: Dictionary = {}
var shop_stat_values: Dictionary = {}
var shop_equip_pool_data: Array = []

# 子场景
var combat_scene: Control = null
var chest_ui: Control = null
var pause_menu: Control = null

# TSCN子节点引用
@onready var map_title_label: Label = $MapTitle
@onready var status_title_label: Label = $PlayerStatusPanel/StatusTitle
@onready var player_status_panel: Panel = $PlayerStatusPanel
@onready var hp_bar: ProgressBar = $PlayerStatusPanel/HPBar
@onready var hp_label: Label = $PlayerStatusPanel/HPLabel
@onready var equip_label: Label = $PlayerStatusPanel/EquipLabel
@onready var lines_label: Label = $PlayerStatusPanel/LinesLabel
@onready var equip_hint_label: Label = $PlayerStatusPanel/EquipHintLabel
@onready var hint_label: Label = $HintLabel
@onready var credit_label: Label = $CreditLabel
@onready var defeat_screen = $DefeatScreen
@onready var victory_screen = $VictoryScreen
@onready var rest_screen = $RestScreen
@onready var event_panel: PanelContainer = $EventPanel
@onready var event_title_label: Label = $EventPanel/Margin/VBox/TitleLabel
@onready var event_desc_label: Label = $EventPanel/Margin/VBox/ContentHBox/DescLabel
@onready var event_buttons_row: VBoxContainer = $EventPanel/Margin/VBox/ContentHBox/ButtonsRow

const NODE_SIZE := 54.0
const MAP_CENTER_Y := 340.0
const LAYER_SPACING := 110.0
const ROW_SPACING := 96.0
const BASE_FRAME_SIZE = Vector2(800, 600)

# 节点图片接口（后续将null替换为Texture2D即可）
const NODE_TEXTURES: Dictionary = {
	NodeType.START: null,
	NodeType.COMBAT: null,
	NodeType.BOSS: null,
	NodeType.REST: null,
	NodeType.SHOP: null,
	NodeType.EVENT: null,
	NodeType.TREASURE_CHEST: null,
}

const NODE_COLORS = {
	NodeType.START: Color(0.4, 0.7, 0.4),
	NodeType.COMBAT: Color(0.8, 0.3, 0.3),
	NodeType.BOSS: Color(0.9, 0.2, 0.5),
	NodeType.REST: Color(0.3, 0.7, 0.9),
	NodeType.SHOP: Color(0.9, 0.8, 0.3),
	NodeType.EVENT: Color(0.6, 0.45, 0.9),
	NodeType.TREASURE_CHEST: Color(0.85, 0.65, 0.15),
}

const NODE_ICON_KEYS = {
	NodeType.START: "UI_ROGUELIKEMAP_ICON_START",
	NodeType.COMBAT: "UI_ROGUELIKEMAP_ICON_COMBAT",
	NodeType.BOSS: "UI_ROGUELIKEMAP_ICON_BOSS",
	NodeType.REST: "UI_ROGUELIKEMAP_ICON_REST",
	NodeType.SHOP: "UI_ROGUELIKEMAP_ICON_SHOP",
	NodeType.TREASURE_CHEST: "UI_ROGUELIKEMAP_ICON_CHEST",
}

const TEXT_KEYS = {
	"map_title": "UI_ROGUELIKEMAP_MAP_TITLE",
	"player_status": "UI_ROGUELIKEMAP_PLAYER_STATUS",
	"equipment": "UI_ROGUELIKEMAP_EQUIPMENT",
	"lines": "UI_ROGUELIKEMAP_LINES",
	"hint": "UI_HINT_ENTER_NEXT_NODE_ESC_PAUSE",
	"next_hint": "UI_ROGUELIKEMAP_NEXT_HINT",
	"view_equipment": "UI_COMMON_VIEW_EQUIP",
	"equip_hint_prefix": "UI_COMMON_KEY_E_BRACKET",
}

func _ready() -> void:
	_load_rogue_config_defaults()
	_load_rogue_data_from_db()
	_load_event_item_pool_from_db()

	Global.current_game_mode = Global.GameMode.ROGUE
	_refresh_rogue_bgm_state()

	_generate_map()

	pause_menu = PauseMenuScene.instantiate()
	pause_menu.hide()
	add_child(pause_menu)
	pause_menu.resume_game.connect(_on_resume_pressed)
	pause_menu.restart_game.connect(_on_restart_pressed)
	pause_menu.end_game.connect(_on_end_game_pressed)
	pause_menu.goto_options.connect(_on_options_pressed)
	pause_menu.goto_menu.connect(_on_menu_pressed)

	var relic_scene = load(Config.PATHS_SCENE_RELIC_SELECTION)
	if relic_scene:
		chest_ui = relic_scene.instantiate()
		chest_ui.hide()
		add_child(chest_ui)
		chest_ui.relic_selected.connect(_on_chest_selected)
		chest_ui.relic_skipped.connect(_on_chest_skipped)

	var shop_scene = load(Config.PATHS_SCENE_ROGUE_SHOP)
	if shop_scene:
		shop_ui = shop_scene.instantiate()
		shop_ui.hide()
		add_child(shop_ui)
		shop_ui.stat_purchased.connect(_on_shop_stat_purchased)
		shop_ui.equip_purchased.connect(_on_shop_equip_purchased)
		shop_ui.close_requested.connect(_close_shop)
		shop_ui.toggle_equipment_requested.connect(_toggle_equipment_ui)

	var tangram_scene = load(Config.PATHS_SCENE_TANGRAM_EQUIP)
	if tangram_scene:
		tangram_equipment = tangram_scene.instantiate()
	else:
		tangram_equipment = TangramEquipmentUI.new()

	var window = get_window()
	if window:
		window.focus_entered.connect(_on_window_focus_entered)
		window.focus_exited.connect(_on_window_focus_exited)
	tangram_equipment.hide()
	add_child(tangram_equipment)
	tangram_equipment.equipment_changed.connect(_on_tangram_equipment_changed)

	if defeat_screen:
		defeat_screen.return_to_menu.connect(_on_screen_return_to_menu)
	if victory_screen:
		victory_screen.return_to_menu.connect(_on_screen_return_to_menu)
	if rest_screen:
		rest_screen.rest_confirmed.connect(_on_rest_confirmed)

	_update_player_status_ui()
	_update_map_texts()
	_layout_map_ui()
	queue_redraw()

func _get_game_frame_rect() -> Rect2:
	var viewport_size = get_viewport_rect().size
	var frame_pos = (viewport_size - BASE_FRAME_SIZE) * 0.5
	return Rect2(frame_pos, BASE_FRAME_SIZE)

func _layout_map_ui() -> void:
	var frame = _get_game_frame_rect()
	if map_title_label:
		map_title_label.position = Vector2(frame.position.x + 320.0, frame.position.y + 30.0)
	if player_status_panel:
		player_status_panel.position = Vector2(frame.position.x + 20.0, frame.position.y + 85.0)
	if event_panel:
		event_panel.position = Vector2(frame.position.x + 236.0, frame.position.y + 78.0)
		event_panel.size = Vector2(frame.size.x - 244.0, frame.size.y - 86.0)

func _load_rogue_config_defaults() -> void:
	wave_configs.clear()
	wave_id_to_index.clear()
	shop_stat_base_prices.clear()
	shop_stat_values.clear()
	shop_equip_pool_data.clear()
	if not FileAccess.file_exists(ROGUE_CONFIG_PATH):
		return
	var file = FileAccess.open(ROGUE_CONFIG_PATH, FileAccess.READ)
	if not file:
		return
	var data = JSON.parse_string(file.get_as_text())
	if data is Dictionary:
		var loaded_waves = data.get("wave_configs", [])
		if loaded_waves is Array:
			wave_configs = loaded_waves
			for i in range(wave_configs.size()):
				var wave_id = String(wave_configs[i].get("id", ""))
				if not wave_id.is_empty():
					wave_id_to_index[wave_id] = i
		var base_prices = data.get("shop_stat_base_prices", {})
		if base_prices is Dictionary:
			shop_stat_base_prices = base_prices
		var stat_values = data.get("shop_stat_values", {})
		if stat_values is Dictionary:
			shop_stat_values = stat_values
		var equip_pool = data.get("shop_equip_pool", [])
		if equip_pool is Array:
			shop_equip_pool_data = equip_pool

func _load_rogue_data_from_db() -> void:
	var db = null
	if Engine.has_singleton("ResourceDB"):
		db = Engine.get_singleton("ResourceDB")
	if db == null:
		db = get_node_or_null("/root/ResourceDB")
	if db == null:
		return

	if db.has_method("get_enemies_by_kind"):
		var wave_rows: Array[Dictionary] = db.get_enemies_by_kind("wave")
		if not wave_rows.is_empty():
			wave_rows.sort_custom(func(a, b): return int(a.get("order", 0)) < int(b.get("order", 0)))
			var loaded_waves: Array = []
			var loaded_wave_id_map: Dictionary = {}
			for row in wave_rows:
				var wave_name = row.get("name", tr("UI_ROGUELIKEMAP_WAVE_FALLBACK"))
				var wave_id = row.get("id", "")
				var enemy_defs: Array = []
				for slot in row.get("enemies", []):
					var enemy_id = slot.get("enemy_id", "")
					var count = int(slot.get("count", 1))
					var base_enemy = db.get_enemy(enemy_id)
					if base_enemy.is_empty():
						continue
					for _i in range(max(1, count)):
						enemy_defs.append({
							"name": base_enemy.get("name", tr("UI_ROGUELIKEMAP_ENEMY_FALLBACK")),
							"health": int(base_enemy.get("health", 100)),
							"damage": int(base_enemy.get("damage", 10)),
							"cooldown_base": float(base_enemy.get("cooldown_base", 5.0)),
							"cooldown_variance": float(base_enemy.get("cooldown_variance", 0.4)),
							"gold_reward": int(base_enemy.get("gold_reward", 10)),
						})
				if not enemy_defs.is_empty():
					loaded_wave_id_map[wave_id] = loaded_waves.size()
					loaded_waves.append({"id": wave_id, "name": wave_name, "enemies": enemy_defs})
			if not loaded_waves.is_empty():
				wave_configs = loaded_waves
				wave_id_to_index = loaded_wave_id_map

	if db.has_method("get_items_by_kind"):
		var stat_rows: Array[Dictionary] = db.get_items_by_kind("shop_stat")
		if not stat_rows.is_empty():
			shop_stat_base_prices.clear()
			shop_stat_values.clear()
			for row in stat_rows:
				var stat_key = row.get("stat_key", "")
				if stat_key.is_empty():
					continue
				shop_stat_base_prices[stat_key] = int(row.get("base_price", 20))
				shop_stat_values[stat_key] = int(row.get("value", 0))

		var equip_rows: Array[Dictionary] = db.get_items_by_kind("shop_equip")
		if not equip_rows.is_empty():
			shop_equip_pool_data.clear()
			equip_rows.sort_custom(func(a, b): return int(a.get("order", 0)) < int(b.get("order", 0)))
			for row in equip_rows:
				shop_equip_pool_data.append({
					"id": row.get("equip_id", ""),
					"price": int(row.get("base_price", 50)),
					"type": int(row.get("equipment_type", -1)),
				})

func _load_event_item_pool_from_db() -> void:
	event_random_item_pool.clear()
	if not Engine.has_singleton("ResourceDB"):
		return
	var db = Engine.get_singleton("ResourceDB")
	if db and db.has_method("get_items_by_kind"):
		var rows: Array[Dictionary] = db.get_items_by_kind("event_reward")
		for row in rows:
			event_random_item_pool.append(row)

func _generate_map() -> void:
	map_nodes.clear()
	map_layers.clear()
	node_index.clear()
	map_edges.clear()
	selectable_next_ids.clear()
	selected_next_index = 0
	current_node_id = -1
	active_node_id = -1
	_next_node_id_seed = 0

	if USE_DEMO_ROGUE_MODE:
		_generate_demo_random_map()
	else:
		_generate_true_rogue_placeholder_map()

	if not map_layers.is_empty() and not map_layers[0].is_empty():
		current_node_id = int(map_layers[0][0])
		var start_node: Dictionary = node_index[current_node_id]
		start_node["completed"] = true
		_refresh_selectable_next_nodes()

func _generate_true_rogue_placeholder_map() -> void:
	# 正式Rogue模式占位：后续用独立状态机和内容池替换
	var start_id = _add_node(0, 0, {
		"type": NodeType.START,
		"name": "正式模式（开发中）",
		"name_en": "Rogue Mode (WIP)",
	})
	var boss_id = _add_node(1, 0, {
		"type": NodeType.BOSS,
		"name": "Boss",
		"name_en": "Boss",
		"wave_id": "wave_3_big_bat_swarm",
	})
	_connect_nodes(start_id, boss_id)

func _generate_demo_random_map() -> void:
	# 固定9段，节点数按需求限制：开始/结尾(Boss)单节点，中间段最多3（本实现最多2）
	# 段0: 开始
	var start_id = _add_node(0, 0, {
		"type": NodeType.START,
		"name_key": "node_start",
		"name": "起点",
		"name_en": "Start",
	})

	# 段1: 第一场战斗（固定单节点）
	var combat1_id = _add_node(1, 0, {
		"type": NodeType.COMBAT,
		"name": "第一场战斗",
		"name_en": "Battle I",
		"wave_id": "wave_1_slime_lord",
	})

	# 段2: 随机事件 + 宝箱（宝箱必定且仅一次）
	var seg2_templates: Array = [
		{
			"type": NodeType.EVENT,
			"name": "随机事件",
			"name_en": "Random Event",
			"event_id": _pick_random_event_id(),
		},
		{
			"type": NodeType.TREASURE_CHEST,
			"name": "宝箱",
			"name_en": "Treasure",
			"event_id": "event_treasure_chest",
		},
	]
	# 30%概率额外加一个节点（CHEST 50%／随机事件 50%）
	if randf() < 0.3:
		seg2_templates.append({
			"type": NodeType.EVENT,
			"name": "随机事件",
			"name_en": "Random Event",
			"event_id": _pick_random_event_id(),
		})
	seg2_templates.shuffle()
	var seg2_ids: Array[int] = []
	for i in range(seg2_templates.size()):
		seg2_ids.append(_add_node(2, i, seg2_templates[i]))

	# 段3: 商店（单节点）
	var shop_id = _add_node(3, 0, {
		"type": NodeType.SHOP,
		"name_key": "node_shop",
		"name": "商店",
		"name_en": "Shop",
	})

	# 段4: 第二次战斗（分支双节点）
	var combat_pool = [
		"wave_2_skeleton_duo",
		"wave_pool_blue_guard_pair",
		"wave_pool_ghost_soldier",
		"wave_pool_mage_trio",
	]
	combat_pool.shuffle()
	var combat2_ids: Array[int] = []
	for i in range(2):
		var wave_id = combat_pool[i]
		combat2_ids.append(_add_node(4, i, {
			"type": NodeType.COMBAT,
			"name": "第二场战斗",
			"name_en": "Battle II",
			"wave_id": wave_id,
		}))

	# 段5: 随机事件，随机2或3个节点
	var event5_count = 3 if randf() < 0.4 else 2
	var event5_ids: Array[int] = []
	for i in range(event5_count):
		event5_ids.append(_add_node(5, i, {
			"type": NodeType.EVENT,
			"name": "随机事件",
			"name_en": "Random Event",
			"event_id": _pick_random_event_id(),
		}))

	# 段6: 神秘人（单节点）
	var mystery_id = _add_node(6, 0, {
		"type": NodeType.EVENT,
		"name": "神秘人",
		"name_en": "Mysterious Stranger",
		"event_id": "event_mysterious_talk",
	})

	# 段7: 篝火（单节点）
	var rest_id = _add_node(7, 0, {
		"type": NodeType.REST,
		"name_key": "node_rest",
		"name": "篝火",
		"name_en": "Campfire",
	})

	# 段8: Boss（单节点）
	var boss_id = _add_node(8, 0, {
		"type": NodeType.BOSS,
		"name_key": "node_vampire",
		"name": "结束Boss战",
		"name_en": "Final Boss",
		"wave_id": "wave_3_big_bat_swarm",
	})

	# 分层连接：所有节点可达、无同层连接、无交叉
	_connect_nodes(start_id, combat1_id)
	_connect_all_non_crossing([combat1_id], seg2_ids)
	_connect_all_non_crossing(seg2_ids, [shop_id])
	_connect_all_non_crossing([shop_id], combat2_ids)
	_connect_all_non_crossing(combat2_ids, event5_ids)
	_connect_all_non_crossing(event5_ids, [mystery_id])
	_connect_nodes(mystery_id, rest_id)
	_connect_nodes(rest_id, boss_id)

func _pick_random_event_id() -> String:
	var pool = ["event_blood_item", "event_gold_exchange", "event_bet_duel"]
	return pool[randi() % pool.size()]

func _add_node(layer: int, slot: int, data: Dictionary) -> int:
	var node_id = _next_node_id_seed
	_next_node_id_seed += 1
	while map_layers.size() <= layer:
		map_layers.append([])
	var node: Dictionary = {
		"id": node_id,
		"layer": layer,
		"slot": slot,
		"type": int(data.get("type", NodeType.EVENT)),
		"name_key": String(data.get("name_key", "")),
		"name": String(data.get("name", "")),
		"name_en": String(data.get("name_en", "")),
		"wave_id": String(data.get("wave_id", "")),
		"event_id": String(data.get("event_id", "")),
		"completed": false,
		"offset": _random_node_offset(),
	}
	map_nodes.append(node)
	node_index[node_id] = node
	map_layers[layer].append(node_id)
	map_edges[node_id] = []
	return node_id

func _connect_nodes(from_id: int, to_id: int) -> void:
	if not map_edges.has(from_id):
		map_edges[from_id] = []
	var arr: Array = map_edges[from_id]
	if not arr.has(to_id):
		arr.append(to_id)
	map_edges[from_id] = arr

func _connect_all_non_crossing(prev_ids: Array, next_ids: Array) -> void:
	var prev_size = prev_ids.size()
	var next_size = next_ids.size()
	if prev_size == 0 or next_size == 0:
		return
	if prev_size == 1:
		for nid in next_ids:
			_connect_nodes(int(prev_ids[0]), int(nid))
		return
	if next_size == 1:
		for pid in prev_ids:
			_connect_nodes(int(pid), int(next_ids[0]))
		return
	# 多对多情况：确保每个节点都有连接，避免孤立节点
	# 使用 min(i, size-1) 替代 i%size，保证连线不交叉（单调映射）
	if prev_size <= next_size:
		for i in range(next_size):
			var prev_idx = min(i, prev_size - 1)
			_connect_nodes(int(prev_ids[prev_idx]), int(next_ids[i]))
	else:
		for i in range(prev_size):
			var next_idx = min(i, next_size - 1)
			_connect_nodes(int(prev_ids[i]), int(next_ids[next_idx]))

func _random_node_offset() -> Vector2:
	return Vector2(randf_range(-20.0, 20.0), randf_range(-14.0, 14.0))

func _refresh_selectable_next_nodes() -> void:
	selectable_next_ids.clear()
	selected_next_index = 0
	if current_node_id < 0:
		return
	var outgoing: Array = map_edges.get(current_node_id, [])
	for nid in outgoing:
		selectable_next_ids.append(int(nid))

func _process(delta: float) -> void:
	if map_input_lock_timer > 0:
		map_input_lock_timer = max(map_input_lock_timer - delta, 0.0)

func _t(key: String) -> String:
	var translation_key = TEXT_KEYS.get(key, "")
	if translation_key == "":
		return key
	return tr(translation_key)

func _get_node_icon(node_type: int) -> String:
	if node_type == NodeType.EVENT:
		return "?"
	var translation_key = NODE_ICON_KEYS.get(node_type, "")
	if translation_key == "":
		return "?"
	return tr(translation_key)

func _get_node_display_name(node: Dictionary) -> String:
	var key = String(node.get("name_key", ""))
	if key != "":
		return _node_name_by_key(key)
	if Global.current_language == "en" and not String(node.get("name_en", "")).is_empty():
		return String(node.get("name_en", ""))
	return String(node.get("name", ""))

func _node_name_by_key(key: String) -> String:
	match key:
		"node_start":
			return tr("UI_ROGUELIKEMAP_NODE_START")
		"node_shop":
			return tr("UI_ROGUELIKEMAP_NODE_SHOP")
		"node_rest":
			return tr("UI_ROGUELIKEMAP_NODE_REST")
		"node_vampire":
			return tr("UI_ROGUELIKEMAP_NODE_VAMPIRE")
	return key

func _draw() -> void:
	if current_state == GameState.MAP:
		var viewport_size = get_viewport_rect().size
		draw_rect(Rect2(Vector2.ZERO, viewport_size), Color(0.08, 0.06, 0.12), true)
		_draw_map_graph()

func _draw_map_graph() -> void:
	for from_id in map_edges.keys():
		var from_node: Dictionary = node_index.get(int(from_id), {})
		if from_node.is_empty():
			continue
		var from_center = _get_node_center(from_node)
		for to_id in map_edges[from_id]:
			var to_node: Dictionary = node_index.get(int(to_id), {})
			if to_node.is_empty():
				continue
			var to_center = _get_node_center(to_node)
			var line_color = Color(0.4, 0.4, 0.4)
			# 只有起止两端节点都已走过才变绿，避免未选分支也变绿
			if bool(from_node.get("completed", false)) and bool(to_node.get("completed", false)):
				line_color = Color(0.3, 0.8, 0.3)
			draw_line(from_center, to_center, line_color, 3.0)

	for node in map_nodes:
		_draw_single_node(node)

	_draw_map_scrollbar()

func _compute_max_scroll() -> float:
	if map_layers.is_empty():
		return 0.0
	var frame = _get_game_frame_rect()
	var total_width = 60.0 + float(map_layers.size() - 1) * LAYER_SPACING + NODE_SIZE
	return max(0.0, total_width - (frame.size.x - 30.0))

func _scroll_map(delta: float) -> void:
	var max_scroll = _compute_max_scroll()
	map_scroll_offset = clamp(map_scroll_offset + delta, 0.0, max_scroll)
	queue_redraw()

func _handle_scrollbar_drag(mouse_pos: Vector2) -> void:
	var max_scroll = _compute_max_scroll()
	if max_scroll <= 0.0:
		_scrollbar_dragging = false
		return
	var bar_x = _scrollbar_track_rect.position.x
	var bar_w = _scrollbar_track_rect.size.x
	var thumb_w = _scrollbar_thumb_rect.size.x
	var travel = bar_w - thumb_w
	if travel <= 0.0:
		return
	var new_thumb_x = mouse_pos.x - _scrollbar_drag_offset_x
	var ratio = clamp((new_thumb_x - bar_x) / travel, 0.0, 1.0)
	map_scroll_offset = ratio * max_scroll
	queue_redraw()

func _draw_map_scrollbar() -> void:
	var frame = _get_game_frame_rect()
	var max_scroll = _compute_max_scroll()
	if max_scroll <= 0.0:
		return
	var bar_x = frame.position.x + 10.0
	var bar_y = frame.position.y + frame.size.y - 22.0
	var bar_w = frame.size.x - 20.0
	var bar_h = 10.0
	draw_rect(Rect2(bar_x, bar_y, bar_w, bar_h), Color(0.18, 0.18, 0.25), true)
	draw_rect(Rect2(bar_x, bar_y, bar_w, bar_h), Color(0.4, 0.4, 0.55), false, 1)
	var total_w = 60.0 + float(map_layers.size() - 1) * LAYER_SPACING + NODE_SIZE
	var thumb_ratio = (frame.size.x - 30.0) / total_w
	var thumb_w = max(18.0, bar_w * thumb_ratio)
	var thumb_x = bar_x + (bar_w - thumb_w) * (map_scroll_offset / max_scroll)
	var thumb_color = Color(0.75, 0.75, 0.95) if _scrollbar_dragging else Color(0.55, 0.55, 0.78)
	draw_rect(Rect2(thumb_x, bar_y + 2.0, thumb_w, bar_h - 4.0), thumb_color, true)
	_scrollbar_track_rect = Rect2(bar_x, bar_y, bar_w, bar_h)
	_scrollbar_thumb_rect = Rect2(thumb_x, bar_y + 2.0, thumb_w, bar_h - 4.0)
	draw_string(UI_FONT, Vector2(bar_x, bar_y - 2.0), tr("UI_MAP_SCROLL_HINT"),
		HORIZONTAL_ALIGNMENT_LEFT, bar_w, UITheme.FONT_SIZE_XS, Color(0.5, 0.5, 0.7, 0.7))

func _get_node_center(node: Dictionary) -> Vector2:
	var frame = _get_game_frame_rect()
	var layer = int(node.get("layer", 0))
	var slot = int(node.get("slot", 0))
	var layer_nodes: Array = []
	if layer >= 0 and layer < map_layers.size():
		layer_nodes = map_layers[layer]
	var count = max(1, layer_nodes.size())
	var x = frame.position.x + 60.0 + float(layer) * LAYER_SPACING - map_scroll_offset
	var center_y = frame.position.y + MAP_CENTER_Y
	var y = center_y
	match count:
		1:
			y = center_y
		2:
			y = center_y + (-0.5 + float(slot)) * ROW_SPACING
		3:
			y = center_y + (-1.0 + float(slot)) * (ROW_SPACING * 0.8)
		_:
			y = center_y + (float(slot) - float(count - 1) / 2.0) * 52.0
	return Vector2(x, y) + node.get("offset", Vector2.ZERO)

func _draw_single_node(node: Dictionary) -> void:
	var node_id = int(node.get("id", -1))
	var center = _get_node_center(node)
	var pos = center - Vector2(NODE_SIZE * 0.5, NODE_SIZE * 0.5)
	var node_type = int(node.get("type", NodeType.EVENT))
	var is_current = (node_id == current_node_id)
	var is_completed = bool(node.get("completed", false))
	var is_selectable = selectable_next_ids.has(node_id)
	var is_selected = is_selectable and selectable_next_ids[selected_next_index] == node_id

	var bg_color = NODE_COLORS.get(node_type, Color.GRAY)
	if is_completed:
		bg_color = bg_color.darkened(0.5)
	elif is_selectable:
		bg_color = bg_color.lightened(0.15)

	if is_selected:
		var glow_rect = Rect2(pos - Vector2(5, 5), Vector2(NODE_SIZE + 10, NODE_SIZE + 10))
		draw_rect(glow_rect, Color(bg_color.r, bg_color.g, bg_color.b, 0.35), true)

	draw_rect(Rect2(pos, Vector2(NODE_SIZE, NODE_SIZE)), bg_color, true)

	var border_color = UITheme.BORDER_MEDIUM
	var border_width = UITheme.BORDER_THIN
	if is_current:
		border_color = UITheme.ACCENT_SUCCESS
		border_width = UITheme.BORDER_THICK
	elif is_selected:
		border_color = UITheme.ACCENT_SECONDARY
		border_width = UITheme.BORDER_THICK
	draw_rect(Rect2(pos, Vector2(NODE_SIZE, NODE_SIZE)), border_color, false, border_width)

	# 图片接口：有贴图则绘制，否则绘制图标文字
	var node_texture = NODE_TEXTURES.get(node_type, null)
	if node_texture != null:
		draw_texture_rect(node_texture, Rect2(pos + Vector2(4, 4), Vector2(NODE_SIZE - 8, NODE_SIZE - 8)), false)
	else:
		# 宝箱节点使用特殊图标
		var event_id_str = String(node.get("event_id", ""))
		var icon: String = _get_node_icon(node_type)
		draw_string(UI_FONT, pos + Vector2(0, NODE_SIZE * 0.5 + 8), icon,
			HORIZONTAL_ALIGNMENT_CENTER, int(NODE_SIZE), UITheme.FONT_SIZE_LG, UITheme.TEXT_PRIMARY)

	# 移除所有节点描述，不显示节点下方标签

	if is_selected:
		draw_string(UI_FONT, pos + Vector2(NODE_SIZE * 0.5 - 12, -10), _t("next_hint"),
			HORIZONTAL_ALIGNMENT_CENTER, 24, UITheme.FONT_SIZE_MD, UITheme.ACCENT_SECONDARY)

func _input(event: InputEvent) -> void:
	# 滚动条鼠标拖动（在 is_pressed 过滤前处理 motion 和 release）
	if current_state == GameState.MAP and not (pause_menu and pause_menu.visible):
		if event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			if _scrollbar_dragging:
				_scrollbar_dragging = false
				queue_redraw()
				get_viewport().set_input_as_handled()
				return
		if event is InputEventMouseMotion and _scrollbar_dragging:
			_handle_scrollbar_drag(event.position)
			get_viewport().set_input_as_handled()
			return

	if not event.is_pressed():
		return

	if pause_menu and pause_menu.visible:
		if event.is_action_pressed("ui_cancel"):
			_toggle_pause()
		return

	if current_state == GameState.MAP:
		_handle_map_input(event)

func _handle_map_input(event: InputEvent) -> void:
	if map_input_lock_timer > 0:
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_cancel"):
		_toggle_pause()
		get_viewport().set_input_as_handled()
		return
	# A/D 键水平滚动地图
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_A:
			_scroll_map(-MAP_SCROLL_STEP)
			get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_D:
			_scroll_map(MAP_SCROLL_STEP)
			get_viewport().set_input_as_handled()
			return
	# 鼠标滚轮水平滚动地图
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_scroll_map(MAP_SCROLL_STEP)
			get_viewport().set_input_as_handled()
			return
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_scroll_map(-MAP_SCROLL_STEP)
			get_viewport().set_input_as_handled()
			return
		# 鼠标左键点击/按下滚动条区域（开始拖动）
		if event.button_index == MOUSE_BUTTON_LEFT and _scrollbar_track_rect.size.x > 0:
			if _scrollbar_track_rect.has_point(event.position):
				_scrollbar_dragging = true
				_scrollbar_drag_offset_x = event.position.x - _scrollbar_thumb_rect.position.x
				_scrollbar_drag_offset_x = clamp(_scrollbar_drag_offset_x, 0.0, _scrollbar_thumb_rect.size.x)
				queue_redraw()
				get_viewport().set_input_as_handled()
				return
	if event.is_action_pressed("ui_left") or event.is_action_pressed("ui_up"):
		_cycle_next_selection(-1)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_right") or event.is_action_pressed("ui_down"):
		_cycle_next_selection(1)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_accept"):
		_enter_selected_next_node()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.keycode == KEY_E:
		_toggle_equipment_ui()
		get_viewport().set_input_as_handled()

func _cycle_next_selection(step: int) -> void:
	if selectable_next_ids.is_empty():
		return
	selected_next_index = (selected_next_index + step) % selectable_next_ids.size()
	if selected_next_index < 0:
		selected_next_index += selectable_next_ids.size()
	queue_redraw()

func _enter_selected_next_node() -> void:
	if selectable_next_ids.is_empty():
		return
	if map_input_lock_timer > 0:
		return
	_lock_map_input(0.5)
	var target_node_id = selectable_next_ids[selected_next_index]
	_activate_node(target_node_id)

func _activate_node(node_id: int) -> void:
	var node: Dictionary = node_index.get(node_id, {})
	if node.is_empty():
		return
	active_node_id = node_id
	var node_type = int(node.get("type", NodeType.EVENT))
	match node_type:
		NodeType.COMBAT, NodeType.BOSS:
			_start_combat_from_node(node)
		NodeType.REST:
			_change_state(GameState.REST)
		NodeType.SHOP:
			_open_shop()
		NodeType.EVENT, NodeType.TREASURE_CHEST:
			_run_event_node(node)
		_:
			_complete_active_node_and_return_map()

func _start_combat_from_node(node: Dictionary) -> void:
	var wave_id = String(node.get("wave_id", ""))
	var wave = _get_wave_by_id(wave_id)
	if wave.is_empty() and not wave_configs.is_empty():
		wave = wave_configs[0]
	_start_combat_with_wave(wave)

func _get_wave_by_id(wave_id: String) -> Dictionary:
	if wave_id_to_index.has(wave_id):
		var idx = int(wave_id_to_index[wave_id])
		if idx >= 0 and idx < wave_configs.size():
			return wave_configs[idx]
	return {}

func _start_combat_with_wave(wave: Dictionary) -> void:
	var combat_scene_resource = load("res://UI/RoguelikeCombat.tscn")
	if not combat_scene_resource:
		print(tr("LOG_ROGUE_BATTLE_SCENE_MISSING"))
		_complete_active_node_and_return_map()
		return

	combat_scene = combat_scene_resource.instantiate()
	add_child(combat_scene)
	combat_scene.player_health = player_health
	combat_scene.player_max_health = player_max_health
	combat_scene.player_gold = player_gold

	var atk_bonus = _get_shop_atk_bonus()
	if atk_bonus > 0:
		combat_scene.player_attack_power += atk_bonus
	var def_bonus = _get_shop_def_bonus()
	if def_bonus > 0:
		combat_scene.shop_def_bonus = def_bonus

	combat_scene.setup_wave(wave)
	if combat_scene.has_method("apply_relics"):
		var equipped_types = tangram_equipment.get_equipped_types() if tangram_equipment else []
		combat_scene.apply_relics(equipped_types)

	combat_scene.battle_ended.connect(_on_combat_ended)
	combat_scene.quit_to_menu.connect(_on_combat_quit_to_menu)
	_change_state(GameState.COMBAT)

func _on_combat_ended(victory: bool) -> void:
	if combat_scene:
		player_health = combat_scene.player_health
		player_gold = combat_scene.player_gold
		total_lines_cleared += combat_scene.total_lines_cleared
		remove_child(combat_scene)
		combat_scene.queue_free()
		combat_scene = null

	if victory:
		var active_node: Dictionary = node_index.get(active_node_id, {})
		var active_type = int(active_node.get("type", -1))
		if active_type == NodeType.BOSS:
			_complete_active_node()
			_rogue_is_true_victory = true
			_change_state(GameState.VICTORY)
		else:
			_complete_active_node_and_return_map()
	else:
		_change_state(GameState.DEFEAT)

func _on_combat_quit_to_menu() -> void:
	if combat_scene:
		player_health = combat_scene.player_health
		player_gold = combat_scene.player_gold
		total_lines_cleared += combat_scene.total_lines_cleared
		remove_child(combat_scene)
		combat_scene.queue_free()
		combat_scene = null
	_change_state(GameState.VICTORY)

func _on_chest_selected(relic_type: int) -> void:
	if chest_ui:
		chest_ui.hide()
	collected_relics.append(relic_type)
	var equip_id = TangramEquipmentUI.equipment_type_to_id(relic_type)
	if not equip_id.is_empty() and tangram_equipment:
		var placed = tangram_equipment.auto_place_equipment(equip_id)
		if placed:
			print(tr("LOG_ROGUE_EQUIP_AUTO_PLACED") % [equip_id, relic_type])
		else:
			if not tangram_equipment.inventory.has(equip_id) and not tangram_equipment.has_equipment(equip_id):
				tangram_equipment.inventory.append(equip_id)
			print(tr("LOG_ROGUE_EQUIP_GRID_FULL") % [equip_id])
	else:
		print(tr("LOG_ROGUE_EQUIP_ID_EMPTY") % [relic_type])
	_complete_active_node_and_return_map()

func _on_chest_skipped() -> void:
	print(tr("LOG_ROGUE_SKIP_EQUIP"))
	_complete_active_node_and_return_map()

func _on_tangram_equipment_changed(equipped_list: Array) -> void:
	tangram_equipped_list = equipped_list
	print(tr("LOG_ROGUE_EQUIP_CHANGED") % [str(equipped_list)])
	_update_player_status_ui()

func _on_rest_confirmed() -> void:
	_complete_rest()

func _complete_rest() -> void:
	player_health = player_max_health
	print(tr("LOG_ROGUE_REST_HEAL") % [player_health, player_max_health])
	_complete_active_node_and_return_map()

func _complete_active_node() -> void:
	if active_node_id < 0:
		return
	var active_node: Dictionary = node_index.get(active_node_id, {})
	if not active_node.is_empty():
		active_node["completed"] = true
		current_node_id = active_node_id
	active_node_id = -1

func _complete_active_node_and_return_map() -> void:
	_complete_active_node()
	_change_state(GameState.MAP)
	_refresh_selectable_next_nodes()
	_update_player_status_ui()
	_lock_map_input()

func _lock_map_input(duration: float = 0.5) -> void:
	map_input_lock_timer = max(map_input_lock_timer, duration)

func _run_event_node(node: Dictionary) -> void:
	var event_id = String(node.get("event_id", "event_mysterious_talk"))
	current_event_data = {
		"event_id": event_id,
	}
	match event_id:
		"event_treasure_chest":
			_show_chest_event()
		"event_blood_item":
			_show_blood_item_event()
		"event_gold_exchange":
			_show_gold_exchange_event()
		"event_bet_duel":
			_show_bet_duel_event()
		"event_mysterious_talk":
			_show_mysterious_talk_event()
		_:
			_show_mysterious_talk_event()

func _show_event(title: String, desc: String, options: Array[Dictionary]) -> void:
	event_title_label.text = title
	event_desc_label.text = desc
	for child in event_buttons_row.get_children():
		child.queue_free()
	for option in options:
		var btn = Button.new()
		btn.text = String(option.get("text", tr("UI_COMMON_CONTINUE")))
		btn.add_theme_font_override("font", UI_FONT)
		btn.add_theme_font_size_override("font_size", UITheme.FONT_SIZE_SM)
		btn.add_theme_stylebox_override("normal", UITheme.create_button_style_normal())
		btn.add_theme_stylebox_override("hover", UITheme.create_button_style_hover())
		btn.add_theme_stylebox_override("pressed", UITheme.create_button_style_hover())
		btn.add_theme_color_override("font_color", UITheme.TEXT_PRIMARY)
		btn.add_theme_color_override("font_hover_color", UITheme.ACCENT_SECONDARY)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size = Vector2(0.0, 46.0)
		btn.pressed.connect(_on_event_option_pressed.bind(String(option.get("action", "event_continue"))))
		event_buttons_row.add_child(btn)
	event_panel.show()
	_change_state(GameState.EVENT)

func _on_event_option_pressed(action: String) -> void:
	match action:
		"event_continue":
			event_panel.hide()
			_complete_active_node_and_return_map()
		"blood_accept":
			_resolve_blood_item_accept()
		"blood_skip":
			current_event_data.erase("blood_chance")
			_show_event(
				tr("UI_EVENT_ALTAR_TITLE"),
				tr("UI_EVENT_ALTAR_SKIP_RESULT"),
				[{"text": tr("UI_COMMON_CONTINUE"), "action": "event_continue"}]
			)
		"gold_hp":
			_resolve_gold_choice("hp")
		"gold_key":
			_resolve_gold_choice("key")
		"gold_skip":
			event_panel.hide()
			_complete_active_node_and_return_map()
		"bet_ghost":
			_resolve_bet_duel("ghost")
		"bet_mage":
			_resolve_bet_duel("mage")
		"bet_fight":
			event_panel.hide()
			_change_state(GameState.COMBAT)
			var wave_id = String(current_event_data.get("bet_loser_wave", "wave_event_bet_ghost"))
			_start_combat_with_wave(_get_wave_by_id(wave_id))

func _show_chest_event() -> void:
	if chest_ui:
		chest_ui.show_single_relic()
		_change_state(GameState.EVENT)

func _show_blood_item_event() -> void:
	if not current_event_data.has("blood_chance"):
		current_event_data["blood_chance"] = 25
	var cost = max(1, int(float(player_health) * 0.1))
	var chance = int(current_event_data["blood_chance"])
	current_event_data["blood_cost"] = cost
	_show_event(
		tr("UI_EVENT_ALTAR_TITLE"),
		tr("UI_EVENT_ALTAR_DESC") % [cost],
		[
			{"text": tr("UI_EVENT_ALTAR_BTN_SACRIFICE"), "action": "blood_accept"},
			{"text": tr("UI_EVENT_ALTAR_BTN_SKIP"), "action": "blood_skip"},
		]
	)

func _resolve_blood_item_accept() -> void:
	var cost = int(current_event_data.get("blood_cost", max(1, int(float(player_health) * 0.1))))
	var chance = int(current_event_data.get("blood_chance", 25))
	player_health = max(1, player_health - cost)
	_update_player_status_ui()
	if randf() * 100.0 < float(chance):
		current_event_data.erase("blood_chance")
		var result_text = _grant_random_equipment_from_pool()
		_show_event(
			tr("UI_EVENT_ALTAR_TITLE"),
			tr("UI_EVENT_ALTAR_SUCCESS") % [result_text],
			[{"text": tr("UI_COMMON_CONTINUE"), "action": "event_continue"}]
		)
	else:
		var new_chance = min(100, chance + 17)
		current_event_data["blood_chance"] = new_chance
		var new_cost = max(1, int(float(player_health) * 0.1))
		current_event_data["blood_cost"] = new_cost
		_show_event(
			tr("UI_EVENT_ALTAR_TITLE"),
			tr("UI_EVENT_ALTAR_FAIL"),
			[
				{"text": tr("UI_EVENT_ALTAR_BTN_TRY_AGAIN"), "action": "blood_accept"},
				{"text": tr("UI_EVENT_ALTAR_BTN_SKIP"), "action": "blood_skip"},
			]
		)

func _grant_random_equipment_from_pool() -> String:
	var pool = shop_equip_pool_data.duplicate()
	if pool.is_empty():
		return tr("UI_EVENT_EQUIP_NONE")
	pool.shuffle()
	var equip = pool[0]
	var equip_id = String(equip.get("id", ""))
	var equip_type = int(equip.get("type", -1))
	if not equip_id.is_empty() and equip_type >= 0:
		collected_relics.append(equip_type)
		if tangram_equipment:
			tangram_equipment.auto_place_equipment(equip_id)
	var display_name = _get_equip_display_name(equip_id)
	return display_name

func _show_gold_exchange_event() -> void:
	var cost = 20
	var heal_amount = randi_range(int(float(player_max_health) * 0.09), int(float(player_max_health) * 0.12))
	current_event_data["gold_cost"] = cost
	current_event_data["gold_heal_amount"] = heal_amount
	_show_event(
		tr("UI_EVENT_MERCHANT_TITLE"),
		tr("UI_EVENT_MERCHANT_DESC") % [cost],
		[
			{"text": tr("UI_EVENT_MERCHANT_BTN_HEAL") % [heal_amount], "action": "gold_hp"},
			{"text": tr("UI_EVENT_MERCHANT_BTN_KEY"), "action": "gold_key"},
			{"text": tr("UI_EVENT_MERCHANT_BTN_SKIP"), "action": "gold_skip"},
		]
	)

func _resolve_gold_choice(choice: String) -> void:
	var cost = int(current_event_data.get("gold_cost", 20))
	if player_gold < cost:
		_show_event(
			tr("UI_EVENT_MERCHANT_TITLE"),
			tr("UI_EVENT_MERCHANT_BROKE"),
			[{"text": tr("UI_COMMON_CONTINUE"), "action": "event_continue"}]
		)
		return

	player_gold -= cost
	match choice:
		"hp":
			var heal = int(current_event_data.get("gold_heal_amount", 10))
			player_health = min(player_health + heal, player_max_health)
			_show_event(
				tr("UI_EVENT_MERCHANT_TITLE"),
				tr("UI_EVENT_MERCHANT_HEAL_DONE") % [heal],
				[{"text": tr("UI_COMMON_CONTINUE"), "action": "event_continue"}]
			)
		"key":
			_add_event_item_count("event_item_yellow_key", 1)
			_show_event(
				tr("UI_EVENT_MERCHANT_TITLE"),
				tr("UI_EVENT_MERCHANT_KEY_DONE"),
				[{"text": tr("UI_COMMON_CONTINUE"), "action": "event_continue"}]
			)

	_update_player_status_ui()

func _show_bet_duel_event() -> void:
	_show_event(
		tr("UI_EVENT_BET_TITLE"),
		tr("UI_EVENT_BET_DESC"),
		[
			{"text": tr("UI_EVENT_BET_BTN_GHOST"), "action": "bet_ghost"},
			{"text": tr("UI_EVENT_BET_BTN_MAGE"), "action": "bet_mage"},
		]
	)

func _resolve_bet_duel(player_bet: String) -> void:
	var winner = "ghost" if randf() <= 0.85 else "mage"
	if player_bet == winner:
		var gain = 0
		if winner == "ghost":
			gain = randi_range(6, 11)
		else:
			gain = randi_range(20, 28)
		player_gold += gain
		_show_event(
			tr("UI_EVENT_BET_TITLE"),
			tr("UI_EVENT_BET_WIN") % [gain],
			[{"text": tr("UI_COMMON_CONTINUE"), "action": "event_continue"}]
		)
		_update_player_status_ui()
		return

	# 押错：先显示败北提示，再进入战斗
	var winner_name = tr("UI_EVENT_BET_BTN_GHOST") if winner == "ghost" else tr("UI_EVENT_BET_BTN_MAGE")
	current_event_data["bet_loser_wave"] = "wave_event_bet_ghost" if winner == "ghost" else "wave_event_bet_mage"
	_show_event(
		tr("UI_EVENT_BET_TITLE"),
		tr("UI_EVENT_BET_LOSS") % [winner_name],
		[{"text": tr("UI_COMMON_CONTINUE"), "action": "bet_fight"}]
	)

func _show_mysterious_talk_event() -> void:
	_show_event(
		tr("UI_EVENT_MYSTERY_TITLE"),
		tr("UI_EVENT_MYSTERY_DESC"),
		[{"text": tr("UI_COMMON_CONTINUE"), "action": "event_continue"}]
	)

func _grant_random_event_item(count: int) -> String:
	if event_random_item_pool.is_empty():
		_add_event_item_count("event_item_yellow_key", count)
		return tr("UI_EVENT_ITEM_KEY") % [count]
	var item: Dictionary = event_random_item_pool[randi() % event_random_item_pool.size()]
	var item_id = String(item.get("id", "event_item_yellow_key"))
	var name = String(item.get("name", item_id))
	_add_event_item_count(item_id, count)
	if int(item.get("hp_bonus", 0)) != 0:
		player_health = min(player_max_health, player_health + int(item.get("hp_bonus", 0)) * count)
	if int(item.get("gold_bonus", 0)) != 0:
		player_gold += int(item.get("gold_bonus", 0)) * count
	_update_player_status_ui()
	return "%s x%d" % [name, count]

func _add_event_item_count(item_id: String, amount: int) -> void:
	event_item_counts[item_id] = int(event_item_counts.get(item_id, 0)) + amount

func _change_state(new_state: int) -> void:
	current_state = new_state

	var show_map = (new_state == GameState.MAP)
	var show_shop = (new_state == GameState.SHOP)
	var show_event = (new_state == GameState.EVENT)
	if map_title_label:
		map_title_label.visible = show_map
	if player_status_panel:
		player_status_panel.visible = show_map or show_shop or show_event
	if hint_label:
		hint_label.visible = show_map
	if credit_label:
		credit_label.visible = show_map
	if shop_ui:
		shop_ui.visible = show_shop
	if event_panel:
		event_panel.visible = show_event

	if defeat_screen:
		defeat_screen.hide()
	if victory_screen:
		victory_screen.hide()
	if rest_screen:
		rest_screen.hide()

	match new_state:
		GameState.DEFEAT:
			if victory_screen:
				move_child(victory_screen, -1)
				victory_screen.show_screen(total_lines_cleared, collected_relics.size(), player_gold, false)
		GameState.VICTORY:
			var is_true_win = _rogue_is_true_victory
			_rogue_is_true_victory = false
			if victory_screen:
				move_child(victory_screen, -1)
				victory_screen.show_screen(total_lines_cleared, collected_relics.size(), player_gold, is_true_win)
		GameState.REST:
			if rest_screen:
				move_child(rest_screen, -1)
				rest_screen.show_screen(player_health, player_max_health)
		GameState.MAP:
			_update_player_status_ui()
			_update_map_texts()

	queue_redraw()

func _update_player_status_ui() -> void:
	if hp_bar:
		hp_bar.value = float(player_health) / float(player_max_health) * 100.0
	if hp_label:
		hp_label.text = tr("UI_ROGUELIKEMAP_HP_NUM_OR_NUM") % [player_health, player_max_health]
	var equip_count = tangram_equipped_list.size() if tangram_equipped_list else 0
	if equip_label:
		equip_label.text = tr("UI_ROGUELIKEMAP_VAR_NUM") % [_t("equipment"), equip_count]
	if lines_label:
		var gold_label_text = tr("UI_ROGUELIKE_MAP_GOLD")
		lines_label.text = tr("UI_ROGUELIKEMAP_VAR_NUM_VAR_NUM") % [_t("lines"), total_lines_cleared, gold_label_text, player_gold]

func _update_map_texts() -> void:
	if map_title_label:
		map_title_label.text = _t("map_title")
	if status_title_label:
		status_title_label.text = _t("player_status")
	if hint_label:
		hint_label.text = "方向键选择路径  Enter确认  ESC暂停"
	if equip_hint_label:
		equip_hint_label.text = tr(TEXT_KEYS["equip_hint_prefix"]) + _t("view_equipment")

func _on_screen_return_to_menu() -> void:
	get_tree().change_scene_to_file(Config.PATHS_SCENE_MAIN_MENU)

func _toggle_pause() -> void:
	is_paused = !is_paused
	if pause_menu:
		if is_paused:
			pause_menu.show_menu()
			pause_menu.update_ui_texts()
		else:
			pause_menu.hide()

func _toggle_equipment_ui() -> void:
	if tangram_equipment:
		if tangram_equipment.visible:
			tangram_equipment.hide_ui()
		else:
			tangram_equipment.show_ui()

func _on_resume_pressed() -> void:
	_toggle_pause()

func _on_restart_pressed() -> void:
	get_tree().reload_current_scene()

func _on_end_game_pressed() -> void:
	if pause_menu:
		pause_menu.hide()
	is_paused = false
	_change_state(GameState.VICTORY)

func _on_options_pressed() -> void:
	if pause_menu:
		pause_menu.hide()
	var options_scene = load(Config.PATHS_SCENE_OPTIONS_MENU)
	if options_scene:
		var options_instance = options_scene.instantiate()
		options_instance.set_meta("from_game", true)
		options_instance.tree_exited.connect(_on_options_closed)
		get_tree().root.add_child(options_instance)

func _on_options_closed() -> void:
	if is_paused and pause_menu:
		pause_menu.show_menu()
		pause_menu.update_ui_texts()

func _on_menu_pressed() -> void:
	get_tree().change_scene_to_file(Config.PATHS_SCENE_MAIN_MENU)

# ===== 商店系统 =====

func _open_shop() -> void:
	shop_hp_free_available = true
	shop_first_item_free = true
	_init_shop_items()
	_change_state(GameState.SHOP)
	if shop_ui:
		shop_ui.show()
	_refresh_shop_ui()

func _get_equip_display_name(equip_id: String) -> String:
	var lang = Global.current_language
	if tangram_equipment:
		var texts = TangramEquipmentUI.TEXTS.get(lang, TangramEquipmentUI.TEXTS["zh"])
		if texts.has(equip_id):
			return texts[equip_id]
	match equip_id:
		"iron_sword": return tr("UI_RELICSELECTIONUI_IRON_SWORD")
		"iron_shield": return tr("UI_RELICSELECTIONUI_IRON_SHIELD")
		"downclock_software": return tr("UI_ROGUELIKEMAP_DOWNCLOCK")
		"faulty_score_amplifier": return tr("UI_ROGUELIKEMAP_FAULTY_AMP")
		"rift_meter": return tr("UI_RELICSELECTIONUI_RIFT_METER")
	return equip_id

func _init_shop_items() -> void:
	shop_stat_items.clear()
	shop_equip_items.clear()

	for stat_key in ["hp", "max_hp", "atk", "def"]:
		var base_price = shop_stat_base_prices.get(stat_key, 20)
		var price = _roll_price(base_price)
		var free = false
		if stat_key == "hp" and shop_hp_free_available:
			price = 0
			free = true
			print(tr("LOG_ROGUE_SHOP_HP_FREE_AVAILABLE"))
		shop_stat_items[stat_key] = {"price": price, "free": free}

	var available_equips = []
	for equip_info in shop_equip_pool_data:
		var equip_id = equip_info["id"]
		var already_owned = false
		if tangram_equipment:
			for owned_id in tangram_equipment.get_equipped_types():
				var owned_equip_id = TangramEquipmentUI.equipment_type_to_id(owned_id)
				if owned_equip_id == equip_id:
					already_owned = true
					break
		for relic in collected_relics:
			if TangramEquipmentUI.equipment_type_to_id(relic) == equip_id:
				already_owned = true
				break
		if not already_owned:
			available_equips.append(equip_info)

	available_equips.shuffle()
	for i in range(3):
		if i < available_equips.size():
			var eq = available_equips[i]
			var price = 0 if shop_first_item_free else _roll_price(50)
			shop_equip_items.append({"equip_id": eq["id"], "equip_type": eq["type"], "price": price, "sold": false})
		else:
			shop_equip_items.append({"equip_id": "", "equip_type": -1, "price": 0, "sold": true})

func _roll_price(base_price: int) -> int:
	return max(1, int(ceil(float(base_price) * randf_range(0.92, 1.08))))

func _get_stat_label(stat_key: String, value: int) -> String:
	match stat_key:
		"hp": return (tr("UI_ROGUELIKEMAP_HEAL_HP_PLUSNUM")) % value
		"max_hp": return (tr("UI_ROGUELIKEMAP_MAX_HP_PLUSNUM")) % value
		"atk": return (tr("UI_ROGUELIKEMAP_ATK_PLUSNUM")) % value
		"def": return (tr("UI_ROGUELIKECOMBAT_DEF_PLUSNUM")) % value
	return str(value)

func _refresh_shop_ui() -> void:
	if not shop_ui:
		return
	shop_ui.set_gold(player_gold)
	for stat_key in ["hp", "max_hp", "atk", "def"]:
		var stat_info = shop_stat_items.get(stat_key, {"price": 0, "free": false})
		var value = shop_stat_values.get(stat_key, 0)
		var label = _get_stat_label(stat_key, value)
		var price = int(stat_info.get("price", 0))
		var free = bool(stat_info.get("free", false))
		var can_afford = (price <= player_gold)
		shop_ui.set_stat_button(stat_key, label, price, can_afford, free)
	for i in range(shop_equip_items.size()):
		var item = shop_equip_items[i]
		var equip_id = item.get("equip_id", "")
		var label = "---" if equip_id.is_empty() else _get_equip_display_name(equip_id)
		var price = int(item.get("price", 0))
		var sold = bool(item.get("sold", false))
		var free = (price == 0 and not sold)
		var can_afford = (price <= player_gold)
		shop_ui.set_equip_button(i, label, price, sold, can_afford, free)

func _on_shop_stat_purchased(stat_key: String) -> void:
	if not shop_stat_items.has(stat_key):
		return
	var item = shop_stat_items[stat_key]
	var price = int(item.get("price", 0))
	if price > player_gold:
		return
	player_gold -= price

	var value = shop_stat_values.get(stat_key, 0)
	match stat_key:
		"hp":
			var was_free = shop_hp_free_available
			player_health = min(player_health + value, player_max_health)
			shop_stat_buys["hp"] += 1
			if was_free:
				shop_hp_free_available = false
				shop_first_hp_free = false
				print(tr("LOG_ROGUE_SHOP_HP_FREE_USED"))
			else:
				print(tr("LOG_ROGUE_SHOP_HP_BUY") % [shop_stat_buys["hp"]])
			print(tr("LOG_ROGUE_SHOP_HP_RESTORE") % [value, player_health, player_max_health])
		"max_hp":
			player_max_health += value
			player_health += value
			print(tr("LOG_ROGUE_SHOP_MAX_HP") % [value, player_health, player_max_health])
		"atk":
			print(tr("LOG_ROGUE_SHOP_ATK") % [value])
		"def":
			print(tr("LOG_ROGUE_SHOP_DEF") % [value])

	if stat_key != "hp":
		shop_stat_buys[stat_key] = shop_stat_buys.get(stat_key, 0) + 1
	var base_price = shop_stat_base_prices.get(stat_key, 20)
	item["price"] = _roll_price(base_price)
	item["free"] = false
	shop_stat_items[stat_key] = item
	_update_player_status_ui()
	_refresh_shop_ui()

func _on_shop_equip_purchased(slot_index: int) -> void:
	if slot_index < 0 or slot_index >= shop_equip_items.size():
		return
	var item = shop_equip_items[slot_index]
	if bool(item.get("sold", false)):
		return
	var price = int(item.get("price", 0))
	if price > player_gold:
		return
	player_gold -= price

	var equip_id = item.get("equip_id", "")
	var equip_type = item.get("equip_type", -1)
	if equip_type >= 0:
		collected_relics.append(equip_type)
		if tangram_equipment:
			tangram_equipment.auto_place_equipment(equip_id)
		print(tr("LOG_ROGUE_SHOP_EQUIP_BUY") % [equip_id])
	item["sold"] = true
	shop_equip_items[slot_index] = item

	if shop_first_item_free:
		shop_first_item_free = false
		for i in range(shop_equip_items.size()):
			var equip_item = shop_equip_items[i]
			if not bool(equip_item.get("sold", false)):
				equip_item["price"] = _roll_price(50)
				shop_equip_items[i] = equip_item

	_update_player_status_ui()
	_refresh_shop_ui()

func _close_shop() -> void:
	if shop_ui:
		shop_ui.hide()
	if tangram_equipment and tangram_equipment.visible:
		tangram_equipment.hide_ui()
	_complete_active_node_and_return_map()

func _get_shop_atk_bonus() -> int:
	return shop_stat_buys.get("atk", 0) * int(shop_stat_values.get("atk", 5))

func _get_shop_def_bonus() -> int:
	return shop_stat_buys.get("def", 0) * int(shop_stat_values.get("def", 10))

# ===== BGM控制 =====

const ROGUE_BGM_PATH = "res://musics/bgm/rogue_bgm.mp3"
var bgm_player: AudioStreamPlayer = null
var _background_bgm_paused: bool = false

func _notification(what):
	if what == NOTIFICATION_RESIZED:
		_layout_map_ui()
		queue_redraw()
	if what == NOTIFICATION_APPLICATION_FOCUS_IN or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		call_deferred("_handle_focus_bgm")

func _on_window_focus_entered() -> void:
	call_deferred("_handle_focus_bgm")

func _on_window_focus_exited() -> void:
	call_deferred("_handle_focus_bgm")

func _handle_focus_bgm() -> void:
	if not Global.play_music_when_unfocused and not _is_window_focused():
		if bgm_player and bgm_player.playing:
			bgm_player.stream_paused = true
			_background_bgm_paused = true
		return
	if _background_bgm_paused:
		_background_bgm_paused = false
		_refresh_rogue_bgm_state()

func _start_rogue_bgm() -> void:
	if not Global.bgm_enabled:
		return
	if bgm_player == null:
		bgm_player = AudioStreamPlayer.new()
		bgm_player.bus = "Music"
		add_child(bgm_player)
		bgm_player.finished.connect(_on_bgm_finished)
	var bgm = load(ROGUE_BGM_PATH)
	if bgm:
		bgm_player.stream = bgm
		bgm_player.volume_db = 0
		bgm_player.stream_paused = false
		bgm_player.play()
		print(tr("LOG_ROGUE_BGM_PLAYED"))
	else:
		var fallback = load(Global.BGM_PATH)
		if fallback:
			bgm_player.stream = fallback
			bgm_player.volume_db = 0
			bgm_player.stream_paused = false
			bgm_player.play()
			print(tr("LOG_ROGUE_BGM_FALLBACK"))

func _stop_bgm() -> void:
	if bgm_player and bgm_player.playing:
		bgm_player.stream_paused = false
		bgm_player.stop()
		print(tr("LOG_ROGUE_BGM_STOPPED"))

func _on_bgm_finished() -> void:
	if Global.bgm_enabled and bgm_player and (Global.play_music_when_unfocused or _is_window_focused()):
		bgm_player.play()

func on_bgm_setting_changed(_enabled: bool) -> void:
	_refresh_rogue_bgm_state()

func _refresh_rogue_bgm_state() -> void:
	if not Global.bgm_enabled:
		_stop_bgm()
		return
	if not Global.play_music_when_unfocused and not _is_window_focused():
		if bgm_player and bgm_player.playing:
			bgm_player.stream_paused = true
		return
	if bgm_player == null or not bgm_player.playing:
		_start_rogue_bgm()
		return
	bgm_player.stream_paused = false

func _is_window_focused() -> bool:
	var window = get_window()
	if window:
		return window.has_focus()
	return true
