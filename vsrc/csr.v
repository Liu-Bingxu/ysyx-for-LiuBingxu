// the control and status register
// Copyright (C) 2024  LiuBingxu

// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.

// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.

// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

// Please contact me through the following email: <qwe15889844242@163.com>

`include "./define.v"
module csr#(parameter MHARTID = 0,RST_PC=64'h0) (
    input                   clk,
    input                   rst_n,
    input                   stip,
    input                   seip,
    input                   ssip,
    input                   mtip,
    input                   meip,
    input                   msip,
    input                   halt_req,
    output  [1:0]           current_priv_status,
//interface with mmu
    output                  MXR,
    output                  SUM,
    output                  MPRV,
    output [1:0]            MPP,
    output [3:0]            satp_mode,
    output [15:0]           satp_asid,
    output [43:0]           satp_ppn,
//interface with ifu
    output                  WB_IF_jump_flag,
    output [63:0]           WB_IF_jump_addr,
//interface with idu
    input  [11:0]           ID_WB_csr_addr,
    output [63:0]           WB_ID_csr_rdata,
    output                  TSR,
    output                  TW,
    output                  TVM,
    output                  debug_mode,
//interface with exu
    input                   EX_LS_reg_execute_valid,
    output                  WB_EX_interrupt_flag,
//interface with lsu 
    //common
    input                   LS_WB_reg_ls_valid,
    input  [63:0]           LS_WB_reg_PC,
    input  [63:0]           LS_WB_reg_next_PC,
    //trap:
    input                   LS_WB_reg_trap_valid,
    input                   LS_WB_reg_mret_valid,
    input                   LS_WB_reg_sret_valid,
    input                   LS_WB_reg_dret_valid,
    input  [63:0]           LS_WB_reg_trap_cause,
    input  [63:0]           LS_WB_reg_trap_tval,
    //csr
    input                   LS_WB_reg_csr_wen,
    input  [11:0]           LS_WB_reg_csr_addr,
    input  [63:0]           LS_WB_reg_data,
//interface with gpr
    output [63:0]           csr_rdata
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
reg  [63:0]     WB_ID_csr_rdata_reg;

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
wire [63:0]     Performance_Monitor[1:31];
wire            csr_MPerformance_Monitor_wen[1:31];
wire            MPerformance_Monitor_inc[1:31];
genvar          csr_MPerformance_Monitor_index;

//?mhpmevent
wire [63:0]     mhpmevent[3:31];
wire            csr_mhpmevent_wen[3:31];
genvar          csr_mhpmevent_index;

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
    .MHARTID 	( MHARTID  )
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
    .clk                  	( clk                   ),
    .rst_n                	( rst_n                 ),
    .csr_mstatus_wen      	( csr_mstatus_wen       ),
    .csr_sstatus_wen      	( csr_sstatus_wen       ),
    .trap_m_mode_valid    	( trap_m_mode_valid     ),
    .trap_s_mode_valid    	( trap_s_mode_valid     ),
    .trap_debug_mode_valid  ( trap_debug_mode_valid ),
    .LS_WB_reg_ls_valid     ( LS_WB_reg_ls_valid    ),
    .LS_WB_reg_mret_valid 	( LS_WB_reg_mret_valid  ),
    .LS_WB_reg_sret_valid 	( LS_WB_reg_sret_valid  ),
    .LS_WB_reg_dret_valid   ( LS_WB_reg_dret_valid  ),
    .dcsr_prv               ( dcsr_prv              ),
    .current_priv_status  	( current_priv_status   ),
    .csr_wdata            	( csr_wdata             ),
    .mstatus_TSR          	( mstatus_TSR           ),
    .mstatus_TW           	( mstatus_TW            ),
    .mstatus_TVM          	( mstatus_TVM           ),
    .mstatus_MXR          	( mstatus_MXR           ),
    .mstatus_SUM          	( mstatus_SUM           ),
    .mstatus_MPRV         	( mstatus_MPRV          ),
    .mstatus_MPP          	( mstatus_MPP           ),
    .mstatus_MIE          	( mstatus_MIE           ),
    .mstatus_SIE          	( mstatus_SIE           ),
    .mstatus              	( mstatus               ),
    .sstatus                ( sstatus               )
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
for(csr_MPerformance_Monitor_index = 1 ; csr_MPerformance_Monitor_index < 32; csr_MPerformance_Monitor_index = csr_MPerformance_Monitor_index + 1) begin : csr_Performance_Monitor

if(csr_MPerformance_Monitor_index == 1)begin
    csr_MPerformance_Monitor u_csr_MPerformance_Monitor(
        .clk                          	( clk                                                           ),
        .csr_MPerformance_Monitor_wen 	( csr_MPerformance_Monitor_wen[csr_MPerformance_Monitor_index]  ),
        .MPerformance_Monitor_hibit   	( mcountinhibit[0]                                              ),
        .MPerformance_Monitor_inc     	( MPerformance_Monitor_inc[csr_MPerformance_Monitor_index]      ),
        .csr_wdata                    	( csr_wdata                                                     ),
        .MPerformance_Monitor         	( Performance_Monitor[csr_MPerformance_Monitor_index]           )
    );
end
else begin
    csr_MPerformance_Monitor u_csr_MPerformance_Monitor(
        .clk                          	( clk                                                           ),
        .csr_MPerformance_Monitor_wen 	( csr_MPerformance_Monitor_wen[csr_MPerformance_Monitor_index]  ),
        .MPerformance_Monitor_hibit   	( mcountinhibit[csr_MPerformance_Monitor_index]                 ),
        .MPerformance_Monitor_inc     	( MPerformance_Monitor_inc[csr_MPerformance_Monitor_index]      ),
        .csr_wdata                    	( csr_wdata                                                     ),
        .MPerformance_Monitor         	( Performance_Monitor[csr_MPerformance_Monitor_index]           )
    );
end
end
endgenerate

generate 
for(csr_mhpmevent_index = 3 ; csr_mhpmevent_index < 32; csr_mhpmevent_index = csr_mhpmevent_index + 1) begin : csr_hpmevent_index

csr_mhpmevent u_csr_mhpmevent(
    .clk               	( clk                                       ),
    .csr_mhpmevent_wen 	( csr_mhpmevent_wen[csr_mhpmevent_index]    ),
    .csr_wdata         	( csr_wdata                                 ),
    .mhpmevent         	( mhpmevent[csr_mhpmevent_index]            )
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
    .clk                   	(clk                    ),
    .rst_n                 	(rst_n                  ),
    .debug_cause           	(debug_cause            ),
    .current_priv_status   	(current_priv_status    ),
    .csr_dcsr_wen          	(csr_dcsr_wen           ),
    .trap_debug_mode_valid 	(trap_debug_mode_valid  ),
    .LS_WB_reg_ls_valid    	(LS_WB_reg_ls_valid     ),
    .LS_WB_reg_trap_valid  	(LS_WB_reg_trap_valid   ),
    .LS_WB_reg_dret_valid  	(LS_WB_reg_dret_valid   ),
    .csr_wdata             	(csr_wdata              ),
    .debug_mode            	(debug_mode             ),
    .dcsr_ebreakm          	(dcsr_ebreakm           ),
    .dcsr_ebreaks          	(dcsr_ebreaks           ),
    .dcsr_ebreaku          	(dcsr_ebreaku           ),
    .dcsr_step             	(dcsr_step              ),
    .dcsr_prv              	(dcsr_prv               ),
    .dcsr                  	(dcsr                   )
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
    .halt_req                   ( halt_req                  ),
    .debug_mode                 ( debug_mode                ),
    .dcsr_step                  ( dcsr_step                 ),
    .EX_LS_reg_execute_valid    ( EX_LS_reg_execute_valid   ),
    .LS_WB_reg_ls_valid         ( LS_WB_reg_ls_valid        ),
    .LS_WB_reg_trap_valid    	( LS_WB_reg_trap_valid      ),
    .LS_WB_reg_dret_valid    	( LS_WB_reg_dret_valid      ),
    .trap_debug_mode_valid      ( trap_debug_mode_valid     ),
    .interrupt_m_flag    	    ( interrupt_m_flag          ),
    .interrupt_s_flag    	    ( interrupt_s_flag          ),
    .interrupt_debug_flag       ( interrupt_debug_flag      ),
    .interrupt_cause     	    ( interrupt_cause           ),
    .interrupt_debug_cause     	( interrupt_debug_cause     )
);

trap_control #(RST_PC)u_trap_control(
    .clk                     	( clk                      ),
    .rst_n                   	( rst_n                    ),
    .debug_mode                 ( debug_mode               ),
    .current_priv_status     	( current_priv_status      ),
    .WB_IF_jump_flag         	( WB_IF_jump_flag          ),
    .WB_IF_jump_addr         	( WB_IF_jump_addr          ),
    .EX_LS_reg_execute_valid 	( EX_LS_reg_execute_valid  ),
    .LS_WB_reg_ls_valid      	( LS_WB_reg_ls_valid       ),
    .LS_WB_reg_PC            	( LS_WB_reg_PC             ),
    .LS_WB_reg_next_PC       	( LS_WB_reg_next_PC        ),
    .LS_WB_reg_trap_valid    	( LS_WB_reg_trap_valid     ),
    .LS_WB_reg_mret_valid    	( LS_WB_reg_mret_valid     ),
    .LS_WB_reg_sret_valid    	( LS_WB_reg_sret_valid     ),
    .LS_WB_reg_dret_valid    	( LS_WB_reg_dret_valid     ),
    .LS_WB_reg_trap_cause    	( LS_WB_reg_trap_cause     ),
    .LS_WB_reg_trap_tval     	( LS_WB_reg_trap_tval      ),
    .interrupt_m_flag        	( interrupt_m_flag         ),
    .interrupt_s_flag        	( interrupt_s_flag         ),
    .interrupt_debug_flag       ( interrupt_debug_flag     ),
    .interrupt_cause         	( interrupt_cause          ),
    .interrupt_debug_cause     	( interrupt_debug_cause    ),
    .trap_m_mode_valid       	( trap_m_mode_valid        ),
    .trap_s_mode_valid       	( trap_s_mode_valid        ),
    .trap_debug_mode_valid      ( trap_debug_mode_valid    ),
    .epc                     	( epc                      ),
    .debug_cause           	    ( debug_cause              ),
    .cause                   	( cause                    ),
    .tval                    	( tval                     ),
    .dcsr_ebreakm          	    ( dcsr_ebreakm             ),
    .dcsr_ebreaks          	    ( dcsr_ebreaks             ),
    .dcsr_ebreaku          	    ( dcsr_ebreaku             ),
    .medeleg                 	( medeleg                  ),
    .mepc                    	( mepc                     ),
    .sepc                    	( sepc                     ),
    .dpc                    	( dpc                      ),
    .mtvec                   	( mtvec                    ),
    .stvec                   	( stvec                    )
);


//**********************************************************************************************
//? wen 
assign csr_mstatus_wen          = LS_WB_reg_ls_valid & LS_WB_reg_csr_wen & (!(trap_m_mode_valid | trap_s_mode_valid)) & (LS_WB_reg_csr_addr == 12'h300);
assign csr_sstatus_wen          = LS_WB_reg_ls_valid & LS_WB_reg_csr_wen & (!(trap_m_mode_valid | trap_s_mode_valid)) & (LS_WB_reg_csr_addr == 12'h100);
assign csr_mtvec_wen            = LS_WB_reg_ls_valid & LS_WB_reg_csr_wen & (!(trap_m_mode_valid | trap_s_mode_valid)) & (LS_WB_reg_csr_addr == 12'h305);
assign csr_medeleg_wen          = LS_WB_reg_ls_valid & LS_WB_reg_csr_wen & (!(trap_m_mode_valid | trap_s_mode_valid)) & (LS_WB_reg_csr_addr == 12'h302);
assign csr_mideleg_wen          = LS_WB_reg_ls_valid & LS_WB_reg_csr_wen & (!(trap_m_mode_valid | trap_s_mode_valid)) & (LS_WB_reg_csr_addr == 12'h303);
assign csr_mip_wen              = LS_WB_reg_ls_valid & LS_WB_reg_csr_wen & (!(trap_m_mode_valid | trap_s_mode_valid)) & (LS_WB_reg_csr_addr == 12'h344);
assign csr_sip_wen              = LS_WB_reg_ls_valid & LS_WB_reg_csr_wen & (!(trap_m_mode_valid | trap_s_mode_valid)) & (LS_WB_reg_csr_addr == 12'h144);
assign csr_mie_wen              = LS_WB_reg_ls_valid & LS_WB_reg_csr_wen & (!(trap_m_mode_valid | trap_s_mode_valid)) & (LS_WB_reg_csr_addr == 12'h304);
assign csr_sie_wen              = LS_WB_reg_ls_valid & LS_WB_reg_csr_wen & (!(trap_m_mode_valid | trap_s_mode_valid)) & (LS_WB_reg_csr_addr == 12'h104);
generate 
for(csr_MPerformance_Monitor_index = 1 ; csr_MPerformance_Monitor_index < 32; csr_MPerformance_Monitor_index = csr_MPerformance_Monitor_index + 1) begin : csr_Performance_Monitor_wen
    if(csr_MPerformance_Monitor_index == 1)begin
        assign csr_MPerformance_Monitor_wen[1] = LS_WB_reg_ls_valid & LS_WB_reg_csr_wen & (!(trap_m_mode_valid | trap_s_mode_valid)) & (LS_WB_reg_csr_addr == 12'hB00);
        assign MPerformance_Monitor_inc[1]     = 1'b1;
    end
    else if(csr_MPerformance_Monitor_index == 2)begin
        assign csr_MPerformance_Monitor_wen[2] = LS_WB_reg_ls_valid & LS_WB_reg_csr_wen & (!(trap_m_mode_valid | trap_s_mode_valid)) & (LS_WB_reg_csr_addr == 12'hB02);
        assign MPerformance_Monitor_inc[2]     = LS_WB_reg_ls_valid & (!LS_WB_reg_trap_valid);
    end
    else begin
        assign csr_MPerformance_Monitor_wen[csr_MPerformance_Monitor_index] = LS_WB_reg_ls_valid & LS_WB_reg_csr_wen & (!(trap_m_mode_valid | trap_s_mode_valid)) & (LS_WB_reg_csr_addr == (12'hB00 + csr_MPerformance_Monitor_index));
        assign MPerformance_Monitor_inc[csr_MPerformance_Monitor_index]     = 1'b0;
    end
end
endgenerate
generate 
for(csr_mhpmevent_index = 3 ; csr_mhpmevent_index < 32; csr_mhpmevent_index = csr_mhpmevent_index + 1) begin : csr_hpmevent_index_wen
    assign csr_mhpmevent_wen[csr_mhpmevent_index]                       = LS_WB_reg_ls_valid & LS_WB_reg_csr_wen & (!(trap_m_mode_valid | trap_s_mode_valid)) & (LS_WB_reg_csr_addr == (12'h320 + csr_mhpmevent_index));
end
endgenerate
assign csr_mcountinhibit_wen    = LS_WB_reg_ls_valid & LS_WB_reg_csr_wen & (!(trap_m_mode_valid | trap_s_mode_valid)) & (LS_WB_reg_csr_addr == 12'h320);
assign csr_mscratch_wen         = LS_WB_reg_ls_valid & LS_WB_reg_csr_wen & (!(trap_m_mode_valid | trap_s_mode_valid)) & (LS_WB_reg_csr_addr == 12'h340);
assign csr_mepc_wen             = LS_WB_reg_ls_valid & LS_WB_reg_csr_wen & (!(trap_m_mode_valid | trap_s_mode_valid)) & (LS_WB_reg_csr_addr == 12'h341);
assign csr_mcause_wen           = LS_WB_reg_ls_valid & LS_WB_reg_csr_wen & (!(trap_m_mode_valid | trap_s_mode_valid)) & (LS_WB_reg_csr_addr == 12'h342);
assign csr_mtval_wen            = LS_WB_reg_ls_valid & LS_WB_reg_csr_wen & (!(trap_m_mode_valid | trap_s_mode_valid)) & (LS_WB_reg_csr_addr == 12'h343);
assign csr_stvec_wen            = LS_WB_reg_ls_valid & LS_WB_reg_csr_wen & (!(trap_m_mode_valid | trap_s_mode_valid)) & (LS_WB_reg_csr_addr == 12'h105);
assign csr_sscratch_wen         = LS_WB_reg_ls_valid & LS_WB_reg_csr_wen & (!(trap_m_mode_valid | trap_s_mode_valid)) & (LS_WB_reg_csr_addr == 12'h140);
assign csr_sepc_wen             = LS_WB_reg_ls_valid & LS_WB_reg_csr_wen & (!(trap_m_mode_valid | trap_s_mode_valid)) & (LS_WB_reg_csr_addr == 12'h141);
assign csr_scause_wen           = LS_WB_reg_ls_valid & LS_WB_reg_csr_wen & (!(trap_m_mode_valid | trap_s_mode_valid)) & (LS_WB_reg_csr_addr == 12'h142);
assign csr_stval_wen            = LS_WB_reg_ls_valid & LS_WB_reg_csr_wen & (!(trap_m_mode_valid | trap_s_mode_valid)) & (LS_WB_reg_csr_addr == 12'h143);
assign csr_satp_wen             = LS_WB_reg_ls_valid & LS_WB_reg_csr_wen & (!(trap_m_mode_valid | trap_s_mode_valid)) & (LS_WB_reg_csr_addr == 12'h180);
assign csr_dcsr_wen             = LS_WB_reg_ls_valid & LS_WB_reg_csr_wen & (!(trap_m_mode_valid | trap_s_mode_valid)) & (LS_WB_reg_csr_addr == 12'h7B0);
assign csr_dpc_wen              = LS_WB_reg_ls_valid & LS_WB_reg_csr_wen & (!(trap_m_mode_valid | trap_s_mode_valid)) & (LS_WB_reg_csr_addr == 12'h7B1);
assign csr_dscratch0_wen        = LS_WB_reg_ls_valid & LS_WB_reg_csr_wen & (!(trap_m_mode_valid | trap_s_mode_valid)) & (LS_WB_reg_csr_addr == 12'h7B2);
assign csr_dscratch1_wen        = LS_WB_reg_ls_valid & LS_WB_reg_csr_wen & (!(trap_m_mode_valid | trap_s_mode_valid)) & (LS_WB_reg_csr_addr == 12'h7B3);
assign csr_wdata                = LS_WB_reg_data;
//**********************************************************************************************
//?output csr
always @(*) begin
    case (ID_WB_csr_addr)
        `CSR_ADDR_MISA              : WB_ID_csr_rdata_reg = misa;
        `CSR_ADDR_MVENDORID         : WB_ID_csr_rdata_reg = mvendorid;
        `CSR_ADDR_MARCHID           : WB_ID_csr_rdata_reg = marchid;
        `CSR_ADDR_MIMPID            : WB_ID_csr_rdata_reg = mimpid;
        `CSR_ADDR_MHARTID           : WB_ID_csr_rdata_reg = mhartid;
        `CSR_ADDR_MSTATUS           : WB_ID_csr_rdata_reg = mstatus;
        `CSR_ADDR_MTVEC             : WB_ID_csr_rdata_reg = mtvec;
        `CSR_ADDR_MEDELEG           : WB_ID_csr_rdata_reg = medeleg;
        `CSR_ADDR_MIDELEG           : WB_ID_csr_rdata_reg = mideleg;
        `CSR_ADDR_MIP               : WB_ID_csr_rdata_reg = mip;
        `CSR_ADDR_MIE               : WB_ID_csr_rdata_reg = mie;
        `CSR_ADDR_MCYCLE            : WB_ID_csr_rdata_reg = Performance_Monitor[1];
        `CSR_ADDR_MINSTRET          : WB_ID_csr_rdata_reg = Performance_Monitor[2];
        `CSR_ADDR_MHPMCOUNTER3      : WB_ID_csr_rdata_reg = Performance_Monitor[3];
        `CSR_ADDR_MHPMCOUNTER4      : WB_ID_csr_rdata_reg = Performance_Monitor[4];
        `CSR_ADDR_MHPMCOUNTER5      : WB_ID_csr_rdata_reg = Performance_Monitor[5];
        `CSR_ADDR_MHPMCOUNTER6      : WB_ID_csr_rdata_reg = Performance_Monitor[6];
        `CSR_ADDR_MHPMCOUNTER7      : WB_ID_csr_rdata_reg = Performance_Monitor[7];
        `CSR_ADDR_MHPMCOUNTER8      : WB_ID_csr_rdata_reg = Performance_Monitor[8];
        `CSR_ADDR_MHPMCOUNTER9      : WB_ID_csr_rdata_reg = Performance_Monitor[9];
        `CSR_ADDR_MHPMCOUNTER10     : WB_ID_csr_rdata_reg = Performance_Monitor[10];
        `CSR_ADDR_MHPMCOUNTER11     : WB_ID_csr_rdata_reg = Performance_Monitor[11];
        `CSR_ADDR_MHPMCOUNTER12     : WB_ID_csr_rdata_reg = Performance_Monitor[12];
        `CSR_ADDR_MHPMCOUNTER13     : WB_ID_csr_rdata_reg = Performance_Monitor[13];
        `CSR_ADDR_MHPMCOUNTER14     : WB_ID_csr_rdata_reg = Performance_Monitor[14];
        `CSR_ADDR_MHPMCOUNTER15     : WB_ID_csr_rdata_reg = Performance_Monitor[15];
        `CSR_ADDR_MHPMCOUNTER16     : WB_ID_csr_rdata_reg = Performance_Monitor[16];
        `CSR_ADDR_MHPMCOUNTER17     : WB_ID_csr_rdata_reg = Performance_Monitor[17];
        `CSR_ADDR_MHPMCOUNTER18     : WB_ID_csr_rdata_reg = Performance_Monitor[18];
        `CSR_ADDR_MHPMCOUNTER19     : WB_ID_csr_rdata_reg = Performance_Monitor[19];
        `CSR_ADDR_MHPMCOUNTER20     : WB_ID_csr_rdata_reg = Performance_Monitor[20];
        `CSR_ADDR_MHPMCOUNTER21     : WB_ID_csr_rdata_reg = Performance_Monitor[21];
        `CSR_ADDR_MHPMCOUNTER22     : WB_ID_csr_rdata_reg = Performance_Monitor[22];
        `CSR_ADDR_MHPMCOUNTER23     : WB_ID_csr_rdata_reg = Performance_Monitor[23];
        `CSR_ADDR_MHPMCOUNTER24     : WB_ID_csr_rdata_reg = Performance_Monitor[24];
        `CSR_ADDR_MHPMCOUNTER25     : WB_ID_csr_rdata_reg = Performance_Monitor[25];
        `CSR_ADDR_MHPMCOUNTER26     : WB_ID_csr_rdata_reg = Performance_Monitor[26];
        `CSR_ADDR_MHPMCOUNTER27     : WB_ID_csr_rdata_reg = Performance_Monitor[27];
        `CSR_ADDR_MHPMCOUNTER28     : WB_ID_csr_rdata_reg = Performance_Monitor[28];
        `CSR_ADDR_MHPMCOUNTER29     : WB_ID_csr_rdata_reg = Performance_Monitor[29];
        `CSR_ADDR_MHPMCOUNTER30     : WB_ID_csr_rdata_reg = Performance_Monitor[30];
        `CSR_ADDR_MHPMCOUNTER31     : WB_ID_csr_rdata_reg = Performance_Monitor[31];
        `CSR_ADDR_MHPMENVENT3       : WB_ID_csr_rdata_reg = mhpmevent[3];
        `CSR_ADDR_MHPMENVENT4       : WB_ID_csr_rdata_reg = mhpmevent[4];
        `CSR_ADDR_MHPMENVENT5       : WB_ID_csr_rdata_reg = mhpmevent[5];
        `CSR_ADDR_MHPMENVENT6       : WB_ID_csr_rdata_reg = mhpmevent[6];
        `CSR_ADDR_MHPMENVENT7       : WB_ID_csr_rdata_reg = mhpmevent[7];
        `CSR_ADDR_MHPMENVENT8       : WB_ID_csr_rdata_reg = mhpmevent[8];
        `CSR_ADDR_MHPMENVENT9       : WB_ID_csr_rdata_reg = mhpmevent[9];
        `CSR_ADDR_MHPMENVENT10      : WB_ID_csr_rdata_reg = mhpmevent[10];
        `CSR_ADDR_MHPMENVENT11      : WB_ID_csr_rdata_reg = mhpmevent[11];
        `CSR_ADDR_MHPMENVENT12      : WB_ID_csr_rdata_reg = mhpmevent[12];
        `CSR_ADDR_MHPMENVENT13      : WB_ID_csr_rdata_reg = mhpmevent[13];
        `CSR_ADDR_MHPMENVENT14      : WB_ID_csr_rdata_reg = mhpmevent[14];
        `CSR_ADDR_MHPMENVENT15      : WB_ID_csr_rdata_reg = mhpmevent[15];
        `CSR_ADDR_MHPMENVENT16      : WB_ID_csr_rdata_reg = mhpmevent[16];
        `CSR_ADDR_MHPMENVENT17      : WB_ID_csr_rdata_reg = mhpmevent[17];
        `CSR_ADDR_MHPMENVENT18      : WB_ID_csr_rdata_reg = mhpmevent[18];
        `CSR_ADDR_MHPMENVENT19      : WB_ID_csr_rdata_reg = mhpmevent[19];
        `CSR_ADDR_MHPMENVENT20      : WB_ID_csr_rdata_reg = mhpmevent[20];
        `CSR_ADDR_MHPMENVENT21      : WB_ID_csr_rdata_reg = mhpmevent[21];
        `CSR_ADDR_MHPMENVENT22      : WB_ID_csr_rdata_reg = mhpmevent[22];
        `CSR_ADDR_MHPMENVENT23      : WB_ID_csr_rdata_reg = mhpmevent[23];
        `CSR_ADDR_MHPMENVENT24      : WB_ID_csr_rdata_reg = mhpmevent[24];
        `CSR_ADDR_MHPMENVENT25      : WB_ID_csr_rdata_reg = mhpmevent[25];
        `CSR_ADDR_MHPMENVENT26      : WB_ID_csr_rdata_reg = mhpmevent[26];
        `CSR_ADDR_MHPMENVENT27      : WB_ID_csr_rdata_reg = mhpmevent[27];
        `CSR_ADDR_MHPMENVENT28      : WB_ID_csr_rdata_reg = mhpmevent[28];
        `CSR_ADDR_MHPMENVENT29      : WB_ID_csr_rdata_reg = mhpmevent[29];
        `CSR_ADDR_MHPMENVENT30      : WB_ID_csr_rdata_reg = mhpmevent[30];
        `CSR_ADDR_MHPMENVENT31      : WB_ID_csr_rdata_reg = mhpmevent[31];
        `CSR_ADDR_MCOUNTEREN        : WB_ID_csr_rdata_reg = mcounteren;
        `CSR_ADDR_MCOUNTINHIBIT     : WB_ID_csr_rdata_reg = mcountinhibit;
        `CSR_ADDR_MSCRATCH          : WB_ID_csr_rdata_reg = mscratch;
        `CSR_ADDR_MEPC              : WB_ID_csr_rdata_reg = mepc;
        `CSR_ADDR_MCAUSE            : WB_ID_csr_rdata_reg = mcause;
        `CSR_ADDR_MTVAL             : WB_ID_csr_rdata_reg = mtval;
        `CSR_ADDR_MCONFIGPTR        : WB_ID_csr_rdata_reg = mconfigptr;
        `CSR_ADDR_MENVCFG           : WB_ID_csr_rdata_reg = menvcfg;
        `CSR_ADDR_MSECCFG           : WB_ID_csr_rdata_reg = mseccfg;
        `CSR_ADDR_SSTATUS           : WB_ID_csr_rdata_reg = sstatus;
        `CSR_ADDR_STVEC             : WB_ID_csr_rdata_reg = stvec;
        `CSR_ADDR_SIP               : WB_ID_csr_rdata_reg = sip;
        `CSR_ADDR_SIE               : WB_ID_csr_rdata_reg = sie;
        `CSR_ADDR_SCOUNTEREN        : WB_ID_csr_rdata_reg = scounteren;
        `CSR_ADDR_SSCRATCH          : WB_ID_csr_rdata_reg = sscratch;
        `CSR_ADDR_SEPC              : WB_ID_csr_rdata_reg = sepc;
        `CSR_ADDR_SCAUSE            : WB_ID_csr_rdata_reg = scause;
        `CSR_ADDR_STVAL             : WB_ID_csr_rdata_reg = stval;
        `CSR_ADDR_SENVCFG           : WB_ID_csr_rdata_reg = senvcfg;
        `CSR_ADDR_SATP              : WB_ID_csr_rdata_reg = satp;
        `CSR_ADDR_CYCLE             : WB_ID_csr_rdata_reg = Performance_Monitor[1];
        `CSR_ADDR_INSTRET           : WB_ID_csr_rdata_reg = Performance_Monitor[2];
        `CSR_ADDR_HPMCOUNTER3       : WB_ID_csr_rdata_reg = Performance_Monitor[3];
        `CSR_ADDR_HPMCOUNTER4       : WB_ID_csr_rdata_reg = Performance_Monitor[4];
        `CSR_ADDR_HPMCOUNTER5       : WB_ID_csr_rdata_reg = Performance_Monitor[5];
        `CSR_ADDR_HPMCOUNTER6       : WB_ID_csr_rdata_reg = Performance_Monitor[6];
        `CSR_ADDR_HPMCOUNTER7       : WB_ID_csr_rdata_reg = Performance_Monitor[7];
        `CSR_ADDR_HPMCOUNTER8       : WB_ID_csr_rdata_reg = Performance_Monitor[8];
        `CSR_ADDR_HPMCOUNTER9       : WB_ID_csr_rdata_reg = Performance_Monitor[9];
        `CSR_ADDR_HPMCOUNTER10      : WB_ID_csr_rdata_reg = Performance_Monitor[10];
        `CSR_ADDR_HPMCOUNTER11      : WB_ID_csr_rdata_reg = Performance_Monitor[11];
        `CSR_ADDR_HPMCOUNTER12      : WB_ID_csr_rdata_reg = Performance_Monitor[12];
        `CSR_ADDR_HPMCOUNTER13      : WB_ID_csr_rdata_reg = Performance_Monitor[13];
        `CSR_ADDR_HPMCOUNTER14      : WB_ID_csr_rdata_reg = Performance_Monitor[14];
        `CSR_ADDR_HPMCOUNTER15      : WB_ID_csr_rdata_reg = Performance_Monitor[15];
        `CSR_ADDR_HPMCOUNTER16      : WB_ID_csr_rdata_reg = Performance_Monitor[16];
        `CSR_ADDR_HPMCOUNTER17      : WB_ID_csr_rdata_reg = Performance_Monitor[17];
        `CSR_ADDR_HPMCOUNTER18      : WB_ID_csr_rdata_reg = Performance_Monitor[18];
        `CSR_ADDR_HPMCOUNTER19      : WB_ID_csr_rdata_reg = Performance_Monitor[19];
        `CSR_ADDR_HPMCOUNTER20      : WB_ID_csr_rdata_reg = Performance_Monitor[20];
        `CSR_ADDR_HPMCOUNTER21      : WB_ID_csr_rdata_reg = Performance_Monitor[21];
        `CSR_ADDR_HPMCOUNTER22      : WB_ID_csr_rdata_reg = Performance_Monitor[22];
        `CSR_ADDR_HPMCOUNTER23      : WB_ID_csr_rdata_reg = Performance_Monitor[23];
        `CSR_ADDR_HPMCOUNTER24      : WB_ID_csr_rdata_reg = Performance_Monitor[24];
        `CSR_ADDR_HPMCOUNTER25      : WB_ID_csr_rdata_reg = Performance_Monitor[25];
        `CSR_ADDR_HPMCOUNTER26      : WB_ID_csr_rdata_reg = Performance_Monitor[26];
        `CSR_ADDR_HPMCOUNTER27      : WB_ID_csr_rdata_reg = Performance_Monitor[27];
        `CSR_ADDR_HPMCOUNTER28      : WB_ID_csr_rdata_reg = Performance_Monitor[28];
        `CSR_ADDR_HPMCOUNTER29      : WB_ID_csr_rdata_reg = Performance_Monitor[29];
        `CSR_ADDR_HPMCOUNTER30      : WB_ID_csr_rdata_reg = Performance_Monitor[30];
        `CSR_ADDR_HPMCOUNTER31      : WB_ID_csr_rdata_reg = Performance_Monitor[31];
        `CSR_ADDR_DCSR              : WB_ID_csr_rdata_reg = dcsr;
        `CSR_ADDR_DPC               : WB_ID_csr_rdata_reg = dpc;
        `CSR_ADDR_DSCRATCH0         : WB_ID_csr_rdata_reg = dscratch0;
        `CSR_ADDR_DSCRATCH1         : WB_ID_csr_rdata_reg = dscratch1;
        default: WB_ID_csr_rdata_reg = 64'h0;
    endcase
end
always @(*) begin
    case (LS_WB_reg_csr_addr)
        `CSR_ADDR_MISA              : csr_rdata_reg = misa;
        `CSR_ADDR_MVENDORID         : csr_rdata_reg = mvendorid;
        `CSR_ADDR_MARCHID           : csr_rdata_reg = marchid;
        `CSR_ADDR_MIMPID            : csr_rdata_reg = mimpid;
        `CSR_ADDR_MHARTID           : csr_rdata_reg = mhartid;
        `CSR_ADDR_MSTATUS           : csr_rdata_reg = mstatus;
        `CSR_ADDR_MTVEC             : csr_rdata_reg = mtvec;
        `CSR_ADDR_MEDELEG           : csr_rdata_reg = medeleg;
        `CSR_ADDR_MIDELEG           : csr_rdata_reg = mideleg;
        `CSR_ADDR_MIP               : csr_rdata_reg = mip;
        `CSR_ADDR_MIE               : csr_rdata_reg = mie;
        `CSR_ADDR_MCYCLE            : csr_rdata_reg = Performance_Monitor[1];
        `CSR_ADDR_MINSTRET          : csr_rdata_reg = Performance_Monitor[2];
        `CSR_ADDR_MHPMCOUNTER3      : csr_rdata_reg = Performance_Monitor[3];
        `CSR_ADDR_MHPMCOUNTER4      : csr_rdata_reg = Performance_Monitor[4];
        `CSR_ADDR_MHPMCOUNTER5      : csr_rdata_reg = Performance_Monitor[5];
        `CSR_ADDR_MHPMCOUNTER6      : csr_rdata_reg = Performance_Monitor[6];
        `CSR_ADDR_MHPMCOUNTER7      : csr_rdata_reg = Performance_Monitor[7];
        `CSR_ADDR_MHPMCOUNTER8      : csr_rdata_reg = Performance_Monitor[8];
        `CSR_ADDR_MHPMCOUNTER9      : csr_rdata_reg = Performance_Monitor[9];
        `CSR_ADDR_MHPMCOUNTER10     : csr_rdata_reg = Performance_Monitor[10];
        `CSR_ADDR_MHPMCOUNTER11     : csr_rdata_reg = Performance_Monitor[11];
        `CSR_ADDR_MHPMCOUNTER12     : csr_rdata_reg = Performance_Monitor[12];
        `CSR_ADDR_MHPMCOUNTER13     : csr_rdata_reg = Performance_Monitor[13];
        `CSR_ADDR_MHPMCOUNTER14     : csr_rdata_reg = Performance_Monitor[14];
        `CSR_ADDR_MHPMCOUNTER15     : csr_rdata_reg = Performance_Monitor[15];
        `CSR_ADDR_MHPMCOUNTER16     : csr_rdata_reg = Performance_Monitor[16];
        `CSR_ADDR_MHPMCOUNTER17     : csr_rdata_reg = Performance_Monitor[17];
        `CSR_ADDR_MHPMCOUNTER18     : csr_rdata_reg = Performance_Monitor[18];
        `CSR_ADDR_MHPMCOUNTER19     : csr_rdata_reg = Performance_Monitor[19];
        `CSR_ADDR_MHPMCOUNTER20     : csr_rdata_reg = Performance_Monitor[20];
        `CSR_ADDR_MHPMCOUNTER21     : csr_rdata_reg = Performance_Monitor[21];
        `CSR_ADDR_MHPMCOUNTER22     : csr_rdata_reg = Performance_Monitor[22];
        `CSR_ADDR_MHPMCOUNTER23     : csr_rdata_reg = Performance_Monitor[23];
        `CSR_ADDR_MHPMCOUNTER24     : csr_rdata_reg = Performance_Monitor[24];
        `CSR_ADDR_MHPMCOUNTER25     : csr_rdata_reg = Performance_Monitor[25];
        `CSR_ADDR_MHPMCOUNTER26     : csr_rdata_reg = Performance_Monitor[26];
        `CSR_ADDR_MHPMCOUNTER27     : csr_rdata_reg = Performance_Monitor[27];
        `CSR_ADDR_MHPMCOUNTER28     : csr_rdata_reg = Performance_Monitor[28];
        `CSR_ADDR_MHPMCOUNTER29     : csr_rdata_reg = Performance_Monitor[29];
        `CSR_ADDR_MHPMCOUNTER30     : csr_rdata_reg = Performance_Monitor[30];
        `CSR_ADDR_MHPMCOUNTER31     : csr_rdata_reg = Performance_Monitor[31];
        `CSR_ADDR_MHPMENVENT3       : csr_rdata_reg = mhpmevent[3];
        `CSR_ADDR_MHPMENVENT4       : csr_rdata_reg = mhpmevent[4];
        `CSR_ADDR_MHPMENVENT5       : csr_rdata_reg = mhpmevent[5];
        `CSR_ADDR_MHPMENVENT6       : csr_rdata_reg = mhpmevent[6];
        `CSR_ADDR_MHPMENVENT7       : csr_rdata_reg = mhpmevent[7];
        `CSR_ADDR_MHPMENVENT8       : csr_rdata_reg = mhpmevent[8];
        `CSR_ADDR_MHPMENVENT9       : csr_rdata_reg = mhpmevent[9];
        `CSR_ADDR_MHPMENVENT10      : csr_rdata_reg = mhpmevent[10];
        `CSR_ADDR_MHPMENVENT11      : csr_rdata_reg = mhpmevent[11];
        `CSR_ADDR_MHPMENVENT12      : csr_rdata_reg = mhpmevent[12];
        `CSR_ADDR_MHPMENVENT13      : csr_rdata_reg = mhpmevent[13];
        `CSR_ADDR_MHPMENVENT14      : csr_rdata_reg = mhpmevent[14];
        `CSR_ADDR_MHPMENVENT15      : csr_rdata_reg = mhpmevent[15];
        `CSR_ADDR_MHPMENVENT16      : csr_rdata_reg = mhpmevent[16];
        `CSR_ADDR_MHPMENVENT17      : csr_rdata_reg = mhpmevent[17];
        `CSR_ADDR_MHPMENVENT18      : csr_rdata_reg = mhpmevent[18];
        `CSR_ADDR_MHPMENVENT19      : csr_rdata_reg = mhpmevent[19];
        `CSR_ADDR_MHPMENVENT20      : csr_rdata_reg = mhpmevent[20];
        `CSR_ADDR_MHPMENVENT21      : csr_rdata_reg = mhpmevent[21];
        `CSR_ADDR_MHPMENVENT22      : csr_rdata_reg = mhpmevent[22];
        `CSR_ADDR_MHPMENVENT23      : csr_rdata_reg = mhpmevent[23];
        `CSR_ADDR_MHPMENVENT24      : csr_rdata_reg = mhpmevent[24];
        `CSR_ADDR_MHPMENVENT25      : csr_rdata_reg = mhpmevent[25];
        `CSR_ADDR_MHPMENVENT26      : csr_rdata_reg = mhpmevent[26];
        `CSR_ADDR_MHPMENVENT27      : csr_rdata_reg = mhpmevent[27];
        `CSR_ADDR_MHPMENVENT28      : csr_rdata_reg = mhpmevent[28];
        `CSR_ADDR_MHPMENVENT29      : csr_rdata_reg = mhpmevent[29];
        `CSR_ADDR_MHPMENVENT30      : csr_rdata_reg = mhpmevent[30];
        `CSR_ADDR_MHPMENVENT31      : csr_rdata_reg = mhpmevent[31];
        `CSR_ADDR_MCOUNTEREN        : csr_rdata_reg = mcounteren;
        `CSR_ADDR_MCOUNTINHIBIT     : csr_rdata_reg = mcountinhibit;
        `CSR_ADDR_MSCRATCH          : csr_rdata_reg = mscratch;
        `CSR_ADDR_MEPC              : csr_rdata_reg = mepc;
        `CSR_ADDR_MCAUSE            : csr_rdata_reg = mcause;
        `CSR_ADDR_MTVAL             : csr_rdata_reg = mtval;
        `CSR_ADDR_MCONFIGPTR        : csr_rdata_reg = mconfigptr;
        `CSR_ADDR_MENVCFG           : csr_rdata_reg = menvcfg;
        `CSR_ADDR_MSECCFG           : csr_rdata_reg = mseccfg;
        `CSR_ADDR_SSTATUS           : csr_rdata_reg = sstatus;
        `CSR_ADDR_STVEC             : csr_rdata_reg = stvec;
        `CSR_ADDR_SIP               : csr_rdata_reg = sip;
        `CSR_ADDR_SIE               : csr_rdata_reg = sie;
        `CSR_ADDR_SCOUNTEREN        : csr_rdata_reg = scounteren;
        `CSR_ADDR_SSCRATCH          : csr_rdata_reg = sscratch;
        `CSR_ADDR_SEPC              : csr_rdata_reg = sepc;
        `CSR_ADDR_SCAUSE            : csr_rdata_reg = scause;
        `CSR_ADDR_STVAL             : csr_rdata_reg = stval;
        `CSR_ADDR_SENVCFG           : csr_rdata_reg = senvcfg;
        `CSR_ADDR_SATP              : csr_rdata_reg = satp;
        `CSR_ADDR_CYCLE             : csr_rdata_reg = Performance_Monitor[1];
        `CSR_ADDR_INSTRET           : csr_rdata_reg = Performance_Monitor[2];
        `CSR_ADDR_HPMCOUNTER3       : csr_rdata_reg = Performance_Monitor[3];
        `CSR_ADDR_HPMCOUNTER4       : csr_rdata_reg = Performance_Monitor[4];
        `CSR_ADDR_HPMCOUNTER5       : csr_rdata_reg = Performance_Monitor[5];
        `CSR_ADDR_HPMCOUNTER6       : csr_rdata_reg = Performance_Monitor[6];
        `CSR_ADDR_HPMCOUNTER7       : csr_rdata_reg = Performance_Monitor[7];
        `CSR_ADDR_HPMCOUNTER8       : csr_rdata_reg = Performance_Monitor[8];
        `CSR_ADDR_HPMCOUNTER9       : csr_rdata_reg = Performance_Monitor[9];
        `CSR_ADDR_HPMCOUNTER10      : csr_rdata_reg = Performance_Monitor[10];
        `CSR_ADDR_HPMCOUNTER11      : csr_rdata_reg = Performance_Monitor[11];
        `CSR_ADDR_HPMCOUNTER12      : csr_rdata_reg = Performance_Monitor[12];
        `CSR_ADDR_HPMCOUNTER13      : csr_rdata_reg = Performance_Monitor[13];
        `CSR_ADDR_HPMCOUNTER14      : csr_rdata_reg = Performance_Monitor[14];
        `CSR_ADDR_HPMCOUNTER15      : csr_rdata_reg = Performance_Monitor[15];
        `CSR_ADDR_HPMCOUNTER16      : csr_rdata_reg = Performance_Monitor[16];
        `CSR_ADDR_HPMCOUNTER17      : csr_rdata_reg = Performance_Monitor[17];
        `CSR_ADDR_HPMCOUNTER18      : csr_rdata_reg = Performance_Monitor[18];
        `CSR_ADDR_HPMCOUNTER19      : csr_rdata_reg = Performance_Monitor[19];
        `CSR_ADDR_HPMCOUNTER20      : csr_rdata_reg = Performance_Monitor[20];
        `CSR_ADDR_HPMCOUNTER21      : csr_rdata_reg = Performance_Monitor[21];
        `CSR_ADDR_HPMCOUNTER22      : csr_rdata_reg = Performance_Monitor[22];
        `CSR_ADDR_HPMCOUNTER23      : csr_rdata_reg = Performance_Monitor[23];
        `CSR_ADDR_HPMCOUNTER24      : csr_rdata_reg = Performance_Monitor[24];
        `CSR_ADDR_HPMCOUNTER25      : csr_rdata_reg = Performance_Monitor[25];
        `CSR_ADDR_HPMCOUNTER26      : csr_rdata_reg = Performance_Monitor[26];
        `CSR_ADDR_HPMCOUNTER27      : csr_rdata_reg = Performance_Monitor[27];
        `CSR_ADDR_HPMCOUNTER28      : csr_rdata_reg = Performance_Monitor[28];
        `CSR_ADDR_HPMCOUNTER29      : csr_rdata_reg = Performance_Monitor[29];
        `CSR_ADDR_HPMCOUNTER30      : csr_rdata_reg = Performance_Monitor[30];
        `CSR_ADDR_HPMCOUNTER31      : csr_rdata_reg = Performance_Monitor[31];
        `CSR_ADDR_DCSR              : csr_rdata_reg = dcsr;
        `CSR_ADDR_DPC               : csr_rdata_reg = dpc;
        `CSR_ADDR_DSCRATCH0         : csr_rdata_reg = dscratch0;
        `CSR_ADDR_DSCRATCH1         : csr_rdata_reg = dscratch1;
        default: csr_rdata_reg = 64'h0;
    endcase
end
assign WB_ID_csr_rdata      = WB_ID_csr_rdata_reg;
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
assign WB_EX_interrupt_flag = (interrupt_m_flag | interrupt_s_flag | interrupt_debug_flag);
//**********************************************************************************************

endmodule //csr

module csr_misa(
    output [63:0]           misa
);

assign misa = 64'h8000_0000_0014_1105; 

endmodule //csr_misa

module csr_mvendorid(
    output [63:0]           mvendorid
);

assign mvendorid = 64'h0;

endmodule //csr_mvendorid

module csr_marchid (
    output [63:0]           marchid
);

assign marchid = 64'h0;

endmodule //csr_marchid

module csr_mimpid (
    output [63:0]           mimpid
);

assign mimpid = 64'h79_73_79_78_5F_6C_62_78;

endmodule //csr_mimpid

module csr_mhartid#(parameter MHARTID = 0) (
    output [63:0]           mhartid
);

assign mhartid = MHARTID;

endmodule //csr_mhartid

module csr_mconfigptr(
    output [63:0]           mconfigptr
);

assign mconfigptr = 64'h0;

endmodule //csr_mconfigptr

module csr_mstatus(
    input                   clk,
    input                   rst_n,
    input                   csr_mstatus_wen,
    input                   csr_sstatus_wen,
    input                   trap_m_mode_valid,
    input                   trap_s_mode_valid,
    input                   trap_debug_mode_valid,
    input  [1:0]            dcsr_prv,
    input                   LS_WB_reg_ls_valid,
    input                   LS_WB_reg_mret_valid,
    input                   LS_WB_reg_sret_valid,
    input                   LS_WB_reg_dret_valid,
    input  [63:0]           csr_wdata,
    output                  mstatus_TSR,
    output                  mstatus_TW,    
    output                  mstatus_TVM,
    output                  mstatus_MXR,
    output                  mstatus_SUM,
    output                  mstatus_MPRV,
    output [1:0]            mstatus_MPP,
    output                  mstatus_MIE,
    output                  mstatus_SIE,
    output [1:0]            current_priv_status,
    output [63:0]           mstatus,
    output [63:0]           sstatus
);

reg             TSR;
reg             TW;
reg             TVM;
reg             MXR;
reg             SUM;
reg             MPRV;
reg [1:0]       MPP;
reg             SPP;
reg             MPIE;
reg             SPIE;
reg             MIE;
reg             SIE;
reg [1:0]       current_priv_status_reg;

always @(posedge clk or negedge rst_n) begin
    if(!rst_n)begin
        TSR                     <= 1'b0;
        TW                      <= 1'b0;
        TVM                     <= 1'b0;
        MXR                     <= 1'b0;
        SUM                     <= 1'b0;
        MPRV                    <= 1'b0;
        MPP                     <= 2'h3;
        SPP                     <= 1'b0;
        MPIE                    <= 1'b0;
        SPIE                    <= 1'b0;
        MIE                     <= 1'b0;
        SIE                     <= 1'b0;
    end
    else if(csr_mstatus_wen)begin
        TSR     <= csr_wdata[22];
        TW      <= csr_wdata[21];
        TVM     <= csr_wdata[20];
        MXR     <= csr_wdata[19];
        SUM     <= csr_wdata[18];
        MPRV    <= csr_wdata[17];
        MPP     <= csr_wdata[12:11];
        SPP     <= csr_wdata[8];
        MPIE    <= csr_wdata[7];
        SPIE    <= csr_wdata[5];
        MIE     <= csr_wdata[3];
        SIE     <= csr_wdata[1];
    end
    else if(csr_sstatus_wen)begin
        MXR     <= csr_wdata[19];
        SUM     <= csr_wdata[18];
        SPP     <= csr_wdata[8];
        SPIE    <= csr_wdata[5];
        SIE     <= csr_wdata[1];
    end
    else if(trap_m_mode_valid)begin
        MPP                     <= current_priv_status;
        MPIE                    <= MIE;
        MIE                     <= 1'b0;
    end
    else if(trap_s_mode_valid)begin
        SPP                     <= (current_priv_status == 2'h1);
        SPIE                    <= SIE;
        SIE                     <= 1'b0;
    end
    else if(LS_WB_reg_ls_valid & LS_WB_reg_mret_valid)begin
        MPRV                    <= ((MPP == `PRV_M) & MPRV);
        MPP                     <= 2'h0;
        MPIE                    <= 1'b1;
        MIE                     <= MPIE;
    end
    else if(LS_WB_reg_ls_valid & LS_WB_reg_sret_valid)begin
        MPRV                    <= 1'b0;
        SPP                     <= 1'b0;
        SPIE                    <= 1'b1;
        SIE                     <= SPIE;
    end
    else if(LS_WB_reg_ls_valid & LS_WB_reg_dret_valid)begin
        MPRV                    <= ((dcsr_prv == `PRV_M) & MPRV);
    end
end

always @(posedge clk or negedge rst_n) begin
    if(!rst_n)begin
        current_priv_status_reg <= 2'h3;
    end
    else if(trap_debug_mode_valid)begin
        current_priv_status_reg <= 2'h3;
    end
    else if(trap_m_mode_valid)begin
        current_priv_status_reg <= 2'h3;
    end
    else if(trap_s_mode_valid)begin
        current_priv_status_reg <= 2'h1;
    end
    else if(LS_WB_reg_ls_valid & LS_WB_reg_mret_valid)begin
        current_priv_status_reg <= MPP;
    end
    else if(LS_WB_reg_ls_valid & LS_WB_reg_sret_valid)begin
        current_priv_status_reg <= {1'b0, SPP};
    end
    else if(LS_WB_reg_ls_valid & LS_WB_reg_dret_valid)begin
        current_priv_status_reg <= dcsr_prv;
    end
end

assign mstatus_TSR      = TSR;
assign mstatus_TW       = TW;    
assign mstatus_TVM      = TVM;
assign mstatus_MXR      = MXR;
assign mstatus_SUM      = SUM;
assign mstatus_MPRV     = MPRV;
assign mstatus_MPP      = MPP;
assign mstatus_MIE      = MIE;
assign mstatus_SIE      = SIE;
assign current_priv_status = current_priv_status_reg;

assign mstatus = {/*SD*/1'b0, /*WPRI*/25'h0, /*MBE*/1'b0, /*SBE*/1'b0, /*SXL*/2'b10, /*UXL*/2'b10, 
                    /*WPRI*/9'h0, /*TSR*/TSR, /*TW*/TW, /*TVM*/TVM, /*MXR*/MXR, /*SUM*/SUM, /*MPRV*/MPRV, 
                    /*XS*/2'h0, /*FS*/2'h0, /*MPP*/MPP, /*VS*/2'h0, /*SPP*/SPP, /*MPIE*/MPIE, /*UBE*/1'b0, 
                    /*SPIE*/SPIE, /*WPRI*/1'b0, /*MIE*/MIE, /*WPRI*/1'b0, /*SIE*/SIE, /*WPRI*/1'b0};

assign sstatus = mstatus & 64'h8000_0003_000D_E762;

endmodule //csr_mstatus

module csr_mtvec#(parameter RST_PC=64'h0)(
    input                   clk,
    input                   rst_n,
    input                   csr_mtvec_wen,
    input  [63:0]           csr_wdata,
    output [63:0]           mtvec
);

reg  [63:0]     mtvec_reg;

always @(posedge clk or negedge rst_n) begin
    if(!rst_n)begin
        mtvec_reg <= RST_PC;
    end
    else if(csr_mtvec_wen)begin
        if(csr_wdata[1:0] == 2'h1)begin
            mtvec_reg <= csr_wdata;
        end
        else begin
            mtvec_reg <= {csr_wdata[63:2],2'h0};
        end
    end
end

assign mtvec = mtvec_reg;

endmodule //csr_mtvec

module csr_medeleg(
    input                   clk,
    input                   rst_n,
    input                   csr_medeleg_wen,
    input  [63:0]           csr_wdata,
    output [63:0]           medeleg
);

reg     instruction_addr_misalign;
reg     instruction_access_error;
reg     illegal_instruction;
reg     breakpoint;
reg     load_addr_misalign;
reg     load_access_error;
reg     store_addr_misalign;
reg     store_access_error;
reg     ecall_U;
reg     ecall_S;
reg     ecall_M;
reg     instruction_page_error;
reg     load_page_error;
reg     store_page_error;

always @(posedge clk or negedge rst_n) begin
    if(!rst_n)begin
        instruction_addr_misalign   <= 1'b0;
        instruction_access_error    <= 1'b0;
        illegal_instruction         <= 1'b0;
        breakpoint                  <= 1'b0;
        load_addr_misalign          <= 1'b0;
        load_access_error           <= 1'b0;
        store_addr_misalign         <= 1'b0;
        store_access_error          <= 1'b0;
        ecall_U                     <= 1'b0;
        ecall_S                     <= 1'b0;
        ecall_M                     <= 1'b0;
        instruction_page_error      <= 1'b0;
        load_page_error             <= 1'b0;
        store_page_error            <= 1'b0;
    end
    else if(csr_medeleg_wen)begin
        instruction_addr_misalign   <= csr_wdata[0];
        instruction_access_error    <= csr_wdata[1];
        illegal_instruction         <= csr_wdata[2];
        breakpoint                  <= csr_wdata[3];
        load_addr_misalign          <= csr_wdata[4];
        load_access_error           <= csr_wdata[5];
        store_addr_misalign         <= csr_wdata[6];
        store_access_error          <= csr_wdata[7];
        ecall_U                     <= csr_wdata[8];
        ecall_S                     <= csr_wdata[9];
        ecall_M                     <= csr_wdata[11];
        instruction_page_error      <= csr_wdata[12];
        load_page_error             <= csr_wdata[13];
        store_page_error            <= csr_wdata[15];
    end
end

assign medeleg = {48'h0, store_page_error, 1'b0, load_page_error, instruction_page_error, 
                    ecall_M, 1'b0, ecall_S, ecall_U, store_access_error, store_addr_misalign, 
                    load_access_error, load_addr_misalign, breakpoint, illegal_instruction, 
                    instruction_access_error, instruction_addr_misalign};

endmodule //csr_medeleg

module csr_mideleg(
    input                   clk,
    input                   rst_n,
    input                   csr_mideleg_wen,
    input  [63:0]           csr_wdata,
    output [63:0]           mideleg
);

reg     MTI,MEI,MSI;
reg     STI,SEI,SSI;

always @(posedge clk or negedge rst_n) begin
    if(!rst_n)begin
        STI <= 1'b0;
        SEI <= 1'b0;
        SSI <= 1'b0;
        MTI <= 1'b0;
        MEI <= 1'b0;
        MSI <= 1'b0;
    end
    else if(csr_mideleg_wen)begin
        STI <= csr_wdata[5];
        SEI <= csr_wdata[9];
        SSI <= csr_wdata[1];
        MTI <= csr_wdata[7];
        MEI <= csr_wdata[11];
        MSI <= csr_wdata[3];
    end
end

assign mideleg = {52'h0, MEI, 1'h0, SEI, 1'h0, MTI, 1'h0, STI, 1'h0, MSI, 1'h0, SSI, 1'b0};

endmodule //csr_mideleg

module csr_mip(
    input                   clk,
    input                   rst_n,
    input                   stip,
    input                   seip,
    input                   ssip,
    input                   mtip,
    input                   meip,
    input                   msip,
    input                   csr_mip_wen,
    input                   csr_sip_wen,
    input  [63:0]           csr_wdata,
    input  [63:0]           mideleg,
    output [63:0]           mip,
    output [63:0]           sip
);

reg     STIP,SEIP,SSIP;

always @(posedge clk or negedge rst_n) begin
    if(!rst_n)begin
        STIP <= 1'b0;
        SEIP <= 1'b0;
        SSIP <= 1'b0;
    end
    else if(csr_mip_wen)begin
        STIP <= csr_wdata[5];
        SEIP <= csr_wdata[9];
        SSIP <= csr_wdata[1];
    end
    else if(csr_sip_wen)begin
        if(mideleg[5])STIP <= csr_wdata[5];
        if(mideleg[9])SEIP <= csr_wdata[9];
        if(mideleg[1])SSIP <= csr_wdata[1];
    end
end

assign mip = {52'h0, meip, 1'b0, (seip | SEIP), 1'b0, mtip, 1'b0, (stip | STIP), 1'b0, msip, 1'b0, (ssip | SSIP), 1'b0};
assign sip = mip & mideleg;

endmodule //csr_mip

module csr_mie(
    input                   clk,
    input                   rst_n,
    input                   csr_mie_wen,
    input                   csr_sie_wen,
    input  [63:0]           csr_wdata,
    input  [63:0]           mideleg,
    output [63:0]           mie,
    output [63:0]           sie
);

reg     STIE,SEIE,SSIE;
reg     MTIE,MEIE,MSIE;

always @(posedge clk or negedge rst_n) begin
    if(!rst_n)begin
        STIE <= 1'b0;
        SEIE <= 1'b0;
        SSIE <= 1'b0;
        MTIE <= 1'b0;
        MEIE <= 1'b0;
        MSIE <= 1'b0;
    end
    else if(csr_mie_wen)begin
        STIE <= csr_wdata[5];
        SEIE <= csr_wdata[9];
        SSIE <= csr_wdata[1];
        MTIE <= csr_wdata[7];
        MEIE <= csr_wdata[11];
        MSIE <= csr_wdata[3];
    end
    else if(csr_sie_wen)begin
        if(mideleg[5] )STIE <= csr_wdata[5];
        if(mideleg[9] )SEIE <= csr_wdata[9];
        if(mideleg[1] )SSIE <= csr_wdata[1];
        if(mideleg[7] )MTIE <= csr_wdata[7];
        if(mideleg[11])MEIE <= csr_wdata[11];
        if(mideleg[3] )MSIE <= csr_wdata[3];
    end
end

assign mie = {52'h0, MEIE, 1'b0, SEIE, 1'b0, MTIE, 1'b0, STIE, 1'b0, MSIE, 1'b0, SSIE, 1'b0};
assign sie = mie & mideleg;

endmodule //csr_mie

module csr_MPerformance_Monitor(
    input                   clk,
    input                   csr_MPerformance_Monitor_wen,
    input                   MPerformance_Monitor_hibit,
    input                   MPerformance_Monitor_inc,
    input  [63:0]           csr_wdata,
    output [63:0]           MPerformance_Monitor
);

reg  [63:0]     MPerformance_Monitor_reg;

always @(posedge clk) begin
    if(csr_MPerformance_Monitor_wen)begin
        MPerformance_Monitor_reg <= csr_wdata;
    end
    else if((!MPerformance_Monitor_hibit) & MPerformance_Monitor_inc)begin
        MPerformance_Monitor_reg <= MPerformance_Monitor_reg + 1'b1;
    end
end

assign MPerformance_Monitor = MPerformance_Monitor_reg;

endmodule //csr_MPerformance_Monitor

module csr_mhpmevent(
    input                   clk,
    input                   csr_mhpmevent_wen,
    input  [63:0]           csr_wdata,
    output [63:0]           mhpmevent
);

reg [63:0]      mhpmevent_reg;

always @(posedge clk) begin
    if(csr_mhpmevent_wen)begin
        mhpmevent_reg <= csr_wdata;
    end
end

assign mhpmevent = mhpmevent_reg;

endmodule //csr_mhpmevent

module csr_mcounteren(
    output [63:0]           mcounteren
);

assign mcounteren = {32'h0, {30{1'b1}}, 1'b0, 1'b1};

endmodule //csr_mcounteren


module csr_mcountinhibit(
    input                   clk,
    input                   rst_n,
    input                   csr_mcountinhibit_wen,
    input  [63:0]           csr_wdata,
    output [63:0]           mcountinhibit
);

reg [31:1]      mcountinhibit_reg;

always @(posedge clk or negedge rst_n) begin
    if(!rst_n)begin
        mcountinhibit_reg <= 31'h0;
    end
    else if(csr_mcountinhibit_wen)begin
        mcountinhibit_reg <= {csr_wdata[31:2],csr_wdata[0]};
    end
end

assign mcountinhibit = {32'h0, mcountinhibit_reg[31:2], 1'b0, mcountinhibit_reg[1]};

endmodule //csr_mcountinhibit

module csr_mscratch(
    input                   clk,
    input                   csr_mscratch_wen,
    input  [63:0]           csr_wdata,
    output [63:0]           mscratch
);

reg [63:0]      mscratch_reg;

always @(posedge clk) begin
    if(csr_mscratch_wen)begin
        mscratch_reg <= csr_wdata;
    end
end

assign mscratch = mscratch_reg;

endmodule //csr_mscratch

module csr_mepc(
    input                   clk,
    input                   csr_mepc_wen,
    input                   trap_m_mode_valid,
    input  [63:0]           csr_wdata,
    input  [63:0]           epc,
    output [63:0]           mepc
);

reg [63:0]  mepc_reg;

always @(posedge clk) begin
    if(csr_mepc_wen)begin
        mepc_reg <= csr_wdata;
    end
    else if(trap_m_mode_valid)begin
        mepc_reg <= epc;
    end
end

assign mepc = {mepc_reg[63:1], 1'b0};

endmodule //csr_mepc

module csr_mcause(
    input                   clk,
    input                   csr_mcause_wen,
    input                   trap_m_mode_valid,
    input  [63:0]           csr_wdata,
    input  [63:0]           cause,
    output [63:0]           mcause
);

reg [63:0]  mcause_reg;

always @(posedge clk) begin
    if(csr_mcause_wen)begin
        mcause_reg <= csr_wdata;
    end
    else if(trap_m_mode_valid)begin
        mcause_reg <= cause;
    end
end

assign mcause = mcause_reg;

endmodule //csr_mcause

module csr_mtval(
    input                   clk,
    input                   csr_mtval_wen,
    input                   trap_m_mode_valid,
    input  [63:0]           csr_wdata,
    input  [63:0]           tval,
    output [63:0]           mtval
);

reg [63:0]  mtval_reg;

always @(posedge clk) begin
    if(csr_mtval_wen)begin
        mtval_reg <= csr_wdata;
    end
    else if(trap_m_mode_valid)begin
        mtval_reg <= tval;
    end
end

assign mtval = mtval_reg;

endmodule //csr_mtval

module csr_menvcfg(
    output [63:0]           menvcfg
);

assign menvcfg = 64'h0;

endmodule //csr_menvcfg

module csr_mseccfg(
    output [63:0]           mseccfg
);

assign mseccfg = 64'h0;

endmodule //csr_mseccfg

module csr_stvec#(parameter RST_PC=64'h0)(
    input                   clk,
    input                   rst_n,
    input                   csr_stvec_wen,
    input  [63:0]           csr_wdata,
    output [63:0]           stvec
);

reg  [63:0]     stvec_reg;

always @(posedge clk or negedge rst_n) begin
    if(!rst_n)begin
        stvec_reg <= RST_PC;
    end
    else if(csr_stvec_wen)begin
        if(csr_wdata[1:0] == 2'h1)begin
            stvec_reg <= csr_wdata;
        end
        else begin
            stvec_reg <= {csr_wdata[63:2],2'h0};
        end
    end
end

assign stvec = stvec_reg;

endmodule //csr_mtvec

module csr_scounteren(
    output [63:0]           scounteren
);

assign scounteren = 64'h0;

endmodule //csr_scounteren

module csr_sscratch(
    input                   clk,
    input                   csr_sscratch_wen,
    input  [63:0]           csr_wdata,
    output [63:0]           sscratch
);

reg [63:0]      sscratch_reg;

always @(posedge clk) begin
    if(csr_sscratch_wen)begin
        sscratch_reg <= csr_wdata;
    end
end

assign sscratch = sscratch_reg;

endmodule //csr_sscratch

module csr_sepc(
    input                   clk,
    input                   csr_sepc_wen,
    input                   trap_s_mode_valid,
    input  [63:0]           csr_wdata,
    input  [63:0]           epc,
    output [63:0]           sepc
);

reg [63:0]  sepc_reg;

always @(posedge clk) begin
    if(csr_sepc_wen)begin
        sepc_reg <= csr_wdata;
    end
    else if(trap_s_mode_valid)begin
        sepc_reg <= epc;
    end
end

assign sepc = {sepc_reg[63:1], 1'b0};

endmodule //csr_sepc

module csr_scause(
    input                   clk,
    input                   csr_scause_wen,
    input                   trap_s_mode_valid,
    input  [63:0]           csr_wdata,
    input  [63:0]           cause,
    output [63:0]           scause
);

reg [63:0]  scause_reg;

always @(posedge clk) begin
    if(csr_scause_wen)begin
        scause_reg <= csr_wdata;
    end
    else if(trap_s_mode_valid)begin
        scause_reg <= cause;
    end
end

assign scause = scause_reg;

endmodule //csr_scause

module csr_stval(
    input                   clk,
    input                   csr_stval_wen,
    input                   trap_s_mode_valid,
    input  [63:0]           csr_wdata,
    input  [63:0]           tval,
    output [63:0]           stval
);

reg [63:0]  stval_reg;

always @(posedge clk) begin
    if(csr_stval_wen)begin
        stval_reg <= csr_wdata;
    end
    else if(trap_s_mode_valid)begin
        stval_reg <= tval;
    end
end

assign stval = stval_reg;

endmodule //csr_stval

module csr_senvcfg(
    output [63:0]           senvcfg
);

assign senvcfg = 64'h0;

endmodule //csr_senvcfg

module csr_satp(
    input                   clk,
    input                   rst_n,
    input                   csr_satp_wen,
    input  [63:0]           csr_wdata,
    output [63:0]           satp
);

reg [63:0]      satp_reg;

always @(posedge clk or negedge rst_n) begin
    if(!rst_n)begin
        satp_reg <= 64'h0;
    end
    else if((csr_satp_wen) & ((csr_wdata[63:60] == 4'h0) | (csr_wdata[63:60] == 4'h8)))begin
        satp_reg <= csr_wdata;
    end
end

assign satp = satp_reg;

endmodule //csr_satp

module csr_dcsr(
    input                   clk,
    input                   rst_n,
    input  [2:0]            debug_cause,
    input  [1:0]            current_priv_status,
    input                   csr_dcsr_wen,
    input                   trap_debug_mode_valid,
    input                   LS_WB_reg_ls_valid,
    input                   LS_WB_reg_trap_valid,
    input                   LS_WB_reg_dret_valid,
    input  [63:0]           csr_wdata,
    output                  debug_mode,
    output                  dcsr_ebreakm,
    output                  dcsr_ebreaks,
    output                  dcsr_ebreaku,
    output                  dcsr_step,
    output [1:0]            dcsr_prv,
    output [63:0]           dcsr
);

reg             ebreakm;
reg             ebreaks;
reg             ebreaku;
reg [2:0]       cause;
reg             step;
reg [1:0]       prv;
reg             debug_mode_reg;

always @(posedge clk or negedge rst_n) begin
    if(!rst_n)begin
        ebreakm <= 1'h0;
        ebreaks <= 1'h0;
        ebreaku <= 1'h0;
        cause   <= 3'h0;
        step    <= 1'h0;
        prv     <= 2'h3;
    end
    else if(csr_dcsr_wen)begin
        ebreakm <= csr_wdata[15];
        ebreaks <= csr_wdata[13];
        ebreaku <= csr_wdata[12];
        cause   <= csr_wdata[8:6];
        step    <= csr_wdata[2];
        prv     <= csr_wdata[1:0];
    end
    else if(trap_debug_mode_valid)begin
        cause   <= debug_cause;
        prv     <= current_priv_status;
    end
end

always @(posedge clk or negedge rst_n) begin
    if(!rst_n)begin
        debug_mode_reg <= 1'b0;
    end
    else if(trap_debug_mode_valid)begin
        debug_mode_reg <= 1'b1;
    end
    else if(LS_WB_reg_ls_valid & LS_WB_reg_dret_valid & (!LS_WB_reg_trap_valid))begin
        debug_mode_reg <= 1'b0;
    end
end

assign debug_mode = debug_mode_reg;
assign dcsr_ebreakm = ebreakm;
assign dcsr_ebreaks = ebreaks;
assign dcsr_ebreaku = ebreaku;
assign dcsr_step    = step;
assign dcsr_prv     = prv;

assign dcsr = {32'h0, 4'h4/* debugver */, 1'b0, 3'h0/* ext_cause */, 4'h0, 1'b0/* cetrig */, 1'b0, 
            1'b0/* ebreakvs */, 1'b0/* ebreakvu */, ebreakm, 1'b0, ebreaks, ebreaku, 1'b1/* stepie */, 
            1'b0/* stopcount */, 1'b0/* stoptime */, cause, 1'b0/* v */, 1'b1/* mprven */, 1'b0/* nmip */, step, prv};

endmodule //csr_dcsr

module csr_dpc(
    input                   clk,
    input                   csr_dpc_wen,
    input                   trap_debug_mode_valid,
    input  [63:0]           csr_wdata,
    input  [63:0]           epc,
    output [63:0]           dpc
);

reg [63:0]  dpc_reg;

always @(posedge clk) begin
    if(csr_dpc_wen)begin
        dpc_reg <= csr_wdata;
    end
    else if(trap_debug_mode_valid)begin
        dpc_reg <= epc;
    end
end

assign dpc = {dpc_reg[63:1], 1'b0};

endmodule //csr_dpc

module csr_dscratch(
    input                   clk,
    input                   csr_dscratch_wen,
    input  [63:0]           csr_wdata,
    output [63:0]           dscratch
);

reg [63:0]      dscratch_reg;

always @(posedge clk) begin
    if(csr_dscratch_wen)begin
        dscratch_reg <= csr_wdata;
    end
end

assign dscratch = dscratch_reg;

endmodule //csr_dscratch

module interrupt_control(
    input                   clk,
    input                   rst_n,
    input                   mstatus_MIE,
    input                   mstatus_SIE,
    input  [1:0]            current_priv_status,
    input  [63:0]           mip,
    input  [63:0]           sip,
    input  [63:0]           mie,
    input  [63:0]           sie,
    input                   halt_req,
    input                   debug_mode,
    input                   dcsr_step,
    input                   EX_LS_reg_execute_valid,
    input                   LS_WB_reg_ls_valid,
    input                   LS_WB_reg_trap_valid,
    input                   LS_WB_reg_dret_valid,
    input                   trap_debug_mode_valid,
    output                  interrupt_m_flag,
    output                  interrupt_s_flag,
    output                  interrupt_debug_flag,
    output [63:0]           interrupt_cause,
    output [2:0]            interrupt_debug_cause
);

wire            m_mode_interrupt_enable;
wire            s_mode_interrupt_enable;
wire [63:0]     m_mode_interrupt_pending;
wire [63:0]     s_mode_interrupt_pending;

reg  [1:0]      debug_step_flag;

always @(posedge clk or negedge rst_n) begin
    if(!rst_n)begin
        debug_step_flag <= 2'h0;
    end
    else if(LS_WB_reg_ls_valid & LS_WB_reg_dret_valid & (!LS_WB_reg_trap_valid) & dcsr_step)begin
        debug_step_flag <= 2'h1;
    end
    else if((debug_step_flag == 2'h1) & EX_LS_reg_execute_valid)begin
        debug_step_flag <= 2'h2;
    end
    else if((debug_step_flag == 2'h2) & trap_debug_mode_valid)begin
        debug_step_flag <= 2'h0;
    end
end

assign m_mode_interrupt_enable  = (mstatus_MIE | (current_priv_status < `PRV_M));
assign s_mode_interrupt_enable  = ((mstatus_SIE | (current_priv_status < `PRV_S)) & (current_priv_status != `PRV_M));
assign m_mode_interrupt_pending = (mie & mip);
assign s_mode_interrupt_pending = (sie & sip);

assign interrupt_m_flag         = (m_mode_interrupt_enable & m_mode_interrupt_pending[interrupt_cause[5:0]] & (!interrupt_s_flag) & (!interrupt_debug_flag) & (!debug_mode)); 
assign interrupt_s_flag         = (s_mode_interrupt_enable & s_mode_interrupt_pending[interrupt_cause[5:0]] & (!interrupt_debug_flag) & (!debug_mode)); 
assign interrupt_debug_flag     = ((halt_req | ((debug_step_flag == 2'h1) & EX_LS_reg_execute_valid) | (debug_step_flag == 2'h2)) & (!debug_mode));

assign interrupt_cause          = (m_mode_interrupt_pending[11]) ? 64'h8000_0000_0000_000B : (
                                    (m_mode_interrupt_pending[3]) ? 64'h8000_0000_0000_0003 : (
                                        (m_mode_interrupt_pending[7]) ? 64'h8000_0000_0000_0007 : (
                                            (m_mode_interrupt_pending[9]) ? 64'h8000_0000_0000_0009 : (
                                                (m_mode_interrupt_pending[1]) ? 64'h8000_0000_0000_0001 : (
                                                    (m_mode_interrupt_pending[5]) ? 64'h8000_0000_0000_0001 : 64'h8000_0000_0000_0000
                                                )
                                            )
                                        )
                                    )
                                );
