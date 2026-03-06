extends Node
class_name ResourceDBClass

## 资源数据库 (Autoload)
## 负责加载和管理所有数据驱动的资源：物品、遗物、敌人、叙事碎片等

# ==================== 信号定义 ====================
signal database_loaded(db_name: String)
signal database_load_failed(db_name: String, error: String)


func _write_log(msg: String) -> void:
	var path = "user://resource_db.log"
	var file = FileAccess.open(path, FileAccess.WRITE_READ)
	if not file:
		file = FileAccess.open(path, FileAccess.WRITE)
		if not file:
			print("[ResourceDB] 无法写入日志: ", path)
			return
	file.seek_end()
	file.store_string("%s\n" % msg)
	file.close()

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
		# 目录不存在，将报错写入 log，并发出失败信号
		var err = "资源目录不存在: %s" % path
		_write_log("[ResourceDB] " + err)
		database_load_failed.emit(db_name, err)
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
