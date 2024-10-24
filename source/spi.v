/** Format: [R/W bit, addr, msg] **/
module soft_spi_slave
#(
	parameter msg_width = 32,
	parameter addr_width = 7,
	localparam rw_bit = 1,
	localparam meta_width = rw_bit + addr_width,
	localparam data_width = msg_width - meta_width,
	localparam counter_width = $clog2(msg_width),
	localparam data_counter_width = $clog2(data_width)
)
(
	// General signals
	input rst,
	input clk, 								// Should be at least 4x faster than SCK
	
	// SPI MCU connections
	input 		sck,
	input		ncs,
	output reg	so,
	input 		si,
	
	// SPI Control
	output reg [addr_width-1:0]	addr,
	output reg					addr_ready,
	output reg					rw,				// 1 is read 0 is write
	output reg [data_width-1:0]	data_out,
	output reg					data_ready,
	input      [data_width-1:0]	data_in 		// Must be ready within 1 serial clock cycle
);
	// Wires
	wire spi_rst = rst || ncs;

	// Counters
	wire [counter_width-1:0] data_count;
	reg rw_ready;
	spi_counter SPI_CNT(
		.clk_i(~sck),
        .clk_en_i(~ncs),
        .aclr_i(spi_rst || ~rw_ready),
        .q_o(data_count)
	);
	
	// Data shift reg (needs 1 less bit due to how last bit is handled to reduce output latency and allow consecutive packets)
	reg [data_width-2:0] data_reg;
	
	// Sync SCK to the FPGA clock using a 3-bit shift register
	reg [1:0] sck_r; always @(posedge clk) sck_r <= {sck_r[0], sck};
	wire sck_risingedge = sck_r == 2'b01;
	wire sck_fallingedge = sck_r == 2'b10;
	
	// Incoming data shift reg
	always @ (posedge clk) begin
		if (spi_rst) begin
			// Reset registers
			data_reg <= 0;
		end else begin
			if(sck_risingedge) begin
				// Shifting into the data register
				data_reg <= {data_reg[data_width-3:0], si};
			end else if (sck_fallingedge && data_ready) begin
				// Counter overflow, prepare for another data packet
				// Reset registers
				data_reg <= 0;
			end
		end
	end
	
	// Address handling
	always @ (posedge clk) begin
		if (spi_rst) begin
			// Reset outputs
			rw <= 0;
			// Reset signals
			rw_ready <= 0;
			addr_ready <= 0;
			// Reset registers
			addr <= 0;
		end else begin
			if(sck_risingedge) begin
				// Check the R/W bit
				if (data_count == 0) begin
					rw <= si;
					rw_ready <= 1;
				end
				
				// Check when the address portion is fully received and move it to the output
				if (data_count == (addr_width + rw_bit) - 1) begin
					addr <= {data_reg[addr_width-2:0], si};
					addr_ready <= 1;
				end
			end else if (sck_fallingedge && data_ready) begin
				// Counter overflow, prepare for another data packet
				// Reset outputs
				rw <= 0;
				// Reset signals
				rw_ready <= 0;
				addr_ready <= 0;
				// Reset registers
				addr <= 0;
			end
		end
	end
	
	// Data handling
	always @ (posedge clk) begin
		if (spi_rst) begin
			// Reset signals
			data_ready <= 0;
			// Reset registers
			data_out <= 0;
		end else begin
			if(sck_risingedge) begin
				// Check when the entire message is received
				if (data_count == (msg_width) - 1) begin
					data_out <= {data_reg[data_width-2:0], si};
					data_ready <= 1;
				end
			end else if (sck_fallingedge && data_ready) begin
				// Counter overflow, prepare for another data packet
				// Reset signals
				data_ready <= 0;
				// Reset registers
				data_out <= 0;
			end
		end
	end

	// Data out handling
	always @ (posedge clk) begin
		if (spi_rst) begin
			// Reset outputs
			so <= 0;
		end else begin
			if (sck_fallingedge) begin
				// Counter overflow, prepare for another data packet
				if (data_ready) begin
					// Reset outputs
					so <= 0;
				end else if (addr_ready) begin
					// Shift out the outgoing data
					if (data_count < msg_width) begin
						so <= data_in[msg_width - (data_count + 1)];
					end
				end
			end
		end
	end
endmodule