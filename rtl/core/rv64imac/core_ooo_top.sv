module core_ooo_top
import frontend_pkg::*;
import rob_pkg::*;
import lsq_pkg::*;
import iq_pkg::*;
import regfile_pkg::*;
import core_setting_pkg::*;
#(
    parameter AXI_ID_SB_I = 1,
    parameter AXI_ID_SB_D = 2,

    // Address width in bits
    parameter AXI_ADDR_W = 64,
    // ID width in bits
    parameter AXI_ID_W = 8,
    // Data width in bits
    parameter AXI_DATA_W = 64,

    parameter ICACHE_WAY = 2, 
    parameter ICACHE_GROUP = 2,
    parameter DCACHE_WAY = 2, 
    parameter DCACHE_GROUP = 2,
    parameter PMEM_START = 64'h8000_0000,
    parameter PMEM_END = 64'hFFFF_FFFF,
    parameter MMU_WAY = 2, 
    parameter MMU_GROUP = 1
)(
    input                                               clk,
    input                                               rst_n,
//interface with interrupt sign
    input                                               stip_asyn,
    input                                               seip_asyn,
    input                                               ssip_asyn,
    input                                               mtip_asyn,
    input                                               meip_asyn,
    input                                               msip_asyn,
    input                                               halt_req,
//interface with axi
    //read addr channel
    output                                              icache_arvalid,
    input                                               icache_arready,
    output [AXI_ADDR_W    -1:0]                         icache_araddr,
    output [8             -1:0]                         icache_arlen,
    output [3             -1:0]                         icache_arsize,
    output [2             -1:0]                         icache_arburst,
    output [AXI_ID_W      -1:0]                         icache_arid,
    //read data channel
    input                                               icache_rvalid,
    output                                              icache_rready,
    input  [AXI_ID_W      -1:0]                         icache_rid,
    input  [2             -1:0]                         icache_rresp,
    input  [AXI_DATA_W    -1:0]                         icache_rdata,
    input                                               icache_rlast,
//interface with axi
    //read addr channel
    output                                              dcache_arvalid,
    input                                               dcache_arready,
    output [AXI_ADDR_W    -1:0]                         dcache_araddr,
    output [8             -1:0]                         dcache_arlen,
    output [3             -1:0]                         dcache_arsize,
    output [2             -1:0]                         dcache_arburst,
    output                                              dcache_arlock,
    output [AXI_ID_W      -1:0]                         dcache_arid,
    //read data channel
    input                                               dcache_rvalid,
    output                                              dcache_rready,
    input  [AXI_ID_W      -1:0]                         dcache_rid,
    input  [2             -1:0]                         dcache_rresp,
    input  [AXI_DATA_W    -1:0]                         dcache_rdata,
    input                                               dcache_rlast,
    //write addr channel
    output                                              dcache_awvalid,
    input                                               dcache_awready,
    output [AXI_ADDR_W    -1:0]                         dcache_awaddr,
    output [8             -1:0]                         dcache_awlen,
    output [3             -1:0]                         dcache_awsize,
    output [2             -1:0]                         dcache_awburst,
    output                                              dcache_awlock,
    output [AXI_ID_W      -1:0]                         dcache_awid,
    //write data channel
    output                                              dcache_wvalid,
    input                                               dcache_wready,
    output                                              dcache_wlast,
    output [AXI_DATA_W    -1:0]                         dcache_wdata,
    output [AXI_DATA_W/8  -1:0]                         dcache_wstrb,
    //write resp channel
    input                                               dcache_bvalid,
    output                                              dcache_bready,
    input  [AXI_ID_W      -1:0]                         dcache_bid,
    input  [2             -1:0]                         dcache_bresp,

    // Uncache axi interface
    output                                              Uncache_awvalid,
    input                                               Uncache_awready,
    output  [2:0]                                       Uncache_awsize,
    output  [63:0]                                      Uncache_awaddr,

    output                                              Uncache_wvalid,
    input                                               Uncache_wready,
    output [7:0]                                        Uncache_wstrb,
    output [63:0]                                       Uncache_wdata,

    input                                               Uncache_bvalid,
    output                                              Uncache_bready,
    input  [1:0]                                        Uncache_bresp
);

