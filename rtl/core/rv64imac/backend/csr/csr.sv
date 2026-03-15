module csr
import core_setting_pkg::*;
#(parameter cfg_mhartid = 0) (
    input                           clk,
    input                           rst_n,
    input                           stip,
    input                           seip,
    input                           ssip,
    input                           mtip,
    input                           meip,
    input                           msip,
    input                           halt_req,
    output  [1:0]                   current_priv_status,
//interface with mmu
    output                          MXR,
    output                          SUM,
    output                          MPRV,
    output [1:0]                    MPP,
    output [3:0]                    satp_mode,
    output [15:0]                   satp_asid,
    output [43:0]                   satp_ppn,
//interface with gen_redirect
    output                          csr_jump_flag,
    output [63:0]                   csr_jump_addr,
//interface with idu
    input  [11:0]                   csr_index,
    output [63:0]                   csr_rdata,
    output                          TSR,
    output                          TW,
    output                          TVM,
    output                          debug_mode,
//interface with csr exu
    output [63:0]                   mepc_o,
    output [63:0]                   sepc_o,
    output [63:0]                   dpc_o,
// interface with rob 
    // common
    input                           rob_can_interrupt,
    input  [commit_width - 1 : 0]   rob_commit_instret,
    input                           rob_commit_valid,
    input  [63:0]                   rob_commit_pc,
    input  [63:0]                   rob_commit_next_pc,
    // trap
    output                          interrupt_happen,
    input                           rob_trap_valid,
    input  [63:0]                   rob_trap_cause,
    input  [63:0]                   rob_trap_tval,
//interface with rename
    input  [decode_width - 1 : 0]   decode_out_valid,
    input                           rename_ready,
//interface with exu
    input                           alu_csr_fence_exu_valid_o,
    input                           alu_csr_fence_exu_csrwen_o,
    input  [11:0]                   alu_csr_fence_exu_csr_index_o,
    input  [63:0]                   alu_csr_fence_exu_csr_wdata_o,
    input                           alu_csr_fence_exu_mret_o,
    input                           alu_csr_fence_exu_sret_o,
    input                           alu_csr_fence_exu_dret_o
);

//trap flag
wire            trap_m_mode_valid;
wire            trap_s_mode_valid;
wire            trap_debug_mode_valid;
wire [63:0] 	epc;
wire [2:0]      debug_cause;
wire [63:0] 	cause;
wire [63:0] 	tval;

//interrupt
wire        	interrupt_m_flag;
wire        	interrupt_s_flag;
wire        	interrupt_debug_flag;
wire [63:0] 	interrupt_cause;
wire [2:0]      interrupt_debug_cause;

wire [63:0]     csr_wdata;
reg  [63:0]     csr_rdata_reg;

// ro csr outports wire
wire [63:0] 	mvendorid;
wire [63:0] 	marchid;
wire [63:0] 	mimpid;
wire [63:0] 	mhartid;
wire [63:0] 	mconfigptr;

//misa
wire [63:0] 	misa;

//?mstatus & sstatus
wire [63:0]     mstatus;
wire [63:0]     sstatus;
wire            csr_mstatus_wen;
wire            csr_sstatus_wen;
wire            mstatus_TSR;
wire            mstatus_TW;
wire            mstatus_TVM;
wire            mstatus_MXR;
wire            mstatus_SUM;
wire            mstatus_MPRV;
wire [1:0]      mstatus_MPP;
wire            mstatus_MIE;
wire            mstatus_SIE;

//?mtvec
wire [63:0] 	mtvec;
wire            csr_mtvec_wen;

//?medeleg
wire [63:0] 	medeleg;
wire            csr_medeleg_wen;

//mideleg
wire [63:0] 	mideleg;
wire            csr_mideleg_wen;

//?mip & sip
wire [63:0] 	mip;
wire [63:0] 	sip;
wire            csr_mip_wen;
wire            csr_sip_wen;

//?mie & sie
wire [63:0] 	mie;
wire [63:0] 	sie;
wire            csr_mie_wen;
wire            csr_sie_wen;

//?Performance_Monitor
wire [63:0]     Performance_Monitor[2:31];
wire            csr_MPerformance_Monitor_wen[2:31];
wire            MPerformance_Monitor_inc[2:31];
genvar          csr_MPerformance_Monitor_gen_index;
genvar          csr_MPerformance_Monitor_inc_index;

wire [63:0]     minstret;
wire            csr_minstret_wen;

//?mhpmevent
wire [63:0]     mhpmevent[3:31];
wire            csr_mhpmevent_wen[3:31];
genvar          csr_mhpmevent_gen_index;
genvar          csr_mhpmevent_inc_index;

//?mcounteren
wire [63:0] 	mcounteren;

//?mcountinhibit
wire [63:0]     mcountinhibit;
wire            csr_mcountinhibit_wen;

//?mscratch
wire [63:0]     mscratch;
wire            csr_mscratch_wen;

//?mepc
wire [63:0] 	mepc;
wire            csr_mepc_wen;

//?mcause
wire [63:0] 	mcause;
wire            csr_mcause_wen;

//?mtval
wire [63:0] 	mtval;
wire            csr_mtval_wen;

//?menvcfg
wire [63:0] 	menvcfg;

//?mseccfg
wire [63:0] 	mseccfg;

//?stvec
wire [63:0] 	stvec;
wire            csr_stvec_wen;

