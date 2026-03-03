extends Node
class_name CombatSystemBase

## 战斗系统基类/接口
## 定义统一的战斗API，不同战斗实现（回合制、俄罗斯方块等）需继承此类

# ==================== 信号定义（统一接口）====================
signal combat_started(party: Array, enemies: Array)
signal combat_ended(result: Dictionary)  # {victory: bool, rewards: Dictionary}
signal turn_started(turn_number: int, is_player_turn: bool)
signal turn_ended(turn_number: int)
signal player_action_applied(action: Dictionary)
signal enemy_action_applied(enemy_index: int, action: Dictionary)
signal damage_dealt(target: String, amount: int, is_player_target: bool)
signal heal_applied(target: String, amount: int)
signal status_effect_applied(target: String, effect: Dictionary)
signal energy_changed(current: int, maximum: int)
signal block_changed(amount: int)

# ==================== 战斗状态 ====================
enum CombatState {
	INACTIVE,
	INITIALIZING,
	PLAYER_TURN,
	ENEMY_TURN,
	ANIMATING,
	VICTORY,
	DEFEAT,
}

var current_state: CombatState = CombatState.INACTIVE
var turn_number: int = 0

# ==================== 战斗数据 ====================
var party_data: Array[Dictionary] = []
var enemies_data: Array[Dictionary] = []
var current_energy: int = 0
var max_energy: int = 3
var current_block: int = 0

# ==================== 抽象方法（子类必须实现）====================
func start_combat(party: Array, enemies: Array) -> void:
	# 开始战斗
	# @param party: 玩家队伍数据数组
	# @param enemies: 敌人数据数组
	push_error("[CombatSystem] start_combat 未实现")

func apply_player_action(action: Dictionary) -> void:
	# 应用玩家行动
	# @param action: 行动数据 {type: String, target: int, ...}
	push_error("[CombatSystem] apply_player_action 未实现")

func end_player_turn() -> void:
	# 结束玩家回合
	push_error("[CombatSystem] end_player_turn 未实现")

func process_enemy_turn() -> void:
	# 处理敌人回合
	push_error("[CombatSystem] process_enemy_turn 未实现")

func on_combat_end(result: Dictionary) -> void:
	# 战斗结束处理
	# @param result: {victory: bool, rewards: {...}}
	push_error("[CombatSystem] on_combat_end 未实现")

# ==================== 通用辅助方法 ====================
func is_combat_active() -> bool:
	# 检查战斗是否进行中
	return current_state != CombatState.INACTIVE and \
		   current_state != CombatState.VICTORY and \
		   current_state != CombatState.DEFEAT

func is_player_turn() -> bool:
	# 检查是否为玩家回合
	return current_state == CombatState.PLAYER_TURN

func get_alive_enemies() -> Array[Dictionary]:
	# 获取存活的敌人列表
	var alive: Array[Dictionary] = []
	for enemy in enemies_data:
		if enemy.get("current_health", 0) > 0:
			alive.append(enemy)
	return alive

func get_enemy_at_index(index: int) -> Dictionary:
	# 获取指定索引的敌人
	if index >= 0 and index < enemies_data.size():
		return enemies_data[index]
	return {}

func all_enemies_dead() -> bool:
	# 检查是否所有敌人已死亡
	return get_alive_enemies().is_empty()

# ==================== 伤害/治疗计算（可被子类覆盖）====================
func calculate_damage(base_damage: int, attacker: Dictionary, defender: Dictionary) -> int:
	# 计算最终伤害
	var damage = base_damage
	
	# 攻击者加成
	damage += attacker.get("attack_bonus", 0)
	
	# 防御者减免（先扣格挡）
	var block = defender.get("block", 0)
	if block > 0:
		var blocked = mini(block, damage)
		damage -= blocked
		defender["block"] = block - blocked
	
	# 防御力减免
	var defense = defender.get("defense", 0)
	damage = maxi(0, damage - defense)
	
	return damage

