module mrom#(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32
)(
    input                       clk,
    input                       cs,
    input  [ADDR_WIDTH-1 : 0]   addr,
    input  [DATA_WIDTH-1 : 0]   data_in,
    output [DATA_WIDTH-1 : 0]   data_out
);

endmodule //mrom
