module gmii_rx (
    input                           rx_clk,
    input                           rst_n,

    input  [7:0]                    gmii_rxd,
    input                           gmii_rx_dv,
    input                           gmii_rx_er,
    //todo half duplex
    input                           gmii_crs,
    input                           gmii_col,

    input                           ether_en,
    input                           rdar_rst,
    //todo half duplex
    input                           drt,
    input                           mii_select,
    input                           nlc,
    input                           cfen,
    input                           crcfwd,
    input                           paufwd,
    input                           paden,
    input                           fce,
    input                           bc_rej,
    input                           prom,
    input  [13:0]                   max_fl,

    output                          rx_data_fifo_Wready,
    input  [7:0]                    rx_data_fifo_data_cnt,
    output [63:0]                   rx_data_fifo_wdata,

    output                          rx_frame_fifo_Wready,
    input  [5:0]                    rx_frame_fifo_data_cnt,
    //bit 26:Vlan; bit 25:frame_error; bit 24:M; bit 23:BC; bit 22:MC; bit  21:LG/babr; bit 20:NO; bit 19:CR; bit 18:OV; bit 17:TR;
    //bit 16:plr; bit 15-0:the length of the frame;
    output [26:0]                   rx_frame_fifo_wdata,

    output                          pause_req_in,
    input                           pause_rdy_in,
    //bit 17: 1-recv a pause frame; 0-need to send a pause
    //bit 16: 1-send a pause; 0-send a zero pause
    //bit 15-0: recv pause time
    output [17:0]                   pause_data_in,

    input  [31:0]                   palr,
    input  [15:0]                   paur,
    input  [31:0]                   ialr,
    input  [31:0]                   iaur,
    input  [31:0]                   galr,
    input  [31:0]                   gaur,
    input  [4:0]                    rsem_stat,
    input  [7:0]                    rsem_rx,
    input  [7:0]                    rafl,
    input  [13:0]                   ftrl
);

// transmit fsm status
localparam RX_IDLE          = 3'h0;
localparam RX_START_DA      = 3'h1;
localparam RX_WAIT_END      = 3'h2;
localparam RX_RECV_SA_TYPE  = 3'h3;
localparam RX_RECV_NORMAL   = 3'h4;
localparam RX_ROMVE_PAD     = 3'h5;
localparam RX_RECV_CONTROL  = 3'h6;

reg  [2:0]      rx_status;
reg  [15:0]     rx_status_cnt;

reg  [15:0]     rx_data_out_cnt;

reg  [3:0]      rx_data_cnt;
wire [0:0]      rx_data_finish_flag;
wire [3:0]      rx_data_add_cnt;

wire            rx_unicast_check_success;
wire            rx_multicast_check_success;

wire  [47:0]    pause_DA;
assign pause_DA[47:40]  = 8'h01;
assign pause_DA[39:32]  = 8'h80;
assign pause_DA[31:24]  = 8'hC2;
assign pause_DA[23:16]  = 8'h00;
assign pause_DA[15:8 ]  = 8'h00;
assign pause_DA[ 7:0 ]  = 8'h01;

reg  [7:0]      gmii_rx_Da[5:0];
reg  [7:0]      gmii_rx_Sa[1:0];
reg  [15:0]     gmii_rx_opcode;
reg  [7:0]      gmii_rx_p1;
reg  [7:0]      gmii_rx_p2;

reg  [15:0]     gmii_rx_type_len;

wire [7:0]      gmii_rxd_use;

reg  [7:0]      gmii_rxd_r[11:0];
reg             gmii_rxd_dv[11:0];
reg             gmii_rxd_er[11:0];

wire            vlan_flag;
reg             M_flag;
wire            MC_flag;
wire            BC_flag;
wire            plr_flag;
wire            pause_flag;

wire            LG_flag;
reg             lg_flag;

reg             mii_odd;

wire            data_fifo_w_protect;
assign data_fifo_w_protect = (rx_data_fifo_data_cnt >= rafl) ? 1'b1 : 1'b0;

