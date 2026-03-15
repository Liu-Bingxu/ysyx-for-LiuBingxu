module csr_minstret
import core_setting_pkg::*;
(
    input                           clk,
    input                           csr_minstret_wen,
    input                           minstret_hibit,
    input  [commit_width - 1 : 0]   rob_commit_instret,
    input  [63:0]                   csr_wdata,
    output [63:0]                   minstret
);

reg  [63:0]     minstret_reg;

function logic [63:0] instret_pop_count;
    input [commit_width - 1 : 0]   vec;
    //! 由于不好作参数化，所以用此行为级建模
    integer i;
    instret_pop_count = 0;
    for(i = 0; i < commit_width; i = i + 1)begin
        instret_pop_count = instret_pop_count + {63'h0, vec[i]};
    end
endfunction

always @(posedge clk) begin
    if(csr_minstret_wen)begin
        minstret_reg <= csr_wdata;
    end
    else if((!minstret_hibit) & (|rob_commit_instret))begin
        minstret_reg <= minstret_reg + instret_pop_count(rob_commit_instret);
    end
end

assign minstret = minstret_reg;

endmodule //csr_minstret
