

// TOOL:     vlog2tf
// DATE:     Thu Sep 26 17:26:49 2024
 
// TITLE:    Lattice Semiconductor Corporation
// MODULE:   soft_spi_slave
// DESIGN:   soft_spi_slave
// FILENAME: soft_spi_slave_tf.v
// PROJECT:  VNA_FPGA_DSP
// VERSION:  2.0
// This file is auto generated by Radiant


`timescale 1 ns / 1 ps

// Define Module for Test Fixture
module soft_spi_slave_tf();
	
	// Parameters
    parameter CLK_PERIOD = 4; // Clock period in ns (250 MHz)
	parameter SCK_CYC = 40;
    parameter SCK_PERIOD = CLK_PERIOD*SCK_CYC; // SCK period in clock periods

	// Inputs
    reg rst;
    reg clk;
    reg sck;
    reg ncs;
    reg si;
    reg [2:0] data_in;


	// Outputs
    wire so;
    wire [1:0] addr;
    wire addr_ready;
    wire rw;
    wire [2:0] data_out;
    wire data_ready;


	// Bidirs


	// Instantiate the UUT
	// Please check and add your parameters manually
    soft_spi_slave #(
		.msg_width(6),
		.addr_width(2)
	) UUT (
        .rst(rst), 
        .clk(clk), 
        .sck(sck), 
        .ncs(ncs), 
        .so(so), 
        .si(si), 
        .addr(addr), 
        .addr_ready(addr_ready), 
        .rw(rw), 
        .data_out(data_out), 
        .data_ready(data_ready), 
        .data_in(data_in)
        );
		
	// Clock generation
    initial begin
        clk = 0;
		#(0.5)
        forever #(CLK_PERIOD / 2) clk = ~clk; // Toggle clock every half period
    end
	
	// SCK generation
    initial begin
        sck = 0;
        forever #(SCK_PERIOD / 2) sck = ~sck; // Toggle sck every half period
    end

	// Initialize Inputs
	// You can add your stimulus here
    initial begin
		rst = 1; // Start in reset state
		ncs = 1; // Chip not selected at the beginning
		si = 0;		
		data_in = 3'b000;
		
		forever begin
			// Release reset after some cycles
			#(2 * SCK_PERIOD); 
			rst = 0;
			
			#(SCK_PERIOD); // Data changes on clock falling edges
			ncs = 0;
			
			si = 1;
			#(SCK_PERIOD)
			si = 0;
			#(SCK_PERIOD)
			si = 1;
			#(SCK_PERIOD)
			si = 0;
			data_in = 3'b101;
			#(SCK_PERIOD);
			si = 1;
			#(SCK_PERIOD)
			si = 1;
			#(SCK_PERIOD)
			
			// Back to back data transfer test
			
			si = 1;
			#(SCK_PERIOD)
			si = 0;
			#(SCK_PERIOD)
			si = 1;
			#(SCK_PERIOD)
			si = 1;
			data_in = 3'b110;
			#(SCK_PERIOD);
			si = 1;
			#(SCK_PERIOD)
			si = 0;
			#(SCK_PERIOD)
			
			#(SCK_PERIOD / 2);
			ncs = 1;
			data_in = 3'b000;
			
			// Trigger reset after some cycles
			#(10 * CLK_PERIOD); 
			rst = 1;
		end
    end

endmodule // soft_spi_slave_tf