# Architecture

## Overview

```
                         OpenCode
                            │
                    Oh My OpenAgent (plugin)
                            │
              ┌─────────────┼─────────────┐
              │             │             │
              ▼             ▼             ▼
         Redmine MCP     Dify MCP      Local Git
         (npx)           (local node)  (bash)
              │             │
              ▼             ▼
            Tasks      Dify Knowledge
                            │
                     ┌──────┴──────┐
                     ▼             ▼
              Internal Docs   Google Drive
```

## Components

### OpenCode (primary coding agent)

- **What:** Open-source AI coding agent (terminal TUI, desktop, IDE). 75+ providers via Models.dev. LSP, multi-session, share links.
- **Install:** `curl -fsSL https://opencode.ai/install | bash` or `npm i -g opencode-ai` or `brew install anomalyco/tap/opencode`. Verify: `opencode --version`.
- **Config locations (merged, later overrides earlier):**
  1. Remote `.well-known/opencode`
  2. Global `~/.config/opencode/opencode.json`
  3. `OPENCODE_CONFIG` custom path
  4. Project `opencode.json` (this repo — checked into git)
  5. `.opencode/` dirs (agents/commands/skills/plugins)
  6. `OPENCODE_CONFIG_CONTENT` inline
  7. Managed `/Library/Application Support/opencode/` (macOS) etc.
- **Project config in this repo:** `opencode.json` at root with `$schema: https://opencode.ai/config.json`, `plugin: ["oh-my-openagent"]`, `instructions: ["AGENTS.md"]`, `mcp: {dify-knowledge, redmine}`, `agent: {developer, researcher, reviewer}`.
- **Responsibilities:** understand tasks, inspect source, modify code, run tests, debug, review, use MCP when needed.

Docs: https://opencode.ai/docs  Config: https://opencode.ai/docs/config  MCP: https://opencode.ai/docs/mcp-servers

### Oh My OpenAgent (orchestration layer)

- **What:** Batteries-included OpenCode plugin for multi-model orchestration, parallel background agents, LSP/AST tools.
- **Package:** `oh-my-openagent` (legacy `oh-my-opencode`, dual-published). Current 4.12.0 (2026-09). Do NOT use `npm i -g`; installer writes to `~/.config/opencode` / project plugin.
- **Install:** `bunx oh-my-openagent install` (TUI walks through plugin registration + provider auth). Inside `opencode.json`: `"plugin": ["oh-my-openagent"]` — legacy `"oh-my-opencode"` still loads with warning, prefer new name. Verify: `bunx oh-my-openagent doctor --json`.
- **Why not a custom harness:** Oh My OpenAgent already provides multi-agent workflows, task orchestration, iterative test/fix cycles, background tasks, recovery. Don't rebuild it.
- **Editions shipped by same package:**
  - *Ultimate* (OpenCode): `bunx oh-my-openagent install` → plugin in `opencode.json`
  - *Light* (Codex CLI): `npx lazycodex-ai install` → `~/.codex/`
  - *Both*: `bunx oh-my-openagent install --platform=both`

> Do NOT use `bunx omo` / `npx omo` — `omo` is an unrelated package.

### Redmine MCP

- **Package:** `@onozaty/redmine-mcp-server` (npm, MIT, comprehensive Redmine REST API). Read-only mode via `REDMINE_MCP_READ_ONLY=true`.
- **Config snippet (in `opencode.json`):**
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
- **Env resolution:** `{env:VAR}` is substituted by OpenCode from shell env / `.env`. Never hardcode keys in JSON.
- **Operations:** get issue, list issues, read history/comments, understand context. No duplicate Redmine logic in this repo.
- **Auth:** API key from Redmine → My account → API access key. `REDMINE_MCP_READ_ONLY=true` recommended for AI.

### Dify Knowledge (RAG) + Dify MCP Adapter

**Dify owns RAG:** ingestion, chunking, embeddings, retrieval, reranking, vector storage. This repo does NOT reimplement any of that.

- **Sources:** `company-internal-docs`, `company-google-drive` (plus architecture, API, business rules, conventions).
- **API (verified 2026-09):**
  - `GET /datasets` — list knowledge bases (paginated, `keyword` filter)
  - `GET /datasets/{id}` — one base
  - `POST /datasets/{id}/retrieve` — search, body `{query, retrieval_model: {search_method, reranking_enable, top_k, score_threshold_enabled}}`
  - `GET /datasets/{id}/documents/{doc_id}` — document metadata
  - Auth: `Authorization: Bearer {API_KEY}` (dataset API key, from Knowledge → Service API). One key can access all bases visible to the creator.
