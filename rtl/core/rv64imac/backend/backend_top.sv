module backend_top
import frontend_pkg::*;
import regfile_pkg::*;
import decode_pkg::*;
import rename_pkg::*;
import dispatch_pkg::*;
import iq_pkg::*;
import rob_pkg::*;
import lsq_pkg::*;
import core_setting_pkg::*;
(
    input                                           clk,
    input                                           rst_n,

    input                                           stip,
    input                                           seip,
    input                                           ssip,
    input                                           mtip,
    input                                           meip,
    input                                           msip,
    input                                           halt_req,

    output                                          redirect,
    output                                          rename_fire,

    output rob_entry_ptr_t                          top_rob_ptr,
    output ls_rob_entry_ptr_t                       deq_rob_ptr,

    input  ibuf_inst_o_entry[decode_width - 1 :0]   ibuf_inst_o,
    output [decode_width - 1 :0]                    decode_inst_ready,

    // StoreQueue interface
    output             [rename_width - 1 : 0]       sq_req,
    output  sq_entry_t [rename_width - 1 : 0]       sq_req_entry,
    input   sq_resp_t  [rename_width - 1 : 0]       sq_resp,

    // int5 issue queue interface
    output                                          loadUnit_in_valid,
    input                                           loadUnit_in_ready,
    output iq_mem_load_in_t                         loadUnit_in,

    // int6 issue queue interface
    output                                          storeaddrUnit_in_valid,
    input                                           storeaddrUnit_in_ready,
    output iq_mem_store_addr_in_t                   storeaddrUnit_in,

    // int7 issue queue interface
    output                                          storedataUnit_in_valid,
    input                                           storedataUnit_in_ready,
    output iq_mem_store_data_in_t                   storedataUnit_in,

    // int8 issue queue interface
    output                                          atomicUnit_in_valid,
    input                                           atomicUnit_in_ready,
    output iq_mem_atomic_in_t                       atomicUnit_in,

    output [FTQ_ENTRY_BIT_NUM - 1 : 0]              rob_ftq_ptr,
    output [FTQ_ENTRY_BIT_NUM - 1 : 0]              bru_ftq_ptr,
    output [FTQ_ENTRY_BIT_NUM - 1 : 0]              jump_ftq_ptr,
    output [FTQ_ENTRY_BIT_NUM - 1 : 0]              csr_ftq_ptr,
    output [FTQ_ENTRY_BIT_NUM - 1 : 0]              fence_ftq_ptr,
    output [FTQ_ENTRY_BIT_NUM - 1 : 0]              rob_ftq_ptr_lq_raw,
    input  ftq_entry                                rob_ftq_entry,
    input  ftq_entry                                bru_entry,
    input  ftq_entry                                jump_entry,
    input  ftq_entry                                csr_entry,
    input  ftq_entry                                fence_entry,
    input  ftq_entry                                rob_ftq_entry_lq_raw,

    // fence_i interface
    output logic                                    flush_i_valid,
    input                                           flush_i_ready,
    // sfence_vma interface
    output                                          sflush_vma_valid,

    // read port
    input  pint_regsrc_t                            loadUnit_psrc,
    output intreg_t                                 loadUnit_psrc_rdata,

    input  pint_regsrc_t                            storedataUnit_psrc,
    output intreg_t                                 storedataUnit_psrc_rdata,

    input  pint_regsrc_t                            storeaddrUnit_psrc,
    output intreg_t                                 storeaddrUnit_psrc_rdata,

    input  pint_regsrc_t[1 : 0]                     atomicUnit_psrc,
    output intreg_t     [1 : 0]                     atomicUnit_psrc_rdata,

    // load report interface
    input                                           loadUnit_valid_o,
    output                                          loadUnit_ready_o,
    input                                           loadUnit_addr_misalign_o,
    input                                           loadUnit_page_error_o,
    input                                           loadUnit_load_error_o,
    input  rob_entry_ptr_t                          loadUnit_rob_ptr_o,
    input  [63:0]                                   loadUnit_vaddr_o,
    input                                           loadUnit_rfwen_o,
    input  pint_regdest_t                           loadUnit_pwdest_o,
    input  [63:0]                                   loadUnit_preg_wdata_o,

    // store report interface
    input                                           StoreQueue_valid_o,
    output                                          StoreQueue_ready_o,
    input                                           StoreQueue_addr_misalign_o,
    input                                           StoreQueue_page_error_o,
    input  rob_entry_ptr_t                          StoreQueue_rob_ptr_o,
    input  [63:0]                                   StoreQueue_vaddr_o,

    // atomic report interface
    input                                           atomicUnit_valid_o,
    output                                          atomicUnit_ready_o,
    input                                           atomicUnit_ld_addr_misalign_o,
    input                                           atomicUnit_st_addr_misalign_o,
    input                                           atomicUnit_ld_page_error_o,
    input                                           atomicUnit_st_page_error_o,
    input                                           atomicUnit_load_error_o,
    input                                           atomicUnit_store_error_o,
    input  rob_entry_ptr_t                          atomicUnit_rob_ptr_o,
    input  [63:0]                                   atomic_vaddr_o,
    input                                           atomicUnit_rfwen_o,
    input  pint_regdest_t                           atomicUnit_pwdest_o,
    input  [63:0]                                   atomicUnit_preg_wdata_o,

    // LoadQueueRAW report port
    input                                           LoadQueue_flush_o,
    input  rob_entry_ptr_t                          LoadQueue_rob_ptr_o,

    // status update port
    output               [wb_width - 1 : 0]         rfwen,
    output pint_regdest_t[wb_width - 1 : 0]         pwdest,

    //interface with mmu
    output [1:0]              	                    current_priv_status,
    output                                          MXR,
    output                                          SUM,
    output                                          MPRV,
    output [1:0]                                    MPP,
    output [3:0]                                    satp_mode,
    output [15:0]                                   satp_asid,
    output [43:0]                                   satp_ppn,

    //interface with frontend
    output                                          commit_ftq_valid,
    output                                          commit_end,
    output                                          jump_restore_valid,
    output                                          jump_other_valid,
    output                                          jump_call,
    output                                          jump_ret,
    output [63:0]                                   jump_target,
    output [63:0]                                   jump_push_pc
);


