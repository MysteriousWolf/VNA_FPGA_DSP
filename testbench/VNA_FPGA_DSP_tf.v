

// TOOL:     vlog2tf
// DATE:     Tue Oct  8 14:04:33 2024
 
// TITLE:    Lattice Semiconductor Corporation
// MODULE:   dsp_core
// DESIGN:   dsp_core
// FILENAME: VNA_FPGA_DSP_tf.v
// PROJECT:  VNA_FPGA_DSP
// VERSION:  2.0
// This file is auto generated by Radiant


`timescale 1 ns / 1 ps

// Define Module for Test Fixture
module dsp_core_tf();
	
	// Parameters
	parameter PRE_ST_DELAY = 10;
	parameter PLL_LOCK_DELAY = 10;
	parameter ADC_DELAY = 7.5; // Worst case from the datasheet
	parameter HS_PERIOD = 1000/250;
	parameter MS_PERIOD = HS_PERIOD*2;
	parameter LS_PERIOD = MS_PERIOD*2;
	parameter CLK_PERIOD = 4; // Clock period in ns (250 MHz)
	parameter SCK_CYC = 50;
    parameter SCK_PERIOD = CLK_PERIOD*SCK_CYC; // SCK period in clock periods
	
	localparam DSP_CONV_STAT_CONV_DONE = 16'h2000; // 1 << 13
	localparam DSP_CONV_STAT_POINT_CNT_MASK = 16'h1FFF;

// Inputs
    reg hs_clk;
    reg ms_clk;
	reg adc_conv_clk;
    reg lock;
    reg clk;
    reg rst;
    reg sck;
    reg ncs;
    reg si;
	reg [11:0] adc_a = 0;
	reg [11:0] adc_b = 0;


// Outputs
    wire so;
    wire meas_done;
    wire adc_clk;

// Bidirs


// Instantiate the UUT
// Please check and add your parameters manually
    dsp_core UUT (
		.hs_clk(hs_clk),
		.ms_clk(ms_clk),
		.pll_lock(lock),
        .sys_clk(clk), 
        .rst(rst), 
        .sck(sck), 
        .ncs(ncs), 
        .so(so), 
        .si(si), 
        .meas_done(meas_done), 
        .adc_clk(adc_clk),
		.adc_conv_clk(adc_conv_clk),
		.adc_a(adc_a),
		.adc_b(adc_b)
    );

	// Clock generation
    initial begin
        clk = 0;
		#(PRE_ST_DELAY)
		#(0.5)
        forever #(CLK_PERIOD / 2) clk = ~clk; // Toggle clock every half period
    end
	
    initial begin
        hs_clk = 0;
		#(PRE_ST_DELAY)
		#(0.5)
        forever #(HS_PERIOD / 2) hs_clk = ~hs_clk; // Toggle clock every half period
    end
	
    initial begin
        ms_clk = 0;
		#(0.5)
		#(PRE_ST_DELAY)
        forever #(MS_PERIOD / 2) ms_clk = ~ms_clk; // Toggle clock every half period
    end
	
    initial begin
        adc_conv_clk = 0;
		#(0.5)
		#(PRE_ST_DELAY)
		#(ADC_DELAY)
        forever #(LS_PERIOD / 2) begin
			adc_conv_clk = ~adc_conv_clk; // Toggle clock every half period
			if (~adc_conv_clk) begin
				adc_a = adc_a + 1;
				adc_b = adc_b + 1;
			end
		end
    end
	
	// SCK generation
    initial begin
        sck = 0;
		#(PRE_ST_DELAY)
		#(PLL_LOCK_DELAY)
        forever #(SCK_PERIOD / 2) sck = ~sck; // Toggle sck every half period
    end

// Initialize Inputs
// You can add your stimulus here

// Task to send address and data (similar to send_DSP in C)
task send_DSP;
    input [6:0] addr;    // 7-bit address
    input [23:0] data;   // 24-bit data
    integer i, j;
    begin
        // Activate chip select
        ncs = 0;

        // Send address (including the read/write bit)
        si = 0; // Read bit (0 for write command)
        #SCK_PERIOD;

        // Loop through the 7 address bits (MSB first)
        for (i = 6; i >= 0; i = i - 1) begin
            si = addr[i];  // Set `si` to the corresponding bit of the address
            #SCK_PERIOD;   // Wait for a clock period for each bit
        end

        // Send 24-bit data
        for (j = 23; j >= 0; j = j - 1) begin
            si = data[j];  // Set `si` to the corresponding bit of the data
            #SCK_PERIOD;   // Wait for a clock period for each bit
        end

        // Deactivate chip select
        #(SCK_PERIOD / 2);
        ncs = 1;
		
		// Wait a bit
        #(10*SCK_PERIOD);
    end
endtask

// Task to read from DSP (similar to read_DSP in C)
task read_DSP;
    input [6:0] addr;    // 7-bit address
    output [23:0] data;  // 24-bit data (output)
    integer i, j;
    begin
        // Activate chip select
        ncs = 0;

        // Send address (read command and 7-bit address)
        si = 1; // Read bit
        #SCK_PERIOD;

        // Loop through the 7 address bits (MSB first)
        for (i = 6; i >= 0; i = i - 1) begin
            si = addr[i];  // Set `si` to the corresponding bit of the address
            #SCK_PERIOD;   // Wait for a clock period for each bit
        end
		
        si = 0; // Read bit

        // Receive 24-bit data (assuming data is coming on `si`)
        for (j = 23; j >= 0; j = j - 1) begin
            #(SCK_PERIOD/2);  // Wait for a clock period to latch data
            data[j] = so; // Capture the data from SPI output
            #(SCK_PERIOD/2);  // Wait for a clock period to latch data
        end

        // Deactivate chip select
        #(SCK_PERIOD / 2);
        ncs = 1;
		
        #(10*SCK_PERIOD);
		
		// Wait a bit
        #(10*SCK_PERIOD);
    end
endtask

// Task to monitor DSP conversion
task monitor_dsp_conversion;
    input integer max_wait_cycles;
    output conversion_success;
    output [12:0] final_point_count;

    reg [23:0] rx_data;
    reg [12:0] point_count;
    integer wait_cycles;

    begin
        conversion_success = 0; // Initialize output (0 = not done)

        for (wait_cycles = 0; wait_cycles < max_wait_cycles; wait_cycles = wait_cycles + 1) begin
            // Read DSP status
            read_DSP(7'b0000011, rx_data);
            
            // Extract point count
            point_count = rx_data & DSP_CONV_STAT_POINT_CNT_MASK;
            
            // Check if conversion is done
            if (rx_data & DSP_CONV_STAT_CONV_DONE) begin
                conversion_success = 1; // Set output (1 = done)
                final_point_count = point_count;
                $display("Conversion done. Final point count: %d", point_count);
                disable monitor_dsp_conversion;
            end
            
            if ((wait_cycles % 10) == 0) begin // Display every 10 cycles
                $display("Waiting for conversion. Current point count: %d", point_count);
            end
            
            #10; // Wait for 10 time units (adjust as needed for your testbench timing)
        end

        $display("Timeout: Conversion did not complete within %d cycles.", max_wait_cycles);
        final_point_count = point_count; // Return the last observed point count
        conversion_success = 0; // Conversion not complete (timeout)
    end
endtask

reg [23:0] rx_data;

reg [12:0] final_count;
reg conversion_success;

initial begin
    rst = 0; // No reset signal (like we have irl)
    lock = 0;
    #(PRE_ST_DELAY) // Before the PLL locks
    ncs = 1; // Chip not selected at the beginning
    si = 0;
    #(PLL_LOCK_DELAY)
    lock = 1;

    forever begin
        #(2 * SCK_PERIOD);
        rst = 0;

		// Read the PLL lock bit to make sure we are reading correctly
        read_DSP(7'b0000001, rx_data);
		
		// Read device ID
        read_DSP(7'b0111111, rx_data);
		
        // Send configuration to 4 points
        send_DSP(7'b0000010, 24'h000004);
		
        // Start conversion (questionable?)
        send_DSP(7'b0000010, 24'h002004);
		
		// Wait for the measurement
		monitor_dsp_conversion(5, conversion_success, final_count);

		if (conversion_success) begin
			$display("Conversion completed successfully. Final count: %d", final_count);
		end else begin
			$display("Conversion failed or timed out. Last count: %d", final_count);
		end
			
		// Restart readout
		send_DSP(7'b0000100, 24'h000001);
		
		// Read the next point
		read_DSP(7'b0000100, rx_data);
		read_DSP(7'b0000101, rx_data);
		
		// Read the next point
		read_DSP(7'b0000100, rx_data);
		read_DSP(7'b0000101, rx_data);
		
		// Read the next point
		read_DSP(7'b0000100, rx_data);
		read_DSP(7'b0000101, rx_data);
		
		// Read the next point
		read_DSP(7'b0000100, rx_data);
		read_DSP(7'b0000101, rx_data); // This one should report that we are done on bit 13

        // Trigger reset after some cycles
        #(10 * CLK_PERIOD);
        rst = 1;
    end
end

endmodule // dsp_core_tf