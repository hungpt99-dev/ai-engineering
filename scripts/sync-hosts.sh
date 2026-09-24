#!/usr/bin/env bash
# Sync skills/agents to host-specific locations (Claude Code, Codex, OpenCode)
# Usage: ./scripts/sync-hosts.sh [--host=opencode|claude|codex|all] [--force]
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HOST="all"
FORCE=false
for arg in "$@"; do
  case "$arg" in
    --host=*) HOST="${arg#--host=}" ;;
    --force) FORCE=true ;;
  esac
done

echo "[info] sync-hosts --host=$HOST (root: $ROOT)"

sync_dir() {
  local src="$1" dst="$2"
  mkdir -p "$dst"
  # copy each skill dir
  for d in "$src"/*; do
    [[ -d "$d" ]] || continue
    bn="$(basename "$d")"
    mkdir -p "$dst/$bn"
    if [[ -f "$dst/$bn/SKILL.md" && "$FORCE" != true ]]; then
      echo "[info] skip $dst/$bn/SKILL.md (exists, use --force to overwrite)"
    else
      cp "$d/SKILL.md" "$dst/$bn/SKILL.md"
      echo "[ok] synced skill $bn -> $dst/$bn/SKILL.md"
    fi
  done
}

sync_agents() {
  local src="$1" dst="$2"
  mkdir -p "$dst"
  for f in "$src"/*.md; do
    [[ -f "$f" ]] || continue
    bn="$(basename "$f")"
    if [[ -f "$dst/$bn" && "$FORCE" != true ]]; then
      echo "[info] skip $dst/$bn (exists, use --force)"
    else
      cp "$f" "$dst/$bn"
      echo "[ok] synced agent $bn -> $dst/$bn"
    fi
  done
}

# OpenCode is source of truth — no sync needed for itself, but ensure dirs exist
if [[ "$HOST" == "opencode" || "$HOST" == "all" ]]; then
  echo "[info] Host opencode: source of truth at .opencode/ (no sync needed)"
fi

if [[ "$HOST" == "claude" || "$HOST" == "all" ]]; then
  echo "[info] Syncing to Claude Code (.claude/skills, .claude/agents, .mcp.json)"
  sync_dir "$ROOT/.opencode/skills" "$ROOT/.claude/skills"
  sync_agents "$ROOT/.opencode/agents" "$ROOT/.claude/agents"
  if [[ ! -f "$ROOT/.mcp.json" ]]; then
    cp "$ROOT/config/hosts/claude-code/mcp.json.example" "$ROOT/.mcp.json"
    echo "[ok] created .mcp.json from template (edit env placeholders)"
  else
    echo "[info] .mcp.json already exists — skip (use --force to overwrite)"
    if [[ "$FORCE" == true ]]; then cp "$ROOT/config/hosts/claude-code/mcp.json.example" "$ROOT/.mcp.json"; echo "[ok] overwrote .mcp.json"; fi
  fi
fi

if [[ "$HOST" == "codex" || "$HOST" == "all" ]]; then
  echo "[info] Syncing to Codex (.agents/skills, .codex/config.toml)"
  sync_dir "$ROOT/.opencode/skills" "$ROOT/.agents/skills"
  # Codex also reads .codex/agents? For now keep .agents/skills as universal
  mkdir -p "$ROOT/.codex"
  if [[ ! -f "$ROOT/.codex/config.toml" ]]; then
    cp "$ROOT/config/hosts/codex/config.toml.example" "$ROOT/.codex/config.toml"
    echo "[ok] created .codex/config.toml from template"
  else
    echo "[info] .codex/config.toml already exists — skip"
    if [[ "$FORCE" == true ]]; then cp "$ROOT/config/hosts/codex/config.toml.example" "$ROOT/.codex/config.toml"; echo "[ok] overwrote .codex/config.toml"; fi
  fi
  # Also ensure .agents/skills is present (Codex universal)
fi

echo "[info] sync-hosts done. Verify: ls .claude/skills .agents/skills .codex .mcp.json"
