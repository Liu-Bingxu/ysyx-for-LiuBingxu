module csr_mhpmevent(
    input                   clk,
    input                   csr_mhpmevent_wen,
    input  [63:0]           csr_wdata,
    output [63:0]           mhpmevent
);

reg [63:0]      mhpmevent_reg;

always @(posedge clk) begin
    if(csr_mhpmevent_wen)begin
        mhpmevent_reg <= csr_wdata;
    end
end

assign mhpmevent = mhpmevent_reg;

endmodule //csr_mhpmevent
