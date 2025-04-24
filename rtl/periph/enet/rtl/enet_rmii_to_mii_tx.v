module enet_rmii_to_mii_tx (
    input              rst_ref_n   , //复位信号    
    input              rmii_10T    ,
    //以太网MII接口
    output reg         mii_tx_clk  , //MII发送时钟
    input              mii_tx_en   , //MII发送数据使能信号
    input              mii_tx_er   , //MII发送数据错误信号
    input       [3:0]  mii_txd     , //MII发送数据
    //以太网RMII接口   
    input              rmii_ref_clk, //RMII参考时钟
    output             rmii_tx_en  , //RMII发送数据控制信号
    output      [1:0]  rmii_txd      //RMII发送数据
);

reg         rmii_odd;
reg  [3:0]  clk_cnt;

wire rmii_tx_en_nxt = mii_tx_en & (!mii_tx_er);
FF_D_without_wen #(
    .DATA_LEN 	(1   ),
    .RST_DATA 	(0   ))
u_rmii_tx_en(
    .clk      	(rmii_ref_clk    ),
    .rst_n    	(rst_ref_n       ),
    .data_in  	(rmii_tx_en_nxt  ),
    .data_out 	(rmii_tx_en      )
);

wire [3:0] rmii_txd_r;
wire [3:0] rmii_txd_nxt = (rmii_odd) ? {rmii_txd_r[3:2], rmii_txd_r[3:2]} : mii_txd;
FF_D_without_wen #(
    .DATA_LEN 	(4   ),
    .RST_DATA 	(0   ))
u_rmii_txd(
    .clk      	(rmii_ref_clk    ),
    .rst_n    	(rst_ref_n       ),
    .data_in  	(rmii_txd_nxt    ),
    .data_out 	(rmii_txd_r      )
);
assign rmii_txd = rmii_txd_r[1:0];

always @(posedge rmii_ref_clk or negedge rst_ref_n) begin
    if(rst_ref_n == 1'b0)begin
        mii_tx_clk  <= 1'b0;
        clk_cnt     <= 4'h0;
    end
    else if(!rmii_10T)begin
        mii_tx_clk  <= ~mii_tx_clk;
        clk_cnt     <= 4'h0;
    end
    else if(clk_cnt == 4'h9)begin
        mii_tx_clk  <= ~mii_tx_clk;
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
    else if(!mii_tx_en)begin
        rmii_odd    <= 1'b0;
    end
    else if(!rmii_10T)begin
        rmii_odd    <= ~rmii_odd;
    end
    else if(clk_cnt == 4'h9)begin
        rmii_odd    <= ~rmii_odd;
    end
end

endmodule //enet_rmii_to_mii_tx
