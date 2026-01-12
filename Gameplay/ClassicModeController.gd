extends BaseGameModeController
class_name ClassicModeController

## 经典俄罗斯方块模式控制器

signal snake_mode_changed(is_snake: bool)  # 贪吃蛇模式变化信号

var next_shape: String = ""
var difficulty: int = 0  # 0=简单, 1=普通, 2=困难, 3=残酷

# 下一个方块的特殊属性
var next_is_special_block: bool = false
var next_special_block_type: int = -1

# 下一个是贪吃蛇
var next_is_snake: bool = false

# 贪吃蛇控制器
var snake_controller: SnakeController = null
var is_snake_mode: bool = false  # 当前是否是贪吃蛇模式

# 残酷模式专用变量
var cruel_cached_score: int = 0  # 累计分数用于生成障碍行
const CRUEL_OBSTACLE_THRESHOLD: int = 2000  # 每2000分生成一行障碍

func initialize():
	difficulty = Global.classic_difficulty
	cruel_cached_score = 0
	next_is_special_block = false
	next_special_block_type = -1
	next_is_snake = false
	is_snake_mode = false
	if snake_controller:
		snake_controller = null
	equipment_system.reset_snake_virus()
	super.initialize()
	generate_next_piece()
	spawn_piece()

func generate_next_piece():
	"""根据难度生成下一个方块类型"""
	if difficulty == 0:
		# 简单：只使用7种经典方块
		next_shape = GameConfig.CLASSIC_SHAPES[randi() % GameConfig.CLASSIC_SHAPES.size()]
	else:
		# 普通/困难/残酷：使用所有方块类型
		var rand_val = randf()
		var piece_size: int
		
		if difficulty == 1:
			# 普通：92% 4格, 7% 5格, 0.9% 6格, 0.1% 7格
			if rand_val < 0.92:
				piece_size = 4
			elif rand_val < 0.99:
				piece_size = 5
			elif rand_val < 0.999:
				piece_size = 6
			else:
				piece_size = 7
		elif difficulty == 2:
			# 困难：和歌词模式一样的概率（2% 3格, 73% 4格, 22% 5格, 2.6% 6格, 0.4% 7格）
			if rand_val < 0.02:
				piece_size = 3
			elif rand_val < 0.75:
				piece_size = 4
			elif rand_val < 0.97:
				piece_size = 5
			elif rand_val < 0.996:
				piece_size = 6
			else:
				piece_size = 7
		else:
			# 残酷：4% 3格, 66% 4格, 25% 5格, 3.6% 6格, 1.4% 7格
			if rand_val < 0.04:
				piece_size = 3
			elif rand_val < 0.70:
				piece_size = 4
			elif rand_val < 0.95:
				piece_size = 5
			elif rand_val < 0.986:
				piece_size = 6
			else:
				piece_size = 7
		
		# 根据方块大小选择形状
		var shapes_by_size = {
			1: ["DOT"],
			2: ["I2"],
			3: ["I3", "L3"],
			4: GameConfig.CLASSIC_SHAPES,
			5: ["PLUS", "T5", "L5", "L5R", "I5", "U5", "S5"],
			6: ["L6", "RECT", "I6"],
			7: ["T7", "BIG_T", "I7"]
		}
		
		var available_shapes = shapes_by_size.get(piece_size, GameConfig.CLASSIC_SHAPES)
		next_shape = available_shapes[randi() % available_shapes.size()]
	
	next_piece_data = {
		"shape": next_shape,
		"chars": []
	}
	
	# 检查下一个方块是否是特殊方块
	var special_result = equipment_system.on_piece_spawned()
	if special_result.is_special:
		next_is_special_block = true
		next_special_block_type = special_result.special_type
		# 特殊方块使用DOT形状
		next_piece_data = {
			"shape": "DOT",
			"chars": []
		}
		next_is_snake = false
	else:
		next_is_special_block = false
		next_special_block_type = -1
		
		# 检查是否生成贪吃蛇
		if equipment_system.should_spawn_snake():
			next_is_snake = true
			equipment_system.increase_snake_length()
			print("[经典模式] 下一个是贪吃蛇！")
		else:
			next_is_snake = false

