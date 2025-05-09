module enet_core#(
    // target ("SIM", "GENERIC", "XILINX", "ALTERA")
    parameter TARGET = "GENERIC",
    //输入数据IO延时(如果为n,表示延时n*78ps) 
    parameter IDELAY_VALUE = 0,

    parameter AXI_ID_TX = 3,
    parameter AXI_ID_RX = 3,

    // Address width in bits
    parameter AXI_MAC_ADDR_W = 32,
    // ID width in bits
    parameter AXI_MAC_ID_W = 8,
    // Data width in bits
    parameter AXI_MAC_DATA_W = 64,

    // Address width in bits
    parameter AXI_REG_ADDR_W = 32,
    // ID width in bits
    parameter AXI_REG_ID_W = 8,
    // Data width in bits
    parameter AXI_REG_DATA_W = 32
)(
    input                               clk,
    input                               clk_200m,
    input                               enet_rst_n,
    output                              rst_n,

    output                              enet_gtx_clk,
    // input                               enet_grx_clk,
    output                              enet_rgmii_tx_ctl,
    output [3:0]                        enet_rgmii_txd,
    input                               enet_rgmii_rx_ctl,   
    input  [3:0]                        enet_rgmii_rxd,
    input                               enet_tx_clk,
    input                               enet_rx_clk,
    input                               enet_ref_clk,
    output [7:0]                        enet_txd,
    output                              enet_tx_en,
    output                              enet_tx_er,
    input  [7:0]                        enet_rxd,
    input                               enet_rx_dv,
    input                               enet_rx_er,

    input                               enet_col,
    input                               enet_crs,

    output                              mdc,
    input                               mdi,
    output                              mdo,
    output                              mdo_en,

    input                               mst_awvalid,
    output                              mst_awready,
    input  [AXI_REG_ADDR_W    -1:0]     mst_awaddr,
    input  [8                 -1:0]     mst_awlen,
    input  [3                 -1:0]     mst_awsize,
    input  [2                 -1:0]     mst_awburst,
    input                               mst_awlock,
    input  [4                 -1:0]     mst_awcache,
    input  [3                 -1:0]     mst_awprot,
    input  [4                 -1:0]     mst_awqos,
    input  [4                 -1:0]     mst_awregion,
    input  [AXI_REG_ID_W      -1:0]     mst_awid,
    input                               mst_wvalid,
    output                              mst_wready,
    input                               mst_wlast,
    input  [AXI_REG_DATA_W    -1:0]     mst_wdata,
    input  [AXI_REG_DATA_W/8  -1:0]     mst_wstrb,
    output                              mst_bvalid,
    input                               mst_bready,
    output [AXI_REG_ID_W      -1:0]     mst_bid,
    output [2                 -1:0]     mst_bresp,
    input                               mst_arvalid,
    output                              mst_arready,
    input  [AXI_REG_ADDR_W    -1:0]     mst_araddr,
    input  [8                 -1:0]     mst_arlen,
    input  [3                 -1:0]     mst_arsize,
    input  [2                 -1:0]     mst_arburst,
    input                               mst_arlock,
    input  [4                 -1:0]     mst_arcache,
    input  [3                 -1:0]     mst_arprot,
    input  [4                 -1:0]     mst_arqos,
    input  [4                 -1:0]     mst_arregion,
    input  [AXI_REG_ID_W      -1:0]     mst_arid,
    output                              mst_rvalid,
    input                               mst_rready,
    output [AXI_REG_ID_W      -1:0]     mst_rid,
    output [2                 -1:0]     mst_rresp,
    output [AXI_REG_DATA_W    -1:0]     mst_rdata,
    output                              mst_rlast,

    output                              tx_clk,
    output                              tx_rst_n,
    output                              slv_tx_awvalid,
    input                               slv_tx_awready,
    output [AXI_MAC_ADDR_W    -1:0]     slv_tx_awaddr,
    output [8                 -1:0]     slv_tx_awlen,
    output [3                 -1:0]     slv_tx_awsize,
    output [2                 -1:0]     slv_tx_awburst,
    output                              slv_tx_awlock,
    output [4                 -1:0]     slv_tx_awcache,
    output [3                 -1:0]     slv_tx_awprot,
    output [4                 -1:0]     slv_tx_awqos,
    output [4                 -1:0]     slv_tx_awregion,
    output [AXI_MAC_ID_W      -1:0]     slv_tx_awid,
    output                              slv_tx_wvalid,
    input                               slv_tx_wready,
    output                              slv_tx_wlast, 
    output [AXI_MAC_DATA_W    -1:0]     slv_tx_wdata,
    output [AXI_MAC_DATA_W/8  -1:0]     slv_tx_wstrb,
    input                               slv_tx_bvalid,
    output                              slv_tx_bready,
    input  [AXI_MAC_ID_W      -1:0]     slv_tx_bid,
    input  [2                 -1:0]     slv_tx_bresp,
    output                              slv_tx_arvalid,
    input                               slv_tx_arready,
    output [AXI_MAC_ADDR_W    -1:0]     slv_tx_araddr,
    output [8                 -1:0]     slv_tx_arlen,
    output [3                 -1:0]     slv_tx_arsize,
    output [2                 -1:0]     slv_tx_arburst,
    output                              slv_tx_arlock,
    output [4                 -1:0]     slv_tx_arcache,
    output [3                 -1:0]     slv_tx_arprot,
    output [4                 -1:0]     slv_tx_arqos,
    output [4                 -1:0]     slv_tx_arregion,
    output [AXI_MAC_ID_W      -1:0]     slv_tx_arid,
    input                               slv_tx_rvalid,
    output                              slv_tx_rready,
    input  [AXI_MAC_ID_W      -1:0]     slv_tx_rid,
    input  [2                 -1:0]     slv_tx_rresp,
    input  [AXI_MAC_DATA_W    -1:0]     slv_tx_rdata,
    input                               slv_tx_rlast,

    output                              rx_clk,
    output                              rx_rst_n,
    output                              slv_rx_awvalid,
    input                               slv_rx_awready,
    output [AXI_MAC_ADDR_W    -1:0]     slv_rx_awaddr,
    output [8                 -1:0]     slv_rx_awlen,
    output [3                 -1:0]     slv_rx_awsize,
    output [2                 -1:0]     slv_rx_awburst,
    output                              slv_rx_awlock,
    output [4                 -1:0]     slv_rx_awcache,
    output [3                 -1:0]     slv_rx_awprot,
    output [4                 -1:0]     slv_rx_awqos,
    output [4                 -1:0]     slv_rx_awregion,
    output [AXI_MAC_ID_W      -1:0]     slv_rx_awid,
    output                              slv_rx_wvalid,
    input                               slv_rx_wready,
    output                              slv_rx_wlast, 
    output [AXI_MAC_DATA_W    -1:0]     slv_rx_wdata,
    output [AXI_MAC_DATA_W/8  -1:0]     slv_rx_wstrb,
    input                               slv_rx_bvalid,
    output                              slv_rx_bready,
    input  [AXI_MAC_ID_W      -1:0]     slv_rx_bid,
    input  [2                 -1:0]     slv_rx_bresp,
    output                              slv_rx_arvalid,
    input                               slv_rx_arready,
    output [AXI_MAC_ADDR_W    -1:0]     slv_rx_araddr,
    output [8                 -1:0]     slv_rx_arlen,
    output [3                 -1:0]     slv_rx_arsize,
    output [2                 -1:0]     slv_rx_arburst,
    output                              slv_rx_arlock,
    output [4                 -1:0]     slv_rx_arcache,
    output [3                 -1:0]     slv_rx_arprot,
    output [4                 -1:0]     slv_rx_arqos,
    output [4                 -1:0]     slv_rx_arregion,
    output [AXI_MAC_ID_W      -1:0]     slv_rx_arid,
    input                               slv_rx_rvalid,
    output                              slv_rx_rready,
    input  [AXI_MAC_ID_W      -1:0]     slv_rx_rid,
    input  [2                 -1:0]     slv_rx_rresp,
    input  [AXI_MAC_DATA_W    -1:0]     slv_rx_rdata,
    input                               slv_rx_rlast
);

