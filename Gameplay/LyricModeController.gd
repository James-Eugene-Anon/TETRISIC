extends BaseGameModeController
class_name LyricModeController

## 歌词俄罗斯方块模式控制器

signal lyric_changed(japanese: String, chinese: String)
signal all_blocks_placed  # 所有歌词方块已落完
signal beat_rating_changed(rating: int, text: String, color: Color, combo: int)  # 节拍评价信号

var python_bridge: LyricPythonBridge
var lyrics: Array = []  # LyricLine数组
var current_lyric_index: int = 0
var lyric_blocks: Array = []  # 歌词字符数组
var current_lyric_char_index: int = 0
var next_piece_index: int = 0
var music_time: float = 0.0
var current_chinese_lyric: String = ""
var first_lyric_time: float = 0.0  # 第一句歌词的时间
var fall_delay: float = 0.0  # 方块开始下落的延迟时间
var can_fall: bool = false  # 方块是否可以下落
var blocks_complete_emitted: bool = false  # 是否已发送方块落完信号
var is_last_block: bool = false  # 当前方块是否是最后一个
var interlude_fall_delay: float = 0.0  # 间奏结束后方块开始下落的时间
var interlude_waiting: bool = false  # 是否在间奏等待中（新方块不进入游戏区域）
var lyric_line_ranges: Array = []  # 每行歌词的字符索引范围 [{start, content_end, full_end, time}]
var line_starts: Array = []  # 每行歌词在lyric_blocks中的起始索引
var last_completed_line_idx: int = -1  # 上一个完成的歌词行索引（用于间奏检测）
var is_chinese_song: bool = false  # 是否是中文歌曲
var last_line_last_piece_lock_time := {}  # 每行最后一个方块锁定时间

# 节拍校对器相关
var current_piece_target_time: float = 0.0  # 当前方块对应的目标落地时间
var last_beat_rating: int = -1  # 上一次节拍评价
var beat_timing_offset: float = 0.0  # 滚动时间偏移量：跟踪玩家实际节奏与目标节奏的累积偏差
var piece_spawn_music_time: float = 0.0  # 当前方块生成时的音乐时间

const INTERLUDE_BUFFER_TIME: float = 5.8  # 间奏缓冲时间（秒）

func _init():
	super._init()
	python_bridge = LyricPythonBridge.new()

func initialize():
	super.initialize()
	current_lyric_index = 0
	current_lyric_char_index = 0
	next_piece_index = 0
	music_time = 0.0
	current_chinese_lyric = "准备开始..."
	can_fall = false
	blocks_complete_emitted = false
	is_last_block = false
	interlude_fall_delay = 0.0
	interlude_waiting = false
	# 注意：lyric_line_ranges和line_starts是歌曲级数据，由load_song()构建
	# 不在initialize()中清空，否则start_song()调用initialize()后会丢失所有范围数据
	last_completed_line_idx = -1
	blocks_complete_time = -1.0
	music_complete_time = -1.0
	is_chinese_song = false
	current_piece_target_time = 0.0
	last_beat_rating = -1
	beat_timing_offset = 0.0
	piece_spawn_music_time = 0.0
	last_line_last_piece_lock_time.clear()
	equipment_system.reset_beat_calibrator()

func load_song(song_data: Dictionary):
	# 加载歌曲和歌词
	# 使用Python桥接器加载歌词文件
	var lyric_path = song_data.get("lyric_file", "")
	var result = python_bridge.parse_lrc_file(lyric_path)
	
	# 转换为LyricLine数组
	lyrics.clear()
	for lyric_data in result.get("lyrics", []):
		var lyric_line = LyricsParser.LyricLine.new(
			lyric_data.get("time", 0.0),
			lyric_data.get("japanese", ""),
			lyric_data.get("chinese", "")
		)
		lyrics.append(lyric_line)
	
	# 获取lyric_blocks并同步到桥接器缓存
	lyric_blocks = result.get("lyric_blocks", [])
	python_bridge.cached_lyric_blocks = lyric_blocks
	
	# 获取每行歌词的起始索引
	line_starts = result.get("line_starts", [])
	
	# 检测是否是中文歌曲
	is_chinese_song = result.get("is_chinese_song", false)
	print("[歌曲加载] 是中文歌曲: ", is_chinese_song)
	
	# 计算第一句歌词时间和下落延迟
	if lyrics.size() > 0:
		first_lyric_time = lyrics[0].time
		if first_lyric_time >= 12.0:
			# 如果第一句歌词在12秒之后，方块在前12秒开始下落
			fall_delay = first_lyric_time - 12.0
			print("第一句歌词时间: ", first_lyric_time, "s, 方块将在 ", fall_delay, "s 开始下落")
		else:
			# 如果小于12秒，开局立即下落
			fall_delay = 0.0
			print("第一句歌词时间: ", first_lyric_time, "s, 方块开局立即下落")
	else:
		fall_delay = 0.0
	
	print("加载了 ", lyrics.size(), " 行歌词")
	print("总歌词字符数: ", lyric_blocks.size())
	
	# 构建每行歌词的字符索引范围
	_build_lyric_line_ranges()

