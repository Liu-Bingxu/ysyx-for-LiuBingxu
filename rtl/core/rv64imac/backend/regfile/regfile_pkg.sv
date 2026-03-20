package regfile_pkg;

import core_setting_pkg::*;

localparam int_preg_width       = 7;

typedef logic [63:0] intreg_t;

typedef logic [int_preg_width - 1:0] pint_regsrc_t;
typedef logic [int_preg_width - 1:0] pint_regdest_t;

function automatic logic pint_wb_flag;
    input                [wb_width - 1 : 0]             rfwen;
    input  pint_regdest_t[wb_width - 1 : 0]             pwdest;
    input  pint_regdest_t                               pint_index;
    //! 不好参数化，所以用行为级建模
    integer i;
    pint_wb_flag = 0;
    for (i = 0; i < wb_width; i = i + 1) begin
        pint_wb_flag = pint_wb_flag | (rfwen[i] & (pwdest[i] == pint_index));
    end
endfunction

function automatic logic pint_dp_flag;
    input                [rename_width - 1 : 0]         pdest_valid;
    input  pint_regdest_t[rename_width - 1 : 0]         pdest;
    input  pint_regdest_t                               pint_index;
    //! 不好参数化，所以用行为级建模
    integer i;
    pint_dp_flag = 0;
    for (i = 0; i < rename_width; i = i + 1) begin
        pint_dp_flag = pint_dp_flag | (pdest_valid[i] & (pdest[i] == pint_index));
    end
endfunction

endpackage
