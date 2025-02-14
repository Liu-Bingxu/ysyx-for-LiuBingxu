module general_sync #(
    parameter DATA_LEN = 64,
    parameter CHAIN_LV = 2,
	parameter RST_DATA = 0
) (
    input                       clk,
    input                       rst_n,
    input  [DATA_LEN - 1 : 0]   data_in,
    output [DATA_LEN - 1 : 0]   data_out
);

wire [DATA_LEN - 1 : 0]   data [CHAIN_LV : 0];

genvar i;
generate for(i = 0 ; i < CHAIN_LV; i = i + 1) begin : sync_chain
	FF_D_without_wen #(
        .DATA_LEN 	( DATA_LEN  	),
        .RST_DATA 	( RST_DATA   	)
	)u_sync_ff(
        .clk      	( clk       	),
        .rst_n    	( rst_n     	),
        .data_in  	( data[i]   	),
        .data_out 	( data[i + 1]  	)
    );
end
endgenerate

assign data[0]  = data_in;
assign data_out = data[CHAIN_LV];

endmodule //general_sync
