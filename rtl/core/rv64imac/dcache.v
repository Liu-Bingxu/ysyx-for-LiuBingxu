module dcache#(
    parameter AXI_ID_SB = 3, 

    // Address width in bits
    parameter AXI_ADDR_W = 64,
    // ID width in bits
    parameter AXI_ID_W = 8,
    // Data width in bits
    parameter AXI_DATA_W = 64,

    parameter DCACHE_WAY = 2, 
    parameter DCACHE_GROUP = 4,
    parameter PMEM_START = 64'h8000_0000,
    parameter PMEM_END = 64'hFFFF_FFFF
)(
    input                           clk,
    input                           rst_n,
//interface with wbu 
    input  [1:0]                    current_priv_status,
    input         	                MXR,
    input         	                SUM,
    input         	                MPRV,
    input  [1:0]  	                MPP,
    input  [3:0]                    satp_mode,
    input  [15:0]                   satp_asid,
//all flush flag 
    input                           flush_flag,
    //TODO add flush i fsm and flush i logic
    input                           flush_i_valid,
    output                          flush_i_ready,
    input                           sflush_vma_valid,
    output                          sflush_vma_ready,
//interface with lsu
    //read addr channel
    output                          lsu_arready,
    input                           lsu_arvalid,
    input                           lsu_arlock,
    input  [2:0]                    lsu_arsize,
    input  [63:0]                   lsu_araddr,
    //read data channel
    output                          lsu_rvalid,
    input                           lsu_rready,
    output [1:0]                    lsu_rresp,
    output [63:0]                   lsu_rdata,
    //write addr channel
    input                           lsu_awvalid,
    output                          lsu_awready,
    input                           lsu_awlock,
    input  [2:0]                    lsu_awsize,
    input  [63:0]                   lsu_awaddr,
    //write data channel
    input                           lsu_wvalid,
    output                          lsu_wready,
    input [7:0]                     lsu_wstrb,
    input [63:0]                    lsu_wdata,
    //write resp channel
    output                          lsu_bvalid,
    input                           lsu_bready,
    output [1:0]                    lsu_bresp,
//interface with l2tlb
    output                          dmmu_miss_valid,
    input                           dmmu_miss_ready,
    output [63:0]                   vaddr_d,
    input                           pte_valid,
    output                          pte_ready_d,
    input  [127:0]                  pte,
    input                           pte_error,
    //read addr channel
    output                          mmu_arready,
    input                           mmu_arvalid,
    input  [63:0]                   mmu_araddr,
    //read data channel
    output                          mmu_rvalid,
    input                           mmu_rready,
    output [1:0]                    mmu_rresp,
    output [63:0]                   mmu_rdata,
//interface with axi
    //read addr channel
    output                          dcache_arvalid,
    input                           dcache_arready,
    output [AXI_ADDR_W    -1:0]     dcache_araddr,
    output [8             -1:0]     dcache_arlen,
    output [3             -1:0]     dcache_arsize,
    output [2             -1:0]     dcache_arburst,
    output                          dcache_arlock,
    output [AXI_ID_W      -1:0]     dcache_arid,
    //read data channel
    input                           dcache_rvalid,
    output                          dcache_rready,
    input  [AXI_ID_W      -1:0]     dcache_rid,
    input  [2             -1:0]     dcache_rresp,
    input  [AXI_DATA_W    -1:0]     dcache_rdata,
    input                           dcache_rlast,
    //write addr channel
    output                          dcache_awvalid,
    input                           dcache_awready,
    output [AXI_ADDR_W    -1:0]     dcache_awaddr,
    output [8             -1:0]     dcache_awlen,
    output [3             -1:0]     dcache_awsize,
    output [2             -1:0]     dcache_awburst,
    output                          dcache_awlock,
    output [AXI_ID_W      -1:0]     dcache_awid,
    //write data channel
    output                          dcache_wvalid,
    input                           dcache_wready,
    output                          dcache_wlast,
    output [AXI_DATA_W    -1:0]     dcache_wdata,
    output [AXI_DATA_W/8  -1:0]     dcache_wstrb,
    //write resp channel
    input                           dcache_bvalid,
    output                          dcache_bready,
    input  [AXI_ID_W      -1:0]     dcache_bid,
    input  [2             -1:0]     dcache_bresp
);

localparam DCACHE_TAG_GROUP = (DCACHE_GROUP % 2 == 0) ? DCACHE_GROUP / 2 : (DCACHE_GROUP / 2 + 1);
localparam DCACHE_GROUP_LEN = $clog2(DCACHE_GROUP);
localparam DCACHE_WAY_LEN   = $clog2(DCACHE_WAY);
localparam DCACHE_TAG_SIZE  = 64 - 10 - DCACHE_GROUP_LEN;

//sram interface
wire [63:0]                 dcache_line_valid[0:DCACHE_GROUP-1][0:DCACHE_WAY-1];
wire [63:0]                 dcache_line_dirty[0:DCACHE_GROUP-1][0:DCACHE_WAY-1];
wire [127:0]                sram_tag_rdata[0:DCACHE_TAG_GROUP-1][0:DCACHE_WAY-1];
wire [63:0]                 sram_tag[0:DCACHE_GROUP-1][0:DCACHE_WAY-1];
wire                        sram_tag_cen[0:DCACHE_TAG_GROUP-1];
wire                        sram_tag_wen[0:DCACHE_TAG_GROUP-1][0:DCACHE_WAY-1];
wire [127:0]                sram_tag_bwen;
wire [127:0]                sram_data_rdata[0:DCACHE_GROUP-1][0:DCACHE_WAY-1];
wire                        sram_data_cen[0:DCACHE_GROUP-1];
wire                        sram_data_wen[0:DCACHE_GROUP-1][0:DCACHE_WAY-1];
wire [127:0]                sram_data_bwen;
wire [127:0]                sram_data_bmask;
wire [63:0]                 sram_wmask;
wire [5:0]                  sram_addr;
wire [DCACHE_WAY_LEN-1:0]   rand_way;

//fifo signs 
reg  [2:0]                  lsu_fifo_cnt;
reg  [2:0]                  mmu_fifo_cnt;
wire                        fifo_wen;
reg                         lsu_fifo_ren;
wire                        mmu_fifo_ren;
//!依赖于lsu的特性：aw通道和w通道会同时握手
//+----------------------------------------------------------+
//|                     lsu_wdata                            |
//|__________________________________________________________|
//|140|...|133|132|...|69|  68  |67|66|65|  64  | 63 |...| 0 |
//|   WSTRB   |   WDATA  | LOCK |  SIZE  |  R/W |    ADDR    |
//+-----------|----------|------|--------|------|------------|
wire [140:0]                 lsu_fifo_wdata;
//+-------------------+
//|    mmu_wdata      |
//|___________________|
//|  64  | 63 |...| 0 |
//|  R/W |    ADDR    |
//+------|------------|
wire [64:0]                 mmu_fifo_wdata;
wire                	    lsu_fifo_empty;
wire [140:0] 	            lsu_fifo_rdata;
wire                	    mmu_fifo_empty;
wire [64:0] 	            mmu_fifo_rdata;

wire                        out_mmu_hit;
wire                        out_lsu_read_hit;
wire                        out_mmu_no_hit;
wire                        out_lsu_hit_write;
wire                        out_lsu_hit_write_cacheable;
wire                        out_lsu_no_hit_read_cacheable;
wire                        out_lsu_no_hit_read_not_cacheable;
wire                        out_lsu_no_hit_write;
wire                        out_fifo_wen;
wire                        out_fifo_ren;
//+---------------------------------------+
//|                out_rdata              |
//|_______________________________________|
//|    67   |  66  | 65 | 64 | 63 |...| 0 |
//| LSU/MMU |  R/W |   RESP  |    DATA    |
//+---------|------|---------|------------|
wire [67:0]                 out_fifo_wdata;
wire                	    out_fifo_empty;
wire [67:0] 	            out_fifo_rdata;
reg  [2:0]                  out_fifo_cnt;

//dmmu signs 
wire                        paddr_valid;
wire                        paddr_ready;
wire [63:0]                 paddr;
wire                        paddr_error;

//dcache fsm sign
localparam IDLE         = 4'h0;
localparam FLUSH        = 4'h1;
localparam WAIT_AW_W    = 4'h2;
localparam WAIT_AW      = 4'h3;
localparam WAIT_W       = 4'h4;
localparam WAIT_B       = 4'h5;
localparam WAIT_AR      = 4'h6;
localparam WAIT_R       = 4'h7;
localparam WAIT_ERROR   = 4'h8;
localparam WRITE_CACHE  = 4'h9;
localparam SEND_DATA    = 4'hA;
reg  [3:0]                  dcache_fsm;
reg                         flush_flag_reg;
reg                         dcache_mmu_flag;
reg  [1:0]                  dcache_resp_reg;
reg                         dcache_arvalid_reg;
reg                         dcache_awvalid_reg;
reg                         dcache_lock_reg;
reg  [63:0]                 dcache_addr_reg;
reg  [7:0]                  dcache_len_reg;
reg  [2:0]                  dcache_size_reg;
reg                         dcache_wvalid_reg;
reg  [63:0]                 dcache_wdata_reg;
reg  [7:0]                  dcache_wstrb_reg;
reg                         dcache_wlast_reg;
reg                         dcache_num;
wire [127:0]                sram_tag_wdata;
wire [127:0]                sram_data_wdata;
reg  [127:0]                axi_rdata;
reg  [63:0]                 dcache_rdata_reg;
reg                         dcache_line_wen;
wire [63:0]                 dcache_line_waddr;

//first stage register
wire                        first_stage_valid;
wire                        first_stage_ready;
wire                        first_stage_read_flag;
wire                        first_stage_lock_flag;
wire [2:0]                  first_stage_size_flag;
wire [63:0]                 first_stage_wdata_flag;
wire [7:0]                  first_stage_wstrb_flag;
wire [DCACHE_WAY_LEN-1:0]   rand_way_reg;
//TODO 需要评估时序，从valid一路到way_null需要许多组合电路，时序可能不太好。考虑删除其，仅通过随机选择（或者改用其他算法）替换路
wire [DCACHE_WAY_LEN-1:0]   way_null[0:DCACHE_WAY-1]/* verilator split_var */;
wire [DCACHE_WAY-1:0]       dcache_line_valid_way_bit/* verilator split_var */;
wire [DCACHE_WAY_LEN-1:0]   way_sel;
wire [DCACHE_WAY_LEN-1:0]   hit_way[0:DCACHE_WAY-1]/* verilator split_var */;
wire [127:0]                sram_data_way_reg[0:DCACHE_WAY-1];
wire [63:0]                 sram_tag_way_reg[0:DCACHE_WAY-1];
wire [63:0]                 dcache_line_valid_way_reg[0:DCACHE_WAY-1];
wire [63:0]                 dcache_line_dirty_way_reg[0:DCACHE_WAY-1];

