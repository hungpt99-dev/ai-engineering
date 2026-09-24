#!/usr/bin/env bash
# Install / build MCP adapters
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GREEN="\033[0;32m"; YELLOW="\033[0;33m"; NC="\033[0m"

echo "[info] Building Dify Knowledge MCP…"
if [[ ! -f "$ROOT/mcp/dify-knowledge/package.json" ]]; then echo "[fail] mcp/dify-knowledge/package.json missing"; exit 1; fi
# Enforce Node >=18 (WSL-safe)
NODE_CMD="node"
if ! command -v node >/dev/null 2>&1 && command -v node.exe >/dev/null 2>&1; then NODE_CMD="node.exe"; fi
MAJ="$($NODE_CMD -p 'process.versions.node.split(".")[0]' 2>/dev/null || echo 0)"
if [[ "$MAJ" -lt 18 ]]; then echo "[fail] Node >=18 required (found $MAJ)"; exit 1; fi
# Install deps
if [[ ! -d "$ROOT/mcp/dify-knowledge/node_modules" ]]; then (cd "$ROOT/mcp/dify-knowledge" && npm install); else echo "[info] mcp/dify-knowledge deps already installed"; fi
# Build
(cd "$ROOT/mcp/dify-knowledge" && npm run build)
echo -e "${GREEN}[ok]${NC} Dify MCP built: mcp/dify-knowledge/dist/index.js"

# Verify Redmine MCP resolvable (npx will fetch on demand)
echo "[info] Verifying Redmine MCP package (npx cache)…"
if npx --yes @onozaty/redmine-mcp-server --help >/dev/null 2>&1; then echo -e "${GREEN}[ok]${NC} Redmine MCP package resolvable"; else echo -e "${YELLOW}[warn]${NC} Redmine MCP not yet cached — will be fetched on first OpenCode run via npx (requires network)"; fi

# Quick config sanity (fallback to grep if node missing)
if command -v node >/dev/null 2>&1; then
  if node -e "const j=require('$ROOT/opencode.json'); if(!j.mcp||!j.mcp['dify-knowledge']||!j.mcp['redmine']) throw 1" 2>/dev/null; then echo -e "${GREEN}[ok]${NC} opencode.json mcp entries present"; else echo -e "${YELLOW}[warn]${NC} opencode.json missing mcp entries — check config/opencode/opencode.example.json"; fi
elif command -v node.exe >/dev/null 2>&1; then
  if node.exe -e "const j=require('$ROOT/opencode.json'); if(!j.mcp||!j.mcp['dify-knowledge']||!j.mcp['redmine']) throw 1" 2>/dev/null; then echo -e "${GREEN}[ok]${NC} opencode.json mcp entries present"; else echo -e "${YELLOW}[warn]${NC} opencode.json missing mcp entries — check config/opencode/opencode.example.json"; fi
else
  if grep -q "dify-knowledge" "$ROOT/opencode.json" && grep -q "redmine" "$ROOT/opencode.json"; then echo -e "${GREEN}[ok]${NC} opencode.json mcp entries present (grep)"; else echo -e "${YELLOW}[warn]${NC} opencode.json missing mcp entries"; fi
fi
