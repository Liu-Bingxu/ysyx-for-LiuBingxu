module enet_tcr (
    input                           tx_clk,
    input                           rst_n,

    input                           tcr_wen,
    input                           ecr_wen,

    input  [31:0]                   reg_wdata,

    output                          eir_gra,
    input                           eir_rdy,

    output                          ether_en,
    output                          fden,
    output                          gts,
    output                          rfc_pause,
    output                          tfc_pause,
    output                          tx_stop,
    input                           tx_mac_stop,
    output                          mii_select,
    output                          pause_send,
    input                           pause_mac_send,
    output                          pause_send_zero,
    input                           pause_mac_send_zero,
    output                          crcfwd,
    output                          addins,
    output [13:0]                   max_fl,

    input                           pause_req_out,
    output                          pause_rdy_out,
    //bit 17: 1-recv a pause frame; 0-need to send a pause
    //bit 16: 1-send a pause; 0-send a zero pause
    //bit 15-0: recv pause time
    input  [17:0]                   pause_data_out
);

reg   recv_stop;

reg             mii_odd;
reg  [5:0]      pause_8byte_cnt;
reg  [15:0]     pause_cnt;
reg  [15:0]     pause_time;

FF_D_with_wen #(
    .DATA_LEN 	(1  ),
    .RST_DATA 	(0  ))
u_fden(
    .clk      	(tx_clk        ),
    .rst_n    	(rst_n         ),
    .wen      	(tcr_wen       ),
    .data_in  	(reg_wdata[2]  ),
    .data_out 	(fden          )
);

FF_D_with_wen #(
    .DATA_LEN 	(1  ),
    .RST_DATA 	(0  ))
u_crcfwd(
    .clk      	(tx_clk        ),
    .rst_n    	(rst_n         ),
    .wen      	(tcr_wen       ),
    .data_in  	(reg_wdata[9]  ),
    .data_out 	(crcfwd        )
);

FF_D_with_wen #(
    .DATA_LEN 	(1  ),
    .RST_DATA 	(0  ))
u_addins(
    .clk      	(tx_clk        ),
    .rst_n    	(rst_n         ),
    .wen      	(tcr_wen       ),
    .data_in  	(reg_wdata[8]  ),
    .data_out 	(addins        )
);

FF_D_with_wen #(
    .DATA_LEN 	(1  ),
    .RST_DATA 	(0  ))
u_gts(
    .clk      	(tx_clk        ),
    .rst_n    	(rst_n         ),
    .wen      	(tcr_wen       ),
    .data_in  	(reg_wdata[0]  ),
    .data_out 	(gts           )
);

wire tfc_pause_set = tcr_wen & reg_wdata[3];
wire tfc_pause_clr = pause_mac_send;
wire tfc_pause_wen = (tfc_pause_set | tfc_pause_clr);
wire tfc_pause_nxt = (tfc_pause_set | (!tfc_pause_clr));
FF_D_with_wen #(
    .DATA_LEN 	(1  ),
    .RST_DATA 	(0  ))
u_tfc_pause(
    .clk      	(tx_clk               ),
    .rst_n    	(rst_n                ),
    .wen      	(tfc_pause_wen        ),
    .data_in  	(tfc_pause_nxt        ),
    .data_out 	(tfc_pause            )
);

FF_D_with_wen #(
    .DATA_LEN 	(14         ),
    .RST_DATA 	(14'h5EE    ))
u_max_fl(
    .clk      	(tx_clk             ),
    .rst_n    	(rst_n              ),
    .wen      	(ecr_wen            ),
    .data_in  	(reg_wdata[29:16]   ),
    .data_out 	(max_fl             )
);

FF_D_with_wen #(
    .DATA_LEN 	(1   ),
    .RST_DATA 	(0   ))
u_mii_sel(
    .clk      	(tx_clk         ),
    .rst_n    	(rst_n          ),
    .wen      	(ecr_wen        ),
    .data_in  	(reg_wdata[3]   ),
    .data_out 	(mii_select     )
);

FF_D_with_wen #(
    .DATA_LEN 	(1   ),
    .RST_DATA 	(0   ))
u_ether_en(
    .clk      	(tx_clk         ),
    .rst_n    	(rst_n          ),
    .wen      	(ecr_wen        ),
    .data_in  	(reg_wdata[1]   ),
    .data_out 	(ether_en       )
);

wire tx_stop_r;
FF_D_without_wen #(
    .DATA_LEN 	(1  ),
    .RST_DATA 	(0  ))
u_tx_stop_r(
    .clk      	(tx_clk        ),
    .rst_n    	(rst_n         ),
    .data_in  	(tx_stop       ),
    .data_out 	(tx_stop_r     )
);
wire tx_stop_pos = (!tx_stop_r) & tx_stop;

