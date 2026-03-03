extends Node2D
class_name GameRenderer

## 游戏渲染器 - 单一职责：负责绘制游戏画面

var grid_manager: GridManager
var current_piece: TetrisPiece
var next_piece_data: Dictionary
var is_lyric_mode: bool = false
var font: Font
var current_lyric_piece_color: Color = Color.WHITE  # 当前歌词方块颜色
var next_lyric_piece_color: Color = Color.WHITE  # 下一个歌词方块颜色
var special_block_color: Color = Color.TRANSPARENT  # 特殊方块颜色
var special_block_symbol: String = ""  # 特殊方块符号

# 贪吃蛇相关
var snake_body: Array[Vector2i] = []  # 贪吃蛇身体位置
var is_snake_mode: bool = false
var next_is_snake: bool = false  # 下一个是贪吃蛇

# 节拍校对器相关
var beat_rating_text: String = ""
var beat_rating_color: Color = Color.WHITE
var beat_combo: int = 0
var beat_rating_timer: float = 0.0

func _init():
	font = load("res://fonts/FUSION-PIXEL-12PX-MONOSPACED-ZH_HANS.OTF")

func set_grid_manager(manager: GridManager):
	grid_manager = manager

func set_current_piece(piece: TetrisPiece):
	current_piece = piece

func set_next_piece_data(data: Dictionary):
	next_piece_data = data

func set_lyric_mode(enabled: bool):
	is_lyric_mode = enabled

func set_lyric_piece_colors(current_color: Color, next_color: Color):
	# 设置歌词模式方块颜色
	current_lyric_piece_color = current_color
	next_lyric_piece_color = next_color

func set_special_block_info(color: Color, symbol: String):
	# 设置特殊方块信息
	special_block_color = color
	special_block_symbol = symbol

func set_snake_info(body: Array[Vector2i], is_active: bool, next_snake: bool):
	# 设置贪吃蛇信息
	snake_body = body
	is_snake_mode = is_active
	next_is_snake = next_snake

func set_beat_rating_info(text: String, color: Color, combo: int):
	# 设置节拍评价信息
	beat_rating_text = text
	beat_rating_color = color
	beat_combo = combo
	beat_rating_timer = 1.5  # 显示1.5秒
	queue_redraw()  # 立即刷新显示

func update_beat_timer(delta: float):
	# 更新节拍评价显示计时器
	if beat_rating_timer > 0:
		beat_rating_timer -= delta
		queue_redraw()  # 持续刷新以显示淡出效果
		if beat_rating_timer <= 0:
			beat_rating_text = ""

func _draw():
	if grid_manager == null:
		return
	
	draw_grid_background()
	draw_grid_lines()
	draw_placed_pieces()
	draw_snake()  # 绘制贪吃蛇
	draw_current_piece()
	draw_next_piece_preview()
	draw_beat_rating()  # 绘制节拍评价

func draw_grid_background():
	# 绘制网格背景
	var grid_rect = Rect2(
		GameConfig.GRID_OFFSET_X,
		GameConfig.GRID_OFFSET_Y,
		GameConfig.GRID_WIDTH * GameConfig.CELL_SIZE,
		GameConfig.GRID_HEIGHT * GameConfig.CELL_SIZE
	)
	draw_rect(grid_rect, Color(0.1, 0.1, 0.1))
	draw_rect(grid_rect, Color.WHITE, false, 2)

func draw_grid_lines():
	# 绘制网格线
	for x in range(1, GameConfig.GRID_WIDTH):
		draw_line(
			Vector2(GameConfig.GRID_OFFSET_X + x * GameConfig.CELL_SIZE, GameConfig.GRID_OFFSET_Y),
			Vector2(GameConfig.GRID_OFFSET_X + x * GameConfig.CELL_SIZE, GameConfig.GRID_OFFSET_Y + GameConfig.GRID_HEIGHT * GameConfig.CELL_SIZE),
			Color(0.3, 0.3, 0.3)
		)
	
	for y in range(1, GameConfig.GRID_HEIGHT):
		draw_line(
			Vector2(GameConfig.GRID_OFFSET_X, GameConfig.GRID_OFFSET_Y + y * GameConfig.CELL_SIZE),
			Vector2(GameConfig.GRID_OFFSET_X + GameConfig.GRID_WIDTH * GameConfig.CELL_SIZE, GameConfig.GRID_OFFSET_Y + y * GameConfig.CELL_SIZE),
			Color(0.3, 0.3, 0.3)
		)