// outports logic u_frontend_top
logic                                   redirect;
logic                                   rename_fire;
ftq_entry                               rob_ftq_entry;
ftq_entry                               bru_entry;
ftq_entry                               jump_entry;
ftq_entry                               csr_entry;
ftq_entry                               fence_entry;
ftq_entry                               rob_ftq_entry_lq_raw;
logic                                   immu_miss_valid;
logic [63:0]                            vaddr_i;
ibuf_inst_o_entry [decode_width-1:0]    ibuf_inst_o;

logic                                   meip;
logic                                   msip;
logic                                   mtip;
logic                                   seip;
logic                                   ssip;
logic                                   stip;

// outports logic u_backend_top
rob_entry_ptr_t                         top_rob_ptr;
ls_rob_entry_ptr_t                      deq_rob_ptr;
logic [decode_width-1:0]                decode_inst_ready;
logic [rename_width-1:0]                sq_req;
sq_entry_t [rename_width-1:0]           sq_req_entry;
logic                                   loadUnit_in_valid;
iq_mem_load_in_t                        loadUnit_in;
logic                                   storeaddrUnit_in_valid;
iq_mem_store_addr_in_t                  storeaddrUnit_in;
logic                                   storedataUnit_in_valid;
iq_mem_store_data_in_t                  storedataUnit_in;
logic                                   atomicUnit_in_valid;
iq_mem_atomic_in_t                      atomicUnit_in;
logic [FTQ_ENTRY_BIT_NUM-1:0]           rob_ftq_ptr;
logic [FTQ_ENTRY_BIT_NUM-1:0]           bru_ftq_ptr;
logic [FTQ_ENTRY_BIT_NUM-1:0]           jump_ftq_ptr;
logic [FTQ_ENTRY_BIT_NUM-1:0]           csr_ftq_ptr;
logic [FTQ_ENTRY_BIT_NUM-1:0]           fence_ftq_ptr;
logic [FTQ_ENTRY_BIT_NUM-1:0]           rob_ftq_ptr_lq_raw;
logic                                   flush_i_valid;
logic                                   sflush_vma_valid;
intreg_t                                loadUnit_psrc_rdata;
intreg_t                                storedataUnit_psrc_rdata;
intreg_t                                storeaddrUnit_psrc_rdata;
intreg_t [1:0]                          atomicUnit_psrc_rdata;
logic                                   loadUnit_ready_o;
logic                                   StoreQueue_ready_o;
logic                                   atomicUnit_ready_o;
logic [wb_width-1:0]                    rfwen;
pint_regdest_t [wb_width-1:0]           pwdest;
logic [1:0]                             current_priv_status;
logic                                   MXR;
logic                                   SUM;
logic                                   MPRV;
logic [1:0]                             MPP;
logic [3:0]                             satp_mode;
logic [15:0]                            satp_asid;
logic [43:0]                            satp_ppn;
logic                                   commit_ftq_valid;
logic                                   commit_end;
logic                                   jump_restore_valid;
logic                                   jump_other_valid;
logic                                   jump_call;
logic                                   jump_ret;
logic [63:0]                            jump_target;
logic [63:0]                            jump_push_pc;

// outports logic u_mem_top
logic                                   flush_i_ready;
sq_resp_t [rename_width-1:0]            sq_resp;
logic                                   storeaddrUnit_in_ready;
logic                                   storedataUnit_in_ready;
logic                                   loadUnit_in_ready;
logic                                   atomicUnit_in_ready;
pint_regsrc_t                           storeaddrUnit_psrc;
pint_regsrc_t                           storedataUnit_psrc;
pint_regsrc_t                           loadUnit_psrc;
pint_regsrc_t [1:0]                     atomicUnit_psrc;
logic                                   StoreQueue_valid_o;
logic                                   StoreQueue_addr_misalign_o;
logic                                   StoreQueue_page_error_o;
rob_entry_ptr_t                         StoreQueue_rob_ptr_o;
logic [63:0]                            StoreQueue_vaddr_o;
logic                                   loadUnit_valid_o;
logic                                   loadUnit_addr_misalign_o;
logic                                   loadUnit_page_error_o;
logic                                   loadUnit_load_error_o;
logic                                   loadUnit_rfwen_o;
pint_regdest_t                          loadUnit_pwdest_o;
logic [63:0]                            loadUnit_preg_wdata_o;
rob_entry_ptr_t                         loadUnit_rob_ptr_o;
logic [63:0]                            loadUnit_vaddr_o;
logic                                   atomicUnit_valid_o;
logic                                   atomicUnit_ld_addr_misalign_o;
logic                                   atomicUnit_st_addr_misalign_o;
logic                                   atomicUnit_ld_page_error_o;
logic                                   atomicUnit_st_page_error_o;
logic                                   atomicUnit_load_error_o;
logic                                   atomicUnit_store_error_o;
rob_entry_ptr_t                         atomicUnit_rob_ptr_o;
logic [63:0]                            atomic_vaddr_o;
logic                                   atomicUnit_rfwen_o;
pint_regdest_t                          atomicUnit_pwdest_o;
logic [63:0]                            atomicUnit_preg_wdata_o;
logic                                   LoadQueue_flush_o;
rob_entry_ptr_t                         LoadQueue_rob_ptr_o;
logic                                   immu_miss_ready;
logic                                   pte_valid;
logic [127:0]                           pte;
logic                                   pte_error;

