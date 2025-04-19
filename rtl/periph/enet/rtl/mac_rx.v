module mac_rx #(
    parameter AXI_ID_SB = 3,

    // Address width in bits
    parameter AXI_ADDR_W = 32,
    // ID width in bits
    parameter AXI_ID_W = 8,
    // Data width in bits
    parameter AXI_DATA_W = 64
)(
    input                           rx_clk,
    input                           rst_n,

    input  [7:0]                    gmii_rxd,
    input                           gmii_rx_dv,
    input                           gmii_rx_er,
    //todo half duplex
    input                           gmii_crs,
    input                           gmii_col,

    input                           Rx_in_full,
    output                          Rx_in_wen,
    output [43:0]                   Rx_in_data_in,

    input                           Rx_out_empty,
    output                          Rx_out_ren,
    input  [44:0]                   Rx_out_data_out,

    output                          pause_req_in,
    input                           pause_rdy_in,
    //bit 17: 1-recv a pause frame; 0-need to send a pause
    //bit 16: 1-send a pause; 0-send a zero pause
    //bit 15-0: recv pause time
    output [17:0]                   pause_data_in,

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

// output declaration of module enet_normal_reg_rx
wire [31:0] palr;
wire [15:0] paur;
wire [31:0] ialr;
wire [31:0] iaur;
wire [31:0] galr;
wire [31:0] gaur;
wire [31:0] rdsr;
wire [7:0]  rsfl;
wire [4:0]  rsem_stat;
wire [7:0]  rsem_rx;
wire [7:0]  rafl;
wire [7:0]  raem;
wire [13:0] ftrl;

// output declaration of module enet_rcr
wire        ether_en;
wire        drt;
wire        mii_select;
wire        nlc;
wire        cfen;
wire        crcfwd;
wire        paufwd;
wire        paden;
wire        fce;
wire        bc_rej;
wire        prom;
wire [13:0] max_fl;

// output declaration of module enet_rx_dma
wire        rdar_rst;
wire        rdar;
wire        eir_vld;
wire        eir_babr;
wire        eir_rxf;
wire        eir_eberr;
wire        eir_plr;
wire        rx_data_fifo_Rready;
wire        rx_frame_fifo_Rready;

// output declaration of module gmii_rx
wire        rx_data_fifo_Wready;
wire [63:0] rx_data_fifo_wdata;
wire        rx_frame_fifo_Wready;
wire [26:0] rx_frame_fifo_wdata;

// output declaration of module net_fifo
wire [7:0]  rx_data_fifo_data_cnt;
wire [63:0] rx_data_fifo_rdata;

// output declaration of module net_fifo
wire [5:0]  rx_frame_fifo_data_cnt;
wire [26:0] rx_frame_fifo_rdata;

wire        rdar_wen ;
wire        ecr_wen  ;
wire        rcr_wen  ;
wire        palr_wen ;
wire        paur_wen ;
wire        ialr_wen ;
wire        iaur_wen ;
wire        galr_wen ;
wire        gaur_wen ;
wire        rdsr_wen ;
wire        rsfl_wen ;
wire        rsem_wen ;
wire        rafl_wen ;
wire        raem_wen ;
wire        ftrl_wen ;
wire [31:0] reg_wdata;

wire [31:0] eir;
wire        eir_rdy = (!Rx_in_full);

wire [31:0] rcr;

localparam IDLE  = 2'h0;
localparam WRITE = 2'h1;
localparam READ  = 2'h2;

reg  [1:0]  mac_trans_state;

always @(posedge rx_clk or negedge rst_n) begin
    if(!rst_n)begin
        mac_trans_state <= IDLE;
    end
    else begin
        case (mac_trans_state)
            IDLE: begin
                if((!Rx_out_data_out[0]) & (!Rx_out_empty))begin
                    mac_trans_state      <= WRITE;
                end
                else if(Rx_out_data_out[0] & (!Rx_out_empty))begin
                    mac_trans_state      <= READ;
                end
            end
            WRITE: begin
                mac_trans_state <= IDLE;
            end
            READ: begin
                if((!eir_vld) & (!Rx_in_full))
                    mac_trans_state <= IDLE;
            end
            default: begin
                mac_trans_state <= IDLE;
            end
        endcase
    end
end
assign rdar_wen         = (mac_trans_state == WRITE) & (Rx_out_data_out[12:1] == 12'h010); 
assign ecr_wen          = (mac_trans_state == WRITE) & (Rx_out_data_out[12:1] == 12'h024); 
assign rcr_wen          = (mac_trans_state == WRITE) & (Rx_out_data_out[12:1] == 12'h084); 
assign palr_wen         = (mac_trans_state == WRITE) & (Rx_out_data_out[12:1] == 12'h0E4); 
assign paur_wen         = (mac_trans_state == WRITE) & (Rx_out_data_out[12:1] == 12'h0E8); 
assign ialr_wen         = (mac_trans_state == WRITE) & (Rx_out_data_out[12:1] == 12'h11C); 
assign iaur_wen         = (mac_trans_state == WRITE) & (Rx_out_data_out[12:1] == 12'h118); 
assign galr_wen         = (mac_trans_state == WRITE) & (Rx_out_data_out[12:1] == 12'h124); 
assign gaur_wen         = (mac_trans_state == WRITE) & (Rx_out_data_out[12:1] == 12'h120); 
assign rdsr_wen         = (mac_trans_state == WRITE) & (Rx_out_data_out[12:1] == 12'h180); 
assign rsfl_wen         = (mac_trans_state == WRITE) & (Rx_out_data_out[12:1] == 12'h190); 
assign rsem_wen         = (mac_trans_state == WRITE) & (Rx_out_data_out[12:1] == 12'h194); 
assign rafl_wen         = (mac_trans_state == WRITE) & (Rx_out_data_out[12:1] == 12'h19C); 
assign raem_wen         = (mac_trans_state == WRITE) & (Rx_out_data_out[12:1] == 12'h198); 
assign ftrl_wen         = (mac_trans_state == WRITE) & (Rx_out_data_out[12:1] == 12'h1B0); 
assign reg_wdata        = Rx_out_data_out[44:13];
assign Rx_out_ren       = ((mac_trans_state == WRITE) | ((mac_trans_state == READ) & (!eir_vld) & (!Rx_in_full)));

assign eir              = {1'h0, eir_babr, 4'b0, eir_rxf, 2'h0, eir_eberr, 3'h0, eir_plr, 18'h0};
assign rcr              = {1'h0, nlc, 14'h0, cfen, crcfwd, paufwd, paden, 6'h0, fce, bc_rej, prom, 1'h0, drt, 1'h0};

assign Rx_in_wen        = (((mac_trans_state == READ) & ((Rx_out_data_out[12:1] == 12'h010) | (Rx_out_data_out[12:1] == 12'h084))) | eir_vld);
assign Rx_in_data_in    = (eir_vld) ? {eir, 12'h4} : ((Rx_out_data_out[12:1] == 12'h010) ? {7'h0, rdar, 24'h0, 12'h010} : {rcr, 12'h084});

enet_normal_reg_rx u_enet_normal_reg_rx(
    .rx_clk    	(rx_clk     ),
    .rst_n     	(rst_n      ),
    .palr_wen  	(palr_wen   ),
    .paur_wen  	(paur_wen   ),
    .ialr_wen  	(ialr_wen   ),
    .iaur_wen  	(iaur_wen   ),
    .galr_wen  	(galr_wen   ),
    .gaur_wen  	(gaur_wen   ),
    .rdsr_wen  	(rdsr_wen   ),
    .rsfl_wen  	(rsfl_wen   ),
    .rsem_wen  	(rsem_wen   ),
    .rafl_wen  	(rafl_wen   ),
    .raem_wen  	(raem_wen   ),
    .ftrl_wen  	(ftrl_wen   ),
    .reg_wdata 	(reg_wdata  ),
    .palr      	(palr       ),
    .paur      	(paur       ),
    .ialr      	(ialr       ),
    .iaur      	(iaur       ),
    .galr      	(galr       ),
    .gaur      	(gaur       ),
    .rdsr      	(rdsr       ),
    .rsfl      	(rsfl       ),
    .rsem_stat 	(rsem_stat  ),
    .rsem_rx   	(rsem_rx    ),
    .rafl      	(rafl       ),
    .raem      	(raem       ),
    .ftrl      	(ftrl       )
);

enet_rcr u_enet_rcr(
    .rx_clk     	(rx_clk      ),
    .rst_n      	(rst_n       ),
    .rcr_wen    	(rcr_wen     ),
    .ecr_wen    	(ecr_wen     ),
    .reg_wdata  	(reg_wdata   ),
    .ether_en   	(ether_en    ),
    .drt        	(drt         ),
    .mii_select 	(mii_select  ),
    .nlc        	(nlc         ),
    .cfen       	(cfen        ),
    .crcfwd     	(crcfwd      ),
    .paufwd     	(paufwd      ),
    .paden      	(paden       ),
    .fce        	(fce         ),
    .bc_rej     	(bc_rej      ),
    .prom       	(prom        ),
    .max_fl     	(max_fl      )
);


enet_rx_dma #(
    .AXI_ID_SB  	(AXI_ID_SB   ),
    .AXI_ADDR_W 	(AXI_ADDR_W  ),
    .AXI_ID_W   	(AXI_ID_W    ),
    .AXI_DATA_W 	(AXI_DATA_W  ))
u_enet_rx_dma(
    .rx_clk                 	(rx_clk                  ),
    .rst_n                  	(rst_n                   ),
    .rdar_wen               	(rdar_wen                ),
    .rdar                   	(rdar                    ),
    .ether_en               	(ether_en                ),
    .rdar_rst               	(rdar_rst                ),
    .rsfl                   	(rsfl                    ),
    .raem                   	(raem                    ),
    .rdsr                   	(rdsr                    ),
    .eir_vld                	(eir_vld                 ),
    .eir_rdy                	(eir_rdy                 ),
    .eir_babr               	(eir_babr                ),
    .eir_rxf                	(eir_rxf                 ),
    .eir_eberr              	(eir_eberr               ),
    .eir_plr                	(eir_plr                 ),
    .rx_data_fifo_Rready    	(rx_data_fifo_Rready     ),
    .rx_data_fifo_data_cnt  	(rx_data_fifo_data_cnt   ),
    .rx_data_fifo_rdata     	(rx_data_fifo_rdata      ),
    .rx_frame_fifo_Rready   	(rx_frame_fifo_Rready    ),
    .rx_frame_fifo_data_cnt 	(rx_frame_fifo_data_cnt  ),
    .rx_frame_fifo_rdata    	(rx_frame_fifo_rdata     ),
    .slv_awvalid            	(slv_awvalid             ),
    .slv_awready            	(slv_awready             ),
    .slv_awaddr             	(slv_awaddr              ),
    .slv_awlen              	(slv_awlen               ),
    .slv_awsize             	(slv_awsize              ),
    .slv_awburst            	(slv_awburst             ),
    .slv_awlock             	(slv_awlock              ),
    .slv_awcache            	(slv_awcache             ),
    .slv_awprot             	(slv_awprot              ),
    .slv_awqos              	(slv_awqos               ),
    .slv_awregion           	(slv_awregion            ),
    .slv_awid               	(slv_awid                ),
    .slv_wvalid             	(slv_wvalid              ),
    .slv_wready             	(slv_wready              ),
    .slv_wlast              	(slv_wlast               ),
    .slv_wdata              	(slv_wdata               ),
    .slv_wstrb              	(slv_wstrb               ),
    .slv_bvalid             	(slv_bvalid              ),
    .slv_bready             	(slv_bready              ),
    .slv_bid                	(slv_bid                 ),
    .slv_bresp              	(slv_bresp               ),
    .slv_arvalid            	(slv_arvalid             ),
    .slv_arready            	(slv_arready             ),
    .slv_araddr             	(slv_araddr              ),
    .slv_arlen              	(slv_arlen               ),
    .slv_arsize             	(slv_arsize              ),
    .slv_arburst            	(slv_arburst             ),
    .slv_arlock             	(slv_arlock              ),
    .slv_arcache            	(slv_arcache             ),
    .slv_arprot             	(slv_arprot              ),
    .slv_arqos              	(slv_arqos               ),
    .slv_arregion           	(slv_arregion            ),
    .slv_arid               	(slv_arid                ),
    .slv_rvalid             	(slv_rvalid              ),
    .slv_rready             	(slv_rready              ),
    .slv_rid                	(slv_rid                 ),
    .slv_rresp              	(slv_rresp               ),
    .slv_rdata              	(slv_rdata               ),
    .slv_rlast              	(slv_rlast               )
);

gmii_rx u_gmii_rx(
    .rx_clk                 	(rx_clk                  ),
    .rst_n                  	(rst_n                   ),
    .gmii_rxd               	(gmii_rxd                ),
    .gmii_rx_dv             	(gmii_rx_dv              ),
    .gmii_rx_er             	(gmii_rx_er              ),
    .gmii_crs               	(gmii_crs                ),
    .gmii_col               	(gmii_col                ),
    .ether_en               	(ether_en                ),
    .rdar_rst               	(rdar_rst                ),
    .drt                    	(drt                     ),
    .mii_select             	(mii_select              ),
    .nlc                    	(nlc                     ),
    .cfen                   	(cfen                    ),
    .crcfwd                 	(crcfwd                  ),
    .paufwd                 	(paufwd                  ),
    .paden                  	(paden                   ),
    .fce                    	(fce                     ),
    .bc_rej                 	(bc_rej                  ),
    .prom                   	(prom                    ),
    .max_fl                 	(max_fl                  ),
    .rx_data_fifo_Wready    	(rx_data_fifo_Wready     ),
    .rx_data_fifo_data_cnt  	(rx_data_fifo_data_cnt   ),
    .rx_data_fifo_wdata     	(rx_data_fifo_wdata      ),
    .rx_frame_fifo_Wready   	(rx_frame_fifo_Wready    ),
    .rx_frame_fifo_data_cnt 	(rx_frame_fifo_data_cnt  ),
    .rx_frame_fifo_wdata    	(rx_frame_fifo_wdata     ),
    .pause_req_in           	(pause_req_in            ),
    .pause_rdy_in           	(pause_rdy_in            ),
    .pause_data_in          	(pause_data_in           ),
    .palr                   	(palr                    ),
    .paur                   	(paur                    ),
    .ialr                   	(ialr                    ),
    .iaur                   	(iaur                    ),
    .galr                   	(galr                    ),
    .gaur                   	(gaur                    ),
    .rsem_stat              	(rsem_stat               ),
    .rsem_rx                	(rsem_rx                 ),
    .rafl                   	(rafl                    ),
    .ftrl                   	(ftrl                    )
);


net_fifo #(
    .DATA_WIDTH 	(64  ),
    .ADDR_WIDTH 	(8   ))
u_rx_data_fifo(
    .clk      	(rx_clk                     ),
    .rst_n    	(rst_n                      ),
    .Wready   	(rx_data_fifo_Wready        ),
    .Rready   	(rx_data_fifo_Rready        ),
    .flush    	(((!ether_en) | rdar_rst)   ),
    .wdata    	(rx_data_fifo_wdata         ),
    .data_cnt 	(rx_data_fifo_data_cnt      ),
    .rdata    	(rx_data_fifo_rdata         )
);

net_fifo #(
    .DATA_WIDTH 	(27   ),
    .ADDR_WIDTH 	(6    ))
u_rx_frame_fifo(
    .clk      	(rx_clk                     ),
    .rst_n    	(rst_n                      ),
    .Wready   	(rx_frame_fifo_Wready       ),
    .Rready   	(rx_frame_fifo_Rready       ),
    .flush    	(((!ether_en) | rdar_rst)   ),
    .wdata    	(rx_frame_fifo_wdata        ),
    .data_cnt 	(rx_frame_fifo_data_cnt     ),
    .rdata    	(rx_frame_fifo_rdata        )
);


endmodule //mac_rx
