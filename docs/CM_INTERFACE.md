# SLE CM ABI 1.1

CM.zip is immutable architecture reference. None of its RTL is compiled.
`cm_mapping.json` records all 95 reference files. Bluetooth audio, MWS/WCI and
vendor-radio algorithms are excluded by profile. Seven forward AES modules
now retain the reference names and split control, key expansion and transforms.
The three bidirectional transform alternatives map to their forward counterparts;
CCM decryption needs forward CTR, so inverse AES is not advertised or compiled.

## Crypto hierarchy

`rw_cm_crypto_engine` integrates the BRAM/CCM sequencer `rw_cm_ccm_top`.
Its `sle_block_cipher` boundary owns the selected algorithm and stable result.
AES is implemented by `rw_cm_aes_top`, with independent `rw_cm_aes_fsm`
and `rw_cm_aes_cipher_decipher` round datapath. Each active round instantiates
`rw_cm_aes_keyexpansion`, `rw_cm_aes_sbox`, `rw_cm_aes_shiftrows` and
`rw_cm_aes_mixcolumns`. The key and state are captured on accepted START;
busy START pulses do not change ownership. DONE is one cycle. Outputs retain
the previous complete block until the next completion, including algorithm changes.

SM4 uses the explicitly added `sle_cm_sm4_cipher`, `sle_cm_sm4_keyexpansion`
and `sle_cm_sm4_round` modules. Software command/data movement belongs to
`sle_cm_crypto_dma`; real-time streams keep their existing exclusive ownership.
Default block latency is ten AES or 32 SM4 cycles after acceptance. Streaming
TX retains two AES or four SM4 rounds per cycle. Non-divisor configurations
are also checked by `tb_cm_cipher` against independent OpenSSL-backed vectors.
These are newly written SLE modules; CM.zip is never extracted into a build.
CCM payload storage uses one read port shared by idle host access and the
active engine, plus one byte-enabled write port. All physical RAM controls
pass through synchronously reset registers. Host read latency is two cycles;
read data is meaningful only with read_valid. Simultaneous idle read/write to
the same word is read-first. Host requests while busy are ignored. Reset
cancels validity/ownership but does not clear RAM; an already accepted write
may commit on the reset sampling edge, matching the EM hard-reset contract.
Internal reads cannot be displaced by a host request. The final MIC write
commits before DONE is visible. Normal soft reset/sleep waits for quiescence.

## Clocks and resets

`rw_ble_top` adds `aon_clk`, `external_wake`, `ll_clock_enable` and read-only
sleep/main-clock counters. With `AON_ENABLE=0` host logic uses `clk` (legacy
test/integration mode). The P101 board sets `AON_ENABLE=1`; AON is the ungated
20-MHz clock and `clk` is its BUFGCE-gated copy. This configuration requires
the clocks to be phase-related. It is not an arbitrary asynchronous host bus.
The shared reset epoch resets both domains and forces clock enable high.

Sleep waits for no owned tasks, no FIFO entries, all EM requests completed,
packet/crypto idle, filter/resolve idle and tester TX/RX quiescence. An unsafe
request is rejected. The controller blocks new core accesses before stopping
the clock. On wake it enables the clock, restores a bundled time/phase/day
snapshot, waits for acknowledgment and then releases access. Core state and
BRAM contents are retained; normal wake does not assert soft reset.

The board uses an internal fractional 32768-Hz reference CE. AON 20-MHz phase
supplies the measured quantization correction; 0x51c reports the difference
between elapsed fine ticks and the raw low-rate estimate. This validates
digital retention and gating, not an independent oscillator or power savings.
`rw_cm_timing_gen_lp` remains a separate rational independent-clock timekeeper.

Sleep states: 0 awake, 1 drain/capture, 2 gate settling, 3 gated, 4 clock start,
5 restore handshake, 6 release settling. Core accesses during states 1..6
return errors; AON sleep registers remain accessible. Host bridges always run
on AON and retain response backpressure. Hard-reset accepted-write semantics
remain as documented in INTERFACE.md.

## Local registers (global JTAG base 0x40000000)

- 0x030 DEEPSLCNTL: bit0 enable RW; bit1 ENTER W1P; bit2 software WAKE W1P.
  ENTER writes must include bit0=1. Reserved bits are rejected. Reads return
  only enable. Unsafe/too-near entry returns a bus error and records reason.
- 0x034 DEEPSLWKUP: duration in 0.5us units, full-word writes while awake.
  The earliest armed timer also limits the duration. Actual gate interval ends
  at least the configured margin before the requested deadline.
- 0x038 / 0x508: reason[11:4], state[3:0]. Entry rejection 1=unsafe, 2=too near;
  wake 2=deadline, 4=external level, 8=software. Interpret reason with state.
- 0x500 ID=0x534c434d; 0x504 ABI=0x00010001; both RO.
- 0x50c wake margin in fine ticks, reset/minimum 500; awake/full-word writes.
- 0x510/514 sleep/wake counts; 0x518 low-rate edges in current/last sleep;
  0x51c quantization correction; 0x520 five-grid capability mask 0x1f;
  0x524 remaining fine ticks; 0x528 elapsed fine ticks; all RO.
- 0x050 / 0x540 diagnostics: bit0 CLEAR W1P, bit1 FREEZE RW. Reset zero.
  0x054 reads CM interrupt status. 0x544 reads CM ABI 1.1.
