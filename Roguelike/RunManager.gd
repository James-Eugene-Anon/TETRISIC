extends Node
class_name RunManager

## Roguelike 运行管理器
## 负责地图生成、房间管理、事件调度

# ==================== 信号定义 ====================
signal map_generated(map_data: Dictionary)
signal room_selected(position: Vector2i, room_data: Dictionary)
signal floor_completed(floor_number: int)
signal act_completed(act_number: int)
signal run_completed(victory: bool)

# ==================== 常量 ====================
enum RoomType {
	COMBAT,
	ELITE,
	BOSS,
	REST,
	SHOP,
	EVENT,
	TREASURE,
	START,
}

const ROOM_ICONS: Dictionary = {
	RoomType.COMBAT: "⚔️",
	RoomType.ELITE: "💀",
	RoomType.BOSS: "👹",
	RoomType.REST: "🔥",
	RoomType.SHOP: "💰",
	RoomType.EVENT: "❓",
	RoomType.TREASURE: "📦",
	RoomType.START: "🏠",
}

# ==================== 地图配置 ====================
const MAP_CONFIG: Dictionary = {
	"floors_per_act": 15,
	"paths_count": 4,           # 每层的路径数量
	"min_branches": 2,          # 最小分支
	"max_branches": 4,          # 最大分支
	"elite_floor_min": 6,       # 精英怪最早出现楼层
	"shop_frequency": 0.15,     # 商店出现概率
	"rest_frequency": 0.12,     # 休息点出现概率
	"event_frequency": 0.22,    # 事件出现概率
	"treasure_frequency": 0.05, # 宝箱出现概率
}

# ==================== 状态 ====================
var current_map: Dictionary = {}  # 当前地图数据
var current_position: Vector2i = Vector2i.ZERO
var available_paths: Array[Vector2i] = []

func _ready():
	print("[RunManager] Roguelike运行管理器已加载")

# ==================== 地图生成（杀戮尖塔风格）====================
func generate_map(act: int = 1, seed_value: int = -1) -> Dictionary:
	# 生成新的地图
	# 返回格式: {
	# "act": int,
	# "floors": { floor_number: [room_data, ...] },
	# "connections": { "x,y": [connected_positions...] },
	# "boss": room_data
	# }
	var rng = RandomNumberGenerator.new()
	if seed_value >= 0:
		rng.seed = seed_value
	elif Engine.has_singleton("GameState"):
		var game_state = Engine.get_singleton("GameState")
		rng.seed = game_state.current_run_seed + act * 1000
	else:
		rng.seed = randi()
	
	var floors_count = MAP_CONFIG.floors_per_act
	var paths_count = MAP_CONFIG.paths_count
	
	var map_data: Dictionary = {
		"act": act,
		"floors": {},
		"connections": {},
		"boss": null,
	}
	
	# 生成起始层（0层）
	map_data.floors[0] = [_create_room(RoomType.START, Vector2i(paths_count / 2, 0))]
	
	# 生成中间层（1 到 floors_count - 1）
	for floor_num in range(1, floors_count):
		var rooms: Array = []
		var room_count = rng.randi_range(MAP_CONFIG.min_branches, MAP_CONFIG.max_branches)
		
		for i in range(room_count):
			var x_pos = i
			var room_type = _determine_room_type(floor_num, floors_count, rng)
			var room = _create_room(room_type, Vector2i(x_pos, floor_num))
			rooms.append(room)
		
		map_data.floors[floor_num] = rooms
	
	# 生成Boss层
	var boss_room = _create_room(RoomType.BOSS, Vector2i(paths_count / 2, floors_count))
	boss_room["enemy_id"] = _get_boss_for_act(act)
	map_data.floors[floors_count] = [boss_room]
	map_data.boss = boss_room
	
	# 生成连接（路径）
	map_data.connections = _generate_connections(map_data.floors, rng)
	
	current_map = map_data
	map_generated.emit(map_data)
	
	print("[RunManager] 地图已生成，Act ", act, "，共 ", floors_count + 1, " 层")
	return map_data

func _create_room(type: RoomType, position: Vector2i) -> Dictionary:
	# 创建房间数据
	return {
		"type": type,
		"type_name": RoomType.keys()[type],
		"icon": ROOM_ICONS.get(type, "?"),
		"position": {"x": position.x, "y": position.y},
		"visited": false,
		"cleared": false,
		"data": {},  # 房间特定数据（敌人、事件等）
	}

