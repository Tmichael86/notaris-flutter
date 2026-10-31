# Dot-source from operator/test scripts. Passwords belong in the inherited PG
# environment, never Variables/arguments. No shell, no stderr-to-ErrorRecord pipe.
function Invoke-NotarisPsqlFile {
 param([Parameter(Mandatory)][string]$Executable,[Parameter(Mandatory)][string]$File,
       [Parameter(Mandatory)][string]$Log,[hashtable]$Variables=@{})
 function Quote-NativeArgument([string]$Value) {
  '"'+[regex]::Replace([regex]::Replace($Value,'(\\*)"','$1$1\"'),'(\\+)$','$1$1')+'"'
 }
 $arguments=@('-X','-w','-v','ON_ERROR_STOP=1')
 foreach($key in @($Variables.Keys|Sort-Object)){
  if($key -notmatch '^[A-Z][A-Z0-9_]*$'){throw 'Invalid psql variable name'}
  $arguments+=@('-v',("$key="+[string]$Variables[$key]))
 }
 $arguments+=@('-f',(Resolve-Path -LiteralPath $File).Path)
 $commandLine=($arguments|ForEach-Object {Quote-NativeArgument $_}) -join ' '
 $process=Start-Process -FilePath $Executable -ArgumentList $commandLine -WindowStyle Hidden -RedirectStandardOutput $Log -RedirectStandardError ($Log+'.stderr') -Wait -PassThru
 if($null -eq $process.ExitCode){throw 'psql exit code unavailable; do not assume success'}
 [PSCustomObject]@{ExitCode=[int]$process.ExitCode;Stdout=$Log;Stderr=($Log+'.stderr')}
}
