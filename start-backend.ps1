param(
    [Parameter(Mandatory = $true)]
    [string]$BackendPath
)

$ErrorActionPreference = 'Stop'

function Find-CompatibleJdk {
    $candidates = @()
    if ($env:JAVA_HOME) {
        $candidates += $env:JAVA_HOME
    }
    $javacCommand = Get-Command javac -ErrorAction SilentlyContinue
    if ($javacCommand) {
        $candidates += Split-Path (Split-Path $javacCommand.Source -Parent) -Parent
    }
    $extensionsPath = Join-Path ([Environment]::GetFolderPath('UserProfile')) '.vscode\extensions'
    if (Test-Path -LiteralPath $extensionsPath -PathType Container) {
        $candidates += Get-ChildItem -LiteralPath $extensionsPath -Directory -Filter 'redhat.java-*' |
            ForEach-Object {
                $jrePath = Join-Path $_.FullName 'jre'
                if (Test-Path -LiteralPath $jrePath -PathType Container) {
                    Get-ChildItem -LiteralPath $jrePath -Directory |
                        Select-Object -ExpandProperty FullName
                }
            }
    }
    foreach ($candidate in ($candidates | Select-Object -Unique)) {
        $javacPath = Join-Path $candidate 'bin\javac.exe'
        $javaPath = Join-Path $candidate 'bin\java.exe'
        if ((Test-Path -LiteralPath $javacPath -PathType Leaf) -and
            (Test-Path -LiteralPath $javaPath -PathType Leaf)) {
            $version = (& $javacPath -version 2>&1 | Out-String).Trim()
            if ($LASTEXITCODE -eq 0 -and
                $version -match '^javac\s+(\d+)(?:\.|$)' -and
                [int]$Matches[1] -ge 21) {
                return (Resolve-Path -LiteralPath $candidate).Path
            }
        }
    }
    throw 'JDK 21 ou mais recente não encontrado. Configure JAVA_HOME ou adicione javac ao PATH.'
}

function Protect-BackendOutput {
    param(
        [Parameter(ValueFromPipeline = $true)]
        [object]$InputObject,
        [string[]]$SensitiveValues
    )
    process {
        $outputLine = [string]$InputObject
        if ($outputLine -notmatch '(?i)jdbc\s*url|jdbc:|password|senha|secret|bearer|token|api[_-]?key') {
            foreach ($sensitiveValue in $SensitiveValues) {
                $outputLine = $outputLine.Replace($sensitiveValue, '[omitido]')
            }
            Write-Output $outputLine
        }
    }
}

if (-not (Test-Path -LiteralPath $BackendPath -PathType Container)) {
    throw "Backend não encontrado em: $BackendPath"
}
$resolvedBackendPath = (Resolve-Path -LiteralPath $BackendPath).Path
Set-Location -LiteralPath $resolvedBackendPath
$sensitiveValues = @()
$propertyPaths = @(
    (Join-Path $resolvedBackendPath 'src\main\resources\application.properties'),
    (Join-Path $resolvedBackendPath '.env.properties')
)
foreach ($propertiesPath in $propertyPaths) {
    if (Test-Path -LiteralPath $propertiesPath -PathType Leaf) {
        foreach ($propertyLine in [IO.File]::ReadAllLines($propertiesPath)) {
            if ($propertyLine -match '^\s*(spring\.datasource\.(?:url|username|password)|api\.security\.token\.secret|GHYDRO_DB_URL|GHYDRO_DB_USER|GHYDRO_DB_PASSWORD|GHYDRO_JWT_SECRET)\s*[=:]\s*(.*)$') {
                $propertyValue = $Matches[2].Trim()
                if ($propertyValue -match '^\$\{([A-Za-z0-9_]+)(?::(.*))?\}$') {
                    $environmentValue = [Environment]::GetEnvironmentVariable($Matches[1])
                    $propertyValue = if ($environmentValue) { $environmentValue } else { $Matches[2] }
                }
                if (-not [string]::IsNullOrEmpty($propertyValue)) {
                    $sensitiveValues += $propertyValue
                }
            }
        }
    }
}
$backendScript = Join-Path $resolvedBackendPath 'start-backend.cmd'
if (Test-Path -LiteralPath $backendScript -PathType Leaf) {
    $ErrorActionPreference = 'Continue'
    & $backendScript 2>&1 | Protect-BackendOutput -SensitiveValues $sensitiveValues
    $backendExitCode = $LASTEXITCODE
    exit $backendExitCode
}

$mavenWrapper = Join-Path $resolvedBackendPath 'mvnw.cmd'
if (-not (Test-Path -LiteralPath $mavenWrapper -PathType Leaf)) {
    throw "Nenhum start-backend.cmd ou mvnw.cmd encontrado em: $resolvedBackendPath"
}

# A configuração de Java pertence somente a este processo e aos seus filhos.
$env:JAVA_HOME = Find-CompatibleJdk
$env:Path = "$env:JAVA_HOME\bin;$env:Path"
$springBootArguments = @(
    '--server.port=8081'
    '--debug=false'
    '--trace=false'
    '--logging.level.root=INFO'
    '--logging.level.org.springframework.web=INFO'
    '--logging.level.org.springframework.security=INFO'
) -join ' '
$ErrorActionPreference = 'Continue'
& $mavenWrapper clean compile spring-boot:run "-Dspring-boot.run.arguments=$springBootArguments" 2>&1 |
    Protect-BackendOutput -SensitiveValues $sensitiveValues
$backendExitCode = $LASTEXITCODE
exit $backendExitCode
