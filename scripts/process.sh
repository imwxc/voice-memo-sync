#!/bin/bash
# Voice Memo Sync - 统一处理脚本
# Usage: ./process.sh <input> [--type voice|url|text|file] [--diarize]
#
# 支持输入:
#   - Voice Memos路径 (.qta/.m4a)
#   - iCloud文件路径
#   - YouTube/Bilibili URL
#   - 音视频文件路径
#   - 文本文件路径 (.txt)

set -e

WORKSPACE="${VMS_WORKSPACE:-$HOME/.voice-memo-sync}"
DATA_DIR="$WORKSPACE/data/voice-memos"
VMS_OUTPUT_DIR="${VMS_OUTPUT_DIR:-$HOME/Documents}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TODAY=$(date +%Y-%m-%d)

INPUT="$1"
TYPE="${2:---auto}"
DIARIZE="${3:---no-diarize}"
FUNASR_ENV="${FUNASR_ENV:-${FUNASR_HOME:-$HOME/.funasr}/venv}"
[ -d "$FUNASR_ENV" ] || FUNASR_ENV="/tmp/funasr-env"
FUNASR_PYTHON="$FUNASR_ENV/bin/python3"

# 颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() { echo -e "${GREEN}[VMS]${NC} $1"; }
warn() { echo -e "${YELLOW}[VMS]${NC} $1"; }
error() { echo -e "${RED}[VMS]${NC} $1"; exit 1; }

