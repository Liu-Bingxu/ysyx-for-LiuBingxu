//****************************************Copyright (c)***********************************//
//ԭ�Ӹ����߽�ѧƽ̨��www.yuanzige.com
//����֧�֣�www.openedv.com
//�Ա����̣�http://openedv.taobao.com 
//��ע΢�Ź���ƽ̨΢�źţ�"����ԭ��"����ѻ�ȡZYNQ & FPGA & STM32 & LINUX���ϡ�
//��Ȩ���У�����ؾ���
//Copyright(C) ����ԭ�� 2018-2028
//All rights reserved                                  
//----------------------------------------------------------------------------------------
// File name:           rgmii_tx
// Last modified Date:  2020/2/13 9:20:14
// Last Version:        V1.0
// Descriptions:        RGMII����ģ��
//----------------------------------------------------------------------------------------
// Created by:          ����ԭ��
// Created date:        2020/2/13 9:20:14
// Version:             V1.0
// Descriptions:        The original version
//
//----------------------------------------------------------------------------------------
//****************************************************************************************//

module enet_rgmii_to_gmii_tx_xlinx(
    //GMII���Ͷ˿�
    input              gmii_tx_clk , //GMII����ʱ��    
    input              gmii_tx_en  , //GMII���������Ч�ź�
    input              gmii_tx_er  , //GMII�������ݴ����ź�
    input       [7:0]  gmii_txd    , //GMII�������        
    
    //RGMII���Ͷ˿�
    output             rgmii_txc   , //RGMII��������ʱ��    
    output             rgmii_tx_ctl, //RGMII���������Ч�ź�
    output      [3:0]  rgmii_txd     //RGMII�������     
    );

//*****************************************************
//**                    main code
//*****************************************************

assign rgmii_txc = gmii_tx_clk;

//���˫�ز����Ĵ��� (rgmii_tx_ctl)
ODDR #(
    .DDR_CLK_EDGE  ("SAME_EDGE"),  // "OPPOSITE_EDGE" or "SAME_EDGE" 
    .INIT          (1'b0),         // Initial value of Q: 1'b0 or 1'b1
    .SRTYPE        ("SYNC")        // Set/Reset type: "SYNC" or "ASYNC" 
) ODDR_inst (
    .Q             (rgmii_tx_ctl), // 1-bit DDR output
    .C             (gmii_tx_clk),  // 1-bit clock input
    .CE            (1'b1),         // 1-bit clock enable input
    .D1            (gmii_tx_en),   // 1-bit data input (positive edge)
    .D2            (gmii_tx_er ^ gmii_tx_en),   // 1-bit data input (negative edge)
    .R             (1'b0),         // 1-bit reset
    .S             (1'b0)          // 1-bit set
); 

genvar i;
generate for (i=0; i<4; i=i+1)
    begin : txdata_bus
        //���˫�ز����Ĵ��� (rgmii_txd)
        ODDR #(
            .DDR_CLK_EDGE  ("SAME_EDGE"),  // "OPPOSITE_EDGE" or "SAME_EDGE" 
            .INIT          (1'b0),         // Initial value of Q: 1'b0 or 1'b1
            .SRTYPE        ("SYNC")        // Set/Reset type: "SYNC" or "ASYNC" 
        ) ODDR_inst (
            .Q             (rgmii_txd[i]), // 1-bit DDR output
            .C             (gmii_tx_clk),  // 1-bit clock input
            .CE            (1'b1),         // 1-bit clock enable input
            .D1            (gmii_txd[i]),  // 1-bit data input (positive edge)
            .D2            (gmii_txd[4+i]),// 1-bit data input (negative edge)
            .R             (1'b0),         // 1-bit reset
            .S             (1'b0)          // 1-bit set
        );        
    end
endgenerate

endmodule //enet_rgmii_to_gmii_tx_xlinx
