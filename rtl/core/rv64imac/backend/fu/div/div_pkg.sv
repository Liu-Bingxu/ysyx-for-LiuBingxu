package div_pkg;

typedef enum logic [8:0]{ 
    // | word flag | func3 |
    op_div   = 9'b000000_100,
    op_divu  = 9'b000000_101,
    op_rem   = 9'b000000_110,
    op_remu  = 9'b000000_111,
    op_divw  = 9'b000001_100,
    op_divuw = 9'b000001_101,
    op_remw  = 9'b000001_110,
    op_remuw = 9'b000001_111
}div_optype_t;

/* verilator lint_off UNUSEDSIGNAL */

function logic div_word;
    input div_optype_t op;
    div_word = op[3];
endfunction

function logic div_unsign;
    input div_optype_t op;
    div_unsign = op[0];
endfunction

function logic div_rem;
    input div_optype_t op;
    div_rem = op[1];
endfunction

/* verilator lint_on UNUSEDSIGNAL */

endpackage
