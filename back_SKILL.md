---
name: voice-memo-sync
description: |
  Sync, transcribe, and intelligently organize voice memos, audio/video files, and URLs.
  同步、转录、智能整理语音备忘录、音视频文件和视频链接。
version: 2.2.0
author: Ying Wen
homepage: https://github.com/ying-wen/voice-memo-sync
license: MIT
metadata:
  codeflicker:
    emoji: "🎙️"
    os: ["darwin"]
    requires:
      bins: ["ffmpeg", "python3"]
      optional_bins: ["yt-dlp", "remindctl", "summarize"]
    install:
      - id: init
        kind: script
        command: "./scripts/install.sh"
        label: "Initialize Voice Memo Sync"
      - id: ffmpeg
        kind: brew
        formula: ffmpeg
        bins: ["ffmpeg"]
        label: "Install FFmpeg (required)"
      - id: yt-dlp
        kind: brew
        formula: yt-dlp
        bins: ["yt-dlp"]
        label: "Install yt-dlp (for video URLs)"
---

# Voice Memo Sync 🎙️

Intelligent voice/video transcription and organization system.  
智能语音/视频转录与整理系统。

---

## Quick Start / 快速开始

```bash
# Step 1: 一键安装 FunASR（无需预装 Python，隔离环境）
bash ~/.agents/skills/voice-memo-sync/scripts/setup-funasr.sh

# Step 2: Run installation script / 运行安装脚本
bash ~/.agents/skills/voice-memo-sync/scripts/install.sh
```

**What it does / 安装内容:**
1. Downloads standalone Python to `~/.funasr/python/` (不污染系统)
2. Creates isolated venv at `~/.funasr/venv/` with FunASR + PyTorch
3. Pre-downloads ASR models (Paraformer + VAD + PUNC + cam++) to `~/.funasr/models/`
4. Creates `~/.funasr/env.sh` for environment activation
5. Creates data directory `~/.voice-memo-sync/data/voice-memos/` / 创建数据目录
6. Creates config file `~/.voice-memo-sync/config/voice-memo-sync.yaml` / 创建配置文件

**Uninstall / 卸载:** `rm -rf ~/.funasr && rm -rf ~/.voice-memo-sync`

---

## When to Use / 何时使用

✅ **USE this skill when user:**
- Sends voice/audio/video files / 发送语音/音频/视频文件
- Sends YouTube/Bilibili URLs / 发送 YouTube/B站 链接
- Sends transcript text files / 发送转录文本文件
- Says "sync voice memos", "process recording", "organize this video"
- 说「同步语音备忘录」「处理录音」「整理这个视频」

❌ **DO NOT use when:**
- User just wants to play audio/video / 用户只想播放音视频
- User asks about music/podcasts without transcription needs / 询问音乐/播客但不需要转录

---

## Supported Formats / 支持格式

### ⚡ FunASR Paraformer Engine (v2.0)

FunASR Paraformer with built-in VAD, punctuation, and speaker diarization:

| Audio | FunASR (CPU) | Performance |
|-------|-------------|-------------|
| 5 min | ~1.5s | RTF 0.005 (200x realtime) |
| 30 min | ~8s | 22x realtime |
| 60 min | ~15s | ~4x realtime |

Features out of the box:
- **Native Simplified Chinese** / 原生简体中文输出
- **Speaker Diarization** (cam++) / 说话人识别
- **Punctuation & ITN** / 标点与逆文本正则化
- **Voice Activity Detection** / 语音活动检测

| Type / 类型 | Formats / 格式 | Processing / 处理方式 |
|-------------|----------------|----------------------|
| Voice Memos | .qta, .m4a | Apple native (QTA metadata) → FunASR fallback |
| Audio | .mp3, .wav, .aac, .flac | FunASR Paraformer + diarization |
| Video | .mp4, .mov, .mkv, .webm | ffmpeg extract → FunASR |
| YouTube | URL | summarize CLI → yt-dlp fallback |
| Bilibili | URL | yt-dlp download → FunASR |
| Text | .txt, .md | Direct read, skip transcription |
| Documents | .doc, .docx | textutil convert → process |
| Structured | .json, .csv | Parse and extract text |
| iCloud | Configured paths | Scheduled sync |

