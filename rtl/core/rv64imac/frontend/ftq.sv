module ftq
import frontend_pkg::*;
(
    input                               clk,
    input                               rst_n,

    input                               commit_ftq_valid,
    input                               commit_end,
    input                               jump_restore_valid,
    input                               jump_other_valid,
    input                               jump_call,
    input                               jump_ret,
    input  [63:0]                       jump_target,
    input  [63:0]                       jump_push_pc,

    // uftb interface
    output                              predict,
    input  ftq_entry                    enqueue_entry,

    output                              redirect,
    output [63:0]                       redirect_pc,

    output                              update,
    output                              update_hit,
    output [UFTB_ENTRY_NUM - 1 : 0]     update_sel,
    output [TAG_BIT_NUM - 1: 0]         update_tag,
    output uftb_entry                   update_entry,

    // return addr stack interface
    output                              precheck_restore,
    output                              precheck_push,
    output [63:0]                       precheck_push_pc,
    output                              precheck_pop,
    output [63:0]                       precheck_pop_pc_i,
    input  [63:0]                       precheck_pop_pc,

    output                              commit_restore,
    output                              commit_push,
    output [63:0]                       commit_push_pc,
    output                              commit_pop,

    // ifu interface
    output                              ifu_send_entry_valid,
    input                               ifu_send_entry_ready,
    output ftq_entry                    ifu_send_entry,

    input                               ifu_dequeue_entry_ready,
    output ftq_entry                    ifu_dequeue_entry,
    output [FTQ_ENTRY_BIT_NUM - 1 : 0]  ifu_dequeue_ptr,

    input                               if_precheck_restore,
    input                               if_precheck_update,
    input  [63:0]                       if_precheck_retsore_pc,
    input                               if_precheck_token,
    input                               if_precheck_is_tail,
    input  uftb_entry                   new_entry,
    input                               if_precheck_push,
    input  [63:0]                       if_precheck_push_pc,
    input                               if_precheck_pop,
    input  [63:0]                       if_precheck_pop_pc_i,
    output [63:0]                       if_precheck_pop_pc,

    // ftq req interface
    input  [FTQ_ENTRY_BIT_NUM - 1 : 0]  rob_ftq_ptr,
    input  [FTQ_ENTRY_BIT_NUM - 1 : 0]  bru_ftq_ptr,
    input  [FTQ_ENTRY_BIT_NUM - 1 : 0]  jump_ftq_ptr,
    input  [FTQ_ENTRY_BIT_NUM - 1 : 0]  csr_ftq_ptr,
    input  [FTQ_ENTRY_BIT_NUM - 1 : 0]  fence_ftq_ptr,
    output ftq_entry                    rob_ftq_entry,
    output ftq_entry                    bru_entry,
    output ftq_entry                    jump_entry,
    output ftq_entry                    csr_entry,
    output ftq_entry                    fence_entry
);

ftq_entry                       entry[FTQ_ENTRY_NUM - 1 : 0];

logic                           precheck_update;

logic [FTQ_ENTRY_BIT_NUM : 0]   bpu_w_ptr;
logic [FTQ_ENTRY_BIT_NUM : 0]   ifu_s_ptr;
logic [FTQ_ENTRY_BIT_NUM : 0]   ifu_r_ptr;
logic [FTQ_ENTRY_BIT_NUM : 0]   commit_ptr;

logic                           bpu_w_ptr_wen;
logic [FTQ_ENTRY_BIT_NUM : 0]   bpu_w_ptr_next;
logic                           ifu_s_ptr_wen;
logic [FTQ_ENTRY_BIT_NUM : 0]   ifu_s_ptr_next;
logic                           ifu_r_ptr_wen;
logic [FTQ_ENTRY_BIT_NUM : 0]   ifu_r_ptr_next;
logic                           commit_ptr_wen;
logic [FTQ_ENTRY_BIT_NUM : 0]   commit_ptr_next;

