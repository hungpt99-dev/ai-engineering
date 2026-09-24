---
name: testing-debugging
description: Run tests, analyze failures, fix root causes, and repeat until stable. Never hide failures.
---

# Testing & Debugging

## Workflow

```
Implement
 ↓
Run relevant tests
 ↓
Analyze failure
 ↓
Fix root cause
 ↓
Run tests again
 ↓
Repeat until stable
```

## Steps

### 1. Run relevant tests

- Run the **smallest relevant slice** first (unit / file-level), then broaden.
- Detect the project's test command:
  - `package.json` scripts (`npm test`, `npm run test:unit`, etc.)
  - `Makefile`, `justfile`, `Taskfile`
  - Language-specific runners (`pytest`, `go test ./...`, `cargo test`, `mvn test`)
- Capture output; do not truncate failure details.

### 2. Analyze failure

- Read the failure message and stack trace fully.
- Locate the failing assertion / expectation.
- Trace back to the change: is it a logic error, missing edge case, contract mismatch, or environment issue?
- Check whether the failure is **pre-existing** (run tests on `main` / stash your change) — do not fix unrelated flakes silently.

### 3. Fix root cause

- Fix the **root cause**, not the symptom.
- Do NOT:
  - Increase timeouts to mask slowness.
  - Broaden `catch` to swallow errors.
  - Suppress or skip assertions.
  - Mark tests as `todo`/`skip` to make CI green.

### 4. Re-run

- Re-run the failing slice, then the broader suite.
- Loop until stable (no red tests, no lint failures).

## Verification

- After any edit, run the smallest relevant test slice first, then the broader suite.
- Do not mark a task complete while tests are red or lint is failing.
- If no automated tests exist, propose a manual verification checklist and/or a minimal regression test.

## Reporting

When done, report:

- Command(s) run
- Result (pass/fail, counts)
- Failures analyzed and fixes applied
- Remaining gaps (if any)

## Anti-patterns

- Claiming success without running tests.
- Hiding errors with broader catches or suppressed assertions.
