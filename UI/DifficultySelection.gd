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

const TEXTS = {
	"zh": {
		"title": "选择难度",
		"easy": "简单",
		"easy_desc": "只有7种经典方块\n固定下落速度\n适合新手练习",
		"normal": "普通",
		"normal_desc": "所有方块类型\n92%为4格方块\n每250分速度+0.3%\n最高速度133.3%",
		"hard": "困难",
		"hard_desc": "所有方块类型\n2%为3格、73%为4格方块\n每100分速度+0.5%\n最高速度200%",
		"cruel": "残酷",
		"cruel_desc": "初始速度120%\n每200分速度+1%（最高250%）\n4%为3格、66%为4格方块\n每2000分底部生成障碍行",
		"back": "返回",
		"start": "开始游戏",
		"high_score": "最高分: %d (消除行数: %d)"
	},
	"en": {
		"title": "Select Difficulty",
		"easy": "Easy",
		"easy_desc": "7 classic pieces only\nFixed fall speed\nPerfect for beginners",
		"normal": "Normal",
		"normal_desc": "All piece types\n92% are 4-cell pieces\nSpeed +0.3% per 250 pts\nMax speed 133.3%",
		"hard": "Hard",
		"hard_desc": "All piece types\n2% 3-cell, 73% 4-cell pieces\nSpeed +0.5% per 100 pts\nMax speed 200%",
		"cruel": "Cruel",
		"cruel_desc": "Initial speed 120%\nSpeed +1% per 200 pts (max 250%)\n4% 3-cell, 66% 4-cell pieces\nObstacle row spawns per 2000 pts",
		"back": "Back",
		"start": "Start Game",
		"high_score": "High Score: %d (Lines: %d)"
	}
}

func _ready():
	update_ui_texts()
	populate_difficulty_list()
	bubble_container.visible = false
	back_button.pressed.connect(_on_back_pressed)
	start_button.pressed.connect(_on_start_pressed)

func update_ui_texts():
	var texts = TEXTS[Global.current_language]
	title_label.text = texts["title"]
	back_button.text = texts["back"]
	start_button.text = texts["start"]

func populate_difficulty_list():
	# 清空现有项
	for child in difficulty_list.get_children():
		child.queue_free()
	difficulty_buttons.clear()
	
	var texts = TEXTS[Global.current_language]
	var difficulties = [
		{"key": "easy", "color": Color(0.5, 1, 0.5, 1)},
		{"key": "normal", "color": Color(1, 1, 0.5, 1)},
		{"key": "hard", "color": Color(1, 0.5, 0.5, 1)},
		{"key": "cruel", "color": Color(0.8, 0.2, 0.2, 1)}
	]
	
	for i in range(difficulties.size()):
		var diff = difficulties[i]
		var button = Button.new()
		button.text = texts[diff["key"]]
		button.custom_minimum_size = Vector2(300, 60)
		
		# 加载字体
		var font = load("res://fonts/FUSION-PIXEL-12PX-MONOSPACED-ZH_HANS.OTF")
		button.add_theme_font_override("font", font)
		button.add_theme_font_size_override("font_size", 20)
		button.add_theme_color_override("font_color", diff["color"])
		
		var diff_index = i
		button.pressed.connect(func(): _on_difficulty_selected(diff_index))
		
		difficulty_list.add_child(button)
		difficulty_buttons.append(button)

func _on_difficulty_selected(index: int):
	selected_difficulty = index
	var texts = TEXTS[Global.current_language]
	var keys = ["easy", "normal", "hard", "cruel"]
	var colors = [Color(0.5, 1, 0.5, 1), Color(1, 1, 0.5, 1), Color(1, 0.5, 0.5, 1), Color(0.8, 0.2, 0.2, 1)]
	
	detail_name.text = texts[keys[index]]
	detail_name.add_theme_color_override("font_color", colors[index])
	detail_desc.text = texts[keys[index] + "_desc"]
	
	# 获取最高分
	var high_score_data = Global.get_classic_score(index)
	detail_high_score.text = texts["high_score"] % [high_score_data["score"], high_score_data["lines"]]
	
	# 更新气泡箭头位置指向选中的按钮
	_update_bubble_position(index)
	
	# 显示气泡（带动画）
	_show_bubble()

func _update_bubble_position(index: int):
	"""更新气泡箭头位置，使其指向选中的按钮"""
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
	"""显示气泡（带动画）"""
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
		get_tree().change_scene_to_file("res://Main.tscn")

func _on_back_pressed():
	get_tree().change_scene_to_file("res://UI/MainMenu.tscn")
