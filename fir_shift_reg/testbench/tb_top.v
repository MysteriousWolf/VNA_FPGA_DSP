// =============================================================================
// >>>>>>>>>>>>>>>>>>>>>>>>> COPYRIGHT NOTICE <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
// -----------------------------------------------------------------------------
//   Copyright (c) 2018 by Lattice Semiconductor Corporation
//   ALL RIGHTS RESERVED
// --------------------------------------------------------------------
//
//   Permission:
//
//      Lattice SG Pte. Ltd. grants permission to use this code
//      pursuant to the terms of the Lattice Reference Design License Agreement.
//
//
//   Disclaimer:
//
//      This VHDL or Verilog source code is intended as a design reference
//      which illustrates how these types of functions can be implemented.
//      It is the user's responsibility to verify their design for
//      consistency and functionality through the use of formal
//      verification methods.  Lattice provides no warranty
//      regarding the use or functionality of this code.
//
// -----------------------------------------------------------------------------
//
//                  Lattice SG Pte. Ltd.
//                  101 Thomson Road, United Square #07-02
//                  Singapore 307591
//
//
//                  TEL: 1-800-Lattice (USA and Canada)
//                       +65-6631-2000 (Singapore)
//                       +1-503-268-8001 (other locations)
//
//                  web: http://www.latticesemi.com/
//                  email: techsupport@latticesemi.com
//
// -----------------------------------------------------------------------------
//
// =============================================================================
//                         FILE DETAILS
// Project               :
// File                  : tb_top.v
// Title                 : Testbench for ram_shift_reg.
// Dependencies          : 1.
//                       : 2.
// Description           :
// =============================================================================
//                        REVISION HISTORY
// Version               : 1.0.1
// Author(s)             :
// Mod. Date             : 03/05/2018
// Changes Made          : Initial version of testbench for shift register
// =============================================================================

`ifndef TB_TOP
`define TB_TOP

//==========================================================================
// Module : tb_top
//==========================================================================

`timescale 1ns/1ps

module tb_top();

`include "dut_params.v"

localparam CLK_FREQ = (FAMILY == "iCE40UP") ? 40 : 10;
localparam RESET_CNT = (FAMILY == "iCE40UP") ? 140 : 100;

localparam USE_SHIFT = MAX_SHIFT - 1;

reg                              chk = 1'b1;
reg                              clk_i;
reg                              rst_i;
reg                              clk_en_i;
reg         [(DATA_WIDTH-1):0]   wr_data_i;
reg         [(MAX_WIDTH-1):0]    addr_i;

