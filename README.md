# Voice Memo Sync 🎙️

iPhone 录音 → iCloud 自动同步 → FunASR 转录 + 说话人识别 → Claude/OpenCode 自动摘要 → Markdown 输出

全自动语音备忘录处理 pipeline。录完音什么都不用做，摘要自动出现在你的 Documents 目录。

## 功能

- **全自动 pipeline**：iPhone 录音 → Mac → 转录 → LLM 摘要，零人工干预
- **FunASR Paraformer v2.0**：原生简体中文输出，22x 实时速度，内置标点恢复
- **说话人识别**：cam++ 模型自动区分说话人（DER 10.3% on Aishell-4）
- **LLM 自动摘要**：转录完成后自动调用 Claude CLI 生成结构化摘要
- **launchd 常驻监控**：WatchPaths + 5 分钟兜底轮询
- **多格式支持**：.m4a .mp3 .mp4 .wav .mov .txt .md .doc .docx .json .csv
- **Obsidian 输出**：Markdown 写入知识库，支持自定义 vault 路径
- **隐私优先**：转录本地完成，LLM 摘要通过 CLI 调用

## 架构

```
iPhone 录音
    │
    ▼  iCloud 自动同步
Mac 语音备忘录目录
~/Library/Group Containers/.../Recordings/*.m4a
    │
    ▼  launchd 自动触发（WatchPaths + 5分钟兜底）
sync-icloud-recordings.sh
    │  扫描系统语音备忘录 + iCloud Drive 目录
    │  新文件 → 复制到 ~/.voice-memo-sync/data/voice-memos/icloud/
    ▼
auto-pipeline.sh
    │  检查未转录文件
    │  → funasr_transcribe.py 转录（Apple原生 → FunASR Paraformer + VAD + PUNC + cam++）
    │  → 转录文本保存到 workspace/transcripts/
    ▼
auto-summary.sh
    │  claude -p 生成结构化摘要
    │  → MD 保存到 ~/Documents/（或 Obsidian vault）
    ▼
完成
```

## 安装

### 1. 系统要求

- macOS 13+（Apple Silicon 推荐）
- OpenCode CLI 或 Claude Code CLI
- Homebrew
- Python 3.10+

### 2. 安装依赖

```bash
# 必装
brew install ffmpeg

# 可选
brew install yt-dlp        # YouTube/B站视频
```

### 3. 安装 Skill

```bash
# 从 SkillHub 安装
skillhub install voice-memo-sync --dir ~/.agents/skills

# 然后运行首次安装引导
bash ~/.agents/skills/voice-memo-sync/scripts/first-run.sh
```

### 4. 一键安装 FunASR

```bash
# 一键安装（无需预装 Python，隔离环境不污染系统）
bash ~/.agents/skills/voice-memo-sync/scripts/setup-funasr.sh

# 自定义安装目录
# bash ~/.agents/skills/voice-memo-sync/scripts/setup-funasr.sh --install-dir /custom/path

# 跳过模型预下载（首次转录时会自动下载）
# bash ~/.agents/skills/voice-memo-sync/scripts/setup-funasr.sh --skip-models
```

安装完成后：
- Python + FunASR 安装到 `~/.funasr/venv/`（隔离，不污染系统）
- 模型缓存在 `~/.funasr/models/`
- 每次新终端激活: `source ~/.funasr/env.sh`
- 卸载: `rm -rf ~/.funasr`

### 5. 开启语音备忘录 iCloud 同步

**iPhone**：设置 → 你的姓名 → iCloud → 语音备忘录 → 开启

**Mac**：系统设置 → Apple ID → iCloud → 语音备忘录 → 开启

### 6. 授权 Full Disk Access

系统设置 → 隐私与安全性 → 完全磁盘访问权限 → 添加 **Terminal**（或你使用的终端 App）

### 7. 安装 launchd 自动化服务

```bash
# 复制 plist 到 LaunchAgents
cp ~/.agents/skills/voice-memo-sync/scripts/com.opencode.voice-memo-sync.plist \
   ~/Library/LaunchAgents/

# 修改 plist 中的环境变量：
#   - PATH 中的 nvm node 路径
#   - VMS_WORKSPACE 路径（默认 ~/.voice-memo-sync）
#   - VMS_OUTPUT_DIR 路径（摘要输出目录，默认 ~/Documents/）

# 加载服务
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.opencode.voice-memo-sync.plist
```

### 8. 初始化工作目录

```bash
mkdir -p ~/.voice-memo-sync/{config,data/voice-memos/{sources,transcripts,processed,icloud}}
# 或直接运行安装脚本（自动创建）
bash ~/.agents/skills/voice-memo-sync/scripts/install.sh
```

### 9. 确保 Claude CLI 可用

