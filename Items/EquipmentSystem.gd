extends Node
class_name EquipmentSystem

## 装备系统 - 管理游戏装备和特殊效果

signal special_block_triggered(block_type: String, position: Vector2i, blocks_destroyed: int)

# 装备分类
enum EquipmentCategory {
	UNIVERSAL,    # 通用装备
	CLASSIC,      # 经典模式装备
	SONG,         # 歌曲模式装备
	ROGUELIKE     # Roguelike专属装备
}

# 装备类型枚举
enum EquipmentType {
	NONE,
	SPECIAL_BLOCK_GENERATOR,  # 特殊方块生成器（经典模式）
	FAULTY_SCORE_AMPLIFIER,   # 故障增幅器（通用）
	RIFT_METER,               # 裂隙仪（通用）
	CAPACITY_DISK,            # 扩容磁盘（通用）— 网格12x24
	SNAKE_VIRUS,              # 贪吃蛇病毒（经典模式）
	BEAT_CALIBRATOR,          # 节拍校对器（歌曲模式）
	DOWNCLOCK_SOFTWARE,       # 降频软件（Roguelike）
	HEARTS_MELODY,            # 心之旋律（歌曲模式）— 禁用节拍同步，最终得分×0.85
	IRON_SWORD,               # 铁剑（Roguelike）— 攻击力+5
	IRON_SHIELD               # 铁盾（Roguelike）— 每次防御额外+5护甲
}

# 特殊方块类型
enum SpecialBlockType {
	BOMB,           # 炸弹方块 - 消除3x3
	LASER_H,        # 横向激光 - 消除整行
	LASER_V         # 纵向激光 - 消除整列
}

# 装备数据 - 每个分类只能装备一个
var equipped_universal: EquipmentType = EquipmentType.NONE  # 通用装备
var equipped_classic: EquipmentType = EquipmentType.NONE    # 经典模式装备
var equipped_song: EquipmentType = EquipmentType.NONE       # 歌曲模式装备
var unlocked_equipment: Array[EquipmentType] = []

# 临时装备（用于Roguelike临时装备，不影响全局配置）
var temporary_equipped: Dictionary = {}  # {EquipmentType: bool}

# Roguelike模式仅使用临时装备（不读取全局装备）
var roguelike_only: bool = false

# 特殊方块生成器参数
const SPECIAL_BLOCK_CHANCE: float = 0.015  # 1.5%概率
const SPECIAL_BLOCK_COOLDOWN: int = 6  # 6次冷却
const SPECIAL_BLOCK_SCORE_PER_CELL: int = 5  # 每消除1格+5分

# 故障增幅器参数
const FAULTY_SPEED_MULTIPLIER: float = 1.05  # 速度x105%
const FAULTY_SCORE_MULTIPLIER: float = 1.2   # 非连击得分x120%
const FAULTY_ROGUE_STAT_BONUS_RATE: float = 0.15  # Rogue中初始攻防+15%

# 裂隙仪参数
const RIFT_METER_COOLDOWN: float = 45.0  # 45秒冷却
var rift_meter_timer: float = 0.0  # 剩余冷却时间

# 贪吃蛇病毒参数
const SNAKE_VIRUS_CHANCE: float = 0.01  # 1%概率
const SNAKE_VIRUS_COOLDOWN: int = 12  # 12次生成冷却
var snake_virus_cooldown: int = 0  # 当前冷却计数
var snake_length: int = 3  # 贪吃蛇初始/当前长度

# 节拍校对器参数
var beat_combo: int = 0  # 节拍校对器专属连击数

# Roguelike - 降频软件参数
const DOWNCLOCK_ENEMY_COOLDOWN_MULTIPLIER: float = 1.10  # 敌人行为冷却 *110%
const DOWNCLOCK_PLAYER_DAMAGE_MULTIPLIER: float = 0.90   # 玩家伤害 *90%
# 黑名单：未来可填写特殊敌人种类/行为
const DOWNCLOCK_ENEMY_BLACKLIST: Array[String] = []
const DOWNCLOCK_ACTION_BLACKLIST: Array[String] = []

