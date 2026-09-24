# AI Engineering — Production-Ready Setup Repository

Complete, reusable AI coding environment for a software development team. Clone → run setup → OpenCode + Oh My OpenAgent + MCP + Skills + Agents + Rules → configure credentials → work on any app repo.

```
git clone <this-repo>
        ↓
run setup (install.sh / install.ps1)
        ↓
OpenCode + Oh My OpenAgent + MCP + Skills + Agents + Rules
        ↓
configure credentials (.env)
        ↓
clone any application repository
        ↓
start OpenCode
        ↓
AI is ready to work
```

Reusable across projects:

```
ai-engineering/   ← this repo
    ├── Project A  ← app repo (sibling checkout, opencode started here)
    ├── Project B
    └── Project C
```

> This repo contains **no application source code**, no RAG/embedding/vector DB re-implementation, and no Redmine duplication. It is the AI Engineering harness only.

## Architecture

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

| Layer | Role | Package / Config |
|---|---|---|
| **OpenCode** | Primary coding agent — inspect, edit, test, debug, review | `opencode.json` (`$schema: https://opencode.ai/config.json`), `AGENTS.md` |
| **Oh My OpenAgent** | Orchestration — multi-agent workflows, background tasks, recovery | `oh-my-openagent` (npm), `plugin: ["oh-my-openagent"]` |
| **Redmine MCP** | Ticket context — description, acceptance criteria, history | `@onozaty/redmine-mcp-server` (npx, `REDMINE_MCP_READ_ONLY=true`) |
| **Dify Knowledge** | Internal docs / business rules / API contracts (RAG owner) | Dify Cloud / self-host, `GET /datasets`, `POST /datasets/{id}/retrieve` |
| **Dify MCP** | Thin adapter — 3 tools only | `mcp/dify-knowledge/` (Node, stdio, `search_knowledge / list_knowledge_bases / get_document`) |
| **Local Git** | Source ops — `bash` + `git` directly | No Git MCP for basic ops (intentional) |

Details: `docs/architecture.md`

## Quick Start

### Linux / macOS / WSL

```bash
git clone <this-repo> ai-engineering && cd ai-engineering
./setup/install.sh          # interactive TUI for Oh My OpenAgent
# or: ./setup/install.sh --yes   # non-interactive
# or: ./setup/install.sh --check # validate only
./scripts/configure.sh      # write .env (secrets not echoed)
./setup/check.sh            # validate (no secret leakage)
opencode                    # start TUI — Tab switches agents
```

### Windows (PowerShell)

```powershell
git clone <this-repo> ai-engineering; cd ai-engineering
.\setup\install.ps1
.\scripts\configure.ps1
.\setup\check.ps1
opencode
```

**What `setup/install.*` does:** checks Node ≥18 / git / curl / bun → installs OpenCode (`curl -fsSL https://opencode.ai/install | bash` or `npm i -g opencode-ai`) → `bunx oh-my-openagent install` → builds `mcp/dify-knowledge` → creates `.env` from `.env.example` → validates.

**Granular steps** (if you prefer):

```bash
./scripts/install-opencode.sh  # or .ps1
./scripts/install-omo.sh
./scripts/install-mcp.sh
./scripts/configure.sh
./setup/check.sh
```

## Configuration

### Credentials (`.env`)

Copy and fill — never commit `.env`:

```bash
cp .env.example .env   # then edit, or use scripts/configure.*
```

| Var | Description | Where to get it |
|---|---|---|
| `DIFY_BASE_URL` | `https://api.dify.ai/v1` or `https://dify.company.com/v1` | Dify instance URL + `/v1` |
| `DIFY_API_KEY` | Dataset API key (`Bearer`) — one key can access all visible bases | Dify Console → Knowledge → Service API |
| `REDMINE_URL` | `https://redmine.company.com` | Your Redmine |
| `REDMINE_API_KEY` | API key | Redmine → My account → API access key |
| `REDMINE_MCP_READ_ONLY` | `true` (recommended) | Blocks write tools |
| `ANTHROPIC_API_KEY` / `OPENAI_API_KEY` | At least one provider | `https://opencode.ai/docs/providers` |

`opencode.json` references them via `{env:VAR}` — no secrets in JSON.

### OpenCode Config

Project config at `opencode.json` (checked into git, no secrets):

