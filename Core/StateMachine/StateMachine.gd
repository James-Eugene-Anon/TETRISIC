extends Node
class_name StateMachine

signal state_changed(from_state: String, to_state: String)
signal state_entered(state_name: String)
signal state_exited(state_name: String)

@export var initial_state_path: NodePath

var _states: Dictionary = {}
var _current_state: State = null

func _ready() -> void:
	_collect_states()
	if not initial_state_path.is_empty():
		var init_node = get_node_or_null(initial_state_path)
		if init_node is State:
			change_state(_get_state_key(init_node), {})

func _process(delta: float) -> void:
	if _current_state:
		_current_state.update(delta)

func _physics_process(delta: float) -> void:
	if _current_state:
		_current_state.physics_update(delta)

func _input(event: InputEvent) -> void:
	if _current_state:
		_current_state.handle_input(event)

func _collect_states() -> void:
	_states.clear()
	for child in get_children():
		if child is State:
			var key = _get_state_key(child)
			_states[key] = child

func _get_state_key(state: State) -> String:
	if not state.state_name.is_empty():
		return state.state_name
	return state.name

func get_current_state_name() -> String:
	if _current_state == null:
		return ""
	return _get_state_key(_current_state)

func has_state(state_name: String) -> bool:
	return _states.has(state_name)

func change_state(state_name: String, params: Dictionary = {}) -> bool:
	if not _states.has(state_name):
		push_warning("StateMachine: 未找到状态 %s" % state_name)
		return false

	var next_state: State = _states[state_name]
	if not next_state.can_enter(params):
		return false

	var from_name := ""
	if _current_state:
		if not _current_state.can_exit():
			return false
		from_name = _get_state_key(_current_state)
		_current_state.exit()
		emit_signal("state_exited", from_name)

	_current_state = next_state
	_current_state.enter(params)
	var to_name := _get_state_key(_current_state)
	emit_signal("state_changed", from_name, to_name)
	emit_signal("state_entered", to_name)
	return true
