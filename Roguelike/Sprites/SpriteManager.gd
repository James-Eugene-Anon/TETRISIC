extends Node
class_name RoguelikeSpriteManager

## Roguelike精灵资源管理器
## 管理敌人和玩家的立绘，支持动画帧
## 资源来源: mota-js项目 (BSD-3-Clause License)

# 精灵图资源
static var enemys_texture: Texture2D = null
static var enemy48_texture: Texture2D = null  
static var hero_texture: Texture2D = null

# 精灵尺寸配置
const ENEMY_32_SIZE = 32  # enemys.png中每个敌人的尺寸
const ENEMY_48_SIZE = 48  # enemy48.png中每个敌人的尺寸
const HERO_FRAME_WIDTH = 32
const HERO_FRAME_HEIGHT = 48

# mota-js enemys.png布局：每个敌人占一整行，每行2帧(64px宽)
# 索引直接对应行号，不是2D网格位置

# 敌人在精灵图中的索引映射 (来自mota-js icons.js)
# 32x32精灵图 (enemys.png)
const ENEMY_INDEX_32 = {
	"绿色史莱姆": 0,   # greenSlime
	"红色史莱姆": 1,   # redSlime
	"青色史莱姆": 2,   # blackSlime (实际是青色)
	"史莱姆王": 3,     # slimelord
	"小蝙蝠": 4,       # bat
	"大蝙蝠": 5,       # bigBat
	"红蝙蝠": 6,       # redBat
	"吸血鬼": 7,       # vampire
	"骷髅人": 8,       # skeleton
	"骷髅士兵": 9,     # skeletonWarrior
	"骷髅队长": 10,    # skeletonCaptain
	"冥队长": 11,      # ghostSoldier
	"鬼战士": 11,      # ghostSkeleton (enemy_ghost_skeleton alias)
	"兽人": 12,        # zombie
	"兽人武士": 13,    # zombieKnight
	"石头人": 14,      # rock
	"影子战士": 15,    # slimeman
	"初级法师": 16,    # bluePriest
	"高级法师": 17,    # redPriest
	"初级巫师": 18,    # brownWizard
	"高级巫师": 19,    # redWizard
	"初级卫兵": 20,    # yellowGateKeeper
	"中级卫兵": 21,    # blueGateKeeper
	"高级卫兵": 22,    # redGateKeeper
	"双手剑士": 23,    # swordsman
	"冥战士": 24,      # soldier
	"战士": 24,        # soldier (enemy_soldier alias)
	"金骑士": 25,      # yellowKnight
	"红骑士": 26,      # redKnight
	"黑骑士": 27,      # darkKnight
	"黑衣魔王": 28,    # blackKing
	"黄衣魔王": 29,    # yellowKing
	"青衣武士": 30,    # greenKing
	"蓝骑士": 31,      # blueKnight
	"黄头怪": 32,      # goldSlime
	"紫骷髅": 33,      # poisonSkeleton
	"紫蝙蝠": 34,      # poisonBat
	"铁面人": 35,      # ironRock
	"骷髅法师": 36,    # skeletonPriest
	"骷髅王": 37,      # skeletonKing
	"骷髅巫师": 38,    # skeletonPresbyter
	"骷髅武士": 39,    # skeletonKnight
	"迷失勇者": 40,    # evilHero
	"魔神武士": 41,    # devilWarrior
	"魔神法师": 42,    # demonPriest
	"金角怪": 43,      # goldHornSlime
	"红衣魔王": 44,    # redKing
	"白衣武士": 45,    # blueKing
	"黑暗大法师": 46,  # magicMaster
	"银头怪": 47,      # silverSlime
	"剑圣": 48,        # blademaster
	"尖角怪": 49,      # whiteHornSlime
	"痛苦魔女": 50,    # evilPrincess
	"黑暗仙子": 51,    # evilFairy
	"中级法师": 52,    # yellowPriest
	"剑王": 53,        # redSwordsman
	"水银战士": 54,    # whiteSlimeman
	"绿兽人": 55,      # poisonZombie
	"魔龙": 56,        # dragon
	"血影": 57,        # octopus
	"仙子": 58,        # fairyEnemy
	"假公主": 59,      # princessEnemy
	"银怪王": 60,      # silverSlimelord
	"金怪王": 61,      # goldSlimelord
	"灰色石头人": 62,  # grayRock
	"强盾骑士": 63,    # greenKnight
	"初级弓兵": 64,    # bowman
	"高级弓兵": 65,    # purpleBowman
	"邪眼怪": 66,      # watcherSlime
	"寒蝙蝠": 67,      # frostBat
	"恶灵骑士": 68,    # devilKnight
	"混沌法师": 69,    # grayPriest
	"卫兵队长": 70,    # greenGateKeeper
	"铃兰花妖": 71,    # keiskeiFairy
	"郁金香花妖": 72,  # tulipFairy
}