func start_song():
	# 开始歌曲
	initialize()
	
	if fall_delay <= 0.0:
		# 没有延迟，立即生成方块
		spawn_piece()
		can_fall = true
	else:
		# 有延迟，只生成预览，不生成current_piece
		var piece_info = python_bridge.get_next_piece_info(current_lyric_char_index)
		if piece_info.get("size", 0) > 0:
			next_piece_data = {
				"shape": piece_info.get("shape", ""),
				"chars": piece_info.get("chars", [])
			}
			next_piece_index = piece_info.get("new_index", current_lyric_char_index)
			print("[延迟模式] 预览方块: ", next_piece_data.get("shape"), " - 字符: ", next_piece_data.get("chars"))
		else:
			next_piece_data = {}
		current_piece = null
		can_fall = false

func update(delta: float):
	# 更新游戏逻辑
	# 更新音乐时间和歌词（暂停或游戏结束时不更新）
	if not paused and not game_over:
		music_time += delta
		update_lyrics()
		
		# 检查开局12秒延迟
		if not can_fall and music_time >= fall_delay:
			can_fall = true
			# 如果当前没有方块，生成一个
			if current_piece == null:
				spawn_piece()
			print("在 ", music_time, "s 方块开始下落（开局延迟结束）")
		
		# 检查间奏等待结束
		if interlude_waiting and music_time >= interlude_fall_delay:
			interlude_waiting = false
			interlude_fall_delay = 0.0
			beat_timing_offset = 0.0  # 间奏结束时重置偏移量，重新同步绝对节拍
			# 间奏结束，生成新方块进入游戏区域
			if current_piece == null:
				spawn_piece()
			print("在 ", music_time, "s 间奏结束，新方块进入游戏区域")
	
	# 只有当can_fall为true时才调用父类的update（处理下落）
	if can_fall:
		super.update(delta)

func update_lyrics():
	# 更新中文歌词显示 - 支持快语速歌词（同一帧处理多行）
	# 循环处理所有已到时间的歌词行，避免快语速时丢失歌词
	while current_lyric_index < lyrics.size():
		var current_lyric = lyrics[current_lyric_index]
		
		# 检查是否到达新歌词的时间
		if music_time < current_lyric.time:
			break  # 还没到这行歌词的时间，停止处理
		
		# 更新中文歌词显示
		if not current_lyric.chinese.is_empty():
			# 移除开头的斜杠和空格
			var chinese_text = current_lyric.chinese
			while chinese_text.begins_with("/") or chinese_text.begins_with(" "):
				chinese_text = chinese_text.substr(1)
			current_chinese_lyric = chinese_text.strip_edges()
		else:
			current_chinese_lyric = current_lyric.japanese
		
		lyric_changed.emit(current_lyric.japanese, current_chinese_lyric)
		
		print("=== 新歌词 [", current_lyric_index, "] ===")
		print("时间: ", current_lyric.time, "s")
		print("日文: ", current_lyric.japanese)
		print("中文: ", current_lyric.chinese)
		
		current_lyric_index += 1

