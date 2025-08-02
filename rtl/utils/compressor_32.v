module compressor_32#(
    DATA_WIDTH = 32
)(
    input  [DATA_WIDTH - 1:0]       data0,
    input  [DATA_WIDTH - 1:0]       data1,
    input  [DATA_WIDTH - 1:0]       data2,
    output [DATA_WIDTH - 1:0]       sum,
    output [DATA_WIDTH    :0]       carry_o
);

assign sum = data0 ^ data1 ^ data2;

assign carry_o = {(((data0 ^ data1) & data2) | (data0 & data1)), 1'b0};

endmodule //compressor_32
