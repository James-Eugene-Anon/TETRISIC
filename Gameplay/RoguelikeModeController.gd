extends BaseGameModeController
class_name RoguelikeModeController

## Roguelike模式控制器
## 继承自BaseGameModeController，复用核心俄罗斯方块逻辑

signal damage_dealt(amount: int)
signal attack_cooldown_changed(value: float)

# 7-bag 随机生成器
var piece_bag: Array = []

func _init():
	# Roguelike模式强制使用标准10x20网格，不受扩容磁盘影响
	GameConfig.apply_capacity_disk(false)
	grid_manager = GridManager.new(GameConfig.GRID_WIDTH, GameConfig.GRID_HEIGHT)
	equipment_system = EquipmentSystem.new()

func initialize():
	super.initialize()
	# Roguelike模式不继承经典/歌曲装备
	if equipment_system:
		equipment_system.set_roguelike_only(true)
		equipment_system.clear_temporary_equipment()
	_refill_bag()
	spawn_piece()

func spawn_piece():
	if piece_bag.is_empty():
		_refill_bag()
	
	var shape_name = piece_bag.pop_front()
	# 修复：TetrisPiece.new() 需要 shape 和 position 两个参数
	var spawn_x = int(GameConfig.GRID_WIDTH / 2) - 2
	current_piece = TetrisPiece.new(shape_name, Vector2i(spawn_x, -1))
	
	if check_game_over():
		return
		
	# 准备下一个方块用于显示（取包中下一个，如果空了就暂时显示空或重新填充预演）
	var next_shape = ""
	if piece_bag.is_empty():
		# 为了预览，我们需要临时补充
		_temp_refill_for_preview()
		next_shape = piece_bag[0]
	else:
		next_shape = piece_bag[0]
		
	next_piece_data = {
		"shape": next_shape,
		"color": GameConfig.COLORS.get(next_shape, Color.WHITE)
	}

func _refill_bag():
	var shapes = GameConfig.CLASSIC_SHAPES.duplicate()
	shapes.shuffle()
	piece_bag.append_array(shapes)

func _temp_refill_for_preview():
	# 仅用于预览逻辑，不应该真的影响随机序列，但这里简化处理，直接填充
	# 因为7-bag规则下，预先填充是可以的
	_refill_bag()

# 重写锁定方块逻辑以计算伤害
func lock_piece():
	if current_piece == null:
		return
		
	var color = get_piece_color()
	current_piece.place_on_grid(grid_manager, color)
	
	# 方块已放置到网格，立即清除引用，防止渲染器重复绘制
	current_piece = null
	
	# 清除完整的行
	var lines_cleared = grid_manager.clear_lines()
	var pending_damage: int = 0
	if lines_cleared > 0:
		lines_cleared_total += lines_cleared
		combo += 1
		# 参照经典模式休闲分数表
		var score_table = get_line_score_table()
		var max_index = score_table.size() - 1
		var base_score = score_table[min(lines_cleared, max_index)]
		
		# 计算伤害
		# 基础伤害：每行10点
		pending_damage = lines_cleared * 10
		
		# 连击伤害加成：参考休闲模式得分（与连击次数关联）
		if combo > 1:
			var combo_dmg = int(base_score / 10) * (combo - 1)
			pending_damage += combo_dmg
			print("[Roguelike] 连击加成伤害: ", combo_dmg)
		
		# 同步分数（用于统计显示）
		var combo_score_bonus = 0
		if combo > 1:
			combo_score_bonus = base_score * 10 * (combo - 1)
		var old_score = score
		score += base_score + combo_score_bonus
		on_score_updated(score, old_score, base_score)
		
		score_changed.emit(score)
		lines_changed.emit(lines_cleared_total)
		combo_changed.emit(combo)
	else:
		if combo > 0:
			combo = 0
			combo_changed.emit(combo)

	# 强制流程：先完成方块下落与消除结算，再进行攻击判定
	if pending_damage > 0:
		damage_dealt.emit(pending_damage)

	# 若战斗已结束（如最后一击胜利），不再生成下一个方块
	if game_over:
		return

	spawn_piece()

func get_piece_color() -> Color:
	if current_piece and GameConfig.COLORS.has(current_piece.shape_name):
		return GameConfig.COLORS[current_piece.shape_name]
	return Color.WHITE
