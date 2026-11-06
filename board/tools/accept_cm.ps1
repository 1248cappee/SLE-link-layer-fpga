param([string]$Python='C:\Users\kong\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe',[switch]$SkipPressure)
$ErrorActionPreference='Stop'
$artifact=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\build\board'))
for($round=1;$round -le 3;$round++){
 Write-Output "SLE_CM_DOWNLOAD_ROUND $round"
 & "$PSScriptRoot\run.ps1" -Python $Python 2>&1 | Tee-Object -FilePath "$artifact\round_$round.log"
 if($LASTEXITCODE -ne 0){throw "CM round $round failed"}
 $roundDir=Join-Path $artifact "rounds\$round"
 [void](New-Item -ItemType Directory -Path $roundDir -Force)
 Copy-Item -LiteralPath "$artifact\board_results.json" -Destination "$roundDir\board_results.json"
 Copy-Item -LiteralPath "$artifact\program.log" -Destination "$roundDir\program.log"
 Copy-Item -LiteralPath "$artifact\ps_init.log" -Destination "$roundDir\ps_init.log"
 Copy-Item -LiteralPath "$artifact\ps_post.log" -Destination "$roundDir\ps_post.log"
 Copy-Item -LiteralPath "$artifact\acceptance.json" -Destination "$roundDir\acceptance.json"
 Get-ChildItem -LiteralPath $artifact -Filter 'ila_*.csv' | Copy-Item -Destination $roundDir
}
if($SkipPressure){
 Write-Output 'SLE_CM_PRESSURE_EXCLUDED_BY_USER'
 & $Python -X utf8 "$PSScriptRoot\cm_report.py" --skip-pressure
 if($LASTEXITCODE -ne 0){throw 'CM functional acceptance evidence incomplete'}
 return
}
$bitHash=(Get-FileHash -LiteralPath "$artifact\sle_board.bit" -Algorithm SHA256).Hash.ToLowerInvariant()
$env:PROCESSOR_ARCHITECTURE='AMD64'
& 'D:\vivado\Vivado\2020.2\bin\vivado.bat' -mode batch -source "$PSScriptRoot\test.tcl" -notrace -log "$artifact\pressure.log" -journal "$artifact\pressure.jou" -tclargs $artifact "$PSScriptRoot\..\cases\pressure.tcl" $bitHash
if($LASTEXITCODE -ne 0){throw 'CM 30-minute pressure test failed'}
& $Python -X utf8 "$PSScriptRoot\cm_report.py"
if($LASTEXITCODE -ne 0){throw 'CM acceptance evidence incomplete'}
