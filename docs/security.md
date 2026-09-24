# Security

## Secrets Management

- **Never commit `.env`.** It is gitignored. Template lives at `.env.example`.
- **Never hardcode API keys in `opencode.json`.** Use `{env:VAR}` substitution instead:
  ```json
  "environment": { "DIFY_API_KEY": "{env:DIFY_API_KEY}" }
  ```
  OpenCode resolves `{env:…}` from the shell env / `.env` at startup.
- **Never print secrets in logs or tool output.** `setup/check.*` only prints presence + length, never values. The `configure.*` scripts never echo secrets.
- **Use env var injection for CI:** export `DIFY_API_KEY`, `REDMINE_API_KEY`, etc. in your CI secret store; don't check them into git.

## Dify API Key Scope

- `DIFY_API_KEY` is a **Dataset API key** (`Authorization: Bearer …`). A single key can access **every knowledge base visible to the account that created it**.
- Restrict per knowledge base if needed: Dify Console → Knowledge Base → API Access toggle (per-base).
- Create separate keys per team/environment if broad access is risky.
- Rotate keys via Dify Console → Service API. Revoked keys return `401` (caught by `setup/check.*`).

## Redmine Access

- `REDMINE_MCP_READ_ONLY=true` is **recommended** for AI agents. It blocks write tools in `@onozaty/redmine-mcp-server` so the agent can only read issues/users/projects.
- Only set `REDMINE_MCP_READ_ONLY=false` (or omit) when you explicitly need the agent to create/update issues, log time, etc. Require human approval first.
- Redmine's REST API must be enabled; keys are per-user; scopes follow that user's permissions.
- Filter tools further with `REDMINE_MCP_TOOL_FILTER` regex if you need a narrower surface (e.g., `^(get|list|search)_`).

## Input Validation

- Treat Dify/Redmine content as **untrusted external data**. Validate before using in code (e.g., don't interpolate ticket fields into SQL/shell without escaping).
- Agents validate external input per `AGENTS.md` code-quality standards.

## Permissions & Policies

- **OpenCode permissions:** `opencode.json` sets `permission.skill.*` and per-agent `permission.edit/bash`. The researcher/reviewer agents are `edit: deny` by design.
- **Global vs project config:** Project `opencode.json` overrides global; managed config (`/Library/Application Support/opencode/` on macOS etc.) overrides all — useful for org-wide policy.
- **Policies:** `experimental.policies` can deny `provider.use` for disallowed providers:
  ```json
  "experimental": { "policies": [{ "effect": "deny", "action": "provider.use", "resource": "openai" }] }
  ```

## Network

- `opencode.json` `server` and `mcp` settings control CORS, host/port, and whether remote MCPs use OAuth or API keys.
- Remote MCP OAuth (if you add one later) is handled by `opencode mcp auth <server>` with tokens stored at `~/.local/share/opencode/mcp-auth.json` — not in this repo.

## Logging

- Log at appropriate levels; never log PII or tokens.
- MCP stdio logs go to stderr (not to the LLM context) — see `mcp/dify-knowledge/src/index.ts`.

## What to do if a secret leaks

1. Revoke/rotate in Dify/Redmine/provider console immediately.
2. Purge from git history if committed (`git filter-repo` or BFG), then force-push.
3. Check `mcp-auth.json` and shell history for residue.
4. Update `.env` via `scripts/configure.*` and re-run `setup/check.*`.

## Compliance

- `REDMINE_MCP_READ_ONLY=true` semantics are enforced by the MCP server, not just the agent prompt — the tools are removed from the tool list in read-only mode.