//?scounteren
wire [63:0] 	scounteren;

//?sscratch
wire [63:0] 	sscratch;
wire            csr_sscratch_wen;

//?sepc
wire [63:0] 	sepc;
wire            csr_sepc_wen;

//?scause
wire [63:0] 	scause;
wire            csr_scause_wen;

//?stval
wire [63:0] 	stval;
wire            csr_stval_wen;

//?senvcfg
wire [63:0] 	senvcfg;

//?satp
wire [63:0] 	satp;
wire            csr_satp_wen;

//?dcsr
wire [63:0]     dcsr;
wire            csr_dcsr_wen;
wire            dcsr_ebreakm;
wire            dcsr_ebreaks;
wire            dcsr_ebreaku;
wire            dcsr_step;
wire [1:0]      dcsr_prv;

//?dpc
wire [63:0]     dpc;
wire            csr_dpc_wen;

//?dscratch0
wire [63:0] 	dscratch0;
wire            csr_dscratch0_wen;

//?dscratch1
wire [63:0] 	dscratch1;
wire            csr_dscratch1_wen;

//!M mode
//RO

csr_mvendorid u_csr_mvendorid(
    .mvendorid 	( mvendorid  )
);

csr_marchid u_csr_marchid(
    .marchid 	( marchid  )
);

csr_mimpid u_csr_mimpid(
    .mimpid 	( mimpid  )
);

csr_mhartid #(
    .MHARTID 	( cfg_mhartid  )
)u_csr_mhartid
(
    .mhartid 	( mhartid  )
);

csr_mconfigptr u_csr_mconfigptr(
    .mconfigptr 	( mconfigptr  )
);

//RW
csr_misa u_csr_misa(
    .misa 	( misa  )
);

csr_mstatus u_csr_mstatus(
    .clk                  	    ( clk                       ),
    .rst_n                	    ( rst_n                     ),
    .csr_mstatus_wen      	    ( csr_mstatus_wen           ),
    .csr_sstatus_wen      	    ( csr_sstatus_wen           ),
    .trap_m_mode_valid    	    ( trap_m_mode_valid         ),
    .trap_s_mode_valid    	    ( trap_s_mode_valid         ),
    .trap_debug_mode_valid      ( trap_debug_mode_valid     ),
    .alu_csr_fence_exu_valid_o  ( alu_csr_fence_exu_valid_o ),
    .alu_csr_fence_exu_mret_o 	( alu_csr_fence_exu_mret_o  ),
    .alu_csr_fence_exu_sret_o 	( alu_csr_fence_exu_sret_o  ),
    .alu_csr_fence_exu_dret_o   ( alu_csr_fence_exu_dret_o  ),
    .dcsr_prv                   ( dcsr_prv                  ),
    .current_priv_status  	    ( current_priv_status       ),
    .csr_wdata            	    ( csr_wdata                 ),
    .mstatus_TSR          	    ( mstatus_TSR               ),
    .mstatus_TW           	    ( mstatus_TW                ),
    .mstatus_TVM          	    ( mstatus_TVM               ),
    .mstatus_MXR          	    ( mstatus_MXR               ),
    .mstatus_SUM          	    ( mstatus_SUM               ),
    .mstatus_MPRV         	    ( mstatus_MPRV              ),
    .mstatus_MPP          	    ( mstatus_MPP               ),
    .mstatus_MIE          	    ( mstatus_MIE               ),
    .mstatus_SIE          	    ( mstatus_SIE               ),
    .mstatus              	    ( mstatus                   ),
    .sstatus                    ( sstatus                   )
);

csr_mtvec #(RST_PC)u_csr_mtvec(
    .clk           	( clk            ),
    .rst_n         	( rst_n          ),
    .csr_mtvec_wen 	( csr_mtvec_wen  ),
    .csr_wdata     	( csr_wdata      ),
    .mtvec         	( mtvec          )
);

csr_medeleg u_csr_medeleg(
    .clk             	( clk              ),
    .rst_n           	( rst_n            ),
    .csr_medeleg_wen 	( csr_medeleg_wen  ),
    .csr_wdata       	( csr_wdata        ),
    .medeleg         	( medeleg          )
);

csr_mideleg u_csr_mideleg(
    .clk             	( clk              ),
    .rst_n           	( rst_n            ),
    .csr_mideleg_wen 	( csr_mideleg_wen  ),
    .csr_wdata       	( csr_wdata        ),
    .mideleg         	( mideleg          )
);

csr_mip u_csr_mip(
    .clk         	( clk          ),
    .rst_n       	( rst_n        ),
    .stip        	( stip         ),
    .seip        	( seip         ),
    .ssip        	( ssip         ),
    .mtip        	( mtip         ),
    .meip        	( meip         ),
    .msip        	( msip         ),
    .csr_mip_wen 	( csr_mip_wen  ),
    .csr_sip_wen 	( csr_sip_wen  ),
    .csr_wdata   	( csr_wdata    ),
    .mideleg        ( mideleg      ),
    .mip         	( mip          ),
    .sip         	( sip          )
);

csr_mie u_csr_mie(
    .clk         	( clk          ),
    .rst_n       	( rst_n        ),
    .csr_mie_wen 	( csr_mie_wen  ),
    .csr_sie_wen 	( csr_sie_wen  ),
    .csr_wdata   	( csr_wdata    ),
    .mideleg        ( mideleg      ),
    .mie         	( mie          ),
    .sie         	( sie          )
);

