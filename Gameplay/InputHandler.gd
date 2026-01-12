extends Node
class_name InputHandler

## 输入处理器 - 单一职责：处理玩家输入和按键重复

signal move_left
signal move_right
signal move_down
signal rotate
signal hard_drop
signal pause_toggle

var key_timers: Dictionary = {}
var keys_pressed: Dictionary = {}

func _process(delta: float):
	handle_key_repeat(delta)

func handle_input(event: InputEvent, game_over: bool, paused: bool):
	"""处理输入事件"""
	# 游戏结束或暂停时，只处理暂停相关输入
	if game_over or paused:
		if event.is_action_pressed("ui_cancel"):
			pause_toggle.emit()
		return
	
	if event.is_action_pressed("ui_cancel"):
		pause_toggle.emit()
		return
	
	# 处理按键按下
	if event.is_action_pressed("ui_left"):
		move_left.emit()
		keys_pressed["left"] = true
		key_timers["left"] = GameConfig.REPEAT_DELAY
	elif event.is_action_released("ui_left"):
		keys_pressed["left"] = false
	
	elif event.is_action_pressed("ui_right"):
		move_right.emit()
		keys_pressed["right"] = true
		key_timers["right"] = GameConfig.REPEAT_DELAY
	elif event.is_action_released("ui_right"):
		keys_pressed["right"] = false
	
	elif event.is_action_pressed("ui_down"):
		move_down.emit()
		keys_pressed["down"] = true
		key_timers["down"] = GameConfig.REPEAT_DELAY
	elif event.is_action_released("ui_down"):
		keys_pressed["down"] = false
	
	elif event.is_action_pressed("ui_up"):
		rotate.emit()
	
	elif event.is_action_pressed("ui_accept"):
		hard_drop.emit()

func handle_key_repeat(delta: float):
	"""处理按键重复逻辑"""
	for key in key_timers.keys():
		if keys_pressed.get(key, false):
			key_timers[key] -= delta
			if key_timers[key] <= 0:
				match key:
					"left":
						move_left.emit()
					"right":
						move_right.emit()
					"down":
						move_down.emit()
				key_timers[key] = GameConfig.REPEAT_RATE
