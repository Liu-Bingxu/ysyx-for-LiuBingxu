module mem_top
import lsq_pkg::*;
import rob_pkg::*;
import mem_pkg::*;
import sb_pkg::*;
import iq_pkg::*;
import regfile_pkg::*;
import core_setting_pkg::*;
#(
    parameter AXI_ID_SB = 3, 

    // Address width in bits
    parameter AXI_ADDR_W = 64,
    // ID width in bits
    parameter AXI_ID_W = 8,
    // Data width in bits
    parameter AXI_DATA_W = 64,

    parameter DCACHE_WAY = 2, 
    parameter DCACHE_GROUP = 4,
    parameter PMEM_START = 64'h8000_0000,
    parameter PMEM_END = 64'hFFFF_FFFF,
    parameter MMU_WAY = 2,
    parameter MMU_GROUP = 1
)(
    input                                               clk,
    input                                               rst_n,

    input                                               redirect,

    // interface with wbu 
    input  [1:0]                                        current_priv_status,
    input         	                                    MXR,
    input         	                                    SUM,
    input         	                                    MPRV,
    input  [1:0]  	                                    MPP,
    input  [3:0]                                        satp_mode,
    input  [15:0]                                       satp_asid,
    input  [43:0]                                       satp_ppn,

    // fence_i interface
    input                                               flush_i_valid,
    output                                              flush_i_ready,
    // sfence_vma interface
    input                                               sflush_vma_valid,

    input  rob_entry_ptr_t                              top_rob_ptr,
    input  ls_rob_entry_ptr_t                           deq_rob_ptr,

    input                                               rename_fire,
    input              [rename_width - 1 : 0]           sq_req,
    input   sq_entry_t [rename_width - 1 : 0]           sq_req_entry,
    output  sq_resp_t  [rename_width - 1 : 0]           sq_resp,

    input                                               storeaddrUnit_in_valid,
    output                                              storeaddrUnit_in_ready,
    input  iq_mem_store_addr_in_t                       storeaddrUnit_in,

    input                                               storedataUnit_in_valid,
    output                                              storedataUnit_in_ready,
    input  iq_mem_store_data_in_t                       storedataUnit_in,

    input                                               loadUnit_in_valid,
    output                                              loadUnit_in_ready,
    input  iq_mem_load_in_t                             loadUnit_in,

    input                                               atomicUnit_in_valid,
    output                                              atomicUnit_in_ready,
    input  iq_mem_atomic_in_t                           atomicUnit_in,

    input                [wb_width - 1 : 0]             rfwen,
    input  pint_regdest_t[wb_width - 1 : 0]             pwdest,

    // storeaddr read port
    output pint_regsrc_t                                storeaddrUnit_psrc,
    input  intreg_t                                     storeaddrUnit_psrc_rdata,

    // storedata read port
    output pint_regsrc_t                                storedataUnit_psrc,
    input  intreg_t                                     storedataUnit_psrc_rdata,

    // load read port
    output pint_regsrc_t                                loadUnit_psrc,
    input  intreg_t                                     loadUnit_psrc_rdata,

    // atomic read port
    output pint_regsrc_t[1 : 0]                         atomicUnit_psrc,
    input  intreg_t     [1 : 0]                         atomicUnit_psrc_rdata,

    // store report port
    output                                              StoreQueue_valid_o,
    input                                               StoreQueue_ready_o,
    output                                              StoreQueue_addr_misalign_o,
    output                                              StoreQueue_page_error_o,
    output rob_entry_ptr_t                              StoreQueue_rob_ptr_o,
    output [63:0]                                       StoreQueue_vaddr_o,

    // load report port
    output                                              loadUnit_valid_o,
    input                                               loadUnit_ready_o,
    output                                              loadUnit_addr_misalign_o,
    output                                              loadUnit_page_error_o,
    output                                              loadUnit_load_error_o,
    output                                              loadUnit_rfwen_o,
    output pint_regdest_t                               loadUnit_pwdest_o,
    output [63:0]                                       loadUnit_preg_wdata_o,
    output rob_entry_ptr_t                              loadUnit_rob_ptr_o,
    output [63:0]                                       loadUnit_vaddr_o,

    // atomic report port
    output                                              atomicUnit_valid_o,
    input                                               atomicUnit_ready_o,
    output                                              atomicUnit_ld_addr_misalign_o,
    output                                              atomicUnit_st_addr_misalign_o,
    output                                              atomicUnit_ld_page_error_o,
    output                                              atomicUnit_st_page_error_o,
    output                                              atomicUnit_load_error_o,
    output                                              atomicUnit_store_error_o,
    output rob_entry_ptr_t                              atomicUnit_rob_ptr_o,
    output [63:0]                                       atomic_vaddr_o,
    output                                              atomicUnit_rfwen_o,
    output pint_regdest_t                               atomicUnit_pwdest_o,
    output [63:0]                                       atomicUnit_preg_wdata_o,

    // LoadQueueRAW report port
    output                                              LoadQueue_flush_o,
    output rob_entry_ptr_t                              LoadQueue_rob_ptr_o,

    //interface with immu
    input                                               immu_miss_valid,
    output                                              immu_miss_ready,
    input  [63:0]                                       vaddr_i,
    output                                              pte_valid,
    output [127:0]                                      pte,
    output                                              pte_error,

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

// outports logic u_StoreQueue
store_optype_t              storeaddrUnit_op;
ls_rob_entry_ptr_t          storeaddrUnit_rob_ptr;
logic [63:0]                sq_load_data;
logic [7:0]                 sq_load_rstrb;
logic                       sq_wait;
logic                       storeaddrUnit_ready_o;
logic                       storedataUnit_ready_o;
logic                       StoreQueue2Uncache_valid;
logic [63:0]                StoreQueue_Uncache_waddr_o;
logic [63:0]                StoreQueue_Uncache_wdata_o;
logic [7:0]                 StoreQueue_Uncache_wstrb_o;
logic                       StoreQueue2StoreBuffer_valid;
logic [63:0]                StoreQueue_mem_waddr_o;
logic [63:0]                StoreQueue_mem_wdata_o;
logic [7:0]                 StoreQueue_mem_wstrb_o;

// outports logic u_storeaddrUnit
SQ_entry_ptr_t              storeaddrUnit_sq_ptr;
logic                       storeaddrUnit_mmu_valid;
logic [64:0]                storeaddrUnit_vaddr;
logic                       storeaddrUnit_paddr_ready;
logic                       storeaddrUnit_valid_o;
logic                       storeaddrUnit_addr_misalign_o;
logic                       storeaddrUnit_page_error_o;
logic                       storeaddrUnit_check_RAW_o;
logic [63:0]                storeaddrUnit_waddr_o;
SQ_entry_ptr_t              storeaddrUnit_sq_ptr_o;
logic [2:0]                 storeaddrUnit_wsize_o;
ls_rob_entry_ptr_t          storeaddrUnit_rob_ptr_o;

// outports logic u_storedataUnit
logic                       storedataUnit_valid_o;
SQ_entry_ptr_t              storedataUnit_sq_ptr_o;
logic [63:0]                storedataUnit_mem_wdata_o;

// outports logic u_store_dmmu
logic                       store_dmmu_miss_valid;
logic [63:0]                store_vaddr_d;
logic                       storeaddrUnit_mmu_ready;
logic                       storeaddrUnit_paddr_valid;
logic [63:0]                storeaddrUnit_paddr;
logic                       storeaddrUnit_paddr_error;

// outports logic u_StoreUncache
logic        	            StoreQueue_can_write_uc;

// outports logic u_sbuffer
logic                       StoreQueue_can_write_sb;
logic                       flush_i_ready_sb;
logic                       atomicUnit_invalid_sb_ready;
logic [63:0]                sb_load_data;
logic [7:0]                 sb_load_rstrb;
logic                       sbuffer_req_valid;
logic [63:0]                sbuffer_req_waddr;
logic [15:0]                sbuffer_req_wstrb;
logic [127:0]               sbuffer_req_wdata;
logic                       sbuffer_resp_ready;
logic [sb_line_bit-1:0]     sbuffer_req_index;

// outports logic u_loadUnit
logic                       loadUnit_mmu_valid  ;
logic                       loadUnit_mmu_ready  ;
logic  [64:0]               loadUnit_vaddr      ;
logic                       loadUnit_paddr_valid;
logic                       loadUnit_paddr_ready;
logic [63:0]                loadUnit_paddr      ;
logic                       loadUnit_paddr_error;
logic                       loadUnit_arvalid;
logic [2:0]                 loadUnit_arsize;
logic [63:0]                loadUnit_araddr;
ls_rob_entry_ptr_t          loadUnit_rob_ptr;
logic                       loadUnit_enq_lqRAW_o;
logic [63:0]                loadUnit_raddr_o;
logic [2:0]                 loadUnit_rsize_o;
ls_rob_entry_ptr_t          loadUnit_enq_rob_ptr_o;
logic                       loadUnit_rready;

// outports logic load_bypass_helper
logic                       loadUnit_arready;
logic [63:0]                dcache_load_paddr;
logic [63:0]                load_paddr2sq;
logic [7:0]                 load_rstrb2sq;
ls_rob_entry_ptr_t          load_rob_ptr;
logic [63:0]                load_paddr2sb;
logic [7:0]                 load_rstrb2sb;
logic                       loadUnit_rvalid;
logic [1:0]                 loadUnit_rresp;
logic [63:0]                loadUnit_rdata;
logic                       load_arvalid;
logic [2:0]                 load_arsize;
logic [63:0]                load_araddr;
logic                       load_rready;

// outports logic u_atomicUnit
logic                       stomic_running;
logic                       atomicUnit_invalid_sb_valid;
logic                       atomicUnit_mmu_valid  ;
logic                       atomicUnit_mmu_ready  ;
logic  [64:0]               atomicUnit_vaddr      ;
logic                       atomicUnit_paddr_valid;
logic                       atomicUnit_paddr_ready;
logic [63:0]                atomicUnit_paddr      ;
logic                       atomicUnit_paddr_error;
logic                       atomicUnit_arvalid;
logic [2:0]                 atomicUnit_arsize;
logic [63:0]                atomicUnit_araddr;
logic                       atomicUnit_rready;
logic                       atomicUnit_awvalid;
logic [2:0]                 atomicUnit_awsize;
logic [63:0]                atomicUnit_awaddr;
logic                       atomicUnit_wvalid;
logic [7:0]                 atomicUnit_wstrb;
logic [63:0]                atomicUnit_wdata;
logic                       atomicUnit_bready;

// outports logic u_load_dmmu
logic                       load_dmmu_miss_valid;
logic  [63:0]               load_vaddr_d        ;
logic                       load_mmu_valid      ;
logic                       load_mmu_ready      ;
logic  [64:0]               load_vaddr          ;
logic                       load_paddr_valid    ;
logic                       load_paddr_ready    ;
logic [63:0]                load_paddr          ;
logic                       load_paddr_error    ;

// outports logic u_l2tlb
logic                       mmu_arvalid;
logic [63:0]                mmu_araddr;
logic                       mmu_rready;
logic                       store_dmmu_miss_ready;
logic                       load_dmmu_miss_ready;

logic                       flush_i_valid_dcache;
// outports logic u_dcache_model
logic                       atomicUnit_arready;
logic                       atomicUnit_rvalid;
logic [1:0]                 atomicUnit_rresp;
logic [63:0]                atomicUnit_rdata;
logic                       atomicUnit_awready;
logic                       atomicUnit_wready;
logic                       atomicUnit_bvalid;
logic [1:0]                 atomicUnit_bresp;
logic                       sbuffer_req_ready;
logic                       sbuffer_resp_valid;
logic [sb_line_bit-1:0]     sbuffer_resp_index;
logic                       dcache_load_hit;
logic [63:0]                dcache_load_data;
logic                       load_arready;
logic                       load_rvalid;
logic [1:0]                 load_rresp;
logic [63:0]                load_rdata;
logic                       mmu_arready;
logic                       mmu_rvalid;
logic [1:0]                 mmu_rresp;
logic [63:0]                mmu_rdata;

StoreQueue u_StoreQueue(
	.clk                           	( clk                            ),
	.rst_n                         	( rst_n                          ),
	.redirect                      	( redirect                       ),
	.top_rob_ptr                   	( top_rob_ptr                    ),
    .deq_rob_ptr                    ( deq_rob_ptr                    ),
	.rename_fire                   	( rename_fire                    ),
	.sq_req                        	( sq_req                         ),
	.sq_req_entry                  	( sq_req_entry                   ),
	.sq_resp                       	( sq_resp                        ),
	.storeaddrUnit_sq_ptr          	( storeaddrUnit_sq_ptr           ),
	.storeaddrUnit_op              	( storeaddrUnit_op               ),
    .storeaddrUnit_rob_ptr          ( storeaddrUnit_rob_ptr          ),
	.load_paddr2sq     	            ( load_paddr2sq                  ),
	.load_rstrb2sq     	            ( load_rstrb2sq                  ),
	.load_rob_ptr     	            ( load_rob_ptr                   ),
	.sq_load_data      	            ( sq_load_data                   ),
	.sq_load_rstrb     	            ( sq_load_rstrb                  ),
	.sq_wait           	            ( sq_wait                        ),
	.storeaddrUnit_valid_o         	( storeaddrUnit_valid_o          ),
	.storeaddrUnit_ready_o         	( storeaddrUnit_ready_o          ),
	.storeaddrUnit_addr_misalign_o 	( storeaddrUnit_addr_misalign_o  ),
	.storeaddrUnit_page_error_o    	( storeaddrUnit_page_error_o     ),
	.storeaddrUnit_waddr_o         	( storeaddrUnit_waddr_o          ),
	.storeaddrUnit_sq_ptr_o        	( storeaddrUnit_sq_ptr_o         ),
	.storedataUnit_valid_o         	( storedataUnit_valid_o          ),
	.storedataUnit_ready_o         	( storedataUnit_ready_o          ),
	.storedataUnit_sq_ptr_o        	( storedataUnit_sq_ptr_o         ),
	.storedataUnit_mem_wdata_o     	( storedataUnit_mem_wdata_o      ),
	.StoreQueue_valid_o            	( StoreQueue_valid_o             ),
	.StoreQueue_ready_o            	( StoreQueue_ready_o             ),
	.StoreQueue_addr_misalign_o    	( StoreQueue_addr_misalign_o     ),
	.StoreQueue_page_error_o       	( StoreQueue_page_error_o        ),
	.StoreQueue_rob_ptr_o          	( StoreQueue_rob_ptr_o           ),
	.StoreQueue_vaddr_o            	( StoreQueue_vaddr_o             ),
	.StoreQueue_can_write_uc        ( StoreQueue_can_write_uc        ),
	.StoreQueue2Uncache_valid  	    ( StoreQueue2Uncache_valid       ),
	.StoreQueue_Uncache_waddr_o     ( StoreQueue_Uncache_waddr_o     ),
	.StoreQueue_Uncache_wdata_o     ( StoreQueue_Uncache_wdata_o     ),
	.StoreQueue_Uncache_wstrb_o     ( StoreQueue_Uncache_wstrb_o     ),
	.StoreQueue_can_write_sb        ( StoreQueue_can_write_sb        ),
	.StoreQueue2StoreBuffer_valid  	( StoreQueue2StoreBuffer_valid   ),
	.StoreQueue_mem_waddr_o        	( StoreQueue_mem_waddr_o         ),
	.StoreQueue_mem_wdata_o        	( StoreQueue_mem_wdata_o         ),
	.StoreQueue_mem_wstrb_o        	( StoreQueue_mem_wstrb_o         )
);

storeaddrUnit u_storeaddrUnit(
	.clk                           	( clk                            ),
	.rst_n                         	( rst_n                          ),
	.redirect                      	( redirect                       ),
	.storeaddrUnit_in_valid        	( storeaddrUnit_in_valid         ),
	.storeaddrUnit_in_ready        	( storeaddrUnit_in_ready         ),
	.storeaddrUnit_in              	( storeaddrUnit_in               ),
	.rfwen                         	( rfwen                          ),
	.pwdest                        	( pwdest                         ),
	.storeaddrUnit_psrc            	( storeaddrUnit_psrc             ),
	.storeaddrUnit_psrc_rdata      	( storeaddrUnit_psrc_rdata       ),
	.storeaddrUnit_sq_ptr          	( storeaddrUnit_sq_ptr           ),
	.storeaddrUnit_op              	( storeaddrUnit_op               ),
    .storeaddrUnit_rob_ptr          ( storeaddrUnit_rob_ptr          ),
	.storeaddrUnit_mmu_valid      	( storeaddrUnit_mmu_valid        ),
	.storeaddrUnit_mmu_ready      	( storeaddrUnit_mmu_ready        ),
	.storeaddrUnit_vaddr          	( storeaddrUnit_vaddr            ),
	.storeaddrUnit_paddr_valid     	( storeaddrUnit_paddr_valid      ),
	.storeaddrUnit_paddr_ready     	( storeaddrUnit_paddr_ready      ),
	.storeaddrUnit_paddr           	( storeaddrUnit_paddr            ),
	.storeaddrUnit_paddr_error     	( storeaddrUnit_paddr_error      ),
	.storeaddrUnit_valid_o         	( storeaddrUnit_valid_o          ),
	.storeaddrUnit_ready_o         	( storeaddrUnit_ready_o          ),
	.storeaddrUnit_addr_misalign_o 	( storeaddrUnit_addr_misalign_o  ),
	.storeaddrUnit_page_error_o    	( storeaddrUnit_page_error_o     ),
	.storeaddrUnit_check_RAW_o     	( storeaddrUnit_check_RAW_o      ),
	.storeaddrUnit_waddr_o         	( storeaddrUnit_waddr_o          ),
	.storeaddrUnit_sq_ptr_o        	( storeaddrUnit_sq_ptr_o         ),
    .storeaddrUnit_wsize_o          ( storeaddrUnit_wsize_o  ),
    .storeaddrUnit_rob_ptr_o        ( storeaddrUnit_rob_ptr_o)
);

storedataUnit u_storedataUnit(
	.clk                       	( clk                        ),
	.rst_n                     	( rst_n                      ),
	.redirect                  	( redirect                   ),
	.storedataUnit_in_valid    	( storedataUnit_in_valid     ),
	.storedataUnit_in_ready    	( storedataUnit_in_ready     ),
	.storedataUnit_in          	( storedataUnit_in           ),
	.rfwen                     	( rfwen                      ),
	.pwdest                    	( pwdest                     ),
	.storedataUnit_psrc        	( storedataUnit_psrc         ),
	.storedataUnit_psrc_rdata  	( storedataUnit_psrc_rdata   ),
	.storedataUnit_valid_o     	( storedataUnit_valid_o      ),
	.storedataUnit_ready_o     	( storedataUnit_ready_o      ),
	.storedataUnit_sq_ptr_o    	( storedataUnit_sq_ptr_o     ),
	.storedataUnit_mem_wdata_o 	( storedataUnit_mem_wdata_o  )
);

dmmu u_store_dmmu(
	.clk                 	( clk                               ),
	.rst_n               	( rst_n                             ),
	.current_priv_status 	( current_priv_status               ),
	.MXR                 	( MXR                               ),
	.SUM                 	( SUM                               ),
	.MPRV                	( MPRV                              ),
	.MPP                 	( MPP                               ),
	.satp_mode           	( satp_mode                         ),
	.satp_asid           	( satp_asid                         ),
	.flush_flag          	( redirect                          ),
	.sflush_vma_valid    	( sflush_vma_valid                  ),
	.dmmu_miss_valid     	( store_dmmu_miss_valid             ),
	.dmmu_miss_ready     	( store_dmmu_miss_ready             ),
	.vaddr_d             	( store_vaddr_d                     ),
	.pte_valid           	( pte_valid                         ),
	.pte                 	( pte                               ),
	.pte_error           	( pte_error                         ),
	.mmu_fifo_valid      	( storeaddrUnit_mmu_valid           ),
	.mmu_fifo_ready      	( storeaddrUnit_mmu_ready           ),
	.vaddr               	( storeaddrUnit_vaddr               ),
	.paddr_valid         	( storeaddrUnit_paddr_valid         ),
	.paddr_ready         	( storeaddrUnit_paddr_ready         ),
	.paddr               	( storeaddrUnit_paddr               ),
	.paddr_error         	( storeaddrUnit_paddr_error         )
);

StoreUncache u_StoreUncache(
	.clk                        	( clk                         ),
	.rst_n                      	( rst_n                       ),
	.StoreQueue_can_write_uc    	( StoreQueue_can_write_uc     ),
	.StoreQueue2Uncache_valid   	( StoreQueue2Uncache_valid    ),
	.StoreQueue_Uncache_waddr_o 	( StoreQueue_Uncache_waddr_o  ),
	.StoreQueue_Uncache_wdata_o 	( StoreQueue_Uncache_wdata_o  ),
	.StoreQueue_Uncache_wstrb_o 	( StoreQueue_Uncache_wstrb_o  ),
	.Uncache_awvalid            	( Uncache_awvalid             ),
	.Uncache_awready            	( Uncache_awready             ),
	.Uncache_awsize             	( Uncache_awsize              ),
	.Uncache_awaddr             	( Uncache_awaddr              ),
	.Uncache_wvalid             	( Uncache_wvalid              ),
	.Uncache_wready             	( Uncache_wready              ),
	.Uncache_wstrb              	( Uncache_wstrb               ),
	.Uncache_wdata              	( Uncache_wdata               ),
	.Uncache_bvalid             	( Uncache_bvalid              ),
	.Uncache_bready             	( Uncache_bready              ),
	.Uncache_bresp              	( Uncache_bresp               )
);

sbuffer u_sbuffer(
	.clk                            ( clk                           ),
	.rst_n                          ( rst_n                         ),
	.StoreQueue_can_write_sb        ( StoreQueue_can_write_sb       ),
	.StoreQueue2StoreBuffer_valid   ( StoreQueue2StoreBuffer_valid  ),
	.StoreQueue_mem_waddr_o         ( StoreQueue_mem_waddr_o        ),
	.StoreQueue_mem_wdata_o         ( StoreQueue_mem_wdata_o        ),
	.StoreQueue_mem_wstrb_o         ( StoreQueue_mem_wstrb_o        ),
	.load_paddr2sb     	            ( load_paddr2sb                 ),
	.load_rstrb2sb     	            ( load_rstrb2sb                 ),
	.sb_load_data      	            ( sb_load_data                  ),
	.sb_load_rstrb     	            ( sb_load_rstrb                 ),
	.flush_i_valid                  ( flush_i_valid                 ),
	.flush_i_ready_sb               ( flush_i_ready_sb              ),
	.atomicUnit_invalid_sb_valid    ( atomicUnit_invalid_sb_valid   ),
	.atomicUnit_invalid_sb_ready    ( atomicUnit_invalid_sb_ready   ),
	.sbuffer_req_valid              ( sbuffer_req_valid             ),
	.sbuffer_req_ready              ( sbuffer_req_ready             ),
	.sbuffer_req_waddr              ( sbuffer_req_waddr             ),
	.sbuffer_req_wstrb              ( sbuffer_req_wstrb             ),
	.sbuffer_req_wdata              ( sbuffer_req_wdata             ),
	.sbuffer_req_index              ( sbuffer_req_index             ),
	.sbuffer_resp_valid             ( sbuffer_resp_valid            ),
	.sbuffer_resp_ready             ( sbuffer_resp_ready            ),
	.sbuffer_resp_index             ( sbuffer_resp_index            )
);

loadUnit u_loadUnit(
	.clk                        ( clk                       ),
	.rst_n                      ( rst_n                     ),
	.redirect                   ( redirect                  ),
	.loadUnit_in_valid          ( loadUnit_in_valid         ),
	.loadUnit_in_ready          ( loadUnit_in_ready         ),
	.loadUnit_in                ( loadUnit_in               ),
	.rfwen                      ( rfwen                     ),
	.pwdest                     ( pwdest                    ),
	.loadUnit_psrc              ( loadUnit_psrc             ),
	.loadUnit_psrc_rdata        ( loadUnit_psrc_rdata       ),
	.loadUnit_mmu_valid         ( loadUnit_mmu_valid        ),
	.loadUnit_mmu_ready         ( loadUnit_mmu_ready        ),
	.loadUnit_vaddr             ( loadUnit_vaddr            ),
	.loadUnit_paddr_valid       ( loadUnit_paddr_valid      ),
	.loadUnit_paddr_ready       ( loadUnit_paddr_ready      ),
	.loadUnit_paddr             ( loadUnit_paddr            ),
	.loadUnit_paddr_error       ( loadUnit_paddr_error      ),
	.loadUnit_arvalid           ( loadUnit_arvalid          ),
	.loadUnit_arready           ( loadUnit_arready          ),
	.loadUnit_arsize            ( loadUnit_arsize           ),
	.loadUnit_araddr            ( loadUnit_araddr           ),
	.loadUnit_rob_ptr           ( loadUnit_rob_ptr          ),
	.loadUnit_enq_lqRAW_o       ( loadUnit_enq_lqRAW_o      ),
	.loadUnit_raddr_o           ( loadUnit_raddr_o          ),
	.loadUnit_rsize_o           ( loadUnit_rsize_o          ),
	.loadUnit_enq_rob_ptr_o     ( loadUnit_enq_rob_ptr_o    ),
	.loadUnit_rvalid            ( loadUnit_rvalid           ),
	.loadUnit_rready            ( loadUnit_rready           ),
	.loadUnit_rresp             ( loadUnit_rresp            ),
	.loadUnit_rdata             ( loadUnit_rdata            ),
	.loadUnit_valid_o           ( loadUnit_valid_o          ),
	.loadUnit_ready_o           ( loadUnit_ready_o          ),
	.loadUnit_addr_misalign_o   ( loadUnit_addr_misalign_o  ),
	.loadUnit_page_error_o      ( loadUnit_page_error_o     ),
	.loadUnit_load_error_o      ( loadUnit_load_error_o     ),
	.loadUnit_rfwen_o           ( loadUnit_rfwen_o          ),
	.loadUnit_pwdest_o          ( loadUnit_pwdest_o         ),
	.loadUnit_preg_wdata_o      ( loadUnit_preg_wdata_o     ),
	.loadUnit_rob_ptr_o         ( loadUnit_rob_ptr_o        ),
	.loadUnit_vaddr_o           ( loadUnit_vaddr_o          )
);

load_bypass_helper u_load_bypass_helper(
	.clk               	( clk                ),
	.rst_n             	( rst_n              ),
	.redirect          	( redirect           ),
	.loadUnit_arvalid  	( loadUnit_arvalid   ),
	.loadUnit_arready  	( loadUnit_arready   ),
	.loadUnit_arsize   	( loadUnit_arsize    ),
	.loadUnit_araddr   	( loadUnit_araddr    ),
	.loadUnit_rob_ptr   ( loadUnit_rob_ptr   ),
	.dcache_load_paddr 	( dcache_load_paddr  ),
	.dcache_load_hit   	( dcache_load_hit    ),
	.dcache_load_data  	( dcache_load_data   ),
	.load_paddr2sq     	( load_paddr2sq      ),
	.load_rstrb2sq     	( load_rstrb2sq      ),
	.load_rob_ptr     	( load_rob_ptr       ),
	.sq_load_data      	( sq_load_data       ),
	.sq_load_rstrb     	( sq_load_rstrb      ),
	.sq_wait           	( sq_wait            ),
	.load_paddr2sb     	( load_paddr2sb      ),
	.load_rstrb2sb     	( load_rstrb2sb      ),
	.sb_load_data      	( sb_load_data       ),
	.sb_load_rstrb     	( sb_load_rstrb      ),
	.loadUnit_rvalid   	( loadUnit_rvalid    ),
	.loadUnit_rready   	( loadUnit_rready    ),
	.loadUnit_rresp    	( loadUnit_rresp     ),
	.loadUnit_rdata    	( loadUnit_rdata     ),
	.load_arvalid      	( load_arvalid       ),
	.load_arready      	( load_arready       ),
	.load_arsize       	( load_arsize        ),
	.load_araddr       	( load_araddr        ),
	.load_rvalid       	( load_rvalid        ),
	.load_rready       	( load_rready        ),
	.load_rresp        	( load_rresp         ),
	.load_rdata        	( load_rdata         )
);

LoadQueueRAW u_LoadQueueRAW(
	.clk                        ( clk                        ),
	.rst_n                      ( rst_n                      ),
	.redirect                   ( redirect                   ),
	.deq_rob_ptr                ( deq_rob_ptr                ),
	.loadUnit_enq_lqRAW_o       ( loadUnit_enq_lqRAW_o       ),
	.loadUnit_raddr_o           ( loadUnit_raddr_o           ),
	.loadUnit_rsize_o           ( loadUnit_rsize_o           ),
	.loadUnit_enq_rob_ptr_o     ( loadUnit_enq_rob_ptr_o     ),
	.storeaddrUnit_check_RAW_o  ( storeaddrUnit_check_RAW_o  ),
	.storeaddrUnit_waddr_o      ( storeaddrUnit_waddr_o      ),
	.storeaddrUnit_wsize_o      ( storeaddrUnit_wsize_o      ),
	.storeaddrUnit_rob_ptr_o    ( storeaddrUnit_rob_ptr_o    ),
	.LoadQueue_flush_o          ( LoadQueue_flush_o          ),
	.LoadQueue_rob_ptr_o        ( LoadQueue_rob_ptr_o        )
);

atomicUnit u_atomicUnit(
	.clk                           	( clk                            ),
	.rst_n                         	( rst_n                          ),
	.redirect                      	( redirect                       ),
	.top_rob_ptr                   	( top_rob_ptr                    ),
	.atomicUnit_in_valid           	( atomicUnit_in_valid            ),
	.atomicUnit_in_ready           	( atomicUnit_in_ready            ),
	.atomicUnit_in                 	( atomicUnit_in                  ),
	.stomic_running                	( stomic_running                 ),
	.atomicUnit_psrc               	( atomicUnit_psrc                ),
	.atomicUnit_psrc_rdata         	( atomicUnit_psrc_rdata          ),
	.atomicUnit_invalid_sb_valid   	( atomicUnit_invalid_sb_valid    ),
	.atomicUnit_invalid_sb_ready   	( atomicUnit_invalid_sb_ready    ),
	.atomicUnit_mmu_valid         	( atomicUnit_mmu_valid           ),
	.atomicUnit_mmu_ready         	( atomicUnit_mmu_ready           ),
	.atomicUnit_vaddr             	( atomicUnit_vaddr               ),
	.atomicUnit_paddr_valid        	( atomicUnit_paddr_valid         ),
	.atomicUnit_paddr_ready        	( atomicUnit_paddr_ready         ),
	.atomicUnit_paddr              	( atomicUnit_paddr               ),
	.atomicUnit_paddr_error        	( atomicUnit_paddr_error         ),
	.atomicUnit_arvalid            	( atomicUnit_arvalid             ),
	.atomicUnit_arready            	( atomicUnit_arready             ),
	.atomicUnit_arsize             	( atomicUnit_arsize              ),
	.atomicUnit_araddr             	( atomicUnit_araddr              ),
	.atomicUnit_rvalid             	( atomicUnit_rvalid              ),
	.atomicUnit_rready             	( atomicUnit_rready              ),
	.atomicUnit_rresp              	( atomicUnit_rresp               ),
	.atomicUnit_rdata              	( atomicUnit_rdata               ),
	.atomicUnit_awvalid            	( atomicUnit_awvalid             ),
	.atomicUnit_awready            	( atomicUnit_awready             ),
	.atomicUnit_awsize             	( atomicUnit_awsize              ),
	.atomicUnit_awaddr             	( atomicUnit_awaddr              ),
	.atomicUnit_wvalid             	( atomicUnit_wvalid              ),
	.atomicUnit_wready             	( atomicUnit_wready              ),
	.atomicUnit_wstrb              	( atomicUnit_wstrb               ),
	.atomicUnit_wdata              	( atomicUnit_wdata               ),
	.atomicUnit_bvalid             	( atomicUnit_bvalid              ),
	.atomicUnit_bready             	( atomicUnit_bready              ),
	.atomicUnit_bresp              	( atomicUnit_bresp               ),
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
	.atomicUnit_preg_wdata_o       	( atomicUnit_preg_wdata_o        )
);

dmmu u_load_dmmu(
	.clk                 	( clk                               ),
	.rst_n               	( rst_n                             ),
	.current_priv_status 	( current_priv_status               ),
	.MXR                 	( MXR                               ),
	.SUM                 	( SUM                               ),
	.MPRV                	( MPRV                              ),
	.MPP                 	( MPP                               ),
	.satp_mode           	( satp_mode                         ),
	.satp_asid           	( satp_asid                         ),
	.flush_flag          	( redirect                          ),
	.sflush_vma_valid    	( sflush_vma_valid                  ),
	.dmmu_miss_valid     	( load_dmmu_miss_valid              ),
	.dmmu_miss_ready     	( load_dmmu_miss_ready              ),
	.vaddr_d             	( load_vaddr_d                      ),
	.pte_valid           	( pte_valid                         ),
	.pte                 	( pte                               ),
	.pte_error           	( pte_error                         ),
	.mmu_fifo_valid      	( load_mmu_valid                    ),
	.mmu_fifo_ready      	( load_mmu_ready                    ),
	.vaddr               	( load_vaddr                        ),
	.paddr_valid         	( load_paddr_valid                  ),
	.paddr_ready         	( load_paddr_ready                  ),
	.paddr               	( load_paddr                        ),
	.paddr_error         	( load_paddr_error                  )
);

assign loadUnit_mmu_ready       = load_mmu_ready  ;
assign loadUnit_paddr_valid     = load_paddr_valid;
assign loadUnit_paddr           = load_paddr      ;
assign loadUnit_paddr_error     = load_paddr_error;

assign atomicUnit_mmu_ready     = load_mmu_ready  ;
assign atomicUnit_paddr_valid   = load_paddr_valid;
assign atomicUnit_paddr         = load_paddr      ;
assign atomicUnit_paddr_error   = load_paddr_error;

assign load_mmu_valid   = (stomic_running) ? atomicUnit_mmu_valid   : loadUnit_mmu_valid  ;
assign load_vaddr       = (stomic_running) ? atomicUnit_vaddr       : loadUnit_vaddr      ;
assign load_paddr_ready = (stomic_running) ? atomicUnit_paddr_ready : loadUnit_paddr_ready;

l2tlb #(
	.MMU_WAY   	( MMU_WAY    ),
	.MMU_GROUP 	( MMU_GROUP  ))