generate 
for(csr_MPerformance_Monitor_gen_index = 2 ; csr_MPerformance_Monitor_gen_index < 32; csr_MPerformance_Monitor_gen_index = csr_MPerformance_Monitor_gen_index + 1) begin : csr_Performance_Monitor

if(csr_MPerformance_Monitor_gen_index == 2)begin: U_gen_monitor_0
    csr_MPerformance_Monitor u_csr_MPerformance_Monitor(
        .clk                          	( clk                                                               ),
        .csr_MPerformance_Monitor_wen 	( csr_MPerformance_Monitor_wen[csr_MPerformance_Monitor_gen_index]  ),
        .MPerformance_Monitor_hibit   	( mcountinhibit[0]                                                  ),
        .MPerformance_Monitor_inc     	( MPerformance_Monitor_inc[csr_MPerformance_Monitor_gen_index]      ),
        .csr_wdata                    	( csr_wdata                                                         ),
        .MPerformance_Monitor         	( Performance_Monitor[csr_MPerformance_Monitor_gen_index]           )
    );
end
else begin: U_gen_monitor_another
    csr_MPerformance_Monitor u_csr_MPerformance_Monitor(
        .clk                          	( clk                                                               ),
        .csr_MPerformance_Monitor_wen 	( csr_MPerformance_Monitor_wen[csr_MPerformance_Monitor_gen_index]  ),
        .MPerformance_Monitor_hibit   	( mcountinhibit[csr_MPerformance_Monitor_gen_index]                 ),
        .MPerformance_Monitor_inc     	( MPerformance_Monitor_inc[csr_MPerformance_Monitor_gen_index]      ),
        .csr_wdata                    	( csr_wdata                                                         ),
        .MPerformance_Monitor         	( Performance_Monitor[csr_MPerformance_Monitor_gen_index]           )
    );
end
end
endgenerate

csr_minstret u_csr_minstret(
    .clk                ( clk                   ),
    .csr_minstret_wen 	( csr_minstret_wen      ),
    .minstret_hibit   	( mcountinhibit[2]      ),
    .rob_commit_instret ( rob_commit_instret    ),
    .csr_wdata          ( csr_wdata             ),
    .minstret         	( minstret              )
);

generate 
for(csr_mhpmevent_gen_index = 3 ; csr_mhpmevent_gen_index < 32; csr_mhpmevent_gen_index = csr_mhpmevent_gen_index + 1) begin : csr_hpmevent_index

csr_mhpmevent u_csr_mhpmevent(
    .clk               	( clk                                           ),
    .csr_mhpmevent_wen 	( csr_mhpmevent_wen[csr_mhpmevent_gen_index]    ),
    .csr_wdata         	( csr_wdata                                     ),
    .mhpmevent         	( mhpmevent[csr_mhpmevent_gen_index]            )
);

end
endgenerate

csr_mcounteren u_csr_mcounteren(
    .mcounteren 	( mcounteren  )
);

csr_mcountinhibit u_csr_mcountinhibit(
    .clk                	( clk                   ),
    .rst_n              	( rst_n                 ),
    .csr_mcountinhibit_wen 	( csr_mcountinhibit_wen ),
    .csr_wdata          	( csr_wdata             ),
    .mcountinhibit         	( mcountinhibit         )
);

csr_mscratch u_csr_mscratch(
    .clk             	( clk              ),
    .csr_mscratch_wen 	( csr_mscratch_wen ),
    .csr_wdata       	( csr_wdata        ),
    .mscratch        	( mscratch         )
);

csr_mepc u_csr_mepc(
    .clk                 	( clk                  ),
    .csr_mepc_wen        	( csr_mepc_wen         ),
    .trap_m_mode_valid   	( trap_m_mode_valid    ),
    .csr_wdata           	( csr_wdata            ),
    .epc           	        ( epc                  ),
    .mepc                	( mepc                 )
);

csr_mcause u_csr_mcause(
    .clk               	( clk                ),
    .csr_mcause_wen    	( csr_mcause_wen     ),
    .trap_m_mode_valid 	( trap_m_mode_valid  ),
    .csr_wdata         	( csr_wdata          ),
    .cause             	( cause              ),
    .mcause            	( mcause             )
);

csr_mtval u_csr_mtval(
    .clk               	( clk                ),
    .csr_mtval_wen     	( csr_mtval_wen      ),
    .trap_m_mode_valid 	( trap_m_mode_valid  ),
    .csr_wdata         	( csr_wdata          ),
    .tval              	( tval               ),
    .mtval             	( mtval              )
);

csr_menvcfg u_csr_menvcfg(
    .menvcfg 	( menvcfg  )
);

csr_mseccfg u_csr_mseccfg(
    .mseccfg 	( mseccfg  )
);
//!S mode

csr_stvec #(RST_PC)u_csr_stvec(
    .clk           	( clk            ),
    .rst_n         	( rst_n          ),
    .csr_stvec_wen 	( csr_stvec_wen  ),
    .csr_wdata     	( csr_wdata      ),
    .stvec         	( stvec          )
);

csr_scounteren u_csr_scounteren(
    .scounteren 	( scounteren  )
);

csr_sscratch u_csr_sscratch(
    .clk              	( clk               ),
    .csr_sscratch_wen 	( csr_sscratch_wen  ),
    .csr_wdata        	( csr_wdata         ),
    .sscratch         	( sscratch          )
);