// output declaration of module enet_axi2reg
wire        eir_wen;
wire        eimr_wen;
wire        rdar_wen;
wire        tdar_wen;
wire        ecr_wen;
wire        mmfr_wen;
wire        mscr_wen;
wire        tcr_wen;
wire        rcr_wen;
wire        palr_wen;
wire        paur_wen;
wire        opd_wen;
wire        txic_wen;
wire        rxic_wen;
wire        ialr_wen;
wire        iaur_wen;
wire        galr_wen;
wire        gaur_wen;
wire        rdsr_wen;
wire        tdsr_wen;
wire        rsfl_wen;
wire        rsem_wen;
wire        rafl_wen;
wire        raem_wen;
wire        tfwr_wen;
wire        tsem_wen;
wire        tafl_wen;
wire        taem_wen;
wire        tipg_wen;
wire        ftrl_wen;
wire        rdar_ren;
wire        tdar_ren;
wire        tcr_ren;
wire        rcr_ren;
wire [11:0] reg_addr;
wire [31:0] reg_wdata;

// output declaration of module enet_ecr
wire [31:0] ecr;
wire        ether_en;
wire        mii_select;
wire        rmii_select;
wire        rmii_10T;

// output declaration of module enet_rmii_to_mii
wire        rmii_rx_clk;
wire        rmii_rx_dv;
wire [3:0]  rmii_rxd;
wire        rmii_tx_clk;
wire        rmii_tx_en;
wire        rmii_rx_er;
wire [1:0] rmii_txd;

// output declaration of module enet_rgmii_to_gmii
wire        rgmii_rx_clk;
wire        rgmii_rx_dv;
wire        rgmii_rx_er;
wire [7:0]  rgmii_rxd;
wire        rgmii_tx_clk;

// output declaration of module enet_chclk
wire        txclk_lock;
wire        rxclk_lock;
wire [7:0]  rxd;
wire        rx_dv;
wire        rx_er;

