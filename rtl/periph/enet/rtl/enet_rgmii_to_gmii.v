module enet_rgmii_to_gmii#(
    // target ("SIM", "GENERIC", "XILINX", "ALTERA")
    parameter TARGET = "GENERIC",
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

if(TARGET == "XILINX") begin
    //XILINX FPGA
    enet_rgmii_to_gmii_xlinx #(
        .IDELAY_VALUE 	(IDELAY_VALUE  ))
    u_enet_rgmii_to_gmii_xlinx(
        .idelay_clk   	(idelay_clk    ),
        .gmii_rx_clk  	(gmii_rx_clk   ),
        .gmii_rx_dv   	(gmii_rx_dv    ),
        .gmii_rx_er   	(gmii_rx_er    ),
        .gmii_rxd     	(gmii_rxd      ),
        .gmii_tx_clk  	(gmii_tx_clk   ),
        .gmii_tx_en   	(gmii_tx_en    ),
        .gmii_tx_er   	(gmii_tx_er    ),
        .gmii_txd     	(gmii_txd      ),
        .rgmii_rxc    	(rgmii_rxc     ),
        .rgmii_rx_ctl 	(rgmii_rx_ctl  ),
        .rgmii_rxd    	(rgmii_rxd     ),
        .rgmii_txc    	(rgmii_txc     ),
        .rgmii_tx_ctl 	(rgmii_tx_ctl  ),
        .rgmii_txd    	(rgmii_txd     )
    );
end 
else if (TARGET == "ALTERA") begin
    //ALTERA FPGA
    enet_rgmii_to_gmii_dummy #(
        .IDELAY_VALUE 	(IDELAY_VALUE  ))
    u_enet_rgmii_to_gmii_dummy(
        .idelay_clk   	(idelay_clk    ),
        .gmii_rx_clk  	(gmii_rx_clk   ),
        .gmii_rx_dv   	(gmii_rx_dv    ),
        .gmii_rx_er   	(gmii_rx_er    ),
        .gmii_rxd     	(gmii_rxd      ),
        .gmii_tx_clk  	(gmii_tx_clk   ),
        .gmii_tx_en   	(gmii_tx_en    ),
        .gmii_tx_er   	(gmii_tx_er    ),
        .gmii_txd     	(gmii_txd      ),
        .rgmii_rxc    	(rgmii_rxc     ),
        .rgmii_rx_ctl 	(rgmii_rx_ctl  ),
        .rgmii_rxd    	(rgmii_rxd     ),
        .rgmii_txc    	(rgmii_txc     ),
        .rgmii_tx_ctl 	(rgmii_tx_ctl  ),
        .rgmii_txd    	(rgmii_txd     )
    );
end 
else if (TARGET == "SIM") begin
    //ALTERA FPGA
    enet_rgmii_to_gmii_sim #(
        .IDELAY_VALUE 	(IDELAY_VALUE  ))
    u_enet_rgmii_to_gmii_sim(
        .idelay_clk   	(idelay_clk    ),
        .gmii_rx_clk  	(gmii_rx_clk   ),
        .gmii_rx_dv   	(gmii_rx_dv    ),
        .gmii_rx_er   	(gmii_rx_er    ),
        .gmii_rxd     	(gmii_rxd      ),
        .gmii_tx_clk  	(gmii_tx_clk   ),
        .gmii_tx_en   	(gmii_tx_en    ),
        .gmii_tx_er   	(gmii_tx_er    ),
        .gmii_txd     	(gmii_txd      ),
        .rgmii_rxc    	(rgmii_rxc     ),
        .rgmii_rx_ctl 	(rgmii_rx_ctl  ),
        .rgmii_rxd    	(rgmii_rxd     ),
        .rgmii_txc    	(rgmii_txc     ),
        .rgmii_tx_ctl 	(rgmii_tx_ctl  ),
        .rgmii_txd    	(rgmii_txd     )
    );
end 
else begin
    //GENERIC
    enet_rgmii_to_gmii_dummy #(
        .IDELAY_VALUE 	(IDELAY_VALUE  ))
    u_enet_rgmii_to_gmii_dummy(
        .idelay_clk   	(idelay_clk    ),
        .gmii_rx_clk  	(gmii_rx_clk   ),
        .gmii_rx_dv   	(gmii_rx_dv    ),
        .gmii_rx_er   	(gmii_rx_er    ),
        .gmii_rxd     	(gmii_rxd      ),
        .gmii_tx_clk  	(gmii_tx_clk   ),
        .gmii_tx_en   	(gmii_tx_en    ),
        .gmii_tx_er   	(gmii_tx_er    ),
        .gmii_txd     	(gmii_txd      ),
        .rgmii_rxc    	(rgmii_rxc     ),
        .rgmii_rx_ctl 	(rgmii_rx_ctl  ),
        .rgmii_rxd    	(rgmii_rxd     ),
        .rgmii_txc    	(rgmii_txc     ),
        .rgmii_tx_ctl 	(rgmii_tx_ctl  ),
        .rgmii_txd    	(rgmii_txd     )
    );
end

endmodule //enet_rgmii_to_gmii
