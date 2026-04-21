---
name: voice-memo-sync
description: |
  Sync, transcribe, and intelligently organize voice memos, audio/video files, and URLs.
  同步、转录、智能整理语音备忘录、音视频文件和视频链接。
version: 2.3.0
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

# 🎙️ Voice Memo Sync — 首次安装引导

> ⚠️ **你看到此文件，说明 voice-memo-sync 尚未完成首次安装。**

---

## 📋 Agent 行为指令（优先阅读）

**Agent：请严格按以下步骤操作，不要只展示文档给用户。**

### 当用户触发此 skill 时（无论说什么）：

**第一步：主动告知用户安装状态**

向用户说明：
> "检测到 voice-memo-sync 尚未完成首次安装。我来帮你完成安装，这大约需要 5-15 分钟（主要是下载 FunASR 模型约 2-3GB）。"

**第二步：检查当前依赖状态**

执行以下命令，并将结果告知用户：

```bash
bash ~/.agents/skills/voice-memo-sync/scripts/first-run.sh --check
```

> 退出码含义：
> - `0` = 全部就绪且已激活，无需操作
> - `2` = 依赖全部就绪，只需运行 `--finish` 完成激活
> - `1` = 有依赖未安装，需执行第四步

**第三步：根据检查结果决策**

- 如果 ffmpeg **未安装**：告知需要先安装 Homebrew 依赖，执行 4a
- 如果 FunASR **未安装**：
  - 告知用户需要下载约 2-3GB 模型，安装约 5-15 分钟
  - **询问用户是否继续安装 FunASR**
  - 如果用户**同意**：执行 4b 安装 FunASR
  - 如果用户**拒绝**：说明受限情况后继续执行 4c：
    > "好的，已跳过 FunASR。请注意：没有 FunASR 后，skill 只能处理 iPhone 语音备忘录原生格式（.qta），无法转录普通 .m4a/.mp3 音频或视频链接。你可以随时运行 `setup-funasr.sh` 补装。"
- 如果 `--check` 返回退出码 2（依赖全部就绪，只差激活）：直接跳到第六步执行 `--finish`
- 如果 `--check` 返回退出码 0（全部就绪已激活）：安装已完成，无需操作

**第四步：执行自动化安装（非交互式，Agent 主导）**

按以下顺序执行，每步完成后向用户汇报：

```bash
# 4a. 安装 ffmpeg（如果缺少）
brew install ffmpeg
```

```bash
# 4b. 安装 FunASR（根据第三步决策选择对应命令）

# ── 情况 A：全新机器，从零安装 ──
bash ~/.agents/skills/voice-memo-sync/scripts/setup-funasr.sh

# ── 情况 B：已有 FunASR 备份（换机迁移），FUNASR_ENV 指向现有 venv ──
# 脚本检测到 FUNASR_ENV 可用后会自动跳过重装
export FUNASR_ENV=~/.funasr/venv   # 替换为实际路径
bash ~/.agents/skills/voice-memo-sync/scripts/setup-funasr.sh

# ── 情况 C：Python/venv 损坏需重建，但模型已缓存（跳过 2GB 下载）──
bash ~/.agents/skills/voice-memo-sync/scripts/setup-funasr.sh --skip-models
```

安装完成后验证：
```bash
~/.funasr/venv/bin/python3 -c "import funasr; print('✅ FunASR', funasr.__version__)"
```

```bash
# 4c. 初始化数据目录和配置
bash ~/.agents/skills/voice-memo-sync/scripts/install.sh
```

**第五步：引导用户开启 iCloud 语音备忘录同步（重要）**

主动告知用户：
> "✅ Skill 默认已配置好 iCloud 同步路径，无需额外设置。
> 
> 你只需在 iPhone 上开启 iCloud 语音备忘录：
> **设置 → 你的姓名 → iCloud → 语音备忘录 → 打开**
> 
> 开启后，iPhone 上的语音备忘录会自动同步到 Mac，skill 会从以下默认路径读取：
> - 📁 系统语音备忘录：`~/Library/Group Containers/group.com.apple.VoiceMemos.shared/Recordings/`（需要完全磁盘访问权限）
> - ☁️ iCloud Drive：`~/Library/Mobile Documents/com~apple~CloudDocs/Recordings`（无需额外权限）"

询问用户权限状态：
> "是否已授予终端/应用完全磁盘访问权限？如果没有，可在：
> **系统设置 → 隐私与安全性 → 完全磁盘访问权限 → 添加 Terminal（或你使用的终端应用）**"

