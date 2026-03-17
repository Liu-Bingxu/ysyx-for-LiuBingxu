module LoadQueueRAW
import rob_pkg::*;
import lsq_pkg::*;
import mem_pkg::*;
import core_setting_pkg::*;
(
    input                                               clk,
    input                                               rst_n,

    input                                               redirect,

    input  ls_rob_entry_ptr_t                           deq_rob_ptr,
    input  [commit_width - 1 : 0]                       rob_commit_instret,

    input                                               LoadQueue_enq_lqRAW_o,
    input  [63:0]                                       LoadQueue_raddr_o,
    input  [2:0]                                        LoadQueue_rsize_o,
    input  ls_rob_entry_ptr_t                           LoadQueue_enq_rob_ptr_o,

    input                                               storeaddrUnit_check_RAW_o,
    input  [63:0]                                       storeaddrUnit_waddr_o,
    input  [2:0]                                        storeaddrUnit_wsize_o,
    input  ls_rob_entry_ptr_t                           storeaddrUnit_rob_ptr_o,

    output                                              LoadQueueRAW_flush_o,
    output rob_entry_ptr_t                              LoadQueueRAW_rob_ptr_o
);

logic          [LQRAW_entry_num - 1 : 0]     loadqueue_valid;
lq_RAW_entry_t [LQRAW_entry_num - 1 : 0]     loadqueue;

logic              [LQRAW_entry_num - 1 : 0] loadqueue_flush_valid;
ls_rob_entry_ptr_t [LQRAW_entry_num - 1 : 0] loadqueueRAW_flush_rob_ptr/* verilator split_var */;

LQRAW_entry_ptr_t                            enq_ptr;
logic              [LQRAW_entry_num - 2 : 0] lq_enq_valid/* verilator split_var */;
LQRAW_entry_ptr_t  [LQRAW_entry_num - 1 : 0] lq_enq_ptr/* verilator split_var */;

assign enq_ptr = lq_enq_ptr[LQRAW_entry_num - 1];

lq_RAW_entry_t enq_loadqueue;
assign enq_loadqueue.loadUnit_raddr_o      = LoadQueue_raddr_o       ;
assign enq_loadqueue.loadUnit_rsize_o      = LoadQueue_rsize_o       ;
assign enq_loadqueue.loadUnit_rob_ptr_o    = LoadQueue_enq_rob_ptr_o ;

logic               reg_storeaddrUnit_check_RAW_o;
logic [63:0]        reg_storeaddrUnit_waddr_o    ;
logic [2:0]         reg_storeaddrUnit_wsize_o    ;
ls_rob_entry_ptr_t  reg_storeaddrUnit_rob_ptr_o  ;

