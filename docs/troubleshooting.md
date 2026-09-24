# Troubleshooting

## Quick Diagnostics

```bash
# Linux/macOS/WSL
./setup/check.sh

# Windows
.\setup\check.ps1
```

Fix every `FAIL` before starting OpenCode. `WARN` is often actionable (missing optional creds, not-yet-built adapter).

## OpenCode

### `opencode: command not found`

- **Linux/macOS/WSL:** `curl -fsSL https://opencode.ai/install | bash` then reopen terminal (or `source ~/.bashrc`). Fallback: `npm install -g opencode-ai`.
- **Windows (native):** `npm install -g opencode-ai` — ensure `%APPDATA%\npm` is in `PATH`. For best experience, use WSL: https://opencode.ai/docs/windows-wsl
- **Brew (macOS/Linux):** `brew install anomalyco/tap/opencode` (tap is fresher than core `opencode`).
- Verify: `opencode --version`

### `opencode.json: invalid JSON`

- Run `node -e "JSON.parse(require('fs').readFileSync('opencode.json','utf8'))"` to locate the error (trailing comma, missing quote).
- Ensure `$schema` is `https://opencode.ai/config.json` (not `opencode.ai/...` without `https`).
- Validate MCP `type` is exactly `"local"` or `"remote"` — not `"stdio"` etc.

### `opencode mcp` tools not appearing

- Ensure `mcp.*.enabled` is `true` or omitted (defaults to enabled).
- Check `opencode debug config` to see resolved merged config (global + project + managed).
- `opencode mcp list` (and `opencode mcp debug <server>`) shows connectivity + OAuth status (for remote servers).

### Theme / keybinds / `tui` in `opencode.json`

- Those keys are deprecated there. Move TUI settings to `tui.json` (`$schema: https://opencode.ai/tui.json`). See `config/opencode/tui.example.json`.

## Oh My OpenAgent

### `bunx: command not found`

- Install bun: `curl -fsSL https://bun.sh/install | bash` (or `powershell -c "irm bun.sh/install.ps1 | iex"` on Windows), then reopen terminal.

### `bunx oh-my-openagent install` fails with `EEXIST` (global `omo` bin)

- You have an old `oh-my-openagent`/`oh-my-opencode` ≤4.19.4 installed globally that owns the `omo` bin. Do: `npm uninstall -g oh-my-openagent oh-my-opencode` or `bun pm uninstall -g oh-my-openagent`, then `bunx oh-my-openagent install`.

### `Plugin array should contain "oh-my-openagent"` warning

- In `opencode.json`, use `"plugin": ["oh-my-openagent"]`. Legacy `"oh-my-opencode"` still loads with a warning — rename it.

### `Do not use bunx omo / npx omo`

- `omo` on npm is an unrelated package. Always use `bunx oh-my-openagent` / `npx oh-my-openagent`.

### `doctor` reports failures

- Run `bunx oh-my-openagent doctor` (or `--json`) — it checks System, Configuration, TUI Plugin, Tools, Models, Telemetry, Team Mode. Follow its fix hints.

## Dify Knowledge MCP

### `Missing required env: DIFY_BASE_URL, DIFY_API_KEY`

- Copy `.env.example` to `.env`, fill `DIFY_BASE_URL` (must end with `/v1` — e.g., `https://api.dify.ai/v1`) and `DIFY_API_KEY` (Dataset key: Dify Console → Knowledge → Service API).
- Ensure build exists: `npm --prefix mcp/dify-knowledge install && npm --prefix mcp/dify-knowledge run build`.

### `401 Unauthorized`

- `DIFY_API_KEY` wrong or revoked. Re-create in Dify Console. Check that the key's account can see the target dataset.

### `403 Forbidden`

- Knowledge base has API access disabled (Dify Console → Knowledge Base → API Access toggle) or the key is scoped away from that base.

### `404 Dataset not found`

- `dataset_id` typo. List bases first: Dify MCP `list_knowledge_bases` or `curl -H "Authorization: Bearer $DIFY_API_KEY" $DIFY_BASE_URL/datasets`.

### `search_knowledge` returns no chunks

- Dify retrieval needs indexed documents. Check document status in Dify Console (indexing may be async). Try a broader query (≤250 chars, keyword-like).

### `No relevant chunks` on every query

- Check that documents are enabled for retrieval and that `score_threshold` isn't filtering everything (this adapter uses `score_threshold_enabled: false` by default).

## Redmine MCP

### `401 Unauthorized`

- `REDMINE_API_KEY` wrong or REST API disabled. Get key: Redmine → My account → API access key → Show. Ensure `Administration → Settings → API` enables REST.

### `REDMINE_URL` trailing slash / 404

- `REDMINE_URL` should be `https://redmine.example.com` (no trailing slash). The server appends paths.

### Write blocked but you expected write

- `REDMINE_MCP_READ_ONLY=true` removes write tools. Set to `false` (or omit) to enable writes — but only with approval.

### `X-Redmine-API-Key` header 403

- User lacks permission for that project/issue. Check Redmine roles.

## Jira MCP

