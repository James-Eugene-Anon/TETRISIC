extends Control

# alpha开发版本动画参数
var alpha_label_time: float = 0.0
@onready var alpha_label_node = $AlphaDevLabel

# 存档/账号UI节点（在 MainMenu.tscn 中定义）
@onready var save_btn = $TopLeftHBox/SaveBtn
@onready var current_account_label = $TopLeftHBox/CurrentAccountLabel
@onready var save_overlay = $SaveOverlay
@onready var slot_container = $SaveOverlay/SavePanel/SavePanelVBox/SlotContainer
@onready var save_title_label = $SaveOverlay/SavePanel/SavePanelVBox/SaveTitleLabel
@onready var close_btn = $SaveOverlay/SavePanel/SavePanelVBox/CloseBtn
@onready var slot_rename_dialog = $SlotRenameDialog
@onready var slot_rename_line_edit = $SlotRenameDialog/SlotRenameLineEdit
@onready var slot_delete_confirm_dialog = $SlotDeleteConfirmDialog
var _rename_target_account_id: String = ""
var _delete_target_account_id: String = ""

@onready var start_button = $VBox/StartButton
@onready var lyric_mode_button = $VBox/LyricModeButton
@onready var roguelike_demo_button = $VBox/RoguelikeDemoButton
@onready var options_button = $VBox/OptionsButton
@onready var equipment_button = $VBox/EquipmentButton
@onready var quit_button = $VBox/QuitButton
@onready var instructions_label = $Instructions
@onready var version_label = $VersionLabel


func _ready():
	# 存档/账号UI信号连接
	save_btn.pressed.connect(_on_save_btn_pressed)
	close_btn.pressed.connect(_close_save_overlay)
	slot_rename_dialog.confirmed.connect(_on_rename_confirmed)
	slot_delete_confirm_dialog.confirmed.connect(_on_delete_confirmed)
	# 主菜单按钮连接
	update_ui_texts()
	start_button.pressed.connect(_on_start_button_pressed)
	lyric_mode_button.pressed.connect(_on_lyric_mode_button_pressed)
	roguelike_demo_button.pressed.connect(_on_roguelike_demo_button_pressed)
	options_button.pressed.connect(_on_options_button_pressed)
	equipment_button.pressed.connect(_on_equipment_button_pressed)
	quit_button.pressed.connect(_on_quit_button_pressed)
	_refresh_top_bar()

func _process(delta: float):
	# alpha开发版本文字的缩放脉动动画
	alpha_label_time += delta * 2.5
	if alpha_label_node and alpha_label_node.visible:
		var pulse = 1.0 + sin(alpha_label_time) * 0.06
		alpha_label_node.scale = Vector2(pulse, pulse)

func update_ui_texts():
	var game_info = Global.get_game_info()
	start_button.text = tr("UI_MAIN_START")
	lyric_mode_button.text = tr("UI_MAIN_LYRIC_MODE")
	roguelike_demo_button.text = tr("UI_MAIN_ROGUELIKE_DEMO")
	options_button.text = tr("UI_MAIN_OPTIONS")
	equipment_button.text = tr("UI_MAIN_EQUIPMENT")
	quit_button.text = tr("UI_MAIN_QUIT")
	instructions_label.text = tr("UI_MAIN_INSTRUCTIONS")
	version_label.text = game_info["version"]
	if alpha_label_node:
		alpha_label_node.text = tr("UI_MAIN_MENU_ALPHA_BUILD")
	# 更新存档UI文本
	if save_btn:
		save_btn.text = tr("UI_SAVE_BTN")
	if save_title_label:
		save_title_label.text = tr("UI_SAVE_BTN")
	if close_btn:
		close_btn.text = tr("UI_COMMON_CLOSE")
	if slot_rename_dialog:
		slot_rename_dialog.get_ok_button().text = tr("UI_COMMON_CONFIRM")
		slot_rename_dialog.get_cancel_button().text = tr("UI_COMMON_CANCEL")
	if slot_delete_confirm_dialog:
		slot_delete_confirm_dialog.get_ok_button().text = tr("UI_COMMON_CONFIRM")
		slot_delete_confirm_dialog.get_cancel_button().text = tr("UI_COMMON_CANCEL")
	_refresh_top_bar()

# ==================== 顶部栏 ====================
func _refresh_top_bar() -> void:
	var cur = Global.get_current_account_profile()
	var display = str(cur.get("name", "- -"))
	if bool(cur.get("is_admin", false)):
		display += tr("UI_ACCOUNT_ADMIN_TAG")
	if current_account_label:
		current_account_label.text = display