```bash
# 如果用 nvm 管理 node，确保 claude 在 PATH 中
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
claude --version   # 应输出版本号
```

## 使用

### 全自动模式（推荐）

安装完成后什么都不用做：

1. 在 iPhone 上用语音备忘录录音
2. 等待 iCloud 同步到 Mac（通常几分钟）
3. `~/Documents/` 下自动出现转录文本和 LLM 摘要

### 手动触发（Agent skill）

在支持 voice-memo-sync skill 的 Agent 中触发：

```
"同步一下"
"处理录音"
"整理这个视频"
```

### 手动运行脚本

```bash
# 同步录音
bash ~/.agents/skills/voice-memo-sync/scripts/sync-icloud-recordings.sh

# 转录单个文件
bash ~/.agents/skills/voice-memo-sync/scripts/process.sh /path/to/audio.m4a

# 生成摘要（需 claude 或 opencode 在 PATH 中）
bash ~/.agents/skills/voice-memo-sync/scripts/auto-summary.sh /path/to/transcript.txt

# 完整 pipeline
VMS_OUTPUT_DIR=~/Documents bash ~/.agents/skills/voice-memo-sync/scripts/auto-pipeline.sh
```

## 配置

### 环境变量

| 变量 | 默认值 | 说明 |
|------|--------|------|
| `VMS_WORKSPACE` | `~/.voice-memo-sync` | 中间数据目录（录音、转录、元数据） |
| `VMS_OUTPUT_DIR` | `~/Documents` | 最终输出目录（摘要 MD） |
| `FUNASR_HOME` | `~/.funasr` | FunASR 安装根目录 |
| `FUNASR_ENV` | `~/.funasr/venv` | FunASR 虚拟环境路径（可设置为已有 venv 路径以跳过重装） |

### 脚本清单

| 脚本 | 用途 |
|------|------|
| `first-run.sh` | 首次安装引导（交互式，推荐新机使用） |
| `sync-icloud-recordings.sh` | 扫描系统语音备忘录 + iCloud Drive，复制新文件到 workspace |
| `process.sh` | 统一转录入口（Apple 原生 → FunASR Paraformer fallback） |
| `funasr_transcribe.py` | FunASR 桥接脚本（ASR + VAD + PUNC + 说话人识别） |
| `auto-pipeline.sh` | 自动化 pipeline：同步 → 转录 → 摘要 |
| `auto-summary.sh` | 调用 LLM（claude -p）生成结构化摘要 |
| `extract-apple-transcript.py` | 提取 `.qta` 格式的 Apple 语音备忘录原生转录 |
| `install.sh` | 初始化目录和配置 |

### 数据目录结构

```
~/.voice-memo-sync/data/voice-memos/   # 中间数据（workspace）
├── icloud/                            # 同步的原始录音
├── transcripts/                       # 原始转录文本
├── sources/                           # 文件元数据
├── processed/                         # Agent 处理后的摘要（手动触发时）
└── .auto_processed.log                # 自动 pipeline 处理记录

~/Documents/                           # 最终输出（可通过 VMS_OUTPUT_DIR 修改）
├── *_voicememo_*.txt                  # 转录文本副本
└── *_摘要.md                          # LLM 结构化摘要
```

## 故障排除

### FunASR 模型下载失败
```bash
# 使用国内镜像重试
source /tmp/funasr-env/bin/activate
export MODELSCOPE_CACHE=~/.cache/modelscope
python3 -c "from funasr import AutoModel; AutoModel(model='paraformer-zh', vad_model='fsmn-vad', punc_model='ct-punc')"
```

### claude -p 认证失败
```bash
# 重新登录
claude login
# 或检查 API Key
claude api-keys
```

### launchd 没有触发
```bash
# 检查服务状态
launchctl print gui/$(id -u)/com.voice-memo-sync

# 查看日志
cat ~/.voice-memo-sync/data/voice-memos/launchd-stderr.log
cat ~/.voice-memo-sync/data/voice-memos/auto-pipeline.log
```

### Full Disk Access 失效
重新授权：系统设置 → 隐私与安全性 → 完全磁盘访问权限 → 确认 Terminal 已勾选

### 录音文件没有出现在 Mac 上
1. 确认 iPhone 已开启语音备忘录 iCloud 同步
2. 在 iPhone 上打开语音备忘录 App 触发同步
3. 等待几分钟（大文件同步可能较慢）

## 卸载

```bash
# 停止并移除 launchd 服务
launchctl bootout gui/$(id -u) ~/Library/LaunchAgents/com.voice-memo-sync.plist
rm ~/Library/LaunchAgents/com.voice-memo-sync.plist

# 移除 skill
rm -rf ~/.agents/skills/voice-memo-sync

# 移除工作数据（谨慎）
rm -rf ~/.voice-memo-sync
```

## License

MIT
