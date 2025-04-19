module enet_chclk (
    input                           rst_n,

    input                           mii_select,
    input                           rmii_select,

    input                           mii_tx_clk,
    input                           mii_rx_clk,
    input  [7:0]                    mii_txd,
    input  [7:0]                    mii_rxd,
    input                           mii_tx_en,
    input                           mii_tx_er,
    input                           mii_rx_dv,
    input                           mii_rx_er,

    input                           rmii_tx_clk,
    input                           rmii_rx_clk,
    input  [7:0]                    rmii_txd,
    input  [7:0]                    rmii_rxd,
    input                           rmii_tx_en,
    input                           rmii_tx_er,
    input                           rmii_rx_dv,
    input                           rmii_rx_er,

    input                           gmii_tx_clk,
    input                           gmii_rx_clk,
    input  [7:0]                    gmii_txd,
    input  [7:0]                    gmii_rxd,
    input                           gmii_tx_en,
    input                           gmii_tx_er,
    input                           gmii_rx_dv,
    input                           gmii_rx_er,

    input                           rgmii_tx_clk,
    input                           rgmii_rx_clk,
    input  [7:0]                    rgmii_txd,
    input  [7:0]                    rgmii_rxd,
    input                           rgmii_tx_en,
    input                           rgmii_tx_er,
    input                           rgmii_rx_dv,
    input                           rgmii_rx_er,

    output                          tx_clk,
    output                          rx_clk,
    output [7:0]                    txd,
    output [7:0]                    rxd,
    output                          tx_en,
    output                          tx_er,
    output                          rx_dv,
    output                          rx_er
);

wire                mii_tx_sel;
wire                mii_rx_sel;
wire                rmii_tx_sel;
wire                rmii_rx_sel;
wire                gmii_tx_sel;
wire                gmii_rx_sel;
wire                rgmii_tx_sel;
wire                rgmii_rx_sel;

wire                mii_tx_clk_sel;
wire                mii_rx_clk_sel;
wire                rmii_tx_clk_sel;
wire                rmii_rx_clk_sel;
wire                gmii_tx_clk_sel;
wire                gmii_rx_clk_sel;
wire                rgmii_tx_clk_sel;
wire                rgmii_rx_clk_sel;

enet_chclk_path u_enet_chclk_path_mii_tx(
    .rst_n   	(rst_n          ),
    .clk_i   	(mii_tx_clk     ),
    .clk_sel 	(mii_tx_sel     ),
    .clk_ena 	(mii_tx_clk_sel )
);

enet_chclk_path u_enet_chclk_path_mii_rx(
    .rst_n   	(rst_n          ),
    .clk_i   	(mii_rx_clk     ),
    .clk_sel 	(mii_rx_sel     ),
    .clk_ena 	(mii_rx_clk_sel )
);

enet_chclk_path u_enet_chclk_path_rmii_tx(
    .rst_n   	(rst_n           ),
    .clk_i   	(rmii_tx_clk     ),
    .clk_sel 	(rmii_tx_sel     ),
    .clk_ena 	(rmii_tx_clk_sel )
);

enet_chclk_path u_enet_chclk_path_rmii_rx(
    .rst_n   	(rst_n           ),
    .clk_i   	(rmii_rx_clk     ),
    .clk_sel 	(rmii_rx_sel     ),
    .clk_ena 	(rmii_rx_clk_sel )
);

enet_chclk_path u_enet_chclk_path_gmii_tx(
    .rst_n   	(rst_n           ),
    .clk_i   	(gmii_tx_clk     ),
    .clk_sel 	(gmii_tx_sel     ),
    .clk_ena 	(gmii_tx_clk_sel )
);

enet_chclk_path u_enet_chclk_path_gmii_rx(
    .rst_n   	(rst_n           ),
    .clk_i   	(gmii_rx_clk     ),
    .clk_sel 	(gmii_rx_sel     ),
    .clk_ena 	(gmii_rx_clk_sel )
);

enet_chclk_path u_enet_chclk_path_rgmii_tx(
    .rst_n   	(rst_n            ),
    .clk_i   	(rgmii_tx_clk     ),
    .clk_sel 	(rgmii_tx_sel     ),
    .clk_ena 	(rgmii_tx_clk_sel )
);

