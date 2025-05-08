module enet_ecr (
    input               clk,
    input               enet_rst_n,
    output              rst_n,

    input               ecr_wen,
    input               write_success,

    input  [31:0]       reg_wdata,

    output [31:0]       ecr,
    output              ether_en,
    output              mii_select,
    output              rmii_select,
    output              rmii_10T
);

reg         rst_n_r[1:0];
always @(posedge clk or negedge enet_rst_n) begin
    if(enet_rst_n == 1'b0)begin
        rst_n_r[0] <= 1'b0;
        rst_n_r[1] <= 1'b0;
    end 
    else if(ecr_wen & (!reg_wdata[0]))begin
        rst_n_r[0] <= 1'b0;
        rst_n_r[1] <= 1'b0;
    end 
    else begin
        rst_n_r[0] <= 1'b1;
        rst_n_r[1] <= rst_n_r[0];
    end
end
assign rst_n = rst_n_r[1];

wire [13:0] max_fl;

FF_D_with_wen #(
    .DATA_LEN 	(14  ),
    .RST_DATA 	(0   ))
u_max_fl(
    .clk      	(clk                        ),
    .rst_n    	(rst_n                      ),
    .wen      	(ecr_wen & write_success    ),
    .data_in  	(reg_wdata[29:16]           ),
    .data_out 	(max_fl                     )
);

FF_D_with_wen #(
    .DATA_LEN 	(1   ),
    .RST_DATA 	(0   ))
u_rmii_10T(
    .clk      	(clk                        ),
    .rst_n    	(rst_n                      ),
    .wen      	(ecr_wen & write_success    ),
    .data_in  	(reg_wdata[4]               ),
    .data_out 	(rmii_10T                   )
);

FF_D_with_wen #(
    .DATA_LEN 	(1   ),
    .RST_DATA 	(0   ))
u_mii_sel(
    .clk      	(clk                        ),
    .rst_n    	(rst_n                      ),
    .wen      	(ecr_wen & write_success    ),
    .data_in  	(reg_wdata[3]               ),
    .data_out 	(mii_select                 )
);

FF_D_with_wen #(
    .DATA_LEN 	(1   ),
    .RST_DATA 	(0   ))
u_rmii_sel(
    .clk      	(clk                        ),
    .rst_n    	(rst_n                      ),
    .wen      	(ecr_wen & write_success    ),
    .data_in  	(reg_wdata[2]               ),
    .data_out 	(rmii_select                )
);

FF_D_with_wen #(
    .DATA_LEN 	(1   ),
    .RST_DATA 	(0   ))
u_ether_en(
    .clk      	(clk                        ),
    .rst_n    	(rst_n                      ),
    .wen      	(ecr_wen & write_success    ),
    .data_in  	(reg_wdata[1]               ),
    .data_out 	(ether_en                   )
);

assign ecr = {2'h0, max_fl, 11'h0, rmii_10T, mii_select, rmii_select, ether_en, 1'b0};

endmodule //enet_ecr
