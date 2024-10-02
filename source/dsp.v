module iq_demodulator
#(
	parameter sig_width = 12
)
(
	// General signals
	input rst,        // Resets everything
	//input flush,      // Clears shift registers only
	input clk,        // Clock signal
	
	input [sig_width-1:0] in_a,				// Filtered input channel A
	input [sig_width-1:0] in_b,				// Filtered input channel B
	
	output reg [sig_width-1:0] out_amp,		// Filtered input channel A
	output reg [sig_width-1:0] out_phs,		// Filtered input channel B
	
	output reg test
);
	reg [sig_width:0] sum_reg;
	
	always @(posedge clk or posedge rst) begin
		if (rst) begin
			test <= 0;
		end else begin
			sum_reg <= ( {1'b0, in_a} + {1'b0, in_b} );
			test <= sum_reg[12];
		end
	end
endmodule

module fir_filt
#(
	parameter sig_width = 12,
	parameter reg_width = 32,
	parameter coef_width = 24,
	parameter coef_count = 16,
	localparam coef_id_w = $clog2(coef_count),
	parameter max_shift = 32,
	localparam max_shift_w = $clog2(max_shift),
	// How many stages per pipeline (more propagation delay)
	parameter stages = 4,
	localparam op_per_stage = coef_count/stages,
	localparam op_stage_res = coef_count - op_per_stage
)
(
	// General signals
	input rst,        // Resets everything
	input flush,      // Clears shift registers only
	input clk,        // Clock signal (4x faster than conversion clock)
	
	// Coefficient loading and management
	input [coef_id_w-1:0] addr,         // Coefficient address
	input [coef_width-1:0] coef,        // Coefficient value
	input coef_ready,                   // Coefficient ready signal
	output reg coef_done,               // Coefficient loading done signal
	output reg [coef_width-1:0] coef_r, // Coefficient value readout
	
	// Result shift management
	input result_shift_ready,						// Ready signal for result shift
	input [max_shift_w-1:0] result_shift_i,			// Shift amount for result
	output reg result_shift_done,					// Result shift done signal
	output reg [max_shift_w-1:0] result_shift,	// Readout for result shift
	
	// Data input (two ADC channels)
	input conv_done,								// Conversion done signal
	input [sig_width-1:0] adc_in_a,					// ADC input channel A
	input [sig_width-1:0] adc_in_b,					// ADC input channel B
	
	// Filtered outputs
	output reg [sig_width-1:0] filt_out_a,			// Filtered output A
	output reg [sig_width-1:0] filt_out_b,			// Filtered output B
	
	// Filtering done
	output reg filt_done = 0						// Signal that we are done
);
	// Internal signals and registers
	reg [coef_width-1:0] coeffs [0:coef_count-1];		// Coefficient memory
	reg [sig_width-1:0] shift_reg_a [0:coef_count-1];	// Shift register for input A
	reg [sig_width-1:0] shift_reg_b [0:coef_count-1];	// Shift register for input B
	reg [reg_width-1:0] mac_a [stages-1:0];							// MAC for channel A
	reg [reg_width-1:0] mac_b [stages-1:0];							// MAC for channel B

	// Sync conversion clock to the FPGA clock
	reg cc_r; always @(posedge clk) cc_r <= conv_done;
	wire cc_rising = {cc_r, conv_done} == 2'b01;
	
	// Coefficients
	integer i;
	always @(posedge clk) begin
		if (rst) begin
			// Reset coefficients
			coeffs[0] <= 1;  // Set the first coefficient to 1 (pass-through function)
			for (i = 1; i < coef_count; i = i + 1) coeffs[i] <= 0;  // Set the rest to 0
			coef_done <= 0;
		end else if (coef_ready) begin
			coeffs[addr] <= coef;
			coef_done <= 1;
		end else begin
			coef_r <= coeffs[addr];
			coef_done <= 0;
		end
	 end

	// Result shift
	always @(posedge clk) begin
		if (rst) begin
			result_shift <= 0;
			result_shift_done <= 0;
		end else if (result_shift_ready) begin
			result_shift <= result_shift_i;
			result_shift_done <= 1;
		end else begin
			result_shift_done <= 0;
		end
	end
	
	// Shift register
	integer j, k;
	always @(posedge clk) begin
		if (rst | flush) begin
			// Reset shift registers, and result shift
			for (j = 0; j < coef_count; j = j + 1) begin
				shift_reg_a[j] <= 0;
				shift_reg_b[j] <= 0;
			end
		end else if (cc_rising) begin
			// Shift new inputs into the shift registers
			for (k = coef_count-1; k > 0; k = k - 1) begin
				shift_reg_a[k] <= shift_reg_a[k-1];
				shift_reg_b[k] <= shift_reg_b[k-1];
			end
			shift_reg_a[0] <= adc_in_a;
			shift_reg_b[0] <= adc_in_b;
		end
	end
	
	// MAC
	integer l, m, stage;
	always @(posedge clk) begin
		if (rst | flush) begin
			// Reset shift registers, MAC accumulators, and result shift
			for (l = 0; l < stages; l = l + 1) begin
				mac_a[l] <= 0;
				mac_b[l] <= 0;
			end
		end else if (cc_rising) begin
			// Perform multiply-accumulate operation for both channels
			for (m = 0; m < coef_count; m = m + 1) begin
				stage = m / op_per_stage;
				mac_a[stage] <= mac_a[stage] + shift_reg_a[m] * coeffs[m];
				mac_b[stage] <= mac_b[stage] + shift_reg_b[m] * coeffs[m];
			end
		end
	end
	
	// Output shifting
	always @(posedge clk) begin
		if (rst | flush) begin
			filt_out_a <= 0;
			filt_out_b <= 0;
			filt_done <= 0;
		end else if (cc_rising) begin
			// Apply result shift or truncate
			if (result_shift != 0) begin
				filt_out_a <= mac_a[0] >> result_shift;
				filt_out_b <= mac_b[0] >> result_shift;
			end else begin
				filt_out_a <= mac_a[0][sig_width-1:0];
				filt_out_b <= mac_b[0][sig_width-1:0];
			end
			
			// Signal that we are done
			filt_done <= 1;
		end else begin
			filt_done <= 0;
		end
	end

endmodule
