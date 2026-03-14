module core_debugger_top_ooo
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

wire clk = clock;


// output declaration of module core_top_with_bpu
logic                       icache_arvalid;
logic [63:0]                icache_araddr;
logic [7:0]                 icache_arid;
logic [7:0]                 icache_arlen;
logic [2:0]                 icache_arsize;
logic [1:0]                 icache_arburst;
logic                       icache_rready;
logic                       dcache_arvalid;
logic [63:0]                dcache_araddr;
logic [7:0]                 dcache_arid;
logic [7:0]                 dcache_arlen;
logic [2:0]                 dcache_arsize;
logic                       dcache_arlock;
logic [1:0]                 dcache_arburst;
logic                       dcache_rready;
logic                       dcache_awvalid;
logic [63:0]                dcache_awaddr;
logic [7:0]                 dcache_awid;
logic [7:0]                 dcache_awlen;
logic [2:0]                 dcache_awsize;
logic                       dcache_awlock;
logic [1:0]                 dcache_awburst;
logic                       dcache_wvalid;
logic [63:0]                dcache_wdata;
logic [7:0]                 dcache_wstrb;
logic                       dcache_wlast;
logic                       dcache_bready;
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
wire                    slv0_awready;
wire                    slv0_wready;
wire                    slv0_bvalid;
wire [AXI_ID_W-1:0]     slv0_bid;
wire [2-1:0]            slv0_bresp;
wire [AXI_BUSER_W-1:0]  slv0_buser;
wire                    slv0_arready;
wire                    slv0_rvalid;
wire [AXI_ID_W-1:0]     slv0_rid;
wire [2-1:0]            slv0_rresp;
wire [AXI_DATA_W-1:0]   slv0_rdata;
wire                    slv0_rlast;
wire [AXI_RUSER_W-1:0]  slv0_ruser;
wire                    slv1_awready;
wire                    slv1_wready;
wire                    slv1_bvalid;
wire [AXI_ID_W-1:0]     slv1_bid;
wire [2-1:0]            slv1_bresp;
wire [AXI_BUSER_W-1:0]  slv1_buser;
wire                    slv1_arready;
wire                    slv1_rvalid;
wire [AXI_ID_W-1:0]     slv1_rid;
wire [2-1:0]            slv1_rresp;
wire [AXI_DATA_W-1:0]   slv1_rdata;
wire                    slv1_rlast;
wire [AXI_RUSER_W-1:0]  slv1_ruser;
wire                    slv2_awready;
wire                    slv2_wready;
wire                    slv2_bvalid;
wire [AXI_ID_W-1:0]     slv2_bid;
wire [2-1:0]            slv2_bresp;
wire [AXI_BUSER_W-1:0]  slv2_buser;
wire                    slv2_arready;
wire                    slv2_rvalid;
wire [AXI_ID_W-1:0]     slv2_rid;
wire [2-1:0]            slv2_rresp;
wire [AXI_DATA_W-1:0]   slv2_rdata;
wire                    slv2_rlast;
wire [AXI_RUSER_W-1:0]  slv2_ruser;
wire [AXI_ID_W-1:0]     slv3_bid;
wire [AXI_BUSER_W-1:0]  slv3_buser;
wire [AXI_ID_W-1:0]     slv3_rid;
wire                    slv3_rlast;
wire [AXI_RUSER_W-1:0]  slv3_ruser;
wire                    mst0_awvalid;
wire [AXI_ADDR_W-1:0]   mst0_awaddr;
wire [8-1:0]            mst0_awlen;
wire [3-1:0]            mst0_awsize;
wire [2-1:0]            mst0_awburst;
wire                    mst0_awlock;
wire [4-1:0]            mst0_awcache;
wire [3-1:0]            mst0_awprot;
wire [4-1:0]            mst0_awqos;
wire [4-1:0]            mst0_awregion;
wire [AXI_ID_W-1:0]     mst0_awid;
wire [AXI_AUSER_W-1:0]  mst0_awuser;
wire                    mst0_wvalid;
wire                    mst0_wlast;
wire [AXI_DATA_W-1:0]   mst0_wdata;
wire [AXI_DATA_W/8-1:0] mst0_wstrb;
wire [AXI_WUSER_W-1:0]  mst0_wuser;
wire                    mst0_bready;
wire                    mst0_arvalid;
wire [AXI_ADDR_W-1:0]   mst0_araddr;
wire [8-1:0]            mst0_arlen;
wire [3-1:0]            mst0_arsize;
wire [2-1:0]            mst0_arburst;
wire                    mst0_arlock;
wire [4-1:0]            mst0_arcache;
wire [3-1:0]            mst0_arprot;
wire [4-1:0]            mst0_arqos;
wire [4-1:0]            mst0_arregion;
wire [AXI_ID_W-1:0]     mst0_arid;
wire [AXI_AUSER_W-1:0]  mst0_aruser;
wire                    mst0_rready;
wire                    mst1_awvalid;
wire [AXI_ADDR_W-1:0]   mst1_awaddr;
wire [8-1:0]            mst1_awlen;
wire [3-1:0]            mst1_awsize;
wire [2-1:0]            mst1_awburst;
wire                    mst1_awlock;
wire [4-1:0]            mst1_awcache;
wire [3-1:0]            mst1_awprot;
wire [4-1:0]            mst1_awqos;
wire [4-1:0]            mst1_awregion;
wire [AXI_ID_W-1:0]     mst1_awid;
wire [AXI_AUSER_W-1:0]  mst1_awuser;
wire                    mst1_wvalid;
wire                    mst1_wlast;
wire [AXI_DATA_W-1:0]   mst1_wdata;
wire [AXI_DATA_W/8-1:0] mst1_wstrb;
wire [AXI_WUSER_W-1:0]  mst1_wuser;
wire                    mst1_bready;
wire                    mst1_arvalid;
wire [AXI_ADDR_W-1:0]   mst1_araddr;
wire [8-1:0]            mst1_arlen;
wire [3-1:0]            mst1_arsize;
wire [2-1:0]            mst1_arburst;
wire                    mst1_arlock;
wire [4-1:0]            mst1_arcache;
wire [3-1:0]            mst1_arprot;
wire [4-1:0]            mst1_arqos;
wire [4-1:0]            mst1_arregion;
wire [AXI_ID_W-1:0]     mst1_arid;
wire [AXI_AUSER_W-1:0]  mst1_aruser;
wire                    mst1_rready;
wire                    mst2_awvalid;
wire [AXI_ADDR_W-1:0]   mst2_awaddr;
wire [8-1:0]            mst2_awlen;
wire [3-1:0]            mst2_awsize;
wire [2-1:0]            mst2_awburst;
wire                    mst2_awlock;
wire [4-1:0]            mst2_awcache;
wire [3-1:0]            mst2_awprot;
wire [4-1:0]            mst2_awqos;
wire [4-1:0]            mst2_awregion;
wire [AXI_ID_W-1:0]     mst2_awid;
wire [AXI_AUSER_W-1:0]  mst2_awuser;
wire                    mst2_wvalid;
wire                    mst2_wlast;
wire [AXI_DATA_W-1:0]   mst2_wdata;
wire [AXI_DATA_W/8-1:0] mst2_wstrb;
wire [AXI_WUSER_W-1:0]  mst2_wuser;
wire                    mst2_bready;
wire                    mst2_arvalid;
wire [AXI_ADDR_W-1:0]   mst2_araddr;
wire [8-1:0]            mst2_arlen;
wire [3-1:0]            mst2_arsize;
wire [2-1:0]            mst2_arburst;
wire                    mst2_arlock;
wire [4-1:0]            mst2_arcache;
wire [3-1:0]            mst2_arprot;
wire [4-1:0]            mst2_arqos;
wire [4-1:0]            mst2_arregion;
wire [AXI_ID_W-1:0]     mst2_arid;
wire [AXI_AUSER_W-1:0]  mst2_aruser;
wire                    mst2_rready;
wire                    mst3_awvalid;
wire [AXI_ADDR_W-1:0]   mst3_awaddr;
wire [8-1:0]            mst3_awlen;
wire [3-1:0]            mst3_awsize;
wire [2-1:0]            mst3_awburst;
wire                    mst3_awlock;
wire [4-1:0]            mst3_awcache;
wire [3-1:0]            mst3_awprot;
wire [4-1:0]            mst3_awqos;
wire [4-1:0]            mst3_awregion;
wire [AXI_ID_W-1:0]     mst3_awid;
wire [AXI_AUSER_W-1:0]  mst3_awuser;
wire                    mst3_wvalid;
wire                    mst3_wlast;
wire [AXI_DATA_W-1:0]   mst3_wdata;
wire [AXI_DATA_W/8-1:0] mst3_wstrb;
wire [AXI_WUSER_W-1:0]  mst3_wuser;
wire                    mst3_bready;
wire                    mst3_arvalid;
wire [AXI_ADDR_W-1:0]   mst3_araddr;
wire [8-1:0]            mst3_arlen;
wire [3-1:0]            mst3_arsize;
wire [2-1:0]            mst3_arburst;
wire                    mst3_arlock;
wire [4-1:0]            mst3_arcache;
wire [3-1:0]            mst3_arprot;
wire [4-1:0]            mst3_arqos;
wire [4-1:0]            mst3_arregion;
wire [AXI_ID_W-1:0]     mst3_arid;
wire [AXI_AUSER_W-1:0]  mst3_aruser;
wire                    mst3_rready;

