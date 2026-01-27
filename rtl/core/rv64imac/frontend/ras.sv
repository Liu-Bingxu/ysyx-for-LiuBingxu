`include "./struct.sv"
module ras(
    input           clk,
    input           rst_n,

    input           pred_push,
    input  [63:0]   pred_push_pc,
    input           pred_pop,
    input  [63:0]   pred_pop_pc_i,
    output [63:0]   pred_pop_pc,

    input           precheck_restore,
    input           precheck_push,
    input  [63:0]   precheck_push_pc,
    input           precheck_pop,
    input  [63:0]   precheck_pop_pc_i,
    output [63:0]   precheck_pop_pc,

    input           commit_restore,
    input           commit_push,
    input  [63:0]   commit_push_pc,
    input           commit_pop
);

stack    return_addr_stack;
queue    return_addr_queue;

logic [RAS_ENTRY_BIT_NUM - 1:0]  last_nsp; // 上一个提交栈指针
logic [RAS_ENTRY_BIT_NUM - 1:0]  last_ssp; // 上一个预测栈指针
logic [RAS_ENTRY_BIT_NUM - 1:0]  last_psp; // 上一个预译码栈指针

logic    sq_empty,sq_full;
logic    sq_precheck_empty,sq_precheck_full;

logic    stack_empty,stack_full;
logic    stack_pred_empty;
logic    stack_precheck_empty;

logic    pred_push_recursion_flag;
logic    precheck_push_recursion_flag;
logic    commit_push_recursion_flag;

queue_entry queue_tosr_entry ;
queue_entry queue_ptosr_entry;
assign queue_tosr_entry        = return_addr_queue.entry[return_addr_queue.tosr];
assign queue_ptosr_entry       = return_addr_queue.entry[return_addr_queue.ptosr];

stack_entry stack_bos_entry     ;
stack_entry stack_last_nsp_entry;
stack_entry stack_last_ssp_entry;
stack_entry stack_last_psp_entry;
assign stack_bos_entry         = return_addr_stack.entry[return_addr_stack.bos];
assign stack_last_nsp_entry    = return_addr_stack.entry[last_nsp];
assign stack_last_ssp_entry    = return_addr_stack.entry[last_ssp];
assign stack_last_psp_entry    = return_addr_stack.entry[last_psp];

assign last_nsp = (return_addr_stack.nsp - 1);
assign last_ssp = (return_addr_stack.ssp - 1);
assign last_psp = (return_addr_stack.psp - 1);

assign sq_empty             = queue_tosr_entry.pred_cnt == {ENTRY_RECURSION_BIT{1'b0}};
assign sq_full              = ((return_addr_queue.tosw + 1) == return_addr_queue.bos);
assign sq_precheck_empty    = queue_ptosr_entry.precheck_cnt == {ENTRY_RECURSION_BIT{1'b0}};
assign sq_precheck_full     = ((return_addr_queue.ptosw + 1) == return_addr_queue.bos);

assign stack_empty          = stack_bos_entry.cnt == {ENTRY_RECURSION_BIT{1'b0}};
assign stack_full           = ((return_addr_stack.nsp + 1) == return_addr_stack.bos);
assign stack_pred_empty     = stack_bos_entry.pred_cnt == {ENTRY_RECURSION_BIT{1'b0}};
assign stack_precheck_empty = stack_bos_entry.precheck_cnt == {ENTRY_RECURSION_BIT{1'b0}};

assign pred_push_recursion_flag     = ((sq_empty == 1'b0) & (queue_tosr_entry.addr == pred_push_pc) & 
                                    (queue_tosr_entry.pred_cnt != {ENTRY_RECURSION_BIT{1'b1}}));
assign precheck_push_recursion_flag = ((sq_precheck_empty == 1'b0) & (queue_ptosr_entry.addr == pred_push_pc) & 
                                    (queue_ptosr_entry.precheck_cnt != {ENTRY_RECURSION_BIT{1'b1}}));
assign commit_push_recursion_flag   = ((stack_empty == 1'b0) & (stack_last_nsp_entry.addr == pred_push_pc) & 
                                    (stack_last_nsp_entry.cnt != {ENTRY_RECURSION_BIT{1'b1}}));

//============================================return_addr_stack====================================================
logic                               stack_nsp_wen;
logic [RAS_ENTRY_BIT_NUM - 1: 0]   stack_nsp_next;
logic                               stack_ssp_wen;
logic [RAS_ENTRY_BIT_NUM - 1: 0]   stack_ssp_next;
logic                               stack_psp_wen;
logic [RAS_ENTRY_BIT_NUM - 1: 0]   stack_psp_next;
logic                               stack_bos_wen;
logic [RAS_ENTRY_BIT_NUM - 1: 0]   stack_bos_next;


logic                               stack_nsp_push_wen;
assign stack_nsp_push_wen           = (commit_push & (!commit_push_recursion_flag));
logic                               stack_nsp_pop_wen;
assign stack_nsp_pop_wen            = (commit_pop & (!stack_empty) & (stack_last_nsp_entry.cnt == {{(ENTRY_RECURSION_BIT - 1){1'b0}}, 1'b1}));
assign stack_nsp_wen                = (stack_nsp_push_wen | stack_nsp_pop_wen);
assign stack_nsp_next               = ({RAS_ENTRY_BIT_NUM{stack_nsp_push_wen}} & (return_addr_stack.nsp + 1)) | 
                                    ({RAS_ENTRY_BIT_NUM{stack_nsp_pop_wen}} & (return_addr_stack.nsp - 1));
FF_D_with_wen #(
    .DATA_LEN 	(RAS_ENTRY_BIT_NUM  ),
    .RST_DATA 	(0                  ))
u_return_addr_stack_nsp(
    .clk      	(clk                    ),
    .rst_n    	(rst_n                  ),
    .wen      	(stack_nsp_wen          ),
    .data_in  	(stack_nsp_next         ),
    .data_out 	(return_addr_stack.nsp  )
);

logic                               stack_ssp_push_wen;
assign stack_ssp_push_wen           = (pred_push & (!pred_push_recursion_flag));
logic                               stack_ssp_pop_wen;
assign stack_ssp_pop_wen            = (pred_pop & ((!stack_pred_empty) | (!sq_empty)) & (stack_last_ssp_entry.pred_cnt == {{(ENTRY_RECURSION_BIT - 1){1'b0}}, 1'b1}));
assign stack_ssp_wen                = (stack_ssp_push_wen | stack_ssp_pop_wen | precheck_restore | commit_restore);
assign stack_ssp_next               = ({RAS_ENTRY_BIT_NUM{stack_ssp_push_wen}} & (return_addr_stack.ssp + 1)) | 
                                    ({RAS_ENTRY_BIT_NUM{stack_ssp_pop_wen}} & (return_addr_stack.ssp - 1)) | 
                                    ({RAS_ENTRY_BIT_NUM{precheck_restore}} & (return_addr_stack.psp)) | 
                                    ({RAS_ENTRY_BIT_NUM{commit_restore & stack_nsp_wen }} & (stack_nsp_next)) | 
                                    ({RAS_ENTRY_BIT_NUM{commit_restore & (!stack_nsp_wen)}} & (return_addr_stack.nsp));
FF_D_with_wen #(
    .DATA_LEN 	(RAS_ENTRY_BIT_NUM  ),
    .RST_DATA 	(0                    ))
u_return_addr_stack_entry_ssp(
    .clk      	(clk                    ),
    .rst_n    	(rst_n                  ),
    .wen      	(stack_ssp_wen          ),
    .data_in  	(stack_ssp_next         ),
    .data_out 	(return_addr_stack.ssp  )
);

logic                               stack_psp_push_wen;
assign stack_psp_push_wen           = (precheck_push & (!precheck_push_recursion_flag));
logic                               stack_psp_pop_wen;
assign stack_psp_pop_wen            = (precheck_pop & ((!stack_precheck_empty) | (!sq_precheck_empty)) & (stack_last_psp_entry.precheck_cnt == {{(ENTRY_RECURSION_BIT - 1){1'b0}}, 1'b1}));
assign stack_psp_wen                = (stack_psp_push_wen | stack_psp_pop_wen | commit_restore);
assign stack_psp_next               = ({RAS_ENTRY_BIT_NUM{stack_psp_push_wen}} & (return_addr_stack.psp + 1)) | 
                                    ({RAS_ENTRY_BIT_NUM{stack_psp_pop_wen}} & (return_addr_stack.psp - 1)) | 
                                    ({RAS_ENTRY_BIT_NUM{commit_restore & stack_nsp_wen }} & (stack_nsp_next)) | 
                                    ({RAS_ENTRY_BIT_NUM{commit_restore & (!stack_nsp_wen)}} & (return_addr_stack.nsp));
FF_D_with_wen #(
    .DATA_LEN 	(RAS_ENTRY_BIT_NUM  ),
    .RST_DATA 	(0                    ))
u_return_addr_stack_entry_psp(
    .clk      	(clk                    ),
    .rst_n    	(rst_n                  ),
    .wen      	(stack_psp_wen          ),
    .data_in  	(stack_psp_next         ),
    .data_out 	(return_addr_stack.psp  )
);

logic                               stack_bos_push_wen;
assign stack_bos_push_wen           = (commit_push & (!commit_push_recursion_flag) & stack_full);
assign stack_bos_wen                = stack_bos_push_wen;
assign stack_bos_next               = (return_addr_stack.bos + 1);
FF_D_with_wen #(
    .DATA_LEN 	(RAS_ENTRY_BIT_NUM  ),
    .RST_DATA 	(0                    ))
u_return_addr_stack_entry_bos(
    .clk      	(clk                    ),
    .rst_n    	(rst_n                  ),
    .wen      	(stack_bos_wen          ),
    .data_in  	(stack_bos_next         ),
    .data_out 	(return_addr_stack.bos  )
);

genvar stack_index;
generate for(stack_index = 0 ; stack_index < RAS_ENTRY_NUM; stack_index = stack_index + 1) begin : U_gen_ras_entry
    logic                               stack_cnt_wen;
    logic [ENTRY_RECURSION_BIT - 1: 0]  stack_cnt_next;
    logic                               stack_pred_cnt_wen;
    logic [ENTRY_RECURSION_BIT - 1: 0]  stack_pred_cnt_next;
    logic                               stack_precheck_cnt_wen;
    logic [ENTRY_RECURSION_BIT - 1: 0]  stack_precheck_cnt_next;

    FF_D_without_asyn_rst #(
        .DATA_LEN 	(64 ))
    u_return_addr_stack_entry_addr(
        .clk      	(clk                                                                                    ),
        .wen      	(commit_push & (!commit_push_recursion_flag) & (stack_index == return_addr_stack.nsp)   ),
        .data_in  	(commit_push_pc                                                                         ),
        .data_out 	(return_addr_stack.entry[stack_index].addr                                              )
    );

    logic                               stack_cnt_push_recursion_wen;
    assign stack_cnt_push_recursion_wen = (commit_push & commit_push_recursion_flag & (stack_index == last_nsp));
    logic                               stack_cnt_push_new_entry_wen;
    assign stack_cnt_push_new_entry_wen = (commit_push & (!commit_push_recursion_flag) & (stack_index == return_addr_stack.nsp));
    logic                               stack_cnt_pop_wen;
    assign stack_cnt_pop_wen            = (commit_pop & (!stack_empty) & (stack_index == last_nsp));
    assign stack_cnt_wen                = (stack_cnt_push_recursion_wen | stack_cnt_push_new_entry_wen | stack_cnt_pop_wen);
    assign stack_cnt_next               = ({ENTRY_RECURSION_BIT{stack_cnt_push_recursion_wen}} & (return_addr_stack.entry[stack_index].cnt + 1)) | 
                                        ({ENTRY_RECURSION_BIT{stack_cnt_push_new_entry_wen}} & {{(ENTRY_RECURSION_BIT - 1){1'b0}}, 1'b1}) | 
                                        ({ENTRY_RECURSION_BIT{stack_cnt_pop_wen}} & (return_addr_stack.entry[stack_index].cnt - 1));
    FF_D_with_wen #(
        .DATA_LEN 	(ENTRY_RECURSION_BIT  ),
        .RST_DATA 	(0                    ))
    u_return_addr_stack_entry_cnt(
        .clk      	(clk                                        ),
        .rst_n    	(rst_n                                      ),
        .wen      	(stack_cnt_wen                              ),
        .data_in  	(stack_cnt_next                             ),
        .data_out 	(return_addr_stack.entry[stack_index].cnt   )
    );

    logic                               stack_pred_cnt_push_recursion_wen;
    assign stack_pred_cnt_push_recursion_wen = (pred_push & pred_push_recursion_flag & (stack_index == last_ssp));
    logic                               stack_pred_cnt_push_new_entry_set_wen;
    assign stack_pred_cnt_push_new_entry_set_wen = (pred_push & (!pred_push_recursion_flag) & (stack_index == return_addr_stack.ssp));
    logic                               stack_pred_cnt_push_new_entry_clean_wen;
    assign stack_pred_cnt_push_new_entry_clean_wen = (pred_push & (!pred_push_recursion_flag) & (stack_index == (return_addr_stack.ssp + 1)));
    logic                               stack_pred_cnt_pop_wen;
    assign stack_pred_cnt_pop_wen            = (pred_pop & ((!stack_pred_empty) | (!sq_empty)) & (stack_index == last_ssp));
    assign stack_pred_cnt_wen                = (stack_pred_cnt_push_recursion_wen | stack_pred_cnt_push_new_entry_set_wen | stack_pred_cnt_push_new_entry_clean_wen | 
                                            stack_pred_cnt_pop_wen | precheck_restore | commit_restore);
    assign stack_pred_cnt_next          = ({ENTRY_RECURSION_BIT{stack_pred_cnt_push_recursion_wen}} & (return_addr_stack.entry[stack_index].pred_cnt + 1)) | 
                                        ({ENTRY_RECURSION_BIT{stack_pred_cnt_push_new_entry_set_wen}} & {{(ENTRY_RECURSION_BIT - 1){1'b0}}, 1'b1}) | 
                                        ({ENTRY_RECURSION_BIT{stack_pred_cnt_push_new_entry_clean_wen}} & {(ENTRY_RECURSION_BIT){1'b0}}) | 
                                        ({ENTRY_RECURSION_BIT{stack_pred_cnt_pop_wen}} & (return_addr_stack.entry[stack_index].pred_cnt - 1)) | 
                                        ({ENTRY_RECURSION_BIT{precheck_restore}} & (return_addr_stack.entry[stack_index].precheck_cnt)) | 
                                        ({ENTRY_RECURSION_BIT{commit_restore & stack_cnt_wen}} & (stack_cnt_next)) | 
                                        ({ENTRY_RECURSION_BIT{commit_restore & (!stack_cnt_wen)}} & (return_addr_stack.entry[stack_index].cnt));
    FF_D_with_wen #(
        .DATA_LEN 	(ENTRY_RECURSION_BIT  ),
        .RST_DATA 	(0                    ))
    u_return_addr_stack_entry_pred_cnt(
        .clk      	(clk                                            ),
        .rst_n    	(rst_n                                          ),
        .wen      	(stack_pred_cnt_wen                             ),
        .data_in  	(stack_pred_cnt_next                            ),
        .data_out 	(return_addr_stack.entry[stack_index].pred_cnt  )
    );

    logic                               stack_precheck_cnt_push_recursion_wen;
    assign stack_precheck_cnt_push_recursion_wen = (precheck_push & precheck_push_recursion_flag & (stack_index == last_psp));
    logic                               stack_precheck_cnt_push_new_entry_set_wen;
    assign stack_precheck_cnt_push_new_entry_set_wen = (precheck_push & (!precheck_push_recursion_flag) & (stack_index == return_addr_stack.psp));
    logic                               stack_precheck_cnt_push_new_entry_clean_wen;
    assign stack_precheck_cnt_push_new_entry_clean_wen = (precheck_push & (!precheck_push_recursion_flag) & (stack_index == (return_addr_stack.psp + 1)));
    logic                               stack_precheck_cnt_pop_wen;
    assign stack_precheck_cnt_pop_wen            = (precheck_pop & ((!stack_precheck_empty) | (!sq_precheck_empty)) & (stack_index == last_psp));
    assign stack_precheck_cnt_wen                = (stack_precheck_cnt_push_recursion_wen | stack_precheck_cnt_push_new_entry_set_wen | 
                                            stack_precheck_cnt_push_new_entry_clean_wen | stack_precheck_cnt_pop_wen | commit_restore);
    assign stack_precheck_cnt_next          = ({ENTRY_RECURSION_BIT{stack_precheck_cnt_push_recursion_wen}} & (return_addr_stack.entry[stack_index].precheck_cnt + 1)) | 
                                        ({ENTRY_RECURSION_BIT{stack_precheck_cnt_push_new_entry_set_wen}} & {{(ENTRY_RECURSION_BIT - 1){1'b0}}, 1'b1}) | 
                                        ({ENTRY_RECURSION_BIT{stack_precheck_cnt_push_new_entry_clean_wen}} & {(ENTRY_RECURSION_BIT){1'b0}}) | 
                                        ({ENTRY_RECURSION_BIT{stack_precheck_cnt_pop_wen}} & (return_addr_stack.entry[stack_index].precheck_cnt - 1)) | 
                                        ({ENTRY_RECURSION_BIT{commit_restore & stack_cnt_wen}} & (stack_cnt_next)) | 
                                        ({ENTRY_RECURSION_BIT{commit_restore & (!stack_cnt_wen)}} & (return_addr_stack.entry[stack_index].cnt));
    FF_D_with_wen #(
        .DATA_LEN 	(ENTRY_RECURSION_BIT  ),
        .RST_DATA 	(0                    ))
    u_return_addr_stack_entry_precheck_cnt(
        .clk      	(clk                                                ),
        .rst_n    	(rst_n                                              ),
        .wen      	(stack_precheck_cnt_wen                             ),
        .data_in  	(stack_precheck_cnt_next                            ),
        .data_out 	(return_addr_stack.entry[stack_index].precheck_cnt  )
    );
end
endgenerate
//============================================return_addr_stack====================================================



//============================================return_addr_queue====================================================
logic                               queue_tosr_wen;
logic [SQ_ENTRY_BIT_NUM - 1: 0]     queue_tosr_next;
logic                               queue_tosw_wen;
logic [SQ_ENTRY_BIT_NUM - 1: 0]     queue_tosw_next;
logic                               queue_ptosr_wen;
logic [SQ_ENTRY_BIT_NUM - 1: 0]     queue_ptosr_next;
logic                               queue_ptosw_wen;
logic [SQ_ENTRY_BIT_NUM - 1: 0]     queue_ptosw_next;
logic                               queue_bos_wen;
logic [SQ_ENTRY_BIT_NUM - 1: 0]     queue_bos_next;


logic                               queue_tosr_push_wen;
assign queue_tosr_push_wen          = (pred_push & (!pred_push_recursion_flag));
logic                               queue_tosr_pop_wen;
assign queue_tosr_pop_wen           = (pred_pop & (!sq_empty) & (queue_tosr_entry.pred_cnt == {{(ENTRY_RECURSION_BIT - 1){1'b0}}, 1'b1}));
assign queue_tosr_wen               = (queue_tosr_push_wen | queue_tosr_pop_wen | precheck_restore | commit_restore);
assign queue_tosr_next              = ({SQ_ENTRY_BIT_NUM{queue_tosr_push_wen}} & (return_addr_queue.tosw)) | 
                                    ({SQ_ENTRY_BIT_NUM{queue_tosr_pop_wen}} & (queue_tosr_entry.nos)) | 
                                    ({SQ_ENTRY_BIT_NUM{precheck_restore}} & (return_addr_queue.ptosr)) | 
                                    ({SQ_ENTRY_BIT_NUM{commit_restore & queue_bos_wen}} & (queue_bos_next)) | 
                                    ({SQ_ENTRY_BIT_NUM{commit_restore & (!queue_bos_wen)}} & (return_addr_queue.bos));
FF_D_with_wen #(
    .DATA_LEN 	(SQ_ENTRY_BIT_NUM   ),
    .RST_DATA 	(0                  ))
u_return_addr_queue_tosr(
    .clk      	(clk                    ),
    .rst_n    	(rst_n                  ),
    .wen      	(queue_tosr_wen         ),
    .data_in  	(queue_tosr_next        ),
    .data_out 	(return_addr_queue.tosr )
);

logic                               queue_tosw_push_wen;
assign queue_tosw_push_wen           = (pred_push & (!pred_push_recursion_flag));
assign queue_tosw_wen                = (queue_tosw_push_wen | precheck_restore | commit_restore);
assign queue_tosw_next               = ({SQ_ENTRY_BIT_NUM{queue_tosw_push_wen}} & (return_addr_queue.tosw + 1)) | 
                                    ({SQ_ENTRY_BIT_NUM{precheck_restore}} & (return_addr_queue.ptosw)) | 
                                    ({SQ_ENTRY_BIT_NUM{commit_restore & queue_bos_wen}} & (queue_bos_next)) | 
                                    ({SQ_ENTRY_BIT_NUM{commit_restore & (!queue_bos_wen)}} & (return_addr_queue.bos));
FF_D_with_wen #(
    .DATA_LEN 	(SQ_ENTRY_BIT_NUM   ),
    .RST_DATA 	(0                  ))
u_return_addr_queue_tosw(
    .clk      	(clk                    ),
    .rst_n    	(rst_n                  ),
    .wen      	(queue_tosw_wen         ),
    .data_in  	(queue_tosw_next        ),
    .data_out 	(return_addr_queue.tosw )
);

logic                               queue_ptosr_push_wen;
assign queue_ptosr_push_wen           = (precheck_push & (!precheck_push_recursion_flag));
logic                               queue_ptosr_pop_wen;
assign queue_ptosr_pop_wen            = (precheck_pop & (!sq_precheck_empty) & (queue_ptosr_entry.precheck_cnt == {{(ENTRY_RECURSION_BIT - 1){1'b0}}, 1'b1}));
assign queue_ptosr_wen                = (queue_ptosr_push_wen | queue_ptosr_pop_wen | commit_restore);
assign queue_ptosr_next               = ({SQ_ENTRY_BIT_NUM{queue_ptosr_push_wen}} & (return_addr_queue.ptosw)) | 
                                    ({SQ_ENTRY_BIT_NUM{queue_ptosr_pop_wen}} & (queue_ptosr_entry.nos)) | 
                                    ({SQ_ENTRY_BIT_NUM{commit_restore & queue_bos_wen}} & (queue_bos_next)) | 
                                    ({SQ_ENTRY_BIT_NUM{commit_restore & (!queue_bos_wen)}} & (return_addr_queue.bos));
FF_D_with_wen #(
    .DATA_LEN 	(SQ_ENTRY_BIT_NUM   ),
    .RST_DATA 	(0                  ))
u_return_addr_queue_ptosr(
    .clk      	(clk                    ),
    .rst_n    	(rst_n                  ),
    .wen      	(queue_ptosr_wen        ),
    .data_in  	(queue_ptosr_next       ),
    .data_out 	(return_addr_queue.ptosr)
);

logic                               queue_ptosw_push_wen;
assign queue_ptosw_push_wen           = (precheck_push & (!precheck_push_recursion_flag));
assign queue_ptosw_wen                = (queue_ptosw_push_wen | commit_restore);
assign queue_ptosw_next               = ({SQ_ENTRY_BIT_NUM{queue_ptosw_push_wen}} & (return_addr_queue.ptosw + 1)) | 
                                    ({SQ_ENTRY_BIT_NUM{commit_restore & queue_bos_wen}} & (queue_bos_next)) | 
                                    ({SQ_ENTRY_BIT_NUM{commit_restore & (!queue_bos_wen)}} & (return_addr_queue.bos));
FF_D_with_wen #(
    .DATA_LEN 	(SQ_ENTRY_BIT_NUM  ),
    .RST_DATA 	(0                 ))
u_return_addr_queue_ptosw(
    .clk      	(clk                    ),
    .rst_n    	(rst_n                  ),
    .wen      	(queue_ptosw_wen        ),
    .data_in  	(queue_ptosw_next       ),
    .data_out 	(return_addr_queue.ptosw)
);

//! TODO 三种情况赋同样的值，所以不管，除非有bug
logic                               queue_bos_pred_push_wen;
assign queue_bos_pred_push_wen      = (pred_push & (!pred_push_recursion_flag) & sq_full);
logic                               queue_bos_precheck_push_wen;
assign queue_bos_precheck_push_wen  = (precheck_push & (!precheck_push_recursion_flag) & sq_precheck_full);
logic                               queue_bos_commit_push_wen;
assign queue_bos_commit_push_wen    = (commit_push & (return_addr_queue.bos != return_addr_queue.ptosw));
assign queue_bos_wen                = (queue_bos_pred_push_wen | queue_bos_precheck_push_wen | queue_bos_commit_push_wen);
assign queue_bos_next               = (return_addr_queue.bos + 1);
FF_D_with_wen #(
    .DATA_LEN 	(SQ_ENTRY_BIT_NUM  ),
    .RST_DATA 	(0                 ))
u_return_addr_queue_bos(
    .clk      	(clk                    ),
    .rst_n    	(rst_n                  ),
    .wen      	(queue_bos_wen          ),
    .data_in  	(queue_bos_next         ),
    .data_out 	(return_addr_queue.bos  )
);

genvar queue_index;
generate for(queue_index = 0 ; queue_index < SQ_ENTRY_NUM; queue_index = queue_index + 1) begin : U_gen_sq_entry
    logic                               queue_addr_wen;
    logic [63: 0]                       queue_addr_next;
    logic                               queue_nos_wen;
    logic [SQ_ENTRY_BIT_NUM - 1: 0]     queue_nos_next;
    logic                               queue_pred_cnt_wen;
    logic [ENTRY_RECURSION_BIT - 1: 0]  queue_pred_cnt_next;
    logic                               queue_precheck_cnt_wen;
    logic [ENTRY_RECURSION_BIT - 1: 0]  queue_precheck_cnt_next;

    //! TODO pred和precheck有可能同时有效，但很极端，暂且不考虑，以下都是

    logic                               queue_addr_pred_push_new_entry_wen;
    assign queue_addr_pred_push_new_entry_wen = (pred_push & (!pred_push_recursion_flag) & (queue_index == return_addr_queue.tosw));
    logic                               queue_addr_precheck_push_new_entry_wen;
    assign queue_addr_precheck_push_new_entry_wen = (precheck_push & (!precheck_push_recursion_flag) & (queue_index == return_addr_queue.ptosw));
    assign queue_addr_wen                = (queue_addr_pred_push_new_entry_wen | queue_addr_precheck_push_new_entry_wen);
    assign queue_addr_next               = ({64{queue_addr_pred_push_new_entry_wen}} & pred_push_pc) | 
                                        ({64{queue_addr_precheck_push_new_entry_wen}} & precheck_push_pc);
    FF_D_without_asyn_rst #(
        .DATA_LEN 	(64 ))
    u_return_addr_queue_entry_addr(
        .clk      	(clk                                        ),
        .wen      	(queue_addr_wen                             ),
        .data_in  	(queue_addr_next                            ),
        .data_out 	(return_addr_queue.entry[queue_index].addr  )
    );

    logic                               queue_nos_pred_push_new_entry_wen;
    assign queue_nos_pred_push_new_entry_wen = (pred_push & (!pred_push_recursion_flag) & (queue_index == return_addr_queue.tosw));
    logic                               queue_nos_precheck_push_new_entry_wen;
    assign queue_nos_precheck_push_new_entry_wen = (precheck_push & (!precheck_push_recursion_flag) & (queue_index == return_addr_queue.ptosw));
    assign queue_nos_wen                = (queue_nos_pred_push_new_entry_wen | queue_nos_precheck_push_new_entry_wen);
    assign queue_nos_next               = ({SQ_ENTRY_BIT_NUM{queue_nos_pred_push_new_entry_wen}} & return_addr_queue.tosr) | 
                                        ({SQ_ENTRY_BIT_NUM{queue_nos_precheck_push_new_entry_wen}} & return_addr_queue.ptosr);
    FF_D_without_asyn_rst #(
        .DATA_LEN 	(SQ_ENTRY_BIT_NUM  ))
    u_return_addr_queue_entry_nos(
        .clk      	(clk                                        ),
        .wen      	(queue_nos_wen                              ),
        .data_in  	(queue_nos_next                             ),
        .data_out 	(return_addr_queue.entry[queue_index].nos   )
    );

    logic                               queue_pred_cnt_push_recursion_wen;
    assign queue_pred_cnt_push_recursion_wen = (pred_push & pred_push_recursion_flag & (queue_index == return_addr_queue.tosr));
    logic                               queue_pred_cnt_push_new_entry_set_wen;
    assign queue_pred_cnt_push_new_entry_set_wen = (pred_push & (!pred_push_recursion_flag) & (queue_index == return_addr_queue.tosw));
    logic                               queue_pred_cnt_push_new_entry_clean_wen;
    assign queue_pred_cnt_push_new_entry_clean_wen = (pred_push & (!pred_push_recursion_flag) & (queue_index == (return_addr_queue.bos)) & sq_full);
    logic                               queue_pred_cnt_pop_wen;
    assign queue_pred_cnt_pop_wen            = (pred_pop & (!sq_empty) & (queue_index == return_addr_queue.tosr));
    assign queue_pred_cnt_wen                = (queue_pred_cnt_push_recursion_wen | queue_pred_cnt_push_new_entry_set_wen | queue_pred_cnt_push_new_entry_clean_wen | 
                                            queue_pred_cnt_pop_wen | precheck_restore | commit_restore);
    assign queue_pred_cnt_next          = ({ENTRY_RECURSION_BIT{queue_pred_cnt_push_recursion_wen}} & (return_addr_queue.entry[queue_index].pred_cnt + 1)) | 
                                        ({ENTRY_RECURSION_BIT{queue_pred_cnt_push_new_entry_set_wen}} & {{(ENTRY_RECURSION_BIT - 1){1'b0}}, 1'b1}) | 
                                        ({ENTRY_RECURSION_BIT{queue_pred_cnt_push_new_entry_clean_wen}} & {(ENTRY_RECURSION_BIT){1'b0}}) | 
                                        ({ENTRY_RECURSION_BIT{queue_pred_cnt_pop_wen}} & (return_addr_queue.entry[queue_index].pred_cnt - 1)) | 
                                        ({ENTRY_RECURSION_BIT{precheck_restore}} & (return_addr_queue.entry[queue_index].precheck_cnt)) | 
                                        ({ENTRY_RECURSION_BIT{commit_restore}} & {(ENTRY_RECURSION_BIT){1'b0}});
    FF_D_with_wen #(
        .DATA_LEN 	(ENTRY_RECURSION_BIT  ),
        .RST_DATA 	(0                    ))
    u_return_addr_queue_entry_pred_cnt(
        .clk      	(clk                                            ),
        .rst_n    	(rst_n                                          ),
        .wen      	(queue_pred_cnt_wen                             ),
        .data_in  	(queue_pred_cnt_next                            ),
        .data_out 	(return_addr_queue.entry[queue_index].pred_cnt  )
    );

    logic                               queue_precheck_cnt_push_recursion_wen;
    assign queue_precheck_cnt_push_recursion_wen = (precheck_push & precheck_push_recursion_flag & (queue_index == return_addr_queue.ptosr));
    logic                               queue_precheck_cnt_push_new_entry_set_wen;
    assign queue_precheck_cnt_push_new_entry_set_wen = (precheck_push & (!precheck_push_recursion_flag) & (queue_index == return_addr_queue.ptosw));
    logic                               queue_precheck_cnt_push_new_entry_clean_wen;
    assign queue_precheck_cnt_push_new_entry_clean_wen = (precheck_push & (!precheck_push_recursion_flag) & (queue_index == return_addr_queue.bos) & sq_precheck_full);
    logic                               queue_precheck_cnt_pop_wen;
    assign queue_precheck_cnt_pop_wen            = (precheck_pop & (!sq_precheck_empty) & (queue_index == return_addr_queue.ptosr));
    assign queue_precheck_cnt_wen                = (queue_precheck_cnt_push_recursion_wen | queue_precheck_cnt_push_new_entry_set_wen | 
                                            queue_precheck_cnt_push_new_entry_clean_wen | queue_precheck_cnt_pop_wen | commit_restore);
    assign queue_precheck_cnt_next          = ({ENTRY_RECURSION_BIT{queue_precheck_cnt_push_recursion_wen}} & (return_addr_queue.entry[queue_index].precheck_cnt + 1)) | 
                                        ({ENTRY_RECURSION_BIT{queue_precheck_cnt_push_new_entry_set_wen}} & {{(ENTRY_RECURSION_BIT - 1){1'b0}}, 1'b1}) | 
                                        ({ENTRY_RECURSION_BIT{queue_precheck_cnt_push_new_entry_clean_wen}} & {(ENTRY_RECURSION_BIT){1'b0}}) | 
                                        ({ENTRY_RECURSION_BIT{queue_precheck_cnt_pop_wen}} & (return_addr_queue.entry[queue_index].precheck_cnt - 1)) | 
                                        ({ENTRY_RECURSION_BIT{commit_restore}} & {(ENTRY_RECURSION_BIT){1'b0}});
    FF_D_with_wen #(
        .DATA_LEN 	(ENTRY_RECURSION_BIT  ),
        .RST_DATA 	(0                    ))
    u_return_addr_queue_entry_precheck_cnt(
        .clk      	(clk                                                ),
        .rst_n    	(rst_n                                              ),
        .wen      	(queue_precheck_cnt_wen                             ),
        .data_in  	(queue_precheck_cnt_next                            ),
        .data_out 	(return_addr_queue.entry[queue_index].precheck_cnt  )
    );
end
endgenerate
//============================================return_addr_queue====================================================


//? TODO:目前采用组合逻辑直接输出，以后时序有问题了在改时序输出
assign pred_pop_pc = (sq_empty == 1'b0) ? queue_tosr_entry.addr : 
                    (stack_pred_empty == 1'b0) ? stack_last_ssp_entry.addr : pred_pop_pc_i;

assign precheck_pop_pc = (sq_precheck_empty == 1'b0) ? queue_ptosr_entry.addr : 
                    (stack_precheck_empty == 1'b0) ? stack_last_psp_entry.addr : precheck_pop_pc_i;

endmodule// ras