reg [255:0]                      data_in = {256{1'b0}};

genvar din0;

for(din0 = 0; din0 < 8; din0 = din0 + 1) begin
    always @ (posedge clk_i) begin
        data_in[din0*32+31:din0*32] <= $urandom_range({32{1'b0}}, {32{1'b1}});
    end
end

wire [(DATA_WIDTH-1):0] rd_data_o;




// ----------------------------
// GSR instance
// ----------------------------
`ifndef iCE40UP
    GSR GSR_INST ( .GSR_N(1'b1), .CLK(1'b0));
`endif

`include "dut_inst.v"

initial begin
	rst_i = 1'b1;
	#RESET_CNT;
	rst_i = 1'b0;
end

initial begin
	clk_i = 1'b0;
	forever #CLK_FREQ clk_i = ~clk_i;
end

initial begin
	clk_en_i = 1'b1;
end

localparam TOTAL_LOOPS = 5;
localparam PROC = TOTAL_LOOPS*MAX_SHIFT;

integer i0;

initial begin
	wr_data_i <= data_in[DATA_WIDTH-1:0];
	addr_i <= USE_SHIFT;
	@(negedge rst_i);
	for(i0 = 0; i0 < PROC; i0 = i0 + 1) begin
		@(posedge clk_i);
		wr_data_i <= data_in[DATA_WIDTH-1:0];
        if(SHIFT_REG_TYPE == "variable") begin
            addr_i <= {1'b0, data_in[MAX_WIDTH-2:0]} + (2'b10);
        end
	end
    if(chk == 1'b1) begin
        $display("-----------------------------------------------------");
        $display("----------------- SIMULATION PASSED -----------------");
        $display("-----------------------------------------------------");
    end
    else begin
        $display("-----------------------------------------------------");
        $display("!!!!!!!!!!!!!!!!! SIMULATION FAILED !!!!!!!!!!!!!!!!!");
        $display("-----------------------------------------------------");
    end
	$finish;
end	

localparam PROC_WIDTH = clog2(2*PROC);
reg [DATA_WIDTH-1:0] mem [2*PROC-1:0];
reg [DATA_WIDTH-1:0] cmp_data_r = {DATA_WIDTH{1'b0}};
reg [DATA_WIDTH-1:0] cmp_data_p2_r = {DATA_WIDTH{1'b0}};
reg [PROC_WIDTH-1:0] wr_addr_r = {PROC_WIDTH{1'b0}};
reg [PROC_WIDTH-1:0] rd_addr_r = {PROC_WIDTH{1'b0}};
reg [PROC_WIDTH:0]   chk_addr_r = {(PROC_WIDTH+1){1'b1}};
reg [PROC_WIDTH:0]   chk_addr_p2_r = {(PROC_WIDTH+1){1'b1}};

always @ (posedge clk_i) begin
    if(clk_en_i == 1'b1 && rst_i == 1'b0) begin
        mem[wr_addr_r] <= wr_data_i;
        wr_addr_r <= wr_addr_r + 1;
    end
end

initial begin
    for(i0 = 0; i0 < 2*PROC; i0 = i0 + 1) begin
        mem[i0] = {DATA_WIDTH{1'b0}};
    end
end

reg [MAX_WIDTH-1:0] addr_p_r = {MAX_WIDTH{1'b0}};
always @ (posedge clk_i) begin
	addr_p_r <= addr_i;
end

if(IMPLEMENTATION == "LUT") begin
	if (FAMILY == "iCE40UP" || FAMILY == "common") begin
	    always @ (posedge clk_i) begin
	        if(clk_en_i & ~rst_i) begin
	            chk_addr_r <= wr_addr_r - (addr_i + 1);
	            cmp_data_r <= mem[wr_addr_r - (addr_i + 1)];
	        end
	    end
	end
	else begin
		always @ (*) begin
	        if(clk_en_i & ~rst_i) begin
	            chk_addr_r = wr_addr_r - (addr_i + 1);
	            cmp_data_r = mem[wr_addr_r - (addr_i + 1)];
	        end
	    end
	end	
end
else begin
    always @ (posedge clk_i) begin
        if(clk_en_i & ~rst_i) begin
            chk_addr_r <= wr_addr_r - (addr_i + 1);
            cmp_data_r <= mem[wr_addr_r - (addr_i + 1)];
        end
    end
end

reg rst_p_r = 1'b1;

always @ (posedge clk_i) begin
    rst_p_r <= rst_i;
end

if(REGMODE == "noreg") begin
    always @ (posedge clk_i) begin
        if(rst_p_r == 1'b0 && chk_addr_r[PROC_WIDTH] == 1'b0) begin
            if(cmp_data_r !== rd_data_o) begin
                $display("[%0d] Expected DATA = %h, Read DATA = %h. *ERROR*: Data mismatch!", $time, cmp_data_r, rd_data_o);
                chk <= 1'b0;
            end
            else begin
                $display("[%0d] Expected DATA = %h, Read DATA = %h", $time, cmp_data_r, rd_data_o);
            end
        end
    end
end
else begin
    always @ (posedge clk_i) begin
        cmp_data_p2_r <= cmp_data_r;
        chk_addr_p2_r <= chk_addr_r;
        if(rst_p_r == 1'b0 && chk_addr_p2_r[PROC_WIDTH] == 1'b0) begin
            if(cmp_data_p2_r !== rd_data_o) begin
                $display("[%0d] Expected DATA = %h, Read DATA = %h. *ERROR*: Data mismatch!", $time, cmp_data_p2_r, rd_data_o);
                chk <= 1'b0;
            end
            else begin
                $display("[%0d] Expected DATA = %h, Read DATA = %h", $time, cmp_data_p2_r, rd_data_o);
            end
        end
    end
end

function [31:0] clog2;
  input [31:0] value;
  reg   [31:0] num;
  begin
    num = value - 1;
    for (clog2=0; num>0; clog2=clog2+1) num = num>>1;
  end
endfunction

endmodule

`endif