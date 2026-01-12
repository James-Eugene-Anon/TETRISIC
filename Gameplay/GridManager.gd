extends Node
class_name GridManager

## 网格管理器 - 单一职责：管理游戏网格状态

var grid: Array = []  # 颜色网格
var grid_chars: Array = []  # 字符网格（歌词模式）
var width: int
var height: int

func _init(grid_width: int, grid_height: int):
	width = grid_width
	height = grid_height
	initialize()

func initialize():
	"""初始化空网格"""
	grid.clear()
	grid_chars.clear()
	
	for y in range(height):
		var row = []
		var char_row = []
		for x in range(width):
			row.append(null)
			char_row.append("")
		grid.append(row)
		grid_chars.append(char_row)

func is_valid_position(x: int, y: int) -> bool:
	"""检查位置是否在网格内"""
	return x >= 0 and x < width and y < height

func is_cell_empty(x: int, y: int) -> bool:
	"""检查单元格是否为空"""
	if not is_valid_position(x, y):
		return false
	if y < 0:
		return true  # 网格上方视为空
	return grid[y][x] == null

func set_cell(x: int, y: int, color: Color, character: String = ""):
	"""设置单元格"""
	if is_valid_position(x, y) and y >= 0:
		grid[y][x] = color
		grid_chars[y][x] = character

func clear_lines() -> int:
	"""清除完整的行，返回清除的行数"""
	var lines_cleared = 0
	var y = height - 1
	
	while y >= 0:
		var is_full = true
		for x in range(width):
			if grid[y][x] == null:
				is_full = false
				break
		
		if is_full:
			lines_cleared += 1
			# 移除当前行
			grid.remove_at(y)
			grid_chars.remove_at(y)
			# 在顶部添加新的空行
			var new_row = []
			var new_char_row = []
			for x in range(width):
				new_row.append(null)
				new_char_row.append("")
			grid.insert(0, new_row)
			grid_chars.insert(0, new_char_row)
		else:
			y -= 1
	
	return lines_cleared

func get_cell_color(x: int, y: int) -> Color:
	"""获取单元格颜色"""
	if is_valid_position(x, y) and y >= 0:
		return grid[y][x] if grid[y][x] != null else Color.TRANSPARENT
	return Color.TRANSPARENT

func get_cell_char(x: int, y: int) -> String:
	"""获取单元格字符"""
	if is_valid_position(x, y) and y >= 0:
		return grid_chars[y][x]
	return ""
