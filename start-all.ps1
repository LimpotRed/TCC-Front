param(
    [string]$ApiBaseUrl = 'http://localhost:8081'
)

$ErrorActionPreference = 'Stop'
$frontendPath = $PSScriptRoot
$backendPath = Join-Path (Split-Path $frontendPath -Parent) 'TCC-BACKAND'

if (-not (Test-Path -LiteralPath $backendPath)) {
    throw "Backend não encontrado em: $backendPath"
}

$backendScript = Join-Path $backendPath 'start-backend.cmd'
if (-not (Test-Path -LiteralPath $backendScript)) {
    throw "Script do backend não encontrado em: $backendScript"
}

$frontendScript = Join-Path $frontendPath 'start-front.ps1'

Write-Host "Iniciando backend em $backendPath ..." -ForegroundColor Cyan
Start-Process -FilePath 'cmd.exe' `
    -ArgumentList '/c', $backendScript `
    -WorkingDirectory $backendPath `
    -WindowStyle Hidden

Write-Host "Backend iniciado. Iniciando frontend em $frontendPath ..." -ForegroundColor Green
& $frontendScript -ApiBaseUrl $ApiBaseUrl
exit $LASTEXITCODE
