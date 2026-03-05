module csr_mie(
    input                   clk,
    input                   rst_n,
    input                   csr_mie_wen,
    input                   csr_sie_wen,
    /* verilator lint_off UNUSEDSIGNAL */
    input  [63:0]           csr_wdata,
    /* verilator lint_on UNUSEDSIGNAL */
    input  [63:0]           mideleg,
    output [63:0]           mie,
    output [63:0]           sie
);

reg     STIE,SEIE,SSIE;
reg     MTIE,MEIE,MSIE;

always @(posedge clk or negedge rst_n) begin
    if(!rst_n)begin
        STIE <= 1'b0;
        SEIE <= 1'b0;
        SSIE <= 1'b0;
        MTIE <= 1'b0;
        MEIE <= 1'b0;
        MSIE <= 1'b0;
    end
    else if(csr_mie_wen)begin
        STIE <= csr_wdata[5];
        SEIE <= csr_wdata[9];
        SSIE <= csr_wdata[1];
        MTIE <= csr_wdata[7];
        MEIE <= csr_wdata[11];
        MSIE <= csr_wdata[3];
    end
    else if(csr_sie_wen)begin
        if(mideleg[5] )STIE <= csr_wdata[5];
        if(mideleg[9] )SEIE <= csr_wdata[9];
        if(mideleg[1] )SSIE <= csr_wdata[1];
        if(mideleg[7] )MTIE <= csr_wdata[7];
        if(mideleg[11])MEIE <= csr_wdata[11];
        if(mideleg[3] )MSIE <= csr_wdata[3];
    end
end

assign mie = {52'h0, MEIE, 1'b0, SEIE, 1'b0, MTIE, 1'b0, STIE, 1'b0, MSIE, 1'b0, SSIE, 1'b0};
assign sie = mie & mideleg;

endmodule //csr_mie
