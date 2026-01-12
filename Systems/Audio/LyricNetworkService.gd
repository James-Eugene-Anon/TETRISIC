extends Node
class_name LyricNetworkService

## 网络歌词服务 - 从在线源获取歌词
## 
## 支持的歌词API:
## 1. QQ音乐歌词API
## 2. 网易云音乐歌词API
## 3. 酷狗音乐歌词API
##
## 使用方法:
## var service = LyricNetworkService.new()
## var result = await service.search_lyrics("歌曲名", "歌手名")
## if result.success:
##     var lyrics = result.lyrics  # LRC格式歌词

signal search_completed(result: Dictionary)
signal download_completed(result: Dictionary)
signal error_occurred(message: String)

# API配置
const API_SOURCES = {
	"netease": {
		"name": "网易云音乐",
		"search_url": "https://music.163.com/api/search/get/web",
		"lyric_url": "https://music.163.com/api/song/lyric",
		"enabled": true
	},
	"qq": {
		"name": "QQ音乐", 
		"search_url": "https://c.y.qq.com/soso/fcgi-bin/client_search_cp",
		"lyric_url": "https://c.y.qq.com/lyric/fcgi-bin/fcg_query_lyric_new.fcg",
		"enabled": true
	},
	"kugou": {
		"name": "酷狗音乐",
		"search_url": "https://mobilecdn.kugou.com/api/v3/search/song",
		"lyric_url": "https://krcs.kugou.com/search",
		"enabled": true
	}
}

# HTTP客户端
var http_request: HTTPRequest = null
var pending_callback: Callable
var current_source: String = ""

# 缓存
var lyric_cache: Dictionary = {}  # {song_id: lrc_content}

func _init():
	pass

func _ready():
	_ensure_http_request()

func _ensure_http_request():
	"""确保HTTPRequest节点存在"""
	if http_request == null:
		http_request = HTTPRequest.new()
		http_request.timeout = 10.0
		add_child(http_request)
		http_request.request_completed.connect(_on_request_completed)

func is_online_mode() -> bool:
	"""检查是否启用在线模式"""
	return Global.online_mode if Global.has_method("get") else false

# ============ 公共API ============

func search_lyrics(song_name: String, artist: String = "") -> Dictionary:
	"""搜索歌词
	参数:
		song_name: 歌曲名
		artist: 歌手名（可选）
	返回:
		{success: bool, lyrics: String, source: String, error: String}
	"""
	if not is_online_mode():
		return {"success": false, "error": "离线模式", "lyrics": ""}
	
	_ensure_http_request()
	
	# 依次尝试各个API源
	for source in API_SOURCES.keys():
		if not API_SOURCES[source].enabled:
			continue
		
		var result = await _search_from_source(source, song_name, artist)
		if result.success:
			return result
	
	return {"success": false, "error": "未找到歌词", "lyrics": ""}

func search_lyrics_async(song_name: String, artist: String = "") -> void:
	"""异步搜索歌词，通过信号返回结果"""
	var result = await search_lyrics(song_name, artist)
	search_completed.emit(result)

func download_lyric_by_id(source: String, song_id: String) -> Dictionary:
	"""根据歌曲ID下载歌词
	参数:
		source: API源名称 (netease/qq/kugou)
		song_id: 歌曲ID
	返回:
		{success: bool, lyrics: String, error: String}
	"""
	if not is_online_mode():
		return {"success": false, "error": "离线模式", "lyrics": ""}
	
	# 检查缓存
	var cache_key = source + "_" + song_id
	if lyric_cache.has(cache_key):
		return {"success": true, "lyrics": lyric_cache[cache_key], "source": source}
	
	_ensure_http_request()
	
	match source:
		"netease":
			return await _download_netease_lyric(song_id)
		"qq":
			return await _download_qq_lyric(song_id)
		"kugou":
			return await _download_kugou_lyric(song_id)
		_:
			return {"success": false, "error": "未知的API源", "lyrics": ""}

# ============ 内部实现 - 搜索 ============

func _search_from_source(source: String, song_name: String, artist: String) -> Dictionary:
	"""从指定源搜索歌曲"""
	match source:
		"netease":
			return await _search_netease(song_name, artist)
		"qq":
			return await _search_qq(song_name, artist)
		"kugou":
			return await _search_kugou(song_name, artist)
		_:
			return {"success": false, "error": "未知的API源"}

