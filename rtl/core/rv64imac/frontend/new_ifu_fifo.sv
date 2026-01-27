`include "./struct.sv"
module new_ifu_fifo(
    input                                   clk,
    input                                   rst_n,

    input                                   flush,
    output                                  full,
    output                                  empty,

    input                                   push,
    input [IFU_INST_MAX_NUM * 1 - 1 : 0]    o_is_valid,
    input [IFU_INST_MAX_NUM * 1 - 1 : 0]    o_eqa,
    input [IFU_INST_MAX_NUM * 1 - 1 : 0]    o_is_rvc,
    input [IFU_INST_MAX_NUM * 1 - 1 : 0]    o_tval_flag,
    input [2 * IFU_INST_MAX_NUM - 1:0]      o_rresp,
    input [32 * IFU_INST_MAX_NUM - 1:0]     o_inst,
    input [16 * IFU_INST_MAX_NUM - 1:0]     o_c_inst,
    input [64 * IFU_INST_MAX_NUM - 1:0]     o_inst_pc,

    input                                   pop,
    output                                  one_is_valid,
    output                                  one_is_rvc,
    output                                  one_is_end,
    output                                  one_tval_flag,
    output [1:0]                            one_rresp,
//! TODO c_inst 和inst可以合为一个32位的输出；inst_pc也可以通过在exu维持一个pc寄存器而推测pc值；可优化
    output [31:0]                           one_inst,
    output [15:0]                           one_c_inst,
    output [63:0]                           one_inst_pc
);

logic [IFU_INST_MAX_NUM -1 :0]  fifo_full;
logic [IFU_INST_MAX_NUM -1 :0]  fifo_empty;

logic                           is_valid[IFU_INST_MAX_NUM -1 :0];
logic                           eqa[IFU_INST_MAX_NUM -1 :0];
logic                           is_rvc[IFU_INST_MAX_NUM -1 :0];
logic                           tval_flag[IFU_INST_MAX_NUM -1 :0];
logic  [1:0]                    rresp[IFU_INST_MAX_NUM -1 :0];
logic  [31:0]                   inst[IFU_INST_MAX_NUM -1 :0];
logic  [15:0]                   c_inst[IFU_INST_MAX_NUM -1 :0];
logic  [63:0]                   inst_pc[IFU_INST_MAX_NUM -1 :0];

logic [116:0]                   fifo_w_data[IFU_INST_MAX_NUM -1 :0];
logic [116:0]                   fifo_r_data[IFU_INST_MAX_NUM -1 :0];

logic [IFU_INST_MAX_NUM -1 :0]  fifo_is_valid;
logic                           fifo_is_rvc[IFU_INST_MAX_NUM -1 :0];
logic                           fifo_tval_flag[IFU_INST_MAX_NUM -1 :0];
logic  [1:0]                    fifo_rresp[IFU_INST_MAX_NUM -1 :0];
logic  [31:0]                   fifo_inst[IFU_INST_MAX_NUM -1 :0];
logic  [15:0]                   fifo_c_inst[IFU_INST_MAX_NUM -1 :0];
logic  [63:0]                   fifo_inst_pc[IFU_INST_MAX_NUM -1 :0];

logic [IFU_INST_MAX_NUM -1 :0]  fifo_use_mask;
logic [IFU_INST_MAX_NUM -1 :0]  fifo_valid;
assign fifo_valid = fifo_is_valid & fifo_use_mask;

logic [BLOCK_BIT_NUM - 2 : 0]   first_bit_sel[IFU_INST_MAX_NUM -2 :0]/* verilator split_var */;
logic [BLOCK_BIT_NUM - 2 : 0]   first_bit_index;
logic [BLOCK_BIT_NUM - 2 : 0]   valid_bit_cnt;
generate 
    if(IFU_INST_MAX_NUM == 8) begin : U_gen_valid_cnt
        assign valid_bit_cnt =  ({2'h0, fifo_valid[0]}) + 
                                ({2'h0, fifo_valid[1]}) + 
                                ({2'h0, fifo_valid[2]}) + 
                                ({2'h0, fifo_valid[3]}) + 
                                ({2'h0, fifo_valid[4]}) + 
                                ({2'h0, fifo_valid[5]}) + 
                                ({2'h0, fifo_valid[6]}) + 
                                ({2'h0, fifo_valid[7]});
        assign first_bit_sel[0] = (fifo_valid[0]) ? 0 : 1;
        assign first_bit_sel[1] = (fifo_valid[2]) ? 2 : 3;
        assign first_bit_sel[2] = (fifo_valid[4]) ? 4 : 5;
        assign first_bit_sel[3] = (fifo_valid[6]) ? 6 : 7;
        assign first_bit_sel[4] = (|fifo_valid[1:0]) ? first_bit_sel[0] : first_bit_sel[1];
        assign first_bit_sel[5] = (|fifo_valid[5:4]) ? first_bit_sel[2] : first_bit_sel[3];
        assign first_bit_sel[6] = (|fifo_valid[3:0]) ? first_bit_sel[4] : first_bit_sel[5];
        assign first_bit_index  = first_bit_sel[6];
    end
endgenerate

genvar packed_index;
generate for(packed_index = 0 ; packed_index < IFU_INST_MAX_NUM; packed_index = packed_index + 1) begin : U_gen_unpacked
    assign is_valid[packed_index]   = o_is_valid[packed_index];
    assign eqa[packed_index]        = o_eqa[packed_index];
    assign is_rvc[packed_index]     = o_is_rvc[packed_index];
    assign tval_flag[packed_index]  = o_tval_flag[packed_index];
    assign rresp[packed_index]      = o_rresp[2 * packed_index + 1 : 2 * packed_index];
    assign inst[packed_index]       = o_inst[32 * packed_index + 31 : 32 * packed_index];
    assign c_inst[packed_index]     = o_c_inst[16 * packed_index + 15 : 16 * packed_index];
    assign inst_pc[packed_index]    = o_inst_pc[64 * packed_index + 63 : 64 * packed_index];

    fifo #(
        .DATA_W 	(117                ),
        .AddR_W 	(FTQ_ENTRY_BIT_NUM  ))
    u_fifo(
        .clk    	(clk                        ),
        .rst_n  	(rst_n                      ),
        .Wready 	(push                       ),
        .Rready 	((valid_bit_cnt == 1) & pop ),
        .flush  	(flush                      ),
        .wdata  	(fifo_w_data[packed_index]  ),
        .empty  	(fifo_empty[packed_index]   ),
        .full   	(fifo_full[packed_index]    ),
        .rdata  	(fifo_r_data[packed_index]  )
    );
    assign fifo_w_data[packed_index] = {(is_valid[packed_index] & eqa[packed_index]), 
                                        is_rvc[packed_index], tval_flag[packed_index], 
                                        rresp[packed_index], inst[packed_index], 
                                        c_inst[packed_index], inst_pc[packed_index]};

    assign fifo_is_valid[packed_index]   = fifo_r_data[packed_index][116];
    assign fifo_is_rvc[packed_index]     = fifo_r_data[packed_index][115];
    assign fifo_tval_flag[packed_index]  = fifo_r_data[packed_index][114];
    assign fifo_rresp[packed_index]      = fifo_r_data[packed_index][113:112];
    assign fifo_inst[packed_index]       = fifo_r_data[packed_index][111:80];
    assign fifo_c_inst[packed_index]     = fifo_r_data[packed_index][79:64];
    assign fifo_inst_pc[packed_index]    = fifo_r_data[packed_index][63:0];

    FF_D_with_syn_rst #(
        .DATA_LEN 	( 1     ),
        .RST_DATA 	( 1'b1  ))
    u_FF_D_with_syn_rst(
        .clk      	( clk                                       ),
        .rst_n    	( rst_n                                     ),
        .syn_rst  	( ((valid_bit_cnt == 1) & pop) | flush      ),
        .wen      	( pop & (packed_index == first_bit_index)   ),
        .data_in  	( 1'b0                                      ),
        .data_out 	( fifo_use_mask[packed_index]               )
    );
end
endgenerate

assign full  = (|fifo_full);
assign empty = (|fifo_empty);

assign one_is_valid  = fifo_is_valid[first_bit_index] ;
assign one_is_rvc    = fifo_is_rvc[first_bit_index]   ;
assign one_tval_flag = fifo_tval_flag[first_bit_index];
assign one_rresp     = fifo_rresp[first_bit_index]    ;
assign one_inst      = fifo_inst[first_bit_index]     ;
assign one_c_inst    = fifo_c_inst[first_bit_index]   ;
assign one_inst_pc   = fifo_inst_pc[first_bit_index]  ;

assign one_is_end    = (valid_bit_cnt == 1);

endmodule //new_ifu_fifo

