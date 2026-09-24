# Architecture

## Overview — Host-agnostic, Tracker-pluggable

```
                ┌─────────────┐ ┌─────────────┐ ┌─────────────┐
                │  OpenCode   │ │ Claude Code │ │  Codex CLI  │  ← hosts (pick one or all)
                │  + OhMy OMO │ │             │ │             │     via --host
                └──────┬──────┘ └──────┬──────┘ └──────┬──────┘
                       └───────────────┼───────────────┘
                                       │
              ┌────────────────────────┼────────────────────────┐
              │                        │                        │
              ▼                        ▼                        ▼
        Tracker MCP               Dify MCP                Local Git
     (Redmine | Jira)          (local node)              (bash)
   @onozaty/redmine   mcp/dify-knowledge/dist/index.js
   @ahmetbarut/jira              │                        │
              │                  │                        │
              ▼                  ▼                        │
            Tasks          Dify Knowledge                 │
                                 │                       │
                          ┌──────┴──────┐                │
                          ▼             ▼                │
                   Internal Docs   Google Drive          │
                                                         │
                    All hosts share: AGENTS.md, skills, agents
```

Pick your stack at setup:

```bash
./setup/install.sh --host=opencode --tracker=redmine   # default
./setup/install.sh --host=claude   --tracker=jira
./setup/install.sh --host=codex    --tracker=jira
./setup/install.sh --host=all      --tracker=both
```

## Components

### Hosts — pluggable coding agents

All hosts share the same `AGENTS.md` + skills/agents (open Agent Skills standard). Source of truth lives in `.opencode/skills/` + `.opencode/agents/`; `scripts/sync-hosts.*` replicates to host-specific locations.

| Host | Install | Skills location | MCP config | Agents | Docs |
|---|---|---|---|---|---|
| **OpenCode** (default) | `curl -fsSL https://opencode.ai/install \| bash` or `npm i -g opencode-ai` | `.opencode/skills/*/SKILL.md` (+ `~/.config/opencode/skills/`) | `opencode.json` `mcp{}` | `.opencode/agents/*.md` | https://opencode.ai/docs |
| **Claude Code** | `npm i -g @anthropic-ai/claude-code` | `.claude/skills/*/SKILL.md` (+ `~/.claude/skills/`) | `.mcp.json` `mcpServers{}` | `.claude/agents/*.md` | https://code.claude.com/docs |
| **Codex** | `npm i -g @openai/codex` | `.agents/skills/*/SKILL.md` (universal, also `~/.agents/skills/`, `/etc/codex/skills/`) | `~/.codex/config.toml` `[mcp_servers.*]` or `.codex/config.toml` | `.codex/agents/*.toml` / `AGENTS.md` | https://developers.openai.com/codex |

- **OpenCode project config:** `opencode.json` (`$schema: https://opencode.ai/config.json`, `plugin: ["oh-my-openagent"]`, `instructions: ["AGENTS.md"]`, `mcp: {dify-knowledge, redmine, jira}`, `agent: {developer, researcher, reviewer}`).
- **Claude Code config:** `.mcp.json` (`mcpServers{}`) — template at `config/hosts/claude-code/mcp.json.example`, skills at `.claude/skills/`.
- **Codex config:** `.codex/config.toml` (`[mcp_servers.*]`) — template at `config/hosts/codex/config.toml.example`, skills at `.agents/skills/` (universal, also read by Cursor/Gemini/Copilot via `.agents/`).

`AGENTS.md` at repo root is universal — OpenCode loads via `instructions`, Claude reads `CLAUDE.md` or `AGENTS.md` fallback, Codex reads `AGENTS.md` layered.

See `config/hosts/README.md` and `config/hosts/<host>/README.md` for per-host wiring.

### Oh My OpenAgent (OpenCode orchestration layer)

- **What:** Batteries-included OpenCode plugin for multi-model orchestration, parallel background agents, LSP/AST tools.
- **Package:** `oh-my-openagent` (legacy `oh-my-opencode`, dual-published). 4.12.0 (2026-09). Do NOT use `npm i -g`; installer writes to `~/.config/opencode`.
- **Install:** `bunx oh-my-openagent install` (TUI). Inside `opencode.json`: `"plugin": ["oh-my-openagent"]`. Verify: `bunx oh-my-openagent doctor --json`.
- Only applies when `host=opencode` or `all`. Claude/Codex use their own orchestration.

