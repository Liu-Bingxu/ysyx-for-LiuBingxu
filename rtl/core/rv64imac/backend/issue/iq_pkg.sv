package iq_pkg;

import frontend_pkg::*;
import decode_pkg::*;
import rename_pkg::*;
import dispatch_pkg::*;
import rob_pkg::*;
import lsq_pkg::*;
import regfile_pkg::*;
import core_setting_pkg::*;

localparam IQ_W   = 4;
localparam IQ_NUM = 2 ** IQ_W;

typedef logic  [IQ_W - 1 : 0]  iq_ptr_t;
typedef logic  [IQ_W - 1 : 0]  age_t;

typedef struct packed {
    FuType_t                                futype;             // 该指令执行fu类型号
    FuOpType_t                              fuoptype;           // 该指令fu操作符

    pint_regsrc_t                           psrc1;              // 源物理寄存器号1
    src_type_t                              src1_type;          // 源操作数1类型
    reg_status_t                            src1_status;        // 源操作数1状态
    pint_regsrc_t                           psrc2;              // 源物理寄存器号2
    src_type_t                              src2_type;          // 源操作数2类型
    reg_status_t                            src2_status;        // 源操作数2状态
    pint_regdest_t                          pwdest;             // 目的物理寄存器号

    logic [31:0]                            imm;                // 32位需符号拓展立即数

    rob_entry_ptr_t                         rob_ptr;            // rob指针
} iq_acc_in_t;

localparam IQ_ACC_ENTRY_W = 4 + 9 + int_preg_width + 2 + 1 + int_preg_width + 2 + 1 + int_preg_width + 32 + rob_entry_w;
typedef struct packed {
    //! TODO 暂时不考虑年龄，考虑后期优化
    // age_t                                   age;                // 指令年龄

    FuType_t                                futype;             // 该指令执行fu类型号
    FuOpType_t                              fuoptype;           // 该指令fu操作符

    pint_regsrc_t                           psrc1;              // 源物理寄存器号1
    src_type_t                              src1_type;          // 源操作数1类型
    reg_status_t                            src1_status;        // 源操作数1状态
    pint_regsrc_t                           psrc2;              // 源物理寄存器号2
    src_type_t                              src2_type;          // 源操作数2类型
    reg_status_t                            src2_status;        // 源操作数2状态
    pint_regdest_t                          pwdest;             // 目的物理寄存器号

    logic [31:0]                            imm;                // 32位需符号拓展立即数

    rob_entry_ptr_t                         rob_ptr;            // rob指针
} iq_acc_entry_t;

typedef struct packed {
    FuType_t                                futype;             // 该指令执行fu类型号
    FuOpType_t                              fuoptype;           // 该指令fu操作符

    pint_regsrc_t                           psrc1;              // 源物理寄存器号1
    src_type_t                              src1_type;          // 源操作数1类型
    reg_status_t                            src1_status;        // 源操作数1状态
    pint_regsrc_t                           psrc2;              // 源物理寄存器号2
    src_type_t                              src2_type;          // 源操作数2类型
    reg_status_t                            src2_status;        // 源操作数2状态
    logic                                   rfwen;              // 整数寄存器写使能
    pint_regdest_t                          pwdest;             // 目的物理寄存器号

    logic [31:0]                            imm;                // 32位需符号拓展立即数

    rob_entry_ptr_t                         rob_ptr;            // rob指针

    logic                                   rvc_flag;           // 双字节指令标志
    logic                                   end_flag;           // 作为取值块最后一条指令标志
    logic [FTQ_ENTRY_BIT_NUM - 1 : 0]       ftq_ptr;            // 指令在ftq中的指针 
    logic [BLOCK_BIT_NUM - 1:0]             inst_offset;        // 指令与ftq中起始pc的偏移
} iq_need_pc_in_t;

localparam IQ_NEED_PC_ENTRY_W = 4 + 9 + int_preg_width + 2 + 1 + int_preg_width + 2 + 1 + 1 + int_preg_width + 32 + rob_entry_w + 2 + FTQ_ENTRY_BIT_NUM + BLOCK_BIT_NUM;
typedef struct packed {
    //! TODO 暂时不考虑年龄，考虑后期优化
    // age_t                                   age;                // 指令年龄

    FuType_t                                futype;             // 该指令执行fu类型号
    FuOpType_t                              fuoptype;           // 该指令fu操作符

    pint_regsrc_t                           psrc1;              // 源物理寄存器号1
    src_type_t                              src1_type;          // 源操作数1类型
    reg_status_t                            src1_status;        // 源操作数1状态
    pint_regsrc_t                           psrc2;              // 源物理寄存器号2
    src_type_t                              src2_type;          // 源操作数2类型
    reg_status_t                            src2_status;        // 源操作数2状态
    logic                                   rfwen;              // 整数寄存器写使能
    pint_regdest_t                          pwdest;             // 目的物理寄存器号

    logic [31:0]                            imm;                // 32位需符号拓展立即数

    rob_entry_ptr_t                         rob_ptr;            // rob指针

    logic                                   rvc_flag;           // 双字节指令标志
    logic                                   end_flag;           // 作为取值块最后一条指令标志
    logic [FTQ_ENTRY_BIT_NUM - 1 : 0]       ftq_ptr;            // 指令在ftq中的指针 
    logic [BLOCK_BIT_NUM - 1:0]             inst_offset;        // 指令与ftq中起始pc的偏移
} iq_need_pc_entry_t;

