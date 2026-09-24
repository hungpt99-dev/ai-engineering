# AI Engineering — Production-Ready Setup Repository

Host-agnostic, tracker-pluggable AI coding harness for software teams. Works with **OpenCode / Claude Code / Codex** and **Redmine / Jira** (pick one or both) — same `AGENTS.md` + skills + adapters.

```
git clone <this-repo>
        ↓
run setup --host=... --tracker=...   (install.sh / install.ps1)
        ↓
Host + MCP + Skills + Agents + Rules
        ↓
configure credentials (.env)
        ↓
clone any application repository
        ↓
start chosen host (opencode | claude | codex)
        ↓
AI is ready to work
```

Reusable across projects:

```
ai-engineering/   ← this repo
    ├── Project A  ← app repo (sibling, host started here)
    ├── Project B
    └── Project C
```

> No application source code, no RAG/embedding/vector DB duplication, no tracker UI duplication. This repo is the harness only.

## Architecture — pluggable hosts & trackers

```
                ┌─────────────┐ ┌─────────────┐ ┌─────────────┐
                │  OpenCode   │ │ Claude Code │ │  Codex CLI  │  ← --host
                │  + OhMy OMO │ │             │ │             │
                └──────┬──────┘ └──────┬──────┘ └──────┬──────┘
                       └───────────────┼───────────────┘
                                       │
              ┌────────────────────────┼────────────────────────┐
              │                        │                        │
              ▼                        ▼                        ▼
        Tracker MCP               Dify MCP                Local Git  ← --tracker
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

| Layer | Role | Package / Config |
|---|---|---|
| **Hosts** (pick `opencode`/`claude`/`codex`/`all`) | Coding agent | OpenCode `opencode.json` / Claude `.mcp.json` / Codex `.codex/config.toml` |
| **Oh My OpenAgent** | Orchestration for OpenCode host | `oh-my-openagent`, `plugin: ["oh-my-openagent"]` |
| **Tracker MCP** (pick `redmine`/`jira`/`both`) | Ticket context | Redmine `@onozaty/redmine-mcp-server` / Jira `@ahmetbarut/jira-mcp-server` (or Data Center/Rovo) |
| **Dify Knowledge** | Internal docs / business rules (RAG owner) | Dify Cloud/self-host, `GET /datasets`, `POST /datasets/{id}/retrieve` |
| **Dify MCP** | Thin adapter — 3 tools only | `mcp/dify-knowledge/` (`search_knowledge / list_knowledge_bases / get_document`) |
| **Local Git** | Source ops — `bash` + `git` directly | No Git MCP for basic ops |

Details: `docs/architecture.md`, `config/hosts/README.md`, `config/trackers/`, `config/mcp/README.md`

## Quick Start

### Linux / macOS / WSL

```bash
git clone <this-repo> ai-engineering && cd ai-engineering

# Default: OpenCode + Redmine
./setup/install.sh
# Explicit:
./setup/install.sh --host=opencode --tracker=redmine
# Claude + Jira:
./setup/install.sh --host=claude --tracker=jira
# Codex + Jira:
./setup/install.sh --host=codex --tracker=jira
# All hosts + both trackers:
./setup/install.sh --host=all --tracker=both

# Other flags:
./setup/install.sh --yes          # non-interactive
./setup/install.sh --check        # validate only
./scripts/configure.sh            # write .env (secrets not echoed)
./setup/check.sh                  # validate (no secret leakage)
./scripts/sync-hosts.sh --host=all  # sync .opencode → .claude/.agents

# Start host
opencode   # or claude  or  codex
```

### Windows (PowerShell)

```powershell
git clone <this-repo> ai-engineering; cd ai-engineering

# Default: OpenCode + Redmine
.\setup\install.ps1
# Explicit:
.\setup\install.ps1 -Host claude -Tracker jira
.\setup\install.ps1 -Host all -Tracker both

.\scripts\configure.ps1
.\setup\check.ps1
.\scripts\sync-hosts.ps1 -HostName all

