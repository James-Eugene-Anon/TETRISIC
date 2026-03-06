extends Node
class_name State

# 状态名称，默认取节点名。
@export var state_name: String = ""

# 进入状态时调用，可接收上下文参数。
func enter(_params: Dictionary = {}) -> void:
	pass

# 离开状态时调用，用于清理定时器/临时变量。
func exit() -> void:
	pass

# 每帧逻辑（_process）。
func update(_delta: float) -> void:
	pass

# 物理帧逻辑（_physics_process）。
func physics_update(_delta: float) -> void:
	pass

# 输入分发入口，可选实现。
func handle_input(_event: InputEvent) -> void:
	pass

# 可选：是否允许进入该状态。
func can_enter(_params: Dictionary = {}) -> bool:
	return true

# 可选：是否允许离开该状态。
func can_exit() -> bool:
	return true
