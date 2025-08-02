module booth2_code_gen#(
    DATA_WIDTH = 32
)(
    input  [DATA_WIDTH - 1 :0]  A,
    input  [3          - 1 :0]  code,
    output [DATA_WIDTH     :0]  product,
    output [2          - 1 :0]  h,
    output                      sign_not
);

assign product = {(DATA_WIDTH + 1){1'b0}} |
                ({(DATA_WIDTH + 1){code == 3'h0}} & {(DATA_WIDTH +1){1'b0}}) | 
                ({(DATA_WIDTH + 1){code == 3'h1}} & {A[DATA_WIDTH - 1],  A}) | 
                ({(DATA_WIDTH + 1){code == 3'h2}} & {A[DATA_WIDTH - 1],  A}) | 
                ({(DATA_WIDTH + 1){code == 3'h3}} & {A,               1'b0}) | 
                ({(DATA_WIDTH + 1){code == 3'h4}} & {~A,              1'b0}) | 
                ({(DATA_WIDTH + 1){code == 3'h5}} & {~A[DATA_WIDTH - 1],~A}) | 
                ({(DATA_WIDTH + 1){code == 3'h6}} & {~A[DATA_WIDTH - 1],~A}) | 
                ({(DATA_WIDTH + 1){code == 3'h7}} & {(DATA_WIDTH +1){1'b0}});

assign h    =    {2{1'b0}} |
                ({2{code == 3'h0}} & 2'h0) | 
                ({2{code == 3'h1}} & 2'h0) | 
                ({2{code == 3'h2}} & 2'h0) | 
                ({2{code == 3'h3}} & 2'h0) | 
                ({2{code == 3'h4}} & 2'h2) | 
                ({2{code == 3'h5}} & 2'h1) | 
                ({2{code == 3'h6}} & 2'h1) | 
                ({2{code == 3'h7}} & 2'h0);

assign sign_not =   {1'b0} |
                    ((code == 3'h0) & 1'h1) | 
                    ((code == 3'h1) & ~A[DATA_WIDTH - 1]) | 
                    ((code == 3'h2) & ~A[DATA_WIDTH - 1]) | 
                    ((code == 3'h3) & ~A[DATA_WIDTH - 1]) | 
                    ((code == 3'h4) &  A[DATA_WIDTH - 1]) | 
                    ((code == 3'h5) &  A[DATA_WIDTH - 1]) | 
                    ((code == 3'h6) &  A[DATA_WIDTH - 1]) | 
                    ((code == 3'h7) & 1'h1);

endmodule //booth2_code_gen
