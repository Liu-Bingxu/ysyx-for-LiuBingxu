package bru_pkg;

typedef enum logic [8:0]{ 
    // func3
    op_beq   = 9'b000000_001,
    op_bne   = 9'b000001_001,
    op_blt   = 9'b000000_010,
    op_bge   = 9'b000001_010,
    op_bltu  = 9'b000000_100,
    op_bgeu  = 9'b000001_100
}bru_optype_t;

`define branch_eq(bru_op) bru_op[0]

`define branch_lt(bru_op) bru_op[1]

`define branch_ltu(bru_op) bru_op[2]

`define branch_reverse(bru_op) bru_op[3]

endpackage
