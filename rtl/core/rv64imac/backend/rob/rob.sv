module rob
import core_setting_pkg::*;
import frontend_pkg::*;
import decode_pkg::*;
import regfile_pkg::*;
import rob_pkg::*;
(
    input                                               clk,
    input                                               rst_n,

    input                                               redirect,

    output rob_entry_ptr_t                              top_rob_ptr,
    output ls_rob_entry_ptr_t                           deq_rob_ptr,

    output [FTQ_ENTRY_BIT_NUM - 1 : 0]                  rob_ftq_ptr,
    /* verilator lint_off UNUSEDSIGNAL */
    input  ftq_entry                                    rob_ftq_entry,
    /* verilator lint_on UNUSEDSIGNAL */

    output [FTQ_ENTRY_BIT_NUM - 1 : 0]                  rob_ftq_ptr_lq_raw,
    /* verilator lint_off UNUSEDSIGNAL */
    input  ftq_entry                                    rob_ftq_entry_lq_raw,
    /* verilator lint_on UNUSEDSIGNAL */

    // rename table interface
    output               [commit_width - 1 :0]          commit_intrat_valid,
    output      regsrc_t [commit_width - 1 :0]          commit_intrat_dest,
    output pint_regdest_t[commit_width - 1 :0]          commit_intrat_pdest,

    // rename free int list interface
    output               [commit_width - 1 :0]          commit_int_need_free,
    output pint_regdest_t[commit_width - 1 :0]          commit_int_old_pdest,

    // rename interface
    input                                               rename_fire,
    input              [rename_width - 1 : 0]           rob_req,
    input  rob_entry_t [rename_width - 1 : 0]           rob_req_entry,
    output rob_resp_t  [rename_width - 1 : 0]           rob_resp,

    // dispatch interface
    input  rob_entry_ptr_t                              rob_first_ptr,
    output             [dispatch_width - 1 : 0]         rob_can_dispatch,

    // exu1 interface
    input                                               alu_mul_exu_valid_o,
    output                                              alu_mul_exu_ready_o,
    input  rob_entry_ptr_t                              alu_mul_exu_rob_ptr_o,

    // exu2 interface
    input                                               alu_div_exu_valid_o,
    output                                              alu_div_exu_ready_o,
    input  rob_entry_ptr_t                              alu_div_exu_rob_ptr_o,

    // exu3 interface
    input                                               alu_bru_jump_exu_valid_o,
    output                                              alu_bru_jump_exu_ready_o,
    input  rob_entry_ptr_t                              alu_bru_jump_exu_rob_ptr_o,
    input                                               alu_bru_jump_exu_token_miss_o,
    input  [63:0]                                       alu_bru_jump_exu_next_pc_o,

    // exu4 interface
    input                                               alu_csr_fence_exu_valid_o,
    output                                              alu_csr_fence_exu_ready_o,
    input  rob_entry_ptr_t                              alu_csr_fence_exu_rob_ptr_o,
    input                                               alu_csr_fence_exu_mret_o,
    input                                               alu_csr_fence_exu_sret_o,
    input                                               alu_csr_fence_exu_dret_o,
    input                                               alu_csr_fence_exu_satp_change_o,
    input                                               alu_csr_fence_exu_fence_o,
    input  [63:0]                                       alu_csr_fence_exu_next_pc_o,

    // load interface
    input                                               LoadQueue_valid_o,
    output                                              LoadQueue_ready_o,
    input                                               LoadQueue_addr_misalign_o,
    input                                               LoadQueue_page_error_o,
    input                                               LoadQueue_load_error_o,
    input  rob_entry_ptr_t                              LoadQueue_rob_ptr_o,
    input  [63:0]                                       LoadQueue_vaddr_o,

    // store interface
    input                                               StoreQueue_valid_o,
    output                                              StoreQueue_ready_o,
    input                                               StoreQueue_addr_misalign_o,
    input                                               StoreQueue_page_error_o,
    input  rob_entry_ptr_t                              StoreQueue_rob_ptr_o,
    input  [63:0]                                       StoreQueue_vaddr_o,

    // atomic interface
    input                                               atomicUnit_valid_o,
    output                                              atomicUnit_ready_o,
    input                                               atomicUnit_ld_addr_misalign_o,
    input                                               atomicUnit_st_addr_misalign_o,
    input                                               atomicUnit_ld_page_error_o,
    input                                               atomicUnit_st_page_error_o,
    input                                               atomicUnit_load_error_o,
    input                                               atomicUnit_store_error_o,
    input  rob_entry_ptr_t                              atomicUnit_rob_ptr_o,
    input  [63:0]                                       atomic_vaddr_o,

    // LoadQueueRAW interface
    input                                               LoadQueueRAW_flush_o,
    input  rob_entry_ptr_t                              LoadQueueRAW_rob_ptr_o,

    // interface with gen_redirect
    output                                              rob_gen_redirect_valid,
    output                                              rob_gen_redirect_bp_miss,
    output                                              rob_gen_redirect_call,
    output                                              rob_gen_redirect_ret,
    output                                              rob_gen_redirect_end,
    output [63:0]                                       rob_gen_redirect_target,

    // interface with csr
    // common
    output                                              rob_can_interrupt,
    output                                              rob_commit_valid,
    output [63:0]                                       rob_commit_pc,
    output [63:0]                                       rob_commit_next_pc,
    // trap
    input                                               interrupt_happen,
    output                                              rob_trap_valid,
    output [63:0]                                       rob_trap_cause,
    output [63:0]                                       rob_trap_tval
);

