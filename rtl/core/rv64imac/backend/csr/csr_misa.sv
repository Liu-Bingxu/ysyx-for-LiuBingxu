module csr_misa(
    output [63:0]           misa
);

assign misa = 64'h8000_0000_0014_1105; 

endmodule //csr_misa
