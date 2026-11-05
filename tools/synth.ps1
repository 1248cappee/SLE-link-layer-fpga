param(
 [string]$StageRoot=(Join-Path $env:TEMP ('SLEP101-'+[guid]::NewGuid().ToString('N'))),
 [string]$Python='C:\Users\kong\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe'
)
$ErrorActionPreference='Stop'
& $Python -X utf8 "$PSScriptRoot\run_synth.py" --stage-root $StageRoot --prepare-only
if($LASTEXITCODE -ne 0){throw 'Synthesis preparation failed'}
Get-ChildItem -LiteralPath 'D:\vivado\Vivado\2020.2\scripts\rt' -Filter *.tcl -Recurse | ForEach-Object { [void][IO.File]::ReadAllBytes($_.FullName) }
$env:PROCESSOR_ARCHITECTURE='AMD64'
$env:SLE_SYNTH_TOP='rw_ble_top'
Push-Location (Join-Path $StageRoot 'ooc_stage')
try {
 & 'D:\vivado\Vivado\2020.2\bin\vivado.bat' -mode batch -source ooc.tcl -notrace -log final_direct.log -journal final_direct.jou
 if($LASTEXITCODE -ne 0){throw 'Vivado OOC failed; inspect final_direct.log'}
} finally { Pop-Location }
& $Python -X utf8 "$PSScriptRoot\run_synth.py" --stage-root $StageRoot --collect
if($LASTEXITCODE -ne 0){throw 'OOC result or source-hash validation failed'}
