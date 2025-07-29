module ysyxsoc_sim (
    input           clock,
    input           rst_n,
//nvboard
    input  [15:0]   sw,
    input           ps2_clk,
    input           ps2_data,
    input           uart_rx,
    output          uart_tx,
    output [15:0]   ledr,
    output          VGA_CLK,
    output          VGA_HSYNC,
    output          VGA_VSYNC,
    output          VGA_BLANK_N,
    output [7:0]    VGA_R,
    output [7:0]    VGA_G,
    output [7:0]    VGA_B,
    output [7:0]    seg0,
    output [7:0]    seg1,
    output [7:0]    seg2,
    output [7:0]    seg3,
    output [7:0]    seg4,
    output [7:0]    seg5,
    output [7:0]    seg6,
    output [7:0]    seg7,
//not use
    input           mtip_asyn,
    input 		    tck,
    input		    tms,
    input		    tdi,
    output		    tdo,
    output [3:0]    tap_state
);

ysyxSoCFull dut (
    .clock                   (clock         ),
    .reset                   (~rst_n        ),
    .externalPins_gpio_out   (ledr          ),
    .externalPins_gpio_in    (sw            ),
    .externalPins_gpio_seg_0 (seg0          ),
    .externalPins_gpio_seg_1 (seg1          ),
    .externalPins_gpio_seg_2 (seg2          ),
    .externalPins_gpio_seg_3 (seg3          ),
    .externalPins_gpio_seg_4 (seg4          ),
    .externalPins_gpio_seg_5 (seg5          ),
    .externalPins_gpio_seg_6 (seg6          ),
    .externalPins_gpio_seg_7 (seg7          ),
    .externalPins_ps2_clk    (ps2_clk       ),
    .externalPins_ps2_data   (ps2_data      ),
    .externalPins_vga_r      (VGA_R         ),
    .externalPins_vga_g      (VGA_G         ),
    .externalPins_vga_b      (VGA_B         ),
    .externalPins_vga_hsync  (VGA_HSYNC     ),
    .externalPins_vga_vsync  (VGA_VSYNC     ),
    .externalPins_vga_valid  (VGA_BLANK_N   ),
    .externalPins_uart_rx    (uart_rx       ),
    .externalPins_uart_tx    (uart_tx       )
);


