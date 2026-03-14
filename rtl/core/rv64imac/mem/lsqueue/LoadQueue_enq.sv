module LoadQueue_enq
import lsq_pkg::*;
import core_setting_pkg::*;
(    
    input                                           rename_fire,
    input              [rename_width - 1 : 0]       lq_req,
    input  lq_entry_t  [rename_width - 1 : 0]       lq_req_entry,
    input  LQ_entry_ptr_t [rename_width - 1 : 0]    lq_ptr_resp,
    input  LQ_entry_ptr_t                           lq_ptr_self,

    output                                          lq_entry_enq_wen,
    output lq_entry_t                               lq_entry_enq
);

logic       enq_wen;
lq_entry_t  enq;

//! 由于不好作参数化，所以用此行为级建模
integer i;
always_comb begin : sq_enq_comb
    enq_wen = 0;
    enq     = 0;
    for(i = 0; i < rename_width; i = i + 1)begin
        enq_wen = (enq_wen | (rename_fire & lq_req[i] & (lq_ptr_resp[i] == lq_ptr_self)));
        enq     = (enq     | ({LQ_ENTRY_W{rename_fire & lq_req[i] & (lq_ptr_resp[i] == lq_ptr_self)}} & lq_req_entry[i]));
    end
end

assign lq_entry_enq_wen = enq_wen;
assign lq_entry_enq     = enq;

endmodule //LoadQueue_enq
