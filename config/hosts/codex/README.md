# Codex CLI — Host Config

## Install Codex

```bash
npm install -g @openai/codex
codex --version
```

Docs: https://developers.openai.com/codex

## MCP

Codex stores MCP in `~/.codex/config.toml` (global) or `.codex/config.toml` (project, trusted only):

```toml
[mcp_servers.dify-knowledge]
command = "node"
args = ["mcp/dify-knowledge/dist/index.js"]
env = { DIFY_BASE_URL = "${DIFY_BASE_URL}", DIFY_API_KEY = "${DIFY_API_KEY}" }

[mcp_servers.redmine]
command = "npx"
args = ["-y", "@onozaty/redmine-mcp-server"]
env = { REDMINE_URL = "${REDMINE_URL}", REDMINE_API_KEY = "${REDMINE_API_KEY}", REDMINE_MCP_READ_ONLY = "${REDMINE_MCP_READ_ONLY}" }

# Jira (Cloud)
[mcp_servers.jira]
command = "npx"
args = ["-y", "@ahmetbarut/jira-mcp-server"]
env = { JIRA_BASE_URL = "${JIRA_BASE_URL}", JIRA_EMAIL = "${JIRA_EMAIL}", JIRA_API_TOKEN = "${JIRA_API_TOKEN}" }
```

Template at `config/hosts/codex/config.toml.example`.

## Skills

Codex scans **universal** `.agents/skills/<name>/SKILL.md` from CWD up to repo root (+ `~/.agents/skills/`, `/etc/codex/skills/`). It supports the open Agent Skills standard (`name` + `description` frontmatter). Invoke via `$skill-name` or `/skills`.

Source is `.opencode/skills/`; `scripts/sync-hosts.sh --host=codex` copies to `.agents/skills/`.

Optional `agents/openai.yaml` inside a skill can set `allow_implicit_invocation` and UI metadata (Codex-only extension).

## Rules

`AGENTS.md` layered from `~/.codex/AGENTS.md` down to CWD `AGENTS.md`. This repo's `AGENTS.md` works directly.

## Verify

```bash
codex mcp list
codex --help
```
