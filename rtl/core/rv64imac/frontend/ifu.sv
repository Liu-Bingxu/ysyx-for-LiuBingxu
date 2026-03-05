module ifu 
import frontend_pkg::*;
import core_setting_pkg::decode_width;
(
    input                                           clk,
    input                                           rst_n,

    input                                           ifu_send_entry_valid,
    output                                          ifu_send_entry_ready,
    input  ftq_entry                                ifu_send_entry,

    output                                          ifu_dequeue_entry_ready,
    input  ftq_entry                                ifu_dequeue_entry,
    input  [FTQ_ENTRY_BIT_NUM - 1 : 0]              ifu_dequeue_ptr,

    input                                           commit_restore,

    //! TODO precheck_push/pop 可以尝试和restore同时有效
    output                                          if_precheck_restore,
    output                                          if_precheck_update,
    output [63:0]                                   if_precheck_retsore_pc,
    output                                          if_precheck_token,
    output                                          if_precheck_is_tail,
    output uftb_entry                               new_entry,
    output                                          if_precheck_push,
    output [63:0]                                   if_precheck_push_pc,
    output                                          if_precheck_pop,
    output [63:0]                                   if_precheck_pop_pc_i,
    input  [63:0]                                   if_precheck_pop_pc,

    //read addr channel
    input                                           ifu_arready,
    output                                          ifu_arvalid,
    output [63:0]                                   ifu_araddr,

    //read data channel
    input                                           ifu_rvalid,
    output                                          ifu_rready,
    input  [1:0]                                    ifu_rresp,
    input  [63:0]                                   ifu_rdata,

    //ifu - idu interface
    output ibuf_inst_o_entry[decode_width - 1 :0]   ibuf_inst_o,
    input  [decode_width - 1 :0]                    decode_inst_ready
);

//==============================stage 1:fetch code(send addr)==========================================================

localparam ADDR_IDLE    = 2'h0;
localparam SEND_ADDR    = 2'h1;
logic [1:0]                             fetch_fsm;

logic [IFU_SEND_ADDR_BIT - 1 : 0]       fetch_cnt;

logic                                   ifu_arvalid_reg;
logic [63:3]                            ifu_araddr_reg;

logic                                   addr_offset_push;
logic                                   addr_offset_pop;
logic                                   addr_offset_empty;
logic                                   addr_offset_full;
logic [1:0]                             addr_offset_rdata;

always_ff @(posedge clk or negedge rst_n) begin
    if(!rst_n)begin
        fetch_fsm       <= ADDR_IDLE;
        fetch_cnt       <= 0;
        ifu_arvalid_reg <= 1'b0;
    end
    else if(commit_restore | if_precheck_restore)begin
        fetch_fsm       <= ADDR_IDLE;
        fetch_cnt       <= 0;
        ifu_arvalid_reg <= 1'b0;
    end
    else begin
        case (fetch_fsm)
            ADDR_IDLE: begin
                if(ifu_send_entry_valid & (!addr_offset_full))begin
                    fetch_fsm       <= SEND_ADDR;
                    ifu_arvalid_reg <= 1'b1;
                end
            end
            SEND_ADDR: begin
                if(ifu_arvalid & ifu_arready & (fetch_cnt == (IFU_SEND_ADDR_NUM[IFU_SEND_ADDR_BIT - 1 : 0] - 1)) & ifu_send_entry_valid & (!addr_offset_full))begin
                    fetch_fsm       <= SEND_ADDR;
                    fetch_cnt       <= 0;
                end
                else if(ifu_arvalid & ifu_arready & (fetch_cnt == (IFU_SEND_ADDR_NUM[IFU_SEND_ADDR_BIT - 1 : 0] - 1)))begin
                    fetch_fsm       <= ADDR_IDLE;
                    fetch_cnt       <= 0;
                    ifu_arvalid_reg <= 1'b0;
                end
                else if(ifu_arvalid & ifu_arready)begin
                    fetch_fsm <= SEND_ADDR;
                    fetch_cnt <= fetch_cnt + 1'b1;
                end
            end
            default: begin
                fetch_fsm       <= ADDR_IDLE;
                fetch_cnt       <= 0;
                ifu_arvalid_reg <= 1'b0;
            end
        endcase
    end
