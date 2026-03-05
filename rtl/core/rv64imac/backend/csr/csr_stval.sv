module csr_stval(
    input                   clk,
    input                   csr_stval_wen,
    input                   trap_s_mode_valid,
    input  [63:0]           csr_wdata,
    input  [63:0]           tval,
    output [63:0]           stval
);

reg [63:0]  stval_reg;

always @(posedge clk) begin
    if(csr_stval_wen)begin
        stval_reg <= csr_wdata;
    end
    else if(trap_s_mode_valid)begin
        stval_reg <= tval;
    end
end

assign stval = stval_reg;

endmodule //csr_stval
