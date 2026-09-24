#!/usr/bin/env bash
# AI Engineering — Unified Setup (Linux / macOS / WSL)
# Usage:
#   ./setup/install.sh            # interactive
#   ./setup/install.sh --check    # only validate, do not install
#   ./setup/install.sh --yes      # non-interactive defaults
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
YES="${YES:-false}"
CHECK_ONLY=false
HOST="opencode"
TRACKER="redmine"
for arg in "$@"; do
  case "$arg" in
    --check) CHECK_ONLY=true ;;
    --yes) YES=true ;;
    --host=*) HOST="${arg#--host=}" ;;
    --tracker=*) TRACKER="${arg#--tracker=}" ;;
  esac
done
# Backward compat: positional --yes
if [[ "${1:-}" == "--yes" || "${2:-}" == "--yes" ]]; then YES=true; fi

# Colors
GREEN="\033[0;32m"; YELLOW="\033[0;33m"; RED="\033[0;31m"; CYAN="\033[0;36m"; NC="\033[0m"
info()  { echo -e "${CYAN}[info]${NC} $*"; }
ok()    { echo -e "${GREEN}[ok]${NC} $*"; }
warn()  { echo -e "${YELLOW}[warn]${NC} $*"; }
fail()  { echo -e "${RED}[fail]${NC} $*" >&2; }

need_cmd() { command -v "$1" >/dev/null 2>&1; }

echo ""
echo "=== AI Engineering Setup ==="
echo "Root: $ROOT"
echo "Host: $HOST  Tracker: $TRACKER  (hosts: opencode|claude|codex|all, trackers: redmine|jira|both|none)"
echo ""

if [[ "$CHECK_ONLY" == true ]]; then
  exec bash "$ROOT/setup/check.sh"
fi

# 1. Prereqs (WSL-safe: node.exe fallback)
info "Checking prerequisites…"
missing=0
node_cmd="node"
if ! need_cmd node && need_cmd node.exe; then node_cmd="node.exe"; fi
for cmd in git curl node npm; do
  if need_cmd "$cmd" || need_cmd "$cmd.exe"; then
    ver="$($cmd --version 2>&1 | head -1 || $cmd.exe --version 2>&1 | head -1 || echo found)"
    ok "$cmd: $(command -v "$cmd" 2>/dev/null || command -v "$cmd.exe") ($ver)"
  else warn "$cmd not found"; missing=1; fi
done
if ! need_cmd node && ! need_cmd node.exe; then
  fail "Node.js >=18 is required (for MCP adapters). Install from https://nodejs.org then re-run."
  exit 1
fi
NODE_MAJOR="$($node_cmd -p 'process.versions.node.split(".")[0]' 2>/dev/null || echo 0)"
if [[ "$NODE_MAJOR" -lt 18 ]]; then fail "Node >=18 required, found $NODE_MAJOR"; exit 1; fi
if ! need_cmd bun; then warn "bun not found — will try npm/npx fallback for Oh My OpenAgent (bun is recommended: curl -fsSL https://bun.sh/install | bash)"; else ok "bun: $(bun --version)"; fi
echo ""

# 2. Host runtime
if [[ "$HOST" == "opencode" || "$HOST" == "all" ]]; then
  info "Step 1/5 — OpenCode"
  if need_cmd opencode; then ok "OpenCode already installed: $(opencode --version 2>&1 | head -1)"; else
    info "Installing OpenCode via https://opencode.ai/install …"
    if need_cmd curl; then curl -fsSL https://opencode.ai/install | bash; else fail "curl required to install OpenCode"; exit 1; fi
    if ! need_cmd opencode; then
      warn "curl install did not place opencode on PATH, trying npm fallback…"
      npm install -g opencode-ai
    fi
    need_cmd opencode && ok "OpenCode installed: $(opencode --version 2>&1 | head -1)" || { fail "OpenCode install failed"; exit 1; }
  fi
  echo ""
  info "Step 2/5 — Oh My OpenAgent (Ultimate for OpenCode)"
  if [[ "$YES" == true ]]; then
    warn "--yes: skipping interactive Oh My OpenAgent TUI. Run manually: bunx oh-my-openagent install"
  else
    if need_cmd bun; then
      info "Launching: bunx oh-my-openagent install (TUI will guide you — plugin + models + auth)"
      info "If you prefer non-interactive, run: bunx oh-my-openagent install --help"
      bunx oh-my-openagent install || warn "Oh My OpenAgent install exited with error — you can re-run: bunx oh-my-openagent install"
      if grep -q "oh-my-openagent" "$ROOT/opencode.json" 2>/dev/null; then ok "opencode.json already registers oh-my-openagent plugin"; else info "Ensure opencode.json contains \"plugin\": [\"oh-my-openagent\"]"; fi
      if need_cmd opencode; then
        info "Running: bunx oh-my-openagent doctor (optional)"
        bunx oh-my-openagent doctor --json 2>&1 | head -n 50 || true
      fi
    else
      warn "bun not found — install bun first, then run: bunx oh-my-openagent install"
      warn "Docs: https://raw.githubusercontent.com/code-yeongyu/oh-my-openagent/refs/heads/dev/docs/guide/installation.md"
    fi
  fi
  echo ""
