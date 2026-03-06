extends Node
class_name ResourceDBClass

## 资源数据库 (Autoload)
## 负责加载和管理所有数据驱动的资源：物品、遗物、敌人、叙事碎片等

# ==================== 信号定义 ====================
signal database_loaded(db_name: String)
signal database_load_failed(db_name: String, error: String)

# ==================== 数据库存储 ====================
var items_db: Dictionary = {}       # 物品数据库
var relics_db: Dictionary = {}      # 遗物数据库
var enemies_db: Dictionary = {}     # 敌人数据库
var events_db: Dictionary = {}      # 事件数据库
var narrative_db: Dictionary = {}   # 叙事碎片数据库

# ==================== 数据路径 ====================
const DATA_PATHS: Dictionary = {
	"items": "res://Data/Items/",
	"relics": "res://Data/Relics/",
	"enemies": "res://Data/Enemies/",
	"events": "res://Data/Events/",
	"narrative": "res://Data/Narrative/",
}

# ==================== 初始化 ====================
func _ready():
	print("[ResourceDB] 资源数据库已加载")
	load_all_databases()

func load_all_databases() -> void:
	# 加载所有数据库
	_load_json_database("items", items_db)
	_load_json_database("relics", relics_db)
	_load_json_database("enemies", enemies_db)
	_load_json_database("events", events_db)
	_load_json_database("narrative", narrative_db)
	
	print("[ResourceDB] 数据库加载完成:")
	print("  - 消耗品(药水等): ", items_db.size())
	print("  - 遗物: ", relics_db.size())
	print("  - 敌人: ", enemies_db.size())
	print("  - 事件: ", events_db.size())
	print("  - 叙事碎片: ", narrative_db.size())

func _load_json_database(db_name: String, target_db: Dictionary) -> void:
	# 从目录加载JSON数据库
	var path = DATA_PATHS.get(db_name, "")
	if path.is_empty():
		return
	
	var dir = DirAccess.open(path)
	if not dir:
		# 目录不存在，创建示例数据
		_create_sample_data(db_name)
		return
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".json"):
			var file_path = path + file_name
			var data = _load_json_file(file_path)
			if data and data.has("id"):
				target_db[data.id] = data
			elif data is Array:
				for item in data:
					if item.has("id"):
						target_db[item.id] = item
		file_name = dir.get_next()
	
	dir.list_dir_end()
	database_loaded.emit(db_name)

func _load_json_file(path: String) -> Variant:
	# 加载单个JSON文件
	if not FileAccess.file_exists(path):
		return null
	
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		database_load_failed.emit(path, "无法打开文件")
		return null
	
	var json_text = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var error = json.parse(json_text)
	if error != OK:
		database_load_failed.emit(path, json.get_error_message())
		return null
	
	var data = json.get_data()
	
	# 处理嵌套结构：{"items": [...]} 或 {"relics": [...]} 等
	if data is Dictionary:
		# 检查常见的嵌套键
		for key in ["items", "relics", "enemies", "events", "narrative", "narratives", "waves"]:
			if data.has(key) and data[key] is Array:
				return data[key]
	
	return data

# ==================== 查询接口 ====================
# --- 物品 ---
func get_item(item_id: String) -> Dictionary:
	# 获取物品数据
	return items_db.get(item_id, {})

func get_items_by_type(item_type: String) -> Array[Dictionary]:
	# 按类型获取物品列表
	var result: Array[Dictionary] = []
	for item in items_db.values():
		if item.get("type") == item_type:
			result.append(item)
	return result

func get_items_by_rarity(rarity: String) -> Array[Dictionary]:
	# 按稀有度获取物品列表
	var result: Array[Dictionary] = []
	for item in items_db.values():
		if item.get("rarity") == rarity:
			result.append(item)
	return result

func get_all_items() -> Array[Dictionary]:
	# 获取所有物品
	var result: Array[Dictionary] = []
	result.assign(items_db.values())
	return result

func get_items_by_kind(kind: String) -> Array[Dictionary]:
	# 按kind获取物品（用于Rogue配置化数据）
	var result: Array[Dictionary] = []
	for item in items_db.values():
		if item.get("kind", "") == kind:
			result.append(item)
	return result

# --- 遗物 ---
func get_relic(relic_id: String) -> Dictionary:
	# 获取遗物数据
	return relics_db.get(relic_id, {})

func get_relics_by_rarity(rarity: String) -> Array[Dictionary]:
	# 按稀有度获取遗物列表
	var result: Array[Dictionary] = []
	for relic in relics_db.values():
		if relic.get("rarity") == rarity:
			result.append(relic)
	return result