opencode  # or claude  or codex
```

**What `setup/install.*` does:** checks Node ≥18 / git / curl / bun → installs chosen host runtime → (if OpenCode) `bunx oh-my-openagent install` → `scripts/sync-hosts` → builds `mcp/dify-knowledge` → primes tracker MCP `npx` caches → creates `.env` → validates.

**Granular steps:**

```bash
./scripts/install-opencode.sh  # or .ps1
./scripts/install-omo.sh
./scripts/install-mcp.sh        # tracker arg optional
./scripts/sync-hosts.sh --host=claude
./scripts/configure.sh
./setup/check.sh
```

## Configuration

### Credentials (`.env`) — pluggable tracker

```bash
cp .env.example .env   # then edit, or use scripts/configure.*
```

| Var | Description | Where to get it |
|---|---|---|
| `DIFY_BASE_URL` | `https://api.dify.ai/v1` or `https://dify.company.com/v1` | Dify instance URL + `/v1` |
| `DIFY_API_KEY` | Dataset API key (`Bearer`) | Dify Console → Knowledge → Service API |
| `REDMINE_URL` | `https://redmine.company.com` | Redmine — if using Redmine |
| `REDMINE_API_KEY` | API key | Redmine → My account → API access key |
| `JIRA_BASE_URL` | `https://your-domain.atlassian.net` | Jira Cloud — if using Jira |
| `JIRA_EMAIL` / `JIRA_API_TOKEN` | Email + token | `id.atlassian.com` → Security → Create API token |
| `ANTHROPIC_API_KEY` / `OPENAI_API_KEY` | At least one provider | https://opencode.ai/docs/providers (OpenCode) or provider docs |

Only configure the tracker you use — `setup/check.*` warns for the other, fails only for the chosen `--tracker`.

`opencode.json` uses `{env:VAR}`, Claude `.mcp.json` uses `${VAR}`, Codex `config.toml` uses `${VAR}` — no secrets in JSON/TOML.

### Host configs

| Host | Config file (this repo) | Installed location |
|---|---|---|
| OpenCode (default) | `opencode.json` (+ `config/opencode/opencode.example.json`) | `.opencode/` + `opencode.json` (project) or `~/.config/opencode/` (global via `install-global.*`) |
| Claude Code | `config/hosts/claude-code/mcp.json.example` → `.mcp.json` | `.claude/skills/`, `.mcp.json` |
| Codex | `config/hosts/codex/config.toml.example` → `.codex/config.toml` | `.agents/skills/` (universal), `.codex/config.toml` |

TUI/extra: `config/opencode/tui.example.json` → `tui.json`.

Sync: `scripts/sync-hosts.sh --host=claude|codex|all` copies `.opencode/skills` + `.opencode/agents` to host dirs.

### Agents (host-agnostic)

| Agent | Source | Mode | Access | Use |
|---|---|---|---|---|
| **developer** | `.opencode/agents/developer.md` | primary | `edit: allow` | Implement, test, debug |
| **researcher** | `.opencode/agents/researcher.md` | subagent | `edit: deny` | Read-only research |
| **reviewer** | `.opencode/agents/reviewer.md` | subagent | `edit: deny` | Read-only review |

Synced to `.claude/agents/` (Claude) and `.agents/` (universal). Invoke: `@researcher` / `@reviewer`, or host's Tab/agent switch.

### Skills (host-agnostic, open standard)

| Skill | Source | Purpose |
|---|---|---|
| `task-analysis` | `.opencode/skills/task-analysis/SKILL.md` | Requirements → plan |
| `codebase-exploration` | `.opencode/skills/codebase-exploration/SKILL.md` | Structure/stack/risks |
| `internal-knowledge` | `.opencode/skills/internal-knowledge/SKILL.md` | Dify lookup |
| `implementation` | `.opencode/skills/implementation/SKILL.md` | Smallest change |
| `testing-debugging` | `.opencode/skills/testing-debugging/SKILL.md` | Test loop |
| `code-review` | `.opencode/skills/code-review/SKILL.md` | Review |

Source at `.opencode/skills/`; synced to `.claude/skills/` and `.agents/skills/`. Load via `skill({ name: "…" })` (OpenCode), `/skill-name` or model-invoke (Claude/Codex).

## Validation

```bash
./setup/check.sh --tracker=redmine   # or jira / both
.\setup\check.ps1 -Tracker jira
./scripts/health-check.sh / .ps1  # aliases
```

Checks (no secret values):

