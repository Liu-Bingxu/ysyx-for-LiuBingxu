module iq_mem_store_data
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
    input  iq_mem_store_data_in_t                       in,

    input                [wb_width - 1 : 0]             rfwen,
    input  pint_regdest_t[wb_width - 1 : 0]             pwdest,

    // store_data
    output                                              out1_valid,
    input                                               out1_ready,
    output  iq_mem_store_data_out_t                     out1
);


logic                    [IQ_NUM - 1 : 0]   issue_queue_valid;
iq_mem_store_data_entry_t[IQ_NUM - 1 : 0]   issue_queue;

logic         [IQ_NUM - 1 : 0]              iq_can_enq;
iq_ptr_t      [IQ_NUM - 1 : 0]              iq_can_enq_ptr;
iq_mem_store_data_entry_t                   issue_queue_enq;
logic                                       issue_queue_enq_valid;
iq_ptr_t                                    issue_queue_enq_ptr;

/* verilator lint_off UNUSEDSIGNAL */
iq_mem_store_data_entry_t                   issue_queue_store_data;
iq_ptr_t                                    issue_queue_store_data_ptr;
logic         [IQ_NUM - 1 : 0]              iq_can_issue_store_data;
logic         [IQ_NUM - 1 : 0]              iq_can_issue_store_data_valid;
iq_ptr_t      [IQ_NUM - 1 : 0]              iq_can_issue_store_data_ptr;
/* verilator lint_on UNUSEDSIGNAL */

assign issue_queue_enq.psrc2        = in.psrc2      ;
assign issue_queue_enq.src2_type    = in.src2_type  ;
assign issue_queue_enq.src2_status  = in.src2_status;
assign issue_queue_enq.sq_ptr       = in.sq_ptr     ;

genvar iq_index;
generate for(iq_index = 0 ; iq_index < IQ_NUM; iq_index = iq_index + 1) begin : U_gen_issue_queue 
    assign iq_can_issue_store_data       [iq_index] = issue_queue_valid[iq_index] & (issue_queue[iq_index].src2_status == reg_status_fire);
    if(iq_index == 0)begin : u_gen_iq_ptr_0
        assign iq_can_issue_store_data_valid       [iq_index] = iq_can_issue_store_data       [iq_index];
        assign iq_can_issue_store_data_ptr         [iq_index] = iq_index;
    end
    else begin : u_gen_iq_ptr_anothers
        //! TODO 现在采用序号越小的优先级越高，以后可以改为年龄比较
        assign iq_can_issue_store_data_valid       [iq_index] = (iq_can_issue_store_data       [iq_index] | iq_can_issue_store_data_valid       [iq_index - 1]);
        assign iq_can_issue_store_data_ptr         [iq_index] = (iq_can_issue_store_data_valid       [iq_index - 1]) ? iq_can_issue_store_data_ptr      [iq_index - 1] : iq_index;
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
    logic dequeue_store_data;
    assign enqueue              = in_valid & in_ready & (iq_index == issue_queue_enq_ptr);
    assign dequeue              = (dequeue_store_data);
    assign dequeue_store_data   = out1_valid & out1_ready & (iq_index == issue_queue_store_data_ptr);
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
    logic                          issue_queue_src2_fire;
    iq_mem_store_data_entry_t      issue_queue_src2_fire_entry;
    logic                          issue_queue_entry_wen;
    iq_mem_store_data_entry_t      issue_queue_entry_nxt;

    iq_src_monitor u_issue_queue_src2_fire(issue_queue_valid[iq_index], issue_queue[iq_index].psrc2, rfwen, pwdest, issue_queue_src2_fire);
    assign issue_queue_src2_fire_entry.psrc2        = issue_queue[iq_index].psrc2       ;
    assign issue_queue_src2_fire_entry.src2_type    = issue_queue[iq_index].src2_type   ;
    assign issue_queue_src2_fire_entry.src2_status  = reg_status_fire                   ;
    assign issue_queue_src2_fire_entry.sq_ptr       = issue_queue[iq_index].sq_ptr      ;

    assign issue_queue_entry_wen = (enqueue | issue_queue_src2_fire);
    assign issue_queue_entry_nxt =  ({IQ_MEM_STORE_DATA_ENTRY_W{enqueue                }} & issue_queue_enq            ) | 
                                    ({IQ_MEM_STORE_DATA_ENTRY_W{issue_queue_src2_fire  }} & issue_queue_src2_fire_entry);
    FF_D_without_asyn_rst #(IQ_MEM_STORE_DATA_ENTRY_W)u_entry     (clk,issue_queue_entry_wen, issue_queue_entry_nxt, issue_queue[iq_index]);
end
endgenerate

assign issue_queue_enq_valid        = iq_can_enq[IQ_NUM - 1];
assign issue_queue_enq_ptr          = iq_can_enq_ptr[IQ_NUM - 1];

assign in_ready                     = issue_queue_enq_valid;

assign issue_queue_store_data_ptr   = iq_can_issue_store_data_ptr[IQ_NUM - 1];

assign issue_queue_store_data      = issue_queue[issue_queue_store_data_ptr];

assign out1_valid                   = iq_can_issue_store_data_valid[IQ_NUM - 1];
assign out1.psrc2                   = issue_queue_store_data.psrc2    ;
assign out1.src2_type               = issue_queue_store_data.src2_type;
assign out1.sq_ptr                  = issue_queue_store_data.sq_ptr   ;

endmodule //iq_mem_store_data
