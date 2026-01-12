# 测试歌词解析功能
extends Node

func _ready():
	test_lyrics_parser()

func test_lyrics_parser():
	print("=== 测试歌词解析 ===")
	
	var LyricsParser = load("res://Systems/Audio/LyricsParser.gd")
	var lyrics = LyricsParser.parse_lrc("res://musics/lyrics/Masked bitcH.lrc")
	
	print("总共解析了 ", lyrics.size(), " 行歌词")
	
	# 显示前5行
	for i in range(min(5, lyrics.size())):
		var lyric = lyrics[i]
		print("时间: ", lyric.time, "s")
		print("日语: ", lyric.japanese)
		print("中文: ", lyric.chinese)
		print("---")
	
	# 测试文本转方块
	var test_text = "ああもう"
	var blocks = LyricsParser.text_to_blocks(test_text)
	print("\n测试文本: ", test_text)
	print("方块数量: ", blocks.size())
	print("方块内容: ", blocks)
