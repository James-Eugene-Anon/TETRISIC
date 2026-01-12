extends Control

@onready var language_button = $VBox/LanguageButton
@onready var fullscreen_button = $VBox/FullscreenButton
@onready var resolution_button = $VBox/ResolutionButton
@onready var music_volume_label = $VBox/MusicVolumeLabel
@onready var music_volume_slider = $VBox/MusicVolumeSlider
@onready var sfx_volume_label = $VBox/SFXVolumeLabel
@onready var sfx_volume_slider = $VBox/SFXVolumeSlider
@onready var online_mode_button = $VBox/OnlineModeButton
@onready var back_button = $VBox/BackButton
@onready var title_label = $TitleLabel

# 游戏信息标签
@onready var version_label = $InfoPanel/VBox/VersionLabel
@onready var author_label = $InfoPanel/VBox/AuthorLabel
@onready var description_label = $InfoPanel/VBox/DescriptionLabel
@onready var controls_label = $InfoPanel/VBox/ControlsLabel
@onready var disclaimer_label = $InfoPanel/VBox/DisclaimerLabel

const TEXTS = {
	"zh": {
		"title": "选项设置",
		"language": "语言: 中文",
		"language_en": "语言: English",
		"fullscreen": "窗口模式: ",
		"fullscreen_on": "全屏",
		"fullscreen_off": "窗口化",
		"resolution": "分辨率: ",
		"music_volume": "音乐音量: ",
		"sfx_volume": "音效音量: ",
		"online_mode": "联网模式: ",
		"online_on": "在线",
		"online_off": "离线",
		"back": "返回",
		"info_title": "游戏信息"
	},
	"en": {
		"title": "Options",
		"language": "Language: 中文",
		"language_en": "Language: English", 
		"fullscreen": "Window Mode: ",
		"fullscreen_on": "Fullscreen",
		"fullscreen_off": "Windowed",
		"resolution": "Resolution: ",
		"music_volume": "Music Volume: ",
		"sfx_volume": "SFX Volume: ",
		"online_mode": "Network: ",
		"online_on": "Online",
		"online_off": "Offline",
		"back": "Back",
		"info_title": "Game Info"
	}
}

func _ready():
	update_ui_texts()
	language_button.pressed.connect(_on_language_button_pressed)
	fullscreen_button.pressed.connect(_on_fullscreen_button_pressed)
	resolution_button.pressed.connect(_on_resolution_button_pressed)
	music_volume_slider.value_changed.connect(_on_music_volume_changed)
	sfx_volume_slider.value_changed.connect(_on_sfx_volume_changed)
	online_mode_button.pressed.connect(_on_online_mode_button_pressed)
	back_button.pressed.connect(_on_back_button_pressed)
	
	# 设置初始音量
	music_volume_slider.value = Global.music_volume * 100
	sfx_volume_slider.value = Global.sfx_volume * 100

func _input(event):
	# 如果从游戏进入,禁止ESC键关闭(避免触发暂停菜单)
	if get_meta("from_game", false) and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		return

func update_ui_texts():
	var texts = TEXTS[Global.current_language]
	var game_info = Global.get_game_info()
	
	title_label.text = texts["title"]
	
	# 语言按钮显示
	if Global.current_language == "zh":
		language_button.text = texts["language"]
	else:
		language_button.text = texts["language_en"]
	
	# 全屏按钮显示
	var fullscreen_status = texts["fullscreen_on"] if Global.is_fullscreen else texts["fullscreen_off"]
	fullscreen_button.text = texts["fullscreen"] + fullscreen_status
	
	# 分辨率按钮（全屏模式下禁用）
	resolution_button.text = texts["resolution"] + Global.get_resolution_name()
	resolution_button.disabled = Global.is_fullscreen
	resolution_button.modulate.a = 0.5 if Global.is_fullscreen else 1.0
	music_volume_label.text = texts["music_volume"] + str(int(Global.music_volume * 100)) + "%"
	sfx_volume_label.text = texts["sfx_volume"] + str(int(Global.sfx_volume * 100)) + "%"
	
	# 联网模式按钮
	var online_status = texts["online_on"] if Global.online_mode else texts["online_off"]
	online_mode_button.text = texts["online_mode"] + online_status
	
	back_button.text = texts["back"]
	
	# 游戏信息
	version_label.text = game_info["version"]
	author_label.text = game_info["author"]
	description_label.text = game_info["description"]
	controls_label.text = game_info["controls"]
	disclaimer_label.text = game_info.get("disclaimer", "")

func _on_language_button_pressed():
	Global.switch_language()
	update_ui_texts()

func _on_fullscreen_button_pressed():
	Global.toggle_fullscreen()
	update_ui_texts()

func _on_resolution_button_pressed():
	Global.current_resolution_index = (Global.current_resolution_index + 1) % Global.resolutions.size()
	Global.set_resolution(Global.current_resolution_index)
	update_ui_texts()

func _on_music_volume_changed(value: float):
	Global.set_music_volume(value / 100.0)
	update_ui_texts()

func _on_sfx_volume_changed(value: float):
	Global.set_sfx_volume(value / 100.0)
	update_ui_texts()

func _on_online_mode_button_pressed():
	Global.online_mode = not Global.online_mode
	update_ui_texts()

func _on_back_button_pressed():
	# 检查是否从游戏中打开
	if get_meta("from_game", false):
		# 关闭选项菜单，返回游戏
		queue_free()
	else:
		# 从主菜单打开，返回主菜单
		get_tree().change_scene_to_file("res://UI/MainMenu.tscn")
