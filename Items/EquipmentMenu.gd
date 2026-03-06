extends Control

## 装备界面 - 管理和选择装备

@onready var title_label = $TitleLabel
@onready var equipment_list = $LeftPanel/VBox/ScrollContainer/EquipmentList
@onready var back_button = $LeftPanel/VBox/BackButton
@onready var bubble_container = $BubbleContainer
@onready var detail_panel = $BubbleContainer/RightPanel
@onready var bubble_arrow = $BubbleContainer/BubbleArrow
@onready var detail_name = $BubbleContainer/RightPanel/VBox/EquipmentName
@onready var detail_desc = $BubbleContainer/RightPanel/VBox/DescLabel
@onready var detail_status = $BubbleContainer/RightPanel/VBox/StatusLabel
@onready var equip_button = $BubbleContainer/RightPanel/VBox/EquipButton

var selected_equipment = -1
var equipment_buttons: Array = []
var button_to_equip_index: Dictionary = {}  # 按钮到装备索引的映射

# 装备分类
enum EquipmentCategory {
	UNIVERSAL,    # 通用装备
	CLASSIC,      # 经典模式装备
	SONG,         # 歌曲模式装备
	ROGUELIKE     # Roguelike模式装备
}

# 装备数据
var equipment_data = [
	# 通用装备
	{
		"id": "faulty_score_amplifier",
		"category": EquipmentCategory.UNIVERSAL,
		"unlocked": true,
		"equipped": false
	},
	{
		"id": "rift_meter",
		"category": EquipmentCategory.UNIVERSAL,
		"unlocked": true,
		"equipped": false
	},
	{
		"id": "capacity_disk",
		"category": EquipmentCategory.UNIVERSAL,
		"unlocked": true,
		"equipped": false
	},
	# 经典模式装备
	{
		"id": "special_block_generator",
		"category": EquipmentCategory.CLASSIC,
		"unlocked": true,
		"equipped": true
	},
	{
		"id": "snake_virus",
		"category": EquipmentCategory.CLASSIC,
		"unlocked": true,
		"equipped": false
	},
	# Roguelike模式装备
	{
		"id": "downclock_software",
		"category": EquipmentCategory.ROGUELIKE,
		"unlocked": true,
		"equipped": false
	},
	{
		"id": "iron_sword",
		"category": EquipmentCategory.ROGUELIKE,
		"unlocked": true,
		"equipped": false
	},
	{
		"id": "iron_shield",
		"category": EquipmentCategory.ROGUELIKE,
		"unlocked": true,
		"equipped": false
	},
	# 歌曲模式装备
	{
		"id": "hearts_melody",
		"category": EquipmentCategory.SONG,
		"unlocked": true,
		"equipped": false
	}
]

