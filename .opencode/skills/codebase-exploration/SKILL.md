---
name: codebase-exploration
description: Systematically explore project structure, tech stack, patterns, tests, dependencies, and side effects before modifying code.
---

# Codebase Exploration

Use this skill before any code change. Never start modifying code without understanding the existing implementation.

## Checklist

1. **Project structure**
   - List top-level dirs, workspaces, monorepo layout.
   - Identify package managers (`package.json`, `pyproject.toml`, `go.mod`, etc.).

2. **Technology stack**
   - Languages, frameworks, runtimes, build tools.
   - Confirm versions via lockfiles / config.

3. **Entry points**
   - Main executables, servers, CLIs, app bootstraps.
   - Route / handler registration.

4. **Affected modules**
   - Grep for keywords, symbols, and related tests.
   - Map call graph: who calls what, what depends on what.

5. **Existing patterns**
   - Naming, folder structure, error handling, logging, validation.
   - State management, data access, API conventions.

6. **Tests**
   - Where tests live, how to run them, coverage expectations.
   - Existing fixtures / factories / helpers to reuse.

7. **Dependencies**
   - Internal packages, external services, shared libraries.
   - Version constraints and peer dependencies.

8. **Potential side effects**
   - Migrations, config changes, env vars, feature flags.
   - Backward compatibility, concurrent access, performance hot paths.

## Method

Prefer this order:

```
read  → grep → glob → read (deeper) → bash (git log/diff for history)
```

- Use `glob` for file discovery, `grep` for symbol search, `read` for deep inspection.
- For external dependency code, use the built-in `scout` subagent if needed (clones into cache, not workspace).
- Cite findings as `path:line`.

## Output

Return a structured report:

- Structure & stack
- Entry points
- Affected modules (`path:line`)
- Patterns to follow
- Test locations & run commands
- Dependencies
- Risks / side effects
- Recommended next step (e.g., which file to edit first)

## Anti-patterns

- Editing without reading.
- Assuming a library or API exists without checking.
- Adding a new pattern when the repo already has one.
