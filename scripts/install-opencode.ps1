# Install OpenCode (Windows PowerShell)
# Verified 2026-09: npm install -g opencode-ai is the reliable native Windows path.
# Also supports WSL/Git Bash curl install if present.
$ErrorActionPreference = "Stop"
function NeedCmd($n) { $null -ne (Get-Command $n -ErrorAction SilentlyContinue) }
if (NeedCmd "opencode") { Write-Host "[ok] opencode already installed: $(& opencode --version 2>&1 | Select-Object -First 1)" -ForegroundColor Green; exit 0 }

# Prefer npm on native Windows
if (NeedCmd "npm") {
  Write-Host "[info] Installing via npm: npm install -g opencode-ai"
  & npm install -g opencode-ai
  if (NeedCmd "opencode") { Write-Host "[ok] opencode installed via npm: $(& opencode --version 2>&1 | Select-Object -First 1)" -ForegroundColor Green; exit 0 }
  else { Write-Host "[fail] npm install succeeded but opencode not on PATH" -ForegroundColor Red; exit 1 }
}

# Try curl install if curl + bash available (e.g., Git Bash)
if (NeedCmd "curl" -and NeedCmd "bash") {
  Write-Host "[info] Trying curl | bash install (requires bash)…"
  & bash -c "curl -fsSL https://opencode.ai/install | bash"
  if (NeedCmd "opencode") { Write-Host "[ok] opencode installed via curl script" -ForegroundColor Green; exit 0 }
}

Write-Host "[fail] No install method succeeded." -ForegroundColor Red
Write-Host "Manual: npm install -g opencode-ai  OR  in WSL: curl -fsSL https://opencode.ai/install | bash"
exit 1