// outports logic DeocdeUnit
regsrc_t        [decode_width-1:0] 	int_src1_torat;
regsrc_t        [decode_width-1:0] 	int_src2_torat;
regdest_t       [decode_width-1:0] 	int_dest_torat;
logic           [decode_width-1:0] 	decode_out_valid;
decode_out_t    [decode_width-1:0] 	decode_out;

// outports logic Rename table
pint_regsrc_t   [decode_width-1:0] 	int_src1_fromrat;
pint_regsrc_t   [decode_width-1:0] 	int_src2_fromrat;
pint_regdest_t  [decode_width-1:0] 	int_dest_fromrat;

// outports logic Rename int free list
rename_resp_t   [decode_width-1:0] 	rename_int_resp;

// outports logic Rename
logic                    	        rename_ready;
logic                    	        rename_hold;
logic           [rename_width-1:0] 	rename_intrat_valid;
regsrc_t        [rename_width-1:0] 	rename_intrat_dest;
pint_regdest_t  [rename_width-1:0] 	rename_intrat_pdest;
logic           [rename_width-1:0] 	rename_int_req;
logic           [rename_width-1:0] 	rob_req;
rob_entry_t     [rename_width-1:0] 	rob_req_entry;
logic           [rename_width-1:0] 	rename_out_valid;
rename_out_t    [rename_width-1:0] 	rename_out;

// outports wire u_dispatch
logic                      	        dispatch_ready;
rob_entry_ptr_t                     rob_first_ptr;
logic [dispatch_width-1:0] 	        pdest_valid;
pint_regdest_t [dispatch_width-1:0] pdest;
pint_regsrc_t [dispatch_width-1:0] 	dispatch_psrc1;
pint_regsrc_t [dispatch_width-1:0] 	dispatch_psrc2;
logic                      	        alu_mul_exu_in_valid;
iq_acc_in_t                      	alu_mul_exu_in;
logic                      	        alu_div_exu_in_valid;
iq_acc_in_t                      	alu_div_exu_in;
logic                      	        alu_bru_jump_exu_in_valid;
iq_need_pc_in_t                     alu_bru_jump_exu_in;
logic                      	        alu_csr_fence_exu_in_valid;
iq_csr_in_t                      	alu_csr_fence_exu_in;

// outports logic u_rob
logic           [commit_width-1:0]  commit_intrat_valid;
regsrc_t        [commit_width-1:0]  commit_intrat_dest;
pint_regdest_t  [commit_width-1:0]  commit_intrat_pdest;
logic           [commit_width-1:0]  commit_int_need_free;
pint_regdest_t  [commit_width-1:0]  commit_int_old_pdest;
rob_resp_t      [rename_width-1:0]  rob_resp;
logic [dispatch_width-1:0] 	        rob_can_dispatch;
logic                      	        alu_mul_exu_ready_o;
logic                      	        alu_div_exu_ready_o;
logic                      	        alu_bru_jump_exu_ready_o;
logic                      	        alu_csr_fence_exu_ready_o;
logic                         	    rob_gen_redirect_valid;
logic                         	    rob_gen_redirect_bp_miss;
logic                         	    rob_gen_redirect_call;
logic                         	    rob_gen_redirect_ret;
logic                         	    rob_gen_redirect_end;
logic [63:0]                  	    rob_gen_redirect_target;
logic                      	        rob_can_interrupt;
logic                      	        rob_commit_valid;
logic [63:0]               	        rob_commit_pc;
logic [63:0]               	        rob_commit_next_pc;
logic                      	        rob_trap_valid;
logic [63:0]               	        rob_trap_cause;
logic [63:0]               	        rob_trap_tval;

// outports logic u_alu_mul_exu_block
logic [IQ_W - 1 : 0]                alu_mul_exu_iq_enq_num;
logic                	            alu_mul_exu_in_ready;
pint_regsrc_t   [1:0]          	    alu_mul_exu_psrc;
logic                	            alu_mul_exu_valid_o;
rob_entry_ptr_t                	    alu_mul_exu_rob_ptr_o;
pint_regdest_t                	    alu_mul_exu_pwdest_o;
logic           [63:0]          	alu_mul_exu_preg_wdata_o;

// outports logic u_alu_div_exu_block
logic [IQ_W - 1 : 0]                alu_div_exu_iq_enq_num;
logic                	            alu_div_exu_in_ready;
pint_regsrc_t   [1:0]          	    alu_div_exu_psrc;
logic                	            alu_div_exu_valid_o;
rob_entry_ptr_t                	    alu_div_exu_rob_ptr_o;
pint_regdest_t                	    alu_div_exu_pwdest_o;
logic           [63:0]         	    alu_div_exu_preg_wdata_o;

