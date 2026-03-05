module iq_need_pc
import decode_pkg::*;
import regfile_pkg::*;
import dispatch_pkg::*;
import iq_pkg::*;
import core_setting_pkg::*;
(
    input                                               clk,
    input                                               rst_n,

    input                                               redirect,

    output [IQ_W - 1 : 0]                               iq_enq_num,

    input                                               in_valid,
    output                                              in_ready,
    input  iq_need_pc_in_t                              in,

    input                [wb_width - 1 : 0]             rfwen,
    input  pint_regdest_t[wb_width - 1 : 0]             pwdest,

    // alu
    output                                              out1_valid,
    input                                               out1_ready,
    output  iq_acc_out_t                                out1,

    // bru
    output                                              out2_valid,
    input                                               out2_ready,
    output  iq_bru_out_t                                out2,

    // jump
    output                                              out3_valid,
    input                                               out3_ready,
    output  iq_jump_out_t                               out3
);

logic             [IQ_NUM - 1 : 0] issue_queue_valid;
iq_need_pc_entry_t[IQ_NUM - 1 : 0] issue_queue;

logic         [IQ_NUM - 1 : 0] iq_can_enq;
iq_ptr_t      [IQ_NUM - 1 : 0] iq_can_enq_ptr;
iq_need_pc_entry_t             issue_queue_enq;
logic                          issue_queue_enq_valid;
iq_ptr_t                       issue_queue_enq_ptr;

/* verilator lint_off UNUSEDSIGNAL */
iq_need_pc_entry_t             issue_queue_alu;
iq_ptr_t                       issue_queue_alu_ptr;
logic         [IQ_NUM - 1 : 0] iq_can_issue_alu;
logic         [IQ_NUM - 1 : 0] iq_can_issue_alu_valid;
iq_ptr_t      [IQ_NUM - 1 : 0] iq_can_issue_alu_ptr;
iq_need_pc_entry_t             issue_queue_bru;
iq_ptr_t                       issue_queue_bru_ptr;
logic         [IQ_NUM - 1 : 0] iq_can_issue_bru;
logic         [IQ_NUM - 1 : 0] iq_can_issue_bru_valid;
iq_ptr_t      [IQ_NUM - 1 : 0] iq_can_issue_bru_ptr;
iq_need_pc_entry_t             issue_queue_jump;
iq_ptr_t                       issue_queue_jump_ptr;
logic         [IQ_NUM - 1 : 0] iq_can_issue_jump;
logic         [IQ_NUM - 1 : 0] iq_can_issue_jump_valid;
iq_ptr_t      [IQ_NUM - 1 : 0] iq_can_issue_jump_ptr;
/* verilator lint_on UNUSEDSIGNAL */

assign issue_queue_enq.futype       = in.futype     ;
assign issue_queue_enq.fuoptype     = in.fuoptype   ;
assign issue_queue_enq.psrc1        = in.psrc1      ;
assign issue_queue_enq.src1_type    = in.src1_type  ;
assign issue_queue_enq.src1_status  = in.src1_status;
assign issue_queue_enq.psrc2        = in.psrc2      ;
assign issue_queue_enq.src2_type    = in.src2_type  ;
assign issue_queue_enq.src2_status  = in.src2_status;
assign issue_queue_enq.rfwen        = in.rfwen      ;
assign issue_queue_enq.pwdest       = in.pwdest     ;
assign issue_queue_enq.imm          = in.imm        ;
assign issue_queue_enq.rob_ptr      = in.rob_ptr    ;
assign issue_queue_enq.rvc_flag     = in.rvc_flag   ;
assign issue_queue_enq.end_flag     = in.end_flag   ;
assign issue_queue_enq.ftq_ptr      = in.ftq_ptr    ;
assign issue_queue_enq.inst_offset  = in.inst_offset;

logic iq_enq_num_inc;
logic iq_enq_num_dec_alu;
logic iq_enq_num_dec_bru;
logic iq_enq_num_dec_jmp;
assign iq_enq_num_inc           = in_valid & in_ready;
assign iq_enq_num_dec_alu       = out1_valid & out1_ready;
assign iq_enq_num_dec_bru       = out2_valid & out2_ready;
assign iq_enq_num_dec_jmp       = out3_valid & out3_ready;