---

## Processing Pipeline / 处理流程

```
Input (File/URL/Text)
        │
        ▼
┌─────────────────────────────────────┐
│     1. Source Detection            │
│     来源识别                        │
│  Voice Memo / URL / File / Text    │
└─────────────────┬───────────────────┘
                  │
                  ▼
┌─────────────────────────────────────┐
│     2. Save Source Metadata        │
│     保存源信息                      │
│  → data/voice-memos/sources/       │
└─────────────────┬───────────────────┘
                  │
                  ▼
┌─────────────────────────────────────┐
│     3. Transcription               │
│     转录提取                        │
│  .qta: Apple native → FunASR       │
│  .m4a/audio/video: FunASR only     │
└─────────────────┬───────────────────┘
                  │
                  ▼
┌─────────────────────────────────────┐
│     4. Save Raw Transcript         │
│     保存原始转录                    │
│  → data/voice-memos/transcripts/   │
└─────────────────┬───────────────────┘
                  │
                  ▼
┌─────────────────────────────────────┐
│     5. LLM Deep Processing         │
│     LLM深度整理                     │
│  • Read USER.md & MEMORY.md        │
│  • Clean up spoken language        │
│  • Extract key points & insights   │
│  • Identify TODOs & connections    │
└─────────────────┬───────────────────┘
                  │
                  ▼
┌─────────────────────────────────────┐
│     6. Save Processed Result       │
│     保存处理结果                    │
│  → data/voice-memos/processed/     │
└─────────────────┬───────────────────┘
                  │
                  ▼
┌─────────────────────────────────────┐
│     7. Output to Configured Target │
│     输出到配置目标                  │
│  Obsidian (YAML+MD) / raw_markdown  │
└─────────────────┬───────────────────┘
                  │
                  ▼
┌─────────────────────────────────────┐
│     8. Update Index                │
│     更新索引                        │
│  → data/voice-memos/INDEX.md       │
└─────────────────────────────────────┘
```

---

## Data Structure / 数据结构

```
~/.voice-memo-sync/
├── config/
│   └── voice-memo-sync.yaml  # 配置文件
└── data/voice-memos/         # All data
    ├── INDEX.md              # Processing records index / 处理记录索引
    ├── icloud/               # Synced recordings / 同步的录音
    ├── sources/              # Original file metadata / 原始文件元数据
    │   └── YYYY-MM-DD_xxx.json
    ├── transcripts/          # Raw transcripts / 原始转录文本
    │   └── YYYY-MM-DD_source_title.txt
    └── processed/            # LLM processed content / LLM处理后内容
        └── YYYY-MM-DD_source_title.md
```

---

## Output Format / 输出格式

The skill reads `USER.md`, `SOUL.md`, and `MEMORY.md` to provide **personalized analysis**:
- Deep insights tailored to user's research/work focus
- Connections to active projects and ongoing interests  
- Actionable recommendations based on user's decision style

处理时会读取 `USER.md`、`SOUL.md` 和 `MEMORY.md` 提供**个性化分析**。

**Obsidian Markdown 输出格式：**

```markdown
---
date: YYYY-MM-DD
tags: [voice-memo]
type: voice-memo
duration: Xs
source: filename.m4a
---

# 📌 核心摘要
[一段话总结核心内容]

## 🎯 关键要点
1. 要点 1
2. 要点 2

## 💡 深度分析与反思
[结合用户背景的个性化分析]

## 📋 行动建议
- [ ] TODO 1
- [ ] TODO 2

## 💬 金句摘录
- "引用 1"

---

## 📝 原始转录（已整理）
[完整转录文本]
```

