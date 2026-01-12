#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
MusicLyricApp CLI Wrapper
用于 Godot 集成的命令行包装器
"""
import sys
import os
import subprocess
import time
import argparse

def search_and_download(app_path, keyword, output_path):
    """
    调用 MusicLyricApp 搜索并下载歌词
    
    Args:
        app_path: MusicLyricApp 可执行文件路径
        keyword: 搜索关键词（歌曲名或"艺术家 歌曲名"）
        output_path: 输出LRC文件路径
    
    Returns:
        bool: 是否成功
    """
    if not os.path.exists(app_path):
        print(f"错误: 找不到 MusicLyricApp: {app_path}", file=sys.stderr)
        return False
    
    # 确保输出目录存在
    output_dir = os.path.dirname(output_path)
    if output_dir and not os.path.exists(output_dir):
        os.makedirs(output_dir)
    
    try:
        # 由于这是GUI应用，我们需要特殊处理
        # 使用无窗口模式启动
        startupinfo = subprocess.STARTUPINFO()
        startupinfo.dwFlags |= subprocess.STARTF_USESHOWWINDOW
        startupinfo.wShowWindow = 0  # SW_HIDE
        
        # 构建命令行参数
        # 注意：这里假设程序支持某种CLI模式，如果不支持，需要其他方法
        cmd = [
            app_path,
            '--keyword', keyword,
            '--output', output_path,
            '--format', 'lrc',
            '--encoding', 'utf8',
            '--provider', 'netease'  # 网易云音乐
        ]
        
        print(f"执行命令: {' '.join(cmd)}")
        
        # 执行命令（30秒超时）
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=30,
            startupinfo=startupinfo
        )
        
        print(f"退出码: {result.returncode}")
        if result.stdout:
            print(f"标准输出: {result.stdout}")
        if result.stderr:
            print(f"标准错误: {result.stderr}", file=sys.stderr)
        
        # 等待文件生成
        for _ in range(10):  # 最多等待5秒
            if os.path.exists(output_path):
                # 检查文件是否有内容
                if os.path.getsize(output_path) > 0:
                    print(f"成功: 歌词已保存到 {output_path}")
                    return True
            time.sleep(0.5)
        
        print("错误: 未生成歌词文件", file=sys.stderr)
        return False
        
    except subprocess.TimeoutExpired:
        print("错误: 执行超时", file=sys.stderr)
        return False
    except Exception as e:
        print(f"错误: {e}", file=sys.stderr)
        return False

def main():
    parser = argparse.ArgumentParser(description='MusicLyricApp CLI Wrapper')
    parser.add_argument('--app', required=True, help='MusicLyricApp 可执行文件路径')
    parser.add_argument('--keyword', required=True, help='搜索关键词')
    parser.add_argument('--output', required=True, help='输出LRC文件路径')
    
    args = parser.parse_args()
    
    success = search_and_download(args.app, args.keyword, args.output)
    sys.exit(0 if success else 1)

if __name__ == '__main__':
    main()
