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

## Local Git

OpenCode uses `bash` + `git` directly. No Git MCP is configured — intentionally.

A remote Git/MR MCP (GitHub/GitLab) can be added later if PR/review/comment workflows become required. To add it, create a new `mcp` entry with `type: remote` or `type: local` and follow `https://opencode.ai/docs/mcp-servers`.
