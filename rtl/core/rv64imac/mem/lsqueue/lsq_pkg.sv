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

typedef struct packed {
    logic               valid;
    SQ_entry_ptr_t      sq_ptr;
} sq_resp_t;

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

function logic QueueValid;
    input SQ_entry_ptr_inner_t      sq_r_ptr;
    input SQ_entry_ptr_inner_t      sq_w_ptr;
    input SQ_entry_ptr_t            test_sq_ptr;

    logic test_sq_ptr_in_r_eq_w;
    logic test_sq_ptr_in_r_ne_w;
    assign test_sq_ptr_in_r_eq_w = ((test_sq_ptr >= sq_r_ptr[SQ_entry_w - 1 : 0]) & (test_sq_ptr < sq_w_ptr[SQ_entry_w - 1 : 0]));
    assign test_sq_ptr_in_r_ne_w = ((test_sq_ptr >= sq_r_ptr[SQ_entry_w - 1 : 0]) | (test_sq_ptr < sq_w_ptr[SQ_entry_w - 1 : 0]));

    assign QueueValid = (sq_r_ptr[SQ_entry_w] == sq_w_ptr[SQ_entry_w]) ? test_sq_ptr_in_r_eq_w : test_sq_ptr_in_r_ne_w;

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
