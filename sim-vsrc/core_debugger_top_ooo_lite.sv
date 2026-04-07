`include "macro-func-define.sv"
module core_debugger_top_ooo_lite
import core_setting_pkg::*;
import frontend_pkg::*;
import rob_pkg::*;
import mem_pkg::*;
(
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

// Address width in bits
localparam AXI_ADDR_W = 64;
// ID width in bits
localparam AXI_ID_W = 8;
// Data width in bits
localparam AXI_DATA_W = 64;

wire clk = clock;

logic                       icache_arvalid;
logic                       icache_arready;
logic [AXI_ADDR_W    -1:0]  icache_araddr;
logic [8             -1:0]  icache_arlen;
logic [3             -1:0]  icache_arsize;
logic [2             -1:0]  icache_arburst;
logic [AXI_ID_W      -1:0]  icache_arid;
logic                       icache_rvalid;
logic                       icache_rready;
logic  [AXI_ID_W      -1:0] icache_rid;
logic  [2             -1:0] icache_rresp;
logic  [AXI_DATA_W    -1:0] icache_rdata;
logic                       icache_rlast;

logic                       dcache_arvalid;
logic                       dcache_arready;
logic [AXI_ADDR_W    -1:0]  dcache_araddr;
logic [8             -1:0]  dcache_arlen;
logic [3             -1:0]  dcache_arsize;
logic [2             -1:0]  dcache_arburst;
logic                       dcache_arlock;
logic [AXI_ID_W      -1:0]  dcache_arid;
logic                       dcache_rvalid;
logic                       dcache_rready;
logic [AXI_ID_W      -1:0]  dcache_rid;
logic [2             -1:0]  dcache_rresp;
logic [AXI_DATA_W    -1:0]  dcache_rdata;
logic                       dcache_rlast;
logic                       dcache_awvalid;
logic                       dcache_awready;
logic [AXI_ADDR_W    -1:0]  dcache_awaddr;
logic [8             -1:0]  dcache_awlen;
logic [3             -1:0]  dcache_awsize;
logic [2             -1:0]  dcache_awburst;
logic                       dcache_awlock;
logic [AXI_ID_W      -1:0]  dcache_awid;
logic                       dcache_wvalid;
logic                       dcache_wready;
logic                       dcache_wlast;
logic [AXI_DATA_W    -1:0]  dcache_wdata;
logic [AXI_DATA_W/8  -1:0]  dcache_wstrb;
logic                       dcache_bvalid;
logic                       dcache_bready;
logic [AXI_ID_W      -1:0]  dcache_bid;
logic [2             -1:0]  dcache_bresp;

logic                       store_uncache_awvalid;
logic                       store_uncache_awready;
logic  [2:0]                store_uncache_awsize;
logic  [63:0]               store_uncache_awaddr;
logic                       store_uncache_wvalid;
logic                       store_uncache_wready;
logic [7:0]                 store_uncache_wstrb;
logic [63:0]                store_uncache_wdata;
logic                       store_uncache_bvalid;
logic                       store_uncache_bready;
logic [1:0]                 store_uncache_bresp;
logic                       load_uncache_arvalid;
logic                       load_uncache_arready;
logic [2:0]                 load_uncache_arsize;
logic [63:0]                load_uncache_araddr;
logic                       load_uncache_rvalid;
logic                       load_uncache_rready;
logic [1:0]                 load_uncache_rresp;
logic [63:0]                load_uncache_rdata;

wire                    halt_req = 1'b0;

reg core_rst_n_r;
reg core_rst_n;

always @(posedge clk or negedge rst_n) begin
    if(!rst_n)begin
        core_rst_n_r <= 1'b0;
        core_rst_n   <= 1'b0;
    end
    else begin
        core_rst_n_r <= 1'b1;
        core_rst_n   <= core_rst_n_r;
    end
end

core_ooo_top #(
	.AXI_ID_SB_I  	( 8'h10          ),
	.AXI_ID_SB_D  	( 8'h20          ),
	.AXI_ADDR_W   	( AXI_ADDR_W     ),
	.AXI_ID_W     	( AXI_ID_W       ),
	.AXI_DATA_W   	( AXI_DATA_W     ),
	.ICACHE_WAY   	( 2              ),
	.ICACHE_GROUP 	( 2              ),
	.DCACHE_WAY   	( 2              ),
	.DCACHE_GROUP 	( 2              ),
	.MMU_WAY      	( 2              ),
	.MMU_GROUP    	( 1              ),
	.PMEM_START   	( 64'h8000_0000  ),
	.PMEM_END     	( 64'h9fff_ffff  ))
u_core_ooo_top(
	.clk             	            ( clk                           ),
	.rst_n           	            ( rst_n                         ),
	.stip_asyn       	            ( stip_asyn                     ),
	.seip_asyn       	            ( seip_asyn                     ),
	.ssip_asyn       	            ( ssip_asyn                     ),
	.mtip_asyn       	            ( mtip_asyn                     ),
	.meip_asyn       	            ( meip_asyn                     ),
	.msip_asyn       	            ( msip_asyn                     ),
	.halt_req        	            ( halt_req                      ),

	.icache_arvalid  	            ( icache_arvalid                ),
	.icache_arready  	            ( icache_arready                ),
	.icache_araddr   	            ( icache_araddr                 ),
	.icache_arlen    	            ( icache_arlen                  ),
	.icache_arsize   	            ( icache_arsize                 ),
	.icache_arburst  	            ( icache_arburst                ),
	.icache_arid     	            ( icache_arid                   ),
	.icache_rvalid   	            ( icache_rvalid                 ),
	.icache_rready   	            ( icache_rready                 ),
	.icache_rid      	            ( icache_rid                    ),
	.icache_rresp    	            ( icache_rresp                  ),
	.icache_rdata    	            ( icache_rdata                  ),
	.icache_rlast    	            ( icache_rlast                  ),

	.dcache_arvalid  	            ( dcache_arvalid                ),
	.dcache_arready  	            ( dcache_arready                ),
	.dcache_araddr   	            ( dcache_araddr                 ),
	.dcache_arlen    	            ( dcache_arlen                  ),
	.dcache_arsize   	            ( dcache_arsize                 ),
	.dcache_arburst  	            ( dcache_arburst                ),
	.dcache_arlock   	            ( dcache_arlock                 ),
	.dcache_arid     	            ( dcache_arid                   ),
	.dcache_rvalid   	            ( dcache_rvalid                 ),
	.dcache_rready   	            ( dcache_rready                 ),
	.dcache_rid      	            ( dcache_rid                    ),
	.dcache_rresp    	            ( dcache_rresp                  ),
	.dcache_rdata    	            ( dcache_rdata                  ),
	.dcache_rlast    	            ( dcache_rlast                  ),
	.dcache_awvalid  	            ( dcache_awvalid                ),
	.dcache_awready  	            ( dcache_awready                ),
	.dcache_awaddr   	            ( dcache_awaddr                 ),
	.dcache_awlen    	            ( dcache_awlen                  ),
	.dcache_awsize   	            ( dcache_awsize                 ),
	.dcache_awburst  	            ( dcache_awburst                ),
	.dcache_awlock   	            ( dcache_awlock                 ),
	.dcache_awid     	            ( dcache_awid                   ),
	.dcache_wvalid   	            ( dcache_wvalid                 ),
	.dcache_wready   	            ( dcache_wready                 ),
	.dcache_wlast    	            ( dcache_wlast                  ),
	.dcache_wdata    	            ( dcache_wdata                  ),
	.dcache_wstrb    	            ( dcache_wstrb                  ),
	.dcache_bvalid   	            ( dcache_bvalid                 ),
	.dcache_bready   	            ( dcache_bready                 ),
	.dcache_bid      	            ( dcache_bid                    ),
	.dcache_bresp    	            ( dcache_bresp                  ),

	.store_uncache_awvalid          ( store_uncache_awvalid         ),
	.store_uncache_awready          ( store_uncache_awready         ),
	.store_uncache_awsize           ( store_uncache_awsize          ),
	.store_uncache_awaddr           ( store_uncache_awaddr          ),
	.store_uncache_wvalid           ( store_uncache_wvalid          ),
	.store_uncache_wready           ( store_uncache_wready          ),
	.store_uncache_wstrb            ( store_uncache_wstrb           ),
	.store_uncache_wdata            ( store_uncache_wdata           ),
	.store_uncache_bvalid           ( store_uncache_bvalid          ),
	.store_uncache_bready           ( store_uncache_bready          ),
	.store_uncache_bresp            ( store_uncache_bresp           ),
    .load_uncache_arvalid           ( load_uncache_arvalid          ),
    .load_uncache_arready           ( load_uncache_arready          ),
    .load_uncache_arsize            ( load_uncache_arsize           ),
    .load_uncache_araddr            ( load_uncache_araddr           ),
    .load_uncache_rvalid            ( load_uncache_rvalid           ),
    .load_uncache_rready            ( load_uncache_rready           ),
    .load_uncache_rresp             ( load_uncache_rresp            ),
    .load_uncache_rdata             ( load_uncache_rdata            )
);

sim_sram_dpic #(
    .AXI_ADDR_W 	(64  ),
    .AXI_ID_W   	(8   ),
    .AXI_DATA_W 	(64  ))
u_sim_sram_dpic(
    .aclk         	(clk                ),
    .arst_n       	(core_rst_n         ),
    .mst_awvalid  	(1'b0               ),
    .mst_awready  	(                   ),
    .mst_awaddr   	(64'h0              ),
    .mst_awlen    	(8'h0               ),
    .mst_awsize   	(3'h0               ),
    .mst_awburst  	(2'h0               ),
    .mst_awlock   	(1'h0               ),
    .mst_awcache  	(4'h0               ),
    .mst_awprot   	(3'h0               ),
    .mst_awqos    	(4'h0               ),
    .mst_awregion 	(4'h0               ),
    .mst_awid     	(8'h10              ),
    .mst_wvalid   	(1'h0               ),
    .mst_wready   	(                   ),
    .mst_wlast    	(1'h0               ),
    .mst_wdata    	(64'h0              ),
    .mst_wstrb    	(8'h0               ),
    .mst_bvalid   	(                   ),
    .mst_bready   	(1'h0               ),
    .mst_bid      	(                   ),
    .mst_bresp    	(                   ),
    .mst_arvalid  	(icache_arvalid     ),
    .mst_arready  	(icache_arready     ),
    .mst_araddr   	(icache_araddr      ),
    .mst_arlen    	(icache_arlen       ),
    .mst_arsize   	(icache_arsize      ),
    .mst_arburst  	(icache_arburst     ),
    .mst_arlock   	(1'b0               ),
    .mst_arcache  	(4'h0               ),
    .mst_arprot   	(3'h0               ),
    .mst_arqos    	(4'h0               ),
    .mst_arregion 	(4'h0               ),
    .mst_arid     	(icache_arid        ),
    .mst_rvalid   	(icache_rvalid      ),
    .mst_rready   	(icache_rready      ),
    .mst_rid      	(icache_rid         ),
    .mst_rresp    	(icache_rresp       ),
    .mst_rdata    	(icache_rdata       ),
    .mst_rlast    	(icache_rlast       )
);

sim_sram_dpic #(
    .AXI_ADDR_W 	(64  ),
    .AXI_ID_W   	(8   ),
    .AXI_DATA_W 	(64  ))
u_sim_sram_dpic_d(
    .aclk         	(clk                ),
    .arst_n       	(core_rst_n         ),
    .mst_awvalid  	(dcache_awvalid     ),
    .mst_awready  	(dcache_awready     ),
    .mst_awaddr   	(dcache_awaddr      ),
    .mst_awlen    	(dcache_awlen       ),
    .mst_awsize   	(dcache_awsize      ),
    .mst_awburst  	(dcache_awburst     ),
    .mst_awlock   	(dcache_awlock      ),
    .mst_awcache  	(4'h0               ),
    .mst_awprot   	(3'h0               ),
    .mst_awqos    	(4'h0               ),
    .mst_awregion 	(4'h0               ),
    .mst_awid     	(dcache_awid        ),
    .mst_wvalid   	(dcache_wvalid      ),
    .mst_wready   	(dcache_wready      ),
    .mst_wlast    	(dcache_wlast       ),
    .mst_wdata    	(dcache_wdata       ),
    .mst_wstrb    	(dcache_wstrb       ),
    .mst_bvalid   	(dcache_bvalid      ),
    .mst_bready   	(dcache_bready      ),
    .mst_bid      	(dcache_bid         ),
    .mst_bresp    	(dcache_bresp       ),
    .mst_arvalid  	(dcache_arvalid     ),
    .mst_arready  	(dcache_arready     ),
    .mst_araddr   	(dcache_araddr      ),
    .mst_arlen    	(dcache_arlen       ),
    .mst_arsize   	(dcache_arsize      ),
    .mst_arburst  	(dcache_arburst     ),
    .mst_arlock   	(dcache_arlock      ),
    .mst_arcache  	(4'h0               ),
    .mst_arprot   	(3'h0               ),
    .mst_arqos    	(4'h0               ),
    .mst_arregion 	(4'h0               ),
    .mst_arid     	(dcache_arid        ),
    .mst_rvalid   	(dcache_rvalid      ),
    .mst_rready   	(dcache_rready      ),
    .mst_rid      	(dcache_rid         ),
    .mst_rresp    	(dcache_rresp       ),
    .mst_rdata    	(dcache_rdata       ),
    .mst_rlast    	(dcache_rlast       )
);

sim_periph_dpic #(
    .AXI_ADDR_W 	(AXI_ADDR_W  ),
    .AXI_ID_W   	(AXI_ID_W    ),
    .AXI_DATA_W 	(AXI_DATA_W  ))
u_sim_periph_dpic(
    .aclk         	(clk                    ),
    .arst_n       	(core_rst_n             ),
    .mst_awvalid  	(store_uncache_awvalid  ),
    .mst_awready  	(store_uncache_awready  ),
    .mst_awaddr   	(store_uncache_awaddr   ),
    .mst_awlen    	(8'h0                   ),
    .mst_awsize   	(store_uncache_awsize   ),
    .mst_awburst  	(2'h1                   ),
    .mst_awlock   	(1'h0                   ),
    .mst_awcache  	(4'h0                   ),
    .mst_awprot   	(3'h0                   ),
    .mst_awqos    	(4'h0                   ),
    .mst_awregion 	(4'h0                   ),
    .mst_awid     	(8'h80                  ),
    .mst_wvalid   	(store_uncache_wvalid   ),
    .mst_wready   	(store_uncache_wready   ),
    .mst_wlast    	(1'h1                   ),
    .mst_wdata    	(store_uncache_wdata    ),
    .mst_wstrb    	(store_uncache_wstrb    ),
    .mst_bvalid   	(store_uncache_bvalid   ),
    .mst_bready   	(store_uncache_bready   ),
    .mst_bid      	(                       ),
    .mst_bresp    	(store_uncache_bresp    ),
    .mst_arvalid  	(load_uncache_arvalid   ),
    .mst_arready  	(load_uncache_arready   ),
    .mst_araddr   	(load_uncache_araddr    ),
    .mst_arlen    	(8'h0                   ),
    .mst_arsize   	(load_uncache_arsize    ),
    .mst_arburst  	(2'h1                   ),
    .mst_arlock   	(1'h0                   ),
    .mst_arcache  	(4'h0                   ),
    .mst_arprot   	(3'h0                   ),
    .mst_arqos    	(4'h0                   ),
    .mst_arregion 	(4'h0                   ),
    .mst_arid     	(8'h80                  ),
    .mst_rvalid   	(load_uncache_rvalid    ),
    .mst_rready   	(load_uncache_rready    ),
    .mst_rid      	(                       ),
    .mst_rresp    	(load_uncache_rresp     ),
    .mst_rdata    	(load_uncache_rdata     ),
    .mst_rlast    	(                       )
);


DifftestArchIntRegState u_DifftestArchIntRegState(
    .io_value_0  	(64'h0                                                                                                              ),
    .io_value_1  	(u_core_ooo_top.u_backend_top.u_intregfile.regfile[u_core_ooo_top.u_backend_top.u_rename_table.int_arch_rat[1 ]]    ),
    .io_value_2  	(u_core_ooo_top.u_backend_top.u_intregfile.regfile[u_core_ooo_top.u_backend_top.u_rename_table.int_arch_rat[2 ]]    ),
    .io_value_3  	(u_core_ooo_top.u_backend_top.u_intregfile.regfile[u_core_ooo_top.u_backend_top.u_rename_table.int_arch_rat[3 ]]    ),
    .io_value_4  	(u_core_ooo_top.u_backend_top.u_intregfile.regfile[u_core_ooo_top.u_backend_top.u_rename_table.int_arch_rat[4 ]]    ),
    .io_value_5  	(u_core_ooo_top.u_backend_top.u_intregfile.regfile[u_core_ooo_top.u_backend_top.u_rename_table.int_arch_rat[5 ]]    ),
    .io_value_6  	(u_core_ooo_top.u_backend_top.u_intregfile.regfile[u_core_ooo_top.u_backend_top.u_rename_table.int_arch_rat[6 ]]    ),
    .io_value_7  	(u_core_ooo_top.u_backend_top.u_intregfile.regfile[u_core_ooo_top.u_backend_top.u_rename_table.int_arch_rat[7 ]]    ),
    .io_value_8  	(u_core_ooo_top.u_backend_top.u_intregfile.regfile[u_core_ooo_top.u_backend_top.u_rename_table.int_arch_rat[8 ]]    ),
    .io_value_9  	(u_core_ooo_top.u_backend_top.u_intregfile.regfile[u_core_ooo_top.u_backend_top.u_rename_table.int_arch_rat[9 ]]    ),
    .io_value_10 	(u_core_ooo_top.u_backend_top.u_intregfile.regfile[u_core_ooo_top.u_backend_top.u_rename_table.int_arch_rat[10]]    ),
    .io_value_11 	(u_core_ooo_top.u_backend_top.u_intregfile.regfile[u_core_ooo_top.u_backend_top.u_rename_table.int_arch_rat[11]]    ),
    .io_value_12 	(u_core_ooo_top.u_backend_top.u_intregfile.regfile[u_core_ooo_top.u_backend_top.u_rename_table.int_arch_rat[12]]    ),
    .io_value_13 	(u_core_ooo_top.u_backend_top.u_intregfile.regfile[u_core_ooo_top.u_backend_top.u_rename_table.int_arch_rat[13]]    ),
    .io_value_14 	(u_core_ooo_top.u_backend_top.u_intregfile.regfile[u_core_ooo_top.u_backend_top.u_rename_table.int_arch_rat[14]]    ),
    .io_value_15 	(u_core_ooo_top.u_backend_top.u_intregfile.regfile[u_core_ooo_top.u_backend_top.u_rename_table.int_arch_rat[15]]    ),
    .io_value_16 	(u_core_ooo_top.u_backend_top.u_intregfile.regfile[u_core_ooo_top.u_backend_top.u_rename_table.int_arch_rat[16]]    ),
    .io_value_17 	(u_core_ooo_top.u_backend_top.u_intregfile.regfile[u_core_ooo_top.u_backend_top.u_rename_table.int_arch_rat[17]]    ),
    .io_value_18 	(u_core_ooo_top.u_backend_top.u_intregfile.regfile[u_core_ooo_top.u_backend_top.u_rename_table.int_arch_rat[18]]    ),
    .io_value_19 	(u_core_ooo_top.u_backend_top.u_intregfile.regfile[u_core_ooo_top.u_backend_top.u_rename_table.int_arch_rat[19]]    ),
    .io_value_20 	(u_core_ooo_top.u_backend_top.u_intregfile.regfile[u_core_ooo_top.u_backend_top.u_rename_table.int_arch_rat[20]]    ),
    .io_value_21 	(u_core_ooo_top.u_backend_top.u_intregfile.regfile[u_core_ooo_top.u_backend_top.u_rename_table.int_arch_rat[21]]    ),
    .io_value_22 	(u_core_ooo_top.u_backend_top.u_intregfile.regfile[u_core_ooo_top.u_backend_top.u_rename_table.int_arch_rat[22]]    ),
    .io_value_23 	(u_core_ooo_top.u_backend_top.u_intregfile.regfile[u_core_ooo_top.u_backend_top.u_rename_table.int_arch_rat[23]]    ),
    .io_value_24 	(u_core_ooo_top.u_backend_top.u_intregfile.regfile[u_core_ooo_top.u_backend_top.u_rename_table.int_arch_rat[24]]    ),
    .io_value_25 	(u_core_ooo_top.u_backend_top.u_intregfile.regfile[u_core_ooo_top.u_backend_top.u_rename_table.int_arch_rat[25]]    ),
    .io_value_26 	(u_core_ooo_top.u_backend_top.u_intregfile.regfile[u_core_ooo_top.u_backend_top.u_rename_table.int_arch_rat[26]]    ),
    .io_value_27 	(u_core_ooo_top.u_backend_top.u_intregfile.regfile[u_core_ooo_top.u_backend_top.u_rename_table.int_arch_rat[27]]    ),
    .io_value_28 	(u_core_ooo_top.u_backend_top.u_intregfile.regfile[u_core_ooo_top.u_backend_top.u_rename_table.int_arch_rat[28]]    ),
    .io_value_29 	(u_core_ooo_top.u_backend_top.u_intregfile.regfile[u_core_ooo_top.u_backend_top.u_rename_table.int_arch_rat[29]]    ),
    .io_value_30 	(u_core_ooo_top.u_backend_top.u_intregfile.regfile[u_core_ooo_top.u_backend_top.u_rename_table.int_arch_rat[30]]    ),
    .io_value_31 	(u_core_ooo_top.u_backend_top.u_intregfile.regfile[u_core_ooo_top.u_backend_top.u_rename_table.int_arch_rat[31]]    )
);

DifftestPerformRegState u_DifftestPerformRegState(
    .io_value_0  	(u_core_ooo_top.u_backend_top.u_csr.Performance_Monitor[2 ]   ),
    .io_value_1  	(u_core_ooo_top.u_backend_top.u_csr.minstret                  ),
    .io_value_3  	(u_core_ooo_top.u_backend_top.u_csr.Performance_Monitor[3 ]   ),
    .io_value_4  	(u_core_ooo_top.u_backend_top.u_csr.Performance_Monitor[4 ]   ),
    .io_value_5  	(u_core_ooo_top.u_backend_top.u_csr.Performance_Monitor[5 ]   ),
    .io_value_6  	(u_core_ooo_top.u_backend_top.u_csr.Performance_Monitor[6 ]   ),
    .io_value_7  	(u_core_ooo_top.u_backend_top.u_csr.Performance_Monitor[7 ]   ),
    .io_value_8  	(u_core_ooo_top.u_backend_top.u_csr.Performance_Monitor[8 ]   ),
    .io_value_9  	(u_core_ooo_top.u_backend_top.u_csr.Performance_Monitor[9 ]   ),
    .io_value_10 	(u_core_ooo_top.u_backend_top.u_csr.Performance_Monitor[10]   ),
    .io_value_11 	(u_core_ooo_top.u_backend_top.u_csr.Performance_Monitor[11]   ),
    .io_value_12 	(u_core_ooo_top.u_backend_top.u_csr.Performance_Monitor[12]   ),
    .io_value_13 	(u_core_ooo_top.u_backend_top.u_csr.Performance_Monitor[13]   ),
    .io_value_14 	(u_core_ooo_top.u_backend_top.u_csr.Performance_Monitor[14]   ),
    .io_value_15 	(u_core_ooo_top.u_backend_top.u_csr.Performance_Monitor[15]   ),
    .io_value_16 	(u_core_ooo_top.u_backend_top.u_csr.Performance_Monitor[16]   ),
    .io_value_17 	(u_core_ooo_top.u_backend_top.u_csr.Performance_Monitor[17]   ),
    .io_value_18 	(u_core_ooo_top.u_backend_top.u_csr.Performance_Monitor[18]   ),
    .io_value_19 	(u_core_ooo_top.u_backend_top.u_csr.Performance_Monitor[19]   ),
    .io_value_20 	(u_core_ooo_top.u_backend_top.u_csr.Performance_Monitor[20]   ),
    .io_value_21 	(u_core_ooo_top.u_backend_top.u_csr.Performance_Monitor[21]   ),
    .io_value_22 	(u_core_ooo_top.u_backend_top.u_csr.Performance_Monitor[22]   ),
    .io_value_23 	(u_core_ooo_top.u_backend_top.u_csr.Performance_Monitor[23]   ),
    .io_value_24 	(u_core_ooo_top.u_backend_top.u_csr.Performance_Monitor[24]   ),
    .io_value_25 	(u_core_ooo_top.u_backend_top.u_csr.Performance_Monitor[25]   ),
    .io_value_26 	(u_core_ooo_top.u_backend_top.u_csr.Performance_Monitor[26]   ),
    .io_value_27 	(u_core_ooo_top.u_backend_top.u_csr.Performance_Monitor[27]   ),
    .io_value_28 	(u_core_ooo_top.u_backend_top.u_csr.Performance_Monitor[28]   ),
    .io_value_29 	(u_core_ooo_top.u_backend_top.u_csr.Performance_Monitor[29]   ),
    .io_value_30 	(u_core_ooo_top.u_backend_top.u_csr.Performance_Monitor[30]   ),
    .io_value_31 	(u_core_ooo_top.u_backend_top.u_csr.Performance_Monitor[31]   )
);
warp u_warp();
DifftestCSRState u_DifftestCSRState(
    .io_privilegeMode 	({{62{1'b0}},u_core_ooo_top.u_backend_top.u_csr.current_priv_status}),
    .io_mstatus       	(u_core_ooo_top.u_backend_top.u_csr.mstatus                         ),
    .io_sstatus       	(u_core_ooo_top.u_backend_top.u_csr.sstatus                         ),
    .io_mepc          	(u_core_ooo_top.u_backend_top.u_csr.mepc                            ),
    .io_sepc          	(u_core_ooo_top.u_backend_top.u_csr.sepc                            ),
    .io_mtval         	(u_core_ooo_top.u_backend_top.u_csr.mtval                           ),
    .io_stval         	(u_core_ooo_top.u_backend_top.u_csr.stval                           ),
    .io_mtvec         	(u_core_ooo_top.u_backend_top.u_csr.mtvec                           ),
    .io_stvec         	(u_core_ooo_top.u_backend_top.u_csr.stvec                           ),
    .io_mcause        	(u_core_ooo_top.u_backend_top.u_csr.mcause                          ),
    .io_scause        	(u_core_ooo_top.u_backend_top.u_csr.scause                          ),
    .io_satp          	(u_core_ooo_top.u_backend_top.u_csr.satp                            ),
    .io_mip           	(u_core_ooo_top.u_backend_top.u_csr.mip                             ),
    .io_mie           	(u_core_ooo_top.u_backend_top.u_csr.mie                             ),
    .io_mscratch      	(u_core_ooo_top.u_backend_top.u_csr.mscratch                        ),
    .io_sscratch      	(u_core_ooo_top.u_backend_top.u_csr.sscratch                        ),
    .io_mideleg       	(u_core_ooo_top.u_backend_top.u_csr.mideleg                         ),
    .io_medeleg       	(u_core_ooo_top.u_backend_top.u_csr.medeleg                         )
);

logic          rob_entry_io_skip[rob_entry_num - 1 : 0];
logic [31:0]   rob_entry_inst[rob_entry_num - 1 : 0];
logic [31:0]   decode_inst[rename_width - 1 : 0];

genvar decode_index;
generate for(decode_index = 0 ; decode_index < decode_width; decode_index = decode_index + 1) begin : U_gen_decode
    FF_D_without_asyn_rst #(32) u_decode_o (clk,
        u_core_ooo_top.u_backend_top.u_DecodeUnit.ibuf_inst_o[decode_index].is_valid & 
        u_core_ooo_top.u_backend_top.u_DecodeUnit.decode_inst_ready[decode_index],
        u_core_ooo_top.u_backend_top.u_DecodeUnit.ibuf_inst_o[decode_index].inst,
        decode_inst[decode_index]);
end
endgenerate

logic [63:0]    load_paddr;
FF_D_without_asyn_rst #(64)    u_stage3_paddr_o (clk,u_core_ooo_top.u_mem_top.u_loadUnit.send_valid_stage3, u_core_ooo_top.u_mem_top.u_loadUnit.loadUnit_paddr, load_paddr);

genvar entry_index;
generate for(entry_index = 0 ; entry_index < rob_entry_num; entry_index = entry_index + 1) begin : U_gen_rob_entry
    logic       rob_entry_wen_io_skip;
    logic       rob_entry_enq_wen;
    logic       rob_entry_loadUnit_update_wen;
    logic       rob_entry_StoreQueue_update_wen;

    logic       rob_entry_nxt_io_skip;
    logic       rob_entry_enq_io_skip;
    logic       rob_entry_loadUnit_update_io_skip;
    logic       rob_entry_StoreQueue_update_io_skip;

    logic [31:0] rob_entry_nxt_inst;

    integer i;
    always_comb begin : rob_enq_comb
        rob_entry_enq_wen  = 0;
        rob_entry_nxt_inst = 0;
        for(i = 0; i < rename_width; i = i + 1)begin
            rob_entry_enq_wen  = (rob_entry_enq_wen | 
                                (u_core_ooo_top.u_backend_top.u_rob.rename_fire & 
                                u_core_ooo_top.u_backend_top.u_rob.rob_req[i] & 
                                (u_core_ooo_top.u_backend_top.u_rob.rob_ptr_enq[i] == entry_index)));
            rob_entry_nxt_inst = (rob_entry_nxt_inst     | 
                                ({32{u_core_ooo_top.u_backend_top.u_rob.rename_fire & 
                                u_core_ooo_top.u_backend_top.u_rob.rob_req[i] & 
                                (u_core_ooo_top.u_backend_top.u_rob.rob_ptr_enq[i] == entry_index)}} & 
                                decode_inst[i]));
        end
    end

    assign rob_entry_enq_io_skip                            = 1'b0;

    assign rob_entry_loadUnit_update_wen                    = u_core_ooo_top.u_backend_top.u_rob.LoadQueue_valid_o & u_core_ooo_top.u_backend_top.u_rob.LoadQueue_ready_o &
                                                            (entry_index == u_core_ooo_top.u_backend_top.u_rob.LoadQueue_rob_ptr_o) & 
                                                            (!u_core_ooo_top.u_backend_top.u_rob.rob_entry[entry_index].finish) &
                                                            ((!u_core_ooo_top.u_backend_top.u_rob.LoadQueueRAW_flush_o) | 
                                                            (entry_index != u_core_ooo_top.u_backend_top.u_rob.LoadQueueRAW_rob_ptr_o));
    assign rob_entry_loadUnit_update_io_skip                = (!`addrcache(load_paddr))                            ;

    assign rob_entry_StoreQueue_update_wen                  = u_core_ooo_top.u_backend_top.u_rob.StoreQueue_valid_o & 
                                                            u_core_ooo_top.u_backend_top.u_rob.StoreQueue_ready_o &
                                                            (entry_index == u_core_ooo_top.u_backend_top.u_rob.StoreQueue_rob_ptr_o);
    assign rob_entry_StoreQueue_update_io_skip              = u_core_ooo_top.u_mem_top.StoreQueue2Uncache_valid                         ;

    assign rob_entry_wen_io_skip =  (rob_entry_enq_wen                      ) |
                                    (rob_entry_loadUnit_update_wen          ) |
                                    (rob_entry_StoreQueue_update_wen        );
    assign rob_entry_nxt_io_skip =  ((rob_entry_enq_wen              ) & rob_entry_enq_io_skip                      ) |
                                    ((rob_entry_loadUnit_update_wen  ) & rob_entry_loadUnit_update_io_skip          ) |
                                    ((rob_entry_StoreQueue_update_wen) & rob_entry_StoreQueue_update_io_skip        );

    FF_D_without_asyn_rst #(1 )    u_entry_io_skip  (clk,rob_entry_wen_io_skip, rob_entry_nxt_io_skip, rob_entry_io_skip[entry_index]);
    FF_D_without_asyn_rst #(32)    u_entry_inst     (clk,rob_entry_enq_wen, rob_entry_nxt_inst, rob_entry_inst[entry_index]);
