module clint_core#(
    parameter HART_NUM = 1
)(
    input                               clk,
    input                               rst_n,
    input                               mtime_l_wen,
    input                               mtime_h_wen,
    input  [HART_NUM - 1:0]             mtimecmp_l_wen,
    input  [HART_NUM - 1:0]             mtimecmp_h_wen,
    input  [HART_NUM - 1:0]             msip_wen,

    input  [31:0]                       reg_wdata,

    output [63:0]                       mtime,
    output [64 * HART_NUM -1:0]         mtimecmp,
    output [HART_NUM - 1:0]             mtip,
    output [HART_NUM - 1:0]             msip
);

genvar msip_index;
generate 
    for(msip_index = 0 ; msip_index < HART_NUM; msip_index = msip_index + 1) begin : msip_ff
        FF_D_with_wen #(
            .DATA_LEN 	(1  ),
            .RST_DATA 	(0  ))
        u_msip(
            .clk      	(clk                    ),
            .rst_n    	(rst_n                  ),
            .wen      	(msip_wen[msip_index]   ),
            .data_in  	(reg_wdata[0]           ),
            .data_out 	(msip[msip_index]       )
        );
    end
endgenerate

wire        mtime_inc;
wire [63:0] mtime_nxt;

assign mtime_inc = (!(mtime_l_wen | mtime_h_wen));
assign mtime_nxt = (mtime_l_wen | mtime_h_wen) ? {reg_wdata, reg_wdata} : (mtime + 1'b1);

FF_D_with_wen #(
    .DATA_LEN 	(32 ),
    .RST_DATA 	(0  ))
u_mtime_l(
    .clk      	(clk                        ),
    .rst_n    	(rst_n                      ),
    .wen      	(mtime_l_wen | mtime_inc    ),
    .data_in  	(mtime_nxt[31:0]            ),
    .data_out 	(mtime[31:0]                )
);
FF_D_with_wen #(
    .DATA_LEN 	(32 ),
    .RST_DATA 	(0  ))
u_mtime_h(
    .clk      	(clk                        ),
    .rst_n    	(rst_n                      ),
    .wen      	(mtime_h_wen | mtime_inc    ),
    .data_in  	(mtime_nxt[63:32]           ),
    .data_out 	(mtime[63:32]               )
);

genvar mtip_index;
generate 
    for(mtip_index = 0 ; mtip_index < HART_NUM; mtip_index = mtip_index + 1) begin : mtip_ff
        FF_D_without_asyn_rst #(
            .DATA_LEN 	(32 ))
        u_mtimecmp_l(
            .clk      	(clk                                                ),
            .wen      	(mtimecmp_l_wen[mtip_index]                         ),
            .data_in  	(reg_wdata                                          ),
            .data_out 	(mtimecmp[mtip_index * 64 + 31 : mtip_index * 64]   )
        );
        FF_D_without_asyn_rst #(
            .DATA_LEN 	(32 ))
        u_mtimecmp_h(
            .clk      	(clk                                                    ),
            .wen      	(mtimecmp_h_wen[mtip_index]                             ),
            .data_in  	(reg_wdata                                              ),
            .data_out 	(mtimecmp[mtip_index * 64 + 63 : mtip_index * 64 + 32]  )
        );
        assign mtip[mtip_index]         = (mtime >= mtimecmp[mtip_index * 64 + 63 : mtip_index * 64]);
    end
endgenerate

endmodule //clint_core
