module ibuf
import frontend_pkg::*;
import core_setting_pkg::decode_width;
(
    input                                           clk,
    input                                           rst_n,

    input                                           flush,
    output                                          full,

    input                                           push,
    input ibuf_inst_entry[IFU_INST_MAX_NUM- 1 : 0]  ibuf_inst,
    input [FTQ_ENTRY_BIT_NUM - 1 : 0]               ifu_dequeue_ptr,

//! TODO inst_pc也可以通过在exu维持一个pc寄存器而推测pc值；可优化
    output ibuf_inst_o_entry[decode_width - 1 :0]   ibuf_inst_o,
    input  [decode_width - 1 :0]                    decode_inst_ready
);


logic [IFU_INST_MAX_NUM -1 :0]                  push_is_valid;
logic [0:0]                                     push_end_flag[IFU_INST_MAX_NUM -1 :0];
logic [BLOCK_BIT_NUM - 1:0]                     push_inst_offset[IFU_INST_MAX_NUM -1 :0];
logic [0:0]                                     push_tval_flag[IFU_INST_MAX_NUM -1 :0];
logic [1:0]                                     push_rresp[IFU_INST_MAX_NUM -1 :0];
logic [31:0]                                    push_inst[IFU_INST_MAX_NUM -1 :0];

logic [0:0]                                     push_end_flag_serial[IFU_INST_MAX_NUM -1 :0];
genvar push_index;
generate for(push_index = 0 ; push_index < IFU_INST_MAX_NUM; push_index = push_index + 1) begin : U_gen_push_vector
    assign push_is_valid    [push_index] = (ibuf_inst[push_index].is_valid & ibuf_inst[push_index].eqa);
    assign push_inst_offset [push_index] = ibuf_inst[push_index].inst_offset;
    assign push_tval_flag   [push_index] = ibuf_inst[push_index].tval_flag;
    assign push_rresp       [push_index] = ibuf_inst[push_index].rresp;
    assign push_inst        [push_index] = ibuf_inst[push_index].inst;
    if(push_index == (IFU_INST_MAX_NUM - 1))begin:u_gen_finial
        assign push_end_flag[push_index]        = push_is_valid[push_index];
        assign push_end_flag_serial[push_index] = push_is_valid[push_index];
    end
    else begin:u_gen_another
        assign push_end_flag[push_index]        = push_is_valid[push_index] & (!push_end_flag_serial[push_index + 1]);
        assign push_end_flag_serial[push_index] = push_is_valid[push_index] | push_is_valid[push_index + 1];
    end
end
endgenerate

//===============================fifo body========================================================
ibuf_point wdata_poi;
ibuf_point rdata_poi;
logic [BLOCK_BIT_NUM + FTQ_ENTRY_BIT_NUM + 35:0] fifo_sram[0:IBUF_Depth-1];

ibuf_point[IFU_INST_MAX_NUM -1 :0]  wdata_poi_n/* verilator split_var */;
ibuf_point[decode_width -1 :0]      rdata_poi_n;

ibuf_point                          fifo_r_cnt;
ibuf_point                          fifo_r_ptr;

ibuf_data[IFU_INST_MAX_NUM -1 :0]   fifo_w_data;
ibuf_data[decode_width -1 :0]       fifo_r_data;

logic [IFU_INST_MAX_NUM -1 :0]      fifo_full;
logic [decode_width -1 :0]          pop;

logic [decode_width -1 :0]          fifo_valid_o;

