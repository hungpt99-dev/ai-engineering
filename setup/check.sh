#!/usr/bin/env bash
# AI Engineering — Health Check (Linux / macOS / WSL)
# Validates installation without leaking secrets.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PASS=0; FAIL=0; WARN=0

GREEN="\033[0;32m"; YELLOW="\033[0;33m"; RED="\033[0;31m"; CYAN="\033[0;36m"; NC="\033[0m"
pass() { echo -e "${GREEN}✔ $*${NC}"; PASS=$((PASS+1)); }
fail() { echo -e "${RED}✘ $*${NC}"; FAIL=$((FAIL+1)); }
warn() { echo -e "${YELLOW}▲ $*${NC}"; WARN=$((WARN+1)); }
info() { echo -e "${CYAN}  $*${NC}"; }

need_cmd() { command -v "$1" >/dev/null 2>&1; }

echo "=== AI Engineering — Health Check ==="
echo "Root: $ROOT"
echo ""

# Load .env if present (do not export secrets to output)
if [[ -f "$ROOT/.env" ]]; then
  set -a
  # shellcheck disable=SC1091
  source "$ROOT/.env" 2>/dev/null || warn ".env parse warning"
  set +a
  pass ".env found"
else
  warn ".env not found — copy .env.example to .env and configure"
fi

# 1. System (WSL-safe: also check for *.exe)
node_cmd="node"
if ! need_cmd node && need_cmd node.exe; then node_cmd="node.exe"; fi
echo ""
echo "-- System --"
for cmd in git node npm; do
  # try plain and .exe variant (WSL)
  if need_cmd "$cmd" || need_cmd "$cmd.exe"; then
    ver="$($cmd --version 2>&1 2>/dev/null | head -1 || $cmd.exe --version 2>&1 | head -1 || echo "found")"
    pass "$cmd: $ver"
  else
    fail "$cmd not found"
  fi
done
if need_cmd node || need_cmd node.exe; then
  MAJ="$($node_cmd -p 'process.versions.node.split(".")[0]' 2>/dev/null || echo 0)"
  if [[ "$MAJ" -ge 18 ]]; then pass "node >=18 ($MAJ)"; else fail "node >=18 required (found $MAJ)"; fi
fi
need_cmd bun && pass "bun: $(bun --version 2>&1 | head -1)" || warn "bun not found (fallback to npx works)"
need_cmd curl && pass "curl: $(curl --version 2>&1 | head -1)" || warn "curl not found (needed for opencode install script)"

# 2. OpenCode
echo ""
echo "-- OpenCode --"
if need_cmd opencode; then
  pass "opencode: $(opencode --version 2>&1 | head -1)"
  # Validate opencode.json is valid JSON (node or python fallback)
  if [[ -f "$ROOT/opencode.json" ]]; then
    JSON_OK=false
    if need_cmd node; then
      if node -e "JSON.parse(require('fs').readFileSync('$ROOT/opencode.json','utf8'))" 2>/dev/null; then JSON_OK=true; fi
    elif need_cmd python3; then
      if python3 -m json.tool "$ROOT/opencode.json" >/dev/null 2>&1; then JSON_OK=true; fi
    elif need_cmd python; then
      if python -m json.tool "$ROOT/opencode.json" >/dev/null 2>&1; then JSON_OK=true; fi
    else
      warn "No JSON validator (node/python) — skipping opencode.json JSON check"
      JSON_OK=true
    fi
    if [[ "$JSON_OK" == true ]]; then pass "opencode.json: valid JSON"; else fail "opencode.json: invalid JSON"; fi
    # Check schema fields
    CHECKED=false
    if need_cmd node; then
      node -e "
        const j=require('$ROOT/opencode.json');
        const errs=[];
        if(!j['\$schema']) errs.push('missing \$schema');
        if(!j.mcp) errs.push('missing mcp');
        else { if(!j.mcp['dify-knowledge']) errs.push('missing mcp.dify-knowledge'); if(!j.mcp['redmine'] && !j.mcp['jira']) errs.push('missing mcp tracker (redmine or jira)'); }
        if(!j.agent || !j.agent.developer) errs.push('missing agent.developer');
        if(errs.length){ console.error(errs.join('; ')); process.exit(1); }
      " 2>&1 && pass "opencode.json: required keys present" || fail "opencode.json: missing required keys (see above)"
      CHECKED=true
    fi
    if [[ "$CHECKED" == false ]]; then
      if grep -q '"\$schema"' "$ROOT/opencode.json" && grep -q '"mcp"' "$ROOT/opencode.json" && grep -q '"developer"' "$ROOT/opencode.json"; then pass "opencode.json: required keys present (grep fallback)"; else warn "opencode.json: required keys check skipped (no node)"; fi
    fi
    # Check plugin
    if grep -q "oh-my-openagent" "$ROOT/opencode.json" 2>/dev/null; then pass "opencode.json: oh-my-openagent plugin registered"; else warn "opencode.json: oh-my-openagent plugin not found in plugin[]"; fi
  else fail "opencode.json not found at repo root"; fi

  # Agents & skills on disk
  for f in ".opencode/agents/developer.md" ".opencode/agents/researcher.md" ".opencode/agents/reviewer.md"; do
    [[ -f "$ROOT/$f" ]] && pass "$f present" || fail "$f missing"
  done
  for s in task-analysis codebase-exploration internal-knowledge implementation testing-debugging code-review; do
    [[ -f "$ROOT/.opencode/skills/$s/SKILL.md" ]] && pass "skill $s present" || fail "skill $s missing"
  done
  [[ -f "$ROOT/AGENTS.md" ]] && pass "AGENTS.md present" || fail "AGENTS.md missing"
