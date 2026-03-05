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

/* verilator lint_off UNUSEDSIGNAL */

function logic branch_eq;
    input bru_optype_t op;
    branch_eq = op[0];
endfunction

function logic branch_lt;
    input bru_optype_t op;
    branch_lt = op[1];
endfunction

function logic branch_ltu;
    input bru_optype_t op;
    branch_ltu = op[2];
endfunction

function logic branch_reverse;
    input bru_optype_t op;
    branch_reverse = op[3];
endfunction

/* verilator lint_on UNUSEDSIGNAL */

endpackage
