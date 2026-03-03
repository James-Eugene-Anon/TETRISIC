import csv
import os
import re

# Mapping of Old Key -> New Key
key_mapping = {
    "UI_COMBAT_VICTORY_TITLE": "UI_TITLE_VICTORY",
    "UI_GAMEOVER_TITLE_VICTORY": "UI_TITLE_VICTORY",
    "UI_ROGUELIKECOMBAT_VICTORY": "UI_TITLE_VICTORY",
    
    "UI_COMBATHUD_SELECT": "UI_COMMON_SELECT",
    "UI_ROGUELIKECOMBAT_SELECT": "UI_COMMON_SELECT",
    
    "UI_SONGCOMPLETEMENU_SELECT_SONG": "UI_TITLE_SELECT_SONG",
    "UI_SONGCOMPLETE_SELECT_SONG": "UI_TITLE_SELECT_SONG",
    "UI_SONGSELECTION_TITLE": "UI_TITLE_SELECT_SONG",
    
    "UI_DIFFICULTYSELECTION_BACK": "UI_COMMON_BACK",
    "UI_DIFFICULTY_BACK": "UI_COMMON_BACK",
    "UI_SONGSELECTION_BACK": "UI_COMMON_BACK",
    "UI_OPTIONS_BACK": "UI_COMMON_BACK",
    
    "UI_DIFFICULTYSELECTION_START_GAME": "UI_COMMON_START_GAME",
    "UI_DIFFICULTY_START": "UI_COMMON_START_GAME",
    
    "UI_MAINMENU_OPTIONS": "UI_TITLE_OPTIONS",
    "UI_OPTIONSMENU_OPTIONS": "UI_TITLE_OPTIONS",
    "UI_OPTIONSMENU_TITLE": "UI_TITLE_OPTIONS",
    "UI_OPTIONS_TITLE": "UI_TITLE_OPTIONS",

    "UI_GAMEOVERMENU_MAIN_MENU": "UI_COMMON_MAIN_MENU",
    "UI_PAUSEMENU_MAIN_MENU": "UI_COMMON_MAIN_MENU",
    "UI_SONGCOMPLETE_MENU": "UI_COMMON_MAIN_MENU",
    
    "UI_GAMEOVERMENU_RESTART": "UI_COMMON_RESTART",
    "UI_SONGCOMPLETE_RESTART": "UI_COMMON_RESTART",

    "UI_SONGSELECTION_CONFIRM_DELETE": "UI_COMMON_CONFIRM_DELETE",
    "UI_SONGSELECTION_CONFIRM_DELETE_BTN": "UI_COMMON_CONFIRM_DELETE",
    "UI_SONGSELECTION_CONFIRM_DELETE_TITLE": "UI_COMMON_CONFIRM_DELETE",

    "UI_SONGSELECTION_SEARCH_LYRIC": "UI_COMMON_SEARCH_LYRIC",
    "UI_SONGSELECTION_SEARCH_ONLINE_LYRICS": "UI_COMMON_SEARCH_LYRIC",

    "UI_SONGSELECTION_REFRESH": "UI_COMMON_REFRESH_LIST",
    "UI_SONGSELECTION_REFRESH_SONG_LIST": "UI_COMMON_REFRESH_LIST",

    "UI_SONGSELECTION_IMPORT_LOCAL": "UI_COMMON_IMPORT_LOCAL",
    "UI_SONGSELECTION_IMPORT_LOCAL_SONG": "UI_COMMON_IMPORT_LOCAL",

    "UI_ROGUELIKEMAP_ENTER_NEXT_NODE_ESC_PAUSE": "UI_HINT_ENTER_NEXT_NODE_ESC_PAUSE",
    "UI_ROGUELIKEMAP_ENTER_NEXT_NODE_ESC_PAUSE_2": "UI_HINT_ENTER_NEXT_NODE_ESC_PAUSE",
    "UI_ROGUELIKEMAP_HINT": "UI_HINT_ENTER_NEXT_NODE_ESC_PAUSE",

    "UI_COMBATHUD_ATTACK": "UI_COMBATHUD_ATTACK_MODE",

    "UI_PAUSEMENU_GAME_PAUSED": "UI_TITLE_GAME_PAUSED",
    "UI_PAUSE_TITLE": "UI_TITLE_GAME_PAUSED",

    "UI_ROGUEDEFEATSCREEN_PRESS_ENTER_FOR_MENU": "UI_HINT_PRESS_ENTER_FOR_MENU",
    "UI_ROGUEDEFEAT_HINT": "UI_HINT_PRESS_ENTER_FOR_MENU",
    "UI_ROGUEVICTORY_HINT": "UI_HINT_PRESS_ENTER_FOR_MENU",

    "UI_ROGUERESTSCREEN_PRESS_ENTER_TO_REST": "UI_HINT_PRESS_ENTER_TO_REST",
    "UI_ROGUEREST_HINT": "UI_HINT_PRESS_ENTER_TO_REST",
    
    "UI_ROGUELIKEMAP_EQUIP_HINT_PREFIX": "UI_COMMON_KEY_E_BRACKET",
    # "UI_COMMON_KEY_E_BRACKET" doesn't exist yet, defining key value: "[E]"

    "UI_ROGUELIKEMAP_VIEW_EQUIPMENT": "UI_COMMON_VIEW_EQUIP",
    # "UI_ROGUELIKEMAP_E_VIEW_EQUIP" uses "[E] View Equip". "UI_ROGUELIKEMAP_VIEW_EQUIPMENT" is "View Equip". 
}