// output declaration of module tx_enet_intr_coalesce
wire [31:0] txic;
wire txf;

// output declaration of module rx_enet_intr_coalesce
wire [31:0] rxic;
wire rxf;

// output declaration of module mdio_if
wire        mii;
wire [31:0] mmfr;
wire [31:0] mscr;

// output declaration of module normal_reg
wire        write_success;
wire        read_done;
wire        Tx_out_wen;
wire [44:0] Tx_out_data_in;
wire        Tx_in_ren;
wire        Rx_out_wen;
wire [44:0] Rx_out_data_in;
wire        Rx_in_ren;
wire        babr;
wire        babt;
wire        gra;
wire        rxf_in;
wire        txf_in;
wire        eberr;
wire        lc;
wire        rl;
wire        un;
wire        plr;
wire [31:0] eimr;
wire [31:0] tcr;
wire [31:0] tdar;
wire [31:0] rcr;
wire [31:0] rdar;
wire [31:0] palr;
wire [31:0] paur;
wire [31:0] opd;
wire [31:0] ialr;
wire [31:0] iaur;
wire [31:0] galr;
wire [31:0] gaur;
wire [31:0] rdsr;
wire [31:0] tdsr;
wire [31:0] rsfl;
wire [31:0] rsem;
wire [31:0] rafl;
wire [31:0] raem;
wire [31:0] tfwr;
wire [31:0] tsem;
wire [31:0] tafl;
wire [31:0] taem;
wire [31:0] tipg;
wire [31:0] ftrl;

// output declaration of module mac_tx
wire [7:0]  gmii_txd;
wire        gmii_tx_en;
wire        gmii_tx_er;
wire        Tx_in_wen;
wire [43:0] Tx_in_data_in;
wire        Tx_out_ren;
wire        pause_rdy_out;

// output declaration of module mac_rx
wire        Rx_in_wen;
wire [43:0] Rx_in_data_in;
wire        Rx_out_ren;
wire        pause_req_in;
wire [17:0] pause_data_in;

// output declaration of module Tx_out
wire        Tx_out_full;
wire        Tx_out_empty;
wire [44:0] Tx_out_data_out;

// output declaration of module Tx_in
wire        Tx_in_full;
wire        Tx_in_empty;
wire [43:0] Tx_in_data_out;

// output declaration of module Rx_out
wire        Rx_out_full;
wire        Rx_out_empty;
wire [44:0] Rx_out_data_out;

// output declaration of module Rx_in
wire        Rx_in_full;
wire        Rx_in_empty;
wire [43:0] Rx_in_data_out;

// output declaration of module pause_cdc_handle
wire        pause_rdy_in;
wire        pause_req_out;
wire [17:0] pause_data_out;

wire [31:0] eir;
assign eir = {
    1'b0,   // 31
    babr,   // 30
    babt,   // 29
    gra,    // 28
    txf,    // 27
    1'b0,   // 26
    rxf,    // 25
    1'b0,   // 24
    mii,    // 23
    eberr,  // 22
    lc,     // 21
    rl,     // 20
    un,     // 19
    plr,    // 18
    18'h0   // 17:0
};

enet_axi2reg #(
    .AXI_ADDR_W 	(AXI_REG_ADDR_W  ),
    .AXI_ID_W   	(AXI_REG_ID_W    ),
    .AXI_DATA_W 	(AXI_REG_DATA_W  ))
