module gmii_tx (
    input                           tx_clk,
    input                           rst_n,

    output  [7:0]                   gmii_txd,
    output                          gmii_tx_en,
    output                          gmii_tx_er,
    //todo half duplex
    input                           gmii_crs,
    input                           gmii_col,

    input                           ether_en,
    //todo half duplex
    input                           fden,
    input                           tfc_pause,
    input                           tx_stop,
    output                          tx_mac_stop,
    input                           mii_select,
    input                           pause_send,
    output                          pause_mac_send,
    input                           pause_send_zero,
    output                          pause_mac_send_zero,
    input                           crcfwd,
    input                           addins,
    input  [13:0]                   max_fl,

    output                          tx_data_fifo_Rready,
    input  [7:0]                    tx_data_fifo_data_cnt,
    input  [63:0]                   tx_data_fifo_rdata,

    output                          tx_frame_fifo_i_Wready,
    output [7:0]                    tx_frame_fifo_i_wdata,

    output                          tx_frame_fifo_o_Rready,
    input  [5:0]                    tx_frame_fifo_o_data_cnt,
    input  [19:0]                   tx_frame_fifo_o_rdata,

    input  [31:0]                   palr,
    input  [31:0]                   paur,
    input  [31:0]                   opd,
    input                           strfwd,
    input  [7:0]                    tfwr,
    input  [7:0]                    taem,
    input  [15:0]                   tipg
);

wire [7:0]  pause_frame[25:8];
wire [7:0]  pause_zero_frame[25:8];

assign pause_frame[8]  = 8'h01;
assign pause_frame[9]  = 8'h80;
assign pause_frame[10] = 8'hC2;
assign pause_frame[11] = 8'h00;
assign pause_frame[12] = 8'h00;
assign pause_frame[13] = 8'h01;
assign pause_frame[14] = palr[31:24];
assign pause_frame[15] = palr[23:16];
assign pause_frame[16] = palr[15:8];
assign pause_frame[17] = palr[7:0];
assign pause_frame[18] = paur[31:24];
assign pause_frame[19] = paur[23:16];
assign pause_frame[20] = paur[15:8];
assign pause_frame[21] = paur[7:0];
assign pause_frame[22] = opd[31:24];
assign pause_frame[23] = opd[23:16];
assign pause_frame[24] = opd[15:8];
assign pause_frame[25] = opd[7:0];

assign pause_zero_frame[8]  = 8'h01;
assign pause_zero_frame[9]  = 8'h80;
assign pause_zero_frame[10] = 8'hC2;
assign pause_zero_frame[11] = 8'h00;
assign pause_zero_frame[12] = 8'h00;
assign pause_zero_frame[13] = 8'h01;
assign pause_zero_frame[14] = palr[31:24];
assign pause_zero_frame[15] = palr[23:16];
assign pause_zero_frame[16] = palr[15:8];
assign pause_zero_frame[17] = palr[7:0];
assign pause_zero_frame[18] = paur[31:24];
assign pause_zero_frame[19] = paur[23:16];
assign pause_zero_frame[20] = paur[15:8];
assign pause_zero_frame[21] = paur[7:0];
assign pause_zero_frame[22] = opd[31:24];
assign pause_zero_frame[23] = opd[23:16];
assign pause_zero_frame[24] = 8'h0;
assign pause_zero_frame[25] = 8'h0;

// output declaration of module crc32
wire [31:0] crc_out_next;
wire [31:0] crc_out;

// output declaration of module net_fifo_temp
wire [5:0] data_cnt;
//intr warp last tc
wire [3:0] rdata;

// output declaration of module frame_fifo
wire [2:0]   frame_data_cnt;
//desc_num: 22-17 tc: 16 data_len: 15-0
wire [22:0]  frame_rdata;

wire         frame_Wready;
wire         frame_Rready;
wire [22:0]  frame_wdata;
reg  [15:0]  frame_data_len;
reg  [5:0]   frame_desc_len;

