module csr_mideleg(
    input                   clk,
    input                   rst_n,
    input                   csr_mideleg_wen,
    /* verilator lint_off UNUSEDSIGNAL */
    input  [63:0]           csr_wdata,
    /* verilator lint_on UNUSEDSIGNAL */
    output [63:0]           mideleg
);

reg     MTI,MEI,MSI;
reg     STI,SEI,SSI;

always @(posedge clk or negedge rst_n) begin
    if(!rst_n)begin
        STI <= 1'b0;
        SEI <= 1'b0;
        SSI <= 1'b0;
        MTI <= 1'b0;
        MEI <= 1'b0;
        MSI <= 1'b0;
    end
    else if(csr_mideleg_wen)begin
        STI <= csr_wdata[5];
        SEI <= csr_wdata[9];
        SSI <= csr_wdata[1];
        MTI <= csr_wdata[7];
        MEI <= csr_wdata[11];
        MSI <= csr_wdata[3];
    end
end

assign mideleg = {52'h0, MEI, 1'h0, SEI, 1'h0, MTI, 1'h0, STI, 1'h0, MSI, 1'h0, SSI, 1'b0};

endmodule //csr_mideleg
