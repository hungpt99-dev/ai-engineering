#!/usr/bin/env bash
# Install AI Engineering config globally so every app repo reuses it
# Copies opencode.json + .opencode/agents/skills/commands + AGENTS.md to ~/.config/opencode
# Existing global files are backed up with .bak timestamp.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GLOBAL="${XDG_CONFIG_HOME:-$HOME/.config}/opencode"
if [[ "$OSTYPE" == "msys"* || "$OSTYPE" == "cygwin"* ]]; then
  GLOBAL="$APPDATA/opencode"
fi
echo "[info] Installing global config to $GLOBAL"

mkdir -p "$GLOBAL/agents" "$GLOBAL/skills" "$GLOBAL/commands"

backup_if_exists() {
  local f="$1"
  if [[ -f "$f" ]]; then
    cp "$f" "$f.bak.$(date +%Y%m%d%H%M%S)"
    echo "[info] Backed up $f"
  fi
}

# opencode.json — merge plugin/mcp/agents into existing global if present, else copy
if [[ -f "$GLOBAL/opencode.json" ]]; then
  echo "[warn] $GLOBAL/opencode.json already exists — merging plugin/mcp/agent keys (manual review recommended)"
  backup_if_exists "$GLOBAL/opencode.json"
  # Use node to merge (prefer keeps existing model/provider)
  if command -v node >/dev/null 2>&1 || command -v node.exe >/dev/null 2>&1; then
    NODE_BIN="node"; command -v node >/dev/null 2>&1 || NODE_BIN="node.exe"
    $NODE_BIN -e "
      const fs=require('fs');
      const src=JSON.parse(fs.readFileSync('$ROOT/opencode.json','utf8'));
      const dst=JSON.parse(fs.readFileSync('$GLOBAL/opencode.json','utf8'));
      // ensure plugin includes oh-my-openagent
      dst.plugin = Array.from(new Set([...(dst.plugin||[]), ...(src.plugin||[])]));
      dst.mcp = { ...(dst.mcp||{}), ...(src.mcp||{}) };
      dst.agent = { ...(dst.agent||{}), ...(src.agent||{}) };
      dst.instructions = Array.from(new Set([...(dst.instructions||[]), ...(src.instructions||[])]));
      if(!dst['\$schema']) dst['\$schema']=src['\$schema'];
      fs.writeFileSync('$GLOBAL/opencode.json', JSON.stringify(dst, null, 2));
    "
    echo "[ok] Merged global opencode.json"
  else
    echo "[warn] node not found — skipping merge, copy as opencode.json.ai-engineering"
    cp "$ROOT/opencode.json" "$GLOBAL/opencode.json.ai-engineering"
  fi
else
  cp "$ROOT/opencode.json" "$GLOBAL/opencode.json"
  echo "[ok] Copied opencode.json to $GLOBAL/opencode.json"
fi

# Agents
for f in "$ROOT/.opencode/agents"/*.md; do
  [[ -f "$f" ]] || continue
  bn="$(basename "$f")"
  backup_if_exists "$GLOBAL/agents/$bn"
  cp "$f" "$GLOBAL/agents/$bn"
  echo "[ok] Installed agent $bn"
done

# Skills
for d in "$ROOT/.opencode/skills"/*; do
  [[ -d "$d" ]] || continue
  bn="$(basename "$d")"
  mkdir -p "$GLOBAL/skills/$bn"
  backup_if_exists "$GLOBAL/skills/$bn/SKILL.md"
  cp "$d/SKILL.md" "$GLOBAL/skills/$bn/SKILL.md"
  echo "[ok] Installed skill $bn"
done

# Commands
for f in "$ROOT/.opencode/commands"/*.md; do
  [[ -f "$f" ]] || continue
  bn="$(basename "$f")"
  backup_if_exists "$GLOBAL/commands/$bn"
  cp "$f" "$GLOBAL/commands/$bn"
  echo "[ok] Installed command $bn"
done

# AGENTS.md global (also supports ~/.config/opencode/AGENTS.md per docs)
if [[ -f "$ROOT/AGENTS.md" ]]; then
  backup_if_exists "$GLOBAL/AGENTS.md"
  cp "$ROOT/AGENTS.md" "$GLOBAL/AGENTS.md"
  echo "[ok] Installed AGENTS.md to $GLOBAL/AGENTS.md"
fi

echo ""
echo "[ok] Global install complete. Verify: opencode debug config  (should show merged global + plugin + agents)"
echo "To use a sibling app repo, ensure env vars are exported:  set -a; source $ROOT/.env; set +a  (or add to shell profile)"
