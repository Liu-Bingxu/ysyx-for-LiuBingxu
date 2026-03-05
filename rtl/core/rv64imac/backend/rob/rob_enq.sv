module rob_enq
import rob_pkg::*;
import core_setting_pkg::*;
(    
    input                                           rename_fire,
    input              [rename_width - 1 : 0]       rob_req,
    input  rob_entry_t [rename_width - 1 : 0]       rob_req_entry,
    input  rob_entry_ptr_t [rename_width - 1 : 0]   rob_ptr_resp,
    input  rob_entry_ptr_t                          rob_ptr_self,

    output                                          rob_entry_enq_wen,
    output rob_entry_t                              rob_entry_enq
);

logic       enq_wen;
rob_entry_t enq;

//! 由于不好作参数化，所以用此行为级建模
integer i;
always_comb begin : rob_enq_comb
    enq_wen = 0;
    enq     = 0;
    for(i = 0; i < rename_width; i = i + 1)begin
        enq_wen = (enq_wen | (rename_fire & rob_req[i] & (rob_ptr_resp[i] == rob_ptr_self)));
        enq     = (enq     | ({ROB_ENTRY_W{rename_fire & rob_req[i] & (rob_ptr_resp[i] == rob_ptr_self)}} & rob_req_entry[i]));
    end
end

assign rob_entry_enq_wen = enq_wen;
assign rob_entry_enq     = enq;

endmodule //rob_enq