always @(posedge clk or negedge rst_n) begin
    if(!rst_n)begin
        wdata_poi <= {(IBUF_ADDR_W + 1){1'b0}};
        rdata_poi <= {(IBUF_ADDR_W + 1){1'b0}};
    end
    else begin
        if(flush)begin
            wdata_poi <= rdata_poi;
        end
        else begin
            case ({push,(|pop)})
                2'b11:begin
                    wdata_poi   <=  (push_is_valid[IFU_INST_MAX_NUM - 1]) ? 
                                        (wdata_poi_n[IFU_INST_MAX_NUM -1] + 1'b1) : 
                                        wdata_poi_n[IFU_INST_MAX_NUM -1];
                    rdata_poi   <=  fifo_r_ptr;
                end
                2'b10:begin
                    wdata_poi   <=  (push_is_valid[IFU_INST_MAX_NUM - 1]) ? 
                                        (wdata_poi_n[IFU_INST_MAX_NUM -1] + 1'b1) : 
                                        wdata_poi_n[IFU_INST_MAX_NUM -1];
                end
                2'b01:begin
                    rdata_poi   <=  fifo_r_ptr;
                end
                default ;
            endcase
        end
    end
end

genvar fifo_index;
generate for(fifo_index = 0 ; fifo_index < IBUF_Depth; fifo_index = fifo_index + 1) begin : U_gen_ibuf
    logic                                               ibuf_wen;
    logic [BLOCK_BIT_NUM + FTQ_ENTRY_BIT_NUM + 35 : 0]  ibuf_wdata;

    gen_ibuf_wctrl u_gen_ibuf_wctrl(
        .ibuf_sel       ( fifo_index    ),
        .push_is_valid  ( push_is_valid ),
        .wdata_poi_n    ( wdata_poi_n   ),
        .fifo_w_data    ( fifo_w_data   ),
        .ibuf_wen       ( ibuf_wen      ),
        .ibuf_wdata     ( ibuf_wdata    )
    );

    FF_D_without_asyn_rst #(
        .DATA_LEN 	( BLOCK_BIT_NUM + FTQ_ENTRY_BIT_NUM + 36  ))
    u_FF_D_without_asyn_rst(
        .clk      	( clk                   ),
        .wen      	( ibuf_wen & push       ),
        .data_in  	( ibuf_wdata            ),
        .data_out 	( fifo_sram[fifo_index] )
    );
end
endgenerate

genvar fifo_w_index;
generate for(fifo_w_index = 0 ; fifo_w_index < IFU_INST_MAX_NUM; fifo_w_index = fifo_w_index + 1) begin : U_gen_ibuf_w
    if(fifo_w_index == 0)begin: u_gen_fifo_w_ponit_0
        assign wdata_poi_n[fifo_w_index] = wdata_poi;
    end
    else begin: u_gen_fifo_w_ponit_another
        assign wdata_poi_n[fifo_w_index] = (push_is_valid[fifo_w_index - 1]) ? (wdata_poi_n[fifo_w_index - 1] + 1) : wdata_poi_n[fifo_w_index - 1];
    end
    assign fifo_w_data[fifo_w_index] = {push_end_flag[fifo_w_index], push_inst_offset[fifo_w_index], ifu_dequeue_ptr, 
                                        push_tval_flag[fifo_w_index], push_rresp[fifo_w_index], push_inst[fifo_w_index]};
    assign fifo_full[fifo_w_index]   = push_is_valid[fifo_w_index] & 
                                    (wdata_poi_n[fifo_w_index][IBUF_ADDR_W-1:0] == fifo_r_ptr[IBUF_ADDR_W-1:0]) & 
                                    (wdata_poi_n[fifo_w_index][IBUF_ADDR_W]     != fifo_r_ptr[IBUF_ADDR_W]);
end
endgenerate

genvar fifo_r_index;
generate for(fifo_r_index = 0 ; fifo_r_index < decode_width; fifo_r_index = fifo_r_index + 1) begin : U_gen_ibuf_r
    assign rdata_poi_n[fifo_r_index]                    = rdata_poi + fifo_r_index;
    assign fifo_r_data[fifo_r_index]                    = fifo_sram[rdata_poi_n[fifo_r_index][IBUF_ADDR_W-1:0]];
    if(fifo_r_index == 0)begin: u_gen_fifo_r_ponit_0
        assign fifo_valid_o[fifo_r_index]               = (!(rdata_poi_n[fifo_r_index] == wdata_poi));
    end
    else begin: u_gen_fifo_w_ponit_another
        assign fifo_valid_o[fifo_r_index]               = ((!(rdata_poi_n[fifo_r_index] == wdata_poi)) & fifo_valid_o[fifo_r_index - 1]);
    end
    assign ibuf_inst_o[fifo_r_index].is_valid           = fifo_valid_o[fifo_r_index];
    assign ibuf_inst_o[fifo_r_index].end_flag           = fifo_r_data[fifo_r_index][BLOCK_BIT_NUM + FTQ_ENTRY_BIT_NUM + 35];
    assign ibuf_inst_o[fifo_r_index].inst_offset        = fifo_r_data[fifo_r_index][BLOCK_BIT_NUM + FTQ_ENTRY_BIT_NUM + 34: FTQ_ENTRY_BIT_NUM + 35];
    assign ibuf_inst_o[fifo_r_index].ifu_dequeue_ptr    = fifo_r_data[fifo_r_index][FTQ_ENTRY_BIT_NUM + 34:35];
    assign ibuf_inst_o[fifo_r_index].tval_flag          = fifo_r_data[fifo_r_index][34];
    assign ibuf_inst_o[fifo_r_index].rresp              = fifo_r_data[fifo_r_index][33:32];
    assign ibuf_inst_o[fifo_r_index].inst               = fifo_r_data[fifo_r_index][31:0];
    assign pop[fifo_r_index]                            = ibuf_inst_o[fifo_r_index].is_valid & decode_inst_ready[fifo_r_index];
end
endgenerate

//! 行为级建模，因为不好做参数化
integer i;
always_comb begin : gen_fifo_r_poi_next
    fifo_r_cnt = 0;
    for(i = 0; i < decode_width; i++)begin
        fifo_r_cnt = fifo_r_cnt + {{IBUF_ADDR_W{1'b0}}, pop[i]};
    end
end
assign fifo_r_ptr = rdata_poi + fifo_r_cnt;

assign full = (|fifo_full);
//===============================fifo body=======================================================


endmodule //ibuf