# ==================== 存档覆盖层 ====================
func _on_save_btn_pressed() -> void:
	_populate_slot_container()
	save_overlay.visible = true

func _close_save_overlay() -> void:
	save_overlay.visible = false

func _populate_slot_container() -> void:
	for child in slot_container.get_children():
		child.queue_free()
	var profiles = Global.get_account_profiles()
	var current_id = str(Global.get_current_account_profile().get("id", ""))
	const MAX_SLOTS: int = 5

	for i in range(MAX_SLOTS):
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		row.custom_minimum_size = Vector2(0, 44)

		if i < profiles.size():
			var profile: Dictionary = profiles[i]
			var pid: String = str(profile.get("id", ""))
			var pname: String = str(profile.get("name", ""))
			var is_admin: bool = bool(profile.get("is_admin", false))
			var is_current: bool = (pid == current_id)
			var play_secs: int = 0
			if SaveManager and SaveManager.has_method("get_account_play_seconds"):
				play_secs = SaveManager.get_account_play_seconds(pid)

			# 左侧信息区（点击切换账号）
			var info_box = VBoxContainer.new()
			info_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			info_box.add_theme_constant_override("separation", 2)
			info_box.mouse_filter = Control.MOUSE_FILTER_STOP

			var name_lbl = Label.new()
			name_lbl.add_theme_font_size_override("font_size", 13)
			name_lbl.mouse_filter = Control.MOUSE_FILTER_PASS
			var display_name = pname + (tr("UI_ACCOUNT_ADMIN_TAG") if is_admin else "")
			if is_current:
				name_lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3, 1.0))
			name_lbl.text = (">> " if is_current else "   ") + display_name

			var time_lbl = Label.new()
			time_lbl.add_theme_font_size_override("font_size", 10)
			time_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7, 1.0))
			time_lbl.mouse_filter = Control.MOUSE_FILTER_PASS
			time_lbl.text = tr("UI_SAVE_PLAY_TIME_FMT") % _format_seconds(play_secs)

			info_box.add_child(name_lbl)
			info_box.add_child(time_lbl)

			# 点击账号行切换
			var pid_capture: String = pid
			info_box.gui_input.connect(func(event: InputEvent) -> void:
				if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
					_switch_to_account(pid_capture))
			row.add_child(info_box)

			# 改名按钮
			var rename_btn = Button.new()
			rename_btn.custom_minimum_size = Vector2(50, 30)
			rename_btn.add_theme_font_size_override("font_size", 11)
			rename_btn.text = tr("UI_ACCOUNT_RENAME")
			rename_btn.pressed.connect(_on_slot_rename_pressed.bind(pid, pname))
			row.add_child(rename_btn)

			# 删除按钮（管理员不可删）
			var del_btn = Button.new()
			del_btn.custom_minimum_size = Vector2(50, 30)
			del_btn.add_theme_font_size_override("font_size", 11)
			del_btn.text = tr("UI_ACCOUNT_DELETE")
			del_btn.disabled = is_admin
			del_btn.pressed.connect(_on_slot_delete_pressed.bind(pid, pname))
			row.add_child(del_btn)
		else:
			# 空档位
			var empty_lbl = Label.new()
			empty_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			empty_lbl.add_theme_font_size_override("font_size", 12)
			empty_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55, 1.0))
			empty_lbl.text = tr("UI_SAVE_SLOT_EMPTY")
			empty_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			row.add_child(empty_lbl)

			var new_btn = Button.new()
			new_btn.custom_minimum_size = Vector2(106, 30)
			new_btn.add_theme_font_size_override("font_size", 11)
			new_btn.text = tr("UI_SAVE_NEW_ACCOUNT")
			new_btn.pressed.connect(_on_new_account_pressed)
			row.add_child(new_btn)

		slot_container.add_child(row)

func _switch_to_account(account_id: String) -> void:
	if str(Global.get_current_account_profile().get("id", "")) == account_id:
		return
	Global.switch_account_profile(account_id)
	_refresh_top_bar()
	_populate_slot_container()

func _format_seconds(secs: int) -> String:
	var h: int = secs / 3600
	var m: int = (secs % 3600) / 60
	var s: int = secs % 60
	return "%d:%02d:%02d" % [h, m, s]

