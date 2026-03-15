module storeaddrUnit
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

    input                                               storeaddrUnit_in_valid,
    output                                              storeaddrUnit_in_ready,
    input  iq_mem_store_addr_in_t                       storeaddrUnit_in,

    input                [wb_width - 1 : 0]             rfwen,
    input  pint_regdest_t[wb_width - 1 : 0]             pwdest,

    // stage0: prepare data
    output pint_regsrc_t                                storeaddrUnit_psrc,
    input  intreg_t                                     storeaddrUnit_psrc_rdata,

    output SQ_entry_ptr_t                               storeaddrUnit_sq_ptr,
    input  store_optype_t                               storeaddrUnit_op,
    input  ls_rob_entry_ptr_t                           storeaddrUnit_rob_ptr,

    // stage1: send to dmmu
    output                                              storeaddrUnit_mmu_valid,
    input                                               storeaddrUnit_mmu_ready,
    output [64:0]                                       storeaddrUnit_vaddr,

    // stage2: recv from dmmu & send addr to outside
    input                                               storeaddrUnit_paddr_valid,
    output                                              storeaddrUnit_paddr_ready,
    input  [63:0]                                       storeaddrUnit_paddr,
    input                                               storeaddrUnit_paddr_error,

    output                                              storeaddrUnit_valid_o,
    input                                               storeaddrUnit_ready_o,
    output                                              storeaddrUnit_addr_misalign_o,
    output                                              storeaddrUnit_page_error_o,
    output                                              storeaddrUnit_check_RAW_o,
    output [63:0]                                       storeaddrUnit_waddr_o,
    output [2:0]                                        storeaddrUnit_wsize_o,
    output ls_rob_entry_ptr_t                           storeaddrUnit_rob_ptr_o,
    output SQ_entry_ptr_t                               storeaddrUnit_sq_ptr_o
);

logic                   out1_valid;
logic                   out1_ready;
iq_mem_store_addr_out_t out1;
struct packed{
    store_optype_t      op;
    intreg_t            src1;
    logic [31:0]        imm;
    SQ_entry_ptr_t      sq_ptr;
    ls_rob_entry_ptr_t  rob_ptr;
}stage1_in;

logic                  stage1_valid;
logic                  stage1_ready;
struct packed{
    store_optype_t      op;
    logic               addr_misalign_flag;
    logic [63:0]        vaddr;
    SQ_entry_ptr_t      sq_ptr;
    ls_rob_entry_ptr_t  rob_ptr;
}stage2_in;

logic                  stage2_valid;
logic                  stage2_ready;

iq_mem_store_addr u_iq_mem_store_addr(
	.clk        	( clk                   ),
	.rst_n      	( rst_n                 ),
	.redirect      	( redirect              ),
	.in_valid   	( storeaddrUnit_in_valid),
	.in_ready   	( storeaddrUnit_in_ready),
	.in         	( storeaddrUnit_in      ),
	.rfwen      	( rfwen                 ),
	.pwdest     	( pwdest                ),
	.out1_valid 	( out1_valid            ),
	.out1_ready 	( out1_ready            ),
	.out1       	( out1                  )
);

//*******************************stage0: to temp storage the preg_data and inst_use data******************************************
// store addr stage0
assign out1_ready = ((!stage1_valid) | stage1_ready);

logic send_valid_stage1;
assign send_valid_stage1 = out1_valid & out1_ready;
FF_D_with_syn_rst #(
    .DATA_LEN 	( 1  ),
    .RST_DATA 	( 0  )
)u_stage1_valid
(
    .clk      	( clk           ),
    .rst_n    	( rst_n         ),
    .syn_rst    ( redirect      ),
    .wen        ( out1_ready    ),
    .data_in  	( out1_valid    ),
    .data_out 	( stage1_valid  )
);

intreg_t stage1_src1;

assign stage1_src1 =   (({64{out1.src1_type == src_reg}}) & storeaddrUnit_psrc_rdata);