> Do NOT use `bunx omo` / `npx omo` — `omo` is unrelated.

### Tracker MCP — pluggable (Redmine or Jira)

Only configure the tracker you use. `--tracker` flag + `.env` controls which is validated. Both can coexist (`--tracker=both`).

#### Redmine

- **Package:** `@onozaty/redmine-mcp-server` (npm, MIT). Read-only via `REDMINE_MCP_READ_ONLY=true`.
- **Env:** `REDMINE_URL` (`https://redmine.example.com`), `REDMINE_API_KEY` (My account → API access key).
- **Wiring:** OpenCode `opencode.json` `mcp.redmine` (`type: local`, `command: ["npx","-y","@onozaty/redmine-mcp-server"]`), Claude `.mcp.json` `redmine`, Codex `[mcp_servers.redmine]`. `{env:VAR}` / `${VAR}` substituted from shell/` .env`.

Details: `config/trackers/redmine/README.md`.

#### Jira

- **Packages (pick one):**
  - **Cloud (default):** `@ahmetbarut/jira-mcp-server` (`JIRA_BASE_URL`, `JIRA_EMAIL`, `JIRA_API_TOKEN` from `id.atlassian.com` → Security → Create API token). Tools: `get_boards`, `get_issues`, `add_comment_to_issue`, etc.
  - **Data Center:** `@atlassian-dc-mcp/jira` (`JIRA_HOST`/`JIRA_TOKEN`, `npx @atlassian-dc-mcp/jira setup` writes `~/.atlassian-dc-mcp/jira.env`)
  - **Official remote:** Atlassian Rovo `https://domain.atlassian.net/v1/mcp` (streamable HTTP `/mcp`, OAuth 2.1, GA 2026-06) — configure as `type: remote`.
  - **Other:** `mcp-jira-cloud-server` (46 tools, 4 modules), `@mcp-devtools/jira`, `jira-mcp`.
- This repo's default template uses **ahmetbarut** (Cloud). Override `command` if you prefer another.
- **Wiring:** `opencode.json` `mcp.jira`, `.mcp.json` `jira`, `[mcp_servers.jira]`.

Details: `config/trackers/jira/README.md` and `config/mcp/jira.example.json`.

### Dify Knowledge (RAG) + Dify MCP Adapter — host-agnostic

**Dify owns RAG:** ingestion, chunking, embeddings, retrieval, reranking, vector storage. This repo does NOT reimplement.

- **Sources:** `company-internal-docs`, `company-google-drive` (plus architecture, API, business rules).
- **API (verified 2026-09):** `GET /datasets`, `GET /datasets/{id}`, `POST /datasets/{id}/retrieve` (`{query, retrieval_model:{...}}`), `GET /datasets/{id}/documents/{doc_id}`, `Authorization: Bearer {API_KEY}`.
- **Thin MCP adapter:** `mcp/dify-knowledge/` (Node, `@modelcontextprotocol/sdk` + `zod`, stdio). 3 tools: `list_knowledge_bases` → `GET /datasets`, `search_knowledge` → `POST /retrieve` (fans out if no `dataset_id`), `get_document` → `GET /documents/{id}`.
- **Host wiring:**
  - OpenCode: `opencode.json` `mcp.dify-knowledge` (`command: ["node","mcp/dify-knowledge/dist/index.js"]`, `env: {DIFY_*}`)
  - Claude: `.mcp.json` `mcpServers.dify-knowledge`
  - Codex: `config.toml` `[mcp_servers.dify-knowledge]`
- Build once: `npm --prefix mcp/dify-knowledge install && npm --prefix mcp/dify-knowledge run build`.

### Local Git

All hosts use `bash` + `git` directly. No Git MCP for basic ops — intentionally. Remote Git/MR MCP (GitHub/GitLab) can be added later per host's MCP docs (OpenCode: `https://opencode.ai/docs/mcp-servers`, Claude: `https://code.claude.com/docs/en/mcp`, Codex: `https://developers.openai.com/codex/mcp`).

## Repository Structure

