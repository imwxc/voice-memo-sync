#!/bin/bash
# ========================================================
# Create Apple Note via osascript
# 用法: ./create-apple-note.sh "标题" "内容" ["文件夹名"]
# ========================================================

TITLE="$1"
BODY="$2"
FOLDER="${3:-语音备忘录}"  # 默认文件夹

# 转义双引号
TITLE_ESC=$(echo "$TITLE" | sed 's/"/\\"/g')
BODY_ESC=$(echo "$BODY" | sed 's/"/\\"/g')

osascript <<EOF
tell application "Notes"
    tell account "iCloud"
        -- 检查文件夹是否存在，不存在则创建
        if not (exists folder "$FOLDER") then
            make new folder with properties {name:"$FOLDER"}
        end if
        -- 创建笔记
        make new note at folder "$FOLDER" with properties {name:"$TITLE_ESC", body:"$BODY_ESC"}
    end tell
end tell
EOF

echo "[OK] 笔记已创建: $TITLE -> 文件夹: $FOLDER"