func spawn_piece():
	# 生成歌词方块
	# 如果在间奏等待中，不生成新方块到游戏区域
	if interlude_waiting:
		print("[间奏等待] 不生成新方块，等待间奏结束")
		return
	
	# 第一次调用：使用缓存的next_piece_data
	if next_piece_data.has("shape") and not next_piece_data.get("shape", "").is_empty():
		var shape = next_piece_data.get("shape", "")
		var chars = next_piece_data.get("chars", [])
		# 重要：直接使用缓存的next_piece_index
		current_lyric_char_index = next_piece_index
		
		var start_pos = Vector2i(GameConfig.GRID_WIDTH / 2 - 2, 0)
		current_piece = TetrisPiece.new(shape, start_pos, chars)
		
		# 设置节拍校对器的目标时间
		_set_piece_target_time()
		piece_spawn_music_time = music_time
		
		print("[spawn] 使用预览方块: ", shape, " - 字符: ", chars, " 索引:", current_lyric_char_index, " 时间:", snapped(music_time, 0.01))
	else:
		# 没有预览方块，生成新方块
		var piece_info = python_bridge.get_next_piece_info(current_lyric_char_index)
		if piece_info.get("size", 0) == 0:
			# 没有更多方块了，当前是最后一个
			current_piece = null
			next_piece_data = {}
			is_last_block = true
			print("[spawn] 所有歌词方块已落完")
			# 方块全部落完，触发完成信号
			check_blocks_complete()
			return
		
		var shape = piece_info.get("shape", "")
		var chars = piece_info.get("chars", [])
		current_lyric_char_index = piece_info.get("new_index", current_lyric_char_index)
		
		var start_pos = Vector2i(GameConfig.GRID_WIDTH / 2 - 2, 0)
		current_piece = TetrisPiece.new(shape, start_pos, chars)
		
		# 设置节拍校对器的目标时间
		_set_piece_target_time()
		piece_spawn_music_time = music_time
		
		print("[spawn] 生成新方块: ", shape, " - 字符: ", chars, " 时间:", snapped(music_time, 0.01))
	
	# 生成下一个预览方块
	_generate_next_preview()
	
	# 检查游戏是否结束
	check_game_over()

func _generate_next_preview():
	# 生成下一个预览方块
	var next_info = python_bridge.get_next_piece_info(current_lyric_char_index)
	if next_info.get("size", 0) > 0:
		next_piece_data = {
			"shape": next_info.get("shape", ""),
			"chars": next_info.get("chars", [])
		}
		next_piece_index = next_info.get("new_index", current_lyric_char_index)
		is_last_block = false
		print("[spawn] 预览下一个: ", next_piece_data.get("shape"), " - 字符: ", next_piece_data.get("chars"), " 索引:", next_piece_index)
	else:
		next_piece_data = {}
		is_last_block = true
		print("[spawn] 没有更多预览方块，当前方块是最后一个")

func _set_piece_target_time():
	# 设置当前方块对应的目标落地时间（节拍校对器核心）
	# 修复：完全基于LRC锚点的绝对时间计算
	#   - 行首方块：直接使用LRC时间戳（精确锚点）
	#   - 行内方块：行首时间 + 进度 × 行持续时间（纯线性插值）
	#   - 不再混合music_time，避免累积漂移
	current_piece_target_time = 0.0
	
	for i in range(lyric_line_ranges.size()):
		var range_info = lyric_line_ranges[i]
		if current_lyric_char_index >= range_info.start and current_lyric_char_index < range_info.full_end:
			var line_start_time = range_info.time
			
			# 计算行持续时间（到下一行的间隔）
			var line_duration: float
			if i + 1 < lyric_line_ranges.size():
				line_duration = lyric_line_ranges[i + 1].time - line_start_time
			else:
				line_duration = 4.0
			line_duration = clamp(line_duration, 1.0, 10.0)
			
			var line_length = range_info.end - range_info.start
			var pos_in_line = min(current_lyric_char_index - range_info.start, line_length)
			
			if line_length > 0:
				var progress = float(pos_in_line) / float(line_length)
				# 纯LRC锚点线性插值，不混合music_time
				current_piece_target_time = line_start_time + (progress * line_duration)
			else:
				current_piece_target_time = line_start_time
			
			print("[节拍校对器] 方块#", current_lyric_char_index, " 目标时间:", snapped(current_piece_target_time, 0.01), "s (行", i, ":", snapped(line_start_time, 0.01), "-", snapped(line_start_time + line_duration, 0.01), "s pos:", pos_in_line, "/", line_length, ")")
			break

