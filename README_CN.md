# Voice Memo Sync 🎙️

[![macOS](https://img.shields.io/badge/macOS-only-lightgrey)](https://www.apple.com/macos/)
[![Apple Silicon](https://img.shields.io/badge/Apple%20Silicon-FunASR-orange)](https://github.com/modelscope/FunASR)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

**智能同步、转录、整理语音备忘录、音视频文件和视频链接。**

> 🍎 **苹果生态全覆盖**：支持 iPhone、iPad、Mac。在任何苹果设备上录制的语音备忘录通过 iCloud 自动同步，处理后的结构化笔记输出到 Obsidian 或本地目录。不支持 Linux/Windows。

[English Documentation](README.md)

## ✨ 功能特性

- 🎙️ **Apple 原生转录** — 提取 `.qta` 语音备忘录内置转录（零延迟）
- 🤖 **FunASR Paraformer** — 本地 AI 转录，22x 实时速度，原生中文输出，内置说话人识别
- 🎬 **YouTube/B 站支持** — 下载并转录视频内容
- 📄 **多格式输入** — 支持 .m4a, .mp3, .mp4, .txt, .md, .doc, .docx, .json, .csv
- 🧠 **智能摘要** — LLM 驱动的结构化分析
- 📓 **Obsidian 输出** — 写入知识库，支持自定义 vault 路径和命名风格
- 🔒 **隐私优先** — 所有处理默认在本地完成

## 🚀 快速开始

### 首次安装（推荐）

```bash
# 运行首次安装引导脚本（自动完成所有初始化）
bash ~/.agents/skills/voice-memo-sync/scripts/first-run.sh
```

脚本会引导你完成：
1. 安装系统依赖（ffmpeg）
2. 安装 FunASR 转录引擎
3. 配置 Obsidian vault 路径
4. 创建数据目录
5. （可选）配置 launchd 全自动同步

### 手动安装

```bash
# 1. 安装依赖
brew install ffmpeg

# 可选
brew install yt-dlp        # YouTube/B站

# 2. 安装 FunASR（隔离环境，不污染系统）
bash ~/.agents/skills/voice-memo-sync/scripts/setup-funasr.sh

# 3. 初始化数据目录和配置
bash ~/.agents/skills/voice-memo-sync/scripts/install.sh
```

## 📁 支持的格式

| 类型 | 格式 | 处理方式 |
|------|------|----------|
| 语音备忘录（Apple） | .qta | Apple 原生转录 → FunASR 备选 |
| 语音备忘录（通用） | .m4a | FunASR Paraformer |
| 音频 | .mp3, .wav, .aac, .flac | FunASR Paraformer |
| 视频 | .mp4, .mov, .mkv, .webm | ffmpeg 提取 → FunASR |
| YouTube | URL | summarize CLI → yt-dlp 备选 |
| Bilibili | URL | yt-dlp 下载 → FunASR |
| 文本 | .txt, .md | 直接读取 |
| 文档 | .doc, .docx | textutil 转换 |
| 结构化数据 | .json, .csv | 解析提取 |

## 🔧 配置

编辑 `~/.voice-memo-sync/config/voice-memo-sync.yaml`:

```yaml
sources:
  voice_memos:
    enabled: true
  icloud:
    enabled: true
    paths:
      - "~/Library/Mobile Documents/com~apple~CloudDocs/Recordings"

transcription:
  priority: ["apple", "text", "summarize", "funasr"]
  funasr_model: "paraformer-zh"
  funasr_diarize: false        # 多人会议时设为 true
  funasr_env: "~/.funasr/venv"
  language: "auto"

output_targets:
  obsidian:
    enabled: true
    vault_path: "~/Documents/MyDocs"
    notes_folder: ""           # 空字符串 = vault 根目录
    naming: "YYYY-MM-DD-{title}.md"
  raw_markdown:
    enabled: true
    path: "~/Documents/"
```

### 环境变量

| 变量 | 默认值 | 说明 |
|------|--------|------|
| `VMS_WORKSPACE` | `~/.voice-memo-sync` | 中间数据目录 |
| `VMS_OUTPUT_DIR` | `~/Documents` | 摘要输出目录 |
| `FUNASR_HOME` | `~/.funasr` | FunASR 安装根目录 |
| `FUNASR_ENV` | `~/.funasr/venv` | FunASR 虚拟环境路径（可设为已有 venv 跳过重装） |

## 📝 输出格式（Obsidian Markdown）

```markdown
---
date: 2026-04-20
tags: [voice-memo]
type: voice-memo
duration: 33s
source: 20260420_165700.m4a
---

# 📌 核心摘要
[一段话总结核心内容]

## 🎯 关键要点
1. 要点 1
2. 要点 2

## 📋 行动建议
- [ ] TODO 1
- [ ] TODO 2

## 📝 原始转录
[完整转录文本，已整理口语表达]
```

## 🔒 隐私说明

- 所有转录默认在本地完成
- Apple 原生转录从本地文件提取（`.qta` 格式）
- FunASR 完全在本地运行
- 不向外部服务器发送任何数据
- 所有数据存储在本地 `~/.voice-memo-sync/` 目录

## 📂 数据结构

```
~/.voice-memo-sync/
├── config/
│   └── voice-memo-sync.yaml   # 配置文件
└── data/voice-memos/
    ├── INDEX.md               # 处理记录索引
    ├── icloud/                # 同步的原始录音
    ├── sources/               # 原始文件元数据
    ├── transcripts/           # 原始转录文本
    └── processed/             # LLM 处理后内容
```

## 🛠️ 故障排除

### FunASR 未找到
```bash
# 重新安装
bash ~/.agents/skills/voice-memo-sync/scripts/setup-funasr.sh

# 手动验证
~/.funasr/venv/bin/python3 -c "from funasr import AutoModel; print('✅ FunASR OK')"
```

### FunASR 模型下载失败（国内网络）
```bash
source ~/.funasr/venv/bin/activate
export MODELSCOPE_CACHE=~/.cache/modelscope
python3 -c "from funasr import AutoModel; AutoModel(model='paraformer-zh', vad_model='fsmn-vad', punc_model='ct-punc')"
```

### yt-dlp 下载失败
```bash
brew upgrade yt-dlp
# 或使用代理
export ALL_PROXY=http://127.0.0.1:7890
```

### launchd 未触发
```bash
launchctl print gui/$(id -u)/com.voice-memo-sync
cat ~/.voice-memo-sync/data/voice-memos/auto-pipeline.log
```

### 录音文件没有出现在 Mac 上
1. 确认 iPhone 已开启语音备忘录 iCloud 同步
2. 在 iPhone 上打开语音备忘录 App 触发同步
3. 等待几分钟（大文件同步可能较慢）

## 卸载

```bash
# 停止并移除 launchd 服务（若已配置）
launchctl bootout gui/$(id -u) ~/Library/LaunchAgents/com.voice-memo-sync.plist
rm ~/Library/LaunchAgents/com.voice-memo-sync.plist

# 移除 skill
rm -rf ~/.agents/skills/voice-memo-sync

# 移除工作数据（谨慎）
rm -rf ~/.voice-memo-sync
rm -rf ~/.funasr   # FunASR 环境
```

## 📜 更新日志

### v2.1.0 (2026-04-20)
- 去除 Apple Notes 同步，聚焦 Obsidian/Markdown 输出
- 修复 `.m4a` 文件直接走 FunASR（跳过有 Bug 的 Apple 原生脚本）
- 配置文件迁移到通用路径 `~/.voice-memo-sync/`
- 新增首次安装引导脚本 `first-run.sh`

### v2.0.0 (2026-04-16)
- 用 FunASR Paraformer 替换 Whisper，22x 实时速度
- 新增说话人识别（cam++ 模型）
- 原生简体中文输出

### v1.0.0 (2026-03-08)
- 初始版本

## 📄 许可证

MIT