wire                        way_flag_set;
wire                        way_flag_clr;
wire                        way_flag_wen;
wire                        way_flag_nxt;
wire                        way_flag;
wire [127:0]                sram_data_way_use[0:DCACHE_WAY-1];
wire [63:0]                 sram_tag_way_use[0:DCACHE_WAY-1];
wire [63:0]                 dcache_line_valid_way_use[0:DCACHE_WAY-1];
wire [63:0]                 dcache_line_dirty_way_use[0:DCACHE_WAY-1];

wire [127:0]                sram_data_way[0:DCACHE_WAY-1];
wire [63:0]                 sram_tag_way[0:DCACHE_WAY-1];
wire [63:0]                 dcache_line_valid_way[0:DCACHE_WAY-1];
wire [63:0]                 dcache_line_dirty_way[0:DCACHE_WAY-1];

wire [DCACHE_WAY-1:0]       sram_way_sel;
wire [DCACHE_WAY-1:0]       sram_way_sel_dirty;
wire [191:0]                sram_data_sel;

//mmu first stage register
wire                        first_stage_mmu_valid;
wire                        first_stage_mmu_ready;
wire [63:0]                 dcache_line_waddr_mmu;
wire [DCACHE_WAY_LEN-1:0]   rand_way_mmu_reg;
//TODO 需要评估时序，从valid一路到way_null需要许多组合电路，时序可能不太好。考虑删除其，仅通过随机选择（或者改用其他算法）替换路
wire [DCACHE_WAY_LEN-1:0]   way_null_mmu[0:DCACHE_WAY-1]/* verilator split_var */;
wire [DCACHE_WAY-1:0]       dcache_line_valid_way_bit_mmu/* verilator split_var */;
wire [DCACHE_WAY_LEN-1:0]   way_sel_mmu;
wire [127:0]                sram_data_way_mmu_reg[0:DCACHE_WAY-1];
wire [63:0]                 sram_tag_way_mmu_reg[0:DCACHE_WAY-1];
wire [63:0]                 dcache_line_valid_way_mmu_reg[0:DCACHE_WAY-1];
wire [63:0]                 dcache_line_dirty_way_mmu_reg[0:DCACHE_WAY-1];

wire                        way_flag_mmu_set;
wire                        way_flag_mmu_clr;
wire                        way_flag_mmu_wen;
wire                        way_flag_mmu_nxt;
wire                        way_flag_mmu;
wire [127:0]                sram_data_way_mmu_use[0:DCACHE_WAY-1];
wire [63:0]                 sram_tag_way_mmu_use[0:DCACHE_WAY-1];
wire [63:0]                 dcache_line_valid_way_mmu_use[0:DCACHE_WAY-1];
wire [63:0]                 dcache_line_dirty_way_mmu_use[0:DCACHE_WAY-1];

wire [127:0]                sram_data_way_mmu[0:DCACHE_WAY-1];
wire [63:0]                 sram_tag_way_mmu[0:DCACHE_WAY-1];
wire [63:0]                 dcache_line_valid_way_mmu[0:DCACHE_WAY-1];
wire [63:0]                 dcache_line_dirty_way_mmu[0:DCACHE_WAY-1];

wire [DCACHE_WAY-1:0]       sram_way_sel_mmu;
wire [191:0]                sram_data_sel_mmu;
//**********************************************************************************************
//?dcache sram
genvar dcache_group_index;
genvar dcache_way_index;
generate
    for(dcache_group_index = 0; dcache_group_index < DCACHE_GROUP; dcache_group_index = dcache_group_index + 1)begin: dcache_group_sram
        for(dcache_way_index = 0; dcache_way_index < DCACHE_WAY; dcache_way_index = dcache_way_index + 1)begin: dcache_way_sram
            S011HD1P_X32Y2D128_BW u_S011HD1P_X32Y2D128_BW_data(
                .Q    	( sram_data_rdata[dcache_group_index][dcache_way_index]     ),
                .CLK  	( clk                                                       ),
                .CEN  	( sram_data_cen[dcache_group_index]                         ),
                .WEN  	( sram_data_wen[dcache_group_index][dcache_way_index]       ),
                .BWEN 	( sram_data_bwen                                            ),
                .A    	( sram_addr                                                 ),
                .D    	( sram_data_wdata                                           )
            );
            if(DCACHE_GROUP == 1)begin
                assign sram_data_wen[dcache_group_index][dcache_way_index]          = (!dcache_line_wen) | (((dcache_way_index != way_sel) | dcache_mmu_flag) & ((dcache_way_index != way_sel_mmu) | (!dcache_mmu_flag)));
                assign sram_data_way[dcache_way_index]                              = sram_data_rdata[dcache_group_index][dcache_way_index];
                assign sram_tag_way[dcache_way_index]                               = sram_tag[dcache_group_index][dcache_way_index];
                assign dcache_line_valid_way[dcache_way_index]                      = dcache_line_valid[dcache_group_index][dcache_way_index];
                assign dcache_line_dirty_way[dcache_way_index]                      = dcache_line_dirty[dcache_group_index][dcache_way_index];

                assign sram_data_way_mmu[dcache_way_index]                          = sram_data_rdata[dcache_group_index][dcache_way_index];
                assign sram_tag_way_mmu[dcache_way_index]                           = sram_tag[dcache_group_index][dcache_way_index];
                assign dcache_line_valid_way_mmu[dcache_way_index]                  = dcache_line_valid[dcache_group_index][dcache_way_index];
                assign dcache_line_dirty_way_mmu[dcache_way_index]                  = dcache_line_dirty[dcache_group_index][dcache_way_index];
            end
            else begin
                assign sram_data_wen[dcache_group_index][dcache_way_index]          = (((dcache_way_index != way_sel) | (dcache_group_index != dcache_line_waddr[9 + DCACHE_GROUP_LEN:10]) | dcache_mmu_flag) & 
                                                                                        ((dcache_way_index != way_sel_mmu) | (dcache_group_index != dcache_line_waddr_mmu[9 + DCACHE_GROUP_LEN:10]) | (!dcache_mmu_flag))) |
                                                                                        (!dcache_line_wen);
                assign sram_data_way[dcache_way_index]                              = sram_data_rdata[dcache_line_waddr[9 + DCACHE_GROUP_LEN:10]][dcache_way_index];
                assign sram_tag_way[dcache_way_index]                               = sram_tag[dcache_line_waddr[9 + DCACHE_GROUP_LEN:10]][dcache_way_index];
                assign dcache_line_valid_way[dcache_way_index]                      = dcache_line_valid[dcache_line_waddr[9 + DCACHE_GROUP_LEN:10]][dcache_way_index];
                assign dcache_line_dirty_way[dcache_way_index]                      = dcache_line_dirty[dcache_line_waddr[9 + DCACHE_GROUP_LEN:10]][dcache_way_index];

                assign sram_data_way_mmu[dcache_way_index]                          = sram_data_rdata[dcache_line_waddr_mmu[9 + DCACHE_GROUP_LEN:10]][dcache_way_index];
                assign sram_tag_way_mmu[dcache_way_index]                           = sram_tag[dcache_line_waddr_mmu[9 + DCACHE_GROUP_LEN:10]][dcache_way_index];
                assign dcache_line_valid_way_mmu[dcache_way_index]                  = dcache_line_valid[dcache_line_waddr_mmu[9 + DCACHE_GROUP_LEN:10]][dcache_way_index];
                assign dcache_line_dirty_way_mmu[dcache_way_index]                  = dcache_line_dirty[dcache_line_waddr_mmu[9 + DCACHE_GROUP_LEN:10]][dcache_way_index];
            end
            if(dcache_group_index % 2 == 0)begin
                S011HD1P_X32Y2D128_BW u_S011HD1P_X32Y2D128_BW_tag(
                    .Q    	( sram_tag_rdata[dcache_group_index/2][dcache_way_index]    ),
                    .CLK  	( clk                                                       ),
                    .CEN  	( sram_tag_cen[dcache_group_index/2]                        ),
                    .WEN  	( sram_tag_wen[dcache_group_index/2][dcache_way_index]      ),
                    .BWEN 	( sram_tag_bwen                                             ),
                    .A    	( sram_addr                                                 ),
                    .D    	( sram_tag_wdata                                            )
                );
                if((dcache_group_index + 1) >= DCACHE_GROUP)begin
                    assign sram_tag_cen[dcache_group_index/2]                       = sram_data_cen[dcache_group_index];
                    assign sram_tag_wen[dcache_group_index/2][dcache_way_index]     = sram_data_wen[dcache_group_index][dcache_way_index];
                end
                else begin
                    assign sram_tag_cen[dcache_group_index/2]                       = sram_data_cen[dcache_group_index]                     & sram_data_cen[dcache_group_index+1];
                    assign sram_tag_wen[dcache_group_index/2][dcache_way_index]     = sram_data_wen[dcache_group_index][dcache_way_index]   & sram_data_wen[dcache_group_index+1][dcache_way_index];
                end
            end
            if(dcache_group_index % 2 == 0)begin
                assign sram_tag[dcache_group_index][dcache_way_index]               = sram_tag_rdata[dcache_group_index/2][dcache_way_index][63:0];
            end
            else begin
                assign sram_tag[dcache_group_index][dcache_way_index]               = sram_tag_rdata[dcache_group_index/2][dcache_way_index][127:64];
            end
            FF_D_with_addr #(
                .ADDR_LEN   ( 6 ),
                .RST_DATA   ( 0 )
            )u_dcache_line_valid(
                .clk        ( clk                                                       ),
                .rst_n      ( rst_n                                                     ),
                .syn_rst    ( flush_i_valid                                             ),
                .wen        ( !sram_data_wen[dcache_group_index][dcache_way_index]      ),
                .addr       ( sram_addr                                                 ),
                .data_in    ( dcache_fsm != FLUSH                                       ),
                .data_out   ( dcache_line_valid[dcache_group_index][dcache_way_index]   )
            );
            FF_D_with_addr #(
                .ADDR_LEN   ( 6 ),
                .RST_DATA   ( 0 )
            )u_dcache_line_dirty(
                .clk        ( clk                                                                   ),
                .rst_n      ( rst_n                                                                 ),
                .syn_rst    ( flush_i_valid                                                         ),
                .wen        ( !sram_data_wen[dcache_group_index][dcache_way_index]                  ),
                .addr       ( sram_addr                                                             ),
                .data_in    ( (dcache_fsm != FLUSH) & (!dcache_mmu_flag) & (!first_stage_read_flag) ),
                .data_out   ( dcache_line_dirty[dcache_group_index][dcache_way_index]               )
            );
            if(dcache_group_index == 0)begin
                assign sram_way_sel[dcache_way_index]                           = (sram_tag_way_use[dcache_way_index][63:64-DCACHE_TAG_SIZE] == paddr[63:64-DCACHE_TAG_SIZE]) & 
                                                                                    dcache_line_valid_way_use[dcache_way_index][dcache_line_waddr[9:4]]; 
                assign sram_way_sel_dirty[dcache_way_index]                     = sram_way_sel[dcache_way_index] & dcache_line_dirty_way_use[dcache_way_index][dcache_line_waddr[9:4]];
                if(dcache_way_index == 0)begin
                    assign hit_way[dcache_way_index]                            = (sram_way_sel[dcache_way_index]) ? dcache_way_index : 0;
                end
                else begin
                    assign hit_way[dcache_way_index]                            = (sram_way_sel[dcache_way_index]) ? dcache_way_index : hit_way[dcache_way_index - 1];
                end

                assign sram_way_sel_mmu[dcache_way_index]                       = (sram_tag_way_mmu_use[dcache_way_index][63:64-DCACHE_TAG_SIZE] == dcache_line_waddr_mmu[63:64-DCACHE_TAG_SIZE]) & 
                                                                                    dcache_line_valid_way_mmu_use[dcache_way_index][dcache_line_waddr_mmu[9:4]]; 
            end
            if(dcache_group_index == 0)begin
                FF_D_without_asyn_rst #(128)  u_sram_data_way            (clk,way_flag_set,sram_data_way[dcache_way_index],sram_data_way_reg[dcache_way_index]);
                FF_D_without_asyn_rst #(64)   u_sram_tag_way             (clk,way_flag_set,sram_tag_way[dcache_way_index] ,sram_tag_way_reg[dcache_way_index] );
                FF_D_without_asyn_rst #(64)   u_dcache_line_valid_way    (clk,way_flag_set,dcache_line_valid_way[dcache_way_index],dcache_line_valid_way_reg[dcache_way_index]);
                FF_D_without_asyn_rst #(64)   u_dcache_line_dirty_way    (clk,way_flag_set,dcache_line_dirty_way[dcache_way_index],dcache_line_dirty_way_reg[dcache_way_index]);
                assign sram_data_way_use[dcache_way_index]            = (way_flag) ? sram_data_way_reg[dcache_way_index] : sram_data_way[dcache_way_index];
                assign sram_tag_way_use[dcache_way_index]             = (way_flag) ? sram_tag_way_reg[dcache_way_index] : sram_tag_way[dcache_way_index];
                assign dcache_line_valid_way_use[dcache_way_index]    = (way_flag) ? dcache_line_valid_way_reg[dcache_way_index] : dcache_line_valid_way[dcache_way_index];
                assign dcache_line_dirty_way_use[dcache_way_index]    = (way_flag) ? dcache_line_dirty_way_reg[dcache_way_index] : dcache_line_dirty_way[dcache_way_index];
                if(dcache_way_index == 0)begin
                    assign dcache_line_valid_way_bit[dcache_way_index]    = dcache_line_valid_way_use[dcache_way_index][dcache_line_waddr[9:4]];
                    assign way_null[dcache_way_index]                     = (!dcache_line_valid_way_bit[dcache_way_index]) ? dcache_way_index : 0;
                end
                else begin
                    assign dcache_line_valid_way_bit[dcache_way_index]    = dcache_line_valid_way_use[dcache_way_index][dcache_line_waddr[9:4]] | (!(&dcache_line_valid_way_bit[dcache_way_index - 1 : 0]));
                    assign way_null[dcache_way_index]                     = (!dcache_line_valid_way_bit[dcache_way_index]) ? dcache_way_index : way_null[dcache_way_index - 1];
                end

                FF_D_without_asyn_rst #(128)  u_sram_data_way_mmu            (clk,way_flag_mmu_set,sram_data_way_mmu[dcache_way_index],sram_data_way_mmu_reg[dcache_way_index]);
                FF_D_without_asyn_rst #(64)   u_sram_tag_way_mmu             (clk,way_flag_mmu_set,sram_tag_way_mmu[dcache_way_index] ,sram_tag_way_mmu_reg[dcache_way_index] );
                FF_D_without_asyn_rst #(64)   u_dcache_line_valid_way_mmu    (clk,way_flag_mmu_set,dcache_line_valid_way_mmu[dcache_way_index],dcache_line_valid_way_mmu_reg[dcache_way_index]);
                FF_D_without_asyn_rst #(64)   u_dcache_line_dirty_way_mmu    (clk,way_flag_mmu_set,dcache_line_dirty_way_mmu[dcache_way_index],dcache_line_dirty_way_mmu_reg[dcache_way_index]);
                assign sram_data_way_mmu_use[dcache_way_index]            = (way_flag_mmu) ? sram_data_way_mmu_reg[dcache_way_index] : sram_data_way_mmu[dcache_way_index];
                assign sram_tag_way_mmu_use[dcache_way_index]             = (way_flag_mmu) ? sram_tag_way_mmu_reg[dcache_way_index] : sram_tag_way_mmu[dcache_way_index];
                assign dcache_line_valid_way_mmu_use[dcache_way_index]    = (way_flag_mmu) ? dcache_line_valid_way_mmu_reg[dcache_way_index] : dcache_line_valid_way_mmu[dcache_way_index];
                assign dcache_line_dirty_way_mmu_use[dcache_way_index]    = (way_flag_mmu) ? dcache_line_dirty_way_mmu_reg[dcache_way_index] : dcache_line_dirty_way_mmu[dcache_way_index];
                if(dcache_way_index == 0)begin
                    assign dcache_line_valid_way_bit_mmu[dcache_way_index]    = dcache_line_valid_way_mmu_use[dcache_way_index][dcache_line_waddr_mmu[9:4]];
                    assign way_null_mmu[dcache_way_index]                     = (!dcache_line_valid_way_bit_mmu[dcache_way_index]) ? dcache_way_index : 0;
                end
                else begin
                    assign dcache_line_valid_way_bit_mmu[dcache_way_index]    = dcache_line_valid_way_mmu_use[dcache_way_index][dcache_line_waddr_mmu[9:4]] | (!(&dcache_line_valid_way_bit_mmu[dcache_way_index - 1 : 0]));
                    assign way_null_mmu[dcache_way_index]                     = (!dcache_line_valid_way_bit_mmu[dcache_way_index]) ? dcache_way_index : way_null_mmu[dcache_way_index - 1];
                end
            end
        end
        if(DCACHE_GROUP == 1)begin
            assign sram_data_cen[dcache_group_index]                            =   (!dcache_line_wen) & (lsu_fifo_empty) & (!(mmu_arvalid & mmu_arready));
        end
        else begin
            assign sram_data_cen[dcache_group_index]                            =   (( lsu_fifo_empty ) | (dcache_group_index != lsu_fifo_rdata[9 + DCACHE_GROUP_LEN:10]) | dcache_line_wen | (mmu_arvalid & mmu_arready)) & 
                                                                                    ((!(mmu_arvalid & mmu_arready)) | (dcache_group_index != mmu_araddr[9 + DCACHE_GROUP_LEN:10]) | dcache_line_wen) & 
                                                                                    ((!dcache_line_wen) | (dcache_group_index != dcache_line_waddr[9 + DCACHE_GROUP_LEN:10]) | dcache_mmu_flag) &
                                                                                    ((!dcache_line_wen) | (dcache_group_index != dcache_line_waddr_mmu[9 + DCACHE_GROUP_LEN:10]) | (!dcache_mmu_flag)) ;
        end
    end