assign interrupt_debug_cause    = (halt_req) ? 3'h3 : 3'h4;

endmodule //interrupt_control

module trap_control#(parameter RST_PC=64'h0)(
    input                   clk,
    input                   rst_n,
    input                   debug_mode,
    input  [1:0]            current_priv_status,
//interface with ifu
    output                  WB_IF_jump_flag,
    output [63:0]           WB_IF_jump_addr,
//interface with exu
    input                   EX_LS_reg_execute_valid,
//interface with lsu 
    //common
    input                   LS_WB_reg_ls_valid,
    input  [63:0]           LS_WB_reg_PC,
    input  [63:0]           LS_WB_reg_next_PC,
    //trap:
    input                   LS_WB_reg_trap_valid,
    input                   LS_WB_reg_mret_valid,
    input                   LS_WB_reg_sret_valid,
    input                   LS_WB_reg_dret_valid,
    input  [63:0]           LS_WB_reg_trap_cause,
    input  [63:0]           LS_WB_reg_trap_tval,
//interrupt sign input
    input         	        interrupt_m_flag,
    input         	        interrupt_s_flag,
    input         	        interrupt_debug_flag,
    input  [63:0] 	        interrupt_cause,
    input  [2:0]            interrupt_debug_cause,
//trap sign output
    output                  trap_m_mode_valid,
    output                  trap_s_mode_valid,
    output                  trap_debug_mode_valid,
    output [63:0] 	        epc,
    output [2:0]            debug_cause,
    output [63:0] 	        cause,
    output [63:0] 	        tval,
