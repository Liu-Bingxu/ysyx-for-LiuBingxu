module atomicUnit
import decode_pkg::*;
import regfile_pkg::*;
import rob_pkg::*;
import iq_pkg::*;
import lsq_pkg::*;
import mem_pkg::*;
import core_setting_pkg::*;
(
    input                                               clk,
    input                                               rst_n,

    input                                               redirect,

    input  rob_entry_ptr_t                              top_rob_ptr,

    input                                               atomicUnit_in_valid,
    output                                              atomicUnit_in_ready,
    input  iq_mem_atomic_in_t                           atomicUnit_in,

    output                                              stomic_running,

    // stage0: prepare data
    output pint_regsrc_t[1 : 0]                         atomicUnit_psrc,
    input  intreg_t     [1 : 0]                         atomicUnit_psrc_rdata,

    // stage1: invalid store buffer
    output                                              atomicUnit_invalid_sb_valid,
    input                                               atomicUnit_invalid_sb_ready,

    // stage2: send to dmmu
    output                                              atomicUnit_mmu_valid,
    input                                               atomicUnit_mmu_ready,
    output [64:0]                                       atomicUnit_vaddr,

    // stage3: recv from dmmu
    input                                               atomicUnit_paddr_valid,
    output                                              atomicUnit_paddr_ready,
    input  [63:0]                                       atomicUnit_paddr,
    input                                               atomicUnit_paddr_error,

    // stage4: send addr to dcache
    output                                              atomicUnit_arvalid,
    input                                               atomicUnit_arready,
    output  [2:0]                                       atomicUnit_arsize,
    output  [63:0]                                      atomicUnit_araddr,
    
    // stage5: recv data from dcache
    input                                               atomicUnit_rvalid,
    output                                              atomicUnit_rready,
    input  [1:0]                                        atomicUnit_rresp,
    input  [63:0]                                       atomicUnit_rdata,

    // stage6: send addr and data to dcache
    output                                              atomicUnit_awvalid,
    input                                               atomicUnit_awready,
    output  [2:0]                                       atomicUnit_awsize,
    output  [63:0]                                      atomicUnit_awaddr,

    output                                              atomicUnit_wvalid,
    input                                               atomicUnit_wready,
    output [7:0]                                        atomicUnit_wstrb,
    output [63:0]                                       atomicUnit_wdata,

    // stage7: get resp from dcache
    input                                               atomicUnit_bvalid,
    output                                              atomicUnit_bready,
    input  [1:0]                                        atomicUnit_bresp,

    // stage8: send reult to rob & regfile
    output                                              atomicUnit_valid_o,
    input                                               atomicUnit_ready_o,
    output                                              atomicUnit_ld_addr_misalign_o,
    output                                              atomicUnit_st_addr_misalign_o,
    output                                              atomicUnit_ld_page_error_o,
    output                                              atomicUnit_st_page_error_o,
    output                                              atomicUnit_load_error_o,
    output                                              atomicUnit_store_error_o,
    output rob_entry_ptr_t                              atomicUnit_rob_ptr_o,
    output [63:0]                                       atomic_vaddr_o,
    output                                              atomicUnit_rfwen_o,
    output pint_regdest_t                               atomicUnit_pwdest_o,
    output [63:0]                                       atomicUnit_preg_wdata_o
);

logic               out1_valid;
logic               out1_ready;
iq_mem_atomic_out_t out1;

amo_optype_t        op;
intreg_t            src1;
intreg_t            src2;
logic [31:0]        imm;
logic               rfwen;
pint_regdest_t      pwdest;
rob_entry_ptr_t     rob_ptr;

iq_mem_atomic u_iq_mem_atomic(
	.clk        	( clk                   ),
	.rst_n      	( rst_n                 ),
	.redirect      	( redirect              ),
    .top_rob_ptr    ( top_rob_ptr           ),
	.in_valid   	( atomicUnit_in_valid   ),
	.in_ready   	( atomicUnit_in_ready   ),
	.in         	( atomicUnit_in         ),
	.out1_valid 	( out1_valid            ),
	.out1_ready 	( out1_ready            ),
	.out1       	( out1                  )
);

assign out1_ready = 1'b1;

