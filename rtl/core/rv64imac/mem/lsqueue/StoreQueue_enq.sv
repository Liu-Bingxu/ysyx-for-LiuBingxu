module StoreQueue_enq
import lsq_pkg::*;
import core_setting_pkg::*;
(    
    input                                           rename_fire,
    input              [rename_width - 1 : 0]       sq_req,
    input  sq_entry_t [rename_width - 1 : 0]        sq_req_entry,
    input  SQ_entry_ptr_t [rename_width - 1 : 0]    sq_ptr_resp,
    input  SQ_entry_ptr_t                           sq_ptr_self,

    output                                          sq_entry_enq_wen,
    output sq_entry_t                               sq_entry_enq
);

logic       enq_wen;
sq_entry_t  enq;

//! 由于不好作参数化，所以用此行为级建模
integer i;
always_comb begin : sq_enq_comb
    enq_wen = 0;
    enq     = 0;
    for(i = 0; i < rename_width; i = i + 1)begin
        enq_wen = (enq_wen | (rename_fire & sq_req[i] & (sq_ptr_resp[i] == sq_ptr_self)));
        enq     = (enq     | ({SQ_ENTRY_W{rename_fire & sq_req[i] & (sq_ptr_resp[i] == sq_ptr_self)}} & sq_req_entry[i]));
    end
end

assign sq_entry_enq_wen = enq_wen;
assign sq_entry_enq     = enq;

endmodule //rob_enq
