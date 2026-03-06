extends Control

# alpha开发版本动画参数
var alpha_label_time: float = 0.0
@onready var alpha_label_node = $AlphaDevLabel

@onready var start_button = $VBox/StartButton
@onready var lyric_mode_button = $VBox/LyricModeButton
@onready var roguelike_demo_button = $VBox/RoguelikeDemoButton
@onready var options_button = $VBox/OptionsButton
@onready var equipment_button = $VBox/EquipmentButton
@onready var quit_button = $VBox/QuitButton
@onready var title_label = $TitleLabel
@onready var instructions_label = $Instructions
@onready var version_label = $VersionLabel


func _ready():
	update_ui_texts()
	start_button.pressed.connect(_on_start_button_pressed)
	lyric_mode_button.pressed.connect(_on_lyric_mode_button_pressed)
	roguelike_demo_button.pressed.connect(_on_roguelike_demo_button_pressed)
	options_button.pressed.connect(_on_options_button_pressed)
	equipment_button.pressed.connect(_on_equipment_button_pressed)
	quit_button.pressed.connect(_on_quit_button_pressed)

func _process(delta: float):
	# alpha开发版本文字的缩放脉动动画
	alpha_label_time += delta * 2.5
	if alpha_label_node and alpha_label_node.visible:
		var pulse = 1.0 + sin(alpha_label_time) * 0.06
		alpha_label_node.scale = Vector2(pulse, pulse)

func update_ui_texts():
	var game_info = Global.get_game_info()
	
	title_label.text = tr("UI_MAIN_TITLE")
	start_button.text = tr("UI_MAIN_START")
	lyric_mode_button.text = tr("UI_MAIN_LYRIC_MODE")
	roguelike_demo_button.text = tr("UI_MAIN_ROGUELIKE_DEMO")
	options_button.text = tr("UI_MAIN_OPTIONS")
	equipment_button.text = tr("UI_MAIN_EQUIPMENT")
	quit_button.text = tr("UI_MAIN_QUIT")
	instructions_label.text = tr("UI_MAIN_INSTRUCTIONS")
	version_label.text = game_info["version"]
	
	# 更新alpha标签语言
	if alpha_label_node:
		alpha_label_node.text = tr("UI_MAIN_MENU_ALPHA_BUILD")
func _on_start_button_pressed():
	get_tree().change_scene_to_file("res://UI/DifficultySelection.tscn")

func _on_lyric_mode_button_pressed():
	get_tree().change_scene_to_file("res://UI/SongSelection.tscn")

func _on_roguelike_demo_button_pressed():
	# 进入Roguelike地图界面（含战斗、装备、休息）
	if ResourceLoader.exists("res://UI/RoguelikeMap.tscn"):
		get_tree().change_scene_to_file("res://UI/RoguelikeMap.tscn")
	elif ResourceLoader.exists("res://UI/RoguelikeCombat.tscn"):
		# 备用：直接进入战斗
		get_tree().change_scene_to_file("res://UI/RoguelikeCombat.tscn")
	else:
		push_warning(tr("UI_MAIN_ROGUE_NOT_FOUND"))
		var dialog = AcceptDialog.new()
		dialog.dialog_text = tr("UI_MAIN_MENU_WIP_HINT")
		dialog.exclusive = false
		add_child(dialog)
		dialog.popup_centered()

func _on_options_button_pressed():
	get_tree().change_scene_to_file(Config.PATHS_SCENE_OPTIONS_MENU)

func _on_equipment_button_pressed():
	get_tree().change_scene_to_file("res://Items/EquipmentMenu.tscn")

func _on_quit_button_pressed():
	get_tree().quit()
