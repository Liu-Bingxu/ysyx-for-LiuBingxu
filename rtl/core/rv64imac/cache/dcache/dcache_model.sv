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
    input  logic                                              clk,
    input  logic                                              rst_n,

    input  logic                                              redirect,

    /* verilator lint_off UNUSEDSIGNAL */
    /* verilator lint_off UNDRIVEN */
    input  logic                                              flush_i_valid_dcache,
    output logic                                              flush_i_ready,
    /* verilator lint_on UNUSEDSIGNAL */
    /* verilator lint_on UNDRIVEN */

    // atomic interface
    input  logic                                              atomicUnit_arvalid,
    output logic                                              atomicUnit_arready,
    //! TODO remove size, 之前增加size是为了mmio的操作，但是现在mmio操作移动至Uncache接口
    /* verilator lint_off UNUSEDSIGNAL */
    input  logic [2:0]                                        atomicUnit_arsize,
    /* verilator lint_on UNUSEDSIGNAL */
    input  logic [63:0]                                       atomicUnit_araddr,

    output logic                                              atomicUnit_rvalid,
    input  logic                                              atomicUnit_rready,
    output logic [1:0]                                        atomicUnit_rresp,
    output logic [63:0]                                       atomicUnit_rdata,

    input  logic                                              atomicUnit_awvalid,
    output logic                                              atomicUnit_awready,
    input  logic [2:0]                                        atomicUnit_awsize,
    input  logic [63:0]                                       atomicUnit_awaddr,

    input  logic                                              atomicUnit_wvalid,
    output logic                                              atomicUnit_wready,
    input  logic [7:0]                                        atomicUnit_wstrb,
    input  logic [63:0]                                       atomicUnit_wdata,

    output logic                                              atomicUnit_bvalid,
    input  logic                                              atomicUnit_bready,
    output logic [1:0]                                        atomicUnit_bresp,

    // storebuffer interface
    input  logic                                              sbuffer_req_valid,
    output logic                                              sbuffer_req_ready,
    input  logic [63:0]                                       sbuffer_req_waddr,
    input  logic [15:0]                                       sbuffer_req_wstrb,
    input  logic [127:0]                                      sbuffer_req_wdata,
    input  logic [sb_line_bit - 1 : 0]                        sbuffer_req_index,

    output logic                                              sbuffer_resp_valid,
    input  logic                                              sbuffer_resp_ready,
    output logic [sb_line_bit - 1 : 0]                        sbuffer_resp_index,

    /* verilator lint_off UNUSEDSIGNAL */
    /* verilator lint_off UNDRIVEN */
    // load query interface
    input  logic                                              loadUnit_mmu_valid,
    input  logic                                              loadUnit_mmu_ready,
    input  logic [64:0]                                       loadUnit_vaddr,

    input  logic [63:0]                                       dcache_load_paddr,
    output logic                                              dcache_load_hit,
    output logic [63:0]                                       dcache_load_data,
    /* verilator lint_on UNUSEDSIGNAL */
    /* verilator lint_on UNDRIVEN */

    // load interface
    input  logic                                              load_arvalid,
    output logic                                              load_arready,
    //! TODO remove size, 之前增加size是为了mmio的操作，但是现在mmio操作移动至Uncache接口
    /* verilator lint_off UNUSEDSIGNAL */
    input  logic [2:0]                                        load_arsize,
    /* verilator lint_on UNUSEDSIGNAL */
    input  logic [63:0]                                       load_araddr,

    output logic                                              load_rvalid,
    input  logic                                              load_rready,
    output logic [1:0]                                        load_rresp,
    output logic [63:0]                                       load_rdata,

    // l2tlb interface
    input  logic                                              mmu_arvalid,
    output logic                                              mmu_arready,
    input  logic [63:0]                                       mmu_araddr,

    output logic                                              mmu_rvalid,
    input  logic                                              mmu_rready,
    output logic [1:0]                                        mmu_rresp,
    output logic [63:0]                                       mmu_rdata,

    /* verilator lint_off UNUSEDSIGNAL */
    /* verilator lint_off UNDRIVEN */
    //interface with axi
    //read addr channel
    output logic                                              dcache_arvalid,
    input  logic                                              dcache_arready,
    output logic [AXI_ADDR_W    -1:0]                         dcache_araddr,
    output logic [8             -1:0]                         dcache_arlen,
    output logic [3             -1:0]                         dcache_arsize,
    output logic [2             -1:0]                         dcache_arburst,
    output logic                                              dcache_arlock,
    output logic [AXI_ID_W      -1:0]                         dcache_arid,
    //read data channel
    input  logic                                              dcache_rvalid,
    output logic                                              dcache_rready,
    input  logic [AXI_ID_W      -1:0]                         dcache_rid,
    input  logic [2             -1:0]                         dcache_rresp,
    input  logic [AXI_DATA_W    -1:0]                         dcache_rdata,
    input  logic                                              dcache_rlast,
    //write addr channel
    output logic                                              dcache_awvalid,
    input  logic                                              dcache_awready,
    output logic [AXI_ADDR_W    -1:0]                         dcache_awaddr,
    output logic [8             -1:0]                         dcache_awlen,
    output logic [3             -1:0]                         dcache_awsize,
    output logic [2             -1:0]                         dcache_awburst,
    output logic                                              dcache_awlock,
    output logic [AXI_ID_W      -1:0]                         dcache_awid,
    //write data channel
    output logic                                              dcache_wvalid,
    input  logic                                              dcache_wready,
    output logic                                              dcache_wlast,
    output logic [AXI_DATA_W    -1:0]                         dcache_wdata,
    output logic [AXI_DATA_W/8  -1:0]                         dcache_wstrb,
    //write resp channel
    input  logic                                              dcache_bvalid,
    output logic                                              dcache_bready,
    input  logic [AXI_ID_W      -1:0]                         dcache_bid,
    input  logic [2             -1:0]                         dcache_bresp
    /* verilator lint_on UNUSEDSIGNAL */
    /* verilator lint_on UNDRIVEN */
);

