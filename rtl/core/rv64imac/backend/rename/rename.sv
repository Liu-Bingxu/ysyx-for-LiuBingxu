module rename
import decode_pkg::*;
import rename_pkg::*;
import rob_pkg::*;
import lsq_pkg::*;
import regfile_pkg::*;
import core_setting_pkg::*;
(
    input                                               clk,
    input                                               rst_n,

    input                                               redirect,

    input              [dispatch_width - 1 : 0]         rob_can_dispatch,

    input              [decode_width - 1 : 0]           decode_out_valid,
    input  decode_out_t[decode_width - 1 : 0]           decode_out,
    output                                              rename_ready,

    output                                              rename_fire,

    // int rat interface
    output                                              rename_hold,

    input  pint_regsrc_t [decode_width - 1 :0]          int_src1_fromrat,
    input  pint_regsrc_t [decode_width - 1 :0]          int_src2_fromrat,
    input  pint_regdest_t[decode_width - 1 :0]          int_dest_fromrat,

    output               [rename_width - 1 :0]          rename_intrat_valid,
    output      regsrc_t [rename_width - 1 :0]          rename_intrat_dest,
    output pint_regdest_t[rename_width - 1 :0]          rename_intrat_pdest,

    // int free list interface
    output             [rename_width - 1 : 0]           rename_int_req,
    input rename_resp_t[rename_width - 1 : 0]           rename_int_resp,

    // rob interface
    output             [rename_width - 1 : 0]           rob_req,
    output rob_entry_t [rename_width - 1 : 0]           rob_req_entry,
    input  rob_resp_t  [rename_width - 1 : 0]           rob_resp,

    // StoreQueue interface
    output             [rename_width - 1 : 0]           sq_req,
    output  sq_entry_t [rename_width - 1 : 0]           sq_req_entry,
    input   sq_resp_t  [rename_width - 1 : 0]           sq_resp,

    // LoadQueue interface
    output             [rename_width - 1 : 0]           lq_req,
    output  lq_entry_t [rename_width - 1 : 0]           lq_req_entry,
    input   lq_resp_t  [rename_width - 1 : 0]           lq_resp,

    // dispatch interface
    output             [rename_width - 1 : 0]           rename_out_valid,
    output rename_out_t[rename_width - 1 : 0]           rename_out,
    input                                               dispatch_ready
);
rename_out_t[rename_width - 1 : 0]           rename_inst;
logic       [rename_width - 1 : 0]           rename_valid;
rename_out_t[rename_width - 1 : 0]           rename_reg;

logic       [rename_width - 1 : 0]           rename_free_list_fire;
logic       [rename_width - 1 : 0]           rename_rob_fire;
logic       [rename_width - 1 : 0]           rename_sq_fire;
logic       [rename_width - 1 : 0]           rename_lq_fire;

logic       [rename_width - 1 : 0]           rename_rob_finish;

