module enet_rmii_to_mii_rx (
    // input              rst_n            , //复位信号    
    input              rst_ref_n        , //复位信号    
    input              rmii_10T         ,
    //以太网MII接口
    output reg         mii_rx_clk       , //MII接收时钟
    output             mii_rx_dv        , //MII接收数据使能信号
    output             mii_rx_er        , //MII接收数据错误信号
    output      [3:0]  mii_rxd          , //MII接收数据
    //以太网RMII接口   
    input              rmii_ref_clk     , //RMII参考时钟
    input              rmii_rx_crs_dv   , //RMII接收数据控制信号
    input       [1:0]  rmii_rxd           //RMII接收数据
);

reg         rmii_odd;
reg         in_frame;
reg  [3:0]  clk_cnt;

wire                rmii_rx_crs_dv_sync;
general_sync #(
    .DATA_LEN 	(1   ),
    .CHAIN_LV 	(2   ),
    .RST_DATA 	(0   ))
u_rmii_rx_crs_dv_sync(
    .clk      	(rmii_ref_clk           ),
    .rst_n    	(rst_ref_n              ),
    .data_in  	(rmii_rx_crs_dv         ),
    .data_out 	(rmii_rx_crs_dv_sync    )
);

wire [1:0]           rmii_rxd_sync;
general_sync #(
    .DATA_LEN 	(2   ),
    .CHAIN_LV 	(2   ),
    .RST_DATA 	(0   ))
u_rmii_rxd_sync(
    .clk      	(rmii_ref_clk     ),
    .rst_n    	(rst_ref_n        ),
    .data_in  	(rmii_rxd         ),
    .data_out 	(rmii_rxd_sync    )
);

wire        rmii_rx_dv_wen = (!rmii_10T) ? 1'b1 : (clk_cnt == 4'h9);
wire        rmii_rx_dv_nxt = rmii_rx_crs_dv_sync;
wire        rmii_rx_dv_r1;
FF_D_with_wen #(
    .DATA_LEN 	(1   ),
    .RST_DATA 	(0   ))
u_rmii_rx_dv_r1(
    .clk      	(rmii_ref_clk    ),
    .rst_n    	(rst_ref_n       ),
    .wen  	    (rmii_rx_dv_wen  ),
    .data_in  	(rmii_rx_dv_nxt  ),
    .data_out 	(rmii_rx_dv_r1   )
);

wire [3:0] rmii_rxd_r;
wire       rmii_rxd_wen = rmii_rx_dv_wen;
wire [3:0] rmii_rxd_nxt = {rmii_rxd_sync, rmii_rxd_r[3:2]};
FF_D_with_wen #(
    .DATA_LEN 	(4   ),
    .RST_DATA 	(0   ))
u_rmii_rxd_r(
    .clk      	(rmii_ref_clk    ),
    .rst_n    	(rst_ref_n       ),
    .wen      	(rmii_rxd_wen    ),
    .data_in  	(rmii_rxd_nxt    ),
    .data_out 	(rmii_rxd_r      )
);

wire       mii_rxd_wen = rmii_rx_dv_wen & in_frame & (!mii_rx_clk);
wire [3:0] mii_rxd_nxt = (rmii_odd) ? {rmii_rxd_sync, rmii_rxd_r[3:2]} : rmii_rxd_r;
FF_D_with_wen #(
    .DATA_LEN 	(4   ),
    .RST_DATA 	(0   ))
u_mii_rxd(
    .clk      	(rmii_ref_clk    ),
    .rst_n    	(rst_ref_n       ),
    .wen      	(mii_rxd_wen     ),
    .data_in  	(mii_rxd_nxt     ),
    .data_out 	(mii_rxd         )
);

wire       mii_rx_dv_wen = rmii_rx_dv_wen & (!mii_rx_clk);
wire       mii_rx_dv_nxt = in_frame & (rmii_rx_crs_dv_sync | rmii_rx_dv_r1);
FF_D_with_wen #(
    .DATA_LEN 	(1   ),
    .RST_DATA 	(0   ))
u_mii_rx_dv(
    .clk      	(rmii_ref_clk    ),
    .rst_n    	(rst_ref_n       ),
    .wen      	(mii_rx_dv_wen   ),
    .data_in  	(mii_rx_dv_nxt   ),
    .data_out 	(mii_rx_dv       )
);

always @(posedge rmii_ref_clk or negedge rst_ref_n) begin
    if(rst_ref_n == 1'b0)begin
        mii_rx_clk  <= 1'b0;
        clk_cnt     <= 4'h0;
    end
    else if(!rmii_10T)begin
        mii_rx_clk  <= ~mii_rx_clk;
        clk_cnt     <= 4'h0;
    end
    else if(clk_cnt == 4'h9)begin
        mii_rx_clk  <= ~mii_rx_clk;
        clk_cnt     <= 4'h0;
    end
    else begin
        clk_cnt     <= clk_cnt + 4'h1;
    end
end

always @(posedge rmii_ref_clk or negedge rst_ref_n) begin
    if(rst_ref_n == 1'b0)begin
        rmii_odd    <= 1'b0;
    end
    else if((!rmii_rx_crs_dv_sync) & (!rmii_rx_dv_r1))begin
        if((!rmii_10T) | (clk_cnt == 4'h9))
            rmii_odd    <= 1'b0;
    end
    else if((!in_frame) & (rmii_rxd_sync != 2'h0))begin
        if((!rmii_10T) | (clk_cnt == 4'h9))
            rmii_odd    <= 1'b1;
    end
    else if((!in_frame) & (rmii_rxd_sync == 2'h0))begin
        rmii_odd    <= 1'b0;
    end
    else if(!rmii_10T)begin
        rmii_odd    <= ~rmii_odd;
    end
    else if(clk_cnt == 4'h9)begin
        rmii_odd    <= ~rmii_odd;
    end
end
always @(posedge rmii_ref_clk or negedge rst_ref_n) begin
    if(rst_ref_n == 1'b0)begin
        in_frame    <= 1'b0;
    end
    else if((!rmii_rx_crs_dv_sync) & (!rmii_rx_dv_r1))begin
        if((!rmii_10T) | (clk_cnt == 4'h9))
            in_frame    <= 1'b0;
    end
    else if((!in_frame) & (rmii_rxd_sync != 2'h0) & ((!rmii_10T) | (clk_cnt == 4'h9)))begin
        in_frame    <= 1'b1;
    end
end
assign mii_rx_er = 1'b0;

endmodule //enet_rmii_to_mii_rx