- 0x548 reads, 0x54c writes, 0x550 wait cycles, 0x554 faults, 0x558 minimum
  EM address, 0x55c maximum, 0x560 first-fault address, 0x564 first-fault
  info[3]=valid,[2]=write,[1:0]=host/scheduler/packet source. Counts include all
  EM clients (the software DMA exclusively uses the scheduler port).
- 0x568 day[9:0] and valid[10]; 0x56c time-generation token[15:0]; RO.
- 0x574 CM interrupt status W1C; 0x578 mask RW. Bits 0=wake, 1=EM fault,
  2=coexistence withdrawal, 3=software CCM complete. Simultaneous set wins
  clear. Masked status is ORed into existing IRQ; original IRQ bits unchanged.
- 0x150 coex enable bit0; 0x154 same-domain test/platform peer busy bit0 and
  priority[5:1]; 0x158 reserved, RAZ/write-zero. Configuration writes while an
  ET is owned are rejected. The existing external WLAN inputs must be stable
  same-domain inputs or supplied through an upstream atomic CDC handshake.

Undefined CM extension reads return an error. RO writes are rejected except
explicit RAZ/write-zero aliases. Byte enables merge only writable fields;
duration/margin intentionally require full-word writes. Buffers are not reset.

## Per-ET configuration

0x600+ET*16: word0 selection[2:0]=0..4 for 25/50/75/100/125us, bit3 grid check
enable, bit8 slot/day nonce. Reset zero disables grid checks for compatibility
with existing absolute fine timestamps; the base time remains 125us.
Word1 is origin base slot[29:0], word2 origin fine[9:0] (0..249). Word3 is a
time-generation latch: writing zero captures 0x56c; nonzero writes are rejected.
All four words are frozen while the ET is owned, including terminal queued.

Grid legality is `(target - origin) mod (50,100,150,200,250) == 0` fine ticks.
The signed base-slot difference uses the 30-bit half-range convention. Targets
exactly half a range apart are invalid. The grid never shifts a task. Minimum
submit lead remains 500 fine ticks and preparation notification remains 8 base
slots; neither is scaled by the scheduling-grid selection.

## Data-plane security and software commands

Payload-count profile remains unchanged. Slot/day profile uses a 40-bit
little-endian value `{day[9:0],base_slot[29:0]}` followed by the eight IV bytes.
TX uses the scheduled first-frame slot; RX uses the actual sync slot. Day is
initialized according to slot bit29 and incremented on base-counter wrap;
exhaustion invalidates the profile. A time load changes the generation token,
so the ET must explicitly revalidate its context before another secure task.
The 16-bit generation saturates on exhaustion and disables the time profile
until a reset/reinitialization; it never wraps into an old valid generation.

Slot/day profile is admitted for single-frame TX or RX activities. Chained,
continuous and bidirectional activities must use payload-count profile; this
prevents nonce reuse within a base slot without inventing packet start times.
The hardware rejects unsupported profile/activity combinations. This is an
explicit capability boundary, not full SLE security/profile certification.
HMAC-SM3, pairing negotiation and key derivation remain outside this build.

Software CM command: 0x0b4..0x0c0 key low-to-high 32-bit words; 0x0c4 command
pointer in 2-byte units, command aligned to 4B and entirely inside first 32KiB.
0x0b0 write bit0 START, bits[3:1]={auth_only,decrypt,SM4}; other bits invalid.
Read bits0 BUSY,1 sticky DONE,2 sticky ERROR. Key/pointer/start updates while
busy or any ET owned return errors. New START clears completion status.
0x57c reads the result. The software operation exclusively owns the scheduler
EM port until final result-write ACK; task scheduling is paused meanwhile.

The 32B command has source pointer and payload length at +0, destination
pointer and capacity at +4, thirteen nonce bytes in wire order at +8..+20,
result at +24 and zero at +28. Source/destination pointers use 2B units and
must be 4B aligned. Length/capacity occupy bits26:16, pointer bits15:0. Length
0..2043, MIC 4B. Software must freeze the command and buffers until DONE.
Result low bits: 0 done,1 error,2 MIC applicable,3 MIC pass,4 output committed;
bits18:8 report output length on success, bits15:8 report reason on failure.
MIC failure does not write output. Done is raised after all output/result ACKs.

## Board-only additions

The original test window remains at 0x40040000. +0x70 configures the digital
coex peer: bit0 revoke during TX, bit1 force busy, bit2 delay initial grant, bits12:8 priority; +0x74 is
revoke delay in AON clocks after test TX start. +0x78/7c read sequence cycles;
+0x80 main clock count; +0x84 external wake delay after gating (zero disables);
+0x88 enables TX comparison against independently preloaded RX/golden bytes;
+0x8c records first TX mismatch (0xffff means none). Injection configuration
changes require idle LL/sequence. Original tester RAM/CRC/MIC semantics remain.

Microcode adds op12 counted loop, op13 write saved ET target as grid origin,
op14 repeat until 64-bit elapsed-cycle deadline; op15 monotonic time check;
op16 sample/verify stopped main-clock count; op17 verify main-clock restart. Watchdog limits each operation;
host timeout bounds the complete program. The pressure program uses a 36-billion
cycle minimum (30min at 20MHz), checks outcomes each iteration and records errors.
ILA expands to 384 bits; original low 256 bits retain their old locations.
Bits256=clock enable,260:257=sleep state,292:261=wake count,324:293=sleep count,
356:325=actual main-clock edge count. All timestamps are digital test events.