---

## QTA File Format / QTA文件格式 (Technical Reference)

Apple Voice Memos on iOS/macOS 14+ uses `.qta` (QuickTime Audio) files that embed native transcription directly in the file metadata.

### Structure
```
QTA File
├── ftyp (file type marker: "qt  ")
├── wide (extended marker)
├── mdat (audio data, typically 90%+ of file size)
└── moov (metadata container)
    ├── mvhd (movie header)
    └── trak (one or more tracks)
        ├── tkhd (track header)
        ├── mdia (media data)
        └── meta (metadata - TRANSCRIPTION HERE!)
            ├── hdlr (handler: "mdta")
            ├── keys (key list: "com.apple.VoiceMemos.tsrp")
            └── ilst (data list)
                └── data (JSON transcription payload)
```

### Transcription JSON Format
```json
{
  "locale": {"identifier": "zh-Hans_GB", "current": 1},
  "attributedString": {
    "runs": ["字",0,"符",1,"转",2,"录",3,...],
    "attributeTable": [
      {"timeRange": [0.0, 0.5]},
      {"timeRange": [0.5, 0.8]},
      ...
    ]
  }
}
```

**Key Points:**
- `runs` array alternates: `[text, index, text, index, ...]`
- `attributeTable` provides timestamps for each character
- JSON is embedded raw in the `ilst/data` atom
- Use `extract-apple-transcript.py` to reliably extract

### Extraction Script
```bash
# Extract plain text
python3 scripts/extract-apple-transcript.py recording.qta

# Extract with metadata (JSON output)
python3 scripts/extract-apple-transcript.py recording.qta --json

# Extract with timestamps
python3 scripts/extract-apple-transcript.py recording.qta --json --with-timestamps
```

### Common Issues
| Issue | Cause | Solution |
|-------|-------|----------|
| "未找到转录数据" | Recording still processing | Wait 1-2 min, or use Whisper |
| "转录标记存在但数据不完整" | Partial transcription | Use Whisper fallback |
| JSON parse error | Corrupted file | Try Whisper transcription |

---

Location / 位置: `~/.voice-memo-sync/config/voice-memo-sync.yaml`

```yaml
sources:
  icloud_cache:
    enabled: true
    path: "~/.voice-memo-sync/data/voice-memos/icloud/"
  voice_memos:
    enabled: true
    path: "~/Library/Group Containers/group.com.apple.VoiceMemos.shared/Recordings/"
  icloud_drive:
    enabled: false
    paths:
      - "~/Library/Mobile Documents/com~apple~CloudDocs/Recordings"
    watch_patterns: ["*.m4a", "*.mp3", "*.mp4", "*.wav", "*.qta"]

transcription:
  priority: ["apple", "text", "summarize", "funasr"]
  funasr_model: "paraformer-zh"
  funasr_diarize: false        # 多人会议时设为 true
  funasr_env: "~/.funasr/venv"
  language: "auto"

output_targets:
  obsidian:
    enabled: false             # 首次运行时由 Agent 询问后设为 true
    vault_path: ""             # e.g. ~/Documents/MyDocs
    notes_folder: ""           # 空字符串 = vault 根目录
    naming: "YYYY-MM-DD-{title}.md"
  raw_markdown:
    enabled: true
    path: "~/Documents/"

index:
  enabled: true
  path: "~/.voice-memo-sync/data/voice-memos/INDEX.md"

reminders:
  enabled: false
  list: "Reminders"

auto_sync:
  enabled: false
  time: "08:00"
```

---

## Scripts / 脚本

