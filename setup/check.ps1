# AI Engineering -- Health Check (Windows PowerShell)
param()
$ErrorActionPreference = "Continue"
$Root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$Pass = 0; $Fail = 0; $Warn = 0

function Pass($m) { Write-Host "[PASS] $m" -ForegroundColor Green; $script:Pass++ }
function Fail($m) { Write-Host "[FAIL] $m" -ForegroundColor Red;   $script:Fail++ }
function Warn($m) { Write-Host "[WARN] $m" -ForegroundColor Yellow; $script:Warn++ }
function Info($m) { Write-Host "[INFO] $m" -ForegroundColor Cyan }

function NeedCmd($n) { $null -ne (Get-Command $n -ErrorAction SilentlyContinue) }

# Load .env if present (simple KEY=VALUE, ignore # comments)
$envPath = Join-Path $Root ".env"
if (Test-Path $envPath) {
  Get-Content $envPath | ForEach-Object {
    $line = $_.Trim()
    if (-not $line -or $line.StartsWith("#")) { return }
    $eq = $line.IndexOf("=")
    if ($eq -gt 0) {
      $k = $line.Substring(0,$eq).Trim()
      $v = $line.Substring($eq+1).Trim().Trim('"').Trim("'")
      Set-Item -Path "env:$k" -Value $v
    }
  }
  Pass ".env found"
} else { Warn ".env not found -- copy .env.example to .env and configure" }

Write-Host "=== AI Engineering -- Health Check (Windows) ==="
Write-Host "Root: $Root"
Write-Host ""

Write-Host "-- System --"
foreach ($cmd in @("git","node","npm")) {
  if (NeedCmd $cmd) {
    $ver = & $cmd --version 2>&1 | Select-Object -First 1
    Pass "$cmd : $ver"
  } else { Fail "$cmd not found" }
}
if (NeedCmd "node") {
  try { $maj = & node -p "process.versions.node.split('.')[0]" } catch { $maj = 0 }
  if ([int]$maj -ge 18) { Pass "node >=18 ($maj)" } else { Fail "node >=18 required (found $maj)" }
}
if (NeedCmd "bun") {
  $bver = & bun --version 2>&1 | Select-Object -First 1
  Pass "bun : $bver"
} else { Warn "bun not found (fallback to npx works)" }
if (NeedCmd "curl") { Pass "curl : found" } else { Warn "curl not found (curl.exe available on Win10+)" }

Write-Host ""
Write-Host "-- OpenCode --"
if (NeedCmd "opencode") {
  $ocVer = & opencode --version 2>&1 | Select-Object -First 1
  Pass "opencode : $ocVer"
  $ocJson = Join-Path $Root "opencode.json"
  if (Test-Path $ocJson) {
    try { $null = Get-Content $ocJson -Raw | ConvertFrom-Json; Pass "opencode.json: valid JSON" } catch { Fail "opencode.json: invalid JSON - $_" }
    try {
      $j = Get-Content $ocJson -Raw | ConvertFrom-Json
      $errs = @()
      if (-not $j.'$schema') { $errs += "missing schema" }
      if (-not $j.mcp) { $errs += "missing mcp" } else { if (-not $j.mcp.'dify-knowledge') { $errs += "missing mcp.dify-knowledge" }; if (-not $j.mcp.redmine -and -not $j.mcp.jira) { $errs += "missing mcp tracker (redmine or jira)" } }
      if (-not $j.agent -or -not $j.agent.developer) { $errs += "missing agent.developer" }
      if ($errs.Count -eq 0) { Pass "opencode.json: required keys present" } else { Fail "opencode.json: $($errs -join '; ')" }
    } catch { Fail "opencode.json key check failed: $_" }
    $raw = Get-Content $ocJson -Raw
    if ($raw -match "oh-my-openagent") { Pass "opencode.json: oh-my-openagent plugin registered" } else { Warn "opencode.json: oh-my-openagent plugin not found" }
  } else { Fail "opencode.json not found at repo root" }
  foreach ($f in @(".opencode\agents\developer.md",".opencode\agents\researcher.md",".opencode\agents\reviewer.md")) { if (Test-Path (Join-Path $Root $f)) { Pass "$f present" } else { Fail "$f missing" } }
  foreach ($s in @("task-analysis","codebase-exploration","internal-knowledge","implementation","testing-debugging","code-review")) { if (Test-Path (Join-Path $Root ".opencode\skills\$s\SKILL.md")) { Pass "skill $s present" } else { Fail "skill $s missing" } }
  if (Test-Path (Join-Path $Root "AGENTS.md")) { Pass "AGENTS.md present" } else { Fail "AGENTS.md missing" }
} else { Fail "opencode not found on PATH -- run .\setup\install.ps1" }

