`include "./define.v"
module dmmu (
    input                   clk,
    input                   rst_n,
//interface with wbu 
    input  [1:0]            current_priv_status,
    input         	        MXR,
    input         	        SUM,
    input         	        MPRV,
    input  [1:0]  	        MPP,
    input  [3:0]            satp_mode,
    input  [15:0]           satp_asid,
//all flush flag 
    input                   flush_flag,
    input                   sflush_vma_valid,
//interface with l2tlb
    output                  dmmu_miss_valid,
    input                   dmmu_miss_ready,
    output [63:0]           vaddr_d,
    input                   pte_valid,
    output                  pte_ready_d,
    input  [127:0]          pte,
    input                   pte_error,
//interface with fifo
    input                   mmu_fifo_valid,
    output                  mmu_fifo_ready,
    input  [64:0]           vaddr,
//interface with dcache
    output                  paddr_valid,
    input                   paddr_ready,
    output [63:0]           paddr,
    output                  paddr_error
);

//sram interface
wire [63:0]             tlb_4K_valid;
wire [127:0]            tlb_4K[0:63];
wire [63:0]             tlb_4K_wen;
wire [15:0]             tlb_sp_valid;
wire [127:0]            tlb_sp[0:15];
wire [15:0]             tlb_sp_wen;
wire [32:0]             tlb_hit;

wire [127:0]            tlb_sel;

wire                    page_wen;
wire                    page_4K_wen;
wire                    page_sp_wen;

//stage
localparam IDLE         = 2'h0;
localparam SUBMIT_REQ   = 2'h1;
localparam WAIT_RESP    = 2'h3;
localparam SEND_ADDR    = 2'h2;
reg  [1:0]              stage_status;
reg                     dmmu_miss_valid_reg;
reg  [127:0]            pte_reg;
reg                     pte_error_reg;
wire [63:0]             paddr_out;
wire                    paddr_error_out;
//跳过mmu阶段
wire [1:0]              use_priv;
wire                    stage_jump_mmu;

//**********************************************************************************************
//?tlb
genvar tlb_normal_page_index;
generate
    for(tlb_normal_page_index = 0; tlb_normal_page_index < 64; tlb_normal_page_index = tlb_normal_page_index + 1)begin: tlb_normal_page
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
        assign tlb_4K_wen[tlb_normal_page_index]  = page_4K_wen & (vaddr[17:12] == tlb_normal_page_index);
    end
endgenerate
genvar tlb_sp_index;
generate
    for(tlb_sp_index = 0; tlb_sp_index < 16; tlb_sp_index = tlb_sp_index + 1)begin: tlb_super_page
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
assign use_priv             =   (MPRV) ? MPP : current_priv_status;
assign stage_jump_mmu       =   (use_priv == `PRV_M) | (satp_mode == 4'h0);
assign tlb_hit[0]           =   (tlb_4K_valid[vaddr[17:12]]  & (tlb_4K[vaddr[17:12]][57:31]  == vaddr[38:12]) & ((tlb_4K[vaddr[17:12]][127:112] == satp_asid) | tlb_4K[vaddr[17:12]][63]));
assign tlb_hit[1]           =   (tlb_sp_valid[0 ] & (tlb_sp[0 ][57:49] == vaddr[38:30]) & ((tlb_sp[0 ][127:112] == satp_asid) | tlb_sp[0 ][63]) & (tlb_sp[0 ][2:0] == 3'h2));
assign tlb_hit[2]           =   (tlb_sp_valid[1 ] & (tlb_sp[1 ][57:49] == vaddr[38:30]) & ((tlb_sp[1 ][127:112] == satp_asid) | tlb_sp[1 ][63]) & (tlb_sp[1 ][2:0] == 3'h2));
assign tlb_hit[3]           =   (tlb_sp_valid[2 ] & (tlb_sp[2 ][57:49] == vaddr[38:30]) & ((tlb_sp[2 ][127:112] == satp_asid) | tlb_sp[2 ][63]) & (tlb_sp[2 ][2:0] == 3'h2));
assign tlb_hit[4]           =   (tlb_sp_valid[3 ] & (tlb_sp[3 ][57:49] == vaddr[38:30]) & ((tlb_sp[3 ][127:112] == satp_asid) | tlb_sp[3 ][63]) & (tlb_sp[3 ][2:0] == 3'h2));
assign tlb_hit[5]           =   (tlb_sp_valid[4 ] & (tlb_sp[4 ][57:49] == vaddr[38:30]) & ((tlb_sp[4 ][127:112] == satp_asid) | tlb_sp[4 ][63]) & (tlb_sp[4 ][2:0] == 3'h2));
assign tlb_hit[6]           =   (tlb_sp_valid[5 ] & (tlb_sp[5 ][57:49] == vaddr[38:30]) & ((tlb_sp[5 ][127:112] == satp_asid) | tlb_sp[5 ][63]) & (tlb_sp[5 ][2:0] == 3'h2));
assign tlb_hit[7]           =   (tlb_sp_valid[6 ] & (tlb_sp[6 ][57:49] == vaddr[38:30]) & ((tlb_sp[6 ][127:112] == satp_asid) | tlb_sp[6 ][63]) & (tlb_sp[6 ][2:0] == 3'h2));
assign tlb_hit[8]           =   (tlb_sp_valid[7 ] & (tlb_sp[7 ][57:49] == vaddr[38:30]) & ((tlb_sp[7 ][127:112] == satp_asid) | tlb_sp[7 ][63]) & (tlb_sp[7 ][2:0] == 3'h2));
assign tlb_hit[9]           =   (tlb_sp_valid[8 ] & (tlb_sp[8 ][57:49] == vaddr[38:30]) & ((tlb_sp[8 ][127:112] == satp_asid) | tlb_sp[8 ][63]) & (tlb_sp[8 ][2:0] == 3'h2));
assign tlb_hit[10]          =   (tlb_sp_valid[9 ] & (tlb_sp[9 ][57:49] == vaddr[38:30]) & ((tlb_sp[9 ][127:112] == satp_asid) | tlb_sp[9 ][63]) & (tlb_sp[9 ][2:0] == 3'h2));
assign tlb_hit[11]          =   (tlb_sp_valid[10] & (tlb_sp[10][57:49] == vaddr[38:30]) & ((tlb_sp[10][127:112] == satp_asid) | tlb_sp[10][63]) & (tlb_sp[10][2:0] == 3'h2));
assign tlb_hit[12]          =   (tlb_sp_valid[11] & (tlb_sp[11][57:49] == vaddr[38:30]) & ((tlb_sp[11][127:112] == satp_asid) | tlb_sp[11][63]) & (tlb_sp[11][2:0] == 3'h2));
assign tlb_hit[13]          =   (tlb_sp_valid[12] & (tlb_sp[12][57:49] == vaddr[38:30]) & ((tlb_sp[12][127:112] == satp_asid) | tlb_sp[12][63]) & (tlb_sp[12][2:0] == 3'h2));
assign tlb_hit[14]          =   (tlb_sp_valid[13] & (tlb_sp[13][57:49] == vaddr[38:30]) & ((tlb_sp[13][127:112] == satp_asid) | tlb_sp[13][63]) & (tlb_sp[13][2:0] == 3'h2));
assign tlb_hit[15]          =   (tlb_sp_valid[14] & (tlb_sp[14][57:49] == vaddr[38:30]) & ((tlb_sp[14][127:112] == satp_asid) | tlb_sp[14][63]) & (tlb_sp[14][2:0] == 3'h2));
assign tlb_hit[16]          =   (tlb_sp_valid[15] & (tlb_sp[15][57:49] == vaddr[38:30]) & ((tlb_sp[15][127:112] == satp_asid) | tlb_sp[15][63]) & (tlb_sp[15][2:0] == 3'h2));
assign tlb_hit[17]          =   (tlb_sp_valid[0 ] & (tlb_sp[0 ][57:40] == vaddr[38:21]) & ((tlb_sp[0 ][127:112] == satp_asid) | tlb_sp[0 ][63]) & (tlb_sp[0 ][2:0] == 3'h1));
assign tlb_hit[18]          =   (tlb_sp_valid[1 ] & (tlb_sp[1 ][57:40] == vaddr[38:21]) & ((tlb_sp[1 ][127:112] == satp_asid) | tlb_sp[1 ][63]) & (tlb_sp[1 ][2:0] == 3'h1));
assign tlb_hit[19]          =   (tlb_sp_valid[2 ] & (tlb_sp[2 ][57:40] == vaddr[38:21]) & ((tlb_sp[2 ][127:112] == satp_asid) | tlb_sp[2 ][63]) & (tlb_sp[2 ][2:0] == 3'h1));
assign tlb_hit[20]          =   (tlb_sp_valid[3 ] & (tlb_sp[3 ][57:40] == vaddr[38:21]) & ((tlb_sp[3 ][127:112] == satp_asid) | tlb_sp[3 ][63]) & (tlb_sp[3 ][2:0] == 3'h1));
assign tlb_hit[21]          =   (tlb_sp_valid[4 ] & (tlb_sp[4 ][57:40] == vaddr[38:21]) & ((tlb_sp[4 ][127:112] == satp_asid) | tlb_sp[4 ][63]) & (tlb_sp[4 ][2:0] == 3'h1));
assign tlb_hit[22]          =   (tlb_sp_valid[5 ] & (tlb_sp[5 ][57:40] == vaddr[38:21]) & ((tlb_sp[5 ][127:112] == satp_asid) | tlb_sp[5 ][63]) & (tlb_sp[5 ][2:0] == 3'h1));
assign tlb_hit[23]          =   (tlb_sp_valid[6 ] & (tlb_sp[6 ][57:40] == vaddr[38:21]) & ((tlb_sp[6 ][127:112] == satp_asid) | tlb_sp[6 ][63]) & (tlb_sp[6 ][2:0] == 3'h1));
assign tlb_hit[24]          =   (tlb_sp_valid[7 ] & (tlb_sp[7 ][57:40] == vaddr[38:21]) & ((tlb_sp[7 ][127:112] == satp_asid) | tlb_sp[7 ][63]) & (tlb_sp[7 ][2:0] == 3'h1));
assign tlb_hit[25]          =   (tlb_sp_valid[8 ] & (tlb_sp[8 ][57:40] == vaddr[38:21]) & ((tlb_sp[8 ][127:112] == satp_asid) | tlb_sp[8 ][63]) & (tlb_sp[8 ][2:0] == 3'h1));
assign tlb_hit[26]          =   (tlb_sp_valid[9 ] & (tlb_sp[9 ][57:40] == vaddr[38:21]) & ((tlb_sp[9 ][127:112] == satp_asid) | tlb_sp[9 ][63]) & (tlb_sp[9 ][2:0] == 3'h1));
assign tlb_hit[27]          =   (tlb_sp_valid[10] & (tlb_sp[10][57:40] == vaddr[38:21]) & ((tlb_sp[10][127:112] == satp_asid) | tlb_sp[10][63]) & (tlb_sp[10][2:0] == 3'h1));
assign tlb_hit[28]          =   (tlb_sp_valid[11] & (tlb_sp[11][57:40] == vaddr[38:21]) & ((tlb_sp[11][127:112] == satp_asid) | tlb_sp[11][63]) & (tlb_sp[11][2:0] == 3'h1));
assign tlb_hit[29]          =   (tlb_sp_valid[12] & (tlb_sp[12][57:40] == vaddr[38:21]) & ((tlb_sp[12][127:112] == satp_asid) | tlb_sp[12][63]) & (tlb_sp[12][2:0] == 3'h1));
assign tlb_hit[30]          =   (tlb_sp_valid[13] & (tlb_sp[13][57:40] == vaddr[38:21]) & ((tlb_sp[13][127:112] == satp_asid) | tlb_sp[13][63]) & (tlb_sp[13][2:0] == 3'h1));
assign tlb_hit[31]          =   (tlb_sp_valid[14] & (tlb_sp[14][57:40] == vaddr[38:21]) & ((tlb_sp[14][127:112] == satp_asid) | tlb_sp[14][63]) & (tlb_sp[14][2:0] == 3'h1));
assign tlb_hit[32]          =   (tlb_sp_valid[15] & (tlb_sp[15][57:40] == vaddr[38:21]) & ((tlb_sp[15][127:112] == satp_asid) | tlb_sp[15][63]) & (tlb_sp[15][2:0] == 3'h1));

assign tlb_sel              =   ({128{tlb_hit[0 ]}} & tlb_4K[vaddr[17:12]] ) | 
                                ({128{tlb_hit[1 ]}} & tlb_sp[0 ]) | 
                                ({128{tlb_hit[2 ]}} & tlb_sp[1 ]) | 
                                ({128{tlb_hit[3 ]}} & tlb_sp[2 ]) | 
                                ({128{tlb_hit[4 ]}} & tlb_sp[3 ]) | 
                                ({128{tlb_hit[5 ]}} & tlb_sp[4 ]) | 
                                ({128{tlb_hit[6 ]}} & tlb_sp[5 ]) | 
                                ({128{tlb_hit[7 ]}} & tlb_sp[6 ]) | 
                                ({128{tlb_hit[8 ]}} & tlb_sp[7 ]) | 
                                ({128{tlb_hit[9 ]}} & tlb_sp[8 ]) | 
                                ({128{tlb_hit[10]}} & tlb_sp[9 ]) | 
                                ({128{tlb_hit[11]}} & tlb_sp[10]) | 
                                ({128{tlb_hit[12]}} & tlb_sp[11]) | 
                                ({128{tlb_hit[13]}} & tlb_sp[12]) | 
                                ({128{tlb_hit[14]}} & tlb_sp[13]) | 
                                ({128{tlb_hit[15]}} & tlb_sp[14]) | 
                                ({128{tlb_hit[16]}} & tlb_sp[15]) | 
                                ({128{tlb_hit[17]}} & tlb_sp[0 ]) | 
                                ({128{tlb_hit[18]}} & tlb_sp[1 ]) | 
                                ({128{tlb_hit[19]}} & tlb_sp[2 ]) | 
                                ({128{tlb_hit[20]}} & tlb_sp[3 ]) | 
                                ({128{tlb_hit[21]}} & tlb_sp[4 ]) | 
                                ({128{tlb_hit[22]}} & tlb_sp[5 ]) | 
                                ({128{tlb_hit[23]}} & tlb_sp[6 ]) | 
                                ({128{tlb_hit[24]}} & tlb_sp[7 ]) | 
                                ({128{tlb_hit[25]}} & tlb_sp[8 ]) | 
                                ({128{tlb_hit[26]}} & tlb_sp[9 ]) | 
                                ({128{tlb_hit[27]}} & tlb_sp[10]) | 
                                ({128{tlb_hit[28]}} & tlb_sp[11]) | 
                                ({128{tlb_hit[29]}} & tlb_sp[12]) | 
                                ({128{tlb_hit[30]}} & tlb_sp[13]) | 
                                ({128{tlb_hit[31]}} & tlb_sp[14]) | 
                                ({128{tlb_hit[32]}} & tlb_sp[15]) | 
                                ({128{(stage_status == SEND_ADDR)}} & pte_reg);

assign page_4K_wen           = page_wen & (pte[2:0] == 3'h0);
assign page_sp_wen           = page_wen & (pte[2:0] != 3'h0);

plru_16 u_plru_sp(
	.clk      	( clk                                   ),
	.rst_n    	( rst_n                                 ),
	.hit      	( mmu_fifo_valid & (|tlb_hit[32:1])     ),
	.hit_sel  	( tlb_hit[16:1] |   tlb_hit[32:17]      ),
	.plru_wen 	( page_sp_wen                           ),
	.wen      	( tlb_sp_wen                            )
);
//**********************************************************************************************
//!fsm
always @(posedge clk or negedge rst_n) begin
    if(!rst_n)begin
        stage_status        <= IDLE;
        dmmu_miss_valid_reg <= 1'b0;
    end
    else if(flush_flag)begin
        stage_status        <= IDLE;
        dmmu_miss_valid_reg <= 1'b0;
    end
    else begin
        case (stage_status)
            IDLE: begin
                if(mmu_fifo_valid & (!stage_jump_mmu) & (!(|tlb_hit)) & (vaddr[63:39] == {25{vaddr[38]}}))begin
                    stage_status        <= SUBMIT_REQ;
                    dmmu_miss_valid_reg <= 1'b1;
                end
            end
            SUBMIT_REQ: begin
                if(dmmu_miss_valid & dmmu_miss_ready)begin
                    stage_status        <= WAIT_RESP;
                    dmmu_miss_valid_reg <= 1'b0;
                end
            end
            WAIT_RESP: begin
                if(pte_valid & pte_ready_d)begin
                    stage_status        <= SEND_ADDR;
                end
            end
            SEND_ADDR: begin
                if(paddr_valid & paddr_ready)begin
                    stage_status        <= IDLE;
                end
            end
            default: begin
                stage_status        <= IDLE;
                dmmu_miss_valid_reg <= 1'b0;
            end
        endcase
    end
end
FF_D_without_asyn_rst #(128)  u_pte            (clk,pte_valid & pte_ready_d,pte,pte_reg);
FF_D_without_asyn_rst #(1)    u_pte_error      (clk,pte_valid & pte_ready_d,pte_error,pte_error_reg);
assign page_wen         = (stage_status == WAIT_RESP) & (pte_valid) & (pte_ready_d);
//**********************************************************************************************
//?output
assign dmmu_miss_valid  = dmmu_miss_valid_reg;
assign vaddr_d          = vaddr[63:0];
assign pte_ready_d      = 1'b1;
assign mmu_fifo_ready   = ((stage_jump_mmu | (|tlb_hit) | (stage_status == SEND_ADDR) | (vaddr[63:39] != {25{vaddr[38]}})) & mmu_fifo_valid & (paddr_ready | (!paddr_valid)));
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
FF_D_without_asyn_rst #(64)   u_paddr            (clk,mmu_fifo_ready,paddr_out,paddr);
FF_D_without_asyn_rst #(1)    u_paddr_error      (clk,mmu_fifo_ready,paddr_error_out,paddr_error);
assign paddr_out        =   (stage_jump_mmu) ? vaddr[63:0] : 
                            (({64{tlb_sel[2:0] == 3'h0}} & {8'h0, tlb_sel[111:68], vaddr[11:0]}) | 
                            ({64{tlb_sel[2:0] == 3'h1}} & {8'h0, tlb_sel[111:77], vaddr[20:0]}) | 
                            ({64{tlb_sel[2:0] == 3'h2}} & {8'h0, tlb_sel[111:86], vaddr[29:0]}));
//! this page can not read and not Exculte when MXR = 1
//! this page can not write
//! Smode don't access the Umode page data when SUM = 0
//! Umode don't access the Smode page data
//! l2tlb report error
//! vaddr illegel
assign paddr_error_out  =   ((vaddr[63:39] != {25{vaddr[38]}}) | 
                            (((!tlb_sel[59]) & (!(tlb_sel[61] & MXR))) & vaddr[64]) | 
                            ((!tlb_sel[60]) & (!vaddr[64])) | 
                            ((!use_priv[0]) & (!tlb_sel[62])) | 
                            (use_priv[0] & tlb_sel[62] & (!SUM)) | 
                            ((stage_status == SEND_ADDR) & pte_error_reg)) & (!stage_jump_mmu);
endmodule //dmmu
