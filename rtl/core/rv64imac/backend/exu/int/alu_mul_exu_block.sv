module alu_mul_exu_block
import decode_pkg::*;
import regfile_pkg::*;
import iq_pkg::*;
import alu_pkg::*;
import mul_pkg::*;
import rob_pkg::*;
import core_setting_pkg::*;
(
    input                                               clk,
    input                                               rst_n,

    input                                               redirect,

    output [IQ_W - 1 : 0]                               alu_mul_exu_iq_enq_num,

    input                                               alu_mul_exu_in_valid,
    output                                              alu_mul_exu_in_ready,
    input  iq_acc_in_t                                  alu_mul_exu_in,

    input                [wb_width - 1 : 0]             rfwen,
    input  pint_regdest_t[wb_width - 1 : 0]             pwdest,

    //! TODO 现在采用固定优先级，alu > mul，以后可以采用其他优先级方案
    output pint_regsrc_t [1 : 0]                        alu_mul_exu_psrc,
    input  intreg_t      [1 : 0]                        alu_mul_exu_psrc_rdata,

    output                                              alu_mul_exu_valid_o,
    input                                               alu_mul_exu_ready_o,
    output rob_entry_ptr_t                              alu_mul_exu_rob_ptr_o,
    output pint_regdest_t                               alu_mul_exu_pwdest_o,
    output [63:0]                                       alu_mul_exu_preg_wdata_o
);

logic                  out1_valid;
logic                  out1_ready;
iq_acc_out_t           out1;
logic                  out2_valid;
logic                  out2_ready;
iq_acc_out_t           out2;

logic                  alu_valid_i;
logic                  alu_ready_i;
struct packed {
    alu_optype_t       op;
    logic [63:0]       src1;
    logic [63:0]       src2;
    pint_regdest_t     pwdest;
    rob_entry_ptr_t    rob_ptr;
} alu_in;

logic                  mul_valid_i;
logic                  mul_ready_i;
struct packed {
    mul_optype_t      op;
    logic [63:0]      src1;
    logic [63:0]      src2;
    pint_regdest_t    pwdest;
    rob_entry_ptr_t   rob_ptr;
} mul_in;

logic                  alu_valid_o;
logic                  alu_ready_o;
rob_entry_ptr_t        alu_rob_ptr_o;
pint_regdest_t         alu_pwdest_o;
logic [63:0]           alu_preg_wdata_o;

logic                  mul_valid_o;
logic                  mul_ready_o;
rob_entry_ptr_t        mul_rob_ptr_o;
pint_regdest_t         mul_pwdest_o;
logic [63:0]           mul_preg_wdata_o;

iq_acc u_iq_acc(
	.clk        	( clk                       ),
	.rst_n      	( rst_n                     ),
	.redirect      	( redirect                  ),
    .iq_enq_num     ( alu_mul_exu_iq_enq_num    ),
	.in_valid   	( alu_mul_exu_in_valid      ),
	.in_ready   	( alu_mul_exu_in_ready      ),
	.in         	( alu_mul_exu_in            ),
	.rfwen      	( rfwen                     ),
	.pwdest     	( pwdest                    ),
	.out1_valid 	( out1_valid                ),
	.out1_ready 	( out1_ready                ),
	.out1       	( out1                      ),
	.out2_valid 	( out2_valid                ),
	.out2_ready 	( out2_ready                ),
	.out2       	( out2                      )
);

//*******************************stage: to temp storage the preg_data and inst_use data******************************************
// alu stage
assign out1_ready = ((!alu_valid_i) | alu_ready_i);

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

assign alu_src1 =   (({64{out1.src1_type == src_reg}}) & alu_mul_exu_psrc_rdata[0]);
assign alu_src2 =   (({64{out1.src2_type == src_reg}}) & alu_mul_exu_psrc_rdata[1]) | 
                    (({64{out1.src2_type == src_imm}}) & {{32{out1.imm[31]}}, out1.imm});

