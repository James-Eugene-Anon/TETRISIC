extends Control

## Roguelike战斗场景 - 回合制俄罗斯方块战斗系统
## 玩家通过消除方块攻击/防御，敌人按回合行动

const TURN_TIMEOUT = 20.0  # 每回合20秒
const OVERFLOW_DAMAGE = 20
const ENEMY_COOLDOWN_MULTIPLIER = 1.25
const UI_FONT = preload(Config.PATHS_FONT_DEFAULT)
const NPC_SPRITES = preload("res://Data/materials/npc48.png")
const NPC_TILE_SIZE = Vector2(32, 48)
const BASE_FRAME_SIZE = Vector2(800, 600)
const COMBAT_DEFAULTS_PATH = "res://Data/Enemies/combat_defaults.json"

# 本地化文本
const PLAYER_NAME_KEY = "UI_ROGUELIKECOMBAT_PLAYER_NAME"

class MysteryRescueOverlay:
	extends Control
	var combat_ref

	func _draw():
		if not combat_ref:
			return
		combat_ref._draw_mystery_rescue_dialogue(self)

# 战斗模式
enum CombatMode { ATTACK, DEFEND }
var combat_mode: CombatMode = CombatMode.ATTACK

# 回合系统
var turn_number: int = 1
var turn_timer: float = TURN_TIMEOUT
var player_acted: bool = false  # 玩家本回合是否行动（消除行）

# 游戏状态
var is_paused: bool = false
var is_game_over: bool = false
var total_lines_cleared: int = 0
var total_score: int = 0
var combo_count: int = 0
var last_combo: int = 0

# 选敌与时停
var target_select_active: bool = false
var target_confirmed: bool = false
var target_index: int = -1
var enemy_card_rects: Array = []

# 玩家数据
var player_health: int = 300
var player_max_health: int = 300
var player_attack_power: int = 10
var player_base_attack_power: int = 10
var player_shield: int = 0  # 护甲值
var player_gold: int = 0  # 金币
var battle_gold_earned: int = 0  # 本场战斗获得的金币
var shop_def_bonus: int = 0  # 商店防御加成（每次防御额外护甲）
const BASE_DEFENSE_PER_LINE: int = 10  # 初始防御力（每行消除获得的基础护甲值）

# 敌人数据（多敌人系统）
var enemies: Array = []  # 当前场上敌人列表
var slime_merge_turns: int = 5  # 史莱姆合体所需回合数
var slime_lord_split_done: bool = false  # 史莱姆王是否已分裂
var bat_merge_turn: int = 13  # 大蝙蝠合体回合
var bat_merge_done: bool = false  # 大蝙蝠是否已合体

# 战斗波次配置
var wave_config: Dictionary = {}
var combat_defaults: Dictionary = {}

# 通用俄罗斯方块模块控制器
var controller: RoguelikeModeController
var input_handler: InputHandler
var renderer: GameRenderer
var last_viewport_size: Vector2 = Vector2.ZERO

# 预加载UI场景
const PauseMenuScene = preload(Config.PATHS_SCENE_PAUSE_MENU)
const GameOverMenuScene = preload("res://UI/GameOverMenu.tscn")

# UI节点
var pause_menu: Control = null
var game_over_menu: Control = null
var relic_ui: Control = null
var victory_panel: Control = null
var victory_reward_scheduled: bool = false
var victory_pending: bool = false  # 胜利待定，允许最后的消除动画显示
var victory_kill_message: String = ""  # 制胜一击显示文本
var victory_kill_timer: float = 0.0   # 制胜一击文本显示计时
var victory_kill_question_mark: bool = false
var tangram_equipment: TangramEquipmentUI = null  # 局内七巧板装备背包
var mystery_overlay: Control = null

# TSCN子节点引用
@onready var combat_hud = $CombatHUD

func _get_game_frame_rect() -> Rect2:
	var viewport_size = get_viewport_rect().size
	var frame_pos = (viewport_size - BASE_FRAME_SIZE) * 0.5
	return Rect2(frame_pos, BASE_FRAME_SIZE)

func _apply_combat_ui_layout() -> void:
	var frame = _get_game_frame_rect()
	if combat_hud:
		# 重置锚点为左上角，再设定尺寸为 800x600，避免内部 anchor=1.0 的元素定位到视口右边缘
		combat_hud.anchor_left = 0.0
		combat_hud.anchor_top = 0.0
		combat_hud.anchor_right = 0.0
		combat_hud.anchor_bottom = 0.0
		combat_hud.position = frame.position
		combat_hud.size = BASE_FRAME_SIZE

# 地图回调
signal battle_ended(victory: bool)
signal quit_to_menu  # 在Rogue流程中主动退出（暂停菜单→退出游戏）

func _ready():
	# 初始化控制器 (完全复用经典模式逻辑)
	controller = RoguelikeModeController.new()
	add_child(controller)
	
	# 初始化输入处理器 (复用输入处理逻辑)
	input_handler = InputHandler.new()
	add_child(input_handler)
	
	# 连接输入信号
	input_handler.move_left.connect(func(): if not is_paused and not is_game_over: controller.move_piece(Vector2i(-1, 0)))
	input_handler.move_right.connect(func(): if not is_paused and not is_game_over: controller.move_piece(Vector2i(1, 0)))
	input_handler.move_down.connect(func(): if not is_paused and not is_game_over: controller.move_piece(Vector2i(0, 1)))
	input_handler.rotate.connect(func(): if not is_paused and not is_game_over: controller.rotate_piece())
	input_handler.hard_drop.connect(func(): if not is_paused and not is_game_over: controller.hard_drop())
	input_handler.pause_toggle.connect(_toggle_pause)
	
	# 连接游戏信号
	controller.damage_dealt.connect(_on_lines_cleared)
	controller.score_changed.connect(func(score): total_score = score)
	controller.lines_changed.connect(func(lines): total_lines_cleared = lines)
	controller.game_over_signal.connect(_on_overflow_triggered)
	if controller.has_signal("combo_changed"):
		controller.combo_changed.connect(func(c): combo_count = c; last_combo = max(last_combo, c))
	
	# 初始化游戏
	controller.initialize()
	
	# 初始化渲染器
	renderer = GameRenderer.new()
	add_child(renderer)
	renderer.set_grid_manager(controller.grid_manager)
	renderer.set_lyric_mode(false)
	renderer.set_special_block_info(Color.TRANSPARENT, "")
	# 调整网格位置到左下方（动态适配窗口）
	_update_renderer_layout()
	
	# 实例化暂停菜单
	pause_menu = PauseMenuScene.instantiate()
	pause_menu.hide()
	add_child(pause_menu)
	
	# 连接暂停菜单信号
	pause_menu.resume_game.connect(_on_resume_pressed)
	pause_menu.restart_game.connect(_on_restart_pressed)
	pause_menu.end_game.connect(_on_end_game_pressed)
	pause_menu.goto_options.connect(_on_options_pressed)
	pause_menu.goto_menu.connect(_on_menu_pressed)
	
	# 尝试加载遗物选择UI
	var relic_scene = load(Config.PATHS_SCENE_RELIC_SELECTION)
	if relic_scene:
		relic_ui = relic_scene.instantiate()
		relic_ui.hide()
		add_child(relic_ui)
		relic_ui.relic_selected.connect(_on_relic_selected)
		relic_ui.relic_skipped.connect(_on_relic_skipped)
	
	# 初始化局内七巧板装备背包（只读展示，由地图同步）
	var tangram_scene = load(Config.PATHS_SCENE_TANGRAM_EQUIP)
	if tangram_scene:
		tangram_equipment = tangram_scene.instantiate()
	else:
		tangram_equipment = TangramEquipmentUI.new()
	tangram_equipment.hide()
	add_child(tangram_equipment)

	# 神秘人救援遮罩层（确保绘制在最上层）
	mystery_overlay = MysteryRescueOverlay.new()
	mystery_overlay.combat_ref = self
	mystery_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mystery_overlay.z_index = 100
	mystery_overlay.z_as_relative = false
	mystery_overlay.hide()
	add_child(mystery_overlay)
	_load_combat_defaults()
	
	# 默认配置第一波敌人（可由外部覆盖）
	if wave_config.is_empty():
		setup_slime_wave()
	_apply_combat_ui_layout()