typedef struct packed {
    FuType_t                                futype;             // 该指令执行fu类型号
    FuOpType_t                              fuoptype;           // 该指令fu操作符

    pint_regsrc_t                           psrc1;              // 源物理寄存器号1
    src_type_t                              src1_type;          // 源操作数1类型
    reg_status_t                            src1_status;        // 源操作数1状态
    pint_regsrc_t                           psrc2;              // 源物理寄存器号2
    src_type_t                              src2_type;          // 源操作数2类型
    reg_status_t                            src2_status;        // 源操作数2状态
    logic                                   rfwen;              // 整数寄存器写使能
    logic                                   csrwen;             // 控制寄存器写使能
    pint_regdest_t                          pwdest;             // 目的物理寄存器号

    logic [31:0]                            imm;                // 32位需符号拓展立即数

    rob_entry_ptr_t                         rob_ptr;            // rob指针

    logic                                   no_spec_exec;       // 不可乱序执行标志
    logic                                   rvc_flag;           // 双字节指令标志
    logic [FTQ_ENTRY_BIT_NUM - 1 : 0]       ftq_ptr;            // 指令在ftq中的指针 
    logic [BLOCK_BIT_NUM - 1:0]             inst_offset;        // 指令与ftq中起始pc的偏移
} iq_csr_in_t;

localparam IQ_CSR_ENTRY_W = 4 + 9 + int_preg_width + 2 + 1 + int_preg_width + 2 + 1 + 1 + 1 + int_preg_width + 32 + rob_entry_w + 1 + 1 + FTQ_ENTRY_BIT_NUM + BLOCK_BIT_NUM;
typedef struct packed {
    //! TODO 暂时不考虑年龄，考虑后期优化
    // age_t                                   age;                // 指令年龄

    FuType_t                                futype;             // 该指令执行fu类型号
    FuOpType_t                              fuoptype;           // 该指令fu操作符

    pint_regsrc_t                           psrc1;              // 源物理寄存器号1
    src_type_t                              src1_type;          // 源操作数1类型
    reg_status_t                            src1_status;        // 源操作数1状态
    pint_regsrc_t                           psrc2;              // 源物理寄存器号2
    src_type_t                              src2_type;          // 源操作数2类型
    reg_status_t                            src2_status;        // 源操作数2状态
    logic                                   rfwen;              // 整数寄存器写使能
    logic                                   csrwen;             // 控制寄存器写使能
    pint_regdest_t                          pwdest;             // 目的物理寄存器号

    logic [31:0]                            imm;                // 32位需符号拓展立即数

    rob_entry_ptr_t                         rob_ptr;            // rob指针

    logic                                   no_spec_exec;       // 不可乱序执行标志
    logic                                   rvc_flag;           // 双字节指令标志
    logic [FTQ_ENTRY_BIT_NUM - 1 : 0]       ftq_ptr;            // 指令在ftq中的指针 
    logic [BLOCK_BIT_NUM - 1:0]             inst_offset;        // 指令与ftq中起始pc的偏移
} iq_csr_entry_t;

typedef struct packed {
    FuOpType_t                              fuoptype;           // 该指令fu操作符

    pint_regsrc_t                           psrc1;              // 源物理寄存器号1
    src_type_t                              src1_type;          // 源操作数1类型
    reg_status_t                            src1_status;        // 源操作数1状态
    pint_regdest_t                          pwdest;             // 目的物理寄存器号

    logic [31:0]                            imm;                // 32位需符号拓展立即数

    ls_rob_entry_ptr_t                      rob_ptr;            // rob指针
} iq_mem_load_in_t;

localparam IQ_MEM_LOAD_ENTRY_W = 9 + int_preg_width + 2 + 1 + int_preg_width + 32 + rob_entry_w + 1;
typedef struct packed {
    //! TODO 暂时不考虑年龄，考虑后期优化
    // age_t                                   age;                // 指令年龄

    FuOpType_t                              fuoptype;           // 该指令fu操作符

    pint_regsrc_t                           psrc1;              // 源物理寄存器号1
    src_type_t                              src1_type;          // 源操作数1类型
    reg_status_t                            src1_status;        // 源操作数1状态
    pint_regdest_t                          pwdest;             // 目的物理寄存器号

    logic [31:0]                            imm;                // 32位需符号拓展立即数

    ls_rob_entry_ptr_t                      rob_ptr;            // rob指针
} iq_mem_load_entry_t;