frontend_top #(
	.AXI_ID_SB    	( AXI_ID_SB_I   ),
	.AXI_ADDR_W   	( AXI_ADDR_W    ),
	.AXI_ID_W     	( AXI_ID_W      ),
	.AXI_DATA_W   	( AXI_DATA_W    ),
	.ICACHE_WAY   	( ICACHE_WAY    ),
	.ICACHE_GROUP 	( ICACHE_GROUP  ),
	.PMEM_START   	( PMEM_START    ),
	.PMEM_END     	( PMEM_END      ))
u_frontend_top(
	.clk                 	( clk                  ),
	.rst_n               	( rst_n                ),
	.rob_ftq_ptr         	( rob_ftq_ptr          ),
	.bru_ftq_ptr         	( bru_ftq_ptr          ),
	.jump_ftq_ptr        	( jump_ftq_ptr         ),
	.csr_ftq_ptr         	( csr_ftq_ptr          ),
	.fence_ftq_ptr       	( fence_ftq_ptr        ),
    .rob_ftq_ptr_lq_raw     ( rob_ftq_ptr_lq_raw   ),
	.rob_ftq_entry       	( rob_ftq_entry        ),
	.bru_entry           	( bru_entry            ),
	.jump_entry          	( jump_entry           ),
	.csr_entry           	( csr_entry            ),
	.fence_entry         	( fence_entry          ),
    .rob_ftq_entry_lq_raw   ( rob_ftq_entry_lq_raw ),
	.commit_ftq_valid    	( commit_ftq_valid     ),
	.commit_end          	( commit_end           ),
	.jump_restore_valid  	( jump_restore_valid   ),
	.jump_other_valid    	( jump_other_valid     ),
	.jump_call           	( jump_call            ),
	.jump_ret            	( jump_ret             ),
	.jump_target         	( jump_target          ),
	.jump_push_pc        	( jump_push_pc         ),
	.current_priv_status 	( current_priv_status  ),
	.satp_mode           	( satp_mode            ),
	.satp_asid           	( satp_asid            ),
	.flush_i_valid       	( flush_i_valid        ),
	.sflush_vma_valid    	( sflush_vma_valid     ),
	.immu_miss_valid     	( immu_miss_valid      ),
	.immu_miss_ready     	( immu_miss_ready      ),
	.vaddr_i             	( vaddr_i              ),
	.pte_valid           	( pte_valid            ),
	.pte                 	( pte                  ),
	.pte_error           	( pte_error            ),
	.icache_arvalid      	( icache_arvalid       ),
	.icache_arready      	( icache_arready       ),
	.icache_araddr       	( icache_araddr        ),
	.icache_arlen        	( icache_arlen         ),
	.icache_arsize       	( icache_arsize        ),
	.icache_arburst      	( icache_arburst       ),
	.icache_arid         	( icache_arid          ),
	.icache_rvalid       	( icache_rvalid        ),
	.icache_rready       	( icache_rready        ),
	.icache_rid          	( icache_rid           ),
	.icache_rresp        	( icache_rresp         ),
	.icache_rdata        	( icache_rdata         ),
	.icache_rlast        	( icache_rlast         ),
	.ibuf_inst_o         	( ibuf_inst_o          ),
	.decode_inst_ready   	( decode_inst_ready    )
);

