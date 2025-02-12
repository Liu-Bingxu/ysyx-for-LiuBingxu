// the inst decode Unit for a cpu core
// Copyright (C) 2024  LiuBingxu

// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.

// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.

// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

// Please contact me through the following email: <qwe15889844242@163.com>

`include "./define.v"
module idu(
    input                   clk,
    input                   rst_n,

    input                   debug_mode,
    input  [1:0]            current_priv_status,
//interface with ifu
    input  [1:0]            IF_ID_reg_rresp,
    input  [15:0]           IF_ID_reg_inst_compress,
    input  [31:0]           IF_ID_reg_inst,
    input  [63:0]           IF_ID_reg_PC,
    input                   IF_ID_reg_inst_valid,
    input                   IF_ID_reg_inst_compress_flag,
    output                  ID_IF_inst_ready,
    output                  ID_IF_flush_flag,
//interface with exu
    //common sign:
    input                   EX_IF_jump_flag,
    output                  ID_EX_reg_decode_valid,
    input                   EX_ID_decode_ready,
    input                   EX_ID_flush_flag,
    output [4 :0]           ID_EX_reg_rs1,
    output [4 :0]           ID_EX_reg_rs2,
    // input  [63:0]           WB_ID_src1,
    // input  [63:0]           WB_ID_src2,
    output [63:0]           ID_EX_reg_PC,
    output [63:0]           ID_EX_reg_next_PC,
    output [31:0]           ID_EX_reg_inst,
    output [4 :0]           ID_EX_reg_rd,
    output                  ID_EX_reg_dest_wen,
    //control_sign:
    output                  ID_EX_reg_sub,
    output                  ID_EX_reg_word,
    //logic_sign:
    output                  ID_EX_reg_logic_valid,
    output                  ID_EX_reg_logic_or,
    output                  ID_EX_reg_logic_xor,
    output                  ID_EX_reg_logic_and,
    //load_sign:
    output                  ID_EX_reg_load_valid,
    output                  ID_EX_reg_load_signed,
    output                  ID_EX_reg_load_byte,
    output                  ID_EX_reg_load_half,
    output                  ID_EX_reg_load_word,
    output                  ID_EX_reg_load_double,
    //store_sign:
    output                  ID_EX_reg_store_valid,
    output                  ID_EX_reg_store_byte,
    output                  ID_EX_reg_store_half,
    output                  ID_EX_reg_store_word,
    output                  ID_EX_reg_store_double,
    // output [63:0]           ID_EX_reg_store_data,
    //branch:
    output                  ID_EX_reg_branch_valid,
    output                  ID_EX_reg_branch_ne,
    output                  ID_EX_reg_branch_eq,
    output                  ID_EX_reg_branch_lt,
    output                  ID_EX_reg_branch_ge,
    output                  ID_EX_reg_branch_signed,
    //shift:
    output                  ID_EX_reg_shift_valid,
    output                  ID_EX_reg_shift_al,
    output                  ID_EX_reg_shift_lr,
    output                  ID_EX_reg_shift_word,
    //set:
    output                  ID_EX_reg_set_valid,
    output                  ID_EX_reg_set_signed,
    //jump:
    output                  ID_EX_reg_jump_valid,
    output                  ID_EX_reg_jump_jalr,
    //Zicsr:
    output                  ID_EX_reg_csr_valid,
    output                  ID_EX_reg_csr_wen,
    output                  ID_EX_reg_csr_ren,
    output [11:0]           ID_EX_reg_csr_addr,
    output [11:0]           ID_WB_csr_addr,
    input  [63:0]           WB_ID_csr_rdata,
    output                  ID_EX_reg_csr_set,
    output                  ID_EX_reg_csr_clear,
    output                  ID_EX_reg_csr_swap,
    //mul:
    output                  ID_EX_reg_mul_valid,
    output                  ID_EX_reg_mul_high,
    output [1:0]            ID_EX_reg_mul_signed,
    output                  ID_EX_reg_mul_word,
    output                  ID_EX_reg_div_valid,
    output                  ID_EX_reg_div_signed,
    output                  ID_EX_reg_div_rem,
    output                  ID_EX_reg_div_word,
    //atomic:
    output                  ID_EX_reg_atomic_valid,
    output                  ID_EX_reg_atomic_word,
    output                  ID_EX_reg_atomic_lr,
    output                  ID_EX_reg_atomic_sc,
    output                  ID_EX_reg_atomic_swap,
    output                  ID_EX_reg_atomic_add,
    output                  ID_EX_reg_atomic_xor,
    output                  ID_EX_reg_atomic_and,
    output                  ID_EX_reg_atomic_or,
    output                  ID_EX_reg_atomic_min,
    output                  ID_EX_reg_atomic_max,
    output                  ID_EX_reg_atomic_signed,
    //trap:
    output                  ID_EX_reg_trap_valid,
    output                  ID_EX_reg_mret_valid,
    output                  ID_EX_reg_sret_valid,
    output                  ID_EX_reg_dret_valid,
    output [63:0]           ID_EX_reg_trap_cause,
    output [63:0]           ID_EX_reg_trap_tval,
    //operand
    output [63:0]           ID_EX_reg_operand1,   
    output [63:0]           ID_EX_reg_operand2, 
    output [63:0]           ID_EX_reg_operand3,   
    output [63:0]           ID_EX_reg_operand4,
//interface with lsu
    input                   EX_LS_reg_execute_valid,
    input                   EX_LS_reg_csr_wen,
    // input                   EX_LS_reg_atomic_valid,
    // input                   EX_LS_reg_load_valid,
    // input  [4:0]            EX_LS_reg_rd,
    // input                   EX_LS_reg_dest_wen,
    // input  [63:0]           EX_LS_reg_operand,
//interface with wbu
    input                   TSR,
    input                   TW,
    input                   TVM,
    input                   LS_WB_reg_ls_valid,
    input                   LS_WB_reg_csr_wen
    // input  [4:0]            LS_WB_reg_rd,
    // input                   LS_WB_reg_dest_wen,
    // input  [63:0]           LS_WB_reg_data
);
//common
wire [63:0]             next_PC;
wire                    rs1_valid;
wire                    rs2_valid;
wire [4 :0]             rd;
wire [4 :0]             rs1;
wire [4 :0]             rs2;
wire                    dest_wen;
//control_sign:
wire                    alu_sub;
wire                    word;
//logic_sign:
wire                    logic_valid;
wire                    logic_or;
wire                    logic_xor;
wire                    logic_and;
//load_sign:
wire                    load_valid;
wire                    load_signed;
wire                    load_byte;
wire                    load_half;
wire                    load_word;
wire                    load_double;
//store_sign:
wire                    store_valid;
wire                    store_byte;
wire                    store_half;
wire                    store_word;
wire                    store_double;
//branch:
wire                    branch_valid;
wire                    branch_ne;
wire                    branch_eq;
wire                    branch_lt;
wire                    branch_ge;
wire                    branch_signed;
//shift:
wire                    shift_valid;
wire                    shift_al;
wire                    shift_lr;
wire                    shift_word;
//set:
wire                    set_valid;
wire                    set_signed;
//jump:
wire                    jump_valid;
wire                    jump_jalr;
//Zicsr:
wire                    csr_valid;
wire                    csr_wen;
wire                    csr_ren;
wire [11:0]             csr_addr;
wire                    csr_addr_legal;
wire                    csr_set;
wire                    csr_clear;
wire                    csr_swap;
//mul:
wire                    mul_valid;
wire                    mul_high;
wire [1:0]              mul_signed;
wire                    mul_word;
wire                    div_valid;
wire                    div_signed;
wire                    div_rem;
wire                    div_word;
//atomic:
wire                    atomic_valid;
wire                    atomic_word;
wire                    atomic_lr;
wire                    atomic_sc;
wire                    atomic_swap;
wire                    atomic_add;
wire                    atomic_xor;
wire                    atomic_and;
wire                    atomic_or;
wire                    atomic_min;
wire                    atomic_max;
wire                    atomic_signed;
//trap:
wire                    trap_valid;
wire                    mret_valid;
wire                    sret_valid;
wire                    dret_valid;
wire [63:0]             trap_cause;
wire [63:0]             trap_tval;
//operand
wire [63:0]             operand1;
wire [63:0]             operand2;
// wire [63:0]             operand3;
wire [63:0]             operand4;

wire [63:0]             imm;
wire [63:0]             imm_I,imm_J,imm_U,imm_B,imm_S,CSR_imm;

wire [6:0]              funct7;
wire [2:0]              funct3;

wire I_flag,J_flag,U_flag,B_flag,S_flag,R_flag,A_flag,RW_flag,CSR_flag;
wire load_flag,arith_flag,arith_w_flag;

//rv64i instruction sign
wire lui, auipc;
wire jal, jalr;
wire beq, bne, blt, bltu, bge, bgeu;
wire lb, lbu, lh, lhu, lw, lwu, ld;
wire sb, sh, sw, sd;
wire slti, sltiu, xori, ori, andi, addi;
wire sll,srl,sra,slli,srli,srai;
wire sub, slt,sltu, add;
wire OR, XOR, AND;
//todo fence_i to invalid i/d cache
//todo sfence_vma to invalid tlb
wire ecall, ebreak, fence, fence_i, sfence_vma;
wire addiw, addw, subw;
wire sllw,srlw,sraw,slliw,srliw,sraiw;

//rv64 Zicsr
wire csrrw,csrrwi;
wire csrrs,csrrsi;
wire csrrc,csrrci;

//rv64m instruction sign
wire mul, mulh, mulhsu, mulhu, mulw;
wire div, divu, rem, remu;
wire divw, divuw, remw, remuw;

//rv64a instruction sign
wire lr_w, sc_w, amoswap_w, amoadd_w, amoxor_w, amoand_w, amoor_w, amomin_w, amomax_w, amominu_w, amomaxu_w;
wire lr_d, sc_d, amoswap_d, amoadd_d, amoxor_d, amoand_d, amoor_d, amomin_d, amomax_d, amominu_d, amomaxu_d;

//rv64 privileged
wire mret, sret, dret;
wire wfi;

//illegal instruction 
wire        illegal_instruction;

// wire        Data_Conflict;
// reg [63:0]  src1;
// reg [63:0]  src2;

assign rs1              = IF_ID_reg_inst[19:15];
assign rs2              = IF_ID_reg_inst[24:20];
assign rd               = IF_ID_reg_inst[11:7 ];
assign ID_WB_csr_addr   = IF_ID_reg_inst[31:20];

assign funct3 = IF_ID_reg_inst[14:12];
assign funct7 = IF_ID_reg_inst[31:25];

//imm decode
assign imm_I    = {{(52){IF_ID_reg_inst[31]}},IF_ID_reg_inst[31:20]};
assign imm_S    = {{(52){IF_ID_reg_inst[31]}},IF_ID_reg_inst[31:25],IF_ID_reg_inst[11:7]};
assign imm_B    = {{(52){IF_ID_reg_inst[31]}},IF_ID_reg_inst[7],IF_ID_reg_inst[30:25],IF_ID_reg_inst[11:8],1'b0};
assign imm_U    = {{(33){IF_ID_reg_inst[31]}},IF_ID_reg_inst[30:12],12'h0};
assign imm_J    = {{(44){IF_ID_reg_inst[31]}},IF_ID_reg_inst[19:12],IF_ID_reg_inst[20],IF_ID_reg_inst[30:21],1'b0};
assign CSR_imm  = {{(59){1'b0}},rs1};

//type decode
assign R_flag   = (IF_ID_reg_inst[6:0]==7'b0110011)?1'b1:1'b0;
assign A_flag   = (IF_ID_reg_inst[6:0]==7'b0101111)?1'b1:1'b0;
assign RW_flag  = (IF_ID_reg_inst[6:0]==7'b0111011)?1'b1:1'b0;
assign S_flag   = (IF_ID_reg_inst[6:0]==7'b0100011)?1'b1:1'b0;
assign I_flag   = (load_flag|arith_flag|arith_w_flag|jalr);
assign B_flag   = (IF_ID_reg_inst[6:0]==7'b1100011)?1'b1:1'b0;
assign U_flag   = (lui|auipc);
assign J_flag   = jal;
assign CSR_flag = ((IF_ID_reg_inst[6:0]==7'b1110011))?1'b1:1'b0;

assign imm = (I_flag)?imm_I:(
    (U_flag)?imm_U:(
        (J_flag)?imm_J:(
            (S_flag)?imm_S:(
                (CSR_flag)?CSR_imm:imm_B
            )
        )
    )
);

assign load_flag    = (IF_ID_reg_inst[6:0]==7'b0000011)?1'b1:1'b0;
assign arith_flag   = (IF_ID_reg_inst[6:0]==7'b0010011)?1'b1:1'b0;
assign arith_w_flag = (IF_ID_reg_inst[6:0]==7'b0011011)?1'b1:1'b0;

//**********************************************************************************************
//!instruction decode
//rv64i decode
assign lui          =   (IF_ID_reg_inst[6:0]            ==      7'b0110111  ) ? 1'b1 : 1'b0;
assign auipc        =   (IF_ID_reg_inst[6:0]            ==      7'b0010111  ) ? 1'b1 : 1'b0;
assign jal          =   (IF_ID_reg_inst[6:0]            ==      7'b1101111  ) ? 1'b1 : 1'b0;
assign jalr         =   ({funct3,IF_ID_reg_inst[6:0]}   ==  10'b0001100111  ) ? 1'b1 : 1'b0;

assign beq          =   (B_flag&(funct3==3'b000))?1'b1:1'b0;
assign bne          =   (B_flag&(funct3==3'b001))?1'b1:1'b0;
assign blt          =   (B_flag&(funct3==3'b100))?1'b1:1'b0;
assign bge          =   (B_flag&(funct3==3'b101))?1'b1:1'b0;
assign bltu         =   (B_flag&(funct3==3'b110))?1'b1:1'b0;
assign bgeu         =   (B_flag&(funct3==3'b111))?1'b1:1'b0;

assign lb           =   (load_flag&(funct3==3'b000))?1'b1:1'b0;
assign lbu          =   (load_flag&(funct3==3'b100))?1'b1:1'b0;
assign lh           =   (load_flag&(funct3==3'b001))?1'b1:1'b0;
assign lhu          =   (load_flag&(funct3==3'b101))?1'b1:1'b0;
assign lw           =   (load_flag&(funct3==3'b010))?1'b1:1'b0;
assign lwu          =   (load_flag&(funct3==3'b110))?1'b1:1'b0;
assign ld           =   (load_flag&(funct3==3'b011))?1'b1:1'b0;

assign sb           =   (S_flag&(funct3==3'b000))?1'b1:1'b0;
assign sh           =   (S_flag&(funct3==3'b001))?1'b1:1'b0;
assign sw           =   (S_flag&(funct3==3'b010))?1'b1:1'b0;
assign sd           =   (S_flag&(funct3==3'b011))?1'b1:1'b0;

assign addi         =   (arith_flag&(funct3==3'b0))   ?1'b1:1'b0;
assign slti         =   (arith_flag&(funct3==3'h2))   ?1'b1:1'b0;
assign sltiu        =   (arith_flag&(funct3==3'h3))   ?1'b1:1'b0;
assign xori         =   (arith_flag&(funct3==3'h4))   ?1'b1:1'b0;
assign ori          =   (arith_flag&(funct3==3'h6))   ?1'b1:1'b0; 
assign andi         =   (arith_flag&(funct3==3'h7))   ?1'b1:1'b0; 
assign slli         =   (arith_flag&({IF_ID_reg_inst[31:26],funct3}==9'h001))?1'b1:1'b0;
assign srli         =   (arith_flag&({IF_ID_reg_inst[31:26],funct3}==9'h005))?1'b1:1'b0;
assign srai         =   (arith_flag&({IF_ID_reg_inst[31:26],funct3}==9'h085))?1'b1:1'b0;

assign add          =   (R_flag&({funct3,funct7}==10'h000))?1'b1:1'b0;
assign sub          =   (R_flag&({funct3,funct7}==10'h020))?1'b1:1'b0;
assign sll          =   (R_flag&({funct7,funct3}==10'h001))?1'b1:1'b0;
assign slt          =   (R_flag&({funct7,funct3}==10'h002))?1'b1:1'b0;
assign sltu         =   (R_flag&({funct7,funct3}==10'h003))?1'b1:1'b0;
assign XOR          =   (R_flag&({funct7,funct3}==10'h004))?1'b1:1'b0;
assign srl          =   (R_flag&({funct7,funct3}==10'h005))?1'b1:1'b0;
assign sra          =   (R_flag&({funct7,funct3}==10'h105))?1'b1:1'b0;
assign OR           =   (R_flag&({funct7,funct3}==10'h006))?1'b1:1'b0;
assign AND          =   (R_flag&({funct7,funct3}==10'h007))?1'b1:1'b0;

assign addiw        =   (arith_w_flag&(funct3==3'b0))   ?1'b1:1'b0;
assign slliw        =   (arith_w_flag&({IF_ID_reg_inst[31:25],funct3}==10'h001))?1'b1:1'b0;
assign srliw        =   (arith_w_flag&({IF_ID_reg_inst[31:25],funct3}==10'h005))?1'b1:1'b0;
assign sraiw        =   (arith_w_flag&({IF_ID_reg_inst[31:25],funct3}==10'h105))?1'b1:1'b0;
assign addw         =   (RW_flag&({funct3,funct7}==10'h000))?1'b1:1'b0;
assign subw         =   (RW_flag&({funct3,funct7}==10'h020))?1'b1:1'b0;
assign sllw         =   (RW_flag&({funct7,funct3}==10'h001))?1'b1:1'b0;
assign srlw         =   (RW_flag&({funct7,funct3}==10'h005))?1'b1:1'b0;
assign sraw         =   (RW_flag&({funct7,funct3}==10'h105))?1'b1:1'b0;

assign fence        =   ({funct3,IF_ID_reg_inst[6:0]} == 10'h00F) ? 1'b1 : 1'b0;
assign fence_i      =   ({funct3,IF_ID_reg_inst[6:0]} == 10'h08F) ? 1'b1 : 1'b0;
assign sfence_vma   =   ({funct7,IF_ID_reg_inst[14:0]} == 22'h048073) ? 1'b1 : 1'b0;
assign ecall        =   (IF_ID_reg_inst ==  32'h00000073) ? 1'b1 : 1'b0;
assign ebreak       =   (IF_ID_reg_inst ==  32'h00100073) ? 1'b1 : 1'b0;

//rv64 Zicsr decode
assign csrrw        =   (CSR_flag&(funct3==3'b001))?1'b1:1'b0;
assign csrrs        =   (CSR_flag&(funct3==3'b010))?1'b1:1'b0;
assign csrrc        =   (CSR_flag&(funct3==3'b011))?1'b1:1'b0;
assign csrrwi       =   (CSR_flag&(funct3==3'b101))?1'b1:1'b0;
assign csrrsi       =   (CSR_flag&(funct3==3'b110))?1'b1:1'b0;
assign csrrci       =   (CSR_flag&(funct3==3'b111))?1'b1:1'b0;

//rv64m decode
assign mul          =   (R_flag &({funct7,funct3}==10'h008))?1'b1:1'b0;
assign mulh         =   (R_flag &({funct7,funct3}==10'h009))?1'b1:1'b0;
assign mulhsu       =   (R_flag &({funct7,funct3}==10'h00A))?1'b1:1'b0;
assign mulhu        =   (R_flag &({funct7,funct3}==10'h00B))?1'b1:1'b0;
assign div          =   (R_flag &({funct7,funct3}==10'h00C))?1'b1:1'b0;
assign divu         =   (R_flag &({funct7,funct3}==10'h00D))?1'b1:1'b0;
assign rem          =   (R_flag &({funct7,funct3}==10'h00E))?1'b1:1'b0;
assign remu         =   (R_flag &({funct7,funct3}==10'h00F))?1'b1:1'b0;
assign mulw         =   (RW_flag&({funct7,funct3}==10'h008))?1'b1:1'b0;
assign divw         =   (RW_flag&({funct7,funct3}==10'h00C))?1'b1:1'b0;
assign divuw        =   (RW_flag&({funct7,funct3}==10'h00D))?1'b1:1'b0;
assign remw         =   (RW_flag&({funct7,funct3}==10'h00E))?1'b1:1'b0;
assign remuw        =   (RW_flag&({funct7,funct3}==10'h00F))?1'b1:1'b0;

//rv64a decode
assign lr_w         =   (A_flag&(funct3==3'h2)&({IF_ID_reg_inst[31:27],rs2}==10'h040))?1'b1:1'b0;
assign sc_w         =   (A_flag&(funct3==3'h2)&({IF_ID_reg_inst[31:27]}==5'h03))?1'b1:1'b0;
assign amoswap_w    =   (A_flag&(funct3==3'h2)&({IF_ID_reg_inst[31:27]}==5'h01))?1'b1:1'b0;
assign amoadd_w     =   (A_flag&(funct3==3'h2)&({IF_ID_reg_inst[31:27]}==5'h00))?1'b1:1'b0;
assign amoxor_w     =   (A_flag&(funct3==3'h2)&({IF_ID_reg_inst[31:27]}==5'h04))?1'b1:1'b0;
assign amoand_w     =   (A_flag&(funct3==3'h2)&({IF_ID_reg_inst[31:27]}==5'h0C))?1'b1:1'b0;
assign amoor_w      =   (A_flag&(funct3==3'h2)&({IF_ID_reg_inst[31:27]}==5'h08))?1'b1:1'b0;
assign amomin_w     =   (A_flag&(funct3==3'h2)&({IF_ID_reg_inst[31:27]}==5'h10))?1'b1:1'b0;
assign amomax_w     =   (A_flag&(funct3==3'h2)&({IF_ID_reg_inst[31:27]}==5'h14))?1'b1:1'b0;
assign amominu_w    =   (A_flag&(funct3==3'h2)&({IF_ID_reg_inst[31:27]}==5'h18))?1'b1:1'b0;
assign amomaxu_w    =   (A_flag&(funct3==3'h2)&({IF_ID_reg_inst[31:27]}==5'h1C))?1'b1:1'b0;
assign lr_d         =   (A_flag&(funct3==3'h3)&({IF_ID_reg_inst[31:27],rs2}==10'h040))?1'b1:1'b0;
assign sc_d         =   (A_flag&(funct3==3'h3)&({IF_ID_reg_inst[31:27]}==5'h03))?1'b1:1'b0;
assign amoswap_d    =   (A_flag&(funct3==3'h3)&({IF_ID_reg_inst[31:27]}==5'h01))?1'b1:1'b0;
assign amoadd_d     =   (A_flag&(funct3==3'h3)&({IF_ID_reg_inst[31:27]}==5'h00))?1'b1:1'b0;
assign amoxor_d     =   (A_flag&(funct3==3'h3)&({IF_ID_reg_inst[31:27]}==5'h04))?1'b1:1'b0;
assign amoand_d     =   (A_flag&(funct3==3'h3)&({IF_ID_reg_inst[31:27]}==5'h0C))?1'b1:1'b0;
assign amoor_d      =   (A_flag&(funct3==3'h3)&({IF_ID_reg_inst[31:27]}==5'h08))?1'b1:1'b0;
assign amomin_d     =   (A_flag&(funct3==3'h3)&({IF_ID_reg_inst[31:27]}==5'h10))?1'b1:1'b0;
assign amomax_d     =   (A_flag&(funct3==3'h3)&({IF_ID_reg_inst[31:27]}==5'h14))?1'b1:1'b0;
assign amominu_d    =   (A_flag&(funct3==3'h3)&({IF_ID_reg_inst[31:27]}==5'h18))?1'b1:1'b0;
assign amomaxu_d    =   (A_flag&(funct3==3'h3)&({IF_ID_reg_inst[31:27]}==5'h1C))?1'b1:1'b0;

assign mret         =   (IF_ID_reg_inst ==  32'h30200073) ? 1'b1 : 1'b0;
assign sret         =   (IF_ID_reg_inst ==  32'h10200073) ? 1'b1 : 1'b0;
assign dret         =   (IF_ID_reg_inst ==  32'h7b200073) ? 1'b1 : 1'b0;
assign wfi          =   (IF_ID_reg_inst ==  32'h10500073) ? 1'b1 : 1'b0;
//**********************************************************************************************
// assign Data_Conflict = ((rs1 == EX_LS_reg_rd) & EX_LS_reg_execute_valid & (rs1 != 5'h0) & rs1_valid & (EX_LS_reg_load_valid | EX_LS_reg_atomic_valid) & EX_LS_reg_dest_wen) |
//                         ((rs2 == EX_LS_reg_rd) & EX_LS_reg_execute_valid & (rs2 != 5'h0) & rs2_valid & (EX_LS_reg_load_valid | EX_LS_reg_atomic_valid) & EX_LS_reg_dest_wen) |
//                         ((rs1 == ID_EX_reg_rd) & ID_EX_reg_decode_valid & (rs1 != 5'h0) & rs1_valid & ID_EX_reg_dest_wen) |
//                         ((rs2 == ID_EX_reg_rd) & ID_EX_reg_decode_valid & (rs2 != 5'h0) & rs2_valid & ID_EX_reg_dest_wen);
// always @(*) begin
//     if((rs1 == EX_LS_reg_rd) & EX_LS_reg_execute_valid & (rs1 != 5'h0) & rs1_valid & EX_LS_reg_dest_wen)begin
//         src1 = EX_LS_reg_operand;
//     end
//     else if((rs1 == LS_WB_reg_rd) & LS_WB_reg_ls_valid & (rs1 != 5'h0) & rs1_valid & LS_WB_reg_dest_wen)begin
//         src1 = LS_WB_reg_data;
//     end
//     else begin
//         src1 = WB_ID_src1;
//     end
// end
// always @(*) begin
//     if((rs2 == EX_LS_reg_rd) & EX_LS_reg_execute_valid & (rs2 != 5'h0) & rs2_valid & EX_LS_reg_dest_wen)begin
//         src2 = EX_LS_reg_operand;
//     end
//     else if((rs2 == LS_WB_reg_rd) & LS_WB_reg_ls_valid & (rs2 != 5'h0) & rs2_valid & LS_WB_reg_dest_wen)begin
//         src2 = LS_WB_reg_data;
//     end
//     else begin
//         src2 = WB_ID_src2;
//     end
// end
//!output sign decode
//common
assign next_PC          = (IF_ID_reg_inst_compress_flag) ? (IF_ID_reg_PC + 2) : (IF_ID_reg_PC + 4);
assign rs1_valid        = (A_flag | R_flag | RW_flag | I_flag | S_flag | B_flag | csrrw | csrrc | csrrs);
assign rs2_valid        = (B_flag | R_flag | RW_flag | A_flag | S_flag);
assign rd               = IF_ID_reg_inst[11:7];
assign dest_wen         = (I_flag | U_flag | A_flag | R_flag | RW_flag | J_flag | csr_ren);
//control_sign:
assign alu_sub          = (set_valid | branch_valid | sub | subw);
assign word             = (addw | addiw | subw);
//logic_sign:
assign logic_valid      = (OR | XOR | AND | ori | xori | andi);
assign logic_or         = (OR | ori);
assign logic_xor        = (XOR | xori);
assign logic_and        = (AND | andi);
//load_sign:
assign load_valid       = (lb | lbu | lh | lhu | lw | lwu | ld);
assign load_signed      = (lb | lh | lw | ld);
assign load_byte        = (lb | lbu);
assign load_half        = (lh | lhu);
assign load_word        = (lw | lwu);
assign load_double      = (ld);
//store_sign:
assign store_valid      = (sb | sh | sw | sd);
assign store_byte       = (sb);
assign store_half       = (sh);
assign store_word       = (sw);
assign store_double     = (sd);
//branch:
assign branch_valid     = (bne | beq | blt | bltu | bge | bgeu);
assign branch_ne        = (bne);
assign branch_eq        = (beq);
assign branch_lt        = (blt | bltu);
assign branch_ge        = (bge | bgeu);
assign branch_signed    = (bne | beq | blt | bge);
//shift:
assign shift_valid      = (sll | slli | sllw | slliw | sra | srai | sraw | sraiw | srl | srli | srlw | srliw);
assign shift_al         = (sra | srai | sraw | sraiw);
assign shift_lr         = (sll | slli | sllw | slliw);
assign shift_word       = (sllw | slliw | srlw | srliw | sraw | sraiw);
//set:
assign set_valid        = (slt | sltu | slti | sltiu);
assign set_signed       = (slt | slti);
//jump:
assign jump_valid       = (jal | jalr);
assign jump_jalr        = jalr;
//Zicsr:
assign csr_valid        = (csrrw | csrrwi | csrrc | csrrci | csrrs | csrrsi);
assign csr_ren          = (csrrc | csrrci | csrrs | csrrsi | ((csrrw | csrrwi) & (rd != 5'h0)));
assign csr_wen          = (((csrrc | csrrci | csrrs | csrrsi) & (rs1 != 5'h0)) | csrrw | csrrwi);
assign csr_addr         = IF_ID_reg_inst[31:20];
assign csr_addr_legal   = ( (csr_addr == `CSR_ADDR_MISA          ) |
                            (csr_addr == `CSR_ADDR_MVENDORID     ) |
                            (csr_addr == `CSR_ADDR_MARCHID       ) |
                            (csr_addr == `CSR_ADDR_MIMPID        ) |
                            (csr_addr == `CSR_ADDR_MHARTID       ) |
                            (csr_addr == `CSR_ADDR_MSTATUS       ) |
                            (csr_addr == `CSR_ADDR_MTVEC         ) |
                            (csr_addr == `CSR_ADDR_MEDELEG       ) |
                            (csr_addr == `CSR_ADDR_MIDELEG       ) |
                            (csr_addr == `CSR_ADDR_MIP           ) |
                            (csr_addr == `CSR_ADDR_MIE           ) |
                            (csr_addr == `CSR_ADDR_MCYCLE        ) |
                            (csr_addr == `CSR_ADDR_MINSTRET      ) |
                            (csr_addr == `CSR_ADDR_MHPMCOUNTER3  ) |
                            (csr_addr == `CSR_ADDR_MHPMCOUNTER4  ) |
                            (csr_addr == `CSR_ADDR_MHPMCOUNTER5  ) |
                            (csr_addr == `CSR_ADDR_MHPMCOUNTER6  ) |
                            (csr_addr == `CSR_ADDR_MHPMCOUNTER7  ) |
                            (csr_addr == `CSR_ADDR_MHPMCOUNTER8  ) |
                            (csr_addr == `CSR_ADDR_MHPMCOUNTER9  ) |
                            (csr_addr == `CSR_ADDR_MHPMCOUNTER10 ) |
                            (csr_addr == `CSR_ADDR_MHPMCOUNTER11 ) |
                            (csr_addr == `CSR_ADDR_MHPMCOUNTER12 ) |
                            (csr_addr == `CSR_ADDR_MHPMCOUNTER13 ) |
                            (csr_addr == `CSR_ADDR_MHPMCOUNTER14 ) |
                            (csr_addr == `CSR_ADDR_MHPMCOUNTER15 ) |
                            (csr_addr == `CSR_ADDR_MHPMCOUNTER16 ) |
                            (csr_addr == `CSR_ADDR_MHPMCOUNTER17 ) |
                            (csr_addr == `CSR_ADDR_MHPMCOUNTER18 ) |
                            (csr_addr == `CSR_ADDR_MHPMCOUNTER19 ) |
                            (csr_addr == `CSR_ADDR_MHPMCOUNTER20 ) |
                            (csr_addr == `CSR_ADDR_MHPMCOUNTER21 ) |
                            (csr_addr == `CSR_ADDR_MHPMCOUNTER22 ) |
                            (csr_addr == `CSR_ADDR_MHPMCOUNTER23 ) |
                            (csr_addr == `CSR_ADDR_MHPMCOUNTER24 ) |
                            (csr_addr == `CSR_ADDR_MHPMCOUNTER25 ) |
                            (csr_addr == `CSR_ADDR_MHPMCOUNTER26 ) |
                            (csr_addr == `CSR_ADDR_MHPMCOUNTER27 ) |
                            (csr_addr == `CSR_ADDR_MHPMCOUNTER28 ) |
                            (csr_addr == `CSR_ADDR_MHPMCOUNTER29 ) |
                            (csr_addr == `CSR_ADDR_MHPMCOUNTER3  ) |
                            (csr_addr == `CSR_ADDR_MHPMCOUNTER3  ) |
                            (csr_addr == `CSR_ADDR_MHPMENVENT3   ) |
                            (csr_addr == `CSR_ADDR_MHPMENVENT4   ) |
                            (csr_addr == `CSR_ADDR_MHPMENVENT5   ) |
                            (csr_addr == `CSR_ADDR_MHPMENVENT6   ) |
                            (csr_addr == `CSR_ADDR_MHPMENVENT7   ) |
                            (csr_addr == `CSR_ADDR_MHPMENVENT8   ) |
                            (csr_addr == `CSR_ADDR_MHPMENVENT9   ) |
                            (csr_addr == `CSR_ADDR_MHPMENVENT10  ) |
                            (csr_addr == `CSR_ADDR_MHPMENVENT11  ) |
                            (csr_addr == `CSR_ADDR_MHPMENVENT12  ) |
                            (csr_addr == `CSR_ADDR_MHPMENVENT13  ) |
                            (csr_addr == `CSR_ADDR_MHPMENVENT14  ) |
                            (csr_addr == `CSR_ADDR_MHPMENVENT15  ) |
                            (csr_addr == `CSR_ADDR_MHPMENVENT16  ) |
                            (csr_addr == `CSR_ADDR_MHPMENVENT17  ) |
                            (csr_addr == `CSR_ADDR_MHPMENVENT18  ) |
                            (csr_addr == `CSR_ADDR_MHPMENVENT19  ) |
                            (csr_addr == `CSR_ADDR_MHPMENVENT20  ) |
                            (csr_addr == `CSR_ADDR_MHPMENVENT21  ) |
                            (csr_addr == `CSR_ADDR_MHPMENVENT22  ) |
                            (csr_addr == `CSR_ADDR_MHPMENVENT23  ) |
                            (csr_addr == `CSR_ADDR_MHPMENVENT24  ) |
                            (csr_addr == `CSR_ADDR_MHPMENVENT25  ) |
                            (csr_addr == `CSR_ADDR_MHPMENVENT26  ) |
                            (csr_addr == `CSR_ADDR_MHPMENVENT27  ) |
                            (csr_addr == `CSR_ADDR_MHPMENVENT28  ) |
                            (csr_addr == `CSR_ADDR_MHPMENVENT29  ) |
                            (csr_addr == `CSR_ADDR_MHPMENVENT30  ) |
                            (csr_addr == `CSR_ADDR_MHPMENVENT31  ) |
                            (csr_addr == `CSR_ADDR_MCOUNTEREN    ) |
                            (csr_addr == `CSR_ADDR_MCOUNTINHIBIT ) |
                            (csr_addr == `CSR_ADDR_MSCRATCH      ) |
                            (csr_addr == `CSR_ADDR_MEPC          ) |
                            (csr_addr == `CSR_ADDR_MCAUSE        ) |
                            (csr_addr == `CSR_ADDR_MTVAL         ) |
                            (csr_addr == `CSR_ADDR_MCONFIGPTR    ) |
                            (csr_addr == `CSR_ADDR_MENVCFG       ) |
                            (csr_addr == `CSR_ADDR_MSECCFG       ) |
                            (csr_addr == `CSR_ADDR_SSTATUS       ) |
                            (csr_addr == `CSR_ADDR_STVEC         ) |
                            (csr_addr == `CSR_ADDR_SIP           ) |
                            (csr_addr == `CSR_ADDR_SIE           ) |
                            (csr_addr == `CSR_ADDR_SCOUNTEREN    ) |
                            (csr_addr == `CSR_ADDR_SSCRATCH      ) |
                            (csr_addr == `CSR_ADDR_SEPC          ) |
                            (csr_addr == `CSR_ADDR_SCAUSE        ) |
                            (csr_addr == `CSR_ADDR_STVAL         ) |
                            (csr_addr == `CSR_ADDR_SENVCFG       ) |
                            (csr_addr == `CSR_ADDR_SATP          ) |
                            (csr_addr == `CSR_ADDR_CYCLE         ) |
                            (csr_addr == `CSR_ADDR_INSTRET       ) |
                            (csr_addr == `CSR_ADDR_HPMCOUNTER3   ) |
                            (csr_addr == `CSR_ADDR_HPMCOUNTER4   ) |
                            (csr_addr == `CSR_ADDR_HPMCOUNTER5   ) |
                            (csr_addr == `CSR_ADDR_HPMCOUNTER6   ) |
                            (csr_addr == `CSR_ADDR_HPMCOUNTER7   ) |
                            (csr_addr == `CSR_ADDR_HPMCOUNTER8   ) |
                            (csr_addr == `CSR_ADDR_HPMCOUNTER9   ) |
                            (csr_addr == `CSR_ADDR_HPMCOUNTER10  ) |
                            (csr_addr == `CSR_ADDR_HPMCOUNTER11  ) |
                            (csr_addr == `CSR_ADDR_HPMCOUNTER12  ) |
                            (csr_addr == `CSR_ADDR_HPMCOUNTER13  ) |
                            (csr_addr == `CSR_ADDR_HPMCOUNTER14  ) |
                            (csr_addr == `CSR_ADDR_HPMCOUNTER15  ) |
                            (csr_addr == `CSR_ADDR_HPMCOUNTER16  ) |
                            (csr_addr == `CSR_ADDR_HPMCOUNTER17  ) |
                            (csr_addr == `CSR_ADDR_HPMCOUNTER18  ) |
                            (csr_addr == `CSR_ADDR_HPMCOUNTER19  ) |
                            (csr_addr == `CSR_ADDR_HPMCOUNTER20  ) |
                            (csr_addr == `CSR_ADDR_HPMCOUNTER21  ) |
                            (csr_addr == `CSR_ADDR_HPMCOUNTER22  ) |
                            (csr_addr == `CSR_ADDR_HPMCOUNTER23  ) |
                            (csr_addr == `CSR_ADDR_HPMCOUNTER24  ) |
                            (csr_addr == `CSR_ADDR_HPMCOUNTER25  ) |
                            (csr_addr == `CSR_ADDR_HPMCOUNTER26  ) |
                            (csr_addr == `CSR_ADDR_HPMCOUNTER27  ) |
                            (csr_addr == `CSR_ADDR_HPMCOUNTER28  ) |
                            (csr_addr == `CSR_ADDR_HPMCOUNTER29  ) |
                            (csr_addr == `CSR_ADDR_HPMCOUNTER30  ) |
                            (csr_addr == `CSR_ADDR_HPMCOUNTER31  ) |
                            ((csr_addr == `CSR_ADDR_DCSR         ) & debug_mode) |
                            ((csr_addr == `CSR_ADDR_DPC          ) & debug_mode) |
                            ((csr_addr == `CSR_ADDR_DSCRATCH0    ) & debug_mode) |
                            ((csr_addr == `CSR_ADDR_DSCRATCH1    ) & debug_mode));
assign csr_set          = (csrrs | csrrsi);
assign csr_clear        = (csrrc | csrrci);
assign csr_swap         = (csrrw | csrrwi);    
//mul:
assign mul_valid        = (mul | mulh | mulhsu | mulhu | mulw);
assign mul_high         = (mulh | mulhsu | mulhu);
assign mul_signed       = {(mulh | mulhsu | mul | mulw), (mulh | mul | mulw)};
assign mul_word         = (mulw);
assign div_valid        = (div | divu | rem | remu | divw | divuw | remw | remuw);
assign div_signed       = (div | rem | divw | remw);
assign div_rem          = (rem | remu | remw | remuw);
assign div_word         = (divw | divuw | remw | remuw);
//atomic:
assign atomic_valid     = (atomic_lr | atomic_sc | atomic_swap | atomic_add | atomic_xor | atomic_and | atomic_or | atomic_min | atomic_max);
assign atomic_word      = (lr_w | sc_w | amoswap_w | amoadd_w | amoand_w | amoxor_w | amoor_w | amomin_w | amominu_w | amomax_w | amomaxu_w);
assign atomic_lr        = (lr_w | lr_d);
assign atomic_sc        = (sc_w | sc_d);
assign atomic_swap      = (amoswap_w | amoswap_d);
assign atomic_add       = (amoadd_w | amoadd_d);
assign atomic_xor       = (amoxor_w | amoxor_d);
assign atomic_and       = (amoand_w | amoand_d);
assign atomic_or        = (amoor_w | amoor_d);
assign atomic_min       = (amomin_w | amominu_w | amomin_d | amominu_d);
assign atomic_max       = (amomax_w | amomaxu_w | amomax_d | amomaxu_d);
assign atomic_signed    = (!(amominu_w | amominu_d | amomaxu_w | amomaxu_d));
//trap:
assign trap_valid       = (ecall | ebreak | (IF_ID_reg_rresp != 2'h0) | illegal_instruction);
assign mret_valid       = (mret);
assign sret_valid       = (sret);
assign dret_valid       = (dret);
assign trap_cause       = ((IF_ID_reg_rresp == 2'h2) ? 64'hC : (
                            (illegal_instruction) ? 64'h2 :(
                                (ebreak) ? 64'h3 : (
                                    (IF_ID_reg_rresp == 2'h3) ? 64'h1 :(
                                        (ecall & (current_priv_status == `PRV_M)) ? 64'hB : (
                                            (ecall & (current_priv_status == `PRV_S)) ? 64'h9 : (
                                                (ecall & (current_priv_status == `PRV_U)) ? 64'h8 : 64'h0
                                            )
                                        )
                                    )
                                )
                            ) 
                        ));
