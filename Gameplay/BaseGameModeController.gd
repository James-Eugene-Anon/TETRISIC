extends Node
class_name BaseGameModeController

## 游戏模式基类 - 定义游戏模式的通用接口和行为

signal game_over_signal
signal score_changed(score: int)
signal lines_changed(lines: int)
signal combo_changed(combo: int)  # 连击数变化信号
signal special_block_effect(effect_type: String, position: Vector2i, destroyed: int)  # 特殊方块效果信号

var grid_manager: GridManager
var current_piece: TetrisPiece = null
var next_piece_data: Dictionary = {}  # {shape: String, chars: Array}
var equipment_system: EquipmentSystem = null  # 装备系统

var score: int = 0
var lines_cleared_total: int = 0
var combo: int = 0  # 当前连击数
var game_over: bool = false
var paused: bool = false

# 方块下落和锁定
var fall_timer: float = 0.0
var lock_timer: float = 0.0
var is_locking: bool = false

# 特殊方块状态
var is_special_block: bool = false
var special_block_type: int = -1

func _init():
	grid_manager = GridManager.new(GameConfig.GRID_WIDTH, GameConfig.GRID_HEIGHT)
	equipment_system = EquipmentSystem.new()

func initialize():
	"""初始化游戏模式"""
	grid_manager.initialize()
	score = 0
	lines_cleared_total = 0
	combo = 0
	game_over = false
	paused = false
	fall_timer = 0.0
	lock_timer = 0.0
	is_locking = false
	is_special_block = false
	special_block_type = -1

func update(delta: float):
	"""更新游戏逻辑"""
	if paused or game_over:
		return
	
	if current_piece != null:
		# 自动下落
		fall_timer += delta
		var current_fall_speed = get_fall_speed()
		if fall_timer >= current_fall_speed:
			fall_timer = 0.0
			if not current_piece.move(Vector2i(0, 1), grid_manager):
				# 无法下落，开始锁定倒计时
				if not is_locking:
					is_locking = true
					lock_timer = 0.0
		
		# 处理方块锁定
		if is_locking:
			lock_timer += delta
			if lock_timer >= get_lock_delay():
				lock_piece()
				is_locking = false
				lock_timer = 0.0

func get_fall_speed() -> float:
	"""获取下落速度 - 子类可重写"""
	# 应用装备速度倍率（故障的计分增幅器）
	var equipment_speed_mult = equipment_system.get_speed_multiplier()
	return GameConfig.FALL_SPEED / equipment_speed_mult

func get_lock_delay() -> float:
	"""获取方块锁定延迟 - 子类可重写"""
	return GameConfig.LOCK_DELAY

func spawn_piece():
	"""生成新方块 - 子类实现"""
	pass

func lock_piece():
	"""锁定方块到网格"""
	if current_piece == null:
		return
	
	var color = get_piece_color()
	var piece_position = current_piece.position + current_piece.cells[0]  # 获取方块实际位置
	current_piece.place_on_grid(grid_manager, color)
	
	# 保存特殊方块状态供后续使用
	var was_special_block = is_special_block
	var saved_special_type = special_block_type
	
	# 重置特殊方块状态
	is_special_block = false
	special_block_type = -1
	
	# 清除完整的行
	var lines_cleared = grid_manager.clear_lines()
	if lines_cleared > 0:
		lines_cleared_total += lines_cleared
		# 使用子类提供的得分表
		var score_table = get_line_score_table()
		var max_index = score_table.size() - 1
		var base_score = score_table[min(lines_cleared, max_index)]
		
		# 连击机制：连续消除时，额外获得 原始得分 * 10 * 连击数
		combo += 1
		var combo_bonus = 0
		if combo > 1:
			combo_bonus = base_score * 10 * (combo - 1)  # 第一次消除无连击加分
			print("[连击] ", combo, " 连击！基础分: ", base_score, " 连击加分: ", combo_bonus)
		
		# 应用非连击得分倍率（故障的计分增幅器）
		var score_multiplier = equipment_system.get_score_multiplier(combo > 1)
		var final_base_score = int(base_score * score_multiplier)
		
		var old_score = score
		score += final_base_score + combo_bonus
		# 传递基础分（不含连击）用于残酷模式障碍行计算
		on_score_updated(score, old_score, final_base_score)
		score_changed.emit(score)
		lines_changed.emit(lines_cleared_total)
		combo_changed.emit(combo)
	else:
		# 没有消除，重置连击数
		if combo > 0:
			combo = 0
			combo_changed.emit(combo)
	
	# 在正常消除行之后触发特殊方块效果
	if was_special_block and saved_special_type >= 0:
		var special_score = equipment_system.trigger_special_block_after_clear(
			saved_special_type, piece_position, grid_manager, lines_cleared)
		if special_score > 0:
			var old_score = score
			score += special_score
			on_score_updated(score, old_score, special_score)  # 特殊方块分数也不含连击
			score_changed.emit(score)
			special_block_effect.emit(["BOMB", "LASER_H", "LASER_V"][saved_special_type], piece_position, special_score / 5)
	
	# 生成新方块
	spawn_piece()

func get_line_score_table() -> Array:
	"""获取得分表 - 子类可重写"""
	return GameConfig.LINE_SCORES_EASY

func on_score_updated(new_score: int, old_score: int, base_score_without_combo: int = 0):
	"""分数更新回调 - 子类可重写
	   base_score_without_combo: 不含连击加分的基础分数，用于残酷模式障碍行计算"""
	pass

func get_piece_color() -> Color:
	"""获取方块颜色 - 子类可重写"""
	if current_piece and GameConfig.COLORS.has(current_piece.shape_name):
		return GameConfig.COLORS[current_piece.shape_name]
	return Color.WHITE

func move_piece(direction: Vector2i):
	"""移动方块"""
	if current_piece and current_piece.move(direction, grid_manager):
		# 向下移动成功时重置锁定计时器
		if direction.y == 1:
			is_locking = false
			lock_timer = 0.0

func rotate_piece():
	"""旋转方块"""
	if current_piece and current_piece.try_rotate(grid_manager):
		is_locking = false
		lock_timer = 0.0

func hard_drop():
	"""硬降落"""
	if current_piece == null:
		return
	
	while current_piece.move(Vector2i(0, 1), grid_manager):
		pass
	
	lock_piece()
	is_locking = false
	lock_timer = 0.0

func toggle_pause():
	"""切换暂停状态"""
	paused = !paused

func check_game_over() -> bool:
	"""检查游戏是否结束"""
	if current_piece and not current_piece.can_place(grid_manager, current_piece.position):
		game_over = true
		game_over_signal.emit()
		return true
	return false
