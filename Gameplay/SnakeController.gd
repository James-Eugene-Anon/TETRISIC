extends RefCounted
class_name SnakeController

## 贪吃蛇控制器 - 管理贪吃蛇病毒的游戏逻辑

signal snake_fixed(cells: Array)  # 贪吃蛇固定为方块
signal snake_abandoned  # 贪吃蛇撞到上壁消失

var body: Array[Vector2i] = []  # 蛇身，body[0]是头
var direction: Vector2i = Vector2i(0, 1)  # 当前移动方向（初始向下）
var grid_width: int
var grid_height: int
var is_active: bool = false

# 移动计时
var move_timer: float = 0.0
const MOVE_INTERVAL: float = 0.18  # 移动间隔（秒）- 原0.15秒的约1.2倍

func initialize(length: int, grid_w: int, grid_h: int):
	"""初始化贪吃蛇
	   length: 初始长度
	   grid_w: 网格宽度
	   grid_h: 网格高度"""
	grid_width = grid_w
	grid_height = grid_h
	
	# 从顶部中间开始生成，蛇头在上方，蛇尾在下方
	# 这样向下移动时不会碰撞自己
	body.clear()
	var start_x = grid_width / 2
	for i in range(length):
		body.append(Vector2i(start_x, -1 - i))  # 蛇头在-1，蛇身向上延伸
	
	direction = Vector2i(0, 1)  # 初始向下
	is_active = true
	move_timer = 0.0
	print("[贪吃蛇] 初始化，长度:", length, " 起始位置:", body[0])

func update(delta: float, grid_manager: GridManager) -> bool:
	"""更新贪吃蛇状态
	   返回是否仍在活动"""
	if not is_active:
		return false
	
	move_timer += delta
	if move_timer >= MOVE_INTERVAL:
		move_timer = 0.0
		return move_snake(grid_manager)
	return true

func move_snake(grid_manager: GridManager) -> bool:
	"""移动贪吃蛇一格
	   返回是否仍在活动"""
	if body.is_empty():
		is_active = false
		return false
	
	var head = body[0]
	var new_head = head + direction
	
	# 检查左右边界 - 传送
	if new_head.x < 0:
		new_head.x = grid_width - 1
	elif new_head.x >= grid_width:
		new_head.x = 0
	
	# 检查上边界 - 只有向上移动且超出屏幕时才放弃（消失）
	# 初始从屏幕外进入时不触发
	if new_head.y < 0 and direction.y < 0:
		print("[贪吃蛇] 向上撞出屏幕，消失")
		is_active = false
		body.clear()
		snake_abandoned.emit()
		return false
	
	# 检查下边界或其他方块 - 固定
	if new_head.y >= grid_height or _check_collision(new_head, grid_manager):
		print("[贪吃蛇] 撞到底壁或方块，固定")
		_fix_snake(grid_manager)
		return false
	
	# 检查自身碰撞
	for i in range(1, body.size()):
		if body[i] == new_head:
			print("[贪吃蛇] 撞到自身，固定")
			_fix_snake(grid_manager)
			return false
	
	# 正常移动 - 头部前进，尾部跟随
	body.insert(0, new_head)
	body.pop_back()
	
	return true

func _check_collision(pos: Vector2i, grid_manager: GridManager) -> bool:
	"""检查位置是否与现有方块碰撞"""
	if pos.y < 0 or pos.y >= grid_height:
		return false
	if pos.x < 0 or pos.x >= grid_width:
		return false
	return grid_manager.grid[pos.y][pos.x] != null

func _fix_snake(grid_manager: GridManager):
	"""将贪吃蛇固定为方块"""
	var fixed_cells = []
	for cell in body:
		if cell.y >= 0 and cell.y < grid_height and cell.x >= 0 and cell.x < grid_width:
			# 只固定在游戏区域内的部分
			grid_manager.grid[cell.y][cell.x] = Color(0.4, 0.8, 0.4, 1)  # 绿色
			grid_manager.grid_chars[cell.y][cell.x] = ""
			fixed_cells.append(cell)
	
	is_active = false
	body.clear()
	snake_fixed.emit(fixed_cells)
	print("[贪吃蛇] 固定了", fixed_cells.size(), "个方块")

func change_direction(new_dir: Vector2i):
	"""改变移动方向（不能直接反向）"""
	# 检查是否是180度转向
	if new_dir.x == -direction.x and new_dir.y == -direction.y:
		return  # 不允许直接反向
	
	direction = new_dir
	print("[贪吃蛇] 方向改变:", direction)

func handle_input(event: InputEvent):
	"""处理贪吃蛇输入"""
	if not is_active:
		return
	
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_UP:
				change_direction(Vector2i(0, -1))
			KEY_DOWN:
				change_direction(Vector2i(0, 1))
			KEY_LEFT:
				change_direction(Vector2i(-1, 0))
			KEY_RIGHT:
				change_direction(Vector2i(1, 0))

func get_body_positions() -> Array[Vector2i]:
	"""获取蛇身所有位置"""
	return body
