extends Control

@onready var title_label = $TitleLabel
@onready var difficulty_list = $LeftPanel/VBox/ScrollContainer/DifficultyList
@onready var back_button = $LeftPanel/VBox/BackButton
@onready var bubble_container = $BubbleContainer
@onready var detail_panel = $BubbleContainer/RightPanel
@onready var bubble_arrow = $BubbleContainer/BubbleArrow
@onready var detail_name = $BubbleContainer/RightPanel/VBox/DifficultyName
@onready var detail_desc = $BubbleContainer/RightPanel/VBox/DescLabel
@onready var detail_high_score = $BubbleContainer/RightPanel/VBox/HighScoreLabel
@onready var start_button = $BubbleContainer/RightPanel/VBox/StartButton

var selected_difficulty = -1
var difficulty_buttons: Array = []


func _ready():
	update_ui_texts()
	populate_difficulty_list()
	bubble_container.visible = false
	back_button.pressed.connect(_on_back_pressed)
	start_button.pressed.connect(_on_start_pressed)

func update_ui_texts():
	title_label.text = tr("UI_DIFFICULTY_TITLE")
	back_button.text = tr("UI_COMMON_BACK")
	start_button.text = tr("UI_COMMON_START_GAME")

func populate_difficulty_list():
	# 清空现有项
	for child in difficulty_list.get_children():
		child.queue_free()
	difficulty_buttons.clear()
	
	var difficulties = [
		{"key": "UI_DIFFICULTY_EASY", "desc": "UI_DIFFICULTY_EASY_DESC", "color": Color(0.5, 1, 0.5, 1)},
		{"key": "UI_DIFFICULTY_NORMAL", "desc": "UI_DIFFICULTY_NORMAL_DESC", "color": Color(1, 1, 0.5, 1)},
		{"key": "UI_DIFFICULTY_HARD", "desc": "UI_DIFFICULTY_HARD_DESC", "color": Color(1, 0.5, 0.5, 1)},
		{"key": "UI_DIFFICULTY_CRUEL", "desc": "UI_DIFFICULTY_CRUEL_DESC", "color": Color(0.8, 0.2, 0.2, 1)}
	]
	
	for i in range(difficulties.size()):
		var diff = difficulties[i]
		var button = Button.new()
		button.text = tr(diff["key"])
		button.custom_minimum_size = Vector2(300, 60)
		
		# 加载字体
		var font = load(Config.PATHS_FONT_DEFAULT)
		button.add_theme_font_override("font", font)
		button.add_theme_font_size_override("font_size", 20)
		button.add_theme_color_override("font_color", diff["color"])
		
		var diff_index = i
		button.pressed.connect(func(): _on_difficulty_selected(diff_index))
		
		difficulty_list.add_child(button)
		difficulty_buttons.append(button)

func _on_difficulty_selected(index: int):
	selected_difficulty = index
	var keys = ["UI_DIFFICULTY_EASY", "UI_DIFFICULTY_NORMAL", "UI_DIFFICULTY_HARD", "UI_DIFFICULTY_CRUEL"]
	var desc_keys = ["UI_DIFFICULTY_EASY_DESC", "UI_DIFFICULTY_NORMAL_DESC", "UI_DIFFICULTY_HARD_DESC", "UI_DIFFICULTY_CRUEL_DESC"]
	var colors = [Color(0.5, 1, 0.5, 1), Color(1, 1, 0.5, 1), Color(1, 0.5, 0.5, 1), Color(0.8, 0.2, 0.2, 1)]
	
	detail_name.text = tr(keys[index])
	detail_name.add_theme_color_override("font_color", colors[index])
	detail_desc.text = tr(desc_keys[index])
	
	# 获取最高分
	var high_score_data = Global.get_classic_score(index)
	detail_high_score.text = tr("UI_DIFFICULTY_HIGH_SCORE") % [high_score_data["score"], high_score_data["lines"]]
	
	# 更新气泡箭头位置指向选中的按钮
	_update_bubble_position(index)
	
	# 显示气泡（带动画）
	_show_bubble()

func _update_bubble_position(index: int):
	# 更新气泡箭头位置，使其指向选中的按钮
	if index < difficulty_buttons.size():
		var button = difficulty_buttons[index]
		var button_center_y = button.global_position.y + button.size.y / 2
		var bubble_global_y = bubble_container.global_position.y
		var arrow_local_y = button_center_y - bubble_global_y
		
		# 更新箭头位置
		bubble_arrow.polygon = PackedVector2Array([
			Vector2(-20, arrow_local_y),
			Vector2(0, arrow_local_y - 15),
			Vector2(0, arrow_local_y + 15)
		])

func _show_bubble():
	# 显示气泡（带动画）
	if not bubble_container.visible:
		bubble_container.visible = true
		bubble_container.modulate.a = 0.0
		bubble_container.scale = Vector2(0.9, 0.9)
		
		var bubble_tween = create_tween()
		bubble_tween.set_parallel(true)
		bubble_tween.tween_property(bubble_container, "modulate:a", 1.0, 0.2).set_ease(Tween.EASE_OUT)
		bubble_tween.tween_property(bubble_container, "scale", Vector2(1.0, 1.0), 0.2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

func _on_start_pressed():
	if selected_difficulty >= 0:
		Global.classic_difficulty = selected_difficulty
		Global.lyric_mode_enabled = false
		get_tree().change_scene_to_file(Config.PATHS_SCENE_MAIN)

func _on_back_pressed():
	get_tree().change_scene_to_file(Config.PATHS_SCENE_MAIN_MENU)
