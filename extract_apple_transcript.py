#!/usr/bin/env python3
"""
Voice Memo Sync - Extract Apple transcription from .qta files
Usage: python3 extract_apple_transcript.py <path_to_qta_file>
"""

import sys
import struct
import json
import re
from pathlib import Path

def find_meta_atom(filepath):
    """Find the meta atom containing transcription data"""
    with open(filepath, 'rb') as f:
        # Read file to find moov atom
        while True:
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
            
            if typ == 'moov':
                # Search within moov for meta atoms
                return search_moov_for_meta(f, pos + size)
            
            f.seek(pos + size)
    return None

def search_moov_for_meta(f, moov_end):
    """Search within moov atom for transcription meta data"""
    results = []
    while f.tell() < moov_end:
        pos = f.tell()
        header = f.read(8)
        if len(header) < 8:
            break
        size, typ = struct.unpack('>I4s', header)
        typ = typ.decode('latin-1', errors='replace')
        if size == 0 or size > 100000000:
            break
        
        # Check for meta atom with transcription
        if typ == 'meta' and size > 1000:
            f.seek(pos + 12)  # skip header + version/flags
            data = f.read(min(size - 12, 50000))
            decoded = data.decode('utf-8', errors='ignore')
            if 'attributedString' in decoded and 'runs' in decoded:
                results.append((pos, size, data))
        
        f.seek(pos + size)
    
    return results[0] if results else None

def extract_transcript(qta_path):
    """Extract transcription text from .qta file"""
    with open(qta_path, 'rb') as f:
        content = f.read()
    
    decoded = content.decode('utf-8', errors='ignore')
    
    # Find the runs array
    match = re.search(r'"runs":\[([^\]]+)\]', decoded)
    if not match:
        return None, "No transcription found in file"
    
    runs_str = match.group(1)
    # Extract all quoted strings (text segments)
    texts = re.findall(r'"([^"]+)"', runs_str)
    # Filter out pure numbers (indices)
    texts = [t for t in texts if not t.isdigit()]
    
    if not texts:
        return None, "Transcription data found but empty"
    
    full_text = ''.join(texts)
    return full_text, None

def extract_metadata(qta_path):
    """Extract recording metadata from .qta file"""
    import subprocess
    try:
        result = subprocess.run(
            ['ffprobe', '-v', 'quiet', '-print_format', 'json', '-show_format', str(qta_path)],
            capture_output=True, text=True
        )
        if result.returncode == 0:
            data = json.loads(result.stdout)
            fmt = data.get('format', {})
            tags = fmt.get('tags', {})
            return {
                'title': tags.get('title', Path(qta_path).stem),
                'duration': float(fmt.get('duration', 0)),
                'creation_time': tags.get('creation_time', ''),
            }
    except:
        pass
    return {'title': Path(qta_path).stem, 'duration': 0, 'creation_time': ''}

def main():
    if len(sys.argv) < 2:
        print("Usage: python3 extract_apple_transcript.py <path_to_qta_file>")
        print("       python3 extract_apple_transcript.py --list  # List today's recordings")
        sys.exit(1)
    
    if sys.argv[1] == '--list':
        # List today's recordings
        from datetime import datetime
        today = datetime.now().strftime('%Y%m%d')
        recordings_dir = Path.home() / 'Library/Group Containers/group.com.apple.VoiceMemos.shared/Recordings'
        
        recordings = []
        for f in recordings_dir.glob(f'{today}*.qta'):
            meta = extract_metadata(f)
            transcript, _ = extract_transcript(f)
            recordings.append({
                'path': str(f),
                'filename': f.name,
                'title': meta['title'],
                'duration': meta['duration'],
                'has_transcript': transcript is not None,
                'transcript_length': len(transcript) if transcript else 0
            })
        
        print(json.dumps(recordings, ensure_ascii=False, indent=2))
        return
    
    qta_path = sys.argv[1]
    
    if not Path(qta_path).exists():
        print(json.dumps({'error': f'File not found: {qta_path}'}, ensure_ascii=False))
        sys.exit(1)
    
    # Extract metadata
    metadata = extract_metadata(qta_path)
    
    # Extract transcript
    transcript, error = extract_transcript(qta_path)
    
    result = {
        'path': qta_path,
        'metadata': metadata,
        'transcript': transcript,
        'error': error,
        'source': 'apple_builtin' if transcript else None
    }
    
    print(json.dumps(result, ensure_ascii=False, indent=2))

if __name__ == '__main__':
    main()
