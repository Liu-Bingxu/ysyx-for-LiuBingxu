`include "macro-func-define.sv"
module Csr_fu
import decode_pkg::*;
import regfile_pkg::*;
import csr_pkg::*;
import rob_pkg::*;
import core_setting_pkg::*;
(
    input                                               clk,
    input                                               rst_n,

    input                                               redirect,

    input                                               csr_valid_i,
    output                                              csr_ready_i,
    /* verilator lint_off UNUSEDSIGNAL */
    input  csr_optype_t                                 op,
    /* verilator lint_on UNUSEDSIGNAL */
    input  [11:0]                                       csr_index,
    input  [63:0]                                       csr_rdata,
    input  [63:0]                                       src1,
    input  [63:0]                                       mepc,
    input  [63:0]                                       sepc,
    input  [63:0]                                       dpc,
    input                                               inst_rvc,
    input  [63:0]                                       pc,
    input  pint_regdest_t                               pwdest,
    input                                               rfwen,
    input                                               csrwen,
    input  rob_entry_ptr_t                              rob_ptr,

    output                                              csr_valid_o,
    input                                               csr_ready_o,
    output rob_entry_ptr_t                              csr_rob_ptr_o,
    output pint_regdest_t                               csr_pwdest_o,
    output                                              csr_rfwen_o,
    output                                              csr_csrwen_o,
    output [11:0]                                       csr_index_o,
    output                                              csr_mret_o,
    output                                              csr_sret_o,
    output                                              csr_dret_o,
    output                                              csr_satp_change_o,
    output [63:0]                                       csr_jump_pc_o,
    output [63:0]                                       csr_preg_wdata_o,
    output [63:0]                                       csr_wdata_o
);

//csr logic
logic [63:0]             csr_and;
logic [63:0]             csr_or;

logic [63:0]             csr_res;

logic [63:0]             csr_jump_pc;

logic [63:0]             npc;
logic                    csr_satp_change;

//csr logic
assign csr_and = (~src1) & csr_rdata;
assign csr_or  = src1 | csr_rdata;

assign npc              = pc + (inst_rvc ? 64'h2 : 64'h4);
assign csr_satp_change  = (csrwen & (csr_index == SATP));

assign csr_res =    (src1    & {64{`csr_swap (op)}}) | 
                    (csr_or  & {64{`csr_set  (op)}}) | 
                    (csr_and & {64{`csr_clear(op)}});

assign csr_jump_pc =    (mepc & {64{`csr_mret_flag(op)}}) | 
                        (sepc & {64{`csr_sret_flag(op)}}) | 
                        (dpc  & {64{`csr_dret_flag(op)}}) | 
                        (npc  & {64{ csr_satp_change  }});
//*************************************************************************
//!output
assign csr_ready_i = ((!csr_valid_o) | csr_ready_o);

logic send_valid;
assign send_valid = csr_valid_i & csr_ready_i;
FF_D_with_syn_rst #(
    .DATA_LEN 	( 1  ),
    .RST_DATA 	( 0  )
)u_csr_valid_o
(
    .clk      	( clk                               ),
    .rst_n    	( rst_n                             ),
    .syn_rst    ( redirect                          ),
    .wen        ( ((!csr_valid_o) | csr_ready_o)    ),
    .data_in  	( send_valid                        ),
    .data_out 	( csr_valid_o                       )
);
FF_D_without_asyn_rst #(rob_entry_w)    u_rob_ptr_o     (clk,send_valid, rob_ptr, csr_rob_ptr_o);
FF_D_without_asyn_rst #(int_preg_width) u_pwdest_o      (clk,send_valid, pwdest, csr_pwdest_o);
FF_D_without_asyn_rst #(1 )             u_rfwen_o       (clk,send_valid, `csr_acc_flag(op) & rfwen,  csr_rfwen_o );
FF_D_without_asyn_rst #(1 )             u_csrwen_o      (clk,send_valid, `csr_acc_flag(op) & csrwen, csr_csrwen_o);
FF_D_without_asyn_rst #(12)             u_csr_index_o   (clk,send_valid, csr_index, csr_index_o);
FF_D_without_asyn_rst #(1 )             u_mret_o        (clk,send_valid, `csr_mret_flag(op), csr_mret_o);
FF_D_without_asyn_rst #(1 )             u_sret_o        (clk,send_valid, `csr_sret_flag(op), csr_sret_o);
FF_D_without_asyn_rst #(1 )             u_dret_o        (clk,send_valid, `csr_dret_flag(op), csr_dret_o);
FF_D_without_asyn_rst #(1 )             u_satp_change_o (clk,send_valid, csr_satp_change, csr_satp_change_o);
FF_D_without_asyn_rst #(64)             u_result_o      (clk,send_valid, csr_rdata, csr_preg_wdata_o);
FF_D_without_asyn_rst #(64)             u_jump_pc_o     (clk,send_valid, csr_jump_pc, csr_jump_pc_o);
FF_D_without_asyn_rst #(64)             u_csr_wdata_o   (clk,send_valid, csr_res, csr_wdata_o);
//*************************************************************************


endmodule //Csr_fu
