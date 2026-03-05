module csr_mhartid#(parameter MHARTID = 0) (
    output [63:0]           mhartid
);

assign mhartid = MHARTID;

endmodule //csr_mhartid
