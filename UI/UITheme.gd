extends Node
class_name UITheme

## UI主题配置 - 统一的像素风格主题
## 提供一致的颜色、间距、边框等设计规范

# =============================================================================
# 颜色配置
# =============================================================================

# 背景色（从深到浅）
const BG_DARKEST = Color(0.04, 0.03, 0.06)      # 最深背景
const BG_DARK = Color(0.08, 0.06, 0.12)         # 深色背景
const BG_MEDIUM = Color(0.12, 0.10, 0.18)       # 中等背景
const BG_LIGHT = Color(0.18, 0.15, 0.25)        # 浅色背景
const BG_PANEL = Color(0.14, 0.12, 0.20, 0.95)  # 面板背景

# 强调色
const ACCENT_PRIMARY = Color(0.4, 0.7, 0.9)     # 主强调色（蓝）
const ACCENT_SECONDARY = Color(0.9, 0.7, 0.3)   # 次强调色（金）
const ACCENT_SUCCESS = Color(0.3, 0.9, 0.5)     # 成功色（绿）
const ACCENT_DANGER = Color(0.9, 0.3, 0.3)      # 危险色（红）
const ACCENT_WARNING = Color(1.0, 0.7, 0.2)     # 警告色（橙）

# 文字色
const TEXT_PRIMARY = Color(0.95, 0.95, 0.98)    # 主文字
const TEXT_SECONDARY = Color(0.75, 0.75, 0.80)  # 次要文字
const TEXT_MUTED = Color(0.55, 0.55, 0.60)      # 淡化文字
const TEXT_TITLE = Color(0.95, 0.90, 0.70)      # 标题文字（暖色）

# 边框色
const BORDER_LIGHT = Color(0.5, 0.5, 0.6, 0.8)   # 浅边框
const BORDER_MEDIUM = Color(0.4, 0.4, 0.5, 0.9)  # 中等边框
const BORDER_ACCENT = Color(0.5, 0.7, 0.9, 1.0)  # 强调边框

# =============================================================================
# 尺寸配置
# =============================================================================

# 间距
const SPACING_XS = 4
const SPACING_SM = 8
const SPACING_MD = 16
const SPACING_LG = 24
const SPACING_XL = 32

# 边框
const BORDER_THIN = 1
const BORDER_NORMAL = 2
const BORDER_THICK = 3

# 圆角（像素风格：全部为0）
const CORNER_SM = 0
const CORNER_MD = 0
const CORNER_LG = 0

# 按钮
const BUTTON_MIN_WIDTH = 180
const BUTTON_MIN_HEIGHT = 40
const BUTTON_PADDING_H = 20
const BUTTON_PADDING_V = 10

# 面板
const PANEL_PADDING = 20
const PANEL_MIN_WIDTH = 320

# =============================================================================
# 字体配置
# =============================================================================

const FONT_SIZE_XS = 10
const FONT_SIZE_SM = 12
const FONT_SIZE_MD = 14
const FONT_SIZE_LG = 18
const FONT_SIZE_XL = 24
const FONT_SIZE_TITLE = 28
const FONT_SIZE_HEADER = 36

# 全局默认字体
const DEFAULT_FONT = preload(Config.PATHS_FONT_DEFAULT)

# =============================================================================
# 动画配置
# =============================================================================

const ANIM_DURATION_FAST = 0.12
const ANIM_DURATION_NORMAL = 0.2
const ANIM_DURATION_SLOW = 0.35

# =============================================================================
# 工具函数
# =============================================================================

static func create_panel_style(bg_color: Color = BG_PANEL, border_color: Color = BORDER_MEDIUM, 
		corner_radius: int = CORNER_MD, border_width: int = BORDER_NORMAL) -> StyleBoxFlat:
	# 创建面板样式
	var style = StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = border_color
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(corner_radius)
	style.content_margin_left = PANEL_PADDING
	style.content_margin_right = PANEL_PADDING
	style.content_margin_top = PANEL_PADDING
	style.content_margin_bottom = PANEL_PADDING
	return style

static func create_button_style_normal() -> StyleBoxFlat:
	# 创建按钮正常状态样式
	var style = StyleBoxFlat.new()
	style.bg_color = BG_MEDIUM
	style.border_color = BORDER_LIGHT
	style.set_border_width_all(BORDER_THIN)
	style.set_corner_radius_all(CORNER_SM)
	style.content_margin_left = BUTTON_PADDING_H
	style.content_margin_right = BUTTON_PADDING_H
	style.content_margin_top = BUTTON_PADDING_V
	style.content_margin_bottom = BUTTON_PADDING_V
	return style

static func create_button_style_hover() -> StyleBoxFlat:
	# 创建按钮悬停状态样式
	var style = StyleBoxFlat.new()
	style.bg_color = BG_LIGHT
	style.border_color = ACCENT_PRIMARY
	style.set_border_width_all(BORDER_NORMAL)
	style.set_corner_radius_all(CORNER_SM)
	style.content_margin_left = BUTTON_PADDING_H
	style.content_margin_right = BUTTON_PADDING_H
	style.content_margin_top = BUTTON_PADDING_V
	style.content_margin_bottom = BUTTON_PADDING_V
	return style

