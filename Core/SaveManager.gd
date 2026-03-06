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
const ACCOUNTS_DIR: String = "user://accounts/"
const ACCOUNTS_FILE: String = "user://accounts/accounts.json"
const LEGACY_SETTINGS_FILE: String = "user://settings.cfg"
const LEGACY_SONG_SCORES_FILE: String = "user://song_scores.save"
const LEGACY_CLASSIC_SCORES_FILE: String = "user://classic_scores.save"
const ADMIN_ACCOUNT_NAME: String = "Jim Anon"

const SETTINGS_KEYS = {
	"language": "language",
	"resolution_index": "resolution_index",
	"is_fullscreen": "is_fullscreen",
	"music_volume": "music_volume",
	"sfx_volume": "sfx_volume",
	"online_mode": "online_mode",
	"lyric_search_retry_count": "lyric_search_retry_count",
	"bgm_enabled": "bgm_enabled",
	"play_music_when_unfocused": "play_music_when_unfocused"
}

# ==================== 初始化 ====================
func _ready():
	print("[SaveManager] 存档管理器已加载")
	_ensure_save_directory()
	_ensure_accounts_directory()
	_ensure_default_admin_and_migrate_legacy()

func _ensure_save_directory() -> void:
	# 确保存档目录存在
	var dir = DirAccess.open("user://")
	if dir and not dir.dir_exists("saves"):
		dir.make_dir("saves")

func ensure_accounts_ready() -> void:
	_ensure_accounts_directory()
	_ensure_default_admin_and_migrate_legacy()

func _ensure_accounts_directory() -> void:
	var dir = DirAccess.open("user://")
	if dir and not dir.dir_exists("accounts"):
		dir.make_dir("accounts")

func _account_dir(account_id: String) -> String:
	return ACCOUNTS_DIR + account_id + "/"

func _account_settings_path(account_id: String) -> String:
	return _account_dir(account_id) + "settings.cfg"

func _account_song_scores_path(account_id: String) -> String:
	return _account_dir(account_id) + "song_scores.save"

func _account_classic_scores_path(account_id: String) -> String:
	return _account_dir(account_id) + "classic_scores.save"

func _account_saves_dir(account_id: String) -> String:
	return _account_dir(account_id) + "saves/"

func _ensure_account_directories(account_id: String) -> void:
	var base = _account_dir(account_id)
	DirAccess.make_dir_recursive_absolute(base)
	DirAccess.make_dir_recursive_absolute(_account_saves_dir(account_id))

func _read_json_file(path: String, default_value):
	if not FileAccess.file_exists(path):
		return default_value
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		return default_value
	var text = file.get_as_text()
	file.close()
	var json = JSON.new()
	if json.parse(text) != OK:
		return default_value
	return json.get_data()

func _write_json_file(path: String, data) -> bool:
	var file = FileAccess.open(path, FileAccess.WRITE)
	if not file:
		return false
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	return true

func _default_accounts_data() -> Dictionary:
	return {
		"version": 1,
		"next_id": 1,
		"current_account_id": "",
		"accounts": []
	}

func _load_accounts_data() -> Dictionary:
	var data = _read_json_file(ACCOUNTS_FILE, _default_accounts_data())
	if typeof(data) != TYPE_DICTIONARY:
		return _default_accounts_data()
	if not data.has("accounts"):
		data["accounts"] = []
	if not data.has("next_id"):
		data["next_id"] = 1
	if not data.has("current_account_id"):
		data["current_account_id"] = ""
	return data

func _save_accounts_data(data: Dictionary) -> bool:
	DirAccess.make_dir_recursive_absolute(ACCOUNTS_DIR)
	return _write_json_file(ACCOUNTS_FILE, data)

func _sanitize_account_name(name: String) -> String:
	return name.strip_edges()

func _find_account_index_by_id(data: Dictionary, account_id: String) -> int:
	var accounts: Array = data.get("accounts", [])
	for i in range(accounts.size()):
		var a: Dictionary = accounts[i]
		if str(a.get("id", "")) == account_id:
			return i
	return -1

