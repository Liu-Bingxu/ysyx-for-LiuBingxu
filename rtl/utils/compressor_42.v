module compressor_42#(
    DATA_WIDTH = 32
)(
    input  [DATA_WIDTH - 1:0]       data0,
    input  [DATA_WIDTH - 1:0]       data1,
    input  [DATA_WIDTH - 1:0]       data2,
    input  [DATA_WIDTH - 1:0]       data3,
    output [DATA_WIDTH - 1:0]       sum,
    output [DATA_WIDTH    :0]       carry_o
);

wire [DATA_WIDTH - 2:0] carry_inter;

wire [DATA_WIDTH - 1:0] carry_temp;

assign carry_inter = (((data0[DATA_WIDTH - 2:0] ^ data1[DATA_WIDTH - 2:0]) & data2[DATA_WIDTH - 2:0]) | (data0[DATA_WIDTH - 2:0] & data1[DATA_WIDTH - 2:0]));

assign carry_temp = data0 ^ data1 ^ data2;

assign sum = carry_temp ^ data3 ^ {carry_inter, 1'b0};

assign carry_o = {(((carry_temp ^ data3) & {carry_inter, 1'b0}) | (carry_temp & data3)), 1'b0};

endmodule //compressor_42