Write-Host ""
Write-Host "-- Oh My OpenAgent --"
if (NeedCmd "bun") {
  try { & bunx oh-my-openagent --help 2>&1 | Out-Null; Pass "oh-my-openagent CLI resolvable (bunx)" } catch { Warn "oh-my-openagent CLI not resolvable -- run: bunx oh-my-openagent install" }
} else { Warn "bun missing -- cannot verify oh-my-openagent" }

Write-Host ""
Write-Host "-- Dify Knowledge MCP --"
if (Test-Path (Join-Path $Root "mcp\dify-knowledge\package.json")) { Pass "mcp\dify-knowledge\package.json present" } else { Fail "mcp\dify-knowledge\package.json missing" }
if (Test-Path (Join-Path $Root "mcp\dify-knowledge\dist\index.js")) { Pass "mcp\dify-knowledge built (dist\index.js)" } else { Warn "mcp\dify-knowledge not built -- run: npm --prefix mcp\dify-knowledge install; npm --prefix mcp\dify-knowledge run build" }
if ($env:DIFY_BASE_URL) { Pass "DIFY_BASE_URL set" } else { Warn "DIFY_BASE_URL not set (in .env)" }
if ($env:DIFY_API_KEY) { Pass "DIFY_API_KEY set (length $($env:DIFY_API_KEY.Length))" } else { Warn "DIFY_API_KEY not set" }
if ($env:DIFY_BASE_URL -and $env:DIFY_API_KEY) {
  try {
    $headers = @{ Authorization = "Bearer $env:DIFY_API_KEY" }
    $resp = Invoke-WebRequest -Uri "$env:DIFY_BASE_URL/datasets?limit=1&page=1" -Headers $headers -Method Get -TimeoutSec 8 -UseBasicParsing -ErrorAction Stop
    if ($resp.StatusCode -eq 200) { Pass "Dify connectivity: 200 OK ($env:DIFY_BASE_URL)" } else { Warn "Dify connectivity: HTTP $($resp.StatusCode)" }
  } catch {
    $exc = $_.Exception
    $code = $null
    try { $code = $exc.Response.StatusCode.Value__ } catch {}
    if ($code -eq 401) { Fail "Dify connectivity: 401 Unauthorized -- check DIFY_API_KEY" }
    elseif ($code -eq 403) { Fail "Dify connectivity: 403 Forbidden -- check API access / key scope" }
    else { Warn "Dify connectivity: failed - $($exc.Message)" }
  }
}

