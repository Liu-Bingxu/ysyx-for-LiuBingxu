module rename_table
import decode_pkg::*;
import rename_pkg::*;
import regfile_pkg::*;
import core_setting_pkg::*;
(
    input                                               clk,
    input                                               rst_n,

    input                                               redirect,

    input           [decode_width - 1 : 0]              inst_out_valid,
    input           [decode_width - 1 : 0]              decode_inst_ready,

    input  regsrc_t [decode_width - 1 :0]               int_src1_torat,
    input  regsrc_t [decode_width - 1 :0]               int_src2_torat,
    input  regdest_t[decode_width - 1 :0]               int_dest_torat,

    input                                               rename_hold,

    output pint_regsrc_t [decode_width - 1 :0]          int_src1_fromrat,
    output pint_regsrc_t [decode_width - 1 :0]          int_src2_fromrat,
    output pint_regdest_t[decode_width - 1 :0]          int_dest_fromrat,

    input                                               rename_fire,
    input                [rename_width - 1 :0]          rename_intrat_valid,
    input       regsrc_t [rename_width - 1 :0]          rename_intrat_dest,
    input  pint_regdest_t[rename_width - 1 :0]          rename_intrat_pdest,

    input                [commit_width - 1 :0]          commit_intrat_valid,
    input       regsrc_t [commit_width - 1 :0]          commit_intrat_dest,
    input  pint_regdest_t[commit_width - 1 :0]          commit_intrat_pdest
);

pint_regsrc_t[31:1]     int_rat;
pint_regsrc_t[31:1]     int_arch_rat;

logic         [31:1]    int_rat_wen;
pint_regdest_t[31:1]    int_rat_nxt;

pint_regsrc_t [decode_width - 1 :0]          int_src1_fromrat_nxt;
pint_regsrc_t [decode_width - 1 :0]          int_src2_fromrat_nxt;
pint_regdest_t[decode_width - 1 :0]          int_dest_fromrat_nxt;

genvar rat_decode_index;
generate for(rat_decode_index = 0 ; rat_decode_index < decode_width; rat_decode_index = rat_decode_index + 1) begin : U_gen_rat_decode
    logic src1_wen;
    logic src2_wen;
    logic dest_wen;
    assign src1_wen = inst_out_valid[rat_decode_index] & decode_inst_ready[rat_decode_index] & (!rename_hold) & (int_src1_torat[rat_decode_index] != 5'h0);
    assign src2_wen = inst_out_valid[rat_decode_index] & decode_inst_ready[rat_decode_index] & (!rename_hold) & (int_src2_torat[rat_decode_index] != 5'h0);
    assign dest_wen = inst_out_valid[rat_decode_index] & decode_inst_ready[rat_decode_index] & (!rename_hold) & (int_dest_torat[rat_decode_index] != 5'h0);
    assign int_src1_fromrat_nxt[rat_decode_index] = (int_rat_wen[int_src1_torat[rat_decode_index]]) ? int_rat_nxt[int_src1_torat[rat_decode_index]] : int_rat[int_src1_torat[rat_decode_index]];
    assign int_src2_fromrat_nxt[rat_decode_index] = (int_rat_wen[int_src2_torat[rat_decode_index]]) ? int_rat_nxt[int_src2_torat[rat_decode_index]] : int_rat[int_src2_torat[rat_decode_index]];
    assign int_dest_fromrat_nxt[rat_decode_index] = (int_rat_wen[int_dest_torat[rat_decode_index]]) ? int_rat_nxt[int_dest_torat[rat_decode_index]] : int_rat[int_dest_torat[rat_decode_index]];
    FF_D_without_asyn_rst #(
        .DATA_LEN 	( int_preg_width))
    u_int_src1_fromrat(
        .clk      	( clk                                   ),
        .wen      	( src1_wen                              ),
        .data_in  	( int_src1_fromrat_nxt[rat_decode_index]),
        .data_out 	( int_src1_fromrat[rat_decode_index]    )
    );
    FF_D_without_asyn_rst #(
        .DATA_LEN 	( int_preg_width))
    u_int_src2_fromrat( 
        .clk      	( clk                                   ),
        .wen      	( src2_wen                              ),
        .data_in  	( int_src2_fromrat_nxt[rat_decode_index]),
        .data_out 	( int_src2_fromrat[rat_decode_index]    )
    );
    FF_D_without_asyn_rst #(
        .DATA_LEN 	( int_preg_width))
    u_int_dest_fromrat(
        .clk      	( clk                                   ),
        .wen      	( dest_wen                              ),
        .data_in  	( int_dest_fromrat_nxt[rat_decode_index]),
        .data_out 	( int_dest_fromrat[rat_decode_index]    )
    );
end
endgenerate

genvar rat_index;
generate for(rat_index = 1 ; rat_index < 32; rat_index = rat_index + 1) begin : U_gen_rat
    logic           int_arch_rat_wen;
    pint_regdest_t  int_arch_rat_nxt;
    logic           int_temp_rat_wen;
    pint_regdest_t  int_temp_rat_nxt;
    always_comb begin : rename_commit
        int_commit_one(rat_index, commit_intrat_valid, commit_intrat_dest, commit_intrat_pdest, int_arch_rat_wen, int_arch_rat_nxt);
        int_rename_one(rat_index, rename_intrat_valid, rename_intrat_dest, rename_intrat_pdest, int_temp_rat_wen, int_temp_rat_nxt);
        int_rat_wen[rat_index] =    ((int_temp_rat_wen & rename_fire) | redirect);
        int_rat_nxt[rat_index] =    ({int_preg_width{redirect & int_arch_rat_wen   }} & int_arch_rat_nxt       ) | 
                                    ({int_preg_width{redirect & (!int_arch_rat_wen)}} & int_arch_rat[rat_index]) | 
                                    ({int_preg_width{(!redirect) & int_temp_rat_wen}} & int_temp_rat_nxt       );
    end
    FF_D_with_wen #(
        .DATA_LEN 	( int_preg_width                    ),
        .RST_DATA 	( rat_index[int_preg_width - 1:0]   ))
    u_arch_rat(
        .clk      	( clk                       ),
        .rst_n    	( rst_n                     ),
        .wen      	( int_arch_rat_wen          ),
        .data_in  	( int_arch_rat_nxt          ),
        .data_out 	( int_arch_rat[rat_index]   )
    );
    FF_D_with_wen #(
        .DATA_LEN 	( int_preg_width                    ),
        .RST_DATA 	( rat_index[int_preg_width - 1:0]   ))
    u_rat(
        .clk      	( clk                   ),
        .rst_n    	( rst_n                 ),
        .wen      	( int_rat_wen[rat_index]),
        .data_in  	( int_rat_nxt[rat_index]),
        .data_out 	( int_rat[rat_index]    )
    );
end
endgenerate


endmodule //rename_table
