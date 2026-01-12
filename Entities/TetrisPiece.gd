extends RefCounted
class_name TetrisPiece

## 俄罗斯方块块 - 单一职责：管理单个方块的状态和行为

var shape_name: String
var rotation: int = 0
var position: Vector2i
var cells: Array  # 当前旋转状态的单元格
var chars: Array = []  # 方块携带的字符（歌词模式）

func _init(shape: String, pos: Vector2i, characters: Array = []):
	shape_name = shape
	position = pos
	rotation = 0
	chars = characters
	update_cells()

func update_cells():
	"""更新当前旋转状态的单元格"""
	if GameConfig.SHAPES.has(shape_name):
		var rotations = GameConfig.SHAPES[shape_name]
		cells = rotations[rotation % rotations.size()]

func rotate():
	"""旋转方块"""
	# 只有O和DOT不能旋转
	if shape_name == "O" or shape_name == "DOT":
		return
	# PLUS是对称的，不需要旋转
	if shape_name == "PLUS":
		return
	
	var rotations = GameConfig.SHAPES[shape_name]
	rotation = (rotation + 1) % rotations.size()
	update_cells()

func try_rotate(grid_manager: GridManager) -> bool:
	"""尝试旋转，带墙踢"""
	if shape_name == "O" or shape_name == "DOT" or shape_name == "PLUS":
		return false
	
	var old_rotation = rotation
	rotate()
	
	# 尝试在当前位置旋转
	if can_place(grid_manager, position):
		return true
	
	# 智能墙踢：根据方块大小调整尝试范围
	var max_x = 0
	var max_y = 0
	for cell in cells:
		max_x = max(max_x, cell.x)
		max_y = max(max_y, cell.y)
	
	# 根据大小设置墙踢范围
	var kick_offsets = []
	if max_x <= 2 and max_y <= 2:
		kick_offsets = [Vector2i(-1, 0), Vector2i(1, 0)]
	elif max_x <= 3 and max_y <= 3:
		kick_offsets = [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(-2, 0), Vector2i(2, 0)]
	else:
		kick_offsets = [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(-2, 0), Vector2i(2, 0), Vector2i(0, -1)]
	
	for offset in kick_offsets:
		if can_place(grid_manager, position + offset):
			position += offset
			return true
	
	# 旋转失败，恢复
	rotation = old_rotation
	update_cells()
	return false

func move(direction: Vector2i, grid_manager: GridManager) -> bool:
	"""移动方块"""
	var new_pos = position + direction
	if can_place(grid_manager, new_pos):
		position = new_pos
		return true
	return false

func can_place(grid_manager: GridManager, pos: Vector2i) -> bool:
	"""检查方块是否可以放置在指定位置"""
	for cell in cells:
		var x = pos.x + cell.x
		var y = pos.y + cell.y
		
		# 检查边界
		if x < 0 or x >= grid_manager.width or y >= grid_manager.height:
			return false
		
		# 检查是否与已有方块重叠
		if not grid_manager.is_cell_empty(x, y):
			return false
	
	return true

func place_on_grid(grid_manager: GridManager, color: Color):
	"""将方块放置到网格上"""
	var cell_index = 0
	for cell in cells:
		var x = position.x + cell.x
		var y = position.y + cell.y
		if y >= 0:
			var char = chars[cell_index] if cell_index < chars.size() else ""
			grid_manager.set_cell(x, y, color, char)
		cell_index += 1

func get_absolute_cells() -> Array:
	"""获取方块的绝对位置单元格"""
	var result = []
	for cell in cells:
		result.append(position + cell)
	return result
