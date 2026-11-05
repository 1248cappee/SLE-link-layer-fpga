`ifndef SLE_DEFS_VH
`define SLE_DEFS_VH
`define SLE_FREE       3'd0
`define SLE_READY      3'd1
`define SLE_FETCHED    3'd2
`define SLE_RUNNING    3'd3
`define SLE_DONE       3'd4
`define SLE_SKIPPED    3'd5
`define SLE_CANCELLED  3'd6
`define SLE_ERROR      3'd7
`define SLE_EV_START   4'd1
`define SLE_EV_END     4'd2
`define SLE_EV_SKIP    4'd3
`define SLE_EV_CANCEL  4'd4
`define SLE_EV_ERROR   4'd5
`define SLE_EV_TX      4'd6
`define SLE_EV_RX      4'd7
`define SLE_OK         8'd0
`define SLE_LATE       8'd1
`define SLE_CONFLICT   8'd2
`define SLE_SW_CANCEL  8'd3
`define SLE_BAD_DESC   8'd4
`define SLE_BUS_FAULT  8'd5
`define SLE_WINDOW_END 8'd6
`define SLE_NO_BUFFER  8'd7
`define SLE_PHY_ABI    32'h00010000
`define SLE_PHY_TX_START 0
`define SLE_PHY_TX_END   1
`define SLE_PHY_RX_SYNC  2
`define SLE_PHY_DRAIN    3
`endif
