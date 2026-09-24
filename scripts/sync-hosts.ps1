# Sync skills/agents to host-specific locations (Claude Code, Codex, OpenCode) - Windows
param(
  [string]$HostName = "all",
  [switch]$Force
)
$ErrorActionPreference = "Stop"
$Root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
if ($HostName -eq "") { $HostName = "all" }
Write-Host "[info] sync-hosts --host=$HostName (root: $Root)" -ForegroundColor Cyan

function Sync-Skills($src, $dst) {
  New-Item -ItemType Directory -Path $dst -Force | Out-Null
  Get-ChildItem $src -Directory | ForEach-Object {
    $bn = $_.Name
    $dstDir = Join-Path $dst $bn
    New-Item -ItemType Directory -Path $dstDir -Force | Out-Null
    $srcFile = Join-Path $_.FullName "SKILL.md"
    $dstFile = Join-Path $dstDir "SKILL.md"
    if ((Test-Path $dstFile) -and (-not $Force)) {
      Write-Host "[info] skip $dstFile (exists, use -Force)" -ForegroundColor Yellow
    } else {
      Copy-Item $srcFile $dstFile -Force
      Write-Host "[ok] synced skill $bn -> $dstFile" -ForegroundColor Green
    }
  }
}
function Sync-Agents($src, $dst) {
  New-Item -ItemType Directory -Path $dst -Force | Out-Null
  Get-ChildItem "$src\*.md" | ForEach-Object {
    $dstFile = Join-Path $dst $_.Name
    if ((Test-Path $dstFile) -and (-not $Force)) {
      Write-Host "[info] skip $dstFile (exists, use -Force)" -ForegroundColor Yellow
    } else {
      Copy-Item $_.FullName $dstFile -Force
      Write-Host "[ok] synced agent $($_.Name) -> $dstFile" -ForegroundColor Green
    }
  }
}

if ($HostName -eq "opencode" -or $HostName -eq "all") {
  Write-Host "[info] Host opencode: source of truth at .opencode/ (no sync needed)" -ForegroundColor Cyan
}
if ($HostName -eq "claude" -or $HostName -eq "all") {
  Write-Host "[info] Syncing to Claude Code (.claude/skills, .claude/agents, .mcp.json)" -ForegroundColor Cyan
  Sync-Skills (Join-Path $Root ".opencode\skills") (Join-Path $Root ".claude\skills")
  Sync-Agents (Join-Path $Root ".opencode\agents") (Join-Path $Root ".claude\agents")
  $mcpSrc = Join-Path $Root "config\hosts\claude-code\mcp.json.example"
  $mcpDst = Join-Path $Root ".mcp.json"
  if (-not (Test-Path $mcpDst)) {
    Copy-Item $mcpSrc $mcpDst -Force
    Write-Host "[ok] created .mcp.json from template" -ForegroundColor Green
  } else {
    Write-Host "[info] .mcp.json already exists -- skip (use -Force)" -ForegroundColor Yellow
    if ($Force) { Copy-Item $mcpSrc $mcpDst -Force; Write-Host "[ok] overwrote .mcp.json" -ForegroundColor Green }
  }
}
if ($HostName -eq "codex" -or $HostName -eq "all") {
  Write-Host "[info] Syncing to Codex (.agents/skills, .codex/config.toml)" -ForegroundColor Cyan
  Sync-Skills (Join-Path $Root ".opencode\skills") (Join-Path $Root ".agents\skills")
  New-Item -ItemType Directory -Path (Join-Path $Root ".codex") -Force | Out-Null
  $srcToml = Join-Path $Root "config\hosts\codex\config.toml.example"
  $dstToml = Join-Path $Root ".codex\config.toml"
  if (-not (Test-Path $dstToml)) {
    Copy-Item $srcToml $dstToml -Force
    Write-Host "[ok] created .codex/config.toml from template" -ForegroundColor Green
  } else {
    Write-Host "[info] .codex/config.toml already exists -- skip" -ForegroundColor Yellow
    if ($Force) { Copy-Item $srcToml $dstToml -Force; Write-Host "[ok] overwrote .codex/config.toml" -ForegroundColor Green }
  }
}
Write-Host "[info] sync-hosts done. Verify: dir .claude\skills .agents\skills .codex\.mcp.json" -ForegroundColor Cyan
