extends "res://Combat/CombatSystemBase.gd"
class_name TurnBasedCombat

## 回合制战斗实现
## 经典RPG风格的回合制战斗系统

# ==================== 额外信号 ====================
signal action_queue_updated(queue: Array)
signal enemy_intent_revealed(enemy_index: int, intent: Dictionary)

# ==================== 回合制特有状态 ====================
var action_queue: Array[Dictionary] = []
var enemy_intents: Array[Dictionary] = []  # 敌人意图（杀戮尖塔风格）

# ==================== 实现抽象方法 ====================
func start_combat(party: Array, enemies: Array) -> void:
	# 开始战斗
	print("[TurnBasedCombat] 战斗开始!")
	
	current_state = CombatState.INITIALIZING
	turn_number = 0
	current_block = 0
	action_queue.clear()
	
	# 初始化队伍数据
	party_data.clear()
	for member in party:
		var member_copy = member.duplicate(true)
		party_data.append(member_copy)
	
	# 初始化敌人数据
	enemies_data.clear()
	enemy_intents.clear()
	for enemy in enemies:
		var enemy_copy = enemy.duplicate(true)
		enemy_copy["current_health"] = enemy_copy.get("max_health", 50)
		enemy_copy["block"] = 0
		enemies_data.append(enemy_copy)
		enemy_intents.append({})
	
	combat_started.emit(party_data, enemies_data)
	
	# 开始第一回合
	_start_new_turn()

func apply_player_action(action: Dictionary) -> void:
	# 应用玩家行动
	if current_state != CombatState.PLAYER_TURN:
		push_warning("[TurnBasedCombat] 非玩家回合，无法行动")
		return
	
	var action_type = action.get("type", "")
	var energy_cost = action.get("energy_cost", 1)
	
	# 检查能量
	if not has_energy(energy_cost):
		push_warning("[TurnBasedCombat] 能量不足")
		return
	
	use_energy(energy_cost)
	
	match action_type:
		"attack":
			_execute_attack(action)
		"defend":
			_execute_defend(action)
		"skill":
			_execute_skill(action)
		_:
			push_warning("[TurnBasedCombat] 未知行动类型: " + action_type)
	
	player_action_applied.emit(action)
	
	# 检查战斗是否结束
	if all_enemies_dead():
		return  # 胜利已在 _on_enemy_defeated 中处理

func end_player_turn() -> void:
	# 结束玩家回合
	if current_state != CombatState.PLAYER_TURN:
		return
	
	turn_ended.emit(turn_number)
	current_state = CombatState.ENEMY_TURN
	
	# 开始敌人回合
	await get_tree().create_timer(0.5).timeout
	process_enemy_turn()

func process_enemy_turn() -> void:
	# 处理敌人回合
	current_state = CombatState.ENEMY_TURN
	turn_started.emit(turn_number, false)
	
	for i in range(enemies_data.size()):
		var enemy = enemies_data[i]
		if enemy.get("current_health", 0) <= 0:
			continue
		
		# 执行敌人意图
		var intent = enemy_intents[i]
		await _execute_enemy_action(i, intent)
		
		# 检查玩家是否死亡
		if Engine.has_singleton("GameState"):
			var game_state = Engine.get_singleton("GameState")
			if game_state.player_stats.current_health <= 0:
				_trigger_defeat()
				return
	
	turn_ended.emit(turn_number)
	
	# 开始新回合
	await get_tree().create_timer(0.3).timeout
	_start_new_turn()

func on_combat_end(result: Dictionary) -> void:
	# 战斗结束处理
	
	if result.victory:
		# 发放奖励
		if Engine.has_singleton("GameState"):
			var game_state = Engine.get_singleton("GameState")
			var rewards = result.get("rewards", {})
			game_state.modify_gold(rewards.get("gold", 0))
			
			# 触发遗物效果（战斗结束时）
			_trigger_relic_effects("on_combat_end")

# ==================== 行动执行 ====================
func _execute_attack(action: Dictionary) -> void:
	# 执行攻击
	var target_index = action.get("target", 0)
	var base_damage = action.get("damage", 10)
	
	# 获取玩家攻击力加成
	if Engine.has_singleton("GameState"):
		var game_state = Engine.get_singleton("GameState")
		base_damage += game_state.get_total_attack() - game_state.player_stats.base_attack
	
	apply_damage_to_enemy(target_index, base_damage)