u_enet_axi2reg(
    .clk           	(clk            ),
    .rst_n         	(rst_n          ),
    .eir_wen       	(eir_wen        ),
    .eimr_wen      	(eimr_wen       ),
    .rdar_wen      	(rdar_wen       ),
    .tdar_wen      	(tdar_wen       ),
    .ecr_wen       	(ecr_wen        ),
    .mmfr_wen      	(mmfr_wen       ),
    .mscr_wen      	(mscr_wen       ),
    .tcr_wen       	(tcr_wen        ),
    .rcr_wen       	(rcr_wen        ),
    .palr_wen      	(palr_wen       ),
    .paur_wen      	(paur_wen       ),
    .opd_wen       	(opd_wen        ),
    .txic_wen      	(txic_wen       ),
    .rxic_wen      	(rxic_wen       ),
    .ialr_wen      	(ialr_wen       ),
    .iaur_wen      	(iaur_wen       ),
    .galr_wen      	(galr_wen       ),
    .gaur_wen      	(gaur_wen       ),
    .rdsr_wen      	(rdsr_wen       ),
    .tdsr_wen      	(tdsr_wen       ),
    .rsfl_wen      	(rsfl_wen       ),
    .rsem_wen      	(rsem_wen       ),
    .rafl_wen      	(rafl_wen       ),
    .raem_wen      	(raem_wen       ),
    .tfwr_wen      	(tfwr_wen       ),
    .tsem_wen      	(tsem_wen       ),
    .tafl_wen      	(tafl_wen       ),
    .taem_wen      	(taem_wen       ),
    .tipg_wen      	(tipg_wen       ),
    .ftrl_wen      	(ftrl_wen       ),
    .write_success 	(write_success  ),
    .rdar_ren      	(rdar_ren       ),
    .tdar_ren      	(tdar_ren       ),
    .tcr_ren       	(tcr_ren        ),
    .rcr_ren       	(rcr_ren        ),
    .read_done     	(read_done      ),
    .reg_addr      	(reg_addr       ),
    .reg_wdata     	(reg_wdata      ),
    .eir           	(eir            ),
    .eimr          	(eimr           ),
    .ecr           	(ecr            ),
    .mmfr          	(mmfr           ),
    .mscr          	(mscr           ),
    .tcr           	(tcr            ),
    .tdar          	(tdar           ),
    .rcr           	(rcr            ),
    .rdar          	(rdar           ),
    .palr          	(palr           ),
    .paur          	(paur           ),
    .opd           	(opd            ),
    .txic          	(txic           ),
    .rxic          	(rxic           ),
    .ialr          	(ialr           ),
    .iaur          	(iaur           ),
    .galr          	(galr           ),
    .gaur          	(gaur           ),
    .rdsr          	(rdsr           ),
    .tdsr          	(tdsr           ),
    .rsfl          	(rsfl           ),
    .rsem          	(rsem           ),
    .rafl          	(rafl           ),
    .raem          	(raem           ),
    .tfwr          	(tfwr           ),
    .tsem          	(tsem           ),
    .tafl          	(tafl           ),
    .taem          	(taem           ),
    .tipg          	(tipg           ),
    .ftrl          	(ftrl           ),
    .mst_awvalid   	(mst_awvalid    ),
    .mst_awready   	(mst_awready    ),
    .mst_awaddr    	(mst_awaddr     ),
    .mst_awlen     	(mst_awlen      ),
    .mst_awsize    	(mst_awsize     ),
    .mst_awburst   	(mst_awburst    ),
    .mst_awlock    	(mst_awlock     ),
    .mst_awcache   	(mst_awcache    ),
    .mst_awprot    	(mst_awprot     ),
    .mst_awqos     	(mst_awqos      ),
    .mst_awregion  	(mst_awregion   ),
    .mst_awid      	(mst_awid       ),
    .mst_wvalid    	(mst_wvalid     ),
    .mst_wready    	(mst_wready     ),
    .mst_wlast     	(mst_wlast      ),
    .mst_wdata     	(mst_wdata      ),
    .mst_wstrb     	(mst_wstrb      ),
    .mst_bvalid    	(mst_bvalid     ),
    .mst_bready    	(mst_bready     ),
    .mst_bid       	(mst_bid        ),
    .mst_bresp     	(mst_bresp      ),
    .mst_arvalid   	(mst_arvalid    ),
    .mst_arready   	(mst_arready    ),
    .mst_araddr    	(mst_araddr     ),
    .mst_arlen     	(mst_arlen      ),
    .mst_arsize    	(mst_arsize     ),
    .mst_arburst   	(mst_arburst    ),
    .mst_arlock    	(mst_arlock     ),
    .mst_arcache   	(mst_arcache    ),
    .mst_arprot    	(mst_arprot     ),
    .mst_arqos     	(mst_arqos      ),
    .mst_arregion  	(mst_arregion   ),
    .mst_arid      	(mst_arid       ),
    .mst_rvalid    	(mst_rvalid     ),
    .mst_rready    	(mst_rready     ),
    .mst_rid       	(mst_rid        ),
    .mst_rresp     	(mst_rresp      ),
    .mst_rdata     	(mst_rdata      ),
    .mst_rlast     	(mst_rlast      )
);

enet_ecr u_enet_ecr(
    .clk           	(clk            ),
    .enet_rst_n    	(enet_rst_n     ),
    .rst_n         	(rst_n          ),
    .ecr_wen       	(ecr_wen        ),
    // .write_success 	(write_success  ),
    .reg_wdata     	(reg_wdata      ),
    .txclk_lock     (txclk_lock     ),
    .rxclk_lock     (rxclk_lock     ),
    .Tx_in_full     (Tx_in_full     ),
    .Tx_in_empty    (Tx_in_empty    ),
    .Tx_out_full    (Tx_out_full    ),
    .Tx_out_empty   (Tx_out_empty   ),
    .Rx_in_full     (Rx_in_full     ),
    .Rx_in_empty    (Rx_in_empty    ),
    .Rx_out_full    (Rx_out_full    ),
    .Rx_out_empty   (Rx_out_empty   ),
    .ecr           	(ecr            ),
    .ether_en       (ether_en       ),
    .mii_select    	(mii_select     ),
    .rmii_select   	(rmii_select    ),
    .rmii_10T      	(rmii_10T       )
);

enet_rmii_to_mii u_enet_rmii_to_mii(
    .rst_n        	    (rst_n            ),
    .rmii_10T     	    (rmii_10T         ),    
    .mii_rx_clk     	(rmii_rx_clk      ),
    .mii_rx_dv      	(rmii_rx_dv       ),
    .mii_rx_er     	    (rmii_rx_er       ),
    .mii_rxd        	(rmii_rxd         ),
    .mii_tx_clk     	(rmii_tx_clk      ),
    .mii_tx_en      	(gmii_tx_en       ),
    .mii_tx_er      	(gmii_tx_er       ),
    .mii_txd        	(gmii_txd[3:0]    ),

    .rmii_ref_clk   	(enet_ref_clk     ),
    .rmii_rx_crs_dv 	(enet_rx_dv       ),
    .rmii_rxd       	(enet_rxd[1:0]    ),
    .rmii_tx_en     	(rmii_tx_en       ),
    .rmii_txd       	(rmii_txd         )
);