// outports logic u_alu_bru_jump_exu_block
logic [IQ_W - 1 : 0]                alu_bru_jump_exu_iq_enq_num;
logic                         	    alu_bru_jump_exu_in_ready;
pint_regsrc_t [1:0]                	alu_bru_jump_exu_psrc;
logic                         	    alu_bru_jump_exu_valid_o;
rob_entry_ptr_t                     alu_bru_jump_exu_rob_ptr_o;
logic                         	    alu_bru_jump_exu_rfwen_o;
pint_regdest_t                      alu_bru_jump_exu_pwdest_o;
logic [63:0]                  	    alu_bru_jump_exu_preg_wdata_o;
logic                         	    alu_bru_jump_exu_token_miss_o;
logic [63:0]                  	    alu_bru_jump_exu_next_pc_o;


// outports logic u_alu_csr_fence_exu_block
logic [IQ_W - 1 : 0]                alu_csr_fence_exu_iq_enq_num;
logic                         	    alu_csr_fence_exu_in_ready;
pint_regsrc_t [1:0]                 alu_csr_fence_exu_psrc;
logic [11:0]                  	    csr_index;
logic                         	    alu_csr_fence_exu_valid_o;
rob_entry_ptr_t                     alu_csr_fence_exu_rob_ptr_o;
logic                         	    alu_csr_fence_exu_rfwen_o;
logic                         	    alu_csr_fence_exu_csrwen_o;
logic [11:0]                  	    alu_csr_fence_exu_csr_index_o;
logic [63:0]                  	    alu_csr_fence_exu_csr_wdata_o;
pint_regdest_t                      alu_csr_fence_exu_pwdest_o;
logic [63:0]                  	    alu_csr_fence_exu_preg_wdata_o;
logic                         	    alu_csr_fence_exu_mret_o;
logic                         	    alu_csr_fence_exu_sret_o;
logic                         	    alu_csr_fence_exu_dret_o;
logic                         	    alu_csr_fence_exu_satp_change_o;
logic                         	    alu_csr_fence_exu_fence_o;
logic [63:0]                  	    alu_csr_fence_exu_next_pc_o;

// outports logic u_intregfile
intreg_t        [1:0]          	    alu_mul_exu_psrc_rdata;
intreg_t        [1:0]          	    alu_div_exu_psrc_rdata;
intreg_t        [1:0]          	    alu_bru_jump_exu_psrc_rdata;
intreg_t        [1:0]          	    alu_csr_fence_exu_psrc_rdata;

// outports logic u_int_pstatus
logic [rename_width-1:0] 	        dispatch_psrc1_status;
logic [rename_width-1:0] 	        dispatch_psrc2_status;

// outports logic u_csr
logic                    	        csr_jump_flag;
logic [63:0]             	        csr_jump_addr;
logic [63:0]             	        csr_rdata;
logic [63:0]             	        mepc_o;
logic [63:0]             	        sepc_o;
logic [63:0]             	        dpc_o;
logic                    	        TSR;
logic                    	        TW;
logic                    	        TVM;
logic                    	        debug_mode;
logic                               interrupt_happen;

DecodeUnit u_DecodeUnit(
	.clk                 	( clk                  ),
	.rst_n               	( rst_n                ),
	.redirect               ( redirect             ),
	.debug_mode          	( debug_mode           ),
	.current_priv_status 	( current_priv_status  ),
	.TSR                 	( TSR                  ),
	.TW                  	( TW                   ),
	.TVM                 	( TVM                  ),
	.ibuf_inst_o         	( ibuf_inst_o          ),
	.decode_inst_ready   	( decode_inst_ready    ),
	.int_src1_torat      	( int_src1_torat       ),
	.int_src2_torat      	( int_src2_torat       ),
	.int_dest_torat      	( int_dest_torat       ),
	.decode_out_valid    	( decode_out_valid     ),
	.decode_out          	( decode_out           ),
	.rename_ready        	( rename_ready         )
);

rename_table u_rename_table(
	.clk                 	( clk                  ),
	.rst_n               	( rst_n                ),
	.redirect               ( redirect             ),
	.decode_out_valid    	( decode_out_valid     ),
	.rename_ready        	( rename_ready         ),
	.int_src1_torat      	( int_src1_torat       ),
	.int_src2_torat      	( int_src2_torat       ),
	.int_dest_torat      	( int_dest_torat       ),
	.rename_hold         	( rename_hold          ),
	.int_src1_fromrat    	( int_src1_fromrat     ),
	.int_src2_fromrat    	( int_src2_fromrat     ),
	.int_dest_fromrat    	( int_dest_fromrat     ),
	.rename_fire         	( rename_fire          ),
	.rename_intrat_valid 	( rename_intrat_valid  ),
	.rename_intrat_dest  	( rename_intrat_dest   ),
	.rename_intrat_pdest 	( rename_intrat_pdest  ),
	.commit_intrat_valid 	( commit_intrat_valid  ),
	.commit_intrat_dest  	( commit_intrat_dest   ),
	.commit_intrat_pdest 	( commit_intrat_pdest  )
);

rename_intfreelist u_rename_intfreelist(
	.clk                  	( clk                   ),
	.rst_n                	( rst_n                 ),
	.redirect               ( redirect              ),
	.rename_fire          	( rename_fire           ),
	.rename_int_req       	( rename_int_req        ),
	.rename_int_resp      	( rename_int_resp       ),
	.commit_int_need_free 	( commit_int_need_free  ),
	.commit_int_old_pdest 	( commit_int_old_pdest  )
);