// output declaration of module dm_top
wire                    halt_req;
wire                    hartreset;
wire                    ndmreset;
wire                    slv2_awvalid;
wire [AXI_ADDR_W-1:0]   slv2_awaddr;
wire [8-1:0]            slv2_awlen;
wire [3-1:0]            slv2_awsize;
wire [2-1:0]            slv2_awburst;
wire                    slv2_awlock;
wire [4-1:0]            slv2_awcache;
wire [3-1:0]            slv2_awprot;
wire [4-1:0]            slv2_awqos;
wire [4-1:0]            slv2_awregion;
wire [AXI_ID_W-1:0]     slv2_awid;
wire                    slv2_wvalid;
wire                    slv2_wlast;
wire [AXI_DATA_W-1:0]   slv2_wdata;
wire [AXI_DATA_W/8-1:0] slv2_wstrb;
wire                    slv2_bready;
wire                    slv2_arvalid;
wire [AXI_ADDR_W-1:0]   slv2_araddr;
wire [8-1:0]            slv2_arlen;
wire [3-1:0]            slv2_arsize;
wire [2-1:0]            slv2_arburst;
wire                    slv2_arlock;
wire [4-1:0]            slv2_arcache;
wire [3-1:0]            slv2_arprot;
wire [4-1:0]            slv2_arqos;
wire [4-1:0]            slv2_arregion;
wire [AXI_ID_W-1:0]     slv2_arid;
wire                    slv2_rready;


// output declaration of module dummy_axi_slv0
wire                    mst0_awready;
wire                    mst0_wready;
wire                    mst0_bvalid;
wire [AXI_ID_W-1:0]     mst0_bid;
wire [2-1:0]            mst0_bresp;
wire                    mst0_arready;
wire                    mst0_rvalid;
wire [AXI_ID_W-1:0]     mst0_rid;
wire [2-1:0]            mst0_rresp;
wire [AXI_DATA_W-1:0]   mst0_rdata;
wire                    mst0_rlast;

// output declaration of module dummy_axi_slv1
wire                    mst1_awready;
wire                    mst1_wready;
wire                    mst1_bvalid;
wire [AXI_ID_W-1:0]     mst1_bid;
wire [2-1:0]            mst1_bresp;
wire                    mst1_arready;
wire                    mst1_rvalid;
wire [AXI_ID_W-1:0]     mst1_rid;
wire [2-1:0]            mst1_rresp;
wire [AXI_DATA_W-1:0]   mst1_rdata;
wire                    mst1_rlast;

// output declaration of module dummy_axi_slv2
wire                    mst2_awready;
wire                    mst2_wready;
wire                    mst2_bvalid;
wire [AXI_ID_W-1:0]     mst2_bid;
wire [2-1:0]            mst2_bresp;
wire                    mst2_arready;
wire                    mst2_rvalid;
wire [AXI_ID_W-1:0]     mst2_rid;
wire [2-1:0]            mst2_rresp;
wire [AXI_DATA_W-1:0]   mst2_rdata;
wire                    mst2_rlast;

