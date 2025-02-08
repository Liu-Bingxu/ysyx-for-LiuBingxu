module dummy_axi_slv#(
    // Address width in bits
    parameter AXI_ADDR_W = 64,
    // ID width in bits
    parameter AXI_ID_W = 8,
    // Data width in bits
    parameter AXI_DATA_W = 64
) (
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

assign mst_awready = 1'b0;
assign mst_wready  = 1'b0;
assign mst_bvalid  = 1'b0;
assign mst_bid     = {AXI_ID_W{1'b0}};
assign mst_bresp   = 2'h0;
assign mst_arready = 1'b0;
assign mst_rvalid  = 1'b0;
assign mst_rid     = {AXI_ID_W{1'b0}};
assign mst_rresp   = 2'h0;
assign mst_rdata   = {AXI_DATA_W{1'b0}};
assign mst_rlast   = 1'b0;

endmodule //dummy_axi_slv
