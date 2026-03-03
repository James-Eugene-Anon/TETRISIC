extends Control
class_name RoguelikeMap

## Roguelike地图主界面 - 整合地图导航、战斗、遗物选择、休息
## 单行道地图系统：起点->战斗1->遗物->战斗2->休息->Boss->胜利

const UI_FONT = preload(Config.PATHS_FONT_DEFAULT)
const PauseMenuScene = preload(Config.PATHS_SCENE_PAUSE_MENU)
const ROGUE_CONFIG_PATH = "res://Data/Roguelike/rogue_config.json"

# 地图节点类型
enum NodeType {
	START,       # 起点
	COMBAT,      # 普通战斗
	BOSS,        # Boss战斗
	REST,        # 休息（回血）
	RELIC,       # 遗物获取
	SHOP,        # 商店
	END          # 终点（胜利）
}

# 游戏状态
enum GameState {
	MAP,         # 地图界面
	COMBAT,      # 战斗中
	RELIC,       # 遗物选择
	REST,        # 休息
	SHOP,        # 商店
	VICTORY,     # 通关胜利
	DEFEAT       # 失败
}

var current_state: int = GameState.MAP
var is_paused: bool = false
var _rogue_is_true_victory: bool = false  # true 仅当玩家完成最终节点（真胜利）

# 返回地图后的输入锁，避免战斗结束时误触直接进入下一节点
var map_input_lock_timer: float = 0.0

# 节点数据
var map_nodes: Array = []
var current_node_index: int = 0

# 玩家持久数据（跨战斗）
var player_health: int = 300
var player_max_health: int = 300
var player_gold: int = 0  # 金币（跨战斗持久）
var collected_relics: Array = []
var total_lines_cleared: int = 0

# 商店系统
var shop_stat_buys: Dictionary = {"hp": 0, "max_hp": 0, "atk": 0, "def": 0}  # 已购买次数
var shop_first_hp_free: bool = true  # 兼容旧变量（不再作为主判定）
var shop_hp_free_available: bool = true  # 当前商店是否还有首次回血免费
var shop_first_item_free: bool = true  # 首件装备免费
var shop_ui: RogueShopUI = null
var shop_stat_items: Dictionary = {}
var shop_equip_items: Array = []

# 七巧板装备系统
var tangram_equipment: TangramEquipmentUI = null
var tangram_equipped_list: Array = []  # 已装备的装备ID列表

var wave_configs: Array = []
var wave_id_to_index: Dictionary = {}
var shop_stat_base_prices: Dictionary = {}
var shop_stat_values: Dictionary = {}
var shop_equip_pool_data: Array = []

# 子场景
var combat_scene: Control = null
var relic_ui: Control = null
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

# 节点视觉配置
const NODE_SIZE = 50
const NODE_SPACING = 100
const MAP_START_Y = 350
const BASE_FRAME_SIZE = Vector2(800, 600)

# 节点颜色
const NODE_COLORS = {
	NodeType.START: Color(0.4, 0.7, 0.4),
	NodeType.COMBAT: Color(0.8, 0.3, 0.3),
	NodeType.BOSS: Color(0.9, 0.2, 0.5),
	NodeType.REST: Color(0.3, 0.7, 0.9),
	NodeType.RELIC: Color(0.9, 0.7, 0.2),
	NodeType.SHOP: Color(0.9, 0.8, 0.3),
	NodeType.END: Color(0.3, 0.9, 0.3)
}

const NODE_ICON_KEYS = {
	NodeType.START: "UI_ROGUELIKEMAP_ICON_START",
	NodeType.COMBAT: "UI_ROGUELIKEMAP_ICON_COMBAT",
	NodeType.BOSS: "UI_ROGUELIKEMAP_ICON_BOSS",
	NodeType.REST: "UI_ROGUELIKEMAP_ICON_REST",
	NodeType.RELIC: "UI_ROGUELIKEMAP_ICON_RELIC",
	NodeType.SHOP: "UI_ROGUELIKEMAP_ICON_SHOP",
	NodeType.END: "UI_ROGUELIKEMAP_ICON_END"
}

