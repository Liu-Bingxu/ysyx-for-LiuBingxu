module LoadQueue
import lsq_pkg::*;
import rob_pkg::*;
import regfile_pkg::*;
import mem_pkg::*;
import core_setting_pkg::*;
(
    input                                               clk,
    input                                               rst_n,

    input                                               redirect,

    input  rob_entry_ptr_t                              top_rob_ptr,
    input  [commit_width - 1 : 0]                       rob_commit_instret,

    input                                               rename_fire,
    input              [rename_width - 1 : 0]           lq_req,
    input   lq_entry_t [rename_width - 1 : 0]           lq_req_entry,
    output  lq_resp_t  [rename_width - 1 : 0]           lq_resp,

    input  LQ_entry_ptr_t                               loadUnit_lq_ptr_query,
    output load_optype_t                                loadUnit_op_query,

    input                                               loadUnit_valid_o,
    output                                              loadUnit_ready_o,
    input                                               loadUnit_addr_misalign_o,
    input                                               loadUnit_page_error_o,
    input   [63:0]                                      loadUnit_paddr_o,
    input   [63:0]                                      loadUnit_vaddr_o,
    input  LQ_entry_ptr_t                               loadUnit_lq_ptr_o,

    output                                              LoadQueue_arvalid,
    input                                               LoadQueue_arready,
    output  [2:0]                                       LoadQueue_arsize,
    output  [63:0]                                      LoadQueue_araddr,
    output ls_rob_entry_ptr_t                           LoadQueue_rob_ptr,
    output LQ_entry_ptr_t                               LoadQueue_lq_ptr,

    output                                              LoadQueue_enq_lqRAW_o,
    output [63:0]                                       LoadQueue_raddr_o,
    output [2:0]                                        LoadQueue_rsize_o,
    output ls_rob_entry_ptr_t                           LoadQueue_enq_rob_ptr_o,

    input                                               LoadQueue_rvalid,
    output                                              LoadQueue_rready,
    input  [1:0]                                        LoadQueue_rresp,
    input  [63:0]                                       LoadQueue_rdata,
    input  LQ_entry_ptr_t                               LoadQueue_lq_ptr_update,

    output                                              LoadQueue_valid_o,
    input                                               LoadQueue_ready_o,
    output                                              LoadQueue_addr_misalign_o,
    output                                              LoadQueue_page_error_o,
    output                                              LoadQueue_load_error_o,
    output                                              LoadQueue_rfwen_o,
    output pint_regdest_t                               LoadQueue_pwdest_o,
    output [63:0]                                       LoadQueue_preg_wdata_o,
    output rob_entry_ptr_t                              LoadQueue_rob_ptr_o,
    output [63:0]                                       LoadQueue_vaddr_o
);

lq_entry_t [LQ_entry_num - 1 : 0] lq_entry;
LQ_entry_ptr_inner_t              lq_r_ptr;
LQ_entry_ptr_inner_t              lq_w_ptr;

/* verilator lint_off UNUSEDSIGNAL */
lq_entry_t                        lq_entry_loadaddr_use;
lq_entry_t                        lq_entry_issue_use;
lq_entry_t                        lq_entry_commit_use;
lq_entry_t [LQ_entry_num - 1 : 0] lq_entry_r_ptr_step_use/* verilator split_var */;
/* verilator lint_on UNUSEDSIGNAL */

logic                [LQ_entry_num - 1 : 0] valid_r_ptr_step_inner/* verilator split_var */;
LQ_entry_ptr_inner_t [LQ_entry_num - 1 : 0] lq_ptr_r_ptr_step_inner/* verilator split_var */;
logic                                       valid_r_ptr_step;
LQ_entry_ptr_inner_t                        lq_ptr_r_ptr_step;

logic          [LQ_entry_num - 1 : 0]       valid_issue_ne_inner/* verilator split_var */;
LQ_entry_ptr_t [LQ_entry_num - 1 : 0]       lq_ptr_issue_ne_inner/* verilator split_var */;
logic          [LQ_entry_num - 1 : 0]       valid_issue_eq_inner/* verilator split_var */;
LQ_entry_ptr_t [LQ_entry_num - 1 : 0]       lq_ptr_issue_eq_inner/* verilator split_var */;
logic                                       valid_issue;
LQ_entry_ptr_t                              lq_ptr_issue;

