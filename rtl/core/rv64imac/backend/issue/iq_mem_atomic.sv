module iq_mem_atomic
import decode_pkg::*;
import regfile_pkg::*;
import dispatch_pkg::*;
import iq_pkg::*;
import rob_pkg::*;
import core_setting_pkg::*;
(
    input                                               clk,
    input                                               rst_n,

    input                                               redirect,

    input                                               in_valid,
    output                                              in_ready,
    input  iq_mem_atomic_in_t                           in,

    input  rob_entry_ptr_t                              top_rob_ptr,

    // atomic
    output                                              out1_valid,
    input                                               out1_ready,
    output  iq_mem_atomic_out_t                         out1
);

logic                   issue_queue_valid;
iq_mem_atomic_entry_t   issue_queue;

iq_mem_atomic_entry_t   issue_queue_enq;

assign issue_queue_enq.fuoptype     = in.fuoptype   ;
assign issue_queue_enq.psrc1        = in.psrc1      ;
assign issue_queue_enq.src1_type    = in.src1_type  ;
assign issue_queue_enq.psrc2        = in.psrc2      ;
assign issue_queue_enq.src2_type    = in.src2_type  ;
assign issue_queue_enq.imm          = in.imm        ;
assign issue_queue_enq.rfwen        = in.rfwen      ;
assign issue_queue_enq.pwdest       = in.pwdest     ;
assign issue_queue_enq.rob_ptr      = in.rob_ptr    ;

logic enqueue;
logic dequeue;
assign enqueue              = in_valid & in_ready;
assign dequeue              = (out1_valid & out1_ready);
FF_D_with_syn_rst #(
    .DATA_LEN 	( 1  ),
    .RST_DATA 	( 0  )
)u_issue_queue_valid
(
    .clk        ( clk                   ),
    .rst_n      ( rst_n                 ),
    .syn_rst    ( redirect              ),
    .wen        ( (enqueue |  dequeue  )),
    .data_in    ( (enqueue | (!dequeue))),
    .data_out   ( issue_queue_valid     )
);

FF_D_without_asyn_rst #(IQ_MEM_ATOMIC_ENTRY_W)u_entry     (clk,enqueue, issue_queue_enq, issue_queue);

assign in_ready                     = (!issue_queue_valid);

assign out1_valid                   = (issue_queue_valid & (issue_queue.rob_ptr == top_rob_ptr));
assign out1.fuoptype                = issue_queue.fuoptype ;
assign out1.psrc1                   = issue_queue.psrc1    ;
assign out1.src1_type               = issue_queue.src1_type;
assign out1.psrc2                   = issue_queue.psrc2    ;
assign out1.src2_type               = issue_queue.src2_type;
assign out1.imm                     = issue_queue.imm      ;
assign out1.rfwen                   = issue_queue.rfwen    ;
assign out1.pwdest                  = issue_queue.pwdest   ;
assign out1.rob_ptr                 = issue_queue.rob_ptr  ;

endmodule //iq_mem_atomic
