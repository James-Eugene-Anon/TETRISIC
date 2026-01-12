extends Control

@onready var start_button = $VBox/StartButton
@onready var lyric_mode_button = $VBox/LyricModeButton
@onready var options_button = $VBox/OptionsButton
@onready var equipment_button = $VBox/EquipmentButton
@onready var quit_button = $VBox/QuitButton
@onready var title_label = $TitleLabel
@onready var instructions_label = $Instructions

const TEXTS = {
	"zh": {
		"title": "俄罗斯方块",
		"start": "经典模式",
		"lyric_mode": "歌曲模式",
		"options": "选项",
		"equipment": "装备",
		"quit": "退出游戏",
		"instructions": "游戏控制: ← → 移动  ↑ 旋转  ↓ 快速下降  Enter 硬降落  ESC 暂停"
	},
	"en": {
		"title": "Tetris",
		"start": "Clsaaic Mode",
		"lyric_mode": "Song Mode",
		"options": "Options",
		"equipment": "Equipment",
		"quit": "Quit Game",
		"instructions": "Controls: ← → Move  ↑ Rotate  ↓ Soft Drop  Enter Hard Drop  ESC Pause"
	}
}

func _ready():
	update_ui_texts()
	start_button.pressed.connect(_on_start_button_pressed)
	lyric_mode_button.pressed.connect(_on_lyric_mode_button_pressed)
	options_button.pressed.connect(_on_options_button_pressed)
	equipment_button.pressed.connect(_on_equipment_button_pressed)
	quit_button.pressed.connect(_on_quit_button_pressed)

func update_ui_texts():
	var texts = TEXTS[Global.current_language]
	title_label.text = texts["title"]
	start_button.text = texts["start"]
	lyric_mode_button.text = texts["lyric_mode"]
	options_button.text = texts["options"]
	equipment_button.text = texts["equipment"]
	quit_button.text = texts["quit"]
	instructions_label.text = texts["instructions"]

func _on_start_button_pressed():
	get_tree().change_scene_to_file("res://UI/DifficultySelection.tscn")

func _on_lyric_mode_button_pressed():
	get_tree().change_scene_to_file("res://UI/SongSelection.tscn")

func _on_options_button_pressed():
	get_tree().change_scene_to_file("res://UI/OptionsMenu.tscn")

func _on_equipment_button_pressed():
	get_tree().change_scene_to_file("res://Items/EquipmentMenu.tscn")

func _on_quit_button_pressed():
	get_tree().quit()