const TEXTS = {
	"zh": {
		"title": "装备系统",
		"category_universal": "【通用装备】",
		"category_classic": "【经典模式装备】",
		"category_song": "【歌曲模式装备】",
		"category_roguelike": "【Roguelike装备】",
		"faulty_score_amplifier": "故障增幅器",
		"faulty_score_amplifier_desc": "【效果】\n方块初始下落速度 ×105%\n所有非连击得分 ×120%\n\n【注意】\n连击加分不受此效果影响\n速度加成会叠加难度速度加成",
		"rift_meter": "裂隙仪",
		"rift_meter_desc": "【效果】\n主动道具，按 C 键触发\n消除最底下差一格消除的行\n（消除不计分）\n\n【冷却】\n45秒",
		"capacity_disk": "扩容磁盘",
		"capacity_disk_desc": "【效果】\n网格扩容为12×24\n画面等比缩放，\n占用总空间不变",
		"special_block_generator": "特殊方块生成器",
		"special_block_generator_desc": "【效果】\n每次生成方块时，有1.5%概率生成特殊方块\n（6次生成冷却）\n\n【特殊方块类型】\n💣 炸弹：消除3×3区域\n━ 横向激光：消除整行\n┃ 纵向激光：消除整列\n\n【重力规则】\n只有消除整行时才会下落\n炸弹和纵向激光不触发下落\n\n【计分规则】\n额外消除 +5分/格",
		"snake_virus": "贪吃蛇病毒",
		"snake_virus_desc": "【效果】\n每次生成方块时，有1%概率生成贪吃蛇\n（12次生成冷却）\n\n【贪吃蛇规则】\n初始3格长，每出现一次+1格\n↑↓←→ 控制方向\n撞到上壁：消失（放弃）\n撞到左右壁：传送至另一边\n撞到其他方块或底壁：固定为方块\n\n【预览框显示】\n\"贪吃蛇\" 字样",
		"beat_calibrator": "节拍校对器(未实现)",
		"beat_calibrator_desc": "【效果】\n让歌词方块的落地时机与歌词时间对应\n\n【评价系统】\nPERFECT (±0.3s): 分数×1.5\nGOOD (±0.8s): 分数×1.0\nMISS (>0.8s): 分数×0.5\n\n【专属连击】\nMISS会重置连击\n其他评价+1连击\n（连击不影响计分）",
		"downclock_software": "降频软件",
		"downclock_software_desc": "【效果】\n敌人行为冷却 ×110%\n玩家伤害 ×0.9\n（不影响护甲获取）",
		"iron_sword": "铁剑",
		"iron_sword_desc": "【效果】\n攻击力 +5",
		"iron_shield": "铁盾",
		"iron_shield_desc": "【效果】\n防御力 +5（获得护甲量）",
		"hearts_melody": "心之旋律",
		"hearts_melody_desc": "【效果】\n完全禁用节拍同步机制\n分数不受节拍评价影响\n\n【代价】\n最终得分 ×0.85",
		"back": "返回",
		"equip": "装备",
		"unequip": "卸下",
		"equipped": "已装备",
		"locked": "未解锁",
		"slot_limit": "（每类只能装备1个）",
		"roguelike_only": "仅Roguelike模式可用"
	},
	"en": {
		"title": "Equipment",
		"category_universal": "[UNIVERSAL]",
		"category_classic": "[CLASSIC MODE]",
		"category_song": "[SONG MODE]",
		"category_roguelike": "[ROGUELIKE]",
		"faulty_score_amplifier": "Faulty Score Amplifier",
		"faulty_score_amplifier_desc": "[Effect]\nInitial fall speed ×105%\nAll non-combo scores ×120%\n\n[Note]\nCombo bonus is not affected\nSpeed boost stacks with difficulty",
		"rift_meter": "Rift Meter",
		"rift_meter_desc": "[Effect]\nActive item, press C to trigger\nClears the bottom-most row that is\nmissing one block\n(No score for clearing)\n\n[Cooldown]\n45 seconds",
		"capacity_disk": "Capacity Disk",
		"capacity_disk_desc": "[Effect]\nGrid expands to 12×24\nScaled to keep the same\non-screen footprint",
		"special_block_generator": "Special Block Generator",
		"special_block_generator_desc": "[Effect]\n1.5% chance to spawn special block\n(6 spawn cooldown)\n\n[Special Block Types]\n💣 Bomb: Clears 3×3 area\n━ H-Laser: Clears entire row\n┃ V-Laser: Clears entire column\n\n[Gravity Rules]\nOnly full row clears cause drops\nBomb and V-Laser don't trigger drops\n\n[Scoring]\nExtra cells cleared: +5 pts/cell",
		"snake_virus": "Snake Virus",
		"snake_virus_desc": "[Effect]\n1% chance to spawn snake\n(12 spawn cooldown)\n\n[Snake Rules]\nStarts at 3 cells, +1 each spawn\n↑↓←→ to control direction\nHit top wall: disappears\nHit left/right wall: wraps around\nHit blocks/bottom: becomes blocks\n\n[Preview]\nShows \"Snake\" text",
		"beat_calibrator": "Beat Calibrator",
		"beat_calibrator_desc": "[Effect]\nSyncs block landing with lyrics timing\n\n[Rating System]\nPERFECT (±0.3s): Score×1.5\nGOOD (±0.8s): Score×1.0\nMISS (>0.8s): Score×0.5\n\n[Beat Combo]\nMISS resets combo\nOther ratings +1 combo\n(Combo doesn't affect score)",
		"downclock_software": "Downclock Software",
		"downclock_software_desc": "[Effect]\nEnemy action cooldown ×110%\nPlayer damage ×0.9\n(Armor gain unchanged)",
		"iron_sword": "Iron Sword",
		"iron_sword_desc": "[Effect]\nAttack power +5",
		"iron_shield": "Iron Shield",
		"iron_shield_desc": "[Effect]\nDefend mode gains +5 extra armor",
		"hearts_melody": "Heart's Melody",
		"hearts_melody_desc": "[Effect]\nDisables beat sync entirely\nScore unaffected by beat rating\nAll beat-related UI hidden\n\n[Tradeoff]\nFinal score ×0.85",
		"back": "Back",
		"equip": "Equip",
		"unequip": "Unequip",
		"equipped": "Equipped",
		"locked": "Locked",
		"slot_limit": "(1 per category)",
		"roguelike_only": "Roguelike only"
	}
}

