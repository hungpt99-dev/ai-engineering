# Install AI Engineering config globally (Windows)
# Copies opencode.json + .opencode/agents/skills/commands + AGENTS.md to $env:APPDATA\opencode or $env:XDG_CONFIG_HOME\opencode
$ErrorActionPreference = "Stop"
$Root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$globalBase = if ($env:XDG_CONFIG_HOME) { Join-Path $env:XDG_CONFIG_HOME "opencode" } elseif ($env:APPDATA) { Join-Path $env:APPDATA "opencode" } else { Join-Path $env:USERPROFILE ".config\opencode" }
Write-Host "[info] Installing global config to $globalBase" -ForegroundColor Cyan
New-Item -ItemType Directory -Path "$globalBase\agents" -Force | Out-Null
New-Item -ItemType Directory -Path "$globalBase\skills" -Force | Out-Null
New-Item -ItemType Directory -Path "$globalBase\commands" -Force | Out-Null

function BackupIfExists($path) {
  if (Test-Path $path) {
    $ts = Get-Date -Format "yyyyMMddHHmmss"
    Copy-Item $path "$path.bak.$ts" -Force
    Write-Host "[info] Backed up $path" -ForegroundColor Cyan
  }
}

# opencode.json merge or copy
$srcJson = Join-Path $Root "opencode.json"
$dstJson = Join-Path $globalBase "opencode.json"
if (Test-Path $dstJson) {
  Write-Host "[warn] $dstJson already exists -- merging plugin/mcp/agent keys" -ForegroundColor Yellow
  BackupIfExists $dstJson
  try {
    $src = Get-Content $srcJson -Raw | ConvertFrom-Json
    $dst = Get-Content $dstJson -Raw | ConvertFrom-Json
    # plugin
    $plugins = @()
    if ($dst.plugin) { $plugins += $dst.plugin }
    if ($src.plugin) { $plugins += $src.plugin }
    $dst | Add-Member -NotePropertyName plugin -NotePropertyValue @($plugins | Sort-Object -Unique) -Force
    # mcp
    if (-not $dst.mcp) { $dst | Add-Member -NotePropertyName mcp -NotePropertyValue @{} -Force }
    foreach ($k in $src.mcp.PSObject.Properties.Name) { $dst.mcp | Add-Member -NotePropertyName $k -NotePropertyValue $src.mcp.$k -Force }
    # agent
    if (-not $dst.agent) { $dst | Add-Member -NotePropertyName agent -NotePropertyValue @{} -Force }
    foreach ($k in $src.agent.PSObject.Properties.Name) { $dst.agent | Add-Member -NotePropertyName $k -NotePropertyValue $src.agent.$k -Force }
    # instructions
    $instr = @()
    if ($dst.instructions) { $instr += $dst.instructions }
    if ($src.instructions) { $instr += $src.instructions }
    $dst | Add-Member -NotePropertyName instructions -NotePropertyValue @($instr | Sort-Object -Unique) -Force
    if (-not $dst.'$schema' -and $src.'$schema') { $dst | Add-Member -NotePropertyName '$schema' -NotePropertyValue $src.'$schema' -Force }
    $dst | ConvertTo-Json -Depth 10 | Set-Content -Path $dstJson -Encoding UTF8
    Write-Host "[ok] Merged global opencode.json" -ForegroundColor Green
  } catch {
    Write-Host "[warn] Merge failed ($_), copying as opencode.json.ai-engineering" -ForegroundColor Yellow
    Copy-Item $srcJson "$dstJson.ai-engineering" -Force
  }
} else {
  Copy-Item $srcJson $dstJson -Force
  Write-Host "[ok] Copied opencode.json to $dstJson" -ForegroundColor Green
}

# Agents
Get-ChildItem (Join-Path $Root ".opencode\agents\*.md") | ForEach-Object {
  $dst = Join-Path "$globalBase\agents" $_.Name
  BackupIfExists $dst
  Copy-Item $_.FullName $dst -Force
  Write-Host "[ok] Installed agent $($_.Name)" -ForegroundColor Green
}
# Skills
Get-ChildItem (Join-Path $Root ".opencode\skills") -Directory | ForEach-Object {
  $bn = $_.Name
  $dstDir = Join-Path "$globalBase\skills" $bn
  New-Item -ItemType Directory -Path $dstDir -Force | Out-Null
  $srcSkill = Join-Path $_.FullName "SKILL.md"
  $dstSkill = Join-Path $dstDir "SKILL.md"
  BackupIfExists $dstSkill
  Copy-Item $srcSkill $dstSkill -Force
  Write-Host "[ok] Installed skill $bn" -ForegroundColor Green
}
# Commands
Get-ChildItem (Join-Path $Root ".opencode\commands\*.md") | ForEach-Object {
  $dst = Join-Path "$globalBase\commands" $_.Name
  BackupIfExists $dst
  Copy-Item $_.FullName $dst -Force
  Write-Host "[ok] Installed command $($_.Name)" -ForegroundColor Green
}
# AGENTS.md
$srcAgents = Join-Path $Root "AGENTS.md"
if (Test-Path $srcAgents) {
  $dstAgents = Join-Path $globalBase "AGENTS.md"
  BackupIfExists $dstAgents
  Copy-Item $srcAgents $dstAgents -Force
  Write-Host "[ok] Installed AGENTS.md to $dstAgents" -ForegroundColor Green
}

Write-Host ""
Write-Host "[ok] Global install complete. Verify: opencode debug config" -ForegroundColor Green
Write-Host "For sibling app repos, ensure env vars are in shell:  Get-Content $Root\.env | ForEach-Object { if(`$_ -match '^([^#=]+)=(.*)$'){ Set-Item -Path env:`$1 -Value `$2 } }" -ForegroundColor Cyan
