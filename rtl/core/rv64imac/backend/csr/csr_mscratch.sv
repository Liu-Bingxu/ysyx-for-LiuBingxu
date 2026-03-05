module csr_mscratch(
    input                   clk,
    input                   csr_mscratch_wen,
    input  [63:0]           csr_wdata,
    output [63:0]           mscratch
);

reg [63:0]      mscratch_reg;

always @(posedge clk) begin
    if(csr_mscratch_wen)begin
        mscratch_reg <= csr_wdata;
    end
end

assign mscratch = mscratch_reg;

endmodule //csr_mscratch
