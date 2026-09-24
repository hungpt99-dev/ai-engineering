# Claude Code — Host Config

## Install Claude Code

```bash
npm install -g @anthropic-ai/claude-code
claude --version
```

Docs: https://code.claude.com/docs

## MCP

Claude Code uses `.mcp.json` at repo root (project) or `~/.claude/settings.json` (global):

```json
{
  "mcpServers": {
    "dify-knowledge": {
      "command": "node",
      "args": ["mcp/dify-knowledge/dist/index.js"],
      "env": { "DIFY_BASE_URL": "${DIFY_BASE_URL}", "DIFY_API_KEY": "${DIFY_API_KEY}" }
    },
    "redmine": {
      "command": "npx",
      "args": ["-y", "@onozaty/redmine-mcp-server"],
      "env": { "REDMINE_URL": "${REDMINE_URL}", "REDMINE_API_KEY": "${REDMINE_API_KEY}" }
    }
  }
}
```

For Jira, see `config/trackers/jira/`. Example:

```json
"jira": {
  "command": "npx",
  "args": ["-y", "@ahmetbarut/jira-mcp-server"],
  "env": { "JIRA_BASE_URL": "${JIRA_BASE_URL}", "JIRA_EMAIL": "${JIRA_EMAIL}", "JIRA_API_TOKEN": "${JIRA_API_TOKEN}" }
}
```

Template at `config/hosts/claude-code/mcp.json.example`.

## Skills

- Project: `.claude/skills/<name>/SKILL.md`
- Global: `~/.claude/skills/<name>/SKILL.md`

This repo's source is `.opencode/skills/`; run `scripts/sync-hosts.sh --host=claude` to sync.

## Agents

- `.claude/agents/<name>.md` (same frontmatter as OpenCode agents, but Claude ignores `mode:` and uses its own delegation)

Sync via `scripts/sync-hosts.sh`.

## Rules

- `CLAUDE.md` at root or `.claude/CLAUDE.md`. Claude also reads `AGENTS.md` fallback if `CLAUDE.md` absent. This repo ships `AGENTS.md` which works.

## Verify

```bash
claude mcp list
claude --debug=mcp  # debug logs: ~/.claude/debug/<session>.txt
/skills  # lists discovered skills
```
