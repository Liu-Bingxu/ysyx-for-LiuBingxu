module rename_bypass_pdest 
import decode_pkg::*;
import rename_pkg::*;
import rob_pkg::*;
import regfile_pkg::*;
import core_setting_pkg::*;
#(
    parameter BYPASS_NUM = 1
)(
    input                                           src_need,
    input  regsrc_t                                 src,
    input  pint_regdest_t                           psrc,
    input  rob_entry_t [BYPASS_NUM - 1 : 0]         rob_entry,

    output pint_regdest_t                           psrc_o
);

//! 不好参数化，所以用行为级建模
integer i;
always_comb begin : bypass_psrc
    psrc_o = psrc;
    for (i = 0; i < BYPASS_NUM; i = i + 1) begin
        if((rob_entry[i].wdest == src) & (rob_entry[i].wdest != 5'h0) & (rob_entry[i].rfwen) & src_need) 
            psrc_o = rob_entry[i].pwdest;
    end
end

endmodule //rename_bypass_pdest
