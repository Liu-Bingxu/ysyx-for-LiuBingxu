module csr_sepc(
    input                   clk,
    input                   csr_sepc_wen,
    input                   trap_s_mode_valid,
    input  [63:0]           csr_wdata,
    input  [63:0]           epc,
    output [63:0]           sepc
);

/* verilator lint_off UNUSEDSIGNAL */
reg [63:0]  sepc_reg;
/* verilator lint_on UNUSEDSIGNAL */

always @(posedge clk) begin
    if(csr_sepc_wen)begin
        sepc_reg <= csr_wdata;
    end
    else if(trap_s_mode_valid)begin
        sepc_reg <= epc;
    end
end

assign sepc = {sepc_reg[63:1], 1'b0};

endmodule //csr_sepc
