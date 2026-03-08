module LoadQueueRAW
import rob_pkg::*;
import lsq_pkg::*;
(
    input                                               clk,
    input                                               rst_n,

    input                                               redirect,

    input ls_rob_entry_ptr_t                            deq_rob_ptr,

    input                                               loadUnit_enq_lqRAW_o,
    input  [63:0]                                       loadUnit_raddr_o,
    input  [2:0]                                        loadUnit_rsize_o,
    input  ls_rob_entry_ptr_t                           loadUnit_enq_rob_ptr_o,

    input                                               storeaddrUnit_check_RAW_o,
    input  [63:0]                                       storeaddrUnit_waddr_o,
    input  [2:0]                                        storeaddrUnit_wsize_o,
    input  ls_rob_entry_ptr_t                           storeaddrUnit_rob_ptr_o,

    output                                              LoadQueue_flush_o,
    output rob_entry_ptr_t                              LoadQueue_rob_ptr_o
);

logic          [LQRAW_entry_num - 1 : 0]     loadqueue_valid;
lq_RAW_entry_t [LQRAW_entry_num - 1 : 0]     loadqueue;

logic          [LQRAW_entry_num - 1 : 0]     loadqueue_flush_valid;
ls_rob_entry_ptr_t [LQRAW_entry_num - 1 : 0] loadqueueRAW_flush_rob_ptr/* verilator split_var */;

logic [LQRAW_entry_w - 1 : 0] w_ptr;

lq_RAW_entry_t enq_loadqueue;
assign enq_loadqueue.loadUnit_raddr_o      = loadUnit_raddr_o       ;
assign enq_loadqueue.loadUnit_rsize_o      = loadUnit_rsize_o       ;
assign enq_loadqueue.loadUnit_rob_ptr_o    = loadUnit_enq_rob_ptr_o ;

FF_D_with_syn_rst #(
    .DATA_LEN 	( LQRAW_entry_w ),
    .RST_DATA 	( 0             )
)u_w_ptr
(
    .clk        ( clk                   ),
    .rst_n      ( rst_n                 ),
    .syn_rst    ( redirect              ),
    .wen        ( loadUnit_enq_lqRAW_o  ),
    .data_in    ( w_ptr + 1'b1          ),
    .data_out   ( w_ptr                 )
);

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
    assign enqueue              = loadUnit_enq_lqRAW_o & (entry_index == w_ptr);
    FF_D_with_syn_rst #(
        .DATA_LEN 	( 1  ),
        .RST_DATA 	( 0  )
    )u_queue_valid
    (
        .clk        ( clk                           ),
        .rst_n      ( rst_n                         ),
        .syn_rst    ( redirect                      ),
        .wen        ( enqueue                       ),
        .data_in    ( 1'b1                          ),
        .data_out   ( loadqueue_valid[entry_index]  )
    );
    FF_D_without_asyn_rst #(68 + rob_entry_w) u_entry     (clk,enqueue, enq_loadqueue, loadqueue[entry_index]);


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

assign LoadQueue_flush_o    = (loadqueue_flush_valid[LQRAW_entry_num - 1] & reg_storeaddrUnit_check_RAW_o);
assign LoadQueue_rob_ptr_o  = loadqueueRAW_flush_rob_ptr[LQRAW_entry_num - 1][rob_entry_w - 1 : 0];



endmodule //LoadQueueRAW
