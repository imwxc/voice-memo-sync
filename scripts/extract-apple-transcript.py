#!/usr/bin/env python3
"""
Apple Voice Memos Transcript Extractor
从Mac语音备忘录的.qta/.m4a文件中提取Apple原生转录文本

用法: 
  python3 extract-apple-transcript.py <音频文件>
  python3 extract-apple-transcript.py <音频文件> --json

隐私说明:
  - 此脚本仅在本地运行，不上传任何数据
  - 不收集任何用户信息
"""

import sys
import struct
import json
import os
from pathlib import Path

def extract_apple_transcript(filepath):
    """
    从QuickTime文件(.qta/.m4a)中提取Apple原生转录
    
    Apple Voice Memos将转录存储在文件的meta atom中，格式为JSON
    包含attributedString.runs数组，交替存储文字和索引
    """
    try:
        with open(filepath, 'rb') as f:
            f.seek(0, 2)
            file_size = f.tell()
            f.seek(0)
            
            # 查找moov atom
            moov_pos = None
            moov_size = None
            
            while f.tell() < file_size:
                pos = f.tell()
                header = f.read(8)
                if len(header) < 8:
                    break
                size, typ = struct.unpack('>I4s', header)
                typ = typ.decode('latin-1', errors='replace')
                
                if size == 0:
                    size = file_size - pos
                elif size == 1:
                    ext = f.read(8)
                    size = struct.unpack('>Q', ext)[0]
                
                if typ == 'moov':
                    moov_pos = pos
                    moov_size = size
                    break
                
                f.seek(pos + size)
            
            if moov_pos is None:
                return None, "未找到moov atom"
            
            # 读取moov区域搜索转录JSON
            f.seek(moov_pos)
            moov_data = f.read(moov_size)
            
            # 查找转录JSON (Apple格式)
            json_start = moov_data.find(b'{"locale"')
            if json_start == -1:
                json_start = moov_data.find(b'{"attributedString"')
            
            if json_start == -1:
                return None, "未找到转录数据 (此录音可能没有启用转录)"
            
            # 提取JSON
            json_data = moov_data[json_start:]
            depth = 0
            end_pos = 0
            for i, b in enumerate(json_data):
                if b == ord('{'):
                    depth += 1
                elif b == ord('}'):
                    depth -= 1
                    if depth == 0:
                        end_pos = i + 1
                        break
            
            json_str = json_data[:end_pos].decode('utf-8', errors='ignore')
            transcript_data = json.loads(json_str)
            
            # 提取纯文本
            if 'attributedString' in transcript_data:
                runs = transcript_data['attributedString']['runs']
                # runs是交替的: text, index, text, index, ...
                text_parts = []
                for i in range(0, len(runs), 2):
                    if isinstance(runs[i], str):
                        text_parts.append(runs[i])
                
                full_text = ''.join(text_parts)
                return {
                    'text': full_text,
                    'locale': transcript_data.get('locale', {}),
                    'word_count': len(text_parts),
                    'has_timestamps': 'attributeTable' in transcript_data.get('attributedString', {})
                }, None
            
            return None, "转录数据格式异常"
            
    except json.JSONDecodeError as e:
        return None, f"JSON解析失败: {e}"
    except Exception as e:
        return None, f"提取失败: {e}"

def main():
    if len(sys.argv) < 2:
        print("用法: python3 extract-apple-transcript.py <音频文件.qta/.m4a> [--json]")
        print("\n示例:")
        print("  python3 extract-apple-transcript.py recording.qta")
        print("  python3 extract-apple-transcript.py recording.m4a --json")
        sys.exit(1)
    
    filepath = sys.argv[1]
    output_json = '--json' in sys.argv
    
    if not os.path.exists(filepath):
        print(f"错误: 文件不存在: {filepath}", file=sys.stderr)
        sys.exit(1)
    
    result, error = extract_apple_transcript(filepath)
    
    if error:
        print(f"错误: {error}", file=sys.stderr)
        sys.exit(1)
    
    if output_json:
        print(json.dumps(result, ensure_ascii=False, indent=2))
    else:
        print(result['text'])

if __name__ == '__main__':
    main()