logic          [LQ_entry_num - 1 : 0]       valid_commit_eq_inner/* verilator split_var */;
LQ_entry_ptr_t [LQ_entry_num - 1 : 0]       lq_ptr_commit_eq_inner/* verilator split_var */;
logic          [LQ_entry_num - 1 : 0]       valid_commit_ne_inner/* verilator split_var */;
LQ_entry_ptr_t [LQ_entry_num - 1 : 0]       lq_ptr_commit_ne_inner/* verilator split_var */;
logic                                       valid_commit;
LQ_entry_ptr_t                              lq_ptr_commit;

LQ_entry_ptr_t                              lq_ptr_report;

LQ_entry_ptr_inner_t [rename_width - 1 : 0] lq_ptr_resp/* verilator split_var */;
LQ_entry_ptr_t  [rename_width - 1 : 0]      lq_ptr_enq;
lq_resp_t       [rename_width - 1 : 0]      lq_resp_inner/* verilator split_var */;

LQ_entry_ptr_inner_t              lq_w_ptr_nxt;
assign lq_w_ptr_nxt = (lq_resp_inner[rename_width - 1].valid & lq_req[rename_width - 1] ) ? (lq_ptr_resp[rename_width - 1] + 1) : lq_ptr_resp[rename_width - 1];
FF_D_with_syn_rst #(
    .DATA_LEN 	( LQ_entry_w + 1    ),
    .RST_DATA 	( 0                 )
)u_lq_w_ptr
(
    .clk        ( clk           ),
    .rst_n      ( rst_n         ),
    .syn_rst    ( redirect      ),
    .wen        ( rename_fire   ),
    .data_in    ( lq_w_ptr_nxt  ),
    .data_out   ( lq_w_ptr      )
);

LQ_entry_ptr_inner_t              lq_r_ptr_nxt;
assign lq_r_ptr_nxt = lq_ptr_r_ptr_step;
FF_D_with_syn_rst #(
    .DATA_LEN 	( LQ_entry_w + 1    ),
    .RST_DATA 	( 0                 )
)u_lq_r_ptr
(
    .clk        ( clk               ),
    .rst_n      ( rst_n             ),
    .syn_rst    ( redirect          ),
    .wen        ( valid_r_ptr_step  ),
    .data_in    ( lq_r_ptr_nxt      ),
    .data_out   ( lq_r_ptr          )
);

assign valid_issue          =   (valid_issue_eq_inner[LQ_entry_num - 1] & valid_issue_ne_inner[LQ_entry_num - 1]) ? 
                                ((lq_w_ptr[LQ_entry_w] == lq_r_ptr[LQ_entry_w]) ?  valid_issue_eq_inner[LQ_entry_num - 1] :  valid_issue_ne_inner[LQ_entry_num - 1]) : 
                                (valid_issue_eq_inner[LQ_entry_num - 1] ? valid_issue_eq_inner[LQ_entry_num - 1] : valid_issue_ne_inner[LQ_entry_num - 1]);
assign lq_ptr_issue         =   (valid_issue_eq_inner[LQ_entry_num - 1] & valid_issue_ne_inner[LQ_entry_num - 1]) ? 
                                ((lq_w_ptr[LQ_entry_w] == lq_r_ptr[LQ_entry_w]) ? lq_ptr_issue_eq_inner[LQ_entry_num - 1] : lq_ptr_issue_ne_inner[LQ_entry_num - 1]) : 
                                (valid_issue_eq_inner[LQ_entry_num - 1] ? lq_ptr_issue_eq_inner[LQ_entry_num - 1] : lq_ptr_issue_ne_inner[LQ_entry_num - 1]);

