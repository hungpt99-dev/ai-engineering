---
name: code-review
description: Review correctness, security, concurrency, performance, error handling, logging, compatibility, tests, and maintainability.
---

# Code Review

Review as a read-only reviewer. Do not modify source code in this skill; produce findings.

## Scope

- **Correctness** — logic matches requirements & acceptance criteria
- **Security** — input validation, auth, secrets, injection, exposure
- **Concurrency** — races, locking, transactional boundaries
- **Performance** — N+1, allocations, hot paths, async correctness
- **Database access** — queries, indexes, transactions, migrations
- **Error handling** — explicit, not swallowed; appropriate recovery
- **Logging** — useful diagnostics; no secrets/PII
- **Backward compatibility** — API, schema, config, migration
- **Tests** — coverage (happy path + edge cases + failure modes)
- **Maintainability** — naming, cohesion, duplication, magic literals

## Process

1. **Gather context**
   - Requirements / acceptance criteria (Redmine or user prompt).
   - Internal knowledge if domain rules affect correctness (Dify MCP if needed).
   - `git diff` — focus on what actually changed.

2. **Inspect**
   - Read each changed file with surrounding context (`path:line`).
   - Check callers and downstream consumers.
   - Verify types and contracts.

3. **Evaluate**
   - For each dimension above, note blockers vs suggestions.
   - Consider whether tests are sufficient; propose missing cases.

4. **Report**

## Output

- **Verdict:** `APPROVE` | `APPROVE_WITH_COMMENTS` | `REQUEST_CHANGES`
- **Blockers** (must-fix) — with `path:line` and rationale
- **Suggestions** — with `path:line`
- **Missing tests / edge cases**
- **Security notes** (if any)

Be concise and objective. No superlatives or emotional validation.

## Anti-patterns

- Approving without inspecting the diff.
- Flagging style nits as blockers.
- Missing security or data-integrity issues.
