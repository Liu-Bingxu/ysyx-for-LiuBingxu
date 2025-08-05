module enet_rcr (
    input                           rx_clk,
    input                           rst_n,

    input                           rcr_wen,
    input                           ecr_wen,

    input  [31:0]                   reg_wdata,

    output                          ether_en,
    output                          drt,
    output                          mii_select,
    output                          nlc,
    output                          cfen,
    output                          crcfwd,
    output                          paufwd,
    output                          paden,
    output                          fce,
    output                          bc_rej,
    output                          prom,
    output [13:0]                   max_fl
);

FF_D_with_wen #(
    .DATA_LEN 	(1  ),
    .RST_DATA 	(0  ))
u_drt(
    .clk      	(rx_clk        ),
    .rst_n    	(rst_n         ),
    .wen      	(rcr_wen       ),
    .data_in  	(reg_wdata[1]  ),
    .data_out 	(drt           )
);

FF_D_with_wen #(
    .DATA_LEN 	(1  ),
    .RST_DATA 	(0  ))
u_nlc(
    .clk      	(rx_clk        ),
    .rst_n    	(rst_n         ),
    .wen      	(rcr_wen       ),
    .data_in  	(reg_wdata[30] ),
    .data_out 	(nlc           )
);

FF_D_with_wen #(
    .DATA_LEN 	(1  ),
    .RST_DATA 	(0  ))
u_cfen(
    .clk      	(rx_clk        ),
    .rst_n    	(rst_n         ),
    .wen      	(rcr_wen       ),
    .data_in  	(reg_wdata[15] ),
    .data_out 	(cfen          )
);

FF_D_with_wen #(
    .DATA_LEN 	(1  ),
    .RST_DATA 	(0  ))
u_crcfwd(
    .clk      	(rx_clk        ),
    .rst_n    	(rst_n         ),
    .wen      	(rcr_wen       ),
    .data_in  	(reg_wdata[14] ),
    .data_out 	(crcfwd        )
);

FF_D_with_wen #(
    .DATA_LEN 	(1  ),
    .RST_DATA 	(0  ))
u_paufwd(
    .clk      	(rx_clk        ),
    .rst_n    	(rst_n         ),
    .wen      	(rcr_wen       ),
    .data_in  	(reg_wdata[13] ),
    .data_out 	(paufwd        )
);

FF_D_with_wen #(
    .DATA_LEN 	(1  ),
    .RST_DATA 	(0  ))
u_paden(
    .clk      	(rx_clk        ),
    .rst_n    	(rst_n         ),
    .wen      	(rcr_wen       ),
    .data_in  	(reg_wdata[12] ),
    .data_out 	(paden         )
);

FF_D_with_wen #(
    .DATA_LEN 	(1  ),
    .RST_DATA 	(0  ))
u_fce(
    .clk      	(rx_clk        ),
    .rst_n    	(rst_n         ),
    .wen      	(rcr_wen       ),
    .data_in  	(reg_wdata[5]  ),
    .data_out 	(fce           )
);

FF_D_with_wen #(
    .DATA_LEN 	(1  ),
    .RST_DATA 	(0  ))
u_bc_rej(
    .clk      	(rx_clk        ),
    .rst_n    	(rst_n         ),
    .wen      	(rcr_wen       ),
    .data_in  	(reg_wdata[4]  ),
    .data_out 	(bc_rej        )
);

FF_D_with_wen #(
    .DATA_LEN 	(1  ),
    .RST_DATA 	(0  ))
u_prom(
    .clk      	(rx_clk        ),
    .rst_n    	(rst_n         ),
    .wen      	(rcr_wen       ),
    .data_in  	(reg_wdata[3]  ),
    .data_out 	(prom          )
);

FF_D_with_wen #(
    .DATA_LEN 	(14         ),
    .RST_DATA 	(14'h5EE    ))
u_max_fl(
    .clk      	(rx_clk             ),
    .rst_n    	(rst_n              ),
    .wen      	(ecr_wen            ),
    .data_in  	(reg_wdata[29:16]   ),
    .data_out 	(max_fl             )
);

FF_D_with_wen #(
    .DATA_LEN 	(1   ),
    .RST_DATA 	(0   ))
u_mii_sel(
    .clk      	(rx_clk         ),
    .rst_n    	(rst_n          ),
    .wen      	(ecr_wen        ),
    .data_in  	(reg_wdata[3]   ),
    .data_out 	(mii_select     )
);

FF_D_with_wen #(
    .DATA_LEN 	(1   ),
    .RST_DATA 	(0   ))
u_ether_en(
    .clk      	(rx_clk         ),
    .rst_n    	(rst_n          ),
    .wen      	(ecr_wen        ),
    .data_in  	(reg_wdata[1]   ),
    .data_out 	(ether_en       )
);

endmodule //enet_rcr
