module mac_tx #(
    parameter AXI_ID_SB = 3,

    // Address width in bits
    parameter AXI_ADDR_W = 32,
    // ID width in bits
    parameter AXI_ID_W = 8,
    // Data width in bits
    parameter AXI_DATA_W = 64
)(
    input                           tx_clk,
    input                           rst_n,

    output  [7:0]                   gmii_txd,
    output                          gmii_tx_en,
    output                          gmii_tx_er,
    //todo half duplex
    input                           gmii_crs,
    input                           gmii_col,

    input                           Tx_in_full,
    output                          Tx_in_wen,
    output [43:0]                   Tx_in_data_in,

    input                           Tx_out_empty,
    output                          Tx_out_ren,
    input  [44:0]                   Tx_out_data_out,

    input                           pause_req_out,
    output                          pause_rdy_out,
    //bit 17: 1-recv a pause frame; 0-need to send a pause
    //bit 16: 1-send a pause; 0-send a zero pause
    //bit 15-0: recv pause time
    input  [17:0]                   pause_data_out,

    output                          slv_awvalid,
    input                           slv_awready,
    output [AXI_ADDR_W    -1:0]     slv_awaddr,
    output [8             -1:0]     slv_awlen,
    output [3             -1:0]     slv_awsize,
    output [2             -1:0]     slv_awburst,
    output                          slv_awlock,
    output [4             -1:0]     slv_awcache,
    output [3             -1:0]     slv_awprot,
    output [4             -1:0]     slv_awqos,
    output [4             -1:0]     slv_awregion,
    output [AXI_ID_W      -1:0]     slv_awid,
    output                          slv_wvalid,
    input                           slv_wready,
    output                          slv_wlast, 
    output [AXI_DATA_W    -1:0]     slv_wdata,
    output [AXI_DATA_W/8  -1:0]     slv_wstrb,
    input                           slv_bvalid,
    output                          slv_bready,
    input  [AXI_ID_W      -1:0]     slv_bid,
    input  [2             -1:0]     slv_bresp,
    output                          slv_arvalid,
    input                           slv_arready,
    output [AXI_ADDR_W    -1:0]     slv_araddr,
    output [8             -1:0]     slv_arlen,
    output [3             -1:0]     slv_arsize,
    output [2             -1:0]     slv_arburst,
    output                          slv_arlock,
    output [4             -1:0]     slv_arcache,
    output [3             -1:0]     slv_arprot,
    output [4             -1:0]     slv_arqos,
    output [4             -1:0]     slv_arregion,
    output [AXI_ID_W      -1:0]     slv_arid,
    input                           slv_rvalid,
    output                          slv_rready,
    input  [AXI_ID_W      -1:0]     slv_rid,
    input  [2             -1:0]     slv_rresp,
    input  [AXI_DATA_W    -1:0]     slv_rdata,
    input                           slv_rlast
);

// output declaration of module tx_dma
wire        tdar;
wire        eir_vld;
wire        eir_babt;
wire        eir_txf;
wire        eir_eberr;
wire        eir_lc;
wire        eir_rl;
wire        eir_un;
wire        tx_data_fifo_Wready;
wire [63:0] tx_data_fifo_wdata;
wire        tx_frame_fifo_i_Rready;
wire        tx_frame_fifo_o_Wready;
wire [19:0] tx_frame_fifo_o_wdata;

// output declaration of module gmii_tx
wire        tx_mac_stop;
wire        pause_mac_send;
wire        pause_mac_send_zero;
wire        tx_data_fifo_Rready;
wire        tx_frame_fifo_i_Wready;
wire [7:0]  tx_frame_fifo_i_wdata;
wire        tx_frame_fifo_o_Rready;

// output declaration of module normal_reg_tx
wire [31:0] palr;
wire [31:0] paur;
wire [31:0] opd;
wire [31:0] tdsr;
wire        strfwd;
wire [7:0]  tfwr;
wire [7:0]  tsem;
wire [7:0]  tafl;
wire [7:0]  taem;
wire [15:0] tipg;

// output declaration of module net_fifo
wire [7:0]  tx_data_fifo_data_cnt;
wire [63:0] tx_data_fifo_rdata;

// output declaration of module net_fifo
wire [5:0]  tx_frame_fifo_i_data_cnt;
wire [7:0]  tx_frame_fifo_i_rdata;

// output declaration of module net_fifo
wire [5:0]  tx_frame_fifo_o_data_cnt;
wire [19:0] tx_frame_fifo_o_rdata;

// output declaration of module tcr
wire        eir_gra;
wire        ether_en;
wire        fden;
wire        gts;
wire        rfc_pause;
wire        tfc_pause;
wire        tx_stop;
wire        mii_select;
wire        pause_send;
wire        pause_send_zero;
wire        crcfwd;
wire        addins;
wire [13:0] max_fl;

