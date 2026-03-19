module Jump_fu
import decode_pkg::*;
import regfile_pkg::*;
import jump_pkg::*;
import rob_pkg::*;
(
    input                                               clk,
    input                                               rst_n,

    input                                               redirect,

    input                                               jump_valid_i,
    output                                              jump_ready_i,
    input  jump_optype_t                                op,
    /* verilator lint_off UNUSEDSIGNAL */
    input  [63:0]                                       token_pc,
    /* verilator lint_on UNUSEDSIGNAL */
    input                                               inst_rvc,
    input  [63:0]                                       src1,
    input  [63:0]                                       pc,
    input  [31:0]                                       imm,
    input                                               rfwen,
    input  pint_regdest_t                               pwdest,
    input  rob_entry_ptr_t                              rob_ptr,

    output                                              jump_valid_o,
    input                                               jump_ready_o,
    output rob_entry_ptr_t                              jump_rob_ptr_o,
    output                                              jump_token_miss_o,
    output                                              jump_rfwen_o,
    output pint_regdest_t                               jump_pwdest_o,
    output [63:0]                                       jump_preg_wdata_o,
    output [63:0]                                       jump_addr_o
);

logic           token_miss;

logic [63:0]    auipc_res;
logic [63:0]    preg_wdata;
/* verilator lint_off UNUSEDSIGNAL */
logic [63:0]    jump_addr;
/* verilator lint_on UNUSEDSIGNAL */

assign token_miss   = (jump_jalr(op) & (jump_addr[63:1] != token_pc[63:1]));

assign auipc_res    = pc + {{32{imm[31]}}, imm};
assign preg_wdata   = (jump_auipc(op)) ? auipc_res : pc + (inst_rvc ? 64'h2 : 64'h4);
assign jump_addr    = (jump_jalr(op)) ? (src1 + {{32{imm[31]}}, imm}) : (pc + {{32{imm[31]}}, imm});

//*************************************************************************
//!output
assign jump_ready_i = ((!jump_valid_o) | jump_ready_o);

logic send_valid;
assign send_valid = jump_valid_i & jump_ready_i;
FF_D_with_syn_rst #(
    .DATA_LEN 	( 1  ),
    .RST_DATA 	( 0  )
)u_jump_valid_o
(
    .clk      	( clk                               ),
    .rst_n    	( rst_n                             ),
    .syn_rst    ( redirect                          ),
    .wen        ( ((!jump_valid_o) | jump_ready_o)  ),
    .data_in  	( send_valid                        ),
    .data_out 	( jump_valid_o                      )
);
FF_D_without_asyn_rst #(rob_entry_w)    u_rob_ptr_o     (clk,send_valid, rob_ptr, jump_rob_ptr_o);
FF_D_without_asyn_rst #(1 )             u_token_miss_o  (clk,send_valid, token_miss, jump_token_miss_o);
FF_D_without_asyn_rst #(1 )             u_rfwen_o       (clk,send_valid, rfwen,  jump_rfwen_o );
FF_D_without_asyn_rst #(int_preg_width) u_pwdest_o      (clk,send_valid, pwdest, jump_pwdest_o);
FF_D_without_asyn_rst #(64)             u_preg_wdata_o  (clk,send_valid, preg_wdata, jump_preg_wdata_o);
FF_D_without_asyn_rst #(64)             u_jump_addr_o   (clk,send_valid, {jump_addr[63:1], 1'b0}, jump_addr_o);
//*************************************************************************

endmodule //Jump_fu