func setup_wave(config: Dictionary):
	# 外部设置战斗波次
	wave_config = config
	enemies.clear()
	player_base_attack_power = player_attack_power
	
	var enemy_list = config.get("enemies", [])
	for enemy_data in enemy_list:
		var name = enemy_data.get("name", tr("UI_ROGUELIKEMAP_ENEMY_FALLBACK"))
		var cooldown_base = enemy_data.get("cooldown_base", _get_default_cooldown_base(name))
		var cooldown_variance = enemy_data.get("cooldown_variance", _get_default_cooldown_variance(name))
		enemies.append({
			"name": name,
			"health": enemy_data.get("health", 100),
			"max_health": enemy_data.get("max_health", enemy_data.get("health", 100)),
			"damage": enemy_data.get("damage", 10),
			"shield": enemy_data.get("shield", 0),
			"gold_reward": enemy_data.get("gold_reward", _get_default_gold_reward(name)),
			"intent": "attack",  # attack, defend, buff
			"cooldown_base": cooldown_base,
			"cooldown_variance": cooldown_variance,
			"cooldown_timer": 0.0,
			"acted_this_turn": false
		})
	
	turn_number = 1
	target_index = _get_first_alive_enemy_index()  # 默认选中最近的敌人
	_start_turn(true)

func setup_slime_wave():
	enemies.clear()
	var slime_data = combat_defaults.get("slime_wave", {})
	var enemy_defs = slime_data.get("enemies", [])
	if enemy_defs.is_empty():
		return
	for enemy_def in enemy_defs:
		var name = enemy_def.get("name", tr("UI_ROGUELIKEMAP_ENEMY_FALLBACK"))
		enemies.append({
			"name": name,
			"health": enemy_def.get("health", 100),
			"max_health": enemy_def.get("max_health", enemy_def.get("health", 100)),
			"damage": enemy_def.get("damage", 10),
			"shield": enemy_def.get("shield", 0),
			"gold_reward": _get_gold_reward_from_base(int(enemy_def.get("gold_base", combat_defaults.get("gold_default_base", 3)))),
			"intent": "attack",
			"cooldown_base": enemy_def.get("cooldown_base", _get_default_cooldown_base(name)),
			"cooldown_variance": enemy_def.get("cooldown_variance", _get_default_cooldown_variance(name)),
			"cooldown_timer": 0.0,
			"acted_this_turn": false
		})
	slime_merge_turns = int(slime_data.get("merge_turns", slime_merge_turns))
	turn_number = 1
	target_index = _get_first_alive_enemy_index()  # 默认选中最近的敌人
	_start_turn(true)

func _load_combat_defaults() -> void:
	combat_defaults.clear()
	if not FileAccess.file_exists(COMBAT_DEFAULTS_PATH):
		return
	var file = FileAccess.open(COMBAT_DEFAULTS_PATH, FileAccess.READ)
	if not file:
		return
	var data = JSON.parse_string(file.get_as_text())
	if data is Dictionary:
		combat_defaults = data

func _get_default_cooldown_base(name: String) -> float:
	var rules = combat_defaults.get("cooldown_rules", [])
	for rule in rules:
		var keyword = str(rule.get("keyword", ""))
		if not keyword.is_empty() and name.find(keyword) != -1:
			return float(rule.get("base", combat_defaults.get("cooldown_default_base", 5.5)))
	return float(combat_defaults.get("cooldown_default_base", 5.5))

func _get_default_cooldown_variance(name: String) -> float:
	var rules = combat_defaults.get("cooldown_rules", [])
	for rule in rules:
		var keyword = str(rule.get("keyword", ""))
		if not keyword.is_empty() and name.find(keyword) != -1:
			return float(rule.get("variance", combat_defaults.get("cooldown_default_variance", 0.3)))
	return float(combat_defaults.get("cooldown_default_variance", 0.3))

func _get_default_gold_reward(enemy_name: String) -> int:
	var base_gold: int = int(combat_defaults.get("gold_default_base", 3))
	var base_map = combat_defaults.get("gold_base_by_name", {})
	if base_map.has(enemy_name):
		base_gold = int(base_map.get(enemy_name, base_gold))
	else:
		var fallback_rules = combat_defaults.get("gold_keyword_fallback", [])
		for rule in fallback_rules:
			var keyword = str(rule.get("keyword", ""))
			if not keyword.is_empty() and enemy_name.find(keyword) != -1:
				base_gold = int(rule.get("base_gold", base_gold))
				break
	return _get_gold_reward_from_base(base_gold)

func _get_gold_reward_from_base(base_gold: int) -> int:
	var gold: int = base_gold * 2 + 5
	gold = min(gold, 100)
	var variance: int = max(1, int(gold * 0.1))
	return gold + randi_range(-variance, variance)

func _process(delta: float):
	if is_game_over and not victory_pending:
		return
	
	# 胜利待定期间只渲染最后消除结果，不再更新方块逻辑
	if victory_pending:
		# 清除渲染器中过期的方块引用，避免已消行的方块形状残留在画面上
		renderer.current_piece = null
		# 制胜一击显示倒计时
		if victory_kill_timer > 0:
			victory_kill_timer -= delta
		renderer.queue_redraw()
		queue_redraw()
		return
	
	# 神秘人救援演出
	if mystery_rescue_active:
		if mystery_overlay and not mystery_overlay.visible:
			mystery_overlay.show()
		if mystery_overlay:
			mystery_overlay.queue_redraw()
		return
	elif mystery_overlay and mystery_overlay.visible:
		mystery_overlay.hide()

	# 动态适配窗口布局
	var viewport_size = get_viewport_rect().size
	if viewport_size != last_viewport_size:
		last_viewport_size = viewport_size
		_apply_combat_ui_layout()
		_update_renderer_layout()
		if victory_panel:
			var frame = _get_game_frame_rect()
			victory_panel.position = frame.position + frame.size * 0.5 - victory_panel.size * 0.5
		
	# 更新渲染器引用的方块数据 (每帧同步，包括 null 清除)
	renderer.set_current_piece(controller.current_piece)
	if controller.next_piece_data:
		renderer.set_next_piece_data(controller.next_piece_data)
	
	if is_paused:
		return
	
	var time_scale: float = 0.0 if target_select_active else 1.0
	var scaled_delta: float = delta * time_scale
	if controller and controller.equipment_system:
		controller.equipment_system.update_rift_meter(scaled_delta)

	# 更新游戏逻辑
	controller.update(scaled_delta)

	# 敌人冷却与回合逻辑（相互独立）
	_update_enemy_cooldowns(scaled_delta)
	
	# 回合计时
	turn_timer -= scaled_delta
	if turn_timer <= 0:
		_force_end_turn()
	
	# 时停模式下跳过无意义的重绘（选敌切换时由_select_target触发）
	if not target_select_active:
		renderer.queue_redraw()
	
	# 更新CombatHUD（TSCN节点）
	if combat_hud:
		combat_hud.update_turn_info(turn_number, turn_timer)
		combat_hud.update_combat_mode(combat_mode == CombatMode.ATTACK)
		combat_hud.update_combo(combo_count)

	if not target_select_active:
		queue_redraw()

func _draw():
	var viewport_size = get_viewport_rect().size

	# 绘制渐变背景
	draw_rect(Rect2(Vector2.ZERO, viewport_size), UITheme.BG_DARKEST, true)
	# 添加顶部渐变
	var gradient_rect = Rect2(0, 0, viewport_size.x, viewport_size.y * 0.4)
	draw_rect(gradient_rect, Color(0.08, 0.06, 0.15, 0.5), true)

	# 上方1/4：立绘区域（玩家+敌人）- 动态精灵渲染
	_draw_portrait_area()
	
	# 制胜一击文本（胜利待定期间显示，但不显示问号）
	if victory_pending and victory_kill_timer > 0 and not victory_kill_message.is_empty():
		var alpha: float = clampf(victory_kill_timer / 0.3, 0.0, 1.0)
		var msg_color := Color(1.0, 0.95, 0.3, alpha)
		var frame = _get_game_frame_rect()
		var cx: float = frame.position.x + frame.size.x * 0.5
		var cy: float = frame.position.y + frame.size.y * 0.45
		draw_string(UI_FONT, Vector2(cx - 80, cy), victory_kill_message,
			HORIZONTAL_ALIGNMENT_CENTER, 160, UITheme.FONT_SIZE_XL, msg_color)
		# 注：问号已移至胜利面板，此处不再绘制

	# 裂隙仪提示
	if controller and controller.equipment_system and controller.equipment_system.is_equipped(EquipmentSystem.EquipmentType.RIFT_METER):
		var cd = controller.equipment_system.get_rift_meter_cooldown()
		var rift_text = tr("UI_COMMON_SELECT")
		if cd > 0:
			rift_text = tr("UI_ROGUELIKECOMBAT_RIFT_1FS") % cd
		else:
			rift_text = tr("UI_COMBAT_RIFT_HINT")
		var frame = _get_game_frame_rect()
		draw_string(UI_FONT, Vector2(frame.position.x + 20, frame.position.y + frame.size.y - 20), rift_text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, UITheme.FONT_SIZE_SM, UITheme.TEXT_SECONDARY)