func draw_placed_pieces():
	# 绘制已放置的方块
	for y in range(GameConfig.GRID_HEIGHT):
		for x in range(GameConfig.GRID_WIDTH):
			var color = grid_manager.get_cell_color(x, y)
			if color != Color.TRANSPARENT:
				if is_lyric_mode:
					draw_lyric_cell(x, y)
				else:
					draw_classic_cell(x, y, color)

func draw_classic_cell(x: int, y: int, color: Color):
	# 绘制经典模式方块单元格
	draw_rect(
		Rect2(
			GameConfig.GRID_OFFSET_X + x * GameConfig.CELL_SIZE + 1,
			GameConfig.GRID_OFFSET_Y + y * GameConfig.CELL_SIZE + 1,
			GameConfig.CELL_SIZE - 2,
			GameConfig.CELL_SIZE - 2
		),
		color
	)

func draw_lyric_cell(x: int, y: int):
	# 绘制歌词模式方块单元格（文字）
	var char_text = grid_manager.get_cell_char(x, y)
	if char_text.is_empty():
		return
	
	# 获取单元格颜色
	var cell_color = grid_manager.get_cell_color(x, y)
	if cell_color == Color.TRANSPARENT:
		cell_color = Color.WHITE
	
	var font_size = 24
	var string_size = font.get_string_size(char_text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
	var text_pos = Vector2(
		GameConfig.GRID_OFFSET_X + x * GameConfig.CELL_SIZE + (GameConfig.CELL_SIZE - string_size.x) / 2,
		GameConfig.GRID_OFFSET_Y + y * GameConfig.CELL_SIZE + (GameConfig.CELL_SIZE + string_size.y) / 2 - 5
	)
	draw_string(font, text_pos, char_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, cell_color)

func draw_current_piece():
	# 绘制当前方块
	if current_piece == null:
		return
	
	if is_lyric_mode:
		draw_current_lyric_piece()
	else:
		draw_current_classic_piece()

func draw_current_classic_piece():
	# 绘制经典模式当前方块
	var color: Color
	if special_block_color != Color.TRANSPARENT:
		# 特殊方块
		color = special_block_color
	else:
		color = GameConfig.COLORS.get(current_piece.shape_name, Color.WHITE)
	
	for cell in current_piece.cells:
		var x = current_piece.position.x + cell.x
		var y = current_piece.position.y + cell.y
		if y >= 0 and x >= 0 and x < GameConfig.GRID_WIDTH and y < GameConfig.GRID_HEIGHT:
			draw_classic_cell(x, y, color)
			
			# 如果是特殊方块，绘制符号
			if not special_block_symbol.is_empty():
				var font_size = 20
				var string_size = font.get_string_size(special_block_symbol, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
				var text_pos = Vector2(
					GameConfig.GRID_OFFSET_X + x * GameConfig.CELL_SIZE + (GameConfig.CELL_SIZE - string_size.x) / 2,
					GameConfig.GRID_OFFSET_Y + y * GameConfig.CELL_SIZE + (GameConfig.CELL_SIZE + string_size.y) / 2 - 5
				)
				draw_string(font, text_pos, special_block_symbol, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)

func draw_current_lyric_piece():
	# 绘制歌词模式当前方块
	var cell_index = 0
	for cell in current_piece.cells:
		var x = current_piece.position.x + cell.x
		var y = current_piece.position.y + cell.y
		if y >= 0 and x >= 0 and x < GameConfig.GRID_WIDTH and y < GameConfig.GRID_HEIGHT:
			if cell_index < current_piece.chars.size():
				var char_text = current_piece.chars[cell_index]
				if char_text != "\n":
					var font_size = 24
					var string_size = font.get_string_size(char_text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
					var text_pos = Vector2(
						GameConfig.GRID_OFFSET_X + x * GameConfig.CELL_SIZE + (GameConfig.CELL_SIZE - string_size.x) / 2,
						GameConfig.GRID_OFFSET_Y + y * GameConfig.CELL_SIZE + (GameConfig.CELL_SIZE + string_size.y) / 2 - 5
					)
					draw_string(font, text_pos, char_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, current_lyric_piece_color)
		cell_index += 1

func draw_next_piece_preview():
	# 绘制下一个方块预览
	var preview_x = GameConfig.GRID_OFFSET_X + GameConfig.GRID_WIDTH * GameConfig.CELL_SIZE + 30
	var preview_y = 160
	var preview_size = 20
	
	# 扩大预览框以容纳I7（7格横向，需要140像素）
	var box_width = 160  # 从95扩大到160
	var box_height = 95
	
	# 绘制预览框
	draw_rect(Rect2(preview_x - 15, preview_y - 15, box_width, box_height), Color(0.2, 0.2, 0.2))
	draw_rect(Rect2(preview_x - 15, preview_y - 15, box_width, box_height), Color.WHITE, false, 1)
	
	# 如果下一个是贪吃蛇，显示"贪吃蛇"字样
	if next_is_snake:
		var snake_text = "贪吃蛇" if Global.current_language == "zh" else "Snake"
		var font_size = 20
		var text_size = font.get_string_size(snake_text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
		var text_pos = Vector2(preview_x + (box_width - text_size.x) / 2 - 15, preview_y + 40)
		draw_string(font, text_pos, snake_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0.4, 0.9, 0.4))
		
		# 绘制小蛇图标
		var icon_text = "🐍"
		var icon_pos = Vector2(preview_x + box_width / 2 - 25, preview_y + 15)
		draw_string(font, icon_pos, icon_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color.WHITE)
		return
	
	if not next_piece_data.has("shape") or next_piece_data.get("shape", "").is_empty():
		# 没有下一个方块
		if is_lyric_mode:
			var hint_text = "歌曲\n完成"
			var text_size = font.get_string_size(hint_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 16)
			# 居中文字：使用新的box_width
			var text_pos = Vector2(preview_x + (box_width - text_size.x) / 2 - 15, preview_y + 35)
			draw_string(font, text_pos, hint_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.5, 1, 0.5))
		return
	
	var shape = next_piece_data.get("shape", "")
	if not GameConfig.SHAPES.has(shape):
		return
	
	var next_cells = GameConfig.SHAPES[shape][0]
	
	# 计算方块的边界框以居中显示
	var min_x = 999
	var max_x = -999
	var min_y = 999
	var max_y = -999
	for cell in next_cells:
		if cell.x < min_x: min_x = cell.x
		if cell.x > max_x: max_x = cell.x
		if cell.y < min_y: min_y = cell.y
		if cell.y > max_y: max_y = cell.y
	
	var piece_width = (max_x - min_x + 1) * preview_size
	var piece_height = (max_y - min_y + 1) * preview_size
	
	# 计算居中偏移
	var center_offset_x = (box_width - piece_width) / 2 - 15
	var center_offset_y = (box_height - piece_height) / 2 - 15
	
	if is_lyric_mode:
		draw_next_lyric_piece(next_cells, preview_x + center_offset_x, preview_y + center_offset_y, preview_size, min_x, min_y)
	else:
		draw_next_classic_piece(shape, next_cells, preview_x + center_offset_x, preview_y + center_offset_y, preview_size, min_x, min_y)

var next_special_block_color: Color = Color.TRANSPARENT  # 下一个特殊方块颜色
var next_special_block_symbol: String = ""  # 下一个特殊方块符号

func set_next_special_block_info(color: Color, symbol: String):
	# 设置下一个特殊方块信息
	next_special_block_color = color
	next_special_block_symbol = symbol

func draw_next_classic_piece(shape: String, cells: Array, preview_x: int, preview_y: int, preview_size: int, min_x: int, min_y: int):
	# 绘制经典模式预览方块
	var color: Color
	var symbol: String = ""
	
	# 检查是否是特殊方块预览
	if next_special_block_color != Color.TRANSPARENT:
		color = next_special_block_color
		symbol = next_special_block_symbol
	else:
		color = GameConfig.COLORS.get(shape, Color.WHITE)
	
	for cell in cells:
		var cell_x = preview_x + (cell.x - min_x) * preview_size
		var cell_y = preview_y + (cell.y - min_y) * preview_size
		
		draw_rect(
			Rect2(
				cell_x,
				cell_y,
				preview_size - 1,
				preview_size - 1
			),
			color
		)
		
		# 如果是特殊方块，绘制符号
		if not symbol.is_empty():
			var font_size = 14
			var string_size = font.get_string_size(symbol, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
			var text_pos = Vector2(
				cell_x + (preview_size - string_size.x) / 2,
				cell_y + (preview_size + string_size.y) / 2 - 3
			)
			draw_string(font, text_pos, symbol, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)

func draw_next_lyric_piece(cells: Array, preview_x: int, preview_y: int, preview_size: int, min_x: int, min_y: int):
	# 绘制歌词模式预览方块
	var chars = next_piece_data.get("chars", [])
	var cell_idx = 0
	for cell in cells:
		if cell_idx < chars.size():
			var char_text = chars[cell_idx]
			if char_text != "\n":
				var preview_font_size = 16
				var string_size = font.get_string_size(char_text, HORIZONTAL_ALIGNMENT_CENTER, -1, preview_font_size)
				var text_pos = Vector2(
					preview_x + (cell.x - min_x) * preview_size + (preview_size - string_size.x) / 2,
					preview_y + (cell.y - min_y) * preview_size + (preview_size + string_size.y) / 2 - 3
				)
				draw_string(font, text_pos, char_text, HORIZONTAL_ALIGNMENT_LEFT, -1, preview_font_size, next_lyric_piece_color)
		cell_idx += 1

func draw_snake():
	# 绘制贪吃蛇
	if not is_snake_mode or snake_body.is_empty():
		return
	
	var snake_color = Color(0.3, 0.9, 0.3, 1)  # 绿色
	var head_color = Color(0.2, 0.7, 0.2, 1)  # 深绿色（头）
	
	for i in range(snake_body.size()):
		var cell = snake_body[i]
		if cell.y >= 0 and cell.y < GameConfig.GRID_HEIGHT and cell.x >= 0 and cell.x < GameConfig.GRID_WIDTH:
			var color = head_color if i == 0 else snake_color
			draw_rect(
				Rect2(
					GameConfig.GRID_OFFSET_X + cell.x * GameConfig.CELL_SIZE + 1,
					GameConfig.GRID_OFFSET_Y + cell.y * GameConfig.CELL_SIZE + 1,
					GameConfig.CELL_SIZE - 2,
					GameConfig.CELL_SIZE - 2
				),
				color
			)
			
			# 在蛇头绘制眼睛
			if i == 0:
				var font_size = 16
				var text_pos = Vector2(
					GameConfig.GRID_OFFSET_X + cell.x * GameConfig.CELL_SIZE + 5,
					GameConfig.GRID_OFFSET_Y + cell.y * GameConfig.CELL_SIZE + 20
				)
				draw_string(font, text_pos, "◉", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)

func draw_beat_rating():
	# 绘制节拍评价（仅歌曲模式）
	if not is_lyric_mode or beat_rating_text.is_empty():
		return
	
	# 在游戏区域中央偏上显示（更显眼）
	var center_x = GameConfig.GRID_OFFSET_X + (GameConfig.GRID_WIDTH * GameConfig.CELL_SIZE) / 2
	var rating_y = GameConfig.GRID_OFFSET_Y + 80
	
	# 绘制评价文字（更大字号）
	var font_size = 32
	var alpha = min(beat_rating_timer, 1.0)
	var display_color = Color(beat_rating_color.r, beat_rating_color.g, beat_rating_color.b, alpha)
	
	# 文字缩放效果（刚出现时放大）
	var scale_factor = 1.0 + (beat_rating_timer - 1.0) * 0.3 if beat_rating_timer > 1.0 else 1.0
	var scaled_font_size = int(font_size * scale_factor)
	
	var text_width = font.get_string_size(beat_rating_text, HORIZONTAL_ALIGNMENT_CENTER, -1, scaled_font_size).x
	draw_string(font, Vector2(center_x - text_width / 2, rating_y), beat_rating_text, HORIZONTAL_ALIGNMENT_LEFT, -1, scaled_font_size, display_color)
	
	# 绘制节拍连击数
	if beat_combo > 0:
		var combo_text = str(beat_combo) + " Beat Combo!"
		var combo_size = 20
		var combo_width = font.get_string_size(combo_text, HORIZONTAL_ALIGNMENT_CENTER, -1, combo_size).x
		draw_string(font, Vector2(center_x - combo_width / 2, rating_y + 35), combo_text, HORIZONTAL_ALIGNMENT_LEFT, -1, combo_size, Color(0.9, 0.9, 0.9, alpha))
