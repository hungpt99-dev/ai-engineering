# Install / build MCP adapters (Windows)
$ErrorActionPreference = "Stop"
$Root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path

Write-Host "[info] Building Dify Knowledge MCP…" -ForegroundColor Cyan
if (-not (Test-Path (Join-Path $Root "mcp\dify-knowledge\package.json"))) { Write-Host "[fail] mcp\dify-knowledge\package.json missing" -ForegroundColor Red; exit 1 }
$major = (& node -p "process.versions.node.split('.')[0]" 2>$null)
if ([int]$major -lt 18) { Write-Host "[fail] Node >=18 required (found $major)" -ForegroundColor Red; exit 1 }
$nm = Join-Path $Root "mcp\dify-knowledge\node_modules"
if (-not (Test-Path $nm)) { Push-Location (Join-Path $Root "mcp\dify-knowledge"); & npm install; Pop-Location } else { Write-Host "[info] mcp\dify-knowledge deps already installed" }
Push-Location (Join-Path $Root "mcp\dify-knowledge"); & npm run build; Pop-Location
Write-Host "[ok] Dify MCP built: mcp\dify-knowledge\dist\index.js" -ForegroundColor Green

Write-Host "[info] Verifying tracker MCP packages (npx cache)…" -ForegroundColor Cyan
foreach ($pkg in @("@onozaty/redmine-mcp-server","@ahmetbarut/jira-mcp-server")) {
  try { & npx --yes $pkg --help 2>&1 | Out-Null; Write-Host "[ok] $pkg resolvable" -ForegroundColor Green } catch { Write-Host "[warn] $pkg not yet cached -- will be fetched on first run via npx" -ForegroundColor Yellow }
}

try { $j = Get-Content (Join-Path $Root "opencode.json") -Raw | ConvertFrom-Json; if ($j.mcp.'dify-knowledge' -and ($j.mcp.redmine -or $j.mcp.jira)) { Write-Host "[ok] opencode.json mcp entries present" -ForegroundColor Green } else { Write-Host "[warn] opencode.json missing mcp entries" -ForegroundColor Yellow } } catch { Write-Host "[warn] opencode.json check failed: $_" -ForegroundColor Yellow }
