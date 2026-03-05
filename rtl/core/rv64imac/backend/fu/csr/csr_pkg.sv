package csr_pkg;

typedef enum logic [8:0]{ 
    // | op type | func3 |
    op_mret     = 9'b100000_000,
    op_sret     = 9'b010000_000,
    op_dret     = 9'b001000_000,
    // ebreak和ecall通过trap信号标识
    op_wfi      = 9'b000100_000,
    op_csrrw    = 9'b000001_001,
    op_csrrs    = 9'b000001_010,
    op_csrrc    = 9'b000001_100,
    op_csrrwi   = 9'b000011_001,
    op_csrrsi   = 9'b000011_010,
    op_csrrci   = 9'b000011_100
}csr_optype_t;

/* verilator lint_off UNUSEDSIGNAL */

function logic csr_mret_flag;
    input csr_optype_t op;
    csr_mret_flag = op[8];
endfunction

function logic csr_sret_flag;
    input csr_optype_t op;
    csr_sret_flag = op[7];
endfunction

function logic csr_dret_flag;
    input csr_optype_t op;
    csr_dret_flag = op[6];
endfunction

function logic csr_acc_flag;
    input csr_optype_t op;
    csr_acc_flag = op[3];
endfunction

function logic csr_swap;
    input csr_optype_t op;
    csr_swap = op[0];
endfunction

function logic csr_set;
    input csr_optype_t op;
    csr_set = op[1];
endfunction

function logic csr_clear;
    input csr_optype_t op;
    csr_clear = op[2];
endfunction

/* verilator lint_on UNUSEDSIGNAL */

endpackage