sync #(.DATA_LEN( 1 )) u_meip(.clk( clk ), .rst_n( rst_n ), .in_asyn( meip_asyn ), .out_syn( meip ));
sync #(.DATA_LEN( 1 )) u_msip(.clk( clk ), .rst_n( rst_n ), .in_asyn( msip_asyn ), .out_syn( msip ));
sync #(.DATA_LEN( 1 )) u_mtip(.clk( clk ), .rst_n( rst_n ), .in_asyn( mtip_asyn ), .out_syn( mtip ));
sync #(.DATA_LEN( 1 )) u_seip(.clk( clk ), .rst_n( rst_n ), .in_asyn( seip_asyn ), .out_syn( seip ));
sync #(.DATA_LEN( 1 )) u_ssip(.clk( clk ), .rst_n( rst_n ), .in_asyn( ssip_asyn ), .out_syn( ssip ));
sync #(.DATA_LEN( 1 )) u_stip(.clk( clk ), .rst_n( rst_n ), .in_asyn( stip_asyn ), .out_syn( stip ));

backend_top u_backend_top(
	.clk                           	( clk                            ),
	.rst_n                         	( rst_n                          ),
	.stip                          	( stip                           ),
	.seip                          	( seip                           ),
	.ssip                          	( ssip                           ),
	.mtip                          	( mtip                           ),
	.meip                          	( meip                           ),
	.msip                          	( msip                           ),
	.halt_req                      	( halt_req                       ),
    .redirect                       ( redirect                       ),
    .rename_fire                    ( rename_fire                    ),
	.top_rob_ptr                   	( top_rob_ptr                    ),
	.deq_rob_ptr                   	( deq_rob_ptr                    ),
	.ibuf_inst_o                   	( ibuf_inst_o                    ),
	.decode_inst_ready             	( decode_inst_ready              ),
	.sq_req                        	( sq_req                         ),
	.sq_req_entry                  	( sq_req_entry                   ),
	.sq_resp                       	( sq_resp                        ),
	.loadUnit_in_valid             	( loadUnit_in_valid              ),
	.loadUnit_in_ready             	( loadUnit_in_ready              ),
	.loadUnit_in                   	( loadUnit_in                    ),
	.storeaddrUnit_in_valid        	( storeaddrUnit_in_valid         ),
	.storeaddrUnit_in_ready        	( storeaddrUnit_in_ready         ),
	.storeaddrUnit_in              	( storeaddrUnit_in               ),
	.storedataUnit_in_valid        	( storedataUnit_in_valid         ),
	.storedataUnit_in_ready        	( storedataUnit_in_ready         ),
	.storedataUnit_in              	( storedataUnit_in               ),
	.atomicUnit_in_valid           	( atomicUnit_in_valid            ),
	.atomicUnit_in_ready           	( atomicUnit_in_ready            ),
	.atomicUnit_in                 	( atomicUnit_in                  ),
	.rob_ftq_ptr                   	( rob_ftq_ptr                    ),
	.bru_ftq_ptr                   	( bru_ftq_ptr                    ),
	.jump_ftq_ptr                  	( jump_ftq_ptr                   ),
	.csr_ftq_ptr                   	( csr_ftq_ptr                    ),
	.fence_ftq_ptr                 	( fence_ftq_ptr                  ),
    .rob_ftq_ptr_lq_raw             ( rob_ftq_ptr_lq_raw             ),
	.rob_ftq_entry                 	( rob_ftq_entry                  ),
	.bru_entry                     	( bru_entry                      ),
	.jump_entry                    	( jump_entry                     ),
	.csr_entry                     	( csr_entry                      ),
	.fence_entry                   	( fence_entry                    ),
    .rob_ftq_entry_lq_raw           ( rob_ftq_entry_lq_raw           ),
	.flush_i_valid                 	( flush_i_valid                  ),
	.flush_i_ready                 	( flush_i_ready                  ),
	.sflush_vma_valid              	( sflush_vma_valid               ),
	.loadUnit_psrc                 	( loadUnit_psrc                  ),
	.loadUnit_psrc_rdata           	( loadUnit_psrc_rdata            ),
	.storedataUnit_psrc            	( storedataUnit_psrc             ),
	.storedataUnit_psrc_rdata      	( storedataUnit_psrc_rdata       ),
	.storeaddrUnit_psrc            	( storeaddrUnit_psrc             ),
	.storeaddrUnit_psrc_rdata      	( storeaddrUnit_psrc_rdata       ),
	.atomicUnit_psrc               	( atomicUnit_psrc                ),
	.atomicUnit_psrc_rdata         	( atomicUnit_psrc_rdata          ),
	.loadUnit_valid_o              	( loadUnit_valid_o               ),
	.loadUnit_ready_o              	( loadUnit_ready_o               ),
	.loadUnit_addr_misalign_o      	( loadUnit_addr_misalign_o       ),
	.loadUnit_page_error_o         	( loadUnit_page_error_o          ),
	.loadUnit_load_error_o         	( loadUnit_load_error_o          ),
	.loadUnit_rob_ptr_o            	( loadUnit_rob_ptr_o             ),
	.loadUnit_vaddr_o              	( loadUnit_vaddr_o               ),
	.loadUnit_rfwen_o              	( loadUnit_rfwen_o               ),
	.loadUnit_pwdest_o             	( loadUnit_pwdest_o              ),
	.loadUnit_preg_wdata_o         	( loadUnit_preg_wdata_o          ),
	.StoreQueue_valid_o            	( StoreQueue_valid_o             ),
	.StoreQueue_ready_o            	( StoreQueue_ready_o             ),
	.StoreQueue_addr_misalign_o    	( StoreQueue_addr_misalign_o     ),
	.StoreQueue_page_error_o       	( StoreQueue_page_error_o        ),
	.StoreQueue_rob_ptr_o          	( StoreQueue_rob_ptr_o           ),
	.StoreQueue_vaddr_o            	( StoreQueue_vaddr_o             ),
	.atomicUnit_valid_o            	( atomicUnit_valid_o             ),
	.atomicUnit_ready_o            	( atomicUnit_ready_o             ),
	.atomicUnit_ld_addr_misalign_o 	( atomicUnit_ld_addr_misalign_o  ),
	.atomicUnit_st_addr_misalign_o 	( atomicUnit_st_addr_misalign_o  ),
	.atomicUnit_ld_page_error_o    	( atomicUnit_ld_page_error_o     ),
	.atomicUnit_st_page_error_o    	( atomicUnit_st_page_error_o     ),
	.atomicUnit_load_error_o       	( atomicUnit_load_error_o        ),
	.atomicUnit_store_error_o      	( atomicUnit_store_error_o       ),
	.atomicUnit_rob_ptr_o          	( atomicUnit_rob_ptr_o           ),
	.atomic_vaddr_o                	( atomic_vaddr_o                 ),
	.atomicUnit_rfwen_o            	( atomicUnit_rfwen_o             ),
	.atomicUnit_pwdest_o           	( atomicUnit_pwdest_o            ),
	.atomicUnit_preg_wdata_o       	( atomicUnit_preg_wdata_o        ),
	.LoadQueue_flush_o             	( LoadQueue_flush_o              ),
	.LoadQueue_rob_ptr_o           	( LoadQueue_rob_ptr_o            ),
	.rfwen                         	( rfwen                          ),
	.pwdest                        	( pwdest                         ),
	.current_priv_status           	( current_priv_status            ),
	.MXR                           	( MXR                            ),
	.SUM                           	( SUM                            ),
	.MPRV                          	( MPRV                           ),
	.MPP                           	( MPP                            ),
	.satp_mode                     	( satp_mode                      ),
	.satp_asid                     	( satp_asid                      ),
	.satp_ppn                      	( satp_ppn                       ),
	.commit_ftq_valid              	( commit_ftq_valid               ),
	.commit_end                    	( commit_end                     ),
	.jump_restore_valid            	( jump_restore_valid             ),
	.jump_other_valid              	( jump_other_valid               ),
	.jump_call                     	( jump_call                      ),
	.jump_ret                      	( jump_ret                       ),
	.jump_target                   	( jump_target                    ),
	.jump_push_pc                  	( jump_push_pc                   )
);

