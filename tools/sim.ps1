param([string]$Python='C:\Users\kong\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe')
$ErrorActionPreference='Stop'
& $Python -X utf8 "$PSScriptRoot\run_tests.py" tb_primitives tb_crypto tb_stream_crypto tb_time_fifo tb_registers tb_control tb_low_power tb_bus tb_auxiliary tb_system tb_scheduler tb_recovery tb_lengths tb_secure_system tb_appendix_f tb_secure_chain tb_resources tb_submit_threshold
if($LASTEXITCODE -ne 0){throw 'Link-layer model regression failed'}
