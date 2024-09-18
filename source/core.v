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
	
	wire so_w;
	wire si_w;
	wire sck_w;
	wire scs_w;
	
    wire [3:0] spi1_mcs_n_o;
    wire rst_i;
    wire ipload_i;
    wire ipdone_o;
    wire sb_clk_i;
    wire sb_wr_i;
    wire sb_stb_i;
    wire [7:0] sb_adr_i;
    wire [7:0] sb_dat_i;
    wire [7:0] sb_dat_o;
    wire sb_ack_o;
    wire [1:0] spi_pirq_o;
    wire [1:0] spi_pwkup_o;
	
	spi_peripheral SPI(miso_w, mosi_w, sck_w, scs_w, spi1_mcs_n_o, 
        rst_i, 
        ipload_i, 
        ipdone_o, 
        sb_clk_i, 
        sb_wr_i, 
        sb_stb_i, 
        sb_adr_i, 
        sb_dat_i, 
        sb_dat_o, 
        sb_ack_o, 
        spi_pirq_o, 
        spi_pwkup_o);
endmodule