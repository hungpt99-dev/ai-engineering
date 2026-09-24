# Workflow

## Mandatory Task Flow

Every implementation task MUST follow this order (per `AGENTS.md`):

```
Understand task (Redmine / user prompt)
  → Research codebase (explore, grep, read)
  → Consult internal knowledge (Dify MCP) when domain/business context is needed
  → Create plan (task-analysis skill)
  → Implement (implementation skill)
  → Test & debug (testing-debugging skill)
  → Review (code-review skill)
```

Skipping research or Dify lookup when business/architecture context is relevant is a violation.

## Example Session

### 1. Get the task

User in OpenCode TUI:

```
Work on Redmine #1234
```

Or directly:

```
Redmine issue https://redmine.company.com/issues/1234 — implement it
```

The agent calls Redmine MCP `get_issue` / `getIssue` to fetch description, acceptance criteria, comments/history. Do not start from title alone.

### 2. Task analysis

Load the skill:

```
skill({ name: "task-analysis" })
```

It produces:

- **Summary** (2–3 sentences)
- **Acceptance criteria** (checklist — proposed items marked `PROPOSED` if missing in ticket)
- **Affected components** (from codebase exploration)
- **Unknowns / questions**
- **Steps** (ordered increments)
- **Verification** (tests / manual checks)
- **Risks & mitigations**

Wait for user confirmation if the task is ambiguous or high-risk before coding.

### 3. Codebase exploration

```
skill({ name: "codebase-exploration" })
# or delegate
@researcher explore the codebase for issue #1234
```

The researcher is read-only (`edit: deny`). It checks:

1. Project structure & workspaces
2. Tech stack & versions
3. Entry points
4. Affected modules (`grep` / `glob` / `read`)
5. Existing patterns (naming, error handling, logging)
6. Tests (where they live, how to run)
7. Dependencies
8. Side effects (migrations, compat, perf)

Output cites `path:line` for every claim.

### 4. Internal knowledge

If the task touches architecture, API contracts, business rules, or conventions:

```
skill({ name: "internal-knowledge" })
# which calls Dify MCP:
# list_knowledge_bases { keyword: "payment" }
# search_knowledge { query: "settlement idempotency business rule", top_k: 5 }
```

- Queries must be ≤250 chars.
- If Dify returns no chunk, the agent must state: “No relevant internal knowledge found for ‘…’” — never hallucinate.

### 5. Implementation

```
skill({ name: "implementation" })
```

Rules: smallest reasonable change, KISS/YAGNI/DRY/SOLID pragmatically, match existing project patterns, type-safe, explicit error handling, no unrelated rewrites.

The agent uses the **developer** primary agent (`Tab` to switch) which has `edit: allow, bash: allow`.

### 6. Testing & debugging

```
skill({ name: "testing-debugging" })
```

Loop:

```
Implement → Run relevant tests → Analyze failure → Fix root cause → Re-run → Repeat until stable
```

- Run smallest relevant slice first, then broader suite.
- Never hide failures with broader `catch`, increased timeouts, or suppressed assertions.

### 7. Review

```
skill({ name: "code-review" })
# or delegate
@reviewer review the changes
```

Reviewer is read-only. Checks correctness, security, concurrency, performance, DB, error handling, logging, compat, tests, maintainability. Verdict: `APPROVE | APPROVE_WITH_COMMENTS | REQUEST_CHANGES` with `path:line` findings.

## Parallel Work

- Use the `task` tool to run independent research/implementation slices in parallel.
- Use Oh My OpenAgent background tasks where appropriate (repeated implementation/test/fix cycles, recovery).
- For multi-app teams, keep AI Engineering as a sibling checkout — it is reusable across `Project A/B/C`:

```
ai-engineering/   ← this repo
  ├── Project A   ← app repo (opencode started here)
  ├── Project B
  └── Project C
```

## Skills Reference

| Skill | When | Mode |
|---|---|---|
| `task-analysis` | Start of every task | plan before code |
| `codebase-exploration` | Before any edit | read-only exploration |
| `internal-knowledge` | When domain/arch context may exist in Dify | Dify MCP |
| `implementation` | Making the change | smallest reasonable diff |
| `testing-debugging` | After every change | test loop until green |
| `code-review` | Before marking done | read-only review |

Load via the native `skill` tool: `skill({ name: "task-analysis" })`. Permissions are `allow` by default (`permission.skill.*`).

## Anti-patterns

- Starting to code before `task-analysis` + `codebase-exploration`.
- Fabricating requirements or Dify results.
- Assuming an API exists without checking source/types/tests.
- “While I’m here…” refactors unrelated to the task.
- Claiming success without running tests.