logic                   iq_enq_num_wen;
logic [IQ_W - 1 : 0]    iq_enq_num_nxt;
assign iq_enq_num_wen           = (iq_enq_num_inc |  iq_enq_num_dec_alu | iq_enq_num_dec_bru | iq_enq_num_dec_jmp);
assign iq_enq_num_nxt           = (iq_enq_num + {{(IQ_W - 1){1'b0}}, iq_enq_num_inc} - {{(IQ_W - 1){1'b0}}, iq_enq_num_dec_alu} - 
                                    {{(IQ_W - 1){1'b0}}, iq_enq_num_dec_bru} - {{(IQ_W - 1){1'b0}}, iq_enq_num_dec_jmp});
FF_D_with_syn_rst #(
    .DATA_LEN 	( IQ_W  ),
    .RST_DATA 	( 0     )
)u_iq_enq_num
(
    .clk        ( clk              ),
    .rst_n      ( rst_n            ),
    .syn_rst    ( redirect         ),
    .wen        ( iq_enq_num_wen   ),
    .data_in    ( iq_enq_num_nxt   ),
    .data_out   ( iq_enq_num       )
);

genvar iq_index;
generate for(iq_index = 0 ; iq_index < IQ_NUM; iq_index = iq_index + 1) begin : U_gen_issue_queue 
    assign iq_can_issue_alu [iq_index] = issue_queue_valid[iq_index] & (issue_queue[iq_index].futype == fu_alu) & 
                                        (issue_queue[iq_index].src1_status == reg_status_fire) & (issue_queue[iq_index].src2_status == reg_status_fire);
    assign iq_can_issue_bru [iq_index] = issue_queue_valid[iq_index] & (issue_queue[iq_index].futype == fu_bru) & 
                                        (issue_queue[iq_index].src1_status == reg_status_fire) & (issue_queue[iq_index].src2_status == reg_status_fire);
    assign iq_can_issue_jump[iq_index] = issue_queue_valid[iq_index] & (issue_queue[iq_index].futype == fu_jump) & 
                                        (issue_queue[iq_index].src1_status == reg_status_fire) & (issue_queue[iq_index].src2_status == reg_status_fire);
    if(iq_index == 0)begin : u_gen_iq_ptr_0
        assign iq_can_issue_alu_valid [iq_index] = iq_can_issue_alu [iq_index];
        assign iq_can_issue_alu_ptr   [iq_index] = iq_index;
        assign iq_can_issue_bru_valid [iq_index] = iq_can_issue_bru [iq_index];
        assign iq_can_issue_bru_ptr   [iq_index] = iq_index;
        assign iq_can_issue_jump_valid[iq_index] = iq_can_issue_jump[iq_index];
        assign iq_can_issue_jump_ptr  [iq_index] = iq_index;
    end
    else begin : u_gen_iq_ptr_another
        //! TODO 现在采用序号越小的优先级越高，以后可以改为年龄比较
        assign iq_can_issue_alu_valid [iq_index] = (iq_can_issue_alu     [iq_index] | iq_can_issue_alu_valid     [iq_index - 1]);
        assign iq_can_issue_alu_ptr   [iq_index] = (iq_can_issue_alu_valid     [iq_index - 1]) ? iq_can_issue_alu_ptr    [iq_index - 1] : iq_index;
        assign iq_can_issue_bru_valid [iq_index] = (iq_can_issue_bru [iq_index] | iq_can_issue_bru_valid [iq_index - 1]);
        assign iq_can_issue_bru_ptr   [iq_index] = (iq_can_issue_bru_valid [iq_index - 1]) ? iq_can_issue_bru_ptr[iq_index - 1] : iq_index;
        assign iq_can_issue_jump_valid[iq_index] = (iq_can_issue_jump [iq_index] | iq_can_issue_jump_valid [iq_index - 1]);
        assign iq_can_issue_jump_ptr  [iq_index] = (iq_can_issue_jump_valid [iq_index - 1]) ? iq_can_issue_jump_ptr[iq_index - 1] : iq_index;
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
    logic dequeue_alu;
    logic dequeue_bru;
    logic dequeue_jump;
    assign enqueue          = in_valid & in_ready & (iq_index == issue_queue_enq_ptr);
    assign dequeue          = (dequeue_alu | dequeue_bru | dequeue_jump);
    assign dequeue_alu      = out1_valid & out1_ready & (iq_index == issue_queue_alu_ptr);
    assign dequeue_bru      = out2_valid & out2_ready & (iq_index == issue_queue_bru_ptr);
    assign dequeue_jump     = out3_valid & out3_ready & (iq_index == issue_queue_jump_ptr);
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
    iq_need_pc_entry_t             issue_queue_src1_fire_entry;
    logic                          issue_queue_src2_fire;
    iq_need_pc_entry_t             issue_queue_src2_fire_entry;
    logic                          issue_queue_entry_wen;
    iq_need_pc_entry_t             issue_queue_entry_nxt;

    iq_src_monitor u_issue_queue_src1_fire(issue_queue_valid[iq_index], issue_queue[iq_index].psrc1, rfwen, pwdest, issue_queue_src1_fire);
    assign issue_queue_src1_fire_entry.futype       = issue_queue[iq_index].futype      ;
    assign issue_queue_src1_fire_entry.fuoptype     = issue_queue[iq_index].fuoptype    ;
    assign issue_queue_src1_fire_entry.psrc1        = issue_queue[iq_index].psrc1       ;
    assign issue_queue_src1_fire_entry.src1_type    = issue_queue[iq_index].src1_type   ;
    assign issue_queue_src1_fire_entry.src1_status  = reg_status_fire                   ;
    assign issue_queue_src1_fire_entry.psrc2        = issue_queue[iq_index].psrc2       ;
    assign issue_queue_src1_fire_entry.src2_type    = issue_queue[iq_index].src2_type   ;
    assign issue_queue_src1_fire_entry.src2_status  = issue_queue[iq_index].src2_status ;
    assign issue_queue_src1_fire_entry.rfwen        = issue_queue[iq_index].rfwen       ;
    assign issue_queue_src1_fire_entry.pwdest       = issue_queue[iq_index].pwdest      ;
    assign issue_queue_src1_fire_entry.imm          = issue_queue[iq_index].imm         ;
    assign issue_queue_src1_fire_entry.rob_ptr      = issue_queue[iq_index].rob_ptr     ;
    assign issue_queue_src1_fire_entry.rvc_flag     = issue_queue[iq_index].rvc_flag    ;
    assign issue_queue_src1_fire_entry.end_flag     = issue_queue[iq_index].end_flag    ;
    assign issue_queue_src1_fire_entry.ftq_ptr      = issue_queue[iq_index].ftq_ptr     ;
    assign issue_queue_src1_fire_entry.inst_offset  = issue_queue[iq_index].inst_offset ;

    iq_src_monitor u_issue_queue_src2_fire(issue_queue_valid[iq_index], issue_queue[iq_index].psrc2, rfwen, pwdest, issue_queue_src2_fire);
    assign issue_queue_src2_fire_entry.futype       = issue_queue[iq_index].futype      ;
    assign issue_queue_src2_fire_entry.fuoptype     = issue_queue[iq_index].fuoptype    ;
    assign issue_queue_src2_fire_entry.psrc1        = issue_queue[iq_index].psrc1       ;
    assign issue_queue_src2_fire_entry.src1_type    = issue_queue[iq_index].src1_type   ;
    assign issue_queue_src2_fire_entry.src1_status  = issue_queue[iq_index].src1_status ;
    assign issue_queue_src2_fire_entry.psrc2        = issue_queue[iq_index].psrc2       ;
    assign issue_queue_src2_fire_entry.src2_type    = issue_queue[iq_index].src2_type   ;
    assign issue_queue_src2_fire_entry.src2_status  = reg_status_fire                   ;
    assign issue_queue_src2_fire_entry.rfwen        = issue_queue[iq_index].rfwen       ;
    assign issue_queue_src2_fire_entry.pwdest       = issue_queue[iq_index].pwdest      ;
    assign issue_queue_src2_fire_entry.imm          = issue_queue[iq_index].imm         ;
    assign issue_queue_src2_fire_entry.rob_ptr      = issue_queue[iq_index].rob_ptr     ;
    assign issue_queue_src2_fire_entry.rvc_flag     = issue_queue[iq_index].rvc_flag    ;
    assign issue_queue_src2_fire_entry.end_flag     = issue_queue[iq_index].end_flag    ;
    assign issue_queue_src2_fire_entry.ftq_ptr      = issue_queue[iq_index].ftq_ptr     ;
    assign issue_queue_src2_fire_entry.inst_offset  = issue_queue[iq_index].inst_offset ;

    assign issue_queue_entry_wen = (enqueue | issue_queue_src1_fire | issue_queue_src2_fire);
    assign issue_queue_entry_nxt =  ({IQ_NEED_PC_ENTRY_W{enqueue                }} & issue_queue_enq            ) | 
                                    ({IQ_NEED_PC_ENTRY_W{issue_queue_src1_fire  }} & issue_queue_src1_fire_entry) | 
                                    ({IQ_NEED_PC_ENTRY_W{issue_queue_src2_fire  }} & issue_queue_src2_fire_entry);
    FF_D_without_asyn_rst #(IQ_NEED_PC_ENTRY_W)u_entry     (clk,issue_queue_entry_wen, issue_queue_entry_nxt, issue_queue[iq_index]);