logic send_valid_stage1;
assign send_valid_stage1 = out1_valid & out1_ready;
intreg_t stage1_src1;
intreg_t stage1_src2;

assign stage1_src1 =   (({64{out1.src1_type == src_reg}}) & atomicUnit_psrc_rdata[0]);
assign stage1_src2 =   (({64{out1.src2_type == src_reg}}) & atomicUnit_psrc_rdata[1]);

FF_D_without_asyn_rst #(9 )             u_stage1_op_o      (clk,send_valid_stage1, out1.fuoptype, op);
FF_D_without_asyn_rst #(64)             u_stage1_src1_o    (clk,send_valid_stage1, stage1_src1, src1);
FF_D_without_asyn_rst #(64)             u_stage1_src2_o    (clk,send_valid_stage1, stage1_src2, src2);
FF_D_without_asyn_rst #(32)             u_stage1_imm_o     (clk,send_valid_stage1, out1.imm, imm);
FF_D_without_asyn_rst #(1 )             u_stage1_rfwen_o   (clk,send_valid_stage1, out1.rfwen, rfwen);
FF_D_without_asyn_rst #(int_preg_width) u_stage1_pwdest_o  (clk,send_valid_stage1, out1.pwdest, pwdest);
FF_D_without_asyn_rst #(rob_entry_w)    u_stage1_rob_ptr_o (clk,send_valid_stage1, out1.rob_ptr, rob_ptr);

assign atomicUnit_psrc[0] = out1.psrc1;
assign atomicUnit_psrc[1] = out1.psrc2;

enum logic [3:0] {  
    atomic_IDLE         = 4'h0,
    atomic_INVALID_SB   = 4'h1,
    atomic_S_VA         = 4'h2,
    atomic_G_PA         = 4'h3,
    atomic_S_PA_R       = 4'h4,
    atomic_G_DATA       = 4'h5,
    atomic_S_PA_D_W     = 4'h6,
    atomic_S_PA_W       = 4'h7,
    atomic_S_D_W        = 4'h8,
    atomic_G_Resp_W     = 4'h9,
    atomic_S_DATA       = 4'hA
} atomic_fsm;

logic [63:0]    vaddr;
logic [63:0]    paddr;
logic [63:0]    load_data;
logic [63:0]    preg_wdata;
logic [1:0]     load_resp;
logic [1:0]     store_resp;
assign vaddr = src1 + {{32{imm[31]}}, imm};
logic addr_misalign_flag;
logic addr_uncache_flag;
logic page_error;
logic paddr_access_error;

