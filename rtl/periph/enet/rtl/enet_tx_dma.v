module enet_tx_dma #(
    parameter AXI_ID_SB = 3,

    // Address width in bits
    parameter AXI_ADDR_W = 32,
    // ID width in bits
    parameter AXI_ID_W = 8,
    // Data width in bits
    parameter AXI_DATA_W = 64
)(
    input                           tx_clk,
    input                           rst_n,

    input                           tdar_wen,

    output                          tdar,

    input                           ether_en,

    input  [7:0]                    tafl,
    input  [31:0]                   tdsr,

    output                          eir_vld,
    input                           eir_rdy,
    output                          eir_babt,
    output                          eir_txf,
    output                          eir_eberr,
    output                          eir_lc,
    output                          eir_rl,
    output                          eir_un,

    output                          tx_data_fifo_Wready,
    input  [7:0]                    tx_data_fifo_data_cnt,
    output [63:0]                   tx_data_fifo_wdata,

    output                          tx_frame_fifo_i_Rready,
    input  [5:0]                    tx_frame_fifo_i_data_cnt,
    input  [7:0]                    tx_frame_fifo_i_rdata,

    output                          tx_frame_fifo_o_Wready,
    input  [5:0]                    tx_frame_fifo_o_data_cnt,
    output [19:0]                   tx_frame_fifo_o_wdata,

    output                          slv_awvalid,
    input                           slv_awready,
    output [AXI_ADDR_W    -1:0]     slv_awaddr,
    output [8             -1:0]     slv_awlen,
    output [3             -1:0]     slv_awsize,
    output [2             -1:0]     slv_awburst,
    output                          slv_awlock,
    output [4             -1:0]     slv_awcache,
    output [3             -1:0]     slv_awprot,
    output [4             -1:0]     slv_awqos,
    output [4             -1:0]     slv_awregion,
    output [AXI_ID_W      -1:0]     slv_awid,
    output                          slv_wvalid,
    input                           slv_wready,
    output                          slv_wlast, 
    output [AXI_DATA_W    -1:0]     slv_wdata,
    output [AXI_DATA_W/8  -1:0]     slv_wstrb,
    input                           slv_bvalid,
    output                          slv_bready,
    input  [AXI_ID_W      -1:0]     slv_bid,
    input  [2             -1:0]     slv_bresp,
    output                          slv_arvalid,
    input                           slv_arready,
    output [AXI_ADDR_W    -1:0]     slv_araddr,
    output [8             -1:0]     slv_arlen,
    output [3             -1:0]     slv_arsize,
    output [2             -1:0]     slv_arburst,
    output                          slv_arlock,
    output [4             -1:0]     slv_arcache,
    output [3             -1:0]     slv_arprot,
    output [4             -1:0]     slv_arqos,
    output [4             -1:0]     slv_arregion,
    output [AXI_ID_W      -1:0]     slv_arid,
    input                           slv_rvalid,
    output                          slv_rready,
    input  [AXI_ID_W      -1:0]     slv_rid,
    input  [2             -1:0]     slv_rresp,
    input  [AXI_DATA_W    -1:0]     slv_rdata,
    input                           slv_rlast
);

// bus width assertions
initial begin
    if (AXI_ADDR_W != 32) begin
        $error("Error: Interface addr width must be 32");
        $finish;
    end

    if (AXI_DATA_W != 64) begin
        $error("Error: Interface data width must be 64");
        $finish;
    end
end

// dma send fsm status
localparam DMA_SEND_IDLE           = 3'h0;
localparam DMA_SEND_R_TXBD         = 3'h1;
localparam DMA_SEND_R_DATA         = 3'h3;
localparam DMA_SEND_S_FRAME        = 3'h2;
localparam DMA_SEND_ERROR_REPORT   = 3'h4;
localparam DMA_SEND_ERROR          = 3'h5;

reg  [2:0]              dma_send_status;

wire                    dma_send_eberr;

reg                     wrap;
reg                     intr;
reg                     last;
reg                     tc;
reg  [15:0]             data_len;
reg  [15:0]             data_quene_ar_len;
reg  [15:0]             data_quene_r_len;
reg  [AXI_ADDR_W -1:0]  tx_buf_point;
reg  [15:0]             tx_buf_offset;
reg                     tx_buf_done;
reg  [AXI_ADDR_W -1:0]  tx_bd_point_offset;

reg                     slv_arvalid_reg;
wire [AXI_ADDR_W -1:0]  slv_arddr;

//send addr but not recv data cnt unit is 64bit
reg  [7:0]              send_cnt;

