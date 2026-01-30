`include "./struct.sv"
module uftb#(parameter RST_PC=64'h0)(
    input                           clk,
    input                           rst_n,

    input                           predict,
    output                          pred_push,
    output logic [63:0]             pred_push_pc,
    output                          pred_pop,
    input  [63:0]                   pred_pop_pc,
    output logic [63:0]             pred_pop_pc_i,

    input                           redirect,
    input  [63:0]                   redirect_pc,

    input                           update,
    input                           update_hit,
    input  [UFTB_ENTRY_NUM - 1 : 0] update_sel,
    input  [TAG_BIT_NUM - 1: 0]     update_tag,
    input  uftb_entry               update_entry,

    output ftq_entry                enqueue_entry
);

logic [63:0]    self_pc;
uftb_entry      entry[UFTB_ENTRY_NUM - 1 : 0];

logic [UFTB_ENTRY_NUM - 1 : 0] 	update_hit_sel;

logic                           plru_hit;
logic [UFTB_ENTRY_NUM - 1 : 0] 	hit_sel;
logic                           plru_wen;
logic [UFTB_ENTRY_NUM - 1 : 0] 	plru_sel;

logic [UFTB_ENTRY_NUM - 1 : 0] 	jump_ret_token_sel;
logic [UFTB_ENTRY_NUM - 1 : 0] 	jump_call_token_sel;

logic [63:0] 	                next_pc_sel[UFTB_ENTRY_NUM - 1 : 0];
logic [63:0] 	                push_pc_sel[UFTB_ENTRY_NUM - 1 : 0];
logic [UFTB_ENTRY_NUM - 1 : 0] 	token_sel;
logic [UFTB_ENTRY_NUM - 1 : 0] 	is_tail_sel;

logic                           self_pc_wen;
logic  [63:0]                   self_pc_next;
assign self_pc_wen               = (predict | redirect);
assign self_pc_next              =  ({64{predict}} & (enqueue_entry.next_pc)) | 
                                    ({64{redirect}} & redirect_pc);
FF_D_with_wen #(
    .DATA_LEN 	(64     ),
    .RST_DATA 	(RST_PC ))
u_self_pc(
    .clk      	(clk            ),
    .rst_n    	(rst_n          ),
    .wen      	(self_pc_wen    ),
    .data_in  	(self_pc_next   ),
    .data_out 	(self_pc        )
);

assign plru_hit = (predict & (|hit_sel));
assign plru_wen = (update & ((!update_hit) & (!(|update_hit_sel)) & update_entry.valid));

genvar entry_index;
generate for(entry_index = 0 ; entry_index < UFTB_ENTRY_NUM; entry_index = entry_index + 1) begin : U_gen_uftb_entry
    assign update_hit_sel[entry_index]      = (entry[entry_index].valid & (entry[entry_index].tag == update_tag));

    assign hit_sel[entry_index]             = (entry[entry_index].valid & (entry[entry_index].tag == self_pc[TAG_BIT_NUM + TAG_START_BIT - 1 : TAG_START_BIT]));

    logic br_token  ;
    logic jump_token;
    assign br_token                         = ((entry[entry_index].always_token[0] | entry[entry_index].br_slot.bit2_cnt[1]) & entry[entry_index].br_slot.valid);
    assign jump_token                       = (entry[entry_index].tail_slot.valid & (!entry[entry_index].is_branch) & (!br_token));
    logic tail_token;
    assign tail_token                       = ((entry[entry_index].always_token[1] | entry[entry_index].tail_slot.bit2_cnt[1]) & entry[entry_index].tail_slot.valid & (!br_token));
    assign token_sel[entry_index]           = (br_token | jump_token | tail_token);
    assign is_tail_sel[entry_index]         = (jump_token | tail_token);

    assign jump_ret_token_sel[entry_index]  = jump_token & (entry[entry_index].is_ret);
    assign jump_call_token_sel[entry_index] = jump_token & (entry[entry_index].is_call);
    logic [50:0] br_high                   ;
    logic [42:0] tail_high                 ;
    logic [63-BLOCK_BIT_NUM : 0] block_high;
    assign br_high                          = (self_pc[63:13] + (({51{entry[entry_index].br_slot.carry[0]}} & 51'h1) | ({51{entry[entry_index].br_slot.carry[1]}} & {51{1'b1}})));
    assign tail_high                        = (self_pc[63:21] + (({43{entry[entry_index].tail_slot.carry[0]}} & 43'h1) | ({43{entry[entry_index].tail_slot.carry[1]}} & {43{1'b1}})));
    assign block_high                       = (self_pc[63:BLOCK_BIT_NUM] + (entry[entry_index].carry ? {{(63 - BLOCK_BIT_NUM){1'b0}}, 1'b1} : {(64 - BLOCK_BIT_NUM){1'b0}}));
    assign next_pc_sel[entry_index]         =   ({64{br_token               }} & {br_high, entry[entry_index].br_slot.next_low, 1'b0}) | 
                                                ({64{jump_token | tail_token}} & {tail_high, entry[entry_index].tail_slot.next_low, 1'b0}) | 
                                                ({64{!token_sel[entry_index]}} & {block_high, entry[entry_index].next_low});
    assign push_pc_sel[entry_index]         = self_pc + {{(64 - BLOCK_BIT_NUM){1'b0}}, entry[entry_index].tail_slot.offset} + 
                                            ((entry[entry_index].tail_slot.is_rvc) ? 64'h2 : 64'h4);

    //=============================entry==================================================
    logic entry_update_wen;
    assign entry_update_wen = (update & 
                            ((update_hit & update_sel[entry_index]) | 
                            ((!update_hit) & ( (|update_hit_sel)) & update_entry.valid & update_hit_sel[entry_index]) | 
                            ((!update_hit) & (!(|update_hit_sel)) & update_entry.valid &       plru_sel[entry_index])));
    FF_D_with_wen #(
        .DATA_LEN 	(1  ),
        .RST_DATA 	(0  ))
    u_uftb_entry_valid(
        .clk      	(clk                        ),
        .rst_n    	(rst_n                      ),
        .wen      	(entry_update_wen           ),
        .data_in  	(update_entry.valid         ),
        .data_out 	(entry[entry_index].valid   )
    );
    FF_D_without_asyn_rst #(
        .DATA_LEN 	(TAG_BIT_NUM   ))
    u_uftb_entry_tag(
        .clk      	(clk                    ),
        .wen      	(entry_update_wen       ),
        .data_in  	(update_entry.tag       ),
        .data_out 	(entry[entry_index].tag )
    );
    FF_D_without_asyn_rst #(
        .DATA_LEN 	(18 + BLOCK_BIT_NUM))
    u_uftb_entry_br_slot(
        .clk      	(clk                        ),
        .wen      	(entry_update_wen           ),
        .data_in  	(update_entry.br_slot       ),
        .data_out 	(entry[entry_index].br_slot )
    );
    FF_D_without_asyn_rst #(
        .DATA_LEN 	(26 + BLOCK_BIT_NUM))
    u_uftb_entry_tail_slot(
        .clk      	(clk                            ),
        .wen      	(entry_update_wen               ),
        .data_in  	(update_entry.tail_slot         ),
        .data_out 	(entry[entry_index].tail_slot   )
    );
    FF_D_without_asyn_rst #(
        .DATA_LEN 	(1   ))
    u_uftb_entry_carry(
        .clk      	(clk                        ),
        .wen      	(entry_update_wen           ),
        .data_in  	(update_entry.carry         ),
        .data_out 	(entry[entry_index].carry   )
    );
    FF_D_without_asyn_rst #(
        .DATA_LEN 	(BLOCK_BIT_NUM   ))
    u_uftb_entry_next_low(
        .clk      	(clk                        ),
        .wen      	(entry_update_wen           ),
        .data_in  	(update_entry.next_low       ),
        .data_out 	(entry[entry_index].next_low )
    );
    FF_D_without_asyn_rst #(
        .DATA_LEN 	(1   ))
    u_uftb_entry_is_branch(
        .clk      	(clk                            ),
        .wen      	(entry_update_wen               ),
        .data_in  	(update_entry.is_branch         ),
        .data_out 	(entry[entry_index].is_branch   )
    );
    FF_D_without_asyn_rst #(
        .DATA_LEN 	(1   ))
    u_uftb_entry_is_call(
        .clk      	(clk                        ),
        .wen      	(entry_update_wen           ),
        .data_in  	(update_entry.is_call       ),
        .data_out 	(entry[entry_index].is_call )
    );
    FF_D_without_asyn_rst #(
        .DATA_LEN 	(1   ))
    u_uftb_entry_is_ret(
        .clk      	(clk                        ),
        .wen      	(entry_update_wen           ),
        .data_in  	(update_entry.is_ret        ),
        .data_out 	(entry[entry_index].is_ret  )
    );
    FF_D_without_asyn_rst #(
        .DATA_LEN 	(1   ))
    u_uftb_entry_is_jalr(
        .clk      	(clk                        ),
        .wen      	(entry_update_wen           ),
        .data_in  	(update_entry.is_jalr       ),
        .data_out 	(entry[entry_index].is_jalr )
    );
    FF_D_without_asyn_rst #(
        .DATA_LEN 	(2   ))
    u_uftb_entry_always_token(
        .clk      	(clk                            ),
        .wen      	(entry_update_wen               ),
        .data_in  	(update_entry.always_token       ),
        .data_out 	(entry[entry_index].always_token )
    );
    //=============================entry==================================================
end
endgenerate

generate 
if(UFTB_ENTRY_BIT_NUM == 3) begin : U_gen_plru_2
    plru_8 u_plru_8(
        .clk      	( clk       ),
        .rst_n    	( rst_n     ),
        .hit      	( plru_hit  ),
        .hit_sel  	( hit_sel   ),
        .plru_wen 	( plru_wen  ),
        .wen      	( plru_sel   )
    );
end
else if(UFTB_ENTRY_BIT_NUM == 4) begin : U_gen_plru_4
    plru_16 u_plru_16(
        .clk      	( clk       ),
        .rst_n    	( rst_n     ),
        .hit      	( plru_hit  ),
        .hit_sel  	( hit_sel   ),
        .plru_wen 	( plru_wen  ),
        .wen      	( plru_sel  )
    );
end
else if(UFTB_ENTRY_BIT_NUM == 5) begin : U_gen_plru_4
    plru_32 u_plru_32(
        .clk      	( clk       ),
        .rst_n    	( rst_n     ),
        .hit      	( plru_hit  ),
        .hit_sel  	( hit_sel   ),
        .plru_wen 	( plru_wen  ),
        .wen      	( plru_sel  )
    );
end
else begin : U_gen_error_msg
    `ifdef MODELSIM_SIM
        static_assert(0, "Error: gen_UFTB_ENTRY_BIT_NUM_error_messge");
    `else
        $error("UFTB_ENTRY_BIT_NUM error");
    `endif
