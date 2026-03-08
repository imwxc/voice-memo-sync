# Voice Memo Sync

[![OpenClaw Skill](https://img.shields.io/badge/OpenClaw-Skill-blue)](https://github.com/openclaw/openclaw)
[![macOS](https://img.shields.io/badge/macOS-Only-lightgrey)](https://www.apple.com/macos/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

**Intelligently sync, transcribe, and organize Apple Voice Memos with AI-powered analysis.**

Transform your voice recordings into structured, actionable notes — automatically synced to Apple Notes & Reminders.

[中文文档](README_CN.md)

## ✨ Features

- 🎙️ **Apple Native Transcription** — Extract built-in transcripts from Voice Memos (zero latency)
- 🔄 **Whisper Fallback** — Local AI transcription for recordings without native text
- 🧠 **Smart Summarization** — LLM-powered analysis with personalized insights
- 📝 **Apple Notes Sync** — Auto-create structured notes with #tags
- ⏰ **Reminders Integration** — Extract TODOs and create reminders automatically
- 🔒 **Privacy First** — All processing happens locally by default

## 🚀 Quick Start

### Installation

```bash
# Install via ClawHub (recommended)
clawhub install ying-wen/voice-memo-sync

# Or manually
git clone https://github.com/ying-wen/voice-memo-sync.git ~/.openclaw/workspace/skills/voice-memo-sync
```

### Dependencies

```bash
# Required
brew install ffmpeg

# Optional (for Whisper fallback)
brew install openai-whisper

# Optional (for Reminders integration)
brew install steipete/tap/remindctl
```

### Usage

Just tell OpenClaw:

```
"同步下最新的录音"
"Sync my latest voice memo"
"整理一下刚才的会议录音"
"I just finished a meeting, process the recording"
```

Or process specific files:

```
"帮我整理这个录音" + [attach file]
"Process this transcript: [paste text]"
"Transcribe this podcast: https://..."
```

## 📋 Output Example

```markdown
🎙️ Weekly Team Standup

📅 2026-03-08 15:51 | ⏱️ 5:32 | 🏷️ #meeting #team #planning

## 📌 Core Summary
Discussion on Q2 roadmap priorities and resource allocation...

## 🎯 Key Points
• Prioritize Feature A for March release
• Need 2 additional engineers for Project B
• Customer feedback review scheduled for Friday

## 💡 Insights & Reflection
[Personalized analysis based on your context]

## 📋 Action Items
• [ ] Draft Feature A spec by Wednesday
• [ ] Schedule hiring interviews
• [ ] Prepare customer feedback summary

---
📝 Original Transcript
[Raw transcription in smaller text]
```

## ⚙️ Configuration

Create `~/.openclaw/workspace/config/voice-memo-sync.yaml`:

```yaml
transcription:
  priority: ["apple", "whisper-local"]
  whisper_model: "small"
  language: "zh"

notes:
  folder: "Voice Memos"
  
reminders:
  enabled: true
  list: "Reminders"
```

## 🔐 Privacy

- **Local by default**: All transcription and processing happens on your machine
- **No data upload**: Your voice memos never leave your computer
- **Optional APIs**: External services (OpenAI, Volcengine) only when explicitly configured
- **No hardcoded keys**: All credentials read from environment variables

## 🛠️ How It Works

```
┌─────────────────┐
│  Voice Memos    │
│  (.qta/.m4a)    │
└────────┬────────┘
         │
         ▼
┌─────────────────┐     ┌─────────────────┐
│ Extract Apple   │────▶│ Whisper Local   │
│ Native Transcript│     │ (fallback)      │
└────────┬────────┘     └────────┬────────┘
         │                       │
         └───────────┬───────────┘
                     ▼
         ┌─────────────────┐
         │  LLM Analysis   │
         │  + User Context │
         └────────┬────────┘
                  │
         ┌────────┴────────┐
         ▼                 ▼
┌─────────────────┐ ┌─────────────────┐
│  Apple Notes    │ │   Reminders     │
│  (structured)   │ │   (TODOs)       │
└─────────────────┘ └─────────────────┘
```

## 📁 Files

```
voice-memo-sync/
├── SKILL.md                    # OpenClaw skill definition
├── README.md                   # English documentation
├── README_CN.md               # 中文文档
├── LICENSE                     # MIT License
├── scripts/
│   ├── extract-apple-transcript.py  # Apple transcript extractor
│   ├── voice-memo-processor.py      # Main processor
│   └── create-apple-note.sh         # Apple Notes helper
├── docs/
│   └── ARCHITECTURE.md         # Technical details
└── examples/
    └── sample-output.md        # Example output
```

## 🤝 Contributing

Contributions welcome! Please read our contributing guidelines first.

## 📄 License

MIT License - see [LICENSE](LICENSE) for details.

## 🙏 Acknowledgments

- [OpenClaw](https://github.com/openclaw/openclaw) — The AI agent platform
- [OpenAI Whisper](https://github.com/openai/whisper) — Speech recognition
- Apple Voice Memos — Native transcription

---

Made with ❤️ by [Ying Wen](https://github.com/ying-wen)
