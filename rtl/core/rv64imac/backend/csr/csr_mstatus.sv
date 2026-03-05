module csr_mstatus
import core_setting_pkg::M_LEVEL;
(
    input                   clk,
    input                   rst_n,
    input                   csr_mstatus_wen,
    input                   csr_sstatus_wen,
    input                   trap_m_mode_valid,
    input                   trap_s_mode_valid,
    input                   trap_debug_mode_valid,
    input  [1:0]            dcsr_prv,

    input                   alu_csr_fence_exu_valid_o,
    input                   alu_csr_fence_exu_mret_o,
    input                   alu_csr_fence_exu_sret_o,
    input                   alu_csr_fence_exu_dret_o,

    /* verilator lint_off UNUSEDSIGNAL */
    input  [63:0]           csr_wdata,
    /* verilator lint_on UNUSEDSIGNAL */
    output                  mstatus_TSR,
    output                  mstatus_TW,    
    output                  mstatus_TVM,
    output                  mstatus_MXR,
    output                  mstatus_SUM,
    output                  mstatus_MPRV,
    output [1:0]            mstatus_MPP,
    output                  mstatus_MIE,
    output                  mstatus_SIE,
    output [1:0]            current_priv_status,
    output [63:0]           mstatus,
    output [63:0]           sstatus
);

reg             TSR;
reg             TW;
reg             TVM;
reg             MXR;
reg             SUM;
reg             MPRV;
reg [1:0]       MPP;
reg             SPP;
reg             MPIE;
reg             SPIE;
reg             MIE;
reg             SIE;
reg [1:0]       current_priv_status_reg;

always @(posedge clk or negedge rst_n) begin
    if(!rst_n)begin
        TSR                     <= 1'b0;
        TW                      <= 1'b0;
        TVM                     <= 1'b0;
        MXR                     <= 1'b0;
        SUM                     <= 1'b0;
        MPRV                    <= 1'b0;
        MPP                     <= 2'h3;
        SPP                     <= 1'b0;
        MPIE                    <= 1'b0;
        SPIE                    <= 1'b0;
        MIE                     <= 1'b0;
        SIE                     <= 1'b0;
    end
    else if(csr_mstatus_wen)begin
        TSR     <= csr_wdata[22];
        TW      <= csr_wdata[21];
        TVM     <= csr_wdata[20];
        MXR     <= csr_wdata[19];
        SUM     <= csr_wdata[18];
        MPRV    <= csr_wdata[17];
        MPP     <= csr_wdata[12:11];
        SPP     <= csr_wdata[8];
        MPIE    <= csr_wdata[7];
        SPIE    <= csr_wdata[5];
        MIE     <= csr_wdata[3];
        SIE     <= csr_wdata[1];
    end
    else if(csr_sstatus_wen)begin
        MXR     <= csr_wdata[19];
        SUM     <= csr_wdata[18];
        SPP     <= csr_wdata[8];
        SPIE    <= csr_wdata[5];
        SIE     <= csr_wdata[1];
    end
    else if(trap_m_mode_valid)begin
        MPP                     <= current_priv_status;
        MPIE                    <= MIE;
        MIE                     <= 1'b0;
    end
    else if(trap_s_mode_valid)begin
        SPP                     <= (current_priv_status == 2'h1);
        SPIE                    <= SIE;
        SIE                     <= 1'b0;
    end
    else if(alu_csr_fence_exu_valid_o & alu_csr_fence_exu_mret_o)begin
        MPRV                    <= ((MPP == M_LEVEL) & MPRV);
        MPP                     <= 2'h0;
        MPIE                    <= 1'b1;
        MIE                     <= MPIE;
    end
    else if(alu_csr_fence_exu_valid_o & alu_csr_fence_exu_sret_o)begin
        MPRV                    <= 1'b0;
        SPP                     <= 1'b0;
        SPIE                    <= 1'b1;
        SIE                     <= SPIE;
    end
    else if(alu_csr_fence_exu_valid_o & alu_csr_fence_exu_dret_o)begin
        MPRV                    <= ((dcsr_prv == M_LEVEL) & MPRV);
    end
end

always @(posedge clk or negedge rst_n) begin
    if(!rst_n)begin
        current_priv_status_reg <= 2'h3;
    end
    else if(trap_debug_mode_valid)begin
        current_priv_status_reg <= 2'h3;
    end
    else if(trap_m_mode_valid)begin
        current_priv_status_reg <= 2'h3;
    end
    else if(trap_s_mode_valid)begin
        current_priv_status_reg <= 2'h1;
    end
    else if(alu_csr_fence_exu_valid_o & alu_csr_fence_exu_mret_o)begin
        current_priv_status_reg <= MPP;
    end
    else if(alu_csr_fence_exu_valid_o & alu_csr_fence_exu_sret_o)begin
        current_priv_status_reg <= {1'b0, SPP};
    end
    else if(alu_csr_fence_exu_valid_o & alu_csr_fence_exu_dret_o)begin
        current_priv_status_reg <= dcsr_prv;
    end
end

assign mstatus_TSR      = TSR;
assign mstatus_TW       = TW;    
assign mstatus_TVM      = TVM;
assign mstatus_MXR      = MXR;
assign mstatus_SUM      = SUM;
assign mstatus_MPRV     = MPRV;
assign mstatus_MPP      = MPP;
assign mstatus_MIE      = MIE;
assign mstatus_SIE      = SIE;
assign current_priv_status = current_priv_status_reg;

assign mstatus = {/*SD*/1'b0, /*WPRI*/25'h0, /*MBE*/1'b0, /*SBE*/1'b0, /*SXL*/2'b10, /*UXL*/2'b10, 
                    /*WPRI*/9'h0, /*TSR*/TSR, /*TW*/TW, /*TVM*/TVM, /*MXR*/MXR, /*SUM*/SUM, /*MPRV*/MPRV, 
                    /*XS*/2'h0, /*FS*/2'h0, /*MPP*/MPP, /*VS*/2'h0, /*SPP*/SPP, /*MPIE*/MPIE, /*UBE*/1'b0, 
                    /*SPIE*/SPIE, /*WPRI*/1'b0, /*MIE*/MIE, /*WPRI*/1'b0, /*SIE*/SIE, /*WPRI*/1'b0};

assign sstatus = mstatus & 64'h8000_0003_000D_E762;

endmodule //csr_mstatus