# ==================== 账号改名 / 新建 ====================
func _on_slot_rename_pressed(account_id: String, current_name: String) -> void:
	_rename_target_account_id = account_id
	slot_rename_dialog.title = tr("UI_SAVE_RENAME_TITLE")
	slot_rename_dialog.dialog_text = ""
	slot_rename_line_edit.text = current_name
	slot_rename_line_edit.placeholder_text = tr("UI_ACCOUNT_NAME_PLACEHOLDER")
	slot_rename_dialog.popup_centered()

func _on_new_account_pressed() -> void:
	_rename_target_account_id = ""
	slot_rename_dialog.title = tr("UI_ACCOUNT_CREATE")
	slot_rename_dialog.dialog_text = ""
	slot_rename_line_edit.text = ""
	slot_rename_line_edit.placeholder_text = tr("UI_ACCOUNT_NAME_PLACEHOLDER")
	slot_rename_dialog.popup_centered()

func _on_rename_confirmed() -> void:
	var name: String = slot_rename_line_edit.text.strip_edges()
	# 字节数校验：4-16 bytes（UTF-8）
	var byte_count: int = name.to_utf8_buffer().size()
	if byte_count < 4 or byte_count > 16:
		slot_rename_dialog.dialog_text = tr("UI_SAVE_NAME_ERR_LEN")
		slot_rename_line_edit.text = ""
		slot_rename_dialog.popup_centered()
		return
	# 禁止代码相关特殊字符
	var blocked: Array = ['"', "'", "\\", ";", "=", "<", ">", "/", "*", "?",
		"|", "#", "{", "}", "[", "]", "(", ")", "$", "&", "@", "!", "`", "^", "~"]
	for ch in blocked:
		if name.contains(ch):
			slot_rename_dialog.dialog_text = tr("UI_SAVE_NAME_ERR_CHARS")
			slot_rename_line_edit.text = name
			slot_rename_dialog.popup_centered()
			return

	var result: Dictionary
	if _rename_target_account_id == "":
		# 新建账号模式
		result = Global.create_account_profile(name)
		if bool(result.get("success", false)):
			_populate_slot_container()
			_refresh_top_bar()
		else:
			slot_rename_dialog.dialog_text = _account_error_to_text(str(result.get("error", "")))
			slot_rename_line_edit.text = ""
			slot_rename_dialog.popup_centered()
	else:
		# 改名模式
		result = Global.rename_account_profile(_rename_target_account_id, name)
		if bool(result.get("success", false)):
			_populate_slot_container()
			_refresh_top_bar()
		else:
			slot_rename_dialog.dialog_text = _account_error_to_text(str(result.get("error", "")))
			slot_rename_line_edit.text = name
			slot_rename_dialog.popup_centered()

# ==================== 账号删除 ====================
func _on_slot_delete_pressed(account_id: String, account_name: String) -> void:
	_delete_target_account_id = account_id
	slot_delete_confirm_dialog.title = tr("UI_COMMON_CONFIRM_DELETE")
	slot_delete_confirm_dialog.dialog_text = tr("UI_SAVE_DELETE_FMT") % account_name
	slot_delete_confirm_dialog.popup_centered()

func _on_delete_confirmed() -> void:
	var result = Global.delete_account_profile(_delete_target_account_id)
	if bool(result.get("success", false)):
		_populate_slot_container()
		_refresh_top_bar()

# ==================== 错误文本映射 ====================
func _account_error_to_text(code: String) -> String:
	match code:
		"empty_name":      return tr("UI_ACCOUNT_ERR_EMPTY")
		"duplicate_name":  return tr("UI_ACCOUNT_ERR_DUPLICATE")
		"admin_name_locked":   return tr("UI_ACCOUNT_ERR_ADMIN_RENAME")
		"admin_name_reserved": return tr("UI_ACCOUNT_ERR_ADMIN_RESERVED")
		"admin_cannot_delete": return tr("UI_ACCOUNT_ERR_ADMIN_DELETE")
		"not_found":       return tr("UI_ACCOUNT_ERR_NOT_FOUND")
		_:                 return tr("UI_ACCOUNT_GENERIC_ERROR")

# ==================== 主菜单跳转 ====================
func _on_start_button_pressed():
	get_tree().change_scene_to_file("res://UI/DifficultySelection.tscn")

func _on_lyric_mode_button_pressed():
	get_tree().change_scene_to_file("res://UI/SongSelection.tscn")

func _on_roguelike_demo_button_pressed():
	if ResourceLoader.exists("res://UI/RoguelikeMap.tscn"):
		get_tree().change_scene_to_file("res://UI/RoguelikeMap.tscn")
	elif ResourceLoader.exists("res://UI/RoguelikeCombat.tscn"):
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