func _find_account_index_by_name(data: Dictionary, name: String) -> int:
	var target = _sanitize_account_name(name).to_lower()
	var accounts: Array = data.get("accounts", [])
	for i in range(accounts.size()):
		var a: Dictionary = accounts[i]
		if str(a.get("name", "")).strip_edges().to_lower() == target:
			return i
	return -1

func get_accounts() -> Array[Dictionary]:
	var data = _load_accounts_data()
	var result: Array[Dictionary] = []
	var accounts: Array = data.get("accounts", [])
	for a in accounts:
		result.append({
			"id": str(a.get("id", "")),
			"name": str(a.get("name", "")),
			"is_admin": bool(a.get("is_admin", false)),
			"total_play_seconds": int(a.get("total_play_seconds", 0))
		})
	return result

func get_current_account_id() -> String:
	var data = _load_accounts_data()
	return str(data.get("current_account_id", ""))

func get_current_account() -> Dictionary:
	var data = _load_accounts_data()
	var account_id = str(data.get("current_account_id", ""))
	var idx = _find_account_index_by_id(data, account_id)
	if idx < 0:
		return {}
	return data["accounts"][idx]

func get_current_account_name() -> String:
	var account = get_current_account()
	if account.is_empty():
		return ""
	return str(account.get("name", ""))

func create_account(name: String, force_admin: bool = false) -> Dictionary:
	var account_name = _sanitize_account_name(name)
	if account_name == "":
		return {"success": false, "error": "empty_name"}

	var data = _load_accounts_data()
	if _find_account_index_by_name(data, account_name) >= 0:
		return {"success": false, "error": "duplicate_name"}

	var account_id = str(int(data.get("next_id", 1)))
	data["next_id"] = int(data.get("next_id", 1)) + 1

	var is_admin = force_admin or (account_name == ADMIN_ACCOUNT_NAME)
	if is_admin:
		for i in range(data["accounts"].size()):
			var a: Dictionary = data["accounts"][i]
			a["is_admin"] = false
			data["accounts"][i] = a

	data["accounts"].append({
		"id": account_id,
		"name": account_name,
		"is_admin": is_admin,
		"total_play_seconds": 0
	})
	if str(data.get("current_account_id", "")) == "":
		data["current_account_id"] = account_id

	if not _save_accounts_data(data):
		return {"success": false, "error": "save_failed"}

	_ensure_account_directories(account_id)
	return {"success": true, "id": account_id, "name": account_name, "is_admin": is_admin}

func rename_account(account_id: String, new_name: String) -> Dictionary:
	var name = _sanitize_account_name(new_name)
	if name == "":
		return {"success": false, "error": "empty_name"}

	var data = _load_accounts_data()
	var idx = _find_account_index_by_id(data, account_id)
	if idx < 0:
		return {"success": false, "error": "not_found"}

	var existing_idx = _find_account_index_by_name(data, name)
	if existing_idx >= 0 and existing_idx != idx:
		return {"success": false, "error": "duplicate_name"}

	var account: Dictionary = data["accounts"][idx]
	if bool(account.get("is_admin", false)) and name != ADMIN_ACCOUNT_NAME:
		return {"success": false, "error": "admin_name_locked"}
	if name == ADMIN_ACCOUNT_NAME and not bool(account.get("is_admin", false)):
		return {"success": false, "error": "admin_name_reserved"}

	account["name"] = name
	data["accounts"][idx] = account
	if not _save_accounts_data(data):
		return {"success": false, "error": "save_failed"}
	return {"success": true}

func set_current_account(account_id: String) -> bool:
	var data = _load_accounts_data()
	var idx = _find_account_index_by_id(data, account_id)
	if idx < 0:
		return false
	data["current_account_id"] = account_id
	return _save_accounts_data(data)