func _build_lyric_line_ranges():
	# 根据line_starts构建每行歌词的字符索引范围
	# line_starts由解析器提供，记录每行歌词在lyric_blocks中的起始索引
	lyric_line_ranges.clear()
	
	print("[_build_lyric_line_ranges] lyric_blocks.size=", lyric_blocks.size(), " lyrics.size=", lyrics.size(), " line_starts.size=", line_starts.size())
	
	if line_starts.size() != lyrics.size():
		push_warning("[_build_lyric_line_ranges] line_starts与lyrics数量不匹配！")
		return
	
	for i in range(lyrics.size()):
		var start = line_starts[i]
		# full_end = 下一行的起始（包含当前行的尾部\n）
		var full_end = lyric_blocks.size() if i + 1 >= line_starts.size() else line_starts[i + 1]
		# content_end = 当前行实际内容的结束位置（去掉尾部\n）
		var content_end = full_end
		while content_end > start and lyric_blocks[content_end - 1] == "\n":
			content_end -= 1
		
		lyric_line_ranges.append({
			"start": start,
			"end": content_end,       # 实际内容结束（不含\n）
			"full_end": full_end,      # 下一行起始（含\n）
			"time": lyrics[i].time
		})
	
	print("[歌词行范围] 共 ", lyric_line_ranges.size(), " 行")
	if lyric_line_ranges.size() > 0:
		var r0 = lyric_line_ranges[0]
		print("  第一行: ", r0.time, "s, 索引 ", r0.start, "-", r0.end, " (full_end:", r0.full_end, ")")
	if lyric_line_ranges.size() > 1:
		var r1 = lyric_line_ranges[1]
		print("  第二行: ", r1.time, "s, 索引 ", r1.start, "-", r1.end, " (full_end:", r1.full_end, ")")

func get_piece_color() -> Color:
	# 歌词模式使用形状对应的颜色
	if current_piece and GameConfig.COLORS.has(current_piece.shape_name):
		return GameConfig.COLORS[current_piece.shape_name]
	return Color.WHITE

func get_next_piece_color() -> Color:
	# 获取下一个方块的颜色
	var shape = next_piece_data.get("shape", "")
	if not shape.is_empty() and GameConfig.COLORS.has(shape):
		return GameConfig.COLORS[shape]
	return Color.WHITE

func get_line_score_table() -> Array:
	# 歌词模式使用完整得分表（可能消除5-7行）
	return GameConfig.LINE_SCORES_FULL

func is_song_complete() -> bool:
	# 检查歌曲是否完成（方块全部落完）
	# 当前没有方块 且 没有下一个预览方块
	var no_current = current_piece == null
	var no_next = next_piece_data.is_empty() or next_piece_data.get("shape", "").is_empty()
	
	print("[is_song_complete] no_current=", no_current, " no_next=", no_next, " is_last_block=", is_last_block)
	
	return no_current and no_next

func check_blocks_complete():
	# 检查并发送方块落完信号
	if blocks_complete_emitted:
		return
	
	if is_song_complete():
		blocks_complete_emitted = true
		print("[LyricMode] 所有歌词方块已落完! 发送all_blocks_placed信号")
		all_blocks_placed.emit()

var blocks_complete_time: float = -1.0  # 方块落完的时间
var music_complete_time: float = -1.0  # 音乐结束的时间
var last_lyric_time: float = -1.0  # 最后一句歌词的时间
var song_duration: float = -1.0  # 歌曲总时长

func get_last_lyric_time() -> float:
	# 获取最后一句歌词的时间
	if lyrics.size() > 0:
		return lyrics[lyrics.size() - 1].time
	return 0.0

func calculate_completion_bonus() -> int:
	# 计算完成奖励分数
	# 规则：
	# - a = |最后一个方块落下时间 - 最后一句歌词时间|
	# - b = min(歌曲长度 - 最后一句歌词时间, 8秒)
	# - 如果 a <= b，+233分
	# - 如果 a > b，每超出0.1秒扣4分
	if blocks_complete_time < 0.0:
		return 0
	
	# 获取最后一句歌词时间
	last_lyric_time = get_last_lyric_time()
	
	# 计算 a = |方块落完时间 - 最后一句歌词时间|
	var a = abs(blocks_complete_time - last_lyric_time)
	
	# 计算 b = min(歌曲长度 - 最后一句歌词时间, 8秒)
	var time_after_last_lyric = song_duration - last_lyric_time
	var b = min(time_after_last_lyric, 8.0)
	if b < 0:
		b = 0
	
	print("[LyricMode] 完成奖励计算:")
	print("  - 方块落完时间: %.2fs" % blocks_complete_time)
	print("  - 最后歌词时间: %.2fs" % last_lyric_time)
	print("  - 歌曲总时长: %.2fs" % song_duration)
	print("  - a (时间差): %.2fs" % a)
	print("  - b (容差): %.2fs" % b)
	
	if a <= b:
		# 在容差范围内，奖励233分
		print("  - 结果: 在容差范围内，+233分!")
		return 233
	else:
		# 超过容差，每0.1秒扣4分
		var excess_time = a - b
		var penalty = int(excess_time * 10) * 4  # 每0.1秒扣4分
		var bonus = 233 - penalty
		print("  - 结果: 超出%.2fs，扣%d分，最终奖励: %d" % [excess_time, penalty, bonus])
		return bonus  # 可以是负数

