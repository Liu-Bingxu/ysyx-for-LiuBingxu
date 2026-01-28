`include "./struct.sv"
module ftq(
    input                               clk,
    input                               rst_n,

    //exu interface
    input                               commit_flag,
    input                               commit_end_flag,
    input  [63:0]                       commit_pc,
    //jump interface
    input                               jump_is_call,
    input                               jump_is_ret,
    input                               jump_restore_flag,// restore flag
    input                               jump_flag,        // another flag: sfence, fence.i, satp_change
    input  [63:0]                       jump_addr,        // restore addr
    input  [63:0]                       jump_push_addr,   // restore push addr

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
    input  [63:0]                       if_precheck_retsore_pc,
    input                               if_precheck_token,
    input                               if_precheck_is_tail,
    input  uftb_entry                   new_entry,
    input                               if_precheck_push,
    input  [63:0]                       if_precheck_push_pc,
    input                               if_precheck_pop,
    input  [63:0]                       if_precheck_pop_pc_i,
    output [63:0]                       if_precheck_pop_pc,

    // ex interface
    input  [FTQ_ENTRY_BIT_NUM - 1 : 0]  ex_r_ptr,
    output [63:0]                       ex_r_start_pc
);

ftq_entry                       entry[FTQ_ENTRY_NUM - 1 : 0];

logic                           jump_commit_flag;

logic [63:0]                    next_pc;


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

assign next_pc  = commit_ftq_entry.next_pc;

genvar entry_index;
generate for(entry_index = 0 ; entry_index < FTQ_ENTRY_NUM; entry_index = entry_index + 1) begin : U_gen_ftq_entry
    logic       entry_wen;
    ftq_entry   entry_next;

    // enqueue
    logic enqueue_wen;
    assign enqueue_wen = predict & (entry_index[FTQ_ENTRY_BIT_NUM - 1 : 0] == bpu_w_ptr[FTQ_ENTRY_BIT_NUM - 1 : 0]);

    // precheck_restore use
    logic precheck_wen;
    assign precheck_wen = precheck_restore & (entry_index == ifu_r_ptr[FTQ_ENTRY_BIT_NUM - 1 : 0]);
    ftq_entry   precheck_entry_next;
    assign precheck_entry_next.start_pc          = entry[entry_index].start_pc;
    assign precheck_entry_next.next_pc           = if_precheck_retsore_pc     ;
    assign precheck_entry_next.first_pred_flag   = 1'b1                       ;
    assign precheck_entry_next.hit               = entry[entry_index].hit     ;
    assign precheck_entry_next.token             = if_precheck_token          ;
    assign precheck_entry_next.is_tail           = if_precheck_is_tail        ;
    assign precheck_entry_next.hit_sel           = entry[entry_index].hit_sel ;
    assign precheck_entry_next.old_entry         = new_entry                  ;

    // br commit use
    logic br_not_jump_wen;
    assign br_not_jump_wen = commit_flag & (!jump_restore_flag) & (commit_pc == br_end_pc) & (entry_index == commit_ptr[FTQ_ENTRY_BIT_NUM - 1 : 0]) & entry[entry_index].old_entry.br_slot.valid;
    ftq_entry   commit_br_entry;
    assign commit_br_entry.start_pc                     = entry[entry_index].start_pc                   ;
    assign commit_br_entry.next_pc                      = entry[entry_index].next_pc                    ;
    assign commit_br_entry.first_pred_flag              = entry[entry_index].first_pred_flag            ;
    assign commit_br_entry.hit                          = entry[entry_index].hit                        ;
    assign commit_br_entry.token                        = entry[entry_index].token                      ;
    assign commit_br_entry.is_tail                      = entry[entry_index].is_tail                    ;
    assign commit_br_entry.hit_sel                      = entry[entry_index].hit_sel                    ;
    assign commit_br_entry.old_entry.valid              = entry[entry_index].old_entry.valid            ;
    assign commit_br_entry.old_entry.tag                = entry[entry_index].old_entry.tag              ;
    assign commit_br_entry.old_entry.br_slot.valid      = entry[entry_index].old_entry.br_slot.valid    ;
    assign commit_br_entry.old_entry.br_slot.offset     = entry[entry_index].old_entry.br_slot.offset   ;
    assign commit_br_entry.old_entry.br_slot.is_rvc     = entry[entry_index].old_entry.br_slot.is_rvc   ;
    assign commit_br_entry.old_entry.br_slot.carry      = entry[entry_index].old_entry.br_slot.carry    ;
    assign commit_br_entry.old_entry.br_slot.next_low   = entry[entry_index].old_entry.br_slot.next_low ;
    assign commit_br_entry.old_entry.br_slot.bit2_cnt   = (|entry[entry_index].old_entry.br_slot.bit2_cnt) ? 
                                                            (entry[entry_index].old_entry.br_slot.bit2_cnt - 1) : 
                                                            entry[entry_index].old_entry.br_slot.bit2_cnt;
    assign commit_br_entry.old_entry.tail_slot          = entry[entry_index].old_entry.tail_slot        ;
    assign commit_br_entry.old_entry.carry              = entry[entry_index].old_entry.carry            ;
    assign commit_br_entry.old_entry.next_low           = entry[entry_index].old_entry.next_low         ;
    assign commit_br_entry.old_entry.is_branch          = entry[entry_index].old_entry.is_branch        ;
    assign commit_br_entry.old_entry.is_call            = entry[entry_index].old_entry.is_call          ;
    assign commit_br_entry.old_entry.is_ret             = entry[entry_index].old_entry.is_ret           ;
    assign commit_br_entry.old_entry.is_jalr            = entry[entry_index].old_entry.is_jalr          ;
    assign commit_br_entry.old_entry.always_token[0]    = 1'b0                                          ;
    assign commit_br_entry.old_entry.always_token[1]    = entry[entry_index].old_entry.always_token[1]  ;

    // tail commit use
    logic tail_not_jump_wen;
    assign tail_not_jump_wen = commit_flag & (!jump_restore_flag) & (commit_pc == tail_end_pc) & (entry_index == commit_ptr[FTQ_ENTRY_BIT_NUM - 1 : 0]) & entry[entry_index].old_entry.tail_slot.valid;
    ftq_entry   commit_tail_entry;
    assign commit_tail_entry.start_pc                       = entry[entry_index].start_pc                       ;
    assign commit_tail_entry.next_pc                        = entry[entry_index].next_pc                        ;
    assign commit_tail_entry.first_pred_flag                = entry[entry_index].first_pred_flag                ;
    assign commit_tail_entry.hit                            = entry[entry_index].hit                            ;
    assign commit_tail_entry.token                          = entry[entry_index].token                          ;
    assign commit_tail_entry.is_tail                        = entry[entry_index].is_tail                        ;
    assign commit_tail_entry.hit_sel                        = entry[entry_index].hit_sel                        ;
    assign commit_tail_entry.old_entry.valid                = entry[entry_index].old_entry.valid                ;
    assign commit_tail_entry.old_entry.tag                  = entry[entry_index].old_entry.tag                  ;
    assign commit_tail_entry.old_entry.br_slot              = entry[entry_index].old_entry.br_slot              ;
    assign commit_tail_entry.old_entry.tail_slot.valid      = entry[entry_index].old_entry.tail_slot.valid      ;
    assign commit_tail_entry.old_entry.tail_slot.offset     = entry[entry_index].old_entry.tail_slot.offset     ;
    assign commit_tail_entry.old_entry.tail_slot.is_rvc     = entry[entry_index].old_entry.tail_slot.is_rvc     ;
    assign commit_tail_entry.old_entry.tail_slot.carry      = entry[entry_index].old_entry.tail_slot.carry      ;
    assign commit_tail_entry.old_entry.tail_slot.next_low   = entry[entry_index].old_entry.tail_slot.next_low   ;
    assign commit_tail_entry.old_entry.tail_slot.bit2_cnt   = (|entry[entry_index].old_entry.tail_slot.bit2_cnt) ? 
                                                            (entry[entry_index].old_entry.tail_slot.bit2_cnt - 1) : 
                                                            entry[entry_index].old_entry.tail_slot.bit2_cnt;
    assign commit_tail_entry.old_entry.carry                = entry[entry_index].old_entry.carry                ;
    assign commit_tail_entry.old_entry.next_low             = entry[entry_index].old_entry.next_low             ;
    assign commit_tail_entry.old_entry.is_branch            = entry[entry_index].old_entry.is_branch            ;
    assign commit_tail_entry.old_entry.is_call              = entry[entry_index].old_entry.is_call              ;
    assign commit_tail_entry.old_entry.is_ret               = entry[entry_index].old_entry.is_ret               ;
    assign commit_tail_entry.old_entry.is_jalr              = entry[entry_index].old_entry.is_jalr              ;
    assign commit_tail_entry.old_entry.always_token[0]      = entry[entry_index].old_entry.always_token[0]      ;
    assign commit_tail_entry.old_entry.always_token[1]      = 1'b0                                              ;

    assign entry_wen    = (enqueue_wen | precheck_wen | br_not_jump_wen | tail_not_jump_wen);
    assign entry_next   =   ({FTQ_ENTRY_BIT{enqueue_wen         }} & enqueue_entry      ) | 
                            ({FTQ_ENTRY_BIT{precheck_wen        }} & precheck_entry_next) | 
                            ({FTQ_ENTRY_BIT{br_not_jump_wen     }} & commit_br_entry    ) | 
                            ({FTQ_ENTRY_BIT{tail_not_jump_wen   }} & commit_tail_entry  );

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

logic jump_commit_flag_set;
logic jump_commit_flag_clr;
logic jump_commit_flag_wen;
logic jump_commit_flag_nxt;
assign jump_commit_flag_set = ((!jump_commit_flag) & (!commit_flag) & jump_restore_flag);
assign jump_commit_flag_clr = (jump_commit_flag & commit_flag);
assign jump_commit_flag_wen = (jump_commit_flag_set | jump_commit_flag_clr);
assign jump_commit_flag_nxt = (jump_commit_flag_set & (!jump_commit_flag_clr));
FF_D_with_syn_rst #(
    .DATA_LEN 	( 1  ),
    .RST_DATA   ( 0  ))
u_jump_commit_flag(
    .clk      	( clk                   ),
    .rst_n      ( rst_n                 ),
    .syn_rst    ( jump_flag             ),
    .wen      	( jump_commit_flag_wen  ),
    .data_in  	( jump_commit_flag_nxt  ),
    .data_out 	( jump_commit_flag      )
);

logic br_commit_jump_update;
assign br_commit_jump_update = ((jump_restore_flag | jump_commit_flag) & commit_flag & (commit_pc == br_end_pc) & commit_entry.br_slot.valid);
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
assign br_commit_not_jump_update = ((!(jump_restore_flag | jump_commit_flag)) & commit_flag & (commit_pc == br_end_pc) & commit_end_flag & commit_entry.br_slot.valid);
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
assign tail_commit_jump_update = ((jump_restore_flag | jump_commit_flag) & commit_flag & (commit_pc == tail_end_pc) & commit_entry.tail_slot.valid);
uftb_entry   commit_tail_jump_entry;
assign commit_tail_jump_entry.valid              = commit_entry.valid                ;
assign commit_tail_jump_entry.tag                = commit_entry.tag                  ;
assign commit_tail_jump_entry.br_slot            = commit_entry.br_slot              ;
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
assign commit_tail_jump_entry.always_token[0]    = commit_entry.always_token[0]      ;
assign commit_tail_jump_entry.always_token[1]    = commit_ftq_entry.first_pred_flag ? 
                                                    1'b1 : commit_entry.always_token[1];

logic tail_commit_not_jump_update;
assign tail_commit_not_jump_update = ((!(jump_restore_flag | jump_commit_flag)) & commit_flag & (commit_pc == tail_end_pc) & commit_end_flag & commit_entry.tail_slot.valid);
uftb_entry   commit_tail_not_jump_entry;
assign commit_tail_not_jump_entry.valid              = commit_entry.valid                ;
assign commit_tail_not_jump_entry.tag                = commit_entry.tag                  ;
assign commit_tail_not_jump_entry.br_slot            = commit_entry.br_slot              ;
assign commit_tail_not_jump_entry.tail_slot.valid    = commit_entry.tail_slot.valid      ;
assign commit_tail_not_jump_entry.tail_slot.offset   = commit_entry.tail_slot.offset     ;
assign commit_tail_not_jump_entry.tail_slot.is_rvc   = commit_entry.tail_slot.is_rvc     ;
assign commit_tail_not_jump_entry.tail_slot.carry    = commit_entry.tail_slot.carry      ;
assign commit_tail_not_jump_entry.tail_slot.next_low = commit_entry.tail_slot.next_low   ;
assign commit_tail_not_jump_entry.tail_slot.bit2_cnt = (|commit_entry.tail_slot.bit2_cnt) ? 
                                                        (commit_entry.tail_slot.bit2_cnt - 1) : 
                                                        commit_entry.tail_slot.bit2_cnt;
assign commit_tail_not_jump_entry.carry              = commit_entry.carry                ;
assign commit_tail_not_jump_entry.next_low           = commit_entry.next_low             ;
assign commit_tail_not_jump_entry.is_branch          = commit_entry.is_branch            ;
assign commit_tail_not_jump_entry.is_call            = commit_entry.is_call              ;
assign commit_tail_not_jump_entry.is_ret             = commit_entry.is_ret               ;
assign commit_tail_not_jump_entry.is_jalr            = commit_entry.is_jalr              ;
assign commit_tail_not_jump_entry.always_token[0]    = commit_entry.always_token[0]      ;
assign commit_tail_not_jump_entry.always_token[1]    = 1'b0                              ;

logic update_entry_use_ftq;
assign update_entry_use_ftq = (!(br_commit_jump_update | br_commit_not_jump_update | tail_commit_jump_update | tail_commit_not_jump_update));

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

assign commit_ptr_wen               = (update | jump_flag);
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
assign redirect_pc          = (commit_restore) ? ((jump_restore_flag | jump_flag) ? jump_addr : commit_pc) : if_precheck_retsore_pc;

assign update               = ((commit_flag & commit_end_flag) | (jump_restore_flag & commit_flag) | (jump_commit_flag & commit_flag));
assign update_hit           = commit_ftq_entry.hit;
assign update_sel           = commit_ftq_entry.hit_sel;
assign update_tag           = commit_ftq_entry.old_entry.tag;
assign update_entry         =   ({UFTB_ENTRY_BIT{update_entry_use_ftq       }} & commit_ftq_entry.old_entry ) | 
                                ({UFTB_ENTRY_BIT{br_commit_jump_update      }} & commit_br_jump_entry       ) | 
                                ({UFTB_ENTRY_BIT{br_commit_not_jump_update  }} & commit_br_not_jump_entry   ) | 
                                ({UFTB_ENTRY_BIT{tail_commit_jump_update    }} & commit_tail_jump_entry     ) | 
                                ({UFTB_ENTRY_BIT{tail_commit_not_jump_update}} & commit_tail_not_jump_entry );


assign precheck_restore     = (!commit_restore) & if_precheck_restore;
assign precheck_push        = (!commit_restore) & if_precheck_push;
assign precheck_push_pc     = if_precheck_push_pc;
assign precheck_pop         = (!commit_restore) & if_precheck_pop;
assign precheck_pop_pc_i    = if_precheck_pop_pc_i;
assign if_precheck_pop_pc   = precheck_pop_pc;

assign commit_restore       =   (jump_restore_flag & (jump_addr != next_pc)) | 
                                (jump_restore_flag & (!commit_end_flag)) | 
                                ((!(jump_restore_flag | jump_commit_flag)) & commit_end_flag & commit_flag & commit_ftq_entry.token) | 
                                jump_flag;
assign commit_push          = jump_restore_flag & jump_is_call;
assign commit_push_pc       = jump_push_addr;
assign commit_pop           = jump_restore_flag & jump_is_ret;

assign ifu_send_entry_valid = (ifu_s_ptr != bpu_w_ptr);
assign ifu_send_entry       = entry[ifu_s_ptr[FTQ_ENTRY_BIT_NUM - 1 : 0]];
assign ifu_dequeue_entry    = entry[ifu_r_ptr[FTQ_ENTRY_BIT_NUM - 1 : 0]];
assign ifu_dequeue_ptr      = ifu_r_ptr[FTQ_ENTRY_BIT_NUM - 1 : 0];

assign ex_r_start_pc        = entry[ex_r_ptr].start_pc;


endmodule //ftq