func _search_netease(song_name: String, artist: String) -> Dictionary:
	"""搜索网易云音乐"""
	var query = song_name
	if not artist.is_empty():
		query += " " + artist
	
	var url = "https://music.163.com/api/search/get/web?s=%s&type=1&limit=5" % query.uri_encode()
	
	var headers = [
		"User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
		"Referer: https://music.163.com"
	]
	
	var response = await _make_request(url, headers)
	if response.error:
		return {"success": false, "error": response.error}
	
	# 解析响应
	var json = JSON.new()
	if json.parse(response.body) != OK:
		return {"success": false, "error": "JSON解析失败"}
	
	var data = json.get_data()
	if not data.has("result") or not data.result.has("songs") or data.result.songs.is_empty():
		return {"success": false, "error": "未找到歌曲"}
	
	# 获取第一个匹配的歌曲ID
	var song_id = str(data.result.songs[0].id)
	
	# 下载歌词
	return await _download_netease_lyric(song_id)

func _search_qq(song_name: String, artist: String) -> Dictionary:
	"""搜索QQ音乐"""
	var query = song_name
	if not artist.is_empty():
		query += " " + artist
	
	var url = "https://c.y.qq.com/soso/fcgi-bin/client_search_cp?w=%s&format=json&p=1&n=5" % query.uri_encode()
	
	var headers = [
		"User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
		"Referer: https://y.qq.com"
	]
	
	var response = await _make_request(url, headers)
	if response.error:
		return {"success": false, "error": response.error}
	
	var json = JSON.new()
	if json.parse(response.body) != OK:
		return {"success": false, "error": "JSON解析失败"}
	
	var data = json.get_data()
	if not data.has("data") or not data.data.has("song") or not data.data.song.has("list"):
		return {"success": false, "error": "未找到歌曲"}
	
	if data.data.song.list.is_empty():
		return {"success": false, "error": "未找到歌曲"}
	
	var song_mid = data.data.song.list[0].songmid
	return await _download_qq_lyric(song_mid)

func _search_kugou(song_name: String, artist: String) -> Dictionary:
	"""搜索酷狗音乐"""
	var query = song_name
	if not artist.is_empty():
		query += " " + artist
	
	var url = "https://mobilecdn.kugou.com/api/v3/search/song?keyword=%s&page=1&pagesize=5" % query.uri_encode()
	
	var headers = [
		"User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"
	]
	
	var response = await _make_request(url, headers)
	if response.error:
		return {"success": false, "error": response.error}
	
	var json = JSON.new()
	if json.parse(response.body) != OK:
		return {"success": false, "error": "JSON解析失败"}
	
	var data = json.get_data()
	if not data.has("data") or not data.data.has("info") or data.data.info.is_empty():
		return {"success": false, "error": "未找到歌曲"}
	
	var hash_code = data.data.info[0].hash
	return await _download_kugou_lyric(hash_code)

# ============ 内部实现 - 下载歌词 ============

func _download_netease_lyric(song_id: String) -> Dictionary:
	"""下载网易云歌词"""
	var url = "https://music.163.com/api/song/lyric?id=%s&lv=1&tv=1" % song_id
	
	var headers = [
		"User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
		"Referer: https://music.163.com"
	]
	
	var response = await _make_request(url, headers)
	if response.error:
		return {"success": false, "error": response.error, "lyrics": ""}
	
	var json = JSON.new()
	if json.parse(response.body) != OK:
		return {"success": false, "error": "JSON解析失败", "lyrics": ""}
	
	var data = json.get_data()
	
	# 获取原文歌词和翻译歌词
	var lrc = data.get("lrc", {}).get("lyric", "")
	var tlyric = data.get("tlyric", {}).get("lyric", "")  # 翻译歌词
	
	if lrc.is_empty():
		return {"success": false, "error": "歌词为空", "lyrics": ""}
	
	# 合并原文和翻译歌词
	var merged_lrc = _merge_lyrics(lrc, tlyric)
	
	# 缓存
	lyric_cache["netease_" + song_id] = merged_lrc
	
	return {"success": true, "lyrics": merged_lrc, "source": "netease"}

func _download_qq_lyric(song_mid: String) -> Dictionary:
	"""下载QQ音乐歌词"""
	var url = "https://c.y.qq.com/lyric/fcgi-bin/fcg_query_lyric_new.fcg?songmid=%s&format=json&nobase64=1" % song_mid
	
	var headers = [
		"User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
		"Referer: https://y.qq.com"
	]
	
	var response = await _make_request(url, headers)
	if response.error:
		return {"success": false, "error": response.error, "lyrics": ""}
	
	var json = JSON.new()
	if json.parse(response.body) != OK:
		return {"success": false, "error": "JSON解析失败", "lyrics": ""}
	
	var data = json.get_data()
	var lyric = data.get("lyric", "")
	var trans = data.get("trans", "")  # 翻译歌词
	
	if lyric.is_empty():
		return {"success": false, "error": "歌词为空", "lyrics": ""}
	
	var merged_lrc = _merge_lyrics(lyric, trans)
	lyric_cache["qq_" + song_mid] = merged_lrc
	
	return {"success": true, "lyrics": merged_lrc, "source": "qq"}

