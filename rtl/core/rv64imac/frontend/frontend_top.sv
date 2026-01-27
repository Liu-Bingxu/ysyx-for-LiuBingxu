`include "./struct.sv"
module frontend_top#(parameter RST_PC=64'h0)(
    //clock and reset
    input                   clk,
    input                   rst_n,

    //exu interface
    input                   commit_flag,
    input                   commit_end_flag,
    input  [63:0]           commit_pc,

    output                 	commit_restore,
    output                 	precheck_restore,

    //jump interface
    input                   jump_is_call,
    input                   jump_is_ret,
    input                   jump_restore_flag,// restore flag
    input                   jump_flag,        // another flag: sfence, fence.i, satp_change
    input  [63:0]           jump_addr,        // restore addr
    input  [63:0]           jump_push_addr,   // restore push addr

    //read addr channel
    input                   ifu_arready,
    output                  ifu_arvalid,
    output [63:0]           ifu_araddr,

    //read data channel
    input                   ifu_rvalid,
    output                  ifu_rready,
    input  [1:0]            ifu_rresp,
    input  [63:0]           ifu_rdata,

    //ifu - idu interface
    output                  IF_ID_reg_inst_valid,
    input                   ID_IF_inst_ready,
    output                  IF_ID_reg_inst_compress_flag,
    output                  IF_ID_reg_ftq_end_flag,
    output [1:0]            IF_ID_reg_rresp,
    output [15:0]           IF_ID_reg_inst_compress,
    output [31:0]           IF_ID_reg_inst,
    output [63:0]           IF_ID_reg_tval,
    output [63:0]           IF_ID_reg_PC
);

// module bpu outports wire
ftq_entry                   enqueue_entry;
logic [63:0]               	precheck_pop_pc;

// module ftq outports wire
logic                      	predict;
logic                      	redirect;
logic [63:0]               	redirect_pc;
logic                      	update;
logic                      	update_hit;
logic [UFTB_ENTRY_NUM-1:0] 	update_sel;
logic [TAG_BIT_NUM-1:0]    	update_tag;
uftb_entry                  update_entry;
logic                      	precheck_push;
logic [63:0]               	precheck_push_pc;
logic                      	precheck_pop;
logic [63:0]               	precheck_pop_pc_i;
logic                      	commit_push;
logic [63:0]               	commit_push_pc;
logic                      	commit_pop;
logic                       ifu_send_entry_valid;
ftq_entry                   ifu_send_entry;
ftq_entry                   ifu_dequeue_entry;
logic [63:0]                if_precheck_pop_pc;

// module new_ifu outports wire
logic        	ifu_send_entry_ready;
logic        	ifu_dequeue_entry_ready;
logic        	if_precheck_restore;
logic [63:0] 	if_precheck_retsore_pc;
logic        	if_precheck_token;
logic        	if_precheck_is_tail;
uftb_entry      new_entry;
logic        	if_precheck_push;
logic [63:0] 	if_precheck_push_pc;
logic        	if_precheck_pop;
logic [63:0] 	if_precheck_pop_pc_i;

bpu #(
	.RST_PC 	( RST_PC  ))
u_bpu(
	.clk               	( clk                ),
	.rst_n             	( rst_n              ),
	.predict           	( predict            ),
	.redirect          	( redirect           ),
	.redirect_pc       	( redirect_pc        ),
	.update            	( update             ),
	.update_hit        	( update_hit         ),
	.update_sel        	( update_sel         ),
	.update_tag        	( update_tag         ),
	.update_entry      	( update_entry       ),
	.enqueue_entry     	( enqueue_entry      ),
	.precheck_restore  	( precheck_restore   ),
	.precheck_push     	( precheck_push      ),
	.precheck_push_pc  	( precheck_push_pc   ),
	.precheck_pop      	( precheck_pop       ),
	.precheck_pop_pc_i 	( precheck_pop_pc_i  ),
	.precheck_pop_pc   	( precheck_pop_pc    ),
	.commit_restore    	( commit_restore     ),
	.commit_push       	( commit_push        ),
	.commit_push_pc    	( commit_push_pc     ),
	.commit_pop        	( commit_pop         )
);

ftq u_ftq(
	.clk               	            ( clk                           ),
	.rst_n             	            ( rst_n                         ),
    .commit_flag                    ( commit_flag                   ),
    .commit_end_flag                ( commit_end_flag               ),
    .commit_pc                      ( commit_pc                     ),
    .jump_is_call                   ( jump_is_call                  ),
    .jump_is_ret                    ( jump_is_ret                   ),
    .jump_restore_flag              ( jump_restore_flag             ),
    .jump_flag                      ( jump_flag                     ),
    .jump_addr                      ( jump_addr                     ),
    .jump_push_addr                 ( jump_push_addr                ),   
	.predict           	            ( predict                       ),
	.redirect          	            ( redirect                      ),
	.redirect_pc       	            ( redirect_pc                   ),
	.update            	            ( update                        ),
	.update_hit        	            ( update_hit                    ),
	.update_sel        	            ( update_sel                    ),
	.update_tag        	            ( update_tag                    ),
	.update_entry      	            ( update_entry                  ),
	.enqueue_entry     	            ( enqueue_entry                 ),
	.precheck_restore  	            ( precheck_restore              ),
	.precheck_push     	            ( precheck_push                 ),
	.precheck_push_pc  	            ( precheck_push_pc              ),
	.precheck_pop      	            ( precheck_pop                  ),
	.precheck_pop_pc_i 	            ( precheck_pop_pc_i             ),
	.precheck_pop_pc   	            ( precheck_pop_pc               ),
	.commit_restore    	            ( commit_restore                ),
	.commit_push       	            ( commit_push                   ),
	.commit_push_pc    	            ( commit_push_pc                ),
	.commit_pop        	            ( commit_pop                    ),
	.ifu_send_entry_valid         	( ifu_send_entry_valid          ),
	.ifu_send_entry_ready         	( ifu_send_entry_ready          ),
	.ifu_send_entry               	( ifu_send_entry                ),
	.ifu_dequeue_entry_ready      	( ifu_dequeue_entry_ready       ),
	.ifu_dequeue_entry            	( ifu_dequeue_entry             ),
	.if_precheck_restore          	( if_precheck_restore           ),
    .if_precheck_retsore_pc         ( if_precheck_retsore_pc        ),
    .if_precheck_token              ( if_precheck_token             ),
    .if_precheck_is_tail            ( if_precheck_is_tail           ),
    .new_entry                      ( new_entry                     ),
	.if_precheck_push             	( if_precheck_push              ),
	.if_precheck_push_pc          	( if_precheck_push_pc           ),
	.if_precheck_pop              	( if_precheck_pop               ),
	.if_precheck_pop_pc_i         	( if_precheck_pop_pc_i          ),
	.if_precheck_pop_pc           	( if_precheck_pop_pc            )
);


new_ifu u_new_ifu(
	.clk                          	( clk                           ),
	.rst_n                        	( rst_n                         ),
	.commit_restore    	            ( commit_restore                ),
	.ifu_send_entry_valid         	( ifu_send_entry_valid          ),
	.ifu_send_entry_ready         	( ifu_send_entry_ready          ),
	.ifu_send_entry               	( ifu_send_entry                ),
	.ifu_dequeue_entry_ready      	( ifu_dequeue_entry_ready       ),
	.ifu_dequeue_entry            	( ifu_dequeue_entry             ),
	.if_precheck_restore          	( if_precheck_restore           ),
    .if_precheck_retsore_pc         ( if_precheck_retsore_pc        ),
    .if_precheck_token              ( if_precheck_token             ),
    .if_precheck_is_tail            ( if_precheck_is_tail           ),
    .new_entry                      ( new_entry                     ),
	.if_precheck_push             	( if_precheck_push              ),
	.if_precheck_push_pc          	( if_precheck_push_pc           ),
	.if_precheck_pop              	( if_precheck_pop               ),
	.if_precheck_pop_pc_i         	( if_precheck_pop_pc_i          ),
	.if_precheck_pop_pc           	( if_precheck_pop_pc            ),
	.ifu_arready                  	( ifu_arready                   ),
	.ifu_arvalid                  	( ifu_arvalid                   ),
	.ifu_araddr                   	( ifu_araddr                    ),
	.ifu_rvalid                   	( ifu_rvalid                    ),
	.ifu_rready                   	( ifu_rready                    ),
	.ifu_rresp                    	( ifu_rresp                     ),
	.ifu_rdata                    	( ifu_rdata                     ),
	.IF_ID_reg_inst_valid         	( IF_ID_reg_inst_valid          ),
	.ID_IF_inst_ready             	( ID_IF_inst_ready              ),
	.IF_ID_reg_inst_compress_flag 	( IF_ID_reg_inst_compress_flag  ),
	.IF_ID_reg_ftq_end_flag 	    ( IF_ID_reg_ftq_end_flag        ),
	.IF_ID_reg_rresp              	( IF_ID_reg_rresp               ),
	.IF_ID_reg_inst_compress      	( IF_ID_reg_inst_compress       ),
	.IF_ID_reg_inst               	( IF_ID_reg_inst                ),
	.IF_ID_reg_tval               	( IF_ID_reg_tval                ),
	.IF_ID_reg_PC                 	( IF_ID_reg_PC                  )
);


endmodule //frontend_top