func _draw_mystery_rescue_dialogue(target: CanvasItem = self):
	# 绘制神秘人NPC对话框（像素风格）
	if not mystery_rescue_active or mystery_rescue_current_line >= mystery_rescue_lines.size():
		return
	var viewport_size = get_viewport_rect().size

	# 全屏半透明遮罩
	target.draw_rect(Rect2(Vector2.ZERO, viewport_size), Color(0.0, 0.0, 0.05, 0.75), true)

	# 对话框
	var dialog_w = min(420.0, viewport_size.x - 60)
	var dialog_h = 96.0
	var dialog_pos = Vector2((viewport_size.x - dialog_w) / 2, viewport_size.y * 0.72)
	if dialog_pos.y + dialog_h > viewport_size.y - 12:
		dialog_pos.y = viewport_size.y - dialog_h - 12

	# NPC立绘（npc4，同一人物2帧动画）
	var npc_size = Vector2(56, 84)
	var npc_pos = Vector2(dialog_pos.x - npc_size.x - 12, dialog_pos.y + dialog_h - npc_size.y)
	npc_pos.x = max(12.0, npc_pos.x)

	# 立绘框
	target.draw_rect(Rect2(npc_pos - Vector2(2, 2), npc_size + Vector2(4, 4)), Color(0.5, 0.4, 0.7), false, 2)
	if NPC_SPRITES:
		var rows = int(NPC_SPRITES.get_height() / NPC_TILE_SIZE.y)
		if rows > 0:
			# icons.js: npc48.npc4 = 4（第5行），同一人物使用该行的两帧
			var npc_row = min(4, rows - 1)
			var frame_col = int(Time.get_ticks_msec() / 450) % 2
			var region = Rect2(frame_col * NPC_TILE_SIZE.x, npc_row * NPC_TILE_SIZE.y, NPC_TILE_SIZE.x, NPC_TILE_SIZE.y)
			target.draw_texture_rect_region(NPC_SPRITES, Rect2(npc_pos, npc_size), region)
		else:
			target.draw_rect(Rect2(npc_pos, npc_size), Color(0.15, 0.12, 0.25), true)
	else:
		target.draw_rect(Rect2(npc_pos, npc_size), Color(0.15, 0.12, 0.25), true)

	# 对话框背景
	target.draw_rect(Rect2(dialog_pos, Vector2(dialog_w, dialog_h)), Color(0.08, 0.06, 0.14), true)
	target.draw_rect(Rect2(dialog_pos - Vector2(2, 2), Vector2(dialog_w + 4, dialog_h + 4)), Color(0.5, 0.4, 0.7), false, 2)

	# 名称标签
	var is_zh = Global.current_language == "zh"
	var name_text = tr("UI_ROGUELIKECOMBAT_UNKNOWN_2")
	target.draw_rect(Rect2(dialog_pos + Vector2(12, -14), Vector2(80, 18)), Color(0.15, 0.12, 0.25), true)
	target.draw_rect(Rect2(dialog_pos + Vector2(12, -14), Vector2(80, 18)), Color(0.5, 0.4, 0.7), false, 1)
	target.draw_string(UI_FONT, dialog_pos + Vector2(16, -1), name_text,
		HORIZONTAL_ALIGNMENT_LEFT, 72, 11, Color(0.8, 0.6, 1.0))

	# 对话文本
	var line = mystery_rescue_lines[mystery_rescue_current_line]
	target.draw_string(UI_FONT, dialog_pos + Vector2(20, 40), line,
		HORIZONTAL_ALIGNMENT_LEFT, int(dialog_w - 40), 14, Color(0.90, 0.88, 0.85))
	
	# 继续提示（底部右侧）
	var continue_text = tr("UI_COMBAT_CONTINUE_HINT")
	var continue_x = dialog_pos.x + dialog_w - 100
	var continue_y = dialog_pos.y + dialog_h - 16
	target.draw_string(UI_FONT, Vector2(continue_x, continue_y), continue_text,
		HORIZONTAL_ALIGNMENT_RIGHT, 90, 11, Color(0.7, 0.65, 0.75, 0.8))

func _draw_portrait_area():
	# 绘制上方立绘区域
	var frame = _get_game_frame_rect()
	var portrait_height = frame.size.y / 4
	
	# 背景面板
	var panel_rect = Rect2(frame.position.x, frame.position.y, frame.size.x, portrait_height)
	draw_rect(panel_rect, UITheme.BG_DARK, true)
	# 底部分隔线（带渐变感）
	draw_line(Vector2(frame.position.x, frame.position.y + portrait_height), Vector2(frame.position.x + frame.size.x, frame.position.y + portrait_height), 
		UITheme.BORDER_MEDIUM, 2)
	draw_line(Vector2(frame.position.x, frame.position.y + portrait_height + 1), Vector2(frame.position.x + frame.size.x, frame.position.y + portrait_height + 1), 
		Color(0, 0, 0, 0.5), 1)
	
	# 玩家区域（左侧）
	var player_panel_pos = frame.position + Vector2(20, 15)
	_draw_player_portrait(player_panel_pos)
	
	# 敌人区域（右侧）
	var enemy_panel_start = frame.position.x + frame.size.x - 300
	_draw_enemies_portrait(Vector2(enemy_panel_start, frame.position.y + 15))

func _draw_player_portrait(pos: Vector2):
	# 绘制玩家立绘和状态
	var panel_size = Vector2(200, 130)
	
	# 面板背景（带装饰）
	UITheme.draw_decorated_panel(self, Rect2(pos, panel_size), 
		UITheme.BG_MEDIUM, UITheme.ACCENT_PRIMARY, false)
	
	# 英雄精灵
	var avatar_pos = pos + Vector2(8, 6)
	var avatar_size = Vector2(50, 66)
	
	# 使用精灵管理器绘制英雄
	var frame = int(Time.get_ticks_msec() / 300) % 4
	RoguelikeSpriteManager.draw_hero_sprite(self, avatar_pos, avatar_size, "down", frame)
	
	# 头像边框
	draw_rect(Rect2(avatar_pos - Vector2(2, 2), avatar_size + Vector2(4, 4)), UITheme.BORDER_ACCENT, false, 2)
	
	# 名称（使用本地化）
	var player_name = tr(PLAYER_NAME_KEY)
	draw_string(UI_FONT, pos + Vector2(70, 24), player_name, 
		HORIZONTAL_ALIGNMENT_LEFT, -1, UITheme.FONT_SIZE_LG, UITheme.TEXT_PRIMARY)
	
	# 血量条
	var hp_bar_pos = pos + Vector2(70, 38)
	var hp_bar_width = 110
	var hp_bar_height = 16
	var hp_percentage = float(player_health) / float(player_max_health)
	
	UITheme.draw_progress_bar(self, hp_bar_pos, hp_bar_width, hp_bar_height,
		hp_percentage, Color(0.25, 0.08, 0.08), UITheme.ACCENT_DANGER, UITheme.BORDER_LIGHT)
	
	# 护甲叠加显示
	if player_shield > 0:
		var shield_ratio = float(player_shield) / float(player_max_health)
		var shield_width = min(hp_bar_width * shield_ratio, hp_bar_width - hp_bar_width * hp_percentage)
		if shield_width > 0:
			draw_rect(Rect2(hp_bar_pos + Vector2(hp_bar_width * hp_percentage, 0), 
				Vector2(shield_width, hp_bar_height)), Color(0.3, 0.6, 0.9, 0.85), true)
	
	# 血量文字
	draw_string(UI_FONT, hp_bar_pos + Vector2(6, 14), "%d/%d" % [player_health, player_max_health], 
		HORIZONTAL_ALIGNMENT_LEFT, -1, UITheme.FONT_SIZE_SM, UITheme.TEXT_PRIMARY)
	
	# 护甲值显示（紧贴生命条下方）
	var info_y = hp_bar_pos.y + hp_bar_height + 4
	if player_shield > 0:
		var armor_text = (tr("UI_ROGUELIKECOMBAT_ARMOR_NUM")) % player_shield
		draw_string(UI_FONT, Vector2(hp_bar_pos.x, info_y + 12), armor_text, 
			HORIZONTAL_ALIGNMENT_LEFT, hp_bar_width, UITheme.FONT_SIZE_SM, UITheme.ACCENT_PRIMARY)
		info_y += 16
	
	# 攻击力
	var effective_attack = _get_effective_player_attack_power()
	var atk_text = (tr("UI_ROGUELIKECOMBAT_ATK_NUM_OR_LINE")) % effective_attack
	draw_string(UI_FONT, Vector2(hp_bar_pos.x, info_y + 12), atk_text, 
		HORIZONTAL_ALIGNMENT_LEFT, hp_bar_width, UITheme.FONT_SIZE_SM, UITheme.ACCENT_WARNING)
	
	# 金币
	var gold_text = (tr("UI_ROGUELIKECOMBAT_GOLD_NUM")) % player_gold
	draw_string(UI_FONT, Vector2(hp_bar_pos.x, info_y + 28), gold_text, 
		HORIZONTAL_ALIGNMENT_LEFT, hp_bar_width, UITheme.FONT_SIZE_SM, Color(1.0, 0.85, 0.2))


