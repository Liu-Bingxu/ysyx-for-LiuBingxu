module precheck
import frontend_pkg::*;
(
    input  [63:0]                   start_pc,
    input                           hit,

    input                           has_one_branch,
    input                           has_two_branch,
    input                           has_three_branch,
    input                           has_jump,

    input                           one_br_is_rvc,
    input  [63:0]                   one_br_bracnch_addr,
    input  [BLOCK_BIT_NUM - 1: 0]   one_br_offset,

    input                           two_br_is_rvc,
    input  [63:0]                   two_br_bracnch_addr,
    input  [BLOCK_BIT_NUM - 1: 0]   two_br_offset,

    input  [BLOCK_BIT_NUM - 1: 0]   three_br_offset,

    input                           jump_is_call,
    input                           jump_is_ret,
    input                           jump_is_jalr,
    input                           jump_is_rvc,
    input  [63:0]                   jump_bracnch_addr,
    input  [BLOCK_BIT_NUM - 1: 0]   jump_offset,

    input  uftb_entry               old_entry,

    output                          update,
    output [63:0]                   end_pc,
    output uftb_entry               new_entry
);
logic three_br  ;
logic two_br    ;
logic br_jump   ;
logic only_jump ;
logic one_br    ;
assign three_br  = has_three_branch;
assign two_br    = has_two_branch;
assign br_jump   = has_jump & has_one_branch;
assign only_jump = has_jump & (!has_one_branch);
assign one_br    = has_one_branch;

