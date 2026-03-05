module csr_mepc(
    input                   clk,
    input                   csr_mepc_wen,
    input                   trap_m_mode_valid,
    input  [63:0]           csr_wdata,
    input  [63:0]           epc,
    output [63:0]           mepc
);

/* verilator lint_off UNUSEDSIGNAL */
reg [63:0]  mepc_reg;
/* verilator lint_on UNUSEDSIGNAL */

always @(posedge clk) begin
    if(csr_mepc_wen)begin
        mepc_reg <= csr_wdata;
    end
    else if(trap_m_mode_valid)begin
        mepc_reg <= epc;
    end
end

assign mepc = {mepc_reg[63:1], 1'b0};

endmodule //csr_mepc