func delete_account(account_id: String) -> Dictionary:
	var data = _load_accounts_data()
	var idx = _find_account_index_by_id(data, account_id)
	if idx < 0:
		return {"success": false, "error": "not_found"}

	var account: Dictionary = data["accounts"][idx]
	if bool(account.get("is_admin", false)):
		return {"success": false, "error": "admin_cannot_delete"}

	data["accounts"].remove_at(idx)
	if data["accounts"].is_empty():
		var created = create_account(ADMIN_ACCOUNT_NAME, true)
		if not bool(created.get("success", false)):
			return {"success": false, "error": "create_admin_failed"}
		data = _load_accounts_data()
	else:
		if str(data.get("current_account_id", "")) == account_id:
			data["current_account_id"] = str(data["accounts"][0].get("id", ""))

	if not _save_accounts_data(data):
		return {"success": false, "error": "save_failed"}

	var base = _account_dir(account_id)
	_recursive_delete_dir(base)
	return {"success": true}

func get_account_play_seconds(account_id: String) -> int:
	var data = _load_accounts_data()
	var idx = _find_account_index_by_id(data, account_id)
	if idx < 0:
		return 0
	return int(data["accounts"][idx].get("total_play_seconds", 0))

func add_current_account_play_seconds(seconds: int) -> void:
	if seconds <= 0:
		return
	var data = _load_accounts_data()
	var account_id = str(data.get("current_account_id", ""))
	if account_id == "":
		return
	var idx = _find_account_index_by_id(data, account_id)
	if idx < 0:
		return
	var account: Dictionary = data["accounts"][idx]
	account["total_play_seconds"] = int(account.get("total_play_seconds", 0)) + seconds
	data["accounts"][idx] = account
	_save_accounts_data(data)

