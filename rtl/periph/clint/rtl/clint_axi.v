module clint_axi#(
    // Address width in bits
    parameter AXI_ADDR_W = 32,
    // ID width in bits
    parameter AXI_ID_W = 8,
    // Data width in bits
    parameter AXI_DATA_W = 32,

    parameter HART_NUM = 1
)(
    input                           clk,
    input                           rst_n,

    output [HART_NUM - 1:0]         mtip,
    output [HART_NUM - 1:0]         msip,

    input                           mst_awvalid,
    output                          mst_awready,
    input  [AXI_ADDR_W    -1:0]     mst_awaddr,
    input  [8             -1:0]     mst_awlen,
    input  [3             -1:0]     mst_awsize,
    input  [2             -1:0]     mst_awburst,
    input                           mst_awlock,
    input  [4             -1:0]     mst_awcache,
    input  [3             -1:0]     mst_awprot,
    input  [4             -1:0]     mst_awqos,
    input  [4             -1:0]     mst_awregion,
    input  [AXI_ID_W      -1:0]     mst_awid,
    input                           mst_wvalid,
    output                          mst_wready,
    input                           mst_wlast,
    input  [AXI_DATA_W    -1:0]     mst_wdata,
    input  [AXI_DATA_W/8  -1:0]     mst_wstrb,
    output                          mst_bvalid,
    input                           mst_bready,
    output [AXI_ID_W      -1:0]     mst_bid,
    output [2             -1:0]     mst_bresp,
    input                           mst_arvalid,
    output                          mst_arready,
    input  [AXI_ADDR_W    -1:0]     mst_araddr,
    input  [8             -1:0]     mst_arlen,
    input  [3             -1:0]     mst_arsize,
    input  [2             -1:0]     mst_arburst,
    input                           mst_arlock,
    input  [4             -1:0]     mst_arcache,
    input  [3             -1:0]     mst_arprot,
    input  [4             -1:0]     mst_arqos,
    input  [4             -1:0]     mst_arregion,
    input  [AXI_ID_W      -1:0]     mst_arid,
    output                          mst_rvalid,
    input                           mst_rready,
    output [AXI_ID_W      -1:0]     mst_rid,
    output [2             -1:0]     mst_rresp,
    output [AXI_DATA_W    -1:0]     mst_rdata,
    output                          mst_rlast
);

wire                        mtime_l_wen;
wire                        mtime_h_wen;
wire [HART_NUM - 1:0]       mtimecmp_l_wen;
wire [HART_NUM - 1:0]       mtimecmp_h_wen;
wire [HART_NUM - 1:0]       msip_wen;

wire [31:0]                 reg_wdata;
wire [63:0]                 mtime;
wire [64 * HART_NUM -1:0]   mtimecmp;

clint_axi2reg #(
	.AXI_ADDR_W 	( AXI_ADDR_W  ),
	.AXI_ID_W   	( AXI_ID_W    ),
	.AXI_DATA_W 	( AXI_DATA_W  ),
	.HART_NUM   	( HART_NUM    ))
u_clint_axi2reg(
	.clk          	( clk               ),
	.rst_n        	( rst_n             ),
	.mtime_l_wen    ( mtime_l_wen       ),
	.mtime_h_wen    ( mtime_h_wen       ),
	.mtimecmp_l_wen ( mtimecmp_l_wen    ),
	.mtimecmp_h_wen ( mtimecmp_h_wen    ),
	.msip_wen     	( msip_wen          ),
	.reg_wdata    	( reg_wdata         ),
	.mtime        	( mtime             ),
	.mtimecmp     	( mtimecmp          ),
	.msip         	( msip              ),
	.mst_awvalid  	( mst_awvalid       ),
	.mst_awready  	( mst_awready       ),
	.mst_awaddr   	( mst_awaddr        ),
	.mst_awlen    	( mst_awlen         ),
	.mst_awsize   	( mst_awsize        ),
	.mst_awburst  	( mst_awburst       ),
	.mst_awlock   	( mst_awlock        ),
	.mst_awcache  	( mst_awcache       ),
	.mst_awprot   	( mst_awprot        ),
	.mst_awqos    	( mst_awqos         ),
	.mst_awregion 	( mst_awregion      ),
	.mst_awid     	( mst_awid          ),
	.mst_wvalid   	( mst_wvalid        ),
	.mst_wready   	( mst_wready        ),
	.mst_wlast    	( mst_wlast         ),
	.mst_wdata    	( mst_wdata         ),
	.mst_wstrb    	( mst_wstrb         ),
	.mst_bvalid   	( mst_bvalid        ),
	.mst_bready   	( mst_bready        ),
	.mst_bid      	( mst_bid           ),
	.mst_bresp    	( mst_bresp         ),
	.mst_arvalid  	( mst_arvalid       ),
	.mst_arready  	( mst_arready       ),
	.mst_araddr   	( mst_araddr        ),
	.mst_arlen    	( mst_arlen         ),
	.mst_arsize   	( mst_arsize        ),
	.mst_arburst  	( mst_arburst       ),
	.mst_arlock   	( mst_arlock        ),
	.mst_arcache  	( mst_arcache       ),
	.mst_arprot   	( mst_arprot        ),
	.mst_arqos    	( mst_arqos         ),
	.mst_arregion 	( mst_arregion      ),
	.mst_arid     	( mst_arid          ),
	.mst_rvalid   	( mst_rvalid        ),
	.mst_rready   	( mst_rready        ),
	.mst_rid      	( mst_rid           ),
	.mst_rresp    	( mst_rresp         ),
	.mst_rdata    	( mst_rdata         ),
	.mst_rlast    	( mst_rlast         )
);

clint_core #(
    .HART_NUM 	(HART_NUM  ))
u_clint_core(
    .clk          	(clk            ),
    .rst_n        	(rst_n          ),
	.mtime_l_wen    (mtime_l_wen    ),
	.mtime_h_wen    (mtime_h_wen    ),
	.mtimecmp_l_wen (mtimecmp_l_wen ),
	.mtimecmp_h_wen (mtimecmp_h_wen ),
    .msip_wen     	(msip_wen       ),
    .reg_wdata    	(reg_wdata      ),
    .mtime        	(mtime          ),
    .mtimecmp     	(mtimecmp       ),
    .mtip         	(mtip           ),
    .msip         	(msip           )
);


endmodule //clint_axi
