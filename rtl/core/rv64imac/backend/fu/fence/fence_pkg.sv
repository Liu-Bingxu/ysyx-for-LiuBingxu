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

`define fence_flag(fence_op) fence_op[2]

`define fence_i_flag(fence_op) fence_op[1]

`define sfence_flag(fence_op) fence_op[0]

endpackage