func get_fall_speed() -> float:
	"""根据难度和分数计算下落速度"""
	var base_speed = GameConfig.FALL_SPEED
	
	# 应用装备速度倍率（故障的计分增幅器）
	var equipment_speed_mult = equipment_system.get_speed_multiplier()
	
	if difficulty == 0:
		# 简单：固定速度
		return base_speed / equipment_speed_mult
	elif difficulty == 1:
		# 普通：每250分增加0.3%，最高133.3%
		var speed_multiplier = 1.0 + (score / 250.0) * 0.003
		speed_multiplier = min(speed_multiplier, 1.333)
		return base_speed / (speed_multiplier * equipment_speed_mult)
	elif difficulty == 2:
		# 困难：每100分增加0.5%，最高200%
		var speed_multiplier = 1.0 + (score / 100.0) * 0.005
		speed_multiplier = min(speed_multiplier, 2.0)
		return base_speed / (speed_multiplier * equipment_speed_mult)
	else:
		# 残酷：初始120%，每200分+1%，最高250%
		var speed_multiplier = 1.2 + (score / 200.0) * 0.01
		speed_multiplier = min(speed_multiplier, 2.5)
		return base_speed / (speed_multiplier * equipment_speed_mult)

func get_lock_delay() -> float:
	"""根据难度和分数计算方块锁定延迟"""
	var base_delay = GameConfig.LOCK_DELAY  # 3毫秒 = 0.003秒
	
	if difficulty == 0 or difficulty == 1:
		# 简单/普通：使用默认锁定时间
		return base_delay
	elif difficulty == 2:
		# 困难：每2500分减少0.5毫秒，最小0.5毫秒
		var reduction = int(score / 2500) * 0.0005  # 每2500分减少0.5ms
		var new_delay = base_delay - reduction
		return max(new_delay, 0.0005)  # 最小0.5毫秒
	else:
		# 残酷：每2000分减少0.5毫秒，最小0.3毫秒
		var reduction = int(score / 2000) * 0.0005
		var new_delay = base_delay - reduction
		return max(new_delay, 0.0003)  # 最小0.3毫秒

func spawn_piece():
	"""生成新方块"""
	if next_shape.is_empty():
		generate_next_piece()
	
	# 检查是否生成贪吃蛇
	if next_is_snake:
		_start_snake_mode()
		# 生成新的下一个方块
		generate_next_piece()
		return
	
	# 使用预先计算的下一个方块的特殊属性
	if next_is_special_block:
		# 生成特殊方块（单格）
		is_special_block = true
		special_block_type = next_special_block_type
		var start_pos = Vector2i(GameConfig.GRID_WIDTH / 2, 0)
		current_piece = TetrisPiece.new("DOT", start_pos)
		print("[经典模式] 生成特殊方块: ", ["炸弹", "横向激光", "纵向激光"][special_block_type])
	else:
		# 正常方块
		is_special_block = false
		special_block_type = -1
		var start_pos = Vector2i(GameConfig.GRID_WIDTH / 2 - 2, 0)
		current_piece = TetrisPiece.new(next_shape, start_pos)
	
	# 生成新的下一个方块（包括检查是否是特殊方块）
	generate_next_piece()
	
	# 检查游戏是否结束
	check_game_over()

func _start_snake_mode():
	"""开始贪吃蛇模式"""
	is_snake_mode = true
	current_piece = null  # 暂时没有俄罗斯方块
	
	# 创建贪吃蛇控制器
	snake_controller = SnakeController.new()
	snake_controller.initialize(equipment_system.get_snake_length(), GameConfig.GRID_WIDTH, GameConfig.GRID_HEIGHT)
	snake_controller.snake_fixed.connect(_on_snake_fixed)
	snake_controller.snake_abandoned.connect(_on_snake_abandoned)
	
	snake_mode_changed.emit(true)
	print("[经典模式] 开始贪吃蛇模式，长度:", equipment_system.get_snake_length())

