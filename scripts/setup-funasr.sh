#!/bin/bash
# FunASR 一键安装脚本
# 在全新 Mac 上一键安装 FunASR 语音转录引擎（含说话人识别）
# 不需要预装 Python，所有依赖安装到隔离目录，不污染系统环境
#
# Usage: bash setup-funasr.sh [--install-dir /path] [--skip-models]
#
set -euo pipefail

INSTALL_DIR="${FUNASR_HOME:-$HOME/.funasr}"
SKIP_MODELS=false
MIRROR="https://mirror.sjtu.edu.cn/pypi/web/simple"
PYTHON_VERSION="3.10.14"
PYTHON_MAJOR="3.10"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --install-dir) INSTALL_DIR="$2"; shift 2 ;;
        --skip-models) SKIP_MODELS=true; shift ;;
        --help) echo "Usage: bash setup-funasr.sh [--install-dir /path] [--skip-models]"; exit 0 ;;
        *) echo "Unknown argument: $1"; exit 1 ;;
    esac
done

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log()  { echo -e "${GREEN}[FunASR Setup]${NC} $1"; }
info() { echo -e "${BLUE}[FunASR Setup]${NC} $1"; }
warn() { echo -e "${YELLOW}[FunASR Setup]${NC} $1"; }
err()  { echo -e "${RED}[FunASR Setup]${NC} $1"; exit 1; }

ARCH=$(uname -m)
OS=$(uname -s)

if [ "$OS" != "Darwin" ]; then
    err "This script only supports macOS. For Linux, install manually."
fi

log "=== FunASR 一键安装 ==="
log "安装目录: $INSTALL_DIR"
log "系统: macOS $(sw_vers -productVersion) ($ARCH)"

# ── 已安装检测：FUNASR_ENV 指向现有 venv 时直接跳过 ──────
if [ -n "${FUNASR_ENV:-}" ]; then
    _existing_venv="$FUNASR_ENV"
    if [ -x "$_existing_venv/bin/python3" ] && "$_existing_venv/bin/python3" -c "import funasr" 2>/dev/null; then
        log "检测到 FUNASR_ENV 指向已安装的 FunASR: $_existing_venv"
        log "跳过重新安装 ✅"
        # 同步 INSTALL_DIR 指向 venv 的父目录，写入 env.sh 供后续脚本引用
        _existing_home="$(dirname "$_existing_venv")"
        ENV_FILE="$_existing_home/env.sh"
        if [ ! -f "$ENV_FILE" ]; then
            cat > "$ENV_FILE" << ENVEOF
# FunASR 环境配置 - source 此文件激活环境
export FUNASR_HOME="$_existing_home"
export FUNASR_ENV="$_existing_venv"
export MODELSCOPE_CACHE="$_existing_home/models"
export PATH="$_existing_venv/bin:\$PATH"
ENVEOF
            log "env.sh 已生成: $ENV_FILE"
        fi
        exit 0
    else
        warn "FUNASR_ENV=$_existing_venv 不可用（路径不存在或 funasr 未安装），继续全新安装"
    fi
fi

mkdir -p "$INSTALL_DIR"

# ── Step 1: 检查/安装 standalone Python ─────────────────────
PYTHON_BIN="$INSTALL_DIR/python/bin/python3"

if [ -x "$PYTHON_BIN" ] && "$PYTHON_BIN" --version | grep -q "$PYTHON_MAJOR"; then
    log "Python $PYTHON_MAJOR 已安装: $PYTHON_BIN"
else
    log "下载 Python $PYTHON_VERSION (standalone, 不影响系统)..."

    if [ "$ARCH" = "arm64" ]; then
        PY_URL="https://github.com/indygreg/python-build-standalone/releases/download/20240415/cpython-${PYTHON_VERSION}+20240415-aarch64-apple-darwin-install_only.tar.gz"
    else
        PY_URL="https://github.com/indygreg/python-build-standalone/releases/download/20240415/cpython-${PYTHON_VERSION}+20240415-x86_64-apple-darwin-install_only.tar.gz"
    fi

    PY_TAR="$INSTALL_DIR/python.tar.gz"
    curl -L --progress-bar -o "$PY_TAR" "$PY_URL" || {
        warn "GitHub 下载失败，尝试镜像源..."
        curl -L --progress-bar -o "$PY_TAR" \
            "https://ghp.ci/${PY_URL}" || err "Python 下载失败"
    }

    log "解压 Python..."
    mkdir -p "$INSTALL_DIR/python-tmp"
    tar xzf "$PY_TAR" -C "$INSTALL_DIR/python-tmp" --strip-components=1
    mv "$INSTALL_DIR/python-tmp" "$INSTALL_DIR/python"
    rm -f "$PY_TAR"

    PYTHON_BIN="$INSTALL_DIR/python/bin/python3"
    [ -x "$PYTHON_BIN" ] || err "Python 安装失败"
    log "Python $PYTHON_VERSION 安装完成"