endgenerate
rand_lfsr_8_bit #(
    .USING_LEN(DCACHE_WAY_LEN)
)u_rand_lfsr_8_bit_get_rand_way_num(
    .clk   	( clk           ),
    .rst_n 	( rst_n         ),
    .out   	( rand_way      )
);
FF_D_without_asyn_rst #(64)   u_dcache_line_waddr           (clk,lsu_fifo_ren,lsu_fifo_rdata[63:0],dcache_line_waddr);
FF_D_without_asyn_rst #(64)   u_dcache_line_waddr_mmu       (clk,mmu_arready,mmu_araddr,dcache_line_waddr_mmu);
assign sram_addr                = (dcache_line_wen) ? ((dcache_mmu_flag) ? dcache_line_waddr_mmu[9:4] : dcache_line_waddr[9:4]) : 
                                    ((mmu_arvalid & mmu_arready) ? mmu_araddr[9:4] : lsu_fifo_rdata[9:4]);
assign sram_tag_wdata           = (dcache_mmu_flag) ? {dcache_line_waddr_mmu, dcache_line_waddr_mmu} : {paddr, paddr};
if(DCACHE_GROUP == 1)begin
    assign sram_tag_bwen        = 128'h0;
end
else begin
    assign sram_tag_bwen        = (dcache_mmu_flag) ? ((dcache_line_waddr_mmu[10]) ? {{64{1'b0}}, {64{1'b1}}} : {{64{1'b1}}, {64{1'b0}}}) :
                                                    ((dcache_line_waddr[10]) ? {{64{1'b0}}, {64{1'b1}}} : {{64{1'b1}}, {64{1'b0}}});
end
assign way_flag_set = first_stage_valid & (!first_stage_ready) & (!way_flag);
assign way_flag_clr = first_stage_ready;
assign way_flag_wen = (way_flag_set | way_flag_clr);
assign way_flag_nxt = (way_flag_set | (!way_flag_clr));
FF_D_with_syn_rst #(
    .DATA_LEN 	(1  ),
    .RST_DATA 	(0  ))
u_way_flag(
    .clk      	(clk            ),
    .rst_n    	(rst_n          ),
    .syn_rst  	(flush_flag     ),
    .wen      	(way_flag_wen   ),
    .data_in  	(way_flag_nxt   ),
    .data_out 	(way_flag       )
);
assign way_sel                  = (|sram_way_sel) ? hit_way[DCACHE_WAY - 1] : ((&dcache_line_valid_way_bit) ? rand_way_reg : way_null[DCACHE_WAY - 1]);
assign sram_data_sel            = dcache_line_sel(sram_way_sel, sram_data_way_use, sram_tag_way_use);

assign way_flag_mmu_set = first_stage_mmu_valid & (!first_stage_mmu_ready) & (!way_flag_mmu);
assign way_flag_mmu_clr = first_stage_mmu_ready;
assign way_flag_mmu_wen = (way_flag_mmu_set | way_flag_mmu_clr);
assign way_flag_mmu_nxt = (way_flag_mmu_set | (!way_flag_mmu_clr));
FF_D_with_syn_rst #(
    .DATA_LEN 	(1  ),
    .RST_DATA 	(0  ))
u_way_flag_mmu(
    .clk      	(clk                ),
    .rst_n    	(rst_n              ),
    .syn_rst  	(flush_flag         ),
    .wen      	(way_flag_mmu_wen   ),
    .data_in  	(way_flag_mmu_nxt   ),
    .data_out 	(way_flag_mmu       )
);
assign way_sel_mmu       = (&dcache_line_valid_way_bit_mmu) ? rand_way_mmu_reg : way_null_mmu[DCACHE_WAY - 1];
assign sram_data_sel_mmu = dcache_line_sel(sram_way_sel_mmu, sram_data_way_mmu_use, sram_tag_way_mmu_use);
//**********************************************************************************************
ifu_fifo #(
    .DATA_LEN   	( 141 ),
    .AddR_Width 	( 3   ))
