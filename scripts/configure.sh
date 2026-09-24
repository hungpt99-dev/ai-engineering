#!/usr/bin/env bash
# Interactive credentials configurator — writes .env without ever printing secrets
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TGT="$ROOT/.env"
EXAMPLE="$ROOT/.env.example"

GREEN="\033[0;32m"; YELLOW="\033[0;33m"; CYAN="\033[0;36m"; NC="\033[0m"

if [[ ! -f "$EXAMPLE" ]]; then echo "[fail] .env.example missing"; exit 1; fi
if [[ ! -f "$TGT" ]]; then cp "$EXAMPLE" "$TGT"; echo -e "${CYAN}[info]${NC} Created .env from .env.example"; fi

# Load current (for defaults display — show only length, not value)
set -a; source "$TGT" 2>/dev/null || true; set +a

mask_len() { local v="${1:-}"; if [[ -z "$v" ]]; then echo "not set"; else echo "set (${#v} chars)"; fi; }

echo "=== Configure AI Engineering (.env) ==="
echo "Secrets are NOT echoed. Press Enter to keep current value."
echo ""

prompt_secret() {
  local key="$1" desc="$2" cur="${!1:-}"
  echo -e "${CYAN}$desc${NC}"
  echo "  Current: $(mask_len "$cur")"
  read -rsp "  New value (or Enter to keep): " val; echo ""
  if [[ -n "$val" ]]; then
    # escape for .env (simple)
    # Update or append
    if grep -q "^${key}=" "$TGT"; then
      # Use | as delimiter to avoid / issues
      # Need to escape & and \ for sed
      esc=$(printf '%s' "$val" | sed 's/[&\\/]/\\&/g')
      # macOS sed -i needs '' ; GNU needs no arg ; handle both
      if sed --version >/dev/null 2>&1; then sed -i "s|^${key}=.*|${key}=${esc}|" "$TGT"; else sed -i '' "s|^${key}=.*|${key}=${esc}|" "$TGT"; fi
    else
      printf '%s=%s\n' "$key" "$val" >> "$TGT"
    fi
    echo -e "${GREEN}  → updated $key${NC}"
  else
    echo "  → kept"
  fi
  echo ""
}

prompt_value() {
  local key="$1" desc="$2" cur="${!1:-}"
  echo -e "${CYAN}$desc${NC}"
  echo "  Current: ${cur:-not set}"
  read -rp "  New value (or Enter to keep): " val
  if [[ -n "$val" ]]; then
    esc=$(printf '%s' "$val" | sed 's/[&\\/]/\\&/g')
    if grep -q "^${key}=" "$TGT"; then
      if sed --version >/dev/null 2>&1; then sed -i "s|^${key}=.*|${key}=${esc}|" "$TGT"; else sed -i '' "s|^${key}=.*|${key}=${esc}|" "$TGT"; fi
    else printf '%s=%s\n' "$key" "$val" >> "$TGT"; fi
    echo -e "${GREEN}  → updated $key${NC}"
  else echo "  → kept"; fi
  echo ""
}

prompt_value  "DIFY_BASE_URL"        "Dify Base URL (e.g. https://api.dify.ai/v1 or https://dify.company.com/v1)"
prompt_secret "DIFY_API_KEY"         "Dify Dataset API key (Dify Console → Knowledge → Service API)"
echo "--- Task Tracker (Redmine OR Jira) ---"
prompt_value  "REDMINE_URL"          "Redmine URL (e.g. https://redmine.company.com) — leave empty if using Jira"
prompt_secret "REDMINE_API_KEY"      "Redmine API key (My account → API access key)"
prompt_value  "REDMINE_MCP_READ_ONLY" "Redmine read-only (true/false, recommended true)"
prompt_value  "JIRA_BASE_URL"        "Jira Cloud URL (e.g. https://your-domain.atlassian.net) — leave empty if using Redmine"
prompt_value  "JIRA_EMAIL"           "Jira email (for Cloud)"
prompt_secret "JIRA_API_TOKEN"       "Jira API token (id.atlassian.com → Security → Create API token)"
echo "--- LLM Providers (at least one) ---"
prompt_secret "ANTHROPIC_API_KEY"    "Anthropic API key"
prompt_secret "OPENAI_API_KEY"       "OpenAI API key"

echo "=== Done ==="
echo -e "${GREEN}.env updated at $TGT${NC}"
echo "Validate with: ./setup/check.sh"
echo -e "${YELLOW}Never commit .env — it is gitignored.${NC}"
