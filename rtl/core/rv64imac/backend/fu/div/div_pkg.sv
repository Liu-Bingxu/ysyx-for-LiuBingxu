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

`define div_word(div_op) div_op[3]

`define div_unsign(div_op) div_op[0]

`define div_rem(div_op) div_op[1]

endpackage