- `opencode`/`claude`/`codex` version, `opencode.json`/` .mcp.json`/`config.toml` valid, agents/skills on disk, `AGENTS.md`
- `oh-my-openagent` (when OpenCode host), `mcp/dify-knowledge/dist/index.js` built, `DIFY_*` → `GET /datasets?limit=1` 200
- Tracker `npx` resolvable + `REDMINE_*`/ `JIRA_*` → connectivity 200
- Host sync: `.claude/skills`, `.agents/skills`, `.mcp.json`, `.codex/config.toml`

Exit `0` pass (warnings allowed), `1` fail.

## Workflow — tracker-agnostic

Per `AGENTS.md`:

```
Tracker issue (Redmine/Jira) / prompt → task-analysis → codebase-exploration
  → internal-knowledge (if needed) → implementation
  → testing-debugging → code-review
```

Example (any host, either tracker):

```
Work on Jira PROJ-123  # or Redmine #1234
@researcher explore this for PROJ-123
search_knowledge query="payment settlement idempotency" top_k=5
# implement → test → review
@reviewer review the changes
```

Full workflow: `docs/workflow.md`

## Working on an App Repo

Two reuse patterns:

**A. Global install (sibling clones, recommended for OpenCode):**

```bash
./scripts/install-global.sh   # or .ps1 → ~/.config/opencode
# Then:
git clone <app-repo> ../my-app && cd ../my-app
set -a; source ../ai-engineering/.env; set +a  # or shell profile
opencode   # or claude/codex if host=all
```

**B. Per-project / synced:**

```bash
./scripts/sync-hosts.sh --host=all
cp .mcp.json ../my-app/.mcp.json           # for Claude
cp -r .agents ../my-app/.agents            # for Codex
cp opencode.json ../my-app/opencode.json   # for OpenCode (or install-global)
```

`AGENTS.md` is universal; per-app overrides live in `my-app/AGENTS.md`.

## Self-hosted Dify

See `docker/dify/README.md` — vendor upstream `https://github.com/langgenius/dify` compose; `docker/dify/` is placeholder.

## Docs

- `docs/architecture.md` — host/tracker matrix + decisions
- `docs/setup.md` — host/tracker flags + per-host steps
- `docs/workflow.md` — tracker-agnostic task flow
- `docs/security.md` — secrets, scopes, read-only, policies
- `docs/troubleshooting.md` — host/tracker failures
- `config/hosts/README.md` + `config/hosts/<host>/README.md`
- `config/trackers/redmine/README.md` + `config/trackers/jira/README.md`
- `config/mcp/README.md` — MCP wiring
- `mcp/dify-knowledge/README.md`

## Repository Structure

```
ai-engineering/
├── opencode.json              # OpenCode host (agents, MCP for dify+redmine+jira)
├── .mcp.json                  # (generated) Claude host
├── .codex/config.toml         # (generated) Codex host
├── AGENTS.md                  # universal rules
├── .env.example               # REDMINE_* + JIRA_* (pick one)
├── .opencode/                 # source of truth (agents/skills/commands)
├── .claude/                   # (generated) Claude
├── .agents/                   # (generated) Codex/universal
├── mcp/dify-knowledge/        # thin adapter
├── config/
│   ├── hosts/                 # per-host templates + README
│   ├── trackers/              # per-tracker docs
│   ├── opencode/              # opencode examples
│   └── mcp/                   # redmine/jira/dify snippets
├── setup/                     # install.sh/ps1 --host/--tracker, check.sh/ps1
├── scripts/                   # install-*, sync-hosts.*, configure.*, install-global.*
├── docker/dify/               # self-host placeholder
└── docs/
```

## Verification (What Was Checked)

- OpenCode `opencode.json` + `opencode.ai/config.json`, Claude `.mcp.json` (`mcpServers`), Codex `config.toml` (`[mcp_servers]`), Agents `---description/mode/permission---`, Skills `SKILL.md` (`name/description`), Rules `AGENTS.md`
- Oh My OpenAgent `bunx oh-my-openagent install`, Dify `GET /datasets` / `POST /retrieve`, MCP SDK `@modelcontextprotocol/sdk` + `zod`
- Redmine `@onozaty/redmine-mcp-server`, Jira `@ahmetbarut/jira-mcp-server` (+ alternatives `@atlassian-dc-mcp/jira`, Rovo, `mcp-jira-cloud-server`), no local Git MCP
- Host-agnostic `scripts/sync-hosts` + `--host`/`--tracker` flags + `setup/check` pluggable validation

## License

MIT