enet_chclk_path u_enet_chclk_path_rgmii_rx(
    .rst_n   	(rst_n            ),
    .clk_i   	(rgmii_rx_clk     ),
    .clk_sel 	(rgmii_rx_sel     ),
    .clk_ena 	(rgmii_rx_clk_sel )
);

assign mii_tx_sel   =   mii_select  & (!rmii_select) & (!rmii_tx_clk_sel) & (!gmii_tx_clk_sel) & (!rgmii_tx_clk_sel);
assign mii_rx_sel   =   mii_select  & (!rmii_select) & (!rmii_rx_clk_sel) & (!gmii_rx_clk_sel) & (!rgmii_rx_clk_sel);

assign rmii_tx_sel  =   mii_select  &   rmii_select  & (!mii_tx_clk_sel)  & (!gmii_tx_clk_sel) & (!rgmii_tx_clk_sel);
assign rmii_rx_sel  =   mii_select  &   rmii_select  & (!mii_rx_clk_sel)  & (!gmii_rx_clk_sel) & (!rgmii_rx_clk_sel);

assign gmii_tx_sel  = (!mii_select) & (!rmii_select) & (!mii_tx_clk_sel)  & (!rmii_tx_clk_sel) & (!rgmii_tx_clk_sel);
assign gmii_rx_sel  = (!mii_select) & (!rmii_select) & (!mii_rx_clk_sel)  & (!rmii_rx_clk_sel) & (!rgmii_rx_clk_sel);

assign rgmii_tx_sel = (!mii_select) &   rmii_select  & (!mii_tx_clk_sel)  & (!rmii_tx_clk_sel) & (!gmii_tx_clk_sel);
assign rgmii_rx_sel = (!mii_select) &   rmii_select  & (!mii_rx_clk_sel)  & (!rmii_rx_clk_sel) & (!gmii_rx_clk_sel);

assign tx_clk = (mii_tx_clk_sel   & mii_tx_clk   ) |
                (rmii_tx_clk_sel  & rmii_tx_clk  ) |
                (gmii_tx_clk_sel  & gmii_tx_clk  ) |
                (rgmii_tx_clk_sel & rgmii_tx_clk );

assign txd    = ({8{mii_tx_clk_sel  }} & mii_txd   ) |
                ({8{rmii_tx_clk_sel }} & rmii_txd  ) |
                ({8{gmii_tx_clk_sel }} & gmii_txd  ) |
                ({8{rgmii_tx_clk_sel}} & rgmii_txd );

assign tx_en  = (mii_tx_clk_sel   & mii_tx_en   ) |
                (rmii_tx_clk_sel  & rmii_tx_en  ) |
                (gmii_tx_clk_sel  & gmii_tx_en  ) |
                (rgmii_tx_clk_sel & rgmii_tx_en );

assign tx_er  = (mii_tx_clk_sel   & mii_tx_er   ) |
                (rmii_tx_clk_sel  & rmii_tx_er  ) |
                (gmii_tx_clk_sel  & gmii_tx_er  ) |
                (rgmii_tx_clk_sel & rgmii_tx_er );

assign rx_clk = (mii_rx_clk_sel   & mii_rx_clk   ) |
                (rmii_rx_clk_sel  & rmii_rx_clk  ) |
                (gmii_rx_clk_sel  & gmii_rx_clk  ) |
                (rgmii_rx_clk_sel & rgmii_rx_clk );

assign rxd    = ({8{mii_rx_clk_sel  }} & mii_rxd   ) |
                ({8{rmii_rx_clk_sel }} & rmii_rxd  ) |
                ({8{gmii_rx_clk_sel }} & gmii_rxd  ) |
                ({8{rgmii_rx_clk_sel}} & rgmii_rxd );

assign rx_dv  = (mii_rx_clk_sel   & mii_rx_dv   ) |
                (rmii_rx_clk_sel  & rmii_rx_dv  ) |
                (gmii_rx_clk_sel  & gmii_rx_dv  ) |
                (rgmii_rx_clk_sel & rgmii_rx_dv );

assign rx_er  = (mii_rx_clk_sel   & mii_rx_er   ) |
                (rmii_rx_clk_sel  & rmii_rx_er  ) |
                (gmii_rx_clk_sel  & gmii_rx_er  ) |
                (rgmii_rx_clk_sel & rgmii_rx_er );


endmodule //enet_chclk
