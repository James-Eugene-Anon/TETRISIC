extends Control
class_name RainbowTitle

## 彩虹标题组件 - 显示彩色渐变文字（波浪动画版）

@export var title_text: String = "TETRISIC"
@export var font_size: int = 48
@export var animation_speed: float = 0.8  # 颜色动画速度
@export var wave_speed: float = 3.0  # 波浪速度
@export var wave_amplitude: float = 6.0  # 波浪振幅

# 高饱和度彩色（鲜艳色调）
var colors = [
	Color(1, 0.2, 0.2),   # 红
	Color(1, 0.5, 0.1),   # 橙
	Color(1, 0.95, 0.1),  # 黄
	Color(0.2, 1, 0.3),   # 绿
	Color(0.1, 0.95, 0.9),  # 青
	Color(0.2, 0.4, 1),   # 蓝
	Color(0.6, 0.2, 1),   # 紫
	Color(1, 0.3, 0.6),   # 粉
]

var color_offset: float = 0.0
var wave_time: float = 0.0
var font: Font

func _ready():
	# 尝试加载字体
	font = load("res://fonts/FUSION-PIXEL-12PX-MONOSPACED-ZH_HANS.OTF")

func _process(delta):
	# 更新颜色偏移（平滑过渡）
	color_offset += delta * animation_speed
	if color_offset >= colors.size():
		color_offset -= colors.size()
	# 更新波浪时间
	wave_time += delta * wave_speed
	queue_redraw()

func _draw():
	if font == null:
		return
	
	# 零间距：精确获取每个字符宽度
	var char_widths = []
	var total_width = 0.0
	for i in range(title_text.length()):
		var char = title_text[i]
		var w = font.get_string_size(char, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		char_widths.append(w)
		total_width += w
	
	var start_x = (size.x - total_width) / 2
	var base_y = size.y / 2 + font_size / 3
	
	var current_x = start_x
	
	# 绘制每个字符（带波浪效果）
	for i in range(title_text.length()):
		var char = title_text[i]
		
		# 波浪偏移：每个字母有不同相位
		var wave_offset = sin(wave_time + i * 0.5) * wave_amplitude
		var y = base_y + wave_offset
		
		# 计算颜色索引（平滑过渡）
		var color_index = fmod(i * 0.7 + color_offset, colors.size())
		var color1_idx = int(color_index) % colors.size()
		var color2_idx = (color1_idx + 1) % colors.size()
		var blend = color_index - int(color_index)
		# 使用平滑插值
		blend = blend * blend * (3 - 2 * blend)
		
		# 颜色混合
		var color = colors[color1_idx].lerp(colors[color2_idx], blend)
		
		# 绘制阴影
		var shadow_offset = Vector2(2, 2)
		draw_string(font, Vector2(current_x, y) + shadow_offset, char, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0, 0, 0, 0.5))
		
		# 绘制主文字
		draw_string(font, Vector2(current_x, y), char, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
		
		# 移动到下一个字符位置（零间距）
		current_x += char_widths[i]