// wire tx_mac_stop_r;
// FF_D_without_wen #(
//     .DATA_LEN 	(1  ),
//     .RST_DATA 	(0  ))
// u_tx_mac_stop_r(
//     .clk      	(tx_clk            ),
//     .rst_n    	(rst_n             ),
//     .data_in  	(tx_mac_stop       ),
//     .data_out 	(tx_mac_stop_r     )
// );
// wire tx_mac_stop_pos = (!tx_mac_stop_r) & tx_mac_stop;

wire tx_stop_pos_set = tx_stop_pos;
wire tx_stop_pos_clr = eir_gra & eir_rdy;
wire tx_stop_pos_wen = (tx_stop_pos_set | tx_stop_pos_clr);
wire tx_stop_pos_nxt = (tx_stop_pos_set | (!tx_stop_pos_clr));
wire tx_stop_pos_r;
FF_D_with_wen #(
    .DATA_LEN 	(1  ),
    .RST_DATA 	(0  ))
u_tx_stop_pos_r(
    .clk      	(tx_clk           ),
    .rst_n    	(rst_n            ),
    .wen      	(tx_stop_pos_wen  ),
    .data_in  	(tx_stop_pos_nxt  ),
    .data_out 	(tx_stop_pos_r    )
);

wire eir_gra_set = tx_stop_pos_r & tx_mac_stop;
wire eir_gra_clr = eir_gra & eir_rdy;
wire eir_gra_wen = (eir_gra_set | eir_gra_clr);
wire eir_gra_nxt = (eir_gra_set & (!eir_gra_clr));
FF_D_with_wen #(
    .DATA_LEN 	(1  ),
    .RST_DATA 	(0  ))
u_eir_gra(
    .clk      	(tx_clk       ),
    .rst_n    	(rst_n        ),
    .wen      	(eir_gra_wen  ),
    .data_in  	(eir_gra_nxt  ),
    .data_out 	(eir_gra      )
);

wire pause_send_set = pause_req_out & pause_rdy_out & (!pause_data_out[17]) & pause_data_out[16];
wire pause_send_clr = (pause_mac_send | (pause_req_out & pause_rdy_out & (!pause_data_out[17]) & (!pause_data_out[16])));
wire pause_send_wen = (pause_send_set | pause_send_clr);
wire pause_send_nxt = (pause_send_set | (!pause_send_clr));
FF_D_with_wen #(
    .DATA_LEN 	(1  ),
    .RST_DATA 	(0  ))
u_pause_send(
    .clk      	(tx_clk          ),
    .rst_n    	(rst_n           ),
    .wen      	(pause_send_wen  ),
    .data_in  	(pause_send_nxt  ),
    .data_out 	(pause_send      )
);

wire pause_send_zero_set = pause_req_out & pause_rdy_out & (!pause_data_out[17]) & (!pause_data_out[16]);
wire pause_send_zero_clr = (pause_mac_send_zero | (pause_req_out & pause_rdy_out & (!pause_data_out[17]) & pause_data_out[16]));
wire pause_send_zero_wen = (pause_send_zero_set | pause_send_zero_clr);
wire pause_send_zero_nxt = (pause_send_zero_set | (!pause_send_zero_clr));
FF_D_with_wen #(
    .DATA_LEN 	(1  ),
    .RST_DATA 	(0  ))
u_pause_send_zero(
    .clk      	(tx_clk               ),
    .rst_n    	(rst_n                ),
    .wen      	(pause_send_zero_wen  ),
    .data_in  	(pause_send_zero_nxt  ),
    .data_out 	(pause_send_zero      )
);

always @(posedge tx_clk or negedge rst_n) begin
    if(!rst_n)begin
        recv_stop       <= 1'b0;
        mii_odd         <= 1'b0;
        pause_8byte_cnt <= 6'h0;
        pause_cnt       <= 16'h0;
        pause_time      <= 16'h0;
    end
    else if(pause_req_out & pause_rdy_out & pause_data_out[17])begin
        recv_stop       <= 1'b1;
        mii_odd         <= 1'b0;
        pause_8byte_cnt <= 6'h0;
        pause_cnt       <= 16'h0;
        pause_time      <= pause_data_out[15:0];
    end
    else if(mii_odd)begin
        mii_odd         <= 1'b0;
    end
    else if((pause_cnt == pause_time) & (pause_8byte_cnt == 6'd63) & recv_stop)begin
        recv_stop       <= 1'b0;
        mii_odd         <= 1'b0;
        pause_8byte_cnt <= 6'h0;
        pause_cnt       <= 16'h0;
        pause_time      <= 16'h0;
    end
    else if(recv_stop)begin
        if(mii_select)begin
            mii_odd     <= 1'b1;
        end
        if(pause_8byte_cnt == 6'd63)begin
            pause_8byte_cnt <= 6'h0;
            pause_cnt       <= pause_cnt + 16'h1;
        end
        else begin
            pause_8byte_cnt <= pause_8byte_cnt + 6'h1;
        end
    end
end

assign tx_stop       = (gts | recv_stop);
assign pause_rdy_out = 1'b1;
assign rfc_pause     = recv_stop;

endmodule //enet_tcr