# 特定敌人的可用动画帧（避免空白帧）
const ENEMY_FRAME_OVERRIDE = {
	"绿色史莱姆": [0, 1],
	"吸血鬼": [0, 1],
	"黑衣魔王": [0, 1],
	"史莱姆王": [0, 1],
	"骷髅武士": [0, 1],
	"骷髅士兵": [0, 1],
	"骷髅人": [0, 1],
	"骷髅法师": [0, 1]
}

# 英雄方向帧索引 (行)
const HERO_DIRECTION = {
	"down": 0,
	"left": 1, 
	"right": 2,
	"up": 3
}

static func _ensure_loaded():
	# 确保资源已加载
	if enemys_texture == null:
		enemys_texture = load("res://Data/materials/enemys.png")
	if enemy48_texture == null:
		enemy48_texture = load("res://Data/materials/enemy48.png")
	if hero_texture == null:
		hero_texture = load("res://Data/materials/hero.png")

static func _resolve_enemy_sprite_name(enemy_name: String) -> String:
	return enemy_name

static func get_enemy_sprite_rect(enemy_name: String, frame: int = 0) -> Dictionary:
	# 获取敌人精灵的区域信息
	# 返回: {"texture": Texture2D, "rect": Rect2, "found": bool}
	_ensure_loaded()
	
	# 映射敌人名称
	var sprite_name = _resolve_enemy_sprite_name(enemy_name)
	
	# 查找索引
	if not ENEMY_INDEX_32.has(sprite_name):
		return {"texture": null, "rect": Rect2(), "found": false}
	
	var index = ENEMY_INDEX_32[sprite_name]
	
	# 确定可用帧数 (mota-js的enemys.png宽度64px = 2帧)
	var frames_per_enemy = 2
	if enemys_texture:
		frames_per_enemy = max(1, int(enemys_texture.get_width() / ENEMY_32_SIZE))
	
	# 处理帧索引
	var frame_list = ENEMY_FRAME_OVERRIDE.get(sprite_name, [])
	if frame_list.size() > 0:
		frame = frame_list[frame % frame_list.size()]
	else:
		frame = frame % frames_per_enemy
	
	# 计算在精灵图中的位置
	# mota-js 布局: 每个敌人占一整行，索引即行号
	# 图片宽64px = 2帧(x=0是静态帧, x=32是动画帧)
	var x = frame * ENEMY_32_SIZE
	var y = index * ENEMY_32_SIZE
	
	return {
		"texture": enemys_texture,
		"rect": Rect2(x, y, ENEMY_32_SIZE, ENEMY_32_SIZE),
		"found": true
	}