static func create_button_style_pressed() -> StyleBoxFlat:
	# 创建按钮按下状态样式
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.07, 0.12)
	style.border_color = ACCENT_SECONDARY
	style.set_border_width_all(BORDER_NORMAL)
	style.set_corner_radius_all(CORNER_SM)
	style.content_margin_left = BUTTON_PADDING_H
	style.content_margin_right = BUTTON_PADDING_H
	style.content_margin_top = BUTTON_PADDING_V
	style.content_margin_bottom = BUTTON_PADDING_V
	return style

static func create_button_style_disabled() -> StyleBoxFlat:
	# 创建按钮禁用状态样式
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.05, 0.08, 0.5)
	style.border_color = Color(0.3, 0.3, 0.35, 0.5)
	style.set_border_width_all(BORDER_THIN)
	style.set_corner_radius_all(CORNER_SM)
	style.content_margin_left = BUTTON_PADDING_H
	style.content_margin_right = BUTTON_PADDING_H
	style.content_margin_top = BUTTON_PADDING_V
	style.content_margin_bottom = BUTTON_PADDING_V
	return style

static func apply_button_theme(button: Button, font: Font = null):
	# 应用按钮主题
	button.add_theme_stylebox_override("normal", create_button_style_normal())
	button.add_theme_stylebox_override("hover", create_button_style_hover())
	button.add_theme_stylebox_override("pressed", create_button_style_pressed())
	button.add_theme_stylebox_override("disabled", create_button_style_disabled())
	button.add_theme_color_override("font_color", TEXT_PRIMARY)
	button.add_theme_color_override("font_hover_color", ACCENT_PRIMARY)
	button.add_theme_color_override("font_pressed_color", ACCENT_SECONDARY)
	button.add_theme_color_override("font_disabled_color", TEXT_MUTED)
	
	# 使用指定字体或默认字体
	var target_font = font if font else DEFAULT_FONT
	if target_font:
		button.add_theme_font_override("font", target_font)
		
	button.add_theme_font_size_override("font_size", FONT_SIZE_LG)
	button.custom_minimum_size = Vector2(BUTTON_MIN_WIDTH, BUTTON_MIN_HEIGHT)

static func apply_label_theme(label: Label, font: Font = null, size: int = FONT_SIZE_MD, 
		color: Color = TEXT_PRIMARY):
	# 应用标签主题
	var target_font = font if font else DEFAULT_FONT
	if target_font:
		label.add_theme_font_override("font", target_font)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)

static func draw_decorated_panel(canvas: CanvasItem, rect: Rect2, 
		bg_color: Color = BG_PANEL, border_color: Color = BORDER_MEDIUM,
		has_glow: bool = false):
	# 绘制装饰面板
	# 外发光
	if has_glow:
		var glow_rect = rect.grow(4)
		canvas.draw_rect(glow_rect, Color(border_color.r, border_color.g, border_color.b, 0.15), true)
	
	# 背景
	canvas.draw_rect(rect, bg_color, true)
	
	# 边框
	canvas.draw_rect(rect, border_color, false, BORDER_NORMAL)
	
	# 内边角高光（像素风细节）
	var corner_size = 3
	var hl = Color(1, 1, 1, 0.1)
	canvas.draw_rect(Rect2(rect.position + Vector2(2, 2), Vector2(corner_size, 1)), hl, true)
	canvas.draw_rect(Rect2(rect.position + Vector2(2, 2), Vector2(1, corner_size)), hl, true)

static func draw_progress_bar(canvas: CanvasItem, pos: Vector2, width: float, height: float,
		progress: float, bg_color: Color, fill_color: Color, border_color: Color = BORDER_LIGHT):
	# 绘制进度条
	var rect = Rect2(pos, Vector2(width, height))
	
	# 背景
	canvas.draw_rect(rect, bg_color, true)
	
	# 填充
	var fill_width = width * clamp(progress, 0.0, 1.0)
	if fill_width > 0:
		canvas.draw_rect(Rect2(pos, Vector2(fill_width, height)), fill_color, true)
	
	# 边框
	canvas.draw_rect(rect, border_color, false, BORDER_THIN)

static func draw_card(canvas: CanvasItem, rect: Rect2, is_selected: bool = false,
		accent_color: Color = ACCENT_PRIMARY):
	# 绘制卡片
	var bg = BG_LIGHT if is_selected else BG_MEDIUM
	var border = accent_color if is_selected else BORDER_MEDIUM
	var border_width = BORDER_THICK if is_selected else BORDER_THIN
	
	# 选中时的外发光
	if is_selected:
		var glow_rect = rect.grow(3)
		canvas.draw_rect(glow_rect, Color(accent_color.r, accent_color.g, accent_color.b, 0.2), true)
	
	# 背景
	canvas.draw_rect(rect, bg, true)
	
	# 边框
	canvas.draw_rect(rect, border, false, border_width)

static func draw_icon_placeholder(canvas: CanvasItem, pos: Vector2, size: Vector2, 
		color: Color, icon_char: String = "?", font: Font = null):
	# 绘制图标占位符
	# 背景
	canvas.draw_rect(Rect2(pos, size), color, true)
	canvas.draw_rect(Rect2(pos, size), Color(1, 1, 1, 0.3), false, 1)
	
	# 图标文字
	if font:
		var text_size = font.get_string_size(icon_char, HORIZONTAL_ALIGNMENT_CENTER, -1, 20)
		var text_pos = pos + (size - text_size) / 2 + Vector2(0, text_size.y * 0.8)
		canvas.draw_string(font, text_pos, icon_char, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, TEXT_PRIMARY)
