param([ValidateSet('Go','Flutter')][string]$Role,[string]$SessionRoot,[string]$RepoRoot)
. "$PSScriptRoot/petugas-manual-common.ps1"
$SessionRoot=Assert-TestRoot $SessionRoot
if($Role -eq 'Go') {
    Set-Location -LiteralPath (Join-Path $RepoRoot 'backend-notaris-go')
    $env:NOTARIS_SYNC_TEST_DSN='host=127.0.0.1 port=55439 user=notaris_test dbname=postgres sslmode=disable'
    $env:NOTARIS_FLUTTER_E2E='1'; $env:NOTARIS_MANUAL_DESKTOP='1'
    Remove-Item Env:NOTARIS_MANUAL_SMOKE -ErrorAction SilentlyContinue
    $env:NOTARIS_MANUAL_STOP_FILE=Join-Path $SessionRoot 'harness.stop'
    & go test -v -count=1 -timeout 35m -run TestPetugasSyncHTTPPostgres ./routes
} else {
    Set-Location -LiteralPath (Join-Path $RepoRoot 'frontend_notaris')
    $state=Read-State $SessionRoot
    $env:NOTARIS_MANUAL_SESSION=$state.SessionFile
    & flutter run -d windows --debug -t lib/petugas_manual_main.dart --dart-define=PETUGAS_MANUAL_SYNC=true
}
exit $LASTEXITCODE