csr_sepc u_csr_sepc(
    .clk               	( clk                ),
    .csr_sepc_wen      	( csr_sepc_wen       ),
    .trap_s_mode_valid 	( trap_s_mode_valid  ),
    .csr_wdata         	( csr_wdata          ),
    .epc               	( epc                ),
    .sepc              	( sepc               )
);

csr_scause u_csr_scause(
    .clk               	( clk                ),
    .csr_scause_wen    	( csr_scause_wen     ),
    .trap_s_mode_valid 	( trap_s_mode_valid  ),
    .csr_wdata         	( csr_wdata          ),
    .cause             	( cause              ),
    .scause            	( scause             )
);

csr_stval u_csr_stval(
    .clk               	( clk                ),
    .csr_stval_wen     	( csr_stval_wen      ),
    .trap_s_mode_valid 	( trap_s_mode_valid  ),
    .csr_wdata         	( csr_wdata          ),
    .tval              	( tval               ),
    .stval             	( stval              )
);

csr_senvcfg u_csr_senvcfg(
    .senvcfg 	( senvcfg  )
);

csr_satp u_csr_satp(
    .clk          	( clk           ),
    .rst_n        	( rst_n         ),
    .csr_satp_wen 	( csr_satp_wen  ),
    .csr_wdata    	( csr_wdata     ),
    .satp         	( satp          )
);

//!Debug mode

csr_dcsr u_csr_dcsr(
    .clk                   	    (clk                        ),
    .rst_n                 	    (rst_n                      ),
    .debug_cause           	    (debug_cause                ),
    .current_priv_status   	    (current_priv_status        ),
    .csr_dcsr_wen          	    (csr_dcsr_wen               ),
    .trap_debug_mode_valid 	    (trap_debug_mode_valid      ),
    .alu_csr_fence_exu_valid_o  (alu_csr_fence_exu_valid_o  ),
    .alu_csr_fence_exu_dret_o   (alu_csr_fence_exu_dret_o   ),
    .csr_wdata             	    (csr_wdata                  ),
    .debug_mode            	    (debug_mode                 ),
    .dcsr_ebreakm          	    (dcsr_ebreakm               ),
    .dcsr_ebreaks          	    (dcsr_ebreaks               ),
    .dcsr_ebreaku          	    (dcsr_ebreaku               ),
    .dcsr_step             	    (dcsr_step                  ),
    .dcsr_prv              	    (dcsr_prv                   ),
    .dcsr                  	    (dcsr                       )
);

csr_dpc u_csr_dpc(
    .clk                   	(clk                    ),
    .csr_dpc_wen           	(csr_dpc_wen            ),
    .trap_debug_mode_valid 	(trap_debug_mode_valid  ),
    .csr_wdata             	(csr_wdata              ),
    .epc                    (epc                    ),
    .dpc                  	(dpc                    )
);

csr_dscratch u_csr_dscratch0(
    .clk              	( clk               ),
    .csr_dscratch_wen 	( csr_dscratch0_wen ),
    .csr_wdata        	( csr_wdata         ),
    .dscratch         	( dscratch0         )
);

csr_dscratch u_csr_dscratch1(
    .clk              	( clk               ),
    .csr_dscratch_wen 	( csr_dscratch1_wen ),
    .csr_wdata        	( csr_wdata         ),
    .dscratch         	( dscratch1         )
);

interrupt_control u_interrupt_control(
    .clk                        ( clk                       ),
    .rst_n                      ( rst_n                     ),
    .mstatus_MIE         	    ( mstatus_MIE               ),
    .mstatus_SIE         	    ( mstatus_SIE               ),
    .current_priv_status 	    ( current_priv_status       ),
    .mip                 	    ( mip                       ),
    .sip                 	    ( sip                       ),
    .mie                 	    ( mie                       ),
    .sie                 	    ( sie                       ),
    .mideleg                    ( mideleg                   ),
    .halt_req                   ( halt_req                  ),
    .debug_mode                 ( debug_mode                ),
    .dcsr_step                  ( dcsr_step                 ),
    .decode_out_valid           ( decode_out_valid          ),
    .rename_ready               ( rename_ready              ),
    .alu_csr_fence_exu_valid_o  ( alu_csr_fence_exu_valid_o ),
    .alu_csr_fence_exu_dret_o   ( alu_csr_fence_exu_dret_o  ),
    .trap_debug_mode_valid      ( trap_debug_mode_valid     ),
    .interrupt_m_flag    	    ( interrupt_m_flag          ),
    .interrupt_s_flag    	    ( interrupt_s_flag          ),
    .interrupt_debug_flag       ( interrupt_debug_flag      ),
    .interrupt_cause     	    ( interrupt_cause           ),
    .interrupt_debug_cause     	( interrupt_debug_cause     )
);

