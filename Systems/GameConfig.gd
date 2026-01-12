extends Node
class_name GameConfig

## 游戏配置 - 单一职责：管理所有游戏常量

# 网格配置
const GRID_WIDTH = 10
const GRID_HEIGHT = 20
const CELL_SIZE = 28
const GRID_OFFSET_X = 240  # (800 - 10*28) / 2 = 240，居中
const GRID_OFFSET_Y = 20

# 游戏速度配置
const FALL_SPEED = 1.0  # 秒
const LOCK_DELAY = 0.003  # 方块固定延迟（3毫秒）

# 输入配置
const REPEAT_DELAY = 0.15  # 按键重复延迟
const REPEAT_RATE = 0.05   # 按键重复速率

# 方块形状定义 (包含所有旋转状态)
const SHAPES = {
	"I": [
		[Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1)],
		[Vector2i(2, 0), Vector2i(2, 1), Vector2i(2, 2), Vector2i(2, 3)],
		[Vector2i(0, 2), Vector2i(1, 2), Vector2i(2, 2), Vector2i(3, 2)],
		[Vector2i(1, 0), Vector2i(1, 1), Vector2i(1, 2), Vector2i(1, 3)]
	],
	"O": [
		[Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]
	],
	"T": [
		[Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1)],
		[Vector2i(1, 0), Vector2i(1, 1), Vector2i(2, 1), Vector2i(1, 2)],
		[Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(1, 2)],
		[Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(1, 2)]
	],
	"S": [
		[Vector2i(1, 0), Vector2i(2, 0), Vector2i(0, 1), Vector2i(1, 1)],
		[Vector2i(1, 0), Vector2i(1, 1), Vector2i(2, 1), Vector2i(2, 2)],
		[Vector2i(1, 1), Vector2i(2, 1), Vector2i(0, 2), Vector2i(1, 2)],
		[Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(1, 2)]
	],
	"Z": [
		[Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(2, 1)],
		[Vector2i(2, 0), Vector2i(1, 1), Vector2i(2, 1), Vector2i(1, 2)],
		[Vector2i(0, 1), Vector2i(1, 1), Vector2i(1, 2), Vector2i(2, 2)],
		[Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(0, 2)]
	],
	"J": [
		[Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1)],
		[Vector2i(1, 0), Vector2i(2, 0), Vector2i(1, 1), Vector2i(1, 2)],
		[Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(2, 2)],
		[Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 2), Vector2i(1, 2)]
	],
	"L": [
		[Vector2i(2, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1)],
		[Vector2i(1, 0), Vector2i(1, 1), Vector2i(1, 2), Vector2i(2, 2)],
		[Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(0, 2)],
		[Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(1, 2)]
	],
	"PLUS": [
		[Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(1, 2)],
		[Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(1, 2)],
		[Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(1, 2)],
		[Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(1, 2)]
	],
	"T5": [
		[Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(1, 1), Vector2i(1, 2)],
		[Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2), Vector2i(1, 1), Vector2i(2, 1)],
		[Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 2), Vector2i(1, 2), Vector2i(2, 2)],
		[Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 0), Vector2i(2, 1), Vector2i(2, 2)]
	],
	"L5": [
		# 0度：┗ 形状（竖在左，横在底向右）
		[Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2), Vector2i(1, 2), Vector2i(2, 2)],
		# 90度：┏ 形状（横在顶，竖在左向下）
		[Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(0, 1), Vector2i(0, 2)],
		# 180度：┓ 形状（竖在右，横在顶向左）
		[Vector2i(2, 0), Vector2i(2, 1), Vector2i(2, 2), Vector2i(0, 0), Vector2i(1, 0)],
		# 270度：┘ 形状（横在底，竖在右向上）
		[Vector2i(2, 0), Vector2i(2, 1), Vector2i(2, 2), Vector2i(0, 2), Vector2i(1, 2)]
		
	],
	"L5R": [
		# 0度：┓ 形状（横在顶，竖在右向下）
		[Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(2, 1), Vector2i(2, 2)],
		# 90度：┛ 形状（竖在右，横在底向左）
		[Vector2i(2, 0), Vector2i(2, 1), Vector2i(2, 2), Vector2i(0, 2), Vector2i(1, 2)],
		# 180度：┗ 形状（横在底，竖在左向上）
		[Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2), Vector2i(1, 2), Vector2i(2, 2)],
		# 270度：┏ 形状（竖在左，横在顶向右）
		[Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2), Vector2i(1, 0), Vector2i(2, 0)],

	],
	"L6": [
		[Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2), Vector2i(1, 2), Vector2i(2, 2), Vector2i(3, 2)],
		[Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(0, 1), Vector2i(0, 2), Vector2i(0, 3)],
		[Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0), Vector2i(3, 1), Vector2i(3, 2)],
		[Vector2i(2, 0), Vector2i(2, 1), Vector2i(2, 2), Vector2i(2, 3), Vector2i(0, 3), Vector2i(1, 3)]
	],
	"RECT": [
		[Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(0, 2), Vector2i(1, 2)],
		[Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1)]
	],
	"T7": [
		[Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(0, 2), Vector2i(1, 2), Vector2i(2, 2)],
		[Vector2i(0, 1), Vector2i(1, 0), Vector2i(1, 1), Vector2i(1, 2), Vector2i(2, 0), Vector2i(2, 1), Vector2i(2, 2)],
		[Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(1, 2)],
		[Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2), Vector2i(1, 0), Vector2i(1, 1), Vector2i(1, 2), Vector2i(2, 1)]
	],
	"BIG_T": [
		# 初始状态：横5，中间位置向下延伸3格（类似T字）
		[Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0), Vector2i(4, 0), Vector2i(2, 1), Vector2i(2, 2)],
		# 旋转90度：竖5，中间位置向右延伸3格
		[Vector2i(2, 0), Vector2i(2, 1), Vector2i(2, 2), Vector2i(2, 3), Vector2i(2, 4), Vector2i(3, 2), Vector2i(4, 2)],
		# 旋转180度：横5，中间位置向上延伸3格
		[Vector2i(0, 2), Vector2i(1, 2), Vector2i(2, 2), Vector2i(3, 2), Vector2i(4, 2), Vector2i(2, 0), Vector2i(2, 1)],
		# 旋转270度：竖5，中间位置向左延伸3格
		[Vector2i(2, 0), Vector2i(2, 1), Vector2i(2, 2), Vector2i(2, 3), Vector2i(2, 4), Vector2i(0, 2), Vector2i(1, 2)]
	],
	"I5": [
		# 横向5格（转轴在中心）
		[Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1), Vector2i(4, 1)],
		# 竖向5格（转轴在中心）
		[Vector2i(1, 0), Vector2i(1, 1), Vector2i(1, 2), Vector2i(1, 3), Vector2i(1, 4)]
	],
	"I6": [
		# 横向6格
		[Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0), Vector2i(4, 0), Vector2i(5, 0)],
		# 竖向6格
		[Vector2i(2, 0), Vector2i(2, 1), Vector2i(2, 2), Vector2i(2, 3), Vector2i(2, 4), Vector2i(2, 5)]
	],
	"I7": [
		# 横向7格
		[Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0), Vector2i(4, 0), Vector2i(5, 0), Vector2i(6, 0)],
		# 竖向7格
		[Vector2i(3, 0), Vector2i(3, 1), Vector2i(3, 2), Vector2i(3, 3), Vector2i(3, 4), Vector2i(3, 5), Vector2i(3, 6)]
	],
	"DOT": [
		[Vector2i(0, 0)]
	],
	"I2": [
		[Vector2i(0, 0), Vector2i(1, 0)],
		[Vector2i(0, 0), Vector2i(0, 1)]
	],
	"I3": [
		[Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)],
		[Vector2i(1, 0), Vector2i(1, 1), Vector2i(1, 2)]
	],
	"L3": [
		# 小L形状 - 3格
		# 0度：L形右下角
		[Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 1)],
		# 90度：顺时针旋转
		[Vector2i(0, 1), Vector2i(1, 1), Vector2i(1, 0)],
		# 180度
		[Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1)],
		# 270度
		[Vector2i(0, 1), Vector2i(0, 0), Vector2i(1, 0)]
	],
	"U5": [
		# 凹形 - 5格（U形状）
		# 0度：凹口向上
		[Vector2i(0, 0), Vector2i(2, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1)],
		# 90度：凹口向右
		[Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2), Vector2i(1, 0), Vector2i(1, 2)],
		# 180度：凹口向下
		[Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(0, 1), Vector2i(2, 1)],
		# 270度：凹口向左（修正）
		[Vector2i(0, 0), Vector2i(0, 2), Vector2i(1, 0), Vector2i(1, 1), Vector2i(1, 2)]
	],
	"S5": [
		# 蛇形 - 5格（延长的S形）
		# 0度：横向蛇形
		[Vector2i(1, 0), Vector2i(2, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(0, 2)],
		# 90度：竖向蛇形
		[Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(1, 2), Vector2i(2, 2)],
		# 180度
		[Vector2i(2, 0), Vector2i(1, 1), Vector2i(2, 1), Vector2i(0, 2), Vector2i(1, 2)],
		# 270度
		[Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(2, 1), Vector2i(2, 2)]
	]
}