| Script | Purpose / 用途 | Usage / 用法 |
|--------|----------------|--------------|
| `install.sh` | Initialize setup | `./install.sh` |
| `setup-funasr.sh` | One-click FunASR install (no Python needed) | `bash setup-funasr.sh [--install-dir /path]` |
| `process.sh` | Unified processing (FunASR) | `./process.sh <input> [--diarize]` |
| `funasr_transcribe.py` | FunASR bridge (ASR + diarization) | `python3 funasr_transcribe.py --input <file> --output-dir <dir> [--diarize]` |
| `extract-apple-transcript.py` | Extract Apple native transcription | `python3 extract-apple-transcript.py <file>` |
| `create-apple-note.sh` | Create Apple Notes | `./create-apple-note.sh <title> <content>` |
| `sync-icloud-recordings.sh` | Sync iCloud directory | `./sync-icloud-recordings.sh` |
| `auto-pipeline.sh` | Auto sync → transcribe → summarize | `./auto-pipeline.sh` |
| `auto-summary.sh` | LLM summary via claude/opencode | `./auto-summary.sh <transcript>` |

---

## Agent Processing Guide / Agent处理指南

When user sends audio/video or URL, follow these steps:  
当用户发送音视频或URL时，按以下步骤处理：

---

### Step 0: Pre-flight Config Check / 前置配置检查

**在做任何其他事之前，先读取配置文件：**

```bash
CONFIG="$HOME/.voice-memo-sync/config/voice-memo-sync.yaml"

if [ -f "$CONFIG" ]; then
  echo "✅ 配置文件存在，直接读取"
  # 读取关键配置项：vault_path、notes_folder、output_targets
else
  echo "⚠️ 配置文件不存在，需要首次初始化"
fi
```

**首次运行（配置文件不存在）时，Agent 需要询问用户：**

> 「我需要知道你的 Obsidian vault 位置，以后会记住，不会再问。  
>   请问你的 vault 路径是什么？笔记放在 vault 根目录还是某个子目录？」

询问完毕后，**立即写入配置文件**（使用 `voice-memo-sync.yaml` 模板），之后所有运行直接读取，无需再问。

**非首次运行（配置文件已存在）时：直接读取，静默执行，无需确认。**

> ⚠️ 不要在每次运行时都问用户，这会让 Skill 变得烦人。只在首次运行或配置损坏时询问。

---

### Step 1: Detect Input Type / 识别输入类型

**文件搜索优先级（按顺序检查）：**
```
1. 用户显式提供的路径
2. `~/.voice-memo-sync/data/voice-memos/icloud/`（已同步缓存，无需特殊权限）
3. ~/Library/Group Containers/group.com.apple.VoiceMemos.shared/Recordings/（需完整磁盘访问权限）
4. iCloud Drive 音频路径
5. ~/Downloads/（最后兜底）
```

> ⚠️ macOS 沙盒限制：路径 3 通常 Permission Denied，不要重试，直接跳到路径 2。  
> ⚠️ 路径中含空格时，使用变量赋值而非反斜杠转义：  
>   ```bash
>   # ✅ 推荐
>   DIR="$HOME/Library/Group Containers/..."
>   ls "$DIR"
>   # ❌ 不推荐（并发时易失效）
>   ls ~/Library/Group\ Containers/...
>   ```

**输入类型判断：**
```
YouTube URL      → summarize extract
Bilibili URL     → yt-dlp download + FunASR
.qta             → 优先尝试 Apple 原生转录提取，失败后回退 FunASR
.m4a / .mp3 等   → 直接 FunASR（跳过 Apple 原生转录，避免已知 Bug）
其他音视频        → FunASR transcription
.txt/.md file    → direct read
.doc/.docx       → textutil convert
```

> ⚠️ `.m4a` 文件不走 Apple 原生转录（`extract-apple-transcript.py`），因为该脚本对 `.m4a` 的
> `attributedString` 字段格式（list vs dict）存在兼容性 Bug，直接 FunASR 更可靠。

### Step 2: Save Source Info / 保存源信息
```bash
# Record to memory/voice-memos/sources/
echo '{"input":"...", "type":"...", "date":"YYYY-MM-DD"}' > sources/xxx.json
```