trap_control u_trap_control(
    .clk                     	( clk                       ),
    .rst_n                   	( rst_n                     ),
    .debug_mode                 ( debug_mode                ),
    .current_priv_status     	( current_priv_status       ),
    .csr_jump_flag              ( csr_jump_flag             ),
    .csr_jump_addr              ( csr_jump_addr             ),
    .rob_can_interrupt          ( rob_can_interrupt         ),
    .rob_commit_valid           ( rob_commit_valid          ),
    .rob_commit_pc              ( rob_commit_pc             ),
    .rob_commit_next_pc         ( rob_commit_next_pc        ),
    .interrupt_happen           ( interrupt_happen          ),
    .rob_trap_valid             ( rob_trap_valid            ),
    .rob_trap_cause             ( rob_trap_cause            ),
    .rob_trap_tval              ( rob_trap_tval             ),
    .alu_csr_fence_exu_valid_o  ( alu_csr_fence_exu_valid_o ),
    .alu_csr_fence_exu_mret_o   ( alu_csr_fence_exu_mret_o  ),
    .alu_csr_fence_exu_sret_o   ( alu_csr_fence_exu_sret_o  ),
    .alu_csr_fence_exu_dret_o   ( alu_csr_fence_exu_dret_o  ),
    .interrupt_m_flag        	( interrupt_m_flag          ),
    .interrupt_s_flag        	( interrupt_s_flag          ),
    .interrupt_debug_flag       ( interrupt_debug_flag      ),
    .interrupt_cause         	( interrupt_cause           ),
    .interrupt_debug_cause     	( interrupt_debug_cause     ),
    .trap_m_mode_valid       	( trap_m_mode_valid         ),
    .trap_s_mode_valid       	( trap_s_mode_valid         ),
    .trap_debug_mode_valid      ( trap_debug_mode_valid     ),
    .epc                     	( epc                       ),
    .debug_cause           	    ( debug_cause               ),
    .cause                   	( cause                     ),
    .tval                    	( tval                      ),
    .dcsr_ebreakm          	    ( dcsr_ebreakm              ),
    .dcsr_ebreaks          	    ( dcsr_ebreaks              ),
    .dcsr_ebreaku          	    ( dcsr_ebreaku              ),
    .medeleg                 	( medeleg                   ),
    .mepc                    	( mepc                      ),
    .sepc                    	( sepc                      ),
    .dpc                    	( dpc                       ),
    .mtvec                   	( mtvec                     ),
    .stvec                   	( stvec                     )
);