// output declaration of module sim_sram_dpic
wire                    mst3_awready;
wire                    mst3_wready;
wire                    mst3_bvalid;
wire [AXI_ID_W-1:0]     mst3_bid;
wire [2-1:0]            mst3_bresp;
wire                    mst3_arready;
wire                    mst3_rvalid;
wire [AXI_ID_W-1:0]     mst3_rid;
wire [2-1:0]            mst3_rresp;
wire [AXI_DATA_W-1:0]   mst3_rdata;
wire                    mst3_rlast;

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
	.icache_arready  	            ( slv0_arready                  ),
	.icache_araddr   	            ( icache_araddr                 ),
	.icache_arlen    	            ( icache_arlen                  ),
	.icache_arsize   	            ( icache_arsize                 ),
	.icache_arburst  	            ( icache_arburst                ),
	.icache_arid     	            ( icache_arid                   ),
	.icache_rvalid   	            ( slv0_rvalid                   ),
	.icache_rready   	            ( icache_rready                 ),
	.icache_rid      	            ( slv0_rid                      ),
	.icache_rresp    	            ( slv0_rresp                    ),
	.icache_rdata    	            ( slv0_rdata                    ),
	.icache_rlast    	            ( slv0_rlast                    ),
	.dcache_arvalid  	            ( dcache_arvalid                ),
	.dcache_arready  	            ( slv1_arready                  ),
	.dcache_araddr   	            ( dcache_araddr                 ),
	.dcache_arlen    	            ( dcache_arlen                  ),
	.dcache_arsize   	            ( dcache_arsize                 ),
	.dcache_arburst  	            ( dcache_arburst                ),
	.dcache_arlock   	            ( dcache_arlock                 ),
	.dcache_arid     	            ( dcache_arid                   ),
	.dcache_rvalid   	            ( slv1_rvalid                   ),
	.dcache_rready   	            ( dcache_rready                 ),
	.dcache_rid      	            ( slv1_rid                      ),
	.dcache_rresp    	            ( slv1_rresp                    ),
	.dcache_rdata    	            ( slv1_rdata                    ),
	.dcache_rlast    	            ( slv1_rlast                    ),
	.dcache_awvalid  	            ( dcache_awvalid                ),
	.dcache_awready  	            ( slv1_awready                  ),
	.dcache_awaddr   	            ( dcache_awaddr                 ),
	.dcache_awlen    	            ( dcache_awlen                  ),
	.dcache_awsize   	            ( dcache_awsize                 ),
	.dcache_awburst  	            ( dcache_awburst                ),
	.dcache_awlock   	            ( dcache_awlock                 ),
	.dcache_awid     	            ( dcache_awid                   ),
	.dcache_wvalid   	            ( dcache_wvalid                 ),
	.dcache_wready   	            ( slv1_wready                   ),
	.dcache_wlast    	            ( dcache_wlast                  ),
	.dcache_wdata    	            ( dcache_wdata                  ),
	.dcache_wstrb    	            ( dcache_wstrb                  ),
	.dcache_bvalid   	            ( slv1_bvalid                   ),
	.dcache_bready   	            ( dcache_bready                 ),
	.dcache_bid      	            ( slv1_bid                      ),
	.dcache_bresp    	            ( slv1_bresp                    ),
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

// logic [63:0]                    ftq_entry_start_pc                      [FTQ_ENTRY_NUM - 1 : 0];
// logic [63:0]                    ftq_entry_next_pc                       [FTQ_ENTRY_NUM - 1 : 0];
// logic [0:0]                     ftq_entry_first_pred_flag               [FTQ_ENTRY_NUM - 1 : 0];
// logic [0:0]                     ftq_entry_hit                           [FTQ_ENTRY_NUM - 1 : 0];
// logic [0:0]                     ftq_entry_token                         [FTQ_ENTRY_NUM - 1 : 0];
// logic [0:0]                     ftq_entry_is_tail                       [FTQ_ENTRY_NUM - 1 : 0];
// logic [UFTB_ENTRY_NUM - 1 : 0]  ftq_entry_hit_sel                       [FTQ_ENTRY_NUM - 1 : 0];
// logic [0:0]                     ftq_entry_old_entry_valid               [FTQ_ENTRY_NUM - 1 : 0];
// logic [TAG_BIT_NUM - 1: 0]      ftq_entry_old_entry_tag                 [FTQ_ENTRY_NUM - 1 : 0];
// logic [0:0]                     ftq_entry_old_entry_br_slot_valid       [FTQ_ENTRY_NUM - 1 : 0];
// logic [BLOCK_BIT_NUM - 1: 0]    ftq_entry_old_entry_br_slot_offset      [FTQ_ENTRY_NUM - 1 : 0];
// logic [0:0]                     ftq_entry_old_entry_br_slot_is_rvc      [FTQ_ENTRY_NUM - 1 : 0];
// logic [1:0]                     ftq_entry_old_entry_br_slot_carry       [FTQ_ENTRY_NUM - 1 : 0];
// logic [11:0]                    ftq_entry_old_entry_br_slot_next_low    [FTQ_ENTRY_NUM - 1 : 0];
// logic [1:0]                     ftq_entry_old_entry_br_slot_bit2_cnt    [FTQ_ENTRY_NUM - 1 : 0];
// logic [0:0]                     ftq_entry_old_entry_tail_slot_valid     [FTQ_ENTRY_NUM - 1 : 0];
// logic [BLOCK_BIT_NUM - 1: 0]    ftq_entry_old_entry_tail_slot_offset    [FTQ_ENTRY_NUM - 1 : 0];
// logic [0:0]                     ftq_entry_old_entry_tail_slot_is_rvc    [FTQ_ENTRY_NUM - 1 : 0];
// logic [1:0]                     ftq_entry_old_entry_tail_slot_carry     [FTQ_ENTRY_NUM - 1 : 0];
// logic [19:0]                    ftq_entry_old_entry_tail_slot_next_low  [FTQ_ENTRY_NUM - 1 : 0];
// logic [1:0]                     ftq_entry_old_entry_tail_slot_bit2_cnt  [FTQ_ENTRY_NUM - 1 : 0];
// logic [0:0]                     ftq_entry_old_entry_carry               [FTQ_ENTRY_NUM - 1 : 0];
// logic [BLOCK_BIT_NUM - 1: 0]    ftq_entry_old_entry_next_low            [FTQ_ENTRY_NUM - 1 : 0];
// logic [0:0]                     ftq_entry_old_entry_is_branch           [FTQ_ENTRY_NUM - 1 : 0];
// logic [0:0]                     ftq_entry_old_entry_is_call             [FTQ_ENTRY_NUM - 1 : 0];
// logic [0:0]                     ftq_entry_old_entry_is_ret              [FTQ_ENTRY_NUM - 1 : 0];
// logic [0:0]                     ftq_entry_old_entry_is_jalr             [FTQ_ENTRY_NUM - 1 : 0];
// logic [1:0]                     ftq_entry_old_entry_always_token        [FTQ_ENTRY_NUM - 1 : 0];


// logic [0:0]                     uftb_entry_valid               [UFTB_ENTRY_NUM - 1 : 0];
// logic [TAG_BIT_NUM - 1: 0]      uftb_entry_tag                 [UFTB_ENTRY_NUM - 1 : 0];
// logic [0:0]                     uftb_entry_br_slot_valid       [UFTB_ENTRY_NUM - 1 : 0];
// logic [BLOCK_BIT_NUM - 1: 0]    uftb_entry_br_slot_offset      [UFTB_ENTRY_NUM - 1 : 0];
// logic [0:0]                     uftb_entry_br_slot_is_rvc      [UFTB_ENTRY_NUM - 1 : 0];
// logic [1:0]                     uftb_entry_br_slot_carry       [UFTB_ENTRY_NUM - 1 : 0];
// logic [11:0]                    uftb_entry_br_slot_next_low    [UFTB_ENTRY_NUM - 1 : 0];
// logic [1:0]                     uftb_entry_br_slot_bit2_cnt    [UFTB_ENTRY_NUM - 1 : 0];
// logic [0:0]                     uftb_entry_tail_slot_valid     [UFTB_ENTRY_NUM - 1 : 0];
// logic [BLOCK_BIT_NUM - 1: 0]    uftb_entry_tail_slot_offset    [UFTB_ENTRY_NUM - 1 : 0];
// logic [0:0]                     uftb_entry_tail_slot_is_rvc    [UFTB_ENTRY_NUM - 1 : 0];
// logic [1:0]                     uftb_entry_tail_slot_carry     [UFTB_ENTRY_NUM - 1 : 0];
// logic [19:0]                    uftb_entry_tail_slot_next_low  [UFTB_ENTRY_NUM - 1 : 0];
// logic [1:0]                     uftb_entry_tail_slot_bit2_cnt  [UFTB_ENTRY_NUM - 1 : 0];
// logic [0:0]                     uftb_entry_carry               [UFTB_ENTRY_NUM - 1 : 0];
// logic [BLOCK_BIT_NUM - 1: 0]    uftb_entry_next_low            [UFTB_ENTRY_NUM - 1 : 0];
// logic [0:0]                     uftb_entry_is_branch           [UFTB_ENTRY_NUM - 1 : 0];
// logic [0:0]                     uftb_entry_is_call             [UFTB_ENTRY_NUM - 1 : 0];
// logic [0:0]                     uftb_entry_is_ret              [UFTB_ENTRY_NUM - 1 : 0];
// logic [0:0]                     uftb_entry_is_jalr             [UFTB_ENTRY_NUM - 1 : 0];
// logic [1:0]                     uftb_entry_always_token        [UFTB_ENTRY_NUM - 1 : 0];

