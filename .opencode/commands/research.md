---
description: Research task, codebase, and internal knowledge for a given issue
agent: build
---

Research the task described by `$ARGUMENTS`.

1. If `$ARGUMENTS` contains a Redmine issue ID/URL, fetch it via Redmine MCP.
2. Delegate to `@researcher` for codebase exploration (read-only).
3. If domain/business context is needed, call Dify MCP `search_knowledge` / `list_knowledge_bases`.
4. Return a structured report: task summary, relevant files (`path:line`), stack/patterns, internal knowledge findings (or "no relevant chunk"), dependencies/risks, unknowns.