fi

# ── Step 2: 创建隔离 venv ─────────────────────────────────
VENV_DIR="$INSTALL_DIR/venv"

if [ -x "$VENV_DIR/bin/python3" ]; then
    log "虚拟环境已存在: $VENV_DIR"
else
    log "创建隔离虚拟环境..."
    "$PYTHON_BIN" -m venv "$VENV_DIR"
    log "虚拟环境创建完成"
fi

export PATH="$VENV_DIR/bin:$PATH"

# ── Step 3: 安装 pip 依赖 ─────────────────────────────────
log "安装 Python 依赖（国内镜像源）..."
pip install --upgrade pip -i "$MIRROR" -q
pip install torch torchaudio funasr modelscope -i "$MIRROR" || {
    warn "国内镜像安装失败，尝试官方源..."
    pip install torch torchaudio funasr modelscope
}

log "Python 依赖安装完成"
pip list | grep -E "funasr|torch|modelscope"

# ── Step 4: 预下载模型 ─────────────────────────────────────
if [ "$SKIP_MODELS" = true ]; then
    warn "跳过模型下载 (--skip-models)"
    warn "模型将在首次转录时自动下载（约 2GB）"
else
    log "预下载 ASR 模型（首次约 2GB，后续秒完成）..."

    export MODELSCOPE_CACHE="$INSTALL_DIR/models"

    "$VENV_DIR/bin/python3" -c "
import os, sys
os.environ['MODELSCOPE_CACHE'] = '$INSTALL_DIR/models'
os.environ['FUNASR_DISABLE_UPDATE'] = '1'

from funasr import AutoModel

print('Loading Paraformer + VAD + PUNC + cam++ (diarization)...')
model = AutoModel(
    model='paraformer-zh',
    vad_model='fsmn-vad',
    punc_model='ct-punc',
    spk_model='cam++',
    device='cpu',
    disable_update=True,
)
print('All models loaded successfully!')
" || err "模型下载失败，请检查网络连接"

    log "模型预下载完成"
fi

# ── Step 5: 写入环境配置 ───────────────────────────────────
ENV_FILE="$INSTALL_DIR/env.sh"
cat > "$ENV_FILE" << ENVEOF
# FunASR 环境配置 - source 此文件激活环境
# Usage: source $INSTALL_DIR/env.sh

export FUNASR_HOME="$INSTALL_DIR"
export FUNASR_ENV="$INSTALL_DIR/venv"
export MODELSCOPE_CACHE="$INSTALL_DIR/models"
export PATH="$INSTALL_DIR/venv/bin:\$PATH"
ENVEOF

log "环境配置已写入: $ENV_FILE"

# ── Step 6: 验证安装 ───────────────────────────────────────
log "验证安装..."
source "$ENV_FILE"

python3 -c "import funasr; print(f'FunASR {funasr.__version__} OK')" || err "FunASR 导入失败"
python3 -c "import torch; print(f'PyTorch {torch.__version__} OK')" || err "PyTorch 导入失败"

# ── 完成 ───────────────────────────────────────────────────
echo ""
log "✅ FunASR 安装完成！"
echo ""
echo -e "${GREEN}使用方式:${NC}"
echo ""
echo "  # 激活环境（每次新终端需执行）"
echo "  source $INSTALL_DIR/env.sh"
echo ""
echo "  # 转录音频（含说话人识别）"
echo "  python3 $(dirname "$0")/funasr_transcribe.py --input audio.m4a --output-dir ./out --diarize"
echo ""
echo "  # 或设置环境变量后直接使用 skill 脚本"
echo "  export FUNASR_ENV=$INSTALL_DIR/venv"
echo ""
echo -e "${GREEN}磁盘占用:${NC}"
du -sh "$INSTALL_DIR" 2>/dev/null
echo ""
echo -e "${YELLOW}卸载: rm -rf $INSTALL_DIR${NC}"
