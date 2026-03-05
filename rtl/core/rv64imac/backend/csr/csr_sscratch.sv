module csr_sscratch(
    input                   clk,
    input                   csr_sscratch_wen,
    input  [63:0]           csr_wdata,
    output [63:0]           sscratch
);

reg [63:0]      sscratch_reg;

always @(posedge clk) begin
    if(csr_sscratch_wen)begin
        sscratch_reg <= csr_wdata;
    end
end

assign sscratch = sscratch_reg;

endmodule //csr_sscratch
