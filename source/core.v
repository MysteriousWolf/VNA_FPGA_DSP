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
	reg global_rst;
	reg [rst_cyc_cnt-1:0] g_rst_c;
	wire pll_lock;
	wire hs_clk; 		// 250 MHz - High speed clock
	wire ms_clk;		// 125 MHz - Medium speed clock (this can either be divided by 2 to get 62.5 MHz clock signal (for ADC), or we can simply route out the low speed clock)
	reg ls_clk; 		// 62.5 MHz - Low speed clock
	reg uls_clk;		// 31.25 MHz - Ultra low speed clock for scope to see
	
	// SPI Control
	wire [6:0]	spi_addr;		// 7 bit address
	wire 		spi_addr_rdy;
	wire 		spi_rw;			// 1 is read 0 is write
	wire [23:0]	spi_data;	// 24 bit data
	wire 		spi_data_rdy;
	reg [23:0]	spi_data_tx;	// 24 bit data - must be ready within 1 serial clock cycle
	
	// ADC RAM writing
	wire [max_meas_pnt_cnt:0] meas_cnt;
	wire meas_cnt_done = meas_cnt >= meas_points;
	
	reg [2*adc_width-1 : 0] adc_ab_reg;
	wire [2*adc_width-1 : 0] adc_ab = {adc_a, adc_b};
	reg conversion_clk;
	reg conversion_start;
	reg conversion_rst;
	
	reg delayed_conversion;
	
	// SPI RAM readout
	wire [2*adc_width-1 : 0] spi_ab;
	wire readout_clk = ls_clk;
	reg readout_start;
	reg readout_rst;
	
	reg spi_cnt_trig;
	
	// ADC RAM Counters
	reg adc_or_spi;
	wire count_clk = adc_or_spi ? ~adc_conv_clk : spi_cnt_trig;
	wire count_clk_en = (!meas_cnt_done && delayed_conversion) || readout_start;
	wire count_clr = global_rst || conversion_rst || readout_rst;
	
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
		.clk(uls_clk),
		
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
	
	adc_counter CNT(
		.clk_i(count_clk),
        .clk_en_i(count_clk_en),
        .aclr_i(count_clr),
        .q_o(meas_cnt)
	);
	
	raw_meas_ram RAM(
        .rst_i(global_rst),
		
		// Clock is always enabled
        .wr_clk_en_i(1'b1),
        .rd_clk_en_i(1'b1),
		
		.wr_clk_i(~adc_conv_clk),
        .wr_en_i((~meas_cnt_done) && (~conversion_start)),
        .wr_addr_i({{(12-max_meas_pnt_cnt){1'b0}}, meas_cnt[max_meas_pnt_cnt-1:0]}),
        .wr_data_i(adc_ab),
		
        .rd_clk_i(readout_clk),
        .rd_en_i(~meas_cnt_done && readout_start),
        .rd_addr_i({{(12-max_meas_pnt_cnt){1'b0}}, meas_cnt[max_meas_pnt_cnt-1:0]}),
        .rd_data_o(spi_ab)
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
	always @(posedge ms_clk) begin
		if (global_rst) begin
			addr_rdy_r <= 2'b00;
		end else begin
			addr_rdy_r <= {addr_rdy_r[0], spi_addr_rdy};
		end
	end
	
	// Detect DATA ready edge
    reg [1:0] data_rdy_r;
    wire data_rdy_rising = data_rdy_r[1:0] == 2'b01;
    wire data_rdy_falling = data_rdy_r[1:0] == 2'b10;
    reg data_rdy_rising_d, data_rdy_rising_dd; // 1 and 2 cyc delay
	always @(posedge ms_clk) begin
		if (global_rst) begin
			data_rdy_r <= 2'b00;
			data_rdy_rising_d <= 1'b0;
			data_rdy_rising_dd <= 1'b0;
		end else begin
			data_rdy_r <= {data_rdy_r[0], spi_data_rdy};
			data_rdy_rising_d <= data_rdy_rising;
			data_rdy_rising_dd <= data_rdy_rising_d;
		end
	end
	
	// Delay readout by 1 cycle (to make sure we are fully in sync)
	always @(negedge adc_conv_clk) begin
		if (global_rst || conversion_start) begin
			delayed_conversion <= 0;
		end else begin
			delayed_conversion <= 1;
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
			// Reset all registry
			spi_data_tx <= 24'b0;
			
			// RAM control registry
			adc_or_spi <= 1;
			
			conversion_rst <= 0;
			conversion_start <= 1;
			
			readout_rst <= 0;
			readout_start <= 0;
			spi_cnt_trig <= 0;
			
			// Increment extended reset counters
			g_rst_c <= g_rst_c + 1;
		end else begin
			/* SPI handling */
			// Adress handling and data reading (if RST got triggered, ignore this part of the logic)
			if (addr_rdy_rising) begin
				if (spi_addr == 7'b0000001) begin // General status
					spi_data_tx <= {23'b0, lock_r[0]};
				end else if (spi_addr == 7'b0000010) begin // Conversion control
					spi_data_tx <= {10'b0, conversion_start, meas_points};
					adc_or_spi <= 1;
					conversion_start <= 1;
				end else if (spi_addr == 7'b0000011) begin // Conversion status
					spi_data_tx <= {10'b0, meas_cnt_done, meas_cnt};
				end else if (spi_addr == 7'b0000100) begin // Readout
					if (readout_start) begin
						if (meas_cnt < meas_points) begin
							spi_data_tx <= spi_ab;
							
							// Increment index
							spi_cnt_trig <= 1;
						end
					end else begin
						spi_data_tx <= 24'b0;
					end
					adc_or_spi <= 0;
				end else if (spi_addr == 7'b0000101) begin // Readout status
					spi_data_tx <= {10'b0, ~readout_start, meas_cnt};
				end else // Default option (returns 0 when reading an invalid address)
					spi_data_tx <= 24'b0;
			end
			
			// Writing data
			if (data_rdy_rising) begin
				if (spi_rw) begin
					if (spi_addr == 7'b0000100) begin
						spi_cnt_trig <= 0;
						if (meas_cnt_done)
							readout_start <= 0;
					end 
				end else begin
					if (spi_addr == 7'b0000000) begin
						if (spi_data[0]) begin
							global_rst <= 1;
							g_rst_c <= 0;
						end
					end else if (spi_addr == 7'b0000010) begin
						if (spi_data[13]) begin
							conversion_start <= 0;
							conversion_rst <= 1;
						end
					end else if (spi_addr == 7'b0000100) begin
						if (spi_data[0]) begin
							conversion_start <= 1;
							readout_start <= 1;
							readout_rst <= 1;
						end
					end else if (spi_addr == 7'b0000101) begin
					end
				end
			end
			
			// Lower the conversion_start bit
			if (data_rdy_rising_d) begin
				if (spi_rw) begin end else begin
					if (~spi_rw && spi_addr == 7'b0000010) begin
						if (spi_data[13]) begin
							conversion_rst <= 0;
						end
					end else if (spi_addr == 7'b0000100) begin
						if (spi_data[0]) begin
							readout_rst <= 0;
						end
					end
				end
			end
		end
	end
	
	// Assign the conversion status pin
	assign meas_done = meas_cnt_done;
	
	// Use the B output /2 clock for the ADC conversion
	assign adc_clk = ls_clk;
endmodule