elif [[ "$HOST" == "claude" ]]; then
  info "Step 1-2/5 — Claude Code (host=claude)"
  if need_cmd claude; then ok "Claude Code already installed: $(claude --version 2>&1 | head -1)"; else warn "Claude Code not found — install: npm install -g @anthropic-ai/claude-code (https://code.claude.com/docs)"; fi
  echo ""
elif [[ "$HOST" == "codex" ]]; then
  info "Step 1-2/5 — Codex CLI (host=codex)"
  if need_cmd codex; then ok "Codex already installed: $(codex --version 2>&1 | head -1)"; else warn "Codex not found — install: npm install -g @openai/codex (https://developers.openai.com/codex)"; fi
  echo ""
else
  warn "Unknown host $HOST — skipping host install (valid: opencode|claude|codex|all)"
  echo ""
fi

# 3. Host-agnostic skills/agents sync (ensures .claude/.agents exist for non-OpenCode hosts)
if [[ "$HOST" != "opencode" ]]; then
  info "Syncing skills/agents to host locations (host=$HOST)"
  bash "$ROOT/scripts/sync-hosts.sh" --host="$HOST" || warn "sync-hosts failed"
  echo ""
fi

# 4. MCP adapters (Dify + tracker: $TRACKER)
info "Step 3/5 — MCP adapters (tracker=$TRACKER)"
bash "$ROOT/scripts/install-mcp.sh" --tracker="$TRACKER" 2>/dev/null || bash "$ROOT/scripts/install-mcp.sh"
echo ""

# 5. Credentials (.env)
info "Step 4/5 — Credentials"
if [[ -f "$ROOT/.env" ]]; then ok ".env already exists — leaving as is (edit manually or run scripts/configure.sh)"; else
  if [[ -f "$ROOT/.env.example" ]]; then cp "$ROOT/.env.example" "$ROOT/.env"; ok "Created .env from .env.example — EDIT IT with real credentials"; else warn "No .env.example found"; fi
  if [[ "$YES" != true ]]; then
    info "Run scripts/configure.sh to set DIFY_BASE_URL / DIFY_API_KEY / REDMINE_* / provider keys."
  fi
fi
echo ""

# 6. Validate
info "Step 5/5 — Validation"
bash "$ROOT/setup/check.sh" || warn "Validation reported issues — see above"
echo ""

# 7. Optional global install (so sibling app repos reuse config)
if [[ "${YES}" != true ]]; then
  info "To make this harness available in ANY app repo (sibling clones), install globally: bash ./scripts/install-global.sh"
  info "  (copies opencode.json + .opencode/agents/skills/commands + AGENTS.md to ~/.config/opencode)"
  info "  Skip this if you keep app code inside this repo or prefer per-project copy."
fi
echo ""

cat <<NEXT
Next steps:
  1. Edit .env               — fill DIFY_BASE_URL, DIFY_API_KEY, tracker creds (REDMINE_* or JIRA_*), provider keys
     Tracker in use: $TRACKER  (edit .env or run: ./setup/install.sh --tracker=jira)
  2. Validate                — ./setup/check.sh --tracker=$TRACKER  (or .\setup\check.ps1 -Tracker $TRACKER on Windows)
  3. Sync hosts (if you switch host) — ./scripts/sync-hosts.sh --host=$HOST
  4. Start $HOST             — $(case $HOST in opencode) echo opencode;; claude) echo "claude  (or opencode if both)"; echo "     - Try: /skills, claude mcp list";; codex) echo "codex  — Try: /skills, codex mcp list";; all) echo "opencode / claude / codex  (all hosts synced)"; ;; esac)
     - In TUI: Tab switches agents (developer / researcher / reviewer)
     - Try:  @researcher explore this repo
             search_knowledge query="architecture"  (via Dify MCP)
  5. Clone any app repo next to this one and start the host inside it:
       git clone <app-repo> ../my-app && cd ../my-app && $HOST

Docs: docs/setup.md  docs/architecture.md  docs/workflow.md  config/hosts/README.md  config/trackers/
NEXT