const TEXT_KEYS = {
	"map_title": "UI_ROGUELIKEMAP_MAP_TITLE",
	"player_status": "UI_ROGUELIKEMAP_PLAYER_STATUS",
	"equipment": "UI_ROGUELIKEMAP_EQUIPMENT",
	"lines": "UI_ROGUELIKEMAP_LINES",
	"hint": "UI_HINT_ENTER_NEXT_NODE_ESC_PAUSE",
	"node_start": "UI_ROGUELIKEMAP_NODE_START",
	"node_slime": "UI_ROGUELIKEMAP_NODE_SLIME",
	"node_relic": "UI_ROGUELIKEMAP_NODE_RELIC",
	"node_skeleton": "UI_ROGUELIKEMAP_NODE_SKELETON",
	"node_rest": "UI_ROGUELIKEMAP_NODE_REST",
	"node_vampire": "UI_ROGUELIKEMAP_NODE_VAMPIRE",
	"node_victory": "UI_ROGUELIKEMAP_NODE_VICTORY",
	"node_shop": "UI_ROGUELIKEMAP_NODE_SHOP",
	"next_hint": "UI_ROGUELIKEMAP_NEXT_HINT",
	"view_equipment": "UI_COMMON_VIEW_EQUIP",
	"equip_hint_prefix": "UI_COMMON_KEY_E_BRACKET"
}

func _ready():
	_load_rogue_config_defaults()
	_load_rogue_data_from_db()
	# 设置当前游戏模式
	Global.current_game_mode = Global.GameMode.ROGUE
	# 播放Rogue专属BGM（尊重后台播放设置）
	_refresh_rogue_bgm_state()
	
	_generate_map()
	
	# 暂停菜单
	pause_menu = PauseMenuScene.instantiate()
	pause_menu.hide()
	add_child(pause_menu)
	pause_menu.resume_game.connect(_on_resume_pressed)
	pause_menu.restart_game.connect(_on_restart_pressed)
	pause_menu.end_game.connect(_on_end_game_pressed)
	pause_menu.goto_options.connect(_on_options_pressed)
	pause_menu.goto_menu.connect(_on_menu_pressed)
	
	# 预加载遗物UI
	var relic_scene = load(Config.PATHS_SCENE_RELIC_SELECTION)
	if relic_scene:
		relic_ui = relic_scene.instantiate()
		relic_ui.hide()
		add_child(relic_ui)
		relic_ui.relic_selected.connect(_on_relic_selected)
		relic_ui.relic_skipped.connect(_on_relic_skipped)

	# 预加载商店UI
	var shop_scene = load(Config.PATHS_SCENE_ROGUE_SHOP)
	if shop_scene:
		shop_ui = shop_scene.instantiate()
		shop_ui.hide()
		add_child(shop_ui)
		shop_ui.stat_purchased.connect(_on_shop_stat_purchased)
		shop_ui.equip_purchased.connect(_on_shop_equip_purchased)
		shop_ui.close_requested.connect(_close_shop)
		shop_ui.toggle_equipment_requested.connect(_toggle_equipment_ui)
	
	# 初始化七巧板装备系统
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
	
	# 连接子界面信号
	if defeat_screen:
		defeat_screen.return_to_menu.connect(_on_screen_return_to_menu)
	if victory_screen:
		victory_screen.return_to_menu.connect(_on_screen_return_to_menu)
	if rest_screen:
		rest_screen.rest_confirmed.connect(_on_rest_confirmed)
	
	# 初始化UI
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
	# 从Data JSON加载Rogue核心配置（波次/商店）
	if not Engine.has_singleton("ResourceDB"):
		return
	var db = Engine.get_singleton("ResourceDB")
	if not db:
		return

	# 波次配置
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

	# 商店属性配置
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