lsu_ch_fifo(
    .clk    	( clk               ),
    .rst_n  	( rst_n             ),
    .Wready 	( fifo_wen          ),
    .Rready 	( lsu_fifo_ren      ),
    .flush  	( flush_flag        ),
    .wdata  	( lsu_fifo_wdata    ),
    .empty  	( lsu_fifo_empty    ),
    .rdata  	( lsu_fifo_rdata    )
);

ifu_fifo #(
    .DATA_LEN   	( 65  ),
    .AddR_Width 	( 3   ))
mmu_fifo(
    .clk    	( clk               ),
    .rst_n  	( rst_n             ),
    .Wready 	( fifo_wen          ),
    .Rready 	( mmu_fifo_ren      ),
    .flush  	( flush_flag        ),
    .wdata  	( mmu_fifo_wdata    ),
    .empty  	( mmu_fifo_empty    ),
    .rdata  	( mmu_fifo_rdata    )
);

ifu_fifo #(
    .DATA_LEN   	( 68  ),
    .AddR_Width 	( 3   ))
out_fifo(
    .clk    	( clk               ),
    .rst_n  	( rst_n             ),
    .Wready 	( out_fifo_wen      ),
    .Rready 	( out_fifo_ren      ),
    .flush  	( flush_flag        ),
    .wdata  	( out_fifo_wdata    ),
    .empty  	( out_fifo_empty    ),
    .rdata  	( out_fifo_rdata    )
);

FF_D_with_syn_rst #(
    .DATA_LEN 	(1  ),
    .RST_DATA 	(0  ))
u_first_stage_valid(
    .clk      	(clk                                        ),
    .rst_n    	(rst_n                                      ),
    .syn_rst  	(flush_flag                                 ),
    .wen      	(first_stage_ready | (!first_stage_valid)   ),
    .data_in  	(lsu_fifo_ren                               ),
    .data_out 	(first_stage_valid                          )
);
assign first_stage_ready = out_fifo_wen & (!((dcache_fsm == IDLE) & first_stage_mmu_valid & (|sram_way_sel_mmu))) & (!dcache_mmu_flag);
FF_D_without_asyn_rst #(1)   u_first_stage_read_flag      (clk,lsu_fifo_ren,lsu_fifo_rdata[64],first_stage_read_flag);
FF_D_without_asyn_rst #(1)   u_first_stage_lock_flag      (clk,lsu_fifo_ren,lsu_fifo_rdata[68],first_stage_lock_flag);
FF_D_without_asyn_rst #(3)   u_first_stage_size_flag      (clk,lsu_fifo_ren,lsu_fifo_rdata[67:65],first_stage_size_flag);
FF_D_without_asyn_rst #(64)  u_first_stage_wdata_flag     (clk,lsu_fifo_ren,lsu_fifo_rdata[132:69],first_stage_wdata_flag);
FF_D_without_asyn_rst #(8)   u_first_stage_wstrb_flag     (clk,lsu_fifo_ren,lsu_fifo_rdata[140:133],first_stage_wstrb_flag);

FF_D_without_asyn_rst #(
    .DATA_LEN 	(DCACHE_WAY_LEN  ))
u_rand_way_reg(
    .clk      	(clk                                        ),
    .wen      	(first_stage_ready | (!first_stage_valid)   ),
    .data_in  	(rand_way                                   ),
    .data_out 	(rand_way_reg                               )
);

FF_D_with_syn_rst #(
    .DATA_LEN 	(1  ),
    .RST_DATA 	(0  ))
u_first_stage_valid_mmu(
    .clk      	(clk                                                ),
    .rst_n    	(rst_n                                              ),
    .syn_rst  	(flush_flag                                         ),
    .wen      	(first_stage_mmu_ready | (!first_stage_mmu_valid)   ),
    .data_in  	(mmu_arready                                        ),
    .data_out 	(first_stage_mmu_valid                              )
);
assign first_stage_mmu_ready = out_fifo_wen & (((dcache_fsm == IDLE) & first_stage_mmu_valid & (|sram_way_sel_mmu)) | dcache_mmu_flag);

FF_D_without_asyn_rst #(
    .DATA_LEN 	(DCACHE_WAY_LEN  ))
u_rand_way_mmu_reg(
    .clk      	(clk                                                ),
    .wen      	(first_stage_mmu_ready | (!first_stage_mmu_valid)   ),
    .data_in  	(rand_way                                           ),
    .data_out 	(rand_way_mmu_reg                                   )
);

always @(posedge clk or negedge rst_n) begin
    if(!rst_n)begin
        lsu_fifo_cnt <= 3'h0;
    end
    else if(flush_flag)begin
        lsu_fifo_cnt <= 3'h0;
    end
    else if(lsu_fifo_ren & (!fifo_wen))begin
        lsu_fifo_cnt <= lsu_fifo_cnt + 3'h7;
    end
    else if((!lsu_fifo_ren) & fifo_wen)begin
        lsu_fifo_cnt <= lsu_fifo_cnt + 3'h1;
    end
end
always @(posedge clk or negedge rst_n) begin
    if(!rst_n)begin
        mmu_fifo_cnt <= 3'h0;
    end
    else if(flush_flag)begin
        mmu_fifo_cnt <= 3'h0;
    end
    else if(mmu_fifo_ren & (!fifo_wen))begin
        mmu_fifo_cnt <= mmu_fifo_cnt + 3'h7;
    end
    else if((!mmu_fifo_ren) & fifo_wen)begin
        mmu_fifo_cnt <= mmu_fifo_cnt + 3'h1;
    end
end
always @(posedge clk or negedge rst_n) begin
    if(!rst_n)begin
        out_fifo_cnt <= 3'h0;
    end
    else if(flush_flag)begin
        out_fifo_cnt <= 3'h0;
    end
    else if(out_fifo_ren & (!out_fifo_wen))begin
        out_fifo_cnt <= out_fifo_cnt + 3'h7;
    end
    else if((!out_fifo_ren) & out_fifo_wen)begin
        out_fifo_cnt <= out_fifo_cnt + 3'h1;
    end
