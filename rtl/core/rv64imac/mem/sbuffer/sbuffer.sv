module sbuffer
import sb_pkg::*;
import mem_pkg::*;
(
    input                                               clk,
    input                                               rst_n,

    output                                              StoreQueue_can_write_sb,
    input                                               StoreQueue2StoreBuffer_valid,
    /* verilator lint_off UNUSEDSIGNAL */
    input  [63:0]                                       StoreQueue_mem_waddr_o,
    /* verilator lint_on UNUSEDSIGNAL */
    input  [63:0]                                       StoreQueue_mem_wdata_o,
    input  [ 7:0]                                       StoreQueue_mem_wstrb_o,

    // load query interface
    /* verilator lint_off UNUSEDSIGNAL */
    input  [63:0]                                       load_paddr2sb,
    /* verilator lint_on UNUSEDSIGNAL */
    input  [7:0]                                        load_rstrb2sb,
    output [63:0]                                       sb_load_data,
    output [7:0]                                        sb_load_rstrb,

    // interface with fence_i
    input                                               flush_i_valid,
    output                                              flush_i_ready_sb,
    // interface with atomicUnit
    input                                               atomicUnit_invalid_sb_valid,
    output                                              atomicUnit_invalid_sb_ready,

    output                                              sbuffer_req_valid,
    input                                               sbuffer_req_ready,
    output [63:0]                                       sbuffer_req_waddr,
    output [15:0]                                       sbuffer_req_wstrb,
    output [127:0]                                      sbuffer_req_wdata,
    output [sb_line_bit - 1 : 0]                        sbuffer_req_index,

    input                                               sbuffer_resp_valid,
    output                                              sbuffer_resp_ready,
    input  [sb_line_bit - 1 : 0]                        sbuffer_resp_index
);

logic [sb_line - 1 : 0] StoreBuffer_valid;
logic [sb_line - 1 : 0] StoreBuffer_inflight;
logic [sb_line - 1 : 0] StoreBuffer_wait_same;
logic [19:0]            StoreBuffer_timer[sb_line - 1 : 0];
StoreBufferline         StoreBuffer[sb_line - 1 : 0];
StoreBufferline         StoreBuffer_send;

logic          [sb_line - 1 : 0] sb_line_wen;
StoreBufferline[sb_line - 1 : 0] sb_line_nxt;

logic                       sb_flush_req;
logic                       sb_timerout_req;
logic                       sb_threshold_req;
logic [sb_line_bit - 1 : 0] sb_flush_index;
logic [sb_line_bit - 1 : 0] sb_timerout_index;
logic [sb_line_bit - 1 : 0] sb_threshold_index;

logic                       sb_send_stage0_req;
logic                       sb_send_stage0_resp;
logic [sb_line_bit - 1 : 0] sb_send_stage0_req_index;

logic                       sb_send_stage1_valid;
logic                       sb_send_stage1_ready;
logic [sb_line_bit - 1 : 0] sb_send_stage1_index;

logic                       sb_send_stage2_valid;
logic                       sb_send_stage2_ready;
logic [sb_line_bit - 1 : 0] sb_send_stage2_index;
logic [63:0]                sb_send_stage2_waddr;
logic [15:0]                sb_send_stage2_wstrb;
logic [127:0]               sb_send_stage2_wdata;

logic [sb_line_bit - 1 : 0] sb_valid_num[sb_line - 1 : 0]/* verilator split_var */;
logic [sb_line - 1 : 0]     sb_send_index_valid;
/* verilator lint_off UNUSEDSIGNAL */
//! TODO need to use assert sb_way_replace_index[sb_line_bit]
logic [sb_line_bit     : 0] sb_way_replace_index;
/* verilator lint_on UNUSEDSIGNAL */
logic                       sb_flush_valid[sb_line - 1 : 0]/* verilator split_var */;
logic [sb_line_bit - 1 : 0] sb_flush_index_sel[sb_line - 1 : 0]/* verilator split_var */;
logic                       sb_timeout_valid[sb_line - 1 : 0]/* verilator split_var */;
logic [sb_line_bit - 1 : 0] sb_timeout_index_sel[sb_line - 1 : 0]/* verilator split_var */;

