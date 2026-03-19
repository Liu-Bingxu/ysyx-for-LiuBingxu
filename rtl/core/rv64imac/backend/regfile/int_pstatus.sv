module int_pstatus
import regfile_pkg::*;
import core_setting_pkg::*;
(
    input                                               clk,
    input                                               rst_n,

    input                                               redirect,

    output                                              rename_fire,

    input                [wb_width - 1 : 0]             rfwen,
    input  pint_regdest_t[wb_width - 1 : 0]             pwdest,

    input                [rename_width - 1 : 0]         pdest_valid,
    input  pint_regdest_t[rename_width - 1 : 0]         pdest,

    input  pint_regsrc_t [rename_width - 1 : 0]         dispatch_psrc1,
    input  pint_regsrc_t [rename_width - 1 : 0]         dispatch_psrc2,
    output               [rename_width - 1 : 0]         dispatch_psrc1_status,
    output               [rename_width - 1 : 0]         dispatch_psrc2_status
);

// 95个整数寄存器
logic regfile_status[95:1];
logic regfile_status_wen[95:1];
logic regfile_status_nxt[95:1];

genvar reg_index;
generate for(reg_index = 1 ; reg_index < 96; reg_index = reg_index + 1) begin : U_gen_regfile_sattus
    logic regfile_status_clr;
    logic regfile_status_set;
    assign regfile_status_set = pint_wb_flag(rfwen, pwdest, reg_index);
    assign regfile_status_clr = pint_dp_flag((pdest_valid & {rename_width{rename_fire}}), pdest, reg_index);

    assign regfile_status_wen[reg_index]    = (regfile_status_set | regfile_status_clr);
    assign regfile_status_nxt[reg_index]    = (regfile_status_set | (!regfile_status_clr));

    FF_D_with_syn_rst #(
        .DATA_LEN 	( 1 ),
        .RST_DATA   ( 1 ))
    u_regfile_status(
        .clk      	( clk                           ),
        .rst_n    	( rst_n                         ),
        .syn_rst    ( redirect                      ),
        .wen      	( regfile_status_wen[reg_index] ),
        .data_in  	( regfile_status_nxt[reg_index] ),
        .data_out 	( regfile_status[reg_index]     )
    );
end
endgenerate

genvar dispatch_index;
generate for(dispatch_index = 0 ; dispatch_index < rename_width; dispatch_index = dispatch_index + 1) begin : U_gen_regfile_out
    assign dispatch_psrc1_status[dispatch_index] = (!(|(dispatch_psrc1[dispatch_index]))) ? 1'b1 :
    ((regfile_status_wen[dispatch_psrc1[dispatch_index]]) ? regfile_status_nxt[dispatch_psrc1[dispatch_index]]: regfile_status[dispatch_psrc1[dispatch_index]]);
    assign dispatch_psrc2_status[dispatch_index] = (!(|(dispatch_psrc2[dispatch_index]))) ? 1'b1 :
    ((regfile_status_wen[dispatch_psrc2[dispatch_index]]) ? regfile_status_nxt[dispatch_psrc2[dispatch_index]]: regfile_status[dispatch_psrc2[dispatch_index]]);
end
endgenerate

endmodule //int_pstatus
