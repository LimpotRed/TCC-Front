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
    $javaInstallations = Join-Path $env:ProgramFiles 'Java'
    if (Test-Path -LiteralPath $javaInstallations -PathType Container) {
        $candidates += Get-ChildItem -LiteralPath $javaInstallations -Directory -Filter 'jdk-*' |
            Sort-Object Name -Descending | Select-Object -ExpandProperty FullName
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
$mavenWrapper = Join-Path $resolvedBackendPath 'mvnw.cmd'
if (-not (Test-Path -LiteralPath $mavenWrapper -PathType Leaf)) {
    throw "Maven wrapper não encontrado em: $resolvedBackendPath"
}

# A configuração de Java pertence somente a este processo e aos seus filhos.
$env:JAVA_HOME = Find-CompatibleJdk
$env:Path = "$env:JAVA_HOME\bin;$env:Path"
# O Spring lê a configuração original sem copiá-la para o diretório temporário.
$env:SPRING_CONFIG_IMPORT = 'optional:file:' + ((Join-Path $resolvedBackendPath '.env.properties') -replace '\\', '/')
# Compilar uma cópia temporária evita criar ou apagar arquivos no backend original.
$temporaryRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
$temporaryBackend = Join-Path $temporaryRoot ('ghydro-backend-copy-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $temporaryBackend | Out-Null
try {
    foreach ($entry in @('src', '.mvn', 'pom.xml', 'mvnw.cmd', 'mvnw')) {
        $source = Join-Path $resolvedBackendPath $entry
        if (Test-Path -LiteralPath $source) {
            Copy-Item -LiteralPath $source -Destination $temporaryBackend -Recurse -Force
        }
    }
    Set-Location -LiteralPath $temporaryBackend
    $springBootArguments = @(
        '--server.port=8081'
        '--spring.jpa.hibernate.ddl-auto=none'
        '--debug=false'
        '--trace=false'
        '--logging.level.root=INFO'
        '--logging.level.org.springframework.web=INFO'
        '--logging.level.org.springframework.security=INFO'
    ) -join ' '
    $ErrorActionPreference = 'Continue'
    & (Join-Path $temporaryBackend 'mvnw.cmd') compile spring-boot:run "-Dspring-boot.run.arguments=$springBootArguments" 2>&1 |
        Protect-BackendOutput -SensitiveValues $sensitiveValues
    $backendExitCode = $LASTEXITCODE
} finally {
    Set-Location -LiteralPath $temporaryRoot
    $resolvedTemporaryBackend = (Resolve-Path -LiteralPath $temporaryBackend).Path
    if ($resolvedTemporaryBackend -eq $temporaryBackend -and
        $resolvedTemporaryBackend.StartsWith($temporaryRoot, [StringComparison]::OrdinalIgnoreCase)) {
        Remove-Item -LiteralPath $resolvedTemporaryBackend -Recurse -Force
    }
}
exit $backendExitCode
