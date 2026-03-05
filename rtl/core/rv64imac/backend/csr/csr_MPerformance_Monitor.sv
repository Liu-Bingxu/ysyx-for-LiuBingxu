module csr_MPerformance_Monitor(
    input                   clk,
    input                   csr_MPerformance_Monitor_wen,
    input                   MPerformance_Monitor_hibit,
    input                   MPerformance_Monitor_inc,
    input  [63:0]           csr_wdata,
    output [63:0]           MPerformance_Monitor
);

reg  [63:0]     MPerformance_Monitor_reg;

always @(posedge clk) begin
    if(csr_MPerformance_Monitor_wen)begin
        MPerformance_Monitor_reg <= csr_wdata;
    end
    else if((!MPerformance_Monitor_hibit) & MPerformance_Monitor_inc)begin
        MPerformance_Monitor_reg <= MPerformance_Monitor_reg + 1'b1;
    end
end

assign MPerformance_Monitor = MPerformance_Monitor_reg;

endmodule //csr_MPerformance_Monitor