end
endgenerate

rob_entry_t     rob_entry_commit0;
rob_entry_t     rob_entry_commit1;

logic [5:0] rob_ptr_commit0;
logic [5:0] rob_ptr_commit1;

assign rob_ptr_commit0 = u_core_ooo_top.u_backend_top.u_rob.rob_ptr_button[5:0];
assign rob_ptr_commit1 = (u_core_ooo_top.u_backend_top.u_rob.rob_ptr_button[5:0] + 6'h1);

assign rob_entry_commit0 = u_core_ooo_top.u_backend_top.u_rob.rob_entry[rob_ptr_commit0];
assign rob_entry_commit1 = u_core_ooo_top.u_backend_top.u_rob.rob_entry[rob_ptr_commit1];

wire io_valid0 = ((u_core_ooo_top.u_backend_top.u_rob.rob_ptr_button != u_core_ooo_top.u_backend_top.u_rob.rob_ptr_top)  &
                rob_entry_commit0.finish) & 
                ((!rob_entry_commit0.trap_flag) | 
                (rob_entry_commit0.trap_cause != 5'd26));

wire io_valid1 = (((u_core_ooo_top.u_backend_top.u_rob.rob_ptr_button + 1) != u_core_ooo_top.u_backend_top.u_rob.rob_ptr_top) & 
                io_valid0 &
                (!rob_entry_commit0.trap_flag) & 
                (!rob_entry_commit0.end_flag) & 
                (!rob_entry_commit1.trap_flag) &
                (!rob_entry_commit1.end_flag) &
                rob_entry_commit1.finish);

logic [63:0] next_pc;
assign next_pc = u_core_ooo_top.u_backend_top.u_csr.u_trap_control.csr_jump_flag ? 
                    u_core_ooo_top.u_backend_top.u_csr.u_trap_control.csr_jump_addr : 
                    u_core_ooo_top.u_backend_top.u_csr.u_trap_control.rob_commit_next_pc;

DifftestInstrCommit u_DifftestInstrCommit0(
    .clock      	(clk                                                                ),
    .io_valid   	(io_valid0                                                          ),
    .io_skip    	(rob_entry_io_skip[rob_ptr_commit0]                                 ),
    .io_isRVC   	(rob_entry_commit0.rvc_flag                                         ),
    .io_rfwen   	(rob_entry_commit0.rfwen                                            ),
    .io_fpwen   	(1'b0                                                               ),
    .io_vecwen  	(1'b0                                                               ),
    .io_wpdest  	(rob_entry_commit0.pwdest                                           ),
    .io_wdest   	(rob_entry_commit0.wdest                                            ),
    .io_pc      	(next_pc                                                            ),
    .io_instr  	    (rob_entry_inst[rob_ptr_commit0]                                    ),
    .io_robIdx  	(rob_ptr_commit0                                                    ),
    .io_lqIdx   	(7'h0                                                               ),
    .io_sqIdx   	(7'h0                                                               ),
//     //todo 暂不支持查询是否访存指令
    .io_isLoad  	(1'b0                                                               ),
    .io_isStore 	(1'b0                                                               ),

    .io_nFused  	(8'h0                                                               ),
    .io_special 	(8'h0                                                               ),
    .io_coreid  	(8'h0                                                               ),
    .io_index   	(8'h0                                                               )
);

DifftestInstrCommit u_DifftestInstrCommit1(
    .clock      	(clk                                                                ),
    .io_valid   	(io_valid1                                                          ),
    .io_skip    	(rob_entry_io_skip[rob_ptr_commit1]                                 ),
    .io_isRVC   	(rob_entry_commit1.rvc_flag                                         ),
    .io_rfwen   	(rob_entry_commit1.rfwen                                            ),
    .io_fpwen   	(1'b0                                                               ),
    .io_vecwen  	(1'b0                                                               ),
    .io_wpdest  	(rob_entry_commit0.pwdest                                           ),
    .io_wdest   	(rob_entry_commit0.wdest                                            ),
    .io_pc      	(next_pc                                                            ),
    .io_instr  	    (rob_entry_inst[rob_ptr_commit1]                                    ),
    .io_robIdx  	(rob_ptr_commit1                                                    ),
    .io_lqIdx   	(7'h0                                                               ),
    .io_sqIdx   	(7'h0                                                               ),
//     //todo 暂不支持查询是否访存指令      
    .io_isLoad  	(1'b0                                                               ),
    .io_isStore 	(1'b0                                                               ),

    .io_nFused  	(8'h0                                                               ),
    .io_special 	(8'h0                                                               ),
    .io_coreid  	(8'h0                                                               ),
    .io_index   	(8'h1                                                               )
);

DifftestTrapEvent u_DifftestTrapEvent(
    .clock         (clk                                                                     ),
    .enable        (u_core_ooo_top.u_backend_top.u_csr.u_trap_control.trap_m_interrupt |
                    u_core_ooo_top.u_backend_top.u_csr.u_trap_control.trap_s_interrupt      ),
    .io_hasTrap    (1'b0                                                                    ),
    .io_cycleCnt   (u_core_ooo_top.u_backend_top.u_csr.Performance_Monitor[2]               ),
    .io_instrCnt   (u_core_ooo_top.u_backend_top.u_csr.minstret                             ),
    .io_hasWFI     (1'b0                                                                    ),
    .io_code       (u_core_ooo_top.u_backend_top.u_csr.u_trap_control.cause                 ),
    .io_pc         (u_core_ooo_top.u_backend_top.u_csr.u_trap_control.next_pc               ),
    .io_coreid     (8'h0                                                                    )
);


endmodule //core_debugger_top_ooo_lite

module warp;
always begin
    // // 中断
    // assign core_debugger_top_ooo_lite.u_core_ooo_top.u_backend_top.u_csr.MPerformance_Monitor_inc[3] = 
    //     core_debugger_top_ooo_lite.u_core_top_with_bpu.u_exu.WB_EX_interrupt_flag;
    // // load
    // assign core_debugger_top_ooo_lite.u_core_ooo_top.u_backend_top.u_csr.MPerformance_Monitor_inc[4] = 
    //     core_debugger_top_ooo_lite.u_core_top_with_bpu.u_lsu.EX_LS_reg_execute_valid & 
    //     (!core_debugger_top_ooo_lite.u_core_ooo_top.u_backend_top.u_csr.MPerformance_Monitor_inc[3]) & 
    //     (core_debugger_top_ooo_lite.u_core_top_with_bpu.u_lsu.EX_LS_reg_load_valid & 
    //     (!core_debugger_top_ooo_lite.u_core_top_with_bpu.u_lsu.read_finish));
    // // store
    // assign core_debugger_top_ooo_lite.u_core_ooo_top.u_backend_top.u_csr.MPerformance_Monitor_inc[5] = 
    //     core_debugger_top_ooo_lite.u_core_top_with_bpu.u_lsu.EX_LS_reg_execute_valid & 
    //     (!core_debugger_top_ooo_lite.u_core_ooo_top.u_backend_top.u_csr.MPerformance_Monitor_inc[3]) & 
    //     (core_debugger_top_ooo_lite.u_core_top_with_bpu.u_lsu.EX_LS_reg_store_valid & 
    //     (!core_debugger_top_ooo_lite.u_core_top_with_bpu.u_lsu.write_finish));
    // // atomic
    // assign core_debugger_top_ooo_lite.u_core_ooo_top.u_backend_top.u_csr.MPerformance_Monitor_inc[6] = 
    //     core_debugger_top_ooo_lite.u_core_top_with_bpu.u_lsu.EX_LS_reg_execute_valid & 
    //     (!core_debugger_top_ooo_lite.u_core_ooo_top.u_backend_top.u_csr.MPerformance_Monitor_inc[3]) & 
    //     (core_debugger_top_ooo_lite.u_core_top_with_bpu.u_lsu.EX_LS_reg_atomic_valid & 
    //     (!core_debugger_top_ooo_lite.u_core_top_with_bpu.u_lsu.atomic_finish));
    // // mul
    // assign core_debugger_top_ooo_lite.u_core_ooo_top.u_backend_top.u_csr.MPerformance_Monitor_inc[7] = 
    //     core_debugger_top_ooo_lite.u_core_top_with_bpu.u_exu.ID_EX_reg_decode_valid & 
    //     (!core_debugger_top_ooo_lite.u_core_ooo_top.u_backend_top.u_csr.MPerformance_Monitor_inc[3]) &
    //     (!core_debugger_top_ooo_lite.u_core_ooo_top.u_backend_top.u_csr.MPerformance_Monitor_inc[4]) &
    //     (!core_debugger_top_ooo_lite.u_core_ooo_top.u_backend_top.u_csr.MPerformance_Monitor_inc[5]) &
    //     (!core_debugger_top_ooo_lite.u_core_ooo_top.u_backend_top.u_csr.MPerformance_Monitor_inc[6]) &
    //     core_debugger_top_ooo_lite.u_core_top_with_bpu.u_exu.ID_EX_reg_mul_valid & 
    //     (!core_debugger_top_ooo_lite.u_core_top_with_bpu.u_exu.o_valid);
    // // div
    // assign core_debugger_top_ooo_lite.u_core_ooo_top.u_backend_top.u_csr.MPerformance_Monitor_inc[8] = 
    //     core_debugger_top_ooo_lite.u_core_top_with_bpu.u_exu.ID_EX_reg_decode_valid & 
    //     (!core_debugger_top_ooo_lite.u_core_ooo_top.u_backend_top.u_csr.MPerformance_Monitor_inc[3]) &
    //     (!core_debugger_top_ooo_lite.u_core_ooo_top.u_backend_top.u_csr.MPerformance_Monitor_inc[4]) &
    //     (!core_debugger_top_ooo_lite.u_core_ooo_top.u_backend_top.u_csr.MPerformance_Monitor_inc[5]) &
    //     (!core_debugger_top_ooo_lite.u_core_ooo_top.u_backend_top.u_csr.MPerformance_Monitor_inc[6]) &
    //     core_debugger_top_ooo_lite.u_core_top_with_bpu.u_exu.ID_EX_reg_div_valid & 
    //     (!core_debugger_top_ooo_lite.u_core_top_with_bpu.u_exu.o_valid);
    // // no inst
    // assign core_debugger_top_ooo_lite.u_core_ooo_top.u_backend_top.u_csr.MPerformance_Monitor_inc[9] = 
    //     (!core_debugger_top_ooo_lite.u_core_top_with_bpu.u_idu.IF_ID_reg_inst_valid) & 
    //     (!core_debugger_top_ooo_lite.u_core_ooo_top.u_backend_top.u_csr.MPerformance_Monitor_inc[3]) &
    //     (!core_debugger_top_ooo_lite.u_core_ooo_top.u_backend_top.u_csr.MPerformance_Monitor_inc[4]) &
    //     (!core_debugger_top_ooo_lite.u_core_ooo_top.u_backend_top.u_csr.MPerformance_Monitor_inc[5]) &
    //     (!core_debugger_top_ooo_lite.u_core_ooo_top.u_backend_top.u_csr.MPerformance_Monitor_inc[6]) &
    //     (!core_debugger_top_ooo_lite.u_core_ooo_top.u_backend_top.u_csr.MPerformance_Monitor_inc[7]) &
    //     (!core_debugger_top_ooo_lite.u_core_ooo_top.u_backend_top.u_csr.MPerformance_Monitor_inc[8]);
    // // jump/branch time
    // assign core_debugger_top_ooo_lite.u_core_ooo_top.u_backend_top.u_csr.MPerformance_Monitor_inc[10] = 
    //     (core_debugger_top_ooo_lite.u_core_top_with_bpu.ID_EX_reg_decode_valid & 
    //     core_debugger_top_ooo_lite.u_core_top_with_bpu.EX_ID_decode_ready & 
    //     (core_debugger_top_ooo_lite.u_core_top_with_bpu.ID_EX_reg_branch_valid | 
    //     core_debugger_top_ooo_lite.u_core_top_with_bpu.ID_EX_reg_jump_valid));
    // // commit restore time
    // assign core_debugger_top_ooo_lite.u_core_ooo_top.u_backend_top.u_csr.MPerformance_Monitor_inc[11] = 
    //     (core_debugger_top_ooo_lite.u_core_top_with_bpu.commit_restore);
    // // jump but commit restore time
    // assign core_debugger_top_ooo_lite.u_core_ooo_top.u_backend_top.u_csr.MPerformance_Monitor_inc[12] = 
    //     (core_debugger_top_ooo_lite.u_core_top_with_bpu.commit_restore & 
    //     core_debugger_top_ooo_lite.u_core_top_with_bpu.ID_EX_reg_jump_valid);
    // // jalr but commit restore time
    // assign core_debugger_top_ooo_lite.u_core_ooo_top.u_backend_top.u_csr.MPerformance_Monitor_inc[13] = 
    //     (core_debugger_top_ooo_lite.u_core_top_with_bpu.commit_restore & 
    //     core_debugger_top_ooo_lite.u_core_top_with_bpu.ID_EX_reg_jump_valid & 
    //     core_debugger_top_ooo_lite.u_core_top_with_bpu.ID_EX_reg_jump_jalr);
    // // ret but commit restore time
    // assign core_debugger_top_ooo_lite.u_core_ooo_top.u_backend_top.u_csr.MPerformance_Monitor_inc[14] = 
    //     (core_debugger_top_ooo_lite.u_core_top_with_bpu.commit_restore & 
    //     core_debugger_top_ooo_lite.u_core_top_with_bpu.ID_EX_reg_jump_valid & 
    //     core_debugger_top_ooo_lite.u_core_top_with_bpu.jump_is_ret);
    // // branch but commit restore time
    // assign core_debugger_top_ooo_lite.u_core_ooo_top.u_backend_top.u_csr.MPerformance_Monitor_inc[15] = 
    //     (core_debugger_top_ooo_lite.u_core_top_with_bpu.commit_restore & 
    //     core_debugger_top_ooo_lite.u_core_top_with_bpu.ID_EX_reg_branch_valid);
end
endmodule
