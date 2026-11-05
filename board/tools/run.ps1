param([string]$Python='C:\Users\kong\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe',[switch]$TestsOnly)
$ErrorActionPreference='Stop'
$artifact=Join-Path $PSScriptRoot '..\..\build\board'
$artifact=[IO.Path]::GetFullPath($artifact)
& $Python -X utf8 "$PSScriptRoot\verify.py"
if($LASTEXITCODE -ne 0){throw 'Artifact/source verification failed'}
$env:PROCESSOR_ARCHITECTURE='AMD64'
if(-not $TestsOnly){
& 'D:\vivado\Vitis\2020.2\bin\xsct.bat' "$PSScriptRoot\init_ps.tcl" $artifact init
if($LASTEXITCODE -ne 0){throw 'PS initialization failed'}
& 'D:\vivado\Vivado\2020.2\bin\vivado.bat' -mode batch -source "$PSScriptRoot\program.tcl" -notrace -log "$artifact\program.log" -journal "$artifact\program.jou" -tclargs $artifact
if($LASTEXITCODE -ne 0){throw 'JTAG programming failed'}
& 'D:\vivado\Vitis\2020.2\bin\xsct.bat' "$PSScriptRoot\init_ps.tcl" $artifact post
if($LASTEXITCODE -ne 0){throw 'PS post-configuration failed'}
}
$bitHash=(Get-FileHash -LiteralPath "$artifact\sle_board.bit" -Algorithm SHA256).Hash.ToLowerInvariant()
& 'D:\vivado\Vivado\2020.2\bin\vivado.bat' -mode batch -source "$PSScriptRoot\test.tcl" -notrace -log "$artifact\board_test.log" -journal "$artifact\board_test.jou" -tclargs $artifact "$PSScriptRoot\..\cases\suite.tcl" $bitHash
if($LASTEXITCODE -ne 0){throw 'Board tests failed; inspect board_results.json and board_test.log'}
& $Python -X utf8 "$PSScriptRoot\report.py"
if($LASTEXITCODE -ne 0){throw 'Board evidence incomplete; inspect acceptance.json'}
