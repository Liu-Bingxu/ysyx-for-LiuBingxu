module intregfile
import regfile_pkg::*;
import core_setting_pkg::*;
(
    input                                               clk,

    // read port
    input  pint_regsrc_t                                loadUnit_psrc,
    output intreg_t                                     loadUnit_psrc_rdata,

    input  pint_regsrc_t                                storedataUnit_psrc,
    output intreg_t                                     storedataUnit_psrc_rdata,

    input  pint_regsrc_t                                storeaddrUnit_psrc,
    output intreg_t                                     storeaddrUnit_psrc_rdata,

    input  pint_regsrc_t[1 : 0]                         atomicUnit_psrc,
    output intreg_t     [1 : 0]                         atomicUnit_psrc_rdata,

    input  pint_regsrc_t [1 : 0]                        alu_mul_exu_psrc,
    output intreg_t      [1 : 0]                        alu_mul_exu_psrc_rdata,

    input  pint_regsrc_t [1 : 0]                        alu_div_exu_psrc,
    output intreg_t      [1 : 0]                        alu_div_exu_psrc_rdata,

    input  pint_regsrc_t [1 : 0]                        alu_bru_jump_exu_psrc,
    output intreg_t      [1 : 0]                        alu_bru_jump_exu_psrc_rdata,

    input  pint_regsrc_t [1 : 0]                        alu_csr_fence_exu_psrc,
    output intreg_t      [1 : 0]                        alu_csr_fence_exu_psrc_rdata,

    // write port
    input                                               LoadQueue_valid_o,
    input                                               LoadQueue_rfwen_o,
    input  pint_regdest_t                               LoadQueue_pwdest_o,
    input  [63:0]                                       LoadQueue_preg_wdata_o,

    input                                               atomicUnit_valid_o,
    input                                               atomicUnit_rfwen_o,
    input  pint_regdest_t                               atomicUnit_pwdest_o,
    input  [63:0]                                       atomicUnit_preg_wdata_o,

    input                                               alu_mul_exu_valid_o,
    input  pint_regdest_t                               alu_mul_exu_pwdest_o,
    input  [63:0]                                       alu_mul_exu_preg_wdata_o,

    input                                               alu_div_exu_valid_o,
    input  pint_regdest_t                               alu_div_exu_pwdest_o,
    input  [63:0]                                       alu_div_exu_preg_wdata_o,

    input                                               alu_bru_jump_exu_valid_o,
    input                                               alu_bru_jump_exu_rfwen_o,
    input  pint_regdest_t                               alu_bru_jump_exu_pwdest_o,
    input  [63:0]                                       alu_bru_jump_exu_preg_wdata_o,

    input                                               alu_csr_fence_exu_valid_o,
    input                                               alu_csr_fence_exu_rfwen_o,
    input  pint_regdest_t                               alu_csr_fence_exu_pwdest_o,
    input  [63:0]                                       alu_csr_fence_exu_preg_wdata_o,

    // status update port
    output               [wb_width - 1 : 0]             rfwen,
    output pint_regdest_t[wb_width - 1 : 0]             pwdest
);

// 95个整数寄存器
intreg_t regfile[95:1];

genvar reg_index;
generate for(reg_index = 1 ; reg_index < 96; reg_index = reg_index + 1) begin : U_gen_regfile
    logic       load_exu_wen;
    logic       atomic_exu_wen;
    logic       alu_mul_exu_wen;
    logic       alu_div_exu_wen;
    logic       alu_csr_fence_exu_wen;
    logic       alu_bru_jump_exu_wen;
    logic       regfile_wen;
    intreg_t    regfile_nxt;

    assign load_exu_wen             = LoadQueue_valid_o         & (LoadQueue_pwdest_o           == reg_index) & LoadQueue_rfwen_o;
    assign atomic_exu_wen           = atomicUnit_valid_o        & (atomicUnit_pwdest_o          == reg_index) & atomicUnit_rfwen_o;
    assign alu_mul_exu_wen          = alu_mul_exu_valid_o       & (alu_mul_exu_pwdest_o         == reg_index);
    assign alu_div_exu_wen          = alu_div_exu_valid_o       & (alu_div_exu_pwdest_o         == reg_index);
    assign alu_csr_fence_exu_wen    = alu_csr_fence_exu_valid_o & (alu_csr_fence_exu_pwdest_o   == reg_index) & alu_csr_fence_exu_rfwen_o;
    assign alu_bru_jump_exu_wen     = alu_bru_jump_exu_valid_o  & (alu_bru_jump_exu_pwdest_o    == reg_index) & alu_bru_jump_exu_rfwen_o;

    assign regfile_wen = (load_exu_wen | atomic_exu_wen | alu_div_exu_wen | alu_mul_exu_wen | alu_csr_fence_exu_wen | alu_bru_jump_exu_wen);
    assign regfile_nxt =    ({64{load_exu_wen           }} & LoadQueue_preg_wdata_o         ) | 
                            ({64{atomic_exu_wen         }} & atomicUnit_preg_wdata_o        ) | 
                            ({64{alu_div_exu_wen        }} & alu_div_exu_preg_wdata_o       ) | 
                            ({64{alu_mul_exu_wen        }} & alu_mul_exu_preg_wdata_o       ) | 
                            ({64{alu_csr_fence_exu_wen  }} & alu_csr_fence_exu_preg_wdata_o ) | 
                            ({64{alu_bru_jump_exu_wen   }} & alu_bru_jump_exu_preg_wdata_o  );

    FF_D_without_asyn_rst #(
        .DATA_LEN 	( 64 ))
    u_FF_D_without_asyn_rst(
        .clk      	( clk               ),
        .wen      	( regfile_wen       ),
        .data_in  	( regfile_nxt       ),
        .data_out 	( regfile[reg_index])
    );
