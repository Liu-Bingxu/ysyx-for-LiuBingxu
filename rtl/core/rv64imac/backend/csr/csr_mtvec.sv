module csr_mtvec#(parameter RST_PC=64'h0)(
    input                   clk,
    input                   rst_n,
    input                   csr_mtvec_wen,
    input  [63:0]           csr_wdata,
    output [63:0]           mtvec
);

reg  [63:0]     mtvec_reg;

always @(posedge clk or negedge rst_n) begin
    if(!rst_n)begin
        mtvec_reg <= RST_PC;
    end
    else if(csr_mtvec_wen)begin
        if(csr_wdata[1:0] == 2'h1)begin
            mtvec_reg <= csr_wdata;
        end
        else begin
            mtvec_reg <= {csr_wdata[63:2],2'h0};
        end
    end
end

assign mtvec = mtvec_reg;

endmodule //csr_mtvec