### Step 3: Get/Save Transcript / 获取保存转录
```bash
# Save to memory/voice-memos/transcripts/YYYY-MM-DD_source_title.md
# Include: source info + full raw transcript
```

### Step 4: LLM Deep Processing / LLM深度整理
```
Read USER.md and MEMORY.md, combining user context.

**MODE SELECTION (Auto-detect or Manual Override) / 模式选择:**

┌─────────────────────────────────────────────────────────────────┐
│  Mode A: Solo Memo (Default) / 短语音                           │
│  Trigger: < 5 min, single speaker, casual                       │
│  Output: Clean text + Key points + TODOs + Connections          │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│  Mode B: Deep Meeting / 深度会议                                │
│  Trigger: 15-60 min, multi-speaker with labels                  │
│  Output:                                                        │
│    1. Executive Summary (1 paragraph)                           │
│    2. Chronological Detail by time blocks                       │
│    3. Debate Flow (who said what, conflicts)                    │
│    4. Decision Matrix (Issue → Decision → Rationale)            │
│    5. Action Items with owners                                  │
│    6. Vital Quotes (preserve Voice)                             │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│  Mode C: Lecture / Talk / 讲座模式 (NEW)                        │
│  Trigger: Single speaker, 30min-3hr, structured presentation    │
│  Output:                                                        │
│    1. Executive Summary (1 paragraph)                           │
│    2. **Argument Structure (论点层级)**:                        │
│       - Core Thesis (核心论点)                                  │
│       - Supporting Arguments (分论点 1, 2, 3...)                │
│       - Key Evidence/Examples for each argument                 │
│       - Counter-arguments addressed (if any)                    │
│    3. Key Definitions (关键定义/概念)                           │
│    4. Notable Quotes (金句, with timestamps if available)       │
│    5. Connections to User's Work (个人关联)                     │
│    6. Questions Raised / Gaps (讲座未解决的问题)                │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│  Mode D: Lecture + Q&A / 讲座+问答 (NEW)                        │
│  Trigger: First part monologue, second part Q&A                 │
│  Output:                                                        │
│    **Part I: Lecture Section** (use Mode C structure)           │
│    **Part II: Q&A Section**                                     │
│       - Group questions by theme/topic (not chronological)      │
│       - Format: Q1 → A1 (summary), Q2 → A2...                   │
│       - Highlight: Best Questions, Surprising Answers           │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│  Mode E: Long-form No-Speaker-Label / 超长无标注会议 (NEW)      │
│  Trigger: > 90 min, NO speaker diarization (text is a blob)     │
│  Strategy:                                                      │
│    1. **Chunking**: Split into ~30min segments for processing   │
│    2. **Topic Detection**: Identify topic shift points          │
│       (Don't force time blocks; use semantic breaks)            │
│    3. **Abandon Attribution**: Don't guess who said what        │
│  Output:                                                        │
│    1. Executive Summary                                         │
│    2. **Topic Blocks** (not time blocks):                       │
│       - Topic 1: [Summary] + [Key points] + [Quotes]            │
│       - Topic 2: ...                                            │
│    3. Unresolved Issues / Open Questions                        │
│    4. Action Items (may lack owners)                            │
│    5. Full Cleaned Transcript (appended or linked)              │
└─────────────────────────────────────────────────────────────────┘

**TWO-PASS PROCESSING for Long Content (> 60 min):**
- Pass 1 (Quick Scan): Identify structure type, speaker presence, topic shifts
- Pass 2 (Deep Process): Apply appropriate mode to each segment

**OUTPUT DENSITY LEVELS (User can request):**
- Level 1: Executive Only (1 page, for busy stakeholders)
- Level 2: Structured Summary (5-10 pages, default)
- Level 3: Full Annotated Transcript (everything, with margin notes)
```

### Step 5: Save Processed Result / 保存处理结果
```bash
# Save to ~/.voice-memo-sync/data/voice-memos/processed/YYYY-MM-DD_source_title.md
```