logic                       sb_early_bypass_valid[sb_line - 1 : 0]/* verilator split_var */;
logic [sb_line_bit - 1 : 0] sb_early_bypass_index_sel[sb_line - 1 : 0]/* verilator split_var */;
logic                       sb_late_bypass_valid[sb_line - 1 : 0]/* verilator split_var */;
logic [sb_line_bit - 1 : 0] sb_late_bypass_index_sel[sb_line - 1 : 0]/* verilator split_var */;
/* verilator lint_off UNUSEDSIGNAL */
StoreBufferline             StoreBuffer_early_bypass;
StoreBufferline             StoreBuffer_late_bypass;
/* verilator lint_on UNUSEDSIGNAL */
logic [7:0]                 sb_early_bypass_wstrb;
logic [63:0]                sb_early_bypass_wdata;
logic [7:0]                 sb_late_bypass_wstrb;
logic [63:0]                sb_late_bypass_wdata;

logic [sb_line - 1 : 0]     sb_can_write;
logic [sb_line_bit - 1 : 0] sb_write_index[sb_line - 1 : 0]/* verilator split_var */;
logic [sb_line - 1 : 0]     sb_addr_hit;
logic [sb_line - 1 : 0]     sb_addr_hit_but_same_send;
logic [sb_line_bit - 1 : 0] sb_write_index_sel[sb_line - 1 : 0]/* verilator split_var */;

logic [15:0]                sq_wstrb;
assign sq_wstrb = StoreQueue_mem_waddr_o[3] ? {8'h0, StoreQueue_mem_wstrb_o} : {StoreQueue_mem_wstrb_o, 8'h0};

logic [127:0]               sq_wdata;
assign sq_wdata = StoreQueue_mem_waddr_o[3] ? {64'h0, StoreQueue_mem_wdata_o} : {StoreQueue_mem_wdata_o, 64'h0};

