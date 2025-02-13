`include "define.v"
module core_debugger_top (
    input       clock,
    input       rst_n,

    input 		tck,
    input		tms,
    input		tdi,
    output		tdo,
    output [3:0]tap_state,

    input       stip_asyn,
    input       seip_asyn,
    input       ssip_asyn,
    input       mtip_asyn,
    input       meip_asyn,
    input       msip_asyn
);

wire clk = clock;

// output declaration of module core_top
wire MXR;
wire SUM;
wire MPRV;
wire [1:0] MPP;
wire [3:0] satp_mode;
wire [15:0] satp_asid;
wire [43:0] satp_ppn;
wire ifu_arvalid;
wire [63:0] ifu_araddr;
wire ifu_rready;
wire lsu_arvalid;
wire lsu_arlock;
wire [2:0] lsu_arsize;
wire [63:0] lsu_araddr;
wire lsu_rready;
wire lsu_awvalid;
wire lsu_awlock;
wire [2:0] lsu_awsize;
wire [63:0] lsu_awaddr;
wire lsu_wvalid;
wire [7:0] lsu_wstrb;
wire [63:0] lsu_wdata;
wire lsu_bready;

// Address width in bits
localparam AXI_ADDR_W = 64;
// ID width in bits
localparam AXI_ID_W = 8;
// Data width in bits
localparam AXI_DATA_W = 64;

localparam AXI_AUSER_W = 1;
localparam AXI_WUSER_W = 1;
localparam AXI_BUSER_W = 1;
localparam AXI_RUSER_W = 1;

// output declaration of module axicb_crossbar_top
wire slv0_awready;
wire slv0_wready;
wire slv0_bvalid;
wire [AXI_ID_W-1:0] slv0_bid;
wire [2-1:0] slv0_bresp;
wire [AXI_BUSER_W-1:0] slv0_buser;
wire slv0_arready;
wire slv0_rvalid;
wire [AXI_ID_W-1:0] slv0_rid;
wire [2-1:0] slv0_rresp;
wire [AXI_DATA_W-1:0] slv0_rdata;
wire slv0_rlast;
wire [AXI_RUSER_W-1:0] slv0_ruser;
wire slv1_awready;
wire slv1_wready;
wire slv1_bvalid;
wire [AXI_ID_W-1:0] slv1_bid;
wire [2-1:0] slv1_bresp;
wire [AXI_BUSER_W-1:0] slv1_buser;
wire slv1_arready;
wire slv1_rvalid;
wire [AXI_ID_W-1:0] slv1_rid;
wire [2-1:0] slv1_rresp;
wire [AXI_DATA_W-1:0] slv1_rdata;
wire slv1_rlast;
wire [AXI_RUSER_W-1:0] slv1_ruser;
wire slv2_awready;
wire slv2_wready;
wire slv2_bvalid;
wire [AXI_ID_W-1:0] slv2_bid;
wire [2-1:0] slv2_bresp;
wire [AXI_BUSER_W-1:0] slv2_buser;
wire slv2_arready;
wire slv2_rvalid;
wire [AXI_ID_W-1:0] slv2_rid;
wire [2-1:0] slv2_rresp;
wire [AXI_DATA_W-1:0] slv2_rdata;
wire slv2_rlast;
wire [AXI_RUSER_W-1:0] slv2_ruser;
wire slv3_awready;
wire slv3_wready;
wire slv3_bvalid;
wire [AXI_ID_W-1:0] slv3_bid;
wire [2-1:0] slv3_bresp;
wire [AXI_BUSER_W-1:0] slv3_buser;
wire slv3_arready;
wire slv3_rvalid;
wire [AXI_ID_W-1:0] slv3_rid;
wire [2-1:0] slv3_rresp;
wire [AXI_DATA_W-1:0] slv3_rdata;
wire slv3_rlast;
wire [AXI_RUSER_W-1:0] slv3_ruser;
wire mst0_awvalid;
wire [AXI_ADDR_W-1:0] mst0_awaddr;
wire [8-1:0] mst0_awlen;
wire [3-1:0] mst0_awsize;
wire [2-1:0] mst0_awburst;
wire mst0_awlock;
wire [4-1:0] mst0_awcache;
wire [3-1:0] mst0_awprot;
wire [4-1:0] mst0_awqos;
wire [4-1:0] mst0_awregion;
wire [AXI_ID_W-1:0] mst0_awid;
wire [AXI_AUSER_W-1:0] mst0_awuser;
wire mst0_wvalid;
wire mst0_wlast;
wire [AXI_DATA_W-1:0] mst0_wdata;
wire [AXI_DATA_W/8-1:0] mst0_wstrb;
wire [AXI_WUSER_W-1:0] mst0_wuser;
wire mst0_bready;
wire mst0_arvalid;
wire [AXI_ADDR_W-1:0] mst0_araddr;
wire [8-1:0] mst0_arlen;
wire [3-1:0] mst0_arsize;
wire [2-1:0] mst0_arburst;
wire mst0_arlock;
wire [4-1:0] mst0_arcache;
wire [3-1:0] mst0_arprot;
wire [4-1:0] mst0_arqos;
wire [4-1:0] mst0_arregion;
wire [AXI_ID_W-1:0] mst0_arid;
wire [AXI_AUSER_W-1:0] mst0_aruser;
wire mst0_rready;
wire mst1_awvalid;
wire [AXI_ADDR_W-1:0] mst1_awaddr;
wire [8-1:0] mst1_awlen;
wire [3-1:0] mst1_awsize;
wire [2-1:0] mst1_awburst;
wire mst1_awlock;
wire [4-1:0] mst1_awcache;
wire [3-1:0] mst1_awprot;
wire [4-1:0] mst1_awqos;
wire [4-1:0] mst1_awregion;
wire [AXI_ID_W-1:0] mst1_awid;
wire [AXI_AUSER_W-1:0] mst1_awuser;
wire mst1_wvalid;
wire mst1_wlast;
wire [AXI_DATA_W-1:0] mst1_wdata;
wire [AXI_DATA_W/8-1:0] mst1_wstrb;
wire [AXI_WUSER_W-1:0] mst1_wuser;
wire mst1_bready;
wire mst1_arvalid;
wire [AXI_ADDR_W-1:0] mst1_araddr;
wire [8-1:0] mst1_arlen;
wire [3-1:0] mst1_arsize;
wire [2-1:0] mst1_arburst;
wire mst1_arlock;
wire [4-1:0] mst1_arcache;
wire [3-1:0] mst1_arprot;
wire [4-1:0] mst1_arqos;
wire [4-1:0] mst1_arregion;
wire [AXI_ID_W-1:0] mst1_arid;
wire [AXI_AUSER_W-1:0] mst1_aruser;
wire mst1_rready;
wire mst2_awvalid;
wire [AXI_ADDR_W-1:0] mst2_awaddr;
wire [8-1:0] mst2_awlen;
wire [3-1:0] mst2_awsize;
wire [2-1:0] mst2_awburst;
wire mst2_awlock;
wire [4-1:0] mst2_awcache;
wire [3-1:0] mst2_awprot;
wire [4-1:0] mst2_awqos;
wire [4-1:0] mst2_awregion;
wire [AXI_ID_W-1:0] mst2_awid;
wire [AXI_AUSER_W-1:0] mst2_awuser;
wire mst2_wvalid;
wire mst2_wlast;
wire [AXI_DATA_W-1:0] mst2_wdata;
wire [AXI_DATA_W/8-1:0] mst2_wstrb;
wire [AXI_WUSER_W-1:0] mst2_wuser;
wire mst2_bready;
wire mst2_arvalid;
wire [AXI_ADDR_W-1:0] mst2_araddr;
wire [8-1:0] mst2_arlen;
wire [3-1:0] mst2_arsize;
wire [2-1:0] mst2_arburst;
wire mst2_arlock;
wire [4-1:0] mst2_arcache;
wire [3-1:0] mst2_arprot;
wire [4-1:0] mst2_arqos;
wire [4-1:0] mst2_arregion;
wire [AXI_ID_W-1:0] mst2_arid;
wire [AXI_AUSER_W-1:0] mst2_aruser;
wire mst2_rready;
wire mst3_awvalid;
wire [AXI_ADDR_W-1:0] mst3_awaddr;
wire [8-1:0] mst3_awlen;
wire [3-1:0] mst3_awsize;
wire [2-1:0] mst3_awburst;
wire mst3_awlock;
wire [4-1:0] mst3_awcache;
wire [3-1:0] mst3_awprot;
wire [4-1:0] mst3_awqos;
wire [4-1:0] mst3_awregion;
wire [AXI_ID_W-1:0] mst3_awid;
wire [AXI_AUSER_W-1:0] mst3_awuser;
wire mst3_wvalid;
wire mst3_wlast;
wire [AXI_DATA_W-1:0] mst3_wdata;
wire [AXI_DATA_W/8-1:0] mst3_wstrb;
wire [AXI_WUSER_W-1:0] mst3_wuser;
wire mst3_bready;
wire mst3_arvalid;
wire [AXI_ADDR_W-1:0] mst3_araddr;
wire [8-1:0] mst3_arlen;
wire [3-1:0] mst3_arsize;
wire [2-1:0] mst3_arburst;
wire mst3_arlock;
wire [4-1:0] mst3_arcache;
wire [3-1:0] mst3_arprot;
wire [4-1:0] mst3_arqos;
wire [4-1:0] mst3_arregion;
wire [AXI_ID_W-1:0] mst3_arid;
wire [AXI_AUSER_W-1:0] mst3_aruser;
wire mst3_rready;

// output declaration of module dm_top
wire halt_req;
wire hartreset;
wire ndmreset;
wire slv2_awvalid;
wire [AXI_ADDR_W-1:0] slv2_awaddr;
wire [8-1:0] slv2_awlen;
wire [3-1:0] slv2_awsize;
wire [2-1:0] slv2_awburst;
wire slv2_awlock;
wire [4-1:0] slv2_awcache;
wire [3-1:0] slv2_awprot;
wire [4-1:0] slv2_awqos;
wire [4-1:0] slv2_awregion;
wire [AXI_ID_W-1:0] slv2_awid;
wire slv2_wvalid;
wire slv2_wlast;
wire [AXI_DATA_W-1:0] slv2_wdata;
wire [AXI_DATA_W/8-1:0] slv2_wstrb;
wire slv2_bready;
wire slv2_arvalid;
wire [AXI_ADDR_W-1:0] slv2_araddr;
wire [8-1:0] slv2_arlen;
wire [3-1:0] slv2_arsize;
wire [2-1:0] slv2_arburst;
wire slv2_arlock;
wire [4-1:0] slv2_arcache;
wire [3-1:0] slv2_arprot;
wire [4-1:0] slv2_arqos;
wire [4-1:0] slv2_arregion;
wire [AXI_ID_W-1:0] slv2_arid;
wire slv2_rready;


// output declaration of module dummy_axi_slv0
wire mst0_awready;
wire mst0_wready;
wire mst0_bvalid;
wire [AXI_ID_W-1:0] mst0_bid;
wire [2-1:0] mst0_bresp;
wire mst0_arready;
wire mst0_rvalid;
wire [AXI_ID_W-1:0] mst0_rid;
wire [2-1:0] mst0_rresp;
wire [AXI_DATA_W-1:0] mst0_rdata;
wire mst0_rlast;

// output declaration of module dummy_axi_slv1
wire mst1_awready;
wire mst1_wready;
wire mst1_bvalid;
wire [AXI_ID_W-1:0] mst1_bid;
wire [2-1:0] mst1_bresp;
wire mst1_arready;
wire mst1_rvalid;
wire [AXI_ID_W-1:0] mst1_rid;
wire [2-1:0] mst1_rresp;
wire [AXI_DATA_W-1:0] mst1_rdata;
wire mst1_rlast;

// output declaration of module dummy_axi_slv2
wire mst2_awready;
wire mst2_wready;
wire mst2_bvalid;
wire [AXI_ID_W-1:0] mst2_bid;
wire [2-1:0] mst2_bresp;
wire mst2_arready;
wire mst2_rvalid;
wire [AXI_ID_W-1:0] mst2_rid;
wire [2-1:0] mst2_rresp;
wire [AXI_DATA_W-1:0] mst2_rdata;
wire mst2_rlast;

// output declaration of module sim_sram_dpic
wire mst3_awready;
wire mst3_wready;
wire mst3_bvalid;
wire [AXI_ID_W-1:0] mst3_bid;
wire [2-1:0] mst3_bresp;
wire mst3_arready;
wire mst3_rvalid;
wire [AXI_ID_W-1:0] mst3_rid;
wire [2-1:0] mst3_rresp;
wire [AXI_DATA_W-1:0] mst3_rdata;
wire mst3_rlast;

reg core_rst_n_r;
reg core_rst_n;
reg dm_rst_n_r;
reg dm_rst_n;
reg trst_n_r;
reg trst_n;

always @(posedge clk or negedge rst_n) begin
    if(!rst_n)begin
        core_rst_n_r <= 1'b0;
        core_rst_n   <= 1'b0;
    end
    else if(hartreset)begin
        core_rst_n_r <= 1'b0;
        core_rst_n   <= 1'b0;
    end
    else if(ndmreset)begin
        core_rst_n_r <= 1'b0;
        core_rst_n   <= 1'b0;
    end
    else begin
        core_rst_n_r <= 1'b1;
        core_rst_n   <= core_rst_n_r;
    end
end

always @(posedge clk or negedge rst_n) begin
    if(!rst_n)begin
        dm_rst_n_r <= 1'b0;
        dm_rst_n   <= 1'b0;
    end
    else begin
        dm_rst_n_r <= 1'b1;
        dm_rst_n   <= dm_rst_n_r;
    end
end

always @(posedge tck or negedge rst_n) begin
    if(!rst_n)begin
        trst_n_r <= 1'b0;
        trst_n   <= 1'b0;
    end
    else begin
        trst_n_r <= 1'b1;
        trst_n   <= trst_n_r;
    end
end

core_top #(
    .MHARTID 	(0          ),
    .RST_PC  	(`RST_PC    ))
