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

`define csr_mret_flag(csr_op) csr_op[8]

`define csr_sret_flag(csr_op) csr_op[7]

`define csr_dret_flag(csr_op) csr_op[6]

`define csr_acc_flag(csr_op) csr_op[3]

`define csr_swap(csr_op) csr_op[0]

`define csr_set(csr_op) csr_op[1]

`define csr_clear(csr_op) csr_op[2]

endpackage
