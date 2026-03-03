extends "res://Combat/CombatSystemBase.gd"
class_name TetrisCombat

## 俄罗斯方块战斗系统
## 将俄罗斯方块游戏机制整合为战斗系统
## 消除行数转化为伤害，连击增加伤害倍率

signal lines_cleared(count: int, combo: int)
signal tetris_achieved()  # 一次消除4行
signal block_placed(block_type: String)
signal game_over_reached()

# 俄罗斯方块特有属性
var grid_width: int = 10
var grid_height: int = 20
var grid: Array = []  # 2D网格
var current_piece: Dictionary = {}
var next_piece: Dictionary = {}
var hold_piece: Dictionary = {}
var can_hold: bool = true
var combo_count: int = 0
var total_lines_cleared: int = 0

# 伤害计算参数
var damage_per_line: int = 5
var combo_multiplier: float = 0.5  # 每层连击增加50%伤害
var tetris_bonus: int = 20  # 一次消4行额外伤害
var t_spin_bonus: int = 15

var piece_bag: Array = []
var current_rotation: int = 0
var piece_position: Vector2i = Vector2i.ZERO

# 时间相关
var fall_timer: float = 0.0
var fall_speed: float = 1.0  # 每秒下落格数
var lock_delay: float = 0.5
var lock_timer: float = 0.0
var is_locking: bool = false

func _init() -> void:
	_init_grid()

func _init_grid() -> void:
	grid.clear()
	for y in range(grid_height):
		var row = []
		for x in range(grid_width):
			row.append(null)  # null表示空格
		grid.append(row)

func _get_piece_rotations(piece_type: String) -> Array:
	return GameConfig.SHAPES.get(piece_type, [])

func _get_piece_color(piece_type: String) -> Color:
	return GameConfig.COLORS.get(piece_type, Color.WHITE)

## 开始战斗 - 初始化俄罗斯方块游戏
func start_combat(party: Array, enemies: Array) -> void:
	super.start_combat(party, enemies)
	party_data = party
	enemies_data = enemies
	current_state = CombatState.INITIALIZING
	
	_init_grid()
	piece_bag.clear()
	combo_count = 0
	total_lines_cleared = 0
	can_hold = true
	hold_piece = {}
	
	_spawn_next_piece()
	_spawn_piece()

## 处理玩家动作
func apply_player_action(action: Dictionary) -> void:
	var action_type = action.get("type", "")
	
	match action_type:
		"move_left":
			_try_move(-1, 0)
		"move_right":
			_try_move(1, 0)
		"soft_drop":
			_try_move(0, 1)
		"hard_drop":
			_hard_drop()
		"rotate_cw":
			_try_rotate(1)
		"rotate_ccw":
			_try_rotate(-1)
		"hold":
			_try_hold()
		_:
			print("未知动作: ", action_type)

## 处理方块放置后的逻辑
func _on_piece_placed() -> void:
	# 将当前方块写入网格
	var rotations = _get_piece_rotations(current_piece.type)
	if rotations.is_empty():
		return
	var shape = rotations[current_rotation]
	var color = _get_piece_color(current_piece.type)
	
	for offset in shape:
		var x = piece_position.x + offset.x
		var y = piece_position.y + offset.y
		if y >= 0 and y < grid_height and x >= 0 and x < grid_width:
			grid[y][x] = {"color": color, "type": current_piece.type}
	
	block_placed.emit(current_piece.type)
	
	# 检查消除
	var cleared = _check_and_clear_lines()
	
	if cleared > 0:
		combo_count += 1
		total_lines_cleared += cleared
		
		# 计算伤害
		var damage = _calculate_damage(cleared)
		_deal_damage_to_enemies(damage)
		
		lines_cleared.emit(cleared, combo_count)
		
		if cleared >= 4:
			tetris_achieved.emit()
	else:
		combo_count = 0
	
	# 检查游戏结束
	if _check_game_over():
		game_over_reached.emit()
		_trigger_defeat()
		return
	
	# 生成新方块
	can_hold = true
	_spawn_piece()

## 计算伤害
func _calculate_damage(lines: int) -> int:
	var base_damage = lines * damage_per_line
	
	# 连击加成
	var combo_bonus = int(base_damage * combo_multiplier * (combo_count - 1))
	
	# Tetris加成
	var tetris_extra = 0
	if lines >= 4:
		tetris_extra = tetris_bonus
	
	# 装备/遗物加成（从GameState获取）
	var equipment_bonus = 0
	if party_data.size() > 0:
		equipment_bonus = party_data[0].get("attack", 0)
	
	return base_damage + combo_bonus + tetris_extra + equipment_bonus

## 对敌人造成伤害
func _deal_damage_to_enemies(damage: int) -> void:
	if enemies_data.is_empty():
		return
	
	# 伤害第一个存活的敌人
	for i in range(enemies_data.size()):
		if enemies_data[i].get("current_health", 0) > 0:
			apply_damage_to_enemy(i, damage)
			break

## 检查是否所有敌人都被击败
func _check_all_enemies_defeated() -> void:
	if all_enemies_dead():
		_trigger_victory()

## 结束玩家回合 - 俄罗斯方块模式下每放置一个方块算一个"回合"
func end_player_turn() -> void:
	# 在Tetris战斗中，不是传统的回合制
	# 敌人可能有持续伤害或定时攻击
	pass