mem_top #(
    .AXI_ID_SB     ( AXI_ID_SB_D ),
    .AXI_ADDR_W    ( AXI_ADDR_W  ),
    .AXI_ID_W      ( AXI_ID_W    ),
    .AXI_DATA_W    ( AXI_DATA_W  ),
    .DCACHE_WAY    ( DCACHE_WAY  ),
    .DCACHE_GROUP  ( DCACHE_GROUP),
    .PMEM_START    ( PMEM_START  ),
    .PMEM_END      ( PMEM_END    ),
	.MMU_WAY   	   ( MMU_WAY     ),
	.MMU_GROUP 	   ( MMU_GROUP   ))
u_mem_top(
	.clk                           	( clk                            ),
	.rst_n                         	( rst_n                          ),
	.redirect                      	( redirect                       ),
	.current_priv_status           	( current_priv_status            ),
	.MXR                           	( MXR                            ),
	.SUM                           	( SUM                            ),
	.MPRV                          	( MPRV                           ),
	.MPP                           	( MPP                            ),
	.satp_mode                     	( satp_mode                      ),
	.satp_asid                     	( satp_asid                      ),
	.satp_ppn                      	( satp_ppn                       ),
	.flush_i_valid                 	( flush_i_valid                  ),
	.flush_i_ready                 	( flush_i_ready                  ),
	.sflush_vma_valid              	( sflush_vma_valid               ),
	.top_rob_ptr                   	( top_rob_ptr                    ),
	.deq_rob_ptr                   	( deq_rob_ptr                    ),
	.rename_fire                   	( rename_fire                    ),
	.sq_req                        	( sq_req                         ),
	.sq_req_entry                  	( sq_req_entry                   ),
	.sq_resp                       	( sq_resp                        ),
	.storeaddrUnit_in_valid        	( storeaddrUnit_in_valid         ),
	.storeaddrUnit_in_ready        	( storeaddrUnit_in_ready         ),
	.storeaddrUnit_in              	( storeaddrUnit_in               ),
	.storedataUnit_in_valid        	( storedataUnit_in_valid         ),
	.storedataUnit_in_ready        	( storedataUnit_in_ready         ),
	.storedataUnit_in              	( storedataUnit_in               ),
	.loadUnit_in_valid             	( loadUnit_in_valid              ),
	.loadUnit_in_ready             	( loadUnit_in_ready              ),
	.loadUnit_in                   	( loadUnit_in                    ),
	.atomicUnit_in_valid           	( atomicUnit_in_valid            ),
	.atomicUnit_in_ready           	( atomicUnit_in_ready            ),
	.atomicUnit_in                 	( atomicUnit_in                  ),
	.rfwen                         	( rfwen                          ),
	.pwdest                        	( pwdest                         ),
	.storeaddrUnit_psrc            	( storeaddrUnit_psrc             ),
	.storeaddrUnit_psrc_rdata      	( storeaddrUnit_psrc_rdata       ),
	.storedataUnit_psrc            	( storedataUnit_psrc             ),
	.storedataUnit_psrc_rdata      	( storedataUnit_psrc_rdata       ),
	.loadUnit_psrc                 	( loadUnit_psrc                  ),
	.loadUnit_psrc_rdata           	( loadUnit_psrc_rdata            ),
	.atomicUnit_psrc               	( atomicUnit_psrc                ),
	.atomicUnit_psrc_rdata         	( atomicUnit_psrc_rdata          ),
	.StoreQueue_valid_o            	( StoreQueue_valid_o             ),
	.StoreQueue_ready_o            	( StoreQueue_ready_o             ),
	.StoreQueue_addr_misalign_o    	( StoreQueue_addr_misalign_o     ),
	.StoreQueue_page_error_o       	( StoreQueue_page_error_o        ),
	.StoreQueue_rob_ptr_o          	( StoreQueue_rob_ptr_o           ),
	.StoreQueue_vaddr_o            	( StoreQueue_vaddr_o             ),
	.loadUnit_valid_o              	( loadUnit_valid_o               ),
	.loadUnit_ready_o              	( loadUnit_ready_o               ),
	.loadUnit_addr_misalign_o      	( loadUnit_addr_misalign_o       ),
	.loadUnit_page_error_o         	( loadUnit_page_error_o          ),
	.loadUnit_load_error_o         	( loadUnit_load_error_o          ),
	.loadUnit_rfwen_o              	( loadUnit_rfwen_o               ),
	.loadUnit_pwdest_o             	( loadUnit_pwdest_o              ),
	.loadUnit_preg_wdata_o         	( loadUnit_preg_wdata_o          ),
	.loadUnit_rob_ptr_o             ( loadUnit_rob_ptr_o             ),
	.loadUnit_vaddr_o               ( loadUnit_vaddr_o               ),
	.atomicUnit_valid_o            	( atomicUnit_valid_o             ),
	.atomicUnit_ready_o            	( atomicUnit_ready_o             ),
	.atomicUnit_ld_addr_misalign_o 	( atomicUnit_ld_addr_misalign_o  ),
	.atomicUnit_st_addr_misalign_o 	( atomicUnit_st_addr_misalign_o  ),
	.atomicUnit_ld_page_error_o    	( atomicUnit_ld_page_error_o     ),
	.atomicUnit_st_page_error_o    	( atomicUnit_st_page_error_o     ),
	.atomicUnit_load_error_o       	( atomicUnit_load_error_o        ),
	.atomicUnit_store_error_o      	( atomicUnit_store_error_o       ),
	.atomicUnit_rob_ptr_o          	( atomicUnit_rob_ptr_o           ),
	.atomic_vaddr_o                	( atomic_vaddr_o                 ),
	.atomicUnit_rfwen_o            	( atomicUnit_rfwen_o             ),
	.atomicUnit_pwdest_o           	( atomicUnit_pwdest_o            ),
	.atomicUnit_preg_wdata_o       	( atomicUnit_preg_wdata_o        ),
	.LoadQueue_flush_o             	( LoadQueue_flush_o              ),
	.LoadQueue_rob_ptr_o           	( LoadQueue_rob_ptr_o            ),
	.immu_miss_valid               	( immu_miss_valid                ),
	.immu_miss_ready               	( immu_miss_ready                ),
	.vaddr_i                       	( vaddr_i                        ),
	.pte_valid                     	( pte_valid                      ),
	.pte                           	( pte                            ),
	.pte_error                     	( pte_error                      ),
	.Uncache_awvalid               	( Uncache_awvalid                ),
	.Uncache_awready               	( Uncache_awready                ),
	.Uncache_awsize                	( Uncache_awsize                 ),
	.Uncache_awaddr                	( Uncache_awaddr                 ),
	.Uncache_wvalid                	( Uncache_wvalid                 ),
	.Uncache_wready                	( Uncache_wready                 ),
	.Uncache_wstrb                 	( Uncache_wstrb                  ),
	.Uncache_wdata                 	( Uncache_wdata                  ),
	.Uncache_bvalid                	( Uncache_bvalid                 ),
	.Uncache_bready                	( Uncache_bready                 ),
	.Uncache_bresp                 	( Uncache_bresp                  ),
    .dcache_arvalid                 ( dcache_arvalid                 ),
    .dcache_arready                 ( dcache_arready                 ),
    .dcache_araddr                  ( dcache_araddr                  ),
    .dcache_arlen                   ( dcache_arlen                   ),
    .dcache_arsize                  ( dcache_arsize                  ),
    .dcache_arburst                 ( dcache_arburst                 ),
    .dcache_arlock                  ( dcache_arlock                  ),
    .dcache_arid                    ( dcache_arid                    ),
    .dcache_rvalid                  ( dcache_rvalid                  ),
    .dcache_rready                  ( dcache_rready                  ),
    .dcache_rid                     ( dcache_rid                     ),
    .dcache_rresp                   ( dcache_rresp                   ),
    .dcache_rdata                   ( dcache_rdata                   ),
    .dcache_rlast                   ( dcache_rlast                   ),
    .dcache_awvalid                 ( dcache_awvalid                 ),
    .dcache_awready                 ( dcache_awready                 ),
    .dcache_awaddr                  ( dcache_awaddr                  ),
    .dcache_awlen                   ( dcache_awlen                   ),
    .dcache_awsize                  ( dcache_awsize                  ),
    .dcache_awburst                 ( dcache_awburst                 ),
    .dcache_awlock                  ( dcache_awlock                  ),
    .dcache_awid                    ( dcache_awid                    ),
    .dcache_wvalid                  ( dcache_wvalid                  ),
    .dcache_wready                  ( dcache_wready                  ),
    .dcache_wlast                   ( dcache_wlast                   ),
    .dcache_wdata                   ( dcache_wdata                   ),
    .dcache_wstrb                   ( dcache_wstrb                   ),
    .dcache_bvalid                  ( dcache_bvalid                  ),
    .dcache_bready                  ( dcache_bready                  ),
    .dcache_bid                     ( dcache_bid                     ),
    .dcache_bresp                   ( dcache_bresp                   )
);



endmodule //core_ooo_top
