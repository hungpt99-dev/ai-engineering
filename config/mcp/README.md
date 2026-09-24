# MCP Configuration

## Redmine MCP

**Package:** `@onozaty/redmine-mcp-server` (npm, MIT, maintained — 22★, 28 commits, 2025-07 → active 2026)

Why this package:
- Comprehensive Redmine REST API coverage (issues, projects, users, time entries, wiki, etc.)
- `REDMINE_MCP_READ_ONLY` flag for safe AI use
- Tool filtering via regex (`REDMINE_MCP_TOOL_FILTER`)
- Stdio transport (works with OpenCode `type: local`)

Alternatives considered:
- `yonaka15/mcp-server-redmine` — 78★, mature, but env uses `REDMINE_HOST` and lacks read-only mode
- `@informatik_tirol/redmine-mcp-server` — fork with extra features but fewer consumers
- Python-based servers require `uv`/`pip` — not ideal for Node-centric setup

**OpenCode config** (`opencode.json`):

```json
{
  "mcp": {
    "redmine": {
      "type": "local",
      "command": ["npx", "-y", "@onozaty/redmine-mcp-server"],
      "environment": {
        "REDMINE_URL": "{env:REDMINE_URL}",
        "REDMINE_API_KEY": "{env:REDMINE_API_KEY}",
        "REDMINE_MCP_READ_ONLY": "{env:REDMINE_MCP_READ_ONLY}"
      },
      "enabled": true
    }
  }
}
```

**Env (`REDMINE_*`):**

| Var | Required | Description |
|---|---|---|
| `REDMINE_URL` | yes | `https://redmine.example.com` (no trailing slash) |
| `REDMINE_API_KEY` | yes | My account → API access key |
| `REDMINE_MCP_READ_ONLY` | no | `true` = block write tools (recommended for AI) |

Get API key: Redmine → My account → API access key → Show.

Test without OpenCode:

```bash
REDMINE_URL=https://redmine.example.com REDMINE_API_KEY=xxx npx -y @onozaty/redmine-mcp-server
# use with MCP Inspector:
npx @modelcontextprotocol/inspector npx -y @onozaty/redmine-mcp-server
```

## Dify Knowledge MCP

Local thin adapter at `mcp/dify-knowledge/`. See `mcp/dify-knowledge/README.md`.

**No RAG implementation here** — Dify handles ingestion, chunking, embeddings, reranking, vector storage. This adapter only calls `GET /datasets`, `POST /datasets/{id}/retrieve`, `GET /datasets/{id}/documents/{doc_id}`.

## Jira MCP

Pluggable. Default is **Cloud** via `@ahmetbarut/jira-mcp-server` (`JIRA_BASE_URL`, `JIRA_EMAIL`, `JIRA_API_TOKEN`). Alternatives: `@atlassian-dc-mcp/jira` (Data Center, `JIRA_HOST`/`JIRA_TOKEN`), Atlassian **Rovo** remote (`/v1/mcp`, OAuth), `mcp-jira-cloud-server` (46 tools). See `config/trackers/jira/README.md`.

**OpenCode example** (`opencode.json` `mcp.jira`):

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

Claude Code (`.mcp.json`) and Codex (`[mcp_servers.jira]`) use same `command`/`env`. Only configure the tracker you use — `setup/check.*` validates whichever `*_URL`/`*_TOKEN` is set, warns for the other.

## Dify Knowledge MCP

Local thin adapter at `mcp/dify-knowledge/`. See `mcp/dify-knowledge/README.md`.

**No RAG implementation here** — Dify handles ingestion, chunking, embeddings, reranking, vector storage. This adapter only calls `GET /datasets`, `POST /datasets/{id}/retrieve`, `GET /datasets/{id}/documents/{doc_id}`.

Host mappings:
- OpenCode: `opencode.json` `mcp.dify-knowledge` (`type: local`, `command: ["node","mcp/dify-knowledge/dist/index.js"]`)
- Claude Code: `.mcp.json` `mcpServers.dify-knowledge`
- Codex: `config.toml` `[mcp_servers.dify-knowledge]`

## Local Git

All hosts use `bash` + `git` directly. No Git MCP for basic ops — intentionally.

A remote Git/MR MCP (GitHub/GitLab) can be added later if PR/review/comment workflows become required. To add it, create a new `mcp` entry with `type: remote` or `type: local` and follow the host's MCP docs (OpenCode: `https://opencode.ai/docs/mcp-servers`, Claude: `https://code.claude.com/docs/en/mcp`, Codex: `https://developers.openai.com/codex/mcp`).

## Host matrix

| Tracker | OpenCode | Claude Code | Codex |
|---|---|---|---|
| Redmine | `opencode.json` `mcp.redmine` | `.mcp.json` `redmine` | `[mcp_servers.redmine]` |
| Jira | `opencode.json` `mcp.jira` | `.mcp.json` `jira` | `[mcp_servers.jira]` |
| Dify | `mcp.dify-knowledge` | `mcpServers.dify-knowledge` | `mcp_servers.dify-knowledge` |

See `config/hosts/*/README.md` and `config/trackers/*/README.md`.
