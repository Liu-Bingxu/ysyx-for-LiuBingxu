module dm_top#(
    parameter ABITS = 7,
    parameter AXI_ID_SB = 3,

    // Address width in bits
    parameter AXI_ADDR_W = 64,
    // ID width in bits
    parameter AXI_ID_W = 8,
    // Data width in bits
    parameter AXI_DATA_W = 64
)(
    input                           dm_clk,
    input                           dm_rst_n,

    input                           dm_core_rst_n,

    output                          halt_req,
    output                          hartreset,
    output                          ndmreset,

    input 				            tck,
    input				            trst_n,
    input				            tms,
    input				            tdi,
    output	   			            tdo,

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
    input                           slv_rlast,

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

// output declaration of module dm
wire dm2dtm_wen;
wire [ABITS+33:0] dm2dtm_data_in;
wire dtm2dm_ren;

// output declaration of module dtm
wire dtm2dm_wen;
wire [ABITS+33:0] dtm2dm_data_in;
wire dm2dtm_ren;

// output declaration of module dtm2dm async_fifo_my
wire dtm2dm_full;
wire dtm2dm_empty;
wire [ABITS+33:0] dtm2dm_data_out;

// output declaration of module dm2dtm async_fifo_my
wire dm2dtm_full;
wire dm2dtm_empty;
wire [ABITS+33:0] dm2dtm_data_out;

dm #(
    .ABITS        	(ABITS      ),
    .READ_THROUGH 	("TRUE"     ),
    .AXI_ID_SB    	(AXI_ID_SB  ),
    .AXI_ADDR_W   	(AXI_ADDR_W ),
    .AXI_ID_W     	(AXI_ID_W   ),
    .AXI_DATA_W   	(AXI_DATA_W ))
u_dm(
    .dm_clk          	(dm_clk           ),
    .dm_rst_n        	(dm_rst_n         ),
    .dm_core_rst_n   	(dm_core_rst_n    ),
    .halt_req        	(halt_req         ),
    .hartreset       	(hartreset        ),
    .ndmreset        	(ndmreset         ),
    .dm2dtm_full     	(dm2dtm_full      ),
    .dm2dtm_wen      	(dm2dtm_wen       ),
    .dm2dtm_data_in  	(dm2dtm_data_in   ),
    .dtm2dm_empty    	(dtm2dm_empty     ),
    .dtm2dm_ren      	(dtm2dm_ren       ),
    .dtm2dm_data_out 	(dtm2dm_data_out  ),
    .slv_awvalid     	(slv_awvalid      ),
    .slv_awready     	(slv_awready      ),
    .slv_awaddr      	(slv_awaddr       ),
    .slv_awlen       	(slv_awlen        ),
    .slv_awsize      	(slv_awsize       ),
    .slv_awburst     	(slv_awburst      ),
    .slv_awlock      	(slv_awlock       ),
    .slv_awcache     	(slv_awcache      ),
    .slv_awprot      	(slv_awprot       ),
    .slv_awqos       	(slv_awqos        ),
    .slv_awregion    	(slv_awregion     ),
    .slv_awid        	(slv_awid         ),
    .slv_wvalid      	(slv_wvalid       ),
    .slv_wready      	(slv_wready       ),
    .slv_wlast       	(slv_wlast        ),
    .slv_wdata       	(slv_wdata        ),
    .slv_wstrb       	(slv_wstrb        ),
    .slv_bvalid      	(slv_bvalid       ),
    .slv_bready      	(slv_bready       ),
    .slv_bid         	(slv_bid          ),
    .slv_bresp       	(slv_bresp        ),
    .slv_arvalid     	(slv_arvalid      ),
    .slv_arready     	(slv_arready      ),
    .slv_araddr      	(slv_araddr       ),
    .slv_arlen       	(slv_arlen        ),
    .slv_arsize      	(slv_arsize       ),
    .slv_arburst     	(slv_arburst      ),
    .slv_arlock      	(slv_arlock       ),
    .slv_arcache     	(slv_arcache      ),
    .slv_arprot      	(slv_arprot       ),
    .slv_arqos       	(slv_arqos        ),
    .slv_arregion    	(slv_arregion     ),
    .slv_arid        	(slv_arid         ),
    .slv_rvalid      	(slv_rvalid       ),
    .slv_rready      	(slv_rready       ),
    .slv_rid         	(slv_rid          ),
    .slv_rresp       	(slv_rresp        ),
    .slv_rdata       	(slv_rdata        ),
    .slv_rlast       	(slv_rlast        ),
    .mst_awvalid     	(mst_awvalid      ),
    .mst_awready     	(mst_awready      ),
    .mst_awaddr      	(mst_awaddr       ),
    .mst_awlen       	(mst_awlen        ),
    .mst_awsize      	(mst_awsize       ),
    .mst_awburst     	(mst_awburst      ),
    .mst_awlock      	(mst_awlock       ),
    .mst_awcache     	(mst_awcache      ),
    .mst_awprot      	(mst_awprot       ),
    .mst_awqos       	(mst_awqos        ),
    .mst_awregion    	(mst_awregion     ),
    .mst_awid        	(mst_awid         ),
    .mst_wvalid      	(mst_wvalid       ),
    .mst_wready      	(mst_wready       ),
    .mst_wlast       	(mst_wlast        ),
    .mst_wdata       	(mst_wdata        ),
    .mst_wstrb       	(mst_wstrb        ),
    .mst_bvalid      	(mst_bvalid       ),
    .mst_bready      	(mst_bready       ),
    .mst_bid         	(mst_bid          ),
    .mst_bresp       	(mst_bresp        ),
    .mst_arvalid     	(mst_arvalid      ),
    .mst_arready     	(mst_arready      ),
    .mst_araddr      	(mst_araddr       ),
    .mst_arlen       	(mst_arlen        ),
    .mst_arsize      	(mst_arsize       ),
    .mst_arburst     	(mst_arburst      ),
    .mst_arlock      	(mst_arlock       ),
    .mst_arcache     	(mst_arcache      ),
    .mst_arprot      	(mst_arprot       ),
    .mst_arqos       	(mst_arqos        ),
    .mst_arregion    	(mst_arregion     ),
    .mst_arid        	(mst_arid         ),
    .mst_rvalid      	(mst_rvalid       ),
    .mst_rready      	(mst_rready       ),
    .mst_rid         	(mst_rid          ),
    .mst_rresp       	(mst_rresp        ),
    .mst_rdata       	(mst_rdata        ),
    .mst_rlast       	(mst_rlast        )
);