### Step 6: Output to Configured Targets / 输出到配置的目标

**读取配置文件中的 `output_targets`，按需执行：**

```bash
# 读取配置（伪代码）
obsidian_enabled = config.output_targets.obsidian.enabled
raw_markdown_enabled = config.output_targets.raw_markdown.enabled
```

#### 6a. Obsidian 输出（如果 `obsidian.enabled: true`）

```bash
# 从配置读取
VAULT="$(config.obsidian.vault_path)"           # e.g. ~/Documents/MyDocs
FOLDER="$(config.obsidian.notes_folder)"         # e.g. "Voice Memos" 或空字符串（根目录）
NAMING="$(config.obsidian.naming)"               # e.g. YYYY-MM-DD-{title}.md

# 确定目标目录
if [ -z "$FOLDER" ]; then
  TARGET_DIR="$VAULT"
else
  TARGET_DIR="$VAULT/$FOLDER"
  mkdir -p "$TARGET_DIR"
fi

# 写入笔记前先检查重复
find "$TARGET_DIR" -name "*$(date +%Y-%m-%d)*" 2>/dev/null
# 如有同日文件，展示列表并询问：合并/追加/单独创建？

# 写入 Markdown（Obsidian 原生支持 Markdown，无需转换）
cp /path/to/processed.md "$TARGET_DIR/$FILENAME"
```

#### 6b. raw_markdown 输出（如果 `raw_markdown.enabled: true`）

```bash
# 直接复制进配置的输出目录
RAW_PATH="$(config.raw_markdown.path)"   # 默认 ~/Documents/
mkdir -p "$RAW_PATH"
cp /path/to/processed.md "$RAW_PATH/$FILENAME"
```

**执行后务必告知用户输出结果：**
```
✅ 已写入 Obsidian：~/Documents/MyDocs/2026-04-20-xxx.md
✅ 已保存 raw_markdown：~/Documents/2026-04-20-xxx_摘要.md
```

> 如果某个 enabled: true 的输出目标执行失败，必须告知用户，不可静默跳过。

### Step 7: Update INDEX.md / 更新索引
```bash
# Append record to ~/.voice-memo-sync/data/voice-memos/INDEX.md
```

---

## Privacy / 隐私说明

⚠️ **Privacy-First Design:**
- All transcription runs locally by default / 所有转录默认在本地完成
- Apple native transcripts extracted from local files (`.qta` only) / Apple 原生转录从本地文件提取
- FunASR runs locally / FunASR 在本地运行
- No data sent to external servers (unless user explicitly configures external API)
- User data stored only in `~/.voice-memo-sync/`

---

## Troubleshooting / 故障排除

### FunASR not found
```bash
# 方法1：运行一键安装脚本（推荐）
bash ~/.agents/skills/voice-memo-sync/scripts/setup-funasr.sh

# 方法2：手动验证并重装
~/.funasr/venv/bin/python3 -c "from funasr import AutoModel; print('OK')" || \
  python3 -m venv ~/.funasr/venv && \
  ~/.funasr/venv/bin/pip install torch torchaudio funasr modelscope \
    -i https://mirror.sjtu.edu.cn/pypi/web/simple
```

### yt-dlp download fails
```bash
# Update yt-dlp
brew upgrade yt-dlp

# Or use proxy
export ALL_PROXY=http://127.0.0.1:7890
```

### Transcription quality issues
```bash
# FunASR Paraformer already produces high-quality Simplified Chinese.
# For dialectal speech, ensure audio quality is good (16kHz+ sampling rate).
```

---

## Changelog / 更新日志

