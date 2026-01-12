extends Control
class_name MusicVisualizer

## 音乐可视化组件 - 柱状图频谱显示

# 可视化参数
const BAR_COUNT = 48  # 柱状图数量（增加让柱子更细）
const MIN_HEIGHT = 3.0  # 最小高度
const MAX_HEIGHT_RATIO = 0.35  # 最大高度比例（由0.8降低到仅占屏幕35%）
const SMOOTHING = 0.15  # 平滑系数（越小越平滑）
const FALL_SPEED = 200.0  # 下落速度

# 颜色配置（低饱和度彩色，降低透明度）
var bar_colors = [
	Color(0.7, 0.4, 0.4, 0.35),  # 淡红
	Color(0.7, 0.55, 0.4, 0.35),  # 淡橙
	Color(0.7, 0.7, 0.4, 0.35),  # 淡黄
	Color(0.5, 0.7, 0.4, 0.35),  # 淡绿
	Color(0.4, 0.7, 0.6, 0.35),  # 淡青
	Color(0.4, 0.55, 0.7, 0.35),  # 淡蓝
	Color(0.55, 0.4, 0.7, 0.35),  # 淡紫
	Color(0.7, 0.4, 0.6, 0.35),  # 淡粉
]

# 内部状态
var spectrum_analyzer: AudioEffectSpectrumAnalyzerInstance
var bar_heights: Array = []
var target_heights: Array = []
var audio_bus_index: int = -1

func _ready():
	print("[MusicVisualizer] _ready() 被调用")
	print("[MusicVisualizer] 当前size: ", size)
	
	# 初始化柱状图高度数组
	bar_heights.resize(BAR_COUNT)
	target_heights.resize(BAR_COUNT)
	for i in range(BAR_COUNT):
		bar_heights[i] = MIN_HEIGHT
		target_heights[i] = MIN_HEIGHT
	
	# 获取音频总线和频谱分析器
	_setup_spectrum_analyzer()
	
	# 打印音频总线信息
	print("[MusicVisualizer] 音频总线数量: ", AudioServer.get_bus_count())
	for i in range(AudioServer.get_bus_count()):
		print("  总线 ", i, ": ", AudioServer.get_bus_name(i))

func _setup_spectrum_analyzer():
	"""设置频谱分析器"""
	# 查找或创建Music总线上的频谱分析器
	audio_bus_index = AudioServer.get_bus_index("Music")
	if audio_bus_index < 0:
		audio_bus_index = AudioServer.get_bus_index("Master")
	
	if audio_bus_index < 0:
		print("[MusicVisualizer] 无法找到音频总线")
		return
	
	# 检查是否已有频谱分析器
	var effect_count = AudioServer.get_bus_effect_count(audio_bus_index)
	for i in range(effect_count):
		var effect = AudioServer.get_bus_effect(audio_bus_index, i)
		if effect is AudioEffectSpectrumAnalyzer:
			spectrum_analyzer = AudioServer.get_bus_effect_instance(audio_bus_index, i)
			print("[MusicVisualizer] 找到现有频谱分析器")
			return
	
	# 没有找到，创建新的
	var analyzer = AudioEffectSpectrumAnalyzer.new()
	analyzer.buffer_length = 0.1
	analyzer.fft_size = AudioEffectSpectrumAnalyzer.FFT_SIZE_1024
	AudioServer.add_bus_effect(audio_bus_index, analyzer)
	
	# 获取实例
	var new_effect_index = AudioServer.get_bus_effect_count(audio_bus_index) - 1
	spectrum_analyzer = AudioServer.get_bus_effect_instance(audio_bus_index, new_effect_index)
	print("[MusicVisualizer] 创建了新的频谱分析器")

func _process(delta):
	if spectrum_analyzer == null:
		_setup_spectrum_analyzer()
		return
	
	# 更新频谱数据
	_update_spectrum()
	
	# 平滑动画
	for i in range(BAR_COUNT):
		if bar_heights[i] < target_heights[i]:
			# 上升：快速响应
			bar_heights[i] = lerp(bar_heights[i], target_heights[i], SMOOTHING * 2)
		else:
			# 下降：缓慢下落
			bar_heights[i] = max(bar_heights[i] - FALL_SPEED * delta, target_heights[i])
		bar_heights[i] = max(bar_heights[i], MIN_HEIGHT)
	
	queue_redraw()

func _update_spectrum():
	"""更新频谱数据"""
	if spectrum_analyzer == null:
		return
	
	var max_height = size.y * MAX_HEIGHT_RATIO
	
	# 频率范围：20Hz - 20000Hz（对数分布）
	var min_freq = 20.0
	var max_freq = 16000.0
	
	for i in range(BAR_COUNT):
		# 对数频率分布
		var freq_low = min_freq * pow(max_freq / min_freq, float(i) / BAR_COUNT)
		var freq_high = min_freq * pow(max_freq / min_freq, float(i + 1) / BAR_COUNT)
		
		# 获取频率范围的幅度
		var magnitude = spectrum_analyzer.get_magnitude_for_frequency_range(freq_low, freq_high)
		var energy = (magnitude.x + magnitude.y) / 2.0
		
		# 转换为高度（使用对数缩放）
		var height = MIN_HEIGHT
		if energy > 0.0001:
			# 对数缩放，使小音量也能显示
			height = (60.0 + linear_to_db(energy)) / 60.0 * max_height
			height = clamp(height, MIN_HEIGHT, max_height)
		
		target_heights[i] = height

func _draw():
	"""绘制柱状图"""
	if bar_heights.is_empty():
		return
	
	# 检查size是否有效
	if size.x <= 0 or size.y <= 0:
		return
	
	var bar_width = size.x / BAR_COUNT
	var gap = 2.0  # 柱子之间的间隙
	
	for i in range(BAR_COUNT):
		var height = bar_heights[i]
		var x = i * bar_width + gap / 2
		var y = size.y - height
		var rect = Rect2(x, y, bar_width - gap, height)
		
		# 选择颜色（循环使用）
		var color = bar_colors[i % bar_colors.size()]
		
		# 根据高度稍微调整亮度
		var brightness = 0.7 + 0.3 * (height / (size.y * MAX_HEIGHT_RATIO))
		color = Color(color.r * brightness, color.g * brightness, color.b * brightness, color.a)
		
		draw_rect(rect, color)
		
		# 绘制顶部高亮
		var highlight_rect = Rect2(x, y, bar_width - gap, 3)
		var highlight_color = Color(color.r + 0.2, color.g + 0.2, color.b + 0.2, 0.8)
		draw_rect(highlight_rect, highlight_color)