assign valid_commit         =   (valid_commit_eq_inner[LQ_entry_num - 1] & valid_commit_ne_inner[LQ_entry_num - 1]) ? 
                                ((lq_w_ptr[LQ_entry_w] == lq_r_ptr[LQ_entry_w]) ?  valid_commit_eq_inner[LQ_entry_num - 1] :  valid_commit_ne_inner[LQ_entry_num - 1]) : 
                                ((valid_commit_eq_inner[LQ_entry_num - 1]) ?  valid_commit_eq_inner[LQ_entry_num - 1] :  valid_commit_ne_inner[LQ_entry_num - 1]);
assign lq_ptr_commit        =   (valid_commit_eq_inner[LQ_entry_num - 1] & valid_commit_ne_inner[LQ_entry_num - 1]) ? 
                                ((lq_w_ptr[LQ_entry_w] == lq_r_ptr[LQ_entry_w]) ? lq_ptr_commit_eq_inner[LQ_entry_num - 1] : lq_ptr_commit_ne_inner[LQ_entry_num - 1]) : 
                                ((valid_commit_eq_inner[LQ_entry_num - 1]) ? lq_ptr_commit_eq_inner[LQ_entry_num - 1] : lq_ptr_commit_ne_inner[LQ_entry_num - 1]);

assign lq_ptr_report        = LoadQueue_rvalid ? LoadQueue_lq_ptr_update : lq_ptr_commit;

assign valid_r_ptr_step     = (|valid_r_ptr_step_inner);
assign lq_ptr_r_ptr_step    = valid_r_ptr_step_inner[LQ_entry_num - 1] ? (lq_ptr_r_ptr_step_inner[LQ_entry_num - 1] + 1) : lq_ptr_r_ptr_step_inner[LQ_entry_num - 1];

