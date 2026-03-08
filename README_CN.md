# Voice Memo Sync 语音备忘录智能同步

[![OpenClaw Skill](https://img.shields.io/badge/OpenClaw-Skill-blue)](https://github.com/openclaw/openclaw)
[![macOS](https://img.shields.io/badge/macOS-专属-lightgrey)](https://www.apple.com/macos/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

**智能同步、转录、整理Apple语音备忘录，AI驱动的深度分析。**

将你的语音录音转化为结构化、可执行的笔记 —— 自动同步到Apple备忘录和提醒事项。

[English Documentation](README.md)

## ✨ 功能特点

- 🎙️ **Apple原生转录** — 直接提取语音备忘录内置转录，零延迟
- 🔄 **Whisper兜底** — 本地AI转录，适用于无原生转录的录音
- 🧠 **智能摘要** — LLM驱动的深度分析，结合你的个人背景
- 📝 **备忘录同步** — 自动创建结构化笔记，支持#标签
- ⏰ **提醒事项** — 自动提取待办并创建提醒
- 🔒 **隐私优先** — 所有处理默认在本地完成

## 🚀 快速开始

### 安装

```bash
# 通过ClawHub安装（推荐）
clawhub install ying-wen/voice-memo-sync

# 或手动安装
git clone https://github.com/ying-wen/voice-memo-sync.git ~/.openclaw/workspace/skills/voice-memo-sync
```

### 依赖

```bash
# 必需
brew install ffmpeg

# 可选（Whisper转录）
brew install openai-whisper

# 可选（提醒事项集成）
brew install steipete/tap/remindctl
```

### 使用方法

告诉OpenClaw：

```
"同步下最新的录音"
"整理一下刚才的会议录音"
"开完会了，帮我处理下录音"
"把今天的语音备忘录整理一下"
```

或处理特定输入：

```
"帮我整理这个录音" + [附件]
"整理这段会议记录：[粘贴文本]"
"把这个播客转录一下：https://..."
```

## 📋 输出示例

```markdown
🎙️ 团队周会记录

📅 2026-03-08 15:51 | ⏱️ 5分32秒 | 🏷️ #会议 #团队 #规划

## 📌 核心摘要
讨论了Q2路线图优先级和资源分配...

## 🎯 关键要点
• 3月优先完成功能A
• 项目B需要增加2名工程师
• 周五安排客户反馈评审

## 💡 深度分析与反思
[基于你的研究背景和当前项目的个性化分析]

## 📋 行动建议
• [ ] 周三前完成功能A技术方案
• [ ] 安排招聘面试
• [ ] 准备客户反馈汇总

## 🔗 相关联系
• 与NSFC 2026项目的关联...
• 参考上周的技术调研...

---
📝 原始转录
[灰色小字的原始转录内容]
```

## ⚙️ 配置

创建 `~/.openclaw/workspace/config/voice-memo-sync.yaml`：

```yaml
# 转录优先级
transcription:
  priority: ["apple", "whisper-local", "whisper-api"]
  whisper_model: "small"  # tiny更快，large更准
  language: "zh"

# 备忘录配置
notes:
  folder: "语音备忘录"     # 目标文件夹名
  
# 提醒事项配置
reminders:
  enabled: true
  list: "Reminders"       # 目标列表名
  auto_create: true       # 自动创建待办

# 外部API（可选，需环境变量）
api:
  volcengine:
    enabled: false
    # export VOLCENGINE_ACCESS_KEY=xxx
    # export VOLCENGINE_SECRET_KEY=xxx
  openai_whisper:
    enabled: false
    # export OPENAI_API_KEY=xxx
```

## 🔐 隐私保护

- **本地处理**：所有转录和分析默认在你的电脑上完成
- **无数据上传**：语音文件不会离开你的设备
- **可选API**：外部服务仅在明确配置后启用
- **无硬编码密钥**：所有凭证通过环境变量读取

## 🛠️ 工作流程

```
┌─────────────────┐
│   语音备忘录     │
│  (.qta/.m4a)    │
└────────┬────────┘
         │
         ▼
┌─────────────────┐     ┌─────────────────┐
│ 提取Apple原生   │────▶│  Whisper本地    │
│    转录文本     │     │   (兜底方案)    │
└────────┬────────┘     └────────┬────────┘
         │                       │
         └───────────┬───────────┘
                     ▼
         ┌─────────────────┐
         │   LLM智能分析   │◀── USER.md (用户背景)
         │  深度整理+反思  │◀── MEMORY.md (长期记忆)
         └────────┬────────┘
                  │
         ┌────────┴────────┐
         ▼                 ▼
┌─────────────────┐ ┌─────────────────┐
│   Apple备忘录   │ │    提醒事项     │
│  (结构化笔记)   │ │   (待办事项)    │
└─────────────────┘ └─────────────────┘
```

## 📁 文件结构

```
voice-memo-sync/
├── SKILL.md                    # OpenClaw技能定义
├── README.md                   # 英文文档
├── README_CN.md               # 中文文档
├── LICENSE                     # MIT许可证
├── scripts/
│   ├── extract-apple-transcript.py  # Apple转录提取
│   ├── voice-memo-processor.py      # 主处理器
│   └── create-apple-note.sh         # 备忘录创建
├── docs/
│   └── ARCHITECTURE.md         # 技术架构
└── examples/
    └── sample-output.md        # 示例输出
```

## 💡 使用场景

| 场景 | 说明 |
|------|------|
| **会议录音** | 开完会说"整理下录音"，自动生成会议纪要+待办 |
| **讲座笔记** | 录制讲座后自动整理要点、关联你的研究方向 |
| **灵感记录** | 随时语音记录想法，自动结构化存档 |
| **访谈整理** | 用户访谈录音自动转录+提取关键洞察 |
| **日记回顾** | 语音日记自动转文字，支持搜索回顾 |

## 🤝 贡献

欢迎贡献！请先阅读贡献指南。

## 📄 许可证

MIT License - 详见 [LICENSE](LICENSE)

## 🙏 致谢

- [OpenClaw](https://github.com/openclaw/openclaw) — AI Agent平台
- [OpenAI Whisper](https://github.com/openai/whisper) — 语音识别
- Apple语音备忘录 — 原生转录支持

---

Made with ❤️ by [Ying Wen](https://github.com/ying-wen)