func _determine_room_type(floor_num: int, total_floors: int, rng: RandomNumberGenerator) -> RoomType:
	# 决定房间类型
	# 倒数第二层强制休息
	if floor_num == total_floors - 1:
		return RoomType.REST
	
	# 精英怪检查
	if floor_num >= MAP_CONFIG.elite_floor_min:
		if rng.randf() < 0.1:  # 10% 概率
			return RoomType.ELITE
	
	# 根据权重随机
	var roll = rng.randf()
	var cumulative = 0.0
	
	cumulative += MAP_CONFIG.treasure_frequency
	if roll < cumulative:
		return RoomType.TREASURE
	
	cumulative += MAP_CONFIG.shop_frequency
	if roll < cumulative:
		return RoomType.SHOP
	
	cumulative += MAP_CONFIG.rest_frequency
	if roll < cumulative:
		return RoomType.REST
	
	cumulative += MAP_CONFIG.event_frequency
	if roll < cumulative:
		return RoomType.EVENT
	
	# 默认战斗
	return RoomType.COMBAT

func _generate_connections(floors: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	# 生成层间连接
	var connections: Dictionary = {}
	
	var floor_numbers = floors.keys()
	floor_numbers.sort()
	
	for i in range(floor_numbers.size() - 1):
		var current_floor = floor_numbers[i]
		var next_floor = floor_numbers[i + 1]
		
		var current_rooms = floors[current_floor]
		var next_rooms = floors[next_floor]
		
		for room in current_rooms:
			var pos = Vector2i(room.position.x, room.position.y)
			var key = _pos_to_key(pos)
			connections[key] = []
			
			# 连接到下一层的1-2个房间
			var connect_count = rng.randi_range(1, mini(2, next_rooms.size()))
			var connected_indices: Array[int] = []
			
			for _c in range(connect_count):
				var target_idx = rng.randi() % next_rooms.size()
				while target_idx in connected_indices and connected_indices.size() < next_rooms.size():
					target_idx = (target_idx + 1) % next_rooms.size()
				
				if target_idx not in connected_indices:
					connected_indices.append(target_idx)
					var target_room = next_rooms[target_idx]
					var target_pos = Vector2i(target_room.position.x, target_room.position.y)
					connections[key].append({"x": target_pos.x, "y": target_pos.y})
	
	return connections

func _pos_to_key(pos: Vector2i) -> String:
	return str(pos.x) + "," + str(pos.y)

func _key_to_pos(key: String) -> Vector2i:
	var parts = key.split(",")
	return Vector2i(int(parts[0]), int(parts[1]))

func _get_boss_for_act(act: int) -> String:
	# 获取章节Boss ID
	match act:
		1: return "enemy_boss_dragon"
		2: return "enemy_boss_lich"
		3: return "enemy_boss_demon"
		_: return "enemy_boss_dragon"

# ==================== 房间选择与进入 ====================
func get_available_rooms() -> Array[Dictionary]:
	# 获取当前可选择的房间
	if current_map.is_empty():
		return []
	
	var key = _pos_to_key(current_position)
	var connected_positions = current_map.connections.get(key, [])
	
	var available: Array[Dictionary] = []
	for pos_dict in connected_positions:
		var pos = Vector2i(pos_dict.x, pos_dict.y)
		var floor_rooms = current_map.floors.get(pos.y, [])
		for room in floor_rooms:
			if room.position.x == pos.x and room.position.y == pos.y:
				available.append(room)
				break
	
	return available

func select_room(position: Vector2i) -> Dictionary:
	# 选择并进入房间
	var floor_rooms = current_map.floors.get(position.y, [])
	var target_room = null
	
	for room in floor_rooms:
		if room.position.x == position.x and room.position.y == position.y:
			target_room = room
			break
	
	if target_room == null:
		push_error("[RunManager] 找不到房间: ", position)
		return {}
	
	# 检查是否可以到达
	var available = get_available_rooms()
	var can_reach = false
	for room in available:
		if room.position.x == position.x and room.position.y == position.y:
			can_reach = true
			break
	
	# 起始位置可以直接选择第一层
	if current_position == Vector2i.ZERO and position.y == 1:
		can_reach = true
	
	if not can_reach and position.y != 0:  # 0层是起始点
		push_warning("[RunManager] 无法到达该房间")
		return {}
	
	# 更新位置
	current_position = position
	target_room.visited = true
	
	# 通知 GameState
	if Engine.has_singleton("GameState"):
		var game_state = Engine.get_singleton("GameState")
		game_state.enter_room(position, target_room.type_name, target_room.data)
	
	room_selected.emit(position, target_room)
	return target_room

func complete_current_room() -> void:
	# 完成当前房间
	var floor_rooms = current_map.floors.get(current_position.y, [])
	for room in floor_rooms:
		if room.position.x == current_position.x and room.position.y == current_position.y:
			room.cleared = true
			break
	
	# 检查是否完成楼层/章节
	if current_position.y == MAP_CONFIG.floors_per_act:
		# Boss层完成
		act_completed.emit(current_map.act)
	else:
		floor_completed.emit(current_position.y)

func start_new_floor() -> void:
	# 开始新楼层（从起始点开始）
	current_position = Vector2i.ZERO
	available_paths = []
	
	# 设置第一层可选
	if current_map.floors.has(1):
		for room in current_map.floors[1]:
			available_paths.append(Vector2i(room.position.x, room.position.y))

# ==================== 房间内容生成 ====================
func prepare_room_content(room: Dictionary) -> Dictionary:
	# 准备房间内容（敌人、事件等）
	var content: Dictionary = {}
	
	match room.type:
		RoomType.COMBAT:
			content = _prepare_combat_room(false)
		RoomType.ELITE:
			content = _prepare_combat_room(true)
		RoomType.BOSS:
			content = _prepare_boss_room(room.get("enemy_id", ""))
		RoomType.EVENT:
			content = _prepare_event_room()
		RoomType.SHOP:
			content = _prepare_shop_room()
		RoomType.REST:
			content = _prepare_rest_room()
		RoomType.TREASURE:
			content = _prepare_treasure_room()
	
	room.data = content
	return content

func _prepare_combat_room(is_elite: bool) -> Dictionary:
	# 准备战斗房间
	var enemies: Array = []
	var enemy_count = 1 if is_elite else randi_range(1, 3)
	
	if Engine.has_singleton("ResourceDB"):
		var db = Engine.get_singleton("ResourceDB")
		var act = current_map.get("act", 1)
		var enemy_type = "elite" if is_elite else "normal"
		
		for _i in range(enemy_count):
			var rng = RandomNumberGenerator.new()
			rng.seed = randi()
			var enemy = db.get_random_enemy(rng, act, enemy_type)
			if not enemy.is_empty():
				enemies.append(enemy)
	
	return {"enemies": enemies, "is_elite": is_elite}

func _prepare_boss_room(boss_id: String) -> Dictionary:
	# 准备Boss房间
	var boss_data = {}
	
	if Engine.has_singleton("ResourceDB"):
		var db = Engine.get_singleton("ResourceDB")
		boss_data = db.get_enemy(boss_id)
	
	return {"enemies": [boss_data], "is_boss": true}

func _prepare_event_room() -> Dictionary:
	# 准备事件房间
	var event_data = {}
	
	if Engine.has_singleton("ResourceDB"):
		var db = Engine.get_singleton("ResourceDB")
		var rng = RandomNumberGenerator.new()
		rng.seed = randi()
		event_data = db.get_random_event(rng, current_map.get("act", 1))
	
	return {"event": event_data}

func _prepare_shop_room() -> Dictionary:
	# 准备商店房间
	var items: Array = []
	var relics: Array = []
	
	if Engine.has_singleton("ResourceDB"):
		var db = Engine.get_singleton("ResourceDB")
		var rng = RandomNumberGenerator.new()
		rng.seed = randi()
		
		# 随机选择3-5个物品
		var all_items = db.get_all_items()
		all_items.shuffle()
		for i in range(mini(4, all_items.size())):
			var item = all_items[i].duplicate()
			item["price"] = _calculate_shop_price(item)
			items.append(item)
		
		# 随机选择1个装备
		var relic = db.get_random_relic(rng)
		if not relic.is_empty():
			relic = relic.duplicate()
			relic["price"] = _calculate_shop_price(relic)
			relics.append(relic)
	
	return {"items": items, "relics": relics}

func _calculate_shop_price(item: Dictionary) -> int:
	# 计算商品价格
	var base_price = 50
	var rarity = item.get("rarity", "common")
	
	match rarity:
		"common": base_price = 50
		"uncommon": base_price = 100
		"rare": base_price = 150
		"boss", "legendary": base_price = 250
	
	# 添加随机波动
	return base_price + randi_range(-10, 20)

func _prepare_rest_room() -> Dictionary:
	# 准备休息房间
	return {
		"options": [
			{"id": "rest", "name": "休息", "description": "恢复30%最大生命值"},
			{"id": "smith", "name": "升级", "description": "升级一件装备"},
		]
	}

func _prepare_treasure_room() -> Dictionary:
	# 准备宝箱房间
	var rewards: Array = []
	
	if Engine.has_singleton("ResourceDB"):
		var db = Engine.get_singleton("ResourceDB")
		var rng = RandomNumberGenerator.new()
		rng.seed = randi()
		
		# 50%概率获得装备
		if rng.randf() < 0.5:
			var relic = db.get_random_relic(rng, "common")
			if not relic.is_empty():
				rewards.append({"type": "relic", "data": relic})
		else:
			# 获得金币
			rewards.append({"type": "gold", "amount": rng.randi_range(25, 75)})
	
	return {"rewards": rewards}

# ==================== 存档接口 ====================
func get_save_data() -> Dictionary:
	return {
		"current_map": current_map,
		"current_position": {"x": current_position.x, "y": current_position.y},
	}

func load_save_data(data: Dictionary) -> void:
	current_map = data.get("current_map", {})
	var pos = data.get("current_position", {"x": 0, "y": 0})
	current_position = Vector2i(pos.x, pos.y)
