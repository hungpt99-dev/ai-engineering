# Complete Setup Guide (English)

Host-agnostic (**OpenCode / Claude Code / Codex**) + Tracker-pluggable (**Redmine / Jira**) + Dify Knowledge harness with CLI `ai-eng`.

This single guide covers everything: prerequisites → install → Dify self-host/cloud → tracker → env → validation → using with any app repo (no sibling required if you use the CLI).

---

## 1. Prerequisites

| Tool | Minimum | Check | Install |
|---|---|---|---|
| Node.js | 18+ (MCP stdio servers) | `node --version` | https://nodejs.org |
| npm | 9+ | `npm --version` | ships with Node |
| bun | latest (only for OpenCode + Oh My OpenAgent) | `bun --version` | `curl -fsSL https://bun.sh/install \| bash` |
| Git | 2.x | `git --version` | https://git-scm.com |
| curl | any | `curl --version` | system package manager |
| PowerShell | 5.1+ (Windows) | `$PSVersionTable` | built-in |

> Node 18+ is required for `@modelcontextprotocol/sdk` (native `fetch`, `node:crypto`).

Optional per host:
- **Claude Code:** `npm install -g @anthropic-ai/claude-code` → `claude --version` (https://code.claude.com/docs)
- **Codex:** `npm install -g @openai/codex` → `codex --version` (https://developers.openai.com/codex)

---

## 2. Install — Two Ways

### A. CLI — inside any app repo (recommended, no sibling)

No need to clone the harness sibling. Run in your **app repo** directory:

```bash
cd my-app

# One-liner without installing (tries npm registry, falls back to GitHub):
npx ai-engineering init --host=all --tracker=both
# or pin to this repo directly:
npx github:hungpt99-dev/ai-engineering init --host=all --tracker=both

# If you prefer a global binary:
npm install -g ai-engineering
ai-eng init --host=all --tracker=both
# Short alias also works:
ai-eng init --host=claude --tracker=jira
ai-eng init ./my-app --host=opencode --tracker=redmine --force
```

What `init` does:
- Copies `opencode.json` (if host includes `opencode`), `.mcp.json` (if `claude`), `.codex/config.toml` (if `codex`)
- Copies `.opencode/agents|skills|commands` → `.opencode/` + `.claude/` + `.agents/` (universal)
- Copies `AGENTS.md` + `.env.example` (template, not secrets)

**Hosts:** `opencode` | `claude` | `codex` | `all` (default `opencode`)
**Trackers:** `redmine` | `jira` | `both` | `none` (default `redmine`). Only the chosen tracker is required in `.env`; `setup/check` warns for the other.

### B. Clone harness (traditional)

```bash
git clone https://github.com/hungpt99-dev/ai-engineering.git
cd ai-engineering

# Default: OpenCode + Redmine
./setup/install.sh
# Pick stack:
./setup/install.sh --host=opencode --tracker=redmine
./setup/install.sh --host=claude   --tracker=jira
./setup/install.sh --host=codex    --tracker=jira
./setup/install.sh --host=all      --tracker=both

# Flags:
./setup/install.sh --yes      # non-interactive (skip Oh My OpenAgent TUI)
./setup/install.sh --check    # validate only

# Windows:
.\setup\install.ps1
.\setup\install.ps1 -Host claude -Tracker jira
.\setup\install.ps1 -Host all -Tracker both
```

What it does: checks prereqs → installs host runtime (`opencode` via `curl -fsSL https://opencode.ai/install | bash` / `npm i -g opencode-ai`, `claude` via `npm i -g @anthropic-ai/claude-code`, `codex` via `npm i -g @openai/codex`) → (if OpenCode) `bunx oh-my-openagent install` → `scripts/sync-hosts --host=...` → builds `mcp/dify-knowledge` (`npm --prefix mcp/dify-knowledge install && npm run build`) → primes `npx` caches for trackers → creates `.env` from `.env.example` → validates.

---

## 3. Dify Knowledge — Cloud or Self-Host

Dify owns RAG (ingestion, chunking, embeddings, retrieval, reranking, vector store). This harness only calls the Dify Knowledge API. No embedding logic here.

### 3.1 Cloud

- Base URL: `https://api.dify.ai/v1` (must end with `/v1`)
- Create knowledge bases: Dify Console → Knowledge → Create Knowledge (e.g. `company-internal-docs`, `company-google-drive`).
- Ingest: upload docs (architecture, APIs, business rules) or connect Google Drive via Data Source. Wait for `status: completed`.
- Get key: `Knowledge → Service API → Create API Key` → `DIFY_API_KEY=dataset-...` (one key sees all bases of that account; per-base `API Access` toggle can restrict).
- Optional: note `Dataset ID` from URL `/datasets/<id>` for `DIFY_DATASET_IDS`.

### 3.2 Self-Host

Placeholder at `docker/dify/` (avoids shipping stale 10-service compose). Vendor upstream:

```bash
git clone https://github.com/langgenius/dify.git /tmp/dify && git -C /tmp/dify checkout 1.1.0
cp -r /tmp/dify/docker/* docker/dify/
cp docker/dify/.env.example docker/dify/.env
# edit docker/dify/.env: DB_PASSWORD, REDIS_PASSWORD, CONSOLE_API_URL, APP_API_URL
docker compose -f docker/dify/docker-compose.yaml up -d
open http://localhost   # or https://dify.your-company.com
```

Then same steps as cloud, but:

```
DIFY_BASE_URL=https://dify.your-company.com/v1   # self-host, must end with /v1
```

Test (both cloud/self-host):

```bash
curl -H "Authorization: Bearer $DIFY_API_KEY" $DIFY_BASE_URL/datasets?limit=1
# expect 200 with { data: [...] }
```

### 3.3 Dify MCP adapter (thin)

At `mcp/dify-knowledge/` (Node, `@modelcontextprotocol/sdk` + `zod`, stdio). 3 tools:

- `list_knowledge_bases` → `GET /datasets`
- `search_knowledge` → `POST /datasets/{id}/retrieve` (if no `dataset_id`, fan-out across all bases, merge by score, `top_k` 1-20)
- `get_document` → `GET /datasets/{id}/documents/{doc_id}`

Env: `DIFY_BASE_URL`, `DIFY_API_KEY` → substituted as `{env:VAR}` (OpenCode) / `${VAR}` (Claude/Codex) in MCP configs.

Build once: `npm --prefix mcp/dify-knowledge install && npm --prefix mcp/dify-knowledge run build` (done by `setup/install`).

---

## 4. Tracker — Redmine or Jira (pick one or both)

Only configure the tracker you use. `setup/check` validates whichever `*_URL`/`*_TOKEN` is set; warns for the other.

### 4.1 Redmine

```
REDMINE_URL=https://redmine.company.com            # no trailing slash
REDMINE_API_KEY=...                                 # My account → API access key → Show
REDMINE_MCP_READ_ONLY=true                          # recommended (blocks write tools)
```

- REST API must be enabled (Administration → Settings → API).
- Package: `@onozaty/redmine-mcp-server` (comprehensive, read-only flag, tool filtering). Alternatives: `yonaka15/mcp-server-redmine`, `@oaxapps/redmine-mcp-server`.
- Wiring (templates already in repo):
  - OpenCode: `opencode.json` `mcp.redmine` (`type: local`, `command: ["npx","-y","@onozaty/redmine-mcp-server"]`)
  - Claude: `.mcp.json` `mcpServers.redmine`
  - Codex: `.codex/config.toml` `[mcp_servers.redmine]`
- Test: `curl -H "X-Redmine-API-Key: $REDMINE_API_KEY" $REDMINE_URL/users/current.json` → 200

### 4.2 Jira

**Option A — Cloud (recommended): `@ahmetbarut/jira-mcp-server`**

```
JIRA_BASE_URL=https://your-domain.atlassian.net
JIRA_EMAIL=you@company.com
JIRA_API_TOKEN=...   # id.atlassian.com → Security → Create API token
```

Tools: `get_boards`, `get_issues`, `add_comment_to_issue`, `search_users`, `get_server_info`.

**Option B — Data Center:** `@atlassian-dc-mcp/jira`

```bash
npx @atlassian-dc-mcp/jira setup --host jira.example.com --token $JIRA_TOKEN --non-interactive
# writes ~/.atlassian-dc-mcp/jira.env (0600) + Keychain on macOS
```
Env: `JIRA_HOST=jira.example.com` (domain, no protocol) or `JIRA_API_BASE_PATH=https://jira.example.com/rest`, `JIRA_TOKEN=...`

**Option C — Official remote:** Atlassian Rovo GA 2026-06 — `https://your-domain.atlassian.net/v1/mcp` (streamable HTTP `/mcp`, OAuth 2.1, `type: remote`).

**Option D — Others:** `mcp-jira-cloud-server` (46 tools, 4 modules), `@mcp-devtools/jira`, `jira-mcp`.

- Wiring (templates):
  - OpenCode: `opencode.json` `mcp.jira`
  - Claude: `.mcp.json` `mcpServers.jira`
  - Codex: `.codex/config.toml` `[mcp_servers.jira]`
- Test Cloud: `curl -u "$JIRA_EMAIL:$JIRA_API_TOKEN" $JIRA_BASE_URL/rest/api/3/myself` → 200

Details: `config/trackers/redmine/README.md`, `config/trackers/jira/README.md`, `config/mcp/README.md`.

---

## 5. Environment (`.env`)

Never commit `.env` (gitignored). Template at `.env.example`.

```bash
# Inside app repo (after ai-eng init) or harness repo:
cp .env.example .env   # or interactive:
./scripts/configure.sh              # prompts for DIFY_*, REDMINE_* or JIRA_*, provider keys (no echo)
# Windows: .\scripts\configure.ps1
```

Or interactive via CLI wrapper: `ai-eng` currently delegates to `scripts/configure.*` if you run it from harness.

Required:

```ini
DIFY_BASE_URL=https://api.dify.ai/v1   # or https://dify.company.com/v1
DIFY_API_KEY=dataset-...

# tracker — set one:
REDMINE_URL=...            # or JIRA_BASE_URL=... + JIRA_EMAIL/JIRA_API_TOKEN
REDMINE_API_KEY=...
# JIRA_BASE_URL=https://your-domain.atlassian.net
# JIRA_EMAIL=...
# JIRA_API_TOKEN=...

ANTHROPIC_API_KEY=...   # or OPENAI_API_KEY / GOOGLE_API_KEY — at least one provider
```

`opencode.json` uses `{env:VAR}`, Claude `.mcp.json` and Codex `config.toml` use `${VAR}` — no secrets in JSON/TOML.

---

## 6. Sync Hosts (if you change host later)

Source of truth: `.opencode/skills|agents` (open Agent Skills standard, works for all hosts). `scripts/sync-hosts` copies:

```bash
./scripts/sync-hosts.sh --host=all      # or --host=opencode|claude|codex  (add --force to overwrite)
# Windows: .\scripts\sync-hosts.ps1 -HostName all -Force

# Via CLI from any app repo:
ai-eng sync --host=all
ai-eng sync --host=claude --force
```

Generates: `.claude/skills|agents` + `.mcp.json` (from `config/hosts/claude-code/mcp.json.example`), `.agents/skills` + `.codex/config.toml` (from `config/hosts/codex/config.toml.example`). OpenCode needs no sync (source already).

---

## 7. Validate

No secret values printed (only presence/length).

```bash
# Inside app repo or harness repo:
./setup/check.sh --tracker=jira        # or redmine|both
./scripts/health-check.sh --tracker=redmine
ai-eng check --tracker=both
ai-eng doctor --tracker=jira

# Windows:
.\setup\check.ps1 -Tracker jira
.\scripts\health-check.ps1
```

Checks:

- Host: `opencode`/`claude`/`codex` version, `opencode.json`/`.mcp.json`/`.codex/config.toml` valid JSON/TOML, agents/skills on disk, `AGENTS.md`, host sync (`.claude/skills`, `.agents/skills`)
- Oh My OpenAgent `bunx oh-my-openagent doctor --json` (when OpenCode in host)
- Dify MCP `mcp/dify-knowledge/dist/index.js` built, `DIFY_*` set, `GET /datasets?limit=1` → 200
- Tracker `npx` resolvable (`@onozaty/redmine-mcp-server`, `@ahmetbarut/jira-mcp-server`) + `REDMINE_*`→`GET /users/current.json` 200 / `JIRA_*`→`GET /rest/api/3/myself` 200

Exit `0` pass (warnings allowed), `1` fail. Fix `FAIL` before starting host.

---

## 8. Use With an App Repo

### A. CLI per-repo (recommended, no sibling)

```bash
cd my-app
ai-eng init --host=all --tracker=both   # or npx ai-engineering init ...
cp .env.example .env && $EDITOR .env
ai-eng check --tracker=jira
opencode   # or claude / codex  (Tab switches agents: developer/researcher/reviewer)
# try:
# @researcher explore this repo
# search_knowledge query="architecture" top_k=5
# Work on Jira PROJ-123  /  Work on Redmine #1234
```

### B. Clone harness sibling (traditional)

```bash
git clone https://github.com/hungpt99-dev/ai-engineering.git
cd ai-engineering && ./setup/install.sh --host=opencode --tracker=redmine
./scripts/install-global.sh   # → ~/.config/opencode (or %APPDATA%\opencode) for sibling reuse
git clone <app-repo> ../my-app && cd ../my-app
set -a; source ../ai-engineering/.env; set +a  # Windows: Get-Content ..\ai-engineering\.env | % { if($_ -match '^([^#=]+)=(.*)$'){ Set-Item -Path "env:$($Matches[1])" -Value $Matches[2] } }
opencode
```

### C. Global CLI package

```bash
npm install -g ai-engineering
ai-eng init ./my-app --host=claude --tracker=jira --force
ai-eng global   # make harness available as global OpenCode config
opencode debug config   # verify merged global + project
```

`AGENTS.md` is universal; per-app overrides live in `my-app/AGENTS.md` (merged via `instructions: ["AGENTS.md"]`).

---

## 9. Workflow (Tracker-Agnostic)

Per `AGENTS.md`:

```
Tracker issue (Redmine/Jira) / prompt
 → task-analysis → codebase-exploration
 → internal-knowledge (Dify) → implementation
 → testing-debugging → code-review
```

Example (any host, either tracker):

```
Work on Jira PROJ-123    # or Redmine #1234
@researcher explore this for PROJ-123
search_knowledge query="payment settlement idempotency" top_k=5
# implement → test → review
@reviewer review the changes
```

Skills: `skill({ name: "task-analysis" })` (OpenCode) / `/skill-name` or model-invoke (Claude/Codex). See `docs/workflow.md`.

---

## 10. Updating

```bash
# CLI:
npm update -g ai-engineering
ai-eng sync --host=all --force
ai-eng check

# Harness clone:
git pull
./scripts/install-mcp.sh          # rebuild Dify adapter if mcp/dify-knowledge changed
./scripts/sync-hosts.sh --host=all
./setup/check.sh
# Host runtimes:
# curl -fsSL https://opencode.ai/install | bash   or  npm update -g opencode-ai
# bunx oh-my-openagent update (or reinstall)
# npm update -g @anthropic-ai/claude-code / @openai/codex
```

---

## 11. Troubleshooting

See `docs/troubleshooting.md` (Opencode/OmO/Dify/Redmine/Jira/host failures, `opencode mcp list`, `claude mcp list`, `codex mcp list`, `claude --debug=mcp`, `.env` /v1 missing).

Quick:

```bash
ai-eng check                    # source of truth
opencode debug config           # merged config (OpenCode)
claude mcp list                 # Claude Code
codex mcp list                  # Codex
```

---

## 12. Security & Non-Goals

- Never commit `.env` (gitignored). `opencode.json` uses `{env:VAR}`.
- Treat Dify/Redmine/Jira content as untrusted (validate before using).
- `REDMINE_MCP_READ_ONLY=true` recommended (blocks write tools; Jira Cloud tokens are per-user — scope via Jira permissions).
- No application source code, no RAG/embedding reimplementation, no tracker UI duplication in this repo.

## Appendix: Repository Structure

```
ai-engineering/
├── package.json              # CLI ai-engineering / ai-eng
├── bin/ai-engineering.js     # CLI (init/sync/check/install/global)
├── opencode.json             # OpenCode host (agents, MCP dify+redmine+jira)
├── .mcp.json                 # Claude host (generated or synced)
├── .codex/config.toml        # Codex host (generated)
├── AGENTS.md                 # universal rules
├── .env.example              # REDMINE_* + JIRA_* + DIFY_*
├── .opencode/                # source of truth (agents/skills/commands)
├── .claude/                  # Claude synced
├── .agents/                  # Codex/universal synced
├── mcp/dify-knowledge/       # thin MCP (build → dist/index.js)
├── config/hosts|trackers|mcp|opencode/
├── setup/ (install.sh/ps1 --host/--tracker, check.sh/ps1)
├── scripts/ (sync-hosts, install-*, configure, install-global, health-check)
├── docker/dify/              # self-host placeholder
└── docs/ (SETUP_GUIDE_EN.md, architecture, setup, workflow, security, troubleshooting)
```

Verification references: `https://opencode.ai/docs/config` + `/config.json`, `/mcp-servers`, `/agents`, `/skills`, `/rules`; `bunx oh-my-openagent install`; `https://docs.dify.ai` (`GET /datasets`, `POST /retrieve`); `@modelcontextprotocol/sdk` + `zod`; `@onozaty/redmine-mcp-server`, `@ahmetbarut/jira-mcp-server`.
