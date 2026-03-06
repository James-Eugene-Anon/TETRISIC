extends Control

@onready var language_button = $"TabContainer/设置/SettingsVBox/LanguageButton"
@onready var window_mode_option = $"TabContainer/设置/SettingsVBox/WindowModeOption"
@onready var resolution_option = $"TabContainer/设置/SettingsVBox/ResolutionOption"
@onready var music_volume_label = $"TabContainer/设置/SettingsVBox/MusicVolumeLabel"
@onready var music_volume_slider = $"TabContainer/设置/SettingsVBox/MusicVolumeSlider"
@onready var sfx_volume_label = $"TabContainer/设置/SettingsVBox/SFXVolumeLabel"
@onready var sfx_volume_slider = $"TabContainer/设置/SettingsVBox/SFXVolumeSlider"
@onready var online_mode_button = $"TabContainer/设置/SettingsVBox/OnlineModeButton"
@onready var lyric_retry_label = $"TabContainer/设置/SettingsVBox/LyricRetryHBox/LyricRetryLabel"
@onready var lyric_retry_spinbox = $"TabContainer/设置/SettingsVBox/LyricRetryHBox/LyricRetrySpinBox"
@onready var bgm_button = $"TabContainer/设置/SettingsVBox/BGMButton"
@onready var bgm_focus_button = $"TabContainer/设置/SettingsVBox/BGMFocusButton"
@onready var back_button = $BackButton
@onready var title_label = $TitleLabel
@onready var tab_container = $TabContainer

# 关于页面标签
@onready var version_label = $"TabContainer/关于/AboutVBox/VersionLabel"
@onready var author_label = $"TabContainer/关于/AboutVBox/AuthorLabel"
@onready var disclaimer_label = $"TabContainer/关于/AboutVBox/DisclaimerLabel"
@onready var thanks_label = $"TabContainer/关于/AboutVBox/ThanksLabel"


func _ready():
	# 确保在暂停时也能处理输入和渲染
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# 初始化下拉菜单项
	update_option_items()
	
	update_ui_texts()
	
	language_button.item_selected.connect(_on_language_button_pressed)
	window_mode_option.toggled.connect(_on_window_mode_toggled)
	resolution_option.item_selected.connect(_on_resolution_selected)
	music_volume_slider.value_changed.connect(_on_music_volume_changed)
	sfx_volume_slider.value_changed.connect(_on_sfx_volume_changed)
	
	music_volume_slider.gui_input.connect(_on_slider_gui_input.bind(music_volume_slider))
	sfx_volume_slider.gui_input.connect(_on_slider_gui_input.bind(sfx_volume_slider))
	
	online_mode_button.pressed.connect(_on_online_mode_button_pressed)
	lyric_retry_spinbox.value_changed.connect(_on_lyric_retry_value_changed)
	bgm_button.pressed.connect(_on_bgm_button_pressed)
	bgm_focus_button.pressed.connect(_on_bgm_focus_button_pressed)
	back_button.pressed.connect(_on_back_button_pressed)
	
	var window = get_window()
	if window:
		window.size_changed.connect(_on_window_size_changed)
	
	_refresh_resolution_selection()

func _input(event):
	# 如果从游戏进入,禁止ESC键关闭(避免触发暂停菜单)
	if get_meta("from_game", false) and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		return

func update_option_items():
	resolution_option.clear()
	
	# 分辨率选项
	for i in range(Global.resolutions.size()):
		resolution_option.add_item(Global.get_resolution_label(i))

func update_ui_texts():
	var game_info = Global.get_game_info()
	
	title_label.text = tr("UI_TITLE_OPTIONS")
	
	# 更新Tab标签名称
	if tab_container:
		tab_container.set_tab_title(0, tr("UI_OPTIONS_TAB_SETTINGS"))
		tab_container.set_tab_title(1, tr("UI_OPTIONS_TAB_ABOUT"))
	
	# 语言下拉项（0=en, 1=zh）
	language_button.clear()
	language_button.add_item(tr("UI_OPTIONS_LANGUAGE_EN"))
	language_button.add_item(tr("UI_OPTIONS_LANGUAGE_ZH"))
	var lang_index = 0 if Global.current_language == "en" else 1
	language_button.selected = lang_index
	# 设置 OptionButton 的主文本为“选择语言”
	language_button.text = tr("UI_OPTIONS_LANGUAGE_SELECT")
	
	update_option_items()
	window_mode_option.text = tr("UI_OPTIONS_FULLSCREEN")
	window_mode_option.button_pressed = Global.is_fullscreen
	_refresh_resolution_selection()
	
	music_volume_label.text = tr("UI_OPTIONS_MUSIC_VOLUME") + str(int(Global.music_volume * 100)) + "%"
	sfx_volume_label.text = tr("UI_OPTIONS_SFX_VOLUME") + str(int(Global.sfx_volume * 100)) + "%"
	# 同步滑条位置到实际保存值，使用 no_signal 避免触发重复保存
	music_volume_slider.set_value_no_signal(Global.music_volume * 100.0)
	sfx_volume_slider.set_value_no_signal(Global.sfx_volume * 100.0)
	
	# 联网模式按钮
	var online_status = tr("UI_OPTIONS_ONLINE_ON") if Global.online_mode else tr("UI_OPTIONS_ONLINE_OFF")
	online_mode_button.text = tr("UI_OPTIONS_ONLINE_MODE") + online_status

	# 歌词候选检查次数（X，0~10）
	lyric_retry_label.text = tr("UI_OPTIONS_LYRIC_RETRY")
	lyric_retry_spinbox.value = Global.lyric_search_retry_count
	
	# BGM按钮（歌曲模式下禁用）
	var is_song_mode = Global.current_game_mode == Global.GameMode.SONG
	if is_song_mode:
		bgm_button.text = tr("UI_OPTIONS_BGM") + tr("UI_OPTIONS_BGM_DISABLED")
		bgm_button.disabled = true
		bgm_button.modulate.a = 0.5
	else:
		var bgm_status = tr("UI_OPTIONS_BGM_ON") if Global.bgm_enabled else tr("UI_OPTIONS_BGM_OFF")
		bgm_button.text = tr("UI_OPTIONS_BGM") + bgm_status
		bgm_button.disabled = false
		bgm_button.modulate.a = 1.0
	
	# 后台播放音乐按钮
	var focus_status = tr("UI_OPTIONS_BGM_FOCUS_ON") if Global.play_music_when_unfocused else tr("UI_OPTIONS_BGM_FOCUS_OFF")
	bgm_focus_button.text = tr("UI_OPTIONS_BGM_FOCUS") + focus_status
	
	back_button.text = tr("UI_COMMON_BACK")
	
	# 关于页面信息
	version_label.text = game_info["version"]
	author_label.text = game_info["author"]
	disclaimer_label.text = tr("UI_OPTIONS_DISCLAIMER_BODY")
	
	# 更新标题文本
	var controls_title = get_node_or_null("TabContainer/关于/AboutVBox/ControlsTitle")
	if controls_title:
		controls_title.text = tr("UI_OPTIONS_CONTROLS_TITLE")
	
	var disclaimer_title = get_node_or_null("TabContainer/关于/AboutVBox/DisclaimerTitle")
	if disclaimer_title:
		disclaimer_title.text = tr("UI_OPTIONS_DISCLAIMER_TITLE")
	
	var thanks_title = get_node_or_null("TabContainer/关于/AboutVBox/ThanksTitle")
	if thanks_title:
		thanks_title.text = tr("UI_OPTIONS_THANKS_TITLE")
	
	# 特别感谢内容
	thanks_label.text = tr("UI_OPTIONS_THANKS_BODY")