end
endgenerate

assign issue_queue_enq_valid    = iq_can_enq[IQ_NUM - 1];
assign issue_queue_enq_ptr      = iq_can_enq_ptr[IQ_NUM - 1];

assign in_ready                 = issue_queue_enq_valid;

assign issue_queue_alu_ptr      = iq_can_issue_alu_ptr[IQ_NUM - 1];
assign issue_queue_bru_ptr      = iq_can_issue_bru_ptr[IQ_NUM - 1];
assign issue_queue_jump_ptr     = iq_can_issue_jump_ptr[IQ_NUM - 1];

assign issue_queue_alu          = issue_queue[issue_queue_alu_ptr];
assign issue_queue_bru          = issue_queue[issue_queue_bru_ptr];
assign issue_queue_jump         = issue_queue[issue_queue_jump_ptr];

assign out1_valid               = iq_can_issue_alu_valid[IQ_NUM - 1];
assign out1.fuoptype            = issue_queue_alu.fuoptype      ;
assign out1.psrc1               = issue_queue_alu.psrc1         ;
assign out1.src1_type           = issue_queue_alu.src1_type     ;
assign out1.psrc2               = issue_queue_alu.psrc2         ;
assign out1.src2_type           = issue_queue_alu.src2_type     ;
assign out1.pwdest              = issue_queue_alu.pwdest        ;
assign out1.imm                 = issue_queue_alu.imm           ;
assign out1.rob_ptr             = issue_queue_alu.rob_ptr       ;