# 心之旋律参数
const HEARTS_MELODY_SCORE_MULTIPLIER: float = 0.85  # 最终得分×0.85

# 铁剑/铁盾参数
const IRON_SWORD_ATK_BONUS: int = 5   # 攻击力+5
const IRON_SHIELD_DEF_BONUS: int = 5  # 每次防御额外+5护甲

var special_block_cooldown: int = 0  # 当前冷却计数
var pending_special_block: int = -1  # 等待触发的特殊方块类型 (-1表示无)
var pending_special_position: Vector2i  # 特殊方块位置

func _ready():
	# 暂时无条件解锁所有装备
	unlocked_equipment.append(EquipmentType.SPECIAL_BLOCK_GENERATOR)
	unlocked_equipment.append(EquipmentType.FAULTY_SCORE_AMPLIFIER)
	unlocked_equipment.append(EquipmentType.RIFT_METER)
	unlocked_equipment.append(EquipmentType.CAPACITY_DISK)
	unlocked_equipment.append(EquipmentType.SNAKE_VIRUS)
	unlocked_equipment.append(EquipmentType.BEAT_CALIBRATOR)
	unlocked_equipment.append(EquipmentType.HEARTS_MELODY)
	# Roguelike专属装备
	unlocked_equipment.append(EquipmentType.DOWNCLOCK_SOFTWARE)
	unlocked_equipment.append(EquipmentType.IRON_SWORD)
	unlocked_equipment.append(EquipmentType.IRON_SHIELD)

func set_roguelike_only(enabled: bool) -> void:
	roguelike_only = enabled

func is_equipped(equipment_type: EquipmentType) -> bool:
	# 检查是否装备了指定装备
	# Roguelike 临时装备优先判定
	if temporary_equipped.has(equipment_type):
		return true
	# Roguelike模式：除临时装备外，也允许全局通用装备生效
	if roguelike_only:
		var cat = get_equipment_category(equipment_type)
		if cat == EquipmentCategory.UNIVERSAL:
			if equipment_type == EquipmentType.FAULTY_SCORE_AMPLIFIER:
				return Global.equipment_universal_faulty_amplifier
			elif equipment_type == EquipmentType.RIFT_METER:
				return Global.equipment_universal_rift_meter
		return false
	if equipment_type == EquipmentType.SPECIAL_BLOCK_GENERATOR:
		return Global.equipment_classic_special_block
	elif equipment_type == EquipmentType.FAULTY_SCORE_AMPLIFIER:
		return Global.equipment_universal_faulty_amplifier
	elif equipment_type == EquipmentType.RIFT_METER:
		return Global.equipment_universal_rift_meter
	elif equipment_type == EquipmentType.CAPACITY_DISK:
		return Global.equipment_universal_capacity_disk
	elif equipment_type == EquipmentType.SNAKE_VIRUS:
		return Global.equipment_classic_snake_virus
	elif equipment_type == EquipmentType.BEAT_CALIBRATOR:
		return Global.equipment_song_beat_calibrator
	elif equipment_type == EquipmentType.HEARTS_MELODY:
		return Global.equipment_song_hearts_melody
	return false

func set_temporary_equipped(equipment_type: EquipmentType, enabled: bool) -> void:
	# 设置临时装备状态（仅本局Roguelike生效）
	# 仅阻止经典/歌曲分类装备进入Roguelike临时槽
	if roguelike_only:
		var cat = get_equipment_category(equipment_type)
		if cat == EquipmentCategory.CLASSIC or cat == EquipmentCategory.SONG:
			return
	if enabled:
		temporary_equipped[equipment_type] = true
	else:
		temporary_equipped.erase(equipment_type)

func clear_temporary_equipment() -> void:
	# 清空所有临时装备
	temporary_equipped.clear()

