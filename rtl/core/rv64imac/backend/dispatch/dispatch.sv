module dispatch
import decode_pkg::*;
import rename_pkg::*;
import dispatch_pkg::*;
import iq_pkg::*;
import rob_pkg::*;
import regfile_pkg::*;
import core_setting_pkg::*;
(
    input                                           clk,
    input                                           rst_n,

    input                                           redirect,

    input  [IQ_W - 1 : 0]                           alu_mul_exu_iq_enq_num,
    input  [IQ_W - 1 : 0]                           alu_div_exu_iq_enq_num,
    input  [IQ_W - 1 : 0]                           alu_bru_jump_exu_iq_enq_num,
    input  [IQ_W - 1 : 0]                           alu_csr_fence_exu_iq_enq_num,

    // rename interface
    input              [rename_width - 1 : 0]       rename_out_valid,
    input  rename_out_t[rename_width - 1 : 0]       rename_out,
    output                                          dispatch_ready,

    // rob interface
    output rob_entry_ptr_t                          rob_first_ptr,
    input              [dispatch_width - 1 : 0]     rob_can_dispatch,

    // pint_ststus interface
    output               [dispatch_width - 1 : 0]   pdest_valid,
    output pint_regdest_t[dispatch_width - 1 : 0]   pdest,

    output pint_regsrc_t [dispatch_width - 1 : 0]   dispatch_psrc1,
    output pint_regsrc_t [dispatch_width - 1 : 0]   dispatch_psrc2,
    input  reg_status_t  [dispatch_width - 1 : 0]   dispatch_psrc1_status,
    input  reg_status_t  [dispatch_width - 1 : 0]   dispatch_psrc2_status,

    // int1 issue queue interface
    output                                          alu_mul_exu_in_valid,
    input                                           alu_mul_exu_in_ready,
    output iq_acc_in_t                              alu_mul_exu_in,

    // int2 issue queue interface
    output                                          alu_div_exu_in_valid,
    input                                           alu_div_exu_in_ready,
    output iq_acc_in_t                              alu_div_exu_in,

    // int3 issue queue interface
    output                                          alu_bru_jump_exu_in_valid,
    input                                           alu_bru_jump_exu_in_ready,
    output iq_need_pc_in_t                          alu_bru_jump_exu_in,

    // int4 issue queue interface
    output                                          alu_csr_fence_exu_in_valid,
    input                                           alu_csr_fence_exu_in_ready,
    output iq_csr_in_t                              alu_csr_fence_exu_in,

    // int5 issue queue interface
    output                                          loadUnit_in_valid,
    input                                           loadUnit_in_ready,
    output iq_mem_load_in_t                         loadUnit_in,

    // int6 issue queue interface
    output                                          storeaddrUnit_in_valid,
    input                                           storeaddrUnit_in_ready,
    output iq_mem_store_addr_in_t                   storeaddrUnit_in,

    // int7 issue queue interface
    output                                          storedataUnit_in_valid,
    input                                           storedataUnit_in_ready,
    output iq_mem_store_data_in_t                   storedataUnit_in,

    // int8 issue queue interface
    output                                          atomicUnit_in_valid,
    input                                           atomicUnit_in_ready,
    output iq_mem_atomic_in_t                       atomicUnit_in
);


typedef struct packed {
    // int1 issue queue interface
    logic                   alu_mul_exu_in_valid;
    iq_acc_in_t             alu_mul_exu_in;

    // int2 issue queue interface
    logic                   alu_div_exu_in_valid;
    iq_acc_in_t             alu_div_exu_in;

    // int3 issue queue interface
    logic                   alu_bru_jump_exu_in_valid;
    iq_need_pc_in_t         alu_bru_jump_exu_in;

    // int4 issue queue interface
    logic                   alu_csr_fence_exu_in_valid;
    iq_csr_in_t             alu_csr_fence_exu_in;

    // int5 issue queue interface
    logic                   loadUnit_in_valid;
    iq_mem_load_in_t        loadUnit_in;

    // int6 issue queue interface
    logic                   storeaddrUnit_in_valid;
    iq_mem_store_addr_in_t  storeaddrUnit_in;

    // int7 issue queue interface
    logic                   storedataUnit_in_valid;
    iq_mem_store_data_in_t  storedataUnit_in;

    // int8 issue queue interface
    logic                   atomicUnit_in_valid;
    iq_mem_atomic_in_t      atomicUnit_in;
} dispatch_vec_t;
dispatch_vec_t [dispatch_width - 1 : 0] dispatch_vec_gen/* verilator split_var */;
dispatch_vec_t [dispatch_width - 1 : 0] dispatch_vec_issue;