func get_relics_by_kind(kind: String) -> Array[Dictionary]:
	# 按kind获取遗物（用于Rogue装备池）
	var result: Array[Dictionary] = []
	for relic in relics_db.values():
		if relic.get("kind", "") == kind:
			result.append(relic)
	return result

func get_random_relic(rng: RandomNumberGenerator, rarity: String = "") -> Dictionary:
	# 随机获取一个遗物
	var pool: Array[Dictionary] = []
	if rarity.is_empty():
		pool.assign(relics_db.values())
	else:
		pool = get_relics_by_rarity(rarity)
	
	if pool.is_empty():
		return {}
	
	return pool[rng.randi() % pool.size()]

# --- 敌人 ---
func get_enemy(enemy_id: String) -> Dictionary:
	# 获取敌人数据
	return enemies_db.get(enemy_id, {})

func get_enemies_by_act(act: int) -> Array[Dictionary]:
	# 按章节获取敌人列表
	var result: Array[Dictionary] = []
	for enemy in enemies_db.values():
		if enemy.get("act", 1) == act:
			result.append(enemy)
	return result

func get_enemies_by_type(enemy_type: String) -> Array[Dictionary]:
	# 按类型获取敌人（normal/elite/boss）
	var result: Array[Dictionary] = []
	for enemy in enemies_db.values():
		var t = enemy.get("type", enemy.get("enemy_type", "normal"))
		if t == enemy_type:
			result.append(enemy)
	return result

func get_enemies_by_kind(kind: String) -> Array[Dictionary]:
	# 按kind获取敌人配置（用于Rogue波次等）
	var result: Array[Dictionary] = []
	for enemy in enemies_db.values():
		if enemy.get("kind", "") == kind:
			result.append(enemy)
	return result

func get_random_enemy(rng: RandomNumberGenerator, act: int = 1, enemy_type: String = "normal") -> Dictionary:
	# 随机获取一个敌人
	var pool: Array[Dictionary] = []
	for enemy in enemies_db.values():
		var t = enemy.get("type", enemy.get("enemy_type", "normal"))
		if enemy.get("act", 1) == act and t == enemy_type:
			pool.append(enemy)
	
	if pool.is_empty():
		return {}
	
	return pool[rng.randi() % pool.size()]

# --- 事件 ---
func get_event(event_id: String) -> Dictionary:
	# 获取事件数据
	return events_db.get(event_id, {})

func get_events_by_kind(kind: String) -> Array[Dictionary]:
	# 按kind获取事件（用于Rogue地图节点流程配置）
	var result: Array[Dictionary] = []
	for event in events_db.values():
		if event.get("kind", "") == kind:
			result.append(event)
	return result

func get_random_event(rng: RandomNumberGenerator, act: int = 1) -> Dictionary:
	# 随机获取一个事件
	var pool: Array[Dictionary] = []
	for event in events_db.values():
		var event_act = event.get("act", 0)  # 0 表示任意章节
		if event_act == 0 or event_act == act:
			pool.append(event)
	
	if pool.is_empty():
		return {}
	
	return pool[rng.randi() % pool.size()]

# --- 叙事碎片 ---
func get_narrative_fragment(fragment_id: String) -> Dictionary:
	# 获取叙事碎片
	return narrative_db.get(fragment_id, {})

func get_narrative_by_keyword(keyword: String) -> Array[Dictionary]:
	# 按关键词获取叙事碎片
	var result: Array[Dictionary] = []
	for fragment in narrative_db.values():
		var keywords = fragment.get("keywords", [])
		if keyword in keywords:
			result.append(fragment)
	return result

# ==================== 示例数据创建 ====================
func _create_sample_data(db_name: String) -> void:
	# 创建示例数据文件
	match db_name:
		"items":
			_create_sample_items()
		"relics":
			_create_sample_relics()
		"enemies":
			_create_sample_enemies()
		"events":
			_create_sample_events()

func _create_sample_items() -> void:
	# 创建示例物品数据
	var sample_items = [
		{
			"id": "sword_basic",
			"name": "铁剑",
			"name_en": "Iron Sword",
			"description": "一把普通的铁剑",
			"type": "weapon",
			"slot": "weapon",
			"rarity": "common",
			"attack_bonus": 5,
			"icon": "res://Assets/Items/sword_basic.png"
		},
		{
			"id": "armor_leather",
			"name": "皮甲",
			"name_en": "Leather Armor",
			"description": "轻便的皮革护甲",
			"type": "armor",
			"slot": "armor",
			"rarity": "common",
			"defense_bonus": 3,
			"icon": "res://Assets/Items/armor_leather.png"
		},
		{
			"id": "ring_power",
			"name": "力量戒指",
			"name_en": "Ring of Power",
			"description": "增加攻击力的戒指",
			"type": "accessory",
			"slot": "accessory_1",
			"rarity": "uncommon",
			"attack_bonus": 3,
			"icon": "res://Assets/Items/ring_power.png"
		}
	]
	
	for item in sample_items:
		items_db[item.id] = item