func _resolve_node_type_from_event(node_event: Dictionary) -> int:
	var node_key = String(node_event.get("node_key", ""))
	match node_key:
		"node_start":
			return NodeType.START
		"node_relic":
			return NodeType.RELIC
		"node_shop":
			return NodeType.SHOP
		"node_rest":
			return NodeType.REST
		"node_victory":
			return NodeType.END
		"node_slime", "node_skeleton":
			return NodeType.COMBAT
		"node_vampire":
			return NodeType.BOSS
		_:
			if node_event.has("wave_id"):
				return NodeType.COMBAT
			return NodeType.COMBAT

func _on_tangram_equipment_changed(equipped_list: Array):
	# 七巧板装备变更
	tangram_equipped_list = equipped_list
	print(tr("LOG_ROGUE_EQUIP_CHANGED") % [str(equipped_list)])
	_update_player_status_ui()

func _generate_map():
	# 生成单行道地图（优先使用Data/Events中的kind=map_node配置）
	map_nodes.clear()

	if Engine.has_singleton("ResourceDB"):
		var db = Engine.get_singleton("ResourceDB")
		if db and db.has_method("get_events_by_kind"):
			var node_rows: Array[Dictionary] = db.get_events_by_kind("map_node")
			if not node_rows.is_empty():
				node_rows.sort_custom(func(a, b): return int(a.get("order", 0)) < int(b.get("order", 0)))
				for row in node_rows:
					var node_type = _resolve_node_type_from_event(row)
					var node_data: Dictionary = {
						"type": node_type,
						"name_key": String(row.get("node_key", "")),
						"name": String(row.get("title", "")),
						"name_en": String(row.get("title_en", "")),
						"completed": false,
						"offset": _random_node_offset(),
					}
					if row.has("wave_id"):
						var wave_id = String(row.get("wave_id", ""))
						if wave_id_to_index.has(wave_id):
							node_data["wave_index"] = int(wave_id_to_index[wave_id])
					map_nodes.append(node_data)

	if map_nodes.is_empty():
		# 最小兜底流程（当Data不可用时）
		map_nodes.append({"type": NodeType.START, "name_key": "node_start", "completed": true, "offset": _random_node_offset()})
		map_nodes.append({"type": NodeType.COMBAT, "name_key": "node_slime", "completed": false, "wave_index": 0, "offset": _random_node_offset()})
		map_nodes.append({"type": NodeType.RELIC, "name_key": "node_relic", "completed": false, "offset": _random_node_offset()})
		map_nodes.append({"type": NodeType.SHOP, "name_key": "node_shop", "completed": false, "offset": _random_node_offset()})
		map_nodes.append({"type": NodeType.COMBAT, "name_key": "node_skeleton", "completed": false, "wave_index": 1, "offset": _random_node_offset()})
		map_nodes.append({"type": NodeType.REST, "name_key": "node_rest", "completed": false, "offset": _random_node_offset()})
		map_nodes.append({"type": NodeType.BOSS, "name_key": "node_vampire", "completed": false, "wave_index": 2, "offset": _random_node_offset()})
		map_nodes.append({"type": NodeType.END, "name_key": "node_victory", "completed": false, "offset": _random_node_offset()})

	if not map_nodes.is_empty():
		map_nodes[0]["completed"] = true

func _process(delta: float):
	if map_input_lock_timer > 0:
		map_input_lock_timer = max(map_input_lock_timer - delta, 0.0)

func _t(key: String) -> String:
	var translation_key = TEXT_KEYS.get(key, "")
	if translation_key == "":
		return key
	return tr(translation_key)

func _get_node_icon(node_type: int) -> String:
	var translation_key = NODE_ICON_KEYS.get(node_type, "")
	if translation_key == "":
		return "?"
	return tr(translation_key)

func _get_node_display_name(node: Dictionary) -> String:
	var key = node.get("name_key", "")
	if key != "":
		return _t(key)
	if Global.current_language == "en" and node.has("name_en") and not String(node.get("name_en", "")).is_empty():
		return String(node.get("name_en", ""))
	return String(node.get("name", ""))

func _draw():
	# 仅在地图状态绘制背景和动态地图节点
	if current_state == GameState.MAP:
		var viewport_size = get_viewport_rect().size
		draw_rect(Rect2(Vector2.ZERO, viewport_size), Color(0.08, 0.06, 0.12), true)
		_draw_map_nodes()