func _ready():
	# 从Global加载装备状态
	_load_equipment_state()
	_apply_styles()
	update_ui_texts()
	populate_equipment_list()
	bubble_container.visible = false
	back_button.pressed.connect(_on_back_pressed)
	equip_button.pressed.connect(_on_equip_pressed)

func _apply_styles():
	# 标题样式
	UITheme.apply_label_theme(title_label, null, UITheme.FONT_SIZE_XL, UITheme.ACCENT_SECONDARY)
	
	# 左面板
	var left_panel = get_node_or_null("LeftPanel")
	if left_panel:
		var panel_style = UITheme.create_panel_style(UITheme.BG_DARK, 
			UITheme.BORDER_MEDIUM, UITheme.BORDER_THIN, UITheme.CORNER_MD)
		left_panel.add_theme_stylebox_override("panel", panel_style)
	
	# 详情面板
	if detail_panel:
		var detail_style = UITheme.create_panel_style(UITheme.BG_MEDIUM, 
			UITheme.ACCENT_PRIMARY, UITheme.BORDER_NORMAL, UITheme.CORNER_LG)
		detail_panel.add_theme_stylebox_override("panel", detail_style)
	
	# 按钮样式
	UITheme.apply_button_theme(back_button)
	UITheme.apply_button_theme(equip_button)
	
	# 详情标签样式
	UITheme.apply_label_theme(detail_name, null, UITheme.FONT_SIZE_LG, UITheme.ACCENT_PRIMARY)
	UITheme.apply_label_theme(detail_desc, null, UITheme.FONT_SIZE_SM, UITheme.TEXT_PRIMARY)
	UITheme.apply_label_theme(detail_status, null, UITheme.FONT_SIZE_MD, UITheme.ACCENT_SUCCESS)

func _load_equipment_state():
	# 从Global加载装备状态
	for equip in equipment_data:
		if equip.id == "special_block_generator":
			equip.equipped = Global.equipment_classic_special_block
		elif equip.id == "faulty_score_amplifier":
			equip.equipped = Global.equipment_universal_faulty_amplifier
		elif equip.id == "rift_meter":
			equip.equipped = Global.equipment_universal_rift_meter
		elif equip.id == "capacity_disk":
			equip.equipped = Global.equipment_universal_capacity_disk
		elif equip.id == "snake_virus":
			equip.equipped = Global.equipment_classic_snake_virus
		elif equip.id == "hearts_melody":
			equip.equipped = Global.equipment_song_hearts_melody

func _save_equipment_state():
	# 保存装备状态到Global
	for equip in equipment_data:
		if equip.id == "special_block_generator":
			Global.equipment_classic_special_block = equip.equipped
		elif equip.id == "faulty_score_amplifier":
			Global.equipment_universal_faulty_amplifier = equip.equipped
		elif equip.id == "rift_meter":
			Global.equipment_universal_rift_meter = equip.equipped
		elif equip.id == "capacity_disk":
			Global.equipment_universal_capacity_disk = equip.equipped
		elif equip.id == "snake_virus":
			Global.equipment_classic_snake_virus = equip.equipped
		elif equip.id == "hearts_melody":
			Global.equipment_song_hearts_melody = equip.equipped

func update_ui_texts():
	var texts = TEXTS[Global.current_language]
	title_label.text = texts["title"]
	back_button.text = texts["back"]

