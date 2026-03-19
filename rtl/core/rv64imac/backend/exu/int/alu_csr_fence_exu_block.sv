module alu_csr_fence_exu_block
import decode_pkg::*;
import regfile_pkg::*;
import iq_pkg::*;
import alu_pkg::*;
import csr_pkg::*;
import fence_pkg::*;
import rob_pkg::*;
import frontend_pkg::*;
import core_setting_pkg::*;
(
    input                                               clk,
    input                                               rst_n,

    input                                               redirect,

    output [IQ_W - 1 : 0]                               alu_csr_fence_exu_iq_enq_num,

    input                                               alu_csr_fence_exu_in_valid,
    output                                              alu_csr_fence_exu_in_ready,
    input  iq_csr_in_t                                  alu_csr_fence_exu_in,

    input                [wb_width - 1 : 0]             rfwen,
    input  pint_regdest_t[wb_width - 1 : 0]             pwdest,

    //! TODO 现在采用固定优先级，fence > csr > alu，以后可以采用其他优先级方案
    output pint_regsrc_t [1 : 0]                        alu_csr_fence_exu_psrc,
    input  intreg_t      [1 : 0]                        alu_csr_fence_exu_psrc_rdata,

    output [11:0]                                       csr_index,
    input  [63:0]                                       csr_rdata,
    input  [63:0]                                       mepc,
    input  [63:0]                                       sepc,
    input  [63:0]                                       dpc,

    // fence_i interface
    output logic                                        flush_i_valid,
    input                                               flush_i_ready,
    // sfence_vma interface
    output                                              sflush_vma_valid,

    input  rob_entry_ptr_t                              top_rob_ptr,

    output [FTQ_ENTRY_BIT_NUM - 1 : 0]                  csr_ftq_ptr,
    output [FTQ_ENTRY_BIT_NUM - 1 : 0]                  fence_ftq_ptr,
    /* verilator lint_off UNUSEDSIGNAL */
    input  ftq_entry                                    csr_entry,
    input  ftq_entry                                    fence_entry,
    /* verilator lint_on UNUSEDSIGNAL */

    output                                              alu_csr_fence_exu_valid_o,
    input                                               alu_csr_fence_exu_ready_o,
    output rob_entry_ptr_t                              alu_csr_fence_exu_rob_ptr_o,
    output                                              alu_csr_fence_exu_rfwen_o,
    output                                              alu_csr_fence_exu_csrwen_o,
    output [11:0]                                       alu_csr_fence_exu_csr_index_o,
    output [63:0]                                       alu_csr_fence_exu_csr_wdata_o,
    output pint_regdest_t                               alu_csr_fence_exu_pwdest_o,
    output [63:0]                                       alu_csr_fence_exu_preg_wdata_o,
    output                                              alu_csr_fence_exu_mret_o,
    output                                              alu_csr_fence_exu_sret_o,
    output                                              alu_csr_fence_exu_dret_o,
    output                                              alu_csr_fence_exu_satp_change_o,
    output                                              alu_csr_fence_exu_fence_o,
    output [63:0]                                       alu_csr_fence_exu_next_pc_o
);

logic                  out1_valid;
logic                  out1_ready;
iq_acc_out_t           out1;
logic                  out2_valid;
logic                  out2_ready;
iq_csr_out_t           out2;
logic                  out3_valid;
logic                  out3_ready;
iq_fence_out_t         out3;

logic                  alu_valid_i;
logic                  alu_ready_i;
struct packed {
    alu_optype_t       op;
    logic [63:0]       src1;
    logic [63:0]       src2;
    pint_regdest_t     pwdest;
    rob_entry_ptr_t    rob_ptr;
} alu_in;

logic                  csr_valid_i;
logic                  csr_ready_i;
struct packed {
    csr_optype_t       op;
    logic  [11:0]      csr_index;
    logic  [63:0]      csr_rdata;
    logic  [63:0]      src1;
    logic              inst_rvc;
    logic  [63:0]      pc;
    pint_regdest_t     pwdest;
    logic              rfwen;
    logic              csrwen;
    rob_entry_ptr_t    rob_ptr;
} csr_in;

logic                  fence_valid_i;
logic                  fence_ready_i;
struct packed {
    fence_optype_t     op;
    logic              inst_rvc;
    logic [63:0]       pc;
    rob_entry_ptr_t    rob_ptr;
} fence_in;

logic                  alu_valid_o;
logic                  alu_ready_o;
rob_entry_ptr_t        alu_rob_ptr_o;
pint_regdest_t         alu_pwdest_o;
logic [63:0]           alu_preg_wdata_o;