ftq_entry commit_ftq_entry;
assign commit_ftq_entry  = entry[commit_ptr[FTQ_ENTRY_BIT_NUM - 1 : 0]];
uftb_entry commit_entry;
assign commit_entry     = commit_ftq_entry.old_entry;
logic [63:0] br_pc;
assign br_pc          = commit_ftq_entry.start_pc + {{(64 - BLOCK_BIT_NUM){1'b0}}, commit_entry.br_slot.offset};
logic [63:0] tail_pc;
assign tail_pc        = commit_ftq_entry.start_pc + {{(64 - BLOCK_BIT_NUM){1'b0}}, commit_entry.tail_slot.offset};
logic [63:0] br_end_pc;
assign br_end_pc      = br_pc + (commit_entry.br_slot.is_rvc ? 64'h2 : 64'h4);
logic [63:0] tail_end_pc;
assign tail_end_pc    = tail_pc + (commit_entry.tail_slot.is_rvc ? 64'h2 : 64'h4);

genvar entry_index;
generate for(entry_index = 0 ; entry_index < FTQ_ENTRY_NUM; entry_index = entry_index + 1) begin : U_gen_ftq_entry
    logic       entry_wen;
    ftq_entry   entry_next;

    // enqueue
    logic enqueue_wen;
    assign enqueue_wen = predict & (entry_index[FTQ_ENTRY_BIT_NUM - 1 : 0] == bpu_w_ptr[FTQ_ENTRY_BIT_NUM - 1 : 0]);

    // precheck_restore use
    logic precheck_wen;
    assign precheck_wen = (precheck_restore | precheck_update) & (entry_index == ifu_r_ptr[FTQ_ENTRY_BIT_NUM - 1 : 0]);
    ftq_entry   precheck_entry_next;
    assign precheck_entry_next.start_pc          = entry[entry_index].start_pc;
    assign precheck_entry_next.next_pc           = (precheck_restore) ? 
                                                    if_precheck_retsore_pc : 
                                                    entry[entry_index].next_pc;
    assign precheck_entry_next.first_pred_flag   = 1'b1                       ;
    assign precheck_entry_next.hit               = entry[entry_index].hit     ;
    assign precheck_entry_next.token             = if_precheck_token          ;
    assign precheck_entry_next.is_tail           = if_precheck_is_tail        ;
    assign precheck_entry_next.hit_sel           = entry[entry_index].hit_sel ;
    assign precheck_entry_next.old_entry         = new_entry                  ;

    assign entry_wen    = (enqueue_wen | precheck_wen);
    assign entry_next   =   ({FTQ_ENTRY_BIT{enqueue_wen         }} & enqueue_entry      ) | 
                            ({FTQ_ENTRY_BIT{precheck_wen        }} & precheck_entry_next);

    FF_D_without_asyn_rst #(
        .DATA_LEN 	(FTQ_ENTRY_BIT ))
    u_ftq_entry(
        .clk      	(clk                ),
        .wen      	(entry_wen          ),
        .data_in  	(entry_next         ),
        .data_out 	(entry[entry_index] )
    );
end
endgenerate

logic br_commit_jump_update;
assign br_commit_jump_update = commit_ftq_valid & (jump_push_pc == br_end_pc) & commit_entry.br_slot.valid & 
                                ((jump_restore_valid & ((!commit_ftq_entry.token) | commit_ftq_entry.is_tail)) | 
                                ((!jump_restore_valid) & commit_ftq_entry.token & (!commit_ftq_entry.is_tail)));
uftb_entry   commit_br_jump_entry;
assign commit_br_jump_entry.valid              = commit_entry.valid            ;
assign commit_br_jump_entry.tag                = commit_entry.tag              ;
assign commit_br_jump_entry.br_slot.valid      = commit_entry.br_slot.valid    ;
assign commit_br_jump_entry.br_slot.offset     = commit_entry.br_slot.offset   ;
assign commit_br_jump_entry.br_slot.is_rvc     = commit_entry.br_slot.is_rvc   ;
assign commit_br_jump_entry.br_slot.carry      = commit_entry.br_slot.carry    ;
assign commit_br_jump_entry.br_slot.next_low   = commit_entry.br_slot.next_low ;
assign commit_br_jump_entry.br_slot.bit2_cnt   = commit_ftq_entry.first_pred_flag ? 2'h3 : 
                                                ((!(&commit_entry.br_slot.bit2_cnt)) ? 
                                                (commit_entry.br_slot.bit2_cnt + 1) : 
                                                commit_entry.br_slot.bit2_cnt);
assign commit_br_jump_entry.tail_slot          = commit_entry.tail_slot        ;
assign commit_br_jump_entry.carry              = commit_entry.carry            ;
assign commit_br_jump_entry.next_low           = commit_entry.next_low         ;
assign commit_br_jump_entry.is_branch          = commit_entry.is_branch        ;
assign commit_br_jump_entry.is_call            = commit_entry.is_call          ;
assign commit_br_jump_entry.is_ret             = commit_entry.is_ret           ;
assign commit_br_jump_entry.is_jalr            = commit_entry.is_jalr          ;
assign commit_br_jump_entry.always_token[0]    = commit_ftq_entry.first_pred_flag ? 
                                                1'b1 : commit_entry.always_token[0];
assign commit_br_jump_entry.always_token[1]    = commit_entry.always_token[1]  ;

logic br_commit_not_jump_update;
assign br_commit_not_jump_update = commit_ftq_valid & (jump_push_pc == br_end_pc) & commit_entry.br_slot.valid & jump_restore_valid & commit_ftq_entry.token & (!commit_ftq_entry.is_tail);
uftb_entry   commit_br_not_jump_entry;
assign commit_br_not_jump_entry.valid              = commit_entry.valid            ;
assign commit_br_not_jump_entry.tag                = commit_entry.tag              ;
assign commit_br_not_jump_entry.br_slot.valid      = commit_entry.br_slot.valid    ;
assign commit_br_not_jump_entry.br_slot.offset     = commit_entry.br_slot.offset   ;
assign commit_br_not_jump_entry.br_slot.is_rvc     = commit_entry.br_slot.is_rvc   ;
assign commit_br_not_jump_entry.br_slot.carry      = commit_entry.br_slot.carry    ;
assign commit_br_not_jump_entry.br_slot.next_low   = commit_entry.br_slot.next_low ;
assign commit_br_not_jump_entry.br_slot.bit2_cnt   = ((|commit_entry.br_slot.bit2_cnt) ? 
                                                    (commit_entry.br_slot.bit2_cnt - 1) : 
                                                    commit_entry.br_slot.bit2_cnt);
assign commit_br_not_jump_entry.tail_slot          = commit_entry.tail_slot        ;
assign commit_br_not_jump_entry.carry              = commit_entry.carry            ;
assign commit_br_not_jump_entry.next_low           = commit_entry.next_low         ;
assign commit_br_not_jump_entry.is_branch          = commit_entry.is_branch        ;
assign commit_br_not_jump_entry.is_call            = commit_entry.is_call          ;
assign commit_br_not_jump_entry.is_ret             = commit_entry.is_ret           ;
assign commit_br_not_jump_entry.is_jalr            = commit_entry.is_jalr          ;
assign commit_br_not_jump_entry.always_token[0]    = 1'b0                          ;
assign commit_br_not_jump_entry.always_token[1]    = commit_entry.always_token[1]  ;

logic tail_commit_jump_update;
assign tail_commit_jump_update = commit_ftq_valid & (jump_push_pc == tail_end_pc) & commit_entry.tail_slot.valid & 
                                ((commit_ftq_entry.token & commit_ftq_entry.is_tail & (!jump_restore_valid)) | 
                                ((!commit_ftq_entry.token) & jump_restore_valid));
uftb_entry   commit_tail_jump_entry;
assign commit_tail_jump_entry.valid              = commit_entry.valid                ;
assign commit_tail_jump_entry.tag                = commit_entry.tag                  ;
assign commit_tail_jump_entry.br_slot.valid      = commit_entry.br_slot.valid        ;
assign commit_tail_jump_entry.br_slot.offset     = commit_entry.br_slot.offset       ;
assign commit_tail_jump_entry.br_slot.is_rvc     = commit_entry.br_slot.is_rvc       ;
assign commit_tail_jump_entry.br_slot.carry      = commit_entry.br_slot.carry        ;
assign commit_tail_jump_entry.br_slot.next_low   = commit_entry.br_slot.next_low     ;
assign commit_tail_jump_entry.br_slot.bit2_cnt   = ((|commit_entry.br_slot.bit2_cnt) ? 
                                                    (commit_entry.br_slot.bit2_cnt - 1) : 
                                                    commit_entry.br_slot.bit2_cnt);
assign commit_tail_jump_entry.tail_slot.valid    = commit_entry.tail_slot.valid      ;
assign commit_tail_jump_entry.tail_slot.offset   = commit_entry.tail_slot.offset     ;
assign commit_tail_jump_entry.tail_slot.is_rvc   = commit_entry.tail_slot.is_rvc     ;
assign commit_tail_jump_entry.tail_slot.carry    = commit_entry.tail_slot.carry      ;
assign commit_tail_jump_entry.tail_slot.next_low = commit_entry.tail_slot.next_low   ;
assign commit_tail_jump_entry.tail_slot.bit2_cnt =  commit_ftq_entry.first_pred_flag ? 2'h3 : 
                                                    (!(&commit_entry.tail_slot.bit2_cnt)) ? 
                                                    (commit_entry.tail_slot.bit2_cnt + 1) : 
                                                    commit_entry.tail_slot.bit2_cnt;
assign commit_tail_jump_entry.carry              = commit_entry.carry                ;
assign commit_tail_jump_entry.next_low           = commit_entry.next_low             ;
assign commit_tail_jump_entry.is_branch          = commit_entry.is_branch            ;
assign commit_tail_jump_entry.is_call            = commit_entry.is_call              ;
assign commit_tail_jump_entry.is_ret             = commit_entry.is_ret               ;
assign commit_tail_jump_entry.is_jalr            = commit_entry.is_jalr              ;
assign commit_tail_jump_entry.always_token[0]    = 1'b0                              ;
assign commit_tail_jump_entry.always_token[1]    = commit_ftq_entry.first_pred_flag ? 
                                                    1'b1 : commit_entry.always_token[1];

logic tail_commit_not_jump_update;
assign tail_commit_not_jump_update = commit_ftq_valid & (jump_push_pc == tail_end_pc) & commit_entry.tail_slot.valid & 
                                    ((commit_ftq_entry.token & commit_ftq_entry.is_tail & jump_restore_valid) | 
                                    ((!commit_ftq_entry.token) & (!jump_restore_valid) & commit_end));
uftb_entry   commit_tail_not_jump_entry;
assign commit_tail_not_jump_entry.valid              = commit_entry.valid                ;
assign commit_tail_not_jump_entry.tag                = commit_entry.tag                  ;
assign commit_tail_not_jump_entry.br_slot.valid      = commit_entry.br_slot.valid        ;
assign commit_tail_not_jump_entry.br_slot.offset     = commit_entry.br_slot.offset       ;
assign commit_tail_not_jump_entry.br_slot.is_rvc     = commit_entry.br_slot.is_rvc       ;
assign commit_tail_not_jump_entry.br_slot.carry      = commit_entry.br_slot.carry        ;
assign commit_tail_not_jump_entry.br_slot.next_low   = commit_entry.br_slot.next_low     ;
assign commit_tail_not_jump_entry.br_slot.bit2_cnt   = ((|commit_entry.br_slot.bit2_cnt) ? 
                                                    (commit_entry.br_slot.bit2_cnt - 1) : 
                                                    commit_entry.br_slot.bit2_cnt);
assign commit_tail_not_jump_entry.tail_slot.valid    = commit_entry.tail_slot.valid      ;
assign commit_tail_not_jump_entry.tail_slot.offset   = commit_entry.tail_slot.offset     ;
assign commit_tail_not_jump_entry.tail_slot.is_rvc   = commit_entry.tail_slot.is_rvc     ;
assign commit_tail_not_jump_entry.tail_slot.carry    = commit_entry.tail_slot.carry      ;
assign commit_tail_not_jump_entry.tail_slot.next_low = commit_entry.tail_slot.next_low   ;
assign commit_tail_not_jump_entry.tail_slot.bit2_cnt =  commit_ftq_entry.first_pred_flag ? 2'h3 : 
                                                        (|commit_entry.tail_slot.bit2_cnt) ? 
                                                        (commit_entry.tail_slot.bit2_cnt - 1) : 
                                                        commit_entry.tail_slot.bit2_cnt;
assign commit_tail_not_jump_entry.carry              = commit_entry.carry                ;
assign commit_tail_not_jump_entry.next_low           = commit_entry.next_low             ;
assign commit_tail_not_jump_entry.is_branch          = commit_entry.is_branch            ;
assign commit_tail_not_jump_entry.is_call            = commit_entry.is_call              ;
assign commit_tail_not_jump_entry.is_ret             = commit_entry.is_ret               ;
assign commit_tail_not_jump_entry.is_jalr            = commit_entry.is_jalr              ;
assign commit_tail_not_jump_entry.always_token[0]    = 1'b0                              ;
assign commit_tail_not_jump_entry.always_token[1]    = 1'b0                              ;

logic end_commit_update;
assign end_commit_update = commit_ftq_valid & commit_end & ((commit_push_pc != br_end_pc) | (!commit_entry.br_slot.valid)) & ((commit_push_pc != tail_end_pc) | (!commit_entry.tail_slot.valid)) & (!jump_restore_valid);
uftb_entry   commit_end_entry;
assign commit_end_entry.valid              = commit_entry.valid                ;
assign commit_end_entry.tag                = commit_entry.tag                  ;
assign commit_end_entry.br_slot.valid      = commit_entry.br_slot.valid        ;
assign commit_end_entry.br_slot.offset     = commit_entry.br_slot.offset       ;
assign commit_end_entry.br_slot.is_rvc     = commit_entry.br_slot.is_rvc       ;
assign commit_end_entry.br_slot.carry      = commit_entry.br_slot.carry        ;
assign commit_end_entry.br_slot.next_low   = commit_entry.br_slot.next_low     ;
assign commit_end_entry.br_slot.bit2_cnt   = ((|commit_entry.br_slot.bit2_cnt) ? 
                                            (commit_entry.br_slot.bit2_cnt - 1) : 
                                            commit_entry.br_slot.bit2_cnt);
assign commit_end_entry.tail_slot.valid    = commit_entry.tail_slot.valid      ;
assign commit_end_entry.tail_slot.offset   = commit_entry.tail_slot.offset     ;
assign commit_end_entry.tail_slot.is_rvc   = commit_entry.tail_slot.is_rvc     ;
assign commit_end_entry.tail_slot.carry    = commit_entry.tail_slot.carry      ;
assign commit_end_entry.tail_slot.next_low = commit_entry.tail_slot.next_low   ;
assign commit_end_entry.tail_slot.bit2_cnt = (|commit_entry.tail_slot.bit2_cnt) ? 
                                            (commit_entry.tail_slot.bit2_cnt - 1) : 
                                            commit_entry.tail_slot.bit2_cnt;
assign commit_end_entry.carry              = commit_entry.carry                ;
assign commit_end_entry.next_low           = commit_entry.next_low             ;
assign commit_end_entry.is_branch          = commit_entry.is_branch            ;
assign commit_end_entry.is_call            = commit_entry.is_call              ;
assign commit_end_entry.is_ret             = commit_entry.is_ret               ;
assign commit_end_entry.is_jalr            = commit_entry.is_jalr              ;
assign commit_end_entry.always_token[0]    = 1'b0                              ;
assign commit_end_entry.always_token[1]    = 1'b0                              ;

assign bpu_w_ptr_wen                = (predict | precheck_restore | commit_restore);
assign bpu_w_ptr_next               = ({(FTQ_ENTRY_BIT_NUM + 1){predict}} & (bpu_w_ptr + 1)) | 
                                    ({(FTQ_ENTRY_BIT_NUM + 1){precheck_restore}} & (ifu_r_ptr + 1)) | 
                                    ({(FTQ_ENTRY_BIT_NUM + 1){commit_restore}} & (commit_ptr + 1));
FF_D_with_wen #(
    .DATA_LEN 	(FTQ_ENTRY_BIT_NUM + 1  ),
    .RST_DATA 	(0                      ))
u_bpu_w_ptr(
    .clk      	(clk            ),
    .rst_n    	(rst_n          ),
    .wen      	(bpu_w_ptr_wen  ),
    .data_in  	(bpu_w_ptr_next ),
    .data_out 	(bpu_w_ptr      )
);

logic  ifu_s_ptr_handle;
assign ifu_s_ptr_handle             = (ifu_send_entry_valid & ifu_send_entry_ready & (!precheck_restore) & (!commit_restore)); 
assign ifu_s_ptr_wen                = (ifu_s_ptr_handle | precheck_restore | commit_restore);
assign ifu_s_ptr_next               = ({(FTQ_ENTRY_BIT_NUM + 1){ifu_s_ptr_handle}} & (ifu_s_ptr + 1)) | 
                                    ({(FTQ_ENTRY_BIT_NUM + 1){precheck_restore}} & (ifu_r_ptr + 1)) | 
                                    ({(FTQ_ENTRY_BIT_NUM + 1){commit_restore}} & (commit_ptr + 1));
FF_D_with_wen #(
    .DATA_LEN 	(FTQ_ENTRY_BIT_NUM + 1  ),
    .RST_DATA 	(0                      ))
u_ifu_s_ptr(
    .clk      	(clk            ),
    .rst_n    	(rst_n          ),
    .wen      	(ifu_s_ptr_wen  ),
    .data_in  	(ifu_s_ptr_next ),
    .data_out 	(ifu_s_ptr      )
);

assign ifu_r_ptr_wen                = (ifu_dequeue_entry_ready | commit_restore);
assign ifu_r_ptr_next               = ({(FTQ_ENTRY_BIT_NUM + 1){ifu_dequeue_entry_ready & (!commit_restore)}} & (ifu_r_ptr + 1)) | 
                                    ({(FTQ_ENTRY_BIT_NUM + 1){commit_restore}} & (commit_ptr + 1));
FF_D_with_wen #(
    .DATA_LEN 	(FTQ_ENTRY_BIT_NUM + 1  ),
    .RST_DATA 	(0                      ))
u_ifu_r_ptr(
    .clk      	(clk            ),
    .rst_n    	(rst_n          ),
    .wen      	(ifu_r_ptr_wen  ),
    .data_in  	(ifu_r_ptr_next ),
    .data_out 	(ifu_r_ptr      )
);

assign commit_ptr_wen               = (update | jump_other_valid);
assign commit_ptr_next              = (commit_ptr + 1);
FF_D_with_wen #(
    .DATA_LEN 	(FTQ_ENTRY_BIT_NUM + 1  ),
    .RST_DATA 	(0                      ))
u_commit_ptr(
    .clk      	(clk            ),
    .rst_n    	(rst_n          ),
    .wen      	(commit_ptr_wen ),
    .data_in  	(commit_ptr_next),
    .data_out 	(commit_ptr     )
);

assign predict              = ((commit_ptr[FTQ_ENTRY_BIT_NUM - 1 : 0] != bpu_w_ptr[FTQ_ENTRY_BIT_NUM - 1 : 0]) | 
                                (commit_ptr[FTQ_ENTRY_BIT_NUM] == bpu_w_ptr[FTQ_ENTRY_BIT_NUM])) & (!precheck_restore) & (!commit_restore);

assign redirect             = (precheck_restore | commit_restore);
assign redirect_pc          = (commit_restore) ? jump_target : if_precheck_retsore_pc;

assign update               = ((commit_ftq_valid & commit_end & (!jump_restore_valid) & (!jump_other_valid)) | jump_restore_valid);
assign update_hit           = commit_ftq_entry.hit;
assign update_sel           = commit_ftq_entry.hit_sel;
assign update_tag           = commit_ftq_entry.old_entry.tag;
assign update_entry         =   ({UFTB_ENTRY_BIT{br_commit_jump_update      }} & commit_br_jump_entry       ) | 
                                ({UFTB_ENTRY_BIT{br_commit_not_jump_update  }} & commit_br_not_jump_entry   ) | 
                                ({UFTB_ENTRY_BIT{tail_commit_jump_update    }} & commit_tail_jump_entry     ) | 
                                ({UFTB_ENTRY_BIT{tail_commit_not_jump_update}} & commit_tail_not_jump_entry ) | 
                                ({UFTB_ENTRY_BIT{end_commit_update          }} & commit_end_entry           );

assign precheck_update      = (!commit_restore) & if_precheck_update;
assign precheck_restore     = (!commit_restore) & if_precheck_restore;
assign precheck_push        = (!commit_restore) & if_precheck_push;
assign precheck_push_pc     = if_precheck_push_pc;
assign precheck_pop         = (!commit_restore) & if_precheck_pop;
assign precheck_pop_pc_i    = if_precheck_pop_pc_i;
assign if_precheck_pop_pc   = precheck_pop_pc;

assign commit_restore       = (jump_restore_valid | jump_other_valid);
assign commit_push          = commit_ftq_valid & jump_call;
assign commit_push_pc       = jump_push_pc;
assign commit_pop           = commit_ftq_valid & jump_ret;

assign ifu_send_entry_valid = (ifu_s_ptr != bpu_w_ptr);
assign ifu_send_entry       = entry[ifu_s_ptr[FTQ_ENTRY_BIT_NUM - 1 : 0]];
assign ifu_dequeue_entry    = entry[ifu_r_ptr[FTQ_ENTRY_BIT_NUM - 1 : 0]];
assign ifu_dequeue_ptr      = ifu_r_ptr[FTQ_ENTRY_BIT_NUM - 1 : 0];

assign rob_ftq_entry        = entry[rob_ftq_ptr];
assign bru_entry            = entry[bru_ftq_ptr];
assign jump_entry           = entry[jump_ftq_ptr];
assign csr_entry            = entry[csr_ftq_ptr];
assign fence_entry          = entry[fence_ftq_ptr];

endmodule //ftq