wire        tdar_wen ;
wire        ecr_wen  ;
wire        tcr_wen  ;
wire        palr_wen ;
wire        paur_wen ;
wire        opd_wen  ;
wire        tdsr_wen ;
wire        tfwr_wen ;
wire        tsem_wen ;
wire        tafl_wen ;
wire        taem_wen ;
wire        tipg_wen ;
wire [31:0] reg_wdata;

wire        eir_all_vld = (eir_vld | eir_gra);

wire [31:0] eir;
wire        eir_rdy = (!Tx_in_full);

localparam IDLE  = 2'h0;
localparam WRITE = 2'h1;
localparam READ  = 2'h2;

reg  [1:0]  mac_trans_state;

always @(posedge tx_clk or negedge rst_n) begin
    if(!rst_n)begin
        mac_trans_state <= IDLE;
    end
    else begin
        case (mac_trans_state)
            IDLE: begin
                if((!Tx_out_data_out[0]) & (!Tx_out_empty))begin
                    mac_trans_state      <= WRITE;
                end
                else if(Tx_out_data_out[0] & (!Tx_out_empty))begin
                    mac_trans_state      <= READ;
                end
            end
            WRITE: begin
                mac_trans_state <= IDLE;
            end
            READ: begin
                if((!eir_all_vld) & (!Tx_in_full))
                    mac_trans_state <= IDLE;
            end
            default: begin
                mac_trans_state <= IDLE;
            end
        endcase
    end