logic [63:0] end_pc_three_br;
logic [63:0] end_pc_jump    ;
assign end_pc_three_br  = start_pc + {{(64 - BLOCK_BIT_NUM){1'b0}}, three_br_offset};
assign end_pc_jump       = start_pc + {{(64 - BLOCK_BIT_NUM){1'b0}}, jump_offset} + ((jump_is_rvc) ? 64'h2 : 64'h4);

assign end_pc = ({64{!(three_br | br_jump | only_jump)}} & (start_pc + {{(63 - BLOCK_BIT_NUM){1'b0}}, 1'b1, {(BLOCK_BIT_NUM){1'b0}}})) | 
                ({64{three_br                         }} & end_pc_three_br ) | 
                ({64{br_jump | only_jump              }} & end_pc_jump     );

localparam true  = 1'b1;
localparam false = 1'b0;

assign new_entry.valid  =    false | 
                            ({{three_br }} & true) | 
                            ({{two_br   }} & true) | 
                            ({{br_jump  }} & true) | 
                            ({{only_jump}} & true) | 
                            ({{one_br   }} & true);

assign new_entry.tag    =    start_pc[TAG_BIT_NUM + TAG_START_BIT - 1: TAG_START_BIT];

assign new_entry.br_slot.valid = false | 
                                ({{three_br }} & true ) | 
                                ({{two_br   }} & true ) | 
                                ({{br_jump  }} & true ) | 
                                ({{only_jump}} & false) | 
                                ({{one_br   }} & true );
assign new_entry.br_slot.offset     = one_br_offset;
assign new_entry.br_slot.is_rvc     = one_br_is_rvc;
assign new_entry.br_slot.carry[0]   = ((one_br_bracnch_addr[63:13] - 1) == start_pc[63:13]);
assign new_entry.br_slot.carry[1]   = ((one_br_bracnch_addr[63:13] + 1) == start_pc[63:13]);
assign new_entry.br_slot.next_low   = one_br_bracnch_addr[12:1];
assign new_entry.br_slot.bit2_cnt   = 2'h0;

assign new_entry.tail_slot.valid = false | 
                                ({{three_br }} & true ) | 
                                ({{two_br   }} & true ) | 
                                ({{br_jump  }} & true ) | 
                                ({{only_jump}} & true ) | 
                                ({{one_br   }} & false);
assign new_entry.tail_slot.offset     = (has_jump) ? jump_offset : two_br_offset;
assign new_entry.tail_slot.is_rvc     = (has_jump) ? jump_is_rvc : two_br_is_rvc;
assign new_entry.tail_slot.carry[0]   = (has_jump) ? ((jump_bracnch_addr[63:21] - 1) == start_pc[63:21]) : ((two_br_bracnch_addr[63:21] - 1) == start_pc[63:21]);
assign new_entry.tail_slot.carry[1]   = (has_jump) ? ((jump_bracnch_addr[63:21] + 1) == start_pc[63:21]) : ((two_br_bracnch_addr[63:21] + 1) == start_pc[63:21]);
assign new_entry.tail_slot.next_low   = (has_jump) ? jump_bracnch_addr[20:1] : two_br_bracnch_addr[20:1];
assign new_entry.tail_slot.bit2_cnt   = 2'h0;

assign new_entry.carry      = (end_pc[63:BLOCK_BIT_NUM] != start_pc[63:BLOCK_BIT_NUM]);
assign new_entry.next_low   = end_pc[BLOCK_BIT_NUM - 1 : 0];

assign new_entry.is_branch =    false | 
                            ({{three_br }} & true ) | 
                            ({{two_br   }} & true ) | 
                            ({{br_jump  }} & false) | 
                            ({{only_jump}} & false) | 
                            ({{one_br   }} & false);

assign new_entry.is_call =    false | 
                            ({{three_br }} & false        ) | 
                            ({{two_br   }} & false        ) | 
                            ({{br_jump  }} & jump_is_call ) | 
                            ({{only_jump}} & jump_is_call ) | 
                            ({{one_br   }} & false        );

assign new_entry.is_ret =    false | 
                            ({{three_br }} & false        ) | 
                            ({{two_br   }} & false        ) | 
                            ({{br_jump  }} & jump_is_ret  ) | 
                            ({{only_jump}} & jump_is_ret  ) | 
                            ({{one_br   }} & false        );

assign new_entry.is_jalr =    false | 
                            ({{three_br }} & false        ) | 
                            ({{two_br   }} & false        ) | 
                            ({{br_jump  }} & jump_is_jalr ) | 
                            ({{only_jump}} & jump_is_jalr ) | 
                            ({{one_br   }} & false        );

assign new_entry.always_token = 2'h0;

logic br_slot_valid_check   ;
logic br_slot_offset_check  ;
logic br_slot_carry_check   ;
logic br_slot_next_low_check;
logic br_slot_rvc_check     ;
assign br_slot_valid_check    = old_entry.br_slot.valid != new_entry.br_slot.valid;
assign br_slot_offset_check   = old_entry.br_slot.offset != new_entry.br_slot.offset;
assign br_slot_carry_check    = old_entry.br_slot.carry != new_entry.br_slot.carry;
assign br_slot_next_low_check = old_entry.br_slot.next_low != new_entry.br_slot.next_low;
assign br_slot_rvc_check      = old_entry.br_slot.is_rvc != new_entry.br_slot.is_rvc;

logic br_slot_check;
assign br_slot_check = br_slot_valid_check | 
                    (old_entry.br_slot.valid & br_slot_offset_check) | 
                    (old_entry.br_slot.valid & br_slot_carry_check) | 
                    (old_entry.br_slot.valid & br_slot_next_low_check) | 
                    (old_entry.br_slot.valid & br_slot_rvc_check);

logic tail_slot_valid_check  ;
logic tail_slot_offset_check ;
logic tail_slot_rvc_check    ;
logic tail_slot_bracnch_check;
logic tail_slot_call_check   ;
logic tail_slot_jalr_check   ;
logic tail_slot_ret_check    ;
assign tail_slot_valid_check    = old_entry.tail_slot.valid != new_entry.tail_slot.valid;
assign tail_slot_offset_check   = old_entry.tail_slot.offset != new_entry.tail_slot.offset;
assign tail_slot_rvc_check      = old_entry.tail_slot.is_rvc != new_entry.tail_slot.is_rvc;
assign tail_slot_bracnch_check  = old_entry.is_branch != new_entry.is_branch ;
assign tail_slot_call_check     = old_entry.is_call   != new_entry.is_call   ;
assign tail_slot_jalr_check     = old_entry.is_jalr   != new_entry.is_jalr   ;
assign tail_slot_ret_check      = old_entry.is_ret    != new_entry.is_ret    ;

logic tail_slot_check;
assign tail_slot_check = tail_slot_valid_check | 
                    (old_entry.tail_slot.valid & tail_slot_offset_check   ) | 
                    (old_entry.tail_slot.valid & tail_slot_rvc_check      ) |
                    (old_entry.tail_slot.valid & tail_slot_bracnch_check  ) |
                    (old_entry.tail_slot.valid & tail_slot_call_check     ) |
                    (old_entry.tail_slot.valid & tail_slot_jalr_check     ) |
                    (old_entry.tail_slot.valid & tail_slot_ret_check      );


logic valid_check   ;
logic carry_check   ;
logic next_low_check;
assign valid_check       = old_entry.valid != new_entry.valid;
assign carry_check       = old_entry.carry != new_entry.carry;
assign next_low_check    = old_entry.next_low != new_entry.next_low;

logic entry_check;
assign entry_check = (valid_check | carry_check | next_low_check);

assign update = (br_slot_check | tail_slot_check | entry_check | (!hit));


endmodule //precheck
