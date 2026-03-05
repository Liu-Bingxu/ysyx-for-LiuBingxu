module csr_mtval(
    input                   clk,
    input                   csr_mtval_wen,
    input                   trap_m_mode_valid,
    input  [63:0]           csr_wdata,
    input  [63:0]           tval,
    output [63:0]           mtval
);

reg [63:0]  mtval_reg;

always @(posedge clk) begin
    if(csr_mtval_wen)begin
        mtval_reg <= csr_wdata;
    end
    else if(trap_m_mode_valid)begin
        mtval_reg <= tval;
    end
end

assign mtval = mtval_reg;

endmodule //csr_mtval
