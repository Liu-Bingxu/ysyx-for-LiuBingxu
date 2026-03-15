package lsq_pkg;

import regfile_pkg::*;
import frontend_pkg::*;
import decode_pkg::*;
import rob_pkg::*;
import mem_pkg::*;
import core_setting_pkg::*;

localparam SQ_entry_w   = 6;
localparam SQ_entry_num = 2 ** SQ_entry_w;

typedef logic [SQ_entry_w - 1 : 0] SQ_entry_ptr_t;
typedef logic [SQ_entry_w     : 0] SQ_entry_ptr_inner_t;

localparam LQRAW_entry_w   = 6;
localparam LQRAW_entry_num = 2 ** LQRAW_entry_w;
typedef logic [LQRAW_entry_w - 1 : 0] LQRAW_entry_ptr_t;

localparam LQ_entry_w   = 6;
localparam LQ_entry_num = 2 ** LQ_entry_w;

typedef logic [LQ_entry_w - 1 : 0] LQ_entry_ptr_t;
typedef logic [LQ_entry_w     : 0] LQ_entry_ptr_inner_t;

localparam LSQ_entry_w   = 6;

typedef logic [LSQ_entry_w - 1 : 0] LSQ_entry_ptr_t;

typedef struct packed {
    logic               valid;
    SQ_entry_ptr_t      sq_ptr;
} sq_resp_t;

typedef struct packed {
    logic               valid;
    LQ_entry_ptr_t      lq_ptr;
} lq_resp_t;

localparam SQ_ENTRY_W = rob_entry_w + 1 + 9 + 1 + 1 + 1 + 64 + 1 + 64;
typedef struct packed {
    ls_rob_entry_ptr_t                      rob_ptr;
    store_optype_t                          storeaddrUnit_op;
    logic                                   addr_misalign;
    logic                                   page_error;
    logic                                   addr_finish;
    logic [63:0]                            mem_waddr;
    logic                                   data_finish;
    logic [63:0]                            mem_wdata;
} sq_entry_t;

typedef struct packed {
    logic  [63:0]                           loadUnit_raddr_o;
    logic  [2:0]                            loadUnit_rsize_o;
    ls_rob_entry_ptr_t                      loadUnit_rob_ptr_o;
} lq_RAW_entry_t;

typedef enum logic [2:0] {  
    lq_not_addr     = 'h0,
    lq_get_addr     = 'h1,
    lq_send_addr    = 'h2,
    lq_send_rob     = 'h3,
    lq_commit       = 'h4
}lq_entry_status_t;

localparam LQ_ENTRY_W = rob_entry_w + 1 + 9 + int_preg_width + 3 + 1 + 1 + 64 + 64;
typedef struct packed {
    ls_rob_entry_ptr_t                      rob_ptr;
    load_optype_t                           op;
    pint_regdest_t                          pwdest;
    lq_entry_status_t                       lq_entry_status;
    logic                                   addr_misalign;
    logic                                   page_error;
    logic [63:0]                            mem_paddr;
    logic [63:0]                            mem_vaddr;
} lq_entry_t;

task automatic Load_commit_judge(
    input  rob_entry_ptr_t          top_rob_ptr,
    input  [commit_width - 1 : 0]   rob_commit_instret,
    //! TODO 使用不用的位作assert检查
    /* verilator lint_off UNUSEDSIGNAL */
    input  lq_entry_t               lq_entry_self,
    /* verilator lint_on UNUSEDSIGNAL */
    output                          lq_wen_update,
    output lq_entry_t               lq_entry_update);

    rob_entry_ptr_t [commit_width - 1 : 0] rob_ptr_update;
    logic           [commit_width - 1 : 0] wen_update;
    //! 由于不好作参数化，所以用此行为级建模
    integer i;
    for(i = 0; i < commit_width; i = i + 1)begin
        assign rob_ptr_update[i]    = (top_rob_ptr + i[rob_entry_w - 1 : 0]);
        assign wen_update[i]        = ((rob_ptr_update[i] == lq_entry_self.rob_ptr[rob_entry_w - 1 : 0]) & rob_commit_instret[i]);
    end

    assign lq_wen_update                     = (|wen_update)               ;
    assign lq_entry_update.rob_ptr           = lq_entry_self.rob_ptr       ;
    assign lq_entry_update.op                = lq_entry_self.op            ;
    assign lq_entry_update.pwdest            = lq_entry_self.pwdest        ;
    assign lq_entry_update.lq_entry_status   = lq_commit                   ;
    assign lq_entry_update.addr_misalign     = lq_entry_self.addr_misalign ;
    assign lq_entry_update.page_error        = lq_entry_self.page_error    ;
    assign lq_entry_update.mem_paddr         = lq_entry_self.mem_paddr     ;
    assign lq_entry_update.mem_vaddr         = lq_entry_self.mem_vaddr     ;