func _create_sample_relics() -> void:
	# 创建示例遗物数据
	var sample_relics = [
		{
			"id": "relic_burning_blood",
			"name": "燃烧之血",
			"name_en": "Burning Blood",
			"description": "每场战斗结束后恢复6点生命值",
			"lore": "曾属于一位堕落的圣骑士，鲜血中蕴含着不灭的生命力。",
			"rarity": "starter",
			"effect_type": "on_combat_end",
			"effect_value": 6,
			"icon": "res://Assets/Relics/burning_blood.png"
		},
		{
			"id": "relic_anchor",
			"name": "船锚",
			"name_en": "Anchor",
			"description": "每回合开始时获得10点格挡",
			"lore": "沉重却令人安心。",
			"rarity": "common",
			"effect_type": "on_turn_start",
			"effect_value": 10,
			"icon": "res://Assets/Relics/anchor.png"
		},
		{
			"id": "relic_lantern",
			"name": "灯笼",
			"name_en": "Lantern",
			"description": "每场战斗的第一回合获得1点额外能量",
			"lore": "照亮前路，驱散黑暗。",
			"rarity": "boss",
			"effect_type": "on_combat_start",
			"effect_value": 1,
			"icon": "res://Assets/Relics/lantern.png"
		}
	]
	
	for relic in sample_relics:
		relics_db[relic.id] = relic

func _create_sample_enemies() -> void:
	# 创建示例敌人数据
	var sample_enemies = [
		{
			"id": "enemy_slime",
			"name": "史莱姆",
			"name_en": "Slime",
			"description": "一团黏糊糊的生物",
			"type": "normal",
			"act": 1,
			"max_health": 20,
			"base_attack": 5,
			"moves": ["attack", "defend"],
			"icon": "res://Assets/Enemies/slime.png"
		},
		{
			"id": "enemy_goblin",
			"name": "哥布林",
			"name_en": "Goblin",
			"description": "狡猾的小型生物",
			"type": "normal",
			"act": 1,
			"max_health": 30,
			"base_attack": 8,
			"moves": ["attack", "attack", "buff"],
			"icon": "res://Assets/Enemies/goblin.png"
		},
		{
			"id": "enemy_elite_knight",
			"name": "黑暗骑士",
			"name_en": "Dark Knight",
			"description": "曾经的英雄，如今堕入黑暗",
			"type": "elite",
			"act": 1,
			"max_health": 80,
			"base_attack": 15,
			"moves": ["attack", "heavy_attack", "defend"],
			"icon": "res://Assets/Enemies/dark_knight.png"
		},
		{
			"id": "enemy_boss_dragon",
			"name": "远古巨龙",
			"name_en": "Ancient Dragon",
			"description": "统治这片土地的远古存在",
			"type": "boss",
			"act": 1,
			"max_health": 200,
			"base_attack": 25,
			"moves": ["attack", "flame_breath", "tail_sweep", "enrage"],
			"icon": "res://Assets/Enemies/dragon.png"
		}
	]
	
	for enemy in sample_enemies:
		enemies_db[enemy.id] = enemy

func _create_sample_events() -> void:
	# 创建示例事件数据
	var sample_events = [
		{
			"id": "event_shrine",
			"name": "神秘祭坛",
			"name_en": "Mysterious Shrine",
			"description": "你发现了一座古老的祭坛，散发着微弱的光芒。",
			"act": 0,  # 0 表示任意章节
			"choices": [
				{
					"text": "祈祷 (恢复25%生命)",
					"effect": {"type": "heal_percent", "value": 25}
				},
				{
					"text": "献祭 (失去10%生命，获得随机遗物)",
					"effect": {"type": "sacrifice", "health_cost_percent": 10, "reward": "random_relic"}
				},
				{
					"text": "离开",
					"effect": {"type": "none"}
				}
			]
		},
		{
			"id": "event_merchant",
			"name": "旅行商人",
			"name_en": "Traveling Merchant",
			"description": "一位神秘的商人出现在你面前。",
			"act": 0,
			"choices": [
				{
					"text": "购买补给 (50金币，恢复30生命)",
					"cost": 50,
					"effect": {"type": "heal", "value": 30}
				},
				{
					"text": "购买装备 (100金币，获得随机装备)",
					"cost": 100,
					"effect": {"type": "random_item"}
				},
				{
					"text": "离开",
					"effect": {"type": "none"}
				}
			]
		}
	]
	
	for event in sample_events:
		events_db[event.id] = event