# 自动检测输入类型
detect_type() {
    local input="$1"
    
    if [[ "$input" =~ ^https?://(www\.)?(youtube\.com|youtu\.be) ]]; then
        echo "youtube"
    elif [[ "$input" =~ ^https?://(www\.)?bilibili\.com ]]; then
        echo "bilibili"
    elif [[ "$input" =~ \.qta$ ]]; then
        echo "voice_memo"
    elif [[ "$input" =~ \.m4a$ ]]; then
        echo "audio"
    elif [[ "$input" =~ \.(mp3|wav|aac|flac)$ ]]; then
        echo "audio"
    elif [[ "$input" =~ \.(mp4|mov|mkv|webm)$ ]]; then
        echo "video"
    elif [[ "$input" =~ \.(txt|md)$ ]]; then
        echo "text"
    elif [[ "$input" =~ \.(doc|docx)$ ]]; then
        echo "document"
    elif [[ "$input" =~ \.json$ ]]; then
        echo "json"
    elif [[ "$input" =~ \.csv$ ]]; then
        echo "csv"
    else
        echo "unknown"
    fi
}

# 提取Apple原生转录
extract_apple_transcript() {
    local file="$1"
    python3 "$SCRIPT_DIR/extract-apple-transcript.py" "$file" 2>/dev/null
}

funasr_transcribe() {
    local file="$1"
    local output_dir="$2"
    local diarize="${3:-false}"
    local basename=$(basename "${file%.*}")
    local args=("--input" "$file" "--output-dir" "$output_dir")
    [ "$diarize" = "true" ] && args+=("--diarize")

    if [ ! -x "$FUNASR_PYTHON" ]; then
        error "FunASR 未安装。请先运行安装脚本设置 Python 环境。"
    fi

    "$FUNASR_PYTHON" "$SCRIPT_DIR/funasr_transcribe.py" "${args[@]}"
}

# 处理YouTube
process_youtube() {
    local url="$1"
    local output_file="$DATA_DIR/transcripts/${TODAY}_youtube_$(echo "$url" | md5 -q | cut -c1-8).txt"
    
    if command -v summarize &> /dev/null; then
        log "使用summarize提取YouTube转录..."
        summarize "$url" --youtube auto --extract-only > "$output_file" 2>/dev/null
        cat "$output_file"
    else
        log "summarize未安装，使用yt-dlp下载音频..."
        local audio_file="/tmp/yt_audio_$$.mp3"
        yt-dlp -x --audio-format mp3 -o "$audio_file" "$url" --no-playlist
        funasr_transcribe "$audio_file" "$DATA_DIR/transcripts" "$DIARIZE"
        rm -f "$audio_file"
    fi
}

# 处理Bilibili
process_bilibili() {
    local url="$1"
    local audio_file="/tmp/bilibili_audio_$$.mp3"
    
    log "下载B站视频音频..."
    yt-dlp -x --audio-format mp3 -o "$audio_file" "$url" --no-playlist 2>&1
    
    if [ -f "$audio_file" ]; then
        log "音频下载完成，开始转录..."
        funasr_transcribe "$audio_file" "$DATA_DIR/transcripts" "$DIARIZE"
        rm -f "$audio_file"
    else
        error "B站音频下载失败"
    fi
}

# 处理语音备忘录
process_voice_memo() {
    local file="$1"
    local filename=$(basename "$file")
    local transcript_file="$DATA_DIR/transcripts/${TODAY}_voicememo_${filename%.*}.txt"
    
    # 尝试提取Apple原生转录
    log "尝试提取Apple原生转录..."
    local apple_transcript=$(extract_apple_transcript "$file")
    
    if [ -n "$apple_transcript" ] && [ "$apple_transcript" != "null" ]; then
        log "成功提取Apple原生转录"
        echo "$apple_transcript" > "$transcript_file"
        cat "$transcript_file"
    else
        log "无Apple转录，使用FunASR..."
        funasr_transcribe "$file" "$DATA_DIR/transcripts" "$DIARIZE" > "$transcript_file"
        cat "$transcript_file"
    fi
}

# 处理普通音频
process_audio() {
    local file="$1"
    funasr_transcribe "$file" "$DATA_DIR/transcripts" "$DIARIZE"
}

# 处理视频
process_video() {
    local file="$1"
    local audio_file="/tmp/video_audio_$$.mp3"
    
    log "提取视频音频..."
    ffmpeg -i "$file" -vn -acodec mp3 -ab 128k "$audio_file" -y 2>/dev/null
    funasr_transcribe "$audio_file" "$DATA_DIR/transcripts" "$DIARIZE"
    rm -f "$audio_file"
}

# 处理文本
process_text() {
    local file="$1"
    cat "$file"
}

# 处理Word文档 (.doc/.docx)
process_document() {
    local file="$1"
    local temp_txt="/tmp/doc_convert_$$.txt"
    
    log "转换Word文档..."
    # macOS自带textutil
    textutil -convert txt -output "$temp_txt" "$file" 2>/dev/null
    cat "$temp_txt"
    rm -f "$temp_txt"
}

# 处理JSON
process_json() {
    local file="$1"
    log "处理JSON文件..."
    # 提取文本内容，格式化输出
    python3 -c "
import json
import sys
with open('$file', 'r', encoding='utf-8') as f:
    data = json.load(f)
    
def extract_text(obj, depth=0):
    if isinstance(obj, str):
        print(obj)
    elif isinstance(obj, dict):
        for k, v in obj.items():
            if isinstance(v, str) and len(v) > 20:
                print(f'{k}: {v}')
            else:
                extract_text(v, depth+1)
    elif isinstance(obj, list):
        for item in obj:
            extract_text(item, depth+1)

extract_text(data)
"
}

# 处理CSV
process_csv() {
    local file="$1"
    log "处理CSV文件..."
    # 转为可读格式
    python3 -c "
import csv
with open('$file', 'r', encoding='utf-8') as f:
    reader = csv.DictReader(f)
    for row in reader:
        for k, v in row.items():
            if v and len(str(v)) > 10:
                print(f'{k}: {v}')
        print('---')
"
}

# 主处理流程
main() {
    if [ -z "$INPUT" ]; then
        error "用法: $0 <input> [--type voice|url|text|file]"
    fi
    
    # 检测类型
    if [ "$TYPE" == "--auto" ]; then
        TYPE=$(detect_type "$INPUT")
    fi
    
    log "输入: $INPUT"
    log "类型: $TYPE"
    
    # 保存源信息
    local source_file="$DATA_DIR/sources/${TODAY}_$(echo "$INPUT" | md5 -q | cut -c1-8).json"
    mkdir -p "$DATA_DIR/sources"
    cat > "$source_file" << EOF
{
  "input": "$INPUT",
  "type": "$TYPE",
  "date": "$TODAY",
  "timestamp": "$(date -Iseconds)"
}
EOF
    
    # 根据类型处理
    case "$TYPE" in
        youtube)
            process_youtube "$INPUT"
            ;;
        bilibili)
            process_bilibili "$INPUT"
            ;;
        voice_memo)
            process_voice_memo "$INPUT"
            ;;
        audio)
            process_audio "$INPUT"
            ;;
        video)
            process_video "$INPUT"
            ;;
        text)
            process_text "$INPUT"
            ;;
        document)
            process_document "$INPUT"
            ;;
        json)
            process_json "$INPUT"
            ;;
        csv)
            process_csv "$INPUT"
            ;;
        *)
            error "无法识别输入类型: $INPUT"
            ;;
    esac
}

main "$@"
