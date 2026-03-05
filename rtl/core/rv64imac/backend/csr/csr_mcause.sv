module csr_mcause(
    input                   clk,
    input                   csr_mcause_wen,
    input                   trap_m_mode_valid,
    input  [63:0]           csr_wdata,
    input  [63:0]           cause,
    output [63:0]           mcause
);

reg [63:0]  mcause_reg;

always @(posedge clk) begin
    if(csr_mcause_wen)begin
        mcause_reg <= csr_wdata;
    end
    else if(trap_m_mode_valid)begin
        mcause_reg <= cause;
    end
end

assign mcause = mcause_reg;

endmodule //csr_mcause
