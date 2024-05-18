module icache (
    input               clk,
    input               rst_n,
//interface with ifu
    //read addr channel
    output                  ifu_arready,
    input                   ifu_arvalid,
    input  [63:0]           ifu_araddr,
    //read data channel
    output                  ifu_rvalid,
    input                   ifu_rready,
    output [1:0]            ifu_rresp,
    output [31:0]           ifu_rdata,
//interface with axi
    //read addr channel
    input                   icache_arready,
    output                  icache_arvalid,
    output [63:0]           icache_araddr,
    output [3:0]            icache_arid,
    output [7:0]            icache_arlen,
    output [2:0]            icache_arsize,
    output [1:0]            icache_arburst,
    //read data channel
    output                  icache_rready,
    input                   icache_rvalid,
    input  [1:0]            icache_rresp,
    input  [63:0]           icache_rdata,
    input                   icache_rlast,
    input  [3:0]            icache_rid
);



endmodule //icache
