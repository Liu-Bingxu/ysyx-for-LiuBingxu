module loadUnit
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

    input                                               loadUnit_in_valid,
    output                                              loadUnit_in_ready,
    input  iq_mem_load_in_t                             loadUnit_in,

    input                [wb_width - 1 : 0]             rfwen,
    input  pint_regdest_t[wb_width - 1 : 0]             pwdest,

    // stage0: prepare data
    output pint_regsrc_t                                loadUnit_psrc,
    input  intreg_t                                     loadUnit_psrc_rdata,

    // stage1: send to dmmu
    output                                              loadUnit_mmu_valid,
    input                                               loadUnit_mmu_ready,
    output [64:0]                                       loadUnit_vaddr,

    // stage2: recv from dmmu & send addr to outside, enqueue LoadQueueRAW
    input                                               loadUnit_paddr_valid,
    output                                              loadUnit_paddr_ready,
    input  [63:0]                                       loadUnit_paddr,
    input                                               loadUnit_paddr_error,

    output                                              loadUnit_arvalid,
    input                                               loadUnit_arready,
    output  [2:0]                                       loadUnit_arsize,
    output  [63:0]                                      loadUnit_araddr,
    output ls_rob_entry_ptr_t                           loadUnit_rob_ptr,

    output                                              loadUnit_enq_lqRAW_o,
    output [63:0]                                       loadUnit_raddr_o,
    output [2:0]                                        loadUnit_rsize_o,
    output ls_rob_entry_ptr_t                           loadUnit_enq_rob_ptr_o,
    
    // stage3: send result to rob & regfile
    input                                               loadUnit_rvalid,
    output                                              loadUnit_rready,
    input  [1:0]                                        loadUnit_rresp,
    input  [63:0]                                       loadUnit_rdata,

    output                                              loadUnit_valid_o,
    input                                               loadUnit_ready_o,
    output                                              loadUnit_addr_misalign_o,
    output                                              loadUnit_page_error_o,
    output                                              loadUnit_load_error_o,
    output                                              loadUnit_rfwen_o,
    output pint_regdest_t                               loadUnit_pwdest_o,
    output [63:0]                                       loadUnit_preg_wdata_o,
    output rob_entry_ptr_t                              loadUnit_rob_ptr_o,
    output [63:0]                                       loadUnit_vaddr_o
);

logic                   out1_valid;
logic                	out1_ready;
struct packed{
    load_optype_t       op;
    intreg_t            src1;
    logic [31:0]        imm;
    pint_regdest_t      pwdest;
    ls_rob_entry_ptr_t  rob_ptr;
}stage1_in;
iq_mem_load_out_t       out1;

logic                  stage1_valid;
logic                  stage1_ready;
struct packed{
    load_optype_t       op;
    logic               addr_misalign_flag;
    pint_regdest_t      pwdest;
    ls_rob_entry_ptr_t  rob_ptr;
    logic [63:0]        vaddr;
}stage2_in;

logic                  stage2_valid;
logic                  stage2_ready;
struct packed{
    load_optype_t       op;
    logic               addr_misalign_flag;
    logic               page_error_flag;
    logic [63:0]        paddr;
    pint_regdest_t      pwdest;
    rob_entry_ptr_t     rob_ptr;
    logic [63:0]        vaddr;
}stage3_in;

logic                  stage3_valid;
logic                  stage3_ready;

iq_mem_load u_iq_mem_load(
	.clk        	( clk               ),
	.rst_n      	( rst_n             ),
	.redirect      	( redirect          ),
	.in_valid   	( loadUnit_in_valid ),
	.in_ready   	( loadUnit_in_ready ),
	.in         	( loadUnit_in       ),
	.rfwen      	( rfwen             ),
	.pwdest     	( pwdest            ),
	.out1_valid 	( out1_valid        ),
	.out1_ready 	( out1_ready        ),
	.out1       	( out1              )
);

//*******************************stage0: to temp storage the preg_data and inst_use data******************************************
// load stage0
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

assign stage1_src1 =   (({64{out1.src1_type == src_reg}}) & loadUnit_psrc_rdata);

FF_D_without_asyn_rst #(9 )             u_stage1_op_o      (clk,send_valid_stage1, out1.fuoptype, stage1_in.op);
FF_D_without_asyn_rst #(64)             u_stage1_src1_o    (clk,send_valid_stage1, stage1_src1, stage1_in.src1);
FF_D_without_asyn_rst #(32)             u_stage1_imm_o     (clk,send_valid_stage1, out1.imm, stage1_in.imm);
FF_D_without_asyn_rst #(int_preg_width) u_stage1_pwdest_o  (clk,send_valid_stage1, out1.pwdest, stage1_in.pwdest);
FF_D_without_asyn_rst #(rob_entry_w + 1)u_stage1_rob_ptr_o (clk,send_valid_stage1, out1.rob_ptr, stage1_in.rob_ptr);

assign loadUnit_psrc    = out1.psrc1;
//*******************************stage1: send va to dmmu get resp and check addr misalign******************************************
// load stage1
//! TODO 以后可以在这一级加入pmp，pma检查
logic [63:0]    vaddr;
assign vaddr = (stage1_in.src1 + {{32{stage1_in.imm[31]}}, stage1_in.imm});

logic addr_misalign_flag;