rob_entry_t [rob_entry_num - 1 : 0]         rob_entry;
ls_rob_entry_ptr_t                          rob_ptr_top;
ls_rob_entry_ptr_t                          rob_ptr_button;

rob_entry_ptr_t [dispatch_width - 1 : 0]    rob_ptr_dispatch/* verilator split_var */;
logic           [dispatch_width - 1 : 0]    rob_can_dispatch_inner/* verilator split_var */;
/* verilator lint_off UNUSEDSIGNAL */
rob_entry_t     [dispatch_width - 1 : 0]    rob_entry_dispatch/* verilator split_var */;
rob_entry_t                                 rob_entry_button;
rob_entry_t                                 rob_entry_lq_raw;
/* verilator lint_on UNUSEDSIGNAL */
assign rob_entry_button = rob_entry[rob_ptr_button[rob_entry_w - 1 : 0]];

ls_rob_entry_ptr_t [rename_width - 1 : 0]   rob_ptr_resp/* verilator split_var */;
rob_entry_ptr_t [rename_width - 1 : 0]      rob_ptr_enq;
rob_resp_t      [rename_width - 1 : 0]      rob_resp_inner/* verilator split_var */;
ls_rob_entry_ptr_t [commit_width - 1 : 0]   rob_ptr_commit_full/* verilator split_var */;
rob_entry_ptr_t [commit_width - 1 : 0]      rob_ptr_commit;
rob_entry_t     [commit_width - 1 : 0]      rob_entry_commit/* verilator split_var */;
logic           [commit_width - 1 : 0]      rob_can_commit/* verilator split_var */;

logic                                       rob_commit_valid_inner[commit_width - 1 : 0]/* verilator split_var */;
logic                                       rob_rvc_flag_inner[commit_width - 1 : 0]/* verilator split_var */;
logic                                       rob_trap_flag_inner[commit_width - 1 : 0]/* verilator split_var */;
logic [4:0]                                 rob_trap_cause_inner[commit_width - 1 : 0]/* verilator split_var */;
logic [63:0]                                rob_trap_tval_inner[commit_width - 1 : 0]/* verilator split_var */;
logic                                       rob_end_flag_inner[commit_width - 1 : 0]/* verilator split_var */;
logic                                       rob_call_inner[commit_width - 1 : 0]/* verilator split_var */;
logic                                       rob_ret_inner[commit_width - 1 : 0]/* verilator split_var */;
logic [FTQ_ENTRY_BIT_NUM - 1 : 0]           rob_ftq_ptr_inner[commit_width - 1 : 0]/* verilator split_var */;
logic [BLOCK_BIT_NUM - 1:0]                 rob_inst_offset_inner[commit_width - 1 : 0]/* verilator split_var */;

ls_rob_entry_ptr_t                          rob_ptr_top_nxt;
assign rob_ptr_top_nxt = (rob_resp_inner[rename_width - 1].valid) ? (rob_ptr_resp[rename_width - 1] + 1) : rob_ptr_resp[rename_width - 1];
FF_D_with_syn_rst #(
    .DATA_LEN 	( rob_entry_w + 1   ),
    .RST_DATA 	( 0                 )
)u_rob_ptr_top
(
    .clk        ( clk               ),
    .rst_n      ( rst_n             ),
    .syn_rst    ( redirect          ),
    .wen        ( rename_fire       ),
    .data_in    ( rob_ptr_top_nxt   ),
    .data_out   ( rob_ptr_top       )
);

ls_rob_entry_ptr_t                          rob_ptr_button_nxt;
assign rob_ptr_button_nxt = (rob_can_commit[commit_width - 1]) ? (rob_ptr_commit_full[commit_width - 1] + 1) : rob_ptr_commit_full[commit_width - 1];
FF_D_with_syn_rst #(
    .DATA_LEN 	( rob_entry_w + 1   ),
    .RST_DATA 	( 0                 )
)u_rob_ptr_button
(
    .clk        ( clk                   ),
    .rst_n      ( rst_n                 ),
    .syn_rst    ( redirect              ),
    .wen        ( rob_commit_valid      ),
    .data_in    ( rob_ptr_button_nxt    ),
    .data_out   ( rob_ptr_button        )
);

