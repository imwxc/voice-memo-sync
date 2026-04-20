#!/bin/bash
# Voice Memo Sync - Installation Script
# Usage: ./install.sh [--with-heartbeat]

set -e

WORKSPACE="${VMS_WORKSPACE:-$HOME/.voice-memo-sync}"
DATA_DIR="$WORKSPACE/data/voice-memos"
CONFIG_DIR="$WORKSPACE/config"

# Parse arguments
WITH_HEARTBEAT=false
for arg in "$@"; do
    case $arg in
        --with-heartbeat) WITH_HEARTBEAT=true ;;
    esac
done

echo "🎙️ Voice Memo Sync - Installation"
echo "=================================="

# 1. Create data directories
echo "📁 Creating data directories..."
mkdir -p "$DATA_DIR"/{icloud,sources,transcripts,processed}

# 2. Create config file
if [ ! -f "$CONFIG_DIR/voice-memo-sync.yaml" ]; then
    echo "⚙️  Creating default config..."
    mkdir -p "$CONFIG_DIR"
    cat > "$CONFIG_DIR/voice-memo-sync.yaml" << 'YAML'
# Voice Memo Sync Configuration

sources:
  voice_memos:
    enabled: true
    path: "~/Library/Group Containers/group.com.apple.VoiceMemos.shared/Recordings/"
  icloud:
    enabled: true
    paths:
      - "~/Library/Mobile Documents/com~apple~CloudDocs/Recordings"
    watch_patterns: ["*.m4a", "*.mp3", "*.mp4", "*.wav", "*.qta"]

transcription:
  priority: ["apple", "text", "summarize", "funasr"]
  funasr_model: "paraformer-zh"
  funasr_diarize: false
  funasr_env: "~/.funasr/venv"
  language: "auto"

output_targets:
  obsidian:
    enabled: false
    vault_path: ""               # 首次运行时由 Agent 询问并填入
    notes_folder: ""
    naming: "YYYY-MM-DD-{title}.md"
  raw_markdown:
    enabled: true
    path: "~/Documents/"

index:
  enabled: true
  path: "data/voice-memos/INDEX.md"

reminders:
  enabled: false
  list: "Reminders"

auto_sync:
  enabled: false
  time: "08:00"
YAML
fi

# 4. Create INDEX.md
if [ ! -f "$DATA_DIR/INDEX.md" ]; then
    echo "📋 Creating index file..."
    cat > "$DATA_DIR/INDEX.md" << 'MD'
# Voice Memo Sync - Index

| Date | Source | Title | Status |
|------|--------|-------|--------|

*Last updated: Initialized*
MD
fi

# 5. Check dependencies
echo ""
echo "🔧 Checking dependencies..."
for dep in ffmpeg python3; do
    command -v "$dep" &>/dev/null && echo "  ✅ $dep" || echo "  ❌ $dep (required)"
done

FUNASR_ENV="${FUNASR_ENV:-${FUNASR_HOME:-$HOME/.funasr}/venv}"
if [ -x "$FUNASR_ENV/bin/python3" ] && "$FUNASR_ENV/bin/python3" -c "import funasr" 2>/dev/null; then
    echo "  ✅ FunASR (Paraformer + VAD + PUNC + cam++)"
else
    echo "  ⚠️  FunASR not found — run setup script to install"
fi

for dep in yt-dlp remindctl summarize; do
    command -v "$dep" &>/dev/null && echo "  ✅ $dep" || echo "  ⚠️  $dep (optional)"
done

echo ""
echo "✅ Installation complete!"
echo ""
echo "Usage:"
echo "  • Send voice files → I'll organize them"
echo "  • Say 'sync voice memos'"
echo "  • Send YouTube/Bilibili URLs"
echo "  • Send transcript text files"
