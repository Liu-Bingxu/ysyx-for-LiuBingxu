`include "./define.v"
module immu(
    input                   clk,
    input                   rst_n,
//interface with wbu 
    input  [1:0]            current_priv_status,
    input  [3:0]            satp_mode,
    input  [15:0]           satp_asid,
//all flush flag 
    input                   flush_flag,
    input                   sflush_vma_valid,
    output                  sflush_vma_ready,
//interface with l2tlb
    output                  immu_miss_valid,
    input                   immu_miss_ready,
    output [63:0]           vaddr_i,
    input                   pte_valid,
    output                  pte_ready_i,
    input  [127:0]          pte,
    input                   pte_error,
//interface with fifo
    input                   mmu_fifo_valid,
    output                  mmu_fifo_ready,
    input  [63:0]           vaddr,
//interface with icache
    output                  paddr_valid,
    input                   paddr_ready,
    output [63:0]           paddr,
    output                  paddr_error
);

//sram interface
wire [31:0]             tlb_4K_valid;
wire [127:0]            tlb_4K[0:31];
wire [31:0]             tlb_4K_wen;
wire [7:0]              tlb_sp_valid;
wire [127:0]            tlb_sp[0:7];
wire [7:0]              tlb_sp_wen;
wire [47:0]             tlb_hit;

wire [127:0]            tlb_sel;

wire                    page_wen;
wire                    page_4K_wen;
wire                    page_sp_wen;

//stage
localparam IDLE         = 2'h0;
localparam SUBMIT_REQ   = 2'h1;
localparam WAIT_RESP    = 2'h3;
reg  [1:0]              stage_status;
reg                     immu_miss_valid_reg;
//跳过mmu阶段
wire                    stage_jump_mmu;

//**********************************************************************************************
//?tlb
genvar tlb_normal_page_index;
generate
    for(tlb_normal_page_index = 0; tlb_normal_page_index < 32; tlb_normal_page_index = tlb_normal_page_index + 1)begin: tlb_normal_page
        FF_D_without_asyn_rst #(
            .DATA_LEN 	(128  ))
        u_normal_page(
            .clk      	(clk                                ),
            .wen      	(tlb_4K_wen[tlb_normal_page_index]  ),
            .data_in  	(pte                                ),
            .data_out 	(tlb_4K[tlb_normal_page_index]      )
        );
        FF_D_with_syn_rst #(
            .DATA_LEN 	(1  ),
            .RST_DATA 	(0  ))
        u_normal_page_valid(
            .clk      	(clk                                  ),
            .rst_n    	(rst_n                                ),
            .syn_rst  	(sflush_vma_valid                     ),
            .wen      	(tlb_4K_wen[tlb_normal_page_index]    ),
            .data_in  	(1'b1                                 ),
            .data_out 	(tlb_4K_valid[tlb_normal_page_index]  )
        );
    end
endgenerate
genvar tlb_sp_index;
generate
    for(tlb_sp_index = 0; tlb_sp_index < 8; tlb_sp_index = tlb_sp_index + 1)begin: tlb_super_page
        FF_D_without_asyn_rst #(
            .DATA_LEN 	(128  ))
        u_super_page(
            .clk      	(clk                       ),
            .wen      	(tlb_sp_wen[tlb_sp_index]  ),
            .data_in  	(pte                       ),
            .data_out 	(tlb_sp[tlb_sp_index]      )
        );
        FF_D_with_syn_rst #(
            .DATA_LEN 	(1  ),
            .RST_DATA 	(0  ))
        u_super_page_valid(
            .clk      	(clk                         ),
            .rst_n    	(rst_n                       ),
            .syn_rst  	(sflush_vma_valid            ),
            .wen      	(tlb_sp_wen[tlb_sp_index]    ),
            .data_in  	(1'b1                        ),
            .data_out 	(tlb_sp_valid[tlb_sp_index]  )
        );
    end
endgenerate
assign stage_jump_mmu       =   (current_priv_status == `PRV_M) | (satp_mode == 4'h0);
assign tlb_hit[0]           =   (tlb_4K_valid[0]  & (tlb_4K[0][57:31]  == vaddr[38:12]) & ((tlb_4K[0 ][127:112] == satp_asid) | tlb_4K[0 ][63]));
assign tlb_hit[1]           =   (tlb_4K_valid[1]  & (tlb_4K[1][57:31]  == vaddr[38:12]) & ((tlb_4K[1 ][127:112] == satp_asid) | tlb_4K[1 ][63]));
assign tlb_hit[2]           =   (tlb_4K_valid[2]  & (tlb_4K[2][57:31]  == vaddr[38:12]) & ((tlb_4K[2 ][127:112] == satp_asid) | tlb_4K[2 ][63]));
assign tlb_hit[3]           =   (tlb_4K_valid[3]  & (tlb_4K[3][57:31]  == vaddr[38:12]) & ((tlb_4K[3 ][127:112] == satp_asid) | tlb_4K[3 ][63]));
assign tlb_hit[4]           =   (tlb_4K_valid[4]  & (tlb_4K[4][57:31]  == vaddr[38:12]) & ((tlb_4K[4 ][127:112] == satp_asid) | tlb_4K[4 ][63]));
assign tlb_hit[5]           =   (tlb_4K_valid[5]  & (tlb_4K[5][57:31]  == vaddr[38:12]) & ((tlb_4K[5 ][127:112] == satp_asid) | tlb_4K[5 ][63]));
assign tlb_hit[6]           =   (tlb_4K_valid[6]  & (tlb_4K[6][57:31]  == vaddr[38:12]) & ((tlb_4K[6 ][127:112] == satp_asid) | tlb_4K[6 ][63]));
assign tlb_hit[7]           =   (tlb_4K_valid[7]  & (tlb_4K[7][57:31]  == vaddr[38:12]) & ((tlb_4K[7 ][127:112] == satp_asid) | tlb_4K[7 ][63]));
assign tlb_hit[8]           =   (tlb_4K_valid[8]  & (tlb_4K[8][57:31]  == vaddr[38:12]) & ((tlb_4K[8 ][127:112] == satp_asid) | tlb_4K[8 ][63]));
assign tlb_hit[9]           =   (tlb_4K_valid[9]  & (tlb_4K[9][57:31]  == vaddr[38:12]) & ((tlb_4K[9 ][127:112] == satp_asid) | tlb_4K[9 ][63]));
assign tlb_hit[10]          =   (tlb_4K_valid[10] & (tlb_4K[10][57:31] == vaddr[38:12]) & ((tlb_4K[10][127:112] == satp_asid) | tlb_4K[10][63]));
assign tlb_hit[11]          =   (tlb_4K_valid[11] & (tlb_4K[11][57:31] == vaddr[38:12]) & ((tlb_4K[11][127:112] == satp_asid) | tlb_4K[11][63]));
assign tlb_hit[12]          =   (tlb_4K_valid[12] & (tlb_4K[12][57:31] == vaddr[38:12]) & ((tlb_4K[12][127:112] == satp_asid) | tlb_4K[12][63]));
assign tlb_hit[13]          =   (tlb_4K_valid[13] & (tlb_4K[13][57:31] == vaddr[38:12]) & ((tlb_4K[13][127:112] == satp_asid) | tlb_4K[13][63]));
assign tlb_hit[14]          =   (tlb_4K_valid[14] & (tlb_4K[14][57:31] == vaddr[38:12]) & ((tlb_4K[14][127:112] == satp_asid) | tlb_4K[14][63]));
assign tlb_hit[15]          =   (tlb_4K_valid[15] & (tlb_4K[15][57:31] == vaddr[38:12]) & ((tlb_4K[15][127:112] == satp_asid) | tlb_4K[15][63]));
assign tlb_hit[16]          =   (tlb_4K_valid[16] & (tlb_4K[16][57:31] == vaddr[38:12]) & ((tlb_4K[16][127:112] == satp_asid) | tlb_4K[16][63]));
assign tlb_hit[17]          =   (tlb_4K_valid[17] & (tlb_4K[17][57:31] == vaddr[38:12]) & ((tlb_4K[17][127:112] == satp_asid) | tlb_4K[17][63]));
assign tlb_hit[18]          =   (tlb_4K_valid[18] & (tlb_4K[18][57:31] == vaddr[38:12]) & ((tlb_4K[18][127:112] == satp_asid) | tlb_4K[18][63]));
assign tlb_hit[19]          =   (tlb_4K_valid[19] & (tlb_4K[19][57:31] == vaddr[38:12]) & ((tlb_4K[19][127:112] == satp_asid) | tlb_4K[19][63]));
assign tlb_hit[20]          =   (tlb_4K_valid[20] & (tlb_4K[20][57:31] == vaddr[38:12]) & ((tlb_4K[20][127:112] == satp_asid) | tlb_4K[20][63]));
assign tlb_hit[21]          =   (tlb_4K_valid[21] & (tlb_4K[21][57:31] == vaddr[38:12]) & ((tlb_4K[21][127:112] == satp_asid) | tlb_4K[21][63]));
assign tlb_hit[22]          =   (tlb_4K_valid[22] & (tlb_4K[22][57:31] == vaddr[38:12]) & ((tlb_4K[22][127:112] == satp_asid) | tlb_4K[22][63]));
assign tlb_hit[23]          =   (tlb_4K_valid[23] & (tlb_4K[23][57:31] == vaddr[38:12]) & ((tlb_4K[23][127:112] == satp_asid) | tlb_4K[23][63]));
assign tlb_hit[24]          =   (tlb_4K_valid[24] & (tlb_4K[24][57:31] == vaddr[38:12]) & ((tlb_4K[24][127:112] == satp_asid) | tlb_4K[24][63]));
assign tlb_hit[25]          =   (tlb_4K_valid[25] & (tlb_4K[25][57:31] == vaddr[38:12]) & ((tlb_4K[25][127:112] == satp_asid) | tlb_4K[25][63]));
assign tlb_hit[26]          =   (tlb_4K_valid[26] & (tlb_4K[26][57:31] == vaddr[38:12]) & ((tlb_4K[26][127:112] == satp_asid) | tlb_4K[26][63]));
assign tlb_hit[27]          =   (tlb_4K_valid[27] & (tlb_4K[27][57:31] == vaddr[38:12]) & ((tlb_4K[27][127:112] == satp_asid) | tlb_4K[27][63]));
assign tlb_hit[28]          =   (tlb_4K_valid[28] & (tlb_4K[28][57:31] == vaddr[38:12]) & ((tlb_4K[28][127:112] == satp_asid) | tlb_4K[28][63]));
assign tlb_hit[29]          =   (tlb_4K_valid[29] & (tlb_4K[29][57:31] == vaddr[38:12]) & ((tlb_4K[29][127:112] == satp_asid) | tlb_4K[29][63]));
assign tlb_hit[30]          =   (tlb_4K_valid[30] & (tlb_4K[30][57:31] == vaddr[38:12]) & ((tlb_4K[30][127:112] == satp_asid) | tlb_4K[30][63]));
assign tlb_hit[31]          =   (tlb_4K_valid[31] & (tlb_4K[31][57:31] == vaddr[38:12]) & ((tlb_4K[31][127:112] == satp_asid) | tlb_4K[31][63]));
assign tlb_hit[32]          =   (tlb_sp_valid[0]  & (tlb_sp[0][57:49]  == vaddr[38:30]) & ((tlb_sp[0 ][127:112] == satp_asid) | tlb_sp[0 ][63]) & (tlb_sp[0][2:0] == 3'h2));
assign tlb_hit[33]          =   (tlb_sp_valid[1]  & (tlb_sp[1][57:49]  == vaddr[38:30]) & ((tlb_sp[1 ][127:112] == satp_asid) | tlb_sp[1 ][63]) & (tlb_sp[1][2:0] == 3'h2));
assign tlb_hit[34]          =   (tlb_sp_valid[2]  & (tlb_sp[2][57:49]  == vaddr[38:30]) & ((tlb_sp[2 ][127:112] == satp_asid) | tlb_sp[2 ][63]) & (tlb_sp[2][2:0] == 3'h2));
assign tlb_hit[35]          =   (tlb_sp_valid[3]  & (tlb_sp[3][57:49]  == vaddr[38:30]) & ((tlb_sp[3 ][127:112] == satp_asid) | tlb_sp[3 ][63]) & (tlb_sp[3][2:0] == 3'h2));
assign tlb_hit[36]          =   (tlb_sp_valid[4]  & (tlb_sp[4][57:49]  == vaddr[38:30]) & ((tlb_sp[4 ][127:112] == satp_asid) | tlb_sp[4 ][63]) & (tlb_sp[4][2:0] == 3'h2));
assign tlb_hit[37]          =   (tlb_sp_valid[5]  & (tlb_sp[5][57:49]  == vaddr[38:30]) & ((tlb_sp[5 ][127:112] == satp_asid) | tlb_sp[5 ][63]) & (tlb_sp[5][2:0] == 3'h2));
assign tlb_hit[38]          =   (tlb_sp_valid[6]  & (tlb_sp[6][57:49]  == vaddr[38:30]) & ((tlb_sp[6 ][127:112] == satp_asid) | tlb_sp[6 ][63]) & (tlb_sp[6][2:0] == 3'h2));
assign tlb_hit[39]          =   (tlb_sp_valid[7]  & (tlb_sp[7][57:49]  == vaddr[38:30]) & ((tlb_sp[7 ][127:112] == satp_asid) | tlb_sp[7 ][63]) & (tlb_sp[7][2:0] == 3'h2));
assign tlb_hit[40]          =   (tlb_sp_valid[0]  & (tlb_sp[0][57:40]  == vaddr[38:21]) & ((tlb_sp[0 ][127:112] == satp_asid) | tlb_sp[0 ][63]) & (tlb_sp[0][2:0] == 3'h1));
assign tlb_hit[41]          =   (tlb_sp_valid[1]  & (tlb_sp[1][57:40]  == vaddr[38:21]) & ((tlb_sp[1 ][127:112] == satp_asid) | tlb_sp[1 ][63]) & (tlb_sp[1][2:0] == 3'h1));
assign tlb_hit[42]          =   (tlb_sp_valid[2]  & (tlb_sp[2][57:40]  == vaddr[38:21]) & ((tlb_sp[2 ][127:112] == satp_asid) | tlb_sp[2 ][63]) & (tlb_sp[2][2:0] == 3'h1));
assign tlb_hit[43]          =   (tlb_sp_valid[3]  & (tlb_sp[3][57:40]  == vaddr[38:21]) & ((tlb_sp[3 ][127:112] == satp_asid) | tlb_sp[3 ][63]) & (tlb_sp[3][2:0] == 3'h1));
assign tlb_hit[44]          =   (tlb_sp_valid[4]  & (tlb_sp[4][57:40]  == vaddr[38:21]) & ((tlb_sp[4 ][127:112] == satp_asid) | tlb_sp[4 ][63]) & (tlb_sp[4][2:0] == 3'h1));
assign tlb_hit[45]          =   (tlb_sp_valid[5]  & (tlb_sp[5][57:40]  == vaddr[38:21]) & ((tlb_sp[5 ][127:112] == satp_asid) | tlb_sp[5 ][63]) & (tlb_sp[5][2:0] == 3'h1));
assign tlb_hit[46]          =   (tlb_sp_valid[6]  & (tlb_sp[6][57:40]  == vaddr[38:21]) & ((tlb_sp[6 ][127:112] == satp_asid) | tlb_sp[6 ][63]) & (tlb_sp[6][2:0] == 3'h1));
assign tlb_hit[47]          =   (tlb_sp_valid[7]  & (tlb_sp[7][57:40]  == vaddr[38:21]) & ((tlb_sp[7 ][127:112] == satp_asid) | tlb_sp[7 ][63]) & (tlb_sp[7][2:0] == 3'h1));

assign tlb_sel              =   ({128{tlb_hit[0 ]}} & tlb_4K[0] ) | 
                                ({128{tlb_hit[1 ]}} & tlb_4K[1] ) | 
                                ({128{tlb_hit[2 ]}} & tlb_4K[2] ) | 
                                ({128{tlb_hit[3 ]}} & tlb_4K[3] ) | 
                                ({128{tlb_hit[4 ]}} & tlb_4K[4] ) | 
                                ({128{tlb_hit[5 ]}} & tlb_4K[5] ) | 
                                ({128{tlb_hit[6 ]}} & tlb_4K[6] ) | 
                                ({128{tlb_hit[7 ]}} & tlb_4K[7] ) | 
                                ({128{tlb_hit[8 ]}} & tlb_4K[8] ) | 
                                ({128{tlb_hit[9 ]}} & tlb_4K[9] ) | 
                                ({128{tlb_hit[10]}} & tlb_4K[10]) | 
                                ({128{tlb_hit[11]}} & tlb_4K[11]) | 
                                ({128{tlb_hit[12]}} & tlb_4K[12]) | 
                                ({128{tlb_hit[13]}} & tlb_4K[13]) | 
                                ({128{tlb_hit[14]}} & tlb_4K[14]) | 
                                ({128{tlb_hit[15]}} & tlb_4K[15]) | 
                                ({128{tlb_hit[16]}} & tlb_4K[16]) | 
                                ({128{tlb_hit[17]}} & tlb_4K[17]) | 
                                ({128{tlb_hit[18]}} & tlb_4K[18]) | 
                                ({128{tlb_hit[19]}} & tlb_4K[19]) | 
                                ({128{tlb_hit[20]}} & tlb_4K[20]) | 
                                ({128{tlb_hit[21]}} & tlb_4K[21]) | 
                                ({128{tlb_hit[22]}} & tlb_4K[22]) | 
                                ({128{tlb_hit[23]}} & tlb_4K[23]) | 
                                ({128{tlb_hit[24]}} & tlb_4K[24]) | 
                                ({128{tlb_hit[25]}} & tlb_4K[25]) | 
                                ({128{tlb_hit[26]}} & tlb_4K[26]) | 
                                ({128{tlb_hit[27]}} & tlb_4K[27]) | 
                                ({128{tlb_hit[28]}} & tlb_4K[28]) | 
                                ({128{tlb_hit[29]}} & tlb_4K[29]) | 
                                ({128{tlb_hit[30]}} & tlb_4K[30]) | 
                                ({128{tlb_hit[31]}} & tlb_4K[31]) | 
                                ({128{tlb_hit[32]}} & tlb_sp[0 ]) | 
                                ({128{tlb_hit[33]}} & tlb_sp[1 ]) | 
                                ({128{tlb_hit[34]}} & tlb_sp[2 ]) | 
                                ({128{tlb_hit[35]}} & tlb_sp[3 ]) | 
                                ({128{tlb_hit[36]}} & tlb_sp[4 ]) | 
                                ({128{tlb_hit[37]}} & tlb_sp[5 ]) | 
                                ({128{tlb_hit[38]}} & tlb_sp[6 ]) | 
                                ({128{tlb_hit[39]}} & tlb_sp[7 ]) | 
                                ({128{(stage_status == WAIT_RESP)}} & pte);

assign page_4K_wen           = page_wen & (pte[2:0] == 3'h0);
assign page_sp_wen           = page_wen & (pte[2:0] != 3'h0);
plru_32 u_plru_4K(
	.clk      	( clk                               ),
	.rst_n    	( rst_n                             ),
	.hit      	( mmu_fifo_valid & (|tlb_hit[31:0]) ),
	.hit_sel  	( tlb_hit[31:0]                     ),
	.plru_wen 	( page_4K_wen                       ),
	.wen      	( tlb_4K_wen                        )
);

plru_8 u_plru_sp(
	.clk      	( clk                                   ),
	.rst_n    	( rst_n                                 ),
	.hit      	( mmu_fifo_valid & (|tlb_hit[47:32])    ),
	.hit_sel  	( tlb_hit[39:32] |   tlb_hit[47:40]     ),
	.plru_wen 	( page_sp_wen                           ),
	.wen      	( tlb_sp_wen                            )
);
//**********************************************************************************************
//!fsm
always @(posedge clk or negedge rst_n) begin
    if(!rst_n)begin
        stage_status        <= IDLE;
        immu_miss_valid_reg <= 1'b0;
    end
    else if(flush_flag)begin
        stage_status        <= IDLE;
        immu_miss_valid_reg <= 1'b0;
    end
    else begin
        case (stage_status)
            IDLE: begin
                if(mmu_fifo_valid & (!stage_jump_mmu) & (!(|tlb_hit)) & (vaddr[63:39] == {25{vaddr[38]}}))begin
                    stage_status        <= SUBMIT_REQ;
                    immu_miss_valid_reg <= 1'b1;
                end
            end
            SUBMIT_REQ: begin
                if(immu_miss_valid & immu_miss_ready)begin
                    stage_status        <= WAIT_RESP;
                    immu_miss_valid_reg <= 1'b0;
                end
            end
            WAIT_RESP: begin
                if(pte_valid & pte_ready_i & (paddr_ready | (!paddr_valid)))begin
                    stage_status        <= IDLE;
                end
            end
            default: begin
                stage_status        <= IDLE;
                immu_miss_valid_reg <= 1'b0;
            end
        endcase
    end
end
assign page_wen         = (stage_status == WAIT_RESP) & (pte_valid) & (pte_ready_i) & (paddr_ready | (!paddr_valid));
//**********************************************************************************************
//?output
assign sflush_vma_ready = 1'b1;
assign immu_miss_valid  = immu_miss_valid_reg;
assign vaddr_i          = vaddr;
assign pte_ready_i      = (stage_status == WAIT_RESP);
assign mmu_fifo_ready   = ((stage_jump_mmu | (|tlb_hit) | ((stage_status == WAIT_RESP) & (pte_valid) & (pte_ready_i)) | (vaddr[63:39] != {25{vaddr[38]}})) & mmu_fifo_valid & (paddr_ready | (!paddr_valid)));
FF_D_with_syn_rst #(
    .DATA_LEN 	(1  ),
    .RST_DATA 	(0  ))
u_paddr_valid(
    .clk      	(clk                            ),
    .rst_n    	(rst_n                          ),
    .syn_rst  	(flush_flag                     ),
    .wen      	(paddr_ready | (!paddr_valid)   ),
    .data_in  	(mmu_fifo_ready                 ),
    .data_out 	(paddr_valid                    )
);
assign paddr        =   (stage_jump_mmu) ? vaddr : 
                        (({64{tlb_sel[2:0] == 3'h0}} & {8'h0, tlb_sel[111:68], vaddr[11:0]}) | 
                        ({64{tlb_sel[2:0] == 3'h1}} & {8'h0, tlb_sel[111:77], vaddr[20:0]}) | 
                        ({64{tlb_sel[2:0] == 3'h2}} & {8'h0, tlb_sel[111:86], vaddr[29:0]}));
//! this page can not Excute
//! Smode don't fetch the Umode page instrument
//! Umode don't fetch the Smode page instrument
//! l2tlb report error
//! vaddr illegel
assign paddr_error  =   ((vaddr[63:39] != {25{vaddr[38]}}) | (!tlb_sel[61]) | (current_priv_status[0] == tlb_sel[62]) | ((stage_status == WAIT_RESP) & pte_error)) & (!stage_jump_mmu);

endmodule //immu
