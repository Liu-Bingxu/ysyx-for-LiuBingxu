module enet_rmii_to_mii (
    input              rst_n      , //复位信号   
    input              rmii_10T,
    //以太网MII接口
    output             mii_rx_clk , //MII接收时钟
    output             mii_rx_dv  , //MII接收数据有效信号
    output             mii_rx_er  , //MII接收数据错误信号
    output      [3:0]  mii_rxd    , //MII接收数据
    output             mii_tx_clk , //MII发送时钟
    input              mii_tx_en  , //MII发送数据使能信号
    input              mii_tx_er  , //MII发送数据错误信号
    input       [3:0]  mii_txd    , //MII发送数据
    //以太网RMII接口   
    input              rmii_ref_clk   , //RMII参考时钟
    input              rmii_rx_crs_dv , //RMII接收数据控制信号
    input       [1:0]  rmii_rxd       , //RMII接收数据
    output             rmii_tx_en     , //RMII发送数据控制信号
    output      [1:0]  rmii_txd         //RMII发送数据
);

wire                rst_ref_n;
general_sync #(
    .DATA_LEN 	(1   ),
    .CHAIN_LV 	(2   ),
    .RST_DATA 	(0   ))
u_clk_async_rst_sync(
    .clk      	(rmii_ref_clk   ),
    .rst_n    	(rst_n          ),
    .data_in  	(1'b1           ),
    .data_out 	(rst_ref_n      )
);

enet_rmii_to_mii_tx u_enet_rmii_to_mii_tx(
    .rst_ref_n      (rst_ref_n     ),
    .rmii_10T       (rmii_10T      ),
    //以太网MII接口
    .mii_tx_clk     (mii_tx_clk     ),
    .mii_tx_en      (mii_tx_en      ),
    .mii_tx_er      (mii_tx_er      ),
    .mii_txd        (mii_txd        ),
    //以太网RMII接口   
    .rmii_ref_clk   (rmii_ref_clk   ),
    .rmii_tx_en     (rmii_tx_en     ),
    .rmii_txd       (rmii_txd       )
);

enet_rmii_to_mii_rx u_enet_rmii_to_mii_rx(
    .rst_ref_n      	(rst_ref_n       ),
    .rmii_10T       	(rmii_10T        ),
    .mii_rx_clk     	(mii_rx_clk      ),
    .mii_rx_dv      	(mii_rx_dv       ),
    .mii_rx_er      	(mii_rx_er       ),
    .mii_rxd        	(mii_rxd         ),
    .rmii_ref_clk   	(rmii_ref_clk    ),
    .rmii_rx_crs_dv 	(rmii_rx_crs_dv  ),
    .rmii_rxd       	(rmii_rxd        )
);


endmodule //enet_rmii_to_mii
