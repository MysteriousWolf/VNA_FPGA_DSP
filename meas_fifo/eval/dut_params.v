localparam WADDR_DEPTH = 4096;
localparam WDATA_WIDTH = 24;
localparam RADDR_DEPTH = 4096;
localparam RDATA_WIDTH = 24;
localparam FIFO_CONTROLLER = "FABRIC";
localparam FORCE_FAST_CONTROLLER = 0;
localparam IMPLEMENTATION = "EBR";
localparam WADDR_WIDTH = 12;
localparam RADDR_WIDTH = 12;
localparam REGMODE = "reg";
localparam RESETMODE = "sync";
localparam ENABLE_ALMOST_FULL_FLAG = "FALSE";
localparam ALMOST_FULL_ASSERTION = "static-dual";
localparam ALMOST_FULL_ASSERT_LVL = 4095;
localparam ALMOST_FULL_DEASSERT_LVL = 4094;
localparam ENABLE_ALMOST_EMPTY_FLAG = "FALSE";
localparam ALMOST_EMPTY_ASSERTION = "static-dual";
localparam ALMOST_EMPTY_ASSERT_LVL = 1;
localparam ALMOST_EMPTY_DEASSERT_LVL = 2;
localparam ENABLE_DATA_COUNT_WR = "FALSE";
localparam ENABLE_DATA_COUNT_RD = "FALSE";
localparam FAMILY = "iCE40UP";
`define iCE40UP
`define ice40tp
`define iCE40UP5K
