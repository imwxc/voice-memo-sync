#!/bin/bash
# ============================================================
# Voice Memo Sync — 首次安装引导脚本
# 
# Usage:
#   bash first-run.sh           — 交互式首次安装引导
#   bash first-run.sh --check   — 仅检查安装状态，不修改任何内容
#   bash first-run.sh --finish  — 完成安装（激活正式 SKILL.md）
# ============================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"
WORKSPACE="${VMS_WORKSPACE:-$HOME/.voice-memo-sync}"
FUNASR_ENV="${FUNASR_ENV:-${FUNASR_HOME:-$HOME/.funasr}/venv}"

# SKILL.md 文件路径
SKILL_MD="$SKILL_DIR/SKILL.md"
BACK_SKILL_MD="$SKILL_DIR/back_SKILL.md"

# ── 颜色 ──────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

log()     { echo -e "${GREEN}[✓]${NC} $1"; }
info()    { echo -e "${BLUE}[i]${NC} $1"; }
warn()    { echo -e "${YELLOW}[!]${NC} $1"; }
error()   { echo -e "${RED}[✗]${NC} $1"; }
section() { echo -e "\n${CYAN}━━━ $1 ━━━${NC}"; }

# ── 检查安装状态 ─────────────────────────────────────────
check_status() {
    local deps_ok=true   # 依赖（ffmpeg/python3/FunASR/config/data）是否全部就绪
    local all_ok=true    # 包含 Skill 激活状态在内的整体状态

    section "依赖检查"

    # ffmpeg
    if command -v ffmpeg &>/dev/null; then
        log "ffmpeg $(ffmpeg -version 2>&1 | head -1 | grep -oE '[0-9]+\.[0-9]+' | head -1)"
    else
        error "ffmpeg 未安装 → brew install ffmpeg"
        deps_ok=false
        all_ok=false
    fi

    # python3
    if command -v python3 &>/dev/null; then
        log "python3 $(python3 --version 2>&1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')"
    else
        error "python3 未找到"
        deps_ok=false
        all_ok=false
    fi

    # FunASR
    if [ -x "$FUNASR_ENV/bin/python3" ] && "$FUNASR_ENV/bin/python3" -c "import funasr" 2>/dev/null; then
        log "FunASR (Paraformer + VAD + PUNC + cam++) at $FUNASR_ENV"
    else
        warn "FunASR 未安装 → bash $SCRIPT_DIR/setup-funasr.sh"
        deps_ok=false
        all_ok=false
    fi

    # yt-dlp (optional)
    command -v yt-dlp &>/dev/null && log "yt-dlp (optional)" || info "yt-dlp 未安装（可选，YouTube/B站支持）"

    section "配置文件"
    local config="$WORKSPACE/config/voice-memo-sync.yaml"
    if [ -f "$config" ]; then
        log "配置文件存在: $config"
        # 检查 obsidian vault_path 是否已配置
        local vault_path
        vault_path=$(grep 'vault_path:' "$config" | head -1 | sed 's/.*vault_path: *"\(.*\)".*/\1/')
        if [ -z "$vault_path" ] || [ "$vault_path" = "" ]; then
            warn "Obsidian vault_path 未配置（可选，如需输出到 Obsidian 请设置）"
        else
            log "Obsidian vault: $vault_path"
        fi
    else
        warn "配置文件不存在 → bash $SCRIPT_DIR/install.sh"
        deps_ok=false
        all_ok=false
    fi

    section "数据目录"
    local data_dir="$WORKSPACE/data/voice-memos"
    if [ -d "$data_dir" ]; then
        log "数据目录存在: $data_dir"
    else
        warn "数据目录不存在 → bash $SCRIPT_DIR/install.sh"
        deps_ok=false
        all_ok=false
    fi

    section "Skill 状态"
    if [ -f "$BACK_SKILL_MD" ]; then
        warn "back_SKILL.md 存在 — 安装尚未完成（运行 bash first-run.sh --finish 激活）"
        all_ok=false
    elif [ -f "$SKILL_MD" ]; then
        # 检查 SKILL.md 是否为首次安装引导（包含特定标记）
        if head -40 "$SKILL_MD" 2>/dev/null | grep -q "Voice Memo Sync — 首次安装引导"; then
            warn "SKILL.md 仍为首次安装引导版本 — 请完成安装后运行 --finish"
            all_ok=false
        else
            log "SKILL.md 已激活正式版本"
        fi
    fi

    echo ""
    if [ "$all_ok" = "true" ]; then
        log "所有检查通过 ✅"
        return 0
    elif [ "$deps_ok" = "true" ]; then
        # 依赖全部就绪，只差 --finish 激活
        log "依赖已全部就绪 ✅"
        warn "安装尚未激活 — 运行 bash $(basename "$0") --finish 完成最后一步"
        return 2
    else
        warn "部分依赖未就绪，请按提示安装后重试"
        return 1
    fi
}