genvar line_index;
generate for(line_index = 0 ; line_index < sb_line; line_index = line_index + 1) begin : U_gen_sb_line
    logic           sb_line_inflight_set;
    logic           sb_line_inflight_clr;

    if(line_index == 0)begin : U_gen_sb_write_index_0
        assign sb_can_write[line_index]         = (!StoreBuffer_valid[line_index]);

        assign sb_valid_num[line_index]         = {{(sb_line_bit - 1){1'b0}}, (StoreBuffer_valid[line_index] & (!StoreBuffer_inflight[line_index]) & (!StoreBuffer_wait_same[line_index]))};

        assign sb_flush_valid[line_index]       = (StoreBuffer_valid[line_index] & (!StoreBuffer_inflight[line_index]) & (!StoreBuffer_wait_same[line_index]));
        assign sb_flush_index_sel[line_index]   = line_index;

        assign sb_timeout_valid[line_index]     = (StoreBuffer_valid[line_index] & (!StoreBuffer_inflight[line_index]) & (!StoreBuffer_wait_same[line_index]) & StoreBuffer_timer[line_index][19]);
        assign sb_timeout_index_sel[line_index] = line_index;

        assign sb_early_bypass_valid[line_index]        = (StoreBuffer_valid[line_index] & (!StoreBuffer_wait_same[line_index]) & (StoreBuffer[line_index].line_addr == load_paddr2sb[63:4]));
        assign sb_early_bypass_index_sel[line_index]    = line_index;
        assign sb_late_bypass_valid[line_index]         = (StoreBuffer_valid[line_index] &   StoreBuffer_wait_same[line_index]  & (StoreBuffer[line_index].line_addr == load_paddr2sb[63:4]));
        assign sb_late_bypass_index_sel[line_index]     = line_index;

        assign sb_write_index[line_index]       = line_index;
        assign sb_write_index_sel[line_index]   = line_index;
    end
    else begin : U_gen_sb_write_index_other
        assign sb_can_write[line_index]         = ((!StoreBuffer_valid[line_index]) | sb_can_write[line_index - 1]);

        assign sb_valid_num[line_index]         = sb_valid_num[line_index - 1] + {{(sb_line_bit - 1){1'b0}}, (StoreBuffer_valid[line_index] & (!StoreBuffer_inflight[line_index]) & (!StoreBuffer_wait_same[line_index]))};

        assign sb_flush_valid[line_index]       = ((StoreBuffer_valid[line_index] & (!StoreBuffer_inflight[line_index]) & (!StoreBuffer_wait_same[line_index])) | sb_flush_valid[line_index - 1]);
        assign sb_flush_index_sel[line_index]   = sb_flush_valid[line_index - 1] ? sb_flush_index_sel[line_index - 1] : line_index;

        assign sb_timeout_valid[line_index]     = ((StoreBuffer_valid[line_index] & (!StoreBuffer_inflight[line_index]) & (!StoreBuffer_wait_same[line_index]) & StoreBuffer_timer[line_index][19]) | sb_timeout_valid[line_index - 1]);
        assign sb_timeout_index_sel[line_index] = sb_timeout_valid[line_index - 1] ? sb_timeout_index_sel[line_index - 1] : line_index;
    
        assign sb_early_bypass_valid[line_index]        = ((StoreBuffer_valid[line_index] & (!StoreBuffer_wait_same[line_index]) & (StoreBuffer[line_index].line_addr == load_paddr2sb[63:4])) | sb_early_bypass_valid[line_index - 1]);
        assign sb_early_bypass_index_sel[line_index]    = sb_early_bypass_valid[line_index - 1] ? sb_early_bypass_index_sel[line_index - 1] : line_index;
        assign sb_late_bypass_valid[line_index]         = ((StoreBuffer_valid[line_index] &   StoreBuffer_wait_same[line_index]  & (StoreBuffer[line_index].line_addr == load_paddr2sb[63:4])) | sb_late_bypass_valid[line_index - 1]);
        assign sb_late_bypass_index_sel[line_index]     = sb_late_bypass_valid[line_index - 1] ? sb_late_bypass_index_sel[line_index - 1] : line_index;

        assign sb_write_index[line_index]       = sb_can_write[line_index - 1] ? sb_write_index[line_index - 1] : line_index;
        assign sb_write_index_sel[line_index]   = (!sb_line_wen[line_index]) ? sb_write_index_sel[line_index - 1] : line_index;
    end
    assign sb_addr_hit[line_index]                  = (StoreBuffer_valid[line_index] & (StoreBuffer[line_index].line_addr == StoreQueue_mem_waddr_o[63:4]) & 
                                                        (!StoreBuffer_inflight[line_index]));
    assign sb_addr_hit_but_same_send[line_index]    = (StoreBuffer_valid[line_index] & (StoreBuffer[line_index].line_addr == StoreQueue_mem_waddr_o[63:4]));
    assign sb_send_index_valid[line_index]          = (StoreBuffer_valid[line_index] & (!StoreBuffer_inflight[line_index]) & (!StoreBuffer_wait_same[line_index]));

    logic [127:0] recv_update_data;
    //! 由于不好作参数化，所以用此行为级建模
    integer i;
    always_comb begin : cal_recv_update_data
        recv_update_data = 0;
        for(i = 0; i < 16; i = i + 1)begin
            recv_update_data[8 * i + 7 -: 8] = (sq_wstrb[i]) ? sq_wdata[8 * i + 7 -: 8] : StoreBuffer[line_index].line[8 * i + 7 -: 8];
        end
    end

    assign sb_line_wen[line_index]              = StoreQueue2StoreBuffer_valid & 
                                                (sb_addr_hit[line_index] | ((!(|sb_addr_hit)) & sb_can_write[sb_line - 1] & (line_index == sb_write_index[sb_line - 1])));
    assign sb_line_nxt[line_index].line_addr    = StoreQueue_mem_waddr_o[63:4]                                                                  ;
    assign sb_line_nxt[line_index].line_strb    = sq_wstrb | (StoreBuffer_valid[line_index] ? StoreBuffer[line_index].line_strb : 16'h0)        ;
    assign sb_line_nxt[line_index].line         = recv_update_data                                                                              ;

    logic StoreBuffer_valid_wen;
    logic StoreBuffer_valid_nxt;
    assign StoreBuffer_valid_wen = (sb_line_wen[line_index] | sb_line_inflight_clr);
    assign StoreBuffer_valid_nxt = (sb_line_wen[line_index] | (!sb_line_inflight_clr));
    FF_D_with_wen #(
        .DATA_LEN 	( 1 ),
        .RST_DATA 	( 0 )
    )u_StoreBuffer_valid
    (
        .clk        ( clk                           ),
        .rst_n      ( rst_n                         ),
        .wen        ( StoreBuffer_valid_wen         ),
        .data_in    ( StoreBuffer_valid_nxt         ),
        .data_out   ( StoreBuffer_valid[line_index] )
    );
    logic StoreBuffer_inflight_wen;
    logic StoreBuffer_inflight_nxt;
    assign sb_line_inflight_set     = sb_send_stage0_req & sb_send_stage0_resp & (sb_send_stage0_req_index == line_index);
    assign sb_line_inflight_clr     = sbuffer_resp_valid & sbuffer_resp_ready & (sbuffer_resp_index == line_index);
    assign StoreBuffer_inflight_wen = (sb_line_inflight_set | sb_line_inflight_clr);
    assign StoreBuffer_inflight_nxt = (sb_line_inflight_set | (!sb_line_inflight_clr));
    FF_D_with_wen #(
        .DATA_LEN 	( 1 ),
        .RST_DATA 	( 0 )
    )u_StoreBuffer_inflight
    (
        .clk        ( clk                               ),
        .rst_n      ( rst_n                             ),
        .wen        ( StoreBuffer_inflight_wen          ),
        .data_in    ( StoreBuffer_inflight_nxt          ),
        .data_out   ( StoreBuffer_inflight[line_index]  )
    );
    /* verilator lint_off UNUSEDSIGNAL */
    StoreBufferline         StoreBuffer_resp;
    /* verilator lint_on UNUSEDSIGNAL */
    assign StoreBuffer_resp = StoreBuffer[sbuffer_resp_index];
    logic StoreBuffer_wait_same_set;
    logic StoreBuffer_wait_same_clr;
    logic StoreBuffer_wait_same_wen;
    logic StoreBuffer_wait_same_nxt;
    assign StoreBuffer_wait_same_set = (|sb_addr_hit_but_same_send) & (!(|sb_addr_hit)) & sb_line_wen[line_index] & 
                                    ((!(sbuffer_resp_valid & sbuffer_resp_ready)) | (StoreQueue_mem_waddr_o[63:4] != StoreBuffer_resp.line_addr));
    assign StoreBuffer_wait_same_clr = sbuffer_resp_valid & sbuffer_resp_ready & (StoreBuffer[line_index].line_addr == StoreBuffer_resp.line_addr);
    assign StoreBuffer_wait_same_wen = (StoreBuffer_wait_same_set | StoreBuffer_wait_same_clr);
    assign StoreBuffer_wait_same_nxt = (StoreBuffer_wait_same_set | (!StoreBuffer_wait_same_clr));
    FF_D_with_wen #(
        .DATA_LEN 	( 1 ),
        .RST_DATA 	( 0 )
    )u_StoreBuffer_wait_same
    (
        .clk        ( clk                               ),
        .rst_n      ( rst_n                             ),
        .wen        ( StoreBuffer_wait_same_wen         ),
        .data_in    ( StoreBuffer_wait_same_nxt         ),
        .data_out   ( StoreBuffer_wait_same[line_index] )
    );
    logic           StoreBuffer_timer_wen;
    logic [19:0]    StoreBuffer_timer_nxt;
    assign StoreBuffer_timer_wen = (StoreBuffer_valid[line_index] & (!StoreBuffer_inflight[line_index]) & (!StoreBuffer_timer[line_index][19]));
    assign StoreBuffer_timer_nxt = (StoreBuffer_timer[line_index] + 20'h1);
    FF_D_with_syn_rst #(
        .DATA_LEN 	( 20 ),
        .RST_DATA 	( 0  )
    )u_StoreBuffer_timer
    (
        .clk        ( clk                               ),
        .rst_n      ( rst_n                             ),
        .syn_rst    ( (!StoreBuffer_valid[line_index])  ),
        .wen        ( StoreBuffer_timer_wen             ),
        .data_in    ( StoreBuffer_timer_nxt             ),
        .data_out   ( StoreBuffer_timer[line_index]     )
    );
    FF_D_without_asyn_rst #(SB_LINE_W)    u_line     (clk,sb_line_wen[line_index], sb_line_nxt[line_index], StoreBuffer[line_index]);
end
endgenerate

assign StoreBuffer_early_bypass = StoreBuffer[sb_early_bypass_index_sel[sb_line - 1]];
assign StoreBuffer_late_bypass  = StoreBuffer[sb_late_bypass_index_sel[sb_line - 1]];
assign sb_early_bypass_wstrb    = {8{sb_early_bypass_valid[sb_line - 1]}} & (load_paddr2sb[3] ? StoreBuffer_early_bypass.line_strb[15:8] : StoreBuffer_early_bypass.line_strb[7:0]);
assign sb_early_bypass_wdata    = load_paddr2sb[3] ? StoreBuffer_early_bypass.line[127:64] : StoreBuffer_early_bypass.line[63:0];
assign sb_late_bypass_wstrb     = {8{sb_late_bypass_valid[sb_line - 1]}} & (load_paddr2sb[3] ? StoreBuffer_late_bypass.line_strb[15:8] : StoreBuffer_late_bypass.line_strb[7:0]);
assign sb_late_bypass_wdata     = load_paddr2sb[3] ? StoreBuffer_late_bypass.line[127:64] : StoreBuffer_late_bypass.line[63:0];

assign sb_load_data             = data_splicing_64(sb_early_bypass_wdata, sb_late_bypass_wdata, sb_late_bypass_wstrb);
assign sb_load_rstrb            = ((sb_early_bypass_wstrb | sb_late_bypass_wstrb) & load_rstrb2sb);

plru_with_valid #(
    .way_num 	(sb_line  ))
u_plru_with_valid(
    .clk               	(clk                                ),
    .rst_n             	(rst_n                              ),
    .way_valid         	(sb_send_index_valid                ),
    .way_access        	((|sb_line_wen)                     ),
    .way_access_index  	(sb_write_index_sel[sb_line - 1]    ),
    .way_replace_index 	(sb_way_replace_index               )
);

assign sb_flush_req         = (sb_flush_valid[sb_line - 1] & (flush_i_valid | atomicUnit_invalid_sb_valid));
assign sb_timerout_req      = sb_timeout_valid[sb_line - 1];
assign sb_threshold_req     = (sb_valid_num[sb_line - 1] > sb_send_th);
assign sb_flush_index       = sb_flush_index_sel[sb_line - 1];
assign sb_timerout_index    = sb_timeout_index_sel[sb_line - 1];
assign sb_threshold_index   = sb_way_replace_index[sb_line_bit - 1 : 0];

assign sb_send_stage0_req       = (sb_flush_req | sb_timerout_req | sb_threshold_req);
assign sb_send_stage0_resp      = ((!sb_send_stage1_valid) | sb_send_stage1_ready);
assign sb_send_stage0_req_index = sb_flush_req ? sb_flush_index : (sb_timerout_req ? sb_timerout_index : sb_threshold_index);

FF_D_with_wen #(
    .DATA_LEN 	( 1  ),
    .RST_DATA 	( 0  )
)u_sb_send_stage1_valid
(
    .clk      	( clk                   ),
    .rst_n    	( rst_n                 ),
    .wen        ( sb_send_stage0_resp   ),
    .data_in  	( sb_send_stage0_req    ),
    .data_out 	( sb_send_stage1_valid  )
);
FF_D_without_asyn_rst #(sb_line_bit)    u_sb_send_stage1_index (clk, (sb_send_stage0_req & sb_send_stage0_resp), sb_send_stage0_req_index, sb_send_stage1_index);

assign sb_send_stage1_ready = ((!sb_send_stage2_valid) | sb_send_stage2_ready);
logic send_valid_stage2;
assign send_valid_stage2 = sb_send_stage1_valid & sb_send_stage1_ready;
FF_D_with_wen #(
    .DATA_LEN 	( 1  ),
    .RST_DATA 	( 0  )
)u_sb_send_stage2_valid
(
    .clk      	( clk                   ),
    .rst_n    	( rst_n                 ),
    .wen        ( sb_send_stage1_ready  ),
    .data_in  	( sb_send_stage1_valid  ),
    .data_out 	( sb_send_stage2_valid  )
);
assign StoreBuffer_send = StoreBuffer[sb_send_stage1_index];
FF_D_without_asyn_rst #(sb_line_bit)    u_sb_send_stage2_index (clk,send_valid_stage2, sb_send_stage1_index, sb_send_stage2_index);
FF_D_without_asyn_rst #(64)             u_sb_send_stage2_waddr (clk,send_valid_stage2, {StoreBuffer_send.line_addr, 4'h0}, sb_send_stage2_waddr);
FF_D_without_asyn_rst #(16)             u_sb_send_stage2_wstrb (clk,send_valid_stage2, StoreBuffer_send.line_strb, sb_send_stage2_wstrb);
FF_D_without_asyn_rst #(128)            u_sb_send_stage2_wdata (clk,send_valid_stage2, StoreBuffer_send.line, sb_send_stage2_wdata);

assign StoreQueue_can_write_sb      = ((|sb_addr_hit) | sb_can_write[sb_line - 1]);

assign flush_i_ready_sb             = (!(|StoreBuffer_valid));
assign atomicUnit_invalid_sb_ready  = (!(|StoreBuffer_valid));

assign sbuffer_req_valid    = sb_send_stage2_valid;
assign sb_send_stage2_ready = sbuffer_req_ready;
assign sbuffer_req_waddr    = sb_send_stage2_waddr;
assign sbuffer_req_wstrb    = sb_send_stage2_wstrb;
assign sbuffer_req_wdata    = sb_send_stage2_wdata;
assign sbuffer_req_index    = sb_send_stage2_index;

assign sbuffer_resp_ready           = 1'b1;

endmodule //sbuffer
