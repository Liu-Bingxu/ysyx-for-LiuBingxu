module csr_dpc(
    input                   clk,
    input                   csr_dpc_wen,
    input                   trap_debug_mode_valid,
    input  [63:0]           csr_wdata,
    input  [63:0]           epc,
    output [63:0]           dpc
);

/* verilator lint_off UNUSEDSIGNAL */
reg [63:0]  dpc_reg;
/* verilator lint_on UNUSEDSIGNAL */

always @(posedge clk) begin
    if(csr_dpc_wen)begin
        dpc_reg <= csr_wdata;
    end
    else if(trap_debug_mode_valid)begin
        dpc_reg <= epc;
    end
end

assign dpc = {dpc_reg[63:1], 1'b0};

endmodule //csr_dpc
