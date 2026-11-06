# CM implementation status

The final CM cipher-hierarchy and synchronous RAM-control implementation
has passed all 28 XSim testbenches, including all 87 board-program scenarios.
Additional CCM checks cover pending-read reset, both algorithms aborted during
computation, retained RAM, no stale completion, and independent-vector recovery.
No old result is accepted for changed source. Independent xc7z100 synthesis confirmed one physical CCM
payload BRAM; its address/data/byte-enable controls now have synchronous
registers and pass the dedicated REQP-1839/1840 checks. Host reads explicitly
wait two clocks for read_valid. The four directed crypto/system benches passed
after that change (build/cm_crypto_bram.*).
Seven AES modules now implement the CM reference responsibility split rather
than mapping all ten applicable AES files to one monolithic block. Three
bidirectional alternatives share the corresponding forward transforms; SM4
has a separately named round/key/engine hierarchy. The interface and
parameter-dependent block latency are preserved and independently tested,
including immediate back-to-back algorithm changes without an idle bubble.

The final r5 full P101 implementation passed with setup slack 20.997 ns,
hold slack 0.043 ns, 42,127 LUTs, 45,027 registers, 135 BRAM tiles and zero
DSPs. No black boxes, latches, own BRAM async-control violations or unsafe/
unknown CDC endpoints remain. The actual dedicated gate reports 7SERIES;
JTAG/ILA/debug clocks are physically connected to the ungated AON driver.
Remaining vendor debug-IP and benign synthesis notices are documented in
CM_TOOL_WARNINGS.md, without rule waivers.

All three new physical board rounds passed 87/87 on the same image. Each
round performed 10,000 sleep/wake cycles and full 128KiB EM retention checks.
The representative ILA captures contain 995, 993 and 997 gated samples with
stable main-clock counts. Target serial: Digilent/210203859289A, xc7z100_1.
Image SHA256:
827173e6b9bb1ca6fac9ed1540a12e894bc8b9f4ba84b46df34e7c1f72c5314b.
The isolated regeneration audit passed for all 149 RTL/test/filelist objects.

95 CM references are mapped: 36 same-name implementations, three forward-
transform equivalents, 56 explicitly excluded profile branches. The build
has 43 original BLE correspondences, 43 newly written CM RTL files, four
common RTL files and six board RTL files. No original CM RTL is compiled.
The seven supplied reference files and 153 frozen PHY files are unchanged.

The user stopped the older r3 30-minute pressure run. It was safely quiesced
with 402,076 TX frames and no tester error, but is NOT a completed pressure
pass. Its records are preserved under build/board/history/r3_user_stopped_pressure/.
No long pressure run was restarted for r5. Functional acceptance is PASS;
the original combined acceptance including 30-minute pressure is not passed.
See build/board/cm_acceptance.json and docs/CM_ACCEPTANCE.md for separate flags.

The pre-CM source/evidence snapshot is
`build/baselines/pre_cm_20261106/sources_and_evidence.zip`.
The earlier 22 simulations and 44 board scenarios are historical baseline only.
The prior r3 source/evidence is independently preserved under
build/baselines/cm_r3_before_cipher_split_20261106/. Diagnostic r4 was stopped
before acceptance; neither historical result substitutes for r5 evidence.

Scope: P101 xc7z100ffg900-2, 20 MHz, external PHY replaced by a digital
interface tester. No QSPI writes. CM.zip is read-only reference, never compiled.
Slot/day nonce remains limited to single-frame TX/RX. HMAC-SM3, key negotiation,
real PHY/RF, independent low-rate oscillator and whole-system power acceptance
are outside this agreed profile.
