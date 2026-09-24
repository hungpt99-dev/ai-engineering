# Setup

## Prerequisites

| Tool | Minimum | Check | Install |
|---|---|---|---|
| Node.js | 18+ (for MCP stdio servers) | `node --version` | https://nodejs.org |
| npm | 9+ | `npm --version` | ships with Node |
| bun | latest (for Oh My OpenAgent Ultimate) | `bun --version` | `curl -fsSL https://bun.sh/install \| bash` |
| Git | 2.x | `git --version` | https://git-scm.com |
| curl | any | `curl --version` | system package manager |
| PowerShell | 5.1+ (Windows) | `$PSVersionTable` | built-in on Windows |

> Node 18+ is required because `@modelcontextprotocol/sdk` uses native `fetch` and `node:crypto`.

## Quick Start

### Linux / macOS / WSL

```bash
git clone <this-repo> ai-engineering
cd ai-engineering

# One-command setup (interactive TUI for Oh My OpenAgent)
./setup/install.sh

# If you prefer to validate only:
./setup/install.sh --check
# Or non-interactive (skip TUI, just install binaries):
./setup/install.sh --yes
```

### Windows (native PowerShell)

```powershell
git clone <this-repo> ai-engineering
cd ai-engineering

# One-command setup
.\setup\install.ps1

# Validate only:
.\setup\install.ps1 -CheckOnly
# Non-interactive:
.\setup\install.ps1 -Yes
```

Both entry points do:

1. Check prerequisites (Node ≥18, git, curl, bun).
2. Install OpenCode (`curl -fsSL https://opencode.ai/install | bash` or `npm i -g opencode-ai` fallback; on Windows: `npm i -g opencode-ai`).
3. Run `bunx oh-my-openagent install` (Ultimate for OpenCode — TUI walks through `plugin` registration + provider auth).
4. Build Dify MCP adapter (`npm --prefix mcp/dify-knowledge install && npm run build`).
5. Create `.env` from `.env.example` if missing.
6. Run `setup/check.*` validation.

## Configure Credentials

### Interactive (recommended)

```bash
# Linux/macOS/WSL
./scripts/configure.sh

# Windows
.\scripts\configure.ps1
```

Prompts for `DIFY_*`, `REDMINE_*`, provider keys. Secrets are never echoed. Writes `.env`.

### Manual

```bash
cp .env.example .env
# edit with your editor — then validate
```

Required vars (see `.env.example` for full list):

```ini
DIFY_BASE_URL=https://api.dify.ai/v1
DIFY_API_KEY=dataset-...

REDMINE_URL=https://redmine.company.com
REDMINE_API_KEY=...
REDMINE_MCP_READ_ONLY=true

ANTHROPIC_API_KEY=...   # and/or OPENAI_API_KEY, etc.
```

**How to get them:**

- **Dify:** Dify Console → Knowledge → Service API → Create key. Base URL is `https://api.dify.ai/v1` for cloud or `https://dify.company.com/v1` for self-host.
- **Redmine:** Redmine → My account → API access key → Show. Ensure REST API is enabled.
- **Providers:** `https://opencode.ai/docs/providers` — 75+ via Models.dev.

## Validate

```bash
# Linux/macOS/WSL
./setup/check.sh
# or
./scripts/health-check.sh

# Windows
.\setup\check.ps1
# or
.\scripts\health-check.ps1
```

Checks (no secret leakage — only lengths / presence):

- `opencode --version`, `opencode.json` valid JSON + required keys, agents/skills on disk
- `oh-my-openagent` CLI resolvable, `doctor --json` (if installed)
- Dify MCP built (`dist/index.js`), `DIFY_*` set, HTTP 200 to `GET /datasets?limit=1`
- Redmine MCP `npx` resolvable, `REDMINE_*` set, HTTP 200 to `GET /users/current.json`
- Exit code: `0` pass (warnings allowed), `1` fail.

Fix failures, then re-run `setup/check.*` before starting OpenCode.

## Granular Scripts

If you prefer step-by-step:

```bash
./scripts/install-opencode.sh   # or .ps1
./scripts/install-omo.sh        # bunx oh-my-openagent install
./scripts/install-mcp.sh        # build dify adapter, prime redmine npx cache
./scripts/configure.sh          # write .env
./setup/check.sh                # validate
```

## Self-hosted Dify (optional)

This repo does not vendor a full Dify deployment (see `docker/dify/README.md`). To spin one up:

```bash
git clone https://github.com/langgenius/dify.git /tmp/dify
cp -r /tmp/dify/docker/* docker/dify/
cp docker/dify/.env.example docker/dify/.env
# edit docker/dify/.env
docker compose -f docker/dify/docker-compose.yaml up -d
# then set DIFY_BASE_URL=http://localhost/v1 in this repo's .env
```

## Next: Use with an App Repo

This repo contains no app code. To work on an application, make the harness available globally first:

```bash
# One-time: install harness globally (copies to ~/.config/opencode or %APPDATA%\opencode)
./scripts/install-global.sh   # Linux/macOS/WSL
# or
.\scripts\install-global.ps1  # Windows
# Verify:
opencode debug config
```

Then any sibling clone works:

```bash
git clone <app-repo> ../my-app
cd ../my-app
# Export creds from ai-engineering (or add to shell profile / env manager):
set -a; source ../ai-engineering/.env; set +a
# PowerShell:
# Get-Content ..\ai-engineering\.env | ForEach-Object { if($_ -match '^([^#=]+)=(.*)$'){ Set-Item -Path "env:$($Matches[1])" -Value $Matches[2] } }
opencode
# Inside TUI:
#   Tab switches agents (developer / researcher / reviewer)
#   @researcher explore this codebase
#   search_knowledge query="payment settlement rules"
```

`AGENTS.md` and `opencode.json` are installed globally via `install-global.*`; per-app rules live in `my-app/AGENTS.md` (merged via `instructions: ["AGENTS.md"]`). Alternatively, keep app as a subdirectory of ai-engineering or copy `opencode.json` + `.opencode` per-project — see `README.md` for options.

## Updating

```bash
git pull
./scripts/install-mcp.sh        # rebuild adapter if mcp/dify-knowledge changed
./setup/check.sh
# To update OpenCode: curl -fsSL https://opencode.ai/install | bash  or  npm update -g opencode-ai
# To update OmO:      bunx oh-my-openagent update  (or reinstall)
```