Write-Host ""
Write-Host "-- Task Tracker MCP (Redmine / Jira) --"
Write-Host "[tracker] Redmine"
try { & npx --yes @onozaty/redmine-mcp-server --help 2>&1 | Out-Null; Pass "Redmine MCP package resolvable (npx)" } catch { Info "Redmine MCP not yet cached -- will be fetched on first run via npx" }
if ($env:REDMINE_URL) { Pass "REDMINE_URL set" } else { Warn "REDMINE_URL not set (set if using Redmine)" }
if ($env:REDMINE_API_KEY) { Pass "REDMINE_API_KEY set (length $($env:REDMINE_API_KEY.Length))" } else { Warn "REDMINE_API_KEY not set" }
if ($env:REDMINE_URL -and $env:REDMINE_API_KEY) {
  try {
    $headers = @{ "X-Redmine-API-Key" = $env:REDMINE_API_KEY }
    $resp = Invoke-WebRequest -Uri "$env:REDMINE_URL/users/current.json" -Headers $headers -Method Get -TimeoutSec 8 -UseBasicParsing -ErrorAction Stop
    if ($resp.StatusCode -eq 200) { Pass "Redmine connectivity: 200 OK ($env:REDMINE_URL)" } else { Warn "Redmine connectivity: HTTP $($resp.StatusCode)" }
  } catch {
    $exc = $_.Exception
    $code = $null
    try { $code = $exc.Response.StatusCode.Value__ } catch {}
    if ($code -eq 401) { Fail "Redmine connectivity: 401 Unauthorized -- check REDMINE_API_KEY" }
    elseif ($code -eq 403) { Fail "Redmine connectivity: 403 Forbidden" }
    else { Warn "Redmine connectivity: failed - $($exc.Message)" }
  }
}
Write-Host "[tracker] Jira"
try { & npx --yes @ahmetbarut/jira-mcp-server --help 2>&1 | Out-Null; Pass "Jira MCP package resolvable (npx)" } catch { Info "Jira MCP not yet cached -- will be fetched on first run via npx" }
if ($env:JIRA_BASE_URL) { Pass "JIRA_BASE_URL set" } else { Warn "JIRA_BASE_URL not set (set if using Jira Cloud)" }
if ($env:JIRA_API_TOKEN) { Pass "JIRA_API_TOKEN set (length $($env:JIRA_API_TOKEN.Length))" } else { Warn "JIRA_API_TOKEN not set" }
if ($env:JIRA_BASE_URL -and $env:JIRA_API_TOKEN) {
  try {
    $pair = "${env:JIRA_EMAIL}:$env:JIRA_API_TOKEN"
    $bytes = [System.Text.Encoding]::ASCII.GetBytes($pair)
    $b64 = [Convert]::ToBase64String($bytes)
    $headers = @{ Authorization = "Basic $b64" }
    $resp = Invoke-WebRequest -Uri "$env:JIRA_BASE_URL/rest/api/3/myself" -Headers $headers -Method Get -TimeoutSec 8 -UseBasicParsing -ErrorAction Stop
    if ($resp.StatusCode -eq 200) { Pass "Jira connectivity: 200 OK ($env:JIRA_BASE_URL)" } else { Warn "Jira connectivity: HTTP $($resp.StatusCode)" }
  } catch {
    $exc = $_.Exception
    $code = $null
    try { $code = $exc.Response.StatusCode.Value__ } catch {}
    if ($code -eq 401) { Fail "Jira connectivity: 401 Unauthorized -- check JIRA_EMAIL/JIRA_API_TOKEN" }
    elseif ($code -eq 403) { Fail "Jira connectivity: 403 Forbidden" }
    else { Warn "Jira connectivity: failed - $($exc.Message)" }
  }
}
if (-not $env:REDMINE_URL -and -not $env:JIRA_BASE_URL) { Warn "No tracker configured -- set REDMINE_URL or JIRA_BASE_URL in .env" }
Write-Host ""
Write-Host "-- Host sync --"
if (Test-Path (Join-Path $Root ".claude\skills")) { Pass "Claude Code skills synced (.claude/skills)" } else { Warn "Claude skills not synced -- run scripts/sync-hosts.ps1 -HostName claude" }
if (Test-Path (Join-Path $Root ".agents\skills")) { Pass "Codex/Agents skills synced (.agents/skills)" } else { Warn "Codex skills not synced -- run scripts/sync-hosts.ps1 -HostName codex" }
if (Test-Path (Join-Path $Root ".mcp.json")) { Pass "Claude .mcp.json present" } else { Info ".mcp.json not present (only needed for Claude host)" }
if (Test-Path (Join-Path $Root ".codex\config.toml")) { Pass "Codex .codex/config.toml present" } else { Info ".codex/config.toml not present (only needed for Codex host)" }

Write-Host ""
Write-Host "================ Summary ================"
Write-Host "PASS: $Pass  WARN: $Warn  FAIL: $Fail"
if ($Fail -gt 0) { Write-Host "Health check FAILED -- fix FAIL items above." -ForegroundColor Red; exit 1 }
elseif ($Warn -gt 0) { Write-Host "Health check passed with warnings." -ForegroundColor Yellow; exit 0 }
else { Write-Host "All checks passed." -ForegroundColor Green; exit 0 }
