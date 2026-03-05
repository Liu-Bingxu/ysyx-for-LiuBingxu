module csr_mip(
    input                   clk,
    input                   rst_n,
    input                   stip,
    input                   seip,
    input                   ssip,
    input                   mtip,
    input                   meip,
    input                   msip,
    input                   csr_mip_wen,
    input                   csr_sip_wen,
    /* verilator lint_off UNUSEDSIGNAL */
    input  [63:0]           csr_wdata,
    /* verilator lint_on UNUSEDSIGNAL */
    input  [63:0]           mideleg,
    output [63:0]           mip,
    output [63:0]           sip
);

reg     STIP,SEIP,SSIP;

always @(posedge clk or negedge rst_n) begin
    if(!rst_n)begin
        STIP <= 1'b0;
        SEIP <= 1'b0;
        SSIP <= 1'b0;
    end
    else if(csr_mip_wen)begin
        STIP <= csr_wdata[5];
        SEIP <= csr_wdata[9];
        SSIP <= csr_wdata[1];
    end
    else if(csr_sip_wen)begin
        if(mideleg[5])STIP <= csr_wdata[5];
        if(mideleg[9])SEIP <= csr_wdata[9];
        if(mideleg[1])SSIP <= csr_wdata[1];
    end
end

assign mip = {52'h0, meip, 1'b0, (seip | SEIP), 1'b0, mtip, 1'b0, (stip | STIP), 1'b0, msip, 1'b0, (ssip | SSIP), 1'b0};
assign sip = mip & mideleg;

endmodule //csr_mip
