# Voice Memo Sync — 安装体验优化分析报告

> **基于**：全新安装验证实测（见 `INSTALL_VALIDATION.md`）  
> **时间**：2026-04-20  
> **范围**：首次安装引导链路（SKILL.md → first-run.sh → setup-funasr.sh → install.sh）

---

## 一、问题总览

本次验证发现 **3 个真实问题 + 2 个潜在问题**：

| 编号 | 优先级 | 类型 | 问题简述 |
|------|--------|------|---------|
| P1 | 🔴 | 脚本 | `setup-funasr.sh` 忽略 `VMS_FUNASR_ENV`，无法复用已有安装 |
| P2 | 🟡 | 文档 | SKILL.md 未文档化 `--skip-models` 和复用路径 |
| P3 | 🟡 | 文档 | 第三步决策缺失"用户拒绝"分支说明 |
| P4 | 🟢 | UX | `--check` 输出对 Agent 不够机器可读 |
| P5 | 🟢 | 架构 | 快速路径（无 FunASR）未被清晰定义 |

---

## 二、详细分析

### 问题 P1：`VMS_FUNASR_ENV` 与 `FUNASR_HOME` 变量名不统一

#### 根因

`first-run.sh` 第 16 行支持 `VMS_FUNASR_ENV`：

```bash
# first-run.sh:16
FUNASR_ENV="${VMS_FUNASR_ENV:-${FUNASR_HOME:-$HOME/.funasr}/venv}"
```

但 `setup-funasr.sh` 第 10 行只读 `FUNASR_HOME`，完全不看 `VMS_FUNASR_ENV`：

```bash
# setup-funasr.sh:10
INSTALL_DIR="${FUNASR_HOME:-$HOME/.funasr}"
```

两个脚本使用了不同的变量名，导致：
- 即使设置了 `VMS_FUNASR_ENV=/path/to/existing`，`setup-funasr.sh` 仍然从零开始安装
- 用户换机迁移时，即使有完整备份，也无法节省任何安装时间

#### 影响
- 实测：子 Agent 设置 `VMS_FUNASR_ENV=~/.funasr_bak/venv`，`setup-funasr.sh` 完全无视，重新安装了 Python + torch + funasr（约 10 分钟，1GB）
- 对用户的影响：**误导性**——用户以为设置了变量可以跳过安装，实际没有效果

#### 修复方案

**方案 A（推荐）**：在 `setup-funasr.sh` 开头增加"已安装检测"逻辑

```bash
# setup-funasr.sh 修改：读取 VMS_FUNASR_ENV，增加 early-exit

INSTALL_DIR="${VMS_FUNASR_ENV:+$(dirname "$VMS_FUNASR_ENV")}"  # 从 venv 路径推导安装目录
INSTALL_DIR="${INSTALL_DIR:-${FUNASR_HOME:-$HOME/.funasr}}"

# 如果目标 venv 已存在且 funasr 可导入，直接跳过
VENV_DIR="$INSTALL_DIR/venv"
if [ -x "$VENV_DIR/bin/python3" ] && "$VENV_DIR/bin/python3" -c "import funasr" 2>/dev/null; then
    log "FunASR 已安装于 $VENV_DIR，跳过重装 ✅"
    exit 0
fi
```

**方案 B**：统一所有脚本使用 `VMS_FUNASR_HOME` 代替 `FUNASR_HOME`，避免与用户系统变量冲突。

---

### 问题 P2：SKILL.md 未文档化关键参数

#### 问题详情

SKILL.md 第四步 4b 仅写：

```bash
bash ~/.agents/skills/voice-memo-sync/scripts/setup-funasr.sh
```

未提及：
1. `--skip-models` 参数（已有缓存时跳过 2GB 下载）
2. `VMS_FUNASR_ENV` / `VMS_FUNASR_HOME` 环境变量（复用已有安装）
3. 安装完成的验证方式（如何确认 FunASR 安装成功）

#### 影响

Agent 无法为以下典型场景提供最优路径：
- **换机场景**：已有旧机备份，想复用
- **网络受限场景**：模型已缓存，只需重建 venv
- **CI/测试场景**：验证安装链路但不想真正下载模型

#### 修复方案