//**********************************************************************************************
//? wen 
assign csr_mstatus_wen          = alu_csr_fence_exu_valid_o & alu_csr_fence_exu_csrwen_o & (!(trap_m_mode_valid | trap_s_mode_valid)) & (alu_csr_fence_exu_csr_index_o == 12'h300);
assign csr_sstatus_wen          = alu_csr_fence_exu_valid_o & alu_csr_fence_exu_csrwen_o & (!(trap_m_mode_valid | trap_s_mode_valid)) & (alu_csr_fence_exu_csr_index_o == 12'h100);
assign csr_mtvec_wen            = alu_csr_fence_exu_valid_o & alu_csr_fence_exu_csrwen_o & (!(trap_m_mode_valid | trap_s_mode_valid)) & (alu_csr_fence_exu_csr_index_o == 12'h305);
assign csr_medeleg_wen          = alu_csr_fence_exu_valid_o & alu_csr_fence_exu_csrwen_o & (!(trap_m_mode_valid | trap_s_mode_valid)) & (alu_csr_fence_exu_csr_index_o == 12'h302);
assign csr_mideleg_wen          = alu_csr_fence_exu_valid_o & alu_csr_fence_exu_csrwen_o & (!(trap_m_mode_valid | trap_s_mode_valid)) & (alu_csr_fence_exu_csr_index_o == 12'h303);
assign csr_mip_wen              = alu_csr_fence_exu_valid_o & alu_csr_fence_exu_csrwen_o & (!(trap_m_mode_valid | trap_s_mode_valid)) & (alu_csr_fence_exu_csr_index_o == 12'h344);
assign csr_sip_wen              = alu_csr_fence_exu_valid_o & alu_csr_fence_exu_csrwen_o & (!(trap_m_mode_valid | trap_s_mode_valid)) & (alu_csr_fence_exu_csr_index_o == 12'h144);
assign csr_mie_wen              = alu_csr_fence_exu_valid_o & alu_csr_fence_exu_csrwen_o & (!(trap_m_mode_valid | trap_s_mode_valid)) & (alu_csr_fence_exu_csr_index_o == 12'h304);
assign csr_sie_wen              = alu_csr_fence_exu_valid_o & alu_csr_fence_exu_csrwen_o & (!(trap_m_mode_valid | trap_s_mode_valid)) & (alu_csr_fence_exu_csr_index_o == 12'h104);
generate 
for(csr_MPerformance_Monitor_inc_index = 2 ; csr_MPerformance_Monitor_inc_index < 32; csr_MPerformance_Monitor_inc_index = csr_MPerformance_Monitor_inc_index + 1) begin : csr_Performance_Monitor_wen
    if(csr_MPerformance_Monitor_inc_index == 2)begin: U_gen_monitor_cycle
        assign csr_MPerformance_Monitor_wen[2] = alu_csr_fence_exu_valid_o & alu_csr_fence_exu_csrwen_o & (!(trap_m_mode_valid | trap_s_mode_valid)) & (alu_csr_fence_exu_csr_index_o == 12'hB00);
        assign MPerformance_Monitor_inc[2]     = 1'b1;
    end
    // else if(csr_MPerformance_Monitor_inc_index == 2)begin: U_gen_monitor_inst
    //     assign csr_MPerformance_Monitor_wen[2] = alu_csr_fence_exu_valid_o & alu_csr_fence_exu_csrwen_o & (!(trap_m_mode_valid | trap_s_mode_valid)) & (alu_csr_fence_exu_csr_index_o == 12'hB02);
    //     assign MPerformance_Monitor_inc[2]     = alu_csr_fence_exu_valid_o;
    // end
    else begin: U_gen_monitor_another
        assign csr_MPerformance_Monitor_wen[csr_MPerformance_Monitor_inc_index] = alu_csr_fence_exu_valid_o & alu_csr_fence_exu_csrwen_o & (!(trap_m_mode_valid | trap_s_mode_valid)) & (alu_csr_fence_exu_csr_index_o == (12'hB00 + csr_MPerformance_Monitor_inc_index));
        // assign MPerformance_Monitor_inc[csr_MPerformance_Monitor_inc_index]     = 1'b0;
    end
end
endgenerate
assign csr_minstret_wen = alu_csr_fence_exu_valid_o & alu_csr_fence_exu_csrwen_o & (!(trap_m_mode_valid | trap_s_mode_valid)) & (alu_csr_fence_exu_csr_index_o == 12'hB02);
generate 
for(csr_mhpmevent_inc_index = 3 ; csr_mhpmevent_inc_index < 32; csr_mhpmevent_inc_index = csr_mhpmevent_inc_index + 1) begin : csr_hpmevent_index_wen
    assign csr_mhpmevent_wen[csr_mhpmevent_inc_index]                       = alu_csr_fence_exu_valid_o & alu_csr_fence_exu_csrwen_o & (!(trap_m_mode_valid | trap_s_mode_valid)) & (alu_csr_fence_exu_csr_index_o == (12'h320 + csr_mhpmevent_inc_index));
end
endgenerate
assign csr_mcountinhibit_wen    = alu_csr_fence_exu_valid_o & alu_csr_fence_exu_csrwen_o & (!(trap_m_mode_valid | trap_s_mode_valid)) & (alu_csr_fence_exu_csr_index_o == 12'h320);
assign csr_mscratch_wen         = alu_csr_fence_exu_valid_o & alu_csr_fence_exu_csrwen_o & (!(trap_m_mode_valid | trap_s_mode_valid)) & (alu_csr_fence_exu_csr_index_o == 12'h340);
assign csr_mepc_wen             = alu_csr_fence_exu_valid_o & alu_csr_fence_exu_csrwen_o & (!(trap_m_mode_valid | trap_s_mode_valid)) & (alu_csr_fence_exu_csr_index_o == 12'h341);
assign csr_mcause_wen           = alu_csr_fence_exu_valid_o & alu_csr_fence_exu_csrwen_o & (!(trap_m_mode_valid | trap_s_mode_valid)) & (alu_csr_fence_exu_csr_index_o == 12'h342);
assign csr_mtval_wen            = alu_csr_fence_exu_valid_o & alu_csr_fence_exu_csrwen_o & (!(trap_m_mode_valid | trap_s_mode_valid)) & (alu_csr_fence_exu_csr_index_o == 12'h343);
assign csr_stvec_wen            = alu_csr_fence_exu_valid_o & alu_csr_fence_exu_csrwen_o & (!(trap_m_mode_valid | trap_s_mode_valid)) & (alu_csr_fence_exu_csr_index_o == 12'h105);
assign csr_sscratch_wen         = alu_csr_fence_exu_valid_o & alu_csr_fence_exu_csrwen_o & (!(trap_m_mode_valid | trap_s_mode_valid)) & (alu_csr_fence_exu_csr_index_o == 12'h140);
assign csr_sepc_wen             = alu_csr_fence_exu_valid_o & alu_csr_fence_exu_csrwen_o & (!(trap_m_mode_valid | trap_s_mode_valid)) & (alu_csr_fence_exu_csr_index_o == 12'h141);
assign csr_scause_wen           = alu_csr_fence_exu_valid_o & alu_csr_fence_exu_csrwen_o & (!(trap_m_mode_valid | trap_s_mode_valid)) & (alu_csr_fence_exu_csr_index_o == 12'h142);
assign csr_stval_wen            = alu_csr_fence_exu_valid_o & alu_csr_fence_exu_csrwen_o & (!(trap_m_mode_valid | trap_s_mode_valid)) & (alu_csr_fence_exu_csr_index_o == 12'h143);
assign csr_satp_wen             = alu_csr_fence_exu_valid_o & alu_csr_fence_exu_csrwen_o & (!(trap_m_mode_valid | trap_s_mode_valid)) & (alu_csr_fence_exu_csr_index_o == 12'h180);
assign csr_dcsr_wen             = alu_csr_fence_exu_valid_o & alu_csr_fence_exu_csrwen_o & (!(trap_m_mode_valid | trap_s_mode_valid)) & (alu_csr_fence_exu_csr_index_o == 12'h7B0);
assign csr_dpc_wen              = alu_csr_fence_exu_valid_o & alu_csr_fence_exu_csrwen_o & (!(trap_m_mode_valid | trap_s_mode_valid)) & (alu_csr_fence_exu_csr_index_o == 12'h7B1);
assign csr_dscratch0_wen        = alu_csr_fence_exu_valid_o & alu_csr_fence_exu_csrwen_o & (!(trap_m_mode_valid | trap_s_mode_valid)) & (alu_csr_fence_exu_csr_index_o == 12'h7B2);
assign csr_dscratch1_wen        = alu_csr_fence_exu_valid_o & alu_csr_fence_exu_csrwen_o & (!(trap_m_mode_valid | trap_s_mode_valid)) & (alu_csr_fence_exu_csr_index_o == 12'h7B3);
assign csr_wdata                = alu_csr_fence_exu_csr_wdata_o;
//**********************************************************************************************
//?output csr
always @(*) begin
    case (csr_index)
        MISA              : csr_rdata_reg = misa;
        MVENDORID         : csr_rdata_reg = mvendorid;
        MARCHID           : csr_rdata_reg = marchid;
        MIMPID            : csr_rdata_reg = mimpid;
        MHARTID           : csr_rdata_reg = mhartid;
        MSTATUS           : csr_rdata_reg = mstatus;
        MTVEC             : csr_rdata_reg = mtvec;
        MEDELEG           : csr_rdata_reg = medeleg;
        MIDELEG           : csr_rdata_reg = mideleg;
        MIP               : csr_rdata_reg = mip;
        MIE               : csr_rdata_reg = mie;
        MCYCLE            : csr_rdata_reg = Performance_Monitor[2];
        MINSTRET          : csr_rdata_reg = Performance_Monitor[2];
        MHPMCOUNTER3      : csr_rdata_reg = Performance_Monitor[3];
        MHPMCOUNTER4      : csr_rdata_reg = Performance_Monitor[4];
        MHPMCOUNTER5      : csr_rdata_reg = Performance_Monitor[5];
        MHPMCOUNTER6      : csr_rdata_reg = Performance_Monitor[6];
        MHPMCOUNTER7      : csr_rdata_reg = Performance_Monitor[7];
        MHPMCOUNTER8      : csr_rdata_reg = Performance_Monitor[8];
        MHPMCOUNTER9      : csr_rdata_reg = Performance_Monitor[9];
        MHPMCOUNTER10     : csr_rdata_reg = Performance_Monitor[10];
        MHPMCOUNTER11     : csr_rdata_reg = Performance_Monitor[11];
        MHPMCOUNTER12     : csr_rdata_reg = Performance_Monitor[12];
        MHPMCOUNTER13     : csr_rdata_reg = Performance_Monitor[13];
        MHPMCOUNTER14     : csr_rdata_reg = Performance_Monitor[14];
        MHPMCOUNTER15     : csr_rdata_reg = Performance_Monitor[15];
        MHPMCOUNTER16     : csr_rdata_reg = Performance_Monitor[16];
        MHPMCOUNTER17     : csr_rdata_reg = Performance_Monitor[17];
        MHPMCOUNTER18     : csr_rdata_reg = Performance_Monitor[18];
        MHPMCOUNTER19     : csr_rdata_reg = Performance_Monitor[19];
        MHPMCOUNTER20     : csr_rdata_reg = Performance_Monitor[20];
        MHPMCOUNTER21     : csr_rdata_reg = Performance_Monitor[21];
        MHPMCOUNTER22     : csr_rdata_reg = Performance_Monitor[22];
        MHPMCOUNTER23     : csr_rdata_reg = Performance_Monitor[23];
        MHPMCOUNTER24     : csr_rdata_reg = Performance_Monitor[24];
        MHPMCOUNTER25     : csr_rdata_reg = Performance_Monitor[25];
        MHPMCOUNTER26     : csr_rdata_reg = Performance_Monitor[26];
        MHPMCOUNTER27     : csr_rdata_reg = Performance_Monitor[27];
        MHPMCOUNTER28     : csr_rdata_reg = Performance_Monitor[28];
        MHPMCOUNTER29     : csr_rdata_reg = Performance_Monitor[29];
        MHPMCOUNTER30     : csr_rdata_reg = Performance_Monitor[30];
        MHPMCOUNTER31     : csr_rdata_reg = Performance_Monitor[31];
        MHPMEVENT3        : csr_rdata_reg = mhpmevent[3];
        MHPMEVENT4        : csr_rdata_reg = mhpmevent[4];
        MHPMEVENT5        : csr_rdata_reg = mhpmevent[5];
        MHPMEVENT6        : csr_rdata_reg = mhpmevent[6];
        MHPMEVENT7        : csr_rdata_reg = mhpmevent[7];
        MHPMEVENT8        : csr_rdata_reg = mhpmevent[8];
        MHPMEVENT9        : csr_rdata_reg = mhpmevent[9];
        MHPMEVENT10       : csr_rdata_reg = mhpmevent[10];
        MHPMEVENT11       : csr_rdata_reg = mhpmevent[11];
        MHPMEVENT12       : csr_rdata_reg = mhpmevent[12];
        MHPMEVENT13       : csr_rdata_reg = mhpmevent[13];
        MHPMEVENT14       : csr_rdata_reg = mhpmevent[14];
        MHPMEVENT15       : csr_rdata_reg = mhpmevent[15];
        MHPMEVENT16       : csr_rdata_reg = mhpmevent[16];
        MHPMEVENT17       : csr_rdata_reg = mhpmevent[17];
        MHPMEVENT18       : csr_rdata_reg = mhpmevent[18];
        MHPMEVENT19       : csr_rdata_reg = mhpmevent[19];
        MHPMEVENT20       : csr_rdata_reg = mhpmevent[20];
        MHPMEVENT21       : csr_rdata_reg = mhpmevent[21];
        MHPMEVENT22       : csr_rdata_reg = mhpmevent[22];
        MHPMEVENT23       : csr_rdata_reg = mhpmevent[23];
        MHPMEVENT24       : csr_rdata_reg = mhpmevent[24];
        MHPMEVENT25       : csr_rdata_reg = mhpmevent[25];
        MHPMEVENT26       : csr_rdata_reg = mhpmevent[26];
        MHPMEVENT27       : csr_rdata_reg = mhpmevent[27];
        MHPMEVENT28       : csr_rdata_reg = mhpmevent[28];
        MHPMEVENT29       : csr_rdata_reg = mhpmevent[29];
        MHPMEVENT30       : csr_rdata_reg = mhpmevent[30];
        MHPMEVENT31       : csr_rdata_reg = mhpmevent[31];
        MCOUNTEREN        : csr_rdata_reg = mcounteren;
        MCOUNTINHIBIT     : csr_rdata_reg = mcountinhibit;
        MSCRATCH          : csr_rdata_reg = mscratch;
        MEPC              : csr_rdata_reg = mepc;
        MCAUSE            : csr_rdata_reg = mcause;
        MTVAL             : csr_rdata_reg = mtval;
        MCONFIGPTR        : csr_rdata_reg = mconfigptr;
        MENVCFG           : csr_rdata_reg = menvcfg;
        MSECCFG           : csr_rdata_reg = mseccfg;
        SSTATUS           : csr_rdata_reg = sstatus;
        STVEC             : csr_rdata_reg = stvec;
        SIP               : csr_rdata_reg = sip;
        SIE               : csr_rdata_reg = sie;
        SCOUNTEREN        : csr_rdata_reg = scounteren;
        SSCRATCH          : csr_rdata_reg = sscratch;
        SEPC              : csr_rdata_reg = sepc;
        SCAUSE            : csr_rdata_reg = scause;
        STVAL             : csr_rdata_reg = stval;
        SENVCFG           : csr_rdata_reg = senvcfg;
        SATP              : csr_rdata_reg = satp;
        CYCLE             : csr_rdata_reg = Performance_Monitor[2];
        INSTRET           : csr_rdata_reg = minstret;
        HPMCOUNTER3       : csr_rdata_reg = Performance_Monitor[3];
        HPMCOUNTER4       : csr_rdata_reg = Performance_Monitor[4];
        HPMCOUNTER5       : csr_rdata_reg = Performance_Monitor[5];
        HPMCOUNTER6       : csr_rdata_reg = Performance_Monitor[6];
        HPMCOUNTER7       : csr_rdata_reg = Performance_Monitor[7];
        HPMCOUNTER8       : csr_rdata_reg = Performance_Monitor[8];
        HPMCOUNTER9       : csr_rdata_reg = Performance_Monitor[9];
        HPMCOUNTER10      : csr_rdata_reg = Performance_Monitor[10];
        HPMCOUNTER11      : csr_rdata_reg = Performance_Monitor[11];
        HPMCOUNTER12      : csr_rdata_reg = Performance_Monitor[12];
        HPMCOUNTER13      : csr_rdata_reg = Performance_Monitor[13];
        HPMCOUNTER14      : csr_rdata_reg = Performance_Monitor[14];
        HPMCOUNTER15      : csr_rdata_reg = Performance_Monitor[15];
        HPMCOUNTER16      : csr_rdata_reg = Performance_Monitor[16];
        HPMCOUNTER17      : csr_rdata_reg = Performance_Monitor[17];
        HPMCOUNTER18      : csr_rdata_reg = Performance_Monitor[18];
        HPMCOUNTER19      : csr_rdata_reg = Performance_Monitor[19];
        HPMCOUNTER20      : csr_rdata_reg = Performance_Monitor[20];
        HPMCOUNTER21      : csr_rdata_reg = Performance_Monitor[21];
        HPMCOUNTER22      : csr_rdata_reg = Performance_Monitor[22];
        HPMCOUNTER23      : csr_rdata_reg = Performance_Monitor[23];
        HPMCOUNTER24      : csr_rdata_reg = Performance_Monitor[24];
        HPMCOUNTER25      : csr_rdata_reg = Performance_Monitor[25];
        HPMCOUNTER26      : csr_rdata_reg = Performance_Monitor[26];
        HPMCOUNTER27      : csr_rdata_reg = Performance_Monitor[27];
        HPMCOUNTER28      : csr_rdata_reg = Performance_Monitor[28];
        HPMCOUNTER29      : csr_rdata_reg = Performance_Monitor[29];
        HPMCOUNTER30      : csr_rdata_reg = Performance_Monitor[30];
        HPMCOUNTER31      : csr_rdata_reg = Performance_Monitor[31];
        DCSR              : csr_rdata_reg = dcsr;
        DPC               : csr_rdata_reg = dpc;
        DSCRATCH0         : csr_rdata_reg = dscratch0;
        DSCRATCH1         : csr_rdata_reg = dscratch1;
        default: csr_rdata_reg = 64'h0;
    endcase
end
assign csr_rdata            = csr_rdata_reg;
assign TW                   = mstatus_TW;
assign TVM                  = mstatus_TVM;
assign TSR                  = mstatus_TSR;
assign MXR                  = mstatus_MXR;
assign SUM                  = mstatus_SUM;
assign MPRV                 = mstatus_MPRV;
assign MPP                  = mstatus_MPP;
assign satp_mode            = satp[63:60];
assign satp_asid            = satp[59:44];
assign satp_ppn             = satp[43:0];
assign mepc_o               = mepc;
assign sepc_o               = sepc;
assign dpc_o                = dpc;
//**********************************************************************************************

endmodule //csr
