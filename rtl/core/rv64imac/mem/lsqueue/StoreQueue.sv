module StoreQueue
import lsq_pkg::*;
import rob_pkg::*;
import mem_pkg::*;
import core_setting_pkg::*;
(
    input                                               clk,
    input                                               rst_n,

    input                                               redirect,

    input  rob_entry_ptr_t                              top_rob_ptr,
    input  ls_rob_entry_ptr_t                           deq_rob_ptr,

    input                                               rename_fire,
    input              [rename_width - 1 : 0]           sq_req,
    input   sq_entry_t [rename_width - 1 : 0]           sq_req_entry,
    output  sq_resp_t  [rename_width - 1 : 0]           sq_resp,

    input  SQ_entry_ptr_t                               storeaddrUnit_sq_ptr,
    output store_optype_t                               storeaddrUnit_op,
    output ls_rob_entry_ptr_t                           storeaddrUnit_rob_ptr,

    // load query interface
    /* verilator lint_off UNUSEDSIGNAL */
    input  [63:0]                                       load_paddr2sq,
    /* verilator lint_on UNUSEDSIGNAL */
    input  [7:0]                                        load_rstrb2sq,
    input  ls_rob_entry_ptr_t                           load_rob_ptr,
    output [63:0]                                       sq_load_data,
    output [7:0]                                        sq_load_rstrb,
    output                                              sq_wait,

    input                                               storeaddrUnit_valid_o,
    output                                              storeaddrUnit_ready_o,
    input                                               storeaddrUnit_addr_misalign_o,
    input                                               storeaddrUnit_page_error_o,
    input  [63:0]                                       storeaddrUnit_waddr_o,
    input  SQ_entry_ptr_t                               storeaddrUnit_sq_ptr_o,

    input                                               storedataUnit_valid_o,
    output                                              storedataUnit_ready_o,
    input  SQ_entry_ptr_t                               storedataUnit_sq_ptr_o,
    input  [63:0]                                       storedataUnit_mem_wdata_o,

    output                                              StoreQueue_valid_o,
    input                                               StoreQueue_ready_o,
    output                                              StoreQueue_addr_misalign_o,
    output                                              StoreQueue_page_error_o,
    output rob_entry_ptr_t                              StoreQueue_rob_ptr_o,
    output [63:0]                                       StoreQueue_vaddr_o,

    input                                               StoreQueue_can_write_uc,
    output                                              StoreQueue2Uncache_valid,
    output [63:0]                                       StoreQueue_Uncache_waddr_o,
    output [63:0]                                       StoreQueue_Uncache_wdata_o,
    output [ 7:0]                                       StoreQueue_Uncache_wstrb_o,

    input                                               StoreQueue_can_write_sb,
    output                                              StoreQueue2StoreBuffer_valid,
    output [63:0]                                       StoreQueue_mem_waddr_o,
    output [63:0]                                       StoreQueue_mem_wdata_o,
    output [ 7:0]                                       StoreQueue_mem_wstrb_o
);

sq_entry_t [SQ_entry_num - 1 : 0] sq_entry;
SQ_entry_ptr_inner_t              sq_r_ptr;
SQ_entry_ptr_inner_t              sq_w_ptr;
logic                             sq_empty;

/* verilator lint_off UNUSEDSIGNAL */
sq_entry_t                        sq_entry_storeaddr_use;
sq_entry_t                        sq_entry_wirte_use;
/* verilator lint_on UNUSEDSIGNAL */

SQ_entry_ptr_inner_t [rename_width - 1 : 0] sq_ptr_resp/* verilator split_var */;
SQ_entry_ptr_t  [rename_width - 1 : 0]      sq_ptr_enq;
sq_resp_t       [rename_width - 1 : 0]      sq_resp_inner/* verilator split_var */;
logic                                       sq_bypass_wait[SQ_entry_num - 1 : 0]/* verilator split_var */;
logic [7:0]                                 sq_bypass_wstrb_normal[SQ_entry_num - 1 : 0];
logic [7:0]                                 sq_bypass_wstrb_spec[SQ_entry_num - 1 : 0];
logic [7:0]                                 sq_bypass_wstrb_normal_o[SQ_entry_num - 1 : 0]/* verilator split_var */;
logic [7:0]                                 sq_bypass_wstrb_spec_o[SQ_entry_num - 1 : 0]/* verilator split_var */;
logic [63:0]                                sq_bypass_data_normal[SQ_entry_num - 1 : 0]/* verilator split_var */;
logic [63:0]                                sq_bypass_data_spec[SQ_entry_num - 1 : 0]/* verilator split_var */;

