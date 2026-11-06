param([string]$Stage=(Join-Path $env:TEMP ('SLEB-'+[guid]::NewGuid().ToString('N').Substring(0,8))),[string]$Python='C:\Users\kong\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe',[switch]$ResumeResetFix)
$ErrorActionPreference='Stop'
& $Python -X utf8 "$PSScriptRoot\prepare.py" $Stage
if($LASTEXITCODE -ne 0){throw 'Board preparation failed'}
Get-ChildItem -LiteralPath 'D:\vivado\Vivado\2020.2\scripts\rt' -Filter *.tcl -Recurse | ForEach-Object { [void][IO.File]::ReadAllBytes($_.FullName) }
$env:PROCESSOR_ARCHITECTURE='AMD64'
Push-Location $Stage
try {
 $entry=if($ResumeResetFix){'tools/resume_reset_fix.tcl'}else{'tools/build.tcl'}
 & 'D:\vivado\Vivado\2020.2\bin\vivado.bat' -mode batch -source $entry -notrace -log build.log -journal build.jou
 if($LASTEXITCODE -ne 0){throw "Board build failed: $Stage\build.log"}
 $init=Get-ChildItem -LiteralPath "$Stage\project" -Filter ps7_init.tcl -Recurse | Select-Object -First 1
 if(-not $init){throw 'Missing generated PS initialization'}
 Copy-Item -LiteralPath $init.FullName -Destination "$Stage\results\ps7_init.tcl"
} finally {Pop-Location}
& "$PSScriptRoot\reset_sim.ps1" -Stage $Stage
& 'D:\vivado\Vivado\2020.2\bin\vivado.bat' -mode batch -source "$PSScriptRoot\check_debug_clocks.tcl" -notrace -log "$Stage\debug_clocks.log" -journal "$Stage\debug_clocks.jou" -tclargs $Stage
if($LASTEXITCODE -ne 0){throw 'Debug clock/AON physical connectivity check failed'}
& $Python -X utf8 "$PSScriptRoot\prepare.py" $Stage --collect
if($LASTEXITCODE -ne 0){throw 'Board artifact validation failed'}