func add_early_completion_bonus():
	# 方块落完时记录时间（旧接口保留兼容）
	blocks_complete_time = music_time
	print("[LyricMode] 方块落完时间: %.2fs" % blocks_complete_time)

func set_music_complete_time(time: float):
	# 音乐结束时记录时间
	music_complete_time = time
	print("[LyricMode] 音乐结束时间: %.2fs" % music_complete_time)

func apply_completion_bonus():
	# 应用完成奖励分数
	var bonus = calculate_completion_bonus()
	if bonus != 0:
		score += bonus
		print("[LyricMode] 应用完成奖励: %+d 分" % bonus)
	
	# 心之旋律：最终得分×0.85
	var final_mult = equipment_system.get_final_score_multiplier()
	if final_mult < 1.0:
		var old_score = score
		score = int(score * final_mult)
		print("[心之旋律] 最终得分×%.2f: %d → %d" % [final_mult, old_score, score])
	
	score_changed.emit(score)

func lock_piece():
	# 重写lock_piece以检测歌曲完成和节拍评价
	var hearts_melody_active = equipment_system.is_hearts_melody_active()
	print("[LyricMode.lock_piece] 被调用, 节拍同步模式已启用, 心之旋律:", hearts_melody_active, " 目标时间:", current_piece_target_time)
	print("[lock_piece] 方块锁定时间: ", snapped(music_time, 0.01), "s")
	
	# 歌曲模式核心功能：节拍同步评价（心之旋律装备时跳过）
	if not hearts_melody_active and current_piece_target_time > 0:
		# 使用滚动偏移量补偿累积延迟：
		# beat_timing_offset 跟踪玩家实际节奏与目标节奏的偏差
		# 将目标时间+偏移量作为评判基准，使评价更宽容
		var adjusted_target = current_piece_target_time + beat_timing_offset
		var time_diff = abs(music_time - adjusted_target)
		var rating = equipment_system.get_beat_rating(adjusted_target, music_time)
		
		# 平滑更新偏移量：使用极低的lerp因子(0.08)缓慢跟踪玩家节奏
		# 严格限制偏移范围在±0.8秒内，防止漂移失控
		var raw_offset = music_time - current_piece_target_time
		beat_timing_offset = snappedf(lerp(beat_timing_offset, raw_offset, 0.08), 0.001)
		beat_timing_offset = clamp(beat_timing_offset, -0.8, 0.8)
		
		equipment_system.update_beat_combo(rating)
		last_beat_rating = rating
		
		var rating_text = equipment_system.get_beat_rating_text(rating)
		var rating_color = equipment_system.get_beat_rating_color(rating)
		var beat_combo = equipment_system.get_beat_combo()
		
		beat_rating_changed.emit(rating, rating_text, rating_color, beat_combo)
		print("[节拍同步] ", rating_text, " (差", snapped(time_diff, 0.01), "s, 偏移:", snapped(beat_timing_offset, 0.01), "s) 连击:", beat_combo)
	else:
		# 没有目标时间时，不进行评价
		print("[节拍同步] 无目标时间，跳过评价")
	
	# 调用带节拍倍率的方块锁定
	_lock_piece_with_beat_multiplier()
	
	# 如果这是最后一个方块且已落完，触发完成
	if is_last_block and current_piece == null:
		print("[lock_piece] 最后一个方块已落完")
		check_blocks_complete()