FF_D_without_asyn_rst #(9 )             u_alu_op_o      (clk,send_valid_alu, out1.fuoptype, alu_in.op);
FF_D_without_asyn_rst #(64)             u_alu_src1_o    (clk,send_valid_alu, alu_src1, alu_in.src1);
FF_D_without_asyn_rst #(64)             u_alu_src2_o    (clk,send_valid_alu, alu_src2, alu_in.src2);
FF_D_without_asyn_rst #(int_preg_width) u_alu_pwdest_o  (clk,send_valid_alu, out1.pwdest, alu_in.pwdest);
FF_D_without_asyn_rst #(rob_entry_w)    u_alu_rob_ptr_o (clk,send_valid_alu, out1.rob_ptr, alu_in.rob_ptr);
//*******************************************************************************************************************************
// mul stage
assign out2_ready = ((!mul_valid_i) | mul_ready_i) & 
                    ((!out1_valid) | (
                    ((out1.src1_type != src_reg) | (out2.src1_type != src_reg)) & 
                    ((out1.src2_type != src_reg) | (out2.src2_type != src_reg))
                    ));

logic send_valid_mul;
assign send_valid_mul = out2_valid & out2_ready;
FF_D_with_syn_rst #(
    .DATA_LEN 	( 1  ),
    .RST_DATA 	( 0  )
)u_mul_valid_i
(
    .clk      	( clk                            ),
    .rst_n    	( rst_n                          ),
    .syn_rst    ( redirect                       ),
    .wen        ( ((!mul_valid_i) | mul_ready_i) ),
    .data_in  	( send_valid_mul                 ),
    .data_out 	( mul_valid_i                    )
);
intreg_t mul_src1;
intreg_t mul_src2;

assign mul_src1 =   (({64{out2.src1_type == src_reg}}) & alu_mul_exu_psrc_rdata[0]);
assign mul_src2 =   (({64{out2.src2_type == src_reg}}) & alu_mul_exu_psrc_rdata[1]) | 
                    (({64{out2.src2_type == src_imm}}) & {{32{out2.imm[31]}}, out2.imm});

FF_D_without_asyn_rst #(9 )             u_mul_op_o      (clk,send_valid_mul, out2.fuoptype, mul_in.op);
FF_D_without_asyn_rst #(64)             u_mul_src1_o    (clk,send_valid_mul, mul_src1, mul_in.src1);
FF_D_without_asyn_rst #(64)             u_mul_src2_o    (clk,send_valid_mul, mul_src2, mul_in.src2);
FF_D_without_asyn_rst #(int_preg_width) u_mul_pwdest_o  (clk,send_valid_mul, out2.pwdest, mul_in.pwdest);
FF_D_without_asyn_rst #(rob_entry_w)    u_mul_rob_ptr_o (clk,send_valid_mul, out2.rob_ptr, mul_in.rob_ptr);
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

Mul_fu u_Mul_fu(
	.clk              	( clk               ),
	.rst_n            	( rst_n             ),
	.redirect           ( redirect          ),
	.mul_valid_i      	( mul_valid_i       ),
	.mul_ready_i      	( mul_ready_i       ),
	.op               	( mul_in.op         ),
	.src1             	( mul_in.src1       ),
	.src2             	( mul_in.src2       ),
	.pwdest           	( mul_in.pwdest     ),
	.rob_ptr          	( mul_in.rob_ptr    ),
	.mul_valid_o      	( mul_valid_o       ),
	.mul_ready_o      	( mul_ready_o       ),
	.mul_rob_ptr_o    	( mul_rob_ptr_o     ),
	.mul_pwdest_o     	( mul_pwdest_o      ),
	.mul_preg_wdata_o 	( mul_preg_wdata_o  )
);

assign alu_mul_exu_psrc[0]  = (out1_valid & (out1.src1_type == src_reg)) ? out1.psrc1 : out2.psrc1;
assign alu_mul_exu_psrc[1]  = (out1_valid & (out1.src2_type == src_reg)) ? out1.psrc2 : out2.psrc2;

assign alu_ready_o              = alu_mul_exu_ready_o;
assign mul_ready_o              = (alu_mul_exu_ready_o & (!alu_valid_o));

assign alu_mul_exu_valid_o      = (alu_valid_o | mul_valid_o);
assign alu_mul_exu_rob_ptr_o    = (alu_valid_o) ? alu_rob_ptr_o    : mul_rob_ptr_o   ;
assign alu_mul_exu_pwdest_o     = (alu_valid_o) ? alu_pwdest_o     : mul_pwdest_o    ;
assign alu_mul_exu_preg_wdata_o = (alu_valid_o) ? alu_preg_wdata_o : mul_preg_wdata_o;

endmodule //alu_mul_exu_block