dtm #(
    .ABITS        	(ABITS   ),
    .READ_THROUGH 	("TRUE"  ))
u_dtm(
    .tck             	(tck              ),
    .trst_n          	(trst_n           ),
    .tms             	(tms              ),
    .tdi             	(tdi              ),
    .tdo             	(tdo              ),
    .dtm2dm_full     	(dtm2dm_full      ),
    .dtm2dm_wen      	(dtm2dm_wen       ),
    .dtm2dm_data_in  	(dtm2dm_data_in   ),
    .dm2dtm_empty    	(dm2dtm_empty     ),
    .dm2dtm_ren      	(dm2dtm_ren       ),
    .dm2dtm_data_out 	(dm2dtm_data_out  )
);

async_fifo_my #(
    .DATA_LEN     	(ABITS+34),
    .ADDR_LEN     	(1       ),
    .READ_THROUGH 	("TRUE"  ))
u_dtm2dm_async_fifo_my(
    .clk_w    	(tck            ),
    .rstn_w   	(trst_n         ),
    .full     	(dtm2dm_full    ),
    .wen      	(dtm2dm_wen     ),
    .data_in  	(dtm2dm_data_in ),
    .clk_r    	(dm_clk         ),
    .rstn_r   	(dm_rst_n       ),
    .empty    	(dtm2dm_empty   ),
    .ren      	(dtm2dm_ren     ),
    .data_out 	(dtm2dm_data_out)
);

async_fifo_my #(
    .DATA_LEN     	(ABITS+34),
    .ADDR_LEN     	(1       ),
    .READ_THROUGH 	("TRUE"  ))
u_dm2dtm_async_fifo_my(
    .clk_w    	(dm_clk         ),
    .rstn_w   	(dm_rst_n       ),
    .full     	(dm2dtm_full    ),
    .wen      	(dm2dtm_wen     ),
    .data_in  	(dm2dtm_data_in ),
    .clk_r    	(tck            ),
    .rstn_r   	(trst_n         ),
    .empty    	(dm2dtm_empty   ),
    .ren      	(dm2dtm_ren     ),
    .data_out 	(dm2dtm_data_out)
);


endmodule //dm_top