end

logic        araddr_idle_wen;
logic        araddr_send_wen;
logic        araddr_wen     ;
logic [63:3] araddr_nxt     ;
assign araddr_idle_wen = addr_offset_push;
assign araddr_send_wen = (fetch_fsm == SEND_ADDR) & ifu_arvalid & ifu_arready & (!araddr_idle_wen);
assign araddr_wen      = (araddr_idle_wen | araddr_send_wen);
assign araddr_nxt      =    ({61{araddr_idle_wen}} & (ifu_send_entry.start_pc[63:3] )) | 
                            ({61{araddr_send_wen}} & (ifu_araddr_reg + 1            ));
FF_D_without_asyn_rst #(
    .DATA_LEN 	( 61  ))
u_ifu_araddr_reg(
    .clk      	( clk               ),
    .wen      	( araddr_wen        ),
    .data_in  	( araddr_nxt        ),
    .data_out 	( ifu_araddr_reg    )
);
assign ifu_send_entry_ready = addr_offset_push;

assign ifu_arvalid = ifu_arvalid_reg;
assign ifu_araddr  = {ifu_araddr_reg, 3'h0};

fifo #(
    .DATA_W 	(2                  ),
    .AddR_W 	(FTQ_ENTRY_BIT_NUM  ))
u_addr_offset_fifo(
    .clk    	(clk                                    ),
    .rst_n  	(rst_n                                  ),
    .Wready 	(addr_offset_push                       ),
    .Rready 	(addr_offset_pop                        ),
    .flush  	(if_precheck_restore | commit_restore   ),
    .wdata  	(ifu_send_entry.start_pc[2:1]           ),
    .empty  	(addr_offset_empty                      ),
    .full   	(addr_offset_full                       ),
    .rdata  	(addr_offset_rdata                      )
);
assign addr_offset_push = ifu_send_entry_valid & (!addr_offset_full) & ((fetch_fsm == ADDR_IDLE)  | 
                        (fetch_fsm == SEND_ADDR) & ifu_arvalid & ifu_arready & (fetch_cnt == (IFU_SEND_ADDR_NUM[IFU_SEND_ADDR_BIT - 1 : 0] - 1)));

//==============stage 1.5:recv and send data ==================================
logic                                   fetch_valid;
logic                                   fetch_ready;
logic [IFU_SEND_ADDR_NUM * 64 - 1 :0]   fetch_code;
logic [IFU_SEND_ADDR_NUM * 64 - 1 :0]   fetch_use_code;
logic [IFU_SEND_ADDR_NUM * 64 - 49 :0]  fetch_code_shift;
logic [IFU_SEND_ADDR_NUM * 64 - 49 :0]  fetch_code_shift_reg;
logic [IFU_SEND_ADDR_NUM * 2 - 1 :0]    fetch_rresp;
logic [IFU_SEND_ADDR_NUM * 2 - 1 :0]    fetch_use_rresp;
logic [IFU_SEND_ADDR_NUM * 2 + 1 :0]    fetch_rresp_reg;
logic [IFU_SEND_ADDR_NUM * 8 - 1 :0]    fetch_rresp_reg_extend;
logic [IFU_SEND_ADDR_NUM * 8 - 7 :0]    fetch_rresp_reg_shift;

logic                                   ifu_rready_reg;

logic [IFU_SEND_ADDR_BIT - 1 : 0]       fetch_data_cnt;

localparam RECV_DATA = 2'h0;
localparam HANDLE    = 2'h1;
logic [1:0]                             fetch_data_fsm;

logic                                   fsm_recv_send;
logic                                   fsm_handle_send;

assign fsm_recv_send    = (fetch_data_fsm == RECV_DATA) & ifu_rvalid & ifu_rready & (fetch_data_cnt == (IFU_SEND_ADDR_NUM[IFU_SEND_ADDR_BIT - 1 : 0] - 1));
assign fsm_handle_send  = (fetch_data_fsm == HANDLE);