end
endgenerate

assign loadUnit_psrc_rdata             = regfile[loadUnit_psrc             ];
assign storedataUnit_psrc_rdata        = regfile[storedataUnit_psrc        ];
assign storeaddrUnit_psrc_rdata        = regfile[storeaddrUnit_psrc        ];
assign atomicUnit_psrc_rdata       [0] = regfile[atomicUnit_psrc        [0]];
assign alu_mul_exu_psrc_rdata      [0] = regfile[alu_mul_exu_psrc       [0]];
assign alu_div_exu_psrc_rdata      [0] = regfile[alu_div_exu_psrc       [0]];
assign alu_bru_jump_exu_psrc_rdata [0] = regfile[alu_bru_jump_exu_psrc  [0]];
assign alu_csr_fence_exu_psrc_rdata[0] = regfile[alu_csr_fence_exu_psrc [0]];
assign atomicUnit_psrc_rdata       [1] = regfile[atomicUnit_psrc        [1]];
assign alu_mul_exu_psrc_rdata      [1] = regfile[alu_mul_exu_psrc       [1]];
assign alu_div_exu_psrc_rdata      [1] = regfile[alu_div_exu_psrc       [1]];
assign alu_bru_jump_exu_psrc_rdata [1] = regfile[alu_bru_jump_exu_psrc  [1]];
assign alu_csr_fence_exu_psrc_rdata[1] = regfile[alu_csr_fence_exu_psrc [1]];

//! TODO 目前不做参数化设计
logic       report_load_exu_wen;
logic       report_atomic_exu_wen;
logic       report_alu_mul_exu_wen;
logic       report_alu_div_exu_wen;
logic       report_alu_csr_fence_exu_wen;
logic       report_alu_bru_jump_exu_wen;

assign report_load_exu_wen             = LoadQueue_valid_o         & LoadQueue_rfwen_o           ;
assign report_atomic_exu_wen           = atomicUnit_valid_o        & atomicUnit_rfwen_o         ;
assign report_alu_mul_exu_wen          = alu_mul_exu_valid_o                                    ;
assign report_alu_div_exu_wen          = alu_div_exu_valid_o                                    ;
assign report_alu_csr_fence_exu_wen    = alu_csr_fence_exu_valid_o & alu_csr_fence_exu_rfwen_o  ;
assign report_alu_bru_jump_exu_wen     = alu_bru_jump_exu_valid_o  & alu_bru_jump_exu_rfwen_o   ;

assign rfwen [0] = report_load_exu_wen         ;
assign rfwen [1] = report_atomic_exu_wen       ;
assign rfwen [2] = report_alu_mul_exu_wen      ;
assign rfwen [3] = report_alu_div_exu_wen      ;
assign rfwen [4] = report_alu_csr_fence_exu_wen;
assign rfwen [5] = report_alu_bru_jump_exu_wen ;
assign pwdest[0] = LoadQueue_pwdest_o          ;
assign pwdest[1] = atomicUnit_pwdest_o         ;
assign pwdest[2] = alu_mul_exu_pwdest_o        ;
assign pwdest[3] = alu_div_exu_pwdest_o        ;
assign pwdest[4] = alu_csr_fence_exu_pwdest_o  ;
assign pwdest[5] = alu_bru_jump_exu_pwdest_o   ;

endmodule //intregfile