### v2.2.0 (2026-04-20)
- **REMOVED**: 完全移除 Apple Notes 同步功能，聚焦 Obsidian/Markdown 输出。
- **REMOVED**: 删除 `create-apple-note.sh` 脚本。
- **FIXED**: `process.sh` — `.m4a` 文件直接走 FunASR，不再尝试有 Bug 的 Apple 原生转录。
- **FIXED**: 所有路径统一为 `data/voice-memos/`（原为 `memory/voice-memos/`）。
- **FIXED**: 故障排除中 FunASR 路径统一为 `~/.funasr/venv`。
- **NEW**: 首次安装引导脚本 `first-run.sh`。
- **NEW**: `launchd` plist 文件加入 scripts 目录。

### v2.1.0 (2026-04-20)
- **NEW**: Step 0 Pre-flight Config Check — 首次运行询问 vault 路径并持久化，后续静默执行。
- **CHANGED**: 通用化路径，移除 openclaw 耦合，VMS_WORKSPACE 默认 `~/.voice-memo-sync`。
- **FIXED**: Step 1 输入类型判断 — `.m4a` 直接走 FunASR，跳过有 Bug 的 Apple 原生转录脚本。
- **CONFIG**: 配置文件路径 `~/.voice-memo-sync/config/voice-memo-sync.yaml`。

### v2.0.0 (2026-04-16)
- **BREAKING**: Replaced whisper.cpp with FunASR Paraformer for all transcription.
- **NEW**: Speaker diarization via cam++ (Paraformer-VAD-SPK pipeline).
- **NEW**: `funasr_transcribe.py` bridge script for ASR + diarization.
- **NEW**: `--diarize` flag on process.sh for speaker-labeled output.
- **IMPROVED**: Native Simplified Chinese output (no more Traditional Chinese hacks).
- **IMPROVED**: Built-in punctuation restoration and inverse text normalization.
- **IMPROVED**: 22x realtime transcription speed (was ~3-4x with whisper.cpp).
- Removed whisper-cpp and openai-whisper dependencies.

### v1.6.1 (2026-03-09)
- **CRITICAL FIX**: Apple Notes sync step marked as MANDATORY (不可跳过).
- **FORMAT FIX**: Explicit requirement to convert Markdown → HTML via pandoc before syncing.
- Added complete AppleScript template with folder creation.
- Common mistakes checklist to prevent format issues.

### v1.6.0 (2026-03-09)
- **QTA Format Documentation**: Added detailed technical reference for Apple's QTA file format.
- **Enhanced extract-apple-transcript.py v1.1**: Improved JSON boundary detection, better error diagnostics, timestamp extraction support.
- Added `--with-timestamps` option for detailed time-aligned output.
- Better handling of large files (>100MB).

### v1.5.0 (2026-03-09)
- Added Mode C: Lecture/Talk (single speaker, argument structure extraction).
- Added Mode D: Lecture + Q&A (hybrid processing).
- Added Mode E: Long-form No-Speaker-Label (> 90min, topic-based chunking).
- Introduced Two-Pass Processing for content > 60 min.
- Added Output Density Levels (Executive / Structured / Full Annotated).

### v1.4.0 (2026-03-09)
- Introduced "Deep Meeting Mode" for content > 15min or multi-speaker.
- Preserves information density for critical discussions/interviews.
- New structure: Executive Summary + Chronological Detail + Debate Flow + Decision Matrix.
- Explicit attribution of quotes and arguments.

### v1.2.0 (2026-03-08)
- Added unified processing script process.sh / 新增统一处理脚本
- Added installation script install.sh / 新增安装脚本
- Unified data storage to memory/voice-memos/ / 统一数据存储
- Added .doc/.docx/.json/.csv support / 新增文档格式支持
- Bilingual SKILL.md / 中英双语SKILL.md
- Improved INDEX.md auto-update / 完善索引自动更新

### v1.1.0 (2026-03-08)
- Added iCloud directory sync / 新增iCloud目录同步
- Added YouTube/Bilibili support / 新增YouTube/B站支持
- Added text file processing / 新增文本文件处理

### v1.0.0 (2026-03-08)
- Initial release / 初始版本
- Apple Voice Memos transcription / Apple语音备忘录转录
- Apple Notes sync / Apple Notes同步
