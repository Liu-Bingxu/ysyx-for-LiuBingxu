module csr_dscratch(
    input                   clk,
    input                   csr_dscratch_wen,
    input  [63:0]           csr_wdata,
    output [63:0]           dscratch
);

reg [63:0]      dscratch_reg;

always @(posedge clk) begin
    if(csr_dscratch_wen)begin
        dscratch_reg <= csr_wdata;
    end
end

assign dscratch = dscratch_reg;

endmodule //csr_dscratch
