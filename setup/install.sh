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
if [[ "${1:-}" == "--check" ]]; then CHECK_ONLY=true; fi
if [[ "${1:-}" == "--yes" ]]; then YES=true; fi
if [[ "${2:-}" == "--yes" ]]; then YES=true; fi

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

# 2. OpenCode
info "Step 1/5 — OpenCode"
if need_cmd opencode; then ok "OpenCode already installed: $(opencode --version 2>&1 | head -1)"; else
  info "Installing OpenCode via https://opencode.ai/install …"
  if need_cmd curl; then curl -fsSL https://opencode.ai/install | bash; else fail "curl required to install OpenCode"; exit 1; fi
  # fallback to npm if curl install didn't put opencode on PATH
  if ! need_cmd opencode; then
    warn "curl install did not place opencode on PATH, trying npm fallback…"
    npm install -g opencode-ai
  fi
  need_cmd opencode && ok "OpenCode installed: $(opencode --version 2>&1 | head -1)" || { fail "OpenCode install failed"; exit 1; }
fi
echo ""

# 3. Oh My OpenAgent (Ultimate — OpenCode)
info "Step 2/5 — Oh My OpenAgent (Ultimate for OpenCode)"
if [[ "$YES" == true ]]; then
  warn "--yes: skipping interactive Oh My OpenAgent TUI. Run manually: bunx oh-my-openagent install"
else
  if need_cmd bun; then
    info "Launching: bunx oh-my-openagent install (TUI will guide you — plugin + models + auth)"
    info "If you prefer non-interactive, run: bunx oh-my-openagent install --help"
    bunx oh-my-openagent install || warn "Oh My OpenAgent install exited with error — you can re-run: bunx oh-my-openagent install"
    # Verify plugin registration
    if grep -q "oh-my-openagent" "$ROOT/opencode.json" 2>/dev/null; then ok "opencode.json already registers oh-my-openagent plugin"; else info "Ensure opencode.json contains \"plugin\": [\"oh-my-openagent\"] (this repo's template does)"; fi
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

# 4. MCP adapters
info "Step 3/5 — MCP adapters"
bash "$ROOT/scripts/install-mcp.sh"
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

cat <<'NEXT'
Next steps:
  1. Edit .env               — fill DIFY_BASE_URL, DIFY_API_KEY, REDMINE_URL, REDMINE_API_KEY, provider keys
  2. Validate                — ./setup/check.sh   (or .\setup\check.ps1 on Windows)
  3. Start OpenCode          — opencode
     - In TUI: Tab switches agents (developer / researcher / reviewer)
     - Try:  @researcher explore this repo
             search_knowledge query="architecture"  (via Dify MCP)
  4. Clone any app repo next to this one and start OpenCode inside it:
       git clone <app-repo> ../my-app && cd ../my-app && opencode

Docs: docs/setup.md  docs/architecture.md  docs/workflow.md
NEXT
