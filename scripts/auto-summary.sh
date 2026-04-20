#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WORKSPACE="${VMS_WORKSPACE:-$HOME/.voice-memo-sync}"
VMS_OUTPUT_DIR="${VMS_OUTPUT_DIR:-$HOME/Documents}"
TRANSCRIPT_FILE="$1"

if [ -z "$TRANSCRIPT_FILE" ] || [ ! -f "$TRANSCRIPT_FILE" ]; then
    echo "[VMS-Summary] 用法: $0 <transcript_file>"
    exit 1
fi

TRANSCRIPT=$(cat "$TRANSCRIPT_FILE")
FILE_SIZE=$(wc -c < "$TRANSCRIPT_FILE" | tr -d ' ')

if [ "$FILE_SIZE" -lt 200 ]; then
    echo "[VMS-Summary] 跳过: 转录内容过短 (${FILE_SIZE}B)，可能是空白/噪音"
    exit 0
fi

BASENAME=$(basename "$TRANSCRIPT_FILE" .txt)
DATE_PART=$(echo "$BASENAME" | grep -oE '^[0-9]{4}-[0-9]{2}-[0-9]{2}' || date +%Y-%m-%d)
OUTPUT_FILE="$VMS_OUTPUT_DIR/${BASENAME}_摘要.md"

if [ -f "$OUTPUT_FILE" ]; then
    echo "[VMS-Summary] 跳过: 摘要已存在 $OUTPUT_FILE"
    exit 0
fi

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"

PROMPT="请对以下语音转录文本生成结构化摘要，直接输出 Markdown 格式。

规则：
1. 标题用一级标题，格式：# [日期] 简短描述
2. 必须包含以下章节：📌 核心摘要、🎯 关键要点、📋 行动项
3. 核心摘要：一段话概括全文
4. 关键要点：用编号列表，每条一个要点
5. 行动项：用 checkbox 列表（- [ ] 格式）
6. 不要输出原始转录文本
7. 使用简体中文输出
8. 不要输出任何解释性文字，只输出 Markdown

--- 转录文本开始 ---
${TRANSCRIPT}
--- 转录文本结束 ---"

CLAUDE_CMD=$(which claude 2>/dev/null || true)
OPENCODE_CMD=$(which opencode 2>/dev/null || true)

SUMMARY=""

if [ -n "$CLAUDE_CMD" ]; then
    echo "[VMS-Summary] 使用 claude -p 生成摘要..."
    SUMMARY=$(claude -p "$PROMPT" --dangerously-skip-permissions 2>/dev/null || true)
fi

if [ -z "$SUMMARY" ] && [ -n "$OPENCODE_CMD" ]; then
    echo "[VMS-Summary] claude 失败，fallback 到 opencode run..."
    SUMMARY=$(opencode run "$PROMPT" --dangerously-skip-permissions 2>/dev/null || true)
fi

if [ -z "$SUMMARY" ]; then
    echo "[VMS-Summary] 错误: 两个 LLM 都失败了"
    exit 1
fi

echo "$SUMMARY" > "$OUTPUT_FILE"
echo "[VMS-Summary] 摘要已保存: $OUTPUT_FILE ($(wc -c < "$OUTPUT_FILE" | tr -d ' ')B)"