reg          underrun;
reg  [5:0]   frame_desc_cnt;
reg  [5:0]   frame_desc_len_reg;
reg  [15:0]  frame_data_len_reg;

wire         frame_through_start = (tfwr == 8'h0) ? (tx_data_fifo_data_cnt > 8'h7) : (tx_data_fifo_data_cnt >= tfwr);
wire         frame_through_un    = (tx_data_fifo_data_cnt == taem) & (!(|frame_data_cnt));

// transmit fsm status
localparam TX_IDLE          = 3'h0;
localparam TX_STRFWD        = 3'h1;
localparam TX_THROUGH       = 3'h2;
localparam TX_UNDERRUN      = 3'h3;
localparam TX_SEND_PAUSE    = 3'h4;
localparam TX_SEND_ZERO     = 3'h5;
localparam TX_SEND_CRC      = 3'h6;
localparam TX_WAIT_IPG      = 3'h7;

reg  [2:0]      tx_status;
reg  [7:0]      txd;
reg             tx_en;
reg             tx_er;
reg             tx_mii_odd;
reg             tx_data_fifo_Rready_reg;
reg  [2:0]      tx_data_cnt;
reg             crc_en;
reg             crc_flush;

reg  [15:0]     tx_clk_cnt;

crc32 u_crc32(
    .clk          	(tx_clk        ),
    .rst_n        	(rst_n         ),
    .flush        	(crc_flush     ),
    .data_en      	(crc_en        ),
    .data_in      	(gmii_txd      ),
    .crc_out_next 	(crc_out_next  ),
    .crc_out      	(crc_out       )
);

net_fifo #(
    .DATA_WIDTH 	(4           ),
    .ADDR_WIDTH 	(6           ))
u_net_fifo_temp(
    .clk      	(tx_clk                         ),
    .rst_n    	(rst_n                          ),
    .Wready   	(tx_frame_fifo_o_Rready         ),
    .Rready   	(tx_frame_fifo_i_Wready         ),
    .flush    	(!ether_en                      ),
    .wdata    	(tx_frame_fifo_o_rdata[19:16]   ),
    .data_cnt 	(data_cnt                       ),
    .rdata    	(rdata                          )
);

net_fifo #(
    .DATA_WIDTH 	(23          ),
    .ADDR_WIDTH 	(3           ))
u_frame_fifo(
    .clk      	(tx_clk         ),
    .rst_n    	(rst_n          ),
    .Wready   	(frame_Wready   ),
    .Rready   	(frame_Rready   ),
    .flush    	(!ether_en      ),
    .wdata    	(frame_wdata    ),
    .data_cnt 	(frame_data_cnt ),
    .rdata    	(frame_rdata    )
);

always @(posedge tx_clk or negedge rst_n) begin
    if(!rst_n)begin
        frame_data_len <= 16'h8;
        frame_desc_len <= 6'h0;
    end
    else if(!ether_en)begin
        frame_data_len <= 16'h8;
        frame_desc_len <= 6'h0;
    end
    else begin
        if(tx_frame_fifo_o_Rready & tx_frame_fifo_o_rdata[17])begin
            frame_data_len <= 16'h8;
            frame_desc_len <= 6'h0;
        end
        else if(tx_frame_fifo_o_Rready)begin
            frame_data_len <= frame_data_len + tx_frame_fifo_o_rdata[15:0];
            frame_desc_len <= frame_desc_len + 6'h1;
        end
    end