rename u_rename(
	.clk                 	( clk                  ),
	.rst_n               	( rst_n                ),
	.redirect               ( redirect             ),
	.decode_out_valid    	( decode_out_valid     ),
	.decode_out          	( decode_out           ),
	.rename_ready        	( rename_ready         ),
	.rename_fire         	( rename_fire          ),
	.rename_hold         	( rename_hold          ),
	.int_src1_fromrat    	( int_src1_fromrat     ),
	.int_src2_fromrat    	( int_src2_fromrat     ),
	.int_dest_fromrat    	( int_dest_fromrat     ),
	.rename_intrat_valid 	( rename_intrat_valid  ),
	.rename_intrat_dest  	( rename_intrat_dest   ),
	.rename_intrat_pdest 	( rename_intrat_pdest  ),
	.rename_int_req      	( rename_int_req       ),
	.rename_int_resp     	( rename_int_resp      ),
	.rob_req             	( rob_req              ),
	.rob_req_entry       	( rob_req_entry        ),
	.rob_resp            	( rob_resp             ),
	.sq_req              	( sq_req               ),
	.sq_req_entry        	( sq_req_entry         ),
	.sq_resp             	( sq_resp              ),
	.rename_out_valid    	( rename_out_valid     ),
	.rename_out          	( rename_out           ),
	.dispatch_ready      	( dispatch_ready       )
);

dispatch u_dispatch(
	.clk                        	( clk                           ),
	.rst_n                      	( rst_n                         ),
	.redirect                   	( redirect                      ),
    .alu_mul_exu_iq_enq_num         ( alu_mul_exu_iq_enq_num        ),
    .alu_div_exu_iq_enq_num         ( alu_div_exu_iq_enq_num        ),
    .alu_bru_jump_exu_iq_enq_num    ( alu_bru_jump_exu_iq_enq_num   ),
    .alu_csr_fence_exu_iq_enq_num   ( alu_csr_fence_exu_iq_enq_num  ),
	.rename_out_valid           	( rename_out_valid              ),
	.rename_out                 	( rename_out                    ),
	.dispatch_ready             	( dispatch_ready                ),
    .rob_first_ptr                  ( rob_first_ptr                 ),
	.rob_can_dispatch           	( rob_can_dispatch              ),
	.pdest_valid                	( pdest_valid                   ),
	.pdest                      	( pdest                         ),
	.dispatch_psrc1             	( dispatch_psrc1                ),
	.dispatch_psrc2             	( dispatch_psrc2                ),
	.dispatch_psrc1_status      	( dispatch_psrc1_status         ),
	.dispatch_psrc2_status      	( dispatch_psrc2_status         ),
	.alu_mul_exu_in_valid       	( alu_mul_exu_in_valid          ),
	.alu_mul_exu_in_ready       	( alu_mul_exu_in_ready          ),
	.alu_mul_exu_in             	( alu_mul_exu_in                ),
	.alu_div_exu_in_valid       	( alu_div_exu_in_valid          ),
	.alu_div_exu_in_ready       	( alu_div_exu_in_ready          ),
	.alu_div_exu_in             	( alu_div_exu_in                ),
	.alu_bru_jump_exu_in_valid  	( alu_bru_jump_exu_in_valid     ),
	.alu_bru_jump_exu_in_ready  	( alu_bru_jump_exu_in_ready     ),
	.alu_bru_jump_exu_in        	( alu_bru_jump_exu_in           ),
	.alu_csr_fence_exu_in_valid 	( alu_csr_fence_exu_in_valid    ),
	.alu_csr_fence_exu_in_ready 	( alu_csr_fence_exu_in_ready    ),
	.alu_csr_fence_exu_in       	( alu_csr_fence_exu_in          ),
	.loadUnit_in_valid          	( loadUnit_in_valid             ),
	.loadUnit_in_ready          	( loadUnit_in_ready             ),
	.loadUnit_in                	( loadUnit_in                   ),
	.storeaddrUnit_in_valid     	( storeaddrUnit_in_valid        ),
	.storeaddrUnit_in_ready     	( storeaddrUnit_in_ready        ),
	.storeaddrUnit_in           	( storeaddrUnit_in              ),
	.storedataUnit_in_valid     	( storedataUnit_in_valid        ),
	.storedataUnit_in_ready     	( storedataUnit_in_ready        ),
	.storedataUnit_in           	( storedataUnit_in              ),
	.atomicUnit_in_valid        	( atomicUnit_in_valid           ),
	.atomicUnit_in_ready        	( atomicUnit_in_ready           ),
	.atomicUnit_in              	( atomicUnit_in                 )
);