```
ai-engineering/
├── opencode.json                 # OpenCode host config (agents, MCP, plugin, instructions)
├── .mcp.json                     # (generated) Claude Code MCP — copy from config/hosts/claude-code/mcp.json.example
├── .codex/config.toml            # (generated) Codex MCP — copy from config/hosts/codex/config.toml.example
├── AGENTS.md                     # Universal rules (all hosts)
├── .env.example                  # Template (REDMINE_* and JIRA_* — configure one)
├── .opencode/                    # Source of truth — host-agnostic
│   ├── agents/                   # developer.md, researcher.md, reviewer.md
│   ├── skills/                   # 6 SKILL.md (universal spec)
│   └── commands/                 # health, research
├── .claude/                      # (generated) Claude Code — synced via scripts/sync-hosts.sh
│   ├── agents/ + skills/
├── .agents/                      # (generated) Universal — used by Codex/Cursor/Gemini
│   └── skills/
├── mcp/
│   └── dify-knowledge/           # Thin MCP adapter (build → dist/index.js)
├── config/
│   ├── hosts/
│   │   ├── README.md
│   │   ├── opencode/README.md
│   │   ├── claude-code/ (mcp.json.example, README)
│   │   └── codex/ (config.toml.example, README)
│   ├── trackers/
│   │   ├── redmine/README.md
│   │   └── jira/README.md
│   ├── opencode/ (opencode.example.json, tui.example.json)
│   └── mcp/ (redmine/jira/dify examples + README)
├── setup/
│   ├── install.sh / install.ps1  # --host= / --tracker= flags, sync-hosts
│   └── check.sh / check.ps1      # validates host + tracker pluggable
├── scripts/
│   ├── sync-hosts.sh/ps1         # sync .opencode → .claude/.agents
│   ├── install-opencode.sh/ps1
│   ├── install-omo.sh/ps1
│   ├── install-mcp.sh/ps1        # primes both Redmine+Jira npx caches
│   ├── install-global.sh/ps1     # copy to ~/.config/opencode (OpenCode global)
│   ├── configure.sh/ps1          # interactive .env (REDMINE or JIRA)
│   └── health-check.sh/ps1       # alias to setup/check
├── docker/dify/                  # Self-host placeholder + vendoring guide
└── docs/
    ├── architecture.md           # this file
    ├── setup.md
    ├── workflow.md
    ├── security.md
    └── troubleshooting.md
```

## Data Flow (example: Redmine + OpenCode)

1. `git clone <ai-engineering> && ./setup/install.sh --host=opencode --tracker=redmine`
2. Scripts install OpenCode, `bunx oh-my-openagent install`, build `mcp/dify-knowledge`, sync hosts if needed.
3. `scripts/configure.sh` → `.env` (Dify + `REDMINE_*` or `JIRA_*` + provider keys).
4. `setup/check.sh --tracker=redmine` validates.
5. `scripts/sync-hosts.sh --host=all` + `scripts/install-global.sh` (for sibling app repos) if needed.
6. Clone app repo sibling → host loads global/project config, `AGENTS.md`, skills, spawns MCPs.
7. Agent fulfills task: Tracker MCP (Redmine/Jira) → context, Dify MCP → internal docs, `read`/`edit`/`bash` → code.

Swap `--host`/`--tracker` for other stacks — same flow.

## Design Decisions

- **Host-agnostic skills/agents:** open Agent Skills standard (`name`/`description` frontmatter) works across OpenCode, Claude Code, Codex, Cursor, etc. One source, synced to host dirs. No duplicate logic.
- **Oh My OpenAgent only for OpenCode:** Claude/Codex have native orchestration; don't force OMO onto them.
- **Pluggable tracker:** only the configured tracker's env + package are required; `setup/check` warns for the other instead of failing. Both can coexist.
- **Thin Dify adapter only:** keeps retrieval thin; Dify remains system of record.
- **No Git MCP:** `bash` + `git` simpler; remote MR MCP is incremental.
- **`{env:…}` / `${VAR}`:** avoids committing secrets; works with direnv/dotenv.

## Non-goals

- No application source code in this repo.
- No RAG/embeddings/vector DB in this repo.
- No tracker UI duplication.
