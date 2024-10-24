localparam FAMILY = "iCE40UP";
localparam ADDRESS_DEPTH = 4096;
localparam DATA_WIDTH = 24;
localparam FIFO_CONTROLLER = "FABRIC";
localparam FORCE_FAST_CONTROLLER = 0;
localparam IMPLEMENTATION = "EBR";
localparam ADDRESS_WIDTH = 12;
localparam REGMODE = "reg";
localparam RESET_MODE = "async";
localparam ENABLE_ALMOST_FULL_FLAG = "FALSE";
localparam ALMOST_FULL_ASSERTION = "static-dual";
localparam ALMOST_FULL_ASSERT_LVL = 4095;
localparam ALMOST_FULL_DEASSERT_LVL = 4094;
localparam ENABLE_ALMOST_EMPTY_FLAG = "FALSE";
localparam ALMOST_EMPTY_ASSERTION = "static-dual";
localparam ALMOST_EMPTY_ASSERT_LVL = 1;
localparam ALMOST_EMPTY_DEASSERT_LVL = 2;
localparam ENABLE_DATA_COUNT = "FALSE";
`define iCE40UP
`define ice40tp
`define iCE40UP5K
