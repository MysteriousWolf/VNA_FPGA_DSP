module fifo 
#(
    parameter addr_width = 12,
    parameter data_width = 24,
    parameter max_data_count = (1<<addr_width)
)(
    input rst,

    input write_en,
    input wclk,
    input [data_width-1:0] din,

    input rclk,
    output [data_width-1:0] dout,
    
    output reg full,
    output reg empty,
    output reg direction // 0 is write, 1 is read
);
    /*
    After being reset, the FIFO should be empty and ready to accept data. The empty flag is high until we write data to the FIFO.
    The FIFO then takes in data and stores it in the RAM until it is full. When full, the full flag is high and the counter resets to be ready for readout.
    The readout process is similar to the write process, but the data is read out of the RAM and the empty flag is low until the FIFO is empty.
    */
    // Counter and states for the FIFO
	reg [addr_width-1:0] data_count;
    wire counter_clock = direction ? rclk : wclk;

    // Assert output flags (full when counter is at max and direction is write, empty when counter is at max and direction is read)
    // Max counter value is 2^addr_width
    wire overflow = data_count == (max_data_count - 1);
    wire underflow = data_count == 0;
    //wire overflow_warn = data_count >= (max_data_count-2);

    // RAM module for the FIFO
    ram #(
        .addr_width(addr_width),
        .data_width(data_width)
    ) ram_inst (
        .din(din),
        .write_en(write_en),
        .waddr(data_count),
        .wclk(wclk),
        .raddr(data_count),
        .rclk(rclk),
        .dout(dout)
    );

    // Count up until we reach the maximum address width based on the direction
    always @(negedge counter_clock or posedge rst) begin
        if (rst) begin
            full <= 0;
            empty <= 1;
            data_count <= 0;
            direction <= 0;
        end else begin
            if (!direction && write_en) begin
                full <= (direction && underflow) || (!direction && overflow);
                empty <= 0;
            end else if (direction) begin
                full <= 0;
                empty <= (direction && overflow) || (!direction && underflow);
            end

            if (overflow) begin
                direction <= ~direction;
                data_count <= 0;
            end else begin
                if (direction || (!direction && write_en)) begin
                    data_count <= data_count + 1;
                end
            end
        end
    end

endmodule

// 
module ram (din, write_en, waddr, wclk, raddr, rclk, dout); //4096x24 
    parameter addr_width = 12; 
    parameter data_width = 24; 
    input [addr_width-1:0] waddr, raddr; 
    input [data_width-1:0] din; 
    input write_en, wclk, rclk; 
    output reg [data_width-1:0] dout; 
    reg [data_width-1:0] mem [(1<<addr_width)-1:0]; 

    always @(posedge wclk) // Write memory. 
        begin if (write_en) 
            mem[waddr] <= din; // Using write address bus. 
        end 
    
    always @(posedge rclk) // Read memory. 
        begin 
            dout <= mem[raddr]; // Using read address bus. 
        end 
endmodule