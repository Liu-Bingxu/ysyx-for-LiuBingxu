`include "./struct.sv"
module gen_ibuf_wctrl(
    input [IBUF_ADDR_W-1:0]                   ibuf_sel,
    input [IFU_INST_MAX_NUM -1 :0]            push_is_valid,
    input ibuf_point[IFU_INST_MAX_NUM -1 :0]  wdata_poi_n,
    input ibuf_data[IFU_INST_MAX_NUM -1 :0]   fifo_w_data,

    output logic                              ibuf_wen,
    output ibuf_data                          ibuf_wdata
);

logic     temp_ibuf_wen  [IFU_INST_MAX_NUM -1 :0]/* verilator split_var */;
ibuf_data temp_ibuf_wdata[IFU_INST_MAX_NUM -1 :0]/* verilator split_var */;

genvar ibuf_index;
generate for(ibuf_index = 0 ; ibuf_index < IFU_INST_MAX_NUM; ibuf_index = ibuf_index + 1) begin : U_gen_ibuf_wctrl
    if(ibuf_index == 0)begin: U_gen_ibuf_wctrl_0
        assign temp_ibuf_wen  [ibuf_index] = (push_is_valid[ibuf_index] & (ibuf_sel == wdata_poi_n[ibuf_index][IBUF_ADDR_W-1:0]));
        assign temp_ibuf_wdata[ibuf_index] = ({BLOCK_BIT_NUM + FTQ_ENTRY_BIT_NUM + 36{push_is_valid[ibuf_index] & 
                                                (ibuf_sel == wdata_poi_n[ibuf_index][IBUF_ADDR_W-1:0])}} & fifo_w_data[ibuf_index]);
    end
    else begin: U_gen_ibuf_wctrl_another
        assign temp_ibuf_wen  [ibuf_index] = temp_ibuf_wen  [ibuf_index - 1] | (push_is_valid[ibuf_index] & (ibuf_sel == wdata_poi_n[ibuf_index][IBUF_ADDR_W-1:0]));
        assign temp_ibuf_wdata[ibuf_index] = temp_ibuf_wdata[ibuf_index - 1] | ({BLOCK_BIT_NUM + FTQ_ENTRY_BIT_NUM + 36{push_is_valid[ibuf_index] & 
                                                (ibuf_sel == wdata_poi_n[ibuf_index][IBUF_ADDR_W-1:0])}} & fifo_w_data[ibuf_index]);
    end
end
endgenerate

assign ibuf_wen     = temp_ibuf_wen  [IFU_INST_MAX_NUM -1];
assign ibuf_wdata   = temp_ibuf_wdata[IFU_INST_MAX_NUM -1];

endmodule //gen_ibuf_wctrl
