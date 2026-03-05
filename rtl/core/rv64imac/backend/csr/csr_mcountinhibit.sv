module csr_mcountinhibit(
    input                   clk,
    input                   rst_n,
    input                   csr_mcountinhibit_wen,
    /* verilator lint_off UNUSEDSIGNAL */
    input  [63:0]           csr_wdata,
    /* verilator lint_on UNUSEDSIGNAL */
    output [63:0]           mcountinhibit
);

reg [31:1]      mcountinhibit_reg;

always @(posedge clk or negedge rst_n) begin
    if(!rst_n)begin
        mcountinhibit_reg <= 31'h0;
    end
    else if(csr_mcountinhibit_wen)begin
        mcountinhibit_reg <= {csr_wdata[31:2],csr_wdata[0]};
    end
end

assign mcountinhibit = {32'h0, mcountinhibit_reg[31:2], 1'b0, mcountinhibit_reg[1]};

endmodule //csr_mcountinhibit
