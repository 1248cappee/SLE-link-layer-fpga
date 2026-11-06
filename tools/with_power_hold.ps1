param([Parameter(Mandatory=$true)][scriptblock]$Action)
$ErrorActionPreference='Stop'
if(-not ('SleBoardPowerHold' -as [type])){
 Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class SleBoardPowerHold {
 [DllImport("kernel32.dll", SetLastError=true)]
 public static extern uint SetThreadExecutionState(uint flags);
}
'@
}
$previous=[SleBoardPowerHold]::SetThreadExecutionState([uint32]2147483649)
if($previous -eq 0){throw 'Cannot establish temporary system-awake request'}
try {& $Action} finally {[void][SleBoardPowerHold]::SetThreadExecutionState($previous)}
