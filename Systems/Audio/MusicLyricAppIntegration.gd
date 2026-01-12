extends Node
class_name MusicLyricAppIntegration

## 网易云音乐歌词下载工具集成
## 使用第三方工具 163MusicLyrics (Apache-2.0 License)
## https://github.com/jitwxs/163MusicLyrics

signal search_completed(result: Dictionary)

var app_path: String = ""
var temp_dir: String = ""

func _init():
	# 设置临时目录（使用游戏目录下的temp子目录）
	temp_dir = ProjectSettings.globalize_path("user://temp_lyrics/")
	DirAccess.make_dir_recursive_absolute(temp_dir)

func set_app_path(path: String):
	"""设置 MusicLyricApp 可执行文件路径"""
	app_path = path

func search_and_download_lyrics(song_name: String, artist: String = "") -> Dictionary:
	"""搜索并下载歌词
	
	参数:
		song_name: 歌曲名
		artist: 艺术家名（可选，用于更精确的搜索）
	
	返回:
		{success: bool, lyrics: String, source: String, error: String}
	"""
	if not Global.online_mode:
		return {"success": false, "error": "离线模式", "lyrics": ""}
	
	if app_path.is_empty() or not FileAccess.file_exists(app_path):
		return {"success": false, "error": "未配置 MusicLyricApp 路径", "lyrics": ""}
	
	# 构建搜索关键词
	var keyword = song_name
	if not artist.is_empty() and artist != "Unknown Artist":
		keyword = artist + " " + song_name
	
	# 生成临时输出文件路径
	var temp_file = temp_dir + "temp_" + str(Time.get_ticks_msec()) + ".lrc"
	
	# 使用 Python 包装器（转换 res:// 路径为实际文件系统路径）
	var wrapper_path = ProjectSettings.globalize_path("res://Systems/Audio/music_lyric_wrapper.py")
	var python_cmd = "python"  # 或者 "python3"
	
	# 构建命令参数
	var args = [
		wrapper_path,
		"--app", app_path,
		"--keyword", keyword,
		"--output", temp_file
	]
	
	print("[歌词下载] 执行命令: ", python_cmd, " ", args)
	
	# 执行命令
	var output = []
	var exit_code = OS.execute(python_cmd, args, output, true, false)
	
	print("[歌词下载] 退出码: ", exit_code)
	if not output.is_empty():
		print("[歌词下载] 输出: ", output)
	
	# 检查是否成功
	if exit_code != 0:
		return {"success": false, "error": "歌词下载失败，退出码: " + str(exit_code), "lyrics": ""}
	
	# 等待文件生成
	await get_tree().create_timer(0.5).timeout
	
	# 读取结果文件
	if not FileAccess.file_exists(temp_file):
		return {"success": false, "error": "未生成歌词文件", "lyrics": ""}
	
	var lyric_file = FileAccess.open(temp_file, FileAccess.READ)
	if not lyric_file:
		return {"success": false, "error": "无法读取歌词文件", "lyrics": ""}
	
	var lyrics = lyric_file.get_as_text()
	lyric_file.close()
	
	# 清理临时文件
	DirAccess.remove_absolute(temp_file)
	
	if lyrics.is_empty():
		return {"success": false, "error": "歌词内容为空", "lyrics": ""}
	
	return {"success": true, "lyrics": lyrics, "source": "163MusicLyrics"}

func is_available() -> bool:
	"""检查工具是否可用"""
	return not app_path.is_empty() and FileAccess.file_exists(app_path)

func clear_temp():
	"""清理临时文件"""
	var dir = DirAccess.open(temp_dir)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir():
				DirAccess.remove_absolute(temp_dir + file_name)
			file_name = dir.get_next()
		dir.list_dir_end()