## 处理敌人回合 - 在Tetris战斗中可能是定时触发
func process_enemy_turn() -> void:
	# 敌人的攻击可以是：
	# 1. 增加垃圾行
	# 2. 加速下落
	# 3. 遮挡视野
	for i in range(enemies_data.size()):
		var enemy = enemies_data[i]
		if enemy.get("current_health", 0) <= 0:
			continue
		
		var action = enemy.get("current_action", {"type": "attack", "value": 5})
		match action.type:
			"garbage_lines":
				_add_garbage_lines(action.value)
			"speed_up":
				fall_speed *= 1.2
			"attack":
				# 直接伤害玩家
				var damage = action.value
				apply_damage_to_player(damage, enemy)

## 添加垃圾行
func _add_garbage_lines(count: int) -> void:
	# 移除顶部的行
	for i in range(count):
		grid.pop_front()
	
	# 在底部添加垃圾行
	var gap = randi() % grid_width
	for i in range(count):
		var garbage_row = []
		for x in range(grid_width):
			if x == gap:
				garbage_row.append(null)
			else:
				garbage_row.append({"color": Color.GRAY, "type": "garbage"})
		grid.append(garbage_row)

## 战斗结束处理
func on_combat_end(result: Dictionary) -> void:
	var victory = result.get("victory", false)
	if victory:
		# 计算奖励（已在父类中计算）
		pass

# === 俄罗斯方块核心逻辑 ===

func _spawn_next_piece() -> void:
	if piece_bag.is_empty():
		piece_bag = GameConfig.CLASSIC_SHAPES.duplicate()
		piece_bag.shuffle()
	
	next_piece = {"type": piece_bag.pop_back()}

func _spawn_piece() -> void:
	current_piece = next_piece
	_spawn_next_piece()
	
	current_rotation = 0
	piece_position = Vector2i(grid_width / 2 - 1, 0)
	is_locking = false
	lock_timer = 0.0

func _try_move(dx: int, dy: int) -> bool:
	var new_pos = piece_position + Vector2i(dx, dy)
	if _is_valid_position(new_pos, current_rotation):
		piece_position = new_pos
		if dy > 0:
			is_locking = false
			lock_timer = 0.0
		return true
	elif dy > 0:
		# 无法下移，开始锁定
		if not is_locking:
			is_locking = true
			lock_timer = 0.0
	return false

func _try_rotate(direction: int) -> bool:
	var rotations = _get_piece_rotations(current_piece.type)
	if rotations.is_empty():
		return false
	var new_rotation = (current_rotation + direction) % rotations.size()
	if new_rotation < 0:
		new_rotation += rotations.size()
	
	if _is_valid_position(piece_position, new_rotation):
		current_rotation = new_rotation
		return true
	
	# Wall kick尝试
	var kicks = [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, -1), Vector2i(1, -1)]
	for kick in kicks:
		if _is_valid_position(piece_position + kick, new_rotation):
			piece_position += kick
			current_rotation = new_rotation
			return true
	
	return false

func _try_hold() -> bool:
	if not can_hold:
		return false
	
	can_hold = false
	
	if hold_piece.is_empty():
		hold_piece = current_piece
		_spawn_piece()
	else:
		var temp = current_piece
		current_piece = hold_piece
		hold_piece = temp
		current_rotation = 0
		piece_position = Vector2i(grid_width / 2 - 1, 0)
	
	return true

func _hard_drop() -> int:
	var distance = 0
	while _try_move(0, 1):
		distance += 1
	_on_piece_placed()
	return distance

func _is_valid_position(pos: Vector2i, rotation: int) -> bool:
	var rotations = _get_piece_rotations(current_piece.type)
	if rotations.is_empty() or rotation < 0 or rotation >= rotations.size():
		return false
	var shape = rotations[rotation]
	
	for offset in shape:
		var x = pos.x + offset.x
		var y = pos.y + offset.y
		
		if x < 0 or x >= grid_width:
			return false
		if y >= grid_height:
			return false
		if y >= 0 and grid[y][x] != null:
			return false
	
	return true

func _check_and_clear_lines() -> int:
	var lines_to_clear = []
	
	for y in range(grid_height):
		var is_full = true
		for x in range(grid_width):
			if grid[y][x] == null:
				is_full = false
				break
		if is_full:
			lines_to_clear.append(y)
	
	# 从下往上清除
	lines_to_clear.sort()
	lines_to_clear.reverse()
	
	for y in lines_to_clear:
		grid.remove_at(y)
		var empty_row = []
		for x in range(grid_width):
			empty_row.append(null)
		grid.insert(0, empty_row)
	
	return lines_to_clear.size()

func _check_game_over() -> bool:
	# 检查生成位置是否被占用
	var rotations = _get_piece_rotations(current_piece.type)
	if rotations.is_empty():
		return true
	var shape = rotations[0]
	var spawn_pos = Vector2i(grid_width / 2 - 1, 0)
	
	for offset in shape:
		var x = spawn_pos.x + offset.x
		var y = spawn_pos.y + offset.y
		if y >= 0 and y < grid_height and x >= 0 and x < grid_width:
			if grid[y][x] != null:
				return true
	
	return false

## 更新游戏（每帧调用）
func update(delta: float) -> void:
	if not is_combat_active:
		return
	
	fall_timer += delta
	
	if fall_timer >= 1.0 / fall_speed:
		fall_timer = 0.0
		if not _try_move(0, 1):
			# 无法下移
			pass
	
	if is_locking:
		lock_timer += delta
		if lock_timer >= lock_delay:
			_on_piece_placed()

## 获取当前游戏状态（用于渲染）
func get_game_state() -> Dictionary:
	return {
		"grid": grid,
		"current_piece": current_piece,
		"current_rotation": current_rotation,
		"piece_position": piece_position,
		"next_piece": next_piece,
		"hold_piece": hold_piece,
		"can_hold": can_hold,
		"combo": combo_count,
		"total_lines": total_lines_cleared,
		"fall_speed": fall_speed,
	}
