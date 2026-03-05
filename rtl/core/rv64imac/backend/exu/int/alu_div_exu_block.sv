module alu_div_exu_block
import decode_pkg::*;
import regfile_pkg::*;
import iq_pkg::*;
import alu_pkg::*;
import div_pkg::*;
import rob_pkg::*;
import core_setting_pkg::*;
(
    input                                               clk,
    input                                               rst_n,

    input                                               redirect,

    output [IQ_W - 1 : 0]                               alu_div_exu_iq_enq_num,

    input                                               alu_div_exu_in_valid,
    output                                              alu_div_exu_in_ready,
    input  iq_acc_in_t                                  alu_div_exu_in,

    input                [wb_width - 1 : 0]             rfwen,
    input  pint_regdest_t[wb_width - 1 : 0]             pwdest,

    //! TODO 现在采用固定优先级，alu > div，以后可以采用其他优先级方案
    output pint_regsrc_t [1 : 0]                        alu_div_exu_psrc,
    input  intreg_t      [1 : 0]                        alu_div_exu_psrc_rdata,

    output                                              alu_div_exu_valid_o,
    input                                               alu_div_exu_ready_o,
    output rob_entry_ptr_t                              alu_div_exu_rob_ptr_o,
    output pint_regdest_t                               alu_div_exu_pwdest_o,
    output [63:0]                                       alu_div_exu_preg_wdata_o
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

logic                  div_valid_i;
logic                  div_ready_i;
struct packed {
    div_optype_t      op;
    logic [63:0]      src1;
    logic [63:0]      src2;
    pint_regdest_t    pwdest;
    rob_entry_ptr_t   rob_ptr;
} div_in;

logic                  alu_valid_o;
logic                  alu_ready_o;
rob_entry_ptr_t        alu_rob_ptr_o;
pint_regdest_t         alu_pwdest_o;
logic [63:0]           alu_preg_wdata_o;

logic                  div_valid_o;
logic                  div_ready_o;
rob_entry_ptr_t        div_rob_ptr_o;
pint_regdest_t         div_pwdest_o;
logic [63:0]           div_preg_wdata_o;

iq_acc u_iq_acc(
	.clk        	( clk                       ),
	.rst_n      	( rst_n                     ),
	.redirect      	( redirect                  ),
    .iq_enq_num     ( alu_div_exu_iq_enq_num    ),
	.in_valid   	( alu_div_exu_in_valid      ),
	.in_ready   	( alu_div_exu_in_ready      ),
	.in         	( alu_div_exu_in            ),
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
    .clk      	( clk           ),
    .rst_n    	( rst_n         ),
    .syn_rst    ( redirect      ),
    .wen        ( out1_ready    ),
    .data_in  	( out1_valid    ),
    .data_out 	( alu_valid_i   )
);
intreg_t alu_src1;
intreg_t alu_src2;

assign alu_src1 =   (({64{out1.src1_type == src_reg}}) & alu_div_exu_psrc_rdata[0]);
assign alu_src2 =   (({64{out1.src2_type == src_reg}}) & alu_div_exu_psrc_rdata[1]) | 
                    (({64{out1.src2_type == src_imm}}) & {{32{out1.imm[31]}}, out1.imm});

FF_D_without_asyn_rst #(9 )             u_alu_op_o      (clk,send_valid_alu, out1.fuoptype, alu_in.op);
FF_D_without_asyn_rst #(64)             u_alu_src1_o    (clk,send_valid_alu, alu_src1, alu_in.src1);
FF_D_without_asyn_rst #(64)             u_alu_src2_o    (clk,send_valid_alu, alu_src2, alu_in.src2);
FF_D_without_asyn_rst #(int_preg_width) u_alu_pwdest_o  (clk,send_valid_alu, out1.pwdest, alu_in.pwdest);
FF_D_without_asyn_rst #(rob_entry_w)    u_alu_rob_ptr_o (clk,send_valid_alu, out1.rob_ptr, alu_in.rob_ptr);
//*******************************************************************************************************************************
// div stage
assign out2_ready = ((!div_valid_i) | div_ready_i) & 
                    ((!out1_valid) | (
                    ((out1.src1_type != src_reg) | (out2.src1_type != src_reg)) & 
                    ((out1.src2_type != src_reg) | (out2.src2_type != src_reg))
                    ));

logic send_valid_div;
assign send_valid_div = out2_valid & out2_ready;
FF_D_with_syn_rst #(
    .DATA_LEN 	( 1  ),
    .RST_DATA 	( 0  )
)u_div_valid_i
(
    .clk      	( clk                            ),
    .rst_n    	( rst_n                          ),
    .syn_rst    ( redirect                       ),
    .wen        ( ((!div_valid_i) | div_ready_i) ),
    .data_in  	( send_valid_div                 ),
    .data_out 	( div_valid_i                    )
);
intreg_t div_src1;
intreg_t div_src2;

