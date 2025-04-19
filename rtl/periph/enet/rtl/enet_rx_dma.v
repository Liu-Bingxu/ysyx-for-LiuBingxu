module enet_rx_dma #(
    parameter AXI_ID_SB = 3,

    // Address width in bits
    parameter AXI_ADDR_W = 32,
    // ID width in bits
    parameter AXI_ID_W = 8,
    // Data width in bits
    parameter AXI_DATA_W = 64
)(
    input                           rx_clk,
    input                           rst_n,

    input                           rdar_wen,

    output                          rdar,

    input                           ether_en,

    output                          rdar_rst,

    input  [7:0]                    rsfl,
    input  [7:0]                    raem,
    input  [31:0]                   rdsr,

    output                          eir_vld,
    input                           eir_rdy,
    output                          eir_babr,
    output                          eir_rxf,
    output                          eir_eberr,
    output                          eir_plr,

    output                          rx_data_fifo_Rready,
    input  [7:0]                    rx_data_fifo_data_cnt,
    input  [63:0]                   rx_data_fifo_rdata,

    output                          rx_frame_fifo_Rready,
    input  [5:0]                    rx_frame_fifo_data_cnt,
    //bit 26:Vlan; bit 25:frame_error; bit 24:M; bit 23:BC; bit 22:MC; bit  21:LG/babr; bit 20:NO; bit 19:CR; bit 18:OV; bit 17:TR;
    //bit 16:plr; bit 15-0:the length of the frame;
    input  [26:0]                    rx_frame_fifo_rdata,

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

// dma fsm status
localparam DMA_IDLE           = 4'h0;
localparam DMA_R_RXBD         = 4'h1;
localparam DMA_R_FRAME        = 4'h2;
localparam DMA_S_DATA_THROUGH = 4'h3;
localparam DMA_S_DATA         = 4'h4;
localparam DMA_R_DATA         = 4'h5;
localparam DMA_S_DESC         = 4'h6;
localparam DMA_REPORT_EIR     = 4'h7;
localparam DMA_ERROR_REPORT   = 4'h8;
localparam DMA_ERROR          = 4'h9;

reg  [3:0]              dma_status;
reg                     dma_w_er;
reg  [15:0]             dma_through_len;
reg  [15:0]             dma_through_b_len;

wire                    dma_read_though_flag = ((rx_data_fifo_data_cnt > rsfl) & (rsfl > raem));
wire                    dma_read_stop_flag   = (rx_data_fifo_data_cnt <= raem);

reg                     wrap;
reg  [AXI_ADDR_W -1:0]  rx_buf_point;
reg  [15:0]             rx_buf_offset;
reg  [AXI_ADDR_W -1:0]  rx_bd_point_offset;

wire                    Vlan;
wire                    frame_error;
wire                    M;
wire                    BC;
wire                    MC;
wire                    LG;
wire                    NO;
wire                    CR;
wire                    OV;
wire                    TR;
wire                    PLR;
wire [15:0]             len;
reg  [15:0]             data_quene_aw_len;
reg  [15:0]             data_quene_w_len;
reg  [15:0]             data_quene_b_len;
reg  [15:0]             data_quene_r_len;
assign {Vlan, frame_error, M, BC, MC, LG, NO, CR, OV, TR, PLR, len} = rx_frame_fifo_rdata;

reg                     Vlan_reg;
reg                     frame_error_reg;
reg                     M_reg;
reg                     BC_reg;
reg                     MC_reg;
reg                     LG_reg;
reg                     NO_reg;
reg                     CR_reg;
reg                     OV_reg;
reg                     TR_reg;
reg                     PLR_reg;
reg  [15:0]             len_reg;
wire [63:0]             rx_bd_update_data = {32'h0, 1'b0/* E */, Vlan_reg/* RO1/Vlan */, wrap, frame_error_reg/* RO2/frame_error */, 
                                            1'b1/* L */, 2'h0, M_reg, BC_reg, MC_reg, LG_reg, NO_reg, 1'b0, CR_reg, OV_reg, 
                                            TR_reg, len_reg[15:0]};

reg                     slv_arvalid_reg;

reg                     slv_awvalid_reg;
reg                     slv_aw_done;
reg                     slv_aw_wait;
reg                     slv_wvalid_reg;
reg                     slv_w_done;
reg                     slv_w_wait;
reg                     slv_wlast_reg;
reg  [1:0]              slv_wlast_cnt_reg;
wire [AXI_ADDR_W -1:0]  slv_awddr;

wire rdar_set   = rdar_wen;
wire rdar_clr   = (dma_status == DMA_R_RXBD) & slv_rvalid & slv_rready & slv_rlast & (slv_rid == AXI_ID_SB) & ((!slv_rdata[31]) | (slv_rresp != 2'h0));
wire rdar_wen_u = rdar_set | rdar_clr;
wire rdar_nxt   = rdar_set | (!rdar_clr);
FF_D_with_syn_rst #(
    .DATA_LEN 	(1  ),
    .RST_DATA 	(0  ))
u_rdar(
    .clk      	(rx_clk             ),
    .rst_n    	(rst_n              ),
    .syn_rst    (!ether_en          ),
    .wen      	(rdar_wen_u         ),
    .data_in  	(rdar_nxt           ),
    .data_out 	(rdar               )
);
assign rdar_rst = rdar_clr;

always @(posedge rx_clk or negedge rst_n) begin
    if(!rst_n)begin
        dma_status      <= DMA_IDLE;
        dma_w_er        <= 1'b0;
        dma_through_len <= 16'h0;
    end
    else if(!ether_en)begin
        dma_status      <= DMA_IDLE;
        dma_w_er        <= 1'b0;
        dma_through_len <= 16'h0;
    end
    else begin
        case (dma_status)
            DMA_IDLE: begin
                if(rdar)begin
                    dma_status      <= DMA_R_RXBD;
                end
            end
            DMA_R_RXBD: begin
                if(slv_rvalid & slv_rready & slv_rlast & (slv_rid == AXI_ID_SB) & slv_rdata[31] & (slv_rresp == 2'h0))begin
                    dma_status      <= DMA_R_FRAME;
                end
                else if(slv_rvalid & slv_rready & slv_rlast & (slv_rid == AXI_ID_SB) & (!slv_rdata[31]) & (slv_rresp == 2'h0))begin
                    dma_status      <= DMA_IDLE;
                end
                else if(slv_rvalid & slv_rready & (slv_rid == AXI_ID_SB) & (slv_rresp != 2'h0))begin
                    dma_status      <= DMA_ERROR_REPORT;
                end
            end
            DMA_R_FRAME: begin
                if(rx_frame_fifo_Rready & (LG | NO | CR | OV | TR))begin
                    dma_status      <= DMA_R_DATA;
                end
                else if(rx_frame_fifo_Rready)begin
                    dma_status      <= DMA_S_DATA;
                end
                else if(dma_read_though_flag)begin
                    dma_status      <= DMA_S_DATA_THROUGH;
                    dma_through_len <= 16'h0;
                end
            end
            DMA_S_DATA_THROUGH: begin
                if(slv_bvalid & slv_bready & (slv_bid == AXI_ID_SB) & (|rx_frame_fifo_data_cnt) & ((dma_through_len + 16'd8) >= len) & (slv_bresp == 2'h0))begin
                    dma_status      <= DMA_S_DESC;
                end
                else if(slv_bvalid & slv_bready & (slv_bid == AXI_ID_SB) & (slv_bresp != 2'h0))begin
                    dma_status      <= DMA_ERROR_REPORT;
                end
                else if(slv_bvalid & slv_bready & (slv_bid == AXI_ID_SB) & (slv_bresp == 2'h0))begin
                    dma_through_len <= dma_through_len + 16'd8;
                end
            end
            DMA_S_DATA: begin
                if(slv_bvalid & slv_bready & (slv_bid == AXI_ID_SB) & (data_quene_b_len < 16'h33) & ((slv_bresp != 2'h0) | dma_w_er))begin
                    dma_status      <= DMA_ERROR_REPORT;
                    dma_w_er        <= 1'b0;
                end
                else if(slv_bvalid & slv_bready & (slv_bid == AXI_ID_SB) & (data_quene_b_len < 16'h33) & (slv_bresp == 2'h0))begin
                    dma_status      <= DMA_S_DESC;
                end
                else if(slv_bvalid & slv_bready & (slv_bid == AXI_ID_SB) & (slv_bresp != 2'h0))begin
                    dma_w_er        <= 1'b1;
                end
            end
            DMA_R_DATA: begin
                if(data_quene_r_len < 16'h9)begin
                    dma_status      <= DMA_S_DESC;
                end
            end
            DMA_S_DESC: begin
                if(slv_bvalid & slv_bready & (slv_bid == AXI_ID_SB) & (slv_bresp == 2'h0))begin
                    dma_status      <= DMA_REPORT_EIR;
                end
                else if(slv_bvalid & slv_bready & (slv_bid == AXI_ID_SB) & (slv_bresp != 2'h0))begin
                    dma_status      <= DMA_ERROR_REPORT;
                end
            end
            DMA_REPORT_EIR: begin
                if(eir_vld & eir_rdy)begin
                    dma_status      <= DMA_R_RXBD;
                end
            end
            DMA_ERROR_REPORT: begin
                if(eir_vld & eir_rdy)begin
                    dma_status      <= DMA_ERROR;
                end
            end
            DMA_ERROR: begin
                //! nothing to do in here
            end
            default: begin
                dma_status          <= DMA_IDLE;
            end
        endcase
    end
end
assign eir_vld   = (eir_babr | eir_rxf | eir_eberr | eir_plr);
assign eir_babr  = (dma_status == DMA_REPORT_EIR) & LG_reg;
assign eir_rxf   = (dma_status == DMA_REPORT_EIR) ? 1'b1 : 1'b0;
assign eir_plr   = (dma_status == DMA_REPORT_EIR) & PLR_reg;
assign eir_eberr = (dma_status == DMA_ERROR_REPORT);
assign slv_awddr = (dma_status == DMA_S_DESC) ? (rdsr + rx_bd_point_offset) : (rx_buf_point + {16'h0, rx_buf_offset});

assign rx_data_fifo_Rready = ((slv_wvalid & slv_wready) | ((dma_status == DMA_R_DATA)));

assign rx_frame_fifo_Rready = ((dma_status == DMA_R_FRAME) & (|rx_frame_fifo_data_cnt)) | 
    ((dma_status == DMA_S_DATA_THROUGH) & slv_bvalid & slv_bready & (slv_bid == AXI_ID_SB) & 
    (|rx_frame_fifo_data_cnt) & ((dma_through_len + 16'd8) >= len) & (slv_bresp == 2'h0));

always @(posedge rx_clk or negedge rst_n) begin
    if(!rst_n)begin
        slv_arvalid_reg <= 1'b0;
    end
    else if(!ether_en)begin
        slv_arvalid_reg <= 1'b0;
    end
    else begin
        case (dma_status)
            DMA_IDLE: begin
                if(rdar)begin
                    slv_arvalid_reg <= 1'b1;
                end
            end
            DMA_R_RXBD: begin
                if(slv_arvalid & slv_arready)begin
                    slv_arvalid_reg <= 1'b0;
                end
            end
            DMA_REPORT_EIR: begin
                if(eir_vld & eir_rdy)begin
                    slv_arvalid_reg <= 1'b1;
                end
            end
            default: begin
                slv_arvalid_reg <= 1'b0;
            end
        endcase
    end
end

always @(posedge rx_clk or negedge rst_n) begin
    if(!rst_n)begin
        slv_awvalid_reg     <= 1'b0;
        slv_aw_done         <= 1'b0;
        slv_aw_wait         <= 1'b0;
        dma_through_b_len   <= 16'h0;
    end
    else if(!ether_en)begin
        slv_awvalid_reg     <= 1'b0;
        slv_aw_done         <= 1'b0;
        slv_aw_wait         <= 1'b0;
        dma_through_b_len   <= 16'h0;
    end
    else begin
        case (dma_status)
            DMA_R_FRAME: begin
                if(rx_frame_fifo_Rready & (!LG) & (!NO) & (!CR) & (!OV) & (!TR))begin
                    slv_awvalid_reg     <= 1'b1;
                end
                else if(dma_read_though_flag)begin
                    slv_awvalid_reg     <= 1'b1;
                    slv_aw_done         <= 1'b0;
                    slv_aw_wait         <= 1'b0;
                    dma_through_b_len   <= 16'h0;
                end
            end
            DMA_S_DATA_THROUGH: begin
                if(slv_bvalid & slv_bready & (slv_bid == AXI_ID_SB) & (|rx_frame_fifo_data_cnt) & ((dma_through_len + 16'd8) >= len) & (slv_bresp == 2'h0))begin
                    slv_awvalid_reg     <= 1'b1;
                    slv_aw_done         <= 1'b0;
                end
                else if(slv_awvalid & slv_awready & (|rx_frame_fifo_data_cnt) & ((dma_through_b_len + 16'd8) >= len))begin
                    slv_awvalid_reg     <= 1'b0;
                    slv_aw_done         <= 1'b1;
                end
                else if(slv_awvalid & slv_awready)begin
                    slv_awvalid_reg     <= 1'b0;
                    slv_aw_wait         <= 1'b1;
                end
                else if(slv_bvalid & slv_bready & (slv_bid == AXI_ID_SB) & (slv_bresp == 2'h0) & (!slv_aw_done) & ((!dma_read_stop_flag) | (|rx_frame_fifo_data_cnt)))begin
                    slv_awvalid_reg     <= 1'b1;
                    slv_aw_wait         <= 1'b0;
                    dma_through_b_len   <= dma_through_b_len + 16'h8;
                end
                else if(slv_bvalid & slv_bready & (slv_bid == AXI_ID_SB) & (slv_bresp == 2'h0))begin
                    slv_awvalid_reg     <= 1'b0;
                    slv_aw_wait         <= 1'b0;
                    dma_through_b_len   <= dma_through_b_len + 16'h8;
                end
                else if((!slv_aw_done) & (!slv_aw_wait) & ((!dma_read_stop_flag) | (|rx_frame_fifo_data_cnt)))begin
                    slv_awvalid_reg     <= 1'b1;
                end
            end
            DMA_S_DATA: begin
                if(slv_awvalid & slv_awready & (data_quene_aw_len < 16'd33))begin
                    slv_awvalid_reg <= 1'b0;
                end
                else if(slv_bvalid & slv_bready & (slv_bid == AXI_ID_SB) & (data_quene_b_len < 16'h33) & (slv_bresp == 2'h0) & (!dma_w_er))begin
                    slv_awvalid_reg <= 1'b1;
                end
            end
            DMA_R_DATA: begin
                if(data_quene_r_len < 16'h9)begin
                    slv_awvalid_reg <= 1'b1;
                end
            end
            DMA_S_DESC: begin
                if(slv_awvalid & slv_awready)begin
                    slv_awvalid_reg <= 1'b0;
                end
            end
            default: begin
                slv_awvalid_reg <= 1'b0;
            end
        endcase
    end
end

always @(posedge rx_clk or negedge rst_n) begin
    if(!rst_n)begin
        slv_wvalid_reg  <= 1'b0;
        slv_w_done      <= 1'b0;
        slv_w_wait      <= 1'b0;
    end
    else if(!ether_en)begin
        slv_wvalid_reg  <= 1'b0;
        slv_w_done      <= 1'b0;
        slv_w_wait      <= 1'b0;
    end
    else begin
        case (dma_status)
            DMA_R_FRAME: begin
                if(rx_frame_fifo_Rready & (!LG) & (!NO) & (!CR) & (!OV) & (!TR))begin
                    slv_wvalid_reg <= 1'b1;
                end
                else if(dma_read_though_flag)begin
                    slv_wvalid_reg <= 1'b1;
                    slv_w_done     <= 1'b0;
                    slv_w_wait     <= 1'b0;
                end
            end
            DMA_S_DATA_THROUGH: begin
                if(slv_bvalid & slv_bready & (slv_bid == AXI_ID_SB) & (|rx_frame_fifo_data_cnt) & ((dma_through_len + 16'd8) >= len) & (slv_bresp == 2'h0))begin
                    slv_wvalid_reg     <= 1'b1;
                    slv_w_done         <= 1'b0;
                end
                else if(slv_wvalid & slv_wready & (|rx_frame_fifo_data_cnt) & ((dma_through_b_len + 16'd8) >= len))begin
                    slv_wvalid_reg     <= 1'b0;
                    slv_w_done         <= 1'b1;
                end
                else if(slv_wvalid & slv_wready)begin
                    slv_wvalid_reg     <= 1'b0;
                    slv_w_wait         <= 1'b1;
                end
                else if(slv_bvalid & slv_bready & (slv_bid == AXI_ID_SB) & (slv_bresp == 2'h0) & (!slv_w_done) & ((!dma_read_stop_flag) | (|rx_frame_fifo_data_cnt)))begin
                    slv_wvalid_reg     <= 1'b1;
                    slv_w_wait         <= 1'b0;
                end
                else if(slv_bvalid & slv_bready & (slv_bid == AXI_ID_SB) & (slv_bresp == 2'h0))begin
                    slv_wvalid_reg     <= 1'b0;
                    slv_w_wait         <= 1'b0;
                end
                else if((!slv_w_done) & (!slv_w_wait) & ((!dma_read_stop_flag) | (|rx_frame_fifo_data_cnt)))begin
                    slv_wvalid_reg     <= 1'b1;
                end
            end
            DMA_S_DATA: begin
                if(slv_wvalid & slv_wready & (data_quene_w_len < 16'd9))begin
                    slv_wvalid_reg <= 1'b0;
                end
                else if(slv_bvalid & slv_bready & (slv_bid == AXI_ID_SB) & (data_quene_b_len < 16'h33) & (slv_bresp == 2'h0) & (!dma_w_er))begin
                    slv_wvalid_reg <= 1'b1;
                end
            end
            DMA_R_DATA: begin
                if(data_quene_r_len < 16'h9)begin
                    slv_wvalid_reg <= 1'b1;
                end
            end
            DMA_S_DESC: begin
                if(slv_wvalid & slv_wready)begin
                    slv_wvalid_reg <= 1'b0;
                end
            end
            default: begin
                slv_wvalid_reg  <= 1'b0;
            end
        endcase
    end
end

always @(posedge rx_clk or negedge rst_n) begin
    if(!rst_n)begin
        slv_wlast_reg       <= 1'b0;
        slv_wlast_cnt_reg   <= 2'h0;
    end
    else if(!ether_en)begin
        slv_wlast_reg       <= 1'b0;
        slv_wlast_cnt_reg   <= 2'h0;
    end
    else begin
        case (dma_status)
            DMA_R_FRAME: begin
                if(rx_frame_fifo_Rready & (!LG) & (!NO) & (!CR) & (!OV) & (!TR))begin
                    slv_wlast_reg       <= 1'b0;
                    slv_wlast_cnt_reg   <= 2'h0;
                end
                else if(rx_frame_fifo_Rready)begin
                    slv_wlast_reg       <= 1'b1;
                    slv_wlast_cnt_reg   <= 2'h0;
                end
                else if(dma_read_though_flag)begin
                    slv_wlast_reg       <= 1'b1;
                    slv_wlast_cnt_reg   <= 2'h0;
                end
            end
            DMA_S_DATA: begin
                if(slv_wvalid & slv_wready & (data_quene_w_len < 16'd17))begin
                    slv_wlast_reg <= 1'b1;
                end
                else if(slv_wvalid & slv_wready)begin
                    if(slv_wlast_cnt_reg == 2'h2)begin
                        slv_wlast_reg       <= 1'b1;
                        slv_wlast_cnt_reg   <= slv_wlast_cnt_reg + 2'h1;
                    end
                    else if(slv_wlast_cnt_reg == 2'h3)begin
                        slv_wlast_reg       <= 1'b0;
                        slv_wlast_cnt_reg   <= 2'h0;
                    end
                    else begin
                        slv_wlast_reg       <= 1'b0;
                        slv_wlast_cnt_reg   <= slv_wlast_cnt_reg + 2'h1;
                    end
                end
            end
            default: begin
                slv_wlast_reg  <= 1'b0;
            end
        endcase
    end
end

always @(posedge rx_clk) begin
    if((dma_status == DMA_R_FRAME) & rx_frame_fifo_Rready)begin
        data_quene_r_len <= len;
    end
    else if((dma_status == DMA_R_DATA))begin
        data_quene_r_len <= (data_quene_r_len - 16'd8);
    end
end

always @(posedge rx_clk) begin
    if((dma_status == DMA_R_FRAME) & rx_frame_fifo_Rready)begin
        data_quene_b_len <= len;
    end
    else if((dma_status == DMA_S_DATA) & slv_bvalid & slv_bready & (slv_bid == AXI_ID_SB))begin
        data_quene_b_len <= (data_quene_b_len - 16'd32);
    end
end

always @(posedge rx_clk) begin
    if((dma_status == DMA_R_FRAME) & rx_frame_fifo_Rready)begin
        data_quene_w_len <= len;
    end
    else if((dma_status == DMA_S_DATA) & slv_wvalid & slv_wready)begin
        data_quene_w_len <= (data_quene_w_len - 16'd8);
    end
end

always @(posedge rx_clk) begin
    if((dma_status == DMA_R_FRAME) & rx_frame_fifo_Rready)begin
        data_quene_aw_len <= len;
    end
    else if((dma_status == DMA_S_DATA) & slv_awvalid & slv_awready)begin
        data_quene_aw_len <= (data_quene_aw_len - 16'd32);
    end
end

always @(posedge rx_clk) begin
    if((dma_status == DMA_R_RXBD) & slv_rvalid & slv_rready & slv_rlast & (slv_rid == AXI_ID_SB))begin
        wrap         <= slv_rdata[29];
        rx_buf_point <= slv_rdata[63:32];
    end
end

always @(posedge rx_clk) begin
    if(rx_frame_fifo_Rready)begin
        Vlan_reg        <= Vlan;
        frame_error_reg <= frame_error;
        M_reg           <= M;
        BC_reg          <= BC;
        MC_reg          <= MC;
        LG_reg          <= LG;
        NO_reg          <= NO;
        CR_reg          <= CR;
        OV_reg          <= OV;
        TR_reg          <= TR;
        PLR_reg         <= PLR;
        len_reg         <= len;
    end
end

always @(posedge rx_clk or negedge rst_n) begin
    if(!rst_n)begin
        rx_bd_point_offset <= 32'h0;
    end
    else if(!ether_en)begin
        rx_bd_point_offset <= 32'h0;
    end
    else if(dma_status == DMA_R_RXBD)begin
        if(slv_rvalid & slv_rready & slv_rlast & (slv_rid == AXI_ID_SB) & slv_rdata[31] & slv_rdata[29])begin
            rx_bd_point_offset <= 32'h0;
        end
        else if(slv_rvalid & slv_rready & slv_rlast & (slv_rid == AXI_ID_SB) & slv_rdata[31])begin
            rx_bd_point_offset <= rx_bd_point_offset + 32'h8;
        end
    end
end

always @(posedge rx_clk) begin
    if(dma_status == DMA_R_RXBD)begin
        rx_buf_offset   <= 16'h0;
    end
    else if((dma_status == DMA_S_DATA_THROUGH) & slv_awvalid & slv_awready)begin
        rx_buf_offset   <= rx_buf_offset + 16'd8;
    end
    else if((dma_status == DMA_S_DATA) & slv_awvalid & slv_awready)begin
        rx_buf_offset   <= rx_buf_offset + 16'd32;
    end
end

assign slv_awvalid  = slv_awvalid_reg;
assign slv_awaddr   = slv_awddr;
assign slv_awlen    =   (dma_status == DMA_S_DATA_THROUGH   ) ? 8'h0 : 
                        (dma_status == DMA_S_DESC           ) ? 8'h0 : 
                        (data_quene_aw_len > 16'd24         ) ? 8'h3 : 
                        (data_quene_aw_len > 16'd16         ) ? 8'h2 : 
                        (data_quene_aw_len > 16'd8          ) ? 8'h1 : 
                        8'h0;
assign slv_awsize   = 3'h3;
assign slv_awburst  = 2'h1;
assign slv_awlock   = 1'b0;
assign slv_awcache  = 4'h0;
assign slv_awprot   = 3'h0;
assign slv_awqos    = 4'h0;
assign slv_awregion = 4'h0;
assign slv_awid     = AXI_ID_SB;
assign slv_wvalid   = slv_wvalid_reg;
assign slv_wlast    = slv_wlast_reg;
assign slv_wdata    = ((dma_status == DMA_S_DATA) | (dma_status == DMA_S_DATA_THROUGH)) ? rx_data_fifo_rdata : rx_bd_update_data;
assign slv_wstrb    = ((dma_status == DMA_S_DATA) | (dma_status == DMA_S_DATA_THROUGH)) ? 8'hFF : 8'hF;
assign slv_bready   = 1'b1;
assign slv_arvalid  = slv_arvalid_reg;
assign slv_araddr   = (rdsr + rx_bd_point_offset);
assign slv_arlen    = 8'h0;
assign slv_arsize   = 3'h3;
assign slv_arburst  = 2'h1;
assign slv_arlock   = 1'b0;
assign slv_arcache  = 4'h0;
assign slv_arprot   = 3'h0;
assign slv_arqos    = 4'h0;
assign slv_arregion = 4'h0;
assign slv_arid     = AXI_ID_SB;
assign slv_rready   = 1'b1;

endmodule //enet_rx_dma
