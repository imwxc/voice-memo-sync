# Voice Memo Sync — 首次安装验证报告

> **验证时间**：2026-04-20  
> **验证方式**：打包备份现有安装 → 删除 → 子 Agent 模拟全新用户安装 → 检查结果  
> **结论**：安装整体成功，但发现 3 个问题，详见踩坑章节

---

## 1. 验证环境

| 项目 | 状态 |
|------|------|
| macOS | Sequoia |
| SKILL.md | 引导版 v2.2.0 |
| `~/.voice-memo-sync/` | 不存在（全新机器） |
| `~/.funasr/` | 不存在（全新机器，备份放在 `~/.funasr_bak/`） |
| ffmpeg | ✅ 已安装 |
| python3 | ✅ 已安装 |

---

## 2. 安装时间线

| 阶段 | 操作 | 结果 |
|------|------|------|
| T+0 | 读取 SKILL.md，理解 Agent 行为指令 | ✅ 成功 |
| T+1 | 执行 `first-run.sh --check` | ✅ 成功，输出依赖状态 |
| T+2 | 设置 `VMS_FUNASR_ENV=~/.funasr_bak/venv` 并执行 `setup-funasr.sh --skip-models` | ⚠️ 环境变量被忽略，重新安装了 Python+依赖 |
| T+3 | 执行 `install.sh` 初始化数据目录和配置 | ✅ 成功 |
| T+4 | 询问 Obsidian 配置（全新安装跳过） | ✅ 已记录 |
| T+5 | 执行 `first-run.sh --finish` 激活正式 SKILL.md | ✅ 成功 |
| T+6 | 验证正式 SKILL.md 激活状态 | ✅ 成功 |

---

## 3. 最终验收状态

```
SKILL.md     → 正式版 v2.2.0 ✅（引导版已清除）
back_SKILL.md → 已删除 ✅
~/.voice-memo-sync/
  config/voice-memo-sync.yaml ✅
  data/voice-memos/
    icloud/      ✅
    sources/     ✅
    transcripts/ ✅
    processed/   ✅
    INDEX.md     ✅
~/.funasr/venv/bin/python3 ✅（重新安装）
```

**整体安装：✅ 成功**

---

## 4. 踩坑记录

### 🔴 坑 1：`setup-funasr.sh` 忽略 `VMS_FUNASR_ENV` 环境变量

**现象**：  
设置了 `export VMS_FUNASR_ENV=~/.funasr_bak/venv`，但 `setup-funasr.sh` 完全忽略此变量，仍然在 `~/.funasr/` 重新安装了完整的 Python + pip 依赖（约 1GB，耗时 5-10 分钟）。

**根因**：  
`setup-funasr.sh` 的 `INSTALL_DIR` 变量读取的是 `FUNASR_HOME`，而不是 `VMS_FUNASR_ENV`：
```bash
INSTALL_DIR="${FUNASR_HOME:-$HOME/.funasr}"
```
而 SKILL.md 的 Agent 行为指令里给出的环境变量是 `VMS_FUNASR_ENV`，两者名称不匹配。

**影响**：全新机器无法通过设置环境变量跳过重装，每次都需要完整安装。对于有备份的迁移场景（换机）尤其浪费。

**期望行为**：  
若 `VMS_FUNASR_ENV` 已设置且路径下 `python3` 可用且 `funasr` 可导入，应直接跳过安装并复用。

---

### 🟡 坑 2：SKILL.md 未记录 `VMS_FUNASR_ENV` 变量和 `--skip-models` 参数

**现象**：  
SKILL.md 的 Agent 行为指令中，第四步 4b 只写了：
```bash
bash ~/.agents/skills/voice-memo-sync/scripts/setup-funasr.sh
```
没有说明：
- `VMS_FUNASR_ENV` 环境变量可以控制安装路径
- `--skip-models` 参数可以跳过模型下载（适合已有缓存的用户）

**影响**：Agent 无法为"已有 FunASR 备份的用户"提供最优安装路径。

---

### 🟡 坑 3：第三步决策缺失"用户拒绝"路径

**现象**：  
SKILL.md 第三步写道："如果 FunASR 未安装：告知用户需要下载约 2-3GB 模型，询问是否继续"。  
但如果用户回答"不"，Agent 完全不知道接下来该怎么办，SKILL.md 没有说明：
- 是否可以继续安装（功能受限）？
- 还是直接终止安装？
- 受限功能是什么？

**影响**：Agent 在面对"拒绝安装 FunASR"的用户时会陷入不确定状态。

---

### 🟢 坑 4（轻微）：`--check` 输出没有汇总信号

**现象**：  
`first-run.sh --check` 的输出如下：
```
━━━ Skill 状态 ━━━
[!] back_SKILL.md 存在 — 安装尚未完成（运行 bash first-run.sh --finish 激活）
[!] 部分项目尚未就绪，请按提示完成安装
```
即使所有依赖都已就绪（ffmpeg/python3/FunASR/config/data 全绿），仍然显示"部分项目尚未就绪"，原因仅仅是 `back_SKILL.md` 存在（安装未完成）。

这对 Agent 来说容易混淆：所有依赖都 ✅，但整体还是显示 ⚠️，需要 Agent 自己判断"其实依赖都好了，只差 --finish"。

---

## 5. 验证结论

| 检查项 | 预期 | 实际 |
|--------|------|------|
| SKILL.md Agent 行为指令是否清晰 | Agent 能独立执行 | ✅ 基本清晰，有 3 处模糊 |
| `first-run.sh --check` 是否正常 | 输出依赖状态 | ✅ 正常 |
| `install.sh` 创建正确目录 | `icloud/sources/transcripts/processed/` | ✅ 正确 |
| 配置文件正确生成 | yaml 存在且字段完整 | ✅ 正确 |
| `first-run.sh --finish` 成功激活 | back_SKILL.md 清除，SKILL.md 变正式版 | ✅ 成功 |
| 激活后 `--check` 全绿 | 所有检查通过 | ✅ 通过 |
| `VMS_FUNASR_ENV` 复用逻辑 | 跳过重装 | ❌ 被忽略，重新安装 |

---

## 6. 改进建议（汇总）

| 优先级 | 文件 | 问题 | 建议 |
|--------|------|------|------|
| P0 | `setup-funasr.sh` | 忽略 `VMS_FUNASR_ENV` | 脚本开头检查：若 `$VMS_FUNASR_ENV` 存在且 funasr 可导入，直接跳过 |
| P0 | `SKILL.md` | 未说明 `VMS_FUNASR_ENV` 和 `--skip-models` | 第四步 4b 增加"已有安装？"分支说明 |
| P1 | `SKILL.md` | 用户拒绝安装 FunASR 的处理缺失 | 第三步增加"如果用户拒绝：说明功能受限，仍可继续仅安装基础框架" |
| P1 | `first-run.sh` | `--check` 输出对 Agent 不友好 | 最后一行增加汇总：`[✓] 依赖就绪，可运行 --finish` 或 `[!] 需要先安装缺失依赖` |
| P2 | `SKILL.md` | 手动步骤与 Agent 指令冗余 | 将手动步骤移到 README.md，SKILL.md 保持 Agent 行为指令简洁 |

---

*详细优化分析见 `INSTALL_OPTIMIZATION.md`*