func populate_equipment_list():
	# 清空现有项
	for child in equipment_list.get_children():
		child.queue_free()
	equipment_buttons.clear()
	button_to_equip_index.clear()
	
	var texts = TEXTS[Global.current_language]
	var font = load("res://fonts/FUSION-PIXEL-12PX-MONOSPACED-ZH_HANS.OTF")
	
	# 按分类组织装备
	var categories = [
		{"type": EquipmentCategory.UNIVERSAL, "key": "category_universal"},
		{"type": EquipmentCategory.CLASSIC, "key": "category_classic"},
		{"type": EquipmentCategory.SONG, "key": "category_song"},
		{"type": EquipmentCategory.ROGUELIKE, "key": "category_roguelike"}
	]
	
	for cat in categories:
		var category_items = []
		for i in range(equipment_data.size()):
			if equipment_data[i].category == cat.type:
				category_items.append({"index": i, "data": equipment_data[i]})
		
		# 添加分类标题
		var cat_label = Label.new()
		cat_label.text = texts[cat.key]
		cat_label.add_theme_font_override("font", font)
		cat_label.add_theme_font_size_override("font_size", 16)
		cat_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.9, 1))
		equipment_list.add_child(cat_label)
		
		if category_items.is_empty():
			# 无装备提示
			var empty_label = Label.new()
			empty_label.text = "  -"
			empty_label.add_theme_font_override("font", font)
			empty_label.add_theme_font_size_override("font_size", 14)
			empty_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5, 1))
			equipment_list.add_child(empty_label)
		else:
			for item in category_items:
				var equip = item.data
				var button = Button.new()
				var equip_name = texts.get(equip.id, equip.id)
				
				# 显示装备状态（文字居中）
				if equip.equipped:
					button.text = equip_name + " ✓"
				elif not equip.unlocked:
					button.text = equip_name + " 🔒"
				else:
					button.text = equip_name
				
				button.custom_minimum_size = Vector2(300, 40)
				button.alignment = HORIZONTAL_ALIGNMENT_CENTER  # 文字居中
				button.add_theme_font_override("font", font)
				button.add_theme_font_size_override("font_size", 16)
				
				# 根据状态设置颜色
				if equip.equipped:
					button.add_theme_color_override("font_color", Color(0.5, 1, 0.5, 1))
				elif not equip.unlocked:
					button.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5, 1))
				else:
					button.add_theme_color_override("font_color", Color(1, 1, 1, 1))
				
				var equip_index = item.index
				button.pressed.connect(func(): _on_equipment_selected(equip_index))
				
				equipment_list.add_child(button)
				equipment_buttons.append(button)
				button_to_equip_index[button] = equip_index

func _on_equipment_selected(index: int):
	selected_equipment = index
	var texts = TEXTS[Global.current_language]
	var equip = equipment_data[index]
	
	detail_name.text = texts.get(equip.id, equip.id)
	detail_desc.text = texts.get(equip.id + "_desc", "")
	
	# 更新状态标签
	if equip.equipped:
		detail_status.text = texts["equipped"]
		detail_status.add_theme_color_override("font_color", Color(0.5, 1, 0.5, 1))
		equip_button.text = texts["unequip"]
		equip_button.disabled = false
	elif not equip.unlocked:
		detail_status.text = texts["locked"]
		detail_status.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5, 1))
		equip_button.text = texts["equip"]
		equip_button.disabled = true
	elif equip.category == EquipmentCategory.ROGUELIKE:
		detail_status.text = texts["roguelike_only"]
		detail_status.add_theme_color_override("font_color", Color(0.6, 0.7, 1, 1))
		equip_button.text = texts["equip"]
		equip_button.disabled = true
	else:
		detail_status.text = texts["slot_limit"]
		detail_status.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8, 1))
		equip_button.text = texts["equip"]
		equip_button.disabled = false
	
	# 更新气泡箭头位置
	_update_bubble_position(index)
	_show_bubble()

func _update_bubble_position(equip_index: int):
	# 根据装备索引找到对应按钮并更新气泡位置
	for btn in button_to_equip_index.keys():
		if button_to_equip_index[btn] == equip_index:
			var button_center_y = btn.global_position.y + btn.size.y / 2
			var bubble_global_y = bubble_container.global_position.y
			var arrow_local_y = button_center_y - bubble_global_y
			
			bubble_arrow.polygon = PackedVector2Array([
				Vector2(-20, arrow_local_y),
				Vector2(0, arrow_local_y - 15),
				Vector2(0, arrow_local_y + 15)
			])
			break

func _show_bubble():
	if not bubble_container.visible:
		bubble_container.visible = true
		bubble_container.modulate.a = 0.0
		bubble_container.scale = Vector2(0.9, 0.9)
		
		var bubble_tween = create_tween()
		bubble_tween.set_parallel(true)
		bubble_tween.tween_property(bubble_container, "modulate:a", 1.0, 0.2).set_ease(Tween.EASE_OUT)
		bubble_tween.tween_property(bubble_container, "scale", Vector2(1.0, 1.0), 0.2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

func _on_equip_pressed():
	if selected_equipment < 0:
		return
	
	var equip = equipment_data[selected_equipment]
	if not equip.unlocked:
		return
	if equip.category == EquipmentCategory.ROGUELIKE:
		return
	
	if equip.equipped:
		# 卸下装备
		equip.equipped = false
	else:
		# 装备前先卸下同分类的其他装备
		for other_equip in equipment_data:
			if other_equip.category == equip.category and other_equip.equipped:
				other_equip.equipped = false
		equip.equipped = true
	
	_save_equipment_state()
	GameConfig.apply_capacity_disk(Global.equipment_universal_capacity_disk)
	
	# 刷新界面
	populate_equipment_list()
	_on_equipment_selected(selected_equipment)

func _on_back_pressed():
	get_tree().change_scene_to_file("res://UI/MainMenu.tscn")
