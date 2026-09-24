---
name: task-analysis
description: Analyze task requirements, acceptance criteria, affected components, unknowns, and create an implementation plan.
---

# Task Analysis

Use this skill whenever you receive a task/ticket or user request that requires code changes.

## Workflow

```
Task
 ↓
Understand requirements
 ↓
Identify acceptance criteria
 ↓
Identify affected components
 ↓
Identify unknowns
 ↓
Research if necessary
 ↓
Create implementation plan
```

## Steps

### 1. Understand requirements

- If a Redmine issue ID is given, fetch it via Redmine MCP (`get_issue` / `getIssue` depending on server).
  Read description + comments/history — do not rely on title alone.
- If a plain user prompt is given, restate the request in your own words and confirm understanding.
- Extract: goal, scope, out-of-scope, constraints.

### 2. Identify acceptance criteria

- List verifiable criteria (behavior, API, UI, performance, security).
- If criteria are missing or vague, explicitly call that out and propose concrete criteria to confirm with the requester.
- Do not invent criteria silently — mark proposals as `PROPOSED`.

### 3. Identify affected components

- Call `codebase-exploration` skill or delegate to `@researcher` to map affected modules.
- List files, services, and tests likely to change.
- Note dependencies and integration points.

### 4. Identify unknowns & risks

- Missing specs, ambiguous edge cases, undocumented business rules.
- Technical risks: migrations, breaking changes, concurrency, performance.

### 5. Research if necessary

- If business/architecture context is needed, use Dify MCP `search_knowledge`.
- If you find no relevant chunk, state "No relevant internal knowledge found for <query>" — do not hallucinate.

### 6. Create implementation plan

Produce a concise plan with:

- **Summary** (2-3 sentences)
- **Acceptance criteria** (checklist)
- **Affected components** (`path:line` where possible)
- **Unknowns / questions** (with proposed answers if applicable)
- **Steps** (ordered, smallest reasonable increments)
- **Verification** (how to know it is done: tests, manual checks)
- **Risks & mitigations**

Do NOT start coding in this skill. Output the plan and wait for confirmation if the task is ambiguous or high-risk.

## Anti-patterns

- Starting implementation before analysis is complete.
- Fabricating requirements or internal doc results.
- Assuming an API exists without checking source/types/tests.
