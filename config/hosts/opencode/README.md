# OpenCode — Host Config (default)

Default host. `opencode.json` at repo root is the canonical config.

- **Skills:** `.opencode/skills/<name>/SKILL.md` (+ `~/.config/opencode/skills/`)
- **Agents:** `.opencode/agents/<name>.md`
- **MCP:** `opencode.json` `mcp{}` (see `config/mcp/`)
- **Rules:** `AGENTS.md` (+ `instructions: ["AGENTS.md"]` in opencode.json)
- **Plugin:** `oh-my-openagent` (`plugin: ["oh-my-openagent"]`, installed via `bunx oh-my-openagent install`)

No extra sync needed for OpenCode — source of truth already lives in `.opencode/`. To reuse globally:

```bash
./scripts/install-global.sh   # copies to ~/.config/opencode
```

For other hosts, run `scripts/sync-hosts.sh --host=claude|codex|all`.
