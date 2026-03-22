package alu_pkg;

typedef enum logic [8:0]{ 
    // shift
    // | shift code | word flag | al flag | lr flag |
    op_sll  = 9'b000001_001,
    op_srl  = 9'b000001_000,
    op_sra  = 9'b000001_010,
    op_sllw = 9'b000001_101,
    op_srlw = 9'b000001_100,
    op_sraw = 9'b000001_110,
    // logic
    // | logic code | and flag | or flag | xor flag |
    op_and  = 9'b000010_001,
    op_or   = 9'b000010_010,
    op_xor  = 9'b000010_100,
    // sub: use src1 - src2
    // | sub code | word flag | encoding |
    op_sub  = 9'b001100_000,
    op_subw = 9'b001100_100,
    op_sltu = 9'b000100_010,
    op_slt  = 9'b000100_011,
    // add: use src1 + src2
    // | sub code | word flag | encoding |
    op_add  = 9'b001000_000,
    op_addw = 9'b001000_100
}alu_optype_t;

`define shift_word(alu_op) alu_op[2]

`define shift_al(alu_op) alu_op[1]

`define shift_lr(alu_op) alu_op[0]

`define logic_and(alu_op) alu_op[0]

`define logic_or(alu_op) alu_op[1]

`define logic_xor(alu_op) alu_op[2]

`define sub_flag(alu_op) alu_op[5]

`define shift_flag(alu_op) alu_op[3]

`define logic_flag(alu_op) alu_op[4]

`define set_flag(alu_op) ((!alu_op[6]) & (alu_op[5]))

`define add_sub_flag(alu_op) alu_op[6]

`define set_signed(alu_op) alu_op[0]

`define add_sub_word(alu_op) alu_op[2]

endpackage
