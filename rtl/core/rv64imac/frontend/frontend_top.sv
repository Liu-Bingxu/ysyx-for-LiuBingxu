module frontend_top
import frontend_pkg::*;
#(
    parameter AXI_ID_SB = 3, 

    // Address width in bits
    parameter AXI_ADDR_W = 64,
    // ID width in bits
    parameter AXI_ID_W = 8,
    // Data width in bits
    parameter AXI_DATA_W = 64,

    parameter ICACHE_WAY = 2, 
    parameter ICACHE_GROUP = 2,
    parameter PMEM_START = 64'h8000_0000,
    parameter PMEM_END = 64'hFFFF_FFFF
)(
    //clock and reset
    input                               clk,
    input                               rst_n,

    // ftq req interface
    input  [FTQ_ENTRY_BIT_NUM - 1 : 0]  rob_ftq_ptr,
    input  [FTQ_ENTRY_BIT_NUM - 1 : 0]  bru_ftq_ptr,
    input  [FTQ_ENTRY_BIT_NUM - 1 : 0]  jump_ftq_ptr,
    input  [FTQ_ENTRY_BIT_NUM - 1 : 0]  csr_ftq_ptr,
    input  [FTQ_ENTRY_BIT_NUM - 1 : 0]  fence_ftq_ptr,
    output ftq_entry                    rob_ftq_entry,
    output ftq_entry                    bru_entry,
    output ftq_entry                    jump_entry,
    output ftq_entry                    csr_entry,
    output ftq_entry                    fence_entry,

    //jump interface
    input                               commit_ftq_valid,
    input                               commit_end,
    input                               jump_restore_valid,
    input                               jump_other_valid,
    input                               jump_call,
    input                               jump_ret,
    input  [63:0]                       jump_target,
    input  [63:0]                       jump_push_pc,

    //interface with wbu 
    input  [1:0]                        current_priv_status,
    input  [3:0]                        satp_mode,
    input  [15:0]                       satp_asid,
//all flush flag 
    input                               flush_i_valid,
    input                               sflush_vma_valid,
//interface with l2tlb
    output                              immu_miss_valid,
    input                               immu_miss_ready,
    output [63:0]                       vaddr_i,
    input                               pte_valid,
    output                              pte_ready_i,
    input  [127:0]                      pte,
    input                               pte_error,
//interface with axi
    //read addr channel
    output                              icache_arvalid,
    input                               icache_arready,
    output [AXI_ADDR_W    -1:0]         icache_araddr,
    output [8             -1:0]         icache_arlen,
    output [3             -1:0]         icache_arsize,
    output [2             -1:0]         icache_arburst,
    output [AXI_ID_W      -1:0]         icache_arid,
    //read data channel
    input                               icache_rvalid,
    output                              icache_rready,
    input  [AXI_ID_W      -1:0]         icache_rid,
    input  [2             -1:0]         icache_rresp,
    input  [AXI_DATA_W    -1:0]         icache_rdata,
    input                               icache_rlast,

    //ifu - idu interface
    output ibuf_inst_o_entry[decode_width - 1 :0]   ibuf_inst_o,
    input  [decode_width - 1 :0]                    decode_inst_ready
);

import core_setting_pkg::decode_width;
// module bpu outports wire
ftq_entry                           enqueue_entry;
logic [63:0]               	        precheck_pop_pc;
logic                 	            commit_restore;
logic                 	            precheck_restore;

// module ftq outports wire
logic                      	        predict;
logic                      	        redirect;
logic [63:0]               	        redirect_pc;
logic                      	        update;
logic                      	        update_hit;
logic [UFTB_ENTRY_NUM-1:0] 	        update_sel;
logic [TAG_BIT_NUM-1:0]    	        update_tag;
uftb_entry                          update_entry;
logic                      	        precheck_push;
logic [63:0]               	        precheck_push_pc;
logic                      	        precheck_pop;
logic [63:0]               	        precheck_pop_pc_i;
logic                      	        commit_push;
logic [63:0]               	        commit_push_pc;
logic                      	        commit_pop;
logic                               ifu_send_entry_valid;
ftq_entry                           ifu_send_entry;
ftq_entry                           ifu_dequeue_entry;
logic [FTQ_ENTRY_BIT_NUM - 1 : 0]   ifu_dequeue_ptr;
logic [63:0]                        if_precheck_pop_pc;

// module new_ifu outports wire
logic        	                    ifu_send_entry_ready;
logic        	                    ifu_dequeue_entry_ready;
logic        	                    if_precheck_restore;
logic                               if_precheck_update;
logic [63:0] 	                    if_precheck_retsore_pc;
logic        	                    if_precheck_token;
logic        	                    if_precheck_is_tail;
uftb_entry                          new_entry;
logic        	                    if_precheck_push;
logic [63:0] 	                    if_precheck_push_pc;
logic        	                    if_precheck_pop;
logic [63:0] 	                    if_precheck_pop_pc_i;
logic                               ifu_arvalid;
logic [63:0]                        ifu_araddr;
logic                               ifu_rready;

