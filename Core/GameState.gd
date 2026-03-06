extends Node
class_name GameStateClass

## 游戏状态管理器 (Autoload)
## 负责管理当前运行的全局状态：角色属性、遗物、进度、随机种子等

# ==================== 信号定义 ====================
signal player_stats_changed(stats: Dictionary)
signal gold_changed(new_amount: int)
signal relics_changed(relics: Array)
signal health_changed(current: int, maximum: int)
signal run_started(seed_value: int)
signal run_ended(victory: bool)
signal floor_changed(floor_number: int)
signal room_entered(room_type: String, room_data: Dictionary)

# ==================== 运行状态 ====================
var current_run_seed: int = 0
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var is_run_active: bool = false
var current_floor: int = 0
var current_act: int = 1

# ==================== 玩家属性 ====================
var player_stats: Dictionary = {
	"max_health": 80,
	"current_health": 80,
	"gold": 99,
	"base_attack": 10,
	"base_defense": 0,
}

# ==================== 遗物系统 ====================
var relics: Array[Dictionary] = []
const MAX_RELICS: int = 10  # 遗物槽上限

# ==================== 装备系统（背包乱斗风格）====================
var equipment_slots: Dictionary = {
	"weapon": null,
	"armor": null,
	"accessory_1": null,
	"accessory_2": null,
}
const MAX_BACKPACK_SIZE: int = 8  # 背包格子上限
var backpack: Array[Dictionary] = []

# ==================== 地图进度 ====================
var visited_rooms: Array[Vector2i] = []
var current_room_position: Vector2i = Vector2i.ZERO
var map_data: Dictionary = {}

# ==================== 初始化 ====================
func _ready():
	print("[GameState] 游戏状态管理器已加载")

# ==================== 运行管理 ====================
func start_new_run(seed_value: int = -1) -> void:
	# 开始新的一轮游戏
	if seed_value < 0:
		current_run_seed = randi()
	else:
		current_run_seed = seed_value
	
	rng.seed = current_run_seed
	is_run_active = true
	current_floor = 0
	current_act = 1
	
	# 重置玩家状态
	_reset_player_stats()
	relics.clear()
	backpack.clear()
	_clear_equipment()
	visited_rooms.clear()
	map_data.clear()
	
	print("[GameState] 新运行开始，种子: ", current_run_seed)
	run_started.emit(current_run_seed)

func end_run(victory: bool) -> void:
	# 结束当前运行
	is_run_active = false
	print("[GameState] 运行结束，胜利: ", victory)
	run_ended.emit(victory)

func _reset_player_stats() -> void:
	player_stats = {
		"max_health": 80,
		"current_health": 80,
		"gold": 99,
		"base_attack": 10,
		"base_defense": 0,
	}
	player_stats_changed.emit(player_stats)
	health_changed.emit(player_stats.current_health, player_stats.max_health)
	gold_changed.emit(player_stats.gold)

func _clear_equipment() -> void:
	for slot in equipment_slots.keys():
		equipment_slots[slot] = null

# ==================== 生命值管理 ====================
func modify_health(amount: int) -> void:
	# 修改生命值（正数为治疗，负数为伤害）
	var old_health = player_stats.current_health
	player_stats.current_health = clampi(
		player_stats.current_health + amount,
		0,
		player_stats.max_health
	)
	
	if player_stats.current_health != old_health:
		health_changed.emit(player_stats.current_health, player_stats.max_health)
		player_stats_changed.emit(player_stats)
	
	if player_stats.current_health <= 0:
		end_run(false)

func modify_max_health(amount: int) -> void:
	# 修改最大生命值
	player_stats.max_health = maxi(1, player_stats.max_health + amount)
	player_stats.current_health = mini(player_stats.current_health, player_stats.max_health)
	health_changed.emit(player_stats.current_health, player_stats.max_health)
	player_stats_changed.emit(player_stats)

# ==================== 金币管理 ====================
func modify_gold(amount: int) -> void:
	# 修改金币数量
	player_stats.gold = maxi(0, player_stats.gold + amount)
	gold_changed.emit(player_stats.gold)
	player_stats_changed.emit(player_stats)

func can_afford(cost: int) -> bool:
	return player_stats.gold >= cost