SQ_entry_ptr_inner_t              sq_w_ptr_nxt;
assign sq_w_ptr_nxt = (sq_resp_inner[rename_width - 1].valid & sq_req[rename_width - 1] ) ? (sq_ptr_resp[rename_width - 1] + 1) : sq_ptr_resp[rename_width - 1];
FF_D_with_syn_rst #(
    .DATA_LEN 	( SQ_entry_w + 1    ),
    .RST_DATA 	( 0                 )
)u_sq_w_ptr
(
    .clk        ( clk           ),
    .rst_n      ( rst_n         ),
    .syn_rst    ( redirect      ),
    .wen        ( rename_fire   ),
    .data_in    ( sq_w_ptr_nxt  ),
    .data_out   ( sq_w_ptr      )
);

FF_D_with_syn_rst #(
    .DATA_LEN 	( rob_entry_w + 1   ),
    .RST_DATA 	( 0                 )
)u_sq_r_ptr
(
    .clk        ( clk                                       ),
    .rst_n      ( rst_n                                     ),
    .syn_rst    ( redirect                                  ),
    .wen        ( StoreQueue_valid_o & StoreQueue_ready_o   ),
    .data_in    ( sq_r_ptr + 1                              ),
    .data_out   ( sq_r_ptr                                  )
);

//get wstrb by control sign 
logic [7:0] byte_wstrb, half_wstrb, word_wstrb, double_wstrb;
always_comb begin
    case (sq_entry_wirte_use.mem_waddr[2:0])
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
always_comb begin
    case (sq_entry_wirte_use.mem_waddr[2:0])
        3'b000: half_wstrb=8'b00000011;
        3'b010: half_wstrb=8'b00001100;
        3'b100: half_wstrb=8'b00110000;
        3'b110: half_wstrb=8'b11000000;
        default: half_wstrb=8'b00000000;
    endcase
end
always_comb begin
    case (sq_entry_wirte_use.mem_waddr[2:0])
        3'b000: word_wstrb=8'b00001111;
        3'b100: word_wstrb=8'b11110000;
        default: word_wstrb=8'b00000000;
    endcase
end
always_comb begin
    case (sq_entry_wirte_use.mem_waddr[2:0])
        3'b000: double_wstrb=8'b11111111;
        default: double_wstrb=8'b00000000;
    endcase
end

logic [63:0] store_data;
memory_store_move u_memory_store_move(
    .pre_data    	( sq_entry_wirte_use.mem_wdata      ),
    .data_offset 	( sq_entry_wirte_use.mem_waddr[2:0] ),
    .data        	( store_data                        )
);