func _draw_enemies_portrait(pos: Vector2):
	# 绘制敌人立绘（支持多敌人）
	var enemy_card_width = 95
	var enemy_card_height = 130
	var spacing = 8
	var frame = _get_game_frame_rect()
	enemy_card_rects.clear()
	_remove_dead_enemies()
	var is_bat_swarm = _is_bat_swarm()
	var max_draw = enemies.size()
	if is_bat_swarm:
		max_draw = min(3, enemies.size())
		if target_index >= max_draw:
			target_index = _get_first_alive_enemy_index()
	
	for i in range(max_draw):
		var enemy = enemies[i]
		var card_pos = pos + Vector2(i * (enemy_card_width + spacing), 0)
		var min_x = frame.position.x
		var max_x = frame.position.x + frame.size.x - enemy_card_width
		card_pos.x = clamp(card_pos.x, min_x, max_x)
		enemy_card_rects.append(Rect2(card_pos, Vector2(enemy_card_width, enemy_card_height)))
		
		# 边框颜色：根据意图/选中
		var accent_color = UITheme.BORDER_MEDIUM
		if enemy.intent == "attack":
			accent_color = UITheme.ACCENT_DANGER
		elif enemy.intent == "defend":
			accent_color = UITheme.ACCENT_PRIMARY
		elif enemy.intent == "merge":
			accent_color = Color(0.7, 0.4, 0.9)
		
		var is_selected = (i == target_index)
		
		# 选中的敌人不再改变边框颜色，保持意图颜色
		# 使用卡片绘制
		UITheme.draw_card(self, Rect2(card_pos, Vector2(enemy_card_width, enemy_card_height)), 
			is_selected, accent_color)
		
		# 选中指示器：在卡片上方绘制向下的三角形箭头
		if is_selected:
			var tri_size = 10.0
			var tri_cx = card_pos.x + enemy_card_width / 2.0
			var tri_top_y = card_pos.y - tri_size - 3.0
			var tri_points = PackedVector2Array([
				Vector2(tri_cx - tri_size, tri_top_y),
				Vector2(tri_cx + tri_size, tri_top_y),
				Vector2(tri_cx, tri_top_y + tri_size)
			])
			draw_colored_polygon(tri_points, UITheme.ACCENT_SECONDARY)
			# 三角形边框线
			draw_polyline(PackedVector2Array([
				Vector2(tri_cx - tri_size, tri_top_y),
				Vector2(tri_cx + tri_size, tri_top_y),
				Vector2(tri_cx, tri_top_y + tri_size),
				Vector2(tri_cx - tri_size, tri_top_y)
			]), UITheme.TEXT_PRIMARY, 1.5)
		
		# 敌人精灵 (使用精灵管理器)
		var avatar_pos = card_pos + Vector2(enemy_card_width / 2 - 22, 8)
		var avatar_size = Vector2(44, 44)
		var anim_frame = int(Time.get_ticks_msec() / 300) % 4
		
		# 使用精灵管理器绘制敌人立绘
		RoguelikeSpriteManager.draw_enemy_sprite(self, enemy.name, avatar_pos, avatar_size, anim_frame)
		
		# 精灵边框
		draw_rect(Rect2(avatar_pos - Vector2(1, 1), avatar_size + Vector2(2, 2)), UITheme.BORDER_LIGHT, false, 1)
		
		# 名称（使用映射后的显示名称）
		var display_name = RoguelikeSpriteManager.get_mapped_enemy_name(enemy.name)
		if is_bat_swarm and i == max_draw - 1 and enemies.size() > max_draw:
			var stack_count = enemies.size() - (max_draw - 1)
			display_name += " x" + str(stack_count)
		draw_string(UI_FONT, card_pos + Vector2(5, 64), display_name, 
			HORIZONTAL_ALIGNMENT_LEFT, enemy_card_width - 10, UITheme.FONT_SIZE_SM, 
			UITheme.TEXT_PRIMARY)
		
		# 血量条
		var hp_bar_pos = card_pos + Vector2(6, 72)
		var hp_bar_width = enemy_card_width - 12
		var hp_bar_height = 12
		var hp_percentage = float(enemy.health) / float(enemy.max_health)
		
		UITheme.draw_progress_bar(self, hp_bar_pos, hp_bar_width, hp_bar_height,
			hp_percentage, Color(0.15, 0.2, 0.15), UITheme.ACCENT_SUCCESS, UITheme.BORDER_LIGHT)
		draw_string(UI_FONT, hp_bar_pos + Vector2(3, 10), str(enemy.health), 
			HORIZONTAL_ALIGNMENT_LEFT, -1, UITheme.FONT_SIZE_XS, UITheme.TEXT_PRIMARY)
		
		# 敌人护甲叠加显示
		if enemy.has("shield") and enemy.shield > 0:
			var shield_ratio = float(enemy.shield) / float(enemy.max_health)
			var shield_width = min(hp_bar_width * shield_ratio, hp_bar_width - hp_bar_width * hp_percentage)
			if shield_width > 0:
				draw_rect(Rect2(hp_bar_pos + Vector2(hp_bar_width * hp_percentage, 0), 
					Vector2(shield_width, hp_bar_height)), Color(0.3, 0.6, 0.9, 0.85), true)
		
		# 护甲值/意图/冷却显示在血条下方（统一行高）
		# 血条底部Y=72+12=84，增加4像素间距从88开始
		var info_y_offset = 96  # 调大间距避免重叠
		if enemy.has("shield") and enemy.shield > 0:
			draw_string(UI_FONT, card_pos + Vector2(6, info_y_offset), "🛡 %d" % enemy.shield,
				HORIZONTAL_ALIGNMENT_LEFT, -1, UITheme.FONT_SIZE_XS, UITheme.ACCENT_PRIMARY)
			info_y_offset += 11
		
		# 合并意图显示（意图+数值+护甲获取）
		var intent_text = tr("UI_COMMON_SELECT")
		var intent_color = UITheme.TEXT_MUTED
		if enemy.intent == "attack":
			var is_zh = Global.current_language == "zh"
			intent_text = (tr("UI_ROGUELIKECOMBAT_ATK_NUM")) % enemy.damage
			intent_color = UITheme.ACCENT_DANGER
		elif enemy.intent == "defend":
			var is_zh = Global.current_language == "zh"
			var shield_gain = enemy.get("shield_gain", 10)
			intent_text = (tr("UI_ROGUELIKECOMBAT_DEF_PLUSNUM")) % shield_gain
			intent_color = UITheme.ACCENT_PRIMARY
		elif enemy.intent == "merge":
			var is_zh = Global.current_language == "zh"
			intent_text = tr("UI_COMBAT_INTENT_MERGE")
			intent_color = Color(0.8, 0.6, 1.0)
		draw_string(UI_FONT, card_pos + Vector2(6, info_y_offset), intent_text, 
			HORIZONTAL_ALIGNMENT_LEFT, -1, UITheme.FONT_SIZE_XS, intent_color)
		info_y_offset += 11
		
		# 行为冷却显示
		var cooldown_text = tr("UI_COMMON_SELECT")
		var cooldown_color = UITheme.TEXT_MUTED
		if enemy.acted_this_turn:
			var is_zh = Global.current_language == "zh"
			cooldown_text = tr("UI_COMBAT_COOLDOWN_DONE")
			cooldown_color = UITheme.ACCENT_SUCCESS
		else:
			cooldown_text = tr("UI_ROGUELIKECOMBAT_1FS") % max(enemy.cooldown_timer, 0.0)
			if enemy.cooldown_timer <= 0.8:
				cooldown_color = UITheme.ACCENT_WARNING
		draw_string(UI_FONT, card_pos + Vector2(6, info_y_offset), cooldown_text, 
			HORIZONTAL_ALIGNMENT_LEFT, -1, UITheme.FONT_SIZE_XS, cooldown_color)