func _recursive_delete_dir(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	var dir = DirAccess.open(path)
	if not dir:
		return
	dir.list_dir_begin()
	var name = dir.get_next()
	while name != "":
		if name != "." and name != "..":
			var full_path = path.path_join(name)
			if dir.current_is_dir():
				_recursive_delete_dir(full_path)
			else:
				DirAccess.remove_absolute(full_path)
		name = dir.get_next()
	dir.list_dir_end()
	DirAccess.remove_absolute(path)

func save_account_settings(settings: Dictionary) -> bool:
	var account_id = get_current_account_id()
	if account_id == "":
		return false
	_ensure_account_directories(account_id)
	var cfg = ConfigFile.new()
	for key in settings.keys():
		cfg.set_value("settings", str(key), settings[key])
	return cfg.save(_account_settings_path(account_id)) == OK

func load_account_settings(defaults: Dictionary = {}) -> Dictionary:
	var account_id = get_current_account_id()
	var result = defaults.duplicate(true)
	if account_id == "":
		return result
	var cfg = ConfigFile.new()
	if cfg.load(_account_settings_path(account_id)) != OK:
		return result
	for key in SETTINGS_KEYS.values():
		if cfg.has_section_key("settings", key):
			result[key] = cfg.get_value("settings", key, result.get(key))
	return result

func save_account_song_scores(scores: Dictionary) -> bool:
	var account_id = get_current_account_id()
	if account_id == "":
		return false
	_ensure_account_directories(account_id)
	return _write_json_file(_account_song_scores_path(account_id), scores)

func load_account_song_scores() -> Dictionary:
	var account_id = get_current_account_id()
	if account_id == "":
		return {}
	var data = _read_json_file(_account_song_scores_path(account_id), {})
	return data if typeof(data) == TYPE_DICTIONARY else {}

func save_account_classic_scores(scores: Dictionary) -> bool:
	var account_id = get_current_account_id()
	if account_id == "":
		return false
	_ensure_account_directories(account_id)
	return _write_json_file(_account_classic_scores_path(account_id), scores)

func load_account_classic_scores() -> Dictionary:
	var account_id = get_current_account_id()
	if account_id == "":
		return {}
	var data = _read_json_file(_account_classic_scores_path(account_id), {})
	return data if typeof(data) == TYPE_DICTIONARY else {}

func _collect_legacy_settings() -> Dictionary:
	var defaults = {
		SETTINGS_KEYS.language: "zh",
		SETTINGS_KEYS.resolution_index: 0,
		SETTINGS_KEYS.is_fullscreen: false,
		SETTINGS_KEYS.music_volume: 0.8,
		SETTINGS_KEYS.sfx_volume: 0.8,
		SETTINGS_KEYS.online_mode: true,
		SETTINGS_KEYS.lyric_search_retry_count: 3,
		SETTINGS_KEYS.bgm_enabled: true,
		SETTINGS_KEYS.play_music_when_unfocused: false
	}
	var cfg = ConfigFile.new()
	if cfg.load(LEGACY_SETTINGS_FILE) != OK:
		return defaults
	for key in SETTINGS_KEYS.values():
		defaults[key] = cfg.get_value("settings", key, defaults.get(key))
	return defaults

func _migrate_legacy_data_to_account(account_id: String) -> void:
	_ensure_account_directories(account_id)
	var migrated_flag_path = _account_dir(account_id) + "migrated.flag"
	if FileAccess.file_exists(migrated_flag_path):
		return

	var legacy_settings = _collect_legacy_settings()
	save_account_settings(legacy_settings)

	var song_scores = _read_json_file(LEGACY_SONG_SCORES_FILE, {})
	if typeof(song_scores) == TYPE_DICTIONARY:
		save_account_song_scores(song_scores)

	var classic_scores = _read_json_file(LEGACY_CLASSIC_SCORES_FILE, {})
	if typeof(classic_scores) == TYPE_DICTIONARY:
		save_account_classic_scores(classic_scores)

	var f = FileAccess.open(migrated_flag_path, FileAccess.WRITE)
	if f:
		f.store_string("ok")
		f.close()

func _migrate_db_json_to_admin(admin_id: String) -> void:
	# 将旧版 user://tetrisic.db.json 中的分数迁移到管理员账号存档
	var db_flag = _account_dir(admin_id) + "db_migrated.flag"
	if FileAccess.file_exists(db_flag):
		return
	var db_path = "user://tetrisic.db.json"
	if not FileAccess.file_exists(db_path):
		# 标记已处理，避免每次重复检查
		var ff = FileAccess.open(db_flag, FileAccess.WRITE)
		if ff:
			ff.store_string("no_source")
			ff.close()
		return
	var db_data = _read_json_file(db_path, {})
	if typeof(db_data) != TYPE_DICTIONARY:
		return
	var tables = db_data.get("tables", {})
	if typeof(tables) != TYPE_DICTIONARY:
		return
	# 迁移 song_scores
	var db_song = tables.get("song_scores", {})
	if typeof(db_song) == TYPE_DICTIONARY and not db_song.is_empty():
		var existing_song = _read_json_file(_account_song_scores_path(admin_id), {})
		if typeof(existing_song) != TYPE_DICTIONARY:
			existing_song = {}
		for song_name in db_song.keys():
			var entry = db_song[song_name]
			if typeof(entry) != TYPE_DICTIONARY:
				continue
			var new_score = int(entry.get("score", 0))
			var new_lines = int(entry.get("lines", 0))
			if not existing_song.has(song_name) or int(existing_song[song_name].get("score", 0)) < new_score:
				existing_song[song_name] = {"score": new_score, "lines": new_lines}
		_write_json_file(_account_song_scores_path(admin_id), existing_song)
	# 迁移 classic_scores
	var db_classic = tables.get("classic_scores", {})
	if typeof(db_classic) == TYPE_DICTIONARY and not db_classic.is_empty():
		var existing_classic = _read_json_file(_account_classic_scores_path(admin_id), {})
		if typeof(existing_classic) != TYPE_DICTIONARY:
			existing_classic = {}
		for difficulty_key in db_classic.keys():
			var entry = db_classic[difficulty_key]
			if typeof(entry) != TYPE_DICTIONARY:
				continue
			var new_score = int(entry.get("score", 0))
			var new_lines = int(entry.get("lines", 0))
			if not existing_classic.has(difficulty_key) or int(existing_classic[difficulty_key].get("score", 0)) < new_score:
				existing_classic[difficulty_key] = {"score": new_score, "lines": new_lines}
		_write_json_file(_account_classic_scores_path(admin_id), existing_classic)
	# 写入完成标记
	var flag_file = FileAccess.open(db_flag, FileAccess.WRITE)
	if flag_file:
		flag_file.store_string("ok")
		flag_file.close()
	print("[SaveManager] tetrisic.db.json 分数已迁移到管理员账号")

func _ensure_default_admin_and_migrate_legacy() -> void:
	var data = _load_accounts_data()
	var admin_idx = _find_account_index_by_name(data, ADMIN_ACCOUNT_NAME)
	if admin_idx < 0:
		var created = create_account(ADMIN_ACCOUNT_NAME, true)
		if bool(created.get("success", false)):
			data = _load_accounts_data()
			admin_idx = _find_account_index_by_name(data, ADMIN_ACCOUNT_NAME)
	if admin_idx < 0:
		return

	for i in range(data["accounts"].size()):
		var a: Dictionary = data["accounts"][i]
		a["is_admin"] = (i == admin_idx)
		data["accounts"][i] = a

	var admin_account: Dictionary = data["accounts"][admin_idx]
	var admin_id = str(admin_account.get("id", ""))
	if admin_id == "":
		return

	var was_first_run = str(data.get("current_account_id", "")) == ""
	if was_first_run:
		data["current_account_id"] = admin_id
	_save_accounts_data(data)
	# 首次运行才自动切换到管理员账号，后续启动保持上次登录账号
	if was_first_run:
		set_current_account(admin_id)
	_migrate_legacy_data_to_account(admin_id)
	_migrate_db_json_to_admin(admin_id)

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

	# 将旧存档备份为 .bak，防止写入失败导致数据丢失
	if FileAccess.file_exists(file_path):
		var old_file = FileAccess.open(file_path, FileAccess.READ)
		if old_file:
			var old_content = old_file.get_as_text()
			old_file.close()
			var bak_file = FileAccess.open(file_path + ".bak", FileAccess.WRITE)
			if bak_file:
				bak_file.store_string(old_content)
				bak_file.close()

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
		push_error("[SaveManager] 存档解析失败 " + json.get_error_message() + "，尝试从备份加载...")
		# 尝试加载备份文件
		var bak_path = file_path + ".bak"
		if FileAccess.file_exists(bak_path):
			var bak_file = FileAccess.open(bak_path, FileAccess.READ)
			if bak_file:
				var bak_text = bak_file.get_as_text()
				bak_file.close()
				var bak_json = JSON.new()
				if bak_json.parse(bak_text) == OK:
					push_warning("[SaveManager] 已从备份恢复存档 slot=" + str(slot))
					json = bak_json
					parse_result = OK
					json_string = bak_text
		if parse_result != OK:
			load_completed.emit(slot, false)
			return false
	
	var save_data = json.get_data()
	# 数据完整性校验：加载的数据必须是字典且包含 meta 字段
	if typeof(save_data) != TYPE_DICTIONARY:
		push_error("[SaveManager] 存档文件格式异常: slot=" + str(slot))
		load_completed.emit(slot, false)
		return false
	_apply_save_data(save_data)
	
	print("[SaveManager] 游戏已从槽位 ", slot, " 加载")
	load_completed.emit(slot, true)
	return true

func delete_save(slot: int) -> bool:
	# 删除指定槽位的存档（包括备份）
	var file_path = _get_save_path(slot)
	
	if not FileAccess.file_exists(file_path):
		return false
	
	var result = DirAccess.remove_absolute(file_path)
	if result == OK:
		# 一并删除常常存在的备份文件
		var bak_path = file_path + ".bak"
		if FileAccess.file_exists(bak_path):
			DirAccess.remove_absolute(bak_path)
		save_deleted.emit(slot)
		print("[SaveManager] 已删除槽位 ", slot, " 的存档")
		return true
	
	push_error("[SaveManager] 删除存档失败: " + file_path)
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
	var account_id = get_current_account_id()
	if account_id == "":
		return SAVE_DIR + SAVE_FILE_PREFIX + str(slot) + SAVE_FILE_EXT
	_ensure_account_directories(account_id)
	return _account_saves_dir(account_id) + SAVE_FILE_PREFIX + str(slot) + SAVE_FILE_EXT

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
