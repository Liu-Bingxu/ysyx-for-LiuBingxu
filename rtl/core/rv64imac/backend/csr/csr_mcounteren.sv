module csr_mcounteren(
    output [63:0]           mcounteren
);

assign mcounteren = {32'h0, {30{1'b1}}, 1'b0, 1'b1};

endmodule //csr_mcounteren