rob u_rob(
	.clk                             	( clk                              ),
	.rst_n                           	( rst_n                            ),
	.redirect                        	( redirect                         ),
	.top_rob_ptr                     	( top_rob_ptr                      ),
	.deq_rob_ptr                     	( deq_rob_ptr                      ),
	.rob_ftq_ptr                     	( rob_ftq_ptr                      ),
	.rob_ftq_entry                   	( rob_ftq_entry                    ),
    .rob_ftq_ptr_lq_raw                 ( rob_ftq_ptr_lq_raw               ),
    .rob_ftq_entry_lq_raw               ( rob_ftq_entry_lq_raw             ),
	.commit_intrat_valid             	( commit_intrat_valid              ),
	.commit_intrat_dest              	( commit_intrat_dest               ),
	.commit_intrat_pdest             	( commit_intrat_pdest              ),
	.commit_int_need_free            	( commit_int_need_free             ),
	.commit_int_old_pdest            	( commit_int_old_pdest             ),
	.rename_fire                     	( rename_fire                      ),
	.rob_req                         	( rob_req                          ),
	.rob_req_entry                   	( rob_req_entry                    ),
	.rob_resp                        	( rob_resp                         ),
	.rob_first_ptr                   	( rob_first_ptr                    ),
	.rob_can_dispatch                	( rob_can_dispatch                 ),
	.alu_mul_exu_valid_o             	( alu_mul_exu_valid_o              ),
	.alu_mul_exu_ready_o             	( alu_mul_exu_ready_o              ),
	.alu_mul_exu_rob_ptr_o           	( alu_mul_exu_rob_ptr_o            ),
	.alu_div_exu_valid_o             	( alu_div_exu_valid_o              ),
	.alu_div_exu_ready_o             	( alu_div_exu_ready_o              ),
	.alu_div_exu_rob_ptr_o           	( alu_div_exu_rob_ptr_o            ),
	.alu_bru_jump_exu_valid_o        	( alu_bru_jump_exu_valid_o         ),
	.alu_bru_jump_exu_ready_o        	( alu_bru_jump_exu_ready_o         ),
	.alu_bru_jump_exu_rob_ptr_o      	( alu_bru_jump_exu_rob_ptr_o       ),
	.alu_bru_jump_exu_token_miss_o   	( alu_bru_jump_exu_token_miss_o    ),
	.alu_bru_jump_exu_next_pc_o      	( alu_bru_jump_exu_next_pc_o       ),
	.alu_csr_fence_exu_valid_o       	( alu_csr_fence_exu_valid_o        ),
	.alu_csr_fence_exu_ready_o       	( alu_csr_fence_exu_ready_o        ),
	.alu_csr_fence_exu_rob_ptr_o     	( alu_csr_fence_exu_rob_ptr_o      ),
	.alu_csr_fence_exu_mret_o        	( alu_csr_fence_exu_mret_o         ),
	.alu_csr_fence_exu_sret_o        	( alu_csr_fence_exu_sret_o         ),
	.alu_csr_fence_exu_dret_o        	( alu_csr_fence_exu_dret_o         ),
	.alu_csr_fence_exu_satp_change_o 	( alu_csr_fence_exu_satp_change_o  ),
	.alu_csr_fence_exu_fence_o       	( alu_csr_fence_exu_fence_o        ),
	.alu_csr_fence_exu_next_pc_o     	( alu_csr_fence_exu_next_pc_o      ),
	.loadUnit_valid_o                	( loadUnit_valid_o                 ),
	.loadUnit_ready_o                	( loadUnit_ready_o                 ),
	.loadUnit_addr_misalign_o        	( loadUnit_addr_misalign_o         ),
	.loadUnit_page_error_o           	( loadUnit_page_error_o            ),
	.loadUnit_load_error_o           	( loadUnit_load_error_o            ),
	.loadUnit_rob_ptr_o              	( loadUnit_rob_ptr_o               ),
	.loadUnit_vaddr_o                	( loadUnit_vaddr_o                 ),
	.StoreQueue_valid_o              	( StoreQueue_valid_o               ),
	.StoreQueue_ready_o              	( StoreQueue_ready_o               ),
	.StoreQueue_addr_misalign_o      	( StoreQueue_addr_misalign_o       ),
	.StoreQueue_page_error_o         	( StoreQueue_page_error_o          ),
	.StoreQueue_rob_ptr_o            	( StoreQueue_rob_ptr_o             ),
	.StoreQueue_vaddr_o              	( StoreQueue_vaddr_o               ),
	.atomicUnit_valid_o              	( atomicUnit_valid_o               ),
	.atomicUnit_ready_o              	( atomicUnit_ready_o               ),
	.atomicUnit_ld_addr_misalign_o   	( atomicUnit_ld_addr_misalign_o    ),
	.atomicUnit_st_addr_misalign_o   	( atomicUnit_st_addr_misalign_o    ),
	.atomicUnit_ld_page_error_o      	( atomicUnit_ld_page_error_o       ),
	.atomicUnit_st_page_error_o      	( atomicUnit_st_page_error_o       ),
	.atomicUnit_load_error_o         	( atomicUnit_load_error_o          ),
	.atomicUnit_store_error_o        	( atomicUnit_store_error_o         ),
	.atomicUnit_rob_ptr_o            	( atomicUnit_rob_ptr_o             ),
	.atomic_vaddr_o                  	( atomic_vaddr_o                   ),
    .LoadQueue_flush_o                  ( LoadQueue_flush_o                ),
    .LoadQueue_rob_ptr_o                ( LoadQueue_rob_ptr_o              ),
	.rob_gen_redirect_valid          	( rob_gen_redirect_valid           ),
	.rob_gen_redirect_bp_miss        	( rob_gen_redirect_bp_miss         ),
	.rob_gen_redirect_call           	( rob_gen_redirect_call            ),
	.rob_gen_redirect_ret            	( rob_gen_redirect_ret             ),
	.rob_gen_redirect_end            	( rob_gen_redirect_end             ),
	.rob_gen_redirect_target         	( rob_gen_redirect_target          ),
	.rob_can_interrupt               	( rob_can_interrupt                ),
	.rob_commit_valid                	( rob_commit_valid                 ),
	.rob_commit_pc                   	( rob_commit_pc                    ),
	.rob_commit_next_pc              	( rob_commit_next_pc               ),
	.rob_trap_valid                  	( rob_trap_valid                   ),
	.rob_trap_cause                  	( rob_trap_cause                   ),
	.rob_trap_tval                   	( rob_trap_tval                    )
);