u_core_top(
    .clk         	(clk          ),
    .rst_n       	(core_rst_n   ),
    .stip_asyn   	(stip_asyn    ),
    .seip_asyn   	(seip_asyn    ),
    .ssip_asyn   	(ssip_asyn    ),
    .mtip_asyn   	(mtip_asyn    ),
    .meip_asyn   	(meip_asyn    ),
    .msip_asyn   	(msip_asyn    ),
    .halt_req       (halt_req     ),
    .MXR         	(MXR          ),
    .SUM         	(SUM          ),
    .MPRV        	(MPRV         ),
    .MPP         	(MPP          ),
    .satp_mode   	(satp_mode    ),
    .satp_asid   	(satp_asid    ),
    .satp_ppn    	(satp_ppn     ),

    .ifu_arready 	(slv0_arready ),
    .ifu_arvalid 	(ifu_arvalid  ),
    .ifu_araddr  	(ifu_araddr   ),
    .ifu_rvalid  	(slv0_rvalid  ),
    .ifu_rready  	(ifu_rready   ),
    .ifu_rresp   	(slv0_rresp   ),
    .ifu_rdata   	(slv0_rdata   ),

    .lsu_arvalid 	(lsu_arvalid  ),
    .lsu_arready 	(slv1_arready ),
    .lsu_arlock  	(lsu_arlock   ),
    .lsu_arsize  	(lsu_arsize   ),
    .lsu_araddr  	(lsu_araddr   ),
    .lsu_rvalid  	(slv1_rvalid  ),
    .lsu_rready  	(lsu_rready   ),
    .lsu_rresp   	(slv1_rresp   ),
    .lsu_rdata   	(slv1_rdata   ),
    .lsu_awvalid 	(lsu_awvalid  ),
    .lsu_awready 	(slv1_awready ),
    .lsu_awlock  	(lsu_awlock   ),
    .lsu_awsize  	(lsu_awsize   ),
    .lsu_awaddr  	(lsu_awaddr   ),
    .lsu_wvalid  	(lsu_wvalid   ),
    .lsu_wready  	(slv1_wready  ),
    .lsu_wstrb  	(lsu_wstrb    ),
    .lsu_wdata   	(lsu_wdata    ),
    .lsu_bvalid  	(slv1_bvalid  ),
    .lsu_bready  	(lsu_bready   ),
    .lsu_bresp   	(slv1_bresp   )
);