### `401 Unauthorized (Jira)`

- `JIRA_EMAIL` / `JIRA_API_TOKEN` wrong. Cloud: `id.atlassian.com` → Security → Create API token. Data Center: `JIRA_TOKEN` (PAT) or `npx @atlassian-dc-mcp/jira setup` writes `~/.atlassian-dc-mcp/jira.env`.

### `JIRA_BASE_URL` 404

- Cloud: `https://your-domain.atlassian.net` (no trailing slash, no `/rest`). Data Center: `JIRA_HOST=jira.example.com` (domain only) or `JIRA_API_BASE_PATH=https://jira.example.com/rest`.

### `jira-mcp-server` not found / npx 404

- Package is `@ahmetbarut/jira-mcp-server` (Cloud, this repo default). Data Center uses `@atlassian-dc-mcp/jira`. Check `npx -y @ahmetbarut/jira-mcp-server --help`.

### Jira connectivity: 401/403 in `setup/check`

- Cloud test is `GET /rest/api/3/myself` with Basic `JIRA_EMAIL:JIRA_API_TOKEN`. Ensure email matches token owner and site URL correct.

## Hosts — Claude Code / Codex

### `claude: command not found` / `codex: command not found`

- Install: `npm install -g @anthropic-ai/claude-code` / `npm install -g @openai/codex`. Check `claude --version` / `codex --version`. Reopen terminal.

### Claude `claude mcp list` shows disconnected

- Check `.mcp.json` is valid JSON (`node -e "JSON.parse(require('fs').readFileSync('.mcp.json','utf8'))"`). Env uses `${VAR}` (Claude) vs `{env:VAR}` (OpenCode). Run `claude --debug=mcp` and read `~/.claude/debug/<session>.txt`.

### Codex `codex mcp list` empty

- Check `.codex/config.toml` is `[mcp_servers.xxx]` TOML, or global `~/.codex/config.toml`. Run `codex --help`. Codex scans `.agents/skills` from CWD up to repo root — ensure `scripts/sync-hosts.sh --host=codex` was run (now pre-synced).

### `.mcp.json` / `.codex/config.toml` invalid after `ai-eng init`

- Templates at `config/hosts/claude-code/mcp.json.example` / `config/hosts/codex/config.toml.example` — copy again with `ai-eng init --host=all --force` or `scripts/sync-hosts.sh --host=all --force`.

## CLI `ai-eng`

### `ai-eng: command not found` after `npm install -g ai-engineering`

- Ensure npm global bin in PATH (`%APPDATA%\npm` on Windows, `~/.npm-global/bin` or `~/.local/bin` on Linux). Try `npx ai-engineering --help` or `node ./bin/ai-engineering.js --help`.

### `ai-eng init` warns `Dify MCP adapter not present`

- Since `1014bfc` `ai-eng init` auto-copies `mcp/` + builds `dist` in target, this should not happen. If it does, manually: `cp -r <harness>/mcp <target>/mcp && npm --prefix <target>/mcp/dify-knowledge install && npm --prefix <target>/mcp/dify-knowledge run build`.

### `npx ai-engineering` 404

- Package not yet published to npm registry. Use `npx github:hungpt99-dev/ai-engineering init` or `npm install -g` from clone (`npm link` / `npm pack`). Publish via `npm publish --access public` with `NPM_TOKEN`.

## Skills / Agents

### Skill not showing up

- Verify `SKILL.md` is all caps, frontmatter has `name` and `description`, directory name matches `name`, and `permission.skill` allows it (`deny` hides the skill).
- Run `opencode debug config` to check resolved permissions.

### Agent not appearing / wrong permissions

- `opencode.json` `agent.*.mode` must be `primary` or `subagent`. `edit: deny` agents cannot write.
- Markdown agents live at `.opencode/agents/<name>.md` — filename becomes agent name. Check `hidden: true` isn't hiding it from autocomplete.

### `AGENTS.md` not loaded

- Project `AGENTS.md` must be at repo root or traversed up to git worktree. Check `instructions` field in `opencode.json` — it adds extra files but does not replace `AGENTS.md`.

## Setup Scripts

### `install.sh: permission denied`

- `chmod +x setup/install.sh setup/check.sh scripts/*.sh` then re-run.

### PowerShell `execution policy` error

- `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned` then `.\setup\install.ps1`.

### `setup/check.sh` reports `/tmp/dify_check.json` with HTML

- `DIFY_BASE_URL` points to a web UI, not the API `/v1` endpoint. Append `/v1` (e.g., `https://dify.company.com/v1`).

## Getting Help

- OpenCode docs: https://opencode.ai/docs
- Oh My OpenAgent install guide: https://raw.githubusercontent.com/code-yeongyu/oh-my-openagent/refs/heads/dev/docs/guide/installation.md
- Dify Knowledge API: https://docs.dify.ai/en/api-reference/knowledge-bases/retrieve-chunks-from-a-knowledge-base-test-retrieval
- Redmine MCP: https://github.com/onozaty/redmine-mcp-server
- File an issue in this repo with `setup/check.*` output (redact keys).
