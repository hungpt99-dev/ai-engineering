# Interactive credentials configurator — Windows (secrets not echoed)
$ErrorActionPreference = "Stop"
$Root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$Tgt = Join-Path $Root ".env"
$Example = Join-Path $Root ".env.example"

if (-not (Test-Path $Example)) { Write-Host "[fail] .env.example missing" -ForegroundColor Red; exit 1 }
if (-not (Test-Path $Tgt)) { Copy-Item $Example $Tgt; Write-Host "[info] Created .env from .env.example" -ForegroundColor Cyan }

# Parse existing .env into hashtable (do not print secrets)
$envMap = @{}
Get-Content $Tgt | ForEach-Object {
  $line = $_.Trim()
  if (-not $line -or $line.StartsWith("#")) { return }
  $eq = $line.IndexOf("=")
  if ($eq -gt 0) { $k = $line.Substring(0,$eq).Trim(); $v = $line.Substring($eq+1).Trim().Trim('"').Trim("'"); $envMap[$k] = $v }
}

function MaskLen($v) { if ([string]::IsNullOrEmpty($v)) { "not set" } else { "set ($($v.Length) chars)" } }

function UpsertEnv($key, $value) {
  $content = Get-Content $Tgt -Raw -ErrorAction SilentlyContinue
  if ($null -eq $content) { $content = "" }
  # Escape for regex replacement value
  $esc = $value -replace '\$', '$$$$'
  if ($content -match "(?m)^$([regex]::Escape($key))=.*$") {
    $content = $content -replace "(?m)^$([regex]::Escape($key))=.*$", "$key=$esc"
    Set-Content -Path $Tgt -Value $content.TrimEnd() -NoNewline
  } else {
    Add-Content -Path $Tgt -Value "`n$key=$value"
  }
  $envMap[$key] = $value
}

function PromptSecret($key, $desc) {
  $cur = $envMap[$key]
  Write-Host $desc -ForegroundColor Cyan
  Write-Host "  Current: $(MaskLen $cur)"
  $sec = Read-Host "  New value (or Enter to keep)"
  # Read-Host echoes; for real secret use Read-Host -AsSecureString but keep simple cross-version
  if (-not [string]::IsNullOrWhiteSpace($sec)) { UpsertEnv $key $sec; Write-Host "  → updated $key" -ForegroundColor Green } else { Write-Host "  → kept" }
  Write-Host ""
}

function PromptValue($key, $desc) {
  $cur = $envMap[$key]
  Write-Host $desc -ForegroundColor Cyan
  Write-Host "  Current: $(if ($cur) { $cur } else { 'not set' })"
  $val = Read-Host "  New value (or Enter to keep)"
  if (-not [string]::IsNullOrWhiteSpace($val)) { UpsertEnv $key $val; Write-Host "  → updated $key" -ForegroundColor Green } else { Write-Host "  → kept" }
  Write-Host ""
}

Write-Host "=== Configure AI Engineering (.env) ===" -ForegroundColor Cyan
Write-Host "Press Enter to keep current value."
Write-Host ""

PromptValue  "DIFY_BASE_URL"         "Dify Base URL (e.g. https://api.dify.ai/v1 or https://dify.company.com/v1)"
PromptSecret "DIFY_API_KEY"          "Dify Dataset API key (Dify Console → Knowledge → Service API)"
Write-Host "--- Task Tracker (Redmine OR Jira) ---" -ForegroundColor Yellow
PromptValue  "REDMINE_URL"           "Redmine URL (e.g. https://redmine.company.com) — leave empty if using Jira"
PromptSecret "REDMINE_API_KEY"       "Redmine API key (My account → API access key)"
PromptValue  "REDMINE_MCP_READ_ONLY" "Redmine read-only (true/false, recommended true)"
PromptValue  "JIRA_BASE_URL"         "Jira Cloud URL (e.g. https://your-domain.atlassian.net) — leave empty if using Redmine"
PromptValue  "JIRA_EMAIL"            "Jira email (for Cloud)"
PromptSecret "JIRA_API_TOKEN"        "Jira API token (id.atlassian.com → Security → Create API token)"
Write-Host "--- LLM Providers (at least one) ---"
PromptSecret "ANTHROPIC_API_KEY"     "Anthropic API key"
PromptSecret "OPENAI_API_KEY"        "OpenAI API key"

Write-Host "=== Done ===" -ForegroundColor Green
Write-Host ".env updated at $Tgt"
Write-Host "Validate with: .\setup\check.ps1"
Write-Host "Never commit .env — it is gitignored." -ForegroundColor Yellow