//debug
    input                   dcsr_ebreakm,
    input                   dcsr_ebreaks,
    input                   dcsr_ebreaku,
//exception
    input  [63:0]           medeleg,
//return pc
    input  [63:0]           mepc,
    input  [63:0]           sepc,
    input  [63:0]           dpc,
//trap vector
    input  [63:0]           mtvec,
    input  [63:0]           stvec
);

wire            ebreak_entry_debug;

wire [63:0]     tvec;
wire [63:0]     trap_addr;
wire            trap_m_interrupt;
wire            trap_m_exception;
wire            trap_s_interrupt;
wire            trap_s_exception;
wire            trap_debug_interrupt;
wire            trap_debug_exception;
wire            debug_exception;

reg  [63:0]     next_pc;

//**********************************************************************************************
always @(posedge clk or negedge rst_n) begin
    if(!rst_n)begin
        next_pc <= RST_PC;
    end
    else begin
        if(WB_IF_jump_flag)begin
            next_pc <= WB_IF_jump_addr;
        end
        else if(LS_WB_reg_ls_valid) begin
            next_pc <= LS_WB_reg_next_PC;
        end
    end
end
assign ebreak_entry_debug   =   (dcsr_ebreakm & (current_priv_status == 2'h3)) |
                                (dcsr_ebreaks & (current_priv_status == 2'h1)) |
                                (dcsr_ebreaku & (current_priv_status == 2'h0));
assign tvec                 = ((trap_debug_mode_valid) ? {52'h0, `DEBUG_ENTRY_TVEC} : 
                                    ((debug_exception) ? ((LS_WB_reg_trap_cause[5:0] == 6'h3) ? {52'h0, `DEBUG_ENTRY_TVEC} : {52'h0, `DEBUG_EXCEPTION_TVEC}) : 
                                        ((trap_s_mode_valid) ? stvec : mtvec))
                            );
assign trap_addr            = (cause[63] & (tvec[1:0] == 2'h1)) ? ({tvec[63:2], 2'h0} + {cause[61:0], 2'h0}) : tvec;
assign trap_m_interrupt     = (interrupt_m_flag & ((!(EX_LS_reg_execute_valid | LS_WB_reg_ls_valid)) | (LS_WB_reg_ls_valid & LS_WB_reg_trap_valid)));
assign trap_s_interrupt     = (interrupt_s_flag & ((!(EX_LS_reg_execute_valid | LS_WB_reg_ls_valid)) | (LS_WB_reg_ls_valid & LS_WB_reg_trap_valid)));
assign trap_debug_interrupt = (interrupt_debug_flag & ((!(EX_LS_reg_execute_valid | LS_WB_reg_ls_valid)) | (LS_WB_reg_ls_valid & LS_WB_reg_trap_valid & (interrupt_debug_cause == 3'h3))));
assign trap_m_exception     = (LS_WB_reg_ls_valid & LS_WB_reg_trap_valid & (!trap_s_exception) & (!trap_debug_mode_valid) & (!debug_mode));
assign trap_s_exception     = (LS_WB_reg_ls_valid & LS_WB_reg_trap_valid & medeleg[LS_WB_reg_trap_cause[5:0]] & (current_priv_status <= `PRV_S) & (!trap_debug_mode_valid) & (!debug_mode));
assign trap_debug_exception = (LS_WB_reg_ls_valid & LS_WB_reg_trap_valid & (LS_WB_reg_trap_cause[5:0] == 6'h3) & ebreak_entry_debug & (!debug_mode));
assign debug_exception      = (LS_WB_reg_ls_valid & LS_WB_reg_trap_valid & debug_mode);
//**********************************************************************************************
assign WB_IF_jump_flag      = (trap_m_mode_valid | trap_s_mode_valid | trap_debug_mode_valid | debug_exception |
                                (LS_WB_reg_ls_valid & (LS_WB_reg_mret_valid | LS_WB_reg_sret_valid | LS_WB_reg_dret_valid)));
assign WB_IF_jump_addr      = (trap_m_mode_valid | trap_s_mode_valid | trap_debug_mode_valid | debug_exception) ? trap_addr : 
                                ((LS_WB_reg_mret_valid) ? mepc : 
                                    ((LS_WB_reg_sret_valid) ? sepc : 
                                        ((LS_WB_reg_dret_valid) ? dpc : 64'h0)));
assign trap_m_mode_valid    = (trap_m_interrupt | trap_m_exception);
assign trap_s_mode_valid    = (trap_s_interrupt | trap_s_exception);
assign trap_debug_mode_valid= (trap_debug_interrupt | trap_debug_exception);
assign epc                  = (trap_m_interrupt | trap_s_interrupt | trap_debug_interrupt) ? next_pc : LS_WB_reg_PC;
assign debug_cause          = (trap_debug_interrupt) ? interrupt_debug_cause : 3'h1;
assign cause                = (trap_m_interrupt | trap_s_interrupt) ? interrupt_cause : LS_WB_reg_trap_cause;
assign tval                 = (trap_m_interrupt | trap_s_interrupt) ? 64'h0 : LS_WB_reg_trap_tval;
//**********************************************************************************************



endmodule //trap_control