assign out2_valid               = iq_can_issue_bru_valid[IQ_NUM - 1];
assign out2.fuoptype            = issue_queue_bru.fuoptype      ;
assign out2.psrc1               = issue_queue_bru.psrc1         ;
assign out2.src1_type           = issue_queue_bru.src1_type     ;
assign out2.psrc2               = issue_queue_bru.psrc2         ;
assign out2.src2_type           = issue_queue_bru.src2_type     ;
assign out2.imm                 = issue_queue_bru.imm           ;
assign out2.rob_ptr             = issue_queue_bru.rob_ptr       ;
assign out2.rvc_flag            = issue_queue_bru.rvc_flag      ;
assign out2.end_flag            = issue_queue_bru.end_flag      ;
assign out2.ftq_ptr             = issue_queue_bru.ftq_ptr       ;
assign out2.inst_offset         = issue_queue_bru.inst_offset   ;

assign out3_valid               = iq_can_issue_jump_valid[IQ_NUM - 1];
assign out3.fuoptype            = issue_queue_jump.fuoptype      ;
assign out3.psrc1               = issue_queue_jump.psrc1         ;
assign out3.src1_type           = issue_queue_jump.src1_type     ;
assign out3.rfwen               = issue_queue_jump.rfwen         ;
assign out3.pwdest              = issue_queue_jump.pwdest        ;
assign out3.imm                 = issue_queue_jump.imm           ;
assign out3.rob_ptr             = issue_queue_jump.rob_ptr       ;
assign out3.rvc_flag            = issue_queue_jump.rvc_flag      ;
assign out3.ftq_ptr             = issue_queue_jump.ftq_ptr       ;
assign out3.inst_offset         = issue_queue_jump.inst_offset   ;

endmodule //iq_need_pc
