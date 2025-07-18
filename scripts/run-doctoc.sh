#!/usr/bin/env bash
# ------------------------------------------------------------
# Renda Cloud Lab · run-doctoc.sh
# 功能：在提交前自动更新 README 与 docs 目录下文档的目录
# Usage: bash scripts/run-doctoc.sh
# ------------------------------------------------------------
set -euo pipefail

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

root="$(git rev-parse --show-toplevel)"

cd "$root" || { log "Failed to change to directory: $root"; exit 1; }

if ! command -v doctoc >/dev/null 2>&1; then
  log "SKIP: doctoc not installed"
  exit 0
fi

log "Running doctoc on README.md and docs/*.md..."
doctoc README.md docs/*.md || { log "Failed to run doctoc"; exit 1; }
git add README.md docs/*.md || { log "ERROR: Failed to stage changes"; exit 1; }