end
assign tdar_wen         = (mac_trans_state == WRITE) & (Tx_out_data_out[12:1] == 12'h014); 
assign ecr_wen          = (mac_trans_state == WRITE) & (Tx_out_data_out[12:1] == 12'h024); 
assign tcr_wen          = (mac_trans_state == WRITE) & (Tx_out_data_out[12:1] == 12'h0C4); 
assign palr_wen         = (mac_trans_state == WRITE) & (Tx_out_data_out[12:1] == 12'h0E4); 
assign paur_wen         = (mac_trans_state == WRITE) & (Tx_out_data_out[12:1] == 12'h0E8); 
assign opd_wen          = (mac_trans_state == WRITE) & (Tx_out_data_out[12:1] == 12'h0EC); 
assign tdsr_wen         = (mac_trans_state == WRITE) & (Tx_out_data_out[12:1] == 12'h184); 
assign tfwr_wen         = (mac_trans_state == WRITE) & (Tx_out_data_out[12:1] == 12'h144); 
assign tsem_wen         = (mac_trans_state == WRITE) & (Tx_out_data_out[12:1] == 12'h1A0); 
assign tafl_wen         = (mac_trans_state == WRITE) & (Tx_out_data_out[12:1] == 12'h1A8); 
assign taem_wen         = (mac_trans_state == WRITE) & (Tx_out_data_out[12:1] == 12'h1A4); 
assign tipg_wen         = (mac_trans_state == WRITE) & (Tx_out_data_out[12:1] == 12'h1AC); 
assign reg_wdata        = Tx_out_data_out[44:13];
assign Tx_out_ren       = ((mac_trans_state == WRITE) | ((mac_trans_state == READ) & (!eir_all_vld) & (!Tx_in_full)));

assign eir              = {2'h0, eir_babt, eir_gra, eir_txf, 4'h0, eir_eberr, eir_lc, eir_rl, eir_un, 19'h0};

assign Tx_in_wen        = (((mac_trans_state == READ) & ((Tx_out_data_out[12:1] == 12'h014) | (Tx_out_data_out[12:1] == 12'h0C4))) | eir_all_vld);
assign Tx_in_data_in    = (eir_all_vld) ? {eir, 12'h4} : ((Tx_out_data_out[12:1] == 12'h014) ? {7'h0, tdar, 24'h0, 12'h014} : {22'h0, crcfwd, addins, 3'h0, rfc_pause, tfc_pause, fden, 1'b0, gts, 12'h0C4});

enet_normal_reg_tx u_normal_reg_tx(
    .tx_clk    	(tx_clk     ),
    .rst_n     	(rst_n      ),
    .palr_wen  	(palr_wen   ),
    .paur_wen  	(paur_wen   ),
    .opd_wen   	(opd_wen    ),
    .tdsr_wen  	(tdsr_wen   ),
    .tfwr_wen  	(tfwr_wen   ),
    .tsem_wen  	(tsem_wen   ),
    .tafl_wen  	(tafl_wen   ),
    .taem_wen  	(taem_wen   ),
    .tipg_wen  	(tipg_wen   ),
    .reg_wdata 	(reg_wdata  ),
    .palr      	(palr       ),
    .paur      	(paur       ),
    .opd       	(opd        ),
    .tdsr      	(tdsr       ),
    .strfwd    	(strfwd     ),
    .tfwr      	(tfwr       ),
    .tsem      	(tsem       ),
    .tafl      	(tafl       ),
    .taem      	(taem       ),
    .tipg      	(tipg       )
);

enet_tcr u_tcr(
    .tx_clk              	(tx_clk               ),
    .rst_n               	(rst_n                ),
    .tcr_wen             	(tcr_wen              ),
    .ecr_wen             	(ecr_wen              ),
    .reg_wdata           	(reg_wdata            ),
    .eir_gra             	(eir_gra              ),
    .eir_rdy             	(eir_rdy              ),
    .ether_en               (ether_en             ),
    .fden                	(fden                 ),
    .gts                    (gts                  ),
    .rfc_pause              (rfc_pause            ),
    .tfc_pause              (tfc_pause            ),
    .tx_stop             	(tx_stop              ),
    .tx_mac_stop         	(tx_mac_stop          ),
    .mii_select          	(mii_select           ),
    .pause_send          	(pause_send           ),
    .pause_mac_send      	(pause_mac_send       ),
    .pause_send_zero     	(pause_send_zero      ),
    .pause_mac_send_zero 	(pause_mac_send_zero  ),
    .crcfwd              	(crcfwd               ),
    .addins              	(addins               ),
    .max_fl              	(max_fl               ),
    .pause_req_out       	(pause_req_out        ),
    .pause_rdy_out       	(pause_rdy_out        ),
    .pause_data_out      	(pause_data_out       )
);


enet_tx_dma #(
    .AXI_ID_SB  	(AXI_ID_SB   ),
    .AXI_ADDR_W 	(AXI_ADDR_W  ),
    .AXI_ID_W   	(AXI_ID_W    ),
    .AXI_DATA_W 	(AXI_DATA_W  ))
u_tx_dma(
    .tx_clk                   	(tx_clk                    ),
    .rst_n                    	(rst_n                     ),
    .tdar_wen                 	(tdar_wen                  ),
    .tdar                     	(tdar                      ),
    .ether_en                 	(ether_en                  ),
    .tafl                     	(tafl                      ),
    .tdsr                     	(tdsr                      ),
    .eir_vld                  	(eir_vld                   ),
    .eir_rdy                  	(eir_rdy                   ),
    .eir_babt                 	(eir_babt                  ),
    .eir_txf                  	(eir_txf                   ),
    .eir_eberr                	(eir_eberr                 ),
    .eir_lc                   	(eir_lc                    ),
    .eir_rl                   	(eir_rl                    ),
    .eir_un                   	(eir_un                    ),
    .tx_data_fifo_Wready      	(tx_data_fifo_Wready       ),
    .tx_data_fifo_data_cnt    	(tx_data_fifo_data_cnt     ),
    .tx_data_fifo_wdata       	(tx_data_fifo_wdata        ),
    .tx_frame_fifo_i_Rready   	(tx_frame_fifo_i_Rready    ),
    .tx_frame_fifo_i_data_cnt 	(tx_frame_fifo_i_data_cnt  ),
    .tx_frame_fifo_i_rdata    	(tx_frame_fifo_i_rdata     ),
    .tx_frame_fifo_o_Wready   	(tx_frame_fifo_o_Wready    ),
    .tx_frame_fifo_o_data_cnt 	(tx_frame_fifo_o_data_cnt  ),
    .tx_frame_fifo_o_wdata    	(tx_frame_fifo_o_wdata     ),
    .slv_awvalid              	(slv_awvalid               ),
    .slv_awready              	(slv_awready               ),
    .slv_awaddr               	(slv_awaddr                ),
    .slv_awlen                	(slv_awlen                 ),
    .slv_awsize               	(slv_awsize                ),
    .slv_awburst              	(slv_awburst               ),
    .slv_awlock               	(slv_awlock                ),
    .slv_awcache              	(slv_awcache               ),
    .slv_awprot               	(slv_awprot                ),
    .slv_awqos                	(slv_awqos                 ),
    .slv_awregion             	(slv_awregion              ),
    .slv_awid                 	(slv_awid                  ),
    .slv_wvalid               	(slv_wvalid                ),
    .slv_wready               	(slv_wready                ),
    .slv_wlast                	(slv_wlast                 ),
    .slv_wdata                	(slv_wdata                 ),
    .slv_wstrb                	(slv_wstrb                 ),
    .slv_bvalid               	(slv_bvalid                ),
    .slv_bready               	(slv_bready                ),
    .slv_bid                  	(slv_bid                   ),
    .slv_bresp                	(slv_bresp                 ),
    .slv_arvalid              	(slv_arvalid               ),
    .slv_arready              	(slv_arready               ),
    .slv_araddr               	(slv_araddr                ),
    .slv_arlen                	(slv_arlen                 ),
    .slv_arsize               	(slv_arsize                ),
    .slv_arburst              	(slv_arburst               ),
    .slv_arlock               	(slv_arlock                ),
    .slv_arcache              	(slv_arcache               ),
    .slv_arprot               	(slv_arprot                ),
    .slv_arqos                	(slv_arqos                 ),
    .slv_arregion             	(slv_arregion              ),
    .slv_arid                 	(slv_arid                  ),
    .slv_rvalid               	(slv_rvalid                ),
    .slv_rready               	(slv_rready                ),
    .slv_rid                  	(slv_rid                   ),
    .slv_rresp                	(slv_rresp                 ),
    .slv_rdata                	(slv_rdata                 ),
    .slv_rlast                	(slv_rlast                 )
);

gmii_tx u_gmii_tx(
    .tx_clk                   	(tx_clk                    ),
    .rst_n                    	(rst_n                     ),
    .gmii_txd                 	(gmii_txd                  ),
    .gmii_tx_en               	(gmii_tx_en                ),
    .gmii_tx_er               	(gmii_tx_er                ),
    .gmii_crs                 	(gmii_crs                  ),
    .gmii_col                 	(gmii_col                  ),
    .ether_en                 	(ether_en                  ),
    .tfc_pause                  (tfc_pause                 ),
    .fden         	            (fden                      ),
    .tx_stop                  	(tx_stop                   ),
    .tx_mac_stop              	(tx_mac_stop               ),
    .mii_select               	(mii_select                ),
    .pause_send               	(pause_send                ),
    .pause_mac_send      	    (pause_mac_send            ),
    .pause_send_zero     	    (pause_send_zero           ),
    .pause_mac_send_zero 	    (pause_mac_send_zero       ),
    .crcfwd                   	(crcfwd                    ),
    .addins                   	(addins                    ),
    .max_fl                   	(max_fl                    ),
    .tx_data_fifo_Rready      	(tx_data_fifo_Rready       ),
    .tx_data_fifo_data_cnt    	(tx_data_fifo_data_cnt     ),
    .tx_data_fifo_rdata       	(tx_data_fifo_rdata        ),
    .tx_frame_fifo_i_Wready   	(tx_frame_fifo_i_Wready    ),
    .tx_frame_fifo_i_wdata    	(tx_frame_fifo_i_wdata     ),
    .tx_frame_fifo_o_Rready   	(tx_frame_fifo_o_Rready    ),
    .tx_frame_fifo_o_data_cnt 	(tx_frame_fifo_o_data_cnt  ),
    .tx_frame_fifo_o_rdata    	(tx_frame_fifo_o_rdata     ),
    .palr                     	(palr                      ),
    .paur                     	(paur                      ),
    .opd                      	(opd                       ),
    .strfwd                   	(strfwd                    ),
    .tfwr                     	(tfwr                      ),
    .taem                     	(taem                      ),
    .tipg                     	(tipg                      )
);

net_fifo #(
    .DATA_WIDTH 	(64  ),
    .ADDR_WIDTH 	(8   ))
u_tx_data_fifo(
    .clk      	(tx_clk                 ),
    .rst_n    	(rst_n                  ),
    .Wready   	(tx_data_fifo_Wready    ),
    .Rready   	(tx_data_fifo_Rready    ),
    .flush    	(!ether_en              ),
    .wdata    	(tx_data_fifo_wdata     ),
    .data_cnt 	(tx_data_fifo_data_cnt  ),
    .rdata    	(tx_data_fifo_rdata     )
);

net_fifo #(
    .DATA_WIDTH 	(8   ),
    .ADDR_WIDTH 	(6   ))
u_tx_frame_fifo_i(
    .clk      	(tx_clk                     ),
    .rst_n    	(rst_n                      ),
    .Wready   	(tx_frame_fifo_i_Wready     ),
    .Rready   	(tx_frame_fifo_i_Rready     ),
    .flush    	(!ether_en                  ),
    .wdata    	(tx_frame_fifo_i_wdata      ),
    .data_cnt 	(tx_frame_fifo_i_data_cnt   ),
    .rdata    	(tx_frame_fifo_i_rdata      )
);

net_fifo #(
    .DATA_WIDTH 	(20  ),
    .ADDR_WIDTH 	(6   ))
u_tx_frame_fifo_o(
    .clk      	(tx_clk                     ),
    .rst_n    	(rst_n                      ),
    .Wready   	(tx_frame_fifo_o_Wready     ),
    .Rready   	(tx_frame_fifo_o_Rready     ),
    .flush    	(!ether_en                  ),
    .wdata    	(tx_frame_fifo_o_wdata      ),
    .data_cnt 	(tx_frame_fifo_o_data_cnt   ),
    .rdata    	(tx_frame_fifo_o_rdata      )
);


endmodule //mac_tx
