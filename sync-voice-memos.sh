#!/bin/bash

# ========================================================
# Voice Memo Sync & Transcribe Script
# ========================================================
# 功能: 
# 1. 扫描Mac语音备忘录目录中今日的新录音
# 2. 复制到OpenClaw工作区
# 3. 使用Whisper进行转录
# 4. 生成Markdown每日报告
# ========================================================

# 配置
SOURCE_DIR="$HOME/Library/Group Containers/group.com.apple.VoiceMemos.shared/Recordings"
WORKSPACE_DIR="$HOME/.openclaw/workspace/memory/voice-memos"
RAW_DIR="$WORKSPACE_DIR/raw"
TRANSCRIPT_DIR="$WORKSPACE_DIR/transcripts"
REPORT_DIR="$WORKSPACE_DIR/daily-reports"
TODAY=$(date +"%Y%m%d")
TODAY_DASH=$(date +"%Y-%m-%d")

# 确保目录存在
mkdir -p "$RAW_DIR/$TODAY_DASH"
mkdir -p "$TRANSCRIPT_DIR/$TODAY_DASH"
mkdir -p "$REPORT_DIR"

echo "=== [$(date)] 开始同步语音备忘录 ($TODAY_DASH) ==="
echo "源目录: $SOURCE_DIR"

# 计数器
count=0

# 查找今日录音 (文件名格式通常为 YYYYMMDD XXXXXX.m4a)
# 使用find命令查找包含今日日期的m4a文件
find "$SOURCE_DIR" -name "${TODAY}*.m4a" | while read -r filepath; do
    filename=$(basename "$filepath")
    target_raw="$RAW_DIR/$TODAY_DASH/$filename"
    target_transcript_txt="$TRANSCRIPT_DIR/$TODAY_DASH/${filename%.*}.txt"
    
    # 检查是否已处理
    if [ -f "$target_transcript_txt" ]; then
        echo "[跳过] 已存在转录: $filename"
        continue
    fi
    
    echo "[处理中] 发现新录音: $filename"
    ((count++))
    
    # 1. 复制文件
    cp "$filepath" "$target_raw"
    
    # 2. 转录 (使用Whisper)
    # --model small (速度/精度平衡) --language Chinese (默认中文，可改auto)
    echo "       正在转录..."
    /opt/homebrew/bin/whisper "$target_raw" --model small --language Chinese --output_format txt --output_dir "$TRANSCRIPT_DIR/$TODAY_DASH" --verbose False
    
    echo "       转录完成."
done

# 3. 生成/更新每日报告
REPORT_FILE="$REPORT_DIR/voice-memo-report-$TODAY_DASH.md"

# 如果没有任何录音文件，且报告不存在，则不生成空报告
# 如果有录音文件，或者想更新现有报告，则重新生成

# 检查是否有转录文件
TRANSCRIPT_COUNT=$(ls "$TRANSCRIPT_DIR/$TODAY_DASH"/*.txt 2>/dev/null | wc -l)

if [ "$TRANSCRIPT_COUNT" -gt 0 ]; then
    echo "正在生成每日报告: $REPORT_FILE"
    
    echo "# 🎙️ 语音备忘录日报 | $TODAY_DASH" > "$REPORT_FILE"
    echo "> 自动生成于 $(date)" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
    echo "## 📊 概览" >> "$REPORT_FILE"
    echo "- **今日录音数**: $TRANSCRIPT_COUNT" >> "$REPORT_FILE"
    echo "- **存储路径**: \`$RAW_DIR/$TODAY_DASH\`" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
    echo "---" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
    
    for txt_file in "$TRANSCRIPT_DIR/$TODAY_DASH"/*.txt; do
        if [ -e "$txt_file" ]; then
            base_name=$(basename "$txt_file" .txt)
            # 尝试从文件名提取时间 (假设格式 YYYYMMDD HHMMSS)
            # 提取 20260308 131500 部分
            time_part=$(echo "$base_name" | awk '{print $2}' | cut -d'-' -f1)
            formatted_time="${time_part:0:2}:${time_part:2:2}:${time_part:4:2}"
            
            echo "## 📼 录音: $formatted_time" >> "$REPORT_FILE"
            echo "**文件名**: \`$base_name\`" >> "$REPORT_FILE"
            echo "" >> "$REPORT_FILE"
            echo "\`\`\`text" >> "$REPORT_FILE"
            cat "$txt_file" >> "$REPORT_FILE"
            echo "" >> "$REPORT_FILE"
            echo "\`\`\`" >> "$REPORT_FILE"
            echo "" >> "$REPORT_FILE"
            echo "> [💡 点击播放本地音频](file://$RAW_DIR/$TODAY_DASH/$base_name.m4a)" >> "$REPORT_FILE"
            echo "" >> "$REPORT_FILE"
            echo "---" >> "$REPORT_FILE"
            echo "" >> "$REPORT_FILE"
        fi
    done
    
    echo "报告生成完毕."
else
    echo "今日无录音，跳过报告生成."
fi

echo "=== 同步完成 ==="
