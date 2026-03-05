module csr_scause(
    input                   clk,
    input                   csr_scause_wen,
    input                   trap_s_mode_valid,
    input  [63:0]           csr_wdata,
    input  [63:0]           cause,
    output [63:0]           scause
);

reg [63:0]  scause_reg;

always @(posedge clk) begin
    if(csr_scause_wen)begin
        scause_reg <= csr_wdata;
    end
    else if(trap_s_mode_valid)begin
        scause_reg <= cause;
    end
end

assign scause = scause_reg;

endmodule //csr_scause
