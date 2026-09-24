---
description: Run repository health checks and report
agent: build
---

Run health checks for this AI Engineering setup:

1. Validate `opencode.json` is valid JSON and required keys exist.
2. Check `mcp/dify-knowledge/dist/index.js` is built.
3. If `.env` exists, check Dify/Redmine connectivity (without leaking secrets).
4. Summarize `PASS/WARN/FAIL` and suggest fixes.

Use `bash ./setup/check.sh` (or `.\setup\check.ps1` on Windows) as the source of truth.
