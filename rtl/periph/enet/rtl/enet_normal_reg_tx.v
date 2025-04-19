module enet_normal_reg_tx (
    input               tx_clk,
    input               rst_n,

    input               palr_wen,
    input               paur_wen,
    input               opd_wen,
    input               tdsr_wen,
    input               tfwr_wen,
    input               tsem_wen,
    input               tafl_wen,
    input               taem_wen,
    input               tipg_wen,

    input  [31:0]       reg_wdata,

    output [31:0]       palr,
    output [31:0]       paur,
    output [31:0]       opd,
    output [31:0]       tdsr,
    output              strfwd,
    output [7:0]        tfwr,
    output [7:0]        tsem,
    output [7:0]        tafl,
    output [7:0]        taem,
    output [15:0]       tipg
);

FF_D_with_wen #(
    .DATA_LEN 	(32 ),
    .RST_DATA 	(0  ))
u_palr(
    .clk      	(tx_clk     ),
    .rst_n    	(rst_n      ),
    .wen      	(palr_wen   ),
    .data_in  	(reg_wdata  ),
    .data_out 	(palr       )
);

wire [15:0] paur_u16;
FF_D_with_wen #(
    .DATA_LEN 	(16 ),
    .RST_DATA 	(0  ))
u_paur(
    .clk      	(tx_clk             ),
    .rst_n    	(rst_n              ),
    .wen      	(paur_wen           ),
    .data_in  	(reg_wdata[31:16]   ),
    .data_out 	(paur_u16           )
);
assign paur = {paur_u16, 16'h8808};

wire [15:0] opd_l16;
FF_D_with_wen #(
    .DATA_LEN 	(16 ),
    .RST_DATA 	(0  ))
u_opd(
    .clk      	(tx_clk             ),
    .rst_n    	(rst_n              ),
    .wen      	(opd_wen            ),
    .data_in  	(reg_wdata[15:0]    ),
    .data_out 	(opd_l16            )
);
assign opd = {16'h0001, opd_l16};

FF_D_with_wen #(
    .DATA_LEN 	(29 ),
    .RST_DATA 	(0  ))
u_tdsr(
    .clk      	(tx_clk             ),
    .rst_n    	(rst_n              ),
    .wen      	(tdsr_wen           ),
    .data_in  	(reg_wdata[31:3]    ),
    .data_out 	(tdsr[31:3]         )
);
assign tdsr[2:0] = 3'h0;

FF_D_with_wen #(
    .DATA_LEN 	(1  ),
    .RST_DATA 	(0  ))
u_tfwr_strfwd(
    .clk      	(tx_clk         ),
    .rst_n    	(rst_n          ),
    .wen      	(tfwr_wen       ),
    .data_in  	(reg_wdata[8]   ),
    .data_out 	(strfwd         )
);
FF_D_with_wen #(
    .DATA_LEN 	(5  ),
    .RST_DATA 	(0  ))
u_tfwr(
    .clk      	(tx_clk         ),
    .rst_n    	(rst_n          ),
    .wen      	(tfwr_wen       ),
    .data_in  	(reg_wdata[4:0] ),
    .data_out 	(tfwr[7:3]      )
);
assign tfwr[2:0] = 3'h0;

FF_D_with_wen #(
    .DATA_LEN 	(8  ),
    .RST_DATA 	(0  ))
u_tsem(
    .clk      	(tx_clk         ),
    .rst_n    	(rst_n          ),
    .wen      	(tsem_wen       ),
    .data_in  	(reg_wdata[7:0] ),
    .data_out 	(tsem           )
);

wire [7:0] tafl_wdata = (reg_wdata[7:0] > 8'd120) ? 8'd120 : reg_wdata[7:0];
FF_D_with_wen #(
    .DATA_LEN 	(8       ),
    .RST_DATA 	(8'd120  ))
u_tafl(
    .clk      	(tx_clk     ),
    .rst_n    	(rst_n      ),
    .wen      	(tafl_wen   ),
    .data_in  	(tafl_wdata ),
    .data_out 	(tafl       )
);

wire [7:0] taem_wdata = (reg_wdata[7:0] < 8'h4) ? 8'h4 : reg_wdata[7:0];
FF_D_with_wen #(
    .DATA_LEN 	(8      ),
    .RST_DATA 	(8'h4   ))
u_taem(
    .clk      	(tx_clk     ),
    .rst_n    	(rst_n      ),
    .wen      	(taem_wen   ),
    .data_in  	(taem_wdata ),
    .data_out 	(taem       )
);

wire [4:0] tipg_reg;
FF_D_with_wen #(
    .DATA_LEN 	(5       ),
    .RST_DATA 	(5'hC    ))
u_tipg(
    .clk      	(tx_clk            ),
    .rst_n    	(rst_n             ),
    .wen      	(tipg_wen          ),
    .data_in  	(reg_wdata[4:0]    ),
    .data_out 	(tipg_reg          )
);
assign tipg = ((tipg_reg > 5'd26) | (tipg_reg < 5'd8)) ? 16'd12 : {11'h0, tipg_reg};

endmodule //enet_normal_reg_tx
