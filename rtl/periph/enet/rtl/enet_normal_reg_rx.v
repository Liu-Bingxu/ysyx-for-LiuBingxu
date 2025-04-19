module enet_normal_reg_rx (
    input               rx_clk,
    input               rst_n,

    input               palr_wen,
    input               paur_wen,
    input               ialr_wen,
    input               iaur_wen,
    input               galr_wen,
    input               gaur_wen,
    input               rdsr_wen,
    input               rsfl_wen,
    input               rsem_wen,
    input               rafl_wen,
    input               raem_wen,
    input               ftrl_wen,

    input  [31:0]       reg_wdata,

    output [31:0]       palr,
    output [15:0]       paur,
    output [31:0]       ialr,
    output [31:0]       iaur,
    output [31:0]       galr,
    output [31:0]       gaur,
    output [31:0]       rdsr,
    output [7:0]        rsfl,
    output [4:0]        rsem_stat,
    output [7:0]        rsem_rx,
    output [7:0]        rafl,
    output [7:0]        raem,
    output [13:0]       ftrl
);

FF_D_with_wen #(
    .DATA_LEN 	(32 ),
    .RST_DATA 	(0  ))
u_palr(
    .clk      	(rx_clk    ),
    .rst_n    	(rst_n     ),
    .wen      	(palr_wen  ),
    .data_in  	(reg_wdata ),
    .data_out 	(palr      )
);

FF_D_with_wen #(
    .DATA_LEN 	(16 ),
    .RST_DATA 	(0  ))
u_paur(
    .clk      	(rx_clk             ),
    .rst_n    	(rst_n              ),
    .wen      	(paur_wen           ),
    .data_in  	(reg_wdata[31:16]   ),
    .data_out 	(paur               )
);

FF_D_with_wen #(
    .DATA_LEN 	(32 ),
    .RST_DATA 	(0  ))
u_ialr(
    .clk      	(rx_clk    ),
    .rst_n    	(rst_n     ),
    .wen      	(ialr_wen  ),
    .data_in  	(reg_wdata ),
    .data_out 	(ialr      )
);

FF_D_with_wen #(
    .DATA_LEN 	(32 ),
    .RST_DATA 	(0  ))
u_iaur(
    .clk      	(rx_clk    ),
    .rst_n    	(rst_n     ),
    .wen      	(iaur_wen  ),
    .data_in  	(reg_wdata ),
    .data_out 	(iaur      )
);

FF_D_with_wen #(
    .DATA_LEN 	(32 ),
    .RST_DATA 	(0  ))
u_galr(
    .clk      	(rx_clk    ),
    .rst_n    	(rst_n     ),
    .wen      	(galr_wen  ),
    .data_in  	(reg_wdata ),
    .data_out 	(galr      )
);

FF_D_with_wen #(
    .DATA_LEN 	(32 ),
    .RST_DATA 	(0  ))
u_gaur(
    .clk      	(rx_clk    ),
    .rst_n    	(rst_n     ),
    .wen      	(gaur_wen  ),
    .data_in  	(reg_wdata ),
    .data_out 	(gaur      )
);

FF_D_with_wen #(
    .DATA_LEN 	(29 ),
    .RST_DATA 	(0  ))
u_rdsr(
    .clk      	(rx_clk             ),
    .rst_n    	(rst_n              ),
    .wen      	(rdsr_wen           ),
    .data_in  	(reg_wdata[31:3]    ),
    .data_out 	(rdsr[31:3]         )
);
assign rdsr[2:0] = 3'h0;

FF_D_with_wen #(
    .DATA_LEN 	(8  ),
    .RST_DATA 	(0  ))
u_rsfl(
    .clk      	(rx_clk         ),
    .rst_n    	(rst_n          ),
    .wen      	(rsfl_wen       ),
    .data_in  	(reg_wdata[7:0] ),
    .data_out 	(rsfl           )
);

FF_D_with_wen #(
    .DATA_LEN 	(5  ),
    .RST_DATA 	(0  ))
u_rsem_stat(
    .clk      	(rx_clk             ),
    .rst_n    	(rst_n              ),
    .wen      	(rsem_wen           ),
    .data_in  	(reg_wdata[20:16]   ),
    .data_out 	(rsem_stat          )
);
FF_D_with_wen #(
    .DATA_LEN 	(8  ),
    .RST_DATA 	(0  ))
u_rsem_rx(
    .clk      	(rx_clk             ),
    .rst_n    	(rst_n              ),
    .wen      	(rsem_wen           ),
    .data_in  	(reg_wdata[7:0]     ),
    .data_out 	(rsem_rx            )
);

wire [7:0] rafl_wdata = (reg_wdata[7:0] > 8'd124) ? 8'd124 : reg_wdata[7:0];
FF_D_with_wen #(
    .DATA_LEN 	(8       ),
    .RST_DATA 	(8'd124  ))
u_rafl(
    .clk      	(rx_clk      ),
    .rst_n    	(rst_n       ),
    .wen      	(rafl_wen    ),
    .data_in  	(rafl_wdata  ),
    .data_out 	(rafl        )
);

wire [7:0] raem_wdata = (reg_wdata[7:0] < 8'h4) ? 8'h4 : reg_wdata[7:0];
FF_D_with_wen #(
    .DATA_LEN 	(8      ),
    .RST_DATA 	(8'h4   ))
u_raem(
    .clk      	(rx_clk        ),
    .rst_n    	(rst_n         ),
    .wen      	(raem_wen      ),
    .data_in  	(raem_wdata    ),
    .data_out 	(raem          )
);

FF_D_with_wen #(
    .DATA_LEN 	(14         ),
    .RST_DATA 	(14'h7ff    ))
u_ftrl(
    .clk      	(rx_clk             ),
    .rst_n    	(rst_n              ),
    .wen      	(ftrl_wen           ),
    .data_in  	(reg_wdata[13:0]    ),
    .data_out 	(ftrl               )
);

endmodule //enet_normal_reg_rx
