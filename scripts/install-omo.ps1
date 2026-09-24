# Install Oh My OpenAgent (Ultimate for OpenCode) — Windows
# Requires bun (recommended). npm/npx Light edition is Codex-only; Ultimate expects bunx.
$ErrorActionPreference = "Stop"
function NeedCmd($n) { $null -ne (Get-Command $n -ErrorAction SilentlyContinue) }
if (NeedCmd "bun") {
  Write-Host "[info] Running: bunx oh-my-openagent install" -ForegroundColor Cyan
  Write-Host "[info] TUI will walk you through plugin + provider auth. See --help for CI flags." -ForegroundColor Cyan
  & bunx oh-my-openagent install
  Write-Host ""
  if (NeedCmd "opencode") {
    Write-Host "[info] Running doctor check…" -ForegroundColor Cyan
    try { & bunx oh-my-openagent doctor --json 2>&1 | Select-Object -First 80 } catch {}
  }
  Write-Host "[ok] Oh My OpenAgent install finished. Ensure opencode.json has 'plugin': ['oh-my-openagent']" -ForegroundColor Green
} elseif (NeedCmd "npx") {
  Write-Host "[warn] bun not found — trying npx fallback (not officially supported for Ultimate). Recommend installing bun from https://bun.sh" -ForegroundColor Yellow
  & npx --yes oh-my-openagent install
} else {
  Write-Host "[fail] Need bun or npx. Install bun: https://bun.sh" -ForegroundColor Red
  exit 1
}
