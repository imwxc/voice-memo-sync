#!/usr/bin/env python3
"""
Apple Voice Memos Transcript Extractor
从Mac语音备忘录的.qta/.m4a文件中提取Apple原生转录文本

用法: python3 extract-apple-transcript.py <qta_or_m4a_file>
"""

import sys
import struct
import json
import re
import os

def find_meta_atom(filepath):
    """在QuickTime文件中查找包含转录的meta atom"""
    with open(filepath, 'rb') as f:
        # 读取文件大小
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
            return None
        
        # 在moov中搜索meta atom
        f.seek(moov_pos + 8)
        moov_end = moov_pos + moov_size
        
        while f.tell() < moov_end:
            pos = f.tell()
            header = f.read(8)
            if len(header) < 8:
                break
            size, typ = struct.unpack('>I4s', header)
            typ = typ.decode('latin-1', errors='replace')
            
            if size == 0:
                break
            if size == 1:
                ext = f.read(8)
                size = struct.unpack('>Q', ext)[0]
            
            # 查找较大的meta atom（转录数据通常较大）
            if typ == 'meta' and size > 1000:
                return pos, size
            
            # 递归进入trak
            if typ == 'trak':
                f.seek(pos + 8)
                trak_end = pos + size
                while f.tell() < trak_end:
                    tpos = f.tell()
                    theader = f.read(8)
                    if len(theader) < 8:
                        break
                    tsize, ttyp = struct.unpack('>I4s', theader)
                    ttyp = ttyp.decode('latin-1', errors='replace')
                    if tsize == 0:
                        break
                    if ttyp == 'meta' and tsize > 1000:
                        return tpos, tsize
                    f.seek(tpos + tsize)
            
            f.seek(pos + size)
        
        return None

def extract_transcript(filepath):
    """从文件中提取转录文本"""
    result = find_meta_atom(filepath)
    if result is None:
        return None, "未找到转录数据 (meta atom)"
    
    meta_pos, meta_size = result
    
    with open(filepath, 'rb') as f:
        f.seek(meta_pos + 8)  # skip atom header
        # 跳过version/flags
        f.read(4)
        data = f.read(meta_size - 12)
    
    # 查找JSON数据
    try:
        # 找到JSON起始位置
        json_start = data.find(b'{"locale"')
        if json_start == -1:
            json_start = data.find(b'{"attributedString"')
        
        if json_start == -1:
            return None, "未找到转录JSON数据"
        
        # 提取JSON
        json_data = data[json_start:]
        # 找到JSON结束位置 (最后一个})
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
                'raw': transcript_data
            }, None
        
        return None, "转录数据格式异常"
        
    except json.JSONDecodeError as e:
        return None, f"JSON解析失败: {e}"
    except Exception as e:
        return None, f"提取失败: {e}"

def main():
    if len(sys.argv) < 2:
        print("用法: python3 extract-apple-transcript.py <音频文件.qta/.m4a>")
        sys.exit(1)
    
    filepath = sys.argv[1]
    if not os.path.exists(filepath):
        print(f"文件不存在: {filepath}")
        sys.exit(1)
    
    result, error = extract_transcript(filepath)
    
    if error:
        print(f"错误: {error}", file=sys.stderr)
        sys.exit(1)
    
    # 输出格式
    if '--json' in sys.argv:
        print(json.dumps(result, ensure_ascii=False, indent=2))
    else:
        print(result['text'])

if __name__ == '__main__':
    main()