在 SKILL.md 第四步 4b 增加条件分支说明：

```markdown
**第四步 4b：安装 FunASR**

如果是**全新机器（无 FunASR）**：
```bash
bash ~/.agents/skills/voice-memo-sync/scripts/setup-funasr.sh
```

如果**已有 FunASR 备份**（如迁移换机）：
```bash
# VMS_FUNASR_HOME 指向已有安装目录，脚本会检测并跳过重装
export VMS_FUNASR_HOME=~/.funasr  # 替换为实际路径
bash ~/.agents/skills/voice-memo-sync/scripts/setup-funasr.sh
```

如果**模型已缓存但 venv 损坏**（需要重建依赖但不重下模型）：
```bash
bash ~/.agents/skills/voice-memo-sync/scripts/setup-funasr.sh --skip-models
```

安装完成验证：
```bash
~/.funasr/venv/bin/python3 -c "import funasr; print('✅ FunASR', funasr.__version__)"
```
```

---

### 问题 P3：SKILL.md 第三步决策树不完整

#### 问题详情

当前写法：
> "如果 FunASR **未安装**：告知用户需要下载约 2-3GB 模型，询问是否继续"

缺少：
- 用户回答"否"时的处理路径
- "受限功能模式"是否被支持（仅靠 Apple 原生转录？）

#### 修复方案

补充决策树的完整分支：

```markdown
**用户回答"是"**：继续执行第四步 4b 安装 FunASR  
**用户回答"否"**：
  - 说明：跳过 FunASR 后，skill 仅能处理 `.qta`（Apple 语音备忘录原生转录），
    无法处理普通 `.m4a`/`.mp3` 或视频链接
  - 仍可继续执行 4c（install.sh）和后续步骤，安装基础框架
  - 提示：后续可随时运行 `setup-funasr.sh` 补装
```

---

### 问题 P4：`--check` 输出不便于 Agent 机器读取

#### 问题详情

当前 `--check` 输出示例：
```
━━━ Skill 状态 ━━━
[!] back_SKILL.md 存在 — 安装尚未完成
[!] 部分项目尚未就绪，请按提示完成安装
```

即使 ffmpeg/python3/FunASR/config/data 全部 `[✓]`，因为 `back_SKILL.md` 存在，整体仍显示 `[!]`。  
Agent 需要自行判断"依赖都好了，只差 `--finish`"，而不是直接看到明确信号。

#### 期望输出

把"依赖就绪"和"安装未完成"分开：

```
━━━ Skill 状态 ━━━
[✓] 所有依赖就绪
[!] 安装尚未完成 — 运行 bash first-run.sh --finish 激活正式版
```

或者增加退出码语义：
- `exit 0`：全部就绪（包括 SKILL.md 已激活）
- `exit 1`：有依赖缺失
- `exit 2`：依赖就绪但 `--finish` 未执行

这样 Agent 可以通过 `$?` 精确判断下一步行动。

#### 修复方案

在 `first-run.sh` 的 `check_status()` 函数末尾区分两种"未就绪"：

```bash
if [ "$all_ok" = "true" ]; then
    log "所有检查通过 ✅"
elif $deps_ok && [ -f "$BACK_SKILL_MD" ]; then
    # 依赖已就绪，只差激活
    warn "依赖已就绪，运行 bash first-run.sh --finish 完成激活"
    exit 2  # 特殊退出码：不是错误，只是未完成
else
    warn "部分依赖未就绪，请按提示完成安装"
    exit 1
fi
```

---

### 问题 P5：快速路径（无 FunASR 的最小安装）未定义

#### 问题详情

`setup-funasr.sh` 是整个安装流程中最重的部分（2-3GB 下载 + 10-15 分钟）。  
对于以下用户，这是不必要的阻塞：
1. 只想处理 iPhone 语音备忘录（已有 Apple 原生转录 `.qta`）的用户
2. 想先试用 skill 再决定是否安装转录引擎的用户
3. 需要快速 CI 验证安装框架的开发者

当前 SKILL.md 没有提供"不安装 FunASR 的最小可用版本"选项。

#### 建议

在 SKILL.md 的第一步（告知用户）时，增加模式选择：

