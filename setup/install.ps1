# AI Engineering — Unified Setup (Windows PowerShell 5.1+ / pwsh)
# Usage:
#   .\setup\install.ps1
#   .\setup\install.ps1 -CheckOnly
#   .\setup\install.ps1 -Yes   # non-interactive
#   .\setup\install.ps1 -Host opencode -Tracker redmine   # hosts: opencode|claude|codex|all, trackers: redmine|jira|both|none
param(
  [switch]$CheckOnly,
  [switch]$Yes,
  [string]$HostName = "opencode",
  [string]$Tracker = "redmine"
)

$ErrorActionPreference = "Stop"
$Root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path

function Info($m) { Write-Host "[info] $m" -ForegroundColor Cyan }
function Ok($m)   { Write-Host "[ok] $m" -ForegroundColor Green }
function Warn($m) { Write-Host "[warn] $m" -ForegroundColor Yellow }
function Fail($m) { Write-Host "[fail] $m" -ForegroundColor Red }

function NeedCmd($name) { $null -ne (Get-Command $name -ErrorAction SilentlyContinue) }

Write-Host ""
Write-Host "=== AI Engineering Setup (Windows) ==="
Write-Host "Root: $Root"
Write-Host "Host: $HostName  Tracker: $Tracker  (hosts: opencode|claude|codex|all, trackers: redmine|jira|both|none)"
Write-Host ""

if ($CheckOnly) { & (Join-Path $Root "setup\check.ps1"); exit $LASTEXITCODE }

# 1. Prereqs
Info "Checking prerequisites…"
$missingNode = $false
foreach ($cmd in @("git","node","npm")) {
  if (NeedCmd $cmd) { Ok "$cmd : $((& $cmd --version 2>&1 | Select-Object -First 1))" } else { Warn "$cmd not found"; if ($cmd -eq "node") { $missingNode = $true } }
}
if (-not (NeedCmd "node")) { Fail "Node.js >=18 is required. Install from https://nodejs.org then re-run."; exit 1 }
$nodeMajor = (& node -p "process.versions.node.split('.')[0]" 2>$null)
if ([int]$nodeMajor -lt 18) { Fail "Node >=18 required, found $nodeMajor"; exit 1 }
if (NeedCmd "bun") { Ok "bun : $(& bun --version)" } else { Warn "bun not found — will use npm/npx fallback for Oh My OpenAgent (recommended: https://bun.sh)" }
# Check for curl (Windows 10+ has curl.exe)
if (NeedCmd "curl") { Ok "curl : found" } else { Warn "curl not found — OpenCode install may need manual step" }
Write-Host ""

# 2. Host runtime
if ($HostName -eq "opencode" -or $HostName -eq "all") {
  Info "Step 1/5 — OpenCode"
  if (NeedCmd "opencode") {
    Ok "OpenCode already installed: $(& opencode --version 2>&1 | Select-Object -First 1)"
  } else {
    Info "Installing OpenCode via npm (Windows)…"
    try {
      & npm install -g opencode-ai
      if (NeedCmd "opencode") { Ok "OpenCode installed: $(& opencode --version 2>&1 | Select-Object -First 1)" } else { Fail "opencode not on PATH after npm install — check npm global bin is in PATH"; exit 1 }
    } catch {
      Fail "OpenCode install failed: $_"
      Write-Host "Try manually: npm install -g opencode-ai  OR  curl -fsSL https://opencode.ai/install | bash  (in WSL/Git Bash)"
      exit 1
    }
    Warn "For best Windows experience, OpenCode docs recommend WSL: https://opencode.ai/docs/windows-wsl"
  }
  Write-Host ""
  Info "Step 2/5 — Oh My OpenAgent (Ultimate for OpenCode)"
  if ($Yes) {
    Warn "-Yes: skipping interactive Oh My OpenAgent TUI. Run manually: bunx oh-my-openagent install"
  } else {
    if (NeedCmd "bun") {
      Info "Launching: bunx oh-my-openagent install (TUI will guide you)"
      try { & bunx oh-my-openagent install } catch { Warn "Oh My OpenAgent install exited with error — re-run: bunx oh-my-openagent install" }
      if (Test-Path (Join-Path $Root "opencode.json")) {
        $j = Get-Content (Join-Path $Root "opencode.json") -Raw
        if ($j -match "oh-my-openagent") { Ok "opencode.json registers oh-my-openagent plugin" } else { Info "Ensure opencode.json contains 'plugin': ['oh-my-openagent'] (this repo template does)" }
      }
      try { & bunx oh-my-openagent doctor --json 2>&1 | Select-Object -First 50 } catch {}
    } else {
      Warn "bun not found — install bun first, then run: bunx oh-my-openagent install"
      Warn "Docs: https://raw.githubusercontent.com/code-yeongyu/oh-my-openagent/refs/heads/dev/docs/guide/installation.md"
    }
  }
  Write-Host ""
} elseif ($HostName -eq "claude") {
  Info "Step 1-2/5 — Claude Code (host=claude)"
  if (NeedCmd "claude") { Ok "Claude Code already installed: $(& claude --version 2>&1 | Select-Object -First 1)" } else { Warn "Claude Code not found — install: npm install -g @anthropic-ai/claude-code (https://code.claude.com/docs)" }
  Write-Host ""
} elseif ($HostName -eq "codex") {
  Info "Step 1-2/5 — Codex CLI (host=codex)"
  if (NeedCmd "codex") { Ok "Codex already installed: $(& codex --version 2>&1 | Select-Object -First 1)" } else { Warn "Codex not found — install: npm install -g @openai/codex (https://developers.openai.com/codex)" }
  Write-Host ""
} else {
  Warn "Unknown host $HostName — skipping host install (valid: opencode|claude|codex|all)"
  Write-Host ""
}