// logic [63:0]                        ras_stack_entry_addr        [RAS_ENTRY_NUM - 1: 0];
// logic [ENTRY_RECURSION_BIT - 1:0]   ras_stack_entry_cnt         [RAS_ENTRY_NUM - 1: 0];
// logic [ENTRY_RECURSION_BIT - 1:0]   ras_stack_entry_pred_cnt    [RAS_ENTRY_NUM - 1: 0];
// logic [ENTRY_RECURSION_BIT - 1:0]   ras_stack_entry_precheck_cnt[RAS_ENTRY_NUM - 1: 0];
// logic [63:0]                        ras_queue_entry_addr        [SQ_ENTRY_NUM - 1: 0];
// logic [ENTRY_RECURSION_BIT - 1:0]   ras_queue_entry_pred_cnt    [SQ_ENTRY_NUM - 1: 0];
// logic [ENTRY_RECURSION_BIT - 1:0]   ras_queue_entry_precheck_cnt[SQ_ENTRY_NUM - 1: 0];
// logic [SQ_ENTRY_BIT_NUM - 1:0]      ras_queue_entry_nos         [SQ_ENTRY_NUM - 1: 0];
// logic [RAS_ENTRY_BIT_NUM - 1:0]     ras_stack_nsp; // 提交栈指针
// logic [RAS_ENTRY_BIT_NUM - 1:0]     ras_stack_ssp; // 预测栈指针
// logic [RAS_ENTRY_BIT_NUM - 1:0]     ras_stack_psp; // 预译码栈指针
// logic [RAS_ENTRY_BIT_NUM - 1:0]     ras_stack_bos; // 栈底
// logic [SQ_ENTRY_BIT_NUM - 1:0]      ras_queue_tosr;  // 预测队读指针
// logic [SQ_ENTRY_BIT_NUM - 1:0]      ras_queue_tosw;  // 预测队写指针
// logic [SQ_ENTRY_BIT_NUM - 1:0]      ras_queue_ptosr; // 预译码队读指针
// logic [SQ_ENTRY_BIT_NUM - 1:0]      ras_queue_ptosw; // 预译码队写指针
// logic [SQ_ENTRY_BIT_NUM - 1:0]      ras_queue_bos;   // 队尾指针

// stack    return_addr_stack;
// queue    return_addr_queue;
// assign return_addr_stack = core_debugger_top_ooo.u_core_top_with_bpu.u_frontend_top.u_bpu.u_ras.return_addr_stack;
// assign return_addr_queue = core_debugger_top_ooo.u_core_top_with_bpu.u_frontend_top.u_bpu.u_ras.return_addr_queue;

// assign ras_stack_nsp    = return_addr_stack.nsp;
// assign ras_stack_ssp    = return_addr_stack.ssp;
// assign ras_stack_psp    = return_addr_stack.psp;
// assign ras_stack_bos    = return_addr_stack.bos;
// assign ras_queue_tosr   = return_addr_queue.tosr ;
// assign ras_queue_tosw   = return_addr_queue.tosw ;
// assign ras_queue_ptosr  = return_addr_queue.ptosr;
// assign ras_queue_ptosw  = return_addr_queue.ptosw;
// assign ras_queue_bos    = return_addr_queue.bos  ;

// genvar ras_stack_entry_index;
// generate for(ras_stack_entry_index = 0 ; ras_stack_entry_index < RAS_ENTRY_NUM; ras_stack_entry_index = ras_stack_entry_index + 1) begin : U_gen_ras_stack_entry
//     stack_entry entry = return_addr_stack.entry[ras_stack_entry_index];
//     assign ras_stack_entry_addr        [ras_stack_entry_index] = entry.addr        ;
//     assign ras_stack_entry_cnt         [ras_stack_entry_index] = entry.cnt         ;
//     assign ras_stack_entry_pred_cnt    [ras_stack_entry_index] = entry.pred_cnt    ;
//     assign ras_stack_entry_precheck_cnt[ras_stack_entry_index] = entry.precheck_cnt;
// end
// endgenerate

// genvar ras_queue_entry_index;
// generate for(ras_queue_entry_index = 0 ; ras_queue_entry_index < SQ_ENTRY_NUM; ras_queue_entry_index = ras_queue_entry_index + 1) begin : U_gen_ras_queue_entry
//     queue_entry entry = return_addr_queue.entry[ras_queue_entry_index];
//     assign ras_queue_entry_addr        [ras_queue_entry_index] = entry.addr        ;
//     assign ras_queue_entry_pred_cnt    [ras_queue_entry_index] = entry.pred_cnt    ;
//     assign ras_queue_entry_precheck_cnt[ras_queue_entry_index] = entry.precheck_cnt;
//     assign ras_queue_entry_nos         [ras_queue_entry_index] = entry.nos         ;
// end
// endgenerate

