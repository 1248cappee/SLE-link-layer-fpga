param([string]$Stage=(Join-Path $env:TEMP ('SLE-crypto-'+[guid]::NewGuid().ToString('N').Substring(0,8))),[string]$Python='C:\Users\kong\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe')
$ErrorActionPreference='Stop'
$cmRoot=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
[void](New-Item -ItemType Directory -Path (Join-Path $Stage 'rtl') -Force)
foreach($line in Get-Content -LiteralPath "$cmRoot\rtl.f"){
 if($line.EndsWith('.v')){Copy-Item -LiteralPath (Join-Path $cmRoot $line) -Destination (Join-Path $Stage 'rtl')}
}
Get-ChildItem -LiteralPath "$cmRoot\common\rtl" -Filter '*.vh' | Copy-Item -Destination (Join-Path $Stage 'rtl')
Copy-Item -LiteralPath "$PSScriptRoot\check_cm_crypto_bram.tcl" -Destination $Stage
$env:PROCESSOR_ARCHITECTURE='AMD64'
Push-Location $Stage
try{
 & 'D:\vivado\Vivado\2020.2\bin\vivado.bat' -mode batch -source check_cm_crypto_bram.tcl -notrace -log cm_crypto_bram.log -journal cm_crypto_bram.jou -tclargs $Stage
 if($LASTEXITCODE -ne 0){throw 'Directed CCM BRAM synthesis failed'}
 foreach($name in @('cm_crypto_bram.json','cm_crypto_bram.rpt','cm_crypto_bram.log','cm_crypto_bram_drc.rpt')){
  Copy-Item -LiteralPath (Join-Path $Stage $name) -Destination "$cmRoot\build\$name"
 }
}finally{Pop-Location}
& $Python -X utf8 "$PSScriptRoot\seal_cm_crypto_bram.py" $Stage
if($LASTEXITCODE -ne 0){throw 'CCM BRAM source proof failed'}