u_l2tlb(
	.clk                   	( clk                    ),
	.rst_n                 	( rst_n                  ),
	.satp_asid             	( satp_asid              ),
	.satp_ppn              	( satp_ppn               ),
	.flush_flag            	( redirect               ),
	.sflush_vma_valid      	( sflush_vma_valid       ),
	.mmu_arready           	( mmu_arready            ),
	.mmu_arvalid           	( mmu_arvalid            ),
	.mmu_araddr            	( mmu_araddr             ),
	.mmu_rready            	( mmu_rready             ),
	.mmu_rvalid            	( mmu_rvalid             ),
	.mmu_rresp             	( mmu_rresp              ),
	.mmu_rdata             	( mmu_rdata              ),
	.immu_miss_valid       	( immu_miss_valid        ),
	.immu_miss_ready       	( immu_miss_ready        ),
	.vaddr_i               	( vaddr_i                ),
	.store_dmmu_miss_valid 	( store_dmmu_miss_valid  ),
	.store_dmmu_miss_ready 	( store_dmmu_miss_ready  ),
	.store_vaddr_d         	( store_vaddr_d          ),
	.load_dmmu_miss_valid  	( load_dmmu_miss_valid   ),
	.load_dmmu_miss_ready  	( load_dmmu_miss_ready   ),
	.load_vaddr_d          	( load_vaddr_d           ),
	.pte_valid             	( pte_valid              ),
	.pte                   	( pte                    ),
	.pte_error             	( pte_error              )
);