// import "DPI-C" function void Log_mem_read(longint addr);
// import "DPI-C" function void Log_mem_wirte(longint addr, longint data,byte wmask);

import "DPI-C" function longint sim_sram_read (
    input   longint raddr
);

import "DPI-C" function void sim_sram_write (
    input   longint waddr,
    input   longint wdata,
    input      byte wmask
);

// import "DPI-C" function void halt(byte code);

assign flush_i_ready = 1'b1;

logic        atomic_re_valid;
logic [2:0]  atomic_re_size;
logic [63:0] atomicUnit_re_addr;

always_ff@(posedge clk or negedge rst_n)begin
    if(!rst_n)begin
        atomic_re_valid    <= 0;
        atomic_re_size     <= 0;
        atomicUnit_re_addr <= 0;
    end
    else if(atomicUnit_arvalid & atomicUnit_arready)begin
        atomic_re_valid    <= 1;
        atomic_re_size     <= atomicUnit_arsize;
        atomicUnit_re_addr <= atomicUnit_araddr;
    end
    else if(atomicUnit_awvalid & atomicUnit_awready)begin
        atomic_re_valid    <= 1'b0;
    end
end

always_ff@(posedge clk or negedge rst_n)begin
    if(!rst_n)begin
        atomicUnit_bvalid    <= 0;
        atomicUnit_bresp     <= 0;
    end
    else if(atomicUnit_awvalid & atomicUnit_awready & atomicUnit_wvalid & atomicUnit_wready)begin
        atomicUnit_bvalid    <= 1;
        atomicUnit_bresp     <= (atomic_re_valid & (atomicUnit_re_addr == atomicUnit_awaddr) & (atomic_re_size == atomicUnit_awsize)) ? 2'h1 : 2'h0;
        if(atomic_re_valid & (atomicUnit_re_addr == atomicUnit_awaddr) & (atomic_re_size == atomicUnit_awsize))begin
            sim_sram_write (atomicUnit_awaddr, atomicUnit_wdata, atomicUnit_wstrb);
        end
    end
    else if(atomicUnit_bvalid & atomicUnit_bready)begin
        atomicUnit_bvalid    <= 0;
    end
end
assign atomicUnit_awready  = 1'b1;
assign atomicUnit_wready   = 1'b1;

always_ff@(posedge clk or negedge rst_n)begin
    if(!rst_n)begin
        atomicUnit_rvalid  <= 1'b0;
        atomicUnit_rdata   <= 0;
    end
    else if(atomicUnit_arvalid & atomicUnit_arready)begin
        atomicUnit_rvalid  <= 1'b1;
        atomicUnit_rdata   <= sim_sram_read(atomicUnit_araddr);
    end
    else if(atomicUnit_rvalid & atomicUnit_rready)begin
        atomicUnit_rvalid  <= 1'b0;
    end
end
assign atomicUnit_arready  = 1'b1;
assign atomicUnit_rresp    = 2'h1;

always_ff@(posedge clk or negedge rst_n)begin
    if(!rst_n)begin
        sbuffer_resp_valid  <= 1'b0;
        sbuffer_resp_index  <= 0;
    end
    else if(sbuffer_req_valid & sbuffer_req_ready)begin
        sbuffer_resp_valid  <= 1'b1;
        sbuffer_resp_index  <= sbuffer_req_index;
        sim_sram_write (sbuffer_req_waddr, sbuffer_req_wdata[63:0], sbuffer_req_wstrb[7:0]);
        sim_sram_write ((sbuffer_req_waddr + 8), sbuffer_req_wdata[127:64], sbuffer_req_wstrb[15:8]);
    end
    else if(sbuffer_resp_valid & sbuffer_resp_ready)begin
        sbuffer_resp_valid  <= 1'b0;
    end
end
assign sbuffer_req_ready = 1'b1;

//! TODO 现在仿真让dcache永远miss
assign dcache_load_hit  = 1'b0;
assign dcache_load_data = 64'h0;

always_ff@(posedge clk or negedge rst_n)begin
    if(!rst_n)begin
        load_rvalid  <= 1'b0;
        load_rdata   <= 0;
    end
    else if(redirect)begin
        load_rvalid  <= 1'b0;
        load_rdata   <= 0;
    end
    else if(load_arvalid & load_arready)begin
        load_rvalid  <= 1'b1;
        load_rdata   <= sim_sram_read(load_araddr);
    end
    else if(load_rvalid & load_rready)begin
        load_rvalid  <= 1'b0;
    end
end
assign load_arready  = 1'b1;
assign load_rresp    = 2'h0;

always_ff@(posedge clk or negedge rst_n)begin
    if(!rst_n)begin
        mmu_rvalid  <= 1'b0;
        mmu_rdata   <= 0;
    end
    else if(redirect)begin
        mmu_rvalid  <= 1'b0;
        mmu_rdata   <= 0;
    end
    else if(mmu_arvalid & mmu_arready)begin
        mmu_rvalid  <= 1'b1;
        mmu_rdata   <= sim_sram_read(mmu_araddr);
    end
    else if(mmu_rvalid & mmu_rready)begin
        mmu_rvalid  <= 1'b0;
    end
end
assign mmu_arready  = 1'b1;
assign mmu_rresp    = 2'h0;

assign dcache_arvalid = 1'b0;
assign dcache_awvalid = 1'b0;
assign dcache_wvalid  = 1'b0;

endmodule
