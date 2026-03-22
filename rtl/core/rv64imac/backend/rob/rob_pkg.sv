package rob_pkg;

import regfile_pkg::*;
import frontend_pkg::*;
import decode_pkg::*;
import core_setting_pkg::*;

localparam rob_entry_w   = 6;
localparam rob_entry_num = 2 ** rob_entry_w;

typedef logic [rob_entry_w - 1 : 0] rob_entry_ptr_t;
typedef logic [rob_entry_w     : 0] ls_rob_entry_ptr_t;

typedef struct packed {
    logic               valid;
    ls_rob_entry_ptr_t  rob_ptr;
} rob_resp_t;

localparam ROB_ENTRY_W = 1 + 1 + 5 + int_preg_width + int_preg_width + 1 + 1 + 1 + 1 + 1 + 1 + 5 + 64 + 1 + FTQ_ENTRY_BIT_NUM + BLOCK_BIT_NUM;
typedef struct packed {
    logic                                   finish;             // rob entry完成位

    logic                                   rfwen;              // 整数寄存器写使能
    regdest_t                               wdest;              // 目的逻辑寄存器号
    pint_regdest_t                          old_pdest;          // 旧的目的物理寄存器号
    pint_regdest_t                          pwdest;             // 目的物理寄存器号

    logic                                   no_intr_exec;       // 不可中断执行标志
    logic                                   block_forward_flag; // 阻塞后面指令标志
    logic                                   rvc_flag;           // 双字节指令标志

    logic                                   call;               // call指令标志
    logic                                   ret;                // ret指令标志

    logic                                   trap_flag;          // 异常发生标志
    logic [4:0]                             trap_cause;         // 异常号，目前异常号不超过31
    logic [63:0]                            trap_tval;          // 异常补充信息，cause为1时，代表pc+2是否为异常pc；cause为2时tval为异常指令

    logic                                   end_flag;           // 作为取值块最后一条指令标志
    logic [FTQ_ENTRY_BIT_NUM - 1 : 0]       ftq_ptr;            // 指令在ftq中的指针 
    logic [BLOCK_BIT_NUM - 1:0]             inst_offset;        // 指令与ftq中起始pc的偏移
} rob_entry_t;

`define RobQueueValid(func_rob_r_ptr, func_rob_w_ptr, func_test_rob_ptr) \
    ((func_rob_r_ptr[rob_entry_w] == func_rob_w_ptr[rob_entry_w]) ?  \
    ((func_test_rob_ptr >= func_rob_r_ptr[rob_entry_w - 1 : 0]) & (func_test_rob_ptr < func_rob_w_ptr[rob_entry_w - 1 : 0])) : \
    ((func_test_rob_ptr >= func_rob_r_ptr[rob_entry_w - 1 : 0]) | (func_test_rob_ptr < func_rob_w_ptr[rob_entry_w - 1 : 0])))

`define rob_is_older(func_a_ptr, func_b_ptr, func_deq_rob_ptr) \
    (((func_a_ptr[rob_entry_w] == func_b_ptr[rob_entry_w]) & (func_a_ptr[rob_entry_w - 1 : 0] < func_b_ptr[rob_entry_w - 1 : 0]  )) | \
    (((func_a_ptr[rob_entry_w] != func_b_ptr[rob_entry_w]) & (func_a_ptr[rob_entry_w - 1 : 0] != func_b_ptr[rob_entry_w - 1 : 0])) &  \
    ({(!func_a_ptr[rob_entry_w]), func_a_ptr[rob_entry_w - 1 : 0]} > func_b_ptr)) |                                                   \
    (((func_a_ptr[rob_entry_w] != func_b_ptr[rob_entry_w]) & (func_a_ptr[rob_entry_w - 1 : 0] == func_b_ptr[rob_entry_w - 1 : 0])) &  \
    (func_a_ptr == func_deq_rob_ptr)))

endpackage