genvar entry_index;
generate for(entry_index = 0 ; entry_index < LQ_entry_num; entry_index = entry_index + 1) begin : U_gen_lq_entry
    logic       lq_entry_wen;
    logic       lq_entry_enq_wen;
    logic       lq_entry_loadaddr_update_wen;
    logic       lq_entry_load_send_addr_update_wen;
    logic       lq_entry_loadfinish_update_wen;
    logic       lq_entry_loadcommit_update_wen;
    lq_entry_t  lq_entry_nxt;
    lq_entry_t  lq_entry_enq;
    lq_entry_t  lq_entry_loadaddr_update;
    lq_entry_t  lq_entry_load_send_addr_update;
    lq_entry_t  lq_entry_loadfinish_update;
    lq_entry_t  lq_entry_loadcommit_update;

    LoadQueue_enq u_LoadQueue_enq(
        .rename_fire       	( rename_fire        ),
        .lq_req           	( lq_req             ),
        .lq_req_entry     	( lq_req_entry       ),
        .lq_ptr_resp      	( lq_ptr_enq         ),
        .lq_ptr_self      	( entry_index        ),
        .lq_entry_enq_wen 	( lq_entry_enq_wen   ),
        .lq_entry_enq     	( lq_entry_enq       )
    );
    logic lq_commit_maybe_finish;
    always_comb begin
        Load_commit_judge(
            top_rob_ptr,
            rob_commit_instret,
            lq_entry[entry_index],
            lq_commit_maybe_finish,
            lq_entry_loadcommit_update
        );
    end
    assign lq_entry_loadcommit_update_wen = lq_commit_maybe_finish & `LoadQueueValid(lq_r_ptr, lq_w_ptr, entry_index);

    assign lq_entry_loadaddr_update_wen                     = loadUnit_valid_o & loadUnit_ready_o & (entry_index == loadUnit_lq_ptr_o);
    assign lq_entry_loadaddr_update.rob_ptr                 = lq_entry[entry_index].rob_ptr                        ;
    assign lq_entry_loadaddr_update.op                      = lq_entry[entry_index].op                             ;
    assign lq_entry_loadaddr_update.rfwen                   = lq_entry[entry_index].rfwen                          ;
    assign lq_entry_loadaddr_update.pwdest                  = lq_entry[entry_index].pwdest                         ;
    assign lq_entry_loadaddr_update.lq_entry_status         = lq_get_addr                                          ;
    assign lq_entry_loadaddr_update.addr_misalign           = loadUnit_addr_misalign_o                             ;
    assign lq_entry_loadaddr_update.page_error              = loadUnit_page_error_o                                ;
    assign lq_entry_loadaddr_update.mem_paddr               = loadUnit_paddr_o                                     ;
    assign lq_entry_loadaddr_update.mem_vaddr               = loadUnit_vaddr_o                                     ;

    assign lq_entry_load_send_addr_update_wen               = LoadQueue_arvalid & LoadQueue_arready & (entry_index == lq_ptr_issue);
    assign lq_entry_load_send_addr_update.rob_ptr           = lq_entry[entry_index].rob_ptr                        ;
    assign lq_entry_load_send_addr_update.op                = lq_entry[entry_index].op                             ;
    assign lq_entry_load_send_addr_update.rfwen             = lq_entry[entry_index].rfwen                          ;
    assign lq_entry_load_send_addr_update.pwdest            = lq_entry[entry_index].pwdest                         ;
    assign lq_entry_load_send_addr_update.lq_entry_status   = lq_send_addr                                         ;
    assign lq_entry_load_send_addr_update.addr_misalign     = lq_entry[entry_index].addr_misalign                  ;
    assign lq_entry_load_send_addr_update.page_error        = lq_entry[entry_index].page_error                     ;
    assign lq_entry_load_send_addr_update.mem_paddr         = lq_entry[entry_index].mem_paddr                      ;
    assign lq_entry_load_send_addr_update.mem_vaddr         = lq_entry[entry_index].mem_vaddr                      ;

    assign lq_entry_loadfinish_update_wen                   = LoadQueue_valid_o & LoadQueue_ready_o & (entry_index == lq_ptr_report);
    assign lq_entry_loadfinish_update.rob_ptr               = lq_entry[entry_index].rob_ptr                        ;
    assign lq_entry_loadfinish_update.op                    = lq_entry[entry_index].op                             ;
    assign lq_entry_loadfinish_update.rfwen                 = lq_entry[entry_index].rfwen                          ;
    assign lq_entry_loadfinish_update.pwdest                = lq_entry[entry_index].pwdest                         ;
    assign lq_entry_loadfinish_update.lq_entry_status       = lq_send_rob                                          ;
    assign lq_entry_loadfinish_update.addr_misalign         = lq_entry[entry_index].addr_misalign                  ;
    assign lq_entry_loadfinish_update.page_error            = lq_entry[entry_index].page_error                     ;
    assign lq_entry_loadfinish_update.mem_paddr             = lq_entry[entry_index].mem_paddr                      ;
    assign lq_entry_loadfinish_update.mem_vaddr             = lq_entry[entry_index].mem_vaddr                      ;

    assign lq_entry_wen =   (lq_entry_enq_wen                      ) | 
                            (lq_entry_loadaddr_update_wen          ) | 
                            (lq_entry_load_send_addr_update_wen    ) | 
                            (lq_entry_loadfinish_update_wen        ) | 
                            (lq_entry_loadcommit_update_wen        );
    assign lq_entry_nxt =   ({LQ_ENTRY_W{lq_entry_enq_wen                   }} & lq_entry_enq                   ) | 
                            ({LQ_ENTRY_W{lq_entry_loadaddr_update_wen       }} & lq_entry_loadaddr_update       ) | 
                            ({LQ_ENTRY_W{lq_entry_load_send_addr_update_wen }} & lq_entry_load_send_addr_update ) | 
                            ({LQ_ENTRY_W{lq_entry_loadfinish_update_wen     }} & lq_entry_loadfinish_update     ) | 
                            ({LQ_ENTRY_W{lq_entry_loadcommit_update_wen     }} & lq_entry_loadcommit_update     );

    FF_D_without_asyn_rst #(LQ_ENTRY_W)    u_entry     (clk,lq_entry_wen, lq_entry_nxt, lq_entry[entry_index]);

    logic issue_valid;
    assign issue_valid = (`LoadQueueValid(lq_r_ptr, lq_w_ptr, entry_index) & (lq_entry[entry_index].lq_entry_status == lq_get_addr) & 
                        (!lq_entry[entry_index].addr_misalign) & (!lq_entry[entry_index].page_error) & 
                        (`addrcache(lq_entry[entry_index].mem_paddr) | (lq_entry[entry_index].rob_ptr[rob_entry_w - 1 : 0] == top_rob_ptr)));

    logic commit_valid;
    assign commit_valid = (`LoadQueueValid(lq_r_ptr, lq_w_ptr, entry_index) & (lq_entry[entry_index].lq_entry_status == lq_get_addr) & 
                        (lq_entry[entry_index].addr_misalign | lq_entry[entry_index].page_error));

    assign lq_entry_r_ptr_step_use[entry_index]         = lq_entry[lq_ptr_r_ptr_step_inner[entry_index][LQ_entry_w - 1 : 0]];
    assign valid_r_ptr_step_inner[entry_index]          = (((lq_ptr_r_ptr_step_inner[entry_index] < lq_w_ptr) | (lq_ptr_r_ptr_step_inner[entry_index][LQ_entry_w] & (!lq_w_ptr[LQ_entry_w]))) & 
                                                            (lq_entry_r_ptr_step_use[entry_index].lq_entry_status == lq_commit));

    if(entry_index == 0)begin : U_gen_lq_misc_0
        assign valid_issue_eq_inner[entry_index]        = issue_valid;
        assign lq_ptr_issue_eq_inner[entry_index]       = entry_index;
        assign valid_issue_ne_inner[entry_index]        = (issue_valid & (entry_index >= lq_r_ptr[LQ_entry_w - 1 : 0]));
        assign lq_ptr_issue_ne_inner[entry_index]       = entry_index;

        assign valid_commit_eq_inner[entry_index]       = commit_valid;
        assign lq_ptr_commit_eq_inner[entry_index]      = entry_index;
        assign valid_commit_ne_inner[entry_index]       = (commit_valid & (entry_index >= lq_r_ptr[LQ_entry_w - 1 : 0]));
        assign lq_ptr_commit_ne_inner[entry_index]      = entry_index;

        assign lq_ptr_r_ptr_step_inner[entry_index]     = lq_r_ptr;
    end
    else begin : U_gen_lq_misc_other
        assign valid_issue_eq_inner[entry_index]        = (issue_valid | valid_issue_eq_inner[entry_index - 1]);
        assign lq_ptr_issue_eq_inner[entry_index]       = valid_issue_eq_inner[entry_index - 1] ? lq_ptr_issue_eq_inner[entry_index - 1] : entry_index;
        assign valid_issue_ne_inner[entry_index]        = ((issue_valid & (entry_index >= lq_r_ptr[LQ_entry_w - 1 : 0])) | valid_issue_ne_inner[entry_index - 1]);
        assign lq_ptr_issue_ne_inner[entry_index]       = valid_issue_ne_inner[entry_index - 1] ? lq_ptr_issue_ne_inner[entry_index - 1] : entry_index;

        assign valid_commit_eq_inner[entry_index]       = (commit_valid | valid_commit_eq_inner[entry_index - 1]);
        assign lq_ptr_commit_eq_inner[entry_index]      = valid_commit_eq_inner[entry_index - 1] ? lq_ptr_commit_eq_inner[entry_index - 1] : entry_index;
        assign valid_commit_ne_inner[entry_index]       = ((commit_valid & (entry_index >= lq_r_ptr[LQ_entry_w - 1 : 0])) | valid_commit_ne_inner[entry_index - 1]);
        assign lq_ptr_commit_ne_inner[entry_index]      = valid_commit_ne_inner[entry_index - 1] ? lq_ptr_commit_ne_inner[entry_index - 1] : entry_index;

        assign lq_ptr_r_ptr_step_inner[entry_index]     = valid_r_ptr_step_inner[entry_index - 1] ? (lq_ptr_r_ptr_step_inner[entry_index - 1] + 1) : lq_ptr_r_ptr_step_inner[entry_index - 1];
    end