assign addr_misalign_flag =    ((load_half  (stage1_in.op) & (vaddr[0]   != 1'b0)) |   
                                (load_word  (stage1_in.op) & (vaddr[1:0] != 2'b0)) |   
                                (load_double(stage1_in.op) & (vaddr[2:0] != 3'b0))  
                                );

assign stage1_ready = ((loadUnit_mmu_valid & loadUnit_mmu_ready) | addr_misalign_flag);

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

assign loadUnit_mmu_valid   = (stage1_valid & ((!stage2_valid) | stage2_ready) & (!addr_misalign_flag));
assign loadUnit_vaddr       = {1'b1, vaddr};

FF_D_without_asyn_rst #(9 )             u_stage2_op_o      (clk,send_valid_stage2, stage1_in.op, stage2_in.op);
FF_D_without_asyn_rst #(1 )             u_stage2_misalign_o(clk,send_valid_stage2, addr_misalign_flag, stage2_in.addr_misalign_flag);
FF_D_without_asyn_rst #(int_preg_width) u_stage2_pwdest_o  (clk,send_valid_stage2, stage1_in.pwdest, stage2_in.pwdest);
FF_D_without_asyn_rst #(rob_entry_w + 1)u_stage2_rob_ptr_o (clk,send_valid_stage2, stage1_in.rob_ptr, stage2_in.rob_ptr);
FF_D_without_asyn_rst #(64)             u_stage2_vaddr_o   (clk,send_valid_stage2, vaddr, stage2_in.vaddr);
//*******************************stage2: send pa to dcache get data and check page error******************************************
// load stage2
assign stage2_ready = loadUnit_paddr_valid & loadUnit_paddr_ready;

logic send_valid_stage3;
assign send_valid_stage3 = stage2_valid & stage2_ready;
FF_D_with_syn_rst #(
    .DATA_LEN   ( 1  ),
    .RST_DATA   ( 0  )
)u_stage3_valid
(
    .clk        ( clk                               ),
    .rst_n      ( rst_n                             ),
    .syn_rst    ( redirect                          ),
    .wen        ( ((!stage3_valid) | stage3_ready)  ),
    .data_in    ( send_valid_stage3                 ),
    .data_out   ( stage3_valid                      )
);

assign loadUnit_paddr_ready = (loadUnit_arready | loadUnit_paddr_error) & ((!stage3_valid) | stage3_ready);
assign loadUnit_arvalid     = loadUnit_paddr_valid & ((!stage3_valid) | stage3_ready) & (!stage2_in.addr_misalign_flag) & (!loadUnit_paddr_error);
assign loadUnit_arsize      = load_size(stage2_in.op);
assign loadUnit_araddr      = loadUnit_paddr;
assign loadUnit_rob_ptr     = stage2_in.rob_ptr;

FF_D_without_asyn_rst #(9 )             u_stage3_op_o      (clk,send_valid_stage3, stage2_in.op, stage3_in.op);
FF_D_without_asyn_rst #(1 )             u_stage3_misalign_o(clk,send_valid_stage3, stage2_in.addr_misalign_flag, stage3_in.addr_misalign_flag);
FF_D_without_asyn_rst #(1 )             u_stage3_perror_o  (clk,send_valid_stage3, loadUnit_paddr_error, stage3_in.page_error_flag);
FF_D_without_asyn_rst #(64)             u_stage3_paddr_o   (clk,send_valid_stage3, loadUnit_paddr, stage3_in.paddr);
FF_D_without_asyn_rst #(int_preg_width) u_stage3_pwdest_o  (clk,send_valid_stage3, stage2_in.pwdest, stage3_in.pwdest);
FF_D_without_asyn_rst #(rob_entry_w)    u_stage3_rob_ptr_o (clk,send_valid_stage3, stage2_in.rob_ptr[rob_entry_w - 1 : 0], stage3_in.rob_ptr);
FF_D_without_asyn_rst #(64)             u_stage3_vaddr_o   (clk,send_valid_stage3, stage2_in.vaddr, stage3_in.vaddr);

assign loadUnit_enq_lqRAW_o     = (loadUnit_arvalid & loadUnit_arready);
assign loadUnit_raddr_o         = loadUnit_paddr;
assign loadUnit_rsize_o         = load_size(stage2_in.op);
assign loadUnit_enq_rob_ptr_o   = stage2_in.rob_ptr;
//*******************************stage3: send result to rob & regfile******************************************
// load stage3
assign stage3_ready = loadUnit_valid_o & loadUnit_ready_o;

logic [63:0] load_data;

memory_load_move u_memory_load_move(
    .pre_data    	( loadUnit_rdata            ),
    .data_offset 	( stage3_in.paddr[2:0]      ),
    .is_byte     	( load_byte(stage3_in.op)   ),
    .is_half     	( load_half(stage3_in.op)   ),
    .is_word     	( load_word(stage3_in.op)   ),
    .is_double   	( load_double(stage3_in.op) ),
    .is_sign     	( load_signed(stage3_in.op) ),
    .data        	( load_data                 )
);

assign loadUnit_rready          = loadUnit_ready_o;
assign loadUnit_valid_o         = (loadUnit_rvalid | loadUnit_addr_misalign_o | loadUnit_page_error_o);

assign loadUnit_addr_misalign_o = stage3_in.addr_misalign_flag;
assign loadUnit_page_error_o    = stage3_in.page_error_flag;
assign loadUnit_load_error_o    = ((loadUnit_rresp != 2'h0) & (!stage3_in.addr_misalign_flag) & (!stage3_in.page_error_flag));
assign loadUnit_rfwen_o         = (!(stage3_in.addr_misalign_flag | stage3_in.page_error_flag | loadUnit_load_error_o));
assign loadUnit_pwdest_o        = stage3_in.pwdest;
assign loadUnit_preg_wdata_o    = load_data;
assign loadUnit_rob_ptr_o       = stage3_in.rob_ptr;
assign loadUnit_vaddr_o         = stage3_in.vaddr;
//*******************************************************************************************************************************


endmodule //loadUnit
