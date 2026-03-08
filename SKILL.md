---
name: voice-memo-sync
description: |
  Sync, transcribe, and intelligently organize Apple Voice Memos. 
  Extracts Apple's native transcription, generates structured summaries with LLM,
  syncs to Apple Notes & Reminders. Supports voice files, text, and URLs.
  同步、转录、智能整理Apple语音备忘录，支持多种输入格式。
version: 1.0.0
author: Ying Wen
homepage: https://github.com/ying-wen/voice-memo-sync
metadata:
  openclaw:
    emoji: "🎙️"
    os: ["darwin"]
    requires:
      bins: ["ffprobe", "python3"]
      optional_bins: ["whisper", "remindctl"]
    install:
      - id: ffmpeg
        kind: brew
        formula: ffmpeg
        bins: ["ffprobe", "ffmpeg"]
        label: "Install FFmpeg (required)"
      - id: whisper
        kind: brew  
        formula: openai-whisper
        bins: ["whisper"]
        label: "Install Whisper (optional fallback)"
      - id: remindctl
        kind: brew
        formula: steipete/tap/remindctl
        bins: ["remindctl"]
        label: "Install remindctl (optional, for Reminders)"
---

# Voice Memo Sync

Intelligently sync and organize Apple Voice Memos with AI-powered analysis.

## When to Use

✅ **USE this skill when:**
- User says "同步语音备忘录" / "sync voice memos"
- User says "整理录音" / "process recording"  
- User says "开完会了" / "会议结束" / "meeting done"
- User shares a voice file (.m4a, .mp3, .wav, .qta)
- User shares a transcript text for processing
- User shares a video/audio URL to transcribe

❌ **DON'T use this skill when:**
- User wants real-time transcription (use live services)
- User needs video editing (use video tools)

## Quick Commands

### Sync Latest Voice Memo
```
用户: "同步下最新的录音"
动作: 
1. 扫描 ~/Library/Group Containers/group.com.apple.VoiceMemos.shared/Recordings/
2. 提取Apple原生转录 (优先) 或 Whisper fallback
3. LLM深度整理 (结合用户背景)
4. 写入Apple Notes (带标签)
5. 创建Reminders (如有待办)
```

### Process Voice File
```
用户: "帮我整理这个录音 [附件: meeting.m4a]"
动作: 同上流程，但处理用户上传的文件
```

### Process Transcript Text
```
用户: "帮我整理这段会议记录: [粘贴文本]"
动作: 跳过转录，直接LLM整理
```

### Process URL
```
用户: "把这个播客整理下 https://..."
动作: 下载音频 → 转录 → 整理
```

## Transcription Priority

1. **Apple Native** (优先): 从.qta/.m4a文件的meta atom提取，零延迟
2. **Whisper Local** (fallback): 本地运行，隐私安全，但较慢
3. **External API** (可选): 火山引擎/OpenAI Whisper API，需用户配置

## Output Structure

写入Apple Notes的内容结构：
```
🎙️ [标题]
📅 时间 | ⏱️ 时长 | 🏷️ #标签1 #标签2

📌 核心摘要
[一段话总结]

🎯 关键要点
• 要点1
• 要点2

💡 深度分析与反思
[结合用户背景的个性化分析]

📋 行动建议
• TODO 1
• TODO 2

🔗 相关联系
[与用户其他项目/记忆的关联]

---
📝 原始转录
[灰色小字，放最后]
```

## User Context Integration

Skill会自动读取用户的配置来个性化输出：
- `USER.md`: 用户背景、研究方向、偏好
- `MEMORY.md`: 长期记忆、项目索引
- `SOUL.md`: 助手人格（影响整理风格）

## Configuration

用户可在 `~/.openclaw/workspace/config/voice-memo-sync.yaml` 自定义：

```yaml
# 转录优先级
transcription:
  priority: ["apple", "whisper-local", "whisper-api"]
  whisper_model: "small"  # tiny/small/medium/large
  language: "zh"          # 默认语言

# Apple Notes配置
notes:
  folder: "语音备忘录"     # 目标文件夹
  tags_prefix: true       # 是否在标题前加标签

# Reminders配置  
reminders:
  enabled: true
  list: "Reminders"       # 目标列表
  auto_create: true       # 自动创建待办

# 外部API (可选)
api:
  volcengine:
    enabled: false
    # access_key 和 secret_key 从环境变量读取
  openai_whisper:
    enabled: false
    # api_key 从环境变量读取
```

## Privacy & Security

⚠️ **隐私保护设计:**
- 所有转录默认在本地完成，不上传任何数据
- 外部API需用户明确配置启用
- 不存储任何API密钥在代码中
- 用户记忆文件只在本地读取，不外传

## Scripts

| 脚本 | 用途 |
|------|------|
| `scripts/extract-apple-transcript.py` | 提取Apple原生转录 |
| `scripts/voice-memo-processor.py` | 完整处理流程 |
| `scripts/create-apple-note.sh` | 创建Apple Notes |

## Examples

见 `examples/` 目录。