genvar entry_index;
generate for(entry_index = 0 ; entry_index < SQ_entry_num; entry_index = entry_index + 1) begin : U_gen_sq_entry
    logic       sq_entry_wen;
    logic       sq_entry_enq_wen;
    logic       sq_entry_storeaddr_update_wen;
    logic       sq_entry_storedata_update_wen;
    sq_entry_t  sq_entry_nxt;
    sq_entry_t  sq_entry_enq;
    sq_entry_t  sq_entry_storeaddr_update;
    sq_entry_t  sq_entry_storedata_update;

    StoreQueue_enq u_StoreQueue_enq(
        .rename_fire       	( rename_fire        ),
        .sq_req           	( sq_req             ),
        .sq_req_entry     	( sq_req_entry       ),
        .sq_ptr_resp      	( sq_ptr_enq         ),
        .sq_ptr_self      	( entry_index        ),
        .sq_entry_enq_wen 	( sq_entry_enq_wen   ),
        .sq_entry_enq     	( sq_entry_enq       )
    );

    assign sq_entry_storeaddr_update_wen                  = storeaddrUnit_valid_o & storeaddrUnit_ready_o & (entry_index == storeaddrUnit_sq_ptr_o);
    assign sq_entry_storeaddr_update.rob_ptr              = sq_entry[entry_index].rob_ptr              ;
    assign sq_entry_storeaddr_update.storeaddrUnit_op     = sq_entry[entry_index].storeaddrUnit_op     ;
    assign sq_entry_storeaddr_update.addr_misalign        = storeaddrUnit_addr_misalign_o              ;
    assign sq_entry_storeaddr_update.page_error           = storeaddrUnit_page_error_o                 ;
    assign sq_entry_storeaddr_update.addr_finish          = 1'b1                                       ;
    assign sq_entry_storeaddr_update.mem_waddr            = storeaddrUnit_waddr_o                      ;
    assign sq_entry_storeaddr_update.data_finish          = sq_entry[entry_index].data_finish          ;
    assign sq_entry_storeaddr_update.mem_wdata            = sq_entry[entry_index].mem_wdata            ;

    assign sq_entry_storedata_update_wen                  = storedataUnit_valid_o & storedataUnit_ready_o & (entry_index == storedataUnit_sq_ptr_o);
    assign sq_entry_storedata_update.rob_ptr              = sq_entry[entry_index].rob_ptr              ;
    assign sq_entry_storedata_update.storeaddrUnit_op     = sq_entry[entry_index].storeaddrUnit_op     ;
    assign sq_entry_storedata_update.addr_misalign        = sq_entry[entry_index].addr_misalign        ;
    assign sq_entry_storedata_update.page_error           = sq_entry[entry_index].page_error           ;
    assign sq_entry_storedata_update.addr_finish          = sq_entry[entry_index].addr_finish          ;
    assign sq_entry_storedata_update.mem_waddr            = sq_entry[entry_index].mem_waddr            ;
    assign sq_entry_storedata_update.data_finish          = 1'b1                                       ;
    assign sq_entry_storedata_update.mem_wdata            = storedataUnit_mem_wdata_o                  ;

    assign sq_entry_wen =   (sq_entry_enq_wen                      ) |
                            (sq_entry_storeaddr_update_wen         ) | 
                            (sq_entry_storedata_update_wen         );
    assign sq_entry_nxt =   ({SQ_ENTRY_W{sq_entry_enq_wen                      }} & sq_entry_enq                      ) |
                            ({SQ_ENTRY_W{sq_entry_storeaddr_update_wen         }} & sq_entry_storeaddr_update         ) | 
                            ({SQ_ENTRY_W{sq_entry_storedata_update_wen         }} & sq_entry_storedata_update         );

    FF_D_without_asyn_rst #(SQ_ENTRY_W)    u_entry     (clk,sq_entry_wen, sq_entry_nxt, sq_entry[entry_index]);

    logic Queue_entry_use_for_bypass;
    assign Queue_entry_use_for_bypass = (QueueValid(sq_r_ptr, sq_w_ptr, entry_index) & sq_entry[entry_index].addr_finish & 
                                    (sq_entry[entry_index].mem_waddr[63:3] == load_paddr2sq[63:3]) & rob_is_older(sq_entry[entry_index].rob_ptr, load_rob_ptr, deq_rob_ptr));

    if(entry_index == 0)begin : U_gen_sq_bypass_0
        assign sq_bypass_wait[entry_index]              = (Queue_entry_use_for_bypass & (!sq_entry[entry_index].data_finish));
        assign sq_bypass_wstrb_normal_o[entry_index]    = sq_bypass_wstrb_normal[entry_index];
        assign sq_bypass_wstrb_spec_o[entry_index]      = sq_bypass_wstrb_spec[entry_index];
        assign sq_bypass_data_normal[entry_index]       = data_splicing_64(64'h0, sq_entry[entry_index].mem_wdata, sq_bypass_wstrb_normal[entry_index]);
        assign sq_bypass_data_spec[entry_index]         = data_splicing_64(64'h0, sq_entry[entry_index].mem_wdata, sq_bypass_wstrb_spec[entry_index]);
    end
    else begin : U_gen_sq_bypass_other
        assign sq_bypass_wait[entry_index]              = ((Queue_entry_use_for_bypass & (!sq_entry[entry_index].data_finish)) | sq_bypass_wait[entry_index - 1]);
        assign sq_bypass_wstrb_normal_o[entry_index]    = (sq_bypass_wstrb_normal[entry_index] | sq_bypass_wstrb_normal_o[entry_index - 1]);
        assign sq_bypass_wstrb_spec_o[entry_index]      = (sq_bypass_wstrb_spec[entry_index] | sq_bypass_wstrb_spec_o[entry_index - 1]);
        assign sq_bypass_data_normal[entry_index]       = data_splicing_64(sq_bypass_data_normal[entry_index - 1], sq_entry[entry_index].mem_wdata, sq_bypass_wstrb_normal[entry_index]);
        assign sq_bypass_data_spec[entry_index]         = data_splicing_64(sq_bypass_data_spec[entry_index - 1], sq_entry[entry_index].mem_wdata, sq_bypass_wstrb_spec[entry_index]);
    end

    logic [7:0] bypass_byte_wstrb, bypass_half_wstrb, bypass_word_wstrb, bypass_double_wstrb;
    logic [7:0] bypass_wstrb;
    always_comb begin
        case (sq_entry[entry_index].mem_waddr[2:0])
            3'b000: bypass_byte_wstrb=8'b00000001;
            3'b001: bypass_byte_wstrb=8'b00000010;
            3'b010: bypass_byte_wstrb=8'b00000100;
            3'b011: bypass_byte_wstrb=8'b00001000;
            3'b100: bypass_byte_wstrb=8'b00010000;
            3'b101: bypass_byte_wstrb=8'b00100000;
            3'b110: bypass_byte_wstrb=8'b01000000;
            3'b111: bypass_byte_wstrb=8'b10000000;
            default: bypass_byte_wstrb=8'b00000000;
        endcase
    end
    always_comb begin
        case (sq_entry[entry_index].mem_waddr[2:0])
            3'b000: bypass_half_wstrb=8'b00000011;
            3'b010: bypass_half_wstrb=8'b00001100;
            3'b100: bypass_half_wstrb=8'b00110000;
            3'b110: bypass_half_wstrb=8'b11000000;
            default: bypass_half_wstrb=8'b00000000;
        endcase
    end
    always_comb begin
        case (sq_entry[entry_index].mem_waddr[2:0])
            3'b000: bypass_word_wstrb=8'b00001111;
            3'b100: bypass_word_wstrb=8'b11110000;
            default: bypass_word_wstrb=8'b00000000;
        endcase
    end
    always_comb begin
        case (sq_entry[entry_index].mem_waddr[2:0])
            3'b000: bypass_double_wstrb=8'b11111111;
            default: bypass_double_wstrb=8'b00000000;
        endcase
    end
    assign bypass_wstrb = 8'h0 |
                        ({8{store_byte  (sq_entry[entry_index].storeaddrUnit_op)}} & bypass_byte_wstrb   ) | 
                        ({8{store_half  (sq_entry[entry_index].storeaddrUnit_op)}} & bypass_half_wstrb   ) |
                        ({8{store_word  (sq_entry[entry_index].storeaddrUnit_op)}} & bypass_word_wstrb   ) |
                        ({8{store_double(sq_entry[entry_index].storeaddrUnit_op)}} & bypass_double_wstrb ) ;

    assign sq_bypass_wstrb_normal[entry_index]  = ({8{Queue_entry_use_for_bypass & ((sq_r_ptr[SQ_entry_w] == sq_w_ptr[SQ_entry_w]) | (entry_index <  sq_w_ptr[SQ_entry_w - 1 : 0]))}} & bypass_wstrb);
    assign sq_bypass_wstrb_spec[entry_index]    = ({8{Queue_entry_use_for_bypass &  (sq_r_ptr[SQ_entry_w] != sq_w_ptr[SQ_entry_w]) & (entry_index >= sq_r_ptr[SQ_entry_w - 1 : 0]) }} & bypass_wstrb);
end
endgenerate

genvar resp_index;
generate for(resp_index = 0 ; resp_index < rename_width; resp_index = resp_index + 1) begin : U_gen_sq_resp
    if(resp_index == 0)begin : U_gen_sq_resp_0
        assign sq_resp_inner[resp_index].valid     = ((sq_ptr_resp[resp_index][SQ_entry_w] == sq_r_ptr[SQ_entry_w]) |
                                                    (sq_ptr_resp[resp_index][SQ_entry_w - 1 : 0] != sq_r_ptr[SQ_entry_w - 1 : 0]));
        assign sq_ptr_resp[resp_index]             = sq_w_ptr;
    end
    else begin : U_gen_sq_resp_other
        assign sq_resp_inner[resp_index].valid     = ((sq_ptr_resp[resp_index][SQ_entry_w] == sq_r_ptr[SQ_entry_w]) |
                                                    (sq_ptr_resp[resp_index][SQ_entry_w - 1 : 0] != sq_r_ptr[SQ_entry_w - 1 : 0])) &
                                                    sq_resp_inner[resp_index - 1].valid;
        assign sq_ptr_resp[resp_index]             = (sq_resp_inner[resp_index - 1].valid & sq_req[resp_index - 1] ) ? (sq_ptr_resp[resp_index - 1] + 1) : sq_ptr_resp[resp_index - 1];
    end
    assign sq_ptr_enq[resp_index]              = sq_ptr_resp[resp_index][SQ_entry_w - 1 : 0];
    assign sq_resp_inner[resp_index].sq_ptr    = sq_ptr_enq[resp_index];
end
endgenerate
assign sq_resp = sq_resp_inner;

assign sq_entry_storeaddr_use   = sq_entry[storeaddrUnit_sq_ptr];
assign storeaddrUnit_op         = sq_entry_storeaddr_use.storeaddrUnit_op;
assign storeaddrUnit_rob_ptr    = sq_entry_storeaddr_use.rob_ptr;

assign sq_load_data             = data_splicing_64(sq_bypass_data_spec[SQ_entry_num - 1], sq_bypass_data_normal[SQ_entry_num - 1], sq_bypass_wstrb_normal_o[SQ_entry_num - 1]);
assign sq_load_rstrb            = ((sq_bypass_wstrb_normal_o[SQ_entry_num - 1] | sq_bypass_wstrb_spec_o[SQ_entry_num - 1]) & load_rstrb2sq);
assign sq_wait                  = sq_bypass_wait[SQ_entry_num - 1];

assign storeaddrUnit_ready_o    = 1'b1;
assign storedataUnit_ready_o    = 1'b1;

assign sq_empty                 = (sq_r_ptr != sq_w_ptr);
assign sq_entry_wirte_use       = sq_entry[sq_r_ptr];

assign StoreQueue_valid_o           = (StoreQueue_rob_ptr_o == top_rob_ptr) & sq_entry_wirte_use.addr_finish & sq_entry_wirte_use.data_finish & 
                                    (addrcache(StoreQueue_vaddr_o) & StoreQueue_can_write_sb | ((!addrcache(StoreQueue_vaddr_o)) & StoreQueue_can_write_uc) | 
                                    StoreQueue_addr_misalign_o | StoreQueue_page_error_o) & (!sq_empty);
assign StoreQueue_addr_misalign_o   = sq_entry_wirte_use.addr_misalign  ;
assign StoreQueue_page_error_o      = sq_entry_wirte_use.page_error     ;
assign StoreQueue_rob_ptr_o         = sq_entry_wirte_use.rob_ptr[rob_entry_w - 1 : 0];
assign StoreQueue_vaddr_o           = sq_entry_wirte_use.mem_waddr      ;

assign StoreQueue2Uncache_valid     = StoreQueue_valid_o & (!StoreQueue_addr_misalign_o) & (!StoreQueue_page_error_o) & (!addrcache(StoreQueue_vaddr_o));
assign StoreQueue_Uncache_waddr_o   = sq_entry_wirte_use.mem_waddr      ;
assign StoreQueue_Uncache_wdata_o   = store_data                        ;
assign StoreQueue_Uncache_wstrb_o   = 8'h0 |
                                    ({8{store_byte  (sq_entry_wirte_use.storeaddrUnit_op)}} & byte_wstrb   ) |
                                    ({8{store_half  (sq_entry_wirte_use.storeaddrUnit_op)}} & half_wstrb   ) |
                                    ({8{store_word  (sq_entry_wirte_use.storeaddrUnit_op)}} & word_wstrb   ) |
                                    ({8{store_double(sq_entry_wirte_use.storeaddrUnit_op)}} & double_wstrb ) ;

assign StoreQueue2StoreBuffer_valid = StoreQueue_valid_o & (!StoreQueue_addr_misalign_o) & (!StoreQueue_page_error_o) & addrcache(StoreQueue_vaddr_o);
assign StoreQueue_mem_waddr_o       = sq_entry_wirte_use.mem_waddr      ;
assign StoreQueue_mem_wdata_o       = store_data                        ;
assign StoreQueue_mem_wstrb_o       = 8'h0 |
                                    ({8{store_byte  (sq_entry_wirte_use.storeaddrUnit_op)}} & byte_wstrb   ) | 
                                    ({8{store_half  (sq_entry_wirte_use.storeaddrUnit_op)}} & half_wstrb   ) |
                                    ({8{store_word  (sq_entry_wirte_use.storeaddrUnit_op)}} & word_wstrb   ) |
                                    ({8{store_double(sq_entry_wirte_use.storeaddrUnit_op)}} & double_wstrb ) ;

endmodule //StoreQueue