DifftestArchIntRegState u_DifftestArchIntRegState(
    .io_value_0  	(64'h0                                        ),
    .io_value_1  	(dut.asic.cpu.cpu.u_wbu.u_gpr.riscv_reg[1]    ),
    .io_value_2  	(dut.asic.cpu.cpu.u_wbu.u_gpr.riscv_reg[2]    ),
    .io_value_3  	(dut.asic.cpu.cpu.u_wbu.u_gpr.riscv_reg[3]    ),
    .io_value_4  	(dut.asic.cpu.cpu.u_wbu.u_gpr.riscv_reg[4]    ),
    .io_value_5  	(dut.asic.cpu.cpu.u_wbu.u_gpr.riscv_reg[5]    ),
    .io_value_6  	(dut.asic.cpu.cpu.u_wbu.u_gpr.riscv_reg[6]    ),
    .io_value_7  	(dut.asic.cpu.cpu.u_wbu.u_gpr.riscv_reg[7]    ),
    .io_value_8  	(dut.asic.cpu.cpu.u_wbu.u_gpr.riscv_reg[8]    ),
    .io_value_9  	(dut.asic.cpu.cpu.u_wbu.u_gpr.riscv_reg[9]    ),
    .io_value_10 	(dut.asic.cpu.cpu.u_wbu.u_gpr.riscv_reg[10]   ),
    .io_value_11 	(dut.asic.cpu.cpu.u_wbu.u_gpr.riscv_reg[11]   ),
    .io_value_12 	(dut.asic.cpu.cpu.u_wbu.u_gpr.riscv_reg[12]   ),
    .io_value_13 	(dut.asic.cpu.cpu.u_wbu.u_gpr.riscv_reg[13]   ),
    .io_value_14 	(dut.asic.cpu.cpu.u_wbu.u_gpr.riscv_reg[14]   ),
    .io_value_15 	(dut.asic.cpu.cpu.u_wbu.u_gpr.riscv_reg[15]   ),
    .io_value_16 	(dut.asic.cpu.cpu.u_wbu.u_gpr.riscv_reg[16]   ),
    .io_value_17 	(dut.asic.cpu.cpu.u_wbu.u_gpr.riscv_reg[17]   ),
    .io_value_18 	(dut.asic.cpu.cpu.u_wbu.u_gpr.riscv_reg[18]   ),
    .io_value_19 	(dut.asic.cpu.cpu.u_wbu.u_gpr.riscv_reg[19]   ),
    .io_value_20 	(dut.asic.cpu.cpu.u_wbu.u_gpr.riscv_reg[20]   ),
    .io_value_21 	(dut.asic.cpu.cpu.u_wbu.u_gpr.riscv_reg[21]   ),
    .io_value_22 	(dut.asic.cpu.cpu.u_wbu.u_gpr.riscv_reg[22]   ),
    .io_value_23 	(dut.asic.cpu.cpu.u_wbu.u_gpr.riscv_reg[23]   ),
    .io_value_24 	(dut.asic.cpu.cpu.u_wbu.u_gpr.riscv_reg[24]   ),
    .io_value_25 	(dut.asic.cpu.cpu.u_wbu.u_gpr.riscv_reg[25]   ),
    .io_value_26 	(dut.asic.cpu.cpu.u_wbu.u_gpr.riscv_reg[26]   ),
    .io_value_27 	(dut.asic.cpu.cpu.u_wbu.u_gpr.riscv_reg[27]   ),
    .io_value_28 	(dut.asic.cpu.cpu.u_wbu.u_gpr.riscv_reg[28]   ),
    .io_value_29 	(dut.asic.cpu.cpu.u_wbu.u_gpr.riscv_reg[29]   ),
    .io_value_30 	(dut.asic.cpu.cpu.u_wbu.u_gpr.riscv_reg[30]   ),
    .io_value_31 	(dut.asic.cpu.cpu.u_wbu.u_gpr.riscv_reg[31]   )
);

DifftestPerformRegState u_DifftestPerformRegState(
    .io_value_0  	(dut.asic.cpu.cpu.u_wbu.u_csr.Performance_Monitor[1]    ),
    .io_value_1  	(dut.asic.cpu.cpu.u_wbu.u_csr.Performance_Monitor[2]    ),
    .io_value_3  	(dut.asic.cpu.cpu.u_wbu.u_csr.Performance_Monitor[3]    ),
    .io_value_4  	(dut.asic.cpu.cpu.u_wbu.u_csr.Performance_Monitor[4]    ),
    .io_value_5  	(dut.asic.cpu.cpu.u_wbu.u_csr.Performance_Monitor[5]    ),
    .io_value_6  	(dut.asic.cpu.cpu.u_wbu.u_csr.Performance_Monitor[6]    ),
    .io_value_7  	(dut.asic.cpu.cpu.u_wbu.u_csr.Performance_Monitor[7]    ),
    .io_value_8  	(dut.asic.cpu.cpu.u_wbu.u_csr.Performance_Monitor[8]    ),
    .io_value_9  	(dut.asic.cpu.cpu.u_wbu.u_csr.Performance_Monitor[9]    ),
    .io_value_10 	(dut.asic.cpu.cpu.u_wbu.u_csr.Performance_Monitor[10]   ),
    .io_value_11 	(dut.asic.cpu.cpu.u_wbu.u_csr.Performance_Monitor[11]   ),
    .io_value_12 	(dut.asic.cpu.cpu.u_wbu.u_csr.Performance_Monitor[12]   ),
    .io_value_13 	(dut.asic.cpu.cpu.u_wbu.u_csr.Performance_Monitor[13]   ),
    .io_value_14 	(dut.asic.cpu.cpu.u_wbu.u_csr.Performance_Monitor[14]   ),
    .io_value_15 	(dut.asic.cpu.cpu.u_wbu.u_csr.Performance_Monitor[15]   ),
    .io_value_16 	(dut.asic.cpu.cpu.u_wbu.u_csr.Performance_Monitor[16]   ),
    .io_value_17 	(dut.asic.cpu.cpu.u_wbu.u_csr.Performance_Monitor[17]   ),
    .io_value_18 	(dut.asic.cpu.cpu.u_wbu.u_csr.Performance_Monitor[18]   ),
    .io_value_19 	(dut.asic.cpu.cpu.u_wbu.u_csr.Performance_Monitor[19]   ),
    .io_value_20 	(dut.asic.cpu.cpu.u_wbu.u_csr.Performance_Monitor[20]   ),
    .io_value_21 	(dut.asic.cpu.cpu.u_wbu.u_csr.Performance_Monitor[21]   ),
    .io_value_22 	(dut.asic.cpu.cpu.u_wbu.u_csr.Performance_Monitor[22]   ),
    .io_value_23 	(dut.asic.cpu.cpu.u_wbu.u_csr.Performance_Monitor[23]   ),
    .io_value_24 	(dut.asic.cpu.cpu.u_wbu.u_csr.Performance_Monitor[24]   ),
    .io_value_25 	(dut.asic.cpu.cpu.u_wbu.u_csr.Performance_Monitor[25]   ),
    .io_value_26 	(dut.asic.cpu.cpu.u_wbu.u_csr.Performance_Monitor[26]   ),
    .io_value_27 	(dut.asic.cpu.cpu.u_wbu.u_csr.Performance_Monitor[27]   ),
    .io_value_28 	(dut.asic.cpu.cpu.u_wbu.u_csr.Performance_Monitor[28]   ),
    .io_value_29 	(dut.asic.cpu.cpu.u_wbu.u_csr.Performance_Monitor[29]   ),
    .io_value_30 	(dut.asic.cpu.cpu.u_wbu.u_csr.Performance_Monitor[30]   ),
    .io_value_31 	(dut.asic.cpu.cpu.u_wbu.u_csr.Performance_Monitor[31]   )
);

DifftestCSRState u_DifftestCSRState(
    .io_privilegeMode 	({{62{1'b0}},dut.asic.cpu.cpu.u_wbu.u_csr.current_priv_status}),
    .io_mstatus       	(dut.asic.cpu.cpu.u_wbu.u_csr.mstatus                         ),
    .io_sstatus       	(dut.asic.cpu.cpu.u_wbu.u_csr.sstatus                         ),
    .io_mepc          	(dut.asic.cpu.cpu.u_wbu.u_csr.mepc                            ),
    .io_sepc          	(dut.asic.cpu.cpu.u_wbu.u_csr.sepc                            ),
    .io_mtval         	(dut.asic.cpu.cpu.u_wbu.u_csr.mtval                           ),
    .io_stval         	(dut.asic.cpu.cpu.u_wbu.u_csr.stval                           ),
    .io_mtvec         	(dut.asic.cpu.cpu.u_wbu.u_csr.mtvec                           ),
    .io_stvec         	(dut.asic.cpu.cpu.u_wbu.u_csr.stvec                           ),
    .io_mcause        	(dut.asic.cpu.cpu.u_wbu.u_csr.mcause                          ),
    .io_scause        	(dut.asic.cpu.cpu.u_wbu.u_csr.scause                          ),
    .io_satp          	(dut.asic.cpu.cpu.u_wbu.u_csr.satp                            ),
    .io_mip           	(dut.asic.cpu.cpu.u_wbu.u_csr.mip                             ),
    .io_mie           	(dut.asic.cpu.cpu.u_wbu.u_csr.mie                             ),
    .io_mscratch      	(dut.asic.cpu.cpu.u_wbu.u_csr.mscratch                        ),
    .io_sscratch      	(dut.asic.cpu.cpu.u_wbu.u_csr.sscratch                        ),
    .io_mideleg       	(dut.asic.cpu.cpu.u_wbu.u_csr.mideleg                         ),
    .io_medeleg       	(dut.asic.cpu.cpu.u_wbu.u_csr.medeleg                         )
);

reg  io_ls_flag_reg;
wire io_load_addr_flag  = ((dut.asic.cpu.cpu.dcache_araddr >= 64'h1000_0000) && (dut.asic.cpu.cpu.dcache_araddr < 64'h1000_0008)) | 
                            ((dut.asic.cpu.cpu.dcache_araddr >= 64'h1000_1000) && (dut.asic.cpu.cpu.dcache_araddr < 64'h1000_1020)) |
                            ((dut.asic.cpu.cpu.dcache_araddr >= 64'h1000_2000) && (dut.asic.cpu.cpu.dcache_araddr < 64'h1000_2010)) | 
                            ((dut.asic.cpu.cpu.dcache_araddr >= 64'h1001_1000) && (dut.asic.cpu.cpu.dcache_araddr < 64'h1001_1008)) | 
                            ((dut.asic.cpu.cpu.dcache_araddr >= 64'h2100_0000) && (dut.asic.cpu.cpu.dcache_araddr < 64'h2112_C000));
wire io_store_addr_flag = ((dut.asic.cpu.cpu.dcache_awaddr >= 64'h1000_0000) && (dut.asic.cpu.cpu.dcache_awaddr < 64'h1000_0008)) | 
                            ((dut.asic.cpu.cpu.dcache_awaddr >= 64'h1000_1000) && (dut.asic.cpu.cpu.dcache_awaddr < 64'h1000_1020)) | 
                            ((dut.asic.cpu.cpu.dcache_awaddr >= 64'h1000_2000) && (dut.asic.cpu.cpu.dcache_awaddr < 64'h1000_2010)) | 
                            ((dut.asic.cpu.cpu.dcache_awaddr >= 64'h1001_1000) && (dut.asic.cpu.cpu.dcache_awaddr < 64'h1001_1008)) | 
                            ((dut.asic.cpu.cpu.dcache_awaddr >= 64'h2100_0000) && (dut.asic.cpu.cpu.dcache_awaddr < 64'h2112_C000));
wire io_load_flag  = dut.asic.cpu.cpu.dcache_arvalid & dut.asic.cpu.cpu.dcache_arready & io_load_addr_flag;
wire io_store_flag = dut.asic.cpu.cpu.dcache_awvalid & dut.asic.cpu.cpu.dcache_awready & io_store_addr_flag;
always @(posedge clock or negedge rst_n) begin
    if(!rst_n)begin
        io_ls_flag_reg  <= 1'b0;
    end
    else if((!io_ls_flag_reg) & (io_load_flag | io_store_flag))begin
        io_ls_flag_reg  <= 1'b1;
    end
    else if(dut.asic.cpu.cpu.u_lsu.LS_EX_execute_ready)begin
        io_ls_flag_reg  <= 1'b0;
    end
end
wire skip_flag;
FF_D_without_asyn_rst #(1) u_skip_flag (clock,dut.asic.cpu.cpu.u_lsu.LS_EX_execute_ready,io_ls_flag_reg,skip_flag);

DifftestInstrCommit u_DifftestInstrCommit(
    .clock      	(clock                                        ),
    .io_valid   	(dut.asic.cpu.cpu.u_wbu.LS_WB_reg_ls_valid    ),
    .io_skip    	(skip_flag                                    ),
    //todo 暂不支持查询是否压缩指令
    .io_isRVC   	(1'b0                                         ),

    .io_rfwen   	(dut.asic.cpu.cpu.u_wbu.LS_WB_reg_dest_wen    ),
    .io_fpwen   	(1'b0                                         ),
    .io_vecwen  	(1'b0                                         ),
    .io_wpdest  	(dut.asic.cpu.cpu.u_wbu.LS_WB_reg_rd          ),
    .io_wdest   	({3'h0, dut.asic.cpu.cpu.u_wbu.LS_WB_reg_rd}  ),
    .io_pc      	((dut.asic.cpu.cpu.u_wbu.WB_IF_jump_flag) ? 
                    dut.asic.cpu.cpu.u_wbu.WB_IF_jump_addr : 
                    dut.asic.cpu.cpu.u_wbu.LS_WB_reg_next_PC      ),
    .io_instr   	(dut.asic.cpu.cpu.u_wbu.LS_WB_reg_inst        ),
    .io_robIdx  	(10'h0                                        ),
    .io_lqIdx   	(7'h0                                         ),
    .io_sqIdx   	(7'h0                                         ),
    //todo 暂不支持查询是否访存指令
    .io_isLoad  	(1'b0                                         ),
    .io_isStore 	(1'b0                                         ),

    .io_nFused  	(8'h0                                         ),
    .io_special 	(8'h0                                         ),
    .io_coreid  	(8'h0                                         ),
    .io_index   	(8'h0                                         )
);

DifftestTrapEvent u_DifftestTrapEvent(
    .clock         (clock                                                          ),
    .enable        (dut.asic.cpu.cpu.u_wbu.u_csr.u_trap_control.trap_m_interrupt |
                    dut.asic.cpu.cpu.u_wbu.u_csr.u_trap_control.trap_s_interrupt   ),
    .io_hasTrap    (1'b0                                                           ),
    .io_cycleCnt   (dut.asic.cpu.cpu.u_wbu.u_csr.Performance_Monitor[1]            ),
    .io_instrCnt   (dut.asic.cpu.cpu.u_wbu.u_csr.Performance_Monitor[2]            ),
    .io_hasWFI     (1'b0                                                           ),
    .io_code       (dut.asic.cpu.cpu.u_wbu.u_csr.u_trap_control.cause              ),
    .io_pc         (dut.asic.cpu.cpu.u_wbu.u_csr.u_trap_control.next_pc            ),
    .io_coreid     (8'h0                                                           )
);

endmodule //ysyxsoc_sim
