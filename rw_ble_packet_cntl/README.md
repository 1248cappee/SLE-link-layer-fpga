# rw_ble_packet_cntl

`rw_ble_packet_cntl_main_fsm`: Descriptor-chain sequencer, ordered memory access and TX/RX completion. Tests: tb_system, tb_lengths, tb_secure_system, tb_recovery, tb_appendix_f, tb_secure_chain.

`rw_ble_packet_cntl_em_access_fsm`: Descriptor-chain sequencer, ordered memory access and TX/RX completion. Tests: tb_system, tb_lengths, tb_secure_system, tb_recovery, tb_appendix_f, tb_secure_chain.

`rw_ble_packet_cntl`: Descriptor-chain sequencer, ordered memory access and TX/RX completion. Tests: tb_system, tb_lengths, tb_secure_system, tb_recovery, tb_appendix_f, tb_secure_chain, tb_board, tb_board_suite.

Run all commands from the SLE root. Shared dependencies are in ../rtl.f; source-of-truth interface changes are in ../docs/module_mapping.json.