dcache #(
    .AXI_ID_SB     ( AXI_ID_SB   ),
    .AXI_ADDR_W    ( AXI_ADDR_W  ),
    .AXI_ID_W      ( AXI_ID_W    ),
    .AXI_DATA_W    ( AXI_DATA_W  ),
    .DCACHE_WAY    ( DCACHE_WAY  ),
    .DCACHE_GROUP  ( DCACHE_GROUP),
    .PMEM_START    ( PMEM_START  ),
    .PMEM_END      ( PMEM_END    )
)u_dcache_model(
	.clk                  	( clk                   ),
	.rst_n                	( rst_n                 ),
	.redirect             	( redirect              ),
	.flush_i_valid_dcache 	( flush_i_valid_dcache  ),
	.flush_i_ready        	( flush_i_ready         ),
	.atomicUnit_arvalid   	( atomicUnit_arvalid    ),
	.atomicUnit_arready   	( atomicUnit_arready    ),
	.atomicUnit_arsize    	( atomicUnit_arsize     ),
	.atomicUnit_araddr    	( atomicUnit_araddr     ),
	.atomicUnit_rvalid    	( atomicUnit_rvalid     ),
	.atomicUnit_rready    	( atomicUnit_rready     ),
	.atomicUnit_rresp     	( atomicUnit_rresp      ),
	.atomicUnit_rdata     	( atomicUnit_rdata      ),
	.atomicUnit_awvalid   	( atomicUnit_awvalid    ),
	.atomicUnit_awready   	( atomicUnit_awready    ),
	.atomicUnit_awsize    	( atomicUnit_awsize     ),
	.atomicUnit_awaddr    	( atomicUnit_awaddr     ),
	.atomicUnit_wvalid    	( atomicUnit_wvalid     ),
	.atomicUnit_wready    	( atomicUnit_wready     ),
	.atomicUnit_wstrb     	( atomicUnit_wstrb      ),
	.atomicUnit_wdata     	( atomicUnit_wdata      ),
	.atomicUnit_bvalid    	( atomicUnit_bvalid     ),
	.atomicUnit_bready    	( atomicUnit_bready     ),
	.atomicUnit_bresp     	( atomicUnit_bresp      ),
	.sbuffer_req_valid    	( sbuffer_req_valid     ),
	.sbuffer_req_ready    	( sbuffer_req_ready     ),
	.sbuffer_req_waddr    	( sbuffer_req_waddr     ),
	.sbuffer_req_wstrb    	( sbuffer_req_wstrb     ),
	.sbuffer_req_wdata    	( sbuffer_req_wdata     ),
	.sbuffer_req_index    	( sbuffer_req_index     ),
	.sbuffer_resp_valid   	( sbuffer_resp_valid    ),
	.sbuffer_resp_ready   	( sbuffer_resp_ready    ),
	.sbuffer_resp_index   	( sbuffer_resp_index    ),
	.loadUnit_mmu_valid   	( loadUnit_mmu_valid    ),
	.loadUnit_mmu_ready   	( loadUnit_mmu_ready    ),
	.loadUnit_vaddr       	( loadUnit_vaddr        ),
	.dcache_load_paddr    	( dcache_load_paddr     ),
	.dcache_load_hit      	( dcache_load_hit       ),
	.dcache_load_data     	( dcache_load_data      ),
	.load_arvalid         	( load_arvalid          ),
	.load_arready         	( load_arready          ),
	.load_arsize          	( load_arsize           ),
	.load_araddr          	( load_araddr           ),
	.load_rvalid          	( load_rvalid           ),
	.load_rready          	( load_rready           ),
	.load_rresp           	( load_rresp            ),
	.load_rdata           	( load_rdata            ),
	.mmu_arvalid          	( mmu_arvalid           ),
	.mmu_arready          	( mmu_arready           ),
	.mmu_araddr           	( mmu_araddr            ),
	.mmu_rvalid           	( mmu_rvalid            ),
	.mmu_rready           	( mmu_rready            ),
	.mmu_rresp            	( mmu_rresp             ),
	.mmu_rdata            	( mmu_rdata             ),
    .dcache_arvalid         ( dcache_arvalid        ),
    .dcache_arready         ( dcache_arready        ),
    .dcache_araddr          ( dcache_araddr         ),
    .dcache_arlen           ( dcache_arlen          ),
    .dcache_arsize          ( dcache_arsize         ),
    .dcache_arburst         ( dcache_arburst        ),
    .dcache_arlock          ( dcache_arlock         ),
    .dcache_arid            ( dcache_arid           ),
    .dcache_rvalid          ( dcache_rvalid         ),
    .dcache_rready          ( dcache_rready         ),
    .dcache_rid             ( dcache_rid            ),
    .dcache_rresp           ( dcache_rresp          ),
    .dcache_rdata           ( dcache_rdata          ),
    .dcache_rlast           ( dcache_rlast          ),
    .dcache_awvalid         ( dcache_awvalid        ),
    .dcache_awready         ( dcache_awready        ),
    .dcache_awaddr          ( dcache_awaddr         ),
    .dcache_awlen           ( dcache_awlen          ),
    .dcache_awsize          ( dcache_awsize         ),
    .dcache_awburst         ( dcache_awburst        ),
    .dcache_awlock          ( dcache_awlock         ),
    .dcache_awid            ( dcache_awid           ),
    .dcache_wvalid          ( dcache_wvalid         ),
    .dcache_wready          ( dcache_wready         ),
    .dcache_wlast           ( dcache_wlast          ),
    .dcache_wdata           ( dcache_wdata          ),
    .dcache_wstrb           ( dcache_wstrb          ),
    .dcache_bvalid          ( dcache_bvalid         ),
    .dcache_bready          ( dcache_bready         ),
    .dcache_bid             ( dcache_bid            ),
    .dcache_bresp           ( dcache_bresp          )
);

assign flush_i_valid_dcache = (flush_i_valid & flush_i_ready_sb);


endmodule //mem_top