end
endgenerate

genvar resp_index;
generate for(resp_index = 0 ; resp_index < rename_width; resp_index = resp_index + 1) begin : U_gen_lq_resp
    if(resp_index == 0)begin : U_gen_lq_resp_0
        assign lq_resp_inner[resp_index].valid     = ((lq_ptr_resp[resp_index][LQ_entry_w] == lq_r_ptr[LQ_entry_w]) |
                                                    (lq_ptr_resp[resp_index][LQ_entry_w - 1 : 0] != lq_r_ptr[LQ_entry_w - 1 : 0]));
        assign lq_ptr_resp[resp_index]             = lq_w_ptr;
    end
    else begin : U_gen_lq_resp_other
        assign lq_resp_inner[resp_index].valid     = ((lq_ptr_resp[resp_index][LQ_entry_w] == lq_r_ptr[LQ_entry_w]) |
                                                    (lq_ptr_resp[resp_index][LQ_entry_w - 1 : 0] != lq_r_ptr[LQ_entry_w - 1 : 0]));
        assign lq_ptr_resp[resp_index]             = (lq_resp_inner[resp_index - 1].valid & lq_req[resp_index - 1] ) ? (lq_ptr_resp[resp_index - 1] + 1) : lq_ptr_resp[resp_index - 1];
    end
    assign lq_ptr_enq[resp_index]              = lq_ptr_resp[resp_index][LQ_entry_w - 1 : 0];
    assign lq_resp_inner[resp_index].lq_ptr    = lq_ptr_enq[resp_index];
