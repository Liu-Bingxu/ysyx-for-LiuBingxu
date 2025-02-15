module sram#(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32,
    parameter MASK_WIDTH = 4
)(
    input                       clk,
    input                       cs,
    input                       we,
    input  [ADDR_WIDTH-1 : 0]   addr,    
    input  [DATA_WIDTH-1 : 0]   data_in,    
    input  [MASK_WIDTH-1 : 0]   mask,    
    output [DATA_WIDTH-1 : 0]   data_out    
);

localparam DP = 2 ** ADDR_WIDTH;

reg  [DATA_WIDTH-1 : 0] ram[0 : DP -1];
reg  [DATA_WIDTH-1 : 0] data_out_reg;

wire                    ren;
wire [MASK_WIDTH-1 : 0] wen;

assign ren = cs & (~we);
assign wen = {MASK_WIDTH{cs & we}} & mask;

always @(posedge clk ) begin
    if(ren)begin
        data_out_reg <= ram[addr];
    end
end

genvar i;
generate
    for(i = 0; i < MASK_WIDTH; i = i + 1)begin
        if(i * 8 + 8 > DATA_WIDTH)begin : last
            always @(posedge clk ) begin
                if(wen[i])begin
                    ram[addr][DATA_WIDTH - 1 : 8 * i] <= data_in[DATA_WIDTH - 1 : 8 * i];
                end
            end
        end
        else begin : not_last
            always @(posedge clk ) begin
                if(wen[i])begin
                    ram[addr][8 * i + 7 : 8 * i] <= data_in[8 * i + 7 : 8 * i];
                end
            end
        end
    end
endgenerate


assign data_out = data_out_reg;

endmodule //sram