func get_equipment_category(equipment_type: EquipmentType) -> EquipmentCategory:
	# 获取装备所属分类
	match equipment_type:
		EquipmentType.SPECIAL_BLOCK_GENERATOR:
			return EquipmentCategory.CLASSIC
		EquipmentType.FAULTY_SCORE_AMPLIFIER:
			return EquipmentCategory.UNIVERSAL
		EquipmentType.RIFT_METER:
			return EquipmentCategory.UNIVERSAL
		EquipmentType.CAPACITY_DISK:
			return EquipmentCategory.UNIVERSAL
		EquipmentType.SNAKE_VIRUS:
			return EquipmentCategory.CLASSIC
		EquipmentType.BEAT_CALIBRATOR:
			return EquipmentCategory.SONG
		EquipmentType.HEARTS_MELODY:
			return EquipmentCategory.SONG
		EquipmentType.DOWNCLOCK_SOFTWARE:
			return EquipmentCategory.ROGUELIKE
		EquipmentType.IRON_SWORD:
			return EquipmentCategory.ROGUELIKE
		EquipmentType.IRON_SHIELD:
			return EquipmentCategory.ROGUELIKE
		_:
			return EquipmentCategory.UNIVERSAL

func get_roguelike_damage_multiplier() -> float:
	# Roguelike玩家伤害倍率（不影响护甲）
	if is_equipped(EquipmentType.DOWNCLOCK_SOFTWARE):
		return DOWNCLOCK_PLAYER_DAMAGE_MULTIPLIER
	return 1.0

func get_iron_sword_bonus() -> int:
	# 铁剑攻击力加成
	if is_equipped(EquipmentType.IRON_SWORD):
		return IRON_SWORD_ATK_BONUS
	return 0

func get_iron_shield_bonus() -> int:
	# 铁盾防御护甲加成（每次防御额外+5）
	if is_equipped(EquipmentType.IRON_SHIELD):
		return IRON_SHIELD_DEF_BONUS
	return 0

func get_faulty_amplifier_attack_multiplier() -> float:
	# 故障增幅器在Rogue模式的攻击倍率（+20%，与得分倍率一致）
	if is_equipped(EquipmentType.FAULTY_SCORE_AMPLIFIER):
		return FAULTY_SCORE_MULTIPLIER
	return 1.0

func get_faulty_amplifier_rogue_atk_bonus(base_attack: int) -> int:
	# Rogue模式：故障增幅器将“计分增益”等效为基础攻击+15%
	if not is_equipped(EquipmentType.FAULTY_SCORE_AMPLIFIER):
		return 0
	return int(ceil(float(max(base_attack, 1)) * FAULTY_ROGUE_STAT_BONUS_RATE))

func get_faulty_amplifier_rogue_def_bonus(base_defense_gain: int) -> int:
	# Rogue模式：故障增幅器将“计分增益”等效为基础防御+15%
	if not is_equipped(EquipmentType.FAULTY_SCORE_AMPLIFIER):
		return 0
	return int(ceil(float(max(base_defense_gain, 1)) * FAULTY_ROGUE_STAT_BONUS_RATE))

func is_hearts_melody_active() -> bool:
	# 检查心之旋律是否生效（禁用节拍同步）
	return is_equipped(EquipmentType.HEARTS_MELODY)

func get_final_score_multiplier() -> float:
	# 获取最终得分倍率（心之旋律：×0.85）
	if is_hearts_melody_active():
		return HEARTS_MELODY_SCORE_MULTIPLIER
	return 1.0

func get_enemy_cooldown_multiplier(enemy_name: String, action_type: String = "") -> float:
	# Roguelike敌人行为冷却倍率
	if not is_equipped(EquipmentType.DOWNCLOCK_SOFTWARE):
		return 1.0
	if DOWNCLOCK_ENEMY_BLACKLIST.has(enemy_name):
		return 1.0
	if action_type != "" and DOWNCLOCK_ACTION_BLACKLIST.has(action_type):
		return 1.0
	return DOWNCLOCK_ENEMY_COOLDOWN_MULTIPLIER

func get_speed_multiplier() -> float:
	# 获取速度倍率（用于故障计分增幅器）
	if is_equipped(EquipmentType.FAULTY_SCORE_AMPLIFIER):
		return FAULTY_SPEED_MULTIPLIER
	return 1.0