alu_mul_exu_block u_alu_mul_exu_block(
	.clk                      	( clk                       ),
	.rst_n                    	( rst_n                     ),
	.redirect                   ( redirect                  ),
    .alu_mul_exu_iq_enq_num     ( alu_mul_exu_iq_enq_num    ),
	.alu_mul_exu_in_valid     	( alu_mul_exu_in_valid      ),
	.alu_mul_exu_in_ready     	( alu_mul_exu_in_ready      ),
	.alu_mul_exu_in           	( alu_mul_exu_in            ),
	.rfwen                    	( rfwen                     ),
	.pwdest                   	( pwdest                    ),
	.alu_mul_exu_psrc         	( alu_mul_exu_psrc          ),
	.alu_mul_exu_psrc_rdata   	( alu_mul_exu_psrc_rdata    ),
	.alu_mul_exu_valid_o      	( alu_mul_exu_valid_o       ),
	.alu_mul_exu_ready_o      	( alu_mul_exu_ready_o       ),
	.alu_mul_exu_rob_ptr_o    	( alu_mul_exu_rob_ptr_o     ),
	.alu_mul_exu_pwdest_o     	( alu_mul_exu_pwdest_o      ),
	.alu_mul_exu_preg_wdata_o 	( alu_mul_exu_preg_wdata_o  )
);

alu_div_exu_block u_alu_div_exu_block(
	.clk                      	( clk                       ),
	.rst_n                    	( rst_n                     ),
	.redirect                   ( redirect                  ),
    .alu_div_exu_iq_enq_num     ( alu_div_exu_iq_enq_num    ),
	.alu_div_exu_in_valid     	( alu_div_exu_in_valid      ),
	.alu_div_exu_in_ready     	( alu_div_exu_in_ready      ),
	.alu_div_exu_in           	( alu_div_exu_in            ),
	.rfwen                    	( rfwen                     ),
	.pwdest                   	( pwdest                    ),
	.alu_div_exu_psrc         	( alu_div_exu_psrc          ),
	.alu_div_exu_psrc_rdata   	( alu_div_exu_psrc_rdata    ),
	.alu_div_exu_valid_o      	( alu_div_exu_valid_o       ),
	.alu_div_exu_ready_o      	( alu_div_exu_ready_o       ),
	.alu_div_exu_rob_ptr_o    	( alu_div_exu_rob_ptr_o     ),
	.alu_div_exu_pwdest_o     	( alu_div_exu_pwdest_o      ),
	.alu_div_exu_preg_wdata_o 	( alu_div_exu_preg_wdata_o  )
);

alu_bru_jump_exu_block u_alu_bru_jump_exu_block(
	.clk                           	( clk                            ),
	.rst_n                         	( rst_n                          ),
	.redirect                       ( redirect                       ),
    .alu_bru_jump_exu_iq_enq_num    ( alu_bru_jump_exu_iq_enq_num    ),
	.alu_bru_jump_exu_in_valid     	( alu_bru_jump_exu_in_valid      ),
	.alu_bru_jump_exu_in_ready     	( alu_bru_jump_exu_in_ready      ),
	.alu_bru_jump_exu_in           	( alu_bru_jump_exu_in            ),
	.rfwen                         	( rfwen                          ),
	.pwdest                        	( pwdest                         ),
	.alu_bru_jump_exu_psrc         	( alu_bru_jump_exu_psrc          ),
	.alu_bru_jump_exu_psrc_rdata   	( alu_bru_jump_exu_psrc_rdata    ),
	.bru_ftq_ptr                   	( bru_ftq_ptr                    ),
	.jump_ftq_ptr                  	( jump_ftq_ptr                   ),
	.bru_entry                     	( bru_entry                      ),
	.jump_entry                    	( jump_entry                     ),
	.alu_bru_jump_exu_valid_o      	( alu_bru_jump_exu_valid_o       ),
	.alu_bru_jump_exu_ready_o      	( alu_bru_jump_exu_ready_o       ),
	.alu_bru_jump_exu_rob_ptr_o    	( alu_bru_jump_exu_rob_ptr_o     ),
	.alu_bru_jump_exu_rfwen_o      	( alu_bru_jump_exu_rfwen_o       ),
	.alu_bru_jump_exu_pwdest_o     	( alu_bru_jump_exu_pwdest_o      ),
	.alu_bru_jump_exu_preg_wdata_o 	( alu_bru_jump_exu_preg_wdata_o  ),
	.alu_bru_jump_exu_token_miss_o 	( alu_bru_jump_exu_token_miss_o  ),
	.alu_bru_jump_exu_next_pc_o    	( alu_bru_jump_exu_next_pc_o     )
);