func _change_state(new_state: int):
	# 统一状态切换，自动更新界面可见性
	current_state = new_state
	
	# 地图HUD元素可见性
	var show_map = (new_state == GameState.MAP)
	var show_shop = (new_state == GameState.SHOP)
	if map_title_label:
		map_title_label.visible = show_map
	if player_status_panel:
		player_status_panel.visible = show_map or show_shop
	if hint_label:
		hint_label.visible = show_map
	if credit_label:
		credit_label.visible = show_map
	if shop_ui:
		shop_ui.visible = show_shop
	
	# 隐藏所有子界面
	if defeat_screen:
		defeat_screen.hide()
	if victory_screen:
		victory_screen.hide()
	if rest_screen:
		rest_screen.hide()
	
	# 显示对应界面并确保在最上层
	match new_state:
		GameState.DEFEAT:
			# 展示红色结算面板（使用和胜利相同的运营统计面板，但边框为红色）
			if victory_screen:
				move_child(victory_screen, -1)
				victory_screen.show_screen(total_lines_cleared, collected_relics.size(), player_gold, false)
		GameState.VICTORY:
			var is_true_win = _rogue_is_true_victory
			_rogue_is_true_victory = false  # 重置标志
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

func _update_player_status_ui():
	# 更新玩家状态面板（TSCN节点）
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

func _update_map_texts():
	# 根据当前语言更新地图界面文本
	if map_title_label:
		map_title_label.text = _t("map_title")
	if status_title_label:
		status_title_label.text = _t("player_status")
	if hint_label:
		hint_label.text = _t("hint")
	if equip_hint_label:
		equip_hint_label.text = tr(TEXT_KEYS["equip_hint_prefix"]) + _t("view_equipment")

func _on_screen_return_to_menu():
	# 子界面返回主菜单信号回调
	get_tree().change_scene_to_file(Config.PATHS_SCENE_MAIN_MENU)

func _on_rest_confirmed():
	# 休息界面确认信号回调
	_complete_rest()

func _draw_map_nodes():
	# 绘制地图节点
	var frame = _get_game_frame_rect()
	var total_width = map_nodes.size() * NODE_SPACING
	var start_x = frame.position.x + (frame.size.x - total_width) / 2 + NODE_SPACING / 2
	var map_y = frame.position.y + MAP_START_Y
	
	for i in range(map_nodes.size()):
		var node = map_nodes[i]
		var offset = node.get("offset", Vector2.ZERO)
		var pos = Vector2(start_x + i * NODE_SPACING - NODE_SIZE / 2, map_y) + offset
		
		# 绘制连线
		if i < map_nodes.size() - 1:
			var next_node = map_nodes[i + 1]
			var next_offset = next_node.get("offset", Vector2.ZERO)
			var next_pos = Vector2(start_x + (i + 1) * NODE_SPACING - NODE_SIZE / 2, map_y) + next_offset
			var line_color = Color(0.3, 0.8, 0.3) if node.completed else Color(0.4, 0.4, 0.4)
			draw_line(pos + Vector2(NODE_SIZE, NODE_SIZE / 2), 
				next_pos + Vector2(0, NODE_SIZE / 2), line_color, 3)
		
		# 绘制节点
		_draw_single_node(pos, node, i)