end
assign frame_Wready = tx_frame_fifo_o_Rready & tx_frame_fifo_o_rdata[17];
assign frame_wdata  = {(frame_desc_len + 6'h1), tx_frame_fifo_o_rdata[16], (frame_data_len + tx_frame_fifo_o_rdata[15:0])};

assign tx_frame_fifo_o_Rready   = (|tx_frame_fifo_o_data_cnt) & (data_cnt != 6'h3f);

always @(posedge tx_clk or negedge rst_n) begin
    if(!rst_n)begin
        underrun            <= 1'b0;
        frame_desc_len_reg  <= 6'h0;
        frame_desc_cnt      <= 6'h0;
        frame_data_len_reg  <= 16'h0;
    end
    else if(!ether_en)begin
        underrun            <= 1'b0;
        frame_desc_len_reg  <= 6'h0;
        frame_desc_cnt      <= 6'h0;
        frame_data_len_reg  <= 16'h0;
    end
    else if(frame_desc_len_reg != 6'h0)begin
        if(frame_desc_cnt == frame_desc_len_reg)begin
            frame_desc_len_reg  <= 6'h0;
            frame_desc_cnt      <= 6'h1;
        end
        else begin
            frame_desc_cnt      <= frame_desc_cnt + 6'h1;
        end
    end
    else if((tx_status == TX_STRFWD) & (tx_clk_cnt == frame_rdata[15:0]))begin
        underrun            <= 1'b0;
        frame_desc_len_reg  <= frame_rdata[22:17];
        frame_desc_cnt      <= 6'h1;
        frame_data_len_reg  <= frame_rdata[15:0];
    end
    else if((tx_status == TX_UNDERRUN) & (|frame_data_cnt) & (tx_clk_cnt == frame_rdata[15:0]))begin
        underrun            <= 1'b1;
        frame_desc_len_reg  <= frame_rdata[22:17];
        frame_desc_cnt      <= 6'h1;
        frame_data_len_reg  <= frame_rdata[15:0];
    end
end
assign tx_frame_fifo_i_Wready = (frame_desc_len_reg != 6'h0);
//TODO half duplex
assign tx_frame_fifo_i_wdata  = {rdata, 1'b0/* lc */, 1'b0/* rl */, underrun, (frame_data_len_reg > {2'b0, max_fl})};

assign frame_Rready           = ((tx_status == TX_STRFWD) & (tx_clk_cnt == frame_rdata[15:0])) | 
                                ((tx_status == TX_UNDERRUN) & (|frame_data_cnt) & (tx_clk_cnt == frame_rdata[15:0]));

always @(posedge tx_clk or negedge rst_n) begin
    if(!rst_n)begin
        tx_status               <= TX_IDLE;
        txd                     <= 8'h0;
        tx_en                   <= 1'b0;
        tx_er                   <= 1'b0;
        tx_mii_odd              <= 1'b0;
        tx_data_cnt             <= 3'h0;
        tx_data_fifo_Rready_reg <= 1'b0;
        crc_en                  <= 1'b0;
        crc_flush               <= 1'b1;
        tx_clk_cnt              <= 16'h0;
    end
    else if(!ether_en)begin
        tx_status               <= TX_IDLE;
        txd                     <= 8'h0;
        tx_en                   <= 1'b0;
        tx_er                   <= 1'b0;
        tx_mii_odd              <= 1'b0;
        tx_data_cnt             <= 3'h0;
        tx_data_fifo_Rready_reg <= 1'b0;
        crc_en                  <= 1'b0;
        crc_flush               <= 1'b1;
        tx_clk_cnt              <= 16'h0;
    end
    else if(tx_mii_odd)begin
        txd[3:0]                <= txd[7:4];
        tx_mii_odd              <= 1'b0;
        tx_data_fifo_Rready_reg <= 1'b0;
        crc_en                  <= 1'b0;
    end
    else begin
        case (tx_status)
            TX_IDLE: begin
                tx_data_fifo_Rready_reg <= 1'b0;
                crc_flush               <= 1'b1;
                crc_en                  <= 1'b0;
                if(pause_send | tfc_pause)begin
                    tx_status   <= TX_SEND_PAUSE;
                    tx_clk_cnt  <= 16'h0;
                end
                else if(pause_send_zero)begin
                    tx_status   <= TX_SEND_ZERO;
                    tx_clk_cnt  <= 16'h0;
                end
                else if((!tx_stop) & (|frame_data_cnt))begin
                    tx_status   <= TX_STRFWD;
                    tx_data_cnt <= 3'h0;
                    tx_clk_cnt  <= 16'h0;
                end
                else if((!tx_stop) & (!strfwd) & frame_through_start)begin
                    tx_status   <= TX_THROUGH;
                    tx_data_cnt <= 3'h0;
                    tx_clk_cnt  <= 16'h0;
                end
            end
            TX_SEND_PAUSE: begin
                crc_flush   <= 1'b0;
                tx_en       <= 1'b1;
                if(mii_select)begin
                    tx_mii_odd  <= 1'b1;
                end
                if(tx_clk_cnt < 16'd7) begin
                    txd         <= 8'h55;
                    tx_clk_cnt  <= tx_clk_cnt + 1'b1;
                end
                else if(tx_clk_cnt == 16'd7) begin
                    txd         <= 8'hD5;
                    tx_clk_cnt  <= tx_clk_cnt + 1'b1;
                end 
                else if(tx_clk_cnt < 16'd26) begin
                    crc_en      <= 1'b1;
                    txd         <= pause_frame[tx_clk_cnt];
                    tx_clk_cnt  <= tx_clk_cnt + 1'b1;
                end
                else if(tx_clk_cnt == 16'd59) begin
                    txd         <= 8'h00;
                    tx_clk_cnt  <= 16'h0;
                    tx_status   <= TX_SEND_CRC;
                end
                else begin
                    txd         <= 8'h00;
                    tx_clk_cnt  <= tx_clk_cnt + 1'b1;
                end
            end
            TX_SEND_ZERO: begin
                crc_flush   <= 1'b0;
                tx_en       <= 1'b1;
                if(mii_select)begin
                    tx_mii_odd  <= 1'b1;
                end
                if(tx_clk_cnt < 16'd7) begin
                    txd         <= 8'h55;
                    tx_clk_cnt  <= tx_clk_cnt + 1'b1;
                end
                else if(tx_clk_cnt == 16'd7) begin
                    txd         <= 8'hD5;
                    tx_clk_cnt  <= tx_clk_cnt + 1'b1;
                end 
                else if(tx_clk_cnt < 16'd26) begin
                    crc_en      <= 1'b1;
                    txd         <= pause_zero_frame[tx_clk_cnt];
                    tx_clk_cnt  <= tx_clk_cnt + 1'b1;
                end
                else if(tx_clk_cnt == 16'd59) begin
                    txd         <= 8'h00;
                    tx_clk_cnt  <= 16'h0;
                    tx_status   <= TX_SEND_CRC;
                end
                else begin
                    txd         <= 8'h00;
                    tx_clk_cnt  <= tx_clk_cnt + 1'b1;
                end
            end
            TX_STRFWD: begin
                crc_flush   <= 1'b0;
                tx_en       <= 1'b1;
                if(mii_select)begin
                    tx_mii_odd  <= 1'b1;
                end
                if(tx_clk_cnt < 16'd7) begin
                    txd         <= 8'h55;
                    tx_clk_cnt  <= tx_clk_cnt + 1'b1;
                end
                else if(tx_clk_cnt == 16'd7) begin
                    txd         <= 8'hD5;
                    tx_clk_cnt  <= tx_clk_cnt + 1'b1;
                end 
                else if((tx_clk_cnt < 16'd14) & addins) begin
                    if(tx_data_cnt == 3'h0)begin
                        txd         <= palr[31:24];
                    end
                    else if(tx_data_cnt == 3'h1)begin
                        txd         <= palr[23:16];
                    end
                    else if(tx_data_cnt == 3'h2)begin
                        txd         <= palr[15:8];
                    end
                    else if(tx_data_cnt == 3'h3)begin
                        txd         <= palr[7:0];
                    end
                    else if(tx_data_cnt == 3'h4)begin
                        txd         <= paur[31:24];
                    end
                    else if(tx_data_cnt == 3'h5)begin
                        txd         <= paur[23:16];
                    end
                    tx_data_cnt             <= tx_data_cnt + 1'b1;
                    tx_clk_cnt              <= tx_clk_cnt + 16'h1;
                end
                else if((tx_clk_cnt == frame_rdata[15:0]) & (crcfwd | frame_rdata[16])) begin
                    if(tx_data_cnt != 3'h7)begin
                        tx_data_fifo_Rready_reg <= 1'b1;
                    end
                    else begin
                        tx_data_fifo_Rready_reg <= 1'b0;
                    end
                    tx_en                   <= 1'b0;
                    tx_data_cnt             <= 3'h0;
                    tx_clk_cnt              <= 16'h1;
                    tx_status               <= TX_WAIT_IPG;
                end
                else if((tx_clk_cnt == frame_rdata[15:0])) begin
                    if(tx_data_cnt != 3'h7)begin
                        tx_data_fifo_Rready_reg <= 1'b1;
                    end
                    else begin
                        tx_data_fifo_Rready_reg <= 1'b0;
                    end
                    txd                     <= crc_out_next[31:24];
                    tx_data_cnt             <= 3'h0;
                    tx_clk_cnt              <= 16'h0;
                    tx_status               <= TX_SEND_CRC;
                end
                else begin
                    if(tx_data_cnt == 3'h0)begin
                        txd         <= tx_data_fifo_rdata[7:0];
                        tx_data_cnt <= tx_data_cnt + 1'b1;
                    end
                    else if(tx_data_cnt == 3'h1)begin
                        txd         <= tx_data_fifo_rdata[15:8];
                        tx_data_cnt <= tx_data_cnt + 1'b1;
                    end
                    else if(tx_data_cnt == 3'h2)begin
                        txd         <= tx_data_fifo_rdata[23:16];
                        tx_data_cnt <= tx_data_cnt + 1'b1;
                    end
                    else if(tx_data_cnt == 3'h3)begin
                        txd         <= tx_data_fifo_rdata[31:24];
                        tx_data_cnt <= tx_data_cnt + 1'b1;
                    end
                    else if(tx_data_cnt == 3'h4)begin
                        txd         <= tx_data_fifo_rdata[39:32];
                        tx_data_cnt <= tx_data_cnt + 1'b1;
                    end
                    else if(tx_data_cnt == 3'h5)begin
                        txd         <= tx_data_fifo_rdata[47:40];
                        tx_data_cnt <= tx_data_cnt + 1'b1;
                    end
                    else if(tx_data_cnt == 3'h6)begin
                        tx_data_fifo_Rready_reg <= 1'b1;
                        txd                     <= tx_data_fifo_rdata[55:48];
                        tx_data_cnt             <= tx_data_cnt + 1'b1;
                    end
                    else if(tx_data_cnt == 3'h7)begin
                        tx_data_fifo_Rready_reg <= 1'b0;
                        txd                     <= tx_data_fifo_rdata[63:56];
                        tx_data_cnt             <= 3'h0;
                    end
                    tx_clk_cnt  <= tx_clk_cnt + 1'b1;
                end
            end
            TX_THROUGH: begin
                crc_flush   <= 1'b0;
                tx_en       <= 1'b1;
                if(mii_select)begin
                    tx_mii_odd  <= 1'b1;
                end
                if(tx_clk_cnt < 16'd7) begin
                    txd         <= 8'h55;
                    tx_clk_cnt  <= tx_clk_cnt + 1'b1;
                end
                else if(tx_clk_cnt == 16'd7) begin
                    txd         <= 8'hD5;
                    tx_clk_cnt  <= tx_clk_cnt + 1'b1;
                end 
                else if(frame_through_un)begin
                    tx_er                   <= 1'b1;
                    tx_data_fifo_Rready_reg <= 1'b0;
                    tx_status               <= TX_UNDERRUN;
                end
                else if((tx_clk_cnt < 16'd14) & addins) begin
                    if(tx_data_cnt == 3'h0)begin
                        txd         <= palr[31:24];
                    end
                    else if(tx_data_cnt == 3'h1)begin
                        txd         <= palr[23:16];
                    end
                    else if(tx_data_cnt == 3'h2)begin
                        txd         <= palr[15:8];
                    end
                    else if(tx_data_cnt == 3'h3)begin
                        txd         <= palr[7:0];
                    end
                    else if(tx_data_cnt == 3'h4)begin
                        txd         <= paur[31:24];
                    end
                    else if(tx_data_cnt == 3'h5)begin
                        txd         <= paur[23:16];
                    end
                    tx_data_cnt             <= tx_data_cnt + 1'b1;
                    tx_clk_cnt              <= tx_clk_cnt + 16'h1;
                end
                else if((|frame_data_cnt) & (tx_clk_cnt == frame_rdata[15:0]) & (crcfwd | frame_rdata[16])) begin
                    if(tx_data_cnt != 3'h7)begin
                        tx_data_fifo_Rready_reg <= 1'b1;
                    end
                    else begin
                        tx_data_fifo_Rready_reg <= 1'b0;
                    end
                    tx_en                   <= 1'b0;
                    tx_data_cnt             <= 3'h0;
                    tx_clk_cnt              <= 16'h1;
                    tx_status               <= TX_WAIT_IPG;
                end
                else if((|frame_data_cnt) & (tx_clk_cnt == frame_rdata[15:0])) begin
                    if(tx_data_cnt != 3'h7)begin
                        tx_data_fifo_Rready_reg <= 1'b1;
                    end
                    else begin
                        tx_data_fifo_Rready_reg <= 1'b0;
                    end
                    txd                     <= crc_out_next[31:24];
                    tx_data_cnt             <= 3'h0;
                    tx_clk_cnt              <= 16'h0;
                    tx_status               <= TX_SEND_CRC;
                end
                else begin
                    if(tx_data_cnt == 3'h0)begin
                        txd         <= tx_data_fifo_rdata[7:0];
                        tx_data_cnt <= tx_data_cnt + 1'b1;
                    end
                    else if(tx_data_cnt == 3'h1)begin
                        txd         <= tx_data_fifo_rdata[15:8];
                        tx_data_cnt <= tx_data_cnt + 1'b1;
                    end
                    else if(tx_data_cnt == 3'h2)begin
                        txd         <= tx_data_fifo_rdata[23:16];
                        tx_data_cnt <= tx_data_cnt + 1'b1;
                    end
                    else if(tx_data_cnt == 3'h3)begin
                        txd         <= tx_data_fifo_rdata[31:24];
                        tx_data_cnt <= tx_data_cnt + 1'b1;
                    end
                    else if(tx_data_cnt == 3'h4)begin
                        txd         <= tx_data_fifo_rdata[39:32];
                        tx_data_cnt <= tx_data_cnt + 1'b1;
                    end
                    else if(tx_data_cnt == 3'h5)begin
                        txd         <= tx_data_fifo_rdata[47:40];
                        tx_data_cnt <= tx_data_cnt + 1'b1;
                    end
                    else if(tx_data_cnt == 3'h6)begin
                        tx_data_fifo_Rready_reg <= 1'b1;
                        txd                     <= tx_data_fifo_rdata[55:48];
                        tx_data_cnt             <= tx_data_cnt + 1'b1;
                    end
                    else if(tx_data_cnt == 3'h7)begin
                        tx_data_fifo_Rready_reg <= 1'b0;
                        txd                     <= tx_data_fifo_rdata[63:56];
                        tx_data_cnt             <= 3'h0;
                    end
                    tx_clk_cnt  <= tx_clk_cnt + 1'b1;
                end
            end
            TX_UNDERRUN: begin
                tx_en       <= 1'b0;
                tx_er       <= 1'b0;
                if((|frame_data_cnt) & (tx_clk_cnt == frame_rdata[15:0])) begin
                    if(tx_data_cnt != 3'h7)begin
                        tx_data_fifo_Rready_reg <= 1'b1;
                    end
                    else begin
                        tx_data_fifo_Rready_reg <= 1'b0;
                    end
                    tx_data_cnt             <= 3'h0;
                    tx_clk_cnt              <= 16'h0;
                    tx_status               <= TX_WAIT_IPG;
                end
                else if(|frame_data_cnt)begin
                    if(tx_data_cnt == 3'h0)begin
                        tx_data_cnt <= tx_data_cnt + 1'b1;
                    end
                    else if(tx_data_cnt == 3'h1)begin
                        tx_data_cnt <= tx_data_cnt + 1'b1;
                    end
                    else if(tx_data_cnt == 3'h2)begin
                        tx_data_cnt <= tx_data_cnt + 1'b1;
                    end
                    else if(tx_data_cnt == 3'h3)begin
                        tx_data_cnt <= tx_data_cnt + 1'b1;
                    end
                    else if(tx_data_cnt == 3'h4)begin
                        tx_data_cnt <= tx_data_cnt + 1'b1;
                    end
                    else if(tx_data_cnt == 3'h5)begin
                        tx_data_cnt <= tx_data_cnt + 1'b1;
                    end
                    else if(tx_data_cnt == 3'h6)begin
                        tx_data_fifo_Rready_reg <= 1'b1;
                        tx_data_cnt             <= tx_data_cnt + 1'b1;
                    end
                    else if(tx_data_cnt == 3'h7)begin
                        tx_data_fifo_Rready_reg <= 1'b0;
                        tx_data_cnt             <= 3'h0;
                    end
                    tx_clk_cnt  <= tx_clk_cnt + 1'b1;
                end
            end
            TX_SEND_CRC: begin
                tx_data_fifo_Rready_reg <= 1'b0;
                tx_en                   <= 1'b1;
                crc_en                  <= 1'b0;
                if(mii_select)begin
                    tx_mii_odd  <= 1'b1;
                end 
                if((tx_clk_cnt == 16'd0) & (!mii_select)) begin
                    txd         <= crc_out_next[31:24];
                    tx_clk_cnt  <= tx_clk_cnt + 1'b1;
                end
                else if((tx_clk_cnt == 16'd0) & mii_select) begin
                    txd         <= crc_out[31:24];
                    tx_clk_cnt  <= tx_clk_cnt + 1'b1;
                end
                else if(tx_clk_cnt == 16'd1) begin
                    txd         <= crc_out[23:16];
                    tx_clk_cnt  <= tx_clk_cnt + 1'b1;
                end 
                else if(tx_clk_cnt == 16'd2) begin
                    txd         <= crc_out[15:8];
                    tx_clk_cnt  <= tx_clk_cnt + 1'b1;
                end
                else if(tx_clk_cnt == 16'd3) begin
                    txd         <= crc_out[7:0];
                    tx_clk_cnt  <= 16'h1;
                    tx_status   <= TX_WAIT_IPG;
                end
            end
            TX_WAIT_IPG: begin
                tx_data_fifo_Rready_reg <= 1'b0;
                tx_en                   <= 1'b0;
                tx_er                   <= 1'b0;
                if(mii_select)begin
                    tx_mii_odd          <= 1'b1;
                end 
                if(tx_clk_cnt == tipg) begin
                    tx_clk_cnt          <= 16'h0;
                    tx_status           <= TX_IDLE;
                end
                else begin
                    tx_clk_cnt          <= tx_clk_cnt + 1'b1;
                end
            end
            default: begin
                tx_status <= TX_IDLE;
            end
        endcase
    end
end
assign tx_data_fifo_Rready  = tx_data_fifo_Rready_reg;
assign gmii_txd             = txd;
assign gmii_tx_en           = tx_en;
assign gmii_tx_er           = tx_er;
assign tx_mac_stop          = (tx_status == TX_IDLE);
assign pause_mac_send       = ((tx_clk_cnt == 16'd59) && (tx_status == TX_SEND_PAUSE));
assign pause_mac_send_zero  = ((tx_clk_cnt == 16'd59) && (tx_status == TX_SEND_ZERO ));

endmodule //gmii_tx