func _update_renderer_layout():
	# 让俄罗斯方块主模块固定在左下角，必要时缩放
	if renderer == null:
		return
	var frame = _get_game_frame_rect()
	var portrait_height = frame.size.y / 4
	var grid_width = GameConfig.GRID_WIDTH * GameConfig.CELL_SIZE
	var grid_height = GameConfig.GRID_HEIGHT * GameConfig.CELL_SIZE
	var available_height = max(1.0, frame.size.y - portrait_height - 40)
	var scale_factor = min(1.0, available_height / grid_height)
	# 适当缩放但不小于0.7，且上限0.9
	scale_factor = clamp(scale_factor, 0.7, 0.9)
	renderer.scale = Vector2(scale_factor, scale_factor)
	
	# 左下角对齐
	var desired_x = frame.position.x + 20.0
	var desired_y = frame.position.y + frame.size.y - grid_height * scale_factor - 20.0
	# 不允许侵入上方1/4区域
	var min_top = frame.position.y + portrait_height + 10.0
	var top_y = desired_y
	if top_y < min_top:
		desired_y = min_top
	# 通过移动渲染器抵消居中偏移
	renderer.position = Vector2(desired_x, desired_y) - Vector2(GameConfig.GRID_OFFSET_X, GameConfig.GRID_OFFSET_Y) * scale_factor

func _input(event: InputEvent):
	# 神秘人救援期间跳过输入（Enter手动推进）
	if mystery_rescue_active:
		if event is InputEventKey and event.pressed and not event.echo and event.is_action_pressed("ui_accept"):
			mystery_rescue_current_line += 1
			if mystery_rescue_current_line >= mystery_rescue_lines.size():
				_mystery_rescue_finish()
			if mystery_overlay:
				mystery_overlay.queue_redraw()
		return
	
	# 战斗模式切换 / 时停选敌
	if event is InputEventKey and event.pressed and not is_paused and not is_game_over:
		if event.keycode == KEY_1:
			combat_mode = CombatMode.ATTACK
			queue_redraw()
			return
		elif event.keycode == KEY_2:
			combat_mode = CombatMode.DEFEND
			queue_redraw()
			return
		elif event.keycode == KEY_T:
			_toggle_target_select()
			queue_redraw()
			return
		elif event.keycode == KEY_C:
			if controller and controller.equipment_system:
				if controller.equipment_system.try_activate_rift_meter(controller.grid_manager):
					renderer.queue_redraw()
					queue_redraw()
			return

	# 选敌输入（时停中）
	if target_select_active and not is_paused and not is_game_over:
		if event.is_action_pressed("ui_left") or (event is InputEventKey and event.keycode == KEY_A):
			_select_target_relative(-1)
			return
		elif event.is_action_pressed("ui_right") or (event is InputEventKey and event.keycode == KEY_D):
			_select_target_relative(1)
			return
		elif event.is_action_pressed("ui_up") or (event is InputEventKey and event.keycode == KEY_W):
			_select_target_relative(-1)
			return
		elif event.is_action_pressed("ui_down") or (event is InputEventKey and event.keycode == KEY_S):
			_select_target_relative(1)
			return
		elif event.is_action_pressed("ui_accept"):
			target_confirmed = true
			return
		elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_select_target_by_mouse(event.position)
			return

	# 将输入事件转发给InputHandler
	if input_handler:
		input_handler.handle_input(event, is_game_over, is_paused)

func _on_lines_cleared(damage: int):
	# 消除行时触发
	var lines = damage / player_attack_power if player_attack_power > 0 else 1
	
	if combat_mode == CombatMode.ATTACK:
		# 攻击模式：对敌人造成伤害
		var actual_damage = _apply_player_damage_multiplier(damage)
		_deal_damage_to_enemies(actual_damage)
	else:
		# 防御模式：获得护甲（每行 = 基础防御 + 商店加成 + 铁盾 + 故障增幅）
		var defense_per_line = BASE_DEFENSE_PER_LINE + shop_def_bonus
		# 铁盾：每行额外+5
		if controller and controller.equipment_system:
			defense_per_line += controller.equipment_system.get_iron_shield_bonus()
		# 故障增幅器：基础防御+15%
		var faulty_bonus = 0
		if controller and controller.equipment_system:
			faulty_bonus = controller.equipment_system.get_faulty_amplifier_rogue_def_bonus(BASE_DEFENSE_PER_LINE)
			defense_per_line += faulty_bonus
		var shield_gain = lines * defense_per_line
		player_shield += shield_gain
		print(tr("LOG_COMBAT_SHIELD_GAIN") % [shield_gain, lines, defense_per_line])
		# 防御模式不检查胜利，等待攻击模式再检查
	
	player_acted = true

func _deal_damage_to_enemies(total_damage: int):
	# 对选中敌人造成伤害（单体）
	var target = _get_target_enemy()
	if target == null:
		return
	
	var remaining_damage = total_damage
	if target.has("shield") and target.shield > 0:
		var absorbed = min(target.shield, remaining_damage)
		target.shield -= absorbed
		remaining_damage -= absorbed
		print(tr("LOG_COMBAT_SHIELD_ABSORB") % [target.name, absorbed])
	
	if remaining_damage > 0:
		target.health -= remaining_damage
		if target.health <= 0:
			target.health = 0
			print(tr("LOG_COMBAT_ENEMY_DEFEATED") % [target.name])
	
	print(tr("LOG_COMBAT_DAMAGE_DEALT") % [total_damage, target.name])
	_remove_dead_enemies()
	
	# 检查史莱姆王分裂
	_check_slime_lord_split()
	
	# 检查胜利
	_check_victory()

func _start_turn(is_first: bool = false):
	# 开始新回合：重置计时与敌人冷却
	if not is_first:
		turn_number += 1
	turn_timer = TURN_TIMEOUT
	player_acted = false
	_randomize_enemy_intents()
	_reset_enemy_turn_state()

func _reset_enemy_turn_state():
	for enemy in enemies:
		enemy.acted_this_turn = false
		enemy.cooldown_timer = _roll_enemy_cooldown(enemy)

func _roll_enemy_cooldown(enemy: Dictionary) -> float:
	var base = enemy.get("cooldown_base", 5.5)
	var variance = enemy.get("cooldown_variance", 0.3)
	var cooldown = (base + randf_range(-variance, variance)) * ENEMY_COOLDOWN_MULTIPLIER
	if controller and controller.equipment_system:
		cooldown *= controller.equipment_system.get_enemy_cooldown_multiplier(enemy.get("name", ""), enemy.get("intent", ""))
	return cooldown

func _update_enemy_cooldowns(delta: float):
	# 更新敌人攻击冷却，冷却结束则行动一次
	for enemy in enemies:
		if enemy.health <= 0:
			continue
		if enemy.acted_this_turn:
			continue
		enemy.cooldown_timer -= delta
		if enemy.cooldown_timer <= 0:
			_enemy_act(enemy, false)
			enemy.acted_this_turn = true
	
	if _all_enemies_acted():
		_finish_turn()

func _force_end_turn():
	# 回合超时：所有未行动敌人强制行动一次
	_force_enemies_act()
	_finish_turn()

func _force_enemies_act():
	for enemy in enemies:
		if enemy.health <= 0:
			continue
		if enemy.acted_this_turn:
			continue
		_enemy_act(enemy, true)
		enemy.acted_this_turn = true

