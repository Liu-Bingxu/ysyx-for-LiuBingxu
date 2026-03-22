package jump_pkg;


typedef enum logic [8:0]{ 
    op_auipc   = 9'b000000_001,
    op_jal     = 9'b000000_010,
    op_jalr    = 9'b000000_100
}jump_optype_t;

`define jump_auipc(jump_op) jump_op[0]

`define jump_jal(jump_op) jump_op[1]

`define jump_jalr(jump_op) jump_op[2]

endpackage