logic                  csr_valid_o;
logic                  csr_ready_o;
rob_entry_ptr_t        csr_rob_ptr_o;
pint_regdest_t         csr_pwdest_o;
logic                  csr_rfwen_o;
logic                  csr_csrwen_o;
logic [11:0]           csr_index_o;
logic                  csr_mret_o;
logic                  csr_sret_o;
logic                  csr_dret_o;
logic                  csr_satp_change_o;
logic [63:0]           csr_jump_pc_o;
logic [63:0]           csr_preg_wdata_o;
logic [63:0]           csr_wdata_o;

logic                  fence_valid_o;
logic                  fence_ready_o;
rob_entry_ptr_t        fence_rob_ptr_o;
logic [63:0]           fence_addr_o;

iq_csr u_iq_csr(
	.clk         	( clk                           ),
	.rst_n       	( rst_n                         ),
	.redirect       ( redirect                      ),
    .iq_enq_num     ( alu_csr_fence_exu_iq_enq_num  ),
	.in_valid    	( alu_csr_fence_exu_in_valid    ),
	.in_ready    	( alu_csr_fence_exu_in_ready    ),
	.in          	( alu_csr_fence_exu_in          ),
	.top_rob_ptr 	( top_rob_ptr                   ),
	.rfwen       	( rfwen                         ),
	.pwdest      	( pwdest                        ),
	.out1_valid  	( out1_valid                    ),
	.out1_ready  	( out1_ready                    ),
	.out1        	( out1                          ),
	.out2_valid  	( out2_valid                    ),
	.out2_ready  	( out2_ready                    ),
	.out2        	( out2                          ),
	.out3_valid  	( out3_valid                    ),
	.out3_ready  	( out3_ready                    ),
	.out3        	( out3                          )
);

//*******************************stage: to temp storage the preg_data and inst_use data******************************************
// alu stage
assign out1_ready = ((!alu_valid_i) | alu_ready_i) & 
                    ((!out2_valid) | (out2.src1_type != src_reg) | (out1.src1_type != src_reg));

logic send_valid_alu;
assign send_valid_alu = out1_valid & out1_ready;
FF_D_with_syn_rst #(
    .DATA_LEN 	( 1  ),
    .RST_DATA 	( 0  )
)u_alu_valid_i
(
    .clk      	( clk                               ),
    .rst_n    	( rst_n                             ),
    .syn_rst    ( redirect                          ),
    .wen        ( ((!alu_valid_i) | alu_ready_i)    ),
    .data_in  	( send_valid_alu                    ),
    .data_out 	( alu_valid_i                       )
);
intreg_t alu_src1;
intreg_t alu_src2;

assign alu_src1 =   (({64{out1.src1_type == src_reg}}) & alu_csr_fence_exu_psrc_rdata[0]);
assign alu_src2 =   (({64{out1.src2_type == src_reg}}) & alu_csr_fence_exu_psrc_rdata[1]) | 
                    (({64{out1.src2_type == src_imm}}) & {{32{out1.imm[31]}}, out1.imm});

FF_D_without_asyn_rst #(9 )             u_alu_op_o      (clk,send_valid_alu, out1.fuoptype, alu_in.op);
FF_D_without_asyn_rst #(64)             u_alu_src1_o    (clk,send_valid_alu, alu_src1, alu_in.src1);
FF_D_without_asyn_rst #(64)             u_alu_src2_o    (clk,send_valid_alu, alu_src2, alu_in.src2);
FF_D_without_asyn_rst #(int_preg_width) u_alu_pwdest_o  (clk,send_valid_alu, out1.pwdest, alu_in.pwdest);
FF_D_without_asyn_rst #(rob_entry_w)    u_alu_rob_ptr_o (clk,send_valid_alu, out1.rob_ptr, alu_in.rob_ptr);
//*******************************************************************************************************************************
// csr stage
assign out2_ready = ((!csr_valid_i) | csr_ready_i);

logic send_valid_csr;
assign send_valid_csr = out2_valid & out2_ready;
FF_D_with_syn_rst #(
    .DATA_LEN 	( 1  ),
    .RST_DATA 	( 0  )
)u_csr_valid_i
(
    .clk      	( clk                            ),
    .rst_n    	( rst_n                          ),
    .syn_rst    ( redirect                       ),
    .wen        ( ((!csr_valid_i) | csr_ready_i) ),
    .data_in  	( send_valid_csr                 ),
    .data_out 	( csr_valid_i                    )
);
intreg_t csr_src1;

