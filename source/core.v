module dsp_core#(
	parameter adc_width = 12,
	parameter device_ID = 24'b111100001100110010101011 // test pattern by default, change to real ID in project settings
)
(
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
	output adc_clk,
	input adc_conv_clk,
	input [adc_width-1:0] adc_a,
	input [adc_width-1:0] adc_b
);
	
	// Wires and registry
	reg global_rst = 0;	// Global reset
	wire hs_clk; 		// 250 MHz - High speed clock
	wire ms_clk;		// 125 MHz - Medium speed clock (this can either be divided by 2 to get 62.5 MHz clock signal (for ADC), or we can simply route out the low speed clock)
	reg ls_clk = 0; 	// 62.5 MHz - Low speed clock
	//wire pll_lock;
	
	// PLL Wires
	//wire hs_clk_global; // 250 MHz
	//wire ms_clk_global; // 125 MHz
	
	// SPI Control
	wire [6:0]	spi_addr;		// 7 bit address
	wire 		spi_addr_rdy;
	wire 		spi_rw;			// 1 is read 0 is write
	wire [23:0]	spi_data;	// 24 bit data
	wire 		spi_data_rdy;
	reg [23:0]	spi_data_tx = 24'b0;	// 24 bit data - must be ready within 1 serial clock cycle
	
	// FIR signals
	reg			fir_flush = 0;
	
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
	wire [adc_width-1:0] phs_diff;
	
	/* Components */
	pll_core PLL(
		.ref_clk_i(sys_clk),
		.rst_n_i(global_rst),
		//.outcore_o(hs_clk),
		.outglobal_o(hs_clk),
		//.outcoreb_o(ms_clk),
		.outglobalb_o(ms_clk)
	);
		
	soft_spi_slave SPI(
		// Global signals
		.rst(global_rst), 
		.clk(hs_clk),
		
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
	
	fir_filt #(
		.sig_width(adc_width),
		.reg_width(32),
		.coef_width(24),
		.coef_count(16),
		.max_shift(32)
	) FIR (
		.rst(global_rst),
		.flush(fir_flush),
		.clk(hs_clk),
		
		.addr(fir_addr),
		.coef(fir_coef),
		.coef_ready(fir_coef_rdy),
		.coef_done(fir_coef_d),
		.coef_r(fir_coef_ro),
		
		.result_shift_i(fir_shift),
		.result_shift_ready(fir_rs_rdy),
		.result_shift_done(fir_rs_d),
		.result_shift(fir_rs_ro),
		
		.conv_done(adc_conv_clk),
		.adc_in_a(adc_a),
		.adc_in_b(adc_b),
		
		.filt_out_a(a_filt),
		.filt_out_b(b_filt),
		.filt_done(fir_done)
	);
	
	iq_demodulator #(
		.sig_width(adc_width)
	) IQ (
		.rst(global_rst),
		.clk(hs_clk),
		
		.in_a(a_filt),
		.in_b(b_filt),
		
		.out_amp(amp_diff),
		.out_phs(phs_diff),
		
		.test(meas_done) // TODO remove
	);

	// Clock divider
	always @ (posedge ms_clk) ls_clk <= ~ls_clk;
		
	// For now, use the 125 MHz/2 clock for the ADC part.
	assign adc_clk = ls_clk;
	
	// Sync RST and get edges
    reg [1:0] rst_r;
    always @(posedge hs_clk) 
        rst_r <= {rst_r[0], rst};
    
    wire rst_rising = (rst_r[1:0] == 2'b01);
    wire rst_falling = (rst_r[1:0] == 2'b10);
	
	// Detect fir done edge
    reg [1:0] fd_r;
    always @(posedge hs_clk) 
        fd_r <= {fd_r[0], fir_done};
    
    wire fd_rising = (fd_r[1:0] == 2'b01);
	
	// Detect ADDR ready edge
    reg [3:0] addr_rdy_r;
    always @(posedge hs_clk) 
        addr_rdy_r <= {addr_rdy_r[2:0], spi_addr_rdy};
    
    wire addr_rdy_rising = (addr_rdy_r[1:0] == 2'b01);
    wire addr_rdy_rising_d = (addr_rdy_r[2:1] == 2'b01); // delayed to let the address propagate
    wire addr_rdy_rising_dd = (addr_rdy_r[3:2] == 2'b01); // 2 cyc delayed to let the address propagate
    wire addr_rdy_falling = (addr_rdy_r[1:0] == 2'b10);
	
	// Detect DATA ready edge
    reg [2:0] data_rdy_r;
    always @(posedge hs_clk) 
        data_rdy_r <= {data_rdy_r[1:0], spi_data_rdy};
    
    wire data_rdy_rising = (data_rdy_r[1:0] == 2'b01);
    wire data_rdy_rising_d = (data_rdy_r[2:1] == 2'b01); // delayed data ready for settings that need to send a pulse
    wire data_rdy_falling = (data_rdy_r[1:0] == 2'b10);
	
	/*
	// FIR signals
	reg [4:0]	fir_shift = 0;
	reg			fir_rs_rdy = 0;
	wire		fir_rs_d;
	wire [4:0]	fir_rs_ro;
		
	wire [11:0]	a_filt;
	wire [11:0]	b_filt;
	
	wire fir_done;
	*/
	
	// Registry handling
	always @ (posedge hs_clk) begin
		// Reset signal handling
		if (rst_rising) begin
			global_rst <= 1;
		end else if (rst_falling) begin
			global_rst <= 0;
		end
		
		// Adress handling and data reading
		else if (addr_rdy_rising) begin
			if (spi_addr == 7'b0000001) begin
				fir_rs_rdy <= 0;
				spi_data_tx <= fir_rs_ro;
			end if (spi_addr[6:4] == 3'b100) begin
				fir_addr <= spi_addr[3:0];
				fir_coef_rdy <= 0;
			end else if (spi_addr == 7'b1111111) begin
				spi_data_tx <= device_ID;
			end else
				spi_data_tx <= 24'b0; // return 0s if no address
		end
		// Delayed readouts (special cases)
		if (addr_rdy_rising_dd) begin
			if (spi_addr[6:4] == 3'b100) begin
				spi_data_tx <= fir_coef_ro;
			end
		end
		
		// Writing data
		if (data_rdy_rising) begin
			if (spi_addr == 7'b0000000) begin
				if (spi_data[0])
					global_rst <= 1;
				if (spi_data[1])
					fir_flush <= 1;
			end else if (spi_addr == 7'b0000001) begin
				fir_rs_rdy <= ~spi_rw; // If not ready it's in read mode - don't propagate in that case
				fir_shift <= spi_data;
			end else if (spi_addr[6:4] == 3'b100) begin
				fir_coef_rdy <= ~spi_rw; // If not ready it's in read mode - don't propagate in that case
				fir_coef <= spi_data;
			end
		end
		// Delayed signal resets (special cases)
		if (data_rdy_rising_d) begin
			if (spi_addr == 7'b0000000) begin
				if (spi_data[1])
					fir_flush <= 0;
			end else if (spi_addr == 7'b1111111) begin
				spi_data_tx <= 24'b0;
			end
		end
		// Falling edge resets
		if (data_rdy_falling) begin
			if (global_rst)
				global_rst <= 0; // reset global reset back to 0
		end
		
		else if (fd_rising) begin
			// Add logic to pass data into IQ modulator
		end
	end
endmodule