end
//? read first update 
// dcache_arvalid_reg  <= 1'b0;
// dcache_len_reg      <= 8'h0;
// dcache_size_reg     <= 3'h0;
// dcache_lock_reg     <= 1'b0;
// dcache_num          <= 1'b0;
// dcache_addr_reg     <= 64'b0;
//? write first update
// dcache_awvalid_reg  <= 1'b0;
// dcache_wvalid_reg   <= 1'b0;
// dcache_len_reg      <= 8'h0;
// dcache_size_reg     <= 3'h0;
// dcache_lock_reg     <= 1'b0;
// dcache_addr_reg     <= 64'b0;
// dcache_wdata_reg    <= 64'b0;
// dcache_wstrb_reg    <= 8'b0;
// dcache_wlast_reg    <= 1'b0;
//? write second update 
// dcache_wdata_reg    <= 64'b0;
// dcache_wstrb_reg    <= 8'b0;
// dcache_wlast_reg    <= 1'b0;
//? other
// dcache_line_wen     <= 1'b0;
// dcache_resp_reg     <= 2'h0;
//!fsm
always @(posedge clk or negedge rst_n) begin
    if(!rst_n)begin
        dcache_fsm          <= IDLE;
        dcache_mmu_flag     <= 1'b0;
        dcache_arvalid_reg  <= 1'b0;
        dcache_awvalid_reg  <= 1'b0;
        dcache_wvalid_reg   <= 1'b0;
        dcache_len_reg      <= 8'h0;
        dcache_size_reg     <= 3'h0;
        dcache_lock_reg     <= 1'b0;
        dcache_num          <= 1'b0;
        dcache_addr_reg     <= 64'b0;
        dcache_wdata_reg    <= 64'b0;
        dcache_wstrb_reg    <= 8'b0;
        dcache_wlast_reg    <= 1'b0;
        dcache_line_wen     <= 1'b0;
        dcache_resp_reg     <= 2'h0;
    end
    else begin
        case (dcache_fsm)
            IDLE: begin
                if(flush_flag)begin
                    dcache_fsm          <= IDLE;
                    dcache_mmu_flag     <= 1'b0;
                    dcache_arvalid_reg  <= 1'b0;
                    dcache_awvalid_reg  <= 1'b0;
                    dcache_wvalid_reg   <= 1'b0;
                    dcache_len_reg      <= 8'h0;
                    dcache_size_reg     <= 3'h0;
                    dcache_lock_reg     <= 1'b0;
                    dcache_num          <= 1'b0;
                    dcache_addr_reg     <= 64'b0;
                    dcache_wdata_reg    <= 64'b0;
                    dcache_wstrb_reg    <= 8'b0;
                    dcache_wlast_reg    <= 1'b0;
                    dcache_line_wen     <= 1'b0;
                    dcache_resp_reg     <= 2'h0;
                end
                //? hit cacheable mmu
                else if(first_stage_mmu_valid & (|sram_way_sel_mmu))begin
                    dcache_fsm          <= IDLE;
                end
                //? not hit; cacheable; dirty mmu
                else if(first_stage_mmu_valid & (!(|sram_way_sel_mmu)) & dcache_line_dirty_way_mmu_use[way_sel_mmu][dcache_line_waddr_mmu[9:4]])begin
                    dcache_fsm          <= WAIT_AW_W;
                    dcache_mmu_flag     <= 1'b1;
                    dcache_awvalid_reg  <= 1'b1;
                    dcache_wvalid_reg   <= 1'b1;
                    dcache_len_reg      <= 8'h1;
                    dcache_size_reg     <= 3'h3;
                    dcache_lock_reg     <= 1'b0;
                    dcache_addr_reg     <= {sram_tag_way_mmu_use[way_sel_mmu][63:4], 4'h0};
                    dcache_wdata_reg    <= sram_data_way_mmu_use[way_sel_mmu][63:0];
                    dcache_wstrb_reg    <= 8'hff;
                    dcache_wlast_reg    <= 1'b0;
                end
                // //? not hit; cacheable; not dirty mmu
                else if(first_stage_mmu_valid & (!(|sram_way_sel_mmu)) & (!dcache_line_dirty_way_mmu_use[way_sel_mmu][dcache_line_waddr_mmu[9:4]]))begin
                    dcache_fsm          <= WAIT_AR;
                    dcache_mmu_flag     <= 1'b1;
                    dcache_arvalid_reg  <= 1'b1;
                    dcache_len_reg      <= 8'h1;
                    dcache_size_reg     <= 3'h3;
                    dcache_lock_reg     <= 1'b0;
                    dcache_num          <= 1'b1;
                    dcache_addr_reg     <= {dcache_line_waddr_mmu[63:4], 4'h0};
                end
                //? hit cacheable write
                else if(first_stage_valid & paddr_valid & (!paddr_error) & (!first_stage_lock_flag) & (|sram_way_sel) & (!first_stage_read_flag))begin
                    dcache_fsm          <= WRITE_CACHE;
                    dcache_line_wen     <= 1'b1;
                end
                //? hit cacheable lock dirty
                else if(first_stage_valid & paddr_valid & (!paddr_error) & first_stage_lock_flag & (|sram_way_sel) & (|sram_way_sel_dirty))begin
                    dcache_fsm          <= WAIT_AW_W;
                    dcache_awvalid_reg  <= 1'b1;
                    dcache_wvalid_reg   <= 1'b1;
                    dcache_len_reg      <= 8'h1;
                    dcache_size_reg     <= 3'h3;
                    dcache_lock_reg     <= 1'b0;
                    dcache_addr_reg     <= {sram_data_sel[191:132], 4'h0};
                    dcache_wdata_reg    <= sram_data_sel[63:0];
                    dcache_wstrb_reg    <= 8'hff;
                    dcache_wlast_reg    <= 1'b0;
                end
                //? hit cacheable lock not dirty
                else if(first_stage_valid & paddr_valid & (!paddr_error) & first_stage_lock_flag & (|sram_way_sel))begin
                    dcache_fsm          <= FLUSH;
                    dcache_line_wen     <= 1'b1;
                end
                //? not hit; lock write
                else if(first_stage_valid & paddr_valid & (!paddr_error) & first_stage_lock_flag & (!(|sram_way_sel)) & (!first_stage_read_flag))begin
                    dcache_fsm          <= WAIT_AW_W;
                    dcache_awvalid_reg  <= 1'b1;
                    dcache_wvalid_reg   <= 1'b1;
                    dcache_len_reg      <= 8'h0;
                    dcache_size_reg     <= first_stage_size_flag;
                    dcache_lock_reg     <= 1'b1;
                    dcache_addr_reg     <= paddr;
                    dcache_wdata_reg    <= first_stage_wdata_flag;
                    dcache_wstrb_reg    <= first_stage_wstrb_flag;
                    dcache_wlast_reg    <= 1'b1;
                end
                //? not hit; lock read
                else if(first_stage_valid & paddr_valid & (!paddr_error) & first_stage_lock_flag & (!(|sram_way_sel)) & first_stage_read_flag)begin
                    dcache_fsm          <= WAIT_AR;
                    dcache_arvalid_reg  <= 1'b1;
                    dcache_len_reg      <= 8'h0;
                    dcache_size_reg     <= first_stage_size_flag;
                    dcache_lock_reg     <= 1'b1;
                    dcache_num          <= 1'b0;
                    dcache_addr_reg     <= paddr;
                end
                //? not hit; not cacheable; write
                else if(first_stage_valid & paddr_valid & (!paddr_error) & ((paddr > PMEM_END) | (paddr < PMEM_START)) & (!first_stage_read_flag))begin
                    dcache_fsm          <= WAIT_AW_W;
                    dcache_awvalid_reg  <= 1'b1;
                    dcache_wvalid_reg   <= 1'b1;
                    dcache_len_reg      <= 8'h0;
                    dcache_size_reg     <= first_stage_size_flag;
                    dcache_lock_reg     <= 1'b0;
                    dcache_addr_reg     <= paddr;
                    dcache_wdata_reg    <= first_stage_wdata_flag;
                    dcache_wstrb_reg    <= first_stage_wstrb_flag;
                    dcache_wlast_reg    <= 1'b1;
                end
                //? not hit; not cacheable; read
                else if(first_stage_valid & paddr_valid & (!paddr_error) & ((paddr > PMEM_END) | (paddr < PMEM_START)) & first_stage_read_flag)begin
                    dcache_fsm          <= WAIT_AR;
                    dcache_arvalid_reg  <= 1'b1;
                    dcache_len_reg      <= 8'h0;
                    dcache_size_reg     <= first_stage_size_flag;
                    dcache_lock_reg     <= 1'b0;
                    dcache_num          <= 1'b0;
                    dcache_addr_reg     <= paddr;
                end
                //? not hit; cacheable; dirty
                else if(first_stage_valid & paddr_valid & (!paddr_error) & (!(|sram_way_sel)) & dcache_line_dirty_way_use[way_sel][dcache_line_waddr[9:4]])begin
                    dcache_fsm          <= WAIT_AW_W;
                    dcache_awvalid_reg  <= 1'b1;
                    dcache_wvalid_reg   <= 1'b1;
                    dcache_len_reg      <= 8'h1;
                    dcache_size_reg     <= 3'h3;
                    dcache_lock_reg     <= 1'b0;
                    dcache_addr_reg     <= {sram_tag_way_use[way_sel][63:4], 4'h0};
                    dcache_wdata_reg    <= sram_data_way_use[way_sel][63:0];
                    dcache_wstrb_reg    <= 8'hff;
                    dcache_wlast_reg    <= 1'b0;
                end
                // //? not hit; cacheable; not dirty
                else if(first_stage_valid & paddr_valid & (!paddr_error) & (!(|sram_way_sel)) & (!dcache_line_dirty_way_use[way_sel][dcache_line_waddr[9:4]]))begin
                    dcache_fsm          <= WAIT_AR;
                    dcache_arvalid_reg  <= 1'b1;
                    dcache_len_reg      <= 8'h1;
                    dcache_size_reg     <= 3'h3;
                    dcache_lock_reg     <= 1'b0;
                    dcache_num          <= 1'b1;
                    dcache_addr_reg     <= {paddr[63:4], 4'h0};
                end
            end
            FLUSH: begin
                if(flush_flag)begin
                    dcache_fsm          <= IDLE;
                    dcache_mmu_flag     <= 1'b0;
                    dcache_arvalid_reg  <= 1'b0;
                    dcache_awvalid_reg  <= 1'b0;
                    dcache_wvalid_reg   <= 1'b0;
                    dcache_len_reg      <= 8'h0;
                    dcache_size_reg     <= 3'h0;
                    dcache_lock_reg     <= 1'b0;
                    dcache_num          <= 1'b0;
                    dcache_addr_reg     <= 64'b0;
                    dcache_wdata_reg    <= 64'b0;
                    dcache_wstrb_reg    <= 8'b0;
                    dcache_wlast_reg    <= 1'b0;
                    dcache_line_wen     <= 1'b0;
                    dcache_resp_reg     <= 2'h0;
                end
                //? lock write
                else if(!first_stage_read_flag)begin
                    dcache_fsm          <= WAIT_AW_W;
                    dcache_line_wen     <= 1'b0;
                    dcache_awvalid_reg  <= 1'b1;
                    dcache_wvalid_reg   <= 1'b1;
                    dcache_len_reg      <= 8'h0;
                    dcache_size_reg     <= first_stage_size_flag;
                    dcache_lock_reg     <= 1'b1;
                    dcache_addr_reg     <= paddr;
                    dcache_wdata_reg    <= first_stage_wdata_flag;
                    dcache_wstrb_reg    <= first_stage_wstrb_flag;
                    dcache_wlast_reg    <= 1'b1;
                end
                //? lock read
                else if(first_stage_read_flag)begin
                    dcache_fsm          <= WAIT_AR;
                    dcache_line_wen     <= 1'b0;
                    dcache_arvalid_reg  <= 1'b1;
                    dcache_len_reg      <= 8'h0;
                    dcache_size_reg     <= first_stage_size_flag;
                    dcache_lock_reg     <= 1'b1;
                    dcache_num          <= 1'b0;
                    dcache_addr_reg     <= paddr;
                end
            end
            WAIT_AW_W: begin
                //? AW handle; W handle; last
                if(dcache_awvalid & dcache_awready & dcache_wvalid & dcache_wready & dcache_wlast)begin
                    dcache_fsm          <= WAIT_B;
                    dcache_awvalid_reg  <= 1'b0;
                    dcache_wvalid_reg   <= 1'b0;
                end
                //? AW handle; W handle; not last mmu
                else if(dcache_awvalid & dcache_awready & dcache_wvalid & dcache_wready & (!dcache_wlast) & dcache_mmu_flag)begin
                    dcache_fsm          <= WAIT_W;
                    dcache_awvalid_reg  <= 1'b0;
                    dcache_wdata_reg    <= sram_data_way_mmu_use[way_sel_mmu][127:64];
                    dcache_wstrb_reg    <= 8'hff;
                    dcache_wlast_reg    <= 1'b1;
                end
                //? AW handle; W handle; not last; hit
                else if(dcache_awvalid & dcache_awready & dcache_wvalid & dcache_wready & (!dcache_wlast) & (|sram_way_sel))begin
                    dcache_fsm          <= WAIT_W;
                    dcache_awvalid_reg  <= 1'b0;
                    dcache_wdata_reg    <= sram_data_sel[127:64];
                    dcache_wstrb_reg    <= 8'hff;
                    dcache_wlast_reg    <= 1'b1;
                end
                //? AW handle; W handle; not last; not hit
                else if(dcache_awvalid & dcache_awready & dcache_wvalid & dcache_wready & (!dcache_wlast))begin
                    dcache_fsm          <= WAIT_W;
                    dcache_awvalid_reg  <= 1'b0;
                    dcache_wdata_reg    <= sram_data_way_use[way_sel][127:64];
                    dcache_wstrb_reg    <= 8'hff;
                    dcache_wlast_reg    <= 1'b1;
                end
                //? AW handle;
                else if(dcache_awvalid & dcache_awready)begin
                    dcache_fsm          <= WAIT_W;
                    dcache_awvalid_reg  <= 1'b0;
                end
                //? W handle; last
                else if(dcache_wvalid & dcache_wready & dcache_wlast)begin
                    dcache_fsm          <= WAIT_AW;
                    dcache_wvalid_reg   <= 1'b0;
                end
                //? W handle; not last mmu
                else if(dcache_wvalid & dcache_wready & (!dcache_wlast) & dcache_mmu_flag)begin
                    dcache_fsm          <= WAIT_AW_W;
                    dcache_wdata_reg    <= sram_data_way_mmu_use[way_sel_mmu][127:64];
                    dcache_wstrb_reg    <= 8'hff;
                    dcache_wlast_reg    <= 1'b1;
                end
                //? W handle; not last; hit
                else if(dcache_wvalid & dcache_wready & (!dcache_wlast) & (|sram_way_sel))begin
                    dcache_fsm          <= WAIT_AW_W;
                    dcache_wdata_reg    <= sram_data_sel[127:64];
                    dcache_wstrb_reg    <= 8'hff;
                    dcache_wlast_reg    <= 1'b1;
                end
                //? W handle; not last; not hit
                else if(dcache_wvalid & dcache_wready & (!dcache_wlast))begin
                    dcache_fsm          <= WAIT_AW_W;
                    dcache_wdata_reg    <= sram_data_way_use[way_sel][127:64];
                    dcache_wstrb_reg    <= 8'hff;
                    dcache_wlast_reg    <= 1'b1;
                end
            end
            WAIT_AW: begin
                //? AW handle;
                if(dcache_awvalid & dcache_awready)begin
                    dcache_fsm          <= WAIT_B;
                    dcache_awvalid_reg  <= 1'b0;
                end
            end
            WAIT_W: begin
                //? W handle; last
                if(dcache_wvalid & dcache_wready & dcache_wlast)begin
                    dcache_fsm          <= WAIT_B;
                    dcache_wvalid_reg   <= 1'b0;
                end
                //? W handle; not last mmu
                else if(dcache_wvalid & dcache_wready & (!dcache_wlast) & dcache_mmu_flag)begin
                    dcache_fsm          <= WAIT_W;
                    dcache_wdata_reg    <= sram_data_way_mmu_use[way_sel_mmu][127:64];
                    dcache_wstrb_reg    <= 8'hff;
                    dcache_wlast_reg    <= 1'b1;
                end
                //? W handle; not last; hit
                else if(dcache_wvalid & dcache_wready & (!dcache_wlast) & (|sram_way_sel))begin
                    dcache_fsm          <= WAIT_W;
                    dcache_wdata_reg    <= sram_data_sel[127:64];
                    dcache_wstrb_reg    <= 8'hff;
                    dcache_wlast_reg    <= 1'b1;
                end
                //? W handle; not last; not hit
                else if(dcache_wvalid & dcache_wready & (!dcache_wlast))begin
                    dcache_fsm          <= WAIT_W;
                    dcache_wdata_reg    <= sram_data_way_use[way_sel][127:64];
                    dcache_wstrb_reg    <= 8'hff;
                    dcache_wlast_reg    <= 1'b1;
                end
            end
            WAIT_B: begin
                if((flush_flag | flush_flag_reg) & dcache_bvalid & dcache_bready & (dcache_bid == AXI_ID_SB))begin
                    dcache_fsm          <= IDLE;
                    dcache_mmu_flag     <= 1'b0;
                    dcache_arvalid_reg  <= 1'b0;
                    dcache_awvalid_reg  <= 1'b0;
                    dcache_wvalid_reg   <= 1'b0;
                    dcache_len_reg      <= 8'h0;
                    dcache_size_reg     <= 3'h0;
                    dcache_lock_reg     <= 1'b0;
                    dcache_num          <= 1'b0;
                    dcache_addr_reg     <= 64'b0;
                    dcache_wdata_reg    <= 64'b0;
                    dcache_wstrb_reg    <= 8'b0;
                    dcache_wlast_reg    <= 1'b0;
                    dcache_line_wen     <= 1'b0;
                    dcache_resp_reg     <= 2'h0;
                end
                //? B handle not error; not hit mmu
                else if(dcache_bvalid & dcache_bready & (dcache_bid == AXI_ID_SB) & (dcache_bresp == 2'h0) & dcache_mmu_flag)begin
                    dcache_fsm          <= WAIT_AR;
                    dcache_arvalid_reg  <= 1'b1;
                    dcache_len_reg      <= 8'h1;
                    dcache_size_reg     <= 3'h3;
                    dcache_lock_reg     <= 1'b0;
                    dcache_num          <= 1'b1;
                    dcache_addr_reg     <= {dcache_line_waddr_mmu[63:4], 4'h0};
                end
                //? B handle error; dirty now not start lock
                else if(dcache_bvalid & dcache_bready & (dcache_bid == AXI_ID_SB) & (dcache_bresp != 2'h0) & (|sram_way_sel_dirty) & (!dcache_lock_reg))begin
                    dcache_fsm          <= SEND_DATA;
                    dcache_resp_reg     <= 2'h3;
                end
                //? B handle not error; dirty now not start lock
                else if(dcache_bvalid & dcache_bready & (dcache_bid == AXI_ID_SB) & (dcache_bresp == 2'h0) & (|sram_way_sel_dirty) & (!dcache_lock_reg))begin
                    dcache_fsm          <= FLUSH;
                    dcache_line_wen     <= 1'b1;
                end
                //? B handle error; now finish lock
                else if(dcache_bvalid & dcache_bready & (dcache_bid == AXI_ID_SB) & (dcache_bresp != 2'h1) & dcache_lock_reg)begin
                    dcache_fsm          <= SEND_DATA;
                    dcache_resp_reg     <= 2'h3;
                end
                //? B handle not error; now finish lock
                else if(dcache_bvalid & dcache_bready & (dcache_bid == AXI_ID_SB) & (dcache_bresp == 2'h1) & dcache_lock_reg)begin
                    dcache_fsm          <= SEND_DATA;
                    dcache_resp_reg     <= 2'h1;
                end
                //? B handle error; not cacheable 
                else if(dcache_bvalid & dcache_bready & (dcache_bid == AXI_ID_SB) & (dcache_bresp != 2'h0) & ((paddr > PMEM_END) | (paddr < PMEM_START)))begin
                    dcache_fsm          <= SEND_DATA;
                    dcache_resp_reg     <= 2'h3;
                end
                // ? B handle not error; not cacheable 
                else if(dcache_bvalid & dcache_bready & (dcache_bid == AXI_ID_SB) & (dcache_bresp == 2'h0) & ((paddr > PMEM_END) | (paddr < PMEM_START)))begin
                    dcache_fsm          <= SEND_DATA;
                    dcache_resp_reg     <= 2'h0;
                end
                //? B handle error; not hit
                else if(dcache_bvalid & dcache_bready & (dcache_bid == AXI_ID_SB) & (dcache_bresp != 2'h0))begin
                    dcache_fsm          <= SEND_DATA;
                    dcache_resp_reg     <= 2'h3;
                end
                //? B handle not error; not hit
                else if(dcache_bvalid & dcache_bready & (dcache_bid == AXI_ID_SB) & (dcache_bresp == 2'h0))begin
                    dcache_fsm          <= WAIT_AR;
                    dcache_arvalid_reg  <= 1'b1;
                    dcache_len_reg      <= 8'h1;
                    dcache_size_reg     <= 3'h3;
                    dcache_lock_reg     <= 1'b0;
                    dcache_num          <= 1'b1;
                    dcache_addr_reg     <= {paddr[63:4], 4'h0};
                end
            end
            WAIT_AR: begin
                if(dcache_arvalid & dcache_arready)begin
                    dcache_fsm          <= WAIT_R;
                    dcache_arvalid_reg  <= 1'b0;
                end
            end
            WAIT_R: begin
                if((flush_flag | flush_flag_reg) & dcache_rvalid & dcache_rready & (dcache_rid == AXI_ID_SB) & (!dcache_rlast))begin
                    dcache_fsm          <= WAIT_R;
                end
                else if((flush_flag | flush_flag_reg) & dcache_rvalid & dcache_rready & (dcache_rid == AXI_ID_SB) & dcache_rlast)begin
                    dcache_fsm          <= IDLE;
                    dcache_mmu_flag     <= 1'b0;
                    dcache_arvalid_reg  <= 1'b0;
                    dcache_awvalid_reg  <= 1'b0;
                    dcache_wvalid_reg   <= 1'b0;
                    dcache_len_reg      <= 8'h0;
                    dcache_size_reg     <= 3'h0;
                    dcache_lock_reg     <= 1'b0;
                    dcache_num          <= 1'b0;
                    dcache_addr_reg     <= 64'b0;
                    dcache_wdata_reg    <= 64'b0;
                    dcache_wstrb_reg    <= 8'b0;
                    dcache_wlast_reg    <= 1'b0;
                    dcache_line_wen     <= 1'b0;
                    dcache_resp_reg     <= 2'h0;
                end
                //? R handle error; cacheable; last mmu
                else if(dcache_rvalid & dcache_rready & (dcache_rid == AXI_ID_SB) & (dcache_rresp != 2'h0) & dcache_rlast & dcache_mmu_flag)begin
                    dcache_fsm          <= SEND_DATA;
                    dcache_resp_reg     <= 2'h3;
                end
                //? R handle error; cacheable; last mmu
                else if(dcache_rvalid & dcache_rready & (dcache_rid == AXI_ID_SB) & (dcache_rresp == 2'h0) & dcache_rlast & (dcache_num != 1'b0) & dcache_mmu_flag)begin
                    dcache_fsm          <= SEND_DATA;
                    dcache_resp_reg     <= 2'h3;
                end
                //? R handle error; cacheable; not last mmu
                else if(dcache_rvalid & dcache_rready & (dcache_rid == AXI_ID_SB) & (dcache_rresp != 2'h0) & (!dcache_rlast) & dcache_mmu_flag)begin
                    dcache_fsm          <= WAIT_ERROR;
                    dcache_resp_reg     <= 2'h3;
                end
                //? R handle error; cacheable; not last mmu
                else if(dcache_rvalid & dcache_rready & (dcache_rid == AXI_ID_SB) & (dcache_rresp == 2'h0) & (!dcache_rlast) & (dcache_num == 1'b0) & dcache_mmu_flag)begin
                    dcache_fsm          <= WAIT_ERROR;
                    dcache_resp_reg     <= 2'h3;
                end
                //? R handle not error; cacheable; not last mmu
                else if(dcache_rvalid & dcache_rready & (dcache_rid == AXI_ID_SB) & (dcache_rresp == 2'h0) & (!dcache_rlast) & dcache_mmu_flag)begin
                    dcache_fsm          <= WAIT_R;
                    dcache_num          <= 1'b0;
                end
                //? R handle not error; cacheable; last mmu
                else if(dcache_rvalid & dcache_rready & (dcache_rid == AXI_ID_SB) & (dcache_rresp == 2'h0) & dcache_rlast & dcache_mmu_flag)begin
                    dcache_fsm          <= WRITE_CACHE;
                    dcache_line_wen     <= 1'b1;
                    dcache_resp_reg     <= 2'h0;
                end
                //? R handle error; lock
                else if(dcache_rvalid & dcache_rready & (dcache_rid == AXI_ID_SB) & dcache_lock_reg & (dcache_rresp != 2'h1))begin
                    dcache_fsm          <= SEND_DATA;
                    dcache_resp_reg     <= 2'h3;
                end
                //? R handle error; lock
                else if(dcache_rvalid & dcache_rready & (dcache_rid == AXI_ID_SB) & dcache_lock_reg & (dcache_rresp == 2'h1) & (!dcache_rlast))begin
                    dcache_fsm          <= SEND_DATA;
                    dcache_resp_reg     <= 2'h3;
                end
                //? R handle not error; lock
                else if(dcache_rvalid & dcache_rready & (dcache_rid == AXI_ID_SB) & dcache_lock_reg & (dcache_rresp == 2'h1))begin
                    dcache_fsm          <= SEND_DATA;
                    dcache_resp_reg     <= 2'h1;
                end
                //? R handle error; not cacheable 
                else if(dcache_rvalid & dcache_rready & (dcache_rid == AXI_ID_SB) & (dcache_rresp != 2'h0) & ((paddr > PMEM_END) | (paddr < PMEM_START)))begin
                    dcache_fsm          <= SEND_DATA;
                    dcache_resp_reg     <= 2'h3;
                end
                //? R handle error; not cacheable 
                else if(dcache_rvalid & dcache_rready & (dcache_rid == AXI_ID_SB) & (dcache_rresp != 2'h0) & ((paddr > PMEM_END) | (paddr < PMEM_START)) & (!dcache_rlast))begin
                    dcache_fsm          <= SEND_DATA;
                    dcache_resp_reg     <= 2'h3;
                end
                //? R handle not error; not cacheable 
                else if(dcache_rvalid & dcache_rready & (dcache_rid == AXI_ID_SB) & (dcache_rresp == 2'h0) & ((paddr > PMEM_END) | (paddr < PMEM_START)))begin
                    dcache_fsm          <= SEND_DATA;
                    dcache_resp_reg     <= 2'h0;
                end
                //? R handle error; cacheable; last
                else if(dcache_rvalid & dcache_rready & (dcache_rid == AXI_ID_SB) & (dcache_rresp != 2'h0) & dcache_rlast)begin
                    dcache_fsm          <= SEND_DATA;
                    dcache_resp_reg     <= 2'h3;
                end
                //? R handle error; cacheable; last
                else if(dcache_rvalid & dcache_rready & (dcache_rid == AXI_ID_SB) & (dcache_rresp == 2'h0) & dcache_rlast & (dcache_num != 1'b0))begin
                    dcache_fsm          <= SEND_DATA;
                    dcache_resp_reg     <= 2'h3;
                end
                //? R handle error; cacheable; not last
                else if(dcache_rvalid & dcache_rready & (dcache_rid == AXI_ID_SB) & (dcache_rresp != 2'h0) & (!dcache_rlast))begin
                    dcache_fsm          <= WAIT_ERROR;
                    dcache_resp_reg     <= 2'h3;
                end
                //? R handle error; cacheable; not last
                else if(dcache_rvalid & dcache_rready & (dcache_rid == AXI_ID_SB) & (dcache_rresp == 2'h0) & (!dcache_rlast) & (dcache_num == 1'b0))begin
                    dcache_fsm          <= WAIT_ERROR;
                    dcache_resp_reg     <= 2'h3;
                end
                //? R handle not error; cacheable; not last
                else if(dcache_rvalid & dcache_rready & (dcache_rid == AXI_ID_SB) & (dcache_rresp == 2'h0) & (!dcache_rlast))begin
                    dcache_fsm          <= WAIT_R;
                    dcache_num          <= 1'b0;
                end
                //? R handle not error; cacheable; last
                else if(dcache_rvalid & dcache_rready & (dcache_rid == AXI_ID_SB) & (dcache_rresp == 2'h0) & dcache_rlast)begin
                    dcache_fsm          <= WRITE_CACHE;
                    dcache_line_wen     <= 1'b1;
                    dcache_resp_reg     <= 2'h0;
                end
            end
            WAIT_ERROR: begin
                if(dcache_rvalid & dcache_rready & (dcache_rid == AXI_ID_SB) & dcache_rlast & (flush_flag | flush_flag_reg))begin
                    dcache_fsm          <= SEND_DATA;
                end
                else if(dcache_rvalid & dcache_rready & (dcache_rid == AXI_ID_SB) & dcache_rlast)begin
                    dcache_fsm          <= SEND_DATA;
                end
            end
            SEND_DATA: begin
                if(flush_flag)begin
                    dcache_fsm          <= IDLE;
                    dcache_mmu_flag     <= 1'b0;
                    dcache_arvalid_reg  <= 1'b0;
                    dcache_awvalid_reg  <= 1'b0;
                    dcache_wvalid_reg   <= 1'b0;
                    dcache_len_reg      <= 8'h0;
                    dcache_size_reg     <= 3'h0;
                    dcache_lock_reg     <= 1'b0;
                    dcache_num          <= 1'b0;
                    dcache_addr_reg     <= 64'b0;
                    dcache_wdata_reg    <= 64'b0;
                    dcache_wstrb_reg    <= 8'b0;
                    dcache_wlast_reg    <= 1'b0;
                    dcache_line_wen     <= 1'b0;
                    dcache_resp_reg     <= 2'h0;
                end
                else if(out_fifo_wen)begin
                    dcache_fsm      <= IDLE;
                    dcache_mmu_flag <= 1'b0;
                end
            end
            WRITE_CACHE: begin
                if(flush_flag)begin
                    dcache_fsm          <= IDLE;
                    dcache_mmu_flag     <= 1'b0;
                    dcache_arvalid_reg  <= 1'b0;
                    dcache_awvalid_reg  <= 1'b0;
                    dcache_wvalid_reg   <= 1'b0;
                    dcache_len_reg      <= 8'h0;
                    dcache_size_reg     <= 3'h0;
                    dcache_lock_reg     <= 1'b0;
                    dcache_num          <= 1'b0;
                    dcache_addr_reg     <= 64'b0;
                    dcache_wdata_reg    <= 64'b0;
                    dcache_wstrb_reg    <= 8'b0;
                    dcache_wlast_reg    <= 1'b0;
                    dcache_line_wen     <= 1'b0;
                    dcache_resp_reg     <= 2'h0;
                end
                //? mmu
                else if(dcache_mmu_flag)begin
                    dcache_fsm          <= SEND_DATA;
                    dcache_line_wen     <= 1'b0;
                end
                //? hit cacheable write
                else if(|sram_way_sel)begin
                    dcache_fsm          <= IDLE;
                    dcache_line_wen     <= 1'b0;
                end
                //? not hit; cacheable R/W
                else begin
                    dcache_fsm          <= SEND_DATA;
                    dcache_line_wen     <= 1'b0;
                end
            end
            default: begin
                dcache_fsm          <= IDLE;
                dcache_mmu_flag     <= 1'b0;
                dcache_arvalid_reg  <= 1'b0;
                dcache_awvalid_reg  <= 1'b0;
                dcache_wvalid_reg   <= 1'b0;
                dcache_len_reg      <= 8'h0;
                dcache_size_reg     <= 3'h0;
                dcache_lock_reg     <= 1'b0;
                dcache_num          <= 1'b0;
                dcache_addr_reg     <= 64'b0;
                dcache_wdata_reg    <= 64'b0;
                dcache_wstrb_reg    <= 8'b0;
                dcache_wlast_reg    <= 1'b0;
                dcache_line_wen     <= 1'b0;
                dcache_resp_reg     <= 2'h0;
            end
        endcase
    end
end
//TODO 假设l2tlb发起一笔传输，并且传输过程中flush_flag有效，此时如果已经开始对外传输，那必须完成对外的传输，如果不脏，则发起读传输，对系统状态无影响；如果是写，则会修改内存中的值，导致其与cache line中的值相同，造成假脏，可能会导致下次在写回，使得性能下降一点点？
always @(posedge clk or negedge rst_n) begin
    if(!rst_n)begin
        flush_flag_reg <= 1'b0;
    end
    else if(flush_flag & ((dcache_fsm == WAIT_AW_W) | (dcache_fsm == WAIT_AW) | (dcache_fsm == WAIT_W) | (dcache_fsm == WAIT_AR)))begin
        flush_flag_reg <= 1'b1;
    end
    else if(flush_flag & (dcache_fsm == WAIT_B) & (!(dcache_bvalid & dcache_bready & (dcache_bid == AXI_ID_SB))))begin
        flush_flag_reg <= 1'b1;
    end
    else if(flush_flag_reg & (dcache_fsm == WAIT_B) & dcache_bvalid & dcache_bready & (dcache_bid == AXI_ID_SB))begin
        flush_flag_reg <= 1'b0;
    end
    else if(flush_flag & (dcache_fsm == WAIT_R) & (!(dcache_rvalid & dcache_rready & (dcache_rid == AXI_ID_SB) & dcache_rlast)))begin
        flush_flag_reg <= 1'b1;
    end
    else if(flush_flag_reg & (dcache_fsm == WAIT_R) & dcache_rvalid & dcache_rready & (dcache_rid == AXI_ID_SB) & dcache_rlast)begin
        flush_flag_reg <= 1'b0;
    end
    else if(flush_flag & (dcache_fsm == WAIT_ERROR) & (!(dcache_rvalid & dcache_rready & (dcache_rid == AXI_ID_SB) & dcache_rlast)))begin
        flush_flag_reg <= 1'b1;
    end
    else if(flush_flag_reg & (dcache_fsm == WAIT_ERROR) & dcache_rvalid & dcache_rready & (dcache_rid == AXI_ID_SB) & dcache_rlast)begin
        flush_flag_reg <= 1'b0;
    end
end
always @(posedge clk) begin
    if(dcache_rvalid & dcache_rready & (dcache_rid == AXI_ID_SB) & (!dcache_rlast) & dcache_num)begin
        axi_rdata[63:0]          <= dcache_rdata;
    end
    else if(dcache_rvalid & dcache_rready & (dcache_rid == AXI_ID_SB) & dcache_rlast & (!dcache_num))begin
        axi_rdata[127:64]        <= dcache_rdata;
    end
end
always @(posedge clk) begin
    if(dcache_rvalid & dcache_rready & (dcache_rid == AXI_ID_SB))begin
        dcache_rdata_reg          <= dcache_rdata;
    end
end
assign sram_wmask                           =  {{8{first_stage_wstrb_flag[7]}}, {8{first_stage_wstrb_flag[6]}}, 
                                                {8{first_stage_wstrb_flag[5]}}, {8{first_stage_wstrb_flag[4]}}, 
                                                {8{first_stage_wstrb_flag[3]}}, {8{first_stage_wstrb_flag[2]}}, 
                                                {8{first_stage_wstrb_flag[1]}}, {8{first_stage_wstrb_flag[0]}}};
assign sram_data_bwen                       = (dcache_mmu_flag | first_stage_read_flag | (!(|sram_way_sel))) ? {128{1'b0}} : ((dcache_line_waddr[3]) ? {(~sram_wmask), {64{1'b1}}} : {{64{1'b1}}, (~sram_wmask)});
assign sram_data_bmask                      = (dcache_line_waddr[3]) ? {(~sram_wmask), {64{1'b1}}} : {{64{1'b1}}, (~sram_wmask)};
assign sram_data_wdata                      = (dcache_mmu_flag | first_stage_read_flag | (!(|sram_way_sel))) ? 
                                                ((dcache_mmu_flag | first_stage_read_flag) ? axi_rdata : ((axi_rdata & sram_data_bmask) | ({first_stage_wdata_flag, first_stage_wdata_flag} & (~sram_data_bmask)))) : 
                                                {first_stage_wdata_flag, first_stage_wdata_flag};

//TODO 加入了paddr_valid，会导致stage级别依赖于paddr，导致性能下降，考虑优化
assign lsu_fifo_ren                         = (!lsu_fifo_empty) & (!dcache_line_wen) & (!(mmu_arvalid & mmu_arready)) & (first_stage_ready | (!first_stage_valid)) & paddr_valid & 
                                                (!(first_stage_mmu_valid & (lsu_fifo_rdata[9 + DCACHE_GROUP_LEN:4] == dcache_line_waddr_mmu[9 + DCACHE_GROUP_LEN:4])));
assign fifo_wen                             = (lsu_arvalid & lsu_arready) | (lsu_awvalid & lsu_awready & lsu_wvalid & lsu_wready);
assign lsu_fifo_wdata                       = (lsu_arvalid & lsu_arready) ? {8'h0, 64'h0, lsu_arlock, lsu_arsize, 1'b1, lsu_araddr} : {lsu_wstrb, lsu_wdata, lsu_awlock, lsu_awsize, 1'b0, lsu_awaddr};
assign mmu_fifo_wdata                       = (lsu_arvalid & lsu_arready) ? {1'b1, lsu_araddr} : {1'b0, lsu_awaddr};
assign out_fifo_ren                         = (lsu_rvalid & lsu_rready) | (lsu_bvalid & lsu_bready) | (mmu_rvalid & mmu_rready);
assign out_mmu_hit                          = (dcache_fsm == IDLE) & (first_stage_mmu_valid & (|sram_way_sel_mmu));
assign out_lsu_read_hit                     = (dcache_fsm == IDLE) & (first_stage_valid & paddr_valid & ((|sram_way_sel) | paddr_error) & first_stage_read_flag & (!first_stage_lock_flag) & (!first_stage_mmu_valid));
assign out_mmu_no_hit                       = (dcache_fsm == SEND_DATA) & dcache_mmu_flag;
assign out_lsu_hit_write                    = (dcache_fsm == SEND_DATA) & (!dcache_mmu_flag) & (!first_stage_read_flag) & (|sram_way_sel);
assign out_lsu_hit_write_cacheable          = (dcache_fsm == WRITE_CACHE) & (!first_stage_read_flag) & (|sram_way_sel) & (!dcache_mmu_flag);
assign out_lsu_no_hit_read_cacheable        = (dcache_fsm == SEND_DATA) & (!dcache_mmu_flag) & first_stage_read_flag & (!((paddr > PMEM_END) | (paddr < PMEM_START)));
assign out_lsu_no_hit_read_not_cacheable    = (dcache_fsm == SEND_DATA) & (!dcache_mmu_flag) & first_stage_read_flag & (  (paddr > PMEM_END) | (paddr < PMEM_START));
assign out_lsu_no_hit_write                 = (dcache_fsm == SEND_DATA) & (!dcache_mmu_flag) & (!first_stage_read_flag) & (!(|sram_way_sel));
assign out_fifo_wen                         = (out_mmu_hit | out_lsu_read_hit | 
                                                out_mmu_no_hit | out_lsu_hit_write | out_lsu_hit_write_cacheable |
                                                out_lsu_no_hit_read_cacheable | out_lsu_no_hit_read_not_cacheable | 
                                                out_lsu_no_hit_write) & (out_fifo_cnt != 3'h7);
assign out_fifo_wdata       =   ({68{out_mmu_hit                        &   dcache_line_waddr_mmu[3]  }} & {1'b1, 1'b1, 2'h0,              sram_data_sel_mmu[127:64]   }) |
                                ({68{out_mmu_hit                        & (!dcache_line_waddr_mmu[3]) }} & {1'b1, 1'b1, 2'h0,              sram_data_sel_mmu[63:0]     }) |
                                ({68{out_lsu_read_hit                   &   dcache_line_waddr[3]      }} & {1'b0, 1'b1, paddr_error, 1'b0, sram_data_sel[127:64]       }) |
                                ({68{out_lsu_read_hit                   & (!dcache_line_waddr[3])     }} & {1'b0, 1'b1, paddr_error, 1'b0, sram_data_sel[63:0]         }) |
                                ({68{out_mmu_no_hit                     &   dcache_line_waddr_mmu[3]  }} & {1'b1, 1'b1, dcache_resp_reg,   sram_data_wdata[127:64]     }) |
                                ({68{out_mmu_no_hit                     & (!dcache_line_waddr_mmu[3]) }} & {1'b1, 1'b1, dcache_resp_reg,   sram_data_wdata[63:0]       }) |
                                ({68{out_lsu_hit_write                  &   dcache_line_waddr[3]      }} & {1'b0, 1'b0, dcache_resp_reg,   sram_data_sel[127:64]       }) |
                                ({68{out_lsu_hit_write                  & (!dcache_line_waddr[3])     }} & {1'b0, 1'b0, dcache_resp_reg,   sram_data_sel[63:0]         }) |
                                ({68{out_lsu_hit_write_cacheable                                      }} & {1'b0, 1'b0, 2'h0,              sram_data_sel[63:0]         }) |
                                ({68{out_lsu_no_hit_read_cacheable      &   dcache_line_waddr[3]      }} & {1'b0, 1'b1, dcache_resp_reg,   sram_data_wdata[127:64]     }) |
                                ({68{out_lsu_no_hit_read_cacheable      & (!dcache_line_waddr[3])     }} & {1'b0, 1'b1, dcache_resp_reg,   sram_data_wdata[63:0]       }) |
                                ({68{out_lsu_no_hit_read_not_cacheable                                }} & {1'b0, 1'b1, dcache_resp_reg,   dcache_rdata_reg            }) |
                                ({68{out_lsu_no_hit_write               &   dcache_line_waddr[3]      }} & {1'b0, 1'b0, dcache_resp_reg,   sram_data_sel[127:64]       }) |
                                ({68{out_lsu_no_hit_write               & (!dcache_line_waddr[3])     }} & {1'b0, 1'b0, dcache_resp_reg,   sram_data_sel[63:0]         });

dmmu u_dmmu(
    .clk                 	(clk                  ),
    .rst_n               	(rst_n                ),
    .current_priv_status 	(current_priv_status  ),
    .MXR                    (MXR                  ),
    .SUM                    (SUM                  ),
    .MPRV                   (MPRV                 ),
    .MPP                    (MPP                  ),
    .satp_mode           	(satp_mode            ),
    .satp_asid           	(satp_asid            ),
    .flush_flag          	(flush_flag           ),
    .sflush_vma_valid    	(sflush_vma_valid     ),
    .sflush_vma_ready    	(sflush_vma_ready     ),
    .dmmu_miss_valid     	(dmmu_miss_valid      ),
    .dmmu_miss_ready     	(dmmu_miss_ready      ),
    .vaddr_d             	(vaddr_d              ),
    .pte_valid           	(pte_valid            ),
    .pte_ready_d         	(pte_ready_d          ),
    .pte                 	(pte                  ),
    .pte_error           	(pte_error            ),
    .mmu_fifo_valid      	(!mmu_fifo_empty      ),
    .mmu_fifo_ready      	(mmu_fifo_ren         ),
    .vaddr               	(mmu_fifo_rdata       ),
    .paddr_valid         	(paddr_valid          ),
    .paddr_ready         	(paddr_ready          ),
    .paddr               	(paddr                ),
    .paddr_error         	(paddr_error          )
);
assign paddr_ready      = first_stage_ready;
//**********************************************************************************************
//?out sign
// assign flush_i_ready    = 1'b1;
assign lsu_arready      = (lsu_fifo_cnt != 3'h7) & (mmu_fifo_cnt != 3'h7);
assign lsu_rvalid       = (!out_fifo_rdata[67]) & out_fifo_rdata[66] & (!out_fifo_empty);
assign lsu_rresp        = out_fifo_rdata[65:64];
assign lsu_rdata        = out_fifo_rdata[63:0];
assign lsu_awready      = (lsu_fifo_cnt != 3'h7) & (mmu_fifo_cnt != 3'h7) & (!lsu_arvalid);
assign lsu_wready       = (lsu_fifo_cnt != 3'h7) & (mmu_fifo_cnt != 3'h7) & (!lsu_arvalid);
assign lsu_bvalid       = (!out_fifo_rdata[67]) & (!out_fifo_rdata[66]) & (!out_fifo_empty);
assign lsu_bresp        = out_fifo_rdata[65:64];
assign mmu_arready      = mmu_arvalid & (!dcache_line_wen) & ((!first_stage_mmu_valid) | first_stage_mmu_ready) &
                        (!(first_stage_valid & (mmu_araddr[9 + DCACHE_GROUP_LEN:4] == dcache_line_waddr[9 + DCACHE_GROUP_LEN:4])));
assign mmu_rvalid       = out_fifo_rdata[67] & out_fifo_rdata[66] & (!out_fifo_empty);
assign mmu_rresp        = out_fifo_rdata[65:64];
assign mmu_rdata        = out_fifo_rdata[63:0];
assign dcache_arvalid   = dcache_arvalid_reg;
assign dcache_araddr    = dcache_addr_reg;
assign dcache_arid      = AXI_ID_SB;
assign dcache_arlen     = dcache_len_reg;
assign dcache_arsize    = dcache_size_reg;
assign dcache_arlock    = dcache_lock_reg;
assign dcache_arburst   = 2'h1;
assign dcache_rready    = 1'b1;

assign dcache_awvalid   = dcache_awvalid_reg;
assign dcache_awaddr    = dcache_addr_reg;
assign dcache_awid      = AXI_ID_SB;
assign dcache_awlen     = dcache_len_reg;
assign dcache_awsize    = dcache_size_reg;
assign dcache_awlock    = dcache_lock_reg;
assign dcache_awburst   = 2'h1;
assign dcache_wvalid    = dcache_wvalid_reg;
assign dcache_wdata     = dcache_wdata_reg;
assign dcache_wstrb     = dcache_wstrb_reg;
assign dcache_wlast     = dcache_wlast_reg;
assign dcache_bready    = 1'b1;
//**********************************************************************************************
//?function
function [191:0] dcache_line_sel;
    input [DCACHE_WAY-1:0]  sel;
    input [127:0]           dcache_line_rdata[0:DCACHE_WAY-1];
    input [63:0]            dcache_line_tag[0:DCACHE_WAY-1];
    integer index;
    begin
        dcache_line_sel = 192'h0;
        for (index = 0; index < DCACHE_WAY; index = index + 1) begin
            if(sel[index] == 1'b1)begin
                dcache_line_sel[127:0] = dcache_line_sel[127:0] | dcache_line_rdata[index];
                dcache_line_sel[191:128] = dcache_line_sel[191:128] | dcache_line_tag[index];
            end
        end
    end
endfunction

endmodule //dcache