func _on_snake_fixed(cells: Array):
	"""贪吃蛇固定时的回调"""
	is_snake_mode = false
	snake_controller = null
	snake_mode_changed.emit(false)
	
	# 检查是否有行可以消除
	var lines_cleared = grid_manager.clear_lines()
	if lines_cleared > 0:
		lines_cleared_total += lines_cleared
		var score_table = get_line_score_table()
		var max_index = score_table.size() - 1
		var base_score = score_table[min(lines_cleared, max_index)]
		
		combo += 1
		var combo_bonus = 0
		if combo > 1:
			combo_bonus = base_score * 10 * (combo - 1)
		
		var score_multiplier = equipment_system.get_score_multiplier(combo > 1)
		var final_base_score = int(base_score * score_multiplier)
		
		var old_score = score
		score += final_base_score + combo_bonus
		on_score_updated(score, old_score, final_base_score)
		score_changed.emit(score)
		lines_changed.emit(lines_cleared_total)
		combo_changed.emit(combo)
	else:
		if combo > 0:
			combo = 0
			combo_changed.emit(combo)
	
	# 生成新方块
	spawn_piece()

func _on_snake_abandoned():
	"""贪吃蛇放弃时的回调"""
	is_snake_mode = false
	snake_controller = null
	snake_mode_changed.emit(false)
	
	# 直接生成新方块
	spawn_piece()

func handle_snake_input(event: InputEvent):
	"""处理贪吃蛇输入"""
	if snake_controller and is_snake_mode:
		snake_controller.handle_input(event)

func update_snake(delta: float):
	"""更新贪吃蛇逻辑"""
	if snake_controller and is_snake_mode:
		snake_controller.update(delta, grid_manager)

func get_line_score_table() -> Array:
	"""根据难度返回得分表"""
	if difficulty == 0:
		# 简单模式：只有4格方块，使用简单得分表
		return GameConfig.LINE_SCORES_EASY
	else:
		# 普通/困难/残酷模式：可能消5-7行
		return GameConfig.LINE_SCORES_FULL

func get_piece_color() -> Color:
	"""获取方块颜色 - 处理特殊方块"""
	if is_special_block and special_block_type >= 0:
		return equipment_system.get_special_block_color(special_block_type)
	return super.get_piece_color()

func on_score_updated(new_score: int, old_score: int, base_score_without_combo: int = 0):
	"""分数更新回调，用于残酷模式生成障碍行
	   只计算基础分数（不含连击加分）"""
	if difficulty != 3:
		return
	
	# 使用不含连击的基础分数计算障碍行
	# 如果base_score_without_combo为0，则使用差值（兼容旧代码）
	var score_for_obstacle = base_score_without_combo if base_score_without_combo > 0 else (new_score - old_score)
	cruel_cached_score += score_for_obstacle
	
	# 检查是否需要生成障碍行
	while cruel_cached_score >= CRUEL_OBSTACLE_THRESHOLD:
		cruel_cached_score -= CRUEL_OBSTACLE_THRESHOLD
		_spawn_cruel_obstacle_row()
		print("[残酷模式] 生成障碍行! 基础分累计:", cruel_cached_score, " (不含连击)")

func _spawn_cruel_obstacle_row():
	"""在最底部生成一行随机缺一格的灰色方块"""
	# 先将所有行向上移动一格
	for y in range(1, grid_manager.height):
		for x in range(grid_manager.width):
			grid_manager.grid[y - 1][x] = grid_manager.grid[y][x]
			grid_manager.grid_chars[y - 1][x] = grid_manager.grid_chars[y][x]
	
	# 在最底部生成障碍行
	var bottom_row = grid_manager.height - 1
	var empty_col = randi() % grid_manager.width  # 随机选择一个空格位置
	
	for x in range(grid_manager.width):
		if x == empty_col:
			grid_manager.grid[bottom_row][x] = null
			grid_manager.grid_chars[bottom_row][x] = ""
		else:
			grid_manager.grid[bottom_row][x] = Color.GRAY
			grid_manager.grid_chars[bottom_row][x] = ""
