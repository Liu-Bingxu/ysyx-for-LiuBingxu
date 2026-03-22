package mul_pkg;


typedef enum logic [8:0]{ 
    // | word flag | high flag | signed1 flag | signed0 flag |
    op_mul    = 9'b0000_001_11,
    op_mulh   = 9'b0000_010_11,
    op_mulhsu = 9'b0000_010_10,
    op_mulhu  = 9'b0000_010_00,
    op_mulw   = 9'b0000_100_11
}mul_optype_t;

`define mul_sign(mul_op) mul_op[1:0]

`define mul_low(mul_op) mul_op[2]

`define mul_high(mul_op) mul_op[3]

`define mul_word(mul_op) mul_op[4]

endpackage
