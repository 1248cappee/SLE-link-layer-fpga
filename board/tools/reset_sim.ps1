param([Parameter(Mandatory=$true)][string]$Stage)
$ErrorActionPreference='Stop'
$simDir=Join-Path $Stage 'reset_sim'
New-Item -ItemType Directory -Path $simDir -Force | Out-Null
Copy-Item -LiteralPath "$Stage\project\sle_board.gen\sources_1\bd\board\ip\board_reset20_0\sim\board_reset20_0.vhd" -Destination $simDir
Copy-Item -LiteralPath "$PSScriptRoot\..\verification\tb_board_reset_ip.sv" -Destination $simDir
$env:PROCESSOR_ARCHITECTURE='AMD64'
Push-Location $simDir
try {
 & 'D:\vivado\Vivado\2020.2\bin\xvhdl.bat' --work xil_defaultlib board_reset20_0.vhd *> compile.log
 if($LASTEXITCODE -ne 0){throw 'Reset wrapper VHDL compilation failed'}
 & 'D:\vivado\Vivado\2020.2\bin\xvlog.bat' --sv --work xil_defaultlib tb_board_reset_ip.sv *>> compile.log
 if($LASTEXITCODE -ne 0){throw 'Reset TB compilation failed'}
 & 'D:\vivado\Vivado\2020.2\bin\xelab.bat' --relax -L proc_sys_reset_v5_0_13 -L unisims_ver -L unisim xil_defaultlib.tb_board_reset_ip -s reset_ip_sim *> elaborate.log
 if($LASTEXITCODE -ne 0){throw 'Reset IP elaboration failed'}
 & 'D:\vivado\Vivado\2020.2\bin\xsim.bat' reset_ip_sim -runall *> simulation.log
 if($LASTEXITCODE -ne 0 -or -not (Select-String -LiteralPath simulation.log -Pattern SLE_BOARD_RESET_IP_PASS -Quiet)){throw 'Reset IP test failed'}
 Copy-Item -LiteralPath simulation.log -Destination "$PSScriptRoot\..\..\build\reset_ip_sim.log"
 Write-Output SLE_BOARD_RESET_IP_PASS
}finally{Pop-Location}