```markdown
> 根据你的需求，可以选择安装模式：
> - **完整模式（推荐）**：需要下载约 2-3GB FunASR 模型，支持所有音频格式 + 视频链接
> - **轻量模式**：仅支持 Apple 语音备忘录（`.qta` 格式），安装约 30 秒
```

---

## 三、综合评分

| 维度 | 分数（10分制） | 说明 |
|------|--------------|------|
| Agent 行为指令清晰度 | 7.5 | 结构清晰，但有 3 处模糊点 |
| 安装幂等性 | 9 | `--finish` 可重复执行，`install.sh` 已有 `mkdir -p` |
| 错误处理 | 7 | 有 `set -euo pipefail`，但错误提示不够面向用户 |
| 新机体验（0→1） | 7 | 步骤清晰，但 FunASR 安装无法跳过/复用 |
| 可测试性 | 6 | `--skip-models` 存在但文档化不足，`VMS_FUNASR_ENV` 不工作 |
| **综合** | **7.3** | 可用，但有明确改进空间 |

---

## 四、优化路线图

### v2.3.0 核心修复（建议尽快完成）

1. **`setup-funasr.sh`**：增加"已安装检测"early-exit 逻辑，统一读取 `VMS_FUNASR_HOME`
2. **`SKILL.md`**：补充 FunASR 安装的三种路径（全新/备份复用/`--skip-models`）
3. **`SKILL.md`**：补充第三步"用户拒绝 FunASR"的处理路径
4. **`first-run.sh`**：`--check` 区分"依赖缺失"和"未激活"两种状态，增加差异化退出码

### v2.4.0 体验优化（可选）

5. **`SKILL.md`**：增加安装模式选择（完整/轻量），让用户在第一步就能决策
6. **`first-run.sh`**：`--check` 的 FunASR 检测路径自动读取 `first-run.sh` 使用的同一变量
7. **`SKILL.md`**：将手动安装步骤迁移到 README.md，保持 Agent 行为指令精简
8. **`setup-funasr.sh`**：在国内网络环境下，自动设置 HuggingFace/ModelScope 镜像

---

## 五、具体代码 Diff（P1 修复建议）

### `scripts/setup-funasr.sh` — 增加已安装检测

```bash
# 在第 10 行附近（INSTALL_DIR 赋值后）增加：

# 支持 VMS_FUNASR_ENV 指向现有 venv（换机迁移/复用场景）
if [ -n "${VMS_FUNASR_ENV:-}" ]; then
    VENV_DIR="$VMS_FUNASR_ENV"
    if [ -x "$VENV_DIR/bin/python3" ] && "$VENV_DIR/bin/python3" -c "import funasr" 2>/dev/null; then
        log "FunASR 已安装于 $VENV_DIR (via VMS_FUNASR_ENV)，跳过安装 ✅"
        # 写入 env.sh 以便其他脚本引用
        INSTALL_DIR="$(dirname "$VENV_DIR")"
        ENV_FILE="$INSTALL_DIR/env.sh"
        if [ ! -f "$ENV_FILE" ]; then
            cat > "$ENV_FILE" << ENVEOF
export FUNASR_HOME="$INSTALL_DIR"
export FUNASR_ENV="$VENV_DIR"
export MODELSCOPE_CACHE="$INSTALL_DIR/models"
export PATH="$VENV_DIR/bin:\$PATH"
ENVEOF
            log "env.sh 已创建: $ENV_FILE"
        fi
        exit 0
    fi
fi
```

### `scripts/first-run.sh` — 改善 `--check` 输出

```bash
# 在 check_status() 末尾，分离两种"未就绪"

if $deps_all_ok && [ -f "$BACK_SKILL_MD" ]; then
    echo ""
    log "依赖已全部就绪 ✅"
    warn "安装尚未激活 — 运行 bash $(basename "$0") --finish 完成"
    return 2
elif [ "$all_ok" = "true" ]; then
    echo ""
    log "所有检查通过 ✅"
else
    echo ""
    warn "部分项目尚未就绪，请按提示完成安装"
    return 1
fi
```

---

*报告生成于 voice-memo-sync 验证流程，建议在 v2.3.0 发布前完成所有 P0/P1 修复。*