- `$schema: https://opencode.ai/config.json`
- `plugin: ["oh-my-openagent"]` — prefer new name; legacy `oh-my-opencode` loads with warning
- `instructions: ["AGENTS.md"]` — global rules
- `mcp: { dify-knowledge (local node), redmine (npx) }`
- `agent: { developer (primary), researcher (subagent read-only), reviewer (subagent read-only) }`
- `permission.skill.*: allow`

TUI settings: `config/opencode/tui.example.json` → `tui.json` (`$schema: https://opencode.ai/tui.json`).

Global user overrides: `~/.config/opencode/opencode.json` (not in this repo).

### Agents

| Agent | File | Mode | Access | Use |
|---|---|---|---|---|
| **developer** | `.opencode/agents/developer.md` | primary | `edit: allow, bash: allow` | Implement, test, debug |
| **researcher** | `.opencode/agents/researcher.md` | subagent | `edit: deny` | Read-only codebase & knowledge research |
| **reviewer** | `.opencode/agents/reviewer.md` | subagent | `edit: deny` | Read-only review (security/perf/correctness) |

Invoke: `Tab` switches primary agents; `@researcher` / `@reviewer` mentions subagents.

### Skills

| Skill | Location | Purpose |
|---|---|---|
| `task-analysis` | `.opencode/skills/task-analysis/SKILL.md` | Requirements → acceptance criteria → plan |
| `codebase-exploration` | `.opencode/skills/codebase-exploration/SKILL.md` | Structure, stack, patterns, risks before editing |
| `internal-knowledge` | `.opencode/skills/internal-knowledge/SKILL.md` | Dify lookup when domain context needed |
| `implementation` | `.opencode/skills/implementation/SKILL.md` | Smallest reasonable change, KISS/YAGNI/DRY/SOLID |
| `testing-debugging` | `.opencode/skills/testing-debugging/SKILL.md` | Test → analyze → fix root cause → repeat |
| `code-review` | `.opencode/skills/code-review/SKILL.md` | Correctness/security/perf/compat/tests |

Load via native `skill` tool: `skill({ name: "task-analysis" })`.

## Validation

```bash
./setup/check.sh        # Linux/macOS/WSL
.\setup\check.ps1       # Windows
# Aliases:
./scripts/health-check.sh / .ps1
```

Checks (no secret values printed, only presence/length):

- `opencode --version`, `opencode.json` valid JSON + required keys
- Agents/skills/`AGENTS.md` on disk
- `oh-my-openagent` resolvable + `doctor --json`
- `mcp/dify-knowledge/dist/index.js` built; `DIFY_*` → `GET /datasets?limit=1` 200
- `npx @onozaty/redmine-mcp-server` resolvable; `REDMINE_*` → `GET /users/current.json` 200

Exit `0` pass (warnings allowed), `1` fail.

## Workflow

Per `AGENTS.md`, every task:

```
Redmine / prompt → task-analysis → codebase-exploration
  → internal-knowledge (if needed) → implementation
  → testing-debugging → code-review
```

Example in OpenCode TUI:

```
Work on Redmine #1234
@researcher explore this for #1234
search_knowledge query="payment settlement idempotency" top_k=5
# implement → test → review
@reviewer review the changes
```

Full workflow: `docs/workflow.md`

## Working on an App Repo

This repo stays as the **harness** — not the app. Two reuse patterns:

**A. Global install (recommended for sibling clones):**

```bash
# Inside ai-engineering:
./scripts/install-global.sh        # Linux/macOS/WSL
# or
.\scripts\install-global.ps1       # Windows
# Copies opencode.json + .opencode/agents/skills/commands + AGENTS.md to ~/.config/opencode (or %APPDATA%\opencode)

# Then any app repo sibling works:
git clone <app-repo> ../my-app
cd ../my-app
# Export creds from ai-engineering (or add to shell profile):
set -a; source ../ai-engineering/.env; set +a   # bash
# PowerShell: Get-Content ..\ai-engineering\.env | ForEach-Object { if($_ -match '^([^#=]+)=(.*)$'){ Set-Item -Path "env:$($Matches[1])" -Value $Matches[2] } }
opencode
# In TUI: Tab switches developer/researcher/reviewer; skill({ name: "task-analysis" })
```

Verify global wiring: `opencode debug config`

