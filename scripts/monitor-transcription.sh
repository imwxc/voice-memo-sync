#!/bin/bash
# Voice Memo Sync - 长任务监控脚本
# Usage: ./monitor-transcription.sh <task_name> <pid> <output_file>

TASK_NAME="${1:-transcription}"
PID="${2}"
OUTPUT_FILE="${3}"
LOG_FILE="/tmp/transcription_monitor.log"

echo "=== Transcription Monitor ==="
echo "Task: $TASK_NAME"
echo "PID: $PID"
echo "Output: $OUTPUT_FILE"
echo ""

# 检查进程是否存在
check_process() {
    if ps -p "$PID" > /dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# 监控循环
monitor() {
    local start_time=$(date +%s)
    local check_interval=30
    
    while check_process; do
        local elapsed=$(($(date +%s) - start_time))
        local mins=$((elapsed / 60))
        local secs=$((elapsed % 60))
        
        echo "[${mins}m${secs}s] 进程运行中..."
        
        # 检查是否有输出文件
        if [ -f "$OUTPUT_FILE" ]; then
            local size=$(ls -lh "$OUTPUT_FILE" 2>/dev/null | awk '{print $5}')
            echo "  输出文件: $size"
        fi
        
        sleep $check_interval
    done
    
    # 进程结束
    echo ""
    echo "=== 任务完成 ==="
    if [ -f "$OUTPUT_FILE" ]; then
        echo "✅ 输出文件已生成: $OUTPUT_FILE"
        echo "文件大小: $(ls -lh "$OUTPUT_FILE" | awk '{print $5}')"
        echo ""
        echo "=== 内容预览 ==="
        head -50 "$OUTPUT_FILE"
    else
        echo "❌ 未找到输出文件"
        echo "检查日志获取错误信息"
    fi
}

# 后台监控并记录
if [ -n "$PID" ]; then
    monitor
else
    echo "用法: $0 <task_name> <pid> <output_file>"
fi
