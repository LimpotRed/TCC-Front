param([string]$ApiBaseUrl = 'http://localhost:8081')
$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot
$flutterCommand = Get-Command flutter -ErrorAction SilentlyContinue
$flutterPath = if ($flutterCommand) { $flutterCommand.Source } else { 'C:\Users\Aluno\develop\flutter\bin\flutter.bat' }
if (-not (Test-Path -LiteralPath $flutterPath)) { throw 'Flutter não encontrado. Adicione o SDK ao PATH.' }
& $flutterPath pub get
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& $flutterPath run -d web-server --web-hostname localhost --web-port 8080 "--dart-define=API_BASE_URL=$ApiBaseUrl"
exit $LASTEXITCODE