func _lock_piece_with_beat_multiplier():
	# 带节拍倍率的方块锁定
	if current_piece == null:
		return
	
	var color = get_piece_color()
	current_piece.place_on_grid(grid_manager, color)
	
	# 重置特殊方块状态
	is_special_block = false
	special_block_type = -1
	
	# 清除完整的行
	var lines_cleared = grid_manager.clear_lines()
	if lines_cleared > 0:
		lines_cleared_total += lines_cleared
		var score_table = get_line_score_table()
		var max_index = score_table.size() - 1
		var base_score = score_table[min(lines_cleared, max_index)]
		
		# 应用节拍评价倍率（歌曲模式核心功能，心之旋律装备时跳过）
		if last_beat_rating >= 0 and not equipment_system.is_hearts_melody_active():
			var beat_multiplier = equipment_system.get_beat_score_multiplier(last_beat_rating)
			base_score = int(base_score * beat_multiplier)
			print("[节拍同步] 分数倍率:", beat_multiplier, " 调整后分数:", base_score)
		
		# 连击机制
		combo += 1
		var combo_bonus = 0
		if combo > 1:
			combo_bonus = base_score * 10 * (combo - 1)
		
		# 应用非连击得分倍率
		var score_multiplier = equipment_system.get_score_multiplier(combo > 1)
		var final_base_score = int(base_score * score_multiplier)
		
		var old_score = score
		score += final_base_score + combo_bonus
		on_score_updated(score, old_score, final_base_score)
		score_changed.emit(score)
		lines_changed.emit(lines_cleared_total)
		combo_changed.emit(combo)
	else:
		if combo > 0:
			combo = 0
			combo_changed.emit(combo)
	
	# 行结束与间奏检测（在生成新方块前进行）
	if _check_interlude_after_lock():
		# 进入间奏等待，清空当前方块
		current_piece = null
		return

	# 生成新方块
	spawn_piece()

func _check_interlude_after_lock() -> bool:
	# 在锁定方块后检查是否需要进入间奏等待
	if current_piece == null:
		return false

	var piece_size = current_piece.chars.size()
	var end_index = current_lyric_char_index
	if end_index <= 0:
		return false

	var line_idx = _get_line_index_by_char_index(max(end_index - 1, 0))
	if line_idx < 0:
		return false
	var range_info = lyric_line_ranges[line_idx]
	# 判断当前方块是否是该行最后一个方块
	# 使用content_end（不含尾部\n）：方块生成器的new_index会停在尾部\n处
	var is_last_piece_of_line = (end_index >= range_info.end)
	if not is_last_piece_of_line:
		return false

	# 记录该行最后方块锁定时间
	last_line_last_piece_lock_time[line_idx] = music_time

	# 第一行歌词使用开局机制，不检测间奏
	if line_idx <= 0:
		return false

	# 检查下一行歌词时间，决定是否进入间奏
	var next_line_idx = line_idx + 1
	if next_line_idx >= lyric_line_ranges.size():
		return false

	last_completed_line_idx = line_idx
	return _check_interlude_pause(line_idx)

func _check_interlude_pause(completed_line_idx: int) -> bool:
	# 检查是否需要进入间奏等待（在一行歌词方块完成后调用）
	# 第一行歌词使用"开局12秒"机制，不检测间奏
	if completed_line_idx <= 0:
		return false
	
	# 检查下一行歌词的时间
	var next_line_idx = completed_line_idx + 1
	if next_line_idx >= lyric_line_ranges.size():
		# 没有更多歌词行了
		return false
	
	var completed_line_time = lyric_line_ranges[completed_line_idx].time
	var next_line_time = lyric_line_ranges[next_line_idx].time
	
	# 间奏判定：下一行时间与当前行时间差
	var gap = next_line_time - completed_line_time
	
	print("[间奏检测] 刚完成第", completed_line_idx, "行(", completed_line_time, "s)")
	print("           下一行歌词时间:", next_line_time, "s, 行间隔:", gap, "s")
	
	# 如果间奏超过6秒，进入间奏等待
	if gap > 6.0:
		var last_lock_time = last_line_last_piece_lock_time.get(completed_line_idx, music_time)
		var delay = gap - 3.0 + (completed_line_time - last_lock_time)
		# 延迟时间限制：0~127秒
		delay = clamp(delay, 0.0, 127.0)
		interlude_waiting = true
		interlude_fall_delay = last_lock_time + delay
		print("[间奏等待] 进入间奏等待，新方块将在 ", interlude_fall_delay, "s 恢复下落 (延迟:", delay, "s)")
		return true
	return false

func _get_line_index_by_char_index(char_index: int) -> int:
	# 使用full_end匹配，确保行内\n位置也能正确匹配到对应行
	var line_idx = -1
	for i in range(lyric_line_ranges.size()):
		var range_info = lyric_line_ranges[i]
		if char_index >= range_info.start and char_index < range_info.full_end:
			line_idx = i
			break
	return line_idx
