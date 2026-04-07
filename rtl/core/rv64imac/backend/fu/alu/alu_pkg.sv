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

// function automatic logic shift_word;
//     input alu_optype_t alu_op;
//     shift_word = alu_op[2];
// endfunction

// function automatic logic shift_al;
//     input alu_optype_t alu_op;
//     shift_al = alu_op[1];
// endfunction

// function automatic logic shift_lr;
//     input alu_optype_t alu_op;
//     shift_lr = alu_op[0];
// endfunction

// function automatic logic logic_and;
//     input alu_optype_t alu_op;
//     logic_and = alu_op[0];
// endfunction

// function automatic logic logic_or;
//     input alu_optype_t alu_op;
//     logic_or = alu_op[1];
// endfunction

// function automatic logic logic_xor;
//     input alu_optype_t alu_op;
//     logic_xor = alu_op[2];
// endfunction

// function automatic logic sub_flag;
//     input alu_optype_t alu_op;
//     sub_flag = alu_op[5];
// endfunction

// function automatic logic shift_flag;
//     input alu_optype_t alu_op;
//     shift_flag = alu_op[3];
// endfunction

// function automatic logic logic_flag;
//     input alu_optype_t alu_op;
//     logic_flag = alu_op[4];
// endfunction

// function automatic logic set_flag;
//     input alu_optype_t alu_op;
//     set_flag = (!alu_op[6]) & (alu_op[5]);
// endfunction

// function automatic logic add_sub_flag;
//     input alu_optype_t alu_op;
//     add_sub_flag = alu_op[6];
// endfunction

// function automatic logic set_signed;
//     input alu_optype_t alu_op;
//     set_signed = alu_op[0];
// endfunction

// function automatic logic add_sub_word;
//     input alu_optype_t alu_op;
//     add_sub_word = alu_op[2];
// endfunction

endpackage
