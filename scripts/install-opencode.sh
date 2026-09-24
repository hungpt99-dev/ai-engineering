#!/usr/bin/env bash
# Install OpenCode (Linux / macOS / WSL)
# Verified 2026-09: https://opencode.ai/docs  -> curl -fsSL https://opencode.ai/install | bash
# Fallbacks: npm, brew
set -euo pipefail

GREEN="\033[0;32m"; YELLOW="\033[0;33m"; RED="\033[0;31m"; NC="\033[0m"
ok() { echo -e "${GREEN}[ok]${NC} $*"; }
warn() { echo -e "${YELLOW}[warn]${NC} $*"; }
fail() { echo -e "${RED}[fail]${NC} $*" >&2; }

need_cmd() { command -v "$1" >/dev/null 2>&1; }

if need_cmd opencode; then ok "opencode already installed: $(opencode --version 2>&1 | head -1)"; exit 0; fi

if need_cmd curl; then
  echo "[info] Installing via https://opencode.ai/install …"
  curl -fsSL https://opencode.ai/install | bash
  if need_cmd opencode; then ok "opencode installed: $(opencode --version 2>&1 | head -1)"; exit 0; fi
  warn "curl install did not place opencode on PATH, trying npm fallback…"
fi

if need_cmd npm; then
  echo "[info] Installing via npm: npm install -g opencode-ai …"
  npm install -g opencode-ai
  need_cmd opencode && ok "opencode installed via npm: $(opencode --version 2>&1 | head -1)" || { fail "npm install succeeded but opencode not on PATH"; exit 1; }
  exit 0
fi

# brew fallback
if need_cmd brew; then
  echo "[info] Installing via brew: brew install anomalyco/tap/opencode …"
  brew install anomalyco/tap/opencode
  need_cmd opencode && ok "opencode installed via brew" || { fail "brew install failed"; exit 1; }
  exit 0
fi

fail "No install method succeeded. Manual install: curl -fsSL https://opencode.ai/install | bash  OR  npm install -g opencode-ai"
exit 1
