module alu_bru_jump_exu_block
import decode_pkg::*;
import regfile_pkg::*;
import iq_pkg::*;
import alu_pkg::*;
import bru_pkg::*;
import jump_pkg::*;
import rob_pkg::*;
import frontend_pkg::*;
import core_setting_pkg::*;
(
    input                                               clk,
    input                                               rst_n,

    input                                               redirect,

    output [IQ_W - 1 : 0]                               alu_bru_jump_exu_iq_enq_num,

    input                                               alu_bru_jump_exu_in_valid,
    output                                              alu_bru_jump_exu_in_ready,
    input  iq_need_pc_in_t                              alu_bru_jump_exu_in,

    input                [wb_width - 1 : 0]             rfwen,
    input  pint_regdest_t[wb_width - 1 : 0]             pwdest,

    //! TODO 现在采用固定优先级，bru > jump > alu，以后可以采用其他优先级方案
    output pint_regsrc_t [1 : 0]                        alu_bru_jump_exu_psrc,
    input  intreg_t      [1 : 0]                        alu_bru_jump_exu_psrc_rdata,

    output [FTQ_ENTRY_BIT_NUM - 1 : 0]                  bru_ftq_ptr,
    output [FTQ_ENTRY_BIT_NUM - 1 : 0]                  jump_ftq_ptr,
    /* verilator lint_off UNUSEDSIGNAL */
    input  ftq_entry                                    bru_entry,
    input  ftq_entry                                    jump_entry,
    /* verilator lint_on UNUSEDSIGNAL */

    output                                              alu_bru_jump_exu_valid_o,
    input                                               alu_bru_jump_exu_ready_o,
    output rob_entry_ptr_t                              alu_bru_jump_exu_rob_ptr_o,
    output                                              alu_bru_jump_exu_rfwen_o,
    output pint_regdest_t                               alu_bru_jump_exu_pwdest_o,
    output [63:0]                                       alu_bru_jump_exu_preg_wdata_o,
    output                                              alu_bru_jump_exu_token_miss_o,
    output [63:0]                                       alu_bru_jump_exu_next_pc_o
);

logic                  out1_valid;
logic                  out1_ready;
iq_acc_out_t           out1;
logic                  out2_valid;
logic                  out2_ready;
iq_bru_out_t           out2;
logic                  out3_valid;
logic                  out3_ready;
iq_jump_out_t          out3;

logic                  alu_valid_i;
logic                  alu_ready_i;
struct packed {
    alu_optype_t       op;
    logic [63:0]       src1;
    logic [63:0]       src2;
    pint_regdest_t     pwdest;
    rob_entry_ptr_t    rob_ptr;
} alu_in;

logic                  bru_valid_i;
logic                  bru_ready_i;
struct packed {
    bru_optype_t       op;
    logic              fix_token;
    logic              inst_rvc;
    logic  [63:0]      src1;
    logic  [63:0]      src2;
    logic  [63:0]      pc;
    logic  [31:0]      imm;
    rob_entry_ptr_t    rob_ptr;
} bru_in;

logic                  jump_valid_i;
logic                  jump_ready_i;
struct packed {
    jump_optype_t      op;
    logic  [63:0]      token_pc;
    logic              inst_rvc;
    logic  [63:0]      src1;
    logic  [63:0]      pc;
    logic  [31:0]      imm;
    logic              rfwen;
    pint_regdest_t     pwdest;
    rob_entry_ptr_t    rob_ptr;
} jump_in;

logic                  alu_valid_o;
logic                  alu_ready_o;
rob_entry_ptr_t        alu_rob_ptr_o;
pint_regdest_t         alu_pwdest_o;
logic [63:0]           alu_preg_wdata_o;


logic                  bru_valid_o;
logic                  bru_ready_o;
rob_entry_ptr_t        bru_rob_ptr_o;
logic                  bru_token_miss_o;
logic [63:0]           branch_addr_o;

logic                  jump_valid_o;
logic                  jump_ready_o;
rob_entry_ptr_t        jump_rob_ptr_o;
logic                  jump_token_miss_o;
logic                  jump_rfwen_o;
pint_regdest_t         jump_pwdest_o;
logic [63:0]           jump_preg_wdata_o;
logic [63:0]           jump_addr_o;

