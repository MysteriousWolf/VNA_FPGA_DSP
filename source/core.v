module dsp_core
#(
	parameter adc_width = 12,
	parameter device_ID = 24'b111100001100110010101011, // test pattern by default, change to real ID in project settings
	parameter rst_cycles = 4,
	localparam rst_cyc_cnt = $clog2(rst_cycles)
)
(
	// For testing
	//input hs_clk,
	//input ms_clk,
	//input pll_lock,
	
	// main clock
	input sys_clk,
	input rst,
	
	// SPI for data output
    input sck,
    input ncs,
    output so,
    input si,
	
	// Current measurement/calculation done
	output meas_done,
	
	// ADC inputs
	output adc_clk
	//input adc_conv_clk,
	//input [adc_width-1:0] adc_a,
	//input [adc_width-1:0] adc_b
);
	// Wires and registry
	//wire global_rst = ~rst;
	reg global_rst;
	reg [rst_cyc_cnt-1:0] g_rst_c;
	wire pll_lock;
	wire hs_clk; 		// 250 MHz - High speed clock
	wire ms_clk;		// 125 MHz - Medium speed clock (this can either be divided by 2 to get 62.5 MHz clock signal (for ADC), or we can simply route out the low speed clock)
	reg ls_clk; 		// 62.5 MHz - Low speed clock
	reg uls_clk;		// 31.25 MHz - Ultra low speed clock for scope to see
	reg uuls_clk;		// 15.625 MHz
	reg uuuls_clk;		// 7.8125 MHz
	
	// SPI Control
	wire [6:0]	spi_addr;		// 7 bit address
	wire 		spi_addr_rdy;
	wire 		spi_rw;			// 1 is read 0 is write
	wire [23:0]	spi_data;	// 24 bit data
	wire 		spi_data_rdy;
	reg [23:0]	spi_data_tx;	// 24 bit data - must be ready within 1 serial clock cycle
	
	// FIR signals
	/*reg			fir_flush = 0;
	
	reg [3:0] 	fir_addr = 0;
	reg [23:0] 	fir_coef = 0;
	reg 		fir_coef_rdy = 0;
	wire 		fir_coef_d;
	wire [23:0]	fir_coef_ro;
	
	reg [4:0]	fir_shift = 0;
	reg			fir_rs_rdy = 0;
	wire		fir_rs_d;
	wire [4:0]	fir_rs_ro;
		
	wire [adc_width-1:0]	a_filt;
	wire [adc_width-1:0]	b_filt;
	
	wire fir_done;
	
	// IQ signals
	wire [adc_width-1:0] amp_diff;
	wire [adc_width-1:0] phs_diff;*/
	
	pll_core PLL(
		.ref_clk_i(sys_clk),
        .rst_n_i(~rst),
		.lock_o(pll_lock),
        .outcore_o( ),
        .outglobal_o(hs_clk),
        .outcoreb_o( ),
        .outglobalb_o(ms_clk)
	);
		
	soft_spi_slave SPI(
		// Global signals
		.rst(global_rst),
		.clk(uuuls_clk),
		
		// SPI interface
		.sck(sck),
		.ncs(ncs),
		.so(so),
		.si(si),
		
		// Internal signals
		.addr(spi_addr),
		.addr_ready(spi_addr_rdy),
		
		.rw(spi_rw),
		
		.data_out(spi_data),
		.data_ready(spi_data_rdy),
		
		.data_in(spi_data_tx)
	);
	
	// Get rising PLL lock signal edge (so we can reset logic internally)
    reg [1:0] lock_r; always @(posedge ms_clk) lock_r <= {lock_r[0], pll_lock};
	wire lock_rising = lock_r[1:0] == 2'b01;
	
	// Sync RST and get edges
    reg [1:0] rst_r; always @(posedge ms_clk) rst_r <= {rst_r[0], rst};
    wire rst_rising = rst_r[1:0] == 2'b01;
    wire rst_falling = rst_r[1:0] == 2'b10;
	
	reg uls_r;
	reg uuls_r;
	
	// Clock dividers
	always @ (posedge ms_clk) begin
		if (global_rst) begin
			ls_clk <= 0;
			uls_clk <= 0;
			uuls_clk <= 0;
			uuuls_clk <= 0;
		end else begin
			uls_r <= uls_clk;
			uuls_r <= uuls_clk;
			
			ls_clk <= ~ls_clk;
			
			if (ls_clk)
				uls_clk <= ~uls_clk;
				
			if ({uls_r, uls_clk} == 2'b01)
				uuls_clk <= ~uuls_clk;
				
			if ({uuls_r, uuls_clk} == 2'b01)
				uuuls_clk <= ~uuuls_clk;
		end
	end
	
	// Detect fir done edge
    //reg fd_r; always @(posedge ls_clk) fd_r <= fir_done;
    //wire fd_rising = {fd_r, fir_done} == 2'b01;
	
	// Detect ADDR ready edge
    reg [3:0] addr_rdy_r; always @(posedge ms_clk) addr_rdy_r <= {addr_rdy_r[2:0], spi_addr_rdy};
    wire addr_rdy_rising = addr_rdy_r[1:0] == 2'b01;
    wire addr_rdy_falling = addr_rdy_r[1:0] == 2'b10;
    wire addr_rdy_rising_d = addr_rdy_r[2:1] == 2'b01; // 1 cyc delay
    wire addr_rdy_rising_dd = addr_rdy_r[3:2] == 2'b01; // 2 cyc delay
	
	// Detect DATA ready edge
    reg [2:0] data_rdy_r; always @(posedge ms_clk) data_rdy_r <= {data_rdy_r[1:0], spi_data_rdy};
    wire data_rdy_rising = data_rdy_r[1:0] == 2'b01;
    wire data_rdy_falling = data_rdy_r[1:0] == 2'b10;
    wire data_rdy_rising_d = data_rdy_r[2:1] == 2'b01; // 1 cyc delay
	
	// For testing
	reg [23:0] prev_data;
	reg test;
	
	// Registry handling	
	always @ (posedge ms_clk) begin
		// Reset signal handling
		if (rst_rising || lock_rising) begin
			global_rst <= 1;
			g_rst_c <= 0;
		end else begin
			if (g_rst_c == (rst_cycles - 1))
				global_rst <= 0;
		end
		
		if (global_rst) begin
			prev_data <= 24'b0;
			spi_data_tx <= 24'b0;
			test <= 0;
			g_rst_c <= g_rst_c + 1;
		end
		
		// Adress handling and data reading
		//if (rst_rising) begin end else // If RST got triggered, ignore this part of the logic
		if (addr_rdy_rising) begin
			//if (spi_addr == 7'b0000001) begin
			//	fir_rs_rdy <= 0;
			//	spi_data_tx <= fir_rs_ro;
			//end if (spi_addr[6:4] == 3'b100) begin
			//	fir_addr <= spi_addr[3:0];
			//	fir_coef_rdy <= 0;
			//end else
			if (spi_addr == 7'b1111111) begin
				spi_data_tx <= device_ID;
			end else
				spi_data_tx <= prev_data;
				//spi_data_tx <= 24'b0; // return 0s if no address
		end
		// Delayed readouts (special cases)
		/*if (addr_rdy_rising_dd) begin
			if (spi_addr[6:4] == 3'b100) begin
				spi_data_tx <= fir_coef_ro;
			end
		end*/
		
		// Writing data
		if (data_rdy_rising) begin
			test <= ~test;
			prev_data <= spi_data;
			/*if (spi_addr == 7'b0000000) begin
				//if (spi_data[0])
				//	global_rst <= 1;
				if (spi_data[1])
					fir_flush <= 1;
			end else if (spi_addr == 7'b0000001) begin
				fir_rs_rdy <= ~spi_rw; // If not ready it's in read mode - don't propagate in that case
				fir_shift <= spi_data;
			end else if (spi_addr[6:4] == 3'b100) begin
				fir_coef_rdy <= ~spi_rw; // If not ready it's in read mode - don't propagate in that case
				fir_coef <= spi_data;
			end*/
		end
		// Delayed signal resets (special cases)
		/*if (data_rdy_rising_d) begin
			if (spi_addr == 7'b0000000) begin
				if (spi_data[1])
					fir_flush <= 0;
			end else if (spi_addr == 7'b1111111) begin
				spi_data_tx <= 24'b0;
			end
		end*/
		
		//else if (fd_rising) begin
			// Add logic to pass data into IQ modulator
		//end
	end
	
	assign meas_done = test;
	// For now, use the 125 MHz/2 clock for the ADC part.
	assign adc_clk = ls_clk;
endmodule