# Alias for setup/check.ps1
$Root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
& (Join-Path $Root "setup\check.ps1") @args
exit $LASTEXITCODE
