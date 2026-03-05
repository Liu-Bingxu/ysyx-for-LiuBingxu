module csr_satp(
    input                   clk,
    input                   rst_n,
    input                   csr_satp_wen,
    input  [63:0]           csr_wdata,
    output [63:0]           satp
);

reg [63:0]      satp_reg;

always @(posedge clk or negedge rst_n) begin
    if(!rst_n)begin
        satp_reg <= 64'h0;
    end
    else if((csr_satp_wen) & ((csr_wdata[63:60] == 4'h0) | (csr_wdata[63:60] == 4'h8)))begin
        satp_reg <= csr_wdata;
    end
end

assign satp = satp_reg;

endmodule //csr_satp