# ── 完成安装（激活正式 SKILL.md） ─────────────────────────
finish_install() {
    section "激活正式 SKILL.md"

    if [ ! -f "$BACK_SKILL_MD" ]; then
        warn "back_SKILL.md 不存在 — 无法激活（可能已经完成过安装？）"
        if ! head -40 "$SKILL_MD" 2>/dev/null | grep -q "Voice Memo Sync — 首次安装引导"; then
            log "SKILL.md 已经是正式版本，无需操作"
            return 0
        fi
        error "无法找到正式版 SKILL.md，请联系维护者"
        exit 1
    fi

    # 检查 back_SKILL.md 确实是正式版
    # 只检查前 40 行（frontmatter + 标题区域），避免 Changelog 中的描述文字误判
    if head -40 "$BACK_SKILL_MD" 2>/dev/null | grep -q "Voice Memo Sync — 首次安装引导"; then
        error "back_SKILL.md 似乎也是引导文件，结构异常，请手动检查"
        exit 1
    fi

    # 删除首次安装引导版 SKILL.md
    rm -f "$SKILL_MD"
    log "已删除首次安装引导文件"

    # 将 back_SKILL.md 重命名为 SKILL.md
    mv "$BACK_SKILL_MD" "$SKILL_MD"
    log "back_SKILL.md → SKILL.md 完成"

    echo ""
    echo -e "${GREEN}╔══════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║  🎙️  Voice Memo Sync 安装完成！           ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════╝${NC}"
    echo ""
    echo "现在你可以："
    echo "  • 发送音频/视频文件给 Agent"
    echo "  • 说「同步语音备忘录」"
    echo "  • 发送 YouTube/Bilibili 链接"
    echo ""
}

