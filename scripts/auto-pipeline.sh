#!/bin/bash
set -e

WORKSPACE="${VMS_WORKSPACE:-$HOME/.voice-memo-sync}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DATA_DIR="$WORKSPACE/memory/voice-memos"
VMS_OUTPUT_DIR="${VMS_OUTPUT_DIR:-$HOME/Documents}"
FUNASR_ENV="${FUNASR_ENV:-${FUNASR_HOME:-$HOME/.funasr}/venv}"
[ -d "$FUNASR_ENV" ] || FUNASR_ENV="/tmp/funasr-env"
SYNCED_DIR="$DATA_DIR/icloud"
PROCESSED_LOG="$DATA_DIR/.auto_processed.log"
TODAY=$(date +%Y-%m-%d)
LOG_FILE="$DATA_DIR/auto-pipeline.log"

mkdir -p "$DATA_DIR/transcripts" "$DATA_DIR/processed" "$SYNCED_DIR" "$VMS_OUTPUT_DIR"
touch "$PROCESSED_LOG" "$LOG_FILE"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"; echo "[VMS-Auto] $1"; }

log "=== Pipeline start ==="

export VMS_WORKSPACE="$WORKSPACE"
export VMS_OUTPUT_DIR="$VMS_OUTPUT_DIR"
export FUNASR_ENV="$FUNASR_ENV"
new_count=0

for m4a_file in "$SYNCED_DIR"/*.m4a; do
    [ -f "$m4a_file" ] || continue

    file_hash=$(md5 -q "$m4a_file" 2>/dev/null)
    if grep -q "$file_hash" "$PROCESSED_LOG" 2>/dev/null; then
        continue
    fi

    basename_file=$(basename "$m4a_file")
    log "Processing: $basename_file"

    transcript_name="${TODAY}_voicememo_${basename_file%.*}.txt"
    transcript_path="$DATA_DIR/transcripts/$transcript_name"

    if [ ! -f "$transcript_path" ]; then
        bash "$SCRIPT_DIR/process.sh" "$m4a_file" > "$transcript_path" 2>&1 || true
        log "Transcribed: $transcript_name"
        cp "$transcript_path" "$VMS_OUTPUT_DIR/" 2>/dev/null || true
    fi

    bash "$SCRIPT_DIR/auto-summary.sh" "$transcript_path" 2>&1 || log "Summary failed: $transcript_name"

    echo "$file_hash|$m4a_file|$TODAY" >> "$PROCESSED_LOG"
    ((new_count++)) || true
done

log "=== Pipeline done. $new_count new files processed ==="
