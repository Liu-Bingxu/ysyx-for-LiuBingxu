module interrupt_control
import core_setting_pkg::M_LEVEL;
import core_setting_pkg::S_LEVEL;
import core_setting_pkg::decode_width;
(
    input                           clk,
    input                           rst_n,
    input                           mstatus_MIE,
    input                           mstatus_SIE,
    input  [1:0]                    current_priv_status,
    input  [63:0]                   mip,
    input  [63:0]                   sip,
    input  [63:0]                   mie,
    input  [63:0]                   sie,
    input  [63:0]                   mideleg,
    input                           halt_req,
    input                           debug_mode,
    input                           dcsr_step,
//interface with rename
    input  [decode_width - 1 : 0]   decode_out_valid,
    input                           rename_ready,
//interface with exu
    input                           alu_csr_fence_exu_valid_o,
    input                           alu_csr_fence_exu_dret_o,

    input                           trap_debug_mode_valid,
    output                          interrupt_m_flag,
    output                          interrupt_s_flag,
    output                          interrupt_debug_flag,
    output [63:0]                   interrupt_cause,
    output [2:0]                    interrupt_debug_cause
);

wire            m_mode_interrupt_enable;
wire            s_mode_interrupt_enable;
wire [63:0]     m_mode_interrupt_pending;
wire [63:0]     s_mode_interrupt_pending;
/* verilator lint_off UNUSEDSIGNAL */
wire [63:0]     interrupt_pending;
/* verilator lint_on UNUSEDSIGNAL */

wire            interrupt_m_flag_inter;
wire            interrupt_s_flag_inter;

reg  [1:0]      debug_step_flag;

always @(posedge clk or negedge rst_n) begin
    if(!rst_n)begin
        debug_step_flag <= 2'h0;
    end
    else if(alu_csr_fence_exu_valid_o & alu_csr_fence_exu_dret_o & dcsr_step)begin
        debug_step_flag <= 2'h1;
    end
    else if((debug_step_flag == 2'h1) & (|decode_out_valid) & rename_ready)begin
        debug_step_flag <= 2'h2;
    end
    else if((debug_step_flag == 2'h2) & trap_debug_mode_valid)begin
        debug_step_flag <= 2'h0;
    end
end

assign m_mode_interrupt_enable  = (mstatus_MIE | (current_priv_status < M_LEVEL));
assign s_mode_interrupt_enable  = ((mstatus_SIE | (current_priv_status < S_LEVEL)) & (current_priv_status != M_LEVEL));
assign m_mode_interrupt_pending = (mie & mip & (~mideleg));
assign s_mode_interrupt_pending = (sie & sip);
assign        interrupt_pending = ((m_mode_interrupt_pending & {64{interrupt_m_flag_inter}}) | 
                                    (s_mode_interrupt_pending & {64{interrupt_s_flag_inter}}));

assign interrupt_m_flag_inter   = (m_mode_interrupt_enable & (|m_mode_interrupt_pending) & (!interrupt_debug_flag) & (!debug_mode));
assign interrupt_s_flag_inter   = (s_mode_interrupt_enable & (|s_mode_interrupt_pending) & (!interrupt_debug_flag) & (!debug_mode));

assign interrupt_m_flag         = (interrupt_m_flag_inter & m_mode_interrupt_pending[interrupt_cause[5:0]]);
assign interrupt_s_flag         = (interrupt_s_flag_inter & s_mode_interrupt_pending[interrupt_cause[5:0]]);
assign interrupt_debug_flag     = ((halt_req | ((debug_step_flag == 2'h1) &  & (|decode_out_valid) & rename_ready) | (debug_step_flag == 2'h2)) & (!debug_mode));

assign interrupt_cause          = (interrupt_pending[11]) ? 64'h8000_0000_0000_000B : (
                                    (interrupt_pending[3]) ? 64'h8000_0000_0000_0003 : (
                                        (interrupt_pending[7]) ? 64'h8000_0000_0000_0007 : (
                                            (interrupt_pending[9]) ? 64'h8000_0000_0000_0009 : (
                                                (interrupt_pending[1]) ? 64'h8000_0000_0000_0001 : (
                                                    (interrupt_pending[5]) ? 64'h8000_0000_0000_0005 : 64'h8000_0000_0000_0000
                                                )
                                            )
                                        )
                                    )
                                );
assign interrupt_debug_cause    = (halt_req) ? 3'h3 : 3'h4;

endmodule //interrupt_control