end
endgenerate

localparam false = 1'b0;


assign pred_push                        = predict & (|(jump_call_token_sel & hit_sel));
// assign pred_push_pc                     = uftb_next_pc_sel(hit_sel, push_pc_sel);
assign pred_pop                         = predict & (|(jump_ret_token_sel & hit_sel));
// assign pred_pop_pc_i                    = uftb_next_pc_sel(hit_sel, next_pc_sel);

assign enqueue_entry.start_pc           = self_pc;
assign enqueue_entry.next_pc            =   ({64{!(|(jump_ret_token_sel & hit_sel))}} & pred_pop_pc_i) | 
                                            ({64{ (|(jump_ret_token_sel & hit_sel))}} & pred_pop_pc  );
assign enqueue_entry.first_pred_flag    = false;
assign enqueue_entry.hit                = (|hit_sel);
assign enqueue_entry.token              = (|(hit_sel & token_sel));
assign enqueue_entry.is_tail            = (|(hit_sel & is_tail_sel));
assign enqueue_entry.hit_sel            = hit_sel;
// assign enqueue_entry.old_entry          = uftb_entry_sel(hit_sel, entry);

//! 行为级建模，因为不好做参数化
always_comb begin : gen_for
    integer index;
    pred_push_pc            = 64'h0;
    pred_pop_pc_i           = 64'h0;
    enqueue_entry.old_entry = {UFTB_ENTRY_BIT{1'b0}};
    for (index = 0; index < UFTB_ENTRY_NUM; index = index + 1) begin
        pred_push_pc            = pred_push_pc              | (push_pc_sel[index] & {64{hit_sel[index]}});
        pred_pop_pc_i           = pred_pop_pc_i             | (next_pc_sel[index] & {64{hit_sel[index]}});
        enqueue_entry.old_entry = enqueue_entry.old_entry   | (entry[index] & {UFTB_ENTRY_BIT{hit_sel[index]}});
    end
    pred_pop_pc_i = pred_pop_pc_i | (self_pc + {{(63 - BLOCK_BIT_NUM){1'b0}}, 1'b1, {BLOCK_BIT_NUM{1'b0}}} & {64{!(|hit_sel)}});
end

//**********************************************************************************************
//?function
// function [UFTB_ENTRY_BIT - 1:0] uftb_entry_sel;
//     input [UFTB_ENTRY_NUM - 1 : 0]  sel;
//     input uftb_entry                uftb_entry_rdata[UFTB_ENTRY_NUM - 1 : 0];
//     integer index;
//     begin
//         uftb_entry_sel = {UFTB_ENTRY_BIT{1'b0}};
//         for (index = 0; index < UFTB_ENTRY_NUM; index = index + 1) begin
//             uftb_entry_sel = uftb_entry_sel | (uftb_entry_rdata[index] & {UFTB_ENTRY_BIT{sel[index]}});
//         end
//     end
// endfunction
// function [63:0] uftb_next_pc_sel;
//     input [UFTB_ENTRY_NUM - 1 : 0]  sel;
//     input [63:0]                    next_pc_rdata[UFTB_ENTRY_NUM - 1 : 0];
//     integer index;
//     begin
//         uftb_next_pc_sel = 64'h0;
//         for (index = 0; index < UFTB_ENTRY_NUM; index = index + 1) begin
//             uftb_next_pc_sel = uftb_next_pc_sel | (next_pc_rdata[index] & {64{sel[index]}});
//         end
//     end
// endfunction

endmodule //uftb
