#!/bin/bash
# Voice Memo Sync - 安装/初始化脚本
# Usage: ./install.sh

set -e

WORKSPACE="${OPENCLAW_WORKSPACE:-$HOME/.openclaw/workspace}"
SKILL_DIR="$WORKSPACE/skills/voice-memo-sync"
DATA_DIR="$WORKSPACE/memory/voice-memos"
CONFIG_DIR="$WORKSPACE/config"

echo "🎙️ Voice Memo Sync - 安装初始化"
echo "================================"

# 1. 创建数据目录
echo "📁 创建数据目录..."
mkdir -p "$DATA_DIR"/{sources,transcripts,processed,synced}

# 2. 创建符号链接 (skill/data -> memory/voice-memos)
if [ ! -L "$SKILL_DIR/data" ]; then
    echo "🔗 创建数据符号链接..."
    ln -sf "$DATA_DIR" "$SKILL_DIR/data"
fi

# 3. 创建配置文件
if [ ! -f "$CONFIG_DIR/voice-memo-sync.yaml" ]; then
    echo "⚙️ 创建默认配置..."
    mkdir -p "$CONFIG_DIR"
    cat > "$CONFIG_DIR/voice-memo-sync.yaml" << 'YAML'
# Voice Memo Sync 配置
# 编辑此文件自定义行为

sources:
  # Apple Voice Memos (总是启用)
  voice_memos:
    enabled: true
    path: "~/Library/Group Containers/group.com.apple.VoiceMemos.shared/Recordings/"
  
  # iCloud目录监控
  icloud:
    enabled: true
    paths:
      - "~/Library/Mobile Documents/com~apple~CloudDocs/Recordings"
      - "~/Library/Mobile Documents/com~apple~CloudDocs/会议录音"
    watch_patterns: ["*.m4a", "*.mp3", "*.mp4", "*.wav", "*.mov"]

transcription:
  # 转录优先级: apple > text > summarize > whisper-local > whisper-api
  priority: ["apple", "text", "summarize", "whisper-local"]
  whisper_model: "small"  # tiny/small/medium/large
  language: "zh"

notes:
  folder: "语音备忘录"
  include_quotes: true
  include_original: true

reminders:
  enabled: true
  list: "Reminders"
  auto_create: true

# 外部API (可选，需自行配置)
external_api:
  enabled: false
  # volcengine:
  #   app_id: "YOUR_APP_ID"
  #   access_token: "YOUR_TOKEN"
YAML
fi

# 4. 创建INDEX.md
if [ ! -f "$DATA_DIR/INDEX.md" ]; then
    echo "📋 创建索引文件..."
    cat > "$DATA_DIR/INDEX.md" << 'MD'
# Voice Memo Sync - 转录索引

本目录存储所有语音/视频转录及处理结果，供memory_search检索。

## 目录结构

```
voice-memos/
├── INDEX.md          # 本索引 (memory_search可检索)
├── sources/          # 原始文件元数据
├── transcripts/      # 原始转录文本
├── processed/        # LLM处理后的结构化内容
└── synced/           # 已同步到Notes的记录
```

## 处理记录

| 日期 | 来源 | 标题 | 状态 |
|------|------|------|------|
| - | - | - | - |

---

*最后更新: 初始化*
MD
fi

# 5. 检查依赖
echo ""
echo "🔧 检查依赖..."
MISSING=""

check_dep() {
    if command -v "$1" &> /dev/null; then
        echo "  ✅ $1"
    else
        echo "  ❌ $1 (未安装)"
        MISSING="$MISSING $1"
    fi
}

echo "必需:"
check_dep ffmpeg
check_dep python3

echo "可选:"
check_dep whisper
check_dep yt-dlp
check_dep remindctl
check_dep summarize

# 6. 安装缺失依赖提示
if [ -n "$MISSING" ]; then
    echo ""
    echo "⚠️ 缺失依赖，建议安装:"
    for dep in $MISSING; do
        case $dep in
            ffmpeg)    echo "  brew install ffmpeg" ;;
            whisper)   echo "  brew install openai-whisper" ;;
            yt-dlp)    echo "  brew install yt-dlp" ;;
            remindctl) echo "  brew install steipete/tap/remindctl" ;;
            summarize) echo "  brew install steipete/tap/summarize" ;;
        esac
    done
fi

# 7. 创建Apple Notes文件夹
echo ""
echo "📝 检查Apple Notes文件夹..."
osascript << 'AS' 2>/dev/null || true
tell application "Notes"
    tell account "iCloud"
        if not (exists folder "语音备忘录") then
            make new folder with properties {name:"语音备忘录"}
        end if
    end tell
end tell
AS
echo "  ✅ 语音备忘录 文件夹已就绪"

echo ""
echo "✅ 安装完成！"
echo ""
echo "使用方式:"
echo "  1. 发送语音文件让我整理"
echo "  2. 说「同步语音备忘录」"
echo "  3. 发送YouTube/B站链接整理"
echo "  4. 发送会议转录文本整理"
