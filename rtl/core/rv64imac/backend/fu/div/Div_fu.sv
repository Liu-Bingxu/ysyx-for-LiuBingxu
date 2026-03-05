module Div_fu
import decode_pkg::*;
import regfile_pkg::*;
import div_pkg::*;
import rob_pkg::*;
(
    input                                               clk,
    input                                               rst_n,

    input                                               redirect,

    input                                               div_valid_i,
    output                                              div_ready_i,
    input  div_optype_t                                 op,
    input  [63:0]                                       src1,
    input  [63:0]                                       src2,
    input  pint_regdest_t                               pwdest,
    input  rob_entry_ptr_t                              rob_ptr,

    output                                              div_valid_o,
    input                                               div_ready_o,
    output rob_entry_ptr_t                              div_rob_ptr_o,
    output pint_regdest_t                               div_pwdest_o,
    output [63:0]                                       div_preg_wdata_o
);

logic [63:0]            dividend;
logic [63:0]            divisor;
logic [63:0] 	        quotient;
logic [63:0] 	        remainder;

divu u_divu(
    .clk         	( clk           ),
    .rst_n       	( rst_n         ),
    .div_flush   	( redirect      ),
    .div_signed  	( !div_word(op) ),
    .div_valid   	( div_valid_i   ),
    .div_ready      ( div_ready_i   ),
    .dividend    	( dividend      ),
    .divisor     	( divisor       ),
    .quotient    	( quotient      ),
    .remainder   	( remainder     ),
    .div_o_valid 	( div_valid_o   ),
    .div_o_ready 	( div_ready_o   )
);
assign dividend     = (!div_word(op)) ? src1 : (
                        (!div_unsign(op)) ? {{32{src1[31]}},src1[31:0]} : 
                            {32'h0, src1[31:0]});
assign divisor      = (!div_word(op)) ? src2 : (
                        (!div_unsign(op)) ? {{32{src2[31]}},src2[31:0]} : 
                            {32'h0, src2[31:0]});
assign div_preg_wdata_o = (div_word(op)) ? ((div_rem(op)) ? {{32{remainder[31]}},remainder[31:0]} : {{32{quotient[31]}},quotient[31:0]}) : 
                        ((div_rem(op)) ? remainder : quotient);
FF_D_without_asyn_rst #(rob_entry_w)    u_rob_ptr_o(clk,div_valid_i & div_ready_i, rob_ptr, div_rob_ptr_o);
FF_D_without_asyn_rst #(int_preg_width) u_pwdest_o (clk,div_valid_i & div_ready_i, pwdest, div_pwdest_o);

endmodule //Div_fu
