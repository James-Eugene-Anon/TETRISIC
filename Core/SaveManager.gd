extends Node
class_name SaveManagerClass

## 存档管理器 (Autoload)
## 负责游戏存档的读写、自动存档、多槽位管理

# ==================== 信号定义 ====================
signal save_completed(slot: int, success: bool)
signal load_completed(slot: int, success: bool)
signal save_deleted(slot: int)

# ==================== 常量 ====================
const SAVE_DIR: String = "user://saves/"
const SAVE_FILE_PREFIX: String = "save_slot_"
const SAVE_FILE_EXT: String = ".json"
const AUTO_SAVE_SLOT: int = 0
const MAX_SAVE_SLOTS: int = 3

# ==================== 初始化 ====================
func _ready():
	print("[SaveManager] 存档管理器已加载")
	_ensure_save_directory()

func _ensure_save_directory() -> void:
	# 确保存档目录存在
	var dir = DirAccess.open("user://")
	if dir and not dir.dir_exists("saves"):
		dir.make_dir("saves")

# ==================== 存档 API ====================
func save_game(slot: int = AUTO_SAVE_SLOT) -> bool:
	# 保存游戏到指定槽位
	if slot < 0 or slot > MAX_SAVE_SLOTS:
		push_error("[SaveManager] 无效的存档槽位: " + str(slot))
		save_completed.emit(slot, false)
		return false
	
	var save_data: Dictionary = _collect_save_data()
	save_data["meta"] = {
		"slot": slot,
		"timestamp": Time.get_unix_time_from_system(),
		"datetime": Time.get_datetime_string_from_system(),
		"version": ProjectSettings.get_setting("application/config/version", "1.0.0"),
	}
	
	var file_path = _get_save_path(slot)
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	
	if not file:
		push_error("[SaveManager] 无法创建存档文件: " + file_path)
		save_completed.emit(slot, false)
		return false
	
	var json_string = JSON.stringify(save_data, "\t")
	file.store_string(json_string)
	file.close()
	
	print("[SaveManager] 游戏已保存到槽位 ", slot)
	save_completed.emit(slot, true)
	return true

func load_game(slot: int = AUTO_SAVE_SLOT) -> bool:
	# 从指定槽位加载游戏
	if slot < 0 or slot > MAX_SAVE_SLOTS:
		push_error("[SaveManager] 无效的存档槽位: " + str(slot))
		load_completed.emit(slot, false)
		return false
	
	var file_path = _get_save_path(slot)
	
	if not FileAccess.file_exists(file_path):
		push_warning("[SaveManager] 存档不存在: " + file_path)
		load_completed.emit(slot, false)
		return false
	
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		push_error("[SaveManager] 无法读取存档文件: " + file_path)
		load_completed.emit(slot, false)
		return false
	
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_string)
	
	if parse_result != OK:
		push_error("[SaveManager] 存档解析失败: " + json.get_error_message())
		load_completed.emit(slot, false)
		return false
	
	var save_data = json.get_data()
	_apply_save_data(save_data)
	
	print("[SaveManager] 游戏已从槽位 ", slot, " 加载")
	load_completed.emit(slot, true)
	return true

func delete_save(slot: int) -> bool:
	# 删除指定槽位的存档
	var file_path = _get_save_path(slot)
	
	if not FileAccess.file_exists(file_path):
		return false
	
	var dir = DirAccess.open(SAVE_DIR)
	if dir:
		dir.remove(SAVE_FILE_PREFIX + str(slot) + SAVE_FILE_EXT)
		save_deleted.emit(slot)
		print("[SaveManager] 已删除槽位 ", slot, " 的存档")
		return true
	
	return false

func has_save(slot: int) -> bool:
	# 检查指定槽位是否有存档
	return FileAccess.file_exists(_get_save_path(slot))

func get_save_info(slot: int) -> Dictionary:
	# 获取存档的元信息（不加载完整数据）
	var file_path = _get_save_path(slot)
	
	if not FileAccess.file_exists(file_path):
		return {}
	
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		return {}
	
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	if json.parse(json_string) != OK:
		return {}
	
	var data = json.get_data()
	return data.get("meta", {})

func get_all_save_slots_info() -> Array[Dictionary]:
	# 获取所有存档槽位的信息
	var slots: Array[Dictionary] = []
	
	for i in range(MAX_SAVE_SLOTS + 1):
		var info = get_save_info(i)
		if not info.is_empty():
			slots.append(info)
		else:
			slots.append({"slot": i, "empty": true})
	
	return slots

# ==================== 自动存档 ====================
func auto_save() -> void:
	# 自动存档
	save_game(AUTO_SAVE_SLOT)

func has_auto_save() -> bool:
	# 检查是否有自动存档
	return has_save(AUTO_SAVE_SLOT)

func load_auto_save() -> bool:
	# 加载自动存档
	return load_game(AUTO_SAVE_SLOT)

# ==================== 内部方法 ====================
func _get_save_path(slot: int) -> String:
	# 获取存档文件路径
	return SAVE_DIR + SAVE_FILE_PREFIX + str(slot) + SAVE_FILE_EXT

func _collect_save_data() -> Dictionary:
	# 从各个可保存的模块收集数据
	var data: Dictionary = {}
	
	# 从 GameState 收集数据
	if Engine.has_singleton("GameState"):
		var game_state = Engine.get_singleton("GameState")
		if game_state.has_method("get_save_data"):
			data["game_state"] = game_state.get_save_data()
	
	# 从 persist 组收集数据
	var persist_nodes = get_tree().get_nodes_in_group("persist")
	for node in persist_nodes:
		if node.has_method("get_save_data"):
			var node_path = str(node.get_path())
			data[node_path] = node.get_save_data()
	
	return data

func _apply_save_data(data: Dictionary) -> void:
	# 将存档数据应用到各个模块
	# 应用到 GameState
	if Engine.has_singleton("GameState") and data.has("game_state"):
		var game_state = Engine.get_singleton("GameState")
		if game_state.has_method("load_save_data"):
			game_state.load_save_data(data["game_state"])
	
	# 应用到 persist 组的节点
	var persist_nodes = get_tree().get_nodes_in_group("persist")
	for node in persist_nodes:
		var node_path = str(node.get_path())
		if data.has(node_path) and node.has_method("load_save_data"):
			node.load_save_data(data[node_path])
