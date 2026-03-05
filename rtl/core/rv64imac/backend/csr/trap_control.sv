module trap_control
import core_setting_pkg::*;
(
    input                   clk,
    input                   rst_n,
    input                   debug_mode,
    input  [1:0]            current_priv_status,
//interface with gen_redirect
    output                  csr_jump_flag,
    output [63:0]           csr_jump_addr,
// interface with rob 
    // common
    input                   rob_can_interrupt,
    input                   rob_commit_valid,
    input  [63:0]           rob_commit_pc,
    input  [63:0]           rob_commit_next_pc,
    // trap
    output                  interrupt_happen,
    input                   rob_trap_valid,
    input  [63:0]           rob_trap_cause,
    input  [63:0]           rob_trap_tval,
//interface with exu 
    input                   alu_csr_fence_exu_valid_o,
    input                   alu_csr_fence_exu_mret_o,
    input                   alu_csr_fence_exu_sret_o,
    input                   alu_csr_fence_exu_dret_o,
//interrupt sign input
    input         	        interrupt_m_flag,
    input         	        interrupt_s_flag,
    input         	        interrupt_debug_flag,
    input  [63:0] 	        interrupt_cause,
    input  [2:0]            interrupt_debug_cause,
//trap sign output
    output                  trap_m_mode_valid,
    output                  trap_s_mode_valid,
    output                  trap_debug_mode_valid,
    output [63:0] 	        epc,
    output [2:0]            debug_cause,
    output [63:0] 	        cause,
    output [63:0] 	        tval,
//debug
    input                   dcsr_ebreakm,
    input                   dcsr_ebreaks,
    input                   dcsr_ebreaku,
//exception
    input  [63:0]           medeleg,
//return pc
    input  [63:0]           mepc,
    input  [63:0]           sepc,
    input  [63:0]           dpc,
//trap vector
    input  [63:0]           mtvec,
    input  [63:0]           stvec
);

wire            ebreak_entry_debug;

wire [63:0]     tvec;
wire [63:0]     trap_addr;
wire            trap_m_interrupt;
wire            trap_m_exception;
wire            trap_s_interrupt;
wire            trap_s_exception;
wire            trap_debug_interrupt;
wire            trap_debug_exception;
wire            debug_exception;

reg  [63:0]     next_pc;

//**********************************************************************************************
always @(posedge clk or negedge rst_n) begin
    if(!rst_n)begin
        next_pc <= RST_PC;
    end
    else begin
        if(csr_jump_flag)begin
            next_pc <= csr_jump_addr;
        end
        else if(alu_csr_fence_exu_valid_o & alu_csr_fence_exu_mret_o)begin
            next_pc <= mepc;
        end
        else if(alu_csr_fence_exu_valid_o & alu_csr_fence_exu_sret_o)begin
            next_pc <= sepc;
        end
        else if(alu_csr_fence_exu_valid_o & alu_csr_fence_exu_dret_o)begin
            next_pc <= dpc;
        end
        else if(rob_commit_valid) begin
            next_pc <= rob_commit_next_pc;
        end
    end
end
assign ebreak_entry_debug   =   (dcsr_ebreakm & (current_priv_status == M_LEVEL)) |
                                (dcsr_ebreaks & (current_priv_status == S_LEVEL)) |
                                (dcsr_ebreaku & (current_priv_status == U_LEVEL));
assign tvec                 = ((trap_debug_mode_valid) ? {52'h0, DEBUG_ENTRY_TVEC} : 
                                    ((debug_exception) ? ((rob_trap_cause[5:0] == 6'h3) ? {52'h0, DEBUG_ENTRY_TVEC} : {52'h0, DEBUG_EXCEPTION_TVEC}) : 
                                        ((trap_s_mode_valid) ? stvec : mtvec))
                            );
assign trap_addr            = (cause[63] & (tvec[1:0] == 2'h1)) ? ({tvec[63:2], 2'h0} + {cause[61:0], 2'h0}) : tvec;
assign trap_m_interrupt     = (interrupt_m_flag     & rob_can_interrupt);
assign trap_s_interrupt     = (interrupt_s_flag     & rob_can_interrupt);
assign trap_debug_interrupt = (interrupt_debug_flag & rob_can_interrupt);
assign trap_m_exception     = (rob_commit_valid & rob_trap_valid & (!trap_s_exception) & (!trap_debug_mode_valid) & (!debug_mode));
assign trap_s_exception     = (rob_commit_valid & rob_trap_valid & medeleg[rob_trap_cause[5:0]] & (current_priv_status <= S_LEVEL) & (!trap_debug_mode_valid) & (!debug_mode));
assign trap_debug_exception = (rob_commit_valid & rob_trap_valid & (rob_trap_cause[5:0] == 6'h3) & ebreak_entry_debug & (!debug_mode));
assign debug_exception      = (rob_commit_valid & rob_trap_valid & debug_mode);
//**********************************************************************************************
assign csr_jump_flag        = (trap_m_mode_valid | trap_s_mode_valid | trap_debug_mode_valid | debug_exception);
assign csr_jump_addr        = trap_addr;
assign interrupt_happen     = (trap_m_interrupt | trap_s_interrupt | trap_debug_interrupt);
assign trap_m_mode_valid    = (trap_m_interrupt | trap_m_exception);
assign trap_s_mode_valid    = (trap_s_interrupt | trap_s_exception);
assign trap_debug_mode_valid= (trap_debug_interrupt | trap_debug_exception);
assign epc                  = (trap_m_interrupt | trap_s_interrupt | trap_debug_interrupt) ? next_pc : rob_commit_pc;
assign debug_cause          = (trap_debug_interrupt) ? interrupt_debug_cause : 3'h1;
assign cause                = (trap_m_interrupt | trap_s_interrupt) ? interrupt_cause : rob_trap_cause;
assign tval                 = (trap_m_interrupt | trap_s_interrupt) ? 64'h0 : rob_trap_tval;
//**********************************************************************************************



endmodule //trap_control
