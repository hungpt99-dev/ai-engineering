# Tracker: Jira

Supports **Jira Cloud** and **Jira Data Center** via pluggable MCP packages. Pick one.

## Option A: Cloud — `@ahmetbarut/jira-mcp-server` (recommended for Cloud)

Simple `JIRA_BASE_URL + JIRA_EMAIL + JIRA_API_TOKEN`:

```
JIRA_BASE_URL=https://your-domain.atlassian.net
JIRA_EMAIL=your-email@company.com
JIRA_API_TOKEN=...   # id.atlassian.com → Security → Create API token
```

MCP wiring:

**OpenCode:**

```json
"jira": {
  "type": "local",
  "command": ["npx","-y","@ahmetbarut/jira-mcp-server"],
  "environment": {
    "JIRA_BASE_URL": "{env:JIRA_BASE_URL}",
    "JIRA_EMAIL": "{env:JIRA_EMAIL}",
    "JIRA_API_TOKEN": "{env:JIRA_API_TOKEN}"
  }
}
```

**Claude Code / Codex:** same `command`/`env` under their mcp config (see `config/hosts/*/mcp.json.example` / `config.toml.example`).

Available tools: `get_boards`, `get_issues`, `add_comment_to_issue`, `search_users`, `get_server_info`, etc.

## Option B: Data Center — `@atlassian-dc-mcp/jira` (Data Center)

Interactive `npx @atlassian-dc-mcp/jira setup` writes to `~/.atlassian-dc-mcp/jira.env` (0600) + Keychain on macOS.

Env alternative:

```
JIRA_HOST=your-jira.example.com
JIRA_API_BASE_PATH=https://your-jira.example.com/rest
JIRA_TOKEN=...
```

## Option C: Atlassian Rovo (official, Cloud, GA 2026-06)

Remote `https://your-domain.atlassian.net/v1/mcp` (streamable HTTP `/mcp`, OAuth 2.1, respects Jira permissions). Configure as `type: remote` with `url` + `oauth` (OpenCode supports `oauth` discovery) or use local `jira-mcp` wrappers above for stdio.

## Option D: Generic / modular — `mcp-jira-cloud-server` (46 tools, 4 modules), `@mcp-devtools/jira`, `jira-mcp` (1.0.1)

All are stdio-compatible; swap `command` package name.

## Choosing

- Cloud + simple → **ahmetbarut** (this repo's default jira entry)
- Data Center → **atlassian-dc-mcp**
- Enterprise governance + remote → **Rovo**
- Max tool coverage → **mcp-jira-cloud-server**

This repo's `config/mcp/jira.example.json` and host templates use **ahmetbarut** as default; override via env + `command` if you prefer another.