func get_score_multiplier(is_combo: bool) -> float:
	# 获取得分倍率（非连击时生效）
	if not is_combo and is_equipped(EquipmentType.FAULTY_SCORE_AMPLIFIER):
		return FAULTY_SCORE_MULTIPLIER
	return 1.0

func on_piece_spawned() -> Dictionary:
	# 方块生成时调用，返回是否生成特殊方块
	if not is_equipped(EquipmentType.SPECIAL_BLOCK_GENERATOR):
		return {"is_special": false}
	
	# 检查冷却
	if special_block_cooldown > 0:
		special_block_cooldown -= 1
		return {"is_special": false}
	
	# 1%概率生成特殊方块
	if randf() < SPECIAL_BLOCK_CHANCE:
		var special_type = randi() % 3  # 0=炸弹, 1=横向激光, 2=纵向激光
		special_block_cooldown = SPECIAL_BLOCK_COOLDOWN
		
		var type_names = ["BOMB", "LASER_H", "LASER_V"]
		print("[装备系统] 生成特殊方块: ", type_names[special_type])
		
		return {
			"is_special": true,
			"special_type": special_type,
			"shape": "DOT"  # 特殊方块都是单格
		}
	
	return {"is_special": false}

func trigger_special_block_after_clear(special_type: int, position: Vector2i, grid_manager: GridManager, lines_cleared: int) -> int:
	# 在正常消除行之后触发特殊方块效果
	# 炸弹：消除3x3区域，不触发重力（除非刚好消除整行）
	# 横向激光：消除整行，让上方行下落（和正常消行一样）
	# 纵向激光：消除整列，不触发重力（除非刚好消除整行）
	# 返回额外消除的方块数对应的加分
	var destroyed_count = 0
	
	match special_type:
		SpecialBlockType.BOMB:
			# 炸弹：消除3x3区域，然后检查是否有完整行被消除
			destroyed_count = _trigger_bomb(position, grid_manager)
			# 检查并消除完整行（这会自动处理行下落）
			var bomb_lines = grid_manager.clear_lines()
			if bomb_lines > 0:
				print("[装备系统] 炸弹正好消除了 ", bomb_lines, " 行")
		SpecialBlockType.LASER_H:
			# 横向激光：消除整行，让上方行下落
			destroyed_count = _trigger_laser_h(position, grid_manager)
			if destroyed_count > 0:
				# 整行被消除，让上方行下落
				_remove_empty_row(position.y, grid_manager)
		SpecialBlockType.LASER_V:
			# 纵向激光：消除整列，然后检查是否有完整行被消除
			destroyed_count = _trigger_laser_v(position, grid_manager)
			# 检查并消除完整行（这会自动处理行下落）
			var laser_lines = grid_manager.clear_lines()
			if laser_lines > 0:
				print("[装备系统] 纵向激光正好消除了 ", laser_lines, " 行")
	
	if destroyed_count > 0:
		var type_names = ["炸弹", "横向激光", "纵向激光"]
		print("[装备系统] ", type_names[special_type], " 触发! 额外消除 ", destroyed_count, " 格, 加分: ", destroyed_count * SPECIAL_BLOCK_SCORE_PER_CELL)
		special_block_triggered.emit(["BOMB", "LASER_H", "LASER_V"][special_type], position, destroyed_count)
	
	return destroyed_count * SPECIAL_BLOCK_SCORE_PER_CELL

func _trigger_bomb(position: Vector2i, grid_manager: GridManager) -> int:
	# 触发炸弹效果 - 消除以position为中心的3x3区域
	var destroyed = 0
	
	# 严格限制在3x3范围内
	for dy in range(-1, 2):  # -1, 0, 1
		for dx in range(-1, 2):  # -1, 0, 1
			var x = position.x + dx
			var y = position.y + dy
			
			# 检查边界
			if x >= 0 and x < grid_manager.width and y >= 0 and y < grid_manager.height:
				if grid_manager.grid[y][x] != null:
					destroyed += 1
					grid_manager.grid[y][x] = null
					grid_manager.grid_chars[y][x] = ""
	
	print("[炸弹] 位置(", position.x, ",", position.y, ") 消除", destroyed, "格")
	return destroyed