func _draw_single_node(pos: Vector2, node: Dictionary, index: int):
	var node_type = node.type
	var is_next = (index == current_node_index + 1)
	var is_completed = node.completed
	var is_current = (index == current_node_index)
	
	# 节点背景颜色
	var bg_color = NODE_COLORS.get(node_type, Color.GRAY)
	if is_completed:
		bg_color = bg_color.darkened(0.5)
	elif is_next:
		bg_color = bg_color.lightened(0.15)
	
	# 外发光（下一节点）
	if is_next:
		var glow_rect = Rect2(pos - Vector2(4, 4), Vector2(NODE_SIZE + 8, NODE_SIZE + 8))
		draw_rect(glow_rect, Color(bg_color.r, bg_color.g, bg_color.b, 0.3), true)
	
	# 背景
	draw_rect(Rect2(pos, Vector2(NODE_SIZE, NODE_SIZE)), bg_color, true)
	
	# 边框
	var border_color = UITheme.ACCENT_SECONDARY if is_next else UITheme.BORDER_MEDIUM
	var border_width = UITheme.BORDER_THICK if is_next else UITheme.BORDER_THIN
	if is_current:
		border_color = UITheme.ACCENT_SUCCESS
		border_width = UITheme.BORDER_THICK
	draw_rect(Rect2(pos, Vector2(NODE_SIZE, NODE_SIZE)), border_color, false, border_width)
	
	# 图标
	var icon = _get_node_icon(node_type)
	draw_string(UI_FONT, pos + Vector2(0, NODE_SIZE / 2 + 10), icon, 
		HORIZONTAL_ALIGNMENT_CENTER, NODE_SIZE, UITheme.FONT_SIZE_LG, UITheme.TEXT_PRIMARY)
	
	# 名称
	draw_string(UI_FONT, pos + Vector2(NODE_SIZE / 2 - 40, NODE_SIZE + 18), _get_node_display_name(node), 
		HORIZONTAL_ALIGNMENT_CENTER, 80, UITheme.FONT_SIZE_SM, UITheme.TEXT_SECONDARY)
	
	# 下一节点提示
	if is_next:
		draw_string(UI_FONT, pos + Vector2(NODE_SIZE / 2 - 12, -10), _t("next_hint"), 
			HORIZONTAL_ALIGNMENT_CENTER, 24, UITheme.FONT_SIZE_MD, UITheme.ACCENT_SECONDARY)

func _random_node_offset() -> Vector2:
	return Vector2(randf_range(-14.0, 14.0), randf_range(-10.0, 10.0))

func _input(event: InputEvent):
	if not event.is_pressed():
		return
	
	if pause_menu and pause_menu.visible:
		if event.is_action_pressed("ui_cancel"):
			_toggle_pause()
		return
	
	# 仅处理地图状态输入，休息/胜利/失败由各自TSCN场景处理
	if current_state == GameState.MAP:
		_handle_map_input(event)

func _handle_map_input(event: InputEvent):
	if map_input_lock_timer > 0:
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_cancel"):
		_toggle_pause()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_accept"):
		_enter_next_node()
		get_viewport().set_input_as_handled()
		return
	# E键打开/关闭装备界面
	if event is InputEventKey and event.keycode == KEY_E:
		_toggle_equipment_ui()
		get_viewport().set_input_as_handled()

func _toggle_pause():
	is_paused = !is_paused
	if pause_menu:
		if is_paused:
			pause_menu.show_menu()
			pause_menu.update_ui_texts()
		else:
			pause_menu.hide()

func _toggle_equipment_ui():
	# 切换装备界面显示（全屏居中，无需定位）
	if tangram_equipment:
		if tangram_equipment.visible:
			tangram_equipment.hide_ui()
		else:
			tangram_equipment.show_ui()

func _on_resume_pressed():
	_toggle_pause()

func _on_restart_pressed():
	get_tree().reload_current_scene()

func _on_end_game_pressed():
	if pause_menu:
		pause_menu.hide()
	is_paused = false
	# 显示结算画面（累计行数/遗物/金币），玩家在结算页点击返回主菜单
	_change_state(GameState.VICTORY)

func _on_options_pressed():
	if pause_menu:
		pause_menu.hide()
	var options_scene = load(Config.PATHS_SCENE_OPTIONS_MENU)
	if options_scene:
		var options_instance = options_scene.instantiate()
		options_instance.set_meta("from_game", true)
		options_instance.tree_exited.connect(_on_options_closed)
		get_tree().root.add_child(options_instance)

func _on_options_closed():
	if is_paused and pause_menu:
		pause_menu.show_menu()
		pause_menu.update_ui_texts()

func _on_menu_pressed():
	get_tree().change_scene_to_file(Config.PATHS_SCENE_MAIN_MENU)

