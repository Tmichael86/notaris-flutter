param([switch]$UiSmoke)
$ErrorActionPreference='Stop'
$repo=Split-Path $PSScriptRoot -Parent
$pointer=Join-Path $repo '.local/notarisdev-profile.json'
if(!(Test-Path $pointer)){throw 'Blocked: notarisdev has not been provisioned with approval'}
$profile=Get-Content $pointer -Raw|ConvertFrom-Json
if($profile.database -ne 'notarisdev' -or $profile.port -ne 5432 -or $profile.generation -notmatch '^[a-f0-9]{32}$'){throw 'Invalid development profile'}
if($profile.fixture -ne 'smoke-v1'){throw 'No approved reference manifest for this fixture'}
$previous=$env:NOTARIS_DEV_GENERATION;$location=Get-Location
$previousReferences=$env:NOTARIS_DEV_REFERENCE_MANIFEST
$previousSmoke=$env:NOTARIS_DEV_UI_SMOKE
try {
 $env:NOTARIS_DEV_UI_SMOKE=if($UiSmoke){'1'}else{'0'}
 if($UiSmoke){
  $target=Join-Path ([Environment]::GetFolderPath('ApplicationData')) ('com.notaris/frontend_notaris/notarisdev/'+$profile.generation+'/offline.sqlite')
  if(!(Test-Path -LiteralPath $target)){throw 'Existing development SQLite required for UI smoke'}
 }
 Set-Location (Join-Path $repo 'backend-notaris-go')
 $references=& go run ./cmd/devfixture -mode references
 if($LASTEXITCODE){throw 'Unable to read fixture-owned reference manifest'}
 $references=($references -join "`n")|ConvertFrom-Json
 $references|Add-Member -NotePropertyName generation -NotePropertyValue $profile.generation
 $env:NOTARIS_DEV_REFERENCE_MANIFEST=$references|ConvertTo-Json -Depth 5 -Compress
 $env:NOTARIS_DEV_GENERATION=$profile.generation
 Set-Location (Join-Path $repo 'frontend_notaris')
 & flutter run -d windows --debug -t lib/notaris_dev_main.dart
 if($LASTEXITCODE){throw "Flutter exited with code $LASTEXITCODE"}
} finally {
 if($null -eq $previousSmoke){Remove-Item Env:NOTARIS_DEV_UI_SMOKE -ErrorAction SilentlyContinue}else{$env:NOTARIS_DEV_UI_SMOKE=$previousSmoke}
 Set-Location $location
 if($null -eq $previous){Remove-Item Env:NOTARIS_DEV_GENERATION -ErrorAction SilentlyContinue}else{$env:NOTARIS_DEV_GENERATION=$previous}
 if($null -eq $previousReferences){Remove-Item Env:NOTARIS_DEV_REFERENCE_MANIFEST -ErrorAction SilentlyContinue}else{$env:NOTARIS_DEV_REFERENCE_MANIFEST=$previousReferences}
}
