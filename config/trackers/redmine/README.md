# Tracker: Redmine

**MCP:** `@onozaty/redmine-mcp-server` (npm, MIT, comprehensive, `REDMINE_MCP_READ_ONLY`)

## Env

```
REDMINE_URL=https://redmine.company.com   # no trailing slash
REDMINE_API_KEY=...                       # My account → API access key
REDMINE_MCP_READ_ONLY=true                # recommended
```

## MCP wiring

### OpenCode (`opencode.json`)

```json
"redmine": {
  "type": "local",
  "command": ["npx","-y","@onozaty/redmine-mcp-server"],
  "environment": {
    "REDMINE_URL": "{env:REDMINE_URL}",
    "REDMINE_API_KEY": "{env:REDMINE_API_KEY}",
    "REDMINE_MCP_READ_ONLY": "{env:REDMINE_MCP_READ_ONLY}"
  }
}
```

### Claude Code (`.mcp.json`)

See `config/hosts/claude-code/mcp.json.example` → `redmine` entry.

### Codex (`.codex/config.toml`)

See `config/hosts/codex/config.toml.example` → `[mcp_servers.redmine]`.

## Alternative packages

- `yonaka15/mcp-server-redmine` — 78★, mature, uses `REDMINE_HOST`
- `@informatik_tirol/redmine-mcp-server` — fork
- `@oaxapps/redmine-mcp-server` — self-host focus

Chosen for read-only mode + tool filtering.
