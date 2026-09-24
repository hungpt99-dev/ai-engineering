# Hosts — Pluggable Coding Agents

This repo is **host-agnostic**. Agents/skills (`AGENTS.md`, `.opencode/skills/*/SKILL.md`) are written to the open Agent Skills standard and work across multiple hosts. Host-specific wiring is in `config/hosts/<host>/`.

| Host | Package / Install | Skills location | MCP config | Agents | Docs |
|---|---|---|---|---|---|
| **OpenCode** | `npm i -g opencode-ai` or `curl -fsSL https://opencode.ai/install \| bash` | `.opencode/skills/*/SKILL.md` (+ global `~/.config/opencode/skills/`) | `opencode.json` `mcp{}` | `.opencode/agents/*.md` | https://opencode.ai/docs |
| **Claude Code** | `npm i -g @anthropic-ai/claude-code` | `.claude/skills/*/SKILL.md` (+ `~/.claude/skills/`) | `.mcp.json` `mcpServers{}` | `.claude/agents/*.md` | https://code.claude.com/docs |
| **Codex CLI** | `npm i -g @openai/codex` | `.agents/skills/*/SKILL.md` (+ `~/.agents/skills/`, `/etc/codex/skills/`) | `~/.codex/config.toml` `[mcp_servers.*]` or `.codex/config.toml` | `.codex/agents/*.toml` or `AGENTS.md` | https://developers.openai.com/codex |

## Universal source of truth

Source of truth lives in `.opencode/skills/` and `.opencode/agents/` (open standard). `scripts/sync-hosts.*` syncs them to Claude/Codex locations so you maintain one copy.

```
.opencode/skills/task-analysis/SKILL.md  ─┬─► .claude/skills/task-analysis/SKILL.md
                                          ├─► .agents/skills/task-analysis/SKILL.md  (universal, used by Codex/Cursor/Gemini)
                                          └─► ~/.config/opencode/skills/ (global via install-global)
```

`AGENTS.md` at repo root is already universal — OpenCode, Claude Code (reads `CLAUDE.md` or `AGENTS.md` fallback), and Codex (`AGENTS.md`) all load it.

## Choose a host at setup

```bash
# OpenCode (default, full test harness + Oh My OpenAgent)
./setup/install.sh --host=opencode --tracker=redmine

# Claude Code
./setup/install.sh --host=claude --tracker=jira
# or Windows:
.\setup\install.ps1 -Host claude -Tracker jira

# Codex
./setup/install.sh --host=codex --tracker=jira

# All hosts (copy skills/agents to every location)
./setup/install.sh --host=all --tracker=both
```

`--host` and `--tracker` are optional; default is `opencode` + `redmine` for backward compat.

## What sync does

`scripts/sync-hosts.sh --host=all`:

- Copies each `.opencode/skills/*/SKILL.md` to `.claude/skills/*/SKILL.md` and `.agents/skills/*/SKILL.md`
- Copies `.opencode/agents/*.md` to `.claude/agents/` (and emits `.agents` hint for Codex if needed)
- Generates `.mcp.json` (Claude) and `.codex/config.toml` stub if missing (from templates in `config/hosts/*/`)
- Does NOT overwrite existing host configs without `--force`.

See `config/hosts/<host>/README.md` for per-host details.