# New keys definitions (Key, EN, ZH)
new_keys_defs = {
    "UI_TITLE_VICTORY": ("Victory!", "战斗胜利！"),
    "UI_COMMON_SELECT": ("Select", "选择"),
    "UI_TITLE_SELECT_SONG": ("Select Song", "选择歌曲"),
    "UI_COMMON_BACK": ("Back", "返回"),
    "UI_COMMON_START_GAME": ("Start Game", "开始游戏"),
    "UI_TITLE_OPTIONS": ("Options", "选项设置"),
    "UI_COMMON_MAIN_MENU": ("Main Menu", "主菜单"),
    "UI_COMMON_RESTART": ("Restart", "重新开始"),
    "UI_COMMON_CONFIRM_DELETE": ("Confirm Delete", "确认删除"),
    "UI_COMMON_SEARCH_LYRIC": ("Search Online Lyrics", "搜索在线歌词"),
    "UI_COMMON_REFRESH_LIST": ("Refresh Song List", "刷新歌曲列表"),
    "UI_COMMON_IMPORT_LOCAL": ("Import Local Song", "导入本地歌曲"),
    "UI_HINT_ENTER_NEXT_NODE_ESC_PAUSE": ("Enter Next Node | ESC Pause", "Enter 进入下一节点 | ESC 暂停"),
    "UI_COMBATHUD_ATTACK_MODE": ("Attack Mode", "攻击模式"),
    "UI_TITLE_GAME_PAUSED": ("Game Paused", "游戏暂停"),
    "UI_HINT_PRESS_ENTER_FOR_MENU": ("Press Enter for Menu", "按 Enter 返回主菜单"),
    "UI_HINT_PRESS_ENTER_TO_REST": ("Press Enter to Rest", "按 Enter 休息并继续"),
    "UI_COMMON_KEY_E_BRACKET": ("[E]", "[E]"),
    "UI_COMMON_VIEW_EQUIP": ("View Equip", "查看装备")
}

csv_path = r"d:\Desktop\工具图标\游戏工具\Godot\Tetrisic\translations\translation.csv"
target_dir = r"d:\Desktop\工具图标\游戏工具\Godot\Tetrisic"

# 1. Update CSV
rows = []
seen_keys = set()
header = []

with open(csv_path, 'r', encoding='utf-8') as f:
    reader = csv.reader(f)
    header = next(reader)
    for row in reader:
        if not row: continue
        key = row[0]
        if key in key_mapping:
            key = key_mapping[key]
        
        # If key is in new_keys_defs, use the standard definition
        if key in new_keys_defs:
            en, zh = new_keys_defs[key]
            row = [key, en, zh]
        
        if key not in seen_keys:
            rows.append(row)
            seen_keys.add(key)
        else:
            # If we've seen it, it means we merged it to an existing one or it was a duplicate
            pass

rows.sort(key=lambda x: x[0])

with open(csv_path, 'w', encoding='utf-8', newline='') as f:
    writer = csv.writer(f)
    writer.writerow(header)
    writer.writerows(rows)

print(f"Updated {csv_path}")

# 2. Update Codebase
def replace_in_file(filepath):
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            content = f.read()
    except UnicodeDecodeError:
        try:
             with open(filepath, 'r', encoding='gbk') as f:
                content = f.read()
        except:
            print(f"Skipping binary/unreadable file: {filepath}")
            return

    original_content = content
    modified = False

    for old_key, new_key in key_mapping.items():
        # Simple replace might be dangerous if substrings match, but these keys are usually distinct
        # We should try to match exact words if possible, or at least common string patterns.
        # In Godot, usage is typically "KEY", tr("KEY"), or text = "KEY".
        
        # Regex replacement to ensure we don't partial match (e.g. UI_SELECT matches UI_SELECT_SONG)
        # We want to replace instances where the key is surrounded by valid delimiters or quotes
        # Common patterns: "KEY", 'KEY', tr("KEY"), text="KEY"
        
        pattern = r'(["\'])' + re.escape(old_key) + r'(["\'])'
        
        def replacer(match):
            nonlocal modified
            modified = True
            return match.group(1) + new_key + match.group(2)

        content = re.sub(pattern, replacer, content)

    if modified:
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(content)
        print(f"Updated {filepath}")

for root, dirs, files in os.walk(target_dir):
    # Skip .git, .godot, .venv
    for skip in ['.git', '.godot', '.venv', 'addons']:
        if skip in dirs:
            dirs.remove(skip)
            
    for file in files:
        if file.endswith('.gd') or file.endswith('.tscn'):
            replace_in_file(os.path.join(root, file))