FF_D_with_syn_rst #(
    .DATA_LEN 	( 1  ),
    .RST_DATA 	( 0  )
)u_storeaddrUnit_check_RAW_o
(
    .clk        ( clk                           ),
    .rst_n      ( rst_n                         ),
    .syn_rst    ( redirect                      ),
    .wen        ( 1'b1                          ),
    .data_in    ( storeaddrUnit_check_RAW_o     ),
    .data_out   ( reg_storeaddrUnit_check_RAW_o )
);
FF_D_without_asyn_rst #(64)              u_storeaddrUnit_waddr_o         (clk, 1'b1, storeaddrUnit_waddr_o                  , reg_storeaddrUnit_waddr_o    );
FF_D_without_asyn_rst #(3)               u_storeaddrUnit_wsize_o         (clk, 1'b1, storeaddrUnit_wsize_o                  , reg_storeaddrUnit_wsize_o    );
FF_D_without_asyn_rst #(rob_entry_w + 1) u_storeaddrUnit_sq_ptr_o        (clk, 1'b1, storeaddrUnit_rob_ptr_o                , reg_storeaddrUnit_rob_ptr_o  );

logic [7:0] byte_wstrb,half_wstrb,word_wstrb,double_wstrb;
logic [7:0] store_wmask;
always @(*) begin
    case (reg_storeaddrUnit_waddr_o[2:0])
        3'b000: byte_wstrb=8'b00000001;
        3'b001: byte_wstrb=8'b00000010;
        3'b010: byte_wstrb=8'b00000100;
        3'b011: byte_wstrb=8'b00001000;
        3'b100: byte_wstrb=8'b00010000;
        3'b101: byte_wstrb=8'b00100000;
        3'b110: byte_wstrb=8'b01000000;
        3'b111: byte_wstrb=8'b10000000;
        default: byte_wstrb=8'b00000000;
    endcase
end
always @(*) begin
    case (reg_storeaddrUnit_waddr_o[2:0])
        3'b000: half_wstrb=8'b00000011;
        3'b010: half_wstrb=8'b00001100;
        3'b100: half_wstrb=8'b00110000;
        3'b110: half_wstrb=8'b11000000;
        default: half_wstrb=8'b00000000;
    endcase
end
always @(*) begin
    case (reg_storeaddrUnit_waddr_o[2:0])
        3'b000: word_wstrb=8'b00001111;
        3'b100: word_wstrb=8'b11110000;
        default: word_wstrb=8'b00000000;
    endcase
end
always @(*) begin
    case (reg_storeaddrUnit_waddr_o[2:0])
        3'b000: double_wstrb=8'b11111111;
        default: double_wstrb=8'b00000000;
    endcase
end

assign store_wmask          = 8'h0 |
                            ({8{(reg_storeaddrUnit_wsize_o == 3'h0)}} & byte_wstrb   ) | 
                            ({8{(reg_storeaddrUnit_wsize_o == 3'h1)}} & half_wstrb   ) |
                            ({8{(reg_storeaddrUnit_wsize_o == 3'h2)}} & word_wstrb   ) |
                            ({8{(reg_storeaddrUnit_wsize_o == 3'h3)}} & double_wstrb ) ;

genvar entry_index;
generate for(entry_index = 0 ; entry_index < LQRAW_entry_num; entry_index = entry_index + 1) begin : U_load_queue
    logic enqueue;
    assign enqueue              = LoadQueue_enq_lqRAW_o & (entry_index == enq_ptr);
    logic dequeue;
    lq_entry_t  send_ptr;
    /* verilator lint_off UNUSEDSIGNAL */
    lq_entry_t  DontCare;
    /* verilator lint_on UNUSEDSIGNAL */
    assign send_ptr.rob_ptr           = loadqueue[entry_index].loadUnit_rob_ptr_o;
    assign send_ptr.op                = op_lb;
    assign send_ptr.rfwen             = 0;
    assign send_ptr.pwdest            = 0;
    assign send_ptr.lq_entry_status   = lq_send_rob;
    assign send_ptr.addr_misalign     = 0;
    assign send_ptr.page_error        = 0;
    assign send_ptr.mem_paddr         = 0;
    assign send_ptr.mem_vaddr         = 0;
    always_comb begin
        Load_commit_judge(
            deq_rob_ptr[rob_entry_w - 1 : 0],
            rob_commit_instret,
            send_ptr,
            dequeue,
            DontCare
        );
    end
    FF_D_with_syn_rst #(
        .DATA_LEN 	( 1  ),
        .RST_DATA 	( 0  )
    )u_queue_valid
    (
        .clk        ( clk                           ),
        .rst_n      ( rst_n                         ),
        .syn_rst    ( redirect                      ),
        .wen        ( enqueue | dequeue             ),
        .data_in    ( enqueue | (!dequeue)          ),
        .data_out   ( loadqueue_valid[entry_index]  )
    );
    FF_D_without_asyn_rst #(68 + rob_entry_w) u_entry     (clk,enqueue, enq_loadqueue, loadqueue[entry_index]);

    if(entry_index == 0)begin: U_gen_enq_sel_0
        assign lq_enq_valid[entry_index] = (!loadqueue_valid[entry_index]);
        assign lq_enq_ptr[entry_index]   = entry_index;
    end
    else if(entry_index == (LQRAW_entry_num - 1))begin: U_gen_enq_sel_last
        assign lq_enq_ptr[entry_index]   = (lq_enq_valid[entry_index - 1]) ? lq_enq_ptr[entry_index - 1] : entry_index;
    end
    else begin: U_gen_enq_sel_another
        assign lq_enq_valid[entry_index] = ((!loadqueue_valid[entry_index]) | lq_enq_valid[entry_index - 1]);
        assign lq_enq_ptr[entry_index]   = (lq_enq_valid[entry_index - 1]) ? lq_enq_ptr[entry_index - 1] : entry_index;
    end

    logic [7:0] load_byte_wstrb,load_half_wstrb,load_word_wstrb,load_double_wstrb;
    logic [7:0] load_rmask;
    always @(*) begin
        case (loadqueue[entry_index].loadUnit_raddr_o[2:0])
            3'b000: load_byte_wstrb=8'b00000001;
            3'b001: load_byte_wstrb=8'b00000010;
            3'b010: load_byte_wstrb=8'b00000100;
            3'b011: load_byte_wstrb=8'b00001000;
            3'b100: load_byte_wstrb=8'b00010000;
            3'b101: load_byte_wstrb=8'b00100000;
            3'b110: load_byte_wstrb=8'b01000000;
            3'b111: load_byte_wstrb=8'b10000000;
            default: load_byte_wstrb=8'b00000000;
        endcase
    end
    always @(*) begin
        case (loadqueue[entry_index].loadUnit_raddr_o[2:0])
            3'b000: load_half_wstrb=8'b00000011;
            3'b010: load_half_wstrb=8'b00001100;
            3'b100: load_half_wstrb=8'b00110000;
            3'b110: load_half_wstrb=8'b11000000;
            default: load_half_wstrb=8'b00000000;
        endcase
    end
    always @(*) begin
        case (loadqueue[entry_index].loadUnit_raddr_o[2:0])
            3'b000: load_word_wstrb=8'b00001111;
            3'b100: load_word_wstrb=8'b11110000;
            default: load_word_wstrb=8'b00000000;
        endcase
    end
    always @(*) begin
        case (loadqueue[entry_index].loadUnit_raddr_o[2:0])
            3'b000: load_double_wstrb=8'b11111111;
            default: load_double_wstrb=8'b00000000;
        endcase
    end

    assign load_rmask           = 8'h0 |
                                ({8{(loadqueue[entry_index].loadUnit_rsize_o == 3'h0)}} & load_byte_wstrb   ) | 
                                ({8{(loadqueue[entry_index].loadUnit_rsize_o == 3'h1)}} & load_half_wstrb   ) |
                                ({8{(loadqueue[entry_index].loadUnit_rsize_o == 3'h2)}} & load_word_wstrb   ) |
                                ({8{(loadqueue[entry_index].loadUnit_rsize_o == 3'h3)}} & load_double_wstrb ) ;

    logic load_afte_store;
    assign load_afte_store = (loadqueue_valid[entry_index] & (loadqueue[entry_index].loadUnit_raddr_o[63:3] == reg_storeaddrUnit_waddr_o[63:3]) & ((load_rmask & store_wmask) != 8'h0));
    logic old;
    assign old = rob_is_older(reg_storeaddrUnit_rob_ptr_o, loadqueue[entry_index].loadUnit_rob_ptr_o, deq_rob_ptr);

    if(entry_index == 0)begin: U_gen_load_after_store_0
        assign loadqueue_flush_valid[entry_index]       = load_afte_store & old;
        assign loadqueueRAW_flush_rob_ptr[entry_index]  = loadqueue[entry_index].loadUnit_rob_ptr_o;
    end
    else begin: U_gen_load_after_store_another
        logic prev_old;
        assign prev_old = rob_is_older(loadqueueRAW_flush_rob_ptr[entry_index - 1], loadqueue[entry_index].loadUnit_rob_ptr_o, deq_rob_ptr);

        assign loadqueue_flush_valid[entry_index]       = ((load_afte_store & old) | loadqueue_flush_valid[entry_index - 1]);
        assign loadqueueRAW_flush_rob_ptr[entry_index]  = (loadqueue_flush_valid[entry_index - 1] & (prev_old | (!(load_afte_store & old)))) ? 
                                                        loadqueueRAW_flush_rob_ptr[entry_index - 1] : 
                                                        loadqueue[entry_index].loadUnit_rob_ptr_o;
    end
end
endgenerate

assign LoadQueueRAW_flush_o    = (loadqueue_flush_valid[LQRAW_entry_num - 1] & reg_storeaddrUnit_check_RAW_o);
assign LoadQueueRAW_rob_ptr_o  = loadqueueRAW_flush_rob_ptr[LQRAW_entry_num - 1][rob_entry_w - 1 : 0];



endmodule //LoadQueueRAW