func _on_window_size_changed() -> void:
	_refresh_resolution_selection()

func _refresh_resolution_selection() -> void:
	var current_size = get_window().size
	if Global.is_fullscreen:
		current_size = DisplayServer.screen_get_size()
	
	while resolution_option.item_count > Global.resolutions.size():
		resolution_option.remove_item(resolution_option.item_count - 1)
	
	var match_index = -1
	for i in range(Global.resolutions.size()):
		if Global.resolutions[i] == current_size:
			match_index = i
			break
	
	if match_index != -1:
		resolution_option.selected = match_index
	else:
		var res_name = Global.get_resolution_name()
		resolution_option.add_item(res_name)
		resolution_option.selected = resolution_option.item_count - 1

	if Global.is_fullscreen:
		resolution_option.disabled = true
		resolution_option.modulate.a = 0.5
	else:
		resolution_option.disabled = false
		resolution_option.modulate.a = 1.0

func _on_language_button_pressed(index):
	Global.switch_language(index)
	update_ui_texts()

func _on_window_mode_toggled(pressed: bool):
	var index = 1 if pressed else 0
	Global.set_window_mode(index)
	update_ui_texts()

func _on_resolution_selected(index):
	# 如果选中的是之前添加的"自定义"项（超出预设列表范围）
	if index >= Global.resolutions.size():
		return
		
	Global.set_resolution(index)
	update_ui_texts()

func _on_music_volume_changed(value: float):
	Global.set_music_volume(value / 100.0)
	update_ui_texts()

func _on_sfx_volume_changed(value: float):
	Global.set_sfx_volume(value / 100.0)
	update_ui_texts()

func _on_online_mode_button_pressed():
	Global.set_online_mode(not Global.online_mode)
	update_ui_texts()

func _on_lyric_retry_value_changed(value: float):
	# SpinBox 直接输入/点击调整整数 0~10
	Global.set_lyric_search_retry_count(int(value))

func _on_bgm_button_pressed():
	Global.set_bgm_enabled(not Global.bgm_enabled)
	# 发送信号通知BGM状态变化
	_notify_bgm_change()
	update_ui_texts()

func _on_bgm_focus_button_pressed():
	Global.set_play_music_when_unfocused(not Global.play_music_when_unfocused)
	_notify_bgm_change()
	update_ui_texts()

func _notify_bgm_change():
	# 通知当前场景BGM状态变化
	# 尝试通知Main场景（尝试多种方式找到Main节点）
	var main = get_tree().root.get_node_or_null("Main")
	if main == null:
		# 可能Main是root的子节点的子节点
		for child in get_tree().root.get_children():
			if child.has_method("on_bgm_setting_changed"):
				child.on_bgm_setting_changed(Global.bgm_enabled)
				return
	if main and main.has_method("on_bgm_setting_changed"):
		main.on_bgm_setting_changed(Global.bgm_enabled)
		return
	
	# 尝试通知RoguelikeMap场景
	var rogue_map = get_tree().root.get_node_or_null("RoguelikeMap")
	if rogue_map and rogue_map.has_method("on_bgm_setting_changed"):
		rogue_map.on_bgm_setting_changed(Global.bgm_enabled)

func _on_slider_gui_input(event: InputEvent, slider: HSlider):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			# 只要鼠标在滑条上滚动，就标记事件已处理，防止 ScrollContainer 接收到滚动指令
			accept_event()
			
			var step = slider.step if slider.step > 0 else 1.0
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				slider.value += step
			else:
				slider.value -= step

func _on_back_button_pressed():
	# 检查是否从游戏中打开
	if get_meta("from_game", false):
		# 关闭选项菜单，返回游戏
		queue_free()
	else:
		# 从主菜单打开，返回主菜单
		get_tree().change_scene_to_file("res://UI/MainMenu.tscn")
