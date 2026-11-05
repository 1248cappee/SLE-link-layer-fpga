# rw_ble_top

`rw_ble_top_tglp_ext`: Optional rational low-power time retention. Tests: tb_low_power.

`rw_ble_core_cntl`: RW architectural integration / explicit handshakes. Tests: tb_system, tb_scheduler, tb_secure_system, tb_appendix_f, tb_secure_chain, tb_board, tb_board_suite.

`rw_ble_top`: RW architectural integration / explicit handshakes. Tests: tb_system, tb_scheduler, tb_secure_system, tb_appendix_f, tb_secure_chain, tb_board, tb_board_suite.

`rw_ble_core`: RW architectural integration / explicit handshakes. Tests: tb_system, tb_scheduler, tb_secure_system, tb_appendix_f, tb_secure_chain, tb_board, tb_board_suite.

`rw_ble_misc_logic`: Native PHY control format, full length and MCS packing. Tests: tb_control, real_phy_type1, real_phy_type2, real_phy_type3, real_phy_type4.

Run all commands from the SLE root. Shared dependencies are in ../rtl.f; source-of-truth interface changes are in ../docs/module_mapping.json.