func _execute_defend(action: Dictionary) -> void:
	# 执行防御
	var block_amount = action.get("block", 5)
	
	# 获取玩家防御力加成
	if Engine.has_singleton("GameState"):
		var game_state = Engine.get_singleton("GameState")
		block_amount += game_state.get_total_defense()
	
	add_block(block_amount)

func _execute_skill(action: Dictionary) -> void:
	# 执行技能
	var skill_id = action.get("skill_id", "")
	var target_index = action.get("target", 0)
	
	# 根据技能ID执行不同效果
	match skill_id:
		"heavy_strike":
			apply_damage_to_enemy(target_index, 15)
		"shield_bash":
			apply_damage_to_enemy(target_index, 8)
			add_block(5)
		"heal":
			heal_player(10)
		_:
			print("[TurnBasedCombat] 未知技能: ", skill_id)

func _execute_enemy_action(enemy_index: int, intent: Dictionary) -> void:
	# 执行敌人行动
	current_state = CombatState.ANIMATING
	
	var action_type = intent.get("type", "attack")
	var value = intent.get("value", 10)
	
	match action_type:
		"attack":
			apply_damage_to_player(value, enemies_data[enemy_index])
		"heavy_attack":
			apply_damage_to_player(value * 2, enemies_data[enemy_index])
		"defend":
			enemies_data[enemy_index]["block"] = enemies_data[enemy_index].get("block", 0) + value
		"buff":
			enemies_data[enemy_index]["attack_bonus"] = enemies_data[enemy_index].get("attack_bonus", 0) + 3
		_:
			apply_damage_to_player(value, enemies_data[enemy_index])
	
	enemy_action_applied.emit(enemy_index, intent)
	
	await get_tree().create_timer(0.5).timeout
	current_state = CombatState.ENEMY_TURN

# ==================== 回合管理 ====================
func _start_new_turn() -> void:
	# 开始新回合
	turn_number += 1
	current_state = CombatState.PLAYER_TURN
	
	# 重置格挡
	current_block = 0
	block_changed.emit(current_block)
	
	# 重置敌人格挡
	for enemy in enemies_data:
		enemy["block"] = 0
	
	# 重置能量
	reset_energy()
	
	# 生成敌人意图
	_generate_enemy_intents()
	
	turn_started.emit(turn_number, true)

func _generate_enemy_intents() -> void:
	# 生成敌人意图（杀戮尖塔风格）
	for i in range(enemies_data.size()):
		var enemy = enemies_data[i]
		if enemy.get("current_health", 0) <= 0:
			enemy_intents[i] = {}
			continue
		
		# 根据敌人的可用招式随机选择
		var moves = enemy.get("moves", ["attack"])
		var move = moves[randi() % moves.size()]
		
		var intent = _create_intent_from_move(move, enemy)
		enemy_intents[i] = intent
		enemy_intent_revealed.emit(i, intent)

func _create_intent_from_move(move: String, enemy: Dictionary) -> Dictionary:
	# 根据招式创建意图
	var base_attack = enemy.get("base_attack", 10)
	
	match move:
		"attack":
			return {"type": "attack", "value": base_attack, "icon": "attack"}
		"heavy_attack":
			return {"type": "heavy_attack", "value": base_attack, "icon": "heavy_attack"}
		"defend":
			return {"type": "defend", "value": 10, "icon": "defend"}
		"buff":
			return {"type": "buff", "value": 3, "icon": "buff"}
		_:
			return {"type": "attack", "value": base_attack, "icon": "attack"}

# ==================== 遗物效果触发 ====================
func _trigger_relic_effects(trigger: String) -> void:
	# 触发遗物效果
	if not Engine.has_singleton("GameState"):
		return
	
	var game_state = Engine.get_singleton("GameState")
	
	for relic in game_state.relics:
		if relic.get("effect_type") == trigger:
			var value = relic.get("effect_value", 0)
			match trigger:
				"on_combat_end":
					game_state.modify_health(value)
				"on_combat_start":
					max_energy += value
					reset_energy()
				"on_turn_start":
					add_block(value)