func apply_damage_to_enemy(enemy_index: int, damage: int) -> void:
	# 对敌人造成伤害
	if enemy_index < 0 or enemy_index >= enemies_data.size():
		return
	
	var enemy = enemies_data[enemy_index]
	var actual_damage = calculate_damage(damage, {}, enemy)
	enemy["current_health"] = maxi(0, enemy.get("current_health", 0) - actual_damage)
	
	damage_dealt.emit(enemy.get("name", "Enemy"), actual_damage, false)
	
	if enemy["current_health"] <= 0:
		_on_enemy_defeated(enemy_index)

func apply_damage_to_player(damage: int, attacker: Dictionary = {}) -> void:
	# 对玩家造成伤害
	var player = party_data[0] if party_data.size() > 0 else {}
	var actual_damage = calculate_damage(damage, attacker, player)
	
	# 先扣格挡
	if current_block > 0:
		var blocked = mini(current_block, actual_damage)
		actual_damage -= blocked
		current_block -= blocked
		block_changed.emit(current_block)
	
	if actual_damage > 0 and Engine.has_singleton("GameState"):
		var game_state = Engine.get_singleton("GameState")
		game_state.modify_health(-actual_damage)
	
	damage_dealt.emit("Player", actual_damage, true)

func add_block(amount: int) -> void:
	# 增加格挡
	current_block += amount
	block_changed.emit(current_block)

func heal_player(amount: int) -> void:
	# 治疗玩家
	if Engine.has_singleton("GameState"):
		var game_state = Engine.get_singleton("GameState")
		game_state.modify_health(amount)
	heal_applied.emit("Player", amount)

# ==================== 能量系统 ====================
func reset_energy() -> void:
	# 重置能量到最大值
	current_energy = max_energy
	energy_changed.emit(current_energy, max_energy)

func use_energy(amount: int) -> bool:
	# 使用能量，返回是否成功
	if current_energy >= amount:
		current_energy -= amount
		energy_changed.emit(current_energy, max_energy)
		return true
	return false

func has_energy(amount: int) -> bool:
	# 检查是否有足够能量
	return current_energy >= amount

# ==================== 内部方法 ====================
func _on_enemy_defeated(enemy_index: int) -> void:
	# 敌人被击败
	print("[CombatSystem] 敌人被击败: ", enemies_data[enemy_index].get("name", "Unknown"))
	
	if all_enemies_dead():
		_trigger_victory()

func _trigger_victory() -> void:
	# 触发胜利
	current_state = CombatState.VICTORY
	var rewards = _calculate_rewards()
	on_combat_end({"victory": true, "rewards": rewards})
	combat_ended.emit({"victory": true, "rewards": rewards})

func _trigger_defeat() -> void:
	# 触发失败
	current_state = CombatState.DEFEAT
	on_combat_end({"victory": false, "rewards": {}})
	combat_ended.emit({"victory": false, "rewards": {}})

func _calculate_rewards() -> Dictionary:
	# 计算战斗奖励
	var total_gold = 0
	for enemy in enemies_data:
		total_gold += enemy.get("gold_reward", 10)
	
	return {
		"gold": total_gold,
		"experience": enemies_data.size() * 10,
	}

# ==================== 存档接口 ====================
func get_save_data() -> Dictionary:
	# 获取战斗存档数据
	return {
		"state": current_state,
		"turn_number": turn_number,
		"party_data": party_data,
		"enemies_data": enemies_data,
		"current_energy": current_energy,
		"max_energy": max_energy,
		"current_block": current_block,
	}

func load_save_data(data: Dictionary) -> void:
	# 加载战斗存档数据
	current_state = data.get("state", CombatState.INACTIVE)
	turn_number = data.get("turn_number", 0)
	party_data = data.get("party_data", [])
	enemies_data = data.get("enemies_data", [])
	current_energy = data.get("current_energy", 0)
	max_energy = data.get("max_energy", 3)
	current_block = data.get("current_block", 0)