func _enemy_act(enemy: Dictionary, forced: bool):
	if enemy.intent == "attack":
		var damage = 3 if enemy.name == "大蝙蝠" else enemy.damage
		# 护甲吸收伤害
		if player_shield > 0:
			var absorbed = min(player_shield, damage)
			player_shield -= absorbed
			damage -= absorbed
			print(tr("LOG_COMBAT_SHIELD_ABSORB_SIMPLE") % [absorbed])
		
		if damage > 0:
			player_health -= damage
			print(tr("LOG_COMBAT_ENEMY_ATTACK") % [enemy.name, damage])
	elif enemy.intent == "defend":
		# 敌人防御：获得护甲并小幅蓄力
		enemy.shield += 8
		enemy.damage += 2
		print(tr("LOG_COMBAT_ENEMY_DEFEND") % [enemy.name, 8])
	elif enemy.intent == "merge":
		if enemy.name == "绿色史莱姆" and _get_alive_slime_count() < 2:
			enemy.intent = "attack"
			_enemy_act(enemy, forced)
			return
		if enemy.name == "大蝙蝠" and bat_merge_done:
			enemy.intent = "attack"
			_enemy_act(enemy, forced)
			return
		# 合体意图：本回合不行动，蓄势
		print(tr("LOG_COMBAT_ENEMY_MERGE_CHARGE") % [enemy.name])
	
	# 检查失败
	if player_health <= 0:
		player_health = 0
		_defeat()

func _all_enemies_acted() -> bool:
	for enemy in enemies:
		if enemy.health <= 0:
			continue
		if not enemy.acted_this_turn:
			return false
	return true

func _finish_turn():
	# 结束当前回合并进入下一回合
	# 检查史莱姆合体
	_check_slime_merge()
	
	# 检查大蝙蝠合体为吸血鬼（回合13+）
	_check_bat_merge()
	
	# 护甲衰减
	player_shield = max(0, player_shield - 5)
	
	# 开始下一回合
	_start_turn()

func _check_slime_merge():
	# 检查史莱姆是否应该合体
	if slime_lord_split_done:
		return
	if turn_number < slime_merge_turns:
		return
	
	# 检查是否全是绿色史莱姆
	var slime_count = 0
	var total_health = 0
	var total_damage = 0
	
	for enemy in enemies:
		if enemy.name == "绿色史莱姆" and enemy.health > 0:
			slime_count += 1
			total_health += enemy.health
			total_damage += enemy.damage
	
	if slime_count >= 2:
		# 合体成史莱姆王
		enemies.clear()
		enemies.append({
			"name": "史莱姆王",
			"health": total_health * 2,
			"max_health": total_health * 2,
			"damage": total_damage + 10,
			"shield": 0,
			"gold_reward": _get_default_gold_reward("史莱姆王"),
			"intent": "attack",
			"cooldown_base": 5.2,
			"cooldown_variance": 0.4,
			"cooldown_timer": 0.0,
			"acted_this_turn": false
		})
		print(tr("LOG_COMBAT_SLIME_MERGED"))
		slime_merge_turns = 999  # 防止再次触发

func _check_slime_lord_split():
	# 检查史莱姆王是否应该分裂（HP ≤ 50%）
	if slime_lord_split_done:
		return
	
	for i in range(enemies.size()):
		var enemy = enemies[i]
		if enemy.name == "史莱姆王" and enemy.health > 0:
			var hp_ratio = float(enemy.health) / float(enemy.max_health)
			if hp_ratio <= 0.5:
				# 触发分裂！
				var current_hp = enemy.health
				var hp_per_slime = int(ceil(float(current_hp) / 3.0))
				
				# 移除史莱姆王
				enemies.remove_at(i)
				
				# 生成2个绿色史莱姆 + 1个红色史莱姆
				for j in range(2):
					enemies.append({
						"name": "绿色史莱姆",
						"health": hp_per_slime,
						"max_health": hp_per_slime,
						"damage": 8,
						"shield": 0,
						"gold_reward": _get_default_gold_reward("绿色史莱姆"),
						"intent": "attack",
						"cooldown_base": 4.5,
						"cooldown_variance": 0.3,
						"cooldown_timer": 1.5,  # 分裂后1.5秒冷却
						"acted_this_turn": false
					})
				enemies.append({
					"name": "红色史莱姆",
					"health": hp_per_slime,
					"max_health": hp_per_slime,
					"damage": 10,
					"shield": 0,
					"gold_reward": _get_default_gold_reward("红色史莱姆"),
					"intent": "attack",
					"cooldown_base": 4.2,
					"cooldown_variance": 0.3,
					"cooldown_timer": 1.5,  # 分裂后1.5秒冷却
					"acted_this_turn": false
				})
				
				slime_lord_split_done = true
				slime_merge_turns = 999
				target_index = _get_first_alive_enemy_index()
				print(tr("LOG_COMBAT_SLIME_SPLIT") % [hp_per_slime])
				break

func _check_bat_merge():
	# 检查大蝙蝠是否应该合体为吸血鬼（回合 >= bat_merge_turn）
	if bat_merge_done:
		return
	if turn_number < bat_merge_turn:
		return
	
	# 统计存活的大蝙蝠
	var alive_bats = 0
	var total_bat_health = 0
	for enemy in enemies:
		if enemy.name == "大蝙蝠" and enemy.health > 0:
			alive_bats += 1
			total_bat_health += enemy.health
	
	if alive_bats == 0:
		return
	
	# 合体为吸血鬼
	# 基础属性：hp444, atk199（从enemys.js）
	# 每缺少一只蝙蝠（相对于8只初始），属性-5%
	var initial_bat_count = 8
	var missing_bats = initial_bat_count - alive_bats
	var penalty_ratio = 1.0 - (missing_bats * 0.05)
	penalty_ratio = max(penalty_ratio, 0.2)  # 最低20%
	
	# 吸血鬼增强：基础HP 500（+250），基础DEF 5
	var vampire_hp = int(round(500 * penalty_ratio))
	var vampire_damage = int(round(22 * penalty_ratio))
	var vampire_shield = int(round(5 * penalty_ratio))
	
	# 移除所有大蝙蝠
	for i in range(enemies.size() - 1, -1, -1):
		if enemies[i].name == "大蝙蝠":
			enemies.remove_at(i)
	
	# 生成吸血鬼
	enemies.append({
		"name": "吸血鬼",
		"health": vampire_hp,
		"max_health": vampire_hp,
		"damage": vampire_damage,
		"shield": vampire_shield,
		"gold_reward": _get_default_gold_reward("吸血鬼"),
		"intent": "attack",
		"cooldown_base": 6.2,
		"cooldown_variance": 0.5,
		"cooldown_timer": 0.0,
		"acted_this_turn": false
	})
	
	bat_merge_done = true
	target_index = _get_first_alive_enemy_index()
	print(tr("LOG_COMBAT_BAT_MERGE") % [alive_bats, missing_bats, missing_bats * 5, vampire_hp, vampire_damage, vampire_shield])

func _randomize_enemy_intents():
	# 随机化敌人下回合意图
	var should_merge = _should_slime_merge_intent()
	var should_bat_merge = _should_bat_merge_intent()
	for enemy in enemies:
		if enemy.health <= 0:
			continue
		if should_merge and enemy.name == "绿色史莱姆":
			enemy.intent = "merge"
			continue
		if should_bat_merge and enemy.name == "大蝙蝠":
			enemy.intent = "merge"
			continue
		if enemy.name == "大蝙蝠":
			enemy.intent = "attack"
			continue
		# 70%攻击，30%防御
		if randf() < 0.7:
			enemy.intent = "attack"
		else:
			enemy.intent = "defend"

func _should_slime_merge_intent() -> bool:
	if slime_lord_split_done:
		return false
	if turn_number < slime_merge_turns:
		return false
	return _get_alive_slime_count() >= 2

func _should_bat_merge_intent() -> bool:
	if bat_merge_done:
		return false
	# 在合体回合前1回合显示merge意图预警
	if turn_number < bat_merge_turn - 1:
		return false
	return _get_alive_bat_count() > 0

func _get_alive_bat_count() -> int:
	var count = 0
	for enemy in enemies:
		if enemy.name == "大蝙蝠" and enemy.health > 0:
			count += 1
	return count

func _is_bat_swarm() -> bool:
	if enemies.size() <= 3:
		return false
	for enemy in enemies:
		if enemy.name != "大蝙蝠":
			return false
	return true