assign fetch_use_code = ({IFU_SEND_ADDR_NUM * 64{fsm_recv_send  }} & {ifu_rdata, fetch_code[IFU_SEND_ADDR_NUM * 64 - 65 :0]}) | 
                        ({IFU_SEND_ADDR_NUM * 64{fsm_handle_send}} & fetch_code);
assign fetch_use_rresp =    ({IFU_SEND_ADDR_NUM * 2{fsm_recv_send  }} & {ifu_rresp, fetch_rresp[IFU_SEND_ADDR_NUM * 2 - 3 :0]}) | 
                            ({IFU_SEND_ADDR_NUM * 2{fsm_handle_send}} & fetch_rresp);

assign addr_offset_pop = (fsm_recv_send | fsm_handle_send) & ((!fetch_valid) | fetch_ready) & (!addr_offset_empty);

always_ff @(posedge clk or negedge rst_n) begin
    if(!rst_n)begin
        fetch_data_fsm       <= RECV_DATA;
        fetch_data_cnt       <= 0;
        ifu_rready_reg       <= 1'b1;
    end
    else if(commit_restore | if_precheck_restore)begin
        fetch_data_fsm       <= RECV_DATA;
        fetch_data_cnt       <= 0;
        ifu_rready_reg       <= 1'b1;
    end
    else begin
        case (fetch_data_fsm)
            RECV_DATA: begin
                if(addr_offset_pop)begin
                    fetch_data_fsm       <= RECV_DATA;
                    fetch_data_cnt       <= 0;
                    ifu_rready_reg       <= 1'b1;
                end
                else if(ifu_rvalid & ifu_rready & (fetch_data_cnt == (IFU_SEND_ADDR_NUM[IFU_SEND_ADDR_BIT - 1 : 0] - 1)))begin
                    fetch_data_fsm       <= HANDLE;
                    fetch_data_cnt       <= 0;
                    ifu_rready_reg       <= 1'b0;
                end
                else if(ifu_rvalid & ifu_rready)begin
                    fetch_data_fsm       <= RECV_DATA;
                    fetch_data_cnt       <= fetch_data_cnt + 1'b1;
                end
            end
            HANDLE: begin
                if(addr_offset_pop)begin
                    fetch_data_fsm       <= RECV_DATA;
                    fetch_data_cnt       <= 0;
                    ifu_rready_reg       <= 1'b1;
                end
            end
            default: begin
                fetch_data_fsm       <= RECV_DATA;
                fetch_data_cnt       <= 0;
                ifu_rready_reg       <= 1'b1;
            end
        endcase
    end
end

genvar extend_index;
generate for(extend_index = 0 ; extend_index < IFU_SEND_ADDR_NUM; extend_index = extend_index + 1) begin : U_extend_flag
    assign fetch_rresp_reg_extend[extend_index * 8 +  1 : extend_index * 8 +  0] = fetch_rresp_reg[extend_index * 2 + 1 : extend_index * 2];
    assign fetch_rresp_reg_extend[extend_index * 8 +  3 : extend_index * 8 +  2] = fetch_rresp_reg[extend_index * 2 + 1 : extend_index * 2];
    assign fetch_rresp_reg_extend[extend_index * 8 +  5 : extend_index * 8 +  4] = fetch_rresp_reg[extend_index * 2 + 1 : extend_index * 2];
    assign fetch_rresp_reg_extend[extend_index * 8 +  7 : extend_index * 8 +  6] = fetch_rresp_reg[extend_index * 2 + 1 : extend_index * 2];

    logic fetch_wen;
    assign fetch_wen = ifu_rvalid & ifu_rready & (extend_index == fetch_data_cnt);

    FF_D_without_asyn_rst #(
        .DATA_LEN 	( 64  ))
    u_fetch_data(
        .clk      	( clk                                                   ),
        .wen      	( fetch_wen                                             ),
        .data_in  	( ifu_rdata                                             ),
        .data_out 	( fetch_code[extend_index * 64 + 63 : extend_index * 64])
    );

    FF_D_without_asyn_rst #(
        .DATA_LEN 	( 2  ))
    u_fetch_rresp(
        .clk      	( clk                                                   ),
        .wen      	( fetch_wen                                             ),
        .data_in  	( ifu_rresp                                             ),
        .data_out 	( fetch_rresp[extend_index * 2 + 1 : extend_index * 2]  )
    );