assign div_src1 =   (({64{out2.src1_type == src_reg}}) & alu_div_exu_psrc_rdata[0]);
assign div_src2 =   (({64{out2.src2_type == src_reg}}) & alu_div_exu_psrc_rdata[1]) | 
                    (({64{out2.src2_type == src_imm}}) & {{32{out2.imm[31]}}, out2.imm});

FF_D_without_asyn_rst #(9 )             u_div_op_o      (clk,send_valid_div, out2.fuoptype, div_in.op);
FF_D_without_asyn_rst #(64)             u_div_src1_o    (clk,send_valid_div, div_src1, div_in.src1);
FF_D_without_asyn_rst #(64)             u_div_src2_o    (clk,send_valid_div, div_src2, div_in.src2);
FF_D_without_asyn_rst #(int_preg_width) u_div_pwdest_o  (clk,send_valid_div, out2.pwdest, div_in.pwdest);
FF_D_without_asyn_rst #(rob_entry_w)    u_div_rob_ptr_o (clk,send_valid_div, out2.rob_ptr, div_in.rob_ptr);
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

Div_fu u_Div_fu(
	.clk              	( clk               ),
	.rst_n            	( rst_n             ),
	.redirect           ( redirect          ),
	.div_valid_i      	( div_valid_i       ),
	.div_ready_i      	( div_ready_i       ),
	.op               	( div_in.op         ),
	.src1             	( div_in.src1       ),
	.src2             	( div_in.src2       ),
	.pwdest           	( div_in.pwdest     ),
	.rob_ptr          	( div_in.rob_ptr    ),
	.div_valid_o      	( div_valid_o       ),
	.div_ready_o      	( div_ready_o       ),
	.div_rob_ptr_o    	( div_rob_ptr_o     ),
	.div_pwdest_o     	( div_pwdest_o      ),
	.div_preg_wdata_o 	( div_preg_wdata_o  )
);

assign alu_div_exu_psrc[0]  = (out1_valid & (out1.src1_type == src_reg)) ? out1.psrc1 : out2.psrc1;
assign alu_div_exu_psrc[1]  = (out1_valid & (out1.src2_type == src_reg)) ? out1.psrc2 : out2.psrc2;

assign alu_ready_o              = alu_div_exu_ready_o;
assign div_ready_o              = (alu_div_exu_ready_o & (!alu_valid_o));

assign alu_div_exu_valid_o      = (alu_valid_o | div_valid_o);
assign alu_div_exu_rob_ptr_o    = (alu_valid_o) ? alu_rob_ptr_o    : div_rob_ptr_o   ;
assign alu_div_exu_pwdest_o     = (alu_valid_o) ? alu_pwdest_o     : div_pwdest_o    ;
assign alu_div_exu_preg_wdata_o = (alu_valid_o) ? alu_preg_wdata_o : div_preg_wdata_o;

endmodule //alu_div_exu_block
