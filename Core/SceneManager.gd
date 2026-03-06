extends Node
class_name SceneManagerClass

## 场景管理器 (Autoload)
## 负责场景切换、过渡动画、场景栈管理

# ==================== 信号定义 ====================
signal scene_change_started(from_scene: String, to_scene: String)
signal scene_change_completed(scene_name: String)
signal transition_midpoint  # 过渡动画中点（用于在黑屏时切换场景）

# ==================== 场景路径注册表 ====================
var SCENES: Dictionary = {
	# 主菜单
	"main_menu": "res://UI/MainMenu.tscn",
	"options": "res://UI/OptionsMenu.tscn",
	
	# RPG 核心场景
	"run_map": "res://Roguelike/MapScene.tscn",
	"combat": "res://Combat/CombatScene.tscn",
	"shop": "res://Roguelike/ShopScene.tscn",
	"rest": "res://Roguelike/RestScene.tscn",
	"event": "res://Roguelike/EventScene.tscn",
	"treasure": "res://Roguelike/TreasureScene.tscn",
	
	# 原有俄罗斯方块
	"tetris_classic": "res://Main.tscn",
	"song_selection": "res://UI/SongSelection.tscn",
	
	# Demo 场景
	"demo_map": "res://Demo/DemoMap.tscn",
	"demo_combat": "res://Demo/DemoCombat.tscn",
}

# ==================== 状态 ====================
var current_scene_key: String = ""
var scene_stack: Array[String] = []  # 用于返回上一场景
var is_transitioning: bool = false

# 过渡动画节点（需要在场景中实例化）
var transition_player: AnimationPlayer = null
var transition_rect: ColorRect = null

func _ready():
	print("[SceneManager] 场景管理器已加载")
	_setup_transition_overlay()

func _setup_transition_overlay():
	# 创建过渡动画覆盖层
	# 创建 CanvasLayer 确保在最顶层
	var canvas = CanvasLayer.new()
	canvas.layer = 100
	canvas.name = "TransitionLayer"
	add_child(canvas)
	
	# 创建黑色遮罩
	transition_rect = ColorRect.new()
	transition_rect.color = Color.BLACK
	transition_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	transition_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	transition_rect.modulate.a = 0.0
	canvas.add_child(transition_rect)
	
	# 创建动画播放器
	transition_player = AnimationPlayer.new()
	transition_player.name = "TransitionPlayer"
	canvas.add_child(transition_player)
	
	# 创建淡入淡出动画
	_create_transition_animations()

func _create_transition_animations():
	# 创建过渡动画
	var library = AnimationLibrary.new()
	
	# 淡出动画（场景消失）
	var fade_out = Animation.new()
	fade_out.length = 0.3
	var track_idx = fade_out.add_track(Animation.TYPE_VALUE)
	fade_out.track_set_path(track_idx, "../ColorRect:modulate:a")
	fade_out.track_insert_key(track_idx, 0.0, 0.0)
	fade_out.track_insert_key(track_idx, 0.3, 1.0)
	library.add_animation("fade_out", fade_out)
	
	# 淡入动画（场景出现）
	var fade_in = Animation.new()
	fade_in.length = 0.3
	track_idx = fade_in.add_track(Animation.TYPE_VALUE)
	fade_in.track_set_path(track_idx, "../ColorRect:modulate:a")
	fade_in.track_insert_key(track_idx, 0.0, 1.0)
	fade_in.track_insert_key(track_idx, 0.3, 0.0)
	library.add_animation("fade_in", fade_in)
	
	transition_player.add_animation_library("transitions", library)

# ==================== 场景切换 API ====================
func change_scene(scene_key: String, push_to_stack: bool = true, with_transition: bool = true) -> void:
	# 切换到指定场景
	if is_transitioning:
		push_warning("[SceneManager] 正在切换场景，忽略请求")
		return
	
	var scene_path = SCENES.get(scene_key, scene_key)  # 如果不在注册表中，直接用作路径
	
	if not ResourceLoader.exists(scene_path):
		push_error("[SceneManager] 场景不存在: " + scene_path)
		return
	
	var old_scene = current_scene_key
	
	if push_to_stack and not current_scene_key.is_empty():
		scene_stack.push_back(current_scene_key)
	
	scene_change_started.emit(old_scene, scene_key)
	
	if with_transition:
		await _transition_to_scene(scene_path, scene_key)
	else:
		_do_scene_change(scene_path, scene_key)

func go_back(with_transition: bool = true) -> void:
	# 返回上一个场景
	if scene_stack.is_empty():
		push_warning("[SceneManager] 场景栈为空，无法返回")
		return
	
	var previous_scene = scene_stack.pop_back()
	await change_scene(previous_scene, false, with_transition)

func clear_stack() -> void:
	# 清空场景栈
	scene_stack.clear()

# ==================== 房间类型快捷方法 ====================
func enter_combat(enemy_data: Dictionary = {}) -> void:
	# 进入战斗场景
	# 可以通过 GameState 传递敌人数据
	if Engine.has_singleton("GameState"):
		# 存储战斗数据供战斗场景使用
		pass
	await change_scene("combat")

func enter_shop() -> void:
	# 进入商店
	await change_scene("shop")

func enter_rest() -> void:
	# 进入休息点
	await change_scene("rest")

func enter_event(event_id: String = "") -> void:
	# 进入事件
	await change_scene("event")

func enter_treasure() -> void:
	# 进入宝箱房
	await change_scene("treasure")

func return_to_map() -> void:
	# 返回地图
	await change_scene("run_map", false)

# ==================== 内部方法 ====================
func _transition_to_scene(scene_path: String, scene_key: String) -> void:
	# 带过渡动画的场景切换
	is_transitioning = true
	
	# 播放淡出
	transition_player.play("transitions/fade_out")
	await transition_player.animation_finished
	
	transition_midpoint.emit()
	
	# 切换场景
	_do_scene_change(scene_path, scene_key)
	
	# 等待一帧确保场景加载
	await get_tree().process_frame
	
	# 播放淡入
	transition_player.play("transitions/fade_in")
	await transition_player.animation_finished
	
	is_transitioning = false

func _do_scene_change(scene_path: String, scene_key: String) -> void:
	# 执行场景切换
	var error = get_tree().change_scene_to_file(scene_path)
	if error != OK:
		push_error("[SceneManager] 场景切换失败: " + scene_path)
		return
	
	current_scene_key = scene_key
	scene_change_completed.emit(scene_key)
	print("[SceneManager] 切换到场景: ", scene_key)

# ==================== 工具方法 ====================
func get_scene_path(scene_key: String) -> String:
	# 获取场景路径
	return SCENES.get(scene_key, "")

func is_scene_registered(scene_key: String) -> bool:
	# 检查场景是否已注册
	return SCENES.has(scene_key)

func register_scene(scene_key: String, scene_path: String) -> void:
	# 动态注册场景
	SCENES[scene_key] = scene_path
