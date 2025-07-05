#!/usr/bin/env bash
# ------------------------------------------------------------
# Renda Cloud Lab · check-tools.sh
# 功能：检查并自动安装本地 CLI 工具链 (aws, terraform, eksctl, kubectl, helm)
# Usage: bash scripts/check-tools.sh [--auto] [--log] [--dry-run]
# ------------------------------------------------------------
set -euo pipefail

AUTO=0
LOG=0
DRY_RUN=0
LOG_FILE="scripts/logs/check-tools.log"

# --- 参数解析 ---
while [ $# -gt 0 ]; do
  case "$1" in
    --auto) AUTO=1 ;;
    --log) LOG=1 ;;
    --dry-run) DRY_RUN=1 ;;
    *) echo "Usage: $0 [--auto] [--log] [--dry-run]"; exit 1 ;;
  esac
  shift
done

[ $LOG -eq 1 ] && mkdir -p "$(dirname "$LOG_FILE")" && : > "$LOG_FILE"

log(){
  echo "$*"
  [ $LOG -eq 1 ] && echo "$*" >> "$LOG_FILE"
}

# --- 平台识别 ---
detect_platform(){
  local uname_out
  uname_out="$(uname -s)"
  case "$uname_out" in
    Darwin) echo macos ;;
    Linux)
      if grep -qi microsoft /proc/version 2>/dev/null; then
        echo wsl
      elif command -v apt-get >/dev/null 2>&1; then
        echo ubuntu
      else
        echo other-linux
      fi
      ;;
    *) echo windows ;;
  esac
}

PLATFORM="$(detect_platform)"
case "$PLATFORM" in
  macos)
    log "✅ Detected macOS. Homebrew will be used for installation."
    ;;
  wsl)
    log "✅ Detected Windows WSL (Ubuntu). apt 或 curl 安装."
    ;;
  ubuntu)
    log "🟡 Detected Ubuntu/Debian. Supported but experimental."
    ;;
  other-linux)
    log "❌ Unsupported Linux distribution. Please install tools manually."; exit 1 ;;
  windows)
    log "❌ Windows 原生终端暂不支持，请在 WSL 中运行。"; exit 1 ;;
  *) log "❌ 未识别的平台，脚本退出。"; exit 1 ;;
esac

# --- 安装函数 ---
install_tool(){
  local tool="$1"
  if [ $DRY_RUN -eq 1 ]; then
    log "[dry-run] would install $tool"
    return
  fi
  case "$PLATFORM" in
    macos)
      case "$tool" in
        terraform) brew install hashicorp/tap/terraform ;;
        *) brew install "$tool" ;;
      esac
      ;;
    wsl|ubuntu)
      sudo apt-get update -y
      if sudo apt-get install -y "$tool" 2>/dev/null; then
        return
      fi
      case "$tool" in
        terraform)
          tmp=/tmp/terraform.zip
          curl -Ls -o "$tmp" https://releases.hashicorp.com/terraform/1.8.5/terraform_1.8.5_linux_amd64.zip
          unzip -o "$tmp" -d /tmp
          sudo mv /tmp/terraform /usr/local/bin/
          rm -f "$tmp"
          ;;
        eksctl)
          curl -Ls https://github.com/eksctl-io/eksctl/releases/latest/download/eksctl_Linux_amd64.tar.gz -o /tmp/eksctl.tar.gz
          tar -xzf /tmp/eksctl.tar.gz -C /tmp
          sudo mv /tmp/eksctl /usr/local/bin/
          rm -f /tmp/eksctl.tar.gz
          ;;
        *)
          log "无法自动安装 $tool，请手动安装。"
          ;;
      esac
      ;;
  esac
}

check_tool(){
  local tool="$1"
  if command -v "$tool" >/dev/null 2>&1; then
    local version path
    case "$tool" in
      aws) version=$(aws --version 2>&1 | head -n1) ;;
      terraform) version=$(terraform version | head -n1) ;;
      eksctl) version=$(eksctl version) ;;
      kubectl) version=$(kubectl version --client --short) ;;
      helm) version=$(helm version --short) ;;
    esac
    path=$(command -v "$tool")
    log "✅ $tool: $version ($path)"
  else
    log "❌ 未检测到 $tool 工具"
    if [ $AUTO -eq 1 ]; then
      install_tool "$tool"
    else
      if [ $DRY_RUN -eq 0 ]; then
        read -r -p "是否现在自动安装？(y/N): " ans
        if [ "${ans}" = "y" ] || [ "${ans}" = "Y" ]; then
          install_tool "$tool"
        fi
      fi
    fi
  fi
}

for t in aws terraform eksctl kubectl helm; do
  check_tool "$t"
done

log "✅ 工具检查完成"