end
endgenerate
always_comb begin
    case(addr_offset_rdata)
        2'h0: fetch_code_shift = fetch_use_code[IFU_SEND_ADDR_NUM * 64 - 49 : 0];
        2'h1: fetch_code_shift = fetch_use_code[IFU_SEND_ADDR_NUM * 64 - 33 :16];
        2'h2: fetch_code_shift = fetch_use_code[IFU_SEND_ADDR_NUM * 64 - 17 :32];
        2'h3: fetch_code_shift = fetch_use_code[IFU_SEND_ADDR_NUM * 64 - 1  :48];
    endcase
end
always_comb begin
    case(fetch_rresp_reg[IFU_SEND_ADDR_NUM * 2 + 1 :IFU_SEND_ADDR_NUM * 2])
        2'h0: fetch_rresp_reg_shift = fetch_rresp_reg_extend[IFU_SEND_ADDR_NUM * 8 - 7 : 0];
        2'h1: fetch_rresp_reg_shift = fetch_rresp_reg_extend[IFU_SEND_ADDR_NUM * 8 - 5 : 2];
        2'h2: fetch_rresp_reg_shift = fetch_rresp_reg_extend[IFU_SEND_ADDR_NUM * 8 - 3 : 4];
        2'h3: fetch_rresp_reg_shift = fetch_rresp_reg_extend[IFU_SEND_ADDR_NUM * 8 - 1 : 6];
    endcase
end

FF_D_with_syn_rst #(
	.DATA_LEN 	( 1  ),
	.RST_DATA 	( 0  ))
u_fetch_valid(
	.clk      	( clk                           ),
	.rst_n    	( rst_n                         ),
	.syn_rst  	( commit_restore                ),
	.wen      	( (!fetch_valid) | fetch_ready  ),
	.data_in  	( addr_offset_pop               ),
	.data_out 	( fetch_valid                   )
);

FF_D_without_asyn_rst #(
    .DATA_LEN 	( IFU_SEND_ADDR_NUM * 64 - 48  ))
u_fetch_code_shift_reg(
    .clk      	( clk                   ),
    .wen      	( addr_offset_pop       ),
    .data_in  	( fetch_code_shift      ),
    .data_out 	( fetch_code_shift_reg  )
);

FF_D_without_asyn_rst #(
    .DATA_LEN 	( IFU_SEND_ADDR_NUM * 2 + 2  ))
u_fetch_rresp_reg(
    .clk      	( clk                                   ),
    .wen      	( addr_offset_pop                       ),
    .data_in  	( {addr_offset_rdata,fetch_use_rresp}   ),
    .data_out 	( fetch_rresp_reg                       )
);

assign ifu_rready  = ifu_rready_reg;
//==============stage 2:predecode & precheck & sendto ibuf * precheck pus/pop restore==================================
logic                                   rvi_valid;
logic  [32 * IFU_INST_MAX_NUM - 1:0]    i_predecode_inst;
logic                                   ftq_eqa[IFU_INST_MAX_NUM -1 :0];
logic [IFU_INST_MAX_NUM * 1 - 1 : 0]    o_ftq_eqa;

// output declaration of module predecode
logic                                               has_one_branch;
logic                                               has_two_branch;
logic                                               has_three_branch;
logic                                               has_jump;
decode_result[IFU_INST_MAX_NUM - 1 : 0]             deocde_out;
ibuf_inst_entry[IFU_INST_MAX_NUM- 1 : 0]  ibuf_inst;

logic                                               one_br_is_rvc      ;
logic [63:0]                                        one_br_bracnch_addr;
logic [BLOCK_BIT_NUM - 1: 0]                        one_br_offset      ;

logic                                               two_br_is_rvc      ;
logic [63:0]                                        two_br_bracnch_addr;
logic [BLOCK_BIT_NUM - 1: 0]                        two_br_offset      ;