wire                    report_wrap;
wire                    report_intr;
wire                    report_babt;
wire                    report_last;
wire                    report_tc;
wire                    report_lc;
wire                    report_rl;
wire                    report_un;

wire                    data_fifo_w_protect  = ((tx_data_fifo_data_cnt + send_cnt)  >  tafl  );
wire                    frame_fifo_w_protect = (tx_frame_fifo_o_data_cnt == 6'h3f );

// dma report fsm
localparam DMA_REPORT_IDLE          = 3'h0;
localparam DMA_REPORT_UPDATE        = 3'h1;
localparam DMA_REPORT_S_EIR         = 3'h3;
localparam DMA_REPORT_ERROR_REPORT  = 3'h5;
localparam DMA_REPORT_ERROR         = 3'h4;

reg  [2:0]              dma_report_status;

wire                    dma_report_eberr;

reg  [AXI_ADDR_W -1:0]  tx_bd_point_report_offset;

reg                     slv_awvalid_reg;
reg                     slv_wvalid_reg;
wire [AXI_ADDR_W -1:0]  slv_awddr;

wire tdar_set   = tdar_wen;
wire tdar_clr   = (dma_send_status == DMA_SEND_R_TXBD) & slv_rvalid & slv_rready & slv_rlast & (slv_rid == AXI_ID_SB) & ((!slv_rdata[31]) | (slv_rresp != 2'h0));
wire tdar_wen_u = tdar_set | tdar_clr;
wire tdar_nxt   = tdar_set | (!tdar_clr);
FF_D_with_syn_rst #(
    .DATA_LEN 	(1  ),
    .RST_DATA 	(0  ))
u_tdar(
    .clk      	(tx_clk             ),
    .rst_n    	(rst_n              ),
    .syn_rst    (!ether_en          ),
    .wen      	(tdar_wen_u         ),
    .data_in  	(tdar_nxt           ),
    .data_out 	(tdar               )
);

always @(posedge tx_clk or negedge rst_n) begin
    if(!rst_n)begin
        dma_send_status <= DMA_SEND_IDLE;
    end
    else if(!ether_en)begin
        dma_send_status <= DMA_SEND_IDLE;
    end
    else begin
        case (dma_send_status)
            DMA_SEND_IDLE: begin
                if(tdar)begin
                    dma_send_status <= DMA_SEND_R_TXBD;
                end
            end
            DMA_SEND_R_TXBD: begin
                if(slv_rvalid & slv_rready & slv_rlast & (slv_rid == AXI_ID_SB) & slv_rdata[31] & (slv_rresp == 2'h0))begin
                    dma_send_status <= DMA_SEND_R_DATA;
                end
                else if(slv_rvalid & slv_rready & slv_rlast & (slv_rid == AXI_ID_SB) & (!slv_rdata[31]) & (slv_rresp == 2'h0))begin
                    dma_send_status <= DMA_SEND_IDLE;
                end
                else if(slv_rvalid & slv_rready & (slv_rid == AXI_ID_SB) & (slv_rresp != 2'h0))begin
                    dma_send_status <= DMA_SEND_ERROR_REPORT;
                end
            end
            DMA_SEND_R_DATA: begin
                if(slv_rvalid & slv_rready & slv_rlast & (slv_rid == AXI_ID_SB) & (data_quene_r_len < 16'h9) & (slv_rresp == 2'h0))begin
                    dma_send_status <= DMA_SEND_S_FRAME;
                end
                else if(slv_rvalid & slv_rready & (slv_rid == AXI_ID_SB) & (slv_rresp != 2'h0))begin
                    dma_send_status <= DMA_SEND_ERROR_REPORT;
                end
            end
            DMA_SEND_S_FRAME: begin
                if(tx_frame_fifo_o_Wready & (!tdar))begin
                    dma_send_status <= DMA_SEND_IDLE;
                end
                else if(tx_frame_fifo_o_Wready)begin
                    dma_send_status <= DMA_SEND_R_TXBD;
                end
            end
            DMA_SEND_ERROR_REPORT: begin
                if(eir_vld & eir_rdy)begin
                    dma_send_status <= DMA_SEND_ERROR;
                end
            end
            DMA_SEND_ERROR: begin
                //! nothing to do in here
            end
            default: begin
                dma_send_status <= DMA_SEND_IDLE;
            end
        endcase
    end
end
assign dma_send_eberr = (dma_send_status == DMA_SEND_ERROR_REPORT);

assign tx_data_fifo_Wready    = (dma_send_status == DMA_SEND_R_DATA) & slv_rvalid & slv_rready & (slv_rid == AXI_ID_SB) & (slv_rresp == 2'h0) & (|send_cnt);
assign tx_data_fifo_wdata     = slv_rdata;
assign tx_frame_fifo_o_Wready = (dma_send_status == DMA_SEND_S_FRAME) & (!frame_fifo_w_protect);
assign tx_frame_fifo_o_wdata  = {intr, wrap, last,tc, data_len};
assign slv_arddr = (dma_send_status == DMA_SEND_R_TXBD) ? (tdsr + tx_bd_point_offset) : (tx_buf_point + {16'h0, tx_buf_offset});
always @(posedge tx_clk or negedge rst_n) begin
    if(!rst_n)begin
        tx_bd_point_offset <= 32'h0;
    end
    else if(!ether_en)begin
        tx_bd_point_offset <= 32'h0;
    end
    else if(dma_send_status == DMA_SEND_R_TXBD)begin
        if(slv_rvalid & slv_rready & slv_rlast & (slv_rid == AXI_ID_SB) & slv_rdata[31] & slv_rdata[29])begin
            tx_bd_point_offset <= 32'h0;
        end
        else if(slv_rvalid & slv_rready & slv_rlast & (slv_rid == AXI_ID_SB) & slv_rdata[31])begin
            tx_bd_point_offset <= tx_bd_point_offset + 32'h8;
        end
    end
end
always @(posedge tx_clk or negedge rst_n) begin
    if(!rst_n)begin
        slv_arvalid_reg <= 1'b0;
        tx_buf_done     <= 1'b0;
    end
    else if(!ether_en)begin
        slv_arvalid_reg <= 1'b0;
        tx_buf_done     <= 1'b0;
    end
    else begin
        case (dma_send_status)
            DMA_SEND_IDLE: begin
                if(tdar)begin
                    slv_arvalid_reg <= 1'b1;
                end
            end
            DMA_SEND_R_TXBD: begin
                if(slv_arvalid & slv_arready)begin
                    slv_arvalid_reg <= 1'b0;
                end
                else if(slv_rvalid & slv_rready & slv_rlast & (slv_rid == AXI_ID_SB) & slv_rdata[31] & (!data_fifo_w_protect))begin
                    slv_arvalid_reg <= 1'b1;
                end
            end
            DMA_SEND_R_DATA: begin
                if(slv_arvalid & slv_arready & (data_quene_ar_len < 16'd33))begin
                    slv_arvalid_reg <= 1'b0;
                    tx_buf_done     <= 1'b1;
                end
                else if(slv_arvalid & slv_arready & data_fifo_w_protect)begin
                    slv_arvalid_reg <= 1'b0;
                end
                else if((!tx_buf_done) & (!data_fifo_w_protect))begin
                    slv_arvalid_reg <= 1'b1;
                end
            end
            DMA_SEND_S_FRAME: begin
                tx_buf_done     <= 1'b0;
                if(tx_frame_fifo_o_Wready & tdar)begin
                    slv_arvalid_reg <= 1'b1;
                end
            end
            DMA_SEND_ERROR_REPORT, DMA_SEND_ERROR: begin
                slv_arvalid_reg <= 1'b0;
                tx_buf_done     <= 1'b0;
            end
            default: begin
                slv_arvalid_reg <= 1'b0;
                tx_buf_done     <= 1'b0;
            end
        endcase
    end
end
always @(posedge tx_clk) begin
    if((dma_send_status == DMA_SEND_R_TXBD) & slv_rvalid & slv_rready & slv_rlast & (slv_rid == AXI_ID_SB))begin
        wrap         <= slv_rdata[29];
        intr         <= slv_rdata[28];
        last         <= slv_rdata[27];
        tc           <= slv_rdata[26];
        data_len     <= slv_rdata[15:0];
        tx_buf_point <= slv_rdata[63:32];
    end
end
always @(posedge tx_clk) begin
    if(dma_send_status == DMA_SEND_R_TXBD)begin
        tx_buf_offset   <= 16'h0;
    end
    else if((dma_send_status == DMA_SEND_R_DATA) & slv_arvalid & slv_arready)begin
        tx_buf_offset   <= tx_buf_offset + 16'd32;
    end
end
always @(posedge tx_clk) begin
    if((dma_send_status == DMA_SEND_R_TXBD) & slv_rvalid & slv_rready & (slv_rid == AXI_ID_SB) & slv_rlast)begin
        data_quene_r_len <= slv_rdata[15:0];
    end
    else if((dma_send_status == DMA_SEND_R_DATA) & slv_rvalid & slv_rready & (slv_rid == AXI_ID_SB))begin
        data_quene_r_len <= (data_quene_r_len - 16'h8);
    end
end
always @(posedge tx_clk) begin
    if((dma_send_status == DMA_SEND_R_TXBD) & slv_rvalid & slv_rready & slv_rlast & (slv_rid == AXI_ID_SB))begin
        data_quene_ar_len <= slv_rdata[15:0];
    end
    else if((dma_send_status == DMA_SEND_R_DATA) & slv_arvalid & slv_arready)begin
        data_quene_ar_len <= (data_quene_ar_len - 16'd32);
    end
end
always @(posedge tx_clk or negedge rst_n) begin
    if(!rst_n)begin
        send_cnt <= 8'h0;
    end
    else if(!ether_en)begin
        send_cnt <= 8'h0;
    end
    else if(dma_send_status == DMA_SEND_R_DATA)begin
        if(slv_arvalid & slv_arready & slv_rvalid & slv_rready & (slv_rid == AXI_ID_SB))begin
            send_cnt <= send_cnt + slv_arlen;
        end
        else if(slv_arvalid & slv_arready)begin
            send_cnt <= send_cnt + slv_arlen + 1'b1;
        end
        else if(slv_rvalid & slv_rready & (slv_rid == AXI_ID_SB))begin
            send_cnt <= send_cnt - 8'h1;
        end
    end
end

//? report fsm
always @(posedge tx_clk or negedge rst_n) begin
    if(!rst_n)begin
        dma_report_status <= DMA_REPORT_IDLE;
    end
    else if(!ether_en)begin
        dma_report_status <= DMA_REPORT_IDLE;
    end
    else begin
        case (dma_report_status)
            DMA_REPORT_IDLE: begin
                if(|tx_frame_fifo_i_data_cnt)begin
                    dma_report_status <= DMA_REPORT_UPDATE;
                end
            end
            DMA_REPORT_UPDATE: begin
                if(slv_bvalid & slv_bready & (slv_bid == AXI_ID_SB) & (slv_bresp == 2'h0) & report_intr)begin
                    dma_report_status <= DMA_REPORT_S_EIR;
                end
                else if(slv_bvalid & slv_bready & (slv_bid == AXI_ID_SB) & (slv_bresp == 2'h0) & report_lc)begin
                    dma_report_status <= DMA_REPORT_S_EIR;
                end
                else if(slv_bvalid & slv_bready & (slv_bid == AXI_ID_SB) & (slv_bresp == 2'h0) & report_rl)begin
                    dma_report_status <= DMA_REPORT_S_EIR;
                end
                else if(slv_bvalid & slv_bready & (slv_bid == AXI_ID_SB) & (slv_bresp == 2'h0) & report_un)begin
                    dma_report_status <= DMA_REPORT_S_EIR;
                end
                else if(slv_bvalid & slv_bready & (slv_bid == AXI_ID_SB) & (slv_bresp == 2'h0))begin
                    dma_report_status <= DMA_REPORT_IDLE;
                end
                else if(slv_bvalid & slv_bready & (slv_bid == AXI_ID_SB) & (slv_bresp != 2'h0))begin
                    dma_report_status <= DMA_REPORT_ERROR_REPORT;
                end
            end
            DMA_REPORT_S_EIR: begin
                if(eir_vld & eir_rdy)begin
                    dma_report_status <= DMA_REPORT_IDLE;
                end
            end
            DMA_REPORT_ERROR_REPORT: begin
                if(eir_vld & eir_rdy)begin
                    dma_report_status <= DMA_REPORT_ERROR;
                end
            end
            DMA_REPORT_ERROR: begin
                //! nothing to do in here
            end
            default: begin
                dma_report_status <= DMA_REPORT_IDLE;
            end
        endcase
    end
end
assign dma_report_eberr       = (dma_report_status == DMA_REPORT_ERROR_REPORT);
assign tx_frame_fifo_i_Rready = ((dma_report_status == DMA_REPORT_UPDATE) & slv_bvalid & slv_bready & (slv_bid == AXI_ID_SB) & (slv_bresp == 2'h0) & (!(report_intr | report_lc | report_rl | report_un))) | 
                                ((dma_report_status == DMA_REPORT_S_EIR) & eir_vld & eir_rdy);

always @(posedge tx_clk or negedge rst_n) begin
    if(!rst_n)begin
        slv_awvalid_reg <= 1'b0;
        slv_wvalid_reg  <= 1'b0;
    end
    else if(!ether_en)begin
        slv_awvalid_reg <= 1'b0;
        slv_wvalid_reg  <= 1'b0;
    end
    else begin
        case (dma_report_status)
            DMA_REPORT_IDLE: begin
                if(|tx_frame_fifo_i_data_cnt)begin
                    slv_awvalid_reg <= 1'b1;
                    slv_wvalid_reg  <= 1'b1;
                end
            end
            DMA_REPORT_UPDATE: begin
                if(slv_awvalid & slv_awready & slv_wvalid & slv_wready)begin
                    slv_awvalid_reg <= 1'b0;
                    slv_wvalid_reg  <= 1'b0;
                end
                else if(slv_awvalid & slv_awready)begin
                    slv_awvalid_reg <= 1'b0;
                end
                else if(slv_wvalid & slv_wready)begin
                    slv_wvalid_reg  <= 1'b0;
                end
            end
            default: begin
                slv_awvalid_reg <= 1'b0;
                slv_wvalid_reg  <= 1'b0;
            end
        endcase
    end
end
assign slv_awddr = (tdsr + tx_bd_point_report_offset);
always @(posedge tx_clk or negedge rst_n) begin
    if(!rst_n)begin
        tx_bd_point_report_offset <= 32'h0;
    end
    else if(!ether_en)begin
        tx_bd_point_report_offset <= 32'h0;
    end
    else if(dma_report_status == DMA_REPORT_UPDATE)begin
        if(slv_bvalid & slv_bready & (slv_bid == AXI_ID_SB) & report_wrap)begin
            tx_bd_point_report_offset <= 32'h0;
        end
        else if(slv_bvalid & slv_bready & (slv_bid == AXI_ID_SB))begin
            tx_bd_point_report_offset <= tx_bd_point_report_offset + 32'h8;
        end
    end
end

assign eir_txf      = (dma_report_status == DMA_REPORT_S_EIR) & report_intr;
assign eir_babt     = (dma_report_status == DMA_REPORT_S_EIR) & report_babt;
assign eir_lc       = (dma_report_status == DMA_REPORT_S_EIR) & report_lc;
assign eir_rl       = (dma_report_status == DMA_REPORT_S_EIR) & report_rl;
assign eir_un       = (dma_report_status == DMA_REPORT_S_EIR) & report_un;

assign eir_eberr    = dma_send_eberr | dma_report_eberr;

assign eir_vld      = eir_babt | eir_txf | eir_eberr | eir_lc | eir_rl | eir_un;

assign slv_awvalid  = slv_awvalid_reg;
assign slv_awaddr   = slv_awddr;
assign slv_awlen    = 8'h0;
assign slv_awsize   = 3'h3;
assign slv_awburst  = 2'h1;
assign slv_awlock   = 1'b0;
assign slv_awcache  = 4'h0;
assign slv_awprot   = 3'h0;
assign slv_awqos    = 4'h0;
assign slv_awregion = 4'h0;
assign slv_awid     = AXI_ID_SB;
assign slv_wvalid   = slv_wvalid_reg;
assign slv_wlast    = 1'b1;
assign {report_intr, report_wrap, report_last, report_tc, report_lc, report_rl, report_un, report_babt} = tx_frame_fifo_i_rdata;
assign slv_wdata    = {32'h0, 1'b0,/* R */ 1'b0, /* TO1 */ report_wrap, report_intr, /* intr */ report_last, report_tc, 2'h0, 
                        report_lc, report_rl, 4'h0, report_un, 1'b0, 16'h0};
assign slv_wstrb    = 8'hC;
assign slv_bready   = 1'b1;
assign slv_arvalid  = slv_arvalid_reg;
assign slv_araddr   = slv_arddr;
assign slv_arlen    =   (dma_send_status == DMA_SEND_R_TXBD ) ? 8'h0 : 
                        (data_quene_ar_len > 16'd24         ) ? 8'h3 : 
                        (data_quene_ar_len > 16'd16         ) ? 8'h2 : 
                        (data_quene_ar_len > 16'd8          ) ? 8'h1 : 
                        8'h0;
assign slv_arsize   = 3'h3;
assign slv_arburst  = 2'h1;
assign slv_arlock   = 1'b0;
assign slv_arcache  = 4'h0;
assign slv_arprot   = 3'h0;
assign slv_arqos    = 4'h0;
assign slv_arregion = 4'h0;
assign slv_arid     = AXI_ID_SB;
assign slv_rready   = 1'b1;

endmodule //enet_tx_dma
