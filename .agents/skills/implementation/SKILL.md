---
name: implementation
description: Implement the smallest reasonable change following KISS/YAGNI/DRY/SOLID and existing project patterns.
---

# Implementation

Implement the smallest reasonable change that satisfies the task and acceptance criteria.

## Principles

Follow pragmatically (do not apply mechanically):

- **KISS** — keep it simple; prefer straightforward code over clever abstractions.
- **YAGNI** — do not add what is not required today.
- **DRY** — reuse existing helpers/patterns; do not duplicate.
- **SOLID** — keep functions focused, dependencies explicit, interfaces narrow.

Prefer **consistency with the existing project architecture** over ideal textbook design.

## Preconditions

- `task-analysis` is done (requirements + acceptance criteria clear).
- `codebase-exploration` is done (you know what to touch and what to reuse).
- `internal-knowledge` has been consulted if domain context was needed.

## Steps

1. **Plan the edit** — identify the minimal set of files and the order to change them.
2. **Inspect before modifying** — `read` the target file and surrounding context.
3. **Make the change** — use `edit` with the smallest boundary that satisfies the requirement.
   - Match naming, formatting, and error handling already in the file.
   - Do not rewrite unrelated code or reformat the whole file.
4. **Preserve behavior** — check callers, tests, and downstream consumers.
5. **Handle errors explicitly** — no swallowed exceptions; log at the right level; no secrets/PII.
6. **Consider** concurrency, performance, and backward compatibility where applicable.

## Type safety

- Write type-safe code; avoid `any` / unchecked casts.
- Add/adjust types alongside logic changes.

## After the change

- Run the smallest relevant test slice (see `testing-debugging` skill).
- If tests fail, fix the root cause — do not suppress.

## Anti-patterns

- Doing more than the task asks ("while I'm here…" refactors).
- Adding premature abstractions or config.
- Assuming an API exists without checking source/types/tests.
- Broad `catch` that hides errors or increasing timeouts to mask flakiness.