iq_need_pc u_need_pc(
	.clk        	( clk                           ),
	.rst_n      	( rst_n                         ),
	.redirect      	( redirect                      ),
    .iq_enq_num     ( alu_bru_jump_exu_iq_enq_num   ),
	.in_valid   	( alu_bru_jump_exu_in_valid     ),
	.in_ready   	( alu_bru_jump_exu_in_ready     ),
	.in         	( alu_bru_jump_exu_in           ),
	.rfwen      	( rfwen                         ),
	.pwdest     	( pwdest                        ),
	.out1_valid 	( out1_valid                    ),
	.out1_ready 	( out1_ready                    ),
	.out1       	( out1                          ),
	.out2_valid 	( out2_valid                    ),
	.out2_ready 	( out2_ready                    ),
	.out2       	( out2                          ),
	.out3_valid 	( out3_valid                    ),
	.out3_ready 	( out3_ready                    ),
	.out3       	( out3                          )
);

//*******************************stage: to temp storage the preg_data and inst_use data******************************************
// alu stage
assign out1_ready = ((!alu_valid_i) | alu_ready_i) & 
                    ((!out2_valid) | (
                    ((out2.src1_type != src_reg) | (out1.src1_type != src_reg)) & 
                    ((out2.src2_type != src_reg) | (out1.src2_type != src_reg))
                    )) & 
                    ((!out3_valid) | (out3.src1_type != src_reg) | (out1.src1_type != src_reg));

logic send_valid_alu;
assign send_valid_alu = out1_valid & out1_ready;
FF_D_with_syn_rst #(
    .DATA_LEN 	( 1  ),
    .RST_DATA 	( 0  )
)u_alu_valid_i
(
    .clk      	( clk           ),
    .rst_n    	( rst_n         ),
    .syn_rst    ( redirect      ),
    .wen        ( out1_ready    ),
    .data_in  	( out1_valid    ),
    .data_out 	( alu_valid_i   )
);
intreg_t alu_src1;
intreg_t alu_src2;

assign alu_src1 =   (({64{out1.src1_type == src_reg}}) & alu_bru_jump_exu_psrc_rdata[0]);
assign alu_src2 =   (({64{out1.src2_type == src_reg}}) & alu_bru_jump_exu_psrc_rdata[1]) | 
                    (({64{out1.src2_type == src_imm}}) & {{32{out1.imm[31]}}, out1.imm});

FF_D_without_asyn_rst #(9 )             u_alu_op_o      (clk,send_valid_alu, out1.fuoptype, alu_in.op);
FF_D_without_asyn_rst #(64)             u_alu_src1_o    (clk,send_valid_alu, alu_src1, alu_in.src1);
FF_D_without_asyn_rst #(64)             u_alu_src2_o    (clk,send_valid_alu, alu_src2, alu_in.src2);
FF_D_without_asyn_rst #(int_preg_width) u_alu_pwdest_o  (clk,send_valid_alu, out1.pwdest, alu_in.pwdest);
FF_D_without_asyn_rst #(rob_entry_w)    u_alu_rob_ptr_o (clk,send_valid_alu, out1.rob_ptr, alu_in.rob_ptr);
//*******************************************************************************************************************************
// bru stage
assign out2_ready = ((!bru_valid_i) | bru_ready_i);

logic send_valid_bru;
assign send_valid_bru = out2_valid & out2_ready;
FF_D_with_syn_rst #(
    .DATA_LEN 	( 1  ),
    .RST_DATA 	( 0  )
)u_bru_valid_i
(
    .clk      	( clk                            ),
    .rst_n    	( rst_n                          ),
    .syn_rst    ( redirect                       ),
    .wen        ( ((!bru_valid_i) | bru_ready_i) ),
    .data_in  	( send_valid_bru                 ),
    .data_out 	( bru_valid_i                    )
);
intreg_t bru_src1;
intreg_t bru_src2;

