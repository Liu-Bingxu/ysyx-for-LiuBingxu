module immu (
    input                   clk,
    input                   rst_n,
//interface with wbu 
    input  [1:0]            current_priv_status,
    input  [3:0]            satp_mode,
    input  [15:0]           satp_asid,
    input  [43:0]           satp_ppn,
//all flush flag 
    output                  flush_flag,
    input                   sflush_vma_valid,
    output                  sflush_vma_ready,
//interface with dcache
    //read addr channel
    input                   immu_arready,
    output                  immu_arvalid,
    output                  immu_aruser,
    output [63:0]           immu_araddr,
    //read data channel
    output                  immu_rready,
    input                   immu_rvalid,
    input  [1:0]            immu_rresp,
    input  [63:0]           immu_rdata,
//interface with fifo
    input                   mmu_fifo_valid,
    output                  mmu_fifo_ready,
    input  [63:0]           vaddr,
//interface with icache
    output                  paddr_valid,
    input                   paddr_ready,
    output [63:0]           paddr,
    output                  paddr_error
);

endmodule //immu
