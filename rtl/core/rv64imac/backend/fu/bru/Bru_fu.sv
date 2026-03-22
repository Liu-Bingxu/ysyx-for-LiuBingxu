module Bru_fu
import decode_pkg::*;
import bru_pkg::*;
import rob_pkg::*;
(
    input                                               clk,
    input                                               rst_n,

    input                                               redirect,

    input                                               bru_valid_i,
    output                                              bru_ready_i,
    input  bru_optype_t                                 op,
    input                                               fix_token,
    input                                               inst_rvc,
    input  [63:0]                                       src1,
    input  [63:0]                                       src2,
    input  [63:0]                                       pc,
    input  [31:0]                                       imm,
    input  rob_entry_ptr_t                              rob_ptr,

    output                                              bru_valid_o,
    input                                               bru_ready_o,
    output rob_entry_ptr_t                              bru_rob_ptr_o,
    output                                              bru_token_miss_o,
    output [63:0]                                       branch_addr_o
);

// arithmetic(add or sub)
logic [63:0]	        Sum;
logic               	Cout;
logic                   overflow;

//branch
logic                   res_eq;
logic                   res_lt;
logic                   res_ltu;

logic                   branch_flag;

//out
/* verilator lint_off UNUSEDSIGNAL */
logic [63:0]            branch_pc;
/* verilator lint_on UNUSEDSIGNAL */
logic [63:0]            not_branch_pc;

logic                   token_miss;
logic [63:0]            branch_addr;

//sub
add_with_Cout #(64)add_sub(
    .OP_A 	    ( src1      ),
    .OP_B 	    ( src2      ),
    .Cin  	    ( 1'b1      ),
    .Sum  	    ( Sum       ),
    .overflow   ( overflow  ),
    .Cout 	    ( Cout      )
);

//branch
assign res_eq  = (Sum==0)?1'b1:1'b0;
assign res_lt  = ((overflow) ? ((src1[63]) & (~src2[63])) : Sum[63]);
assign res_ltu = (~Cout);

//*************************************************************************
assign branch_pc        = pc + {{32{imm[31]}}, imm};
assign not_branch_pc    = pc + (inst_rvc ? 64'h2 : 64'h4);
//*************************************************************************
assign branch_flag  =  ((res_eq  & `branch_eq(op)) | 
                        (res_lt  & `branch_lt(op)) | 
                        (res_ltu & `branch_ltu(op))) ^ `branch_reverse(op);

assign token_miss     = (fix_token != branch_flag);
assign branch_addr    = (branch_flag) ? {branch_pc[63:1], 1'b0} : not_branch_pc;

//*************************************************************************
//!output
assign bru_ready_i = ((!bru_valid_o) | bru_ready_o);

logic send_valid;
assign send_valid = bru_valid_i & bru_ready_i;
FF_D_with_syn_rst #(
    .DATA_LEN 	( 1  ),
    .RST_DATA 	( 0  )
)u_bru_valid_o
(
    .clk      	( clk                               ),
    .rst_n    	( rst_n                             ),
    .syn_rst    ( redirect                          ),
    .wen        ( ((!bru_valid_o) | bru_ready_o)    ),
    .data_in  	( send_valid                        ),
    .data_out 	( bru_valid_o                       )
);
FF_D_without_asyn_rst #(rob_entry_w)u_rob_ptr_o(clk,send_valid, rob_ptr, bru_rob_ptr_o);
FF_D_without_asyn_rst #(1 ) u_token_miss_o  (clk,send_valid, token_miss, bru_token_miss_o);
FF_D_without_asyn_rst #(64) u_branch_addr_o (clk,send_valid, branch_addr, branch_addr_o);
//*************************************************************************

endmodule //Bru_fu
