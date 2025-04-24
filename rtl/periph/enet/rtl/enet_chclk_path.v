module enet_chclk_path (
    input                           rst_n,

    input                           clk_i,

    input                           clk_sel,
    output                          clk_ena
);

wire                clk_sel_temp;
wire                clk_n = ~clk_i;
wire                rst_n_inner;
wire                rst_n_inner_n;
general_sync #(
    .DATA_LEN 	(1   ),
    .CHAIN_LV 	(2   ),
    .RST_DATA 	(0   ))
u_clk_async_rst_sync(
    .clk      	(clk_i          ),
    .rst_n    	(rst_n          ),
    .data_in  	(1'b1           ),
    .data_out 	(rst_n_inner    )
);
general_sync #(
    .DATA_LEN 	(1   ),
    .CHAIN_LV 	(2   ),
    .RST_DATA 	(0   ))
u_clk_n_async_rst_sync(
    .clk      	(clk_n          ),
    .rst_n    	(rst_n          ),
    .data_in  	(1'b1           ),
    .data_out 	(rst_n_inner_n  )
);
general_sync #(
    .DATA_LEN 	(1   ),
    .CHAIN_LV 	(2   ),
    .RST_DATA 	(0   ))
u_sel_sync(
    .clk      	(clk_i          ),
    .rst_n    	(rst_n_inner    ),
    .data_in  	(clk_sel        ),
    .data_out 	(clk_sel_temp   )
);
FF_D_without_wen #(
    .DATA_LEN 	(1   ),
    .RST_DATA 	(0   ))
u_FF_D_without_wen(
    .clk      	(clk_n           ),
    .rst_n    	(rst_n_inner_n   ),
    .data_in  	(clk_sel_temp    ),
    .data_out 	(clk_ena         )
);



endmodule //enet_chclk_path