genvar entry_index;
generate for(entry_index = 0 ; entry_index < rob_entry_num; entry_index = entry_index + 1) begin : U_gen_rob_entry
    logic       rob_entry_wen;
    logic       rob_entry_enq_wen;
    logic       rob_entry_alu_mul_exu_update_wen;
    logic       rob_entry_alu_div_exu_update_wen;
    logic       rob_entry_alu_bru_jump_exu_update_wen;
    logic       rob_entry_alu_csr_fence_exu_update_wen;
    logic       rob_entry_LoadQueue_update_wen;
    logic       rob_entry_StoreQueue_update_wen;
    logic       rob_entry_atomic_update_wen;
    logic       rob_entry_loadQueueRAW_update_wen;
    rob_entry_t rob_entry_nxt;
    rob_entry_t rob_entry_enq;
    rob_entry_t rob_entry_alu_mul_exu_update;
    rob_entry_t rob_entry_alu_div_exu_update;
    rob_entry_t rob_entry_alu_bru_jump_exu_update;
    rob_entry_t rob_entry_alu_csr_fence_exu_update;
    rob_entry_t rob_entry_LoadQueue_update;
    rob_entry_t rob_entry_StoreQueue_update;
    rob_entry_t rob_entry_atomic_update;
    rob_entry_t rob_entry_loadQueueRAW_update;

    rob_enq u_rob_enq(
        .rename_fire       	( rename_fire        ),
        .rob_req           	( rob_req            ),
        .rob_req_entry     	( rob_req_entry      ),
        .rob_ptr_resp      	( rob_ptr_enq        ),
        .rob_ptr_self      	( entry_index        ),
        .rob_entry_enq_wen 	( rob_entry_enq_wen  ),
        .rob_entry_enq     	( rob_entry_enq      )
    );

    assign rob_entry_alu_mul_exu_update_wen                  = alu_mul_exu_valid_o & alu_mul_exu_ready_o & (entry_index == alu_mul_exu_rob_ptr_o);
    assign rob_entry_alu_mul_exu_update.finish               = 1'b1                                         ;
    assign rob_entry_alu_mul_exu_update.rfwen                = rob_entry[entry_index].rfwen                 ;
    assign rob_entry_alu_mul_exu_update.wdest                = rob_entry[entry_index].wdest                 ;
    assign rob_entry_alu_mul_exu_update.old_pdest            = rob_entry[entry_index].old_pdest             ;
    assign rob_entry_alu_mul_exu_update.pwdest               = rob_entry[entry_index].pwdest                ;
    assign rob_entry_alu_mul_exu_update.no_intr_exec         = rob_entry[entry_index].no_intr_exec          ;
    assign rob_entry_alu_mul_exu_update.block_forward_flag   = rob_entry[entry_index].block_forward_flag    ;
    assign rob_entry_alu_mul_exu_update.call                 = rob_entry[entry_index].call                  ;
    assign rob_entry_alu_mul_exu_update.ret                  = rob_entry[entry_index].ret                   ;
    assign rob_entry_alu_mul_exu_update.rvc_flag             = rob_entry[entry_index].rvc_flag              ;
    assign rob_entry_alu_mul_exu_update.trap_flag            = rob_entry[entry_index].trap_flag             ;
    assign rob_entry_alu_mul_exu_update.trap_cause           = rob_entry[entry_index].trap_cause            ;
    assign rob_entry_alu_mul_exu_update.trap_tval            = rob_entry[entry_index].trap_tval             ;
    assign rob_entry_alu_mul_exu_update.end_flag             = rob_entry[entry_index].end_flag              ;
    assign rob_entry_alu_mul_exu_update.ftq_ptr              = rob_entry[entry_index].ftq_ptr               ;
    assign rob_entry_alu_mul_exu_update.inst_offset          = rob_entry[entry_index].inst_offset           ;

    assign rob_entry_alu_div_exu_update_wen                  = alu_div_exu_valid_o & alu_div_exu_ready_o & (entry_index == alu_div_exu_rob_ptr_o);
    assign rob_entry_alu_div_exu_update.finish               = 1'b1                                        ;
    assign rob_entry_alu_div_exu_update.rfwen                = rob_entry[entry_index].rfwen                ;
    assign rob_entry_alu_div_exu_update.wdest                = rob_entry[entry_index].wdest                ;
    assign rob_entry_alu_div_exu_update.old_pdest            = rob_entry[entry_index].old_pdest            ;
    assign rob_entry_alu_div_exu_update.pwdest               = rob_entry[entry_index].pwdest               ;
    assign rob_entry_alu_div_exu_update.no_intr_exec         = rob_entry[entry_index].no_intr_exec         ;
    assign rob_entry_alu_div_exu_update.block_forward_flag   = rob_entry[entry_index].block_forward_flag   ;
    assign rob_entry_alu_div_exu_update.call                 = rob_entry[entry_index].call                 ;
    assign rob_entry_alu_div_exu_update.ret                  = rob_entry[entry_index].ret                  ;
    assign rob_entry_alu_div_exu_update.rvc_flag             = rob_entry[entry_index].rvc_flag             ;
    assign rob_entry_alu_div_exu_update.trap_flag            = rob_entry[entry_index].trap_flag            ;
    assign rob_entry_alu_div_exu_update.trap_cause           = rob_entry[entry_index].trap_cause           ;
    assign rob_entry_alu_div_exu_update.trap_tval            = rob_entry[entry_index].trap_tval            ;
    assign rob_entry_alu_div_exu_update.end_flag             = rob_entry[entry_index].end_flag             ;
    assign rob_entry_alu_div_exu_update.ftq_ptr              = rob_entry[entry_index].ftq_ptr              ;
    assign rob_entry_alu_div_exu_update.inst_offset          = rob_entry[entry_index].inst_offset          ;

    assign rob_entry_alu_bru_jump_exu_update_wen                = alu_bru_jump_exu_valid_o & alu_bru_jump_exu_ready_o &
                                                                (entry_index == alu_bru_jump_exu_rob_ptr_o);
    assign rob_entry_alu_bru_jump_exu_update.finish             = 1'b1                                        ;
    assign rob_entry_alu_bru_jump_exu_update.rfwen              = rob_entry[entry_index].rfwen                ;
    assign rob_entry_alu_bru_jump_exu_update.wdest              = rob_entry[entry_index].wdest                ;
    assign rob_entry_alu_bru_jump_exu_update.old_pdest          = rob_entry[entry_index].old_pdest            ;
    assign rob_entry_alu_bru_jump_exu_update.pwdest             = rob_entry[entry_index].pwdest               ;
    assign rob_entry_alu_bru_jump_exu_update.no_intr_exec       = rob_entry[entry_index].no_intr_exec         ;
    assign rob_entry_alu_bru_jump_exu_update.block_forward_flag = rob_entry[entry_index].block_forward_flag   ;
    assign rob_entry_alu_bru_jump_exu_update.call               = rob_entry[entry_index].call                 ;
    assign rob_entry_alu_bru_jump_exu_update.ret                = rob_entry[entry_index].ret                  ;
    assign rob_entry_alu_bru_jump_exu_update.rvc_flag           = rob_entry[entry_index].rvc_flag             ;
    assign rob_entry_alu_bru_jump_exu_update.trap_flag          = alu_bru_jump_exu_token_miss_o               ;
    assign rob_entry_alu_bru_jump_exu_update.trap_cause         = 5'd24                                       ;
    assign rob_entry_alu_bru_jump_exu_update.trap_tval          = alu_bru_jump_exu_next_pc_o                  ;
    assign rob_entry_alu_bru_jump_exu_update.end_flag           = rob_entry[entry_index].end_flag             ;
    assign rob_entry_alu_bru_jump_exu_update.ftq_ptr            = rob_entry[entry_index].ftq_ptr              ;
    assign rob_entry_alu_bru_jump_exu_update.inst_offset        = rob_entry[entry_index].inst_offset          ;

    logic csr_fence_jump_flag;
    assign csr_fence_jump_flag = (alu_csr_fence_exu_mret_o | alu_csr_fence_exu_sret_o | alu_csr_fence_exu_dret_o | alu_csr_fence_exu_satp_change_o | alu_csr_fence_exu_fence_o);
    assign rob_entry_alu_csr_fence_exu_update_wen                   = alu_csr_fence_exu_valid_o & alu_csr_fence_exu_ready_o &
                                                                    (entry_index == alu_csr_fence_exu_rob_ptr_o);
    assign rob_entry_alu_csr_fence_exu_update.finish                = 1'b1                                        ;
    assign rob_entry_alu_csr_fence_exu_update.rfwen                 = rob_entry[entry_index].rfwen                ;
    assign rob_entry_alu_csr_fence_exu_update.wdest                 = rob_entry[entry_index].wdest                ;
    assign rob_entry_alu_csr_fence_exu_update.old_pdest             = rob_entry[entry_index].old_pdest            ;
    assign rob_entry_alu_csr_fence_exu_update.pwdest                = rob_entry[entry_index].pwdest               ;
    assign rob_entry_alu_csr_fence_exu_update.no_intr_exec          = rob_entry[entry_index].no_intr_exec         ;
    assign rob_entry_alu_csr_fence_exu_update.block_forward_flag    = rob_entry[entry_index].block_forward_flag   ;
    assign rob_entry_alu_csr_fence_exu_update.rvc_flag              = rob_entry[entry_index].rvc_flag             ;
    assign rob_entry_alu_csr_fence_exu_update.call                  = rob_entry[entry_index].call                 ;
    assign rob_entry_alu_csr_fence_exu_update.ret                   = rob_entry[entry_index].ret                  ;
    assign rob_entry_alu_csr_fence_exu_update.trap_flag             = csr_fence_jump_flag                         ;
    assign rob_entry_alu_csr_fence_exu_update.trap_cause            = 5'd25                                       ;
    assign rob_entry_alu_csr_fence_exu_update.trap_tval             = alu_csr_fence_exu_next_pc_o                 ;
    assign rob_entry_alu_csr_fence_exu_update.end_flag              = rob_entry[entry_index].end_flag             ;
    assign rob_entry_alu_csr_fence_exu_update.ftq_ptr               = rob_entry[entry_index].ftq_ptr              ;
    assign rob_entry_alu_csr_fence_exu_update.inst_offset           = rob_entry[entry_index].inst_offset          ;

    logic LoadQueue_exc_gen;
    assign LoadQueue_exc_gen = (LoadQueue_addr_misalign_o | LoadQueue_page_error_o | LoadQueue_load_error_o);
    logic [4:0] LoadQueue_exc_code;
    assign LoadQueue_exc_code =  ({5{LoadQueue_addr_misalign_o}} & 5'h4) |
                                ({5{LoadQueue_page_error_o   }} & 5'hd) |
                                ({5{LoadQueue_load_error_o   }} & 5'h5);
    assign rob_entry_LoadQueue_update_wen                   = LoadQueue_valid_o & LoadQueue_ready_o &
                                                            (entry_index == LoadQueue_rob_ptr_o) & (!rob_entry[entry_index].finish) &
                                                            ((!LoadQueueRAW_flush_o) | (entry_index != LoadQueueRAW_rob_ptr_o));
    assign rob_entry_LoadQueue_update.finish                = 1'b1                                        ;
    assign rob_entry_LoadQueue_update.rfwen                 = rob_entry[entry_index].rfwen                ;
    assign rob_entry_LoadQueue_update.wdest                 = rob_entry[entry_index].wdest                ;
    assign rob_entry_LoadQueue_update.old_pdest             = rob_entry[entry_index].old_pdest            ;
    assign rob_entry_LoadQueue_update.pwdest                = rob_entry[entry_index].pwdest               ;
    assign rob_entry_LoadQueue_update.no_intr_exec          = rob_entry[entry_index].no_intr_exec         ;
    assign rob_entry_LoadQueue_update.block_forward_flag    = rob_entry[entry_index].block_forward_flag   ;
    assign rob_entry_LoadQueue_update.rvc_flag              = rob_entry[entry_index].rvc_flag             ;
    assign rob_entry_LoadQueue_update.call                  = rob_entry[entry_index].call                 ;
    assign rob_entry_LoadQueue_update.ret                   = rob_entry[entry_index].ret                  ;
    assign rob_entry_LoadQueue_update.trap_flag             = LoadQueue_exc_gen                           ;
    assign rob_entry_LoadQueue_update.trap_cause            = LoadQueue_exc_code                          ;
    assign rob_entry_LoadQueue_update.trap_tval             = LoadQueue_vaddr_o                           ;
    assign rob_entry_LoadQueue_update.end_flag              = rob_entry[entry_index].end_flag             ;
    assign rob_entry_LoadQueue_update.ftq_ptr               = rob_entry[entry_index].ftq_ptr              ;
    assign rob_entry_LoadQueue_update.inst_offset           = rob_entry[entry_index].inst_offset          ;

    logic StoreQueue_exc_gen;
    assign StoreQueue_exc_gen = (StoreQueue_addr_misalign_o | StoreQueue_page_error_o);
    logic [4:0] StoreQueue_exc_code;
    assign StoreQueue_exc_code =    ({5{StoreQueue_addr_misalign_o}} & 5'h6) |
                                    ({5{StoreQueue_page_error_o   }} & 5'hf);
    assign rob_entry_StoreQueue_update_wen                   = StoreQueue_valid_o & StoreQueue_ready_o &
                                                                (entry_index == StoreQueue_rob_ptr_o);
    assign rob_entry_StoreQueue_update.finish                = 1'b1                                        ;
    assign rob_entry_StoreQueue_update.rfwen                 = rob_entry[entry_index].rfwen                ;
    assign rob_entry_StoreQueue_update.wdest                 = rob_entry[entry_index].wdest                ;
    assign rob_entry_StoreQueue_update.old_pdest             = rob_entry[entry_index].old_pdest            ;
    assign rob_entry_StoreQueue_update.pwdest                = rob_entry[entry_index].pwdest               ;
    assign rob_entry_StoreQueue_update.no_intr_exec          = rob_entry[entry_index].no_intr_exec         ;
    assign rob_entry_StoreQueue_update.block_forward_flag    = rob_entry[entry_index].block_forward_flag   ;
    assign rob_entry_StoreQueue_update.rvc_flag              = rob_entry[entry_index].rvc_flag             ;
    assign rob_entry_StoreQueue_update.call                  = rob_entry[entry_index].call                 ;
    assign rob_entry_StoreQueue_update.ret                   = rob_entry[entry_index].ret                  ;
    assign rob_entry_StoreQueue_update.trap_flag             = StoreQueue_exc_gen                          ;
    assign rob_entry_StoreQueue_update.trap_cause            = StoreQueue_exc_code                         ;
    assign rob_entry_StoreQueue_update.trap_tval             = StoreQueue_vaddr_o                          ;
    assign rob_entry_StoreQueue_update.end_flag              = rob_entry[entry_index].end_flag             ;
    assign rob_entry_StoreQueue_update.ftq_ptr               = rob_entry[entry_index].ftq_ptr              ;
    assign rob_entry_StoreQueue_update.inst_offset           = rob_entry[entry_index].inst_offset          ;

    logic atomic_exc_gen;
    assign atomic_exc_gen = (atomicUnit_ld_addr_misalign_o | atomicUnit_st_addr_misalign_o | atomicUnit_ld_page_error_o |
                            atomicUnit_st_page_error_o | atomicUnit_load_error_o | atomicUnit_store_error_o);
    logic [4:0] atomic_exc_code;
    assign atomic_exc_code =    ({5{atomicUnit_ld_addr_misalign_o}} & 5'h4) |
                                ({5{atomicUnit_ld_page_error_o   }} & 5'hd) |
                                ({5{atomicUnit_st_addr_misalign_o}} & 5'h6) |
                                ({5{atomicUnit_st_page_error_o   }} & 5'hf) |
                                ({5{atomicUnit_load_error_o      }} & 5'h5) |
                                ({5{atomicUnit_store_error_o     }} & 5'h7);
    assign rob_entry_atomic_update_wen                   = atomicUnit_valid_o & atomicUnit_ready_o &
                                                            (entry_index == atomicUnit_rob_ptr_o);
    assign rob_entry_atomic_update.finish                = 1'b1                                        ;
    assign rob_entry_atomic_update.rfwen                 = rob_entry[entry_index].rfwen                ;
    assign rob_entry_atomic_update.wdest                 = rob_entry[entry_index].wdest                ;
    assign rob_entry_atomic_update.old_pdest             = rob_entry[entry_index].old_pdest            ;
    assign rob_entry_atomic_update.pwdest                = rob_entry[entry_index].pwdest               ;
    assign rob_entry_atomic_update.no_intr_exec          = rob_entry[entry_index].no_intr_exec         ;
    assign rob_entry_atomic_update.block_forward_flag    = rob_entry[entry_index].block_forward_flag   ;
    assign rob_entry_atomic_update.rvc_flag              = rob_entry[entry_index].rvc_flag             ;
    assign rob_entry_atomic_update.call                  = rob_entry[entry_index].call                 ;
    assign rob_entry_atomic_update.ret                   = rob_entry[entry_index].ret                  ;
    assign rob_entry_atomic_update.trap_flag             = atomic_exc_gen                              ;
    assign rob_entry_atomic_update.trap_cause            = atomic_exc_code                             ;
    assign rob_entry_atomic_update.trap_tval             = atomic_vaddr_o                              ;
    assign rob_entry_atomic_update.end_flag              = rob_entry[entry_index].end_flag             ;
    assign rob_entry_atomic_update.ftq_ptr               = rob_entry[entry_index].ftq_ptr              ;
    assign rob_entry_atomic_update.inst_offset           = rob_entry[entry_index].inst_offset          ;

    assign rob_entry_loadQueueRAW_update_wen                = LoadQueueRAW_flush_o & (entry_index == LoadQueueRAW_rob_ptr_o);
    assign rob_entry_loadQueueRAW_update.finish             = 1'b1                                                                                              ;
    assign rob_entry_loadQueueRAW_update.rfwen              = rob_entry[entry_index].rfwen                                                                      ;
    assign rob_entry_loadQueueRAW_update.wdest              = rob_entry[entry_index].wdest                                                                      ;
    assign rob_entry_loadQueueRAW_update.old_pdest          = rob_entry[entry_index].old_pdest                                                                  ;
    assign rob_entry_loadQueueRAW_update.pwdest             = rob_entry[entry_index].pwdest                                                                     ;
    assign rob_entry_loadQueueRAW_update.no_intr_exec       = rob_entry[entry_index].no_intr_exec                                                               ;
    assign rob_entry_loadQueueRAW_update.block_forward_flag = rob_entry[entry_index].block_forward_flag                                                         ;
    assign rob_entry_loadQueueRAW_update.rvc_flag           = rob_entry[entry_index].rvc_flag                                                                   ;
    assign rob_entry_loadQueueRAW_update.call               = rob_entry[entry_index].call                                                                       ;
    assign rob_entry_loadQueueRAW_update.ret                = rob_entry[entry_index].ret                                                                        ;
    assign rob_entry_loadQueueRAW_update.trap_flag          = 1'b1                                                                                              ;
    assign rob_entry_loadQueueRAW_update.trap_cause         = 5'd26                                                                                             ;
    assign rob_entry_loadQueueRAW_update.trap_tval          = rob_ftq_entry_lq_raw.start_pc + {{(64 - BLOCK_BIT_NUM){1'b0}}, rob_entry[entry_index].inst_offset};
    assign rob_entry_loadQueueRAW_update.end_flag           = rob_entry[entry_index].end_flag                                                                   ;
    assign rob_entry_loadQueueRAW_update.ftq_ptr            = rob_entry[entry_index].ftq_ptr                                                                    ;
    assign rob_entry_loadQueueRAW_update.inst_offset        = rob_entry[entry_index].inst_offset                                                                ;

    assign rob_entry_wen =  (rob_entry_enq_wen                      ) |
                            (rob_entry_alu_mul_exu_update_wen       ) |
                            (rob_entry_alu_div_exu_update_wen       ) |
                            (rob_entry_alu_bru_jump_exu_update_wen  ) |
                            (rob_entry_alu_csr_fence_exu_update_wen ) |
                            (rob_entry_LoadQueue_update_wen         ) |
                            (rob_entry_StoreQueue_update_wen        ) |
                            (rob_entry_atomic_update_wen            ) |
                            (rob_entry_loadQueueRAW_update_wen      );
    assign rob_entry_nxt =  ({ROB_ENTRY_W{rob_entry_enq_wen                      }} & rob_entry_enq                      ) |
                            ({ROB_ENTRY_W{rob_entry_alu_mul_exu_update_wen       }} & rob_entry_alu_mul_exu_update       ) |
                            ({ROB_ENTRY_W{rob_entry_alu_div_exu_update_wen       }} & rob_entry_alu_div_exu_update       ) |
                            ({ROB_ENTRY_W{rob_entry_alu_bru_jump_exu_update_wen  }} & rob_entry_alu_bru_jump_exu_update  ) |
                            ({ROB_ENTRY_W{rob_entry_alu_csr_fence_exu_update_wen }} & rob_entry_alu_csr_fence_exu_update ) |
                            ({ROB_ENTRY_W{rob_entry_LoadQueue_update_wen         }} & rob_entry_LoadQueue_update         ) |
                            ({ROB_ENTRY_W{rob_entry_StoreQueue_update_wen        }} & rob_entry_StoreQueue_update        ) |
                            ({ROB_ENTRY_W{rob_entry_atomic_update_wen            }} & rob_entry_atomic_update            ) |
                            ({ROB_ENTRY_W{rob_entry_loadQueueRAW_update_wen      }} & rob_entry_loadQueueRAW_update      );

    FF_D_without_asyn_rst #(ROB_ENTRY_W)    u_entry     (clk,rob_entry_wen, rob_entry_nxt, rob_entry[entry_index]);
end
endgenerate

genvar commit_index;
generate for(commit_index = 0 ; commit_index < commit_width; commit_index = commit_index + 1) begin : U_gen_rob_commit
    if(commit_index == 0)begin : U_gen_rob_commit_0
        assign rob_can_commit[commit_index]         = ((rob_ptr_commit_full[commit_index] != rob_ptr_top) & rob_entry_commit[commit_index].finish);
        assign rob_ptr_commit_full[commit_index]    = rob_ptr_button;

        assign rob_commit_valid_inner[commit_index] = rob_can_commit[commit_index];
        assign rob_rvc_flag_inner[commit_index]     = rob_entry_commit[commit_index].rvc_flag;
        assign rob_trap_flag_inner[commit_index]    = rob_entry_commit[commit_index].trap_flag;
        assign rob_trap_cause_inner[commit_index]   = rob_entry_commit[commit_index].trap_cause;
        assign rob_trap_tval_inner[commit_index]    = rob_entry_commit[commit_index].trap_tval;
        assign rob_end_flag_inner[commit_index]     = rob_entry_commit[commit_index].end_flag;
        assign rob_call_inner[commit_index]         = rob_entry_commit[commit_index].call;
        assign rob_ret_inner[commit_index]          = rob_entry_commit[commit_index].ret;
        assign rob_ftq_ptr_inner[commit_index]      = rob_entry_commit[commit_index].ftq_ptr;
        assign rob_inst_offset_inner[commit_index]  = rob_entry_commit[commit_index].inst_offset;
    end
    else begin : U_gen_rob_commit_other
        //! TODO 现在trap和end只能在第一个提交
        assign rob_can_commit[commit_index]         = ((rob_ptr_commit_full[commit_index] != rob_ptr_top) & rob_entry_commit[commit_index].finish & 
                                                        (!rob_entry_commit[commit_index - 1].trap_flag) & (!rob_entry_commit[commit_index - 1].end_flag) & 
                                                        (!rob_entry_commit[commit_index].trap_flag) & (!rob_entry_commit[commit_index].end_flag) & rob_can_commit[commit_index - 1]);
        assign rob_ptr_commit_full[commit_index]    = (rob_can_commit[commit_index - 1]) ? (rob_ptr_commit_full[commit_index - 1] + 1) : rob_ptr_commit_full[commit_index - 1];

        assign rob_commit_valid_inner[commit_index] = (!rob_can_commit[commit_index]) ? rob_commit_valid_inner[commit_index - 1] : rob_can_commit[commit_index];
        assign rob_rvc_flag_inner[commit_index]     = (!rob_can_commit[commit_index]) ? rob_rvc_flag_inner[commit_index - 1]     : rob_entry_commit[commit_index].rvc_flag;
        assign rob_trap_flag_inner[commit_index]    = (!rob_can_commit[commit_index]) ? rob_trap_flag_inner[commit_index - 1]    : rob_entry_commit[commit_index].trap_flag;
        assign rob_trap_cause_inner[commit_index]   = (!rob_can_commit[commit_index]) ? rob_trap_cause_inner[commit_index - 1]   : rob_entry_commit[commit_index].trap_cause;
        assign rob_trap_tval_inner[commit_index]    = (!rob_can_commit[commit_index]) ? rob_trap_tval_inner[commit_index - 1]    : rob_entry_commit[commit_index].trap_tval;
        assign rob_end_flag_inner[commit_index]     = (!rob_can_commit[commit_index]) ? rob_end_flag_inner[commit_index - 1]     : rob_entry_commit[commit_index].end_flag;
        assign rob_call_inner[commit_index]         = (!rob_can_commit[commit_index]) ? rob_call_inner[commit_index - 1]         : rob_entry_commit[commit_index].call;
        assign rob_ret_inner[commit_index]          = (!rob_can_commit[commit_index]) ? rob_ret_inner[commit_index - 1]          : rob_entry_commit[commit_index].ret;
        assign rob_ftq_ptr_inner[commit_index]      = (!rob_can_commit[commit_index]) ? rob_ftq_ptr_inner[commit_index - 1]      : rob_entry_commit[commit_index].ftq_ptr;
        assign rob_inst_offset_inner[commit_index]  = (!rob_can_commit[commit_index]) ? rob_inst_offset_inner[commit_index - 1]  : rob_entry_commit[commit_index].inst_offset;
    end
    assign rob_ptr_commit[commit_index]         = rob_ptr_commit_full[commit_index][rob_entry_w - 1 : 0];
    assign rob_entry_commit[commit_index]       = rob_entry[rob_ptr_commit[commit_index]];

    assign commit_intrat_valid[commit_index]    = (rob_can_commit[commit_index] & rob_entry_commit[commit_index].rfwen & (!interrupt_happen) & ((!rob_entry_commit[commit_index].trap_flag) | (rob_entry_commit[commit_index].trap_cause == 5'd24) | (rob_entry_commit[commit_index].trap_cause == 5'd25)));
    assign commit_intrat_dest[commit_index]     = rob_entry_commit[commit_index].wdest;
    assign commit_intrat_pdest[commit_index]    = rob_entry_commit[commit_index].pwdest;

    assign commit_int_need_free[commit_index]   = (rob_can_commit[commit_index] & rob_entry_commit[commit_index].rfwen & (!interrupt_happen) & ((!rob_entry_commit[commit_index].trap_flag) | (rob_entry_commit[commit_index].trap_cause == 5'd24) | (rob_entry_commit[commit_index].trap_cause == 5'd25)));
    assign commit_int_old_pdest[commit_index]   = rob_entry_commit[commit_index].old_pdest;
end
endgenerate

assign top_rob_ptr = rob_ptr_button[rob_entry_w - 1 : 0];
assign deq_rob_ptr = rob_ptr_button;

genvar resp_index;
generate for(resp_index = 0 ; resp_index < rename_width; resp_index = resp_index + 1) begin : U_gen_rob_resp
    if(resp_index == 0)begin : U_gen_rob_resp_0
        assign rob_resp_inner[resp_index].valid     = ((rob_ptr_resp[resp_index][rob_entry_w] == rob_ptr_button[rob_entry_w]) |
                                                    (rob_ptr_resp[resp_index][rob_entry_w - 1 : 0] != rob_ptr_button[rob_entry_w - 1 : 0])) &
                                                    rob_req[resp_index];
        assign rob_ptr_resp[resp_index]             = rob_ptr_top;
    end
    else begin : U_gen_rob_resp_other
        assign rob_resp_inner[resp_index].valid     = ((rob_ptr_resp[resp_index][rob_entry_w] == rob_ptr_button[rob_entry_w]) |
                                                    (rob_ptr_resp[resp_index][rob_entry_w - 1 : 0] != rob_ptr_button[rob_entry_w - 1 : 0])) &
                                                    rob_req[resp_index] & rob_resp_inner[resp_index - 1].valid;
        assign rob_ptr_resp[resp_index]             = (rob_resp_inner[resp_index - 1].valid) ? (rob_ptr_resp[resp_index - 1] + 1) : rob_ptr_resp[resp_index - 1];
    end
    assign rob_resp_inner[resp_index].rob_ptr   = rob_ptr_resp[resp_index];
    assign rob_ptr_enq[resp_index]              = rob_ptr_resp[resp_index][rob_entry_w - 1 : 0];
end
endgenerate
assign rob_resp = rob_resp_inner;

genvar dispatch_index;
generate for(dispatch_index = 0 ; dispatch_index < dispatch_width; dispatch_index = dispatch_index + 1) begin : U_gen_rob_can_dispatch
    if(dispatch_index == 0)begin : U_gen_rob_can_dispatch_0
        assign rob_ptr_dispatch[dispatch_index]         = rob_first_ptr;
        assign rob_can_dispatch_inner[dispatch_index]   = 1'b1;
    end
    else begin : U_gen_rob_can_dispatch_other
        assign rob_ptr_dispatch[dispatch_index]         = (rob_ptr_dispatch[dispatch_index - 1] + 1);
        assign rob_can_dispatch_inner[dispatch_index]   = rob_can_dispatch_inner[dispatch_index - 1] & 
                    ((!rob_entry_dispatch[dispatch_index - 1].block_forward_flag) | rob_entry_dispatch[dispatch_index - 1].finish);
    end
    assign rob_entry_dispatch[dispatch_index]       = rob_entry[rob_ptr_dispatch[dispatch_index]];
end
endgenerate
assign rob_can_dispatch = rob_can_dispatch_inner;

assign alu_mul_exu_ready_o         = 1'b1;
assign alu_div_exu_ready_o         = 1'b1;
assign alu_bru_jump_exu_ready_o    = 1'b1;
assign alu_csr_fence_exu_ready_o   = 1'b1;
assign LoadQueue_ready_o           = 1'b1;
assign StoreQueue_ready_o          = 1'b1;
assign atomicUnit_ready_o          = 1'b1;

assign rob_ftq_ptr                 = rob_ftq_ptr_inner[commit_width - 1];
assign rob_entry_lq_raw            = rob_entry[LoadQueueRAW_rob_ptr_o];
assign rob_ftq_ptr_lq_raw          = rob_entry_lq_raw.ftq_ptr;

assign rob_gen_redirect_valid      = (rob_commit_valid_inner[commit_width - 1] & rob_trap_flag_inner[commit_width - 1] &
                                    ((rob_trap_cause_inner[commit_width - 1] == 5'd24) | 
                                    ( rob_trap_cause_inner[commit_width - 1] == 5'd25) |
                                    ( rob_trap_cause_inner[commit_width - 1] == 5'd26)));
assign rob_gen_redirect_bp_miss    = (rob_trap_cause_inner[commit_width - 1] == 5'd24);
assign rob_gen_redirect_call       = rob_call_inner[commit_width - 1];
assign rob_gen_redirect_ret        = rob_ret_inner[commit_width - 1];
assign rob_gen_redirect_end        = rob_end_flag_inner[commit_width - 1];
assign rob_gen_redirect_target     = rob_trap_tval_inner[commit_width - 1];

assign rob_can_interrupt           = rob_entry_button.no_intr_exec;
assign rob_commit_valid            = rob_commit_valid_inner[commit_width - 1] & (!interrupt_happen);
assign rob_commit_pc               = rob_ftq_entry.start_pc + {{(64 - BLOCK_BIT_NUM){1'b0}}, rob_inst_offset_inner[commit_width - 1]};
assign rob_commit_next_pc          = (rob_entry_button.trap_flag | 
                                    ((rob_entry_button.trap_cause == 5'd24) & rob_entry_button.end_flag & rob_ftq_entry.token)) ? 
                                    rob_entry_button.trap_tval : 
                                    rob_commit_pc + (rob_rvc_flag_inner[commit_width - 1] ? 64'h2 : 64'h4);

assign rob_trap_valid              = (rob_commit_valid_inner[commit_width - 1] & rob_trap_flag_inner[commit_width - 1] &
                                    (rob_trap_cause_inner[commit_width - 1] != 5'd24) & 
                                    (rob_trap_cause_inner[commit_width - 1] != 5'd25) &
                                    (rob_trap_cause_inner[commit_width - 1] != 5'd26));
assign rob_trap_cause              = {59'h0, rob_trap_cause_inner[commit_width - 1]};
assign rob_trap_tval               = (rob_trap_cause_inner[commit_width - 1] != 5'h1) ? rob_trap_tval_inner[commit_width - 1] :
                                    (rob_trap_tval_inner[commit_width - 1] == 64'h1) ? (rob_commit_pc + 64'h2) : (rob_commit_pc + 64'h4);

endmodule //rob