assign trap_tval        = (((IF_ID_reg_rresp != 2'h0) | (ebreak)) ? IF_ID_reg_PC : (
                            (illegal_instruction & IF_ID_reg_inst_compress_flag) ? {48'h0, IF_ID_reg_inst_compress} :(
                                (illegal_instruction & (!IF_ID_reg_inst_compress_flag)) ? {32'h0, IF_ID_reg_inst} : 64'h0
                            ) 
                        ));
//operand
assign operand1         = (lui) ? 0 : ((auipc | jal | jalr) ? IF_ID_reg_PC : (csrrci | csrrwi | csrrsi) ? imm : 64'h0);
assign operand2         = (jal | jalr) ? ((IF_ID_reg_inst_compress_flag) ? 64'h2 : 64'h4) : (
                            (csrrw | csrrwi) ? 64'h0 : (
                                (csrrc | csrrci | csrrs | csrrsi) ? WB_ID_csr_rdata : (
                                    (I_flag | U_flag | S_flag) ? imm : 64'h0
                                )
                            )
                        );
// assign operand3         = (jalr) ? src1 : IF_ID_reg_PC;
assign operand4         = imm;
//illegal instruction judge
assign illegal_instruction = ((!(logic_valid | load_valid | store_valid | branch_valid | shift_valid | 
                                set_valid | jump_valid | csr_valid | mul_valid | div_valid | atomic_valid | mret | 
                                sret | dret | wfi | lui | auipc | add | addi | sub | addw | addiw | subw | ecall | 
                                ebreak | fence | fence_i | sfence_vma)) | 
                                (csr_valid & ((csr_addr[9:8] > current_priv_status) | (csr_wen & (csr_addr[11:10] == 2'h3)) | (!csr_addr_legal))) | 
                                /*disable all access csr form U*/(csr_valid & (current_priv_status == `PRV_U)) | 
                                /*disable access time form S*/   (csr_valid & (current_priv_status == `PRV_S) & (csr_addr == 12'hC01)) | 
                                /*disable wfi time form S&U*/    (wfi & (current_priv_status < `PRV_M) & TW) | 
                                //! todo need to add the sfence.vma and need to trap the sfence.vma
                                /*disable access satp form S*/   (csr_valid & (current_priv_status == `PRV_S) & (csr_addr == 12'h180) & TVM) | 
                                /*disable dret on no debug*/     (dret & (!debug_mode)) |
                                /*disable sret form S*/          (sret & (current_priv_status == `PRV_S) & TSR) | 
                                /*disable mret form S*/          (mret & (current_priv_status == `PRV_S)) | 
                                /*disable sret form U*/          (sret & (current_priv_status == `PRV_U)) | 
                                /*disable mret form U*/          (mret & (current_priv_status == `PRV_U)));
//**********************************************************************************************
//!output 
assign ID_IF_inst_ready     = IF_ID_reg_inst_valid & (EX_ID_decode_ready | (!ID_EX_reg_decode_valid)) & (!EX_IF_jump_flag) & ((
                            (!(EX_LS_reg_execute_valid & EX_LS_reg_csr_wen)) & (!(LS_WB_reg_ls_valid & LS_WB_reg_csr_wen)) &
                            (!(ID_EX_reg_decode_valid & ID_EX_reg_csr_wen))) | trap_valid | mret_valid | sret_valid | dret_valid) & (!EX_ID_flush_flag) & 
                            (!(ID_EX_reg_decode_valid & (ID_EX_reg_trap_valid | ID_EX_reg_mret_valid | ID_EX_reg_sret_valid | ID_EX_reg_dret_valid)));
assign ID_IF_flush_flag     = (EX_ID_flush_flag | (ID_EX_reg_decode_valid & (ID_EX_reg_trap_valid | ID_EX_reg_mret_valid | ID_EX_reg_sret_valid | ID_EX_reg_dret_valid)));
//common
FF_D_with_syn_rst #(
    .DATA_LEN 	( 1  ),
    .RST_DATA 	( 0  )
)u_decode_valid
(
    .clk      	( clk                                               ),
    .rst_n    	( rst_n                                             ),
    .syn_rst    ( EX_ID_flush_flag                                  ),
    .wen        ( (EX_ID_decode_ready | (!ID_EX_reg_decode_valid))  ),
    .data_in  	( ID_IF_inst_ready                                  ),
    .data_out 	( ID_EX_reg_decode_valid                            )
);
FF_D_without_asyn_rst #(5)  u_rd            (clk,ID_IF_inst_ready,rd,ID_EX_reg_rd);
FF_D_without_asyn_rst #(1)  u_dest_wen      (clk,ID_IF_inst_ready,dest_wen,ID_EX_reg_dest_wen);
FF_D_without_asyn_rst #(32) u_inst          (clk,ID_IF_inst_ready,IF_ID_reg_inst,ID_EX_reg_inst);
FF_D_without_asyn_rst #(5)  u_rs1           (clk,ID_IF_inst_ready,rs1 & {5{rs1_valid}},ID_EX_reg_rs1);
FF_D_without_asyn_rst #(5)  u_rs2           (clk,ID_IF_inst_ready,rs2 & {5{rs2_valid}},ID_EX_reg_rs2);
FF_D_without_asyn_rst #(64) u_PC            (clk,ID_IF_inst_ready,IF_ID_reg_PC,ID_EX_reg_PC);
FF_D_without_asyn_rst #(64) u_next_PC       (clk,ID_IF_inst_ready,next_PC,ID_EX_reg_next_PC);
//control_sign:
FF_D_without_asyn_rst #(1)  u_sub           (clk,ID_IF_inst_ready,alu_sub,ID_EX_reg_sub);
FF_D_without_asyn_rst #(1)  u_word          (clk,ID_IF_inst_ready,word,ID_EX_reg_word);
//logic_sign:
FF_D_without_asyn_rst #(1)  u_logic_valid   (clk,ID_IF_inst_ready,logic_valid,ID_EX_reg_logic_valid);
FF_D_without_asyn_rst #(1)  u_logic_or      (clk,ID_IF_inst_ready,logic_or,ID_EX_reg_logic_or);
FF_D_without_asyn_rst #(1)  u_logic_xor     (clk,ID_IF_inst_ready,logic_xor,ID_EX_reg_logic_xor);
FF_D_without_asyn_rst #(1)  u_logic_and     (clk,ID_IF_inst_ready,logic_and,ID_EX_reg_logic_and);
//load_sign:
FF_D_without_asyn_rst #(1)  u_load_valid    (clk,ID_IF_inst_ready,load_valid,ID_EX_reg_load_valid);
FF_D_without_asyn_rst #(1)  u_load_signed   (clk,ID_IF_inst_ready,load_signed,ID_EX_reg_load_signed);
FF_D_without_asyn_rst #(1)  u_load_byte     (clk,ID_IF_inst_ready,load_byte,ID_EX_reg_load_byte);
FF_D_without_asyn_rst #(1)  u_load_half     (clk,ID_IF_inst_ready,load_half,ID_EX_reg_load_half);
FF_D_without_asyn_rst #(1)  u_load_word     (clk,ID_IF_inst_ready,load_word,ID_EX_reg_load_word);
FF_D_without_asyn_rst #(1)  u_load_double   (clk,ID_IF_inst_ready,load_double,ID_EX_reg_load_double);
//store_sign:
FF_D_without_asyn_rst #(1)  u_store_valid   (clk,ID_IF_inst_ready,store_valid,ID_EX_reg_store_valid);
FF_D_without_asyn_rst #(1)  u_store_byte    (clk,ID_IF_inst_ready,store_byte,ID_EX_reg_store_byte);
FF_D_without_asyn_rst #(1)  u_store_half    (clk,ID_IF_inst_ready,store_half,ID_EX_reg_store_half);
FF_D_without_asyn_rst #(1)  u_store_word    (clk,ID_IF_inst_ready,store_word,ID_EX_reg_store_word);
FF_D_without_asyn_rst #(1)  u_store_double  (clk,ID_IF_inst_ready,store_double,ID_EX_reg_store_double);
// FF_D_without_asyn_rst #(64) u_store_data    (clk,ID_IF_inst_ready,src2,ID_EX_reg_store_data);
//branch:
FF_D_without_asyn_rst #(1)  u_branch_valid  (clk,ID_IF_inst_ready,branch_valid,ID_EX_reg_branch_valid);
FF_D_without_asyn_rst #(1)  u_branch_ne     (clk,ID_IF_inst_ready,branch_ne,ID_EX_reg_branch_ne);
FF_D_without_asyn_rst #(1)  u_branch_eq     (clk,ID_IF_inst_ready,branch_eq,ID_EX_reg_branch_eq);
FF_D_without_asyn_rst #(1)  u_branch_lt     (clk,ID_IF_inst_ready,branch_lt,ID_EX_reg_branch_lt);
FF_D_without_asyn_rst #(1)  u_branch_ge     (clk,ID_IF_inst_ready,branch_ge,ID_EX_reg_branch_ge);
FF_D_without_asyn_rst #(1)  u_branch_signed (clk,ID_IF_inst_ready,branch_signed,ID_EX_reg_branch_signed);
//shift:
FF_D_without_asyn_rst #(1)  u_shift_valid   (clk,ID_IF_inst_ready,shift_valid,ID_EX_reg_shift_valid);
FF_D_without_asyn_rst #(1)  u_shift_al      (clk,ID_IF_inst_ready,shift_al,ID_EX_reg_shift_al);
FF_D_without_asyn_rst #(1)  u_shift_lr      (clk,ID_IF_inst_ready,shift_lr,ID_EX_reg_shift_lr);
FF_D_without_asyn_rst #(1)  u_shift_word    (clk,ID_IF_inst_ready,shift_word,ID_EX_reg_shift_word);
//set:
FF_D_without_asyn_rst #(1)  u_set_valid     (clk,ID_IF_inst_ready,set_valid,ID_EX_reg_set_valid);
FF_D_without_asyn_rst #(1)  u_set_signed    (clk,ID_IF_inst_ready,set_signed,ID_EX_reg_set_signed);
//jump:
FF_D_without_asyn_rst #(1)  u_jump_valid     (clk,ID_IF_inst_ready,jump_valid,ID_EX_reg_jump_valid);
FF_D_without_asyn_rst #(1)  u_jump_jalr      (clk,ID_IF_inst_ready,jump_jalr,ID_EX_reg_jump_jalr);
//Zicsr:
FF_D_without_asyn_rst #(1)  u_csr_valid     (clk,ID_IF_inst_ready,csr_valid,ID_EX_reg_csr_valid);
FF_D_without_asyn_rst #(1)  u_csr_wen       (clk,ID_IF_inst_ready,csr_wen,ID_EX_reg_csr_wen);
FF_D_without_asyn_rst #(1)  u_csr_ren       (clk,ID_IF_inst_ready,csr_ren,ID_EX_reg_csr_ren);
FF_D_without_asyn_rst #(12) u_csr_addr      (clk,ID_IF_inst_ready,csr_addr,ID_EX_reg_csr_addr);
FF_D_without_asyn_rst #(1)  u_csr_set       (clk,ID_IF_inst_ready,csr_set,ID_EX_reg_csr_set);
FF_D_without_asyn_rst #(1)  u_csr_clear     (clk,ID_IF_inst_ready,csr_clear,ID_EX_reg_csr_clear);
FF_D_without_asyn_rst #(1)  u_csr_swap      (clk,ID_IF_inst_ready,csr_swap,ID_EX_reg_csr_swap);
//mul:
FF_D_without_asyn_rst #(1)  u_mul_valid     (clk,ID_IF_inst_ready,mul_valid,ID_EX_reg_mul_valid);
FF_D_without_asyn_rst #(1)  u_mul_high      (clk,ID_IF_inst_ready,mul_high,ID_EX_reg_mul_high);
FF_D_without_asyn_rst #(2)  u_mul_signed    (clk,ID_IF_inst_ready,mul_signed,ID_EX_reg_mul_signed);
FF_D_without_asyn_rst #(1)  u_mul_word      (clk,ID_IF_inst_ready,mul_word,ID_EX_reg_mul_word);
FF_D_without_asyn_rst #(1)  u_div_valid     (clk,ID_IF_inst_ready,div_valid,ID_EX_reg_div_valid);
FF_D_without_asyn_rst #(1)  u_div_signed    (clk,ID_IF_inst_ready,div_signed,ID_EX_reg_div_signed);
FF_D_without_asyn_rst #(1)  u_div_rem       (clk,ID_IF_inst_ready,div_rem,ID_EX_reg_div_rem);
FF_D_without_asyn_rst #(1)  u_div_word      (clk,ID_IF_inst_ready,div_word,ID_EX_reg_div_word);
//atomic:
FF_D_without_asyn_rst #(1)  u_atomic_valid  (clk,ID_IF_inst_ready,atomic_valid,ID_EX_reg_atomic_valid);
FF_D_without_asyn_rst #(1)  u_matomic_word  (clk,ID_IF_inst_ready,atomic_word,ID_EX_reg_atomic_word);
FF_D_without_asyn_rst #(1)  u_atomic_lr     (clk,ID_IF_inst_ready,atomic_lr,ID_EX_reg_atomic_lr);
FF_D_without_asyn_rst #(1)  u_atomic_sc     (clk,ID_IF_inst_ready,atomic_sc,ID_EX_reg_atomic_sc);
FF_D_without_asyn_rst #(1)  u_atomic_swap   (clk,ID_IF_inst_ready,atomic_swap,ID_EX_reg_atomic_swap);
FF_D_without_asyn_rst #(1)  u_atomic_add    (clk,ID_IF_inst_ready,atomic_add,ID_EX_reg_atomic_add);
FF_D_without_asyn_rst #(1)  u_atomic_xor    (clk,ID_IF_inst_ready,atomic_xor,ID_EX_reg_atomic_xor);
FF_D_without_asyn_rst #(1)  u_atomic_and    (clk,ID_IF_inst_ready,atomic_and,ID_EX_reg_atomic_and);
FF_D_without_asyn_rst #(1)  u_atomic_or     (clk,ID_IF_inst_ready,atomic_or,ID_EX_reg_atomic_or);
FF_D_without_asyn_rst #(1)  u_atomic_min    (clk,ID_IF_inst_ready,atomic_min,ID_EX_reg_atomic_min);
FF_D_without_asyn_rst #(1)  u_atomic_max    (clk,ID_IF_inst_ready,atomic_max,ID_EX_reg_atomic_max);
FF_D_without_asyn_rst #(1)  u_atomic_signed (clk,ID_IF_inst_ready,atomic_signed,ID_EX_reg_atomic_signed);
//trap:
FF_D_without_asyn_rst #(1)  u_trap_valid    (clk,ID_IF_inst_ready,trap_valid,ID_EX_reg_trap_valid);
FF_D_without_asyn_rst #(1)  u_mret_valid    (clk,ID_IF_inst_ready,mret_valid,ID_EX_reg_mret_valid);
FF_D_without_asyn_rst #(1)  u_sret_valid    (clk,ID_IF_inst_ready,sret_valid,ID_EX_reg_sret_valid);
FF_D_without_asyn_rst #(1)  u_dret_valid    (clk,ID_IF_inst_ready,dret_valid,ID_EX_reg_dret_valid);
FF_D_without_asyn_rst #(64) u_trap_cause    (clk,ID_IF_inst_ready,trap_cause,ID_EX_reg_trap_cause);
FF_D_without_asyn_rst #(64) u_trap_tval     (clk,ID_IF_inst_ready,trap_tval,ID_EX_reg_trap_tval);
//operand
FF_D_without_asyn_rst #(64) u_operand1      (clk,ID_IF_inst_ready,operand1,ID_EX_reg_operand1);
FF_D_without_asyn_rst #(64) u_operand2      (clk,ID_IF_inst_ready,operand2,ID_EX_reg_operand2);
// FF_D_without_asyn_rst #(63) u_operand3      (clk,ID_IF_inst_ready,operand3,ID_EX_reg_operand3);
assign ID_EX_reg_operand3 = ID_EX_reg_PC;
FF_D_without_asyn_rst #(64) u_operand4      (clk,ID_IF_inst_ready,operand4,ID_EX_reg_operand4);
//**********************************************************************************************

endmodule //idu
//the channel 1 is to GPR, channel 2 is to jump_pc
// U:
// LUI: 	0 	    +	    imm
// AUPIC:	PC	    +       imm
// J:
// JAL：	PC	    + 	    4/2		    PC	        +	imm
// I:
// JALR:	PC	    +	    4/2		    SRC1	    +	imm
// LB:	    SRC1	+	    imm
// LH:	    SRC1	+	    imm
// LW:	    SRC1	+	    imm
// LBU:	    SRC1	+	    imm
// LHU:	    SRC1	+	    imm
// ADDI:	SRC1	+	    imm
// SLTI:	SRC1	-	    imm
// SLTIU:	SRC1	-	    imm
// XORI:	SRC1	^	    imm
// ORI:	    SRC1	|	    imm
// ANDI:	SRC1	&	    imm
// SLLI:	SRC1	no_op	imm
// SRLI:	SRC1	no_op	imm
// SRAI:	SRC1	no_op	imm
// B:    
// BEQ:	    SRC1	-	    SRC2		PC	        +	imm
// BNE:	    SRC1	-	    SRC2		PC	        +	imm
// BLT:	    SRC1	-	    SRC2		PC	        +	imm
// BGE:	    SRC1	-	    SRC2		PC	        +	imm
// BLTU:	SRC1	-	    SRC2		PC	        +	imm
// BGEU:	SRC1	-	    SRC2		PC	        +	imm
// S:
// SB:	    SRC1	+	    imm
// SH:	    SRC1	+	    imm
// SW:	    SRC1	+	    imm
// R:   
// ADD:	    SRC1	+	    SRC2
// SUB:	    SRC1	-	    SRC2
// SLL:	    SRC1	no_op	SRC2
// SLT:	    SRC1	-	    SRC2
// SLTU:	SRC1	-	    SRC2
// XOR: 	SRC1	^	    SRC2
// SRL: 	SRC1	no_op	SRC2
// SRA: 	SRC1	no_op	SRC2
// OR:	    SRC1	|	    SRC2
// AND: 	SRC1	&	    SRC2

// I_W:
// ADDIW:	SRC1[31:0]	+	    imm
// SLLIW:	SRC1[31:0]	no_op	imm
// SRLIW:	SRC1[31:0]	no_op	imm
// SRAIW:	SRC1[31:0]	no_op	imm

// R_W:
// ADDW:	SRC1[31:0]	+	    SRC2[31:0]
// SUBW:	SRC1[31:0]	-	    SRC2[31:0]
// SLLW:	SRC1[31:0]	no_op	SRC2[4:0]
// SRLW:	SRC1[31:0]	no_op	SRC2[4:0]
// SRAW:	SRC1[31:0]	no_op	SRC2[4:0]

//the channel 1 is write CSR, don't use channel 2
// CSR:
// CSRRW	SRC1	+	    0		    
// CSRRS	SRC1	|	    CSR_RDATA	
// CSRRC	SRC1	|	    ~CSR_RDATA	
// CSRRWI	CSR_imm	+	    0		    
// CSRRSI	CSR_imm	|	    CSR_RDATA	
// CSRRCI	CSR_imm	|	    ~CSR_RDATA	

//the channel 1 is write GPR, don't use channel 2
// MUL:
// MUL	    SRC1	*	SRC2
// MULH	    SRC1	*	SRC2
// MULHSU	SRC1	*	SRC2
// MULHU	SRC1	*	SRC2
// MULW	    SRC1	*	SRC2
// DIV	    SRC1	/	SRC2
// DIVU	    SRC1	/	SRC2
// DIVW	    SRC1	/	SRC2
// DIVUW	SRC1	/	SRC2
// REM	    SRC1	%	SRC2
// REMU	    SRC1	%	SRC2
// REMW	    SRC1	%	SRC2
// REMUW	SRC1	%	SRC2

// ATOMIC:
// LR	SRC1	no_op	SRC2
// SC	SRC1	no_op	SRC2
// SAWP	SRC1	no_op	SRC2
// ADD	SRC1	no_op	SRC2
// XOR	SRC1	no_op	SRC2
// AND	SRC1	no_op	SRC2
// OR	SRC1	no_op	SRC2
// MIN	SRC1	no_op	SRC2
// MAX	SRC1	no_op	SRC2

//if unusual happen, Don't use the channels shutdown the wen and ren 
//if unusual return, Don't use the ALU but use the channel 2 to jump back and shutdown the wen and ren  
// unusual
// ECALL
// ret	
