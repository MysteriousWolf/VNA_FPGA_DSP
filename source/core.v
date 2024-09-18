module dsp_core (sys_clk, rst, so, si, sck, scs, meas_done, adc_clk, adc_conv_clk, adc_a, adc_b);
	// main clock
	input sys_clk;
	input rst;
	
	// SPI for data output
    inout sck;
    input scs;
    inout so;
    inout si;
	
	// Current measurement/calculation done
	output meas_done;
	
	// ADC inputs
	output adc_clk;
	input adc_conv_clk;
	input [11:0] adc_a;
	input [11:0] adc_b;
	
	// Global wires
	wire global_rst; 	// Global reset wire
	wire ls_clk; 		// 40  MHz - Low speed clock 
	wire ms_clk;		// 125 MHz - Medium speed clock (this can either be divided by 2 to get 62.5 MHz clock signal (for ADC), or we can simply route out the low speed clock)
	wire hs_clk; 		// 250 MHz - High speed clock
	wire pll_lock;
	
	
	// PLL Wires
	wire ms_clk_global; // 125 MHz
	wire hs_clk_global; // 250 MHz
	
	// SPI Wires
	wire so_w;
	wire si_w;
	wire sck_w;
	wire scs_w;
	
    wire [3:0] spi1_mcs_n_o;
    wire rst_i;
    wire ipload_i;
    wire ipdone_o;
    wire sb_wr_i;
    wire sb_stb_i;
    wire [7:0] sb_adr_i;
    wire [7:0] sb_dat_i;
    wire [7:0] sb_dat_o;
    wire sb_ack_o;
    wire [1:0] spi_pirq_o;
    wire [1:0] spi_pwkup_o;
	
	pll_core PLL(ls_clk, global_rst, pll_lock, hs_clk, hs_clk_global, ms_clk, ms_clk_global);
	
	spi_peripheral SPI(so_w, si_w, sck_w, scs_w, spi1_mcs_n_o, 
        rst_i, 
        ipload_i, 
        ipdone_o, 
        ls_clk, 
        sb_wr_i, 
        sb_stb_i, 
        sb_adr_i, 
        sb_dat_i, 
        sb_dat_o, 
        sb_ack_o, 
        spi_pirq_o, 
        spi_pwkup_o);
		
	// Connecting wires with pins
	assign so_w = so;
	assign si_w = si;
	assign sck_w = sck;
	assign scs_w = scs;
	
	assign ls_clk = sys_clk;
	assign ls_clk = adc_clk; // For now, use the 40 MHz clock for the ADC part.
endmodule