# ==================== 遗物管理 ====================
func add_relic(relic_data: Dictionary) -> bool:
	# 添加遗物，返回是否成功
	if relics.size() >= MAX_RELICS:
		print("[GameState] 遗物槽已满")
		return false
	
	# 检查是否已拥有（唯一性）
	for relic in relics:
		if relic.get("id") == relic_data.get("id"):
			print("[GameState] 已拥有该遗物: ", relic_data.get("id"))
			return false
	
	relics.append(relic_data)
	relics_changed.emit(relics)
	print("[GameState] 获得遗物: ", relic_data.get("name", "Unknown"))
	return true

func has_relic(relic_id: String) -> bool:
	for relic in relics:
		if relic.get("id") == relic_id:
			return true
	return false

# ==================== 装备管理（背包乱斗风格）====================
func equip_item(slot: String, item_data: Dictionary) -> Dictionary:
	# 装备物品到指定槽位，返回被替换的物品（如果有）
	if not equipment_slots.has(slot):
		push_error("[GameState] 无效的装备槽: " + slot)
		return {}
	
	var old_item = equipment_slots[slot]
	equipment_slots[slot] = item_data
	player_stats_changed.emit(player_stats)
	
	return old_item if old_item else {}

func unequip_item(slot: String) -> Dictionary:
	# 卸下指定槽位的装备
	if not equipment_slots.has(slot):
		return {}
	
	var item = equipment_slots[slot]
	equipment_slots[slot] = null
	player_stats_changed.emit(player_stats)
	
	return item if item else {}

func add_to_backpack(item_data: Dictionary) -> bool:
	# 添加物品到背包
	if backpack.size() >= MAX_BACKPACK_SIZE:
		print("[GameState] 背包已满")
		return false
	
	backpack.append(item_data)
	return true

func remove_from_backpack(index: int) -> Dictionary:
	# 从背包移除物品
	if index < 0 or index >= backpack.size():
		return {}
	
	return backpack.pop_at(index)

# ==================== 地图进度 ====================
func enter_room(position: Vector2i, room_type: String, room_data: Dictionary = {}) -> void:
	# 进入房间
	current_room_position = position
	if position not in visited_rooms:
		visited_rooms.append(position)
	
	room_entered.emit(room_type, room_data)

func advance_floor() -> void:
	# 推进楼层
	current_floor += 1
	floor_changed.emit(current_floor)

# ==================== 存档接口 ====================
func get_save_data() -> Dictionary:
	# 获取存档数据
	return {
		"run_seed": current_run_seed,
		"is_run_active": is_run_active,
		"current_floor": current_floor,
		"current_act": current_act,
		"player_stats": player_stats.duplicate(true),
		"relics": relics.duplicate(true),
		"equipment_slots": equipment_slots.duplicate(true),
		"backpack": backpack.duplicate(true),
		"visited_rooms": visited_rooms.duplicate(),
		"current_room_position": {"x": current_room_position.x, "y": current_room_position.y},
		"map_data": map_data.duplicate(true),
	}

func load_save_data(data: Dictionary) -> void:
	# 加载存档数据
	current_run_seed = data.get("run_seed", 0)
	rng.seed = current_run_seed
	is_run_active = data.get("is_run_active", false)
	current_floor = data.get("current_floor", 0)
	current_act = data.get("current_act", 1)
	player_stats = data.get("player_stats", {})
	relics = data.get("relics", [])
	equipment_slots = data.get("equipment_slots", {})
	backpack = data.get("backpack", [])
	visited_rooms = data.get("visited_rooms", [])
	
	var pos = data.get("current_room_position", {"x": 0, "y": 0})
	current_room_position = Vector2i(pos.x, pos.y)
	map_data = data.get("map_data", {})
	
	# 发射信号通知UI更新
	player_stats_changed.emit(player_stats)
	health_changed.emit(player_stats.current_health, player_stats.max_health)
	gold_changed.emit(player_stats.gold)
	relics_changed.emit(relics)

# ==================== 计算属性（考虑装备和遗物加成）====================
func get_total_attack() -> int:
	var total = player_stats.base_attack
	
	# 装备加成
	for slot in equipment_slots.values():
		if slot and slot.has("attack_bonus"):
			total += slot.attack_bonus
	
	# 遗物加成
	for relic in relics:
		if relic.has("attack_bonus"):
			total += relic.attack_bonus
	
	return total

func get_total_defense() -> int:
	var total = player_stats.base_defense
	
	for slot in equipment_slots.values():
		if slot and slot.has("defense_bonus"):
			total += slot.defense_bonus
	
	for relic in relics:
		if relic.has("defense_bonus"):
			total += relic.defense_bonus
	
	return total
