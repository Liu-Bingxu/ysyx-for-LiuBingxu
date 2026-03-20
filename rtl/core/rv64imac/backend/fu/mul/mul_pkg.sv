package mul_pkg;


typedef enum logic [8:0]{ 
    // | word flag | high flag | signed1 flag | signed0 flag |
    op_mul    = 9'b0000_001_11,
    op_mulh   = 9'b0000_010_11,
    op_mulhsu = 9'b0000_010_10,
    op_mulhu  = 9'b0000_010_00,
    op_mulw   = 9'b0000_100_11
}mul_optype_t;

/* verilator lint_off UNUSEDSIGNAL */

function automatic logic [1:0] mul_sign;
    input mul_optype_t op;
    mul_sign = op[1:0];
endfunction

function automatic logic mul_low;
    input mul_optype_t op;
    mul_low = op[2];
endfunction

function automatic logic mul_high;
    input mul_optype_t op;
    mul_high = op[3];
endfunction

function automatic logic mul_word;
    input mul_optype_t op;
    mul_word = op[4];
endfunction

/* verilator lint_on UNUSEDSIGNAL */

endpackage
