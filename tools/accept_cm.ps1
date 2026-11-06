param([string]$Python='C:\Users\kong\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe',[switch]$SkipPressure)
$ErrorActionPreference='Stop'
$entry=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\board\tools\accept_cm.ps1'))
$action={& $entry -Python $Python -SkipPressure:$SkipPressure}.GetNewClosure()
& "$PSScriptRoot\with_power_hold.ps1" -Action $action
