module dcache_model
import sb_pkg::*;
#(
    /* verilator lint_off UNUSEDPARAM */
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
    /* verilator lint_on UNUSEDPARAM */
)
(
    /* verilator lint_off UNUSEDSIGNAL */
    /* verilator lint_off UNDRIVEN */
    input                                               clk,
    input                                               rst_n,

    input                                               redirect,

    input                                               flush_i_valid_dcache,
    output                                              flush_i_ready,

    // atomic interface
    input                                               atomicUnit_arvalid,
    output                                              atomicUnit_arready,
    input  [2:0]                                        atomicUnit_arsize,
    input  [63:0]                                       atomicUnit_araddr,

    output                                              atomicUnit_rvalid,
    input                                               atomicUnit_rready,
    output [1:0]                                        atomicUnit_rresp,
    output [63:0]                                       atomicUnit_rdata,

    input                                               atomicUnit_awvalid,
    output                                              atomicUnit_awready,
    input  [2:0]                                        atomicUnit_awsize,
    input  [63:0]                                       atomicUnit_awaddr,

    input                                               atomicUnit_wvalid,
    output                                              atomicUnit_wready,
    input  [7:0]                                        atomicUnit_wstrb,
    input  [63:0]                                       atomicUnit_wdata,

    output                                              atomicUnit_bvalid,
    input                                               atomicUnit_bready,
    output [1:0]                                        atomicUnit_bresp,

    // storebuffer interface
    input                                               sbuffer_req_valid,
    output                                              sbuffer_req_ready,
    input  [63:0]                                       sbuffer_req_waddr,
    input  [15:0]                                       sbuffer_req_wstrb,
    input  [127:0]                                      sbuffer_req_wdata,
    input  [sb_line_bit - 1 : 0]                        sbuffer_req_index,

    output                                              sbuffer_resp_valid,
    input                                               sbuffer_resp_ready,
    output [sb_line_bit - 1 : 0]                        sbuffer_resp_index,

    // load query interface
    input                                               loadUnit_mmu_valid,
    input                                               loadUnit_mmu_ready,
    input  [64:0]                                       loadUnit_vaddr,

    input  [63:0]                                       dcache_load_paddr,
    output                                              dcache_load_hit,
    output [63:0]                                       dcache_load_data,

    // load interface
    input                                               load_arvalid,
    output                                              load_arready,
    input  [2:0]                                        load_arsize,
    input  [63:0]                                       load_araddr,

    output                                              load_rvalid,
    input                                               load_rready,
    output [1:0]                                        load_rresp,
    output [63:0]                                       load_rdata,

    // l2tlb interface
    input                                               mmu_arvalid,
    output                                              mmu_arready,
    input  [63:0]                                       mmu_araddr,

    output                                              mmu_rvalid,
    input                                               mmu_rready,
    output [1:0]                                        mmu_rresp,
    output [63:0]                                       mmu_rdata,

    //interface with axi
    //read addr channel
    output                                              dcache_arvalid,
    input                                               dcache_arready,
    output [AXI_ADDR_W    -1:0]                         dcache_araddr,
    output [8             -1:0]                         dcache_arlen,
    output [3             -1:0]                         dcache_arsize,
    output [2             -1:0]                         dcache_arburst,
    output                                              dcache_arlock,
    output [AXI_ID_W      -1:0]                         dcache_arid,
    //read data channel
    input                                               dcache_rvalid,
    output                                              dcache_rready,
    input  [AXI_ID_W      -1:0]                         dcache_rid,
    input  [2             -1:0]                         dcache_rresp,
    input  [AXI_DATA_W    -1:0]                         dcache_rdata,
    input                                               dcache_rlast,
    //write addr channel
    output                                              dcache_awvalid,
    input                                               dcache_awready,
    output [AXI_ADDR_W    -1:0]                         dcache_awaddr,
    output [8             -1:0]                         dcache_awlen,
    output [3             -1:0]                         dcache_awsize,
    output [2             -1:0]                         dcache_awburst,
    output                                              dcache_awlock,
    output [AXI_ID_W      -1:0]                         dcache_awid,
    //write data channel
    output                                              dcache_wvalid,
    input                                               dcache_wready,
    output                                              dcache_wlast,
    output [AXI_DATA_W    -1:0]                         dcache_wdata,
    output [AXI_DATA_W/8  -1:0]                         dcache_wstrb,
    //write resp channel
    input                                               dcache_bvalid,
    output                                              dcache_bready,
    input  [AXI_ID_W      -1:0]                         dcache_bid,
    input  [2             -1:0]                         dcache_bresp
    /* verilator lint_on UNUSEDSIGNAL */
    /* verilator lint_on UNDRIVEN */
);




endmodule