static func get_hero_sprite_rect(direction: String = "down", frame: int = 0) -> Dictionary:
	# 获取英雄精灵的区域信息
	# 返回: {"texture": Texture2D, "rect": Rect2, "found": bool}
	_ensure_loaded()
	
	if hero_texture == null:
		return {"texture": null, "rect": Rect2(), "found": false}
	
	var row = HERO_DIRECTION.get(direction, 0)
	frame = clamp(frame, 0, 3)
	
	var x = frame * HERO_FRAME_WIDTH
	var y = row * HERO_FRAME_HEIGHT
	
	return {
		"texture": hero_texture,
		"rect": Rect2(x, y, HERO_FRAME_WIDTH, HERO_FRAME_HEIGHT),
		"found": true
	}

static func draw_enemy_sprite(canvas: CanvasItem, enemy_name: String, position: Vector2, 
							   size: Vector2 = Vector2(44, 44), frame: int = 0):
	# 在画布上绘制敌人精灵
	var sprite_info = get_enemy_sprite_rect(enemy_name, frame)
	
	if sprite_info.found:
		var dest_rect = Rect2(position, size)
		canvas.draw_texture_rect_region(sprite_info.texture, dest_rect, sprite_info.rect)
	else:
		# 回退：绘制占位符
		_draw_placeholder_enemy(canvas, enemy_name, position, size)

static func draw_hero_sprite(canvas: CanvasItem, position: Vector2,
							  size: Vector2 = Vector2(44, 66), direction: String = "down", frame: int = 0):
	# 在画布上绘制英雄精灵
	var sprite_info = get_hero_sprite_rect(direction, frame)
	
	if sprite_info.found:
		var dest_rect = Rect2(position, size)
		canvas.draw_texture_rect_region(sprite_info.texture, dest_rect, sprite_info.rect)
	else:
		# 回退：绘制占位符
		_draw_placeholder_hero(canvas, position, size)

static func _draw_placeholder_enemy(canvas: CanvasItem, enemy_name: String, position: Vector2, size: Vector2):
	# 绘制敌人占位符（无精灵时的后备方案）
	var color = Color(0.6, 0.25, 0.25)
	
	# 根据敌人名称选择颜色
	if enemy_name.find("史莱姆") != -1 or enemy_name.find("绿") != -1:
		color = Color(0.3, 0.7, 0.3)
	elif enemy_name.find("骸骨") != -1 or enemy_name.find("骷髅") != -1:
		color = Color(0.7, 0.7, 0.6)
	elif enemy_name.find("深渊") != -1 or enemy_name.find("魔") != -1:
		color = Color(0.3, 0.2, 0.5)
	elif enemy_name.find("蝙蝠") != -1:
		color = Color(0.5, 0.3, 0.5)
	
	canvas.draw_rect(Rect2(position, size), color, true)
	# 简单眼睛
	var eye_size = size * 0.18
	canvas.draw_rect(Rect2(position + size * Vector2(0.22, 0.35), eye_size), Color.BLACK, true)
	canvas.draw_rect(Rect2(position + size * Vector2(0.6, 0.35), eye_size), Color.BLACK, true)
	canvas.draw_rect(Rect2(position, size), Color(0.4, 0.4, 0.5), false, 1)

static func _draw_placeholder_hero(canvas: CanvasItem, position: Vector2, size: Vector2):
	# 绘制英雄占位符
	canvas.draw_rect(Rect2(position, size), Color(0.25, 0.5, 0.8), true)
	var eye_size = size * Vector2(0.18, 0.12)
	canvas.draw_rect(Rect2(position + size * Vector2(0.22, 0.35), eye_size), Color(0.1, 0.25, 0.5), true)
	canvas.draw_rect(Rect2(position + size * Vector2(0.6, 0.35), eye_size), Color(0.1, 0.25, 0.5), true)
	canvas.draw_rect(Rect2(position, size), Color(0.4, 0.5, 0.7), false, 2)

static func is_enemy_sprite_available(enemy_name: String) -> bool:
	# 检查敌人是否有可用的精灵
	var sprite_name = _resolve_enemy_sprite_name(enemy_name)
	return ENEMY_INDEX_32.has(sprite_name)

static func get_mapped_enemy_name(original_name: String) -> String:
	# 获取映射后的敌人显示名称
	return original_name