func _enter_next_node():
	# 进入下一个节点（加锁防止快速连按导致跳过）
	if map_input_lock_timer > 0:
		return
	_lock_map_input(0.5)
	
	var next_index = current_node_index + 1
	if next_index >= map_nodes.size():
		return
	
	var node = map_nodes[next_index]
	
	match node.type:
		NodeType.COMBAT, NodeType.BOSS:
			_start_combat(node)
		NodeType.RELIC:
			_show_relic_selection()
		NodeType.REST:
			_change_state(GameState.REST)
		NodeType.SHOP:
			_open_shop()
		NodeType.END:
			_complete_node()
			_rogue_is_true_victory = true  # 真正完素，绚色胜利面板
			_change_state(GameState.VICTORY)

func _start_combat(node: Dictionary):
	# 开始战斗
	var wave_index = node.get("wave_index", 0)
	var wave = wave_configs[wave_index] if wave_index < wave_configs.size() else wave_configs[0]
	
	# 加载战斗场景
	var combat_scene_resource = load("res://UI/RoguelikeCombat.tscn")
	if not combat_scene_resource:
		# 如果没有场景文件，直接跳过战斗
		print(tr("LOG_ROGUE_BATTLE_SCENE_MISSING"))
		_on_combat_ended(true)
		return
	
	combat_scene = combat_scene_resource.instantiate()
	add_child(combat_scene)
	
	# 传递玩家血量和金币
	combat_scene.player_health = player_health
	combat_scene.player_max_health = player_max_health
	combat_scene.player_gold = player_gold
	
	# 传递商店加成
	var atk_bonus = _get_shop_atk_bonus()
	if atk_bonus > 0:
		combat_scene.player_attack_power += atk_bonus
	var def_bonus = _get_shop_def_bonus()
	if def_bonus > 0:
		combat_scene.shop_def_bonus = def_bonus
	
	# 设置战斗波次
	combat_scene.setup_wave(wave)
	# 同步七巧板背包中已装备的遗物（仅放入背包格的生效）
	if combat_scene.has_method("apply_relics"):
		var equipped_types = tangram_equipment.get_equipped_types() if tangram_equipment else []
		combat_scene.apply_relics(equipped_types)
	
	# 连接战斗结束信号
	combat_scene.battle_ended.connect(_on_combat_ended)
	combat_scene.quit_to_menu.connect(_on_combat_quit_to_menu)
	
	_change_state(GameState.COMBAT)

func _on_combat_ended(victory: bool):
	# 战斗结束回调
	if combat_scene:
		# 保存玩家血量和金币
		player_health = combat_scene.player_health
		player_gold = combat_scene.player_gold
		# 累计本次战斗消除行数
		total_lines_cleared += combat_scene.total_lines_cleared
		# 立即从树中移除，避免遮挡后续界面
		remove_child(combat_scene)
		combat_scene.queue_free()
		combat_scene = null
	
	if victory:
		# 标记当前节点已完成，但不自动进入下一节点
		var next_index = current_node_index + 1
		if next_index < map_nodes.size():
			map_nodes[next_index].completed = true
			current_node_index = next_index
		_change_state(GameState.MAP)  # 返回地图，等待玩家手动进入下一节点
		_lock_map_input()
	else:
		_change_state(GameState.DEFEAT)

func _on_combat_quit_to_menu():
	# 玩家在战斗中主动退出 → 累计数据后显示全局结算画面
	if combat_scene:
		player_health = combat_scene.player_health
		player_gold = combat_scene.player_gold
		total_lines_cleared += combat_scene.total_lines_cleared
		remove_child(combat_scene)
		combat_scene.queue_free()
		combat_scene = null
	_change_state(GameState.VICTORY)

func _show_relic_selection():
	# 显示装备选择
	_change_state(GameState.RELIC)
	if relic_ui:
		relic_ui.show_single_relic()