alu_csr_fence_exu_block u_alu_csr_fence_exu_block(
	.clk                             	( clk                              ),
	.rst_n                           	( rst_n                            ),
	.redirect                           ( redirect                         ),
    .alu_csr_fence_exu_iq_enq_num       ( alu_csr_fence_exu_iq_enq_num     ),
	.alu_csr_fence_exu_in_valid      	( alu_csr_fence_exu_in_valid       ),
	.alu_csr_fence_exu_in_ready      	( alu_csr_fence_exu_in_ready       ),
	.alu_csr_fence_exu_in            	( alu_csr_fence_exu_in             ),
	.rfwen                           	( rfwen                            ),
	.pwdest                          	( pwdest                           ),
	.alu_csr_fence_exu_psrc          	( alu_csr_fence_exu_psrc           ),
	.alu_csr_fence_exu_psrc_rdata    	( alu_csr_fence_exu_psrc_rdata     ),
	.csr_index                       	( csr_index                        ),
	.csr_rdata                       	( csr_rdata                        ),
	.mepc                            	( mepc_o                           ),
	.sepc                            	( sepc_o                           ),
	.dpc                             	( dpc_o                            ),
	.flush_i_valid                   	( flush_i_valid                    ),
	.flush_i_ready                   	( flush_i_ready                    ),
	.sflush_vma_valid                	( sflush_vma_valid                 ),
	.top_rob_ptr                     	( top_rob_ptr                      ),
	.csr_ftq_ptr                     	( csr_ftq_ptr                      ),
	.fence_ftq_ptr                   	( fence_ftq_ptr                    ),
	.csr_entry                       	( csr_entry                        ),
	.fence_entry                     	( fence_entry                      ),
	.alu_csr_fence_exu_valid_o       	( alu_csr_fence_exu_valid_o        ),
	.alu_csr_fence_exu_ready_o       	( alu_csr_fence_exu_ready_o        ),
	.alu_csr_fence_exu_rob_ptr_o     	( alu_csr_fence_exu_rob_ptr_o      ),
	.alu_csr_fence_exu_rfwen_o       	( alu_csr_fence_exu_rfwen_o        ),
	.alu_csr_fence_exu_csrwen_o      	( alu_csr_fence_exu_csrwen_o       ),
	.alu_csr_fence_exu_csr_index_o   	( alu_csr_fence_exu_csr_index_o    ),
	.alu_csr_fence_exu_csr_wdata_o   	( alu_csr_fence_exu_csr_wdata_o    ),
	.alu_csr_fence_exu_pwdest_o      	( alu_csr_fence_exu_pwdest_o       ),
	.alu_csr_fence_exu_preg_wdata_o  	( alu_csr_fence_exu_preg_wdata_o   ),
	.alu_csr_fence_exu_mret_o        	( alu_csr_fence_exu_mret_o         ),
	.alu_csr_fence_exu_sret_o        	( alu_csr_fence_exu_sret_o         ),
	.alu_csr_fence_exu_dret_o        	( alu_csr_fence_exu_dret_o         ),
	.alu_csr_fence_exu_satp_change_o 	( alu_csr_fence_exu_satp_change_o  ),
	.alu_csr_fence_exu_fence_o       	( alu_csr_fence_exu_fence_o        ),
	.alu_csr_fence_exu_next_pc_o     	( alu_csr_fence_exu_next_pc_o      )
);

intregfile u_intregfile(
	.clk                            	( clk                             ),
	.loadUnit_psrc                  	( loadUnit_psrc                   ),
	.loadUnit_psrc_rdata            	( loadUnit_psrc_rdata             ),
	.storedataUnit_psrc             	( storedataUnit_psrc              ),
	.storedataUnit_psrc_rdata       	( storedataUnit_psrc_rdata        ),
	.storeaddrUnit_psrc             	( storeaddrUnit_psrc              ),
	.storeaddrUnit_psrc_rdata       	( storeaddrUnit_psrc_rdata        ),
	.atomicUnit_psrc                	( atomicUnit_psrc                 ),
	.atomicUnit_psrc_rdata          	( atomicUnit_psrc_rdata           ),
	.alu_mul_exu_psrc               	( alu_mul_exu_psrc                ),
	.alu_mul_exu_psrc_rdata         	( alu_mul_exu_psrc_rdata          ),
	.alu_div_exu_psrc               	( alu_div_exu_psrc                ),
	.alu_div_exu_psrc_rdata         	( alu_div_exu_psrc_rdata          ),
	.alu_bru_jump_exu_psrc          	( alu_bru_jump_exu_psrc           ),
	.alu_bru_jump_exu_psrc_rdata    	( alu_bru_jump_exu_psrc_rdata     ),
	.alu_csr_fence_exu_psrc         	( alu_csr_fence_exu_psrc          ),
	.alu_csr_fence_exu_psrc_rdata   	( alu_csr_fence_exu_psrc_rdata    ),
	.loadUnit_valid_o               	( loadUnit_valid_o                ),
	.loadUnit_rfwen_o               	( loadUnit_rfwen_o                ),
	.loadUnit_pwdest_o              	( loadUnit_pwdest_o               ),
	.loadUnit_preg_wdata_o          	( loadUnit_preg_wdata_o           ),
	.atomicUnit_valid_o             	( atomicUnit_valid_o              ),
	.atomicUnit_rfwen_o             	( atomicUnit_rfwen_o              ),
	.atomicUnit_pwdest_o            	( atomicUnit_pwdest_o             ),
	.atomicUnit_preg_wdata_o        	( atomicUnit_preg_wdata_o         ),
	.alu_mul_exu_valid_o            	( alu_mul_exu_valid_o             ),
	.alu_mul_exu_pwdest_o           	( alu_mul_exu_pwdest_o            ),
	.alu_mul_exu_preg_wdata_o       	( alu_mul_exu_preg_wdata_o        ),
	.alu_div_exu_valid_o            	( alu_div_exu_valid_o             ),
	.alu_div_exu_pwdest_o           	( alu_div_exu_pwdest_o            ),
	.alu_div_exu_preg_wdata_o       	( alu_div_exu_preg_wdata_o        ),
	.alu_bru_jump_exu_valid_o       	( alu_bru_jump_exu_valid_o        ),
	.alu_bru_jump_exu_rfwen_o       	( alu_bru_jump_exu_rfwen_o        ),
	.alu_bru_jump_exu_pwdest_o      	( alu_bru_jump_exu_pwdest_o       ),
	.alu_bru_jump_exu_preg_wdata_o  	( alu_bru_jump_exu_preg_wdata_o   ),
	.alu_csr_fence_exu_valid_o      	( alu_csr_fence_exu_valid_o       ),
	.alu_csr_fence_exu_rfwen_o      	( alu_csr_fence_exu_rfwen_o       ),
	.alu_csr_fence_exu_pwdest_o     	( alu_csr_fence_exu_pwdest_o      ),
	.alu_csr_fence_exu_preg_wdata_o 	( alu_csr_fence_exu_preg_wdata_o  ),
	.rfwen                          	( rfwen                           ),
	.pwdest                         	( pwdest                          )
);