assign bru_src1 =   (({64{out2.src1_type == src_reg}}) & alu_bru_jump_exu_psrc_rdata[0]);
assign bru_src2 =   (({64{out2.src2_type == src_reg}}) & alu_bru_jump_exu_psrc_rdata[1]);

FF_D_without_asyn_rst #(9 )             u_bru_op_o      (clk,send_valid_bru, out2.fuoptype, bru_in.op);
FF_D_without_asyn_rst #(1 )             u_bru_token_o   (clk,send_valid_bru, (out2.end_flag & bru_entry.token), bru_in.fix_token);
FF_D_without_asyn_rst #(1 )             u_bru_rvc_o     (clk,send_valid_bru, out2.rvc_flag, bru_in.inst_rvc);
FF_D_without_asyn_rst #(64)             u_bru_src1_o    (clk,send_valid_bru, bru_src1, bru_in.src1);
FF_D_without_asyn_rst #(64)             u_bru_src2_o    (clk,send_valid_bru, bru_src2, bru_in.src2);
FF_D_without_asyn_rst #(64)             u_bru_pc_o      (clk,send_valid_bru, (bru_entry.start_pc + {{(64 - BLOCK_BIT_NUM){1'b0}}, out2.inst_offset}), bru_in.pc);
FF_D_without_asyn_rst #(32)             u_bru_imm_o     (clk,send_valid_bru, out2.imm, bru_in.imm);
FF_D_without_asyn_rst #(rob_entry_w)    u_bru_rob_ptr_o (clk,send_valid_bru, out2.rob_ptr, bru_in.rob_ptr);
//*******************************************************************************************************************************
// jump stage
assign out3_ready = ((!jump_valid_i) | jump_ready_i) & 
                    ((!out2_valid) | (out2.src1_type != src_reg) | (out3.src1_type != src_reg));

logic send_valid_jump;
assign send_valid_jump = out3_valid & out3_ready;
FF_D_with_syn_rst #(
    .DATA_LEN 	( 1  ),
    .RST_DATA 	( 0  )
)u_jump_valid_i
(
    .clk      	( clk                               ),
    .rst_n    	( rst_n                             ),
    .syn_rst    ( redirect                          ),
    .wen        ( ((!jump_valid_i) | jump_ready_i)  ),
    .data_in  	( send_valid_jump                   ),
    .data_out 	( jump_valid_i                      )
);
intreg_t jump_src1;

assign jump_src1 =   (({64{out3.src1_type == src_reg}}) & alu_bru_jump_exu_psrc_rdata[0]);

FF_D_without_asyn_rst #(9 )             u_jump_op_o      (clk,send_valid_jump, out3.fuoptype, jump_in.op);
FF_D_without_asyn_rst #(64)             u_jump_token_pc_o(clk,send_valid_jump, jump_entry.next_pc, jump_in.token_pc);
FF_D_without_asyn_rst #(1 )             u_jump_rvc_o     (clk,send_valid_jump, out3.rvc_flag, jump_in.inst_rvc);
FF_D_without_asyn_rst #(64)             u_jump_src1_o    (clk,send_valid_jump, jump_src1, jump_in.src1);
FF_D_without_asyn_rst #(64)             u_jump_pc_o      (clk,send_valid_jump, (jump_entry.start_pc + {{(64 - BLOCK_BIT_NUM){1'b0}}, out3.inst_offset}), jump_in.pc);
FF_D_without_asyn_rst #(32)             u_jump_imm_o     (clk,send_valid_jump, out3.imm, jump_in.imm);
FF_D_without_asyn_rst #(1 )             u_jump_rfwen_o   (clk,send_valid_jump, out3.rfwen, jump_in.rfwen);
FF_D_without_asyn_rst #(int_preg_width) u_jump_pwdest_o  (clk,send_valid_jump, out3.pwdest, jump_in.pwdest);
FF_D_without_asyn_rst #(rob_entry_w)    u_jump_rob_ptr_o (clk,send_valid_jump, out3.rob_ptr, jump_in.rob_ptr);
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

