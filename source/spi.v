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
	
	// SPI MCU connections
	input 		sck,
	input		ncs,
	output reg	so,
	input 		si,
	
	// SPI Control
	output reg [addr_width-1:0]	addr,
	output reg					addr_ready,
	output reg					rw,				// 1 is read 0 is write
	output reg					rw_ready,
	output reg [data_width-1:0]	data_out,
	output reg					data_ready,
	input      [data_width-1:0]	data_in 		// Must be ready within 1 serial clock cycle
);
	// Wires
	wire spi_rst = rst || ncs;

	// Counters
	wire [counter_width-1:0] data_count;
	spi_counter SPI_CNT(
		.clk_i(~sck),
        .clk_en_i(~ncs),
        .aclr_i(spi_rst),
        .q_o(data_count)
	);
	
	// Data shift reg (needs 1 less bit due to how last bit is handled to reduce output latency and allow consecutive packets)
	reg [data_width-2:0] data_reg;

	// condition flags
	wire rw_ready_c = data_count == 0;
	wire addr_ready_c = data_count == (addr_width + rw_bit) - 1;
	wire data_ready_c = data_count == (msg_width) - 1;
	
	// Incoming data shift reg
	always @ (posedge sck or posedge spi_rst) begin
		if (spi_rst) begin
			// Reset outputs
			rw <= 0;
			rw_ready <= 0;
			addr_ready <= 0;
			data_ready <= 0;
			// Reset registers
			data_reg <= 0;
			addr <= 0;
			data_out <= 0;
		end else begin
			// Shifting into the data register
			data_reg <= {data_reg[data_width-3:0], si};

			// Check the R/W bit
			if (rw_ready_c) begin
				rw <= si;
				rw_ready <= 1;
			end else if (data_ready_c) begin
				rw <= 0;
				rw_ready <= 0;
			end
			
			// Check when the address portion is fully received and move it to the output
			if (addr_ready_c) begin
				addr <= {data_reg[addr_width-2:0], si};
				addr_ready <= 1;
			end else if (data_ready_c) begin
				addr <= 0;
				addr_ready <= 0;
			end

			// Check when the entire message is received
			if (data_ready_c) begin
				data_out <= {data_reg[data_width-2:0], si};
				data_ready <= 1;
			end else if (rw_ready_c) begin
				data_out <= 0;
				data_ready <= 0;
			end
		end
	end

	// Data out handling
	always @ (negedge sck or posedge spi_rst) begin
		if (spi_rst) begin
			// Reset outputs
			so <= 0;
		end else begin
			// Counter overflow, prepare for another data packet
			if (addr_ready && (data_count < (msg_width - 1))) begin
				// Shift out the outgoing data
				so <= data_in[msg_width - (data_count + 2)];
			end else begin
				so <= 0;
			end
		end
	end
endmodule