// genvar entry_index;
// generate for(entry_index = 0 ; entry_index < FTQ_ENTRY_NUM; entry_index = entry_index + 1) begin : U_gen_ftq_entry
//     ftq_entry entry;
//     assign entry = core_debugger_top_ooo.u_core_top_with_bpu.u_frontend_top.u_ftq.entry[entry_index];
//     assign ftq_entry_start_pc                      [entry_index] = entry.start_pc                    ;
//     assign ftq_entry_next_pc                       [entry_index] = entry.next_pc                     ;
//     assign ftq_entry_first_pred_flag               [entry_index] = entry.first_pred_flag             ;
//     assign ftq_entry_hit                           [entry_index] = entry.hit                         ;
//     assign ftq_entry_token                         [entry_index] = entry.token                       ;
//     assign ftq_entry_is_tail                       [entry_index] = entry.is_tail                     ;
//     assign ftq_entry_hit_sel                       [entry_index] = entry.hit_sel                     ;
//     assign ftq_entry_old_entry_valid               [entry_index] = entry.old_entry.valid             ;
//     assign ftq_entry_old_entry_tag                 [entry_index] = entry.old_entry.tag               ;
//     assign ftq_entry_old_entry_br_slot_valid       [entry_index] = entry.old_entry.br_slot.valid     ;
//     assign ftq_entry_old_entry_br_slot_offset      [entry_index] = entry.old_entry.br_slot.offset    ;
//     assign ftq_entry_old_entry_br_slot_is_rvc      [entry_index] = entry.old_entry.br_slot.is_rvc    ;
//     assign ftq_entry_old_entry_br_slot_carry       [entry_index] = entry.old_entry.br_slot.carry     ;
//     assign ftq_entry_old_entry_br_slot_next_low    [entry_index] = entry.old_entry.br_slot.next_low  ;
//     assign ftq_entry_old_entry_br_slot_bit2_cnt    [entry_index] = entry.old_entry.br_slot.bit2_cnt  ;
//     assign ftq_entry_old_entry_tail_slot_valid     [entry_index] = entry.old_entry.tail_slot.valid   ;
//     assign ftq_entry_old_entry_tail_slot_offset    [entry_index] = entry.old_entry.tail_slot.offset  ;
//     assign ftq_entry_old_entry_tail_slot_is_rvc    [entry_index] = entry.old_entry.tail_slot.is_rvc  ;
//     assign ftq_entry_old_entry_tail_slot_carry     [entry_index] = entry.old_entry.tail_slot.carry   ;
//     assign ftq_entry_old_entry_tail_slot_next_low  [entry_index] = entry.old_entry.tail_slot.next_low;
//     assign ftq_entry_old_entry_tail_slot_bit2_cnt  [entry_index] = entry.old_entry.tail_slot.bit2_cnt;
//     assign ftq_entry_old_entry_carry               [entry_index] = entry.old_entry.carry             ;
//     assign ftq_entry_old_entry_next_low            [entry_index] = entry.old_entry.next_low          ;
//     assign ftq_entry_old_entry_is_branch           [entry_index] = entry.old_entry.is_branch         ;
//     assign ftq_entry_old_entry_is_call             [entry_index] = entry.old_entry.is_call           ;
//     assign ftq_entry_old_entry_is_ret              [entry_index] = entry.old_entry.is_ret            ;
//     assign ftq_entry_old_entry_is_jalr             [entry_index] = entry.old_entry.is_jalr           ;
//     assign ftq_entry_old_entry_always_token        [entry_index] = entry.old_entry.always_token      ;
// end
// endgenerate

// genvar ftb_entry_index;
// generate for(ftb_entry_index = 0 ; ftb_entry_index < UFTB_ENTRY_NUM; ftb_entry_index = ftb_entry_index + 1) begin : U_gen_uftb_entry
//     uftb_entry entry;
//     assign entry = core_debugger_top_ooo.u_core_top_with_bpu.u_frontend_top.u_bpu.u_uftb.entry[ftb_entry_index];
//     assign uftb_entry_valid               [ftb_entry_index] = entry.valid             ;
//     assign uftb_entry_tag                 [ftb_entry_index] = entry.tag               ;
//     assign uftb_entry_br_slot_valid       [ftb_entry_index] = entry.br_slot.valid     ;
//     assign uftb_entry_br_slot_offset      [ftb_entry_index] = entry.br_slot.offset    ;
//     assign uftb_entry_br_slot_is_rvc      [ftb_entry_index] = entry.br_slot.is_rvc    ;
//     assign uftb_entry_br_slot_carry       [ftb_entry_index] = entry.br_slot.carry     ;
//     assign uftb_entry_br_slot_next_low    [ftb_entry_index] = entry.br_slot.next_low  ;
//     assign uftb_entry_br_slot_bit2_cnt    [ftb_entry_index] = entry.br_slot.bit2_cnt  ;
//     assign uftb_entry_tail_slot_valid     [ftb_entry_index] = entry.tail_slot.valid   ;
//     assign uftb_entry_tail_slot_offset    [ftb_entry_index] = entry.tail_slot.offset  ;
//     assign uftb_entry_tail_slot_is_rvc    [ftb_entry_index] = entry.tail_slot.is_rvc  ;
//     assign uftb_entry_tail_slot_carry     [ftb_entry_index] = entry.tail_slot.carry   ;
//     assign uftb_entry_tail_slot_next_low  [ftb_entry_index] = entry.tail_slot.next_low;
//     assign uftb_entry_tail_slot_bit2_cnt  [ftb_entry_index] = entry.tail_slot.bit2_cnt;
//     assign uftb_entry_carry               [ftb_entry_index] = entry.carry             ;
//     assign uftb_entry_next_low            [ftb_entry_index] = entry.next_low          ;
//     assign uftb_entry_is_branch           [ftb_entry_index] = entry.is_branch         ;
//     assign uftb_entry_is_call             [ftb_entry_index] = entry.is_call           ;
//     assign uftb_entry_is_ret              [ftb_entry_index] = entry.is_ret            ;
//     assign uftb_entry_is_jalr             [ftb_entry_index] = entry.is_jalr           ;
//     assign uftb_entry_always_token        [ftb_entry_index] = entry.always_token      ;
// end
// endgenerate