func _on_relic_selected(relic_type: int):
	# 装备被选中 → 自动放置或加入背包，不强制打开装备界面
	# 先隐藏relic_ui，避免灰屏闪烁
	if relic_ui:
		relic_ui.hide()
	
	collected_relics.append(relic_type)
	var equip_id = TangramEquipmentUI.equipment_type_to_id(relic_type)
	if not equip_id.is_empty() and tangram_equipment:
		# 尝试自动放置，失败则加入背包（玩家可用E键手动管理）
		var placed = tangram_equipment.auto_place_equipment(equip_id)
		if placed:
			print(tr("LOG_ROGUE_EQUIP_AUTO_PLACED") % [equip_id, relic_type])
		else:
			# 放置失败（网格已满），确保装备进入背包
			if not tangram_equipment.inventory.has(equip_id) and not tangram_equipment.has_equipment(equip_id):
				tangram_equipment.inventory.append(equip_id)
			print(tr("LOG_ROGUE_EQUIP_GRID_FULL") % [equip_id])
	else:
		print(tr("LOG_ROGUE_EQUIP_ID_EMPTY") % [relic_type])
	# 立即推进，避免灰屏残留
	_finish_relic_node()

func _on_placement_done():
	## 手动放置完成回调
	if tangram_equipment:
		tangram_equipment.hide_ui()
	_finish_relic_node()

func _finish_relic_node():
	## 装备放置流程完成，推进地图
	var next_index = current_node_index + 1
	if next_index < map_nodes.size():
		map_nodes[next_index].completed = true
		current_node_index = next_index
	_change_state(GameState.MAP)
	_lock_map_input()

func _on_relic_skipped():
	# 装备被跳过
	print(tr("LOG_ROGUE_SKIP_EQUIP"))
	# 标记当前节点已完成，但不自动进入下一节点
	var next_index = current_node_index + 1
	if next_index < map_nodes.size():
		map_nodes[next_index].completed = true
		current_node_index = next_index
	_change_state(GameState.MAP)
	_lock_map_input()

func _complete_rest():
	# 完成休息 - 回满生命值
	player_health = player_max_health
	print(tr("LOG_ROGUE_REST_HEAL") % [player_health, player_max_health])
	# 标记当前节点已完成，但不自动进入下一节点
	var next_index = current_node_index + 1
	if next_index < map_nodes.size():
		map_nodes[next_index].completed = true
		current_node_index = next_index
	_change_state(GameState.MAP)
	_lock_map_input()

func _complete_node():
	# 完成当前节点（保留用于终点）
	var next_index = current_node_index + 1
	if next_index < map_nodes.size():
		map_nodes[next_index].completed = true
		current_node_index = next_index

func _lock_map_input(duration: float = 0.5):
	map_input_lock_timer = max(map_input_lock_timer, duration)

# ===== 商店系统 =====

func _open_shop():
	# 打开商店界面
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
	# 回退
	match equip_id:
		"iron_sword": return tr("UI_RELICSELECTIONUI_IRON_SWORD")
		"iron_shield": return tr("UI_RELICSELECTIONUI_IRON_SHIELD")
		"downclock_software": return tr("UI_ROGUELIKEMAP_DOWNCLOCK")
		"faulty_score_amplifier": return tr("UI_ROGUELIKEMAP_FAULTY_AMP")
		"rift_meter": return tr("UI_RELICSELECTIONUI_RIFT_METER")
	return equip_id

func _init_shop_items():
	# 初始化商店可购买项
	shop_stat_items.clear()
	shop_equip_items.clear()

	# 属性类
	for stat_key in ["hp", "max_hp", "atk", "def"]:
		var base_price = shop_stat_base_prices.get(stat_key, 20)
		var price = _roll_price(base_price)
		var free = false
		# 每次进商店首次HP购买免费
		if stat_key == "hp":
			if shop_hp_free_available:
				price = 0
				free = true
				print(tr("LOG_ROGUE_SHOP_HP_FREE_AVAILABLE"))
		shop_stat_items[stat_key] = {"price": price, "free": free}

	# 装备格（3个固定位置，随机从池中选取未拥有的）
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
	var is_zh = Global.current_language == "zh"
	match stat_key:
		"hp": return (tr("UI_ROGUELIKEMAP_HEAL_HP_PLUSNUM")) % value
		"max_hp": return (tr("UI_ROGUELIKEMAP_MAX_HP_PLUSNUM")) % value
		"atk": return (tr("UI_ROGUELIKEMAP_ATK_PLUSNUM")) % value
		"def": return (tr("UI_ROGUELIKECOMBAT_DEF_PLUSNUM")) % value
	return str(value)

