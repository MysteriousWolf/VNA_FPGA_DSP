module dsp_core
#(
	parameter adc_width = 12,
	parameter device_ID = 24'b111100001100110010101011, // test pattern by default, change to real ID in project settings
	parameter rst_cycles = 4,
	parameter max_meas_points = 4096,
	localparam rst_cyc_cnt = $clog2(rst_cycles),
	localparam max_meas_pnt_cnt = $clog2(max_meas_points)
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
	output adc_clk,
	input adc_conv_clk,
	input [adc_width-1:0] adc_a,
	input [adc_width-1:0] adc_b
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
	//reg uuls_clk;		// 15.625 MHz
	//reg uuuls_clk;		// 7.8125 MHz
	
	// SPI Control
	wire [6:0]	spi_addr;		// 7 bit address
	wire 		spi_addr_rdy;
	wire 		spi_rw;			// 1 is read 0 is write
	wire [23:0]	spi_data;	// 24 bit data
	wire 		spi_data_rdy;
	reg [23:0]	spi_data_tx;	// 24 bit data - must be ready within 1 serial clock cycle
	
	// Measurement memmory control
	reg [max_meas_pnt_cnt:0] max_meas_cnt_adc;
	
	reg [2*adc_width-1 : 0] adc_ab_reg;
	wire [2*adc_width-1 : 0] adc_ab = {adc_a, adc_b};
	reg conversion_clk;
	reg conversion_start;
	reg [max_meas_pnt_cnt:0] meas_cnt_adc;
	wire conversion_done = meas_cnt_adc >= max_meas_cnt_adc;
	//wire conversion_done = meas_cnt_adc >= max_meas_points;
	
	
	wire [2*adc_width-1 : 0] spi_ab;
	wire readout_clk = ls_clk;
	reg readout_start;
	reg [max_meas_pnt_cnt:0] meas_cnt_spi;
	
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
	
	raw_meas_ram RAM(
        .rst_i(global_rst),
		
		// Clock is always enabled
        .wr_clk_en_i(1'b1),
        .rd_clk_en_i(1'b1),
		
		.wr_clk_i(~adc_conv_clk),
        .wr_en_i(conversion_start),
        .wr_addr_i(meas_cnt_adc[max_meas_pnt_cnt-1:0]),
        .wr_data_i(adc_ab),
		
        .rd_clk_i(readout_clk),
        .rd_en_i(readout_start),
        .rd_addr_i(meas_cnt_spi[max_meas_pnt_cnt-1:0]),
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
	//reg addr_rdy_rising_d, addr_rdy_rising_dd; // 1 and 2 cyc delay
	always @(posedge ms_clk) begin
		if (global_rst) begin
			addr_rdy_r <= 2'b00;
			/*addr_rdy_rising_d <= 1'b0;
			addr_rdy_rising_dd <= 1'b0;*/
		end else begin
			addr_rdy_r <= {addr_rdy_r[0], spi_addr_rdy};
			/*addr_rdy_rising_d <= addr_rdy_rising;
			addr_rdy_rising_dd <= addr_rdy_rising_d;*/
		end
	end
	
	// Detect DATA ready edge
    reg [1:0] data_rdy_r;
    wire data_rdy_rising = data_rdy_r[1:0] == 2'b01;
    wire data_rdy_falling = data_rdy_r[1:0] == 2'b10;
    reg data_rdy_rising_d, data_rdy_rising_dd, data_rdy_rising_ddd; // 1, 2, and 3 cyc delay
	always @(posedge ms_clk) begin
		if (global_rst) begin
			data_rdy_r <= 2'b00;
			data_rdy_rising_d <= 1'b0;
			data_rdy_rising_dd <= 1'b0;
			data_rdy_rising_ddd <= 1'b0;
		end else begin
			data_rdy_r <= {data_rdy_r[0], spi_data_rdy};
			data_rdy_rising_d <= addr_rdy_rising;
			data_rdy_rising_dd <= data_rdy_rising_d;
			data_rdy_rising_ddd <= data_rdy_rising_dd;
		end
	end
	
	// Temporarly store measured data
	/*always @(posedge adc_conv_clk) begin
		if (global_rst)
			adc_ab_reg <= 24'b0;
		else
			adc_ab_reg <= adc_ab;
	end*/
	
	// Detect conversion clock edges
    reg [1:0] conv_clk_r;
    wire conv_clk_rising = conv_clk_r[1:0] == 2'b01;
    wire conv_clk_falling = conv_clk_r[1:0] == 2'b10;
	always @(posedge ms_clk) begin
		if (global_rst) begin
			conv_clk_r <= 2'b00;
		end else begin
			conv_clk_r <= {conv_clk_r[0], adc_conv_clk};
		end
	end
	
	/*
	reg conversion_start;
	reg [max_meas_pnt_cnt-1:0] meas_cnt_adc;
	
	wire [2*adc_width-1 : 0] spi_ab;
	reg readout_clk;
	reg readout_start;
	reg [max_meas_pnt_cnt-1:0] meas_cnt_spi;
	*/
	
	reg [23:0] prev_spi_data;
	
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
			// Test registry
			prev_spi_data <= 24'b0;
			
			// Reset all registry
			spi_data_tx <= 24'b0;
			
			// RAM control registry
			conversion_start <= 0;
			max_meas_cnt_adc <= max_meas_points;
			conversion_clk <= 0;
			meas_cnt_adc <= 0;
			
			//readout_clk <= 0;
			readout_start <= 0;
			meas_cnt_spi <= 0;
			
			// Increment extended reset counters
			g_rst_c <= g_rst_c + 1;
		end else begin
			// ADC -> RAM readout
			if (conversion_start && ~conversion_done) begin
				if (conv_clk_rising) begin
					conversion_clk <= 1;
				end else if (conv_clk_falling) begin
					conversion_clk <= 0;
					meas_cnt_adc <= meas_cnt_adc + 1;
				end
			end
		
			/* SPI handling */
			// Adress handling and data reading (if RST got triggered, ignore this part of the logic)
			if (addr_rdy_rising) begin
				if (spi_addr == 7'b0000001) begin // General status
					spi_data_tx <= {23'b0, lock_r[0]};
				end else if (spi_addr == 7'b0000010) begin // Conversion control
					spi_data_tx <= {10'b0, conversion_start, max_meas_cnt_adc};
					//spi_data_tx <= {10'b0, conversion_start, max_meas_points};
				end else if (spi_addr == 7'b0000011) begin // Conversion status
					spi_data_tx <= {10'b0, conversion_done, meas_cnt_adc};
				end else if (spi_addr == 7'b0000100) begin // Readout
					if (readout_start) begin
						if (meas_cnt_spi < max_meas_cnt_adc) begin
						//if (meas_cnt_spi < max_meas_points) begin
							spi_data_tx <= spi_ab;
							
							// Increment index
							meas_cnt_spi <= meas_cnt_spi + 1;
						end else
							readout_start <= 0;
					end else begin
						spi_data_tx <= 24'b0;
					end
				end else if (spi_addr == 7'b0000101) begin // Readout status
					spi_data_tx <= {10'b0, ~readout_start, meas_cnt_spi};
				end else if (spi_addr == 7'b0111110) begin // Previous readback (debug option)
					spi_data_tx <= prev_spi_data;
				end else if (spi_addr == 7'b0111111) begin // Device ID
					spi_data_tx <= device_ID;
				end else // Default option (returns 0 when reading an invalid address)
					spi_data_tx <= 24'b0;
			end
			// Delayed read actions (special cases like delayed clocks)
			/*if (addr_rdy_rising_d)
				if (spi_addr == 7'b0000100)
					if (readout_start)
						readout_clk <= 0;*/
			
			// Writing data
			if (data_rdy_rising) begin
				prev_spi_data <= spi_data;
				if (spi_rw) begin
					/*if (spi_addr == 7'b0000100) begin
						if (readout_start)
							readout_clk <= 1;
					end*/
				end else begin
					if (spi_addr == 7'b0000000) begin
						if (spi_data[0]) begin
							global_rst <= 1;
							g_rst_c <= 0;
						end
					end else if (spi_addr == 7'b0000010) begin
						if (spi_data[12:0] > 0 && spi_data[12:0] < max_meas_points)
							max_meas_cnt_adc <= spi_data[12:0];
						else
							max_meas_cnt_adc <= max_meas_points;
							
						if (spi_data[13]) begin
							meas_cnt_adc <= 0;
							conversion_start <= 1;
						end
					end else if (spi_addr == 7'b0000100) begin
						if (spi_data[0]) begin
							meas_cnt_spi <= 0;
							readout_start <= 1;
						end
					end else if (spi_addr == 7'b0000101) begin
						meas_cnt_spi <= spi_data[12:0];
					end
				end
			end
			
			// After SPI is done, read the next sample (2 clock cycles just in case)
			/*if (data_rdy_rising_d) begin
				readout_clk <= 0;
			end else if (data_rdy_rising_dd) begin
				readout_clk <= 1;
			end else if (data_rdy_rising_ddd) begin
				readout_clk <= 0;
			end*/
		end
	end
	
	//assign meas_done = spi_rw;
	assign meas_done = lock_r[0];
	// For now, use the 125 MHz/2 clock for the ADC part.
	assign adc_clk = ls_clk;
endmodule