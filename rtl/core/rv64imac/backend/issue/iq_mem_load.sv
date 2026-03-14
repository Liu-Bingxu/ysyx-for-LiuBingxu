module iq_mem_load
import decode_pkg::*;
import regfile_pkg::*;
import dispatch_pkg::*;
import iq_pkg::*;
import core_setting_pkg::*;
(
    input                                               clk,
    input                                               rst_n,

    input                                               redirect,

    input                                               in_valid,
    output                                              in_ready,
    input  iq_mem_load_in_t                             in,

    input                [wb_width - 1 : 0]             rfwen,
    input  pint_regdest_t[wb_width - 1 : 0]             pwdest,

    // load
    output                                              out1_valid,
    input                                               out1_ready,
    output  iq_mem_load_out_t                           out1
);


logic              [IQ_NUM - 1 : 0]  issue_queue_valid;
iq_mem_load_entry_t[IQ_NUM - 1 : 0]  issue_queue;

logic         [IQ_NUM - 1 : 0]       iq_can_enq;
iq_ptr_t      [IQ_NUM - 1 : 0]       iq_can_enq_ptr;
iq_mem_load_entry_t                  issue_queue_enq;
logic                                issue_queue_enq_valid;
iq_ptr_t                             issue_queue_enq_ptr;

/* verilator lint_off UNUSEDSIGNAL */
iq_mem_load_entry_t                  issue_queue_load;
iq_ptr_t                             issue_queue_load_ptr;
logic         [IQ_NUM - 1 : 0]       iq_can_issue_load;
logic         [IQ_NUM - 1 : 0]       iq_can_issue_load_valid;
iq_ptr_t      [IQ_NUM - 1 : 0]       iq_can_issue_load_ptr;
/* verilator lint_on UNUSEDSIGNAL */

assign issue_queue_enq.psrc1        = in.psrc1      ;
assign issue_queue_enq.src1_type    = in.src1_type  ;
assign issue_queue_enq.src1_status  = in.src1_status;
assign issue_queue_enq.imm          = in.imm        ;
assign issue_queue_enq.lq_ptr       = in.lq_ptr     ;

genvar iq_index;
generate for(iq_index = 0 ; iq_index < IQ_NUM; iq_index = iq_index + 1) begin : U_gen_issue_queue 
    assign iq_can_issue_load       [iq_index] = issue_queue_valid[iq_index] & (issue_queue[iq_index].src1_status == reg_status_fire);
    if(iq_index == 0)begin : u_gen_iq_ptr_0
        assign iq_can_issue_load_valid       [iq_index] = iq_can_issue_load       [iq_index];
        assign iq_can_issue_load_ptr         [iq_index] = iq_index;
    end
    else begin : u_gen_iq_ptr_another
        //! TODO 现在采用序号越小的优先级越高，以后可以改为年龄比较
        assign iq_can_issue_load_valid       [iq_index] = (iq_can_issue_load       [iq_index] | iq_can_issue_load_valid       [iq_index - 1]);
        assign iq_can_issue_load_ptr         [iq_index] = (iq_can_issue_load_valid       [iq_index - 1]) ? iq_can_issue_load_ptr      [iq_index - 1] : iq_index;
    end

    if(iq_index == 0)begin : u_gen_enq
        assign iq_can_enq    [iq_index] = (!issue_queue_valid[iq_index]);
        assign iq_can_enq_ptr[iq_index] = iq_index;
    end
    else begin : u_gen_enq
        assign iq_can_enq    [iq_index] = ((!issue_queue_valid[iq_index]) | iq_can_enq[iq_index - 1]);
        assign iq_can_enq_ptr[iq_index] = iq_can_enq[iq_index - 1] ? iq_can_enq_ptr[iq_index - 1] : iq_index;
    end
    logic enqueue;
    logic dequeue;
    logic dequeue_load;
    assign enqueue              = in_valid & in_ready & (iq_index == issue_queue_enq_ptr);
    assign dequeue              = (dequeue_load);
    assign dequeue_load         = out1_valid & out1_ready & (iq_index == issue_queue_load_ptr);
    FF_D_with_syn_rst #(
        .DATA_LEN 	( 1  ),
        .RST_DATA 	( 0  )
    )u_issue_queue_valid
    (
        .clk        ( clk                           ),
        .rst_n      ( rst_n                         ),
        .syn_rst    ( redirect                      ),
        .wen        ( (enqueue |  dequeue  )        ),
        .data_in    ( (enqueue | (!dequeue))        ),
        .data_out   ( issue_queue_valid[iq_index]   )
    );
    logic                          issue_queue_src1_fire;
    iq_mem_load_entry_t            issue_queue_src1_fire_entry;
    logic                          issue_queue_entry_wen;
    iq_mem_load_entry_t            issue_queue_entry_nxt;

    iq_src_monitor u_issue_queue_src1_fire(issue_queue_valid[iq_index], issue_queue[iq_index].psrc1, rfwen, pwdest, issue_queue_src1_fire);
    assign issue_queue_src1_fire_entry.psrc1        = issue_queue[iq_index].psrc1       ;
    assign issue_queue_src1_fire_entry.src1_type    = issue_queue[iq_index].src1_type   ;
    assign issue_queue_src1_fire_entry.src1_status  = reg_status_fire                   ;
    assign issue_queue_src1_fire_entry.imm          = issue_queue[iq_index].imm         ;
    assign issue_queue_src1_fire_entry.lq_ptr       = issue_queue[iq_index].lq_ptr      ;

    assign issue_queue_entry_wen = (enqueue | issue_queue_src1_fire);
    assign issue_queue_entry_nxt =  ({IQ_MEM_LOAD_ENTRY_W{enqueue                }} & issue_queue_enq            ) | 
                                    ({IQ_MEM_LOAD_ENTRY_W{issue_queue_src1_fire  }} & issue_queue_src1_fire_entry);
    FF_D_without_asyn_rst #(IQ_MEM_LOAD_ENTRY_W)u_entry     (clk,issue_queue_entry_wen, issue_queue_entry_nxt, issue_queue[iq_index]);
end
endgenerate

assign issue_queue_enq_valid        = iq_can_enq[IQ_NUM - 1];
assign issue_queue_enq_ptr          = iq_can_enq_ptr[IQ_NUM - 1];

assign in_ready                     = issue_queue_enq_valid;

assign issue_queue_load_ptr         = iq_can_issue_load_ptr[IQ_NUM - 1];

assign issue_queue_load             = issue_queue[issue_queue_load_ptr];

assign out1_valid                   = iq_can_issue_load_valid[IQ_NUM - 1];
assign out1.psrc1                   = issue_queue_load.psrc1    ;
assign out1.src1_type               = issue_queue_load.src1_type;
assign out1.imm                     = issue_queue_load.imm      ;
assign out1.lq_ptr                  = issue_queue_load.lq_ptr   ;

endmodule //iq_mem_load
