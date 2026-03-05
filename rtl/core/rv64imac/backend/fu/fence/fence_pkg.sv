package fence_pkg;

typedef enum logic [8:0]{ 
    op_sfence      = 9'b000000_001,
    op_fence_i     = 9'b000000_010,
    op_fence       = 9'b000000_100
}fence_optype_t;

typedef enum logic[1:0] { 
    fence_idle = 2'h0,
    fencei_run = 2'h1,
    fencei_out = 2'h2
} fence_fsm_t;

/* verilator lint_off UNUSEDSIGNAL */

function logic fence_flag;
    input fence_optype_t op;
    fence_flag = op[2];
endfunction

function logic fence_i_flag;
    input fence_optype_t op;
    fence_i_flag = op[1];
endfunction

function logic sfence_flag;
    input fence_optype_t op;
    sfence_flag = op[0];
endfunction

/* verilator lint_on UNUSEDSIGNAL */

endpackage
