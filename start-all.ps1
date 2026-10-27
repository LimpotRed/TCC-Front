param(
    [string]$ApiBaseUrl = 'http://localhost:8081',
    [string]$BackendPath
)

$ErrorActionPreference = 'Stop'
$frontendPath = $PSScriptRoot

function Test-BackendPort {
    $connection = New-Object System.Net.Sockets.TcpClient
    try {
        $connection.Connect('localhost', 8081)
        return $connection.Connected
    } catch {
        return $false
    } finally {
        $connection.Dispose()
    }
}

if ([string]::IsNullOrWhiteSpace($BackendPath)) {
    $backendCandidates = @(
        (Join-Path ([Environment]::GetFolderPath('Desktop')) 'TCC BACK\GHydro-BackEnd'),
        (Join-Path (Split-Path $frontendPath -Parent) 'TCC-BACKAND'),
        (Join-Path ([Environment]::GetFolderPath('Desktop')) 'Tcc-Back\GHydro-BackEnd')
    )
    $BackendPath = $backendCandidates |
        Where-Object {
            (Test-Path -LiteralPath $_ -PathType Container) -and
            (Test-Path -LiteralPath (Join-Path $_ 'mvnw.cmd') -PathType Leaf)
        } |
        Select-Object -First 1
    if (-not $BackendPath) {
        throw 'Backend não encontrado. Informe a pasta do projeto com -BackendPath.'
    }
}
if (-not (Test-Path -LiteralPath $BackendPath -PathType Container)) {
    throw "Backend não encontrado em: $BackendPath"
}
$backendPath = (Resolve-Path -LiteralPath $BackendPath).Path

$mavenWrapper = Join-Path $backendPath 'mvnw.cmd'
$backendHelper = Join-Path $frontendPath 'start-backend.ps1'
$frontendScript = Join-Path $frontendPath 'start-front.ps1'

if (Test-BackendPort) {
    throw 'A porta 8081 já está em uso. Para usar a API em execução, inicie apenas .\start-front.cmd.'
}

if (-not (Test-Path -LiteralPath $mavenWrapper -PathType Leaf)) {
    throw "Maven wrapper não encontrado em: $backendPath"
}
# Start-Process une os argumentos; as aspas preservam os caminhos completos.
$backendArguments = '-NoProfile -ExecutionPolicy Bypass -File "{0}" -BackendPath "{1}"' -f $backendHelper, $backendPath
$logPrefix = Join-Path ([IO.Path]::GetTempPath()) ('ghydro-backend-' + [Guid]::NewGuid().ToString('N'))

Write-Host "Iniciando backend em $backendPath ..." -ForegroundColor Cyan
$backendProcess = Start-Process -FilePath (Join-Path $PSHOME 'powershell.exe') `
    -ArgumentList $backendArguments `
    -WorkingDirectory $backendPath `
    -WindowStyle Hidden `
    -RedirectStandardOutput "$logPrefix.stdout.log" `
    -RedirectStandardError "$logPrefix.stderr.log" `
    -PassThru

Write-Host "Aguardando a API em http://localhost:8081. Logs: $logPrefix.stdout.log e $logPrefix.stderr.log" -ForegroundColor Cyan
$startupDeadline = [DateTime]::UtcNow.AddMinutes(2)
while (-not (Test-BackendPort)) {
    $backendProcess.Refresh()
    if ($backendProcess.HasExited -and $backendProcess.ExitCode -ne 0) {
        throw "O backend encerrou durante a inicialização. Confira os logs em $logPrefix.*.log."
    }
    if ([DateTime]::UtcNow -ge $startupDeadline) {
        throw "A API não respondeu na porta 8081 em 2 minutos. Confira os logs em $logPrefix.*.log."
    }
    Start-Sleep -Milliseconds 500
}

Write-Host "Backend iniciado (PID $($backendProcess.Id)). Iniciando frontend em $frontendPath ..." -ForegroundColor Green
& $frontendScript -ApiBaseUrl $ApiBaseUrl
exit $LASTEXITCODE
