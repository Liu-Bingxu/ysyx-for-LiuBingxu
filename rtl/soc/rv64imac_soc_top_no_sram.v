`include "define.v"
module rv64imac_soc_top_no_sram#(
    // Address width in bits
    parameter AXI_ADDR_W = 64,
    // ID width in bits
    parameter AXI_ID_W = 8,
    // Data width in bits
    parameter AXI_DATA_W = 64,
    // USER fields width in bits
    parameter AXI_AUSER_W = 1,
    parameter AXI_WUSER_W = 1,
    parameter AXI_BUSER_W = 1,
    parameter AXI_RUSER_W = 1,

    parameter MST3_CDC = 0,
    parameter MST3_OSTDREQ_NUM = 4,
    parameter MST3_OSTDREQ_SIZE = 1,
    parameter MST3_PRIORITY = 0,
    parameter [3:0] MST3_ROUTES = 4'b1_1_1_1,
    parameter [AXI_ID_W-1:0] MST3_ID_MASK = 'h40,
    parameter MST3_RW = 0,

    parameter SLV1_CDC = 0,
    parameter SLV1_START_ADDR = 64'h100,
    parameter SLV1_END_ADDR = 64'hff,
    parameter SLV1_OSTDREQ_NUM = 4,
    parameter SLV1_OSTDREQ_SIZE = 1,
    parameter SLV1_KEEP_BASE_ADDR = 0,

    parameter SLV2_CDC = 0,
    parameter SLV2_START_ADDR = 64'h100,
    parameter SLV2_END_ADDR = 64'hff,
    parameter SLV2_OSTDREQ_NUM = 4,
    parameter SLV2_OSTDREQ_SIZE = 1,
    parameter SLV2_KEEP_BASE_ADDR = 0,

    parameter SLV3_CDC = 0,
    parameter SLV3_START_ADDR = 64'h100,
    parameter SLV3_END_ADDR = 64'hff,
    parameter SLV3_OSTDREQ_NUM = 4,
    parameter SLV3_OSTDREQ_SIZE = 1,
    parameter SLV3_KEEP_BASE_ADDR = 0
)(
    input                             clock,
    input                             rst_n,
    output                            arst_n,

    input 		                      tck,
    input		                      tms,
    input		                      tdi,
    output		                      tdo,

    input                             stip_asyn,
    input                             seip_asyn,
    input                             ssip_asyn,
    input                             mtip_asyn,
    input                             meip_asyn,
    input                             msip_asyn,

    input  wire                       slv3_aclk,
    input  wire                       slv3_aresetn,
    input  wire                       slv3_awvalid,
    output wire                       slv3_awready,
    input  wire  [AXI_ADDR_W    -1:0] slv3_awaddr,
    input  wire  [8             -1:0] slv3_awlen,
    input  wire  [3             -1:0] slv3_awsize,
    input  wire  [2             -1:0] slv3_awburst,
    input  wire                       slv3_awlock,
    input  wire  [4             -1:0] slv3_awcache,
    input  wire  [3             -1:0] slv3_awprot,
    input  wire  [4             -1:0] slv3_awqos,
    input  wire  [4             -1:0] slv3_awregion,
    input  wire  [AXI_ID_W      -1:0] slv3_awid,
    input  wire                       slv3_wvalid,
    output wire                       slv3_wready,
    input  wire                       slv3_wlast,
    input  wire  [AXI_DATA_W    -1:0] slv3_wdata,
    input  wire  [AXI_DATA_W/8  -1:0] slv3_wstrb,
    output wire                       slv3_bvalid,
    input  wire                       slv3_bready,
    output wire  [AXI_ID_W      -1:0] slv3_bid,
    output wire  [2             -1:0] slv3_bresp,
    input  wire                       slv3_arvalid,
    output wire                       slv3_arready,
    input  wire  [AXI_ADDR_W    -1:0] slv3_araddr,
    input  wire  [8             -1:0] slv3_arlen,
    input  wire  [3             -1:0] slv3_arsize,
    input  wire  [2             -1:0] slv3_arburst,
    input  wire                       slv3_arlock,
    input  wire  [4             -1:0] slv3_arcache,
    input  wire  [3             -1:0] slv3_arprot,
    input  wire  [4             -1:0] slv3_arqos,
    input  wire  [4             -1:0] slv3_arregion,
    input  wire  [AXI_ID_W      -1:0] slv3_arid,
    output wire                       slv3_rvalid,
    input  wire                       slv3_rready,
    output wire  [AXI_ID_W      -1:0] slv3_rid,
    output wire  [2             -1:0] slv3_rresp,
    output wire  [AXI_DATA_W    -1:0] slv3_rdata,
    output wire                       slv3_rlast,

    input  wire                       mst1_aclk,
    input  wire                       mst1_aresetn,
    output wire                       mst1_awvalid,
    input  wire                       mst1_awready,
    output wire  [AXI_ADDR_W    -1:0] mst1_awaddr,
    output wire  [8             -1:0] mst1_awlen,
    output wire  [3             -1:0] mst1_awsize,
    output wire  [2             -1:0] mst1_awburst,
    output wire                       mst1_awlock,
    output wire  [4             -1:0] mst1_awcache,
    output wire  [3             -1:0] mst1_awprot,
    output wire  [4             -1:0] mst1_awqos,
    output wire  [4             -1:0] mst1_awregion,
    output wire  [AXI_ID_W      -1:0] mst1_awid,
    output wire                       mst1_wvalid,
    input  wire                       mst1_wready,
    output wire                       mst1_wlast,
    output wire  [AXI_DATA_W    -1:0] mst1_wdata,
    output wire  [AXI_DATA_W/8  -1:0] mst1_wstrb,
    input  wire                       mst1_bvalid,
    output wire                       mst1_bready,
    input  wire  [AXI_ID_W      -1:0] mst1_bid,
    input  wire  [2             -1:0] mst1_bresp,
    output wire                       mst1_arvalid,
    input  wire                       mst1_arready,
    output wire  [AXI_ADDR_W    -1:0] mst1_araddr,
    output wire  [8             -1:0] mst1_arlen,
    output wire  [3             -1:0] mst1_arsize,
    output wire  [2             -1:0] mst1_arburst,
    output wire                       mst1_arlock,
    output wire  [4             -1:0] mst1_arcache,
    output wire  [3             -1:0] mst1_arprot,
    output wire  [4             -1:0] mst1_arqos,
    output wire  [4             -1:0] mst1_arregion,
    output wire  [AXI_ID_W      -1:0] mst1_arid,
    input  wire                       mst1_rvalid,
    output wire                       mst1_rready,
    input  wire  [AXI_ID_W      -1:0] mst1_rid,
    input  wire  [2             -1:0] mst1_rresp,
    input  wire  [AXI_DATA_W    -1:0] mst1_rdata,
    input  wire                       mst1_rlast,

    input  wire                       mst2_aclk,
    input  wire                       mst2_aresetn,
    output wire                       mst2_awvalid,
    input  wire                       mst2_awready,
    output wire  [AXI_ADDR_W    -1:0] mst2_awaddr,
    output wire  [8             -1:0] mst2_awlen,
    output wire  [3             -1:0] mst2_awsize,
    output wire  [2             -1:0] mst2_awburst,
    output wire                       mst2_awlock,
    output wire  [4             -1:0] mst2_awcache,
    output wire  [3             -1:0] mst2_awprot,
    output wire  [4             -1:0] mst2_awqos,
    output wire  [4             -1:0] mst2_awregion,
    output wire  [AXI_ID_W      -1:0] mst2_awid,
    output wire                       mst2_wvalid,
    input  wire                       mst2_wready,
    output wire                       mst2_wlast,
    output wire  [AXI_DATA_W    -1:0] mst2_wdata,
    output wire  [AXI_DATA_W/8  -1:0] mst2_wstrb,
    input  wire                       mst2_bvalid,
    output wire                       mst2_bready,
    input  wire  [AXI_ID_W      -1:0] mst2_bid,
    input  wire  [2             -1:0] mst2_bresp,
    output wire                       mst2_arvalid,
    input  wire                       mst2_arready,
    output wire  [AXI_ADDR_W    -1:0] mst2_araddr,
    output wire  [8             -1:0] mst2_arlen,
    output wire  [3             -1:0] mst2_arsize,
    output wire  [2             -1:0] mst2_arburst,
    output wire                       mst2_arlock,
    output wire  [4             -1:0] mst2_arcache,
    output wire  [3             -1:0] mst2_arprot,
    output wire  [4             -1:0] mst2_arqos,
    output wire  [4             -1:0] mst2_arregion,
    output wire  [AXI_ID_W      -1:0] mst2_arid,
    input  wire                       mst2_rvalid,
    output wire                       mst2_rready,
    input  wire  [AXI_ID_W      -1:0] mst2_rid,
    input  wire  [2             -1:0] mst2_rresp,
    input  wire  [AXI_DATA_W    -1:0] mst2_rdata,
    input  wire                       mst2_rlast,

    input  wire                       mst3_aclk,
    input  wire                       mst3_aresetn,
    output wire                       mst3_awvalid,
    input  wire                       mst3_awready,
    output wire  [AXI_ADDR_W    -1:0] mst3_awaddr,
    output wire  [8             -1:0] mst3_awlen,
    output wire  [3             -1:0] mst3_awsize,
    output wire  [2             -1:0] mst3_awburst,
    output wire                       mst3_awlock,
    output wire  [4             -1:0] mst3_awcache,
    output wire  [3             -1:0] mst3_awprot,
    output wire  [4             -1:0] mst3_awqos,
    output wire  [4             -1:0] mst3_awregion,
    output wire  [AXI_ID_W      -1:0] mst3_awid,
    output wire                       mst3_wvalid,
    input  wire                       mst3_wready,
    output wire                       mst3_wlast,
    output wire  [AXI_DATA_W    -1:0] mst3_wdata,
    output wire  [AXI_DATA_W/8  -1:0] mst3_wstrb,
    input  wire                       mst3_bvalid,
    output wire                       mst3_bready,
    input  wire  [AXI_ID_W      -1:0] mst3_bid,
    input  wire  [2             -1:0] mst3_bresp,
    output wire                       mst3_arvalid,
    input  wire                       mst3_arready,
    output wire  [AXI_ADDR_W    -1:0] mst3_araddr,
    output wire  [8             -1:0] mst3_arlen,
    output wire  [3             -1:0] mst3_arsize,
    output wire  [2             -1:0] mst3_arburst,
    output wire                       mst3_arlock,
    output wire  [4             -1:0] mst3_arcache,
    output wire  [3             -1:0] mst3_arprot,
    output wire  [4             -1:0] mst3_arqos,
    output wire  [4             -1:0] mst3_arregion,
    output wire  [AXI_ID_W      -1:0] mst3_arid,
    output wire  [AXI_AUSER_W   -1:0] mst3_aruser,
    input  wire                       mst3_rvalid,
    output wire                       mst3_rready,
    input  wire  [AXI_ID_W      -1:0] mst3_rid,
    input  wire  [2             -1:0] mst3_rresp,
    input  wire  [AXI_DATA_W    -1:0] mst3_rdata,
    input  wire                       mst3_rlast
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

assign arst_n = core_rst_n;

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

    .MST3_CDC            	(MST3_CDC           ),
    .MST3_OSTDREQ_NUM    	(MST3_OSTDREQ_NUM   ),
    .MST3_OSTDREQ_SIZE   	(MST3_OSTDREQ_SIZE  ),
    .MST3_PRIORITY       	(MST3_PRIORITY      ),
    .MST3_ROUTES         	(MST3_ROUTES        ),
    .MST3_ID_MASK        	(MST3_ID_MASK       ),
    .MST3_RW             	(MST3_RW            ),

    .SLV0_CDC            	(1        ),
    .SLV0_START_ADDR     	(64'h0000_0000    ),
    .SLV0_END_ADDR       	(64'h0000_0fff    ),
    .SLV0_OSTDREQ_NUM    	(4        ),
    .SLV0_OSTDREQ_SIZE   	(1        ),
    .SLV0_KEEP_BASE_ADDR 	(1        ),

    .SLV1_CDC            	(0        ),
    .SLV1_START_ADDR     	(RAM_START_ADDR    ),
    .SLV1_END_ADDR       	(RAM_END_ADDR      ),
    .SLV1_OSTDREQ_NUM    	(4        ),
    .SLV1_OSTDREQ_SIZE   	(1        ),
    .SLV1_KEEP_BASE_ADDR 	(1        ),

    .SLV2_CDC            	(SLV2_CDC               ),
    .SLV2_START_ADDR     	(SLV2_START_ADDR        ),
    .SLV2_END_ADDR       	(SLV2_END_ADDR          ),
    .SLV2_OSTDREQ_NUM    	(SLV2_OSTDREQ_NUM       ),
    .SLV2_OSTDREQ_SIZE   	(SLV2_OSTDREQ_SIZE      ),
    .SLV2_KEEP_BASE_ADDR 	(SLV2_KEEP_BASE_ADDR    ),

    .SLV3_CDC            	(SLV3_CDC               ),
    .SLV3_START_ADDR     	(SLV3_START_ADDR        ),
    .SLV3_END_ADDR       	(SLV3_END_ADDR          ),
    .SLV3_OSTDREQ_NUM    	(SLV3_OSTDREQ_NUM       ),
    .SLV3_OSTDREQ_SIZE   	(SLV3_OSTDREQ_SIZE      ),
    .SLV3_KEEP_BASE_ADDR 	(SLV3_KEEP_BASE_ADDR    ))
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

    .slv3_aclk     	(slv3_aclk      ),
    .slv3_aresetn  	(slv3_aresetn   ),
    .slv3_srst     	(1'b0           ),
    .slv3_awvalid  	(slv3_awvalid   ),
    .slv3_awready  	(slv3_awready   ),
    .slv3_awaddr   	(slv3_awaddr    ),
    .slv3_awlen    	(slv3_awlen     ),
    .slv3_awsize   	(slv3_awsize    ),
    .slv3_awburst  	(slv3_awburst   ),
    .slv3_awlock   	(slv3_awlock    ),
    .slv3_awcache  	(slv3_awcache   ),
    .slv3_awprot   	(slv3_awprot    ),
    .slv3_awqos    	(slv3_awqos     ),
    .slv3_awregion 	(slv3_awregion  ),
    .slv3_awid     	(slv3_awid      ),
    .slv3_awuser   	(1'b0           ),
    .slv3_wvalid   	(slv3_wvalid    ),
    .slv3_wready   	(slv3_wready    ),
    .slv3_wlast    	(slv3_wlast     ),
    .slv3_wdata    	(slv3_wdata     ),
    .slv3_wstrb    	(slv3_wstrb     ),
    .slv3_wuser    	(1'b0           ),
    .slv3_bvalid   	(slv3_bvalid    ),
    .slv3_bready   	(slv3_bready    ),
    .slv3_bid      	(slv3_bid       ),
    .slv3_bresp    	(slv3_bresp     ),
    .slv3_buser    	(                ),
    .slv3_arvalid  	(slv3_arvalid   ),
    .slv3_arready  	(slv3_arready   ),
    .slv3_araddr   	(slv3_araddr    ),
    .slv3_arlen    	(slv3_arlen     ),
    .slv3_arsize   	(slv3_arsize    ),
    .slv3_arburst  	(slv3_arburst   ),
    .slv3_arlock   	(slv3_arlock    ),
    .slv3_arcache  	(slv3_arcache   ),
    .slv3_arprot   	(slv3_arprot    ),
    .slv3_arqos    	(slv3_arqos     ),
    .slv3_arregion 	(slv3_arregion  ),
    .slv3_arid     	(slv3_arid      ),
    .slv3_aruser   	(1'b0           ),
    .slv3_rvalid   	(slv3_rvalid    ),
    .slv3_rready   	(slv3_rready    ),
    .slv3_rid      	(slv3_rid       ),
    .slv3_rresp    	(slv3_rresp     ),
    .slv3_rdata    	(slv3_rdata     ),
    .slv3_rlast    	(slv3_rlast     ),
    .slv3_ruser    	(                ),

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

    .mst2_aclk     	(mst2_aclk      ),
    .mst2_aresetn  	(mst2_aresetn   ),
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
    .mst2_awuser   	(               ),
    .mst2_wvalid   	(mst2_wvalid    ),
    .mst2_wready   	(mst2_wready    ),
    .mst2_wlast    	(mst2_wlast     ),
    .mst2_wdata    	(mst2_wdata     ),
    .mst2_wstrb    	(mst2_wstrb     ),
    .mst2_wuser    	(                ),
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
    .mst2_aruser   	(               ),
    .mst2_rvalid   	(mst2_rvalid    ),
    .mst2_rready   	(mst2_rready    ),
    .mst2_rid      	(mst2_rid       ),
    .mst2_rresp    	(mst2_rresp     ),
    .mst2_rdata    	(mst2_rdata     ),
    .mst2_rlast    	(mst2_rlast     ),
    .mst2_ruser    	(1'b0           ),

    .mst3_aclk     	(mst3_aclk      ),
    .mst3_aresetn  	(mst3_aresetn   ),
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
    .mst3_awuser   	(               ),
    .mst3_wvalid   	(mst3_wvalid    ),
    .mst3_wready   	(mst3_wready    ),
    .mst3_wlast    	(mst3_wlast     ),
    .mst3_wdata    	(mst3_wdata     ),
    .mst3_wstrb    	(mst3_wstrb     ),
    .mst3_wuser    	(                ),
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
    .mst3_aruser   	(               ),
    .mst3_rvalid   	(mst3_rvalid    ),
    .mst3_rready   	(mst3_rready    ),
    .mst3_rid      	(mst3_rid       ),
    .mst3_rresp    	(mst3_rresp     ),
    .mst3_rdata    	(mst3_rdata     ),
    .mst3_rlast    	(mst3_rlast     ),
    .mst3_ruser    	(1'b0           )
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

endmodule //rv64imac_soc_top_no_sram
