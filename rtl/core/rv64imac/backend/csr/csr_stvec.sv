module csr_stvec#(parameter RST_PC=64'h0)(
    input                   clk,
    input                   rst_n,
    input                   csr_stvec_wen,
    input  [63:0]           csr_wdata,
    output [63:0]           stvec
);

reg  [63:0]     stvec_reg;

always @(posedge clk or negedge rst_n) begin
    if(!rst_n)begin
        stvec_reg <= RST_PC;
    end
    else if(csr_stvec_wen)begin
        if(csr_wdata[1:0] == 2'h1)begin
            stvec_reg <= csr_wdata;
        end
        else begin
            stvec_reg <= {csr_wdata[63:2],2'h0};
        end
    end
end

assign stvec = stvec_reg;

endmodule //csr_mtvec