**B. Keep app inside harness (simplest, no global step):**

```bash
git clone <app-repo> ./workspace/my-app   # inside ai-engineering
cd workspace/my-app
opencode   # .opencode ancestors not auto-discovered across git boundaries — prefer A or copy config
```

**C. Per-project copy:**

```bash
cp ../ai-engineering/opencode.json ./opencode.json
cp -r ../ai-engineering/.opencode ./.opencode
cp ../ai-engineering/AGENTS.md ./AGENTS.md
# Edit for app-specific overrides, commit to app repo if desired
opencode
```

`AGENTS.md` travels with the harness globally; per-app rules live in `my-app/AGENTS.md` merged via `instructions: ["AGENTS.md"]` + OpenCode's instruction discovery.

## Self-hosted Dify

See `docker/dify/README.md` — vendor upstream `https://github.com/langgenius/dify` compose; this repo's `docker/dify/` is a placeholder with instructions (avoids shipping a stale heavy compose).

## Docs

- `docs/architecture.md` — component details + decisions
- `docs/setup.md` — prerequisites + step-by-step install
- `docs/workflow.md` — mandatory task flow + examples
- `docs/security.md` — secrets, scopes, read-only, policies
- `docs/troubleshooting.md` — `setup/check` failures, OpenCode/OmO/Dify/Redmine fixes
- `config/mcp/README.md` — MCP wiring rationale
- `mcp/dify-knowledge/README.md` — adapter build/test

## Repository Structure

```
ai-engineering/
├── opencode.json              # project config (agents, MCP, plugin)
├── AGENTS.md                  # global rules (loaded as instructions)
├── .env.example               # template
├── .opencode/
│   ├── agents/                # developer / researcher / reviewer
│   ├── skills/                # 6 SKILL.md
│   └── commands/              # health, research
├── mcp/
│   └── dify-knowledge/        # thin adapter (src → dist/index.js)
├── config/
│   ├── opencode/              # example JSONs
│   └── mcp/                   # redmine/dify snippets
├── setup/
│   ├── install.sh / .ps1      # unified entry point
│   └── check.sh / .ps1        # validation
├── scripts/
│   ├── install-opencode.*     # opencode alone
│   ├── install-omo.*          # oh-my-openagent alone
│   ├── install-mcp.*          # build dify + prime redmine npx
│   ├── install-global.*       # copy harness to ~/.config/opencode for sibling reuse
│   ├── configure.*            # interactive .env writer
│   └── health-check.*         # alias to setup/check
├── docker/
│   └── dify/                  # self-host placeholder
└── docs/
    ├── architecture.md
    ├── setup.md
    ├── workflow.md
    ├── security.md
    └── troubleshooting.md
```

## Verification (What Was Checked)

- OpenCode config schema & locations: https://opencode.ai/docs/config, https://opencode.ai/config.json
- MCP servers schema: https://opencode.ai/docs/mcp-servers (`type: local|remote`, `command`, `environment`, `{env:VAR}`)
- Agents: https://opencode.ai/docs/agents (markdown `---description/mode/permission---` + `opencode.json` `agent{}`)
- Skills: https://opencode.ai/docs/skills (`.opencode/skills/<name>/SKILL.md`, frontmatter `name/description`)
- Rules: https://opencode.ai/docs/rules (`AGENTS.md` + `instructions: ["AGENTS.md"]`)
- Oh My OpenAgent: `oh-my-openagent` (dual `oh-my-opencode`), `bunx oh-my-openagent install`, `plugin: ["oh-my-openagent"]`, https://raw.githubusercontent.com/code-yeongyu/oh-my-openagent/refs/heads/dev/docs/guide/installation.md
- Dify Knowledge API: `GET /datasets`, `POST /datasets/{id}/retrieve`, `GET /datasets/{id}/documents/{doc_id}`, `Authorization: Bearer {API_KEY}`, https://docs.dify.ai
- MCP SDK: `@modelcontextprotocol/sdk` + `zod`, `McpServer` + `StdioServerTransport`
- Redmine MCP: `@onozaty/redmine-mcp-server` (comprehensive API, `REDMINE_MCP_READ_ONLY`), https://github.com/onozaty/redmine-mcp-server
- No brain-dead local `git` MCP — `bash` + `git` directly per spec.

## License

MIT — see `LICENSE` (add if distributing).