assign csr_src1 =   (({64{out2.src1_type == src_reg}}) & alu_csr_fence_exu_psrc_rdata[0]) | 
                    (({64{out2.src1_type == src_imm}}) & {{(64 - int_preg_width){1'b0}}, out2.psrc1});

FF_D_without_asyn_rst #(9 )             u_csr_op_o      (clk,send_valid_csr, out2.fuoptype, csr_in.op);
FF_D_without_asyn_rst #(12)             u_csr_index_o   (clk,send_valid_csr, out2.csr_index, csr_in.csr_index);
FF_D_without_asyn_rst #(64)             u_csr_rdata_o   (clk,send_valid_csr, csr_rdata, csr_in.csr_rdata);
FF_D_without_asyn_rst #(64)             u_csr_src1_o    (clk,send_valid_csr, csr_src1, csr_in.src1);
FF_D_without_asyn_rst #(1 )             u_csr_rvc_o     (clk,send_valid_csr, out2.rvc_flag, csr_in.inst_rvc);
FF_D_without_asyn_rst #(64)             u_csr_pc_o      (clk,send_valid_csr, (csr_entry.start_pc + {{(64 - BLOCK_BIT_NUM){1'b0}}, out2.inst_offset}), csr_in.pc);
FF_D_without_asyn_rst #(int_preg_width) u_csr_pwdest_o  (clk,send_valid_csr, out2.pwdest, csr_in.pwdest);
FF_D_without_asyn_rst #(1 )             u_csr_rfwen_o   (clk,send_valid_csr, out2.rfwen, csr_in.rfwen);
FF_D_without_asyn_rst #(1 )             u_csr_csrwen_o  (clk,send_valid_csr, out2.csrwen, csr_in.csrwen);
FF_D_without_asyn_rst #(rob_entry_w)    u_csr_rob_ptr_o (clk,send_valid_csr, out2.rob_ptr, csr_in.rob_ptr);
//*******************************************************************************************************************************
// fence stage
assign out3_ready = ((!fence_valid_i) | fence_ready_i);

logic send_valid_fence;
assign send_valid_fence = out3_valid & out3_ready;
FF_D_with_syn_rst #(
    .DATA_LEN 	( 1  ),
    .RST_DATA 	( 0  )
)u_fence_valid_i
(
    .clk      	( clk                               ),
    .rst_n    	( rst_n                             ),
    .syn_rst    ( redirect                          ),
    .wen        ( ((!fence_valid_i) | fence_ready_i)),
    .data_in  	( send_valid_fence                  ),
    .data_out 	( fence_valid_i                     )
);

FF_D_without_asyn_rst #(9 )             u_fence_op_o      (clk,send_valid_fence, out3.fuoptype, fence_in.op);
FF_D_without_asyn_rst #(1 )             u_fence_rvc_o     (clk,send_valid_fence, out3.rvc_flag, fence_in.inst_rvc);
FF_D_without_asyn_rst #(64)             u_fence_pc_o      (clk,send_valid_fence, (fence_entry.start_pc + {{(64 - BLOCK_BIT_NUM){1'b0}}, out3.inst_offset}), fence_in.pc);
FF_D_without_asyn_rst #(rob_entry_w)    u_fence_rob_ptr_o (clk,send_valid_fence, out3.rob_ptr, fence_in.rob_ptr);
//*******************************************************************************************************************************

Alu_fu u_Alu_fu(
	.clk              	( clk               ),
	.rst_n            	( rst_n             ),
	.redirect           ( redirect          ),
	.alu_valid_i      	( alu_valid_i       ),
	.alu_ready_i      	( alu_ready_i       ),
	.op               	( alu_in.op         ),
	.src1             	( alu_in.src1       ),
	.src2             	( alu_in.src2       ),
	.pwdest           	( alu_in.pwdest     ),
	.rob_ptr          	( alu_in.rob_ptr    ),
	.alu_valid_o      	( alu_valid_o       ),
	.alu_ready_o      	( alu_ready_o       ),
	.alu_rob_ptr_o    	( alu_rob_ptr_o     ),
	.alu_pwdest_o     	( alu_pwdest_o      ),
	.alu_preg_wdata_o 	( alu_preg_wdata_o  )
);

Csr_fu u_Csr_fu(
	.clk              	( clk               ),
	.rst_n            	( rst_n             ),
	.redirect           ( redirect          ),
	.csr_valid_i      	( csr_valid_i       ),
	.csr_ready_i      	( csr_ready_i       ),
	.op               	( csr_in.op         ),
	.csr_index        	( csr_in.csr_index  ),
	.csr_rdata        	( csr_in.csr_rdata  ),
	.src1             	( csr_in.src1       ),
	.mepc             	( mepc              ),
	.sepc             	( sepc              ),
	.dpc              	( dpc               ),
	.pc              	( csr_in.pc         ),
	.inst_rvc           ( csr_in.inst_rvc   ),
	.pwdest           	( csr_in.pwdest     ),
	.rfwen            	( csr_in.rfwen      ),
	.csrwen           	( csr_in.csrwen     ),
	.rob_ptr          	( csr_in.rob_ptr    ),
	.csr_valid_o      	( csr_valid_o       ),
	.csr_ready_o      	( csr_ready_o       ),
	.csr_rob_ptr_o    	( csr_rob_ptr_o     ),
	.csr_pwdest_o     	( csr_pwdest_o      ),
	.csr_rfwen_o      	( csr_rfwen_o       ),
	.csr_csrwen_o     	( csr_csrwen_o      ),
    .csr_index_o        ( csr_index_o       ),
	.csr_mret_o       	( csr_mret_o        ),
	.csr_sret_o       	( csr_sret_o        ),
	.csr_dret_o       	( csr_dret_o        ),
	.csr_satp_change_o  ( csr_satp_change_o ),
	.csr_jump_pc_o    	( csr_jump_pc_o     ),
	.csr_preg_wdata_o 	( csr_preg_wdata_o  ),
	.csr_wdata_o      	( csr_wdata_o       )
);

Fence_fu u_Fence_fu(
	.clk              	( clk               ),
	.rst_n            	( rst_n             ),
	.flush_i_valid    	( flush_i_valid     ),
	.flush_i_ready    	( flush_i_ready     ),
	.sflush_vma_valid 	( sflush_vma_valid  ),
	.fence_valid_i    	( fence_valid_i     ),
	.fence_ready_i    	( fence_ready_i     ),
	.op               	( fence_in.op       ),
	.inst_rvc         	( fence_in.inst_rvc ),
	.pc               	( fence_in.pc       ),
	.rob_ptr          	( fence_in.rob_ptr  ),
	.fence_valid_o    	( fence_valid_o     ),
	.fence_ready_o    	( fence_ready_o     ),
	.fence_rob_ptr_o  	( fence_rob_ptr_o   ),
	.fence_addr_o     	( fence_addr_o      )
);


assign csr_ftq_ptr   = out2.ftq_ptr;
assign fence_ftq_ptr = out3.ftq_ptr;

assign alu_csr_fence_exu_psrc[0]  = (out2_valid & (out2.src1_type == src_reg)) ? out2.psrc1 : out1.psrc1;
assign alu_csr_fence_exu_psrc[1]  = out1.psrc2;

assign csr_index                  = out2.csr_index;

assign alu_ready_o              = (alu_csr_fence_exu_ready_o & (!fence_valid_o) & (!csr_valid_o));
assign csr_ready_o              = (alu_csr_fence_exu_ready_o & (!fence_valid_o));
assign fence_ready_o            = (alu_csr_fence_exu_ready_o);

assign alu_csr_fence_exu_valid_o      = (alu_valid_o | csr_valid_o | fence_valid_o);
assign alu_csr_fence_exu_rob_ptr_o    = (fence_valid_o ? fence_rob_ptr_o    : (csr_valid_o ? csr_rob_ptr_o    : alu_rob_ptr_o    ));
assign alu_csr_fence_exu_rfwen_o      = (fence_valid_o ? 0                  : (csr_valid_o ? csr_rfwen_o      : 1'b1             ));
assign alu_csr_fence_exu_csrwen_o     = (fence_valid_o ? 0                  : (csr_valid_o ? csr_csrwen_o     : 1'b0             ));
assign alu_csr_fence_exu_csr_index_o  = (fence_valid_o ? 0                  : (csr_valid_o ? csr_index_o      : 0                ));
assign alu_csr_fence_exu_csr_wdata_o  = (fence_valid_o ? 0                  : (csr_valid_o ? csr_wdata_o      : 0                ));
assign alu_csr_fence_exu_pwdest_o     = (fence_valid_o ? 0                  : (csr_valid_o ? csr_pwdest_o     : alu_pwdest_o     ));
assign alu_csr_fence_exu_preg_wdata_o = (fence_valid_o ? 0                  : (csr_valid_o ? csr_preg_wdata_o : alu_preg_wdata_o ));
assign alu_csr_fence_exu_mret_o       = (fence_valid_o ? 0                  : (csr_valid_o ? csr_mret_o       : 1'b0             ));
assign alu_csr_fence_exu_sret_o       = (fence_valid_o ? 0                  : (csr_valid_o ? csr_sret_o       : 1'b0             ));
assign alu_csr_fence_exu_dret_o       = (fence_valid_o ? 0                  : (csr_valid_o ? csr_dret_o       : 1'b0             ));
assign alu_csr_fence_exu_fence_o      = (fence_valid_o ? 1'b1               : (csr_valid_o ? 1'b0             : 1'b0             ));
assign alu_csr_fence_exu_satp_change_o= (fence_valid_o ? 1'b0               : (csr_valid_o ? csr_satp_change_o: 1'b0             ));
assign alu_csr_fence_exu_next_pc_o    = (fence_valid_o ? fence_addr_o       : (csr_valid_o ? csr_jump_pc_o    : 0                ));


endmodule //alu_csr_fence_exu_block