Bru_fu u_Bru_fu(
	.clk              	( clk               ),
	.rst_n            	( rst_n             ),
	.redirect           ( redirect          ),
	.bru_valid_i      	( bru_valid_i       ),
	.bru_ready_i      	( bru_ready_i       ),
	.op               	( bru_in.op         ),
	.fix_token        	( bru_in.fix_token  ),
	.inst_rvc         	( bru_in.inst_rvc   ),
	.src1             	( bru_in.src1       ),
	.src2             	( bru_in.src2       ),
	.pc               	( bru_in.pc         ),
	.imm              	( bru_in.imm        ),
	.rob_ptr          	( bru_in.rob_ptr    ),
	.bru_valid_o      	( bru_valid_o       ),
	.bru_ready_o      	( bru_ready_o       ),
	.bru_rob_ptr_o    	( bru_rob_ptr_o     ),
	.bru_token_miss_o 	( bru_token_miss_o  ),
	.branch_addr_o    	( branch_addr_o     )
);

Jump_fu u_Jump_fu(
	.clk               	( clk                ),
	.rst_n             	( rst_n              ),
	.redirect           ( redirect           ),
	.jump_valid_i      	( jump_valid_i       ),
	.jump_ready_i      	( jump_ready_i       ),
	.op                	( jump_in.op         ),
	.token_pc          	( jump_in.token_pc   ),
	.inst_rvc          	( jump_in.inst_rvc   ),
	.src1              	( jump_in.src1       ),
	.pc                	( jump_in.pc         ),
	.imm               	( jump_in.imm        ),
	.rfwen             	( jump_in.rfwen      ),
	.pwdest            	( jump_in.pwdest     ),
	.rob_ptr           	( jump_in.rob_ptr    ),
	.jump_valid_o      	( jump_valid_o       ),
	.jump_ready_o      	( jump_ready_o       ),
	.jump_rob_ptr_o    	( jump_rob_ptr_o     ),
	.jump_token_miss_o 	( jump_token_miss_o  ),
	.jump_rfwen_o      	( jump_rfwen_o       ),
	.jump_pwdest_o     	( jump_pwdest_o      ),
	.jump_preg_wdata_o 	( jump_preg_wdata_o  ),
	.jump_addr_o       	( jump_addr_o        )
);

assign bru_ftq_ptr  = out2.ftq_ptr;
assign jump_ftq_ptr = out3.ftq_ptr;

assign alu_bru_jump_exu_psrc[0]  = (out2_valid & (out2.src1_type == src_reg)) ? out2.psrc1 : ((out3_valid & (out3.src1_type == src_reg)) ? out3.psrc1 : out1.psrc1);
assign alu_bru_jump_exu_psrc[1]  = (out2_valid & (out2.src2_type == src_reg)) ? out2.psrc2 : out1.psrc2;

assign alu_ready_o              = (alu_bru_jump_exu_ready_o & (!bru_valid_o) & (!jump_valid_o));
assign bru_ready_o              = (alu_bru_jump_exu_ready_o);
assign jump_ready_o             = (alu_bru_jump_exu_ready_o & (!bru_valid_o));

assign alu_bru_jump_exu_valid_o      = (alu_valid_o | bru_valid_o | jump_valid_o);
assign alu_bru_jump_exu_rob_ptr_o    = (bru_valid_o ? bru_rob_ptr_o    : (jump_valid_o ? jump_rob_ptr_o    : alu_rob_ptr_o    ));
assign alu_bru_jump_exu_rfwen_o      = (bru_valid_o ? 0                : (jump_valid_o ? jump_rfwen_o      : 1'b1             ));
assign alu_bru_jump_exu_pwdest_o     = (bru_valid_o ? 0                : (jump_valid_o ? jump_pwdest_o     : alu_pwdest_o     ));
assign alu_bru_jump_exu_preg_wdata_o = (bru_valid_o ? 0                : (jump_valid_o ? jump_preg_wdata_o : alu_preg_wdata_o ));
assign alu_bru_jump_exu_token_miss_o = (bru_valid_o ? bru_token_miss_o : (jump_valid_o ? jump_token_miss_o : 1'b0             ));
assign alu_bru_jump_exu_next_pc_o    = (bru_valid_o ? branch_addr_o    : (jump_valid_o ? jump_addr_o       : 0                ));

endmodule //alu_bru_jump_exu_block