logic          [dispatch_width - 1 : 0] dispatch_in_mask;
logic          [dispatch_width - 1 : 0] inst_dispatch_success;

logic          [dispatch_width - 1 : 0] dispatch_in_use;
assign dispatch_in_use = rename_out_valid & dispatch_in_mask & rob_can_dispatch;

logic                                   store_can_dispatch;
assign store_can_dispatch = (storeaddrUnit_in_ready & storedataUnit_in_ready);

logic [2:0]                             alu_index[dispatch_width - 1 : 0]/* verilator split_var */;
assign alu_index[0]       = 3'h0;

logic                                   dispatch_in_mask_wen;
logic          [dispatch_width - 1 : 0] dispatch_in_mask_nxt;
assign dispatch_in_mask_wen = (|inst_dispatch_success);
assign dispatch_in_mask_nxt = (dispatch_in_mask & (~inst_dispatch_success));
FF_D_with_syn_rst #(
    .DATA_LEN 	( dispatch_width            ),
    .RST_DATA 	( {dispatch_width{1'b1}}    )
)u_dispatch_in_mask
(
    .clk        ( clk                           ),
    .rst_n      ( rst_n                         ),
    .syn_rst    ( (redirect | dispatch_ready)   ),
    .wen        ( dispatch_in_mask_wen          ),
    .data_in    ( dispatch_in_mask_nxt          ),
    .data_out   ( dispatch_in_mask              )
);

genvar dispatch_index;
generate for(dispatch_index = 0 ; dispatch_index < dispatch_width; dispatch_index = dispatch_index + 1) begin : U_gen_dispatch
    assign dispatch_psrc1[dispatch_index] = rename_out[dispatch_index].psrc1;
    assign dispatch_psrc2[dispatch_index] = rename_out[dispatch_index].psrc2;

    logic       alu_valid;
    /* verilator lint_off UNUSEDSIGNAL */
    logic [2:0] index_next;
    /* verilator lint_on UNUSEDSIGNAL */
    logic       alu_mul_exu_iq_enq_valid;
    logic       alu_div_exu_iq_enq_valid;
    logic       alu_bru_jump_exu_iq_enq_valid;
    logic       alu_csr_fence_exu_iq_enq_valid;
    assign alu_valid = (dispatch_in_use[dispatch_index] & send2alu(rename_out[dispatch_index].futype));
    dispatch_alu_sel u_dispatch_alu_sel(
        .alu_valid                      	(alu_valid                       ),
        .alu_mul_exu_iq_enq_num         	(alu_mul_exu_iq_enq_num          ),
        .alu_div_exu_iq_enq_num         	(alu_div_exu_iq_enq_num          ),
        .alu_bru_jump_exu_iq_enq_num    	(alu_bru_jump_exu_iq_enq_num     ),
        .alu_csr_fence_exu_iq_enq_num   	(alu_csr_fence_exu_iq_enq_num    ),
        .index                          	(alu_index[dispatch_index]       ),
        .index_next                     	(index_next                      ),
        .alu_mul_exu_iq_enq_valid       	(alu_mul_exu_iq_enq_valid        ),
        .alu_div_exu_iq_enq_valid       	(alu_div_exu_iq_enq_valid        ),
        .alu_bru_jump_exu_iq_enq_valid  	(alu_bru_jump_exu_iq_enq_valid   ),
        .alu_csr_fence_exu_iq_enq_valid 	(alu_csr_fence_exu_iq_enq_valid  )
    );
    if(dispatch_index != (dispatch_width - 1))begin : gen_index_nxt
        assign alu_index[dispatch_index + 1] = index_next;
    end

    assign dispatch_vec_gen[dispatch_index].alu_mul_exu_in_valid        = (dispatch_in_use[dispatch_index] & send2mul(rename_out[dispatch_index].futype)) | 
                                                                            alu_mul_exu_iq_enq_valid;
    assign dispatch_vec_gen[dispatch_index].alu_mul_exu_in.futype       = rename_out[dispatch_index].futype                         ;
    assign dispatch_vec_gen[dispatch_index].alu_mul_exu_in.fuoptype     = rename_out[dispatch_index].fuoptype                       ;
    assign dispatch_vec_gen[dispatch_index].alu_mul_exu_in.psrc1        = rename_out[dispatch_index].psrc1                          ;
    assign dispatch_vec_gen[dispatch_index].alu_mul_exu_in.src1_type    = rename_out[dispatch_index].src1_type                      ;
    assign dispatch_vec_gen[dispatch_index].alu_mul_exu_in.src1_status  = (rename_out[dispatch_index].src1_type != src_reg) ? reg_status_fire: 
                                                                        dispatch_psrc1_status[dispatch_index]                       ;
    assign dispatch_vec_gen[dispatch_index].alu_mul_exu_in.psrc2        = rename_out[dispatch_index].psrc2                          ;
    assign dispatch_vec_gen[dispatch_index].alu_mul_exu_in.src2_type    = rename_out[dispatch_index].src2_type                      ;
    assign dispatch_vec_gen[dispatch_index].alu_mul_exu_in.src2_status  = (rename_out[dispatch_index].src2_type != src_reg) ? reg_status_fire: 
                                                                        dispatch_psrc2_status[dispatch_index]                       ;
    assign dispatch_vec_gen[dispatch_index].alu_mul_exu_in.pwdest       = rename_out[dispatch_index].pwdest                         ;
    assign dispatch_vec_gen[dispatch_index].alu_mul_exu_in.imm          = rename_out[dispatch_index].imm                            ;
    assign dispatch_vec_gen[dispatch_index].alu_mul_exu_in.rob_ptr      = rename_out[dispatch_index].rob_ptr[rob_entry_w - 1 : 0]   ;

    assign dispatch_vec_gen[dispatch_index].alu_div_exu_in_valid        = (dispatch_in_use[dispatch_index] & send2div(rename_out[dispatch_index].futype)) | 
                                                                            alu_div_exu_iq_enq_valid;
    assign dispatch_vec_gen[dispatch_index].alu_div_exu_in.futype       = rename_out[dispatch_index].futype                         ;
    assign dispatch_vec_gen[dispatch_index].alu_div_exu_in.fuoptype     = rename_out[dispatch_index].fuoptype                       ;
    assign dispatch_vec_gen[dispatch_index].alu_div_exu_in.psrc1        = rename_out[dispatch_index].psrc1                          ;
    assign dispatch_vec_gen[dispatch_index].alu_div_exu_in.src1_type    = rename_out[dispatch_index].src1_type                      ;
    assign dispatch_vec_gen[dispatch_index].alu_div_exu_in.src1_status  = (rename_out[dispatch_index].src1_type != src_reg) ? reg_status_fire: 
                                                                        dispatch_psrc1_status[dispatch_index]                       ;
    assign dispatch_vec_gen[dispatch_index].alu_div_exu_in.psrc2        = rename_out[dispatch_index].psrc2                          ;
    assign dispatch_vec_gen[dispatch_index].alu_div_exu_in.src2_type    = rename_out[dispatch_index].src2_type                      ;
    assign dispatch_vec_gen[dispatch_index].alu_div_exu_in.src2_status  = (rename_out[dispatch_index].src2_type != src_reg) ? reg_status_fire: 
                                                                        dispatch_psrc2_status[dispatch_index]                       ;
    assign dispatch_vec_gen[dispatch_index].alu_div_exu_in.pwdest       = rename_out[dispatch_index].pwdest                         ;
    assign dispatch_vec_gen[dispatch_index].alu_div_exu_in.imm          = rename_out[dispatch_index].imm                            ;
    assign dispatch_vec_gen[dispatch_index].alu_div_exu_in.rob_ptr      = rename_out[dispatch_index].rob_ptr[rob_entry_w - 1 : 0]   ;

    assign dispatch_vec_gen[dispatch_index].alu_bru_jump_exu_in_valid       = (dispatch_in_use[dispatch_index] & send2jmp(rename_out[dispatch_index].futype)) | 
                                                                            alu_bru_jump_exu_iq_enq_valid;
    assign dispatch_vec_gen[dispatch_index].alu_bru_jump_exu_in.futype      = rename_out[dispatch_index].futype                         ;
    assign dispatch_vec_gen[dispatch_index].alu_bru_jump_exu_in.fuoptype    = rename_out[dispatch_index].fuoptype                       ;
    assign dispatch_vec_gen[dispatch_index].alu_bru_jump_exu_in.psrc1       = rename_out[dispatch_index].psrc1                          ;
    assign dispatch_vec_gen[dispatch_index].alu_bru_jump_exu_in.src1_type   = rename_out[dispatch_index].src1_type                      ;
    assign dispatch_vec_gen[dispatch_index].alu_bru_jump_exu_in.src1_status = (rename_out[dispatch_index].src1_type != src_reg) ? reg_status_fire: 
                                                                        dispatch_psrc1_status[dispatch_index]                           ;
    assign dispatch_vec_gen[dispatch_index].alu_bru_jump_exu_in.psrc2       = rename_out[dispatch_index].psrc2                          ;
    assign dispatch_vec_gen[dispatch_index].alu_bru_jump_exu_in.src2_type   = rename_out[dispatch_index].src2_type                      ;
    assign dispatch_vec_gen[dispatch_index].alu_bru_jump_exu_in.src2_status = (rename_out[dispatch_index].src2_type != src_reg) ? reg_status_fire: 
                                                                        dispatch_psrc2_status[dispatch_index]                           ;
    assign dispatch_vec_gen[dispatch_index].alu_bru_jump_exu_in.rfwen       = rename_out[dispatch_index].rfwen                          ;
    assign dispatch_vec_gen[dispatch_index].alu_bru_jump_exu_in.pwdest      = rename_out[dispatch_index].pwdest                         ;
    assign dispatch_vec_gen[dispatch_index].alu_bru_jump_exu_in.imm         = rename_out[dispatch_index].imm                            ;
    assign dispatch_vec_gen[dispatch_index].alu_bru_jump_exu_in.rob_ptr     = rename_out[dispatch_index].rob_ptr[rob_entry_w - 1 : 0]   ;
    assign dispatch_vec_gen[dispatch_index].alu_bru_jump_exu_in.rvc_flag    = rename_out[dispatch_index].rvc_flag                       ;
    assign dispatch_vec_gen[dispatch_index].alu_bru_jump_exu_in.end_flag    = rename_out[dispatch_index].end_flag                       ;
    assign dispatch_vec_gen[dispatch_index].alu_bru_jump_exu_in.ftq_ptr     = rename_out[dispatch_index].ftq_ptr                        ;
    assign dispatch_vec_gen[dispatch_index].alu_bru_jump_exu_in.inst_offset = rename_out[dispatch_index].inst_offset                    ;

    assign dispatch_vec_gen[dispatch_index].alu_csr_fence_exu_in_valid          = (dispatch_in_use[dispatch_index] & send2csr(rename_out[dispatch_index].futype)) | 
                                                                                    alu_csr_fence_exu_iq_enq_valid;
    assign dispatch_vec_gen[dispatch_index].alu_csr_fence_exu_in.futype         = rename_out[dispatch_index].futype                         ;
    assign dispatch_vec_gen[dispatch_index].alu_csr_fence_exu_in.fuoptype       = rename_out[dispatch_index].fuoptype                       ;
    assign dispatch_vec_gen[dispatch_index].alu_csr_fence_exu_in.psrc1          = rename_out[dispatch_index].psrc1                          ;
    assign dispatch_vec_gen[dispatch_index].alu_csr_fence_exu_in.src1_type      = rename_out[dispatch_index].src1_type                      ;
    assign dispatch_vec_gen[dispatch_index].alu_csr_fence_exu_in.src1_status    = (rename_out[dispatch_index].src1_type != src_reg) ? reg_status_fire: 
                                                                        dispatch_psrc1_status[dispatch_index]                               ;
    assign dispatch_vec_gen[dispatch_index].alu_csr_fence_exu_in.psrc2          = rename_out[dispatch_index].psrc2                          ;
    assign dispatch_vec_gen[dispatch_index].alu_csr_fence_exu_in.src2_type      = rename_out[dispatch_index].src2_type                      ;
    assign dispatch_vec_gen[dispatch_index].alu_csr_fence_exu_in.src2_status    = (rename_out[dispatch_index].src2_type != src_reg) ? reg_status_fire: 
                                                                        dispatch_psrc2_status[dispatch_index]                               ;
    assign dispatch_vec_gen[dispatch_index].alu_csr_fence_exu_in.rfwen          = rename_out[dispatch_index].rfwen                          ;
    assign dispatch_vec_gen[dispatch_index].alu_csr_fence_exu_in.csrwen         = rename_out[dispatch_index].csrwen                         ;
    assign dispatch_vec_gen[dispatch_index].alu_csr_fence_exu_in.pwdest         = rename_out[dispatch_index].pwdest                         ;
    assign dispatch_vec_gen[dispatch_index].alu_csr_fence_exu_in.imm            = rename_out[dispatch_index].imm                            ;
    assign dispatch_vec_gen[dispatch_index].alu_csr_fence_exu_in.rob_ptr        = rename_out[dispatch_index].rob_ptr[rob_entry_w - 1 : 0]   ;
    assign dispatch_vec_gen[dispatch_index].alu_csr_fence_exu_in.no_spec_exec   = rename_out[dispatch_index].no_spec_exec                   ;
    assign dispatch_vec_gen[dispatch_index].alu_csr_fence_exu_in.rvc_flag       = rename_out[dispatch_index].rvc_flag                       ;
    assign dispatch_vec_gen[dispatch_index].alu_csr_fence_exu_in.ftq_ptr        = rename_out[dispatch_index].ftq_ptr                        ;
    assign dispatch_vec_gen[dispatch_index].alu_csr_fence_exu_in.inst_offset    = rename_out[dispatch_index].inst_offset                    ;

    assign dispatch_vec_gen[dispatch_index].loadUnit_in_valid       = (dispatch_in_use[dispatch_index] & send2load(rename_out[dispatch_index].futype));
    assign dispatch_vec_gen[dispatch_index].loadUnit_in.psrc1       = rename_out[dispatch_index].psrc1          ;
    assign dispatch_vec_gen[dispatch_index].loadUnit_in.src1_type   = rename_out[dispatch_index].src1_type      ;
    assign dispatch_vec_gen[dispatch_index].loadUnit_in.src1_status = (rename_out[dispatch_index].src1_type != src_reg) ? reg_status_fire: 
                                                                        dispatch_psrc1_status[dispatch_index]   ;
    assign dispatch_vec_gen[dispatch_index].loadUnit_in.imm         = rename_out[dispatch_index].imm            ;
    assign dispatch_vec_gen[dispatch_index].loadUnit_in.lq_ptr      = rename_out[dispatch_index].lsq_ptr        ;

    assign dispatch_vec_gen[dispatch_index].storeaddrUnit_in_valid          = (dispatch_in_use[dispatch_index] & send2store(rename_out[dispatch_index].futype) & store_can_dispatch);
    assign dispatch_vec_gen[dispatch_index].storeaddrUnit_in.psrc1          = rename_out[dispatch_index].psrc1      ;
    assign dispatch_vec_gen[dispatch_index].storeaddrUnit_in.src1_type      = rename_out[dispatch_index].src1_type  ;
    assign dispatch_vec_gen[dispatch_index].storeaddrUnit_in.src1_status    = (rename_out[dispatch_index].src1_type != src_reg) ? reg_status_fire: 
                                                                        dispatch_psrc1_status[dispatch_index]       ;
    assign dispatch_vec_gen[dispatch_index].storeaddrUnit_in.imm            = rename_out[dispatch_index].imm        ;
    assign dispatch_vec_gen[dispatch_index].storeaddrUnit_in.sq_ptr         = rename_out[dispatch_index].lsq_ptr    ;

    assign dispatch_vec_gen[dispatch_index].storedataUnit_in_valid          = (dispatch_in_use[dispatch_index] & send2store(rename_out[dispatch_index].futype) & store_can_dispatch);
    assign dispatch_vec_gen[dispatch_index].storedataUnit_in.psrc2          = rename_out[dispatch_index].psrc2      ;
    assign dispatch_vec_gen[dispatch_index].storedataUnit_in.src2_type      = rename_out[dispatch_index].src2_type  ;
    assign dispatch_vec_gen[dispatch_index].storedataUnit_in.src2_status    = (rename_out[dispatch_index].src2_type != src_reg) ? reg_status_fire: 
                                                                        dispatch_psrc2_status[dispatch_index]       ;
    assign dispatch_vec_gen[dispatch_index].storedataUnit_in.sq_ptr         = rename_out[dispatch_index].lsq_ptr    ;

    assign dispatch_vec_gen[dispatch_index].atomicUnit_in_valid     = (dispatch_in_use[dispatch_index] & send2amo(rename_out[dispatch_index].futype));
    assign dispatch_vec_gen[dispatch_index].atomicUnit_in.fuoptype  = rename_out[dispatch_index].fuoptype                       ;
    assign dispatch_vec_gen[dispatch_index].atomicUnit_in.psrc1     = rename_out[dispatch_index].psrc1                          ;
    assign dispatch_vec_gen[dispatch_index].atomicUnit_in.src1_type = rename_out[dispatch_index].src1_type                      ;
    assign dispatch_vec_gen[dispatch_index].atomicUnit_in.psrc2     = rename_out[dispatch_index].psrc2                          ;
    assign dispatch_vec_gen[dispatch_index].atomicUnit_in.src2_type = rename_out[dispatch_index].src2_type                      ;
    assign dispatch_vec_gen[dispatch_index].atomicUnit_in.rfwen     = rename_out[dispatch_index].rfwen                          ;
    assign dispatch_vec_gen[dispatch_index].atomicUnit_in.pwdest    = rename_out[dispatch_index].pwdest                         ;
    assign dispatch_vec_gen[dispatch_index].atomicUnit_in.imm       = rename_out[dispatch_index].imm                            ;
    assign dispatch_vec_gen[dispatch_index].atomicUnit_in.rob_ptr   = rename_out[dispatch_index].rob_ptr[rob_entry_w - 1 : 0]   ;


    if(dispatch_index == 0)begin: U_gen_issue_vec_0
        assign dispatch_vec_issue[dispatch_index].alu_mul_exu_in_valid          = dispatch_vec_gen[dispatch_index].alu_mul_exu_in_valid      ;
        assign dispatch_vec_issue[dispatch_index].alu_mul_exu_in                = dispatch_vec_gen[dispatch_index].alu_mul_exu_in            ;
        assign dispatch_vec_issue[dispatch_index].alu_div_exu_in_valid          = dispatch_vec_gen[dispatch_index].alu_div_exu_in_valid      ;
        assign dispatch_vec_issue[dispatch_index].alu_div_exu_in                = dispatch_vec_gen[dispatch_index].alu_div_exu_in            ;
        assign dispatch_vec_issue[dispatch_index].alu_bru_jump_exu_in_valid     = dispatch_vec_gen[dispatch_index].alu_bru_jump_exu_in_valid ;
        assign dispatch_vec_issue[dispatch_index].alu_bru_jump_exu_in           = dispatch_vec_gen[dispatch_index].alu_bru_jump_exu_in       ;
        assign dispatch_vec_issue[dispatch_index].alu_csr_fence_exu_in_valid    = dispatch_vec_gen[dispatch_index].alu_csr_fence_exu_in_valid;
        assign dispatch_vec_issue[dispatch_index].alu_csr_fence_exu_in          = dispatch_vec_gen[dispatch_index].alu_csr_fence_exu_in      ;
        assign dispatch_vec_issue[dispatch_index].loadUnit_in_valid             = dispatch_vec_gen[dispatch_index].loadUnit_in_valid         ;
        assign dispatch_vec_issue[dispatch_index].loadUnit_in                   = dispatch_vec_gen[dispatch_index].loadUnit_in               ;
        assign dispatch_vec_issue[dispatch_index].storeaddrUnit_in_valid        = dispatch_vec_gen[dispatch_index].storeaddrUnit_in_valid    ;
        assign dispatch_vec_issue[dispatch_index].storeaddrUnit_in              = dispatch_vec_gen[dispatch_index].storeaddrUnit_in          ;
        assign dispatch_vec_issue[dispatch_index].storedataUnit_in_valid        = dispatch_vec_gen[dispatch_index].storedataUnit_in_valid    ;
        assign dispatch_vec_issue[dispatch_index].storedataUnit_in              = dispatch_vec_gen[dispatch_index].storedataUnit_in          ;
        assign dispatch_vec_issue[dispatch_index].atomicUnit_in_valid           = dispatch_vec_gen[dispatch_index].atomicUnit_in_valid       ;
        assign dispatch_vec_issue[dispatch_index].atomicUnit_in                 = dispatch_vec_gen[dispatch_index].atomicUnit_in             ;
        assign inst_dispatch_success[dispatch_index]    =   (dispatch_vec_gen[dispatch_index].alu_mul_exu_in_valid       & alu_mul_exu_in_ready) | 
                                                            (dispatch_vec_gen[dispatch_index].alu_div_exu_in_valid       & alu_div_exu_in_ready) | 
                                                            (dispatch_vec_gen[dispatch_index].alu_bru_jump_exu_in_valid  & alu_bru_jump_exu_in_ready) | 
                                                            (dispatch_vec_gen[dispatch_index].alu_csr_fence_exu_in_valid & alu_csr_fence_exu_in_ready) | 
                                                            (dispatch_vec_gen[dispatch_index].loadUnit_in_valid          & loadUnit_in_ready) | 
                                                            (dispatch_vec_gen[dispatch_index].storeaddrUnit_in_valid     & storeaddrUnit_in_ready) | 
                                                            (dispatch_vec_gen[dispatch_index].atomicUnit_in_valid        & atomicUnit_in_ready);
    end
    else begin: U_gen_issue_vec_another
        assign dispatch_vec_issue[dispatch_index].alu_mul_exu_in_valid          = (dispatch_vec_gen[dispatch_index].alu_mul_exu_in_valid | 
                                                                                dispatch_vec_issue[dispatch_index - 1].alu_mul_exu_in_valid)        ;
        assign dispatch_vec_issue[dispatch_index].alu_mul_exu_in                = (dispatch_vec_issue[dispatch_index - 1].alu_mul_exu_in_valid) ? 
                                                                                dispatch_vec_issue[dispatch_index - 1].alu_mul_exu_in : 
                                                                                dispatch_vec_gen[dispatch_index].alu_mul_exu_in                     ;
        assign dispatch_vec_issue[dispatch_index].alu_div_exu_in_valid          = (dispatch_vec_gen[dispatch_index].alu_div_exu_in_valid | 
                                                                                dispatch_vec_issue[dispatch_index - 1].alu_div_exu_in_valid)        ;
        assign dispatch_vec_issue[dispatch_index].alu_div_exu_in                = (dispatch_vec_issue[dispatch_index - 1].alu_div_exu_in_valid) ? 
                                                                                dispatch_vec_issue[dispatch_index - 1].alu_div_exu_in : 
                                                                                dispatch_vec_gen[dispatch_index].alu_div_exu_in                     ;
        assign dispatch_vec_issue[dispatch_index].alu_bru_jump_exu_in_valid     = (dispatch_vec_gen[dispatch_index].alu_bru_jump_exu_in_valid | 
                                                                                dispatch_vec_issue[dispatch_index - 1].alu_bru_jump_exu_in_valid)   ;
        assign dispatch_vec_issue[dispatch_index].alu_bru_jump_exu_in           = (dispatch_vec_issue[dispatch_index - 1].alu_bru_jump_exu_in_valid) ? 
                                                                                dispatch_vec_issue[dispatch_index - 1].alu_bru_jump_exu_in  : 
                                                                                dispatch_vec_gen[dispatch_index].alu_bru_jump_exu_in                ;
        assign dispatch_vec_issue[dispatch_index].alu_csr_fence_exu_in_valid    = (dispatch_vec_gen[dispatch_index].alu_csr_fence_exu_in_valid | 
                                                                                dispatch_vec_issue[dispatch_index - 1].alu_csr_fence_exu_in_valid)  ;
        assign dispatch_vec_issue[dispatch_index].alu_csr_fence_exu_in          = (dispatch_vec_issue[dispatch_index - 1].alu_csr_fence_exu_in_valid) ? 
                                                                                dispatch_vec_issue[dispatch_index - 1].alu_csr_fence_exu_in : 
                                                                                dispatch_vec_gen[dispatch_index].alu_csr_fence_exu_in               ;
        assign dispatch_vec_issue[dispatch_index].loadUnit_in_valid             = (dispatch_vec_gen[dispatch_index].loadUnit_in_valid | 
                                                                                dispatch_vec_issue[dispatch_index - 1].loadUnit_in_valid)           ;
        assign dispatch_vec_issue[dispatch_index].loadUnit_in                   = (dispatch_vec_issue[dispatch_index - 1].loadUnit_in_valid) ? 
                                                                                dispatch_vec_issue[dispatch_index - 1].loadUnit_in : 
                                                                                dispatch_vec_gen[dispatch_index].loadUnit_in                        ;
        assign dispatch_vec_issue[dispatch_index].storeaddrUnit_in_valid        = (dispatch_vec_gen[dispatch_index].storeaddrUnit_in_valid | 
                                                                                dispatch_vec_issue[dispatch_index - 1].storeaddrUnit_in_valid)      ;
        assign dispatch_vec_issue[dispatch_index].storeaddrUnit_in              = (dispatch_vec_issue[dispatch_index - 1].storeaddrUnit_in_valid) ? 
                                                                                dispatch_vec_issue[dispatch_index - 1].storeaddrUnit_in : 
                                                                                dispatch_vec_gen[dispatch_index].storeaddrUnit_in                   ;
        assign dispatch_vec_issue[dispatch_index].storedataUnit_in_valid        = (dispatch_vec_gen[dispatch_index].storedataUnit_in_valid | 
                                                                                dispatch_vec_issue[dispatch_index - 1].storedataUnit_in_valid)      ;
        assign dispatch_vec_issue[dispatch_index].storedataUnit_in              = (dispatch_vec_issue[dispatch_index - 1].storedataUnit_in_valid) ? 
                                                                                dispatch_vec_issue[dispatch_index - 1].storedataUnit_in : 
                                                                                dispatch_vec_gen[dispatch_index].storedataUnit_in                   ;
        assign dispatch_vec_issue[dispatch_index].atomicUnit_in_valid           = (dispatch_vec_gen[dispatch_index].atomicUnit_in_valid | 
                                                                                dispatch_vec_issue[dispatch_index - 1].atomicUnit_in_valid)         ;
        assign dispatch_vec_issue[dispatch_index].atomicUnit_in                 = (dispatch_vec_issue[dispatch_index - 1].atomicUnit_in_valid) ? 
                                                                                dispatch_vec_issue[dispatch_index - 1].atomicUnit_in : 
                                                                                dispatch_vec_gen[dispatch_index].atomicUnit_in                      ;
        assign inst_dispatch_success[dispatch_index]    =   (dispatch_vec_gen[dispatch_index].alu_mul_exu_in_valid          & (!dispatch_vec_issue[dispatch_index - 1].alu_mul_exu_in_valid)        & alu_mul_exu_in_ready) | 
                                                            (dispatch_vec_gen[dispatch_index].alu_div_exu_in_valid          & (!dispatch_vec_issue[dispatch_index - 1].alu_div_exu_in_valid)        & alu_div_exu_in_ready) | 
                                                            (dispatch_vec_gen[dispatch_index].alu_bru_jump_exu_in_valid     & (!dispatch_vec_issue[dispatch_index - 1].alu_bru_jump_exu_in_valid)   & alu_bru_jump_exu_in_ready) | 
                                                            (dispatch_vec_gen[dispatch_index].alu_csr_fence_exu_in_valid    & (!dispatch_vec_issue[dispatch_index - 1].alu_csr_fence_exu_in_valid)  & alu_csr_fence_exu_in_ready) | 
                                                            (dispatch_vec_gen[dispatch_index].loadUnit_in_valid             & (!dispatch_vec_issue[dispatch_index - 1].loadUnit_in_valid)           & loadUnit_in_ready) | 
                                                            (dispatch_vec_gen[dispatch_index].storeaddrUnit_in_valid        & (!dispatch_vec_issue[dispatch_index - 1].storeaddrUnit_in_valid)      & storeaddrUnit_in_ready) | 
                                                            (dispatch_vec_gen[dispatch_index].atomicUnit_in_valid           & (!dispatch_vec_issue[dispatch_index - 1].atomicUnit_in_valid)         & atomicUnit_in_ready);
    end
    assign pdest_valid[dispatch_index]  = (inst_dispatch_success[dispatch_index] & rename_out[dispatch_index].rfwen);
    assign pdest      [dispatch_index]  = rename_out[dispatch_index].pwdest;
end
endgenerate

assign dispatch_ready                = ((rename_out_valid & dispatch_in_mask & inst_dispatch_success) == (rename_out_valid & dispatch_in_mask));

assign rob_first_ptr                 = rename_out[0].rob_ptr[rob_entry_w - 1 : 0];

assign alu_mul_exu_in_valid          = dispatch_vec_issue[dispatch_width - 1].alu_mul_exu_in_valid      ;
assign alu_mul_exu_in                = dispatch_vec_issue[dispatch_width - 1].alu_mul_exu_in            ;
assign alu_div_exu_in_valid          = dispatch_vec_issue[dispatch_width - 1].alu_div_exu_in_valid      ;
assign alu_div_exu_in                = dispatch_vec_issue[dispatch_width - 1].alu_div_exu_in            ;
assign alu_bru_jump_exu_in_valid     = dispatch_vec_issue[dispatch_width - 1].alu_bru_jump_exu_in_valid ;
assign alu_bru_jump_exu_in           = dispatch_vec_issue[dispatch_width - 1].alu_bru_jump_exu_in       ;
assign alu_csr_fence_exu_in_valid    = dispatch_vec_issue[dispatch_width - 1].alu_csr_fence_exu_in_valid;
assign alu_csr_fence_exu_in          = dispatch_vec_issue[dispatch_width - 1].alu_csr_fence_exu_in      ;
assign loadUnit_in_valid             = dispatch_vec_issue[dispatch_width - 1].loadUnit_in_valid         ;
assign loadUnit_in                   = dispatch_vec_issue[dispatch_width - 1].loadUnit_in               ;
assign storeaddrUnit_in_valid        = dispatch_vec_issue[dispatch_width - 1].storeaddrUnit_in_valid    ;
assign storeaddrUnit_in              = dispatch_vec_issue[dispatch_width - 1].storeaddrUnit_in          ;
assign storedataUnit_in_valid        = dispatch_vec_issue[dispatch_width - 1].storedataUnit_in_valid    ;
assign storedataUnit_in              = dispatch_vec_issue[dispatch_width - 1].storedataUnit_in          ;
assign atomicUnit_in_valid           = dispatch_vec_issue[dispatch_width - 1].atomicUnit_in_valid       ;
assign atomicUnit_in                 = dispatch_vec_issue[dispatch_width - 1].atomicUnit_in             ;

endmodule //dispatch