func _trigger_laser_h(position: Vector2i, grid_manager: GridManager) -> int:
	# 触发横向激光 - 消除整行
	var destroyed = 0
	var y = position.y
	
	if y >= 0 and y < grid_manager.height:
		for x in range(grid_manager.width):
			if grid_manager.grid[y][x] != null:
				destroyed += 1
				grid_manager.grid[y][x] = null
				grid_manager.grid_chars[y][x] = ""
	
	return destroyed

func _trigger_laser_v(position: Vector2i, grid_manager: GridManager) -> int:
	# 触发纵向激光 - 消除整列
	var destroyed = 0
	var x = position.x
	
	if x >= 0 and x < grid_manager.width:
		for y in range(grid_manager.height):
			if grid_manager.grid[y][x] != null:
				destroyed += 1
				grid_manager.grid[y][x] = null
				grid_manager.grid_chars[y][x] = ""
	
	print("[纵向激光] 列", x, " 消除", destroyed, "格")
	return destroyed

func _remove_empty_row(row: int, grid_manager: GridManager):
	# 移除空行并让上方行下落（用于横向激光消除整行后）
	if row < 0 or row >= grid_manager.height:
		return
	
	# 将row行上方的所有行向下移动一格
	for y in range(row, 0, -1):
		for x in range(grid_manager.width):
			grid_manager.grid[y][x] = grid_manager.grid[y - 1][x]
			grid_manager.grid_chars[y][x] = grid_manager.grid_chars[y - 1][x]
	
	# 最顶行清空
	for x in range(grid_manager.width):
		grid_manager.grid[0][x] = null
		grid_manager.grid_chars[0][x] = ""

func get_special_block_color(special_type: int) -> Color:
	# 获取特殊方块的颜色（降低饱和度）
	match special_type:
		SpecialBlockType.BOMB:
			return Color(0.85, 0.45, 0.25, 1)  # 柔和橙色 - 炸弹
		SpecialBlockType.LASER_H:
			return Color(0.3, 0.75, 0.75, 1)  # 柔和青色 - 横向激光
		SpecialBlockType.LASER_V:
			return Color(0.75, 0.4, 0.75, 1)  # 柔和紫色 - 纵向激光
		_:
			return Color.WHITE

func get_special_block_symbol(special_type: int) -> String:
	# 获取特殊方块的显示符号
	match special_type:
		SpecialBlockType.BOMB:
			return "💣"
		SpecialBlockType.LASER_H:
			return "━"
		SpecialBlockType.LASER_V:
			return "┃"
		_:
			return "★"

# ==================== 裂隙仪功能 ====================
func update_rift_meter(delta: float):
	# 更新裂隙仪冷却时间
	if rift_meter_timer > 0:
		rift_meter_timer -= delta

func is_rift_meter_ready() -> bool:
	# 检查裂隙仪是否可用
	return is_equipped(EquipmentType.RIFT_METER) and rift_meter_timer <= 0

func get_rift_meter_cooldown() -> float:
	# 获取裂隙仪剩余冷却时间
	return rift_meter_timer

func try_activate_rift_meter(grid_manager: GridManager) -> bool:
	# 尝试激活裂隙仪：消除差一格的最底行（不计分）
	# 返回是否成功激活
	if not is_rift_meter_ready():
		return false
	
	# 从下往上找差一格的行
	for y in range(grid_manager.height - 1, -1, -1):
		var filled_count = 0
		for x in range(grid_manager.width):
			if grid_manager.grid[y][x] != null:
				filled_count += 1
		
		# 差一格意味着有 width - 1 个方块
		if filled_count == grid_manager.width - 1:
			# 找到了，消除这一行
			for x in range(grid_manager.width):
				grid_manager.grid[y][x] = null
				grid_manager.grid_chars[y][x] = ""
			# 让上方行下落
			_remove_empty_row(y, grid_manager)
			# 启动冷却
			rift_meter_timer = RIFT_METER_COOLDOWN
			print("[裂隙仪] 消除第", y, "行，冷却", RIFT_METER_COOLDOWN, "秒")
			return true
	
	print("[裂隙仪] 没有找到差一格的行")
	return false

