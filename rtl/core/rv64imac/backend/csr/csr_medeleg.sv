module csr_medeleg(
    input                   clk,
    input                   rst_n,
    input                   csr_medeleg_wen,
    /* verilator lint_off UNUSEDSIGNAL */
    input  [63:0]           csr_wdata,
    /* verilator lint_on UNUSEDSIGNAL */
    output [63:0]           medeleg
);

reg     instruction_addr_misalign;
reg     instruction_access_error;
reg     illegal_instruction;
reg     breakpoint;
reg     load_addr_misalign;
reg     load_access_error;
reg     store_addr_misalign;
reg     store_access_error;
reg     ecall_U;
reg     ecall_S;
reg     ecall_M;
reg     instruction_page_error;
reg     load_page_error;
reg     store_page_error;

always @(posedge clk or negedge rst_n) begin
    if(!rst_n)begin
        instruction_addr_misalign   <= 1'b0;
        instruction_access_error    <= 1'b0;
        illegal_instruction         <= 1'b0;
        breakpoint                  <= 1'b0;
        load_addr_misalign          <= 1'b0;
        load_access_error           <= 1'b0;
        store_addr_misalign         <= 1'b0;
        store_access_error          <= 1'b0;
        ecall_U                     <= 1'b0;
        ecall_S                     <= 1'b0;
        ecall_M                     <= 1'b0;
        instruction_page_error      <= 1'b0;
        load_page_error             <= 1'b0;
        store_page_error            <= 1'b0;
    end
    else if(csr_medeleg_wen)begin
        instruction_addr_misalign   <= csr_wdata[0];
        instruction_access_error    <= csr_wdata[1];
        illegal_instruction         <= csr_wdata[2];
        breakpoint                  <= csr_wdata[3];
        load_addr_misalign          <= csr_wdata[4];
        load_access_error           <= csr_wdata[5];
        store_addr_misalign         <= csr_wdata[6];
        store_access_error          <= csr_wdata[7];
        ecall_U                     <= csr_wdata[8];
        ecall_S                     <= csr_wdata[9];
        ecall_M                     <= csr_wdata[11];
        instruction_page_error      <= csr_wdata[12];
        load_page_error             <= csr_wdata[13];
        store_page_error            <= csr_wdata[15];
    end
end

assign medeleg = {48'h0, store_page_error, 1'b0, load_page_error, instruction_page_error, 
                    ecall_M, 1'b0, ecall_S, ecall_U, store_access_error, store_addr_misalign, 
                    load_access_error, load_addr_misalign, breakpoint, illegal_instruction, 
                    instruction_access_error, instruction_addr_misalign};

endmodule //csr_medeleg
