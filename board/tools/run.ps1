param([string]$Python='C:\Users\kong\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe',[switch]$TestsOnly)
$ErrorActionPreference='Stop'
$artifact=Join-Path $PSScriptRoot '..\..\build\board'
$artifact=[IO.Path]::GetFullPath($artifact)
& $Python -X utf8 "$PSScriptRoot\verify.py"
if($LASTEXITCODE -ne 0){throw 'Artifact/source verification failed'}
$env:PROCESSOR_ARCHITECTURE='AMD64'
if(-not $TestsOnly){
& 'D:\vivado\Vivado\2020.2\bin\vivado.bat' -mode batch -source "$PSScriptRoot\preflight.tcl" -notrace -log "$artifact\preflight.log" -journal "$artifact\preflight.jou"
if($LASTEXITCODE -ne 0){throw 'JTAG preflight failed before PS reset'}
$initText=(& 'D:\vivado\Vitis\2020.2\bin\xsct.bat' "$PSScriptRoot\init_ps.tcl" $artifact init 2>&1 | Out-String)
$initText | Set-Content -LiteralPath "$artifact\ps_init.log" -Encoding utf8
Write-Output $initText
if($LASTEXITCODE -ne 0 -or -not $initText.Contains('SLE_PS_INIT_PASS')){throw 'PS initialization failed or success marker missing'}
& 'D:\vivado\Vivado\2020.2\bin\vivado.bat' -mode batch -source "$PSScriptRoot\program.tcl" -notrace -log "$artifact\program.log" -journal "$artifact\program.jou" -tclargs $artifact
if($LASTEXITCODE -ne 0){throw 'JTAG programming failed'}
$postText=(& 'D:\vivado\Vitis\2020.2\bin\xsct.bat' "$PSScriptRoot\init_ps.tcl" $artifact post 2>&1 | Out-String)
$postText | Set-Content -LiteralPath "$artifact\ps_post.log" -Encoding utf8
Write-Output $postText
if($LASTEXITCODE -ne 0 -or -not $postText.Contains('SLE_PS_CLOCK_INIT_PASS')){throw 'PS post-configuration failed or success marker missing'}
}
$bitHash=(Get-FileHash -LiteralPath "$artifact\sle_board.bit" -Algorithm SHA256).Hash.ToLowerInvariant()
& 'D:\vivado\Vivado\2020.2\bin\vivado.bat' -mode batch -source "$PSScriptRoot\test.tcl" -notrace -log "$artifact\board_test.log" -journal "$artifact\board_test.jou" -tclargs $artifact "$PSScriptRoot\..\cases\suite.tcl" $bitHash
if($LASTEXITCODE -ne 0){throw 'Board tests failed; inspect board_results.json and board_test.log'}
& $Python -X utf8 "$PSScriptRoot\report.py"
if($LASTEXITCODE -ne 0){throw 'Board evidence incomplete; inspect acceptance.json'}