func _download_kugou_lyric(hash_code: String) -> Dictionary:
	"""下载酷狗歌词"""
	# 酷狗歌词获取需要先搜索歌词ID
	var search_url = "https://krcs.kugou.com/search?keyword=&duration=&hash=%s&album_audio_id=" % hash_code
	
	var headers = [
		"User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"
	]
	
	var response = await _make_request(search_url, headers)
	if response.error:
		return {"success": false, "error": response.error, "lyrics": ""}
	
	var json = JSON.new()
	if json.parse(response.body) != OK:
		return {"success": false, "error": "JSON解析失败", "lyrics": ""}
	
	var data = json.get_data()
	if not data.has("candidates") or data.candidates.is_empty():
		return {"success": false, "error": "未找到歌词", "lyrics": ""}
	
	var candidate = data.candidates[0]
	var lyric_id = candidate.id
	var access_key = candidate.accesskey
	
	# 获取歌词内容
	var lyric_url = "https://lyrics.kugou.com/download?id=%s&accesskey=%s&fmt=lrc" % [lyric_id, access_key]
	
	response = await _make_request(lyric_url, headers)
	if response.error:
		return {"success": false, "error": response.error, "lyrics": ""}
	
	if json.parse(response.body) != OK:
		return {"success": false, "error": "JSON解析失败", "lyrics": ""}
	
	data = json.get_data()
	var content = data.get("content", "")
	
	if content.is_empty():
		return {"success": false, "error": "歌词为空", "lyrics": ""}
	
	# 酷狗歌词是Base64编码的
	var lrc = Marshalls.base64_to_utf8(content)
	lyric_cache["kugou_" + hash_code] = lrc
	
	return {"success": true, "lyrics": lrc, "source": "kugou"}

# ============ 辅助函数 ============

func _make_request(url: String, headers: Array = []) -> Dictionary:
	"""发起HTTP请求"""
	var packed_headers = PackedStringArray(headers)
	var error = http_request.request(url, packed_headers)
	
	if error != OK:
		return {"error": "请求失败: " + str(error), "body": ""}
	
	# 等待请求完成
	var result = await http_request.request_completed
	
	var response_code = result[1]
	var response_body = result[3].get_string_from_utf8()
	
	if response_code != 200:
		return {"error": "HTTP错误: " + str(response_code), "body": ""}
	
	return {"error": "", "body": response_body}

func _on_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray):
	"""HTTP请求完成回调"""
	pass  # 使用await方式处理，此回调暂不使用

func _merge_lyrics(original: String, translation: String) -> String:
	"""合并原文歌词和翻译歌词
	格式：原文部分 + 空行 + [by:...] + 翻译部分"""
	# 清理原文和翻译
	var clean_original = _clean_lyrics(original)
	
	if translation.is_empty():
		return clean_original
	
	var clean_translation = _clean_lyrics(translation)
	
	# 组合格式：原文 + 空行 + 翻译标记 + 翻译
	var merged = clean_original + "\n\n[by:Online Lyrics Service]\n" + clean_translation
	return merged

func _clean_lyrics(lrc: String) -> String:
	"""清理歌词中的元数据标签"""
	var lines = lrc.split("\n")
	var clean_lines = []
	var metadata_tags = ["[ti:", "[ar:", "[al:", "[by:", "[offset:", "[kana:", "[romaji:", "[re:", "[ve:", "[length:"]
	
	for line in lines:
		var trimmed_line = line.strip_edges()
		
		# 跳过空行
		if trimmed_line.is_empty():
			continue
		
		# 检查是否是元数据标签
		var is_metadata = false
		for tag in metadata_tags:
			if trimmed_line.begins_with(tag):
				is_metadata = true
				break
		
		if not is_metadata:
			clean_lines.append(line)
	
	return "\n".join(clean_lines)

func _normalize_time_str(time_str: String) -> String:
	"""归一化时间戳字符串，统一为两位小数"""
	var parts = time_str.split(".")
	if parts.size() >= 2:
		var main_part = parts[0]
		var decimal_part = parts[1]
		if decimal_part.length() > 2:
			decimal_part = decimal_part.substr(0, 2)
		elif decimal_part.length() == 1:
			decimal_part = decimal_part + "0"
		return main_part + "." + decimal_part
	return time_str

func clear_cache():
	"""清除歌词缓存"""
	lyric_cache.clear()

func get_available_sources() -> Array:
	"""获取可用的API源列表"""
	var sources = []
	for key in API_SOURCES.keys():
		if API_SOURCES[key].enabled:
			sources.append({"id": key, "name": API_SOURCES[key].name})
	return sources
