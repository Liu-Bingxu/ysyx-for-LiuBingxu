package rename_pkg;

import regfile_pkg::*;
localparam int_free_list_w      = 6;
localparam int_free_list_NUM    = 2 ** int_free_list_w;

import frontend_pkg::*;
import decode_pkg::*;
import rob_pkg::*;
import lsq_pkg::*;
import core_setting_pkg::*;

typedef logic [int_free_list_w:0]    int_free_list_ptr_t;

typedef struct packed {
    logic                                   rename_valid;
    pint_regdest_t                          rename_dest;
} rename_resp_t;

localparam RENAME_O_W = 4 + 9 + (int_preg_width * 3) + 4 + 2 + 32 + rob_entry_w + 1 + SQ_entry_w + 3 + FTQ_ENTRY_BIT_NUM + BLOCK_BIT_NUM;
typedef struct packed {
    FuType_t                                futype;             // 该指令执行fu类型号
    FuOpType_t                              fuoptype;           // 该指令fu操作符

    pint_regsrc_t                           psrc1;              // 源物理寄存器号1
    src_type_t                              src1_type;          // 源操作数1类型
    pint_regsrc_t                           psrc2;              // 源物理寄存器号2
    src_type_t                              src2_type;          // 源操作数2类型
    logic                                   rfwen;              // 整数寄存器写使能
    logic                                   csrwen;             // 控制寄存器写使能
    pint_regdest_t                          pwdest;             // 目的物理寄存器号

    logic [31:0]                            imm;                // 32位需符号拓展立即数

    ls_rob_entry_ptr_t                      rob_ptr;            // rob指针
    SQ_entry_ptr_t                          sq_ptr;             // lsq指针

    logic                                   no_spec_exec;       // 不可乱序执行标志
    logic                                   rvc_flag;           // 双字节指令标志
    logic                                   end_flag;           // 作为取值块最后一条指令标志
    logic [FTQ_ENTRY_BIT_NUM - 1 : 0]       ftq_ptr;            // 指令在ftq中的指针 
    logic [BLOCK_BIT_NUM - 1:0]             inst_offset;        // 指令与ftq中起始pc的偏移
} rename_out_t;

task automatic int_commit_one(    
    input       regsrc_t                                rat_index,

    input                [commit_width - 1 :0]          commit_valid,
    input       regsrc_t [commit_width - 1 :0]          commit_dest,
    input  pint_regdest_t[commit_width - 1 :0]          commit_pdest,

    output logic                                        arch_rat_wen,
    output pint_regdest_t                               arch_rat_nxt
);
    logic [commit_width - 1 :0] wen;
    integer index;
    arch_rat_wen = 0;
    arch_rat_nxt = 0;
    for(index = 0 ; index < commit_width; index = index + 1)begin: u_gen_rat_once
        assign wen[index] = commit_valid[index] & (commit_dest[index] == rat_index);
        arch_rat_wen = arch_rat_wen | wen[index];
        arch_rat_nxt = (wen[index]) ? commit_pdest[index] : arch_rat_nxt;
    end
endtask //automatic

task automatic int_rename_one(    
    input       regsrc_t                                rat_index,

    input                [rename_width - 1 :0]          rename_valid,
    input       regsrc_t [rename_width - 1 :0]          rename_dest,
    input  pint_regdest_t[rename_width - 1 :0]          rename_pdest,

    output logic                                        rat_wen,
    output pint_regdest_t                               rat_nxt
);
    logic [rename_width - 1 :0] wen;
    integer index;
    rat_wen = 0;
    rat_nxt = 0;
    for(index = 0 ; index < rename_width; index = index + 1)begin: u_gen_rat_once
        assign wen[index] = rename_valid[index] & (rename_dest[index] == rat_index);
        rat_wen = rat_wen | wen[index];
        rat_nxt = (wen[index]) ? rename_pdest[index] : rat_nxt;
    end
endtask //automatic

task automatic int_free_one(    
    input  int_free_list_ptr_t                          free_index,

    input                       [commit_width - 1 :0]   commit_valid,
    input  int_free_list_ptr_t  [commit_width - 1 :0]   commit_dest,
    input  pint_regdest_t       [commit_width - 1 :0]   commit_pdest,

    output logic                                        int_free_list_wen,
    output pint_regdest_t                               int_free_list_nxt
);
    logic [commit_width - 1 :0] wen;
    integer index;
    int_free_list_wen = 0;
    int_free_list_nxt = 0;
    for(index = 0 ; index < commit_width; index = index + 1)begin: u_gen_rat_once
        assign wen[index] = commit_valid[index] & (commit_dest[index] == free_index);
        int_free_list_wen = int_free_list_wen | wen[index];
        int_free_list_nxt = int_free_list_nxt | ({int_preg_width{wen[index]}} & commit_pdest[index]);
    end
endtask //automatic

endpackage