enet_rgmii_to_gmii #(
    .TARGET        	(TARGET         ),
    .IDELAY_VALUE 	(IDELAY_VALUE   ))
u_enet_rgmii_to_gmii_xlinx(
    .idelay_clk   	(clk_200m               ),
    .gmii_rx_clk  	(rgmii_rx_clk           ),
    .gmii_rx_dv   	(rgmii_rx_dv            ),
    .gmii_rx_er   	(rgmii_rx_er            ),
    .gmii_rxd     	(rgmii_rxd              ),
    .gmii_tx_clk  	(rgmii_tx_clk           ),
    .gmii_tx_en   	(gmii_tx_en             ),
    .gmii_tx_er   	(gmii_tx_er             ),
    .gmii_txd     	(gmii_txd               ),
    .rgmii_rxc    	(enet_rx_clk            ),
    .rgmii_rx_ctl 	(enet_rgmii_rx_ctl      ),
    .rgmii_rxd    	(enet_rgmii_rxd         ),
    .rgmii_txc    	(enet_gtx_clk           ),
    .rgmii_tx_ctl 	(enet_rgmii_tx_ctl      ),
    .rgmii_txd    	(enet_rgmii_txd         )
);


enet_chclk u_enet_chclk(
    .clk            (clk                ),
    .rst_n        	(rst_n              ),
    .mii_select   	(mii_select         ),
    .rmii_select  	(rmii_select        ),

    .mii_tx_clk   	(enet_tx_clk        ),
    .mii_rx_clk   	(enet_rx_clk        ),
    .mii_txd      	(gmii_txd           ),
    .mii_rxd      	(enet_rxd           ),
    .mii_tx_en    	(gmii_tx_en         ),
    .mii_tx_er    	(gmii_tx_er         ),
    .mii_rx_dv    	(enet_rx_dv         ),
    .mii_rx_er    	(enet_rx_er         ),

    .rmii_tx_clk  	(rmii_tx_clk        ),
    .rmii_rx_clk  	(rmii_rx_clk        ),
    .rmii_txd     	({6'h0, rmii_txd}   ),
    .rmii_rxd     	({4'h0, rmii_rxd}   ),
    .rmii_tx_en   	(rmii_tx_en         ),
    .rmii_tx_er   	(1'b0               ),
    .rmii_rx_dv   	(rmii_rx_dv         ),
    .rmii_rx_er   	(rmii_rx_er         ),

    .gmii_tx_clk  	(enet_gtx_clk       ),
    .gmii_rx_clk  	(enet_rx_clk        ),
    .gmii_txd     	(gmii_txd           ),
    .gmii_rxd     	(enet_rxd           ),
    .gmii_tx_en   	(gmii_tx_en         ),
    .gmii_tx_er   	(gmii_tx_er         ),
    .gmii_rx_dv   	(enet_rx_dv         ),
    .gmii_rx_er   	(enet_rx_er         ),

    .rgmii_tx_clk 	(rgmii_tx_clk       ),
    .rgmii_rx_clk 	(rgmii_rx_clk       ),
    .rgmii_txd    	({8'h0}             ),
    .rgmii_rxd    	(rgmii_rxd          ),
    .rgmii_tx_en  	(1'b0               ),
    .rgmii_tx_er  	(1'b0               ),
    .rgmii_rx_dv  	(rgmii_rx_dv        ),
    .rgmii_rx_er  	(rgmii_rx_er        ),

    .txclk_lock     (txclk_lock         ),
    .rxclk_lock     (rxclk_lock         ),

    .tx_clk       	(tx_clk             ),
    .tx_rst_n   	(tx_rst_n           ),
    .rx_clk       	(rx_clk             ),
    .rx_rst_n       (rx_rst_n           ),
    .txd          	(enet_txd           ),
    .rxd          	(rxd                ),
    .tx_en        	(enet_tx_en         ),
    .tx_er        	(enet_tx_er         ),
    .rx_dv        	(rx_dv              ),
    .rx_er        	(rx_er              )
);

enet_intr_coalesce u_tx_enet_intr_coalesce(
    .clk           	(clk                        ),
    .rst_n         	(rst_n                      ),
    .eir_in        	(eir_wen & reg_wdata[27]    ),
    .intr_coal_wen 	(txic_wen                   ),
    .reg_wdata     	(reg_wdata                  ),
    .intr_coal     	(txic                       ),
    .intr_in       	(txf_in                     ),
    .intr          	(txf                        )
);


enet_intr_coalesce u_rx_enet_intr_coalesce(
    .clk           	(clk                        ),
    .rst_n         	(rst_n                      ),
    .eir_in        	(eir_wen & reg_wdata[25]    ),
    .intr_coal_wen 	(rxic_wen                   ),
    .reg_wdata     	(reg_wdata                  ),
    .intr_coal     	(rxic                       ),
    .intr_in       	(rxf_in                     ),
    .intr          	(rxf                        )
);


mdio_if u_mdio_if(
    .clk       	(clk        ),
    .rst_n     	(rst_n      ),
    .sync_rst  	(!ether_en  ),
    .eir_wen   	(eir_wen    ),
    .mmfr_wen  	(mmfr_wen   ),
    .mscr_wen  	(mscr_wen   ),
    .reg_wdata 	(reg_wdata  ),
    .mii       	(mii        ),
    .mmfr      	(mmfr       ),
    .mscr      	(mscr       ),
    .mdc       	(mdc        ),
    .mdi       	(mdi        ),
    .mdo       	(mdo        ),
    .mdo_en    	(mdo_en     )
);

enet_normal_reg u_normal_reg(
    .clk            	(clk             ),
    .rst_n          	(rst_n           ),
    .eir_wen        	(eir_wen         ),
    .eimr_wen           (eimr_wen        ),
    .rdar_wen       	(rdar_wen        ),
    .tdar_wen       	(tdar_wen        ),
    .ecr_wen        	(ecr_wen         ),
    .tcr_wen        	(tcr_wen         ),
    .rcr_wen        	(rcr_wen         ),
    .palr_wen       	(palr_wen        ),
    .paur_wen       	(paur_wen        ),
    .opd_wen        	(opd_wen         ),
    .ialr_wen       	(ialr_wen        ),
    .iaur_wen       	(iaur_wen        ),
    .galr_wen       	(galr_wen        ),
    .gaur_wen       	(gaur_wen        ),
    .rdsr_wen       	(rdsr_wen        ),
    .tdsr_wen       	(tdsr_wen        ),
    .rsfl_wen       	(rsfl_wen        ),
    .rsem_wen       	(rsem_wen        ),
    .rafl_wen       	(rafl_wen        ),
    .raem_wen       	(raem_wen        ),
    .tfwr_wen       	(tfwr_wen        ),
    .tsem_wen       	(tsem_wen        ),
    .tafl_wen       	(tafl_wen        ),
    .taem_wen       	(taem_wen        ),
    .tipg_wen       	(tipg_wen        ),
    .ftrl_wen       	(ftrl_wen        ),
    .write_success  	(write_success   ),
    .rdar_ren       	(rdar_ren        ),
    .tdar_ren       	(tdar_ren        ),
    .tcr_ren        	(tcr_ren         ),
    .rcr_ren        	(rcr_ren         ),
    .read_done      	(read_done       ),
    .reg_addr       	(reg_addr        ),
    .reg_wdata      	(reg_wdata       ),
    .Tx_out_full    	(Tx_out_full     ),
    .Tx_out_wen     	(Tx_out_wen      ),
    .Tx_out_data_in 	(Tx_out_data_in  ),
    .Tx_in_empty    	(Tx_in_empty     ),
    .Tx_in_ren      	(Tx_in_ren       ),
    .Tx_in_data_out 	(Tx_in_data_out  ),
    .Rx_out_full    	(Rx_out_full     ),
    .Rx_out_wen     	(Rx_out_wen      ),
    .Rx_out_data_in 	(Rx_out_data_in  ),
    .Rx_in_empty    	(Rx_in_empty     ),
    .Rx_in_ren      	(Rx_in_ren       ),
    .Rx_in_data_out 	(Rx_in_data_out  ),
    .babr           	(babr            ),
    .babt           	(babt            ),
    .gra            	(gra             ),
    .rxf_in         	(rxf_in          ),
    .txf_in         	(txf_in          ),
    .eberr          	(eberr           ),
    .lc             	(lc              ),
    .rl             	(rl              ),
    .un             	(un              ),
    .plr            	(plr             ),
    .eimr               (eimr            ),
    .tcr            	(tcr             ),
    .tdar           	(tdar            ),
    .rcr            	(rcr             ),
    .rdar           	(rdar            ),
    .palr           	(palr            ),
    .paur           	(paur            ),
    .opd            	(opd             ),
    .ialr           	(ialr            ),
    .iaur           	(iaur            ),
    .galr           	(galr            ),
    .gaur           	(gaur            ),
    .rdsr           	(rdsr            ),
    .tdsr           	(tdsr            ),
    .rsfl           	(rsfl            ),
    .rsem           	(rsem            ),
    .rafl           	(rafl            ),
    .raem           	(raem            ),
    .tfwr           	(tfwr            ),
    .tsem           	(tsem            ),
    .tafl           	(tafl            ),
    .taem           	(taem            ),
    .tipg           	(tipg            ),
    .ftrl           	(ftrl            )
);

async_fifo_my #(
    .DATA_LEN     	(45      ),
    .ADDR_LEN     	(3       ),
    .READ_THROUGH 	("TRUE"  ))
u_Tx_out(
    .clk_w    	(clk             ),
    .rstn_w   	(rst_n           ),
    .full     	(Tx_out_full     ),
    .wen      	(Tx_out_wen      ),
    .data_in  	(Tx_out_data_in  ),
    .clk_r    	(tx_clk          ),
    .rstn_r   	(tx_rst_n        ),
    .empty    	(Tx_out_empty    ),
    .ren      	(Tx_out_ren      ),
    .data_out 	(Tx_out_data_out )
);

async_fifo_my #(
    .DATA_LEN     	(44      ),
    .ADDR_LEN     	(3       ),
    .READ_THROUGH 	("TRUE"  ))
u_Tx_in(
    .clk_w    	(tx_clk          ),
    .rstn_w   	(tx_rst_n        ),
    .full     	(Tx_in_full      ),
    .wen      	(Tx_in_wen       ),
    .data_in  	(Tx_in_data_in   ),
    .clk_r    	(clk             ),
    .rstn_r   	(rst_n           ),
    .empty    	(Tx_in_empty     ),
    .ren      	(Tx_in_ren       ),
    .data_out 	(Tx_in_data_out  )
);

async_fifo_my #(
    .DATA_LEN     	(45      ),
    .ADDR_LEN     	(3       ),
    .READ_THROUGH 	("TRUE"  ))
u_Rx_out(
    .clk_w    	(clk             ),
    .rstn_w   	(rst_n           ),
    .full     	(Rx_out_full     ),
    .wen      	(Rx_out_wen      ),
    .data_in  	(Rx_out_data_in  ),
    .clk_r    	(rx_clk          ),
    .rstn_r   	(rx_rst_n        ),
    .empty    	(Rx_out_empty    ),
    .ren      	(Rx_out_ren      ),
    .data_out 	(Rx_out_data_out )
);

async_fifo_my #(
    .DATA_LEN     	(44      ),
    .ADDR_LEN     	(3       ),
    .READ_THROUGH 	("TRUE"  ))
u_Rx_in(
    .clk_w    	(rx_clk          ),
    .rstn_w   	(rx_rst_n        ),
    .full     	(Rx_in_full      ),
    .wen      	(Rx_in_wen       ),
    .data_in  	(Rx_in_data_in   ),
    .clk_r    	(clk             ),
    .rstn_r   	(rst_n           ),
    .empty    	(Rx_in_empty     ),
    .ren      	(Rx_in_ren       ),
    .data_out 	(Rx_in_data_out  )
);

mac_tx #(
    .AXI_ID_SB  	(AXI_ID_TX       ),
    .AXI_ADDR_W 	(AXI_MAC_ADDR_W  ),
    .AXI_ID_W   	(AXI_MAC_ID_W    ),
    .AXI_DATA_W 	(AXI_MAC_DATA_W  ))
u_mac_tx(
    .tx_clk         	(tx_clk             ),
    .rst_n          	(tx_rst_n           ),
    .gmii_txd       	(gmii_txd           ),
    .gmii_tx_en     	(gmii_tx_en         ),
    .gmii_tx_er     	(gmii_tx_er         ),
    .gmii_crs       	(enet_crs           ),
    .gmii_col       	(enet_col           ),
    .Tx_in_full     	(Tx_in_full         ),
    .Tx_in_wen      	(Tx_in_wen          ),
    .Tx_in_data_in 	    (Tx_in_data_in      ),
    .Tx_out_empty   	(Tx_out_empty       ),
    .Tx_out_ren     	(Tx_out_ren         ),
    .Tx_out_data_out 	(Tx_out_data_out    ),
    .pause_req_out  	(pause_req_out      ),
    .pause_rdy_out  	(pause_rdy_out      ),
    .pause_data_out 	(pause_data_out     ),
    .slv_awvalid    	(slv_tx_awvalid     ),
    .slv_awready    	(slv_tx_awready     ),
    .slv_awaddr     	(slv_tx_awaddr      ),
    .slv_awlen      	(slv_tx_awlen       ),
    .slv_awsize     	(slv_tx_awsize      ),
    .slv_awburst    	(slv_tx_awburst     ),
    .slv_awlock     	(slv_tx_awlock      ),
    .slv_awcache    	(slv_tx_awcache     ),
    .slv_awprot     	(slv_tx_awprot      ),
    .slv_awqos      	(slv_tx_awqos       ),
    .slv_awregion   	(slv_tx_awregion    ),
    .slv_awid       	(slv_tx_awid        ),
    .slv_wvalid     	(slv_tx_wvalid      ),
    .slv_wready     	(slv_tx_wready      ),
    .slv_wlast      	(slv_tx_wlast       ),
    .slv_wdata      	(slv_tx_wdata       ),
    .slv_wstrb      	(slv_tx_wstrb       ),
    .slv_bvalid     	(slv_tx_bvalid      ),
    .slv_bready     	(slv_tx_bready      ),
    .slv_bid        	(slv_tx_bid         ),
    .slv_bresp      	(slv_tx_bresp       ),
    .slv_arvalid    	(slv_tx_arvalid     ),
    .slv_arready    	(slv_tx_arready     ),
    .slv_araddr     	(slv_tx_araddr      ),
    .slv_arlen      	(slv_tx_arlen       ),
    .slv_arsize     	(slv_tx_arsize      ),
    .slv_arburst    	(slv_tx_arburst     ),
    .slv_arlock     	(slv_tx_arlock      ),
    .slv_arcache    	(slv_tx_arcache     ),
    .slv_arprot     	(slv_tx_arprot      ),
    .slv_arqos      	(slv_tx_arqos       ),
    .slv_arregion   	(slv_tx_arregion    ),
    .slv_arid       	(slv_tx_arid        ),
    .slv_rvalid     	(slv_tx_rvalid      ),
    .slv_rready     	(slv_tx_rready      ),
    .slv_rid        	(slv_tx_rid         ),
    .slv_rresp      	(slv_tx_rresp       ),
    .slv_rdata      	(slv_tx_rdata       ),
    .slv_rlast      	(slv_tx_rlast       )
);

mac_rx #(
    .AXI_ID_SB  	(AXI_ID_RX       ),
    .AXI_ADDR_W 	(AXI_MAC_ADDR_W  ),
    .AXI_ID_W   	(AXI_MAC_ID_W    ),
    .AXI_DATA_W 	(AXI_MAC_DATA_W  ))
u_mac_rx(
    .rx_clk          	(rx_clk           ),
    .rst_n           	(rx_rst_n         ),
    .gmii_rxd        	(rxd              ),
    .gmii_rx_dv      	(rx_dv            ),
    .gmii_rx_er      	(rx_er            ),
    .gmii_crs        	(enet_crs         ),
    .gmii_col        	(enet_col         ),
    .Rx_in_full      	(Rx_in_full       ),
    .Rx_in_wen       	(Rx_in_wen        ),
    .Rx_in_data_in   	(Rx_in_data_in    ),
    .Rx_out_empty    	(Rx_out_empty     ),
    .Rx_out_ren      	(Rx_out_ren       ),
    .Rx_out_data_out 	(Rx_out_data_out  ),
    .pause_req_in    	(pause_req_in     ),
    .pause_rdy_in    	(pause_rdy_in     ),
    .pause_data_in   	(pause_data_in    ),
    .slv_awvalid     	(slv_rx_awvalid   ),
    .slv_awready     	(slv_rx_awready   ),
    .slv_awaddr      	(slv_rx_awaddr    ),
    .slv_awlen       	(slv_rx_awlen     ),
    .slv_awsize      	(slv_rx_awsize    ),
    .slv_awburst     	(slv_rx_awburst   ),
    .slv_awlock      	(slv_rx_awlock    ),
    .slv_awcache     	(slv_rx_awcache   ),
    .slv_awprot      	(slv_rx_awprot    ),
    .slv_awqos       	(slv_rx_awqos     ),
    .slv_awregion    	(slv_rx_awregion  ),
    .slv_awid        	(slv_rx_awid      ),
    .slv_wvalid      	(slv_rx_wvalid    ),
    .slv_wready      	(slv_rx_wready    ),
    .slv_wlast       	(slv_rx_wlast     ),
    .slv_wdata       	(slv_rx_wdata     ),
    .slv_wstrb       	(slv_rx_wstrb     ),
    .slv_bvalid      	(slv_rx_bvalid    ),
    .slv_bready      	(slv_rx_bready    ),
    .slv_bid         	(slv_rx_bid       ),
    .slv_bresp       	(slv_rx_bresp     ),
    .slv_arvalid     	(slv_rx_arvalid   ),
    .slv_arready     	(slv_rx_arready   ),
    .slv_araddr      	(slv_rx_araddr    ),
    .slv_arlen       	(slv_rx_arlen     ),
    .slv_arsize      	(slv_rx_arsize    ),
    .slv_arburst     	(slv_rx_arburst   ),
    .slv_arlock      	(slv_rx_arlock    ),
    .slv_arcache     	(slv_rx_arcache   ),
    .slv_arprot      	(slv_rx_arprot    ),
    .slv_arqos       	(slv_rx_arqos     ),
    .slv_arregion    	(slv_rx_arregion  ),
    .slv_arid        	(slv_rx_arid      ),
    .slv_rvalid      	(slv_rx_rvalid    ),
    .slv_rready      	(slv_rx_rready    ),
    .slv_rid         	(slv_rx_rid       ),
    .slv_rresp       	(slv_rx_rresp     ),
    .slv_rdata       	(slv_rx_rdata     ),
    .slv_rlast       	(slv_rx_rlast     )
);

cdc_handle #(
    .DATA_W 	(18  ))
u_pause_cdc_handle(
    .clk_in    	(rx_clk           ),
    .rst_n_in  	(rx_rst_n         ),
    .req_in    	(pause_req_in     ),
    .rdy_in    	(pause_rdy_in     ),
    .data_in   	(pause_data_in    ),
    .clk_out   	(tx_clk           ),
    .rst_n_out 	(tx_rst_n         ),
    .req_out   	(pause_req_out    ),
    .rdy_out   	(pause_rdy_out    ),
    .data_out  	(pause_data_out   )
);



endmodule //enet_core
