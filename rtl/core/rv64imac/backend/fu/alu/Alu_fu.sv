module Alu_fu
import decode_pkg::*;
import regfile_pkg::*;
import alu_pkg::*;
import rob_pkg::*;
(
    input                                               clk,
    input                                               rst_n,

    input                                               redirect,

    input                                               alu_valid_i,
    output                                              alu_ready_i,
    input  alu_optype_t                                 op,
    input  [63:0]                                       src1,
    input  [63:0]                                       src2,
    input  pint_regdest_t                               pwdest,
    input  rob_entry_ptr_t                              rob_ptr,

    output                                              alu_valid_o,
    input                                               alu_ready_o,
    output rob_entry_ptr_t                              alu_rob_ptr_o,
    output pint_regdest_t                               alu_pwdest_o,
    output [63:0]                                       alu_preg_wdata_o
);


// arithmetic(add or sub)
wire [63:0] 	        Sum;
wire                	Cout;
wire                    overflow;

//logic
wire [63:0]             res_and;
wire [63:0]             res_xor;
wire [63:0]             res_or;

//cmp
wire                    res_lt;
wire                    res_ltu;

//shift
wire [63:0]             shift_data;
wire [5:0]              shift_shamt;
wire [63:0]             shift_res_temp;
wire [63:0]             shift_res;

//out
wire [63:0]             logic_res;
wire [63:0]             set_res;
wire [63:0]             sum_res;
wire [63:0]             res;

//arithmetic(add or sub)
add_with_Cout #(64)add_sub(
    .OP_A 	    ( src1          ),
    .OP_B 	    ( src2          ),
    .Cin  	    ( sub_flag(op)  ),
    .Sum  	    ( Sum           ),
    .overflow   ( overflow      ),
    .Cout 	    ( Cout          )
);

//logic
assign res_and = src1 & src2;
assign res_xor = src1 ^ src2;
assign res_or  = src1 | src2;

//cmp or branch
assign res_lt  = ((overflow) ? ((src1[63]) & (~src2[63])) : (Sum[63]));
assign res_ltu = (!Cout);

//shift
buck_shift #(64,6)u_buck_shift(
    .LR       	( shift_lr(op)          ),
    .AL       	( shift_al(op)          ),
    .shamt    	( shift_shamt           ),
    .data_in  	( shift_data            ),
    .data_out 	( shift_res_temp        )
);
assign shift_shamt = (shift_word(op)) ? {1'b0, src2[4:0]} : src2[5:0];
assign shift_data  = (!shift_word(op)) ? src1 : 
                        ((shift_al(op)) ? {{32{src1[31]}},src1[31:0]} : 
                            {32'h0,src1[31:0]}); 
assign shift_res   = (shift_word(op)) ? {{32{shift_res_temp[31]}},shift_res_temp[31:0]} : shift_res_temp;

//*************************************************************************
assign logic_res =  (res_and & {64{logic_and(op)}}) | 
                    (res_or  & {64{logic_or(op) }}) | 
                    (res_xor & {64{logic_xor(op)}});
assign set_res   = (set_signed(op)) ? {63'h0, res_lt} : {63'h0, res_ltu};
assign sum_res   = (add_sub_word(op)) ? {{32{Sum[31]}},Sum[31:0]} : Sum;
//*************************************************************************
assign res       =  64'h0 |
                    ({64{logic_flag(op)     }} & logic_res ) |
                    ({64{set_flag(op)       }} & set_res   ) |
                    ({64{shift_flag(op)     }} & shift_res ) |
                    ({64{add_sub_flag(op)   }} & sum_res   );
//*************************************************************************
//!output
assign alu_ready_i = ((!alu_valid_o) | alu_ready_o);

logic send_valid;
assign send_valid = alu_valid_i & alu_ready_i;
FF_D_with_syn_rst #(
    .DATA_LEN 	( 1  ),
    .RST_DATA 	( 0  )
)u_alu_valid_o
(
    .clk      	( clk           ),
    .rst_n    	( rst_n         ),
    .syn_rst    ( redirect      ),
    .wen        ( alu_ready_i   ),
    .data_in  	( alu_valid_i   ),
    .data_out 	( alu_valid_o   )
);
FF_D_without_asyn_rst #(int_preg_width) u_pwdest_o (clk,send_valid, pwdest, alu_pwdest_o);
FF_D_without_asyn_rst #(rob_entry_w)    u_rob_ptr_o(clk,send_valid, rob_ptr, alu_rob_ptr_o);
FF_D_without_asyn_rst #(64)             u_result_o (clk,send_valid, res, alu_preg_wdata_o);
//*************************************************************************

endmodule //alu