# ==================== 贪吃蛇病毒功能 ====================
func reset_snake_virus():
	# 重置贪吃蛇病毒状态
	snake_virus_cooldown = 0
	snake_length = 3

func should_spawn_snake() -> bool:
	# 检查是否应该生成贪吃蛇
	if not is_equipped(EquipmentType.SNAKE_VIRUS):
		return false
	
	# 检查冷却
	if snake_virus_cooldown > 0:
		snake_virus_cooldown -= 1
		return false
	
	# 1%概率
	if randf() < SNAKE_VIRUS_CHANCE:
		snake_virus_cooldown = SNAKE_VIRUS_COOLDOWN
		return true
	
	return false

func get_snake_length() -> int:
	# 获取当前贪吃蛇长度
	return snake_length

func increase_snake_length():
	# 增加贪吃蛇长度（每次出现+1）
	snake_length += 1
	print("[贪吃蛇] 长度增加到", snake_length)

# ==================== 节拍校对器功能 ====================
enum BeatRating {
	MISS,     # x0.5分数
	GOOD,     # x1.0分数
	PERFECT   # x1.5分数
}

func reset_beat_calibrator():
	# 重置节拍校对器状态
	beat_combo = 0

func get_beat_rating(target_time: float, actual_time: float) -> int:
	# 根据时间差计算节拍评价
	# target_time: 目标时间（歌词对应的理想落下时间）
	# actual_time: 实际落地时间（当前音乐时间）
	# 返回BeatRating枚举值
	var time_diff = abs(actual_time - target_time)
	
	# 调整阈值：考虑到方块下落需要时间，给予更宽容的判定
	# PERFECT: 误差在0.325秒内（前后初始0.3s+25ms）
	# GOOD: 误差在0.825秒内（前后初始0.8s+25ms）
	# MISS: 误差超过0.825秒
	if time_diff <= 0.325:
		return BeatRating.PERFECT
	elif time_diff <= 0.825:
		return BeatRating.GOOD
	else:
		return BeatRating.MISS

func get_beat_score_multiplier(rating: int) -> float:
	# 获取节拍评价对应的分数倍率
	# MISS×60%, GOOD×100%, PERFECT×135%
	match rating:
		BeatRating.MISS:
			return 0.6
		BeatRating.GOOD:
			return 1.0
		BeatRating.PERFECT:
			return 1.35
		_:
			return 1.0

func update_beat_combo(rating: int):
	# 更新节拍连击数
	if rating == BeatRating.MISS:
		beat_combo = 0
	else:
		beat_combo += 1

func get_beat_combo() -> int:
	# 获取当前节拍连击数
	return beat_combo

func get_beat_rating_text(rating: int) -> String:
	# 获取评价文字
	match rating:
		BeatRating.MISS:
			return "MISS"
		BeatRating.GOOD:
			return "GOOD"
		BeatRating.PERFECT:
			return "PERFECT"
		_:
			return ""

func get_beat_rating_color(rating: int) -> Color:
	# 获取评价颜色
	match rating:
		BeatRating.MISS:
			return Color(0.8, 0.3, 0.3, 1)  # 红色
		BeatRating.GOOD:
			return Color(0.3, 0.7, 0.9, 1)  # 蓝色
		BeatRating.PERFECT:
			return Color(1.0, 0.85, 0.2, 1)  # 金色
		_:
			return Color.WHITE

func get_beat_multiplier(rating: int) -> float:
	# 获取节拍评价对应的得分倍率
	# MISS×60%, GOOD×100%, PERFECT×135%
	match rating:
		BeatRating.MISS:
			return 0.6
		BeatRating.GOOD:
			return 1.0
		BeatRating.PERFECT:
			return 1.35
		_:
			return 1.0
