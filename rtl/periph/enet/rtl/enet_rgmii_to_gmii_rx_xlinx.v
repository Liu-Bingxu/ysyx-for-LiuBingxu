//****************************************Copyright (c)***********************************//
//ԭ�Ӹ����߽�ѧƽ̨��www.yuanzige.com
//����֧�֣�www.openedv.com
//�Ա����̣�http://openedv.taobao.com 
//��ע΢�Ź���ƽ̨΢�źţ�"����ԭ��"����ѻ�ȡZYNQ & FPGA & STM32 & LINUX���ϡ�
//��Ȩ���У�����ؾ���
//Copyright(C) ����ԭ�� 2018-2028
//All rights reserved                                  
//----------------------------------------------------------------------------------------
// File name:           rgmii_rx
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

module enet_rgmii_to_gmii_rx_xlinx(
    input              idelay_clk  , //200Mhzʱ�ӣ�IDELAYʱ��
    
    //��̫��RGMII�ӿ�
    input              rgmii_rxc   , //RGMII����ʱ��
    input              rgmii_rx_ctl, //RGMII�������ݿ����ź�
    input       [3:0]  rgmii_rxd   , //RGMII��������    

    //��̫��GMII�ӿ�
    output             gmii_rx_clk , //GMII����ʱ��
    output             gmii_rx_dv  , //GMII����������Ч�ź�
    output             gmii_rx_er  , //GMII�������ݴ����ź�
    output      [7:0]  gmii_rxd      //GMII��������   
    );

//parameter define
parameter IDELAY_VALUE = 0;

//wire define
wire         rgmii_rxc_bufg;     //ȫ��ʱ�ӻ���
wire         rgmii_rxc_bufio;    //ȫ��ʱ��IO����
wire  [3:0]  rgmii_rxd_delay;    //rgmii_rxd������ʱ
wire         rgmii_rx_ctl_delay; //rgmii_rx_ctl������ʱ

wire         rgmii_rx_ctl_neg;

//*****************************************************
//**                    main code
//*****************************************************

assign gmii_rx_clk = rgmii_rxc_bufg;

//ȫ��ʱ�ӻ���
BUFG BUFG_inst (
  .I            (rgmii_rxc),     // 1-bit input: Clock input
  .O            (rgmii_rxc_bufg) // 1-bit output: Clock output
);

//ȫ��ʱ��IO����
BUFIO BUFIO_inst (
  .I            (rgmii_rxc),      // 1-bit input: Clock input
  .O            (rgmii_rxc_bufio) // 1-bit output: Clock output
);