# ── 交互式首次安装引导 ────────────────────────────────────
interactive_install() {
    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║   🎙️  Voice Memo Sync 首次安装引导        ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════╝${NC}"
    echo ""

    # ── Step 1: 检查 ffmpeg ──────────────────────────────
    section "Step 1: 检查系统依赖"

    if command -v ffmpeg &>/dev/null; then
        log "ffmpeg 已安装"
    else
        warn "ffmpeg 未安装"
        read -r -p "  是否现在安装 ffmpeg？(需要 Homebrew) [Y/n] " ans
        if [[ "${ans:-Y}" =~ ^[Yy] ]]; then
            brew install ffmpeg
            log "ffmpeg 安装完成"
        else
            error "ffmpeg 是必要依赖，无法继续安装"
            exit 1
        fi
    fi

    # ── Step 2: 安装 FunASR ──────────────────────────────
    section "Step 2: 安装 FunASR 转录引擎"

    if [ -x "$FUNASR_ENV/bin/python3" ] && "$FUNASR_ENV/bin/python3" -c "import funasr" 2>/dev/null; then
        log "FunASR 已安装，跳过"
    else
        info "FunASR 约需下载 2-3GB 模型，首次安装约 5-15 分钟"
        read -r -p "  是否现在安装 FunASR？[Y/n] " ans
        if [[ "${ans:-Y}" =~ ^[Yy] ]]; then
            bash "$SCRIPT_DIR/setup-funasr.sh"
        else
            warn "已跳过 FunASR 安装（后续可运行 bash setup-funasr.sh）"
        fi
    fi

    # ── Step 3: 初始化数据目录 ───────────────────────────
    section "Step 3: 初始化数据目录和配置"
    bash "$SCRIPT_DIR/install.sh"

    # ── Step 4: 配置 Obsidian ────────────────────────────
    section "Step 4: 配置输出目标"

    local config="$WORKSPACE/config/voice-memo-sync.yaml"
    local vault_path
    vault_path=$(grep 'vault_path:' "$config" | head -1 | sed 's/.*vault_path: *"\(.*\)".*/\1/')

    if [ -z "$vault_path" ] || [ "$vault_path" = "" ]; then
        read -r -p "  是否配置 Obsidian vault？[Y/n] " want_obsidian
        if [[ "${want_obsidian:-Y}" =~ ^[Yy] ]]; then
            read -r -p "  输入你的 Obsidian vault 路径（如 ~/Documents/MyDocs）: " vault_input
            vault_input="${vault_input/#\~/$HOME}"  # 展开 ~
            if [ -d "$vault_input" ]; then
                # 更新配置文件
                # 将 enabled: false 改为 enabled: true（obsidian 部分的第一个）
                # 将 vault_path: "" 改为实际路径
                sed -i '' \
                    '/obsidian:/,/raw_markdown:/{
                        s|enabled: false|enabled: true|
                        s|vault_path: ""|vault_path: "'"$vault_input"'"|
                    }' "$config"
                log "Obsidian vault 已配置: $vault_input"

                read -r -p "  笔记放在 vault 的哪个子目录？（直接回车 = vault 根目录）: " sub_folder
                if [ -n "$sub_folder" ]; then
                    sed -i '' \
                        '/obsidian:/,/raw_markdown:/{
                            s|notes_folder: ""|notes_folder: "'"$sub_folder"'"|
                        }' "$config"
                    log "笔记子目录: $sub_folder"
                fi
            else
                warn "路径 '$vault_input' 不存在，跳过（可稍后手动编辑 $config）"
            fi
        fi
    else
        log "Obsidian vault 已配置: $vault_path"
    fi

    # ── Step 5: 可选 launchd ─────────────────────────────
    section "Step 5: （可选）配置全自动同步"
    info "launchd 服务可在 iPhone 录音同步到 Mac 后自动处理（无需手动触发）"
    read -r -p "  是否现在配置 launchd 自动同步？[y/N] " want_launchd
    if [[ "${want_launchd:-N}" =~ ^[Yy] ]]; then
        local plist_src="$SCRIPT_DIR/com.voice-memo-sync.plist"
        local plist_dst="$HOME/Library/LaunchAgents/com.voice-memo-sync.plist"

        sed "s/YOUR_USERNAME/$(whoami)/g" "$plist_src" > "$plist_dst"
        launchctl bootstrap gui/$(id -u) "$plist_dst" 2>/dev/null || true
        log "launchd 服务已启动"
        info "查看状态: launchctl print gui/\$(id -u)/com.voice-memo-sync"
    else
        info "已跳过（可稍后参考 README.md 手动配置）"
    fi

    # ── 完成安装 ──────────────────────────────────────────
    section "完成安装"
    finish_install
}

# ── 入口 ─────────────────────────────────────────────────
case "${1:-}" in
    --check)
        check_status
        ;;
    --finish)
        finish_install
        ;;
    "")
        # 判断是否已经安装过
        if [ ! -f "$BACK_SKILL_MD" ] && ! head -40 "$SKILL_MD" 2>/dev/null | grep -q "Voice Memo Sync — 首次安装引导"; then
            info "Voice Memo Sync 已安装完成，运行 --check 查看状态"
            exit 0
        fi
        interactive_install
        ;;
    *)
        echo "Usage: bash first-run.sh [--check | --finish]"
        exit 1
        ;;
esac