axicb_crossbar_top #(
    .AXI_ADDR_W          	(AXI_ADDR_W         ),
    .AXI_ID_W            	(AXI_ID_W           ),
    .AXI_DATA_W          	(AXI_DATA_W         ),

    .MST_NB              	(4                  ),
    .SLV_NB              	(4                  ),

    .MST_PIPELINE        	(0                  ),
    .SLV_PIPELINE        	(0                  ),

    .AXI_SIGNALING       	(1                  ),

    .USER_SUPPORT        	(0                  ),
    .AXI_AUSER_W         	(1                  ),
    .AXI_WUSER_W         	(1                  ),
    .AXI_BUSER_W         	(1                  ),
    .AXI_RUSER_W         	(1                  ),

    .TIMEOUT_VALUE       	(10000              ),
    .TIMEOUT_ENABLE      	(1                  ),

    .MST0_CDC            	(0                  ),
    .MST0_OSTDREQ_NUM    	(4                  ),
    .MST0_OSTDREQ_SIZE   	(1                  ),
    .MST0_PRIORITY       	(0                  ),
    .MST0_ROUTES         	(4'b1_1_1_1         ),
    .MST0_ID_MASK        	(8'h10              ),
    .MST0_RW             	(1                  ),

    .MST1_CDC            	(0                  ),
    .MST1_OSTDREQ_NUM    	(4                  ),
    .MST1_OSTDREQ_SIZE   	(1                  ),
    .MST1_PRIORITY       	(0                  ),
    .MST1_ROUTES         	(4'b1_1_1_1         ),
    .MST1_ID_MASK        	(8'h20              ),
    .MST1_RW             	(0                  ),

    .MST2_CDC            	(1                  ),
    .MST2_OSTDREQ_NUM    	(4                  ),
    .MST2_OSTDREQ_SIZE   	(1                  ),
    .MST2_PRIORITY       	(0                  ),
    .MST2_ROUTES         	(4'b1_1_1_1         ),
    .MST2_ID_MASK        	(8'h40              ),
    .MST2_RW             	(0                  ),

    .MST3_CDC            	(0                  ),
    .MST3_OSTDREQ_NUM    	(4                  ),
    .MST3_OSTDREQ_SIZE   	(1                  ),
    .MST3_PRIORITY       	(0                  ),
    .MST3_ROUTES         	(4'b1_1_1_1         ),
    .MST3_ID_MASK        	(8'h80              ),
    .MST3_RW             	(0                  ),

    .SLV0_CDC            	(1                  ),
    .SLV0_START_ADDR     	(64'h0000_0000      ),
    .SLV0_END_ADDR       	(64'h0000_0fff      ),
    .SLV0_OSTDREQ_NUM    	(4                  ),
    .SLV0_OSTDREQ_SIZE   	(1                  ),
    .SLV0_KEEP_BASE_ADDR 	(1                  ),

    .SLV1_CDC            	(0                  ),
    .SLV1_START_ADDR     	(64'h0100_0000      ),
    .SLV1_END_ADDR       	(64'h1fff_ffff      ),
    .SLV1_OSTDREQ_NUM    	(4                  ),
    .SLV1_OSTDREQ_SIZE   	(1                  ),
    .SLV1_KEEP_BASE_ADDR 	(1                  ),

    .SLV2_CDC            	(0                  ),
    .SLV2_START_ADDR     	(64'h8000_0000      ),
    .SLV2_END_ADDR       	(64'h9fff_ffff      ),
    .SLV2_OSTDREQ_NUM    	(4                  ),
    .SLV2_OSTDREQ_SIZE   	(1                  ),
    .SLV2_KEEP_BASE_ADDR 	(1                  ),

    .SLV3_CDC            	(0                  ),
    .SLV3_START_ADDR     	(64'hA000_0000      ),
    .SLV3_END_ADDR       	(64'hBfff_ffff      ),
    .SLV3_OSTDREQ_NUM    	(4                  ),
    .SLV3_OSTDREQ_SIZE   	(1                  ),
    .SLV3_KEEP_BASE_ADDR 	(1                  ))
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
    .slv0_arvalid  	(icache_arvalid ),
    .slv0_arready  	(slv0_arready   ),
    .slv0_araddr   	(icache_araddr  ),
    .slv0_arlen    	(icache_arlen   ),
    .slv0_arsize   	(icache_arsize  ),
    .slv0_arburst  	(icache_arburst ),
    .slv0_arlock   	(1'h0           ),
    .slv0_arcache  	(4'h0           ),
    .slv0_arprot   	(3'h0           ),
    .slv0_arqos    	(4'h0           ),
    .slv0_arregion 	(4'h0           ),
    .slv0_arid     	(icache_arid    ),
    .slv0_aruser   	(1'b0           ),
    .slv0_rvalid   	(slv0_rvalid    ),
    .slv0_rready   	(icache_rready  ),
    .slv0_rid      	(slv0_rid       ),
    .slv0_rresp    	(slv0_rresp     ),
    .slv0_rdata    	(slv0_rdata     ),
    .slv0_rlast    	(slv0_rlast     ),
    .slv0_ruser    	(slv0_ruser     ),

    .slv1_aclk     	(clk            ),
    .slv1_aresetn  	(core_rst_n     ),
    .slv1_srst     	(1'b0           ),
    .slv1_awvalid  	(dcache_awvalid ),
    .slv1_awready  	(slv1_awready   ),
    .slv1_awaddr   	(dcache_awaddr  ),
    .slv1_awlen    	(dcache_awlen   ),
    .slv1_awsize   	(dcache_awsize  ),
    .slv1_awburst  	(dcache_awburst ),
    .slv1_awlock   	(dcache_awlock  ),
    .slv1_awcache  	(4'h0           ),
    .slv1_awprot   	(3'h0           ),
    .slv1_awqos    	(4'h0           ),
    .slv1_awregion 	(4'h0           ),
    .slv1_awid     	(dcache_awid    ),
    .slv1_awuser   	(1'b0           ),
    .slv1_wvalid   	(dcache_wvalid  ),
    .slv1_wready   	(slv1_wready    ),
    .slv1_wlast    	(dcache_wlast   ),
    .slv1_wdata    	(dcache_wdata   ),
    .slv1_wstrb    	(dcache_wstrb   ),
    .slv1_wuser    	(1'b0           ),
    .slv1_bvalid   	(slv1_bvalid    ),
    .slv1_bready   	(dcache_bready  ),
    .slv1_bid      	(slv1_bid       ),
    .slv1_bresp    	(slv1_bresp     ),
    .slv1_buser    	(slv1_buser     ),
    .slv1_arvalid  	(dcache_arvalid ),
    .slv1_arready  	(slv1_arready   ),
    .slv1_araddr   	(dcache_araddr  ),
    .slv1_arlen    	(dcache_arlen   ),
    .slv1_arsize   	(dcache_arsize  ),
    .slv1_arburst  	(dcache_arburst ),
    .slv1_arlock   	(dcache_arlock  ),
    .slv1_arcache  	(4'h0           ),
    .slv1_arprot   	(3'h0           ),
    .slv1_arqos    	(4'h0           ),
    .slv1_arregion 	(4'h0           ),
    .slv1_arid     	(dcache_arid    ),
    .slv1_aruser   	(1'b0           ),
    .slv1_rvalid   	(slv1_rvalid    ),
    .slv1_rready   	(dcache_rready  ),
    .slv1_rid      	(slv1_rid       ),
    .slv1_rresp    	(slv1_rresp     ),
    .slv1_rdata    	(slv1_rdata     ),
    .slv1_rlast    	(slv1_rlast     ),
    .slv1_ruser    	(slv1_ruser     ),

    .slv2_aclk     	(clk            ),
    .slv2_aresetn  	(core_rst_n     ),
    .slv2_srst     	(1'b0           ),
    .slv2_awvalid  	(1'b0           ),
    .slv2_awready  	(slv2_awready   ),
    .slv2_awaddr   	(64'h0          ),
    .slv2_awlen    	(8'h0           ),
    .slv2_awsize   	(3'h0           ),
    .slv2_awburst  	(2'h0           ),
    .slv2_awlock   	(1'h0           ),
    .slv2_awcache  	(4'h0           ),
    .slv2_awprot   	(3'h0           ),
    .slv2_awqos    	(4'h0           ),
    .slv2_awregion 	(4'h0           ),
    .slv2_awid     	(8'h3           ),
    .slv2_awuser   	(1'h0           ),
    .slv2_wvalid   	(1'h0           ),
    .slv2_wready   	(slv2_wready    ),
    .slv2_wlast    	(1'h0           ),
    .slv2_wdata    	(64'h0          ),
    .slv2_wstrb    	(8'h0           ),
    .slv2_wuser    	(1'b0           ),
    .slv2_bvalid   	(slv2_bvalid    ),
    .slv2_bready   	(1'h0           ),
    .slv2_bid      	(slv2_bid       ),
    .slv2_bresp    	(slv2_bresp     ),
    .slv2_buser    	(slv2_buser     ),
    .slv2_arvalid  	(1'b0           ),
    .slv2_arready  	(slv2_arready   ),
    .slv2_araddr   	(64'h0          ),
    .slv2_arlen    	(8'h0           ),
    .slv2_arsize   	(3'h0           ),
    .slv2_arburst  	(2'h0           ),
    .slv2_arlock   	(1'h0           ),
    .slv2_arcache  	(4'h0           ),
    .slv2_arprot   	(3'h0           ),
    .slv2_arqos    	(4'h0           ),
    .slv2_arregion 	(4'h0           ),
    .slv2_arid     	(8'h3           ),
    .slv2_aruser   	(1'b0           ),
    .slv2_rvalid   	(slv2_rvalid    ),
    .slv2_rready   	(1'b0           ),
    .slv2_rid      	(slv2_rid       ),
    .slv2_rresp    	(slv2_rresp     ),
    .slv2_rdata    	(slv2_rdata     ),
    .slv2_rlast    	(slv2_rlast     ),
    .slv2_ruser    	(slv2_ruser     ),

    .slv3_aclk     	(clk                    ),
    .slv3_aresetn  	(core_rst_n             ),
    .slv3_srst     	(1'b0                   ),
    .slv3_awvalid  	(store_uncache_awvalid  ),
    .slv3_awready  	(store_uncache_awready  ),
    .slv3_awaddr   	(store_uncache_awaddr   ),
    .slv3_awlen    	(8'h0                   ),
    .slv3_awsize   	(3'h3                   ),
    .slv3_awburst  	(2'h1                   ),
    .slv3_awlock   	(1'h0                   ),
    .slv3_awcache  	(4'h0                   ),
    .slv3_awprot   	(3'h0                   ),
    .slv3_awqos    	(4'h0                   ),
    .slv3_awregion 	(4'h0                   ),
    .slv3_awid     	(8'h80                  ),
    .slv3_awuser   	(1'h0                   ),
    .slv3_wvalid   	(store_uncache_wvalid   ),
    .slv3_wready   	(store_uncache_wready   ),
    .slv3_wlast    	(1'h1                   ),
    .slv3_wdata    	(store_uncache_wdata    ),
    .slv3_wstrb    	(store_uncache_wstrb    ),
    .slv3_wuser    	(1'b0                   ),
    .slv3_bvalid   	(store_uncache_bvalid   ),
    .slv3_bready   	(store_uncache_bready   ),
    .slv3_bid      	(slv3_bid               ),
    .slv3_bresp    	(store_uncache_bresp    ),
    .slv3_buser    	(slv3_buser             ),
    .slv3_arvalid  	(load_uncache_arvalid   ),
    .slv3_arready  	(load_uncache_arready   ),
    .slv3_araddr   	(load_uncache_araddr    ),
    .slv3_arlen    	(8'h0                   ),
    .slv3_arsize   	(3'h3                   ),
    .slv3_arburst  	(2'h1                   ),
    .slv3_arlock   	(1'h0                   ),
    .slv3_arcache  	(4'h0                   ),
    .slv3_arprot   	(3'h0                   ),
    .slv3_arqos    	(4'h0                   ),
    .slv3_arregion 	(4'h0                   ),
    .slv3_arid     	(8'h80                  ),
    .slv3_aruser   	(1'b0                   ),
    .slv3_rvalid   	(load_uncache_rvalid    ),
    .slv3_rready   	(load_uncache_rready    ),
    .slv3_rid      	(slv3_rid               ),
    .slv3_rresp    	(load_uncache_rresp     ),
    .slv3_rdata    	(load_uncache_rdata     ),
    .slv3_rlast    	(slv3_rlast             ),
    .slv3_ruser    	(slv3_ruser             ),

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

dummy_axi_slv #(
    .AXI_ADDR_W 	(AXI_ADDR_W     ),
    .AXI_ID_W   	(AXI_ID_W       ),
    .AXI_DATA_W 	(AXI_DATA_W     ))
u_sim_periph_dpic0(
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
initial begin
    string image;
    string image_path = "/home/kuuga/ysyx-workbench/npc/rot13.image";
    if($value$plusargs("image=%s", image))begin
        image_path = image;
    end
    // $readmemh(image_path, u_sim_sram_dpic.u_sram.ram);
end

sim_periph_dpic #(
    .AXI_ADDR_W 	(AXI_ADDR_W  ),
    .AXI_ID_W   	(AXI_ID_W    ),
    .AXI_DATA_W 	(AXI_DATA_W  ))
u_sim_periph_dpic(
    .aclk         	(clk           ),
    .arst_n       	(core_rst_n    ),
    .read_redirect  ( u_core_ooo_top.u_backend_top.redirect),
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

dummy_axi_slv #(
    .AXI_ADDR_W 	(AXI_ADDR_W  ),
    .AXI_ID_W   	(AXI_ID_W    ),
    .AXI_DATA_W 	(AXI_DATA_W  ))
u_dm_top(
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
    .io_value_0  	(u_core_ooo_top.u_backend_top.u_csr.Performance_Monitor[1 ]   ),
    .io_value_1  	(u_core_ooo_top.u_backend_top.u_csr.Performance_Monitor[2 ]   ),
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
    assign rob_entry_loadUnit_update_io_skip                = (!addrcache(load_paddr))                            ;

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
    .io_cycleCnt   (u_core_ooo_top.u_backend_top.u_csr.Performance_Monitor[1]               ),
    .io_instrCnt   (u_core_ooo_top.u_backend_top.u_csr.Performance_Monitor[2]               ),
    .io_hasWFI     (1'b0                                                                    ),
    .io_code       (u_core_ooo_top.u_backend_top.u_csr.u_trap_control.cause                 ),
    .io_pc         (u_core_ooo_top.u_backend_top.u_csr.u_trap_control.next_pc               ),
    .io_coreid     (8'h0                                                                    )
);


endmodule //core_debugger_top_ooo

module warp;
always begin
    // // 中断
    // assign core_debugger_top_ooo.u_core_ooo_top.u_backend_top.u_csr.MPerformance_Monitor_inc[3] = 
    //     core_debugger_top_ooo.u_core_top_with_bpu.u_exu.WB_EX_interrupt_flag;
    // // load
    // assign core_debugger_top_ooo.u_core_ooo_top.u_backend_top.u_csr.MPerformance_Monitor_inc[4] = 
    //     core_debugger_top_ooo.u_core_top_with_bpu.u_lsu.EX_LS_reg_execute_valid & 
    //     (!core_debugger_top_ooo.u_core_ooo_top.u_backend_top.u_csr.MPerformance_Monitor_inc[3]) & 
    //     (core_debugger_top_ooo.u_core_top_with_bpu.u_lsu.EX_LS_reg_load_valid & 
    //     (!core_debugger_top_ooo.u_core_top_with_bpu.u_lsu.read_finish));
    // // store
    // assign core_debugger_top_ooo.u_core_ooo_top.u_backend_top.u_csr.MPerformance_Monitor_inc[5] = 
    //     core_debugger_top_ooo.u_core_top_with_bpu.u_lsu.EX_LS_reg_execute_valid & 
    //     (!core_debugger_top_ooo.u_core_ooo_top.u_backend_top.u_csr.MPerformance_Monitor_inc[3]) & 
    //     (core_debugger_top_ooo.u_core_top_with_bpu.u_lsu.EX_LS_reg_store_valid & 
    //     (!core_debugger_top_ooo.u_core_top_with_bpu.u_lsu.write_finish));
    // // atomic
    // assign core_debugger_top_ooo.u_core_ooo_top.u_backend_top.u_csr.MPerformance_Monitor_inc[6] = 
    //     core_debugger_top_ooo.u_core_top_with_bpu.u_lsu.EX_LS_reg_execute_valid & 
    //     (!core_debugger_top_ooo.u_core_ooo_top.u_backend_top.u_csr.MPerformance_Monitor_inc[3]) & 
    //     (core_debugger_top_ooo.u_core_top_with_bpu.u_lsu.EX_LS_reg_atomic_valid & 
    //     (!core_debugger_top_ooo.u_core_top_with_bpu.u_lsu.atomic_finish));
    // // mul
    // assign core_debugger_top_ooo.u_core_ooo_top.u_backend_top.u_csr.MPerformance_Monitor_inc[7] = 
    //     core_debugger_top_ooo.u_core_top_with_bpu.u_exu.ID_EX_reg_decode_valid & 
    //     (!core_debugger_top_ooo.u_core_ooo_top.u_backend_top.u_csr.MPerformance_Monitor_inc[3]) &
    //     (!core_debugger_top_ooo.u_core_ooo_top.u_backend_top.u_csr.MPerformance_Monitor_inc[4]) &
    //     (!core_debugger_top_ooo.u_core_ooo_top.u_backend_top.u_csr.MPerformance_Monitor_inc[5]) &
    //     (!core_debugger_top_ooo.u_core_ooo_top.u_backend_top.u_csr.MPerformance_Monitor_inc[6]) &
    //     core_debugger_top_ooo.u_core_top_with_bpu.u_exu.ID_EX_reg_mul_valid & 
    //     (!core_debugger_top_ooo.u_core_top_with_bpu.u_exu.o_valid);
    // // div
    // assign core_debugger_top_ooo.u_core_ooo_top.u_backend_top.u_csr.MPerformance_Monitor_inc[8] = 
    //     core_debugger_top_ooo.u_core_top_with_bpu.u_exu.ID_EX_reg_decode_valid & 
    //     (!core_debugger_top_ooo.u_core_ooo_top.u_backend_top.u_csr.MPerformance_Monitor_inc[3]) &
    //     (!core_debugger_top_ooo.u_core_ooo_top.u_backend_top.u_csr.MPerformance_Monitor_inc[4]) &
    //     (!core_debugger_top_ooo.u_core_ooo_top.u_backend_top.u_csr.MPerformance_Monitor_inc[5]) &
    //     (!core_debugger_top_ooo.u_core_ooo_top.u_backend_top.u_csr.MPerformance_Monitor_inc[6]) &
    //     core_debugger_top_ooo.u_core_top_with_bpu.u_exu.ID_EX_reg_div_valid & 
    //     (!core_debugger_top_ooo.u_core_top_with_bpu.u_exu.o_valid);
    // // no inst
    // assign core_debugger_top_ooo.u_core_ooo_top.u_backend_top.u_csr.MPerformance_Monitor_inc[9] = 
    //     (!core_debugger_top_ooo.u_core_top_with_bpu.u_idu.IF_ID_reg_inst_valid) & 
    //     (!core_debugger_top_ooo.u_core_ooo_top.u_backend_top.u_csr.MPerformance_Monitor_inc[3]) &
    //     (!core_debugger_top_ooo.u_core_ooo_top.u_backend_top.u_csr.MPerformance_Monitor_inc[4]) &
    //     (!core_debugger_top_ooo.u_core_ooo_top.u_backend_top.u_csr.MPerformance_Monitor_inc[5]) &
    //     (!core_debugger_top_ooo.u_core_ooo_top.u_backend_top.u_csr.MPerformance_Monitor_inc[6]) &
    //     (!core_debugger_top_ooo.u_core_ooo_top.u_backend_top.u_csr.MPerformance_Monitor_inc[7]) &
    //     (!core_debugger_top_ooo.u_core_ooo_top.u_backend_top.u_csr.MPerformance_Monitor_inc[8]);
    // // jump/branch time
    // assign core_debugger_top_ooo.u_core_ooo_top.u_backend_top.u_csr.MPerformance_Monitor_inc[10] = 
    //     (core_debugger_top_ooo.u_core_top_with_bpu.ID_EX_reg_decode_valid & 
    //     core_debugger_top_ooo.u_core_top_with_bpu.EX_ID_decode_ready & 
    //     (core_debugger_top_ooo.u_core_top_with_bpu.ID_EX_reg_branch_valid | 
    //     core_debugger_top_ooo.u_core_top_with_bpu.ID_EX_reg_jump_valid));
    // // commit restore time
    // assign core_debugger_top_ooo.u_core_ooo_top.u_backend_top.u_csr.MPerformance_Monitor_inc[11] = 
    //     (core_debugger_top_ooo.u_core_top_with_bpu.commit_restore);
    // // jump but commit restore time
    // assign core_debugger_top_ooo.u_core_ooo_top.u_backend_top.u_csr.MPerformance_Monitor_inc[12] = 
    //     (core_debugger_top_ooo.u_core_top_with_bpu.commit_restore & 
    //     core_debugger_top_ooo.u_core_top_with_bpu.ID_EX_reg_jump_valid);
    // // jalr but commit restore time
    // assign core_debugger_top_ooo.u_core_ooo_top.u_backend_top.u_csr.MPerformance_Monitor_inc[13] = 
    //     (core_debugger_top_ooo.u_core_top_with_bpu.commit_restore & 
    //     core_debugger_top_ooo.u_core_top_with_bpu.ID_EX_reg_jump_valid & 
    //     core_debugger_top_ooo.u_core_top_with_bpu.ID_EX_reg_jump_jalr);
    // // ret but commit restore time
    // assign core_debugger_top_ooo.u_core_ooo_top.u_backend_top.u_csr.MPerformance_Monitor_inc[14] = 
    //     (core_debugger_top_ooo.u_core_top_with_bpu.commit_restore & 
    //     core_debugger_top_ooo.u_core_top_with_bpu.ID_EX_reg_jump_valid & 
    //     core_debugger_top_ooo.u_core_top_with_bpu.jump_is_ret);
    // // branch but commit restore time
    // assign core_debugger_top_ooo.u_core_ooo_top.u_backend_top.u_csr.MPerformance_Monitor_inc[15] = 
    //     (core_debugger_top_ooo.u_core_top_with_bpu.commit_restore & 
    //     core_debugger_top_ooo.u_core_top_with_bpu.ID_EX_reg_branch_valid);
end
endmodule
