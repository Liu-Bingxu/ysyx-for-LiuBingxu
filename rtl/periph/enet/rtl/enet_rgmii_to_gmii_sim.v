//****************************************Copyright (c)***********************************//
//ԭ�Ӹ����߽�ѧƽ̨��www.yuanzige.com
//����֧�֣�www.openedv.com
//�Ա����̣�http://openedv.taobao.com 
//��ע΢�Ź���ƽ̨΢�źţ�"����ԭ��"����ѻ�ȡZYNQ & FPGA & STM32 & LINUX���ϡ�
//��Ȩ���У�����ؾ���
//Copyright(C) ����ԭ�� 2018-2028
//All rights reserved                                  
//----------------------------------------------------------------------------------------
// File name:           gmii_to_rgmii
// Last modified Date:  2020/2/13 9:20:14
// Last Version:        V1.0
// Descriptions:        GMII�ӿ�תRGMII�ӿ�ģ��
//----------------------------------------------------------------------------------------
// Created by:          ����ԭ��
// Created date:        2020/2/13 9:20:14
// Version:             V1.0
// Descriptions:        The original version
//
//----------------------------------------------------------------------------------------
//****************************************************************************************//

module enet_rgmii_to_gmii_sim(
    input              idelay_clk  , //IDELAYʱ��
    //��̫��GMII�ӿ�
    output             gmii_rx_clk , //GMII����ʱ��
    output reg         gmii_rx_dv  , //GMII����������Ч�ź�
    output reg         gmii_rx_er  , //GMII�������ݴ����ź�
    output reg  [7:0]  gmii_rxd    , //GMII��������
    output             gmii_tx_clk , //GMII����ʱ��
    input              gmii_tx_en  , //GMII��������ʹ���ź�
    input              gmii_tx_er  , //GMII�������ݴ����ź�
    input       [7:0]  gmii_txd    , //GMII��������            
    //��̫��RGMII�ӿ�   
    input              rgmii_rxc   , //RGMII����ʱ��
    input              rgmii_rx_ctl, //RGMII�������ݿ����ź�
    input       [3:0]  rgmii_rxd   , //RGMII��������
    output             rgmii_txc   , //RGMII����ʱ��    
    output reg         rgmii_tx_ctl, //RGMII�������ݿ����ź�
    output reg  [3:0]  rgmii_txd     //RGMII��������          
);

//*****************************************************
//**                    main code
//*****************************************************

assign gmii_tx_clk = gmii_rx_clk;

//RGMII Rx
assign gmii_rx_clk = rgmii_rxc;

reg rgmii_rx_ctl_d_reg_1;
reg rgmii_rx_ctl_d_reg_2;
always @(posedge gmii_rx_clk) begin
    rgmii_rx_ctl_d_reg_1 <= rgmii_rx_ctl;
end
always @(negedge gmii_rx_clk) begin
    rgmii_rx_ctl_d_reg_2 <= rgmii_rx_ctl;
end

always @(posedge gmii_rx_clk) begin
    gmii_rx_dv <= rgmii_rx_ctl_d_reg_1;
    gmii_rx_er <= rgmii_rx_ctl_d_reg_2 ^ rgmii_rx_ctl_d_reg_1;
end

reg [3:0] rgmii_rxd_d_reg_1;
reg [3:0] rgmii_rxd_d_reg_2;
always @(posedge gmii_rx_clk) begin
    rgmii_rxd_d_reg_1 <= rgmii_rxd;
end
always @(negedge gmii_rx_clk) begin
    rgmii_rxd_d_reg_2 <= rgmii_rxd;
end
always @(posedge gmii_rx_clk) begin
    gmii_rxd[3:0] <= rgmii_rxd_d_reg_1;
    gmii_rxd[7:4] <= rgmii_rxd_d_reg_2;
end

//RGMII Tx
assign rgmii_txc = gmii_tx_clk;

reg  rgmii_tx_ctl_reg;
always @(posedge gmii_tx_clk) begin
    rgmii_tx_ctl        <= gmii_tx_en;
    rgmii_tx_ctl_reg    <= gmii_tx_er ^ gmii_tx_en;
end
always @(negedge gmii_tx_clk) begin
    rgmii_tx_ctl <= rgmii_tx_ctl_reg;
end

reg [3:0] rgmii_txd_reg;
always @(posedge gmii_tx_clk) begin
    rgmii_txd       <= gmii_txd[3:0];
    rgmii_txd_reg   <= gmii_txd[7:4];
end
always @(negedge gmii_tx_clk) begin
    rgmii_txd <= rgmii_txd_reg;
end

endmodule //enet_rgmii_to_gmii_sim
