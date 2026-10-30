$ErrorActionPreference='Stop'
$repo=Split-Path $PSScriptRoot -Parent
$pointer=Join-Path $repo '.local/notarisdev-profile.json'
if(!(Test-Path $pointer)){throw 'Blocked: notarisdev has not been provisioned with approval'}
$profile=Get-Content $pointer -Raw|ConvertFrom-Json
if($profile.database -ne 'notarisdev' -or $profile.port -ne 5432 -or $profile.generation -notmatch '^[a-f0-9]{32}$'){throw 'Invalid development profile'}
$previous=$env:NOTARIS_DEV_GENERATION;$location=Get-Location
try {
 $env:NOTARIS_DEV_GENERATION=$profile.generation
 Set-Location (Join-Path $repo 'frontend_notaris')
 & flutter run -d windows --debug -t lib/notaris_dev_main.dart
 if($LASTEXITCODE){throw "Flutter exited with code $LASTEXITCODE"}
} finally {
 Set-Location $location
 if($null -eq $previous){Remove-Item Env:NOTARIS_DEV_GENERATION -ErrorAction SilentlyContinue}else{$env:NOTARIS_DEV_GENERATION=$previous}
}