axicb_crossbar_top #(
    .AXI_ADDR_W          	(AXI_ADDR_W         ),
    .AXI_ID_W            	(AXI_ID_W           ),
    .AXI_DATA_W          	(AXI_DATA_W         ),

    .MST_NB              	(4        ),
    .SLV_NB              	(4        ),

    .MST_PIPELINE        	(0        ),
    .SLV_PIPELINE        	(0        ),

    .AXI_SIGNALING       	(1        ),

    .USER_SUPPORT        	(0        ),
    .AXI_AUSER_W         	(1        ),
    .AXI_WUSER_W         	(1        ),
    .AXI_BUSER_W         	(1        ),
    .AXI_RUSER_W         	(1        ),

    .TIMEOUT_VALUE       	(10000    ),
    .TIMEOUT_ENABLE      	(1        ),

    .MST0_CDC            	(0        ),
    .MST0_OSTDREQ_NUM    	(4        ),
    .MST0_OSTDREQ_SIZE   	(1        ),
    .MST0_PRIORITY       	(0        ),
    .MST0_ROUTES         	(4'b1_1_1_1  ),
    .MST0_ID_MASK        	(8'h10       ),
    .MST0_RW             	(1        ),

    .MST1_CDC            	(0        ),
    .MST1_OSTDREQ_NUM    	(4        ),
    .MST1_OSTDREQ_SIZE   	(1        ),
    .MST1_PRIORITY       	(0        ),
    .MST1_ROUTES         	(4'b1_1_1_1  ),
    .MST1_ID_MASK        	(8'h20       ),
    .MST1_RW             	(0        ),

    .MST2_CDC            	(1        ),
    .MST2_OSTDREQ_NUM    	(4        ),
    .MST2_OSTDREQ_SIZE   	(1        ),
    .MST2_PRIORITY       	(0        ),
    .MST2_ROUTES         	(4'b1_1_1_1  ),
    .MST2_ID_MASK        	(8'h40       ),
    .MST2_RW             	(0        ),

    // .MST3_CDC            	(0        ),
    // .MST3_OSTDREQ_NUM    	(4        ),
    // .MST3_OSTDREQ_SIZE   	(1        ),
    // .MST3_PRIORITY       	(0        ),
    // .MST3_ROUTES         	(1_1_1_1  ),
    // .MST3_ID_MASK        	(40       ),
    // .MST3_RW             	(0        ),

    .SLV0_CDC            	(1        ),
    .SLV0_START_ADDR     	(64'h0000_0000    ),
    .SLV0_END_ADDR       	(64'h0000_0fff    ),
    .SLV0_OSTDREQ_NUM    	(4        ),
    .SLV0_OSTDREQ_SIZE   	(1        ),
    .SLV0_KEEP_BASE_ADDR 	(1        ),

    .SLV1_CDC            	(0        ),
    .SLV1_START_ADDR     	(64'h0000_1000    ),
    .SLV1_END_ADDR       	(64'h7fff_ffff    ),
    .SLV1_OSTDREQ_NUM    	(4        ),
    .SLV1_OSTDREQ_SIZE   	(1        ),
    .SLV1_KEEP_BASE_ADDR 	(1        ),

    .SLV2_CDC            	(0        ),
    .SLV2_START_ADDR     	(64'h8000_0000    ),
    .SLV2_END_ADDR       	(64'h9fff_ffff    ),
    .SLV2_OSTDREQ_NUM    	(4        ),
    .SLV2_OSTDREQ_SIZE   	(1        ),
    .SLV2_KEEP_BASE_ADDR 	(1        ),

    .SLV3_CDC            	(0        ),
    .SLV3_START_ADDR     	(64'hA000_0000    ),
    .SLV3_END_ADDR       	(64'hBfff_ffff    ),
    .SLV3_OSTDREQ_NUM    	(4        ),
    .SLV3_OSTDREQ_SIZE   	(1        ),
    .SLV3_KEEP_BASE_ADDR 	(1        ))
u_axicb_crossbar_top(
    .aclk          	(clk            ),
    .aresetn       	(core_rst_n     ),
    .srst          	(1'b0           ),

    .slv0_aclk     	(clk            ),
    .slv0_aresetn  	(core_rst_n     ),
    .slv0_srst     	(1'b0           ),
    .slv0_awvalid  	(1'b0           ),
    .slv0_awready  	(slv0_awready   ),
    .slv0_awaddr   	(64'h0          ),
    .slv0_awlen    	(8'h0           ),
    .slv0_awsize   	(3'h0           ),
    .slv0_awburst  	(2'h0           ),
    .slv0_awlock   	(1'h0           ),
    .slv0_awcache  	(4'h0           ),
    .slv0_awprot   	(3'h0           ),
    .slv0_awqos    	(4'h0           ),
    .slv0_awregion 	(4'h0           ),
    .slv0_awid     	(8'h10          ),
    .slv0_awuser   	(1'h0           ),
    .slv0_wvalid   	(1'h0           ),
    .slv0_wready   	(slv0_wready    ),
    .slv0_wlast    	(1'h0           ),
    .slv0_wdata    	(64'h0          ),
    .slv0_wstrb    	(8'h0           ),
    .slv0_wuser    	(1'b0           ),
    .slv0_bvalid   	(slv0_bvalid    ),
    .slv0_bready   	(1'h0           ),
    .slv0_bid      	(slv0_bid       ),
    .slv0_bresp    	(slv0_bresp     ),
    .slv0_buser    	(slv0_buser     ),
    .slv0_arvalid  	(ifu_arvalid    ),
    .slv0_arready  	(slv0_arready   ),
    .slv0_araddr   	(ifu_araddr     ),
    .slv0_arlen    	(8'h0           ),
    .slv0_arsize   	(3'h3           ),
    .slv0_arburst  	(2'h1           ),
    .slv0_arlock   	(1'h0           ),
    .slv0_arcache  	(4'h0           ),
    .slv0_arprot   	(3'h0           ),
    .slv0_arqos    	(4'h0           ),
    .slv0_arregion 	(4'h0           ),
    .slv0_arid     	(8'h10          ),
    .slv0_aruser   	(1'b0           ),
    .slv0_rvalid   	(slv0_rvalid    ),
    .slv0_rready   	(ifu_rready     ),
    .slv0_rid      	(slv0_rid       ),
    .slv0_rresp    	(slv0_rresp     ),
    .slv0_rdata    	(slv0_rdata     ),
    .slv0_rlast    	(slv0_rlast     ),
    .slv0_ruser    	(slv0_ruser     ),

    .slv1_aclk     	(clk            ),
    .slv1_aresetn  	(core_rst_n     ),
    .slv1_srst     	(1'b0           ),
    .slv1_awvalid  	(lsu_awvalid    ),
    .slv1_awready  	(slv1_awready   ),
    .slv1_awaddr   	(lsu_awaddr     ),
    .slv1_awlen    	(8'h0           ),
    .slv1_awsize   	(lsu_awsize     ),
    .slv1_awburst  	(2'h1           ),
    .slv1_awlock   	(lsu_awlock     ),
    .slv1_awcache  	(4'h0           ),
    .slv1_awprot   	(3'h0           ),
    .slv1_awqos    	(4'h0           ),
    .slv1_awregion 	(4'h0           ),
    .slv1_awid     	(8'h20          ),
    .slv1_awuser   	(1'b0           ),
    .slv1_wvalid   	(lsu_wvalid     ),
    .slv1_wready   	(slv1_wready    ),
    .slv1_wlast    	(1'b1           ),
    .slv1_wdata    	(lsu_wdata      ),
    .slv1_wstrb    	(lsu_wstrb      ),
    .slv1_wuser    	(1'b0           ),
    .slv1_bvalid   	(slv1_bvalid    ),
    .slv1_bready   	(lsu_bready     ),
    .slv1_bid      	(slv1_bid       ),
    .slv1_bresp    	(slv1_bresp     ),
    .slv1_buser    	(slv1_buser     ),
    .slv1_arvalid  	(lsu_arvalid    ),
    .slv1_arready  	(slv1_arready   ),
    .slv1_araddr   	(lsu_araddr     ),
    .slv1_arlen    	(8'h0           ),
    .slv1_arsize   	(lsu_arsize     ),
    .slv1_arburst  	(2'h1           ),
    .slv1_arlock   	(lsu_arlock     ),
    .slv1_arcache  	(4'h0           ),
    .slv1_arprot   	(3'h0           ),
    .slv1_arqos    	(4'h0           ),
    .slv1_arregion 	(4'h0           ),
    .slv1_arid     	(8'h20          ),
    .slv1_aruser   	(1'b0           ),
    .slv1_rvalid   	(slv1_rvalid    ),
    .slv1_rready   	(lsu_rready     ),
    .slv1_rid      	(slv1_rid       ),
    .slv1_rresp    	(slv1_rresp     ),
    .slv1_rdata    	(slv1_rdata     ),
    .slv1_rlast    	(slv1_rlast     ),
    .slv1_ruser    	(slv1_ruser     ),

    .slv2_aclk     	(clk            ),
    .slv2_aresetn  	(dm_rst_n       ),
    .slv2_srst     	(1'b0           ),
    .slv2_awvalid  	(slv2_awvalid   ),
    .slv2_awready  	(slv2_awready   ),
    .slv2_awaddr   	(slv2_awaddr    ),
    .slv2_awlen    	(slv2_awlen     ),
    .slv2_awsize   	(slv2_awsize    ),
    .slv2_awburst  	(slv2_awburst   ),
    .slv2_awlock   	(slv2_awlock    ),
    .slv2_awcache  	(slv2_awcache   ),
    .slv2_awprot   	(slv2_awprot    ),
    .slv2_awqos    	(slv2_awqos     ),
    .slv2_awregion 	(slv2_awregion  ),
    .slv2_awid     	(slv2_awid      ),
    .slv2_awuser   	(1'b0           ),
    .slv2_wvalid   	(slv2_wvalid    ),
    .slv2_wready   	(slv2_wready    ),
    .slv2_wlast    	(slv2_wlast     ),
    .slv2_wdata    	(slv2_wdata     ),
    .slv2_wstrb    	(slv2_wstrb     ),
    .slv2_wuser    	(1'b0           ),
    .slv2_bvalid   	(slv2_bvalid    ),
    .slv2_bready   	(slv2_bready    ),
    .slv2_bid      	(slv2_bid       ),
    .slv2_bresp    	(slv2_bresp     ),
    .slv2_buser    	(slv2_buser     ),
    .slv2_arvalid  	(slv2_arvalid   ),
    .slv2_arready  	(slv2_arready   ),
    .slv2_araddr   	(slv2_araddr    ),
    .slv2_arlen    	(slv2_arlen     ),
    .slv2_arsize   	(slv2_arsize    ),
    .slv2_arburst  	(slv2_arburst   ),
    .slv2_arlock   	(slv2_arlock    ),
    .slv2_arcache  	(slv2_arcache   ),
    .slv2_arprot   	(slv2_arprot    ),
    .slv2_arqos    	(slv2_arqos     ),
    .slv2_arregion 	(slv2_arregion  ),
    .slv2_arid     	(slv2_arid      ),
    .slv2_aruser   	(1'b0           ),
    .slv2_rvalid   	(slv2_rvalid    ),
    .slv2_rready   	(slv2_rready    ),
    .slv2_rid      	(slv2_rid       ),
    .slv2_rresp    	(slv2_rresp     ),
    .slv2_rdata    	(slv2_rdata     ),
    .slv2_rlast    	(slv2_rlast     ),
    .slv2_ruser    	(slv2_ruser     ),

    .slv3_aclk     	(clk            ),
    .slv3_aresetn  	(core_rst_n     ),
    .slv3_srst     	(1'b0           ),
    .slv3_awvalid  	(1'b0           ),
    .slv3_awready  	(slv3_awready   ),
    .slv3_awaddr   	(64'h0          ),
    .slv3_awlen    	(8'h0           ),
    .slv3_awsize   	(3'h0           ),
    .slv3_awburst  	(2'h0           ),
    .slv3_awlock   	(1'h0           ),
    .slv3_awcache  	(4'h0           ),
    .slv3_awprot   	(3'h0           ),
    .slv3_awqos    	(4'h0           ),
    .slv3_awregion 	(4'h0           ),
    .slv3_awid     	(8'h3           ),
    .slv3_awuser   	(1'h0           ),
    .slv3_wvalid   	(1'h0           ),
    .slv3_wready   	(slv3_wready    ),
    .slv3_wlast    	(1'h0           ),
    .slv3_wdata    	(64'h0          ),
    .slv3_wstrb    	(8'h0           ),
    .slv3_wuser    	(1'b0           ),
    .slv3_bvalid   	(slv3_bvalid    ),
    .slv3_bready   	(1'h0           ),
    .slv3_bid      	(slv3_bid       ),
    .slv3_bresp    	(slv3_bresp     ),
    .slv3_buser    	(slv3_buser     ),
    .slv3_arvalid  	(1'b0           ),
    .slv3_arready  	(slv3_arready   ),
    .slv3_araddr   	(64'h0          ),
    .slv3_arlen    	(8'h0           ),
    .slv3_arsize   	(3'h0           ),
    .slv3_arburst  	(2'h0           ),
    .slv3_arlock   	(1'h0           ),
    .slv3_arcache  	(4'h0           ),
    .slv3_arprot   	(3'h0           ),
    .slv3_arqos    	(4'h0           ),
    .slv3_arregion 	(4'h0           ),
    .slv3_arid     	(8'h3           ),
    .slv3_aruser   	(1'b0           ),
    .slv3_rvalid   	(slv3_rvalid    ),
    .slv3_rready   	(1'b0           ),
    .slv3_rid      	(slv3_rid       ),
    .slv3_rresp    	(slv3_rresp     ),
    .slv3_rdata    	(slv3_rdata     ),
    .slv3_rlast    	(slv3_rlast     ),
    .slv3_ruser    	(slv3_ruser     ),

    .mst0_aclk     	(clk            ),
    .mst0_aresetn  	(dm_rst_n       ),
    .mst0_srst     	(1'b0           ),
    .mst0_awvalid  	(mst0_awvalid   ),
    .mst0_awready  	(mst0_awready   ),
    .mst0_awaddr   	(mst0_awaddr    ),
    .mst0_awlen    	(mst0_awlen     ),
    .mst0_awsize   	(mst0_awsize    ),
    .mst0_awburst  	(mst0_awburst   ),
    .mst0_awlock   	(mst0_awlock    ),
    .mst0_awcache  	(mst0_awcache   ),
    .mst0_awprot   	(mst0_awprot    ),
    .mst0_awqos    	(mst0_awqos     ),
    .mst0_awregion 	(mst0_awregion  ),
    .mst0_awid     	(mst0_awid      ),
    .mst0_awuser   	(mst0_awuser    ),
    .mst0_wvalid   	(mst0_wvalid    ),
    .mst0_wready   	(mst0_wready    ),
    .mst0_wlast    	(mst0_wlast     ),
    .mst0_wdata    	(mst0_wdata     ),
    .mst0_wstrb    	(mst0_wstrb     ),
    .mst0_wuser    	(mst0_wuser     ),
    .mst0_bvalid   	(mst0_bvalid    ),
    .mst0_bready   	(mst0_bready    ),
    .mst0_bid      	(mst0_bid       ),
    .mst0_bresp    	(mst0_bresp     ),
    .mst0_buser    	(1'b0           ),
    .mst0_arvalid  	(mst0_arvalid   ),
    .mst0_arready  	(mst0_arready   ),
    .mst0_araddr   	(mst0_araddr    ),
    .mst0_arlen    	(mst0_arlen     ),
    .mst0_arsize   	(mst0_arsize    ),
    .mst0_arburst  	(mst0_arburst   ),
    .mst0_arlock   	(mst0_arlock    ),
    .mst0_arcache  	(mst0_arcache   ),
    .mst0_arprot   	(mst0_arprot    ),
    .mst0_arqos    	(mst0_arqos     ),
    .mst0_arregion 	(mst0_arregion  ),
    .mst0_arid     	(mst0_arid      ),
    .mst0_aruser   	(mst0_aruser    ),
    .mst0_rvalid   	(mst0_rvalid    ),
    .mst0_rready   	(mst0_rready    ),
    .mst0_rid      	(mst0_rid       ),
    .mst0_rresp    	(mst0_rresp     ),
    .mst0_rdata    	(mst0_rdata     ),
    .mst0_rlast    	(mst0_rlast     ),
    .mst0_ruser    	(1'b0           ),

    .mst1_aclk      (clk            ),
    .mst1_aresetn   (core_rst_n     ),
    .mst1_srst      (1'b0           ),
    .mst1_awvalid  	(mst1_awvalid   ),
    .mst1_awready  	(mst1_awready   ),
    .mst1_awaddr   	(mst1_awaddr    ),
    .mst1_awlen    	(mst1_awlen     ),
    .mst1_awsize   	(mst1_awsize    ),
    .mst1_awburst  	(mst1_awburst   ),
    .mst1_awlock   	(mst1_awlock    ),
    .mst1_awcache  	(mst1_awcache   ),
    .mst1_awprot   	(mst1_awprot    ),
    .mst1_awqos    	(mst1_awqos     ),
    .mst1_awregion 	(mst1_awregion  ),
    .mst1_awid     	(mst1_awid      ),
    .mst1_awuser   	(mst1_awuser    ),
    .mst1_wvalid   	(mst1_wvalid    ),
    .mst1_wready   	(mst1_wready    ),
    .mst1_wlast    	(mst1_wlast     ),
    .mst1_wdata    	(mst1_wdata     ),
    .mst1_wstrb    	(mst1_wstrb     ),
    .mst1_wuser    	(mst1_wuser     ),
    .mst1_bvalid   	(mst1_bvalid    ),
    .mst1_bready   	(mst1_bready    ),
    .mst1_bid      	(mst1_bid       ),
    .mst1_bresp    	(mst1_bresp     ),
    .mst1_buser    	(1'b0           ),
    .mst1_arvalid  	(mst1_arvalid   ),
    .mst1_arready  	(mst1_arready   ),
    .mst1_araddr   	(mst1_araddr    ),
    .mst1_arlen    	(mst1_arlen     ),
    .mst1_arsize   	(mst1_arsize    ),
    .mst1_arburst  	(mst1_arburst   ),
    .mst1_arlock   	(mst1_arlock    ),
    .mst1_arcache  	(mst1_arcache   ),
    .mst1_arprot   	(mst1_arprot    ),
    .mst1_arqos    	(mst1_arqos     ),
    .mst1_arregion 	(mst1_arregion  ),
    .mst1_arid     	(mst1_arid      ),
    .mst1_aruser   	(mst1_aruser    ),
    .mst1_rvalid   	(mst1_rvalid    ),
    .mst1_rready   	(mst1_rready    ),
    .mst1_rid      	(mst1_rid       ),
    .mst1_rresp    	(mst1_rresp     ),
    .mst1_rdata    	(mst1_rdata     ),
    .mst1_rlast    	(mst1_rlast     ),
    .mst1_ruser    	(1'b0           ),

    .mst2_aclk     	(clk            ),
    .mst2_aresetn  	(core_rst_n     ),
    .mst2_srst     	(1'b0           ),
    .mst2_awvalid  	(mst2_awvalid   ),
    .mst2_awready  	(mst2_awready   ),
    .mst2_awaddr   	(mst2_awaddr    ),
    .mst2_awlen    	(mst2_awlen     ),
    .mst2_awsize   	(mst2_awsize    ),
    .mst2_awburst  	(mst2_awburst   ),
    .mst2_awlock   	(mst2_awlock    ),
    .mst2_awcache  	(mst2_awcache   ),
    .mst2_awprot   	(mst2_awprot    ),
    .mst2_awqos    	(mst2_awqos     ),
    .mst2_awregion 	(mst2_awregion  ),
    .mst2_awid     	(mst2_awid      ),
    .mst2_awuser   	(mst2_awuser    ),
    .mst2_wvalid   	(mst2_wvalid    ),
    .mst2_wready   	(mst2_wready    ),
    .mst2_wlast    	(mst2_wlast     ),
    .mst2_wdata    	(mst2_wdata     ),
    .mst2_wstrb    	(mst2_wstrb     ),
    .mst2_wuser    	(mst2_wuser     ),
    .mst2_bvalid   	(mst2_bvalid    ),
    .mst2_bready   	(mst2_bready    ),
    .mst2_bid      	(mst2_bid       ),
    .mst2_bresp    	(mst2_bresp     ),
    .mst2_buser    	(1'b0           ),
    .mst2_arvalid  	(mst2_arvalid   ),
    .mst2_arready  	(mst2_arready   ),
    .mst2_araddr   	(mst2_araddr    ),
    .mst2_arlen    	(mst2_arlen     ),
    .mst2_arsize   	(mst2_arsize    ),
    .mst2_arburst  	(mst2_arburst   ),
    .mst2_arlock   	(mst2_arlock    ),
    .mst2_arcache  	(mst2_arcache   ),
    .mst2_arprot   	(mst2_arprot    ),
    .mst2_arqos    	(mst2_arqos     ),
    .mst2_arregion 	(mst2_arregion  ),
    .mst2_arid     	(mst2_arid      ),
    .mst2_aruser   	(mst2_aruser    ),
    .mst2_rvalid   	(mst2_rvalid    ),
    .mst2_rready   	(mst2_rready    ),
    .mst2_rid      	(mst2_rid       ),
    .mst2_rresp    	(mst2_rresp     ),
    .mst2_rdata    	(mst2_rdata     ),
    .mst2_rlast    	(mst2_rlast     ),
    .mst2_ruser    	(1'b0           ),

    .mst3_aclk     	(clk            ),
    .mst3_aresetn  	(core_rst_n     ),
    .mst3_srst     	(1'b0           ),
    .mst3_awvalid  	(mst3_awvalid   ),
    .mst3_awready  	(mst3_awready   ),
    .mst3_awaddr   	(mst3_awaddr    ),
    .mst3_awlen    	(mst3_awlen     ),
    .mst3_awsize   	(mst3_awsize    ),
    .mst3_awburst  	(mst3_awburst   ),
    .mst3_awlock   	(mst3_awlock    ),
    .mst3_awcache  	(mst3_awcache   ),
    .mst3_awprot   	(mst3_awprot    ),
    .mst3_awqos    	(mst3_awqos     ),
    .mst3_awregion 	(mst3_awregion  ),
    .mst3_awid     	(mst3_awid      ),
    .mst3_awuser   	(mst3_awuser    ),
    .mst3_wvalid   	(mst3_wvalid    ),
    .mst3_wready   	(mst3_wready    ),
    .mst3_wlast    	(mst3_wlast     ),
    .mst3_wdata    	(mst3_wdata     ),
    .mst3_wstrb    	(mst3_wstrb     ),
    .mst3_wuser    	(mst3_wuser     ),
    .mst3_bvalid   	(mst3_bvalid    ),
    .mst3_bready   	(mst3_bready    ),
    .mst3_bid      	(mst3_bid       ),
    .mst3_bresp    	(mst3_bresp     ),
    .mst3_buser    	(1'b0           ),
    .mst3_arvalid  	(mst3_arvalid   ),
    .mst3_arready  	(mst3_arready   ),
    .mst3_araddr   	(mst3_araddr    ),
    .mst3_arlen    	(mst3_arlen     ),
    .mst3_arsize   	(mst3_arsize    ),
    .mst3_arburst  	(mst3_arburst   ),
    .mst3_arlock   	(mst3_arlock    ),
    .mst3_arcache  	(mst3_arcache   ),
    .mst3_arprot   	(mst3_arprot    ),
    .mst3_arqos    	(mst3_arqos     ),
    .mst3_arregion 	(mst3_arregion  ),
    .mst3_arid     	(mst3_arid      ),
    .mst3_aruser   	(mst3_aruser    ),
    .mst3_rvalid   	(mst3_rvalid    ),
    .mst3_rready   	(mst3_rready    ),
    .mst3_rid      	(mst3_rid       ),
    .mst3_rresp    	(mst3_rresp     ),
    .mst3_rdata    	(mst3_rdata     ),
    .mst3_rlast    	(mst3_rlast     ),
    .mst3_ruser    	(1'b0           )
);

// dummy_axi_slv #(
//     .AXI_ADDR_W 	(AXI_ADDR_W     ),
//     .AXI_ID_W   	(AXI_ID_W       ),
//     .AXI_DATA_W 	(AXI_DATA_W     ))
// u_dummy_axi_slv0(
//     .mst_awvalid  	(mst0_awvalid   ),
//     .mst_awready  	(mst0_awready   ),
//     .mst_awaddr   	(mst0_awaddr    ),
//     .mst_awlen    	(mst0_awlen     ),
//     .mst_awsize   	(mst0_awsize    ),
//     .mst_awburst  	(mst0_awburst   ),
//     .mst_awlock   	(mst0_awlock    ),
//     .mst_awcache  	(mst0_awcache   ),
//     .mst_awprot   	(mst0_awprot    ),
//     .mst_awqos    	(mst0_awqos     ),
//     .mst_awregion 	(mst0_awregion  ),
//     .mst_awid     	(mst0_awid      ),
//     .mst_wvalid   	(mst0_wvalid    ),
//     .mst_wready   	(mst0_wready    ),
//     .mst_wlast    	(mst0_wlast     ),
//     .mst_wdata    	(mst0_wdata     ),
//     .mst_wstrb    	(mst0_wstrb     ),
//     .mst_bvalid   	(mst0_bvalid    ),
//     .mst_bready   	(mst0_bready    ),
//     .mst_bid      	(mst0_bid       ),
//     .mst_bresp    	(mst0_bresp     ),
//     .mst_arvalid  	(mst0_arvalid   ),
//     .mst_arready  	(mst0_arready   ),
//     .mst_araddr   	(mst0_araddr    ),
//     .mst_arlen    	(mst0_arlen     ),
//     .mst_arsize   	(mst0_arsize    ),
//     .mst_arburst  	(mst0_arburst   ),
//     .mst_arlock   	(mst0_arlock    ),
//     .mst_arcache  	(mst0_arcache   ),
//     .mst_arprot   	(mst0_arprot    ),
//     .mst_arqos    	(mst0_arqos     ),
//     .mst_arregion 	(mst0_arregion  ),
//     .mst_arid     	(mst0_arid      ),
//     .mst_rvalid   	(mst0_rvalid    ),
//     .mst_rready   	(mst0_rready    ),
//     .mst_rid      	(mst0_rid       ),
//     .mst_rresp    	(mst0_rresp     ),
//     .mst_rdata    	(mst0_rdata     ),
//     .mst_rlast    	(mst0_rlast     )
// );

dummy_axi_slv #(
    .AXI_ADDR_W 	(AXI_ADDR_W     ),
    .AXI_ID_W   	(AXI_ID_W       ),
    .AXI_DATA_W 	(AXI_DATA_W     ))
u_dummy_axi_slv1(
    .mst_awvalid  	(mst1_awvalid   ),
    .mst_awready  	(mst1_awready   ),
    .mst_awaddr   	(mst1_awaddr    ),
    .mst_awlen    	(mst1_awlen     ),
    .mst_awsize   	(mst1_awsize    ),
    .mst_awburst  	(mst1_awburst   ),
    .mst_awlock   	(mst1_awlock    ),
    .mst_awcache  	(mst1_awcache   ),
    .mst_awprot   	(mst1_awprot    ),
    .mst_awqos    	(mst1_awqos     ),
    .mst_awregion 	(mst1_awregion  ),
    .mst_awid     	(mst1_awid      ),
    .mst_wvalid   	(mst1_wvalid    ),
    .mst_wready   	(mst1_wready    ),
    .mst_wlast    	(mst1_wlast     ),
    .mst_wdata    	(mst1_wdata     ),
    .mst_wstrb    	(mst1_wstrb     ),
    .mst_bvalid   	(mst1_bvalid    ),
    .mst_bready   	(mst1_bready    ),
    .mst_bid      	(mst1_bid       ),
    .mst_bresp    	(mst1_bresp     ),
    .mst_arvalid  	(mst1_arvalid   ),
    .mst_arready  	(mst1_arready   ),
    .mst_araddr   	(mst1_araddr    ),
    .mst_arlen    	(mst1_arlen     ),
    .mst_arsize   	(mst1_arsize    ),
    .mst_arburst  	(mst1_arburst   ),
    .mst_arlock   	(mst1_arlock    ),
    .mst_arcache  	(mst1_arcache   ),
    .mst_arprot   	(mst1_arprot    ),
    .mst_arqos    	(mst1_arqos     ),
    .mst_arregion 	(mst1_arregion  ),
    .mst_arid     	(mst1_arid      ),
    .mst_rvalid   	(mst1_rvalid    ),
    .mst_rready   	(mst1_rready    ),
    .mst_rid      	(mst1_rid       ),
    .mst_rresp    	(mst1_rresp     ),
    .mst_rdata    	(mst1_rdata     ),
    .mst_rlast    	(mst1_rlast     )
);

// dummy_axi_slv #(
//     .AXI_ADDR_W 	(AXI_ADDR_W     ),
//     .AXI_ID_W   	(AXI_ID_W       ),
//     .AXI_DATA_W 	(AXI_DATA_W     ))
// u_dummy_axi_slv2(
//     .mst_awvalid  	(mst2_awvalid   ),
//     .mst_awready  	(mst2_awready   ),
//     .mst_awaddr   	(mst2_awaddr    ),
//     .mst_awlen    	(mst2_awlen     ),
//     .mst_awsize   	(mst2_awsize    ),
//     .mst_awburst  	(mst2_awburst   ),
//     .mst_awlock   	(mst2_awlock    ),
//     .mst_awcache  	(mst2_awcache   ),
//     .mst_awprot   	(mst2_awprot    ),
//     .mst_awqos    	(mst2_awqos     ),
//     .mst_awregion 	(mst2_awregion  ),
//     .mst_awid     	(mst2_awid      ),
//     .mst_wvalid   	(mst2_wvalid    ),
//     .mst_wready   	(mst2_wready    ),
//     .mst_wlast    	(mst2_wlast     ),
//     .mst_wdata    	(mst2_wdata     ),
//     .mst_wstrb    	(mst2_wstrb     ),
//     .mst_bvalid   	(mst2_bvalid    ),
//     .mst_bready   	(mst2_bready    ),
//     .mst_bid      	(mst2_bid       ),
//     .mst_bresp    	(mst2_bresp     ),
//     .mst_arvalid  	(mst2_arvalid   ),
//     .mst_arready  	(mst2_arready   ),
//     .mst_araddr   	(mst2_araddr    ),
//     .mst_arlen    	(mst2_arlen     ),
//     .mst_arsize   	(mst2_arsize    ),
//     .mst_arburst  	(mst2_arburst   ),
//     .mst_arlock   	(mst2_arlock    ),
//     .mst_arcache  	(mst2_arcache   ),
//     .mst_arprot   	(mst2_arprot    ),
//     .mst_arqos    	(mst2_arqos     ),
//     .mst_arregion 	(mst2_arregion  ),
//     .mst_arid     	(mst2_arid      ),
//     .mst_rvalid   	(mst2_rvalid    ),
//     .mst_rready   	(mst2_rready    ),
//     .mst_rid      	(mst2_rid       ),
//     .mst_rresp    	(mst2_rresp     ),
//     .mst_rdata    	(mst2_rdata     ),
//     .mst_rlast    	(mst2_rlast     )
// );

sim_sram_dpic #(
    .AXI_ADDR_W 	(64  ),
    .AXI_ID_W   	(8   ),
    .AXI_DATA_W 	(64  ))
u_sim_sram_dpic(
    .aclk         	(clk           ),
    .arst_n       	(core_rst_n    ),
    .mst_awvalid  	(mst2_awvalid  ),
    .mst_awready  	(mst2_awready  ),
    .mst_awaddr   	(mst2_awaddr   ),
    .mst_awlen    	(mst2_awlen    ),
    .mst_awsize   	(mst2_awsize   ),
    .mst_awburst  	(mst2_awburst  ),
    .mst_awlock   	(mst2_awlock   ),
    .mst_awcache  	(mst2_awcache  ),
    .mst_awprot   	(mst2_awprot   ),
    .mst_awqos    	(mst2_awqos    ),
    .mst_awregion 	(mst2_awregion ),
    .mst_awid     	(mst2_awid     ),
    .mst_wvalid   	(mst2_wvalid   ),
    .mst_wready   	(mst2_wready   ),
    .mst_wlast    	(mst2_wlast    ),
    .mst_wdata    	(mst2_wdata    ),
    .mst_wstrb    	(mst2_wstrb    ),
    .mst_bvalid   	(mst2_bvalid   ),
    .mst_bready   	(mst2_bready   ),
    .mst_bid      	(mst2_bid      ),
    .mst_bresp    	(mst2_bresp    ),
    .mst_arvalid  	(mst2_arvalid  ),
    .mst_arready  	(mst2_arready  ),
    .mst_araddr   	(mst2_araddr   ),
    .mst_arlen    	(mst2_arlen    ),
    .mst_arsize   	(mst2_arsize   ),
    .mst_arburst  	(mst2_arburst  ),
    .mst_arlock   	(mst2_arlock   ),
    .mst_arcache  	(mst2_arcache  ),
    .mst_arprot   	(mst2_arprot   ),
    .mst_arqos    	(mst2_arqos    ),
    .mst_arregion 	(mst2_arregion ),
    .mst_arid     	(mst2_arid     ),
    .mst_rvalid   	(mst2_rvalid   ),
    .mst_rready   	(mst2_rready   ),
    .mst_rid      	(mst2_rid      ),
    .mst_rresp    	(mst2_rresp    ),
    .mst_rdata    	(mst2_rdata    ),
    .mst_rlast    	(mst2_rlast    )
);

sim_periph_dpic #(
    .AXI_ADDR_W 	(AXI_ADDR_W  ),
    .AXI_ID_W   	(AXI_ID_W    ),
    .AXI_DATA_W 	(AXI_DATA_W  ))
u_sim_periph_dpic(
    .aclk         	(clk           ),
    .arst_n       	(core_rst_n    ),
    .mst_awvalid  	(mst3_awvalid  ),
    .mst_awready  	(mst3_awready  ),
    .mst_awaddr   	(mst3_awaddr   ),
    .mst_awlen    	(mst3_awlen    ),
    .mst_awsize   	(mst3_awsize   ),
    .mst_awburst  	(mst3_awburst  ),
    .mst_awlock   	(mst3_awlock   ),
    .mst_awcache  	(mst3_awcache  ),
    .mst_awprot   	(mst3_awprot   ),
    .mst_awqos    	(mst3_awqos    ),
    .mst_awregion 	(mst3_awregion ),
    .mst_awid     	(mst3_awid     ),
    .mst_wvalid   	(mst3_wvalid   ),
    .mst_wready   	(mst3_wready   ),
    .mst_wlast    	(mst3_wlast    ),
    .mst_wdata    	(mst3_wdata    ),
    .mst_wstrb    	(mst3_wstrb    ),
    .mst_bvalid   	(mst3_bvalid   ),
    .mst_bready   	(mst3_bready   ),
    .mst_bid      	(mst3_bid      ),
    .mst_bresp    	(mst3_bresp    ),
    .mst_arvalid  	(mst3_arvalid  ),
    .mst_arready  	(mst3_arready  ),
    .mst_araddr   	(mst3_araddr   ),
    .mst_arlen    	(mst3_arlen    ),
    .mst_arsize   	(mst3_arsize   ),
    .mst_arburst  	(mst3_arburst  ),
    .mst_arlock   	(mst3_arlock   ),
    .mst_arcache  	(mst3_arcache  ),
    .mst_arprot   	(mst3_arprot   ),
    .mst_arqos    	(mst3_arqos    ),
    .mst_arregion 	(mst3_arregion ),
    .mst_arid     	(mst3_arid     ),
    .mst_rvalid   	(mst3_rvalid   ),
    .mst_rready   	(mst3_rready   ),
    .mst_rid      	(mst3_rid      ),
    .mst_rresp    	(mst3_rresp    ),
    .mst_rdata    	(mst3_rdata    ),
    .mst_rlast    	(mst3_rlast    )
);


dm_top #(
    .ABITS      	(7           ),
    .AXI_ID_SB  	(8'h40       ),
    .AXI_ADDR_W 	(AXI_ADDR_W  ),
    .AXI_ID_W   	(AXI_ID_W    ),
    .AXI_DATA_W 	(AXI_DATA_W  ))
u_dm_top(
    .dm_clk        	(clk            ),
    .dm_rst_n      	(dm_rst_n       ),
    .dm_core_rst_n 	(core_rst_n     ),
    .halt_req      	(halt_req       ),
    .hartreset     	(hartreset      ),
    .ndmreset      	(ndmreset       ),
    .tck           	(tck            ),
    .trst_n        	(trst_n         ),
    .tms           	(tms            ),
    .tdi           	(tdi            ),
    .tdo           	(tdo            ),
    .slv_awvalid   	(slv2_awvalid   ),
    .slv_awready   	(slv2_awready   ),
    .slv_awaddr    	(slv2_awaddr    ),
    .slv_awlen     	(slv2_awlen     ),
    .slv_awsize    	(slv2_awsize    ),
    .slv_awburst   	(slv2_awburst   ),
    .slv_awlock    	(slv2_awlock    ),
    .slv_awcache   	(slv2_awcache   ),
    .slv_awprot    	(slv2_awprot    ),
    .slv_awqos     	(slv2_awqos     ),
    .slv_awregion  	(slv2_awregion  ),
    .slv_awid      	(slv2_awid      ),
    .slv_wvalid    	(slv2_wvalid    ),
    .slv_wready    	(slv2_wready    ),
    .slv_wlast     	(slv2_wlast     ),
    .slv_wdata     	(slv2_wdata     ),
    .slv_wstrb     	(slv2_wstrb     ),
    .slv_bvalid    	(slv2_bvalid    ),
    .slv_bready    	(slv2_bready    ),
    .slv_bid       	(slv2_bid       ),
    .slv_bresp     	(slv2_bresp     ),
    .slv_arvalid   	(slv2_arvalid   ),
    .slv_arready   	(slv2_arready   ),
    .slv_araddr    	(slv2_araddr    ),
    .slv_arlen     	(slv2_arlen     ),
    .slv_arsize    	(slv2_arsize    ),
    .slv_arburst   	(slv2_arburst   ),
    .slv_arlock    	(slv2_arlock    ),
    .slv_arcache   	(slv2_arcache   ),
    .slv_arprot    	(slv2_arprot    ),
    .slv_arqos     	(slv2_arqos     ),
    .slv_arregion  	(slv2_arregion  ),
    .slv_arid      	(slv2_arid      ),
    .slv_rvalid    	(slv2_rvalid    ),
    .slv_rready    	(slv2_rready    ),
    .slv_rid       	(slv2_rid       ),
    .slv_rresp     	(slv2_rresp     ),
    .slv_rdata     	(slv2_rdata     ),
    .slv_rlast     	(slv2_rlast     ),
    .mst_awvalid   	(mst0_awvalid   ),
    .mst_awready   	(mst0_awready   ),
    .mst_awaddr    	(mst0_awaddr    ),
    .mst_awlen     	(mst0_awlen     ),
    .mst_awsize    	(mst0_awsize    ),
    .mst_awburst   	(mst0_awburst   ),
    .mst_awlock    	(mst0_awlock    ),
    .mst_awcache   	(mst0_awcache   ),
    .mst_awprot    	(mst0_awprot    ),
    .mst_awqos     	(mst0_awqos     ),
    .mst_awregion  	(mst0_awregion  ),
    .mst_awid      	(mst0_awid      ),
    .mst_wvalid    	(mst0_wvalid    ),
    .mst_wready    	(mst0_wready    ),
    .mst_wlast     	(mst0_wlast     ),
    .mst_wdata     	(mst0_wdata     ),
    .mst_wstrb     	(mst0_wstrb     ),
    .mst_bvalid    	(mst0_bvalid    ),
    .mst_bready    	(mst0_bready    ),
    .mst_bid       	(mst0_bid       ),
    .mst_bresp     	(mst0_bresp     ),
    .mst_arvalid   	(mst0_arvalid   ),
    .mst_arready   	(mst0_arready   ),
    .mst_araddr    	(mst0_araddr    ),
    .mst_arlen     	(mst0_arlen     ),
    .mst_arsize    	(mst0_arsize    ),
    .mst_arburst   	(mst0_arburst   ),
    .mst_arlock    	(mst0_arlock    ),
    .mst_arcache   	(mst0_arcache   ),
    .mst_arprot    	(mst0_arprot    ),
    .mst_arqos     	(mst0_arqos     ),
    .mst_arregion  	(mst0_arregion  ),
    .mst_arid      	(mst0_arid      ),
    .mst_rvalid    	(mst0_rvalid    ),
    .mst_rready    	(mst0_rready    ),
    .mst_rid       	(mst0_rid       ),
    .mst_rresp     	(mst0_rresp     ),
    .mst_rdata     	(mst0_rdata     ),
    .mst_rlast     	(mst0_rlast     )
);
assign tap_state = u_dm_top.u_dtm.jtag_tap_state;


DifftestArchIntRegState u_DifftestArchIntRegState(
    .io_value_0  	(64'h0                                  ),
    .io_value_1  	(u_core_top.u_wbu.u_gpr.riscv_reg[1]    ),
    .io_value_2  	(u_core_top.u_wbu.u_gpr.riscv_reg[2]    ),
    .io_value_3  	(u_core_top.u_wbu.u_gpr.riscv_reg[3]    ),
    .io_value_4  	(u_core_top.u_wbu.u_gpr.riscv_reg[4]    ),
    .io_value_5  	(u_core_top.u_wbu.u_gpr.riscv_reg[5]    ),
    .io_value_6  	(u_core_top.u_wbu.u_gpr.riscv_reg[6]    ),
    .io_value_7  	(u_core_top.u_wbu.u_gpr.riscv_reg[7]    ),
    .io_value_8  	(u_core_top.u_wbu.u_gpr.riscv_reg[8]    ),
    .io_value_9  	(u_core_top.u_wbu.u_gpr.riscv_reg[9]    ),
    .io_value_10 	(u_core_top.u_wbu.u_gpr.riscv_reg[10]   ),
    .io_value_11 	(u_core_top.u_wbu.u_gpr.riscv_reg[11]   ),
    .io_value_12 	(u_core_top.u_wbu.u_gpr.riscv_reg[12]   ),
    .io_value_13 	(u_core_top.u_wbu.u_gpr.riscv_reg[13]   ),
    .io_value_14 	(u_core_top.u_wbu.u_gpr.riscv_reg[14]   ),
    .io_value_15 	(u_core_top.u_wbu.u_gpr.riscv_reg[15]   ),
    .io_value_16 	(u_core_top.u_wbu.u_gpr.riscv_reg[16]   ),
    .io_value_17 	(u_core_top.u_wbu.u_gpr.riscv_reg[17]   ),
    .io_value_18 	(u_core_top.u_wbu.u_gpr.riscv_reg[18]   ),
    .io_value_19 	(u_core_top.u_wbu.u_gpr.riscv_reg[19]   ),
    .io_value_20 	(u_core_top.u_wbu.u_gpr.riscv_reg[20]   ),
    .io_value_21 	(u_core_top.u_wbu.u_gpr.riscv_reg[21]   ),
    .io_value_22 	(u_core_top.u_wbu.u_gpr.riscv_reg[22]   ),
    .io_value_23 	(u_core_top.u_wbu.u_gpr.riscv_reg[23]   ),
    .io_value_24 	(u_core_top.u_wbu.u_gpr.riscv_reg[24]   ),
    .io_value_25 	(u_core_top.u_wbu.u_gpr.riscv_reg[25]   ),
    .io_value_26 	(u_core_top.u_wbu.u_gpr.riscv_reg[26]   ),
    .io_value_27 	(u_core_top.u_wbu.u_gpr.riscv_reg[27]   ),
    .io_value_28 	(u_core_top.u_wbu.u_gpr.riscv_reg[28]   ),
    .io_value_29 	(u_core_top.u_wbu.u_gpr.riscv_reg[29]   ),
    .io_value_30 	(u_core_top.u_wbu.u_gpr.riscv_reg[30]   ),
    .io_value_31 	(u_core_top.u_wbu.u_gpr.riscv_reg[31]   )
);

DifftestCSRState u_DifftestCSRState(
    .io_privilegeMode 	({{62{1'b0}},u_core_top.u_wbu.u_csr.current_priv_status}),
    .io_mstatus       	(u_core_top.u_wbu.u_csr.mstatus                         ),
    .io_sstatus       	(u_core_top.u_wbu.u_csr.sstatus                         ),
    .io_mepc          	(u_core_top.u_wbu.u_csr.mepc                            ),
    .io_sepc          	(u_core_top.u_wbu.u_csr.sepc                            ),
    .io_mtval         	(u_core_top.u_wbu.u_csr.mtval                           ),
    .io_stval         	(u_core_top.u_wbu.u_csr.stval                           ),
    .io_mtvec         	(u_core_top.u_wbu.u_csr.mtvec                           ),
    .io_stvec         	(u_core_top.u_wbu.u_csr.stvec                           ),
    .io_mcause        	(u_core_top.u_wbu.u_csr.mcause                          ),
    .io_scause        	(u_core_top.u_wbu.u_csr.scause                          ),
    .io_satp          	(u_core_top.u_wbu.u_csr.satp                            ),
    .io_mip           	(u_core_top.u_wbu.u_csr.mip                             ),
    .io_mie           	(u_core_top.u_wbu.u_csr.mie                             ),
    .io_mscratch      	(u_core_top.u_wbu.u_csr.mscratch                        ),
    .io_sscratch      	(u_core_top.u_wbu.u_csr.sscratch                        ),
    .io_mideleg       	(u_core_top.u_wbu.u_csr.mideleg                         ),
    .io_medeleg       	(u_core_top.u_wbu.u_csr.medeleg                         )
);


    // input                   LS_WB_reg_ls_valid,
    // input  [63:0]           LS_WB_reg_PC,
    // input  [63:0]           LS_WB_reg_next_PC,
    // input  [31:0]           LS_WB_reg_inst,
    // //trap:
    // input                   LS_WB_reg_trap_valid,
    // input                   LS_WB_reg_mret_valid,
    // input                   LS_WB_reg_sret_valid,
    // input  [63:0]           LS_WB_reg_trap_cause,
    // input  [63:0]           LS_WB_reg_trap_tval,
    // //csr
    // input                   LS_WB_reg_csr_wen,
    // input                   LS_WB_reg_csr_ren,
    // input  [11:0]           LS_WB_reg_csr_addr,
    // //gpr
    // input  [4:0]            LS_WB_reg_rd,
    // input                   LS_WB_reg_dest_wen,
    // input  [63:0]           LS_WB_reg_data

DifftestInstrCommit u_DifftestInstrCommit(
    .clock      	(clk                                    ),
    .io_valid   	(u_core_top.u_wbu.LS_WB_reg_ls_valid    ),
    .io_skip    	(1'b0                                   ),
    //todo 暂不支持查询是否压缩指令
    .io_isRVC   	(1'b0    ),

    .io_rfwen   	(u_core_top.u_wbu.LS_WB_reg_dest_wen    ),
    .io_fpwen   	(1'b0                                   ),
    .io_vecwen  	(1'b0                                   ),
    .io_wpdest  	(u_core_top.u_wbu.LS_WB_reg_rd          ),
    .io_wdest   	({3'h0, u_core_top.u_wbu.LS_WB_reg_rd}  ),
    .io_pc      	(u_core_top.u_wbu.LS_WB_reg_PC          ),
    .io_instr   	(u_core_top.u_wbu.LS_WB_reg_inst        ),
    .io_robIdx  	(10'h0                                  ),
    .io_lqIdx   	(7'h0                                   ),
    .io_sqIdx   	(7'h0                                   ),
    //todo 暂不支持查询是否访存指令
    .io_isLoad  	(1'b0   ),
    .io_isStore 	(1'b0  ),

    .io_nFused  	(8'h0                                   ),
    .io_special 	(8'h0                                   ),
    .io_coreid  	(8'h0                                   ),
    .io_index   	(8'h0                                   )
);



endmodule //core_debugger_top
