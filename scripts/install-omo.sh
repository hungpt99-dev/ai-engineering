#!/usr/bin/env bash
# Install Oh My OpenAgent (Ultimate for OpenCode)
# Package: oh-my-openagent  (legacy alias: oh-my-opencode) — verified npm 4.12.0 2026-09
# Docs: https://raw.githubusercontent.com/code-yeongyu/oh-my-openagent/refs/heads/dev/docs/guide/installation.md
set -euo pipefail

GREEN="\033[0;32m"; YELLOW="\033[0;33m"; RED="\033[0;31m"; NC="\033[0m"
need_cmd() { command -v "$1" >/dev/null 2>&1; }

if need_cmd bun; then
  echo "[info] Running: bunx oh-my-openagent install"
  echo "[info] TUI will walk you through plugin registration + provider auth. For CI use --help for non-interactive flags."
  bunx oh-my-openagent install
  echo ""
  # Verify
  if command -v opencode >/dev/null 2>&1; then
    echo "[info] Running doctor check…"
    bunx oh-my-openagent doctor --json 2>&1 | head -n 80 || true
  fi
  echo -e "${GREEN}[ok]${NC} Oh My OpenAgent install finished. Ensure opencode.json has \"plugin\": [\"oh-my-openagent\"]."
elif need_cmd npx; then
  echo -e "${YELLOW}[warn]${NC} bun not found — trying npx fallback (not officially supported for OmO Ultimate). Recommend: curl -fsSL https://bun.sh/install | bash"
  npx -y oh-my-openagent install || { echo -e "${RED}[fail]${NC} npx fallback failed. Install bun and re-run."; exit 1; }
else
  echo -e "${RED}[fail]${NC} Need bun or npx. Install bun: curl -fsSL https://bun.sh/install | bash"
  exit 1
fi