- **Thin MCP adapter:** `mcp/dify-knowledge/` (Node, `@modelcontextprotocol/sdk` + `zod`, stdio). Exposes exactly 3 tools:
  - `list_knowledge_bases` → `GET /datasets`
  - `search_knowledge` → `POST /datasets/{id}/retrieve` (if no `dataset_id`, fans out across all bases, merges by score)
  - `get_document` → `GET /datasets/{id}/documents/{doc_id}`
  Only tools supported by current Dify API are exposed. No embeddings/vector logic here.
- **OpenCode wiring:**
  ```json
  "dify-knowledge": {
    "type": "local",
    "command": ["node","mcp/dify-knowledge/dist/index.js"],
    "environment": {
      "DIFY_BASE_URL": "{env:DIFY_BASE_URL}",
      "DIFY_API_KEY": "{env:DIFY_API_KEY}"
    }
  }
  ```
  Build once: `npm --prefix mcp/dify-knowledge install && npm --prefix mcp/dify-knowledge run build`.

### Local Git

- OpenCode runs `bash` + `git` directly against the local clone. **No Git MCP for basic ops is configured** — intentionally per spec.
- A remote Git/MR MCP (GitHub/GitLab) can be added later for PR/review/comment workflows if needed: add an `mcp` entry with `type: remote` or `type: local` per `https://opencode.ai/docs/mcp-servers`.

## Repository Structure (this repo)

```
ai-engineering/
├── opencode.json                 # Project config (agents, MCP, plugin, instructions)
├── AGENTS.md                     # Global rules (loaded as instructions)
├── .env.example                  # Template (never commit .env)
├── .opencode/
│   ├── agents/                   # developer.md, researcher.md, reviewer.md
│   ├── skills/                   # 6 SKILL.md
│   └── commands/                 # (optional custom commands)
├── mcp/
│   └── dify-knowledge/           # Thin MCP adapter (build → dist/index.js)
├── config/
│   ├── opencode/                 # opencode.example.json, tui.example.json
│   └── mcp/                      # redmine/dify example snippets + README
├── setup/
│   ├── install.sh / install.ps1  # Unified entry point
│   └── check.sh / check.ps1      # Health validation
├── scripts/
│   ├── install-opencode.sh/ps1
│   ├── install-omo.sh/ps1
│   ├── install-mcp.sh/ps1
│   ├── configure.sh/ps1          # Interactive .env writer (no secret echo)
│   └── health-check.sh/ps1       # Alias to setup/check
├── docker/
│   └── dify/                     # Self-host placeholder + vendoring guide
└── docs/
    ├── architecture.md           # this file
    ├── setup.md
    ├── workflow.md
    ├── security.md
    └── troubleshooting.md
```

## Data Flow

1. User runs `git clone <ai-engineering> && ./setup/install.sh` (or `install.ps1` on Windows).
2. Scripts install OpenCode, `bunx oh-my-openagent install`, build `mcp/dify-knowledge`.
3. User runs `scripts/configure.sh` → writes `.env` (Dify/Redmine/provider keys).
4. `setup/check.sh` validates versions, JSON, MCP connectivity.
5. User clones any app repo sibling to this repo and runs `opencode` inside it.
6. OpenCode merges global + project config, loads `AGENTS.md`, discovers agents/skills, spawns MCP servers on demand.
7. Agent fulfills a task: Redmine MCP → context, Dify MCP → internal docs, `read`/`edit`/`bash` → code.

## Design Decisions

- **Oh My OpenAgent over custom orchestration:** it already covers multi-agent orchestration, background tasks, recovery. Re-building would duplicate and drift.
- **Thin Dify adapter only:** keeps retrieval thin; Dify remains the system of record for knowledge.
- **No Git MCP:** local `bash` + `git` is simpler and avoids token-scoped MCP for basic ops. Remote MR MCP is an incremental add-on.
- **`{env:…}` in opencode.json:** avoids committing secrets; works with direnv / dotenv.

## Non-goals

- No application source code in this repo.
- No RAG/embeddings/vector DB in this repo.
- No Redmine UI duplication.