typedef struct packed {
    pint_regsrc_t                           psrc1;              // 源物理寄存器号1
    src_type_t                              src1_type;          // 源操作数1类型
    reg_status_t                            src1_status;        // 源操作数1状态

    logic [31:0]                            imm;                // 32位需符号拓展立即数

    SQ_entry_ptr_t                          sq_ptr;            // lsq指针
} iq_mem_store_addr_in_t;

localparam IQ_MEM_STORE_ADDR_ENTRY_W = int_preg_width + 2 + 1 + 32 + SQ_entry_w;
typedef struct packed {
    //! TODO 暂时不考虑年龄，考虑后期优化
    // age_t                                   age;                // 指令年龄

    pint_regsrc_t                           psrc1;              // 源物理寄存器号1
    src_type_t                              src1_type;          // 源操作数1类型
    reg_status_t                            src1_status;        // 源操作数1状态

    logic [31:0]                            imm;                // 32位需符号拓展立即数

    SQ_entry_ptr_t                          sq_ptr;            // lsq指针
} iq_mem_store_addr_entry_t;

typedef struct packed {
    pint_regsrc_t                           psrc2;              // 源物理寄存器号2
    src_type_t                              src2_type;          // 源操作数2类型
    reg_status_t                            src2_status;        // 源操作数2状态

    SQ_entry_ptr_t                          sq_ptr;            // lsq指针
} iq_mem_store_data_in_t;

localparam IQ_MEM_STORE_DATA_ENTRY_W = int_preg_width + 2 + 1 + SQ_entry_w;
typedef struct packed {
    //! TODO 暂时不考虑年龄，考虑后期优化
    // age_t                                   age;                // 指令年龄

    pint_regsrc_t                           psrc2;              // 源物理寄存器号2
    src_type_t                              src2_type;          // 源操作数2类型
    reg_status_t                            src2_status;        // 源操作数2状态

    SQ_entry_ptr_t                          sq_ptr;            // lsq指针
} iq_mem_store_data_entry_t;

typedef struct packed {
    FuOpType_t                              fuoptype;           // 该指令fu操作符

    pint_regsrc_t                           psrc1;              // 源物理寄存器号1
    src_type_t                              src1_type;          // 源操作数1类型
    pint_regsrc_t                           psrc2;              // 源物理寄存器号2
    src_type_t                              src2_type;          // 源操作数2类型
    logic                                   rfwen;              // 整数寄存器写使能
    pint_regdest_t                          pwdest;             // 目的物理寄存器号

    logic [31:0]                            imm;                // 32位需符号拓展立即数

    rob_entry_ptr_t                         rob_ptr;            // rob指针
} iq_mem_atomic_in_t;

localparam IQ_MEM_ATOMIC_ENTRY_W = 9 + int_preg_width + 2 + int_preg_width + 2 + 1 + int_preg_width + 32 + rob_entry_w;
typedef struct packed {
    //! TODO 暂时不考虑年龄，考虑后期优化
    // age_t                                   age;                // 指令年龄

    FuOpType_t                              fuoptype;           // 该指令fu操作符

    pint_regsrc_t                           psrc1;              // 源物理寄存器号1
    src_type_t                              src1_type;          // 源操作数1类型
    pint_regsrc_t                           psrc2;              // 源物理寄存器号2
    src_type_t                              src2_type;          // 源操作数2类型
    logic                                   rfwen;              // 整数寄存器写使能
    pint_regdest_t                          pwdest;             // 目的物理寄存器号

    logic [31:0]                            imm;                // 32位需符号拓展立即数

    rob_entry_ptr_t                         rob_ptr;            // rob指针
} iq_mem_atomic_entry_t;

typedef struct packed {
    FuOpType_t                              fuoptype;           // 该指令fu操作符

    pint_regsrc_t                           psrc1;              // 源物理寄存器号1
    src_type_t                              src1_type;          // 源操作数1类型
    pint_regsrc_t                           psrc2;              // 源物理寄存器号2
    src_type_t                              src2_type;          // 源操作数2类型
    pint_regdest_t                          pwdest;             // 目的物理寄存器号

    logic [31:0]                            imm;                // 32位需符号拓展立即数

    rob_entry_ptr_t                         rob_ptr;            // rob指针
} iq_acc_out_t;

