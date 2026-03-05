module csr_dcsr(
    input                   clk,
    input                   rst_n,
    input  [2:0]            debug_cause,
    input  [1:0]            current_priv_status,
    input                   csr_dcsr_wen,
    input                   trap_debug_mode_valid,
    input                   alu_csr_fence_exu_valid_o,
    input                   alu_csr_fence_exu_dret_o,
    /* verilator lint_off UNUSEDSIGNAL */
    input  [63:0]           csr_wdata,
    /* verilator lint_on UNUSEDSIGNAL */
    output                  debug_mode,
    output                  dcsr_ebreakm,
    output                  dcsr_ebreaks,
    output                  dcsr_ebreaku,
    output                  dcsr_step,
    output [1:0]            dcsr_prv,
    output [63:0]           dcsr
);

reg             ebreakm;
reg             ebreaks;
reg             ebreaku;
reg [2:0]       cause;
reg             step;
reg [1:0]       prv;
reg             debug_mode_reg;

always @(posedge clk or negedge rst_n) begin
    if(!rst_n)begin
        ebreakm <= 1'h0;
        ebreaks <= 1'h0;
        ebreaku <= 1'h0;
        cause   <= 3'h0;
        step    <= 1'h0;
        prv     <= 2'h3;
    end
    else if(csr_dcsr_wen)begin
        ebreakm <= csr_wdata[15];
        ebreaks <= csr_wdata[13];
        ebreaku <= csr_wdata[12];
        cause   <= csr_wdata[8:6];
        step    <= csr_wdata[2];
        prv     <= csr_wdata[1:0];
    end
    else if(trap_debug_mode_valid)begin
        cause   <= debug_cause;
        prv     <= current_priv_status;
    end
end

always @(posedge clk or negedge rst_n) begin
    if(!rst_n)begin
        debug_mode_reg <= 1'b0;
    end
    else if(trap_debug_mode_valid)begin
        debug_mode_reg <= 1'b1;
    end
    else if(alu_csr_fence_exu_valid_o & alu_csr_fence_exu_dret_o)begin
        debug_mode_reg <= 1'b0;
    end
end

assign debug_mode = debug_mode_reg;
assign dcsr_ebreakm = ebreakm;
assign dcsr_ebreaks = ebreaks;
assign dcsr_ebreaku = ebreaku;
assign dcsr_step    = step;
assign dcsr_prv     = prv;

assign dcsr = {32'h0, 4'h4/* debugver */, 1'b0, 3'h0/* ext_cause */, 4'h0, 1'b0/* cetrig */, 1'b0, 
            1'b0/* ebreakvs */, 1'b0/* ebreakvu */, ebreakm, 1'b0, ebreaks, ebreaku, 1'b1/* stepie */, 
            1'b0/* stopcount */, 1'b0/* stoptime */, cause, 1'b0/* v */, 1'b1/* mprven */, 1'b0/* nmip */, step, prv};

endmodule //csr_dcsr
