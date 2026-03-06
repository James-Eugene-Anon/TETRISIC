extends Node
class_name GameDatabase

## 轻量级 JSON 键值数据库
## 用途：统一 Global.gd 散落的分数/设置存取，替代直接 FileAccess+JSON
## 设计原则：无外部依赖、单文件存储、表式 API、原子写入
## 注：如未来需要真正的 SQLite，可接入 godot-sqlite GDExtension (需下载预编译 DLL)

const DB_PATH: String = "user://tetrisic.db.json"
const DB_VERSION: int = 1

var _data: Dictionary = {}  # { "table_name": { "key": value, ... }, ... }
var _dirty: bool = false

# ==================== 生命周期 ====================
func _ready():
	load_db()
	print("[GameDatabase] 数据库已加载，表数量: %d" % _data.size())

func _notification(what):
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		flush()

# ==================== 表操作 ====================

## 读取表中某个键的值，不存在返回 default
func get_value(table: String, key: String, default = null):
	if _data.has(table) and _data[table].has(key):
		return _data[table][key]
	return default

## 写入表中某个键的值（自动标记脏数据）
func set_value(table: String, key: String, value) -> void:
	if not _data.has(table):
		_data[table] = {}
	_data[table][key] = value
	_dirty = true

## 删除表中某个键
func delete_key(table: String, key: String) -> bool:
	if _data.has(table) and _data[table].has(key):
		_data[table].erase(key)
		_dirty = true
		return true
	return false

## 获取整张表（返回副本，防止外部直接修改）
func get_table(table: String) -> Dictionary:
	if _data.has(table):
		return _data[table].duplicate(true)
	return {}

## 替换整张表
func set_table(table: String, dict: Dictionary) -> void:
	_data[table] = dict.duplicate(true)
	_dirty = true

## 删除整张表
func drop_table(table: String) -> bool:
	if _data.has(table):
		_data.erase(table)
		_dirty = true
		return true
	return false

## 检查表/键是否存在
func has_table(table: String) -> bool:
	return _data.has(table)

func has_key(table: String, key: String) -> bool:
	return _data.has(table) and _data[table].has(key)

## 获取表中所有键
func get_keys(table: String) -> Array:
	if _data.has(table):
		return _data[table].keys()
	return []

## 获取所有表名
func get_tables() -> Array:
	return _data.keys()

# ==================== 持久化 ====================

## 强制刷写到磁盘
func flush() -> bool:
	if not _dirty:
		return true
	var wrapper = {
		"_db_version": DB_VERSION,
		"_timestamp": Time.get_unix_time_from_system(),
		"tables": _data
	}
	# 原子写入：先写临时文件再重命名
	var tmp_path = DB_PATH + ".tmp"
	var file = FileAccess.open(tmp_path, FileAccess.WRITE)
	if not file:
		push_error("[GameDatabase] 无法写入数据库: %s" % tmp_path)
		return false
	file.store_string(JSON.stringify(wrapper, "\t"))
	file.close()
	# 覆盖正式文件
	var dir = DirAccess.open("user://")
	if dir:
		if dir.file_exists(DB_PATH.get_file()):
			dir.remove(DB_PATH.get_file())
		dir.rename(tmp_path.get_file(), DB_PATH.get_file())
	_dirty = false
	return true

## 从磁盘加载
func load_db() -> bool:
	if not FileAccess.file_exists(DB_PATH):
		_data = {}
		return true  # 空数据库
	var file = FileAccess.open(DB_PATH, FileAccess.READ)
	if not file:
		push_error("[GameDatabase] 无法读取数据库: %s" % DB_PATH)
		_data = {}
		return false
	var json_text = file.get_as_text()
	file.close()
	var json = JSON.new()
	if json.parse(json_text) != OK:
		push_error("[GameDatabase] JSON 解析失败: %s" % json.get_error_message())
		_data = {}
		return false
	var wrapper = json.get_data()
	if wrapper is Dictionary and wrapper.has("tables"):
		_data = wrapper["tables"]
	else:
		# 兼容无wrapper的旧格式
		_data = wrapper if wrapper is Dictionary else {}
	return true

# ==================== 便利方法（分数读写，直接映射 Global 原接口）====================

func update_song_score(song_name: String, score: int, lines: int) -> bool:
	var old = get_value("song_scores", song_name, {"score": 0, "lines": 0})
	if old is Dictionary and old.get("score", 0) >= score:
		return false
	set_value("song_scores", song_name, {"score": score, "lines": lines})
	flush()
	return true

func get_song_score(song_name: String) -> Dictionary:
	return get_value("song_scores", song_name, {"score": 0, "lines": 0})

func get_all_song_scores() -> Dictionary:
	return get_table("song_scores")

func update_classic_score(difficulty_key: String, score: int, lines: int) -> bool:
	var old = get_value("classic_scores", difficulty_key, {"score": 0, "lines": 0})
	if old is Dictionary and old.get("score", 0) >= score:
		return false
	set_value("classic_scores", difficulty_key, {"score": score, "lines": lines})
	flush()
	return true

func get_classic_score_by_key(difficulty_key: String) -> Dictionary:
	return get_value("classic_scores", difficulty_key, {"score": 0, "lines": 0})

## 设置存取
func save_setting(key: String, value) -> void:
	set_value("settings", key, value)
	flush()

func load_setting(key: String, default = null):
	return get_value("settings", key, default)