# 方块颜色
const COLORS = {
	"I": Color.CYAN,
	"O": Color.YELLOW,
	"T": Color.MAGENTA,
	"S": Color.GREEN,
	"Z": Color.RED,
	"J": Color.BLUE,
	"L": Color.ORANGE,
	"PLUS": Color.PURPLE,
	"T5": Color.MEDIUM_PURPLE,
	"L5": Color.DARK_SALMON,
	"L5R": Color.LIGHT_CORAL,
	"L6": Color.PINK,
	"RECT": Color.LIGHT_SKY_BLUE,
	"T7": Color.DEEP_PINK,
	"BIG_T": Color.GOLD,
	"I5": Color.CYAN,
	"I6": Color.DEEP_SKY_BLUE,
	"I7": Color.DODGER_BLUE,
	"DOT": Color.WHITE,
	"I2": Color.LIGHT_BLUE,
	"I3": Color.MEDIUM_ORCHID,  # 淡紫色，与歌曲完成提示区分
	"L3": Color.KHAKI,
	"U5": Color.MEDIUM_SEA_GREEN,
	"S5": Color.LIGHT_SALMON
}

# 经典模式方块
const CLASSIC_SHAPES = ["I", "O", "T", "S", "Z", "J", "L"]

# 计分规则 - 简单模式使用前5项，普通/困难/歌词模式使用全部
const LINE_SCORES_EASY = [0, 100, 200, 400, 700]  # 简单模式(最多消除4行)
const LINE_SCORES_FULL = [0, 100, 200, 400, 700, 1200, 2000, 4000]  # 普通/困难/歌词模式(最多消除7行)
const LINE_SCORES = LINE_SCORES_EASY  # 默认（向后兼容）
