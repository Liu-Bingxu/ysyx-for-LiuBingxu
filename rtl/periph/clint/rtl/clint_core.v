module clint_core#(
    parameter HART_NUM = 1
)(
    input                               clk,
    input                               rst_n,
    input                               mtime_wen,
    input  [HART_NUM - 1:0]             mtimecmp_wen,
    input  [HART_NUM - 1:0]             msip_wen,

    input  [63:0]                       reg_wdata,

    output [63:0]                       mtime,
    output [64 * HART_NUM -1:0]         mtimecmp,
    output [HART_NUM - 1:0]             mtip,
    output [HART_NUM - 1:0]             msip
);

genvar msip_index;
generate 
    for(msip_index = 0 ; msip_index < HART_NUM; msip_index = msip_index + 1) begin : msip_ff
        if(msip_index % 2 == 0)begin
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
        else begin
            FF_D_with_wen #(
                .DATA_LEN 	(1  ),
                .RST_DATA 	(0  ))
            u_msip(
                .clk      	(clk                    ),
                .rst_n    	(rst_n                  ),
                .wen      	(msip_wen[msip_index]   ),
                .data_in  	(reg_wdata[32]          ),
                .data_out 	(msip[msip_index]       )
            );
        end
    end
endgenerate

FF_D_with_wen #(
    .DATA_LEN 	(64 ),
    .RST_DATA 	(0  ))
u_mtime(
    .clk      	(clk        ),
    .rst_n    	(rst_n      ),
    .wen      	(mtime_wen  ),
    .data_in  	(reg_wdata  ),
    .data_out 	(mtime      )
);

genvar mtip_index;
generate 
    for(mtip_index = 0 ; mtip_index < HART_NUM; mtip_index = mtip_index + 1) begin : mtip_ff
        FF_D_without_asyn_rst #(
            .DATA_LEN 	(64 ))
        u_mtimecmp(
            .clk      	(clk                                                ),
            .wen      	(mtimecmp_wen[mtip_index]                           ),
            .data_in  	(reg_wdata                                          ),
            .data_out 	(mtimecmp[mtip_index * 64 + 63 : mtip_index * 64]   )
        );
        assign mtip[mtip_index]         = (mtime >= mtimecmp[mtip_index * 64 + 63 : mtip_index * 64]);
    end
endgenerate

endmodule //clint_core