logic [BLOCK_BIT_NUM - 1: 0]                        three_br_offset  ;

logic                                               jump_is_call     ;
logic                                               jump_is_ret      ;
logic                                               jump_is_jalr     ;
logic                                               jump_is_rvc      ;
logic [63:0]                                        jump_bracnch_addr;
logic [BLOCK_BIT_NUM - 1: 0]                        jump_offset      ;
logic                                               last_rvi_valid   ;

// output declaration of module precheck
logic                                   update;
logic [63:0]                            end_pc;

// output declaration of module new_ifu_fifo
logic                                   full;

logic                                   precheck_update  ;
logic                                   precheck_restore ;
logic                                   old_entry_is_call;
logic                                   old_entry_is_ret ;
logic                                   new_entry_is_call;
logic                                   new_entry_is_ret ;
assign precheck_update     = (update & new_entry.valid & (!(has_jump | has_three_branch | ifu_dequeue_entry.hit)));
assign precheck_restore    = (update & (has_jump | has_three_branch | ifu_dequeue_entry.hit));
assign old_entry_is_call   = (ifu_dequeue_entry.hit & ifu_dequeue_entry.token & ifu_dequeue_entry.is_tail & ifu_dequeue_entry.old_entry.is_call);
assign old_entry_is_ret    = (ifu_dequeue_entry.hit & ifu_dequeue_entry.token & ifu_dequeue_entry.is_tail & ifu_dequeue_entry.old_entry.is_ret );
assign new_entry_is_call   = (new_entry.is_call);
assign new_entry_is_ret    = (new_entry.is_ret );