else
  fail "opencode not found on PATH — run ./setup/install.sh"
fi

# 3. Oh My OpenAgent
echo ""
echo "-- Oh My OpenAgent --"
if need_cmd bun; then
  if bunx oh-my-openagent --help >/dev/null 2>&1 || npx -y oh-my-openagent --help >/dev/null 2>&1; then pass "oh-my-openagent CLI resolvable"; else warn "oh-my-openagent CLI not resolvable — run: bunx oh-my-openagent install"; fi
  # doctor if available (non-fatal)
  if bunx oh-my-openagent doctor --json >/dev/null 2>&1; then pass "oh-my-openagent doctor: ok" | head -1; else info "oh-my-openagent doctor: skip or not installed yet"; fi
else
  warn "bun missing — cannot verify oh-my-openagent"
fi

# 4. Dify MCP adapter
echo ""
echo "-- Dify Knowledge MCP --"
if [[ -f "$ROOT/mcp/dify-knowledge/package.json" ]]; then pass "mcp/dify-knowledge/package.json present"; else fail "mcp/dify-knowledge/package.json missing"; fi
if [[ -f "$ROOT/mcp/dify-knowledge/dist/index.js" ]]; then pass "mcp/dify-knowledge built (dist/index.js)"; else warn "mcp/dify-knowledge not built — run: npm --prefix mcp/dify-knowledge install && npm --prefix mcp/dify-knowledge run build"; fi
# Env presence (do not print values)
if [[ -n "${DIFY_BASE_URL:-}" ]]; then pass "DIFY_BASE_URL set"; else warn "DIFY_BASE_URL not set (in .env)"; fi
if [[ -n "${DIFY_API_KEY:-}" ]]; then pass "DIFY_API_KEY set (length ${#DIFY_API_KEY})"; else warn "DIFY_API_KEY not set"; fi
# Connectivity (only if both set, do not leak key)
if [[ -n "${DIFY_BASE_URL:-}" && -n "${DIFY_API_KEY:-}" ]]; then
  # Try list datasets with 1s timeout to avoid hang; treat 401 as fail but informative
  HTTP_CODE="$(curl -s -o /tmp/dify_check.json -w "%{http_code}" -H "Authorization: Bearer $DIFY_API_KEY" "$DIFY_BASE_URL/datasets?limit=1&page=1" --max-time 8 2>&1 || echo "curl_fail")"
  if [[ "$HTTP_CODE" == "200" ]]; then pass "Dify connectivity: 200 OK ($DIFY_BASE_URL)"; elif [[ "$HTTP_CODE" == "401" ]]; then fail "Dify connectivity: 401 Unauthorized — check DIFY_API_KEY"; elif [[ "$HTTP_CODE" == "403" ]]; then fail "Dify connectivity: 403 Forbidden — check API access / key scope"; elif [[ "$HTTP_CODE" == "curl_fail"* ]]; then warn "Dify connectivity: curl failed (network or URL?) — $HTTP_CODE"; else warn "Dify connectivity: HTTP $HTTP_CODE (see /tmp/dify_check.json)"; fi
fi