end
endgenerate
assign lq_resp = lq_resp_inner;

assign lq_entry_loadaddr_use    = lq_entry[loadUnit_lq_ptr_query];
assign loadUnit_op_query        = lq_entry_loadaddr_use.op;

assign loadUnit_ready_o         = 1'b1;

assign lq_entry_issue_use       = lq_entry[lq_ptr_issue];
assign LoadQueue_arvalid        = valid_issue;
assign LoadQueue_arsize         = `load_size(lq_entry_issue_use.op);
assign LoadQueue_araddr         = lq_entry_issue_use.mem_paddr;
assign LoadQueue_rob_ptr        = lq_entry_issue_use.rob_ptr;
assign LoadQueue_lq_ptr         = lq_ptr_issue;

assign LoadQueue_enq_lqRAW_o    = (LoadQueue_arvalid & LoadQueue_arready);
assign LoadQueue_raddr_o        = lq_entry_issue_use.mem_paddr;
assign LoadQueue_rsize_o        = `load_size(lq_entry_issue_use.op);
assign LoadQueue_enq_rob_ptr_o  = lq_entry_issue_use.rob_ptr;

assign LoadQueue_rready = LoadQueue_ready_o;

logic [63:0] load_data;
memory_load_move u_memory_load_move(
    .pre_data    	( LoadQueue_rdata                     ),
    .data_offset 	( lq_entry_commit_use.mem_paddr[2:0]  ),
    .is_byte     	( `load_byte  (lq_entry_commit_use.op)),
    .is_half     	( `load_half  (lq_entry_commit_use.op)),
    .is_word     	( `load_word  (lq_entry_commit_use.op)),
    .is_double   	( `load_double(lq_entry_commit_use.op)),
    .is_sign     	( `load_signed(lq_entry_commit_use.op)),
    .data        	( load_data                           )
);

assign lq_entry_commit_use          = lq_entry[lq_ptr_report];
assign LoadQueue_valid_o            = (LoadQueue_rvalid | valid_commit);
assign LoadQueue_addr_misalign_o    = lq_entry_commit_use.addr_misalign;
assign LoadQueue_page_error_o       = lq_entry_commit_use.page_error   ;
assign LoadQueue_load_error_o       = LoadQueue_rvalid ? (LoadQueue_rresp != 2'h0) : 1'b0;
assign LoadQueue_rfwen_o            = (lq_entry_commit_use.rfwen & (LoadQueue_rvalid ? 
                                    (!(LoadQueue_addr_misalign_o | LoadQueue_page_error_o | LoadQueue_load_error_o)) : 1'b0));
assign LoadQueue_pwdest_o           = lq_entry_commit_use.pwdest                        ;
assign LoadQueue_preg_wdata_o       = load_data                                         ;
assign LoadQueue_rob_ptr_o          = lq_entry_commit_use.rob_ptr[rob_entry_w - 1 : 0]  ;
assign LoadQueue_vaddr_o            = lq_entry_commit_use.mem_vaddr                     ;

endmodule //LoadQueue
