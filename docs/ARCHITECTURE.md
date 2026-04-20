# Voice Memo Sync - Architecture

## Overview

This skill provides a complete pipeline for processing Apple Voice Memos and audio/video files:

```
Input Sources          Transcription           Processing            Output
─────────────────────────────────────────────────────────────────────────────────
                                              ┌──────────────┐
.qta (VoiceMemo) ────▶ Apple Native (fast) ──▶│              │──▶ Obsidian Vault
      │                     │ (fail) ▼        │     LLM      │
      ▼                FunASR Paraformer ─────▶│   Analysis   │──▶ ~/Documents/
.m4a / Audio ────────▶ FunASR Paraformer ─────▶│              │
                                               │  + User      │──▶ INDEX.md
Video Files ─────────▶ ffmpeg → FunASR ───────▶│   Context    │
                                               └──────────────┘
YouTube URL ──────────▶ summarize / yt-dlp ────▶ (same pipeline)

Text / Document ──────▶ Direct Read ───────────▶ (skip transcription)
```

## Components

### 1. Transcript Extraction (`extract-apple-transcript.py`)

Extracts native transcription from Apple Voice Memos `.qta` files only.

> ⚠️ `.m4a` files do NOT use this script — they go directly to FunASR.
> The attributedString field format in `.m4a` files differs and causes parsing bugs.

**How it works:**
- Apple stores transcripts in the QuickTime file's `meta` atom
- The transcript is JSON-formatted with `attributedString.runs`
- Each character has associated timestamp information

**File structure:**
```
.qta file
├── ftyp (file type: "qt  ")
├── wide
├── mdat (audio data, ~90% of file)
└── moov (metadata container)
    └── trak
        └── meta (metadata - TRANSCRIPTION HERE!)
            ├── hdlr (handler: "mdta")
            ├── keys ("com.apple.VoiceMemos.tsrp")
            └── ilst
                └── data (JSON transcription payload)
```

**JSON format:**
```json
{
  "locale": {"identifier": "zh-Hans_CN", "current": 1},
  "attributedString": {
    "runs": ["字", 0, "符", 1, "转", 2, "录", 3],
    "attributeTable": [
      {"timeRange": [0, 0.5]},
      {"timeRange": [0.5, 0.8]},
      ...
    ]
  }
}
```

### 2. FunASR Paraformer Engine (`funasr_transcribe.py`)

Primary transcription engine for all non-`.qta` audio, and fallback for `.qta` when Apple native fails.

**Performance:**
| Audio | Speed | Notes |
|-------|-------|-------|
| 5 min | ~1.5s | RTF 0.005 (200x realtime) |
| 30 min | ~8s | 22x realtime |
| 60 min | ~15s | ~4x realtime |

**Features:**
- Native Simplified Chinese output
- Speaker diarization (cam++ model)
- Punctuation restoration + ITN
- Voice Activity Detection (VAD)

**Usage:**
```bash
~/.funasr/venv/bin/python3 funasr_transcribe.py \
    --input audio.m4a \
    --output-dir ~/.voice-memo-sync/data/voice-memos/transcripts/ \
    --diarize   # optional: speaker labels
```

### 3. LLM Analysis

The skill leverages the Agent's LLM capabilities to:

1. **Clean up** spoken language artifacts
2. **Summarize** key points and main topics
3. **Analyze** content in context of user's background (from USER.md / MEMORY.md)
4. **Extract** action items and TODOs
5. **Connect** to user's existing projects and memories

**Processing Modes:**
- Mode A: Solo Memo (< 5 min, single speaker)
- Mode B: Deep Meeting (15-60 min, multi-speaker)
- Mode C: Lecture / Talk (single speaker, structured presentation)
- Mode D: Lecture + Q&A (hybrid)
- Mode E: Long-form No-Speaker-Label (> 90 min, topic-based chunking)

### 4. Output Targets

**Obsidian (primary):**
```bash
# Obsidian-compatible Markdown with YAML frontmatter
cp processed.md "$VAULT_PATH/$NOTES_FOLDER/YYYY-MM-DD-title.md"
```

**raw_markdown (fallback):**
```bash
# Plain Markdown to ~/Documents/
cp processed.md ~/Documents/YYYY-MM-DD-title_摘要.md
```

## Data Flow

```
Input File/URL
    │
    ▼
~/.voice-memo-sync/data/voice-memos/
    ├── sources/          ← source metadata JSON
    ├── transcripts/      ← raw transcript text
    └── processed/        ← LLM-processed Markdown
    │
    ▼
Output Target (Obsidian vault / ~/Documents/)
    │
    ▼
INDEX.md update
```

## Configuration

Location: `~/.voice-memo-sync/config/voice-memo-sync.yaml`

Key sections:
- `sources` — iCloud cache path + system VoiceMemos path
- `transcription` — FunASR model, diarization toggle
- `output_targets` — obsidian (vault path, folder, naming) + raw_markdown
- `index` — INDEX.md path

## Privacy Considerations

1. **Local-first**: All transcription runs on local machine
2. **No API keys in code**: All from environment or config file
3. **No telemetry**: No usage data collected
4. **FunASR isolated**: Installed in `~/.funasr/venv/`, separate from system Python
5. **Data in `~/.voice-memo-sync/`**: All intermediate files in local workspace

## Extending

### Adding new output targets

Add a new section to `output_targets` in config and handle it in the Agent's Step 6:

```bash
# Example: export to Notion
notion_enabled = config.output_targets.notion.enabled
```

### Adding new input sources

Add detection in `process.sh`'s `detect_type()` function:

```bash
elif [[ "$input" =~ \.new_format$ ]]; then
    echo "new_type"
```