wire            data_rsem_flag;
assign data_rsem_flag = ((rx_data_fifo_data_cnt >= rsem_rx) & (rsem_rx != 8'h0)) ? 1'b1 : 1'b0;
wire            frame_rsem_flag;
assign frame_rsem_flag = ((rx_frame_fifo_data_cnt >= {1'b0, rsem_stat}) & (rsem_stat != 5'h0)) ? 1'b1 : 1'b0;

// output declaration of module crc32
wire [31:0]     crc_out_next;
wire [31:0]     crc_out;
wire            crc_en;
wire            crc_flush;
wire            crc_check;

crc32 u_crc32(
    .clk          	(rx_clk        ),
    .rst_n        	(rst_n         ),
    .flush        	(crc_flush     ),
    .data_en      	(crc_en        ),
    .data_in      	(gmii_rxd_use  ),
    .crc_out_next 	(crc_out_next  ),
    .crc_out      	(crc_out       )
);

assign crc_check = (crc_out == {gmii_rxd_r[3], gmii_rxd_r[2], gmii_rxd_r[1], gmii_rxd_r[0]}) ? 1'b1 : 1'b0;

assign rx_unicast_check_success = (!gmii_rx_Da[0][0]) & 
                    (({gmii_rx_Da[0], gmii_rx_Da[1], gmii_rx_Da[2], gmii_rx_Da[3], gmii_rx_Da[4], gmii_rxd_use} == {palr, paur}) |
                    (iaur[crc_out_next[4:0]] & crc_out_next[5]) | (ialr[crc_out_next[4:0]] & (!crc_out_next[5])));

assign rx_multicast_check_success = gmii_rx_Da[0][0] & 
                    ((({gmii_rx_Da[0], gmii_rx_Da[1], gmii_rx_Da[2], gmii_rx_Da[3], gmii_rx_Da[4], gmii_rxd_use} == {48{1'b1}}) & (!bc_rej)) |
                    ({gmii_rx_Da[0], gmii_rx_Da[1], gmii_rx_Da[2], gmii_rx_Da[3], gmii_rx_Da[4], gmii_rxd_use} == {pause_DA}) |
                    (gaur[crc_out_next[4:0]] & crc_out_next[5]) | (galr[crc_out_next[4:0]] & (!crc_out_next[5])));

assign gmii_rxd_use = gmii_rxd_r[3];

assign vlan_flag    = (gmii_rx_type_len == 16'h8100);
assign MC_flag      = gmii_rx_Da[0][0];
assign BC_flag      = ({gmii_rx_Da[0], gmii_rx_Da[1], gmii_rx_Da[2], gmii_rx_Da[3], gmii_rx_Da[4], gmii_rx_Da[5]} == {48{1'b1}});
assign plr_flag     = (nlc & (rx_status == RX_RECV_NORMAL) & (gmii_rx_type_len < 16'h600) & (rx_status_cnt != {gmii_rx_type_len + 16'h12}));
assign pause_flag   = ((gmii_rx_type_len == 16'h8808) & (gmii_rx_opcode == 16'h0001));

assign crc_en       = (rx_status != RX_IDLE) & ((!mii_select) | mii_odd) & gmii_rxd_dv[3];
assign crc_flush    = (rx_status == RX_IDLE);

always @(posedge rx_clk or negedge rst_n) begin
    if(!rst_n)begin
        rx_status       <= RX_IDLE;
        rx_status_cnt   <= 16'h0;
    end
    else if((!ether_en) | rdar_rst)begin
        rx_status       <= RX_IDLE;
        rx_status_cnt   <= 16'h0;
    end
    else begin
        case (rx_status)
            RX_IDLE:begin
                if((gmii_rxd_use == 8'hD5) & (!gmii_rx_er) & gmii_rx_dv & ((!mii_select) | (gmii_rxd_dv[3] & (!gmii_rxd_er[3]))))begin
                    rx_status       <= RX_START_DA;
                    rx_status_cnt   <= 16'h0;
                    gmii_rx_opcode  <= 16'h0;
                end
            end
            RX_START_DA:begin
                if(!gmii_rx_dv)begin
                    rx_status       <= RX_IDLE;
                end
                else if(gmii_rx_er)begin
                    rx_status       <= RX_WAIT_END;
                end
                else if(gmii_rx_dv & ((!mii_select) | mii_odd))begin
                    gmii_rx_Da[rx_status_cnt[2:0]]  <= gmii_rxd_use;
                    if((rx_status_cnt == 16'h5) & (prom | rx_unicast_check_success | rx_multicast_check_success))begin
                        rx_status       <= RX_RECV_SA_TYPE;
                        rx_status_cnt   <= 16'h0;
                    end
                    else if((rx_status_cnt == 16'h5))begin
                        rx_status       <= RX_WAIT_END;
                        rx_status_cnt   <= 16'h0;
                    end
                    else begin
                        rx_status_cnt   <= rx_status_cnt + 1'b1;
                    end
                end
            end
            RX_WAIT_END:begin
                if(!gmii_rx_dv)begin
                    rx_status     <= RX_IDLE;
                end
            end
            RX_RECV_SA_TYPE:begin
                if(!gmii_rx_dv)begin
                    rx_status                   <= RX_IDLE;
                end
                else if(gmii_rx_er)begin
                    rx_status                   <= RX_WAIT_END;
                end
                else if(gmii_rx_dv & ((!mii_select) | mii_odd))begin
                    if((rx_status_cnt == 16'h7) & ({gmii_rx_type_len[15:8], gmii_rxd_use} == 16'h8808))begin
                        gmii_rx_type_len[7:0]   <= gmii_rxd_use;
                        rx_status               <= RX_RECV_CONTROL;
                        rx_status_cnt           <= 16'hE;
                    end
                    else if((rx_status_cnt == 16'h7))begin
                        gmii_rx_type_len[7:0]   <= gmii_rxd_use;
                        rx_status               <= RX_RECV_NORMAL;
                        rx_status_cnt           <= 16'hE;
                    end
                    else if((rx_status_cnt == 16'h6))begin
                        gmii_rx_type_len[15:8]  <= gmii_rxd_use;
                        rx_status_cnt           <= rx_status_cnt + 1'b1;
                    end
                    else if((rx_status_cnt == 16'h0))begin
                        gmii_rx_Sa[0]           <= gmii_rxd_use;
                        rx_status_cnt           <= rx_status_cnt + 1'b1;
                    end
                    else if((rx_status_cnt == 16'h1))begin
                        gmii_rx_Sa[1]           <= gmii_rxd_use;
                        rx_status_cnt           <= rx_status_cnt + 1'b1;
                    end
                    else begin
                        rx_status_cnt           <= rx_status_cnt + 1'b1;
                    end
                end
            end
            RX_RECV_NORMAL:begin
                if(!gmii_rx_dv)begin
                    rx_status       <= RX_IDLE;
                end
                else if(gmii_rx_er)begin
                    rx_status       <= RX_WAIT_END;
                end
                else if(data_fifo_w_protect)begin
                    rx_status       <= RX_WAIT_END;
                end
                else if(gmii_rx_dv & ((!mii_select) | mii_odd))begin
                    //! frame data too long
                    if((rx_status_cnt == {2'h0, ftrl}))begin
                        rx_status               <= RX_WAIT_END;
                    end
                    //! remove the pad
                    else if(paden & (gmii_rx_type_len < 16'h600) & (rx_status_cnt == {gmii_rx_type_len + 16'hD}))begin
                        rx_status               <= RX_ROMVE_PAD;
                    end
                    else begin
                        rx_status_cnt           <= rx_status_cnt + 1'b1;
                    end
                end
            end
            RX_ROMVE_PAD: begin
                if(!gmii_rx_dv)begin
                    rx_status     <= RX_IDLE;
                end
            end
            RX_RECV_CONTROL:begin
                if(!gmii_rx_dv)begin
                    rx_status       <= RX_IDLE;
                end
                else if(gmii_rx_er)begin
                    rx_status       <= RX_WAIT_END;
                end
                else if(data_fifo_w_protect)begin
                    rx_status       <= RX_WAIT_END;
                end
                else if(gmii_rx_dv & ((!mii_select) | mii_odd))begin
                    if((rx_status_cnt == 16'hE))begin
                        gmii_rx_opcode[15:8]    <= gmii_rxd_use;
                        rx_status_cnt           <= rx_status_cnt + 1'b1;
                    end
                    else if((rx_status_cnt == 16'hF))begin
                        gmii_rx_opcode[7:0]     <= gmii_rxd_use;
                        rx_status_cnt           <= rx_status_cnt + 1'b1;
                    end
                    else if((rx_status_cnt == 16'h10))begin
                        gmii_rx_p1              <= gmii_rxd_use;
                        rx_status_cnt           <= rx_status_cnt + 1'b1;
                    end
                    else if((rx_status_cnt == 16'h11))begin
                        gmii_rx_p2              <= gmii_rxd_use;
                        rx_status_cnt           <= rx_status_cnt + 1'b1;
                    end
                    //! frame data too long
                    else if((rx_status_cnt == {2'h0, ftrl}))begin
                        rx_status               <= RX_WAIT_END;
                    end
                    else begin
                        rx_status_cnt           <= rx_status_cnt + 1'b1;
                    end
                end
            end
            default:begin
                rx_status <= RX_IDLE;
            end
        endcase
    end
end

always @(posedge rx_clk) begin
    if(rx_status == RX_IDLE)begin
        lg_flag         <= 1'b0;
    end
    else if((rx_status == RX_RECV_NORMAL) & gmii_rx_dv & ((!mii_select) | mii_odd))begin
        if((rx_status_cnt == {2'h0, max_fl}))begin
            lg_flag         <= 1'b1;
        end
    end
    if((rx_status == RX_RECV_CONTROL) & gmii_rx_dv & ((!mii_select) | mii_odd))begin
        if((rx_status_cnt == {2'h0, max_fl}))begin
            lg_flag         <= 1'b1;
        end
    end
end
assign LG_flag = (lg_flag | (gmii_rx_dv & ((!mii_select) | mii_odd) & (rx_status_cnt == {2'h0, max_fl}) & ((rx_status == RX_RECV_NORMAL) | (rx_status == RX_RECV_CONTROL))));

genvar i;
generate
    for(i = 0; i < 12; i = i + 1)begin: gmii_rxd_reg
        if(i == 0)begin: gen_rxd_0
            always @(posedge rx_clk or negedge rst_n) begin
                if(!rst_n)begin
                    gmii_rxd_r[i]     <= 8'h0;
                    gmii_rxd_dv[i]    <= 1'b0;
                    gmii_rxd_er[i]    <= 1'b0;
                end
                else if((!ether_en) | rdar_rst)begin
                    gmii_rxd_r[i]     <= 8'h0;
                    gmii_rxd_dv[i]    <= 1'b0;
                    gmii_rxd_er[i]    <= 1'b0;
                end
                else if(mii_select & mii_odd)begin
                    gmii_rxd_r[i]     <= {gmii_rxd[3:0], gmii_rxd_r[i][7:4]};
                    gmii_rxd_dv[i]    <= gmii_rxd_dv[i] & gmii_rx_dv;
                    gmii_rxd_er[i]    <= gmii_rxd_er[i] | gmii_rx_er;
                end
                else if(mii_select)begin
                    gmii_rxd_r[i]     <= {gmii_rxd[3:0], gmii_rxd_r[i][7:4]};
                    gmii_rxd_dv[i]    <= gmii_rx_dv;
                    gmii_rxd_er[i]    <= gmii_rx_er;
                end
                else if(!mii_select)begin
                    gmii_rxd_r[i]     <= gmii_rxd;
                    gmii_rxd_dv[i]    <= gmii_rx_dv;
                    gmii_rxd_er[i]    <= gmii_rx_er;
                end
            end
        end
        else begin: gen_rxd_other
            always @(posedge rx_clk or negedge rst_n) begin
                if(!rst_n)begin
                    gmii_rxd_r[i]     <= 8'h0;
                    gmii_rxd_dv[i]    <= 1'b0;
                    gmii_rxd_er[i]    <= 1'b0;
                end
                else if((!ether_en) | rdar_rst)begin
                    gmii_rxd_r[i]     <= 8'h0;
                    gmii_rxd_dv[i]    <= 1'b0;
                    gmii_rxd_er[i]    <= 1'b0;
                end
                else if(mii_select & mii_odd)begin
                    gmii_rxd_r[i]     <= gmii_rxd_r[i - 1];
                    gmii_rxd_dv[i]    <= gmii_rxd_dv[i - 1] & gmii_rx_dv;
                    gmii_rxd_er[i]    <= gmii_rxd_er[i - 1];
                end
                else if(!mii_select)begin
                    gmii_rxd_r[i]     <= gmii_rxd_r[i - 1];
                    gmii_rxd_dv[i]    <= gmii_rxd_dv[i - 1] & gmii_rx_dv;
                    gmii_rxd_er[i]    <= gmii_rxd_er[i - 1];
                end
            end
        end
    end
endgenerate

always @(posedge rx_clk or negedge rst_n) begin
    if(!rst_n)begin
        mii_odd <= 1'b0;
    end
    else if((!ether_en) | rdar_rst)begin
        mii_odd <= 1'b0;
    end
    else if(mii_select & gmii_rx_dv & gmii_rxd_dv[3] & (rx_status == RX_IDLE) & (gmii_rxd_r[3] == 8'hD5))begin
        mii_odd <= 1'b0;
    end
    else if(mii_select)begin
        mii_odd <= ~mii_odd;
    end
    else if(!mii_select)begin
        mii_odd <= 1'b0;
    end
end

always @(posedge rx_clk or negedge rst_n) begin
    if(!rst_n)begin
        rx_data_cnt <= 4'h0;
    end
    else if((!ether_en) | rdar_rst)begin
        rx_data_cnt <= 4'h0;
    end
    else if((rx_status == RX_IDLE) & (gmii_rxd_use == 8'hD5) & (!gmii_rx_er) & gmii_rx_dv & ((!mii_select) | (gmii_rxd_dv[3] & (!gmii_rxd_er[3]))))begin
        rx_data_cnt <= 4'h3;
    end
    else if(( (paden | crcfwd)) & (rx_data_cnt == 4'hB) & gmii_rx_dv & ((!mii_select) | mii_odd))begin
        rx_data_cnt <= 4'h4;
    end
    else if((!(paden | crcfwd)) & (rx_data_cnt == 4'h7) & gmii_rx_dv & ((!mii_select) | mii_odd))begin
        rx_data_cnt <= 4'h0;
    end
    else if(gmii_rx_dv & ((!mii_select) | mii_odd))begin
        rx_data_cnt <= rx_data_cnt + 4'h1;
    end
end
assign rx_data_add_cnt = (paden | crcfwd) ? (rx_data_cnt - 4'h3) : (rx_data_cnt + 4'b1);
assign rx_data_finish_flag = (paden | crcfwd) ? (rx_data_cnt == 4'hB) : (rx_data_cnt == 4'h7);

always @(posedge rx_clk or negedge rst_n) begin
    if(!rst_n)begin
        rx_data_out_cnt <= 16'h0;
    end
    else if((!ether_en) | rdar_rst)begin
        rx_data_out_cnt <= 16'h0;
    end
    else if(rx_status == RX_IDLE)begin
        rx_data_out_cnt <= 16'h0;
    end
    else if(rx_data_fifo_Wready)begin
        rx_data_out_cnt <= rx_data_out_cnt + 16'h8;
    end
end

always @(posedge rx_clk or negedge rst_n) begin
    if(!rst_n)begin
        M_flag <= 1'h0;
    end
    else if((!ether_en) | rdar_rst)begin
        M_flag <= 1'h0;
    end
    else if(rx_status == RX_IDLE)begin
        M_flag <= 1'h0;
    end
    else if((rx_status == RX_START_DA) & gmii_rx_dv & ((!mii_select) | mii_odd) & (rx_status_cnt == 16'h5) & prom & (!(rx_unicast_check_success | rx_multicast_check_success)))begin
        M_flag <= 1'b1;
    end
end

//?frame end or have a error
wire recv_normal_end;
assign recv_normal_end              = (rx_status == RX_RECV_NORMAL) & (!gmii_rx_dv) & ((!mii_select) | mii_odd) & crc_check;
wire recv_remove_pad_end;
assign recv_remove_pad_end          = (rx_status == RX_ROMVE_PAD) & (!gmii_rx_dv) & ((!mii_select) | mii_odd) & crc_check;
wire recv_normal_error;
wire recv_normal_error_fifo;
wire recv_normal_error_er;
wire recv_normal_error_too_long;
wire recv_normal_error_crc;
wire recv_remove_pad_error_crc;
wire recv_normal_error_no;
wire recv_remove_pad_error_no;
assign recv_normal_error            =   recv_normal_error_fifo | recv_normal_error_er | recv_normal_error_too_long |
                                        recv_normal_error_crc | recv_normal_error_no | recv_remove_pad_error_crc | 
                                        recv_remove_pad_error_no;
assign recv_normal_error_fifo       = (rx_status == RX_RECV_NORMAL) & data_fifo_w_protect;
assign recv_normal_error_er         = (rx_status == RX_RECV_NORMAL) & gmii_rx_er;
assign recv_normal_error_too_long   = (rx_status == RX_RECV_NORMAL) & gmii_rx_dv & ((!mii_select) | mii_odd) & (rx_status_cnt == {2'h0, ftrl});
assign recv_normal_error_crc        = (rx_status == RX_RECV_NORMAL) & (!gmii_rx_dv) & (!crc_check);
assign recv_remove_pad_error_crc    = (rx_status == RX_ROMVE_PAD) & (!gmii_rx_dv) & (!crc_check);
assign recv_normal_error_no         = (rx_status == RX_RECV_NORMAL) & (!gmii_rx_dv) & (!((!mii_select) | mii_odd));
assign recv_remove_pad_error_no     = (rx_status == RX_ROMVE_PAD) & (!gmii_rx_dv) & (!((!mii_select) | mii_odd));

wire recv_control_end;
assign recv_control_end             = (rx_status == RX_RECV_CONTROL) & (!gmii_rx_dv) & ((!mii_select) | mii_odd) & crc_check;
wire recv_control_error;
wire recv_control_error_fifo;
wire recv_control_error_er;
wire recv_control_error_too_long;
wire recv_control_error_crc;
wire recv_control_error_no;
assign recv_control_error           =   recv_control_error_fifo | recv_control_error_er | recv_control_error_too_long |
                                        recv_control_error_crc | recv_control_error_no;
assign recv_control_error_fifo      = (rx_status == RX_RECV_CONTROL) & data_fifo_w_protect;
assign recv_control_error_er        = (rx_status == RX_RECV_CONTROL) & gmii_rx_er;
assign recv_control_error_too_long  = (rx_status == RX_RECV_CONTROL) & gmii_rx_dv & ((!mii_select) | mii_odd) & (rx_status_cnt == {2'h0, ftrl});
assign recv_control_error_crc       = (rx_status == RX_RECV_CONTROL) & (!gmii_rx_dv) & (!crc_check);
assign recv_control_error_no        = (rx_status == RX_RECV_CONTROL) & (!gmii_rx_dv) & (!((!mii_select) | mii_odd));

assign rx_frame_fifo_Wready = ((recv_normal_end | recv_remove_pad_end | recv_normal_error | recv_control_end | recv_control_error) & 
                                (rx_data_out_cnt != 16'h0)) ? 1'b1 : 1'b0;                  

assign rx_frame_fifo_wdata = {vlan_flag, recv_normal_error_er | recv_control_error_er, M_flag, BC_flag, MC_flag, LG_flag, 
                                recv_normal_error_no | recv_remove_pad_error_no | recv_control_error_no, 
                                recv_normal_error_crc | recv_remove_pad_error_crc | recv_control_error_crc, 
                                recv_normal_error_fifo | recv_control_error_fifo,
                                recv_normal_error_too_long | recv_control_error_too_long, plr_flag, 
                                (rx_data_fifo_Wready) ? (rx_data_out_cnt + {12'h0, rx_data_add_cnt}) :rx_data_out_cnt};

//?send data to data fifo

assign rx_data_fifo_Wready = (recv_normal_end | (recv_control_end & (rx_data_out_cnt != 16'h0)) | 
                                (((!mii_select) | mii_odd) & (rx_status == RX_RECV_NORMAL) & (rx_status_cnt == 16'hE)) | 
                                (((!mii_select) | mii_odd) & (rx_status == RX_RECV_NORMAL) & (rx_status_cnt == 16'hF) & (!(paden | crcfwd))) | 
                                (((!mii_select) | mii_odd) & (rx_status == RX_RECV_NORMAL) & rx_data_finish_flag) | 
                                (((!mii_select) | mii_odd) & (rx_status == RX_RECV_CONTROL) & pause_flag & paufwd & (rx_status_cnt == 16'h10)) | 
                                (((!mii_select) | mii_odd) & (rx_status == RX_RECV_CONTROL) & pause_flag & paufwd & rx_data_finish_flag) | 
                                (((!mii_select) | mii_odd) & (rx_status == RX_RECV_CONTROL) & (!pause_flag) & (!cfen) & (rx_status_cnt == 16'h10)) | 
                                (((!mii_select) | mii_odd) & (rx_status == RX_RECV_CONTROL) & (!pause_flag) & (!cfen) & rx_data_finish_flag));

wire [3:0]  end_data_shamt;
wire [63:0] end_data_temp;
wire [63:0] end_data;
assign end_data_shamt = 4'h8 - rx_data_add_cnt;
assign end_data_temp = (paden | crcfwd) ? 
    {gmii_rxd_r[4], gmii_rxd_r[5], gmii_rxd_r[6], gmii_rxd_r[7], 
                            gmii_rxd_r[8], gmii_rxd_r[9], gmii_rxd_r[10], gmii_rxd_r[11]} :
    {gmii_rxd_r[0], gmii_rxd_r[1], gmii_rxd_r[2], gmii_rxd_r[3], 
                            gmii_rxd_r[4], gmii_rxd_r[5], gmii_rxd_r[6], gmii_rxd_r[7]};
buck_shift #(64,6)u_buck_shift(
    .LR       	(1'b0                       ),
    .AL       	(1'b0                       ),
    .shamt    	({end_data_shamt[2:0], 3'h0}),
    .data_in  	(end_data_temp              ),
    .data_out 	(end_data                   )
);

assign rx_data_fifo_wdata = 
    (((rx_status == RX_RECV_NORMAL) & (rx_status_cnt == 16'hE)) | 
    ((rx_status == RX_RECV_CONTROL) & pause_flag & paufwd & (rx_status_cnt == 16'h10)) | 
    ((rx_status == RX_RECV_CONTROL) & (!pause_flag) & (!cfen) & (rx_status_cnt == 16'h10))) ?
    {gmii_rx_Sa[1], gmii_rx_Sa[0], gmii_rx_Da[5], gmii_rx_Da[4], 
                            gmii_rx_Da[3], gmii_rx_Da[2], gmii_rx_Da[1], gmii_rx_Da[0]} : 
    (recv_normal_end | (recv_control_end & (rx_data_out_cnt != 16'h0))) ? end_data :
    ((rx_status == RX_RECV_NORMAL) & (rx_status_cnt == 16'hF) & (!(paden | crcfwd))) ? 
    {gmii_rxd_r[3], gmii_rxd_r[4], gmii_rxd_r[5], gmii_rxd_r[6], 
                            gmii_rxd_r[7], gmii_rxd_r[8], gmii_rxd_r[9], gmii_rxd_r[10]} :
    (paden | crcfwd) ? 
    {gmii_rxd_r[4], gmii_rxd_r[5], gmii_rxd_r[6], gmii_rxd_r[7], 
                            gmii_rxd_r[8], gmii_rxd_r[9], gmii_rxd_r[10], gmii_rxd_r[11]} :
    {gmii_rxd_r[0], gmii_rxd_r[1], gmii_rxd_r[2], gmii_rxd_r[3], 
                            gmii_rxd_r[4], gmii_rxd_r[5], gmii_rxd_r[6], gmii_rxd_r[7]};

//?send pause frame or recv pause frame 
wire pause_frame_recv_flag = (rx_status == RX_RECV_CONTROL) & (!gmii_rx_dv) & ((!mii_select) | mii_odd) & crc_check & pause_flag & (rx_status_cnt > 16'h12);
wire pause_frame_recv_set = pause_frame_recv_flag & fce;
wire pause_frame_recv_clr = pause_req_in & pause_rdy_in;
wire pause_frame_recv_wen = (pause_frame_recv_set | pause_frame_recv_clr);
wire pause_frame_recv_nxt = (pause_frame_recv_set | (!pause_frame_recv_clr));
wire pause_frame_recv_r;
FF_D_with_wen #(
    .DATA_LEN 	(1  ),
    .RST_DATA 	(0  ))
u_pause_frame_recv_r(
    .clk      	(rx_clk                ),
    .rst_n    	(rst_n                 ),
    .wen      	(pause_frame_recv_wen  ),
    .data_in  	(pause_frame_recv_nxt  ),
    .data_out 	(pause_frame_recv_r    )
);

wire rsem_flag = (data_rsem_flag | frame_rsem_flag);
wire rsem_flag_r;
FF_D_without_wen #(
    .DATA_LEN 	(1  ),
    .RST_DATA 	(0  ))
u_rsem_flag_r(
    .clk      	(rx_clk         ),
    .rst_n    	(rst_n          ),
    .data_in  	(rsem_flag      ),
    .data_out 	(rsem_flag_r    )
);
wire rsem_flag_edge = (rsem_flag_r != rsem_flag);

wire rsem_flag_edge_set = rsem_flag_edge;
wire rsem_flag_edge_clr = pause_req_in & pause_rdy_in & (!pause_frame_recv_r);
wire rsem_flag_edge_wen = (rsem_flag_edge_set | rsem_flag_edge_clr);
wire rsem_flag_edge_nxt = (rsem_flag_edge_set | (!rsem_flag_edge_clr));
wire rsem_flag_edge_r;
FF_D_with_wen #(
    .DATA_LEN 	(1  ),
    .RST_DATA 	(0  ))
u_rsem_flag_edge_r(
    .clk      	(rx_clk              ),
    .rst_n    	(rst_n               ),
    .wen      	(rsem_flag_edge_wen  ),
    .data_in  	(rsem_flag_edge_nxt  ),
    .data_out 	(rsem_flag_edge_r    )
);

assign pause_req_in = (pause_frame_recv_r | rsem_flag_edge_r);
assign pause_data_in =  (pause_frame_recv_r ) ? {1'b1, 1'b0, gmii_rx_p1, gmii_rx_p2} : 
                        (rsem_flag          ) ? {1'b0, 1'b1, 16'h0} : 
                        (!rsem_flag         ) ? {1'b0, 1'b0, 16'h0} : 
                        {1'b0, 1'b0, 16'h0};

endmodule //gmii_rx