logic [63:0]                            old_entry_push_pc;
logic [63:0]                            new_entry_push_pc;
assign old_entry_push_pc = (ifu_dequeue_entry.old_entry.tail_slot.is_rvc) ? 
                            ifu_dequeue_entry.start_pc + {{(64 - BLOCK_BIT_NUM){1'b0}}, ifu_dequeue_entry.old_entry.tail_slot.offset} + 64'h2 : 
                            ifu_dequeue_entry.start_pc + {{(64 - BLOCK_BIT_NUM){1'b0}}, ifu_dequeue_entry.old_entry.tail_slot.offset} + 64'h4;
assign new_entry_push_pc = end_pc;

logic                                   first_cycle_flag;
logic                                   second_cycle_flag;
logic                                   write_ibuf_flag;
logic [63:0]                            precheck_pop_pc;

logic                                   if_precheck_pop_only_update;

logic                                   stage_done_flag; 
assign stage_done_flag = (precheck_update | precheck_restore) ? 
                        ((fetch_valid & (!first_cycle_flag) & second_cycle_flag & ((!write_ibuf_flag) | ((!full) & write_ibuf_flag))) | 
                        (fetch_valid & (!first_cycle_flag) & (!second_cycle_flag) & ((!full) & write_ibuf_flag))) :
                        (fetch_valid & ((!full) & write_ibuf_flag));

assign                                  fetch_ready = stage_done_flag; 

logic rvi_vakid_nxt;
assign rvi_vakid_nxt = (precheck_update | precheck_restore) ? ((has_jump) ? 1'b0 : ((!has_three_branch) & last_rvi_valid)) : 
                        ((ifu_dequeue_entry.token) ? 1'b0 : ((!has_three_branch) & last_rvi_valid));
FF_D_with_syn_rst #(
	.DATA_LEN 	( 1  ),
	.RST_DATA 	( 0  ))
u_rvi_valid(
	.clk      	( clk               ),
	.rst_n    	( rst_n             ),
	.syn_rst  	( commit_restore    ),
	.wen      	( stage_done_flag   ),
	.data_in  	( rvi_vakid_nxt     ),
	.data_out 	( rvi_valid         )
);

FF_D_with_syn_rst #(
	.DATA_LEN 	( 1  ),
	.RST_DATA 	( 1  ))
u_first_cycle_flag(
	.clk      	( clk                               ),
	.rst_n    	( rst_n                             ),
	.syn_rst  	( commit_restore | stage_done_flag  ),
	.wen      	( fetch_valid                       ),
	.data_in  	( 1'b0                              ),
	.data_out 	( first_cycle_flag                  )
);

FF_D_with_syn_rst #(
	.DATA_LEN 	( 1  ),
	.RST_DATA 	( 1  ))
u_second_cycle_flag(
	.clk      	( clk                               ),
	.rst_n    	( rst_n                             ),
	.syn_rst  	( commit_restore | stage_done_flag  ),
	.wen      	( fetch_valid & (!first_cycle_flag) ),
	.data_in  	( 1'b0                              ),
	.data_out 	( second_cycle_flag                 )
);

FF_D_with_syn_rst #(
	.DATA_LEN 	( 1  ),
	.RST_DATA 	( 1  ))
u_write_ibuf_flag(
	.clk      	( clk                                   ),
	.rst_n    	( rst_n                                 ),
	.syn_rst  	( commit_restore | stage_done_flag      ),
	.wen      	(fetch_valid & (!full) & write_ibuf_flag),
	.data_in  	( 1'b0                                  ),
	.data_out 	( write_ibuf_flag                       )
);

FF_D_without_asyn_rst #(
	.DATA_LEN 	( 64 ))
u_precheck_pop_pc(
	.clk      	( clk                                               ),
	.wen      	( if_precheck_pop & (!if_precheck_pop_only_update)  ),
	.data_in  	( if_precheck_pop_pc                                ),
	.data_out 	( precheck_pop_pc                                   )
);

logic [BLOCK_BIT_NUM - 1: 0] token_offset;
assign token_offset = (ifu_dequeue_entry.is_tail) ? ifu_dequeue_entry.old_entry.tail_slot.offset : ifu_dequeue_entry.old_entry.br_slot.offset;
genvar inst_index;
generate for(inst_index = 0 ; inst_index < IFU_INST_MAX_NUM; inst_index = inst_index + 1) begin : U_gen_ftq_eqa
    assign ftq_eqa[inst_index] = (({inst_index[BLOCK_BIT_NUM - 2: 0], 1'b0} < token_offset) | 
                                ({inst_index[BLOCK_BIT_NUM - 2: 0], 1'b0} == token_offset));
    assign i_predecode_inst[32 * inst_index + 31 : 32 * inst_index]  = fetch_code_shift_reg[inst_index * 16 + 31: inst_index * 16];
    assign o_ftq_eqa[inst_index]                                     = ftq_eqa[inst_index];
    assign ibuf_inst[inst_index].is_valid    = deocde_out[inst_index].is_valid   ;
    assign ibuf_inst[inst_index].eqa         = ((!update) & ifu_dequeue_entry.token) ? o_ftq_eqa[inst_index] : deocde_out[inst_index].decode_eqa;
    assign ibuf_inst[inst_index].tval_flag   = (fetch_rresp_reg_shift[inst_index * 2 + 1: inst_index * 2] == 2'h0);
    assign ibuf_inst[inst_index].rresp       = ((fetch_rresp_reg_shift[inst_index * 2 + 1: inst_index * 2] != 2'h0) | 
                                                (deocde_out[inst_index].inst[1:0] != 2'h3)) ? 
                                                fetch_rresp_reg_shift[inst_index * 2 + 1: inst_index * 2] : 
                                                fetch_rresp_reg_shift[inst_index * 2 + 3: inst_index * 2 + 2];
    assign ibuf_inst[inst_index].inst        = deocde_out[inst_index].inst       ;
    assign ibuf_inst[inst_index].inst_offset = deocde_out[inst_index].inst_offset;
end
endgenerate

predecode u_predecode(
    .i_predecode_inst     	(i_predecode_inst           ),
    .start_pc           	(ifu_dequeue_entry.start_pc ),
    .rvi_valid          	(rvi_valid                  ),
    .has_one_branch     	(has_one_branch             ),
    .has_two_branch     	(has_two_branch             ),
    .has_three_branch   	(has_three_branch           ),
    .has_jump           	(has_jump                   ),
    .deocde_out           	(deocde_out                 ),
    .one_br_is_rvc       	(one_br_is_rvc              ),
    .one_br_bracnch_addr 	(one_br_bracnch_addr        ),
    .one_br_offset       	(one_br_offset              ),
    .two_br_is_rvc       	(two_br_is_rvc              ),
    .two_br_bracnch_addr 	(two_br_bracnch_addr        ),
    .two_br_offset       	(two_br_offset              ),
    .three_br_offset     	(three_br_offset            ),
    .jump_is_call        	(jump_is_call               ),
    .jump_is_ret         	(jump_is_ret                ),
    .jump_is_jalr        	(jump_is_jalr               ),
    .jump_is_rvc         	(jump_is_rvc                ),
    .jump_bracnch_addr   	(jump_bracnch_addr          ),
    .jump_offset         	(jump_offset                ),
    .last_rvi_valid         (last_rvi_valid             )
);

precheck u_precheck(
    .start_pc            	(ifu_dequeue_entry.start_pc ),
    .hit            	    (ifu_dequeue_entry.hit      ),
    .has_one_branch      	(has_one_branch             ),
    .has_two_branch      	(has_two_branch             ),
    .has_three_branch    	(has_three_branch           ),
    .has_jump            	(has_jump                   ),
    .one_br_is_rvc       	(one_br_is_rvc              ),
    .one_br_bracnch_addr 	(one_br_bracnch_addr        ),
    .one_br_offset       	(one_br_offset              ),
    .two_br_is_rvc       	(two_br_is_rvc              ),
    .two_br_bracnch_addr 	(two_br_bracnch_addr        ),
    .two_br_offset       	(two_br_offset              ),
    .three_br_offset     	(three_br_offset            ),
    .jump_is_call        	(jump_is_call               ),
    .jump_is_ret         	(jump_is_ret                ),
    .jump_is_jalr        	(jump_is_jalr               ),
    .jump_is_rvc         	(jump_is_rvc                ),
    .jump_bracnch_addr   	(jump_bracnch_addr          ),
    .jump_offset         	(jump_offset                ),
    .old_entry           	(ifu_dequeue_entry.old_entry),
    .update              	(update                     ),
    .end_pc                 (end_pc                     ),
    .new_entry           	(new_entry                  )
);

ibuf u_ibuf(
    .clk            	(clk                                        ),
    .rst_n          	(rst_n                                      ),
    .flush 	            (commit_restore                             ),
    .full           	(full                                       ),
    .push           	(fetch_valid & (!full) & write_ibuf_flag    ),
    .ibuf_inst     	    (ibuf_inst                                  ),
    .ifu_dequeue_ptr    (ifu_dequeue_ptr                            ),
    .ibuf_inst_o   	    (ibuf_inst_o                                ),
    .decode_inst_ready  (decode_inst_ready                          )
);

assign ifu_dequeue_entry_ready  = stage_done_flag;

assign  if_precheck_update      = (fetch_valid & second_cycle_flag & (!first_cycle_flag) & precheck_update);
assign  if_precheck_restore     = (fetch_valid & second_cycle_flag & (!first_cycle_flag) & precheck_restore);
assign  if_precheck_retsore_pc  =   (64'h0) | 
                                    ({64{            (new_entry_is_ret)}} & precheck_pop_pc  ) | 
                                    ({64{has_jump & (!new_entry_is_ret)}} & jump_bracnch_addr) | 
                                    ({64{(!has_jump)                   }} & end_pc           );
assign  if_precheck_token       = has_jump;
assign  if_precheck_is_tail     = has_jump;

assign  if_precheck_push            = fetch_valid & first_cycle_flag & ((precheck_restore & new_entry_is_call) | ((!precheck_restore) & old_entry_is_call));
assign  if_precheck_push_pc         = (precheck_restore) ? new_entry_push_pc : old_entry_push_pc;
assign  if_precheck_pop             = fetch_valid & first_cycle_flag & ((precheck_restore & new_entry_is_ret ) | ((!precheck_restore) & old_entry_is_ret ));
assign  if_precheck_pop_only_update = (!precheck_restore);
assign  if_precheck_pop_pc_i        = jump_bracnch_addr;


endmodule //ifu
