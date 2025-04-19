module cdc_handle#(
    parameter DATA_W = 64
)(
    input                   clk_in,
    input                   rst_n_in,

    input                   req_in,
    output                  rdy_in,
    input  [DATA_W -1:0]    data_in,

    input                   clk_out,
    input                   rst_n_out,

    output                  req_out,
    input                   rdy_out,
    output [DATA_W -1:0]    data_out
);

wire [DATA_W -1:0]    data_in_r;
wire data_in_wen;

wire [DATA_W -1:0]    data_out_r;
wire data_out_wen;

wire rdy_in_set;
wire rdy_in_clr;
wire rdy_in_wen;
wire rdy_in_nxt;

wire cdc_req;
wire cdc_req_sync;
wire cdc_req_sync_r;
wire cdc_req_sync_neg;
wire cdc_req_set;
wire cdc_req_clr;
wire cdc_req_wen;
wire cdc_req_nxt;

wire cdc_rdy;
wire cdc_rdy_sync;
wire cdc_rdy_sync_r;
wire cdc_rdy_sync_neg;
wire cdc_rdy_set;
wire cdc_rdy_clr;
wire cdc_rdy_wen;
wire cdc_rdy_nxt;

wire req_out_set;
wire req_out_clr;
wire req_out_wen;
wire req_out_nxt;

assign data_in_wen = req_in & rdy_in;
FF_D_with_wen #(
    .DATA_LEN 	(DATA_W ),
    .RST_DATA 	(0      ))
u_data_in_r(
    .clk      	(clk_in             ),
    .rst_n    	(rst_n_in           ),
    .wen      	(data_in_wen        ),
    .data_in  	(data_in            ),
    .data_out 	(data_in_r          )
);

assign data_out_wen = cdc_req_sync & cdc_rdy;
FF_D_with_wen #(
    .DATA_LEN 	(DATA_W ),
    .RST_DATA 	(0      ))
u_data_out_r(
    .clk      	(clk_out            ),
    .rst_n    	(rst_n_out          ),
    .wen      	(data_out_wen       ),
    .data_in  	(data_in_r          ),
    .data_out 	(data_out_r         )
);
assign data_out = data_out_r;

assign rdy_in_set = cdc_rdy_sync_neg;
assign rdy_in_clr = req_in & rdy_in;
assign rdy_in_wen = (rdy_in_set | rdy_in_clr);
assign rdy_in_nxt = (rdy_in_set | (!rdy_in_clr));
FF_D_with_wen #(
    .DATA_LEN 	(1  ),
    .RST_DATA 	(0  ))
u_rdy(
    .clk      	(clk_in             ),
    .rst_n    	(rst_n_in           ),
    .wen      	(rdy_in_wen         ),
    .data_in  	(rdy_in_nxt         ),
    .data_out 	(rdy_in             )
);

assign cdc_req_set = req_in & rdy_in;
assign cdc_req_clr = cdc_req & cdc_rdy_sync;
assign cdc_req_wen = (cdc_req_set | cdc_req_clr);
assign cdc_req_nxt = (cdc_req_set | (!cdc_req_clr));
FF_D_with_wen #(
    .DATA_LEN 	(1  ),
    .RST_DATA 	(0  ))
u_cdc_req(
    .clk      	(clk_in             ),
    .rst_n    	(rst_n_in           ),
    .wen      	(cdc_req_wen        ),
    .data_in  	(cdc_req_nxt        ),
    .data_out 	(cdc_req            )
);

general_sync #(
    .DATA_LEN ( 1 ), 
    .RST_DATA ( 0 ), 
    .CHAIN_LV ( 2 )) 
r_cdc_req_sync(
    .clk      	(clk_out            ),
    .rst_n    	(rst_n_out          ),
    .data_in  	(cdc_req            ),
    .data_out 	(cdc_req_sync       )
);
FF_D_without_wen #(
    .DATA_LEN 	(1  ),
    .RST_DATA 	(0  ))
u_cdc_req_sync_r(
    .clk      	(clk_out            ),
    .rst_n    	(rst_n_out          ),
    .data_in  	(cdc_req_sync       ),
    .data_out 	(cdc_req_sync_r     )
);
assign cdc_req_sync_neg = (cdc_req_sync_r & (!cdc_req_sync));

assign cdc_rdy_set = cdc_req_sync & (!req_out);
assign cdc_rdy_clr = cdc_req_sync_neg;
assign cdc_rdy_wen = (cdc_rdy_set | cdc_rdy_clr);
assign cdc_rdy_nxt = (cdc_rdy_set | (!cdc_rdy_clr));
FF_D_with_wen #(
    .DATA_LEN 	(1  ),
    .RST_DATA 	(0  ))
u_cdc_rdy(
    .clk      	(clk_out            ),
    .rst_n    	(rst_n_out          ),
    .wen      	(cdc_rdy_wen        ),
    .data_in  	(cdc_rdy_nxt        ),
    .data_out 	(cdc_rdy            )
);

general_sync #(
    .DATA_LEN ( 1 ), 
    .RST_DATA ( 0 ), 
    .CHAIN_LV ( 2 )) 
r_cdc_rdy_sync(
    .clk      	(clk_in             ),
    .rst_n    	(rst_n_in           ),
    .data_in  	(cdc_rdy            ),
    .data_out 	(cdc_rdy_sync       )
);
FF_D_without_wen #(
    .DATA_LEN 	(1  ),
    .RST_DATA 	(0  ))
u_cdc_rdy_sync_r(
    .clk      	(clk_in             ),
    .rst_n    	(rst_n_in           ),
    .data_in  	(cdc_rdy_sync       ),
    .data_out 	(cdc_rdy_sync_r     )
);
assign cdc_rdy_sync_neg = (cdc_rdy_sync_r & (!cdc_rdy_sync));

assign req_out_set = cdc_req_sync & cdc_rdy;
assign req_out_clr = req_out & rdy_out;
assign req_out_wen = (req_out_set | req_out_clr);
assign req_out_nxt = (req_out_set | (!req_out_clr));
FF_D_with_wen #(
    .DATA_LEN 	(1  ),
    .RST_DATA 	(0  ))
u_req_out(
    .clk      	(clk_out            ),
    .rst_n    	(rst_n_out          ),
    .wen      	(req_out_wen        ),
    .data_in  	(req_out_nxt        ),
    .data_out 	(req_out            )
);

endmodule //cdc_handle