# 5. Task Tracker MCP (pluggable: Redmine and/or Jira)
echo ""
echo "-- Task Tracker MCP --"
# Redmine
echo "[tracker] Redmine"
if npx -y @onozaty/redmine-mcp-server --help >/dev/null 2>&1 || npm ls -g @onozaty/redmine-mcp-server >/dev/null 2>&1; then pass "Redmine MCP package resolvable (npx)"; else info "Redmine MCP not yet cached — will be fetched on first run via npx"; fi
if [[ -n "${REDMINE_URL:-}" ]]; then pass "REDMINE_URL set"; else warn "REDMINE_URL not set (set if using Redmine)"; fi
if [[ -n "${REDMINE_API_KEY:-}" ]]; then pass "REDMINE_API_KEY set (length ${#REDMINE_API_KEY})"; else warn "REDMINE_API_KEY not set"; fi
if [[ -n "${REDMINE_URL:-}" && -n "${REDMINE_API_KEY:-}" ]]; then
  CODE="$(curl -s -o /tmp/redmine_check.json -w "%{http_code}" -H "X-Redmine-API-Key: $REDMINE_API_KEY" "$REDMINE_URL/users/current.json" --max-time 8 2>&1 || echo "curl_fail")"
  if [[ "$CODE" == "200" ]]; then pass "Redmine connectivity: 200 OK ($REDMINE_URL)"; elif [[ "$CODE" == "401" ]]; then fail "Redmine connectivity: 401 Unauthorized — check REDMINE_API_KEY"; elif [[ "$CODE" == "403" ]]; then fail "Redmine connectivity: 403 Forbidden"; else warn "Redmine connectivity: HTTP $CODE (see /tmp/redmine_check.json)"; fi
fi
# Jira
echo "[tracker] Jira"
if npx -y @ahmetbarut/jira-mcp-server --help >/dev/null 2>&1 || npm ls -g @ahmetbarut/jira-mcp-server >/dev/null 2>&1; then pass "Jira MCP package resolvable (npx)"; else info "Jira MCP not yet cached — will be fetched on first run via npx"; fi
if [[ -n "${JIRA_BASE_URL:-}" ]]; then pass "JIRA_BASE_URL set"; else warn "JIRA_BASE_URL not set (set if using Jira Cloud)"; fi
if [[ -n "${JIRA_API_TOKEN:-}" ]]; then pass "JIRA_API_TOKEN set (length ${#JIRA_API_TOKEN})"; else warn "JIRA_API_TOKEN not set"; fi
if [[ -n "${JIRA_BASE_URL:-}" && -n "${JIRA_API_TOKEN:-}" ]]; then
  # Jira Cloud: GET /rest/api/3/myself  (or /rest/api/2/myself)
  CODE2="$(curl -s -o /tmp/jira_check.json -w "%{http_code}" -u "${JIRA_EMAIL:-}:${JIRA_API_TOKEN}" "$JIRA_BASE_URL/rest/api/3/myself" --max-time 8 2>&1 || echo "curl_fail")"
  if [[ "$CODE2" == "200" ]]; then pass "Jira connectivity: 200 OK ($JIRA_BASE_URL)"; elif [[ "$CODE2" == "401" ]]; then fail "Jira connectivity: 401 Unauthorized — check JIRA_EMAIL/JIRA_API_TOKEN"; elif [[ "$CODE2" == "403" ]]; then fail "Jira connectivity: 403 Forbidden"; else warn "Jira connectivity: HTTP $CODE2 (see /tmp/jira_check.json)"; fi
fi
# At least one tracker should be configured
if [[ -z "${REDMINE_URL:-}" && -z "${JIRA_BASE_URL:-}" ]]; then warn "No tracker configured — set REDMINE_URL or JIRA_BASE_URL in .env"; fi

# 6. Host sync (agnostic)
echo ""
echo "-- Host sync --"
if [[ -d "$ROOT/.claude/skills" ]]; then pass "Claude Code skills synced (.claude/skills)" ; else warn "Claude skills not synced — run scripts/sync-hosts.sh --host=claude"; fi
if [[ -d "$ROOT/.agents/skills" ]]; then pass "Codex/Agents skills synced (.agents/skills)"; else warn "Codex skills not synced — run scripts/sync-hosts.sh --host=codex"; fi
if [[ -f "$ROOT/.mcp.json" ]]; then pass "Claude .mcp.json present"; else info ".mcp.json not present (only needed for Claude host)"; fi
if [[ -f "$ROOT/.codex/config.toml" ]]; then pass "Codex .codex/config.toml present"; else info ".codex/config.toml not present (only needed for Codex host)"; fi

# Summary
echo ""
echo "================ Summary ================"
echo -e "${GREEN}PASS: $PASS${NC}  ${YELLOW}WARN: $WARN${NC}  ${RED}FAIL: $FAIL${NC}"
if [[ $FAIL -gt 0 ]]; then echo -e "${RED}Health check FAILED — fix FAIL items above.${NC}"; exit 1
elif [[ $WARN -gt 0 ]]; then echo -e "${YELLOW}Health check passed with warnings.${NC}"; exit 0
else echo -e "${GREEN}All checks passed.${NC}"; exit 0
fi