typedef struct packed {
    FuOpType_t                              fuoptype;           // 该指令fu操作符

    pint_regsrc_t                           psrc1;              // 源物理寄存器号1
    src_type_t                              src1_type;          // 源操作数1类型
    pint_regsrc_t                           psrc2;              // 源物理寄存器号2
    src_type_t                              src2_type;          // 源操作数2类型

    logic [31:0]                            imm;                // 32位需符号拓展立即数

    rob_entry_ptr_t                         rob_ptr;            // rob指针

    logic                                   rvc_flag;           // 双字节指令标志
    logic                                   end_flag;           // 作为取值块最后一条指令标志
    logic [FTQ_ENTRY_BIT_NUM - 1 : 0]       ftq_ptr;            // 指令在ftq中的指针 
    logic [BLOCK_BIT_NUM - 1:0]             inst_offset;        // 指令与ftq中起始pc的偏移
} iq_bru_out_t;

typedef struct packed {
    FuOpType_t                              fuoptype;           // 该指令fu操作符

    pint_regsrc_t                           psrc1;              // 源物理寄存器号1
    src_type_t                              src1_type;          // 源操作数1类型
    logic                                   rfwen;              // 整数寄存器写使能
    pint_regdest_t                          pwdest;             // 目的物理寄存器号

    logic [31:0]                            imm;                // 32位需符号拓展立即数

    rob_entry_ptr_t                         rob_ptr;            // rob指针

    logic                                   rvc_flag;           // 双字节指令标志
    logic [FTQ_ENTRY_BIT_NUM - 1 : 0]       ftq_ptr;            // 指令在ftq中的指针 
    logic [BLOCK_BIT_NUM - 1:0]             inst_offset;        // 指令与ftq中起始pc的偏移
} iq_jump_out_t;

typedef struct packed {
    FuOpType_t                              fuoptype;           // 该指令fu操作符

    pint_regsrc_t                           psrc1;              // 源物理寄存器号1
    src_type_t                              src1_type;          // 源操作数1类型
    logic                                   rfwen;              // 整数寄存器写使能
    logic                                   csrwen;             // 控制寄存器写使能
    pint_regdest_t                          pwdest;             // 目的物理寄存器号

    logic [11:0]                            csr_index;          // 12位csr地址

    rob_entry_ptr_t                         rob_ptr;            // rob指针

    logic                                   rvc_flag;           // 双字节指令标志
    logic [FTQ_ENTRY_BIT_NUM - 1 : 0]       ftq_ptr;            // 指令在ftq中的指针 
    logic [BLOCK_BIT_NUM - 1:0]             inst_offset;        // 指令与ftq中起始pc的偏移
} iq_csr_out_t;

typedef struct packed {
    FuOpType_t                              fuoptype;           // 该指令fu操作符

    rob_entry_ptr_t                         rob_ptr;            // rob指针

    logic                                   rvc_flag;           // 双字节指令标志
    logic [FTQ_ENTRY_BIT_NUM - 1 : 0]       ftq_ptr;            // 指令在ftq中的指针 
    logic [BLOCK_BIT_NUM - 1:0]             inst_offset;        // 指令与ftq中起始pc的偏移
} iq_fence_out_t;

typedef struct packed {
    FuOpType_t                              fuoptype;           // 该指令fu操作符

    pint_regsrc_t                           psrc1;              // 源物理寄存器号1
    src_type_t                              src1_type;          // 源操作数1类型
    pint_regdest_t                          pwdest;             // 目的物理寄存器号

    logic [31:0]                            imm;                // 32位需符号拓展立即数

    ls_rob_entry_ptr_t                      rob_ptr;            // rob指针
} iq_mem_load_out_t;

typedef struct packed {
    pint_regsrc_t                           psrc1;              // 源物理寄存器号1
    src_type_t                              src1_type;          // 源操作数1类型

    logic [31:0]                            imm;                // 32位需符号拓展立即数

    SQ_entry_ptr_t                          sq_ptr;             // lsq指针
} iq_mem_store_addr_out_t;

typedef struct packed {
    pint_regsrc_t                           psrc2;              // 源物理寄存器号2
    src_type_t                              src2_type;          // 源操作数2类型

    SQ_entry_ptr_t                          sq_ptr;             // lsq指针
} iq_mem_store_data_out_t;

typedef struct packed {
    FuOpType_t                              fuoptype;           // 该指令fu操作符

    pint_regsrc_t                           psrc1;              // 源物理寄存器号1
    src_type_t                              src1_type;          // 源操作数1类型
    pint_regsrc_t                           psrc2;              // 源物理寄存器号2
    src_type_t                              src2_type;          // 源操作数2类型
    logic                                   rfwen;              // 整数寄存器写使能
    pint_regdest_t                          pwdest;             // 目的物理寄存器号

    logic [31:0]                            imm;                // 32位需符号拓展立即数

    rob_entry_ptr_t                         rob_ptr;            // rob指针
} iq_mem_atomic_out_t;

endpackage