# Host-agnostic skills/agents sync
if ($HostName -ne "opencode") {
  Info "Syncing skills/agents to host locations (host=$HostName)"
  & (Join-Path $Root "scripts\sync-hosts.ps1") -HostName $HostName
  Write-Host ""
}

# 4. MCP adapters (tracker=$Tracker)
Info "Step 3/5 — MCP adapters (tracker=$Tracker)"
& (Join-Path $Root "scripts\install-mcp.ps1")
Write-Host ""

# 5. Credentials (.env)
Info "Step 4/5 — Credentials"
$envPath = Join-Path $Root ".env"
$examplePath = Join-Path $Root ".env.example"
if (Test-Path $envPath) { Ok ".env already exists — leaving as is (edit manually or run scripts\configure.ps1)" }
elseif (Test-Path $examplePath) { Copy-Item $examplePath $envPath; Ok "Created .env from .env.example — EDIT IT with real credentials" }
else { Warn "No .env.example found" }
if (-not $Yes) { Info "Run scripts\configure.ps1 to set DIFY_* / REDMINE_* / provider keys." }
Write-Host ""

# 6. Validate
Info "Step 5/5 — Validation"
& (Join-Path $Root "setup\check.ps1")
Write-Host ""
if (-not $Yes) {
  Info "To make this harness available in ANY app repo (sibling clones), install globally: .\scripts\install-global.ps1"
  Info "  (copies opencode.json + .opencode/agents/skills/commands + AGENTS.md to %APPDATA%\opencode or ~/.config/opencode)"
  Info "  Skip if you keep app code inside this repo or prefer per-project copy."
}
Write-Host ""

Write-Host @"
Next steps (host=$HostName tracker=$Tracker):
  1. Edit .env               — fill DIFY_BASE_URL, DIFY_API_KEY, tracker creds (REDMINE_* or JIRA_*) and provider keys
  2. Validate                — .\setup\check.ps1 -Tracker $Tracker   (or ./setup/check.sh --tracker=$Tracker on WSL/macOS)
  3. Start $HostName          — $(if ($HostName -eq "opencode") { "opencode  (Tab switches agents)" } elseif ($HostName -eq "claude") { "claude" } elseif ($HostName -eq "codex") { "codex" } else { "opencode / claude / codex (all)" })
     - Try:  @researcher explore this repo
             search_knowledge query="architecture"  (via Dify MCP)
  4. Clone any app repo next to this one and start the host inside it:
       git clone <app-repo> ..\my-app ; cd ..\my-app ; $HostName

Docs: docs\setup.md  docs\architecture.md  docs\workflow.md  config/hosts/README.md
"@