endtask //automatic

function logic LoadQueueValid;
    input LQ_entry_ptr_inner_t      lq_r_ptr;
    input LQ_entry_ptr_inner_t      lq_w_ptr;
    input LQ_entry_ptr_t            test_lq_ptr;

    logic test_lq_ptr_in_r_eq_w;
    logic test_lq_ptr_in_r_ne_w;
    assign test_lq_ptr_in_r_eq_w = ((test_lq_ptr >= lq_r_ptr[LQ_entry_w - 1 : 0]) & (test_lq_ptr < lq_w_ptr[LQ_entry_w - 1 : 0]));
    assign test_lq_ptr_in_r_ne_w = ((test_lq_ptr >= lq_r_ptr[LQ_entry_w - 1 : 0]) | (test_lq_ptr < lq_w_ptr[LQ_entry_w - 1 : 0]));

    assign LoadQueueValid = (lq_r_ptr[LQ_entry_w] == lq_w_ptr[LQ_entry_w]) ? test_lq_ptr_in_r_eq_w : test_lq_ptr_in_r_ne_w;

endfunction

function logic StoreQueueValid;
    input SQ_entry_ptr_inner_t      sq_r_ptr;
    input SQ_entry_ptr_inner_t      sq_w_ptr;
    input SQ_entry_ptr_t            test_sq_ptr;

    logic test_sq_ptr_in_r_eq_w;
    logic test_sq_ptr_in_r_ne_w;
    assign test_sq_ptr_in_r_eq_w = ((test_sq_ptr >= sq_r_ptr[SQ_entry_w - 1 : 0]) & (test_sq_ptr < sq_w_ptr[SQ_entry_w - 1 : 0]));
    assign test_sq_ptr_in_r_ne_w = ((test_sq_ptr >= sq_r_ptr[SQ_entry_w - 1 : 0]) | (test_sq_ptr < sq_w_ptr[SQ_entry_w - 1 : 0]));

    assign StoreQueueValid = (sq_r_ptr[SQ_entry_w] == sq_w_ptr[SQ_entry_w]) ? test_sq_ptr_in_r_eq_w : test_sq_ptr_in_r_ne_w;

endfunction

// function logic lsq_is_older;
//     input SQ_entry_ptr_t      a_sq_ptr;
//     input SQ_entry_ptr_t      b_sq_ptr;
//     input SQ_entry_ptr_t      deq_sq_ptr;

//     logic same_group, sq_full, diff_group;
//     SQ_entry_ptr_t    diff_a_sq_ptr;
//     assign same_group = (a_sq_ptr[SQ_entry_w] == b_sq_ptr[SQ_entry_w]);
//     assign sq_full    = ((a_sq_ptr[SQ_entry_w] != b_sq_ptr[SQ_entry_w]) & (a_sq_ptr[SQ_entry_w - 1 : 0] == b_sq_ptr[SQ_entry_w - 1 : 0]));
//     assign diff_group = ((a_sq_ptr[SQ_entry_w] != b_sq_ptr[SQ_entry_w]) & (a_sq_ptr[SQ_entry_w - 1 : 0] != b_sq_ptr[SQ_entry_w - 1 : 0]));

//     assign diff_a_sq_ptr = {(!a_sq_ptr[SQ_entry_w]), a_sq_ptr[SQ_entry_w - 1 : 0]};

//     assign lsq_is_older =   (same_group & (a_sq_ptr[SQ_entry_w - 1 : 0] < b_sq_ptr[SQ_entry_w - 1 : 0]  )) | 
//                             (diff_group & (diff_a_sq_ptr                > b_sq_ptr                      )) | 
//                             (sq_full    & (a_sq_ptr                    == deq_sq_ptr                    ));

// endfunction

endpackage