func _refresh_shop_ui():
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
			# 本次商店首次购买后禁用免费标志
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

	# 重新随机价格（除了hp，其他属性也要增加计数）
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

	# 首件免费后，其他装备价格刷新为50(±8%)
	if shop_first_item_free:
		shop_first_item_free = false
		for i in range(shop_equip_items.size()):
			var equip_item = shop_equip_items[i]
			if not bool(equip_item.get("sold", false)):
				equip_item["price"] = _roll_price(50)
				shop_equip_items[i] = equip_item

	_update_player_status_ui()
	_refresh_shop_ui()

func _close_shop():
	# 关闭商店，推进地图
	if shop_ui:
		shop_ui.hide()
	# 确保关闭装备UI（如果在商店中打开）
	if tangram_equipment and tangram_equipment.visible:
		tangram_equipment.hide_ui()
	var next_index = current_node_index + 1
	if next_index < map_nodes.size():
		map_nodes[next_index].completed = true
		current_node_index = next_index
	_change_state(GameState.MAP)
	_lock_map_input()

func _get_shop_atk_bonus() -> int:
	return shop_stat_buys.get("atk", 0) * int(shop_stat_values.get("atk", 5))

func _get_shop_def_bonus() -> int:
	return shop_stat_buys.get("def", 0) * int(shop_stat_values.get("def", 10))

# ===== BGM控制函数 =====

const ROGUE_BGM_PATH = "res://musics/bgm/rogue_bgm.mp3"

var bgm_player: AudioStreamPlayer = null
var _background_bgm_paused: bool = false

func _notification(what):
	if what == NOTIFICATION_RESIZED:
		_layout_map_ui()
		queue_redraw()
	if what == NOTIFICATION_APPLICATION_FOCUS_IN or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		call_deferred("_handle_focus_bgm")

func _on_window_focus_entered():
	call_deferred("_handle_focus_bgm")

func _on_window_focus_exited():
	call_deferred("_handle_focus_bgm")

func _handle_focus_bgm():
	if not Global.play_music_when_unfocused and not _is_window_focused():
		if bgm_player and bgm_player.playing:
			bgm_player.stream_paused = true
			_background_bgm_paused = true
		return

	if _background_bgm_paused:
		_background_bgm_paused = false
		_refresh_rogue_bgm_state()

func _start_rogue_bgm():
	# 播放Rogue专属背景音乐（尊重BGM设置）
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
		# 回退到默认BGM
		var fallback = load(Global.BGM_PATH)
		if fallback:
			bgm_player.stream = fallback
			bgm_player.volume_db = 0
			bgm_player.stream_paused = false
			bgm_player.play()
			print(tr("LOG_ROGUE_BGM_FALLBACK"))

func _start_bgm():
	# 播放背景音乐
	if bgm_player == null:
		bgm_player = AudioStreamPlayer.new()
		bgm_player.bus = "Music"
		add_child(bgm_player)
		bgm_player.finished.connect(_on_bgm_finished)
	
	var bgm = load(Global.BGM_PATH)
	if bgm:
		bgm_player.stream = bgm
		bgm_player.volume_db = 0
		bgm_player.play()
		print(tr("LOG_ROGUE_BGM_LOADED"))

func _stop_bgm():
	# 停止背景音乐
	if bgm_player and bgm_player.playing:
		bgm_player.stream_paused = false
		bgm_player.stop()
		print(tr("LOG_ROGUE_BGM_STOPPED"))

func _on_bgm_finished():
	# BGM循环播放
	if Global.bgm_enabled and bgm_player and (Global.play_music_when_unfocused or _is_window_focused()):
		bgm_player.play()

func on_bgm_setting_changed(enabled: bool):
	# BGM设置变更回调 - 由OptionsMenu调用
	_refresh_rogue_bgm_state()

func _refresh_rogue_bgm_state():
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
