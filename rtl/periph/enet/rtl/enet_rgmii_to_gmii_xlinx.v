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

module enet_rgmii_to_gmii_xlinx(
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
    input              rgmii_txc   , //RGMII����ʱ��    
    output             rgmii_tx_ctl, //RGMII�������ݿ����ź�
    output      [3:0]  rgmii_txd     //RGMII��������          
);

//parameter define
parameter IDELAY_VALUE = 0;  //��������IO��ʱ(���Ϊn,��ʾ��ʱn*78ps) 

//*****************************************************
//**                    main code
//*****************************************************

//RGMII����
enet_rgmii_to_gmii_rx_xlinx #(
    .IDELAY_VALUE  (IDELAY_VALUE)
) u_rgmii_rx(
    .idelay_clk    (idelay_clk      ),
    .gmii_rx_clk   (gmii_rx_clk     ),
    .rgmii_rxc     (rgmii_rxc       ),
    .rgmii_rx_ctl  (rgmii_rx_ctl    ),
    .rgmii_rxd     (rgmii_rxd       ),

    .gmii_rx_dv    (gmii_rx_dv      ),
    .gmii_rx_er    (gmii_rx_er      ),
    .gmii_rxd      (gmii_rxd        )
);

//RGMII����
enet_rgmii_to_gmii_tx_xlinx u_rgmii_tx(
    .gmii_tx_clk   (gmii_tx_clk     ),
    .gmii_tx_en    (gmii_tx_en      ),
    .gmii_tx_er    (gmii_tx_er      ),
    .gmii_txd      (gmii_txd        ),

    .rgmii_txc     (rgmii_txc       ),
    .rgmii_tx_ctl  (rgmii_tx_ctl    ),
    .rgmii_txd     (rgmii_txd       )
);

endmodule //enet_rgmii_to_gmii_xlinx