FF_D_without_asyn_rst #(9 )             u_stage1_op_o      (clk,send_valid_stage1, storeaddrUnit_op, stage1_in.op);
FF_D_without_asyn_rst #(64)             u_stage1_src1_o    (clk,send_valid_stage1, stage1_src1, stage1_in.src1);
FF_D_without_asyn_rst #(32)             u_stage1_imm_o     (clk,send_valid_stage1, out1.imm, stage1_in.imm);
FF_D_without_asyn_rst #(SQ_entry_w)     u_stage1_sq_ptr_o  (clk,send_valid_stage1, out1.sq_ptr, stage1_in.sq_ptr);
FF_D_without_asyn_rst #(rob_entry_w + 1)u_stage1_rob_ptr_o (clk,send_valid_stage1, storeaddrUnit_rob_ptr, stage1_in.rob_ptr);
assign storeaddrUnit_psrc    = out1.psrc1;
assign storeaddrUnit_sq_ptr  = out1.sq_ptr;
//*******************************stage1: send va to dmmu get resp and check addr misalign******************************************
// store addr stage1
//! TODO 以后可以在这一级加入pmp，pma检查
logic [63:0]    vaddr;
assign vaddr = (stage1_in.src1 + {{32{stage1_in.imm[31]}}, stage1_in.imm});

logic addr_misalign_flag;

assign addr_misalign_flag =    ((store_half  (stage1_in.op) & (vaddr[0]   != 1'b0)) |   
                                (store_word  (stage1_in.op) & (vaddr[1:0] != 2'b0)) |   
                                (store_double(stage1_in.op) & (vaddr[2:0] != 3'b0))  
                                );

assign stage1_ready = ((storeaddrUnit_mmu_valid & storeaddrUnit_mmu_ready) | addr_misalign_flag);

logic send_valid_stage2;
assign send_valid_stage2 = stage1_valid & stage1_ready;
FF_D_with_syn_rst #(
    .DATA_LEN   ( 1  ),
    .RST_DATA   ( 0  )
)u_stage2_valid
(
    .clk        ( clk                               ),
    .rst_n      ( rst_n                             ),
    .syn_rst    ( redirect                          ),
    .wen        ( ((!stage2_valid) | stage2_ready)  ),
    .data_in    ( send_valid_stage2                 ),
    .data_out   ( stage2_valid                      )
);

assign storeaddrUnit_mmu_valid  = (stage1_valid & ((!stage2_valid) | stage2_ready) & (!addr_misalign_flag));
assign storeaddrUnit_vaddr      = {1'b0, vaddr};

FF_D_without_asyn_rst #(9 )             u_stage2_op_o      (clk,send_valid_stage2, stage1_in.op, stage2_in.op);
FF_D_without_asyn_rst #(1 )             u_stage2_misalign_o(clk,send_valid_stage2, addr_misalign_flag, stage2_in.addr_misalign_flag);
FF_D_without_asyn_rst #(64)             u_stage2_vaddr_o   (clk,send_valid_stage2, vaddr, stage2_in.vaddr);
FF_D_without_asyn_rst #(SQ_entry_w)     u_stage2_sq_ptr_o  (clk,send_valid_stage2, stage1_in.sq_ptr, stage2_in.sq_ptr);
FF_D_without_asyn_rst #(rob_entry_w + 1)u_stage2_rob_ptr_o (clk,send_valid_stage2, stage1_in.rob_ptr, stage2_in.rob_ptr);
//*******************************stage2: send result to store queue******************************************
// store addr stage2
assign stage2_ready = storeaddrUnit_valid_o & storeaddrUnit_ready_o;

assign storeaddrUnit_paddr_ready        = storeaddrUnit_ready_o;
assign storeaddrUnit_valid_o            = ((storeaddrUnit_paddr_valid | storeaddrUnit_addr_misalign_o) & stage2_valid);

assign storeaddrUnit_addr_misalign_o    = stage2_in.addr_misalign_flag;
assign storeaddrUnit_page_error_o       = storeaddrUnit_paddr_error;
assign storeaddrUnit_check_RAW_o        = (storeaddrUnit_valid_o & storeaddrUnit_ready_o);
assign storeaddrUnit_waddr_o            = (storeaddrUnit_addr_misalign_o | storeaddrUnit_page_error_o) ? stage2_in.vaddr : storeaddrUnit_paddr;
assign storeaddrUnit_sq_ptr_o           = stage2_in.sq_ptr;
assign storeaddrUnit_wsize_o            = store_size(stage2_in.op);
assign storeaddrUnit_rob_ptr_o          = stage2_in.rob_ptr;
//*******************************************************************************************************************************

endmodule //storeaddrUnit
