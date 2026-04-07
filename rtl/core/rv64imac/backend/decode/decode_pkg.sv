package decode_pkg;

import alu_pkg::*;
import bru_pkg::*;
import jump_pkg::*;
import mul_pkg::*;
import div_pkg::*;
import csr_pkg::*;
import fence_pkg::*;
import mem_pkg::*;

import frontend_pkg::*;

typedef logic [4:0]              regsrc_t;
typedef logic [4:0]              regdest_t;
typedef enum logic [1:0]{  
    src_imm     = 2'h0,
    src_reg     = 2'h1,
    src_zero    = 2'h2
}src_type_t;

typedef enum logic [3:0]{  
    fu_alu     = 4'h0,
    fu_fence   = 4'h1,
    fu_csr     = 4'h2,
    fu_jump    = 4'h3,
    fu_bru     = 4'h4,
    fu_div     = 4'h5,
    fu_mul     = 4'h6,
    fu_load    = 4'h7,
    fu_store   = 4'h8,
    fu_amo     = 4'h9
}FuType_t;

typedef union packed{
    fence_optype_t      fence_optype;
    csr_optype_t        csr_optype;
    jump_optype_t       jump_optype;
    bru_optype_t        bru_optype;
    div_optype_t        div_optype;
    mul_optype_t        mul_optype;
    alu_optype_t        alu_optype;
    load_optype_t       load_optype;
    store_optype_t      store_optype;
    amo_optype_t        amo_optype;
}FuOpType_t;

// function logic send2alu;
//     input FuType_t futype;
//     assign send2alu = (futype == fu_alu);
// endfunction

// function logic send2csr;
//     input FuType_t futype;
//     assign send2csr = ((futype == fu_csr) | (futype == fu_fence));
// endfunction

// function logic send2jmp;
//     input FuType_t futype;
//     assign send2jmp = ((futype == fu_bru) | (futype == fu_jump));
// endfunction

// function logic send2mul;
//     input FuType_t futype;
//     assign send2mul = (futype == fu_mul);
// endfunction

// function logic send2div;
//     input FuType_t futype;
//     assign send2div = (futype == fu_div);
// endfunction

// function logic send2load;
//     input FuType_t futype;
//     assign send2load = (futype == fu_load);
// endfunction

// function logic send2store;
//     input FuType_t futype;
//     assign send2store = (futype == fu_store);
// endfunction

// function logic send2amo;
//     input FuType_t futype;
//     assign send2amo = (futype == fu_amo);
// endfunction

// function logic use_wdest;
//     input FuType_t futype;
//     assign use_wdest = ((futype == fu_alu) | (futype == fu_div) | (futype == fu_mul) | (futype == fu_load));
// endfunction

localparam DECODE_O_W = 4 + 9 + 5 + 2 + 5 + 2 + 2 + 5 + 32 + 7 + 4 + 32 + 1 + FTQ_ENTRY_BIT_NUM + BLOCK_BIT_NUM;
typedef struct packed {
    FuType_t                            futype;             // 该指令执行fu类型号
    FuOpType_t                          fuoptype;           // 该指令fu操作符

    regsrc_t                            src1;               // 源逻辑寄存器号1
    src_type_t                          src1_type;          // 源操作数1类型
    regsrc_t                            src2;               // 源逻辑寄存器号2
    src_type_t                          src2_type;          // 源操作数2类型
    logic                               rfwen;              // 整数寄存器写使能
    logic                               csrwen;             // 控制寄存器写使能
    regdest_t                           wdest;              // 目的逻辑寄存器号

    logic [31:0]                        imm;                // 32位需符号拓展立即数

    logic                               no_spec_exec;       // 不可乱序执行标志
    logic                               no_intr_exec;       // 不可中断执行标志
    logic                               block_forward_flag; // 阻塞后面指令标志
    logic                               rvc_flag;           // 双字节指令标志

    logic                               call;               // call指令标志
    logic                               ret;                // ret指令标志

    logic                               trap_flag;          // 异常发生标志
    logic [3:0]                         trap_cause;         // 异常号，目前异常号不超过15
    logic [31:0]                        trap_tval;          // 异常补充信息，cause为1时，代表pc+2是否为异常pc；cause为2时tval为异常指令

    logic                               end_flag;           // 作为取值块最后一条指令标志
    logic [FTQ_ENTRY_BIT_NUM - 1 : 0]   ftq_ptr;            // 指令在ftq中的指针 
    logic [BLOCK_BIT_NUM - 1:0]         inst_offset;        // 指令与ftq中起始pc的偏移
} decode_out_t;


endpackage