验证默认路径是否可访问：
```bash
# 检查两个默认路径是否存在
ls ~/Library/Group\ Containers/group.com.apple.VoiceMemos.shared/Recordings/ 2>/dev/null \
    && echo "✅ 系统语音备忘录路径可访问" || echo "⚠️  系统路径不可访问（可能需要完全磁盘访问权限）"

ls ~/Library/Mobile\ Documents/com\~apple\~CloudDocs/Recordings/ 2>/dev/null \
    && echo "✅ iCloud Drive 路径可访问" || echo "⚠️  iCloud Drive 路径不存在（可能尚未同步或路径不同）"
```

> 💡 **无需手动修改配置**：`install.sh` 生成的默认配置已包含这两个路径，skill 会自动扫描并复制新文件到 `~/.voice-memo-sync/data/voice-memos/icloud/` 工作目录后处理。
> 
> 如果用户的录音存放在其他 iCloud Drive 子目录，引导用户编辑 `~/.voice-memo-sync/config/voice-memo-sync.yaml` 的 `sources.icloud.paths` 字段添加自定义路径。

**第五步 B：询问用户 Obsidian 配置（可选）**

主动询问：
> "是否要配置 Obsidian 输出？如果有 Obsidian，笔记可以自动写入你的 vault。"

如果用户提供了 vault 路径，执行：
```bash
# 示例：用户提供了 /Users/xxx/Documents/MyNotes
VAULT="/Users/xxx/Documents/MyNotes"  # 替换为用户实际路径
CONFIG=~/.voice-memo-sync/config/voice-memo-sync.yaml
sed -i '' \
    '/obsidian:/,/raw_markdown:/{
        s|enabled: false|enabled: true|
        s|vault_path: ""|vault_path: "'"$VAULT"'"|
    }' "$CONFIG"
```

**第六步：激活正式 SKILL.md**

所有步骤完成后，执行：

```bash
bash ~/.agents/skills/voice-memo-sync/scripts/first-run.sh --finish
```

执行成功后，向用户说：
> "✅ 安装完成！voice-memo-sync 已就绪。你现在可以发送音频文件、语音备忘录或视频链接给我，我会自动转录并生成结构化摘要。"

---

## 参考：手动安装步骤（用户自行操作时）

如果用户希望自己操作，或 Agent 无法执行命令，提供以下说明：

### 第一步：检查依赖

```bash
command -v ffmpeg  && echo "✅ ffmpeg" || echo "❌ 缺失，请运行: brew install ffmpeg"
command -v python3 && echo "✅ python3" || echo "❌ python3 缺失"
```

### 第二步：安装 FunASR

```bash
bash ~/.agents/skills/voice-memo-sync/scripts/setup-funasr.sh
```

> 首次约需 5-15 分钟，下载模型约 2-3GB，安装到 `~/.funasr/`。

### 第三步：初始化数据目录

```bash
bash ~/.agents/skills/voice-memo-sync/scripts/install.sh
```

创建：
- `~/.voice-memo-sync/config/voice-memo-sync.yaml`
- `~/.voice-memo-sync/data/voice-memos/{icloud,sources,transcripts,processed}/`

### 第四步：配置 Obsidian 输出（可选）

编辑 `~/.voice-memo-sync/config/voice-memo-sync.yaml`：

```yaml
output_targets:
  obsidian:
    enabled: true
    vault_path: "~/Documents/MyDocs"   # ← 改成你的 vault 路径
    notes_folder: ""
    naming: "YYYY-MM-DD-{title}.md"
```

### 第五步：（可选）设置 launchd 全自动同步

```bash
PLIST=~/.agents/skills/voice-memo-sync/scripts/com.voice-memo-sync.plist
sed "s/YOUR_USERNAME/$(whoami)/g" "$PLIST" > ~/Library/LaunchAgents/com.voice-memo-sync.plist
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.voice-memo-sync.plist
```

iPhone：**设置 → 你的姓名 → iCloud → 语音备忘录 → 开启**

### 第六步：激活正式 skill

```bash
bash ~/.agents/skills/voice-memo-sync/scripts/first-run.sh --finish
```

---

## 遇到问题？

| 问题 | 解决方案 |
|------|----------|
| FunASR 安装失败 | 查看 `setup-funasr.sh` 的错误输出 |
| 模型下载超时 | `export ALL_PROXY=http://127.0.0.1:7890` 后重试 |
| ffmpeg 未找到 | `brew install ffmpeg` |
| 权限被拒绝 | 系统设置 → 隐私与安全性 → 完全磁盘访问权限 → 添加 Terminal |
| 有旧机备份想复用 | `export FUNASR_ENV=旧机备份路径/venv` 后运行 `setup-funasr.sh` |

详细文档：`~/.agents/skills/voice-memo-sync/README.md`