genvar rename_index;
generate for(rename_index = 0 ; rename_index < rename_width; rename_index = rename_index + 1) begin : U_gen_rename
    // int rat interface
    assign rename_intrat_valid[rename_index]        = rename_int_req[rename_index];
    assign rename_intrat_dest [rename_index]        = decode_out[rename_index].wdest;
    assign rename_intrat_pdest[rename_index]        = rename_int_resp[rename_index].rename_dest;

    // int free list interface
    assign rename_int_req[rename_index]             = decode_out_valid[rename_index] & decode_out[rename_index].rfwen & (decode_out[rename_index].wdest != 5'h0) & (!rename_rob_finish[rename_index]);

    // rob interface
    assign rob_req[rename_index]                    = decode_out_valid[rename_index];

    // StoreQueue interface
    assign sq_req[rename_index]                     = decode_out_valid[rename_index] & send2store(decode_out[rename_index].futype) & (!rename_rob_finish[rename_index]);

    // LoadQueue interface
    assign lq_req[rename_index]                     = decode_out_valid[rename_index] & send2load(decode_out[rename_index].futype) & (!rename_rob_finish[rename_index]);

    assign rename_free_list_fire[rename_index]      = ((!rename_int_req[rename_index]) | rename_int_resp[rename_index].rename_valid);
    assign rename_rob_fire[rename_index]            = ((!rob_req[rename_index]) | rob_resp[rename_index].valid);
    assign rename_sq_fire[rename_index]             = ((!sq_req[rename_index])  | sq_resp[rename_index].valid);
    assign rename_lq_fire[rename_index]             = ((!lq_req[rename_index])  | lq_resp[rename_index].valid);

    assign rename_rob_finish[rename_index]          =   (decode_out[rename_index].trap_flag) | 
                                                        ((decode_out[rename_index].rfwen == 1'h0) & use_wdest(decode_out[rename_index].futype));

    if(rename_index == 0)begin: u_gen_pasrc_0
        assign rename_inst[rename_index].psrc1      = (decode_out[rename_index].src1_type == src_imm) ? {{(int_preg_width - 5){1'b0}}, decode_out[rename_index].src1} : int_src1_fromrat[rename_index];
        assign rename_inst[rename_index].psrc2      = (decode_out[rename_index].src2_type == src_imm) ? {{(int_preg_width - 5){1'b0}}, decode_out[rename_index].src2} : int_src2_fromrat[rename_index];
    end
    else begin: u_gen_psrc_another
        pint_regsrc_t bypass_psrc1;
        pint_regsrc_t bypass_psrc2;
        rename_bypass_pdest #(.BYPASS_NUM(rename_index)) u_src1(
            .src_need       (decode_out[rename_index].src1_type == src_reg  ),
            .src            (decode_out[rename_index].src1                  ),
            .psrc           (int_src1_fromrat[rename_index]                 ),
            .rob_entry      (rob_req_entry[rename_index - 1 : 0]            ),
            .psrc_o         (bypass_psrc1                                   )
        );
        rename_bypass_pdest #(.BYPASS_NUM(rename_index)) u_src2(
            .src_need       (decode_out[rename_index].src2_type == src_reg  ),
            .src            (decode_out[rename_index].src2                  ),
            .psrc           (int_src2_fromrat[rename_index]                 ),
            .rob_entry      (rob_req_entry[rename_index - 1 : 0]            ),
            .psrc_o         (bypass_psrc2                                   )
        );
        assign rename_inst[rename_index].psrc1      = (decode_out[rename_index].src1_type == src_imm) ? {{(int_preg_width - 5){1'b0}}, decode_out[rename_index].src1} : bypass_psrc1;
        assign rename_inst[rename_index].psrc2      = (decode_out[rename_index].src2_type == src_imm) ? {{(int_preg_width - 5){1'b0}}, decode_out[rename_index].src2} : bypass_psrc2;
    end

    assign rename_inst[rename_index].futype              = decode_out[rename_index].futype                      ;
    assign rename_inst[rename_index].fuoptype            = decode_out[rename_index].fuoptype                    ;
    assign rename_inst[rename_index].src1_type           = decode_out[rename_index].src1_type                   ;
    assign rename_inst[rename_index].src2_type           = decode_out[rename_index].src2_type                   ;
    assign rename_inst[rename_index].rfwen               = decode_out[rename_index].rfwen                       ;
    assign rename_inst[rename_index].csrwen              = decode_out[rename_index].csrwen                      ;
    assign rename_inst[rename_index].pwdest              = rename_int_resp[rename_index].rename_dest            ;
    assign rename_inst[rename_index].imm                 = decode_out[rename_index].imm                         ;
    assign rename_inst[rename_index].rob_ptr             = rob_resp[rename_index].rob_ptr                       ;
    assign rename_inst[rename_index].lsq_ptr             = (sq_req[rename_index]) ? 
                                                            sq_resp[rename_index].sq_ptr : 
                                                            lq_resp[rename_index].lq_ptr                        ;
    assign rename_inst[rename_index].no_spec_exec        = decode_out[rename_index].no_spec_exec                ;
    assign rename_inst[rename_index].rvc_flag            = decode_out[rename_index].rvc_flag                    ;
    assign rename_inst[rename_index].end_flag            = decode_out[rename_index].end_flag                    ;
    assign rename_inst[rename_index].ftq_ptr             = decode_out[rename_index].ftq_ptr                     ;
    assign rename_inst[rename_index].inst_offset         = decode_out[rename_index].inst_offset                 ;    

    if(rename_index == 0)begin: u_gen_old_pdest_0
        assign rob_req_entry[rename_index].old_pdest     = int_dest_fromrat[rename_index];
    end
    else begin: u_gen_old_pdest_another
        pint_regdest_t bypass_pdest;
        rename_bypass_pdest #(.BYPASS_NUM(rename_index)) u_dest(
            .src_need       (decode_out[rename_index].rfwen         ),
            .src            (decode_out[rename_index].wdest         ),
            .psrc           (int_dest_fromrat[rename_index]         ),
            .rob_entry      (rob_req_entry[rename_index - 1 : 0]    ),
            .psrc_o         (bypass_pdest                           )
        );
        assign rob_req_entry[rename_index].old_pdest        = bypass_pdest;
    end
    assign rob_req_entry[rename_index].finish               = rename_rob_finish[rename_index]             ;
    assign rob_req_entry[rename_index].rfwen                = decode_out[rename_index].rfwen              ;
    assign rob_req_entry[rename_index].wdest                = decode_out[rename_index].wdest              ;
    assign rob_req_entry[rename_index].pwdest               = rename_int_resp[rename_index].rename_dest   ;
    assign rob_req_entry[rename_index].no_intr_exec         = decode_out[rename_index].no_intr_exec       ;
    assign rob_req_entry[rename_index].block_forward_flag   = decode_out[rename_index].block_forward_flag ;
    assign rob_req_entry[rename_index].call                 = decode_out[rename_index].call               ;
    assign rob_req_entry[rename_index].ret                  = decode_out[rename_index].ret                ;
    assign rob_req_entry[rename_index].rvc_flag             = decode_out[rename_index].rvc_flag           ;
    assign rob_req_entry[rename_index].trap_flag            = decode_out[rename_index].trap_flag          ;
    assign rob_req_entry[rename_index].trap_cause           = {1'b0, decode_out[rename_index].trap_cause} ;
    assign rob_req_entry[rename_index].trap_tval            = {32'h0, decode_out[rename_index].trap_tval} ;
    assign rob_req_entry[rename_index].end_flag             = decode_out[rename_index].end_flag           ;
    assign rob_req_entry[rename_index].ftq_ptr              = decode_out[rename_index].ftq_ptr            ;
    assign rob_req_entry[rename_index].inst_offset          = decode_out[rename_index].inst_offset        ;

    /*verilator lint_off ENUMVALUE*/
    assign sq_req_entry[rename_index].rob_ptr               = rob_resp[rename_index].rob_ptr              ;
    assign sq_req_entry[rename_index].storeaddrUnit_op      = decode_out[rename_index].fuoptype           ;
    assign sq_req_entry[rename_index].addr_misalign         = 0                                           ;
    assign sq_req_entry[rename_index].page_error            = 0                                           ;
    assign sq_req_entry[rename_index].addr_finish           = 0                                           ;
    assign sq_req_entry[rename_index].mem_waddr             = 0                                           ;
    assign sq_req_entry[rename_index].data_finish           = 0                                           ;
    assign sq_req_entry[rename_index].mem_wdata             = 0                                           ;
    /*verilator lint_on ENUMVALUE*/

    /*verilator lint_off ENUMVALUE*/
    assign lq_req_entry[rename_index].rob_ptr               = rob_resp[rename_index].rob_ptr              ;
    assign lq_req_entry[rename_index].op                    = decode_out[rename_index].fuoptype           ;
    assign lq_req_entry[rename_index].pwdest                = rename_int_resp[rename_index].rename_dest   ;
    assign lq_req_entry[rename_index].lq_entry_status       = lq_not_addr                                 ;
    assign lq_req_entry[rename_index].addr_misalign         = 0                                           ;
    assign lq_req_entry[rename_index].page_error            = 0                                           ;
    assign lq_req_entry[rename_index].mem_paddr             = 0                                           ;
    assign lq_req_entry[rename_index].mem_vaddr             = 0                                           ;
    /*verilator lint_on ENUMVALUE*/
    //**********************************************************************************************
    //!output
    // valid
    logic send_valid;
    assign send_valid = decode_out_valid[rename_index] & rename_ready & (!rename_rob_finish[rename_index]);
    FF_D_with_syn_rst #(
        .DATA_LEN 	( 1  ),
        .RST_DATA 	( 0  )
    )u_rename_valid
    (
        .clk      	( clk                                   ),
        .rst_n    	( rst_n                                 ),
        .syn_rst    ( redirect                              ),
        .wen        ( ((!(|rename_valid)) | dispatch_ready) ),
        .data_in  	( send_valid                            ),
        .data_out 	( rename_valid[rename_index]            )
    );
    FF_D_without_asyn_rst #(RENAME_O_W) u_rename_o (clk, decode_out_valid[rename_index] & rename_ready, rename_inst[rename_index], rename_reg[rename_index]);
end
endgenerate

assign rename_ready = rename_fire;
assign rename_fire  = ((|decode_out_valid) & (&rename_free_list_fire) & (&rename_rob_fire) & (&rename_sq_fire) & (&rename_lq_fire) & 
                        ((!(|rename_out_valid)) | dispatch_ready) & (rob_can_dispatch == {dispatch_width{1'b1}}));
assign rename_hold  = ((!rename_fire) & (|decode_out_valid));

assign rename_out_valid = rename_valid;
assign rename_out       = rename_reg;

endmodule //rename