// outports logic u_icache
logic                               ifu_arready;
logic                               ifu_rvalid;
logic [1:0]                         ifu_rresp;
logic [63:0]                        ifu_rdata;

bpu u_bpu(
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
    .commit_ftq_valid               ( commit_ftq_valid              ),
    .commit_end                     ( commit_end                    ),
    .jump_restore_valid             ( jump_restore_valid            ),
    .jump_other_valid               ( jump_other_valid              ),
    .jump_call                      ( jump_call                     ),
    .jump_ret                       ( jump_ret                      ),
    .jump_target                    ( jump_target                   ),
    .jump_push_pc                   ( jump_push_pc                  ),
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
    .ifu_dequeue_ptr                ( ifu_dequeue_ptr               ),
    .if_precheck_update             ( if_precheck_update            ),
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
    .rob_ftq_ptr                    ( rob_ftq_ptr                   ),
    .bru_ftq_ptr                    ( bru_ftq_ptr                   ),
    .jump_ftq_ptr                   ( jump_ftq_ptr                  ),
    .csr_ftq_ptr                    ( csr_ftq_ptr                   ),
    .fence_ftq_ptr                  ( fence_ftq_ptr                 ),
    .rob_ftq_entry                  ( rob_ftq_entry                 ),
    .bru_entry                      ( bru_entry                     ),
    .jump_entry                     ( jump_entry                    ),
    .csr_entry                      ( csr_entry                     ),
    .fence_entry                    ( fence_entry                   )
);


ifu u_ifu(
	.clk                          	( clk                           ),
	.rst_n                        	( rst_n                         ),
	.commit_restore    	            ( commit_restore                ),
	.ifu_send_entry_valid         	( ifu_send_entry_valid          ),
	.ifu_send_entry_ready         	( ifu_send_entry_ready          ),
	.ifu_send_entry               	( ifu_send_entry                ),
	.ifu_dequeue_entry_ready      	( ifu_dequeue_entry_ready       ),
	.ifu_dequeue_entry            	( ifu_dequeue_entry             ),
    .ifu_dequeue_ptr                ( ifu_dequeue_ptr               ),
    .if_precheck_update             ( if_precheck_update            ),
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
	.ibuf_inst_o         	        ( ibuf_inst_o                   ),
    .decode_inst_ready              ( decode_inst_ready             )
);

icache #(
	.AXI_ID_SB    	( AXI_ID_SB     ),
	.AXI_ADDR_W   	( AXI_ADDR_W    ),
	.AXI_ID_W     	( AXI_ID_W      ),
	.AXI_DATA_W   	( AXI_DATA_W    ),
	.ICACHE_WAY   	( ICACHE_WAY    ),
	.ICACHE_GROUP 	( ICACHE_GROUP  ),
	.PMEM_START   	( PMEM_START    ),
	.PMEM_END     	( PMEM_END      ))
u_icache(
	.clk                 	( clk                               ),
	.rst_n               	( rst_n                             ),
	.current_priv_status 	( current_priv_status               ),
	.satp_mode           	( satp_mode                         ),
	.satp_asid           	( satp_asid                         ),
	.flush_flag          	( commit_restore | precheck_restore ),
	.flush_i_valid       	( flush_i_valid                     ),
	.sflush_vma_valid    	( sflush_vma_valid                  ),
	.ifu_arready         	( ifu_arready                       ),
	.ifu_arvalid         	( ifu_arvalid                       ),
	.ifu_araddr          	( ifu_araddr                        ),
	.ifu_rvalid          	( ifu_rvalid                        ),
	.ifu_rready          	( ifu_rready                        ),
	.ifu_rresp           	( ifu_rresp                         ),
	.ifu_rdata           	( ifu_rdata                         ),
	.immu_miss_valid     	( immu_miss_valid                   ),
	.immu_miss_ready     	( immu_miss_ready                   ),
	.vaddr_i             	( vaddr_i                           ),
	.pte_valid           	( pte_valid                         ),
	.pte_ready_i         	( pte_ready_i                       ),
	.pte                 	( pte                               ),
	.pte_error           	( pte_error                         ),
	.icache_arvalid      	( icache_arvalid                    ),
	.icache_arready      	( icache_arready                    ),
	.icache_araddr       	( icache_araddr                     ),
	.icache_arlen        	( icache_arlen                      ),
	.icache_arsize       	( icache_arsize                     ),
	.icache_arburst      	( icache_arburst                    ),
	.icache_arid         	( icache_arid                       ),
	.icache_rvalid       	( icache_rvalid                     ),
	.icache_rready       	( icache_rready                     ),
	.icache_rid          	( icache_rid                        ),
	.icache_rresp        	( icache_rresp                      ),
	.icache_rdata        	( icache_rdata                      ),
	.icache_rlast        	( icache_rlast                      )
);


endmodule //frontend_top
