module enet_rgmii_to_gmii_dummy#(
    //输入数据IO延时(如果为n,表示延时n*78ps) 
    parameter IDELAY_VALUE = 0
)(
    input              idelay_clk  , //IDELAY时钟
    //以太网GMII接口
    output             gmii_rx_clk , //GMII接收时钟
    output             gmii_rx_dv  , //GMII接收数据有效信号
    output             gmii_rx_er  , //GMII接收数据错误信号
    output      [7:0]  gmii_rxd    , //GMII接收数据
    output             gmii_tx_clk , //GMII发送时钟
    input              gmii_tx_en  , //GMII发送数据使能信号
    input              gmii_tx_er  , //GMII发送数据错误信号
    input       [7:0]  gmii_txd    , //GMII发送数据            
    //以太网RGMII接口   
    input              rgmii_rxc   , //RGMII接收时钟
    input              rgmii_rx_ctl, //RGMII接收数据控制信号
    input       [3:0]  rgmii_rxd   , //RGMII接收数据
    output             rgmii_txc   , //RGMII发送时钟    
    output             rgmii_tx_ctl, //RGMII发送数据控制信号
    output      [3:0]  rgmii_txd     //RGMII发送数据          
);

assign gmii_rx_clk  = 1'b0; 
assign gmii_rx_dv   = 1'b0; 
assign gmii_rx_er   = 1'b0; 
assign gmii_rxd     = 8'b0; 
assign gmii_tx_clk  = 1'b0; 

assign rgmii_txc    = 1'b0;
assign rgmii_tx_ctl = 1'b0;
assign rgmii_txd    = 4'b0;


endmodule //enet_rgmii_to_gmii_dummy