//������ʱ����
// Specifies group name for associated IDELAYs/ODELAYs and IDELAYCTRL
(* IODELAY_GROUP = "rgmii_rx_delay" *) 
IDELAYCTRL  IDELAYCTRL_inst (
    .RDY(),                      // 1-bit output: Ready output
    .REFCLK(idelay_clk),         // 1-bit input: Reference clock input
    .RST(1'b0)                   // 1-bit input: Active high reset input
);

//rgmii_rx_ctl������ʱ��˫�ز���
(* IODELAY_GROUP = "rgmii_rx_delay" *) 
IDELAYE2 #(
  .IDELAY_TYPE     ("FIXED"),           // FIXED, VARIABLE, VAR_LOAD, VAR_LOAD_PIPE
  .IDELAY_VALUE    (IDELAY_VALUE),      // Input delay tap setting (0-31)
  .REFCLK_FREQUENCY(200.0)              // IDELAYCTRL clock input frequency in MHz 
)
u_delay_rx_ctrl (
  .CNTVALUEOUT     (),                  // 5-bit output: Counter value output
  .DATAOUT         (rgmii_rx_ctl_delay),// 1-bit output: Delayed data output
  .C               (1'b0),              // 1-bit input: Clock input
  .CE              (1'b0),              // 1-bit input: enable increment/decrement
  .CINVCTRL        (1'b0),              // 1-bit input: Dynamic clock inversion input
  .CNTVALUEIN      (5'b0),              // 5-bit input: Counter value input
  .DATAIN          (1'b0),              // 1-bit input: Internal delay data input
  .IDATAIN         (rgmii_rx_ctl),      // 1-bit input: Data input from the I/O
  .INC             (1'b0),              // 1-bit input: Increment / Decrement tap delay
  .LD              (1'b0),              // 1-bit input: Load IDELAY_VALUE input
  .LDPIPEEN        (1'b0),              // 1-bit input: Enable PIPELINE register
  .REGRST          (1'b0)               // 1-bit input: Active-high reset tap-delay input
);

//����˫�ز����Ĵ���
IDDR #(
    .DDR_CLK_EDGE("SAME_EDGE_PIPELINED"),// "OPPOSITE_EDGE", "SAME_EDGE" 
                                        //    or "SAME_EDGE_PIPELINED" 
    .INIT_Q1  (1'b0),                   // Initial value of Q1: 1'b0 or 1'b1
    .INIT_Q2  (1'b0),                   // Initial value of Q2: 1'b0 or 1'b1
    .SRTYPE   ("SYNC")                  // Set/Reset type: "SYNC" or "ASYNC" 
) u_iddr_rx_ctl (
    .Q1       (gmii_rx_dv),         // 1-bit output for positive edge of clock
    .Q2       (rgmii_rx_ctl_neg),         // 1-bit output for negative edge of clock
    .C        (rgmii_rxc_bufio),        // 1-bit clock input
    .CE       (1'b1),                   // 1-bit clock enable input
    .D        (rgmii_rx_ctl_delay),     // 1-bit DDR data input
    .R        (1'b0),                   // 1-bit reset
    .S        (1'b0)                    // 1-bit set
);
assign gmii_rx_er = gmii_rx_dv ^ rgmii_rx_ctl_neg;

//rgmii_rxd������ʱ��˫�ز���
genvar i;
generate for (i=0; i<4; i=i+1)
    (* IODELAY_GROUP = "rgmii_rx_delay" *) 
    begin : rxdata_bus
        //������ʱ           
        (* IODELAY_GROUP = "rgmii_rx_delay" *) 
        IDELAYE2 #(
          .IDELAY_TYPE     ("FIXED"),           // FIXED,VARIABLE,VAR_LOAD,VAR_LOAD_PIPE
          .IDELAY_VALUE    (IDELAY_VALUE),      // Input delay tap setting (0-31)    
          .REFCLK_FREQUENCY(200.0)              // IDELAYCTRL clock input frequency in MHz
        )
        u_delay_rxd (
          .CNTVALUEOUT     (),                  // 5-bit output: Counter value output
          .DATAOUT         (rgmii_rxd_delay[i]),// 1-bit output: Delayed data output
          .C               (1'b0),              // 1-bit input: Clock input
          .CE              (1'b0),              // 1-bit input: enable increment/decrement
          .CINVCTRL        (1'b0),              // 1-bit input: Dynamic clock inversion
          .CNTVALUEIN      (5'b0),              // 5-bit input: Counter value input
          .DATAIN          (1'b0),              // 1-bit input: Internal delay data input
          .IDATAIN         (rgmii_rxd[i]),      // 1-bit input: Data input from the I/O
          .INC             (1'b0),              // 1-bit input: Inc/Decrement tap delay
          .LD              (1'b0),              // 1-bit input: Load IDELAY_VALUE input
          .LDPIPEEN        (1'b0),              // 1-bit input: Enable PIPELINE register 
          .REGRST          (1'b0)               // 1-bit input: Active-high reset tap-delay
        );
        
        //����˫�ز����Ĵ���
        IDDR #(
            .DDR_CLK_EDGE("SAME_EDGE_PIPELINED"),// "OPPOSITE_EDGE", "SAME_EDGE" 
                                                //    or "SAME_EDGE_PIPELINED" 
            .INIT_Q1  (1'b0),                   // Initial value of Q1: 1'b0 or 1'b1
            .INIT_Q2  (1'b0),                   // Initial value of Q2: 1'b0 or 1'b1
            .SRTYPE   ("SYNC")                  // Set/Reset type: "SYNC" or "ASYNC" 
        ) u_iddr_rxd (
            .Q1       (gmii_rxd[i]),            // 1-bit output for positive edge of clock
            .Q2       (gmii_rxd[4+i]),          // 1-bit output for negative edge of clock
            .C        (rgmii_rxc_bufio),        // 1-bit clock input rgmii_rxc_bufio
            .CE       (1'b1),                   // 1-bit clock enable input
            .D        (rgmii_rxd_delay[i]),     // 1-bit DDR data input
            .R        (1'b0),                   // 1-bit reset
            .S        (1'b0)                    // 1-bit set
        );
    end
endgenerate

endmodule //enet_rgmii_to_gmii_rx_xlinx