assign addr_misalign_flag =    ((atomic_word  (op) & (vaddr[1:0] != 2'b0)) |   
                                (atomic_double(op) & (vaddr[2:0] != 3'b0))  
                                );

assign addr_uncache_flag  = (!addrcache(atomicUnit_paddr));

always_ff @(posedge clk or negedge rst_n) begin
    if(!rst_n)begin
        atomic_fsm <= atomic_IDLE;
    end
    else begin
        case (atomic_fsm)
            atomic_IDLE: begin
                if(send_valid_stage1)begin
                    atomic_fsm <= atomic_INVALID_SB;
                end
            end
            atomic_INVALID_SB: begin
                if(atomicUnit_invalid_sb_valid & atomicUnit_invalid_sb_ready & (!addr_misalign_flag))begin
                    atomic_fsm <= atomic_S_VA;
                end
                else if(atomicUnit_invalid_sb_valid & atomicUnit_invalid_sb_ready & addr_misalign_flag)begin
                    atomic_fsm <= atomic_S_DATA;
                end
            end
            atomic_S_VA: begin
                if(atomicUnit_mmu_valid & atomicUnit_mmu_ready)begin
                    atomic_fsm <= atomic_G_PA;
                end
            end
            atomic_G_PA: begin
                if(atomicUnit_paddr_valid & atomicUnit_paddr_ready & (atomicUnit_paddr_error | addr_uncache_flag))begin
                    atomic_fsm <= atomic_S_DATA;
                end
                else if(atomicUnit_paddr_valid & atomicUnit_paddr_ready & atomic_sc(op))begin
                    atomic_fsm <= atomic_S_PA_D_W;
                end
                else if(atomicUnit_paddr_valid & atomicUnit_paddr_ready)begin
                    atomic_fsm <= atomic_S_PA_R;
                end
            end
            atomic_S_PA_R: begin
                if(atomicUnit_arvalid & atomicUnit_arready)begin
                    atomic_fsm <= atomic_G_DATA;
                end
            end
            atomic_G_DATA: begin
                if(atomicUnit_rvalid & atomicUnit_rready & (atomicUnit_rresp != 2'h1))begin
                    atomic_fsm <= atomic_S_DATA;
                end
                else if(atomicUnit_rvalid & atomicUnit_rready & atomic_lr(op))begin
                    atomic_fsm <= atomic_S_DATA;
                end
                else if(atomicUnit_rvalid & atomicUnit_rready)begin
                    atomic_fsm <= atomic_S_PA_D_W;
                end
            end
            atomic_S_PA_D_W: begin
                if(atomicUnit_awvalid & atomicUnit_awready & atomicUnit_wvalid & atomicUnit_wready)begin
                    atomic_fsm <= atomic_G_Resp_W;
                end
                else if(atomicUnit_awvalid & atomicUnit_awready)begin
                    atomic_fsm <= atomic_S_D_W;
                end
                else if(atomicUnit_wvalid & atomicUnit_wready)begin
                    atomic_fsm <= atomic_S_PA_W;
                end
            end
            atomic_S_PA_W: begin
                if(atomicUnit_awvalid & atomicUnit_awready)begin
                    atomic_fsm <= atomic_G_Resp_W;
                end
            end
            atomic_S_D_W: begin
                if(atomicUnit_wvalid & atomicUnit_wready)begin
                    atomic_fsm <= atomic_G_Resp_W;
                end
            end
            atomic_G_Resp_W: begin
                if(atomicUnit_bvalid & atomicUnit_bready)begin
                    atomic_fsm <= atomic_S_DATA;
                end
            end
            atomic_S_DATA: begin
                if(atomicUnit_valid_o & atomicUnit_ready_o)begin
                    atomic_fsm <= atomic_IDLE;
                end
            end
            default: begin
                atomic_fsm <= atomic_IDLE;
            end
        endcase
    end
end

assign stomic_running                = ((atomic_fsm != atomic_IDLE) & (atomic_fsm != atomic_INVALID_SB));

assign atomicUnit_invalid_sb_valid   = (atomic_fsm == atomic_INVALID_SB);

assign atomicUnit_mmu_valid          = (atomic_fsm == atomic_S_VA);
assign atomicUnit_vaddr              = {atomic_lr(op), vaddr};

assign atomicUnit_paddr_ready        = 1'b1;
FF_D_without_asyn_rst #(1 )          u_page_error_o   (clk,atomicUnit_paddr_valid & atomicUnit_paddr_ready, atomicUnit_paddr_error, page_error);
FF_D_without_asyn_rst #(1 )          u_pa_access_er_o (clk,atomicUnit_paddr_valid & atomicUnit_paddr_ready, addr_uncache_flag, paddr_access_error);
FF_D_without_asyn_rst #(64)          u_paddr_o        (clk,atomicUnit_paddr_valid & atomicUnit_paddr_ready, atomicUnit_paddr, paddr);

assign atomicUnit_arvalid            = (atomic_fsm == atomic_S_PA_R);
assign atomicUnit_arsize             = atomic_size(op);
assign atomicUnit_araddr             = paddr;

assign atomicUnit_rready             = 1'b1;
FF_D_without_asyn_rst #(2 )          u_load_resp_o    (clk,atomicUnit_rvalid & atomicUnit_rready, atomicUnit_rresp, load_resp);
FF_D_without_asyn_rst #(64)          u_load_data_o    (clk,atomicUnit_rvalid & atomicUnit_rready, atomicUnit_rdata, load_data);

assign atomicUnit_awvalid            = ((atomic_fsm == atomic_S_PA_D_W) | (atomic_fsm == atomic_S_PA_W));
assign atomicUnit_awsize             = atomic_size(op);
assign atomicUnit_awaddr             = paddr;

logic [7:0] word_wstrb, double_wstrb;
always_comb begin
    case (paddr[2:0])
        3'b000: word_wstrb=8'b00001111;
        3'b100: word_wstrb=8'b11110000;
        default: word_wstrb=8'b00000000;
    endcase
end
always_comb begin
    case (paddr[2:0])
        3'b000: double_wstrb=8'b11111111;
        default: double_wstrb=8'b00000000;
    endcase
end
logic [63:0]    atomic_wirte_memory_data;
lsu_alu u_lsu_alu(
    .atomic_read_memory_data  	( load_data                 ),
    .atomic_read_gpr_data     	( src2                      ),
    .atomic_swap    	        ( atomic_swap  (op)         ),
    .atomic_add     	        ( atomic_add   (op)         ),
    .atomic_xor     	        ( atomic_xor   (op)         ),
    .atomic_and     	        ( atomic_and   (op)         ),
    .atomic_or      	        ( atomic_or    (op)         ),
    .atomic_min     	        ( atomic_min   (op)         ),
    .atomic_max     	        ( atomic_max   (op)         ),
    .atomic_minu    	        ( atomic_minu  (op)         ),
    .atomic_maxu    	        ( atomic_maxu  (op)         ),
    .atomic_wirte_memory_data 	( atomic_wirte_memory_data  )
);
assign atomicUnit_wvalid             = ((atomic_fsm == atomic_S_PA_D_W) | (atomic_fsm == atomic_S_D_W));
assign atomicUnit_wstrb              = 8'h0 |
                                        ({8{atomic_word  (op)}} & word_wstrb   ) |
                                        ({8{atomic_double(op)}} & double_wstrb ) ;
memory_store_move u_memory_store_move(
    .pre_data    	( atomic_sc(op) ? src2 : atomic_wirte_memory_data   ),
    .data_offset 	( paddr[2:0]                                        ),
    .data        	( atomicUnit_wdata                                  )
);

assign atomicUnit_bready             = 1'b1;
FF_D_without_asyn_rst #(2 )          u_store_resp_o   (clk,atomicUnit_bvalid & atomicUnit_bready, atomicUnit_bresp, store_resp);

assign atomicUnit_valid_o            = (atomic_fsm == atomic_S_DATA);
assign atomicUnit_ld_addr_misalign_o = (addr_misalign_flag  & ( atomic_lr(op)));
assign atomicUnit_st_addr_misalign_o = (addr_misalign_flag  & (!atomic_lr(op)));
assign atomicUnit_ld_page_error_o    = (page_error          & ( atomic_lr(op)));
assign atomicUnit_st_page_error_o    = (page_error          & (!atomic_lr(op)));
assign atomicUnit_load_error_o       = (((load_resp != 2'h1) | paddr_access_error) & ( atomic_lr(op)));
assign atomicUnit_store_error_o      = ((!atomic_lr(op)) & (paddr_access_error | 
                                        ((store_resp == 2'h0) & (!atomic_sc(op))) | 
                                        ((store_resp == 2'h2)) | ((store_resp == 2'h3)) | 
                                        ((load_resp  != 2'h1) & (!atomic_sc(op)))));
assign atomicUnit_rob_ptr_o          = rob_ptr;
assign atomic_vaddr_o                = vaddr;
assign atomicUnit_rfwen_o            = rfwen & (!atomicUnit_ld_addr_misalign_o) & (!atomicUnit_st_addr_misalign_o) & (!atomicUnit_ld_page_error_o) & 
                                        (!atomicUnit_st_page_error_o) & (!atomicUnit_load_error_o) & (!atomicUnit_store_error_o);
assign atomicUnit_pwdest_o           = pwdest;
memory_load_move u_memory_load_move(
    .pre_data    	( load_data             ),
    .data_offset 	( paddr[2:0]            ),
    .is_byte     	( 1'b0                  ),
    .is_half     	( 1'b0                  ),
    .is_word     	( atomic_word  (op)     ),
    .is_double   	( atomic_double(op)     ),
    .is_sign     	( 1'b1                  ),
    .data        	( preg_wdata            )
);
assign atomicUnit_preg_wdata_o      = atomic_sc(op) ? {63'h0, (store_resp != 2'h1)} : preg_wdata;

endmodule //atomicUnit
