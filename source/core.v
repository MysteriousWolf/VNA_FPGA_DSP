module dsp_core
#(
	parameter adc_width = 12,
	parameter device_ID = 24'b111100001100110010101011, // test pattern by default, change to real ID in project settings (F0CCAB)
	parameter rst_cycles = 4,
	parameter meas_points = 4096,
	localparam max_meas_points = 4096,
	localparam rst_cyc_cnt = $clog2(rst_cycles),
	localparam max_meas_pnt_cnt = $clog2(max_meas_points)
)
(
	// For testing (comment out PLL and same name signals)
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
	output adc_clk,
	input adc_conv_clk,
	input [adc_width-1:0] adc_a,
	input [adc_width-1:0] adc_b
);
	// Wires and registry
	reg global_rst, spi_rst;
	reg [rst_cyc_cnt-1:0] g_rst_c;
	wire pll_lock;
	wire hs_clk; 		// 250 MHz - High speed clock
	wire ms_clk;		// 125 MHz - Medium speed clock (this can either be divided by 2 to get 62.5 MHz clock signal (for ADC), or we can simply route out the low speed clock)
	reg ls_clk; 		// 62.5 MHz - Low speed clock
	reg uls_clk;		// 31.25 MHz - Ultra low speed clock for scope to see
	
	// SPI Sync
	reg sck_r, sck_rr;
	always @ (posedge uls_clk) begin
		sck_r <= sck;
		sck_rr <= sck_r;
	end
    reg ncs_r, ncs_rr;
	always @ (posedge uls_clk) begin
		ncs_r <= ncs;
		ncs_rr <= ncs_r;
	end
    reg si_r, si_rr;
	always @ (posedge uls_clk) begin
		si_r <= si;
		si_rr <= si_r;
	end
	always @ (posedge uls_clk) begin
		spi_rst <= global_rst;
	end
	
	// SPI Control
	wire [6:0]	spi_addr;		// 7 bit address
	wire 		spi_addr_rdy;
	wire 		spi_rw;			// 1 is read 0 is write
	wire [23:0]	spi_data;	// 24 bit data
	wire 		spi_data_rdy;
	reg [23:0]	spi_data_tx;	// 24 bit data - must be ready within 1 serial clock cycle
	
	// ADC FIFO Data Signals
	wire [2*adc_width-1 : 0] adc_ab = {adc_a, adc_b};
	wire [2*adc_width-1 : 0] spi_ab;
	
	// FIFO Control Signals
	reg fifo_clear;
	reg fifo_wr_en, fifo_rd_en;
	wire fifo_full, fifo_empty;
	wire busy = fifo_wr_en | fifo_rd_en;
	wire ram_clock = fifo_wr_en ? (~adc_conv_clk) : spi_rw;
	
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
		.rst(spi_rst),
		.clk(uls_clk),
		
		// SPI interface
		.sck(sck_rr),
		.ncs(ncs_rr),
		.so(so),
		.si(si_rr),
		
		// Internal signals
		.addr(spi_addr),
		.addr_ready(spi_addr_rdy),
		
		.rw(spi_rw),
		
		.data_out(spi_data),
		.data_ready(spi_data_rdy),
		
		.data_in(spi_ab)
	);
	
	/*meas_fifo MEAS_FIFO(
        .rst_i(global_rst || fifo_clear),
        .rp_rst_i(1'b0), // For retransmission - no need to use right now
		
		.wr_clk_i(~adc_conv_clk),
        .wr_en_i(fifo_wr_en),
        .wr_data_i(adc_ab),
		
        .rd_clk_i(spi_rw),
        .rd_en_i(fifo_rd_en),
        .rd_data_o(spi_ab),
		
        .full_o(fifo_full),
        .empty_o(fifo_empty)
	);*/
	
	meas_fifo_sc MEAS_FIFO(
		.clk_i(ram_clock),
		.rst_i(global_rst || fifo_clear),
		
		.wr_en_i(fifo_wr_en),
		.wr_data_i(adc_ab),
		
		.rd_en_i(fifo_rd_en),
		.rd_data_o(spi_ab),
		
		.full_o(fifo_full),
		.empty_o(fifo_empty)
	);
	
	// Get rising PLL lock signal edge (so we can reset logic internally)
    reg [1:0] lock_r; always @(posedge ms_clk) lock_r <= {lock_r[0], pll_lock};
	wire lock_rising = lock_r[1:0] == 2'b01;
	
	// Sync RST and get edges
    reg [1:0] rst_r; always @(posedge ms_clk) rst_r <= {rst_r[0], rst};
    wire rst_rising = rst_r[1:0] == 2'b01;
    wire rst_falling = rst_r[1:0] == 2'b10;
	
	// Clock dividers
	always @ (posedge ms_clk) begin
		if (global_rst) begin
			ls_clk <= 0;
			uls_clk <= 0;
		end else begin
			ls_clk <= ~ls_clk;
			
			if (ls_clk)
				uls_clk <= ~uls_clk;
		end
	end
	
	// Detect ADDR ready edge
    reg [1:0] addr_rdy_r;
    wire addr_rdy_rising = addr_rdy_r[1:0] == 2'b01;
    wire addr_rdy_falling = addr_rdy_r[1:0] == 2'b10;
    reg addr_rdy_rising_d;
	always @(posedge ms_clk) begin
		if (global_rst) begin
			addr_rdy_r <= 2'b00;
			addr_rdy_rising_d <= 0;
		end else begin
			addr_rdy_r <= {addr_rdy_r[0], spi_addr_rdy};
			addr_rdy_rising_d <= addr_rdy_rising;
		end
	end
	
	always @ (posedge uls_clk) begin
		if (global_rst) begin
			// Reset data registry
			spi_data_tx <= 24'b0;
		end begin
			// Always assert the SPI out data to reduce potential latency
			spi_data_tx <= spi_ab;
		end
	end
	
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
			// RAM control registry
			fifo_clear <= 0;
			fifo_wr_en <= 0;
			fifo_rd_en <= 0;
			
			// Increment extended reset counters
			g_rst_c <= g_rst_c + 1;
		end else begin
			/* SPI handling */
			
			if (addr_rdy_rising) begin
				if (spi_rw) begin
					fifo_wr_en <= 0;
					fifo_rd_en <= 1;
				end else begin
					fifo_clear <= 1;
					fifo_rd_en <= 0;
					fifo_wr_en <= 1;
				end
			end
			if (addr_rdy_rising_d) begin
				if (!spi_rw) begin
					fifo_clear <= 0;
				end
			end
			
			if (fifo_full) fifo_wr_en <= 0;
			if (fifo_empty) fifo_rd_en <= 0;
		end
	end
	
	// This output is used as a "busy" signal
	assign meas_done = busy;
	//assign meas_done = fifo_empty;
	
	// Use the B output /2 clock for the ADC conversion
	assign adc_clk = ls_clk;
endmodule