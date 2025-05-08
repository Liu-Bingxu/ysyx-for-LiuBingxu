module enet_rgmii_to_gmii_dummy#(
    //��������IO��ʱ(���Ϊn,��ʾ��ʱn*78ps) 
    parameter IDELAY_VALUE = 0
)(
    input              idelay_clk  , //IDELAYʱ��
    //��̫��GMII�ӿ�
    output             gmii_rx_clk , //GMII����ʱ��
    output             gmii_rx_dv  , //GMII����������Ч�ź�
    output             gmii_rx_er  , //GMII�������ݴ����ź�
    output      [7:0]  gmii_rxd    , //GMII��������
    output             gmii_tx_clk , //GMII����ʱ��
    input              gmii_tx_en  , //GMII��������ʹ���ź�
    input              gmii_tx_er  , //GMII�������ݴ����ź�
    input       [7:0]  gmii_txd    , //GMII��������            
    //��̫��RGMII�ӿ�   
    input              rgmii_rxc   , //RGMII����ʱ��
    input              rgmii_rx_ctl, //RGMII�������ݿ����ź�
    input       [3:0]  rgmii_rxd   , //RGMII��������
    output             rgmii_txc   , //RGMII����ʱ��    
    output             rgmii_tx_ctl, //RGMII�������ݿ����ź�
    output      [3:0]  rgmii_txd     //RGMII��������          
);

assign gmii_rx_clk  = 1'b0; 
assign gmii_rx_dv   = 1'b0; 
assign gmii_rx_er   = 1'b0; 
assign gmii_rxd     = 8'b0; 
assign gmii_tx_clk  = 1'b0; 

assign rgmii_txc    = rgmii_rxc;
assign rgmii_tx_ctl = 1'b0;
assign rgmii_txd    = 4'b0;


endmodule //enet_rgmii_to_gmii_dummy