func _get_alive_slime_count() -> int:
	var slime_count = 0
	for enemy in enemies:
		if enemy.name == "绿色史莱姆" and enemy.health > 0:
			slime_count += 1
	return slime_count

func _toggle_target_select():
	if target_select_active:
		# 退出时停
		target_select_active = false
		target_confirmed = false
		return
	# 进入时停选敌
	target_select_active = true
	target_confirmed = false
	if target_index < 0:
		target_index = _get_first_alive_enemy_index()

func _select_target_relative(step: int):
	if enemies.is_empty():
		return
	var alive_indices = _get_alive_enemy_indices()
	if alive_indices.is_empty():
		return
	if target_index < 0:
		target_index = alive_indices[0]
		return
	var current_pos = alive_indices.find(target_index)
	if current_pos == -1:
		current_pos = 0
	var next_pos = (current_pos + step) % alive_indices.size()
	if next_pos < 0:
		next_pos = alive_indices.size() - 1
	target_index = alive_indices[next_pos]
	target_confirmed = false
	queue_redraw()

func _select_target_by_mouse(mouse_pos: Vector2):
	for i in range(enemy_card_rects.size()):
		if enemy_card_rects[i].has_point(mouse_pos):
			if enemies[i].health > 0:
				target_index = i
				target_confirmed = true
				queue_redraw()
				return

func _get_first_alive_enemy_index() -> int:
	for i in range(enemies.size()):
		if enemies[i].health > 0:
			return i
	return -1

func _get_alive_enemy_indices() -> Array:
	var indices: Array = []
	for i in range(enemies.size()):
		if enemies[i].health > 0:
			indices.append(i)
	return indices

func _get_alive_enemy_count() -> int:
	var count = 0
	for enemy in enemies:
		if enemy.health > 0:
			count += 1
	return count

func _get_target_enemy():
	if enemies.is_empty():
		return null
	if target_index < 0 or target_index >= enemies.size() or enemies[target_index].health <= 0:
		target_index = _get_first_alive_enemy_index()
	if target_index < 0:
		return null
	return enemies[target_index]

func _check_victory():
	# 检查是否胜利
	_remove_dead_enemies()
	var all_dead = true
	for enemy in enemies:
		if enemy.health > 0:
			all_dead = false
			break
	
	if all_dead and not victory_pending:
		if controller:
			controller.game_over = true
		_victory()

func _victory():
	# 胜利
	victory_pending = true
	# 移除战斗画面的制胜一击文本，直接显示结算UI
	victory_kill_message = ""
	victory_kill_question_mark = false
	# 制胜一击消除信息
	var is_zh: bool = Global.current_language == "zh"
	victory_kill_timer = 1.5
	print(tr("LOG_COMBAT_VICTORY"))
	_schedule_victory_reward()

func _mystery_rescue_finish():
	# 神秘人救援结束：击杀吸血鬼，以特殊胜利结算
	mystery_rescue_active = false
	# 击杀所有敌人
	for enemy in enemies:
		enemy.health = 0
	enemies.clear()
	# 恢复少量HP
	player_health = max(player_health, int(player_max_health * 0.2))
	print(tr("LOG_COMBAT_MYSTERY_VAMP_HEAL") % [player_health])
	# 以胜利结算（带特殊标记）
	victory_pending = true
	if controller:
		controller.game_over = true
	var is_zh: bool = Global.current_language == "zh"
	victory_kill_question_mark = true
	victory_kill_timer = 1.2
	_schedule_victory_reward()

# 神秘人救援机制
var mystery_rescue_active: bool = false  # 是否正在播放神秘人救援
var mystery_rescue_phase: int = 0  # 对话阶段
var mystery_rescue_timer: float = 0.0
var mystery_rescue_lines: Array = []
var mystery_rescue_current_line: int = 0

const MYSTERY_LINE_KEY = "UI_ROGUELIKECOMBAT_MYSTERY_LINE_1"

func _defeat():
	# 检查是否在吸血鬼战斗中 → 触发神秘人救援
	var fighting_vampire = false
	for enemy in enemies:
		if enemy.name == "吸血鬼" and enemy.health > 0:
			fighting_vampire = true
			break
	
	if fighting_vampire and not mystery_rescue_active:
		# 触发神秘人救援
		mystery_rescue_active = true
		mystery_rescue_phase = 0
		mystery_rescue_timer = 0.0
		mystery_rescue_lines = [tr(MYSTERY_LINE_KEY)]
		mystery_rescue_current_line = 0
		player_health = 1  # 保持1HP存活
		is_game_over = false  # 暂不结束
		print(tr("LOG_COMBAT_MYSTERY_TRIGGER"))
		queue_redraw()
		return
	
	# 正常失败
	is_game_over = true
	print(tr("LOG_COMBAT_DEFEAT"))
	battle_ended.emit(false)
	_show_game_over_menu(false)

func _show_victory_reward():
	# 清除战斗画面的制胜一击文本，避免与胜利面板重叠
	victory_kill_message = ""
	victory_kill_timer = 0.0
	queue_redraw()
	
	if victory_panel:
		victory_panel.queue_free()
		victory_panel = null
	
	var panel = Panel.new()
	panel.name = "VictoryRewardPanel"
	panel.size = Vector2(360, 260)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(panel)
	panel.position = get_viewport_rect().size / 2 - panel.size / 2
	
	# 应用主题样式
	var panel_style = UITheme.create_panel_style(UITheme.BG_MEDIUM, UITheme.ACCENT_SUCCESS, 
		UITheme.CORNER_LG, UITheme.BORDER_NORMAL)
	panel.add_theme_stylebox_override("panel", panel_style)

	var vbox = VBoxContainer.new()
	vbox.anchor_right = 1.0
	vbox.anchor_bottom = 1.0
	vbox.offset_left = UITheme.SPACING_MD
	vbox.offset_top = UITheme.SPACING_MD
	vbox.offset_right = -UITheme.SPACING_MD
	vbox.offset_bottom = -UITheme.SPACING_MD
	vbox.add_theme_constant_override("separation", UITheme.SPACING_MD)
	panel.add_child(vbox)

	var title = Label.new()
	# 如果是神秘救场后的胜利，添加问号（问号紧贴标题右侧，类比主标题的 alpha 标签）
	if victory_kill_question_mark:
		# 用 HBoxContainer 将标题和问号排在同一行
		var title_hbox = HBoxContainer.new()
		title_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
		title_hbox.add_theme_constant_override("separation", 0)
		vbox.add_child(title_hbox)
		# 标题文本
		var title_base = tr("UI_TITLE_VICTORY")
		title.text = title_base
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		title.add_theme_font_override("font", UI_FONT)
		title.add_theme_font_size_override("font_size", UITheme.FONT_SIZE_XL)
		title.add_theme_color_override("font_color", UITheme.ACCENT_SUCCESS)
		title_hbox.add_child(title)
		# 问号紧贴标题右侧（大号、红色、微旋转）
		var q_label = Label.new()
		q_label.text = tr("UI_ROGUELIKECOMBAT_UNKNOWN")
		q_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		q_label.add_theme_font_override("font", UI_FONT)
		q_label.add_theme_font_size_override("font_size", int(UITheme.FONT_SIZE_XL * 1.6))
		q_label.add_theme_color_override("font_color", Color(1.0, 0.15, 0.15))
		q_label.rotation_degrees = 12.0
		q_label.pivot_offset = Vector2(6, 14)
		title_hbox.add_child(q_label)
	else:
		title.text = tr("UI_TITLE_VICTORY")
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.add_theme_font_override("font", UI_FONT)
		title.add_theme_font_size_override("font_size", UITheme.FONT_SIZE_XL)
		title.add_theme_color_override("font_color", UITheme.ACCENT_SUCCESS)
		vbox.add_child(title)
	
	var sep = HSeparator.new()
	sep.add_theme_constant_override("separation", UITheme.SPACING_SM)
	sep.add_theme_color_override("separator", UITheme.BORDER_MEDIUM)
	vbox.add_child(sep)

	var summary = Label.new()
	var is_zh_summary = Global.current_language == "zh"
	if is_zh_summary:
		summary.text = tr("UI_COMBAT_VICTORY_SUMMARY") % [total_lines_cleared, total_score, battle_gold_earned]
	else:
		summary.text = tr("UI_ROGUELIKECOMBAT_LINES_CLEARED_NUM_NBATTLE_SCORE_NUM_NGOLD_EARNED_PLUSNUM") % [total_lines_cleared, total_score, battle_gold_earned]
	summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	summary.add_theme_font_override("font", UI_FONT)
	summary.add_theme_font_size_override("font_size", UITheme.FONT_SIZE_MD)
	summary.add_theme_color_override("font_color", UITheme.TEXT_PRIMARY)
	vbox.add_child(summary)

	var reward = Label.new()
	reward.text = tr("UI_COMBAT_REWARD_CONTINUE")
	reward.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reward.add_theme_font_override("font", UI_FONT)
	reward.add_theme_font_size_override("font_size", UITheme.FONT_SIZE_SM)
	reward.add_theme_color_override("font_color", UITheme.ACCENT_SECONDARY)
	vbox.add_child(reward)
	
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, UITheme.SPACING_SM)
	vbox.add_child(spacer)

	var btn = Button.new()
	btn.text = tr("UI_COMMON_CONTINUE")
	btn.pressed.connect(_on_victory_continue)
	UITheme.apply_button_theme(btn)
	vbox.add_child(btn)

	victory_panel = panel
	queue_redraw()
	victory_reward_scheduled = false