int_pstatus u_int_pstatus(
	.clk                   	( clk                    ),
	.rst_n                 	( rst_n                  ),
	.redirect              	( redirect               ),
	.rfwen                 	( rfwen                  ),
	.pwdest                	( pwdest                 ),
	.pdest_valid           	( pdest_valid            ),
	.pdest                 	( pdest                  ),
	.dispatch_psrc1        	( dispatch_psrc1         ),
	.dispatch_psrc2        	( dispatch_psrc2         ),
	.dispatch_psrc1_status 	( dispatch_psrc1_status  ),
	.dispatch_psrc2_status 	( dispatch_psrc2_status  )
);

csr #(
	.cfg_mhartid 	( 0  ))
u_csr(
	.clk                           	( clk                            ),
	.rst_n                         	( rst_n                          ),
	.stip                          	( stip                           ),
	.seip                          	( seip                           ),
	.ssip                          	( ssip                           ),
	.mtip                          	( mtip                           ),
	.meip                          	( meip                           ),
	.msip                          	( msip                           ),
	.halt_req                      	( halt_req                       ),
	.current_priv_status           	( current_priv_status            ),
	.MXR                           	( MXR                            ),
	.SUM                           	( SUM                            ),
	.MPRV                          	( MPRV                           ),
	.MPP                           	( MPP                            ),
	.satp_mode                     	( satp_mode                      ),
	.satp_asid                     	( satp_asid                      ),
	.satp_ppn                      	( satp_ppn                       ),
	.csr_jump_flag                 	( csr_jump_flag                  ),
	.csr_jump_addr                 	( csr_jump_addr                  ),
	.csr_index                     	( csr_index                      ),
	.csr_rdata                     	( csr_rdata                      ),
	.TSR                           	( TSR                            ),
	.TW                            	( TW                             ),
	.TVM                           	( TVM                            ),
	.debug_mode                    	( debug_mode                     ),
    .mepc_o                         ( mepc_o                         ),
    .sepc_o                         ( sepc_o                         ),
    .dpc_o                          ( dpc_o                          ),
	.rob_can_interrupt             	( rob_can_interrupt              ),
	.rob_commit_valid              	( rob_commit_valid               ),
	.rob_commit_pc                 	( rob_commit_pc                  ),
	.rob_commit_next_pc            	( rob_commit_next_pc             ),
    .interrupt_happen               ( interrupt_happen               ),
	.rob_trap_valid                	( rob_trap_valid                 ),
	.rob_trap_cause                	( rob_trap_cause                 ),
	.rob_trap_tval                 	( rob_trap_tval                  ),
	.decode_out_valid              	( decode_out_valid               ),
	.rename_ready                  	( rename_ready                   ),
	.alu_csr_fence_exu_valid_o     	( alu_csr_fence_exu_valid_o      ),
	.alu_csr_fence_exu_csrwen_o    	( alu_csr_fence_exu_csrwen_o     ),
	.alu_csr_fence_exu_csr_index_o 	( alu_csr_fence_exu_csr_index_o  ),
	.alu_csr_fence_exu_csr_wdata_o 	( alu_csr_fence_exu_csr_wdata_o  ),
	.alu_csr_fence_exu_mret_o      	( alu_csr_fence_exu_mret_o       ),
	.alu_csr_fence_exu_sret_o      	( alu_csr_fence_exu_sret_o       ),
	.alu_csr_fence_exu_dret_o      	( alu_csr_fence_exu_dret_o       )
);

gen_redirect u_gen_redirect(
	.rob_commit_valid         	( rob_commit_valid          ),
	.rob_commit_next_pc       	( rob_commit_next_pc        ),
	.rob_gen_redirect_valid   	( rob_gen_redirect_valid    ),
	.rob_gen_redirect_bp_miss 	( rob_gen_redirect_bp_miss  ),
	.rob_gen_redirect_call    	( rob_gen_redirect_call     ),
	.rob_gen_redirect_ret     	( rob_gen_redirect_ret      ),
    .rob_gen_redirect_end       ( rob_gen_redirect_end      ),
	.rob_gen_redirect_target  	( rob_gen_redirect_target   ),
    .interrupt_happen           ( interrupt_happen          ),
	.csr_jump_flag            	( csr_jump_flag             ),
	.csr_jump_addr            	( csr_jump_addr             ),
	.redirect                 	( redirect                  ),
	.commit_ftq_valid         	( commit_ftq_valid          ),
    .commit_end                 ( commit_end                ),
	.jump_restore_valid       	( jump_restore_valid        ),
	.jump_other_valid         	( jump_other_valid          ),
	.jump_call                	( jump_call                 ),
	.jump_ret                 	( jump_ret                  ),
	.jump_target              	( jump_target               ),
	.jump_push_pc             	( jump_push_pc              )
);


endmodule //backend_top
