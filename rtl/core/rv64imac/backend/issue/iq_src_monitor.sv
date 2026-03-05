module iq_src_monitor
import regfile_pkg::*;
import core_setting_pkg::*;
(
    input                                               entry_valid,
    input  pint_regdest_t                               entry_psrc,

    input                [wb_width - 1 : 0]             rfwen,
    input  pint_regdest_t[wb_width - 1 : 0]             pwdest,

    output logic                                        src_fire
);

//! 不好参数化，所以用行为级建模
integer i;
logic   src_change;
always_comb begin
    src_change = 1'b0;
    for(i = 0; i < wb_width; i = i + 1)begin
        src_change = src_change | (rfwen[i] & (entry_psrc == pwdest[i]));
    end
end

assign src_fire = src_change & entry_valid;

endmodule //iq_src_monitor