func _schedule_victory_reward():
	if victory_reward_scheduled:
		return
	victory_reward_scheduled = true
	get_tree().create_timer(0.3).timeout.connect(func():
		# 延迟设置 is_game_over，确保消除动画已渲染
		is_game_over = true
		if victory_pending:
			_show_victory_reward()
	)

func _on_victory_continue():
	if victory_panel:
		victory_panel.queue_free()
		victory_panel = null
	# 延迟发出信号，避免在按钮输入传播链中 remove_child 导致 get_viewport() 返回 null
	call_deferred("emit_signal", "battle_ended", true)

func _apply_player_damage_multiplier(base_damage: int) -> int:
	if controller and controller.equipment_system:
		var mult = controller.equipment_system.get_roguelike_damage_multiplier()
		return int(round(base_damage * mult))
	return base_damage

func _get_effective_player_attack_power() -> int:
	if controller and controller.equipment_system:
		return int(round(player_attack_power * controller.equipment_system.get_roguelike_damage_multiplier()))
	return player_attack_power

func _remove_dead_enemies():
	for i in range(enemies.size() - 1, -1, -1):
		if enemies[i].health <= 0:
			# 获得金币奖励（优先使用预设值，否则按名字计算默认值）
			var gold: int = enemies[i].get("gold_reward", 0)
			if gold <= 0:
				gold = _get_default_gold_reward(enemies[i].get("name", ""))
			if gold > 0:
				player_gold += gold
				battle_gold_earned += gold
				print(tr("LOG_COMBAT_GOLD_GAIN") % [enemies[i].name, gold, player_gold])
			enemies.remove_at(i)
	if target_index >= enemies.size():
		target_index = _get_first_alive_enemy_index()
	
	# 检查史莱姆合体意图是否仍然有效
	# 如果只剩1只史莱姆，将其意图从"merge"改为"attack"
	if _get_alive_slime_count() < 2:
		for enemy in enemies:
			if enemy.name == "绿色史莱姆" and enemy.intent == "merge":
				enemy.intent = "attack"
				print(tr("LOG_COMBAT_SLIME_MERGE_CANCEL"))

func _on_overflow_triggered():
	# 方块溢出处理：扣血 + 清除半屏
	if is_game_over:
		return
	
	player_health = max(player_health - OVERFLOW_DAMAGE, 0)
	print(tr("LOG_COMBAT_OVERFLOW_DAMAGE") % [OVERFLOW_DAMAGE])
	
	_clear_half_rows_without_damage()
	
	controller.game_over = false
	controller.is_locking = false
	controller.lock_timer = 0.0
	controller.fall_timer = 0.0

	if player_health <= 0:
		_defeat()
		return
	
	controller.spawn_piece()

func _clear_half_rows_without_damage():
	# 清除底部一半行
	var rows_to_clear = int(controller.grid_manager.height / 2)
	for i in range(rows_to_clear):
		var y = controller.grid_manager.height - 1 - i
		if y < 0:
			break
		controller.grid_manager.grid.remove_at(y)
		controller.grid_manager.grid_chars.remove_at(y)
	
	for i in range(rows_to_clear):
		var new_row = []
		var new_char_row = []
		for x in range(controller.grid_manager.width):
			new_row.append(null)
			new_char_row.append("")
		controller.grid_manager.grid.insert(0, new_row)
		controller.grid_manager.grid_chars.insert(0, new_char_row)

func _show_game_over_menu(victory: bool):
	# 显示结算菜单
	_save_score()
	
	if not game_over_menu:
		game_over_menu = GameOverMenuScene.instantiate()
		add_child(game_over_menu)
		game_over_menu.restart_game.connect(func(): get_tree().reload_current_scene())
		game_over_menu.goto_menu.connect(func(): get_tree().change_scene_to_file(Config.PATHS_SCENE_MAIN_MENU))
	
	if game_over_menu.has_method("set_result"):
		game_over_menu.set_result(victory, total_score, total_lines_cleared)
	elif game_over_menu.has_method("set_score"):
		game_over_menu.set_score(total_score, total_lines_cleared)
	
	game_over_menu.show_menu()

func _save_score():
	# 保存分数
	if not Global.classic_scores.has("roguelike"):
		Global.classic_scores["roguelike"] = {"score": 0, "lines": 0}
	
	if total_score > Global.classic_scores["roguelike"]["score"]:
		Global.classic_scores["roguelike"]["score"] = total_score
		Global.classic_scores["roguelike"]["lines"] = total_lines_cleared
		Global.save_classic_scores()

func _toggle_pause():
	is_paused = !is_paused
	if pause_menu:
		if is_paused:
			pause_menu.show_menu()
		else:
			pause_menu.hide()

func _on_resume_pressed():
	_toggle_pause()

func _on_restart_pressed():
	get_tree().reload_current_scene()

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

func _on_end_game_pressed():
	is_game_over = true
	is_paused = false
	if pause_menu:
		pause_menu.hide()
	# 若处于Rogue流程（battle_ended有监听者），返回地图并显示全局结算
	if battle_ended.get_connections().size() > 0:
		quit_to_menu.emit()
	else:
		_show_game_over_menu(enemies.filter(func(e): return e.health > 0).is_empty())

func _on_menu_pressed():
	get_tree().change_scene_to_file(Config.PATHS_SCENE_MAIN_MENU)

# 遗物相关
func show_relic_selection(three_choice: bool = false):
	# 显示遗物选择界面
	if relic_ui:
		if three_choice:
			relic_ui.show_three_choice()
		else:
			relic_ui.show_single_relic()

func apply_relics(relics: Array):
	# 从地图同步遗物效果（已通过七巧板背包筛选）
	if controller and controller.equipment_system:
		controller.equipment_system.clear_temporary_equipment()
		for relic_type in relics:
			controller.equipment_system.set_temporary_equipped(relic_type, true)

		# 以基础攻击力重新计算，避免叠加或卸下后残留
		var new_attack = player_base_attack_power
		var sword_bonus = controller.equipment_system.get_iron_sword_bonus()
		if sword_bonus > 0:
			new_attack += sword_bonus
		var faulty_bonus = controller.equipment_system.get_faulty_amplifier_rogue_atk_bonus(player_base_attack_power)
		if faulty_bonus > 0:
			new_attack += faulty_bonus
		player_attack_power = new_attack
		print(tr("LOG_COMBAT_EQUIP_SYNC") % [player_base_attack_power, sword_bonus, faulty_bonus, player_attack_power])
	# 同步到局内七巧板展示
	if tangram_equipment:
		tangram_equipment._init_grid()
		for relic_type in relics:
			var equip_id = TangramEquipmentUI.equipment_type_to_id(relic_type)
			if not equip_id.is_empty():
				tangram_equipment.auto_place_equipment(equip_id)

func _on_relic_selected(relic_type: int):
	# 遗物被选中
	if controller and controller.equipment_system:
		controller.equipment_system.set_temporary_equipped(relic_type, true)
	print(tr("LOG_COMBAT_RELIC_GAIN") % [relic_type])

func _on_relic_skipped():
	# 遗物被跳过
	print(tr("LOG_COMBAT_RELIC_SKIP"))
