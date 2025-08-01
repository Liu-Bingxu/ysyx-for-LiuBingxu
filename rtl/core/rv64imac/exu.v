// the execute Unit for a cpu core
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

module exu (
    input                   clk,
    input                   rst_n,
//interface with idu
    //common sign:
    output                  EX_ID_flush_flag,
    output                  EX_ID_decode_ready,
    input                   ID_EX_reg_decode_valid,
    input  [4 :0]           ID_EX_reg_rs1,
    input  [4 :0]           ID_EX_reg_rs2,
    // output [4 :0]           rs1,
    // output [4 :0]           rs2,
    // input  [63:0]           WB_EX_src1,
    // input  [63:0]           WB_EX_src2,
    input  [63:0]           ID_EX_reg_PC,
    input  [63:0]           ID_EX_reg_next_PC,
    input  [31:0]           ID_EX_reg_inst,
    input  [4 :0]           ID_EX_reg_rd,
    input                   ID_EX_reg_dest_wen,
    //sflush sign:
    input                   ID_EX_reg_sflush_valid,
    input                   ID_EX_reg_fence_i_valid,
    //control_sign:
    input                   ID_EX_reg_sub,
    input                   ID_EX_reg_word,
    //logic_sign:
    input                   ID_EX_reg_logic_valid,
    input                   ID_EX_reg_logic_or,
    input                   ID_EX_reg_logic_xor,
    input                   ID_EX_reg_logic_and,
    //load_sign:
    input                   ID_EX_reg_load_valid,
    input                   ID_EX_reg_load_signed,
    input                   ID_EX_reg_load_byte,
    input                   ID_EX_reg_load_half,
    input                   ID_EX_reg_load_word,
    input                   ID_EX_reg_load_double,
    //store_sign:
    input                   ID_EX_reg_store_valid,
    input                   ID_EX_reg_store_byte,
    input                   ID_EX_reg_store_half,
    input                   ID_EX_reg_store_word,
    input                   ID_EX_reg_store_double,
    input  [63:0]           ID_EX_reg_store_data,
    //branch:
    input                   ID_EX_reg_branch_valid,
    input                   ID_EX_reg_branch_ne,
    input                   ID_EX_reg_branch_eq,
    input                   ID_EX_reg_branch_lt,
    input                   ID_EX_reg_branch_ge,
    input                   ID_EX_reg_branch_signed,
    //shift:
    input                   ID_EX_reg_shift_valid,
    input                   ID_EX_reg_shift_al,
    input                   ID_EX_reg_shift_lr,
    input                   ID_EX_reg_shift_word,
    //set:
    input                   ID_EX_reg_set_valid,
    input                   ID_EX_reg_set_signed,
    //jump:
    input                   ID_EX_reg_jump_valid,
    input                   ID_EX_reg_jump_jalr,
    //Zicsr:
    input                   ID_EX_reg_csr_valid,
    input                   ID_EX_reg_csr_wen,
    input                   ID_EX_reg_csr_ren,
    input  [11:0]           ID_EX_reg_csr_addr,
    input                   ID_EX_reg_csr_set,
    input                   ID_EX_reg_csr_clear,
    input                   ID_EX_reg_csr_swap,
    //mul:
    input                   ID_EX_reg_mul_valid,
    input                   ID_EX_reg_mul_high,
    input  [1:0]            ID_EX_reg_mul_signed,
    input                   ID_EX_reg_mul_word,
    input                   ID_EX_reg_div_valid,
    input                   ID_EX_reg_div_signed,
    input                   ID_EX_reg_div_rem,
    input                   ID_EX_reg_div_word,
    //atomic:
    input                   ID_EX_reg_atomic_valid,
    input                   ID_EX_reg_atomic_word,
    input                   ID_EX_reg_atomic_lr,
    input                   ID_EX_reg_atomic_sc,
    input                   ID_EX_reg_atomic_swap,
    input                   ID_EX_reg_atomic_add,
    input                   ID_EX_reg_atomic_xor,
    input                   ID_EX_reg_atomic_and,
    input                   ID_EX_reg_atomic_or,
    input                   ID_EX_reg_atomic_min,
    input                   ID_EX_reg_atomic_max,
    input                   ID_EX_reg_atomic_signed,
    //trap:
    input                   ID_EX_reg_trap_valid,
    input                   ID_EX_reg_mret_valid,
    input                   ID_EX_reg_sret_valid,
    input                   ID_EX_reg_dret_valid,
    input  [63:0]           ID_EX_reg_trap_cause,
    input  [63:0]           ID_EX_reg_trap_tval,
    //operand
    input  [63:0]           ID_EX_reg_operand1,
    input  [63:0]           ID_EX_reg_operand2,
    input  [63:0]           ID_EX_reg_operand3,
    input  [63:0]           ID_EX_reg_operand4,
//interface with lsu
    //common sign:
    input                   LS_EX_flush_flag,
    input                   LS_EX_execute_ready,
    output                  EX_LS_reg_execute_valid,
    output [63:0]           EX_LS_reg_PC,
    output [63:0]           EX_LS_reg_next_PC,
    output [31:0]           EX_LS_reg_inst,
    output [4 :0]           EX_LS_reg_rd,
    output                  EX_LS_reg_dest_wen,
    //sflush sign:
    output                  EX_LS_reg_sflush_valid,
    output                  EX_LS_reg_fence_i_valid,
    //load_sign:
    output                  EX_LS_reg_load_valid,
    output                  EX_LS_reg_load_signed,
    output                  EX_LS_reg_load_byte,
    output                  EX_LS_reg_load_half,
    output                  EX_LS_reg_load_word,
    output                  EX_LS_reg_load_double,
    //store_sign:
    output                  EX_LS_reg_store_valid,
    output                  EX_LS_reg_store_byte,
    output                  EX_LS_reg_store_half,
    output                  EX_LS_reg_store_word,
    output                  EX_LS_reg_store_double,
    output [63:0]           EX_LS_reg_store_data,
    //Zicsr:
    output                  EX_LS_reg_csr_wen,
    output                  EX_LS_reg_csr_ren,
    output [11:0]           EX_LS_reg_csr_addr,
    //atomic:
    output                  EX_LS_reg_atomic_valid,
    output                  EX_LS_reg_atomic_word,
    output                  EX_LS_reg_atomic_lr,
    output                  EX_LS_reg_atomic_sc,
    output                  EX_LS_reg_atomic_swap,
    output                  EX_LS_reg_atomic_add,
    output                  EX_LS_reg_atomic_xor,
    output                  EX_LS_reg_atomic_and,
    output                  EX_LS_reg_atomic_or,
    output                  EX_LS_reg_atomic_min,
    output                  EX_LS_reg_atomic_max,
    output                  EX_LS_reg_atomic_signed,
    //trap:
    output                  EX_LS_reg_trap_valid,
    output                  EX_LS_reg_mret_valid,
    output                  EX_LS_reg_sret_valid,
    output                  EX_LS_reg_dret_valid,
    output [63:0]           EX_LS_reg_trap_cause,
    output [63:0]           EX_LS_reg_trap_tval,
    //operand
    output [63:0]           EX_LS_reg_operand,   //addr when atomic or store, data when other
//interface with wbu
    input                   WB_EX_interrupt_flag,
    input                   LS_WB_reg_ls_valid,
    input  [4:0]            LS_WB_reg_rd,
    input                   LS_WB_reg_dest_wen,
    input  [63:0]           LS_WB_reg_data,
//interface with ifu
    output                  EX_IF_jump_flag,
    output [63:0]           EX_IF_jump_addr
);

wire [4 :0]             rs1;
wire [4 :0]             rs2;

wire        Data_Conflict;
reg         src1_valid;
reg [63:0]  src1;
reg         src2_valid;
reg [63:0]  src2;

reg  [63:0]             store_data;

reg  [63:0]             operand1;
reg  [63:0]             operand2;
reg  [63:0]             operand3;
wire [63:0]             operand4;

// outports wire
wire        	o_valid;
wire        	branch_flag;
wire [63:0] 	res;

wire [63:0]     jump_addr;
wire [63:0]     next_PC;

//use for give a sigle cycle jump sign 
reg             jump_cnt;

assign rs1 = ID_EX_reg_rs1;
assign rs2 = ID_EX_reg_rs2;

assign Data_Conflict = ((rs1 == EX_LS_reg_rd) & EX_LS_reg_execute_valid & (rs1 != 5'h0) & (EX_LS_reg_load_valid | EX_LS_reg_atomic_valid) & EX_LS_reg_dest_wen) |
                        ((rs2 == EX_LS_reg_rd) & EX_LS_reg_execute_valid & (rs2 != 5'h0) & (EX_LS_reg_load_valid | EX_LS_reg_atomic_valid) & EX_LS_reg_dest_wen);
always @(*) begin
    if((rs1 == EX_LS_reg_rd) & EX_LS_reg_execute_valid & (rs1 != 5'h0) & EX_LS_reg_dest_wen & (!ID_EX_reg_jump_jalr))begin
        operand1 = EX_LS_reg_operand;
    end
    else if((rs1 == LS_WB_reg_rd) & LS_WB_reg_ls_valid & (rs1 != 5'h0) & LS_WB_reg_dest_wen & (!ID_EX_reg_jump_jalr))begin
        operand1 = LS_WB_reg_data;
    end
    else if(src1_valid & (!ID_EX_reg_jump_jalr))begin
        operand1 = src1;
    end
    else begin
        operand1 = ID_EX_reg_operand1;
    end
end
always @(*) begin
    if((rs2 == EX_LS_reg_rd) & EX_LS_reg_execute_valid & (rs2 != 5'h0) & EX_LS_reg_dest_wen & (!ID_EX_reg_store_valid))begin
        operand2 = EX_LS_reg_operand;
    end
    else if((rs2 == LS_WB_reg_rd) & LS_WB_reg_ls_valid & (rs2 != 5'h0) & LS_WB_reg_dest_wen & (!ID_EX_reg_store_valid))begin
        operand2 = LS_WB_reg_data;
    end
    else if(src2_valid & (!ID_EX_reg_store_valid))begin
        operand2 = src2;
    end
    else begin
        operand2 = ID_EX_reg_operand2;
    end
end
always @(*) begin
    if((rs1 == EX_LS_reg_rd) & EX_LS_reg_execute_valid & (rs1 != 5'h0) & EX_LS_reg_dest_wen & ID_EX_reg_jump_jalr)begin
        operand3 = EX_LS_reg_operand;
    end
    else if((rs1 == LS_WB_reg_rd) & LS_WB_reg_ls_valid & (rs1 != 5'h0) & LS_WB_reg_dest_wen & ID_EX_reg_jump_jalr)begin
        operand3 = LS_WB_reg_data;
    end
    else if(src1_valid & ID_EX_reg_jump_jalr)begin
        operand3 = src1;
    end
    else begin
        operand3 = ID_EX_reg_operand3;
    end
end

// assign operand1 = ((rs1 != 5'h0) & (!ID_EX_reg_jump_jalr)) ? src1 : ID_EX_reg_operand1;
// assign operand2 = ((rs2 != 5'h0) & (!ID_EX_reg_store_valid)) ? src2 : ID_EX_reg_operand2;
// assign operand3 = (ID_EX_reg_jump_jalr) ? src1 : ID_EX_reg_operand3;
assign operand4 = ID_EX_reg_operand4;

always @(*) begin
    if((rs2 == EX_LS_reg_rd) & EX_LS_reg_execute_valid & (rs2 != 5'h0) & EX_LS_reg_dest_wen)begin
        store_data = EX_LS_reg_operand;
    end
    else if((rs2 == LS_WB_reg_rd) & LS_WB_reg_ls_valid & (rs2 != 5'h0) & LS_WB_reg_dest_wen)begin
        store_data = LS_WB_reg_data;
    end
    else if(src2_valid)begin
        store_data = src2;
    end
    else begin
        store_data = ID_EX_reg_store_data;
    end
end

alu u_alu(
    .clk                     	( clk                      ),
    .rst_n                   	( rst_n                    ),
    .flush_flag              	( EX_ID_flush_flag         ),
    .ready_flag              	( EX_ID_decode_ready       ),
    .Data_Conflict              ( Data_Conflict            ),
    .ID_EX_reg_decode_valid  	( ID_EX_reg_decode_valid   ),
    .ID_EX_reg_sub           	( ID_EX_reg_sub            ),
    .ID_EX_reg_word          	( ID_EX_reg_word           ),
    .ID_EX_reg_logic_valid   	( ID_EX_reg_logic_valid    ),
    .ID_EX_reg_logic_or      	( ID_EX_reg_logic_or       ),
    .ID_EX_reg_logic_xor     	( ID_EX_reg_logic_xor      ),
    .ID_EX_reg_logic_and     	( ID_EX_reg_logic_and      ),
    .ID_EX_reg_branch_ne     	( ID_EX_reg_branch_ne      ),
    .ID_EX_reg_branch_eq     	( ID_EX_reg_branch_eq      ),
    .ID_EX_reg_branch_lt     	( ID_EX_reg_branch_lt      ),
    .ID_EX_reg_branch_ge     	( ID_EX_reg_branch_ge      ),
    .ID_EX_reg_branch_signed 	( ID_EX_reg_branch_signed  ),
    .ID_EX_reg_shift_valid   	( ID_EX_reg_shift_valid    ),
    .ID_EX_reg_shift_al      	( ID_EX_reg_shift_al       ),
    .ID_EX_reg_shift_lr      	( ID_EX_reg_shift_lr       ),
    .ID_EX_reg_shift_word    	( ID_EX_reg_shift_word     ),
    .ID_EX_reg_set_valid     	( ID_EX_reg_set_valid      ),
    .ID_EX_reg_set_signed    	( ID_EX_reg_set_signed     ),
    .ID_EX_reg_csr_valid     	( ID_EX_reg_csr_valid      ),
    .ID_EX_reg_csr_set       	( ID_EX_reg_csr_set        ),
    .ID_EX_reg_csr_clear     	( ID_EX_reg_csr_clear      ),
    .ID_EX_reg_csr_swap      	( ID_EX_reg_csr_swap       ),
    .ID_EX_reg_mul_valid     	( ID_EX_reg_mul_valid      ),
    .ID_EX_reg_mul_high      	( ID_EX_reg_mul_high       ),
    .ID_EX_reg_mul_signed    	( ID_EX_reg_mul_signed     ),
    .ID_EX_reg_mul_word      	( ID_EX_reg_mul_word       ),
    .ID_EX_reg_div_valid     	( ID_EX_reg_div_valid      ),
    .ID_EX_reg_div_signed    	( ID_EX_reg_div_signed     ),
    .ID_EX_reg_div_rem       	( ID_EX_reg_div_rem        ),
    .ID_EX_reg_div_word      	( ID_EX_reg_div_word       ),
    .ID_EX_reg_atomic_valid  	( ID_EX_reg_atomic_valid   ),
    .ID_EX_reg_trap_valid    	( ID_EX_reg_trap_valid     ),
    .ID_EX_reg_operand1      	( operand1                 ),
    .ID_EX_reg_operand2      	( operand2                 ),
    .o_valid                 	( o_valid                  ),
    .branch_flag             	( branch_flag              ),
    .res                     	( res                      )
);

add_without_Cin #(
    .DATA_LEN 	( 64  )
)u_jump_addr
(
    .OP_A 	( operand3    ),
    .OP_B 	( operand4    ),
    .Sum  	( jump_addr   )
);

//**********************************************************************
assign next_PC = (ID_EX_reg_jump_valid | (ID_EX_reg_branch_valid & branch_flag)) ? {jump_addr[63:1] ,1'b0} : ID_EX_reg_next_PC;
always @(posedge clk or negedge rst_n) begin
    if(!rst_n)begin
        jump_cnt <= 1'b0;
    end
    else if(EX_ID_flush_flag)begin
        jump_cnt <= 1'b0;
    end
    else if(ID_EX_reg_decode_valid & EX_ID_decode_ready)begin
        jump_cnt <= 1'b0;
    end
    else if(ID_EX_reg_decode_valid & (ID_EX_reg_jump_valid | (ID_EX_reg_branch_valid & branch_flag)) & (!Data_Conflict))begin
        jump_cnt <= 1'b1;
    end
end

always @(posedge clk or negedge rst_n) begin
    if(!rst_n)begin
        src1_valid <= 1'b0;
    end
    else if(EX_ID_flush_flag)begin
        src1_valid <= 1'b0;
    end
    else if(ID_EX_reg_decode_valid & EX_ID_decode_ready)begin
        src1_valid <= 1'b0;
    end
    else if(ID_EX_reg_decode_valid & (rs1 == LS_WB_reg_rd) & LS_WB_reg_ls_valid & (rs1 != 5'h0) & LS_WB_reg_dest_wen)begin
        src1_valid <= 1'b1;
    end
end
always @(posedge clk) begin
    if(ID_EX_reg_decode_valid & (rs1 == LS_WB_reg_rd) & LS_WB_reg_ls_valid & (rs1 != 5'h0) & LS_WB_reg_dest_wen)begin
        src1 <= LS_WB_reg_data;
    end
end

always @(posedge clk or negedge rst_n) begin
    if(!rst_n)begin
        src2_valid <= 1'b0;
    end
    else if(EX_ID_flush_flag)begin
        src2_valid <= 1'b0;
    end
    else if(ID_EX_reg_decode_valid & EX_ID_decode_ready)begin
        src2_valid <= 1'b0;
    end
    else if(ID_EX_reg_decode_valid & (rs2 == LS_WB_reg_rd) & LS_WB_reg_ls_valid & (rs2 != 5'h0) & LS_WB_reg_dest_wen)begin
        src2_valid <= 1'b1;
    end
end
always @(posedge clk) begin
    if(ID_EX_reg_decode_valid & (rs2 == LS_WB_reg_rd) & LS_WB_reg_ls_valid & (rs2 != 5'h0) & LS_WB_reg_dest_wen)begin
        src2 <= LS_WB_reg_data;
    end
end
//**********************************************************************
assign EX_ID_decode_ready = (ID_EX_reg_decode_valid & ((!EX_LS_reg_execute_valid) | LS_EX_execute_ready) & (!WB_EX_interrupt_flag) &
                            ((!(((ID_EX_reg_mul_valid | ID_EX_reg_div_valid) & (!o_valid)) | Data_Conflict)) | ID_EX_reg_trap_valid));
assign EX_ID_flush_flag   = (LS_EX_flush_flag | (EX_LS_reg_execute_valid & (EX_LS_reg_trap_valid | EX_LS_reg_mret_valid | EX_LS_reg_sret_valid | EX_LS_reg_dret_valid | EX_LS_reg_fence_i_valid)));
assign EX_IF_jump_flag    = (ID_EX_reg_decode_valid & (ID_EX_reg_jump_valid | (ID_EX_reg_branch_valid & branch_flag)) & (!jump_cnt) & (!Data_Conflict));
assign EX_IF_jump_addr    = {jump_addr[63:1], 1'b0};

//common
FF_D_with_syn_rst #(
    .DATA_LEN 	( 1  ),
    .RST_DATA 	( 0  )
)u_execute_valid
(
    .clk      	( clk                                               ),
    .rst_n    	( rst_n                                             ),
    .syn_rst    ( LS_EX_flush_flag                                  ),
    .wen        ( ((!EX_LS_reg_execute_valid) | LS_EX_execute_ready)),
    .data_in  	( EX_ID_decode_ready & (!EX_ID_flush_flag)          ),
    .data_out 	( EX_LS_reg_execute_valid                           )
);
FF_D_without_asyn_rst #(5)  u_rd            (clk,EX_ID_decode_ready,ID_EX_reg_rd,       EX_LS_reg_rd);
FF_D_without_asyn_rst #(1)  u_dest_wen      (clk,EX_ID_decode_ready,ID_EX_reg_dest_wen, EX_LS_reg_dest_wen);
FF_D_without_asyn_rst #(32) u_inst          (clk,EX_ID_decode_ready,ID_EX_reg_inst,     EX_LS_reg_inst);
FF_D_without_asyn_rst #(64) u_PC            (clk,EX_ID_decode_ready,ID_EX_reg_PC,       EX_LS_reg_PC);
FF_D_without_asyn_rst #(64) u_next_PC       (clk,EX_ID_decode_ready,next_PC,            EX_LS_reg_next_PC);
//sflush_sign:
FF_D_without_asyn_rst #(1)  u_sflush_valid  (clk,EX_ID_decode_ready,ID_EX_reg_sflush_valid,EX_LS_reg_sflush_valid);
FF_D_without_asyn_rst #(1)  u_fence_i_valid (clk,EX_ID_decode_ready,ID_EX_reg_fence_i_valid,EX_LS_reg_fence_i_valid);
//load_sign:
FF_D_without_asyn_rst #(1)  u_load_valid    (clk,EX_ID_decode_ready,ID_EX_reg_load_valid,   EX_LS_reg_load_valid);
FF_D_without_asyn_rst #(1)  u_load_signed   (clk,EX_ID_decode_ready,ID_EX_reg_load_signed,  EX_LS_reg_load_signed);
FF_D_without_asyn_rst #(1)  u_load_byte     (clk,EX_ID_decode_ready,ID_EX_reg_load_byte,    EX_LS_reg_load_byte);
FF_D_without_asyn_rst #(1)  u_load_half     (clk,EX_ID_decode_ready,ID_EX_reg_load_half,    EX_LS_reg_load_half);
FF_D_without_asyn_rst #(1)  u_load_word     (clk,EX_ID_decode_ready,ID_EX_reg_load_word,    EX_LS_reg_load_word);
FF_D_without_asyn_rst #(1)  u_load_double   (clk,EX_ID_decode_ready,ID_EX_reg_load_double,  EX_LS_reg_load_double);
//store_sign:
FF_D_without_asyn_rst #(1)  u_store_valid   (clk,EX_ID_decode_ready,ID_EX_reg_store_valid,  EX_LS_reg_store_valid);
FF_D_without_asyn_rst #(1)  u_store_byte    (clk,EX_ID_decode_ready,ID_EX_reg_store_byte,   EX_LS_reg_store_byte);
FF_D_without_asyn_rst #(1)  u_store_half    (clk,EX_ID_decode_ready,ID_EX_reg_store_half,   EX_LS_reg_store_half);
FF_D_without_asyn_rst #(1)  u_store_word    (clk,EX_ID_decode_ready,ID_EX_reg_store_word,   EX_LS_reg_store_word);
FF_D_without_asyn_rst #(1)  u_store_double  (clk,EX_ID_decode_ready,ID_EX_reg_store_double, EX_LS_reg_store_double);
FF_D_without_asyn_rst #(64) u_store_data    (clk,EX_ID_decode_ready,store_data,             EX_LS_reg_store_data);
//Zicsr:
FF_D_without_asyn_rst #(1)  u_csr_wen       (clk,EX_ID_decode_ready,ID_EX_reg_csr_wen, EX_LS_reg_csr_wen);
FF_D_without_asyn_rst #(1)  u_csr_ren       (clk,EX_ID_decode_ready,ID_EX_reg_csr_ren, EX_LS_reg_csr_ren);
FF_D_without_asyn_rst #(12) u_csr_addr      (clk,EX_ID_decode_ready,ID_EX_reg_csr_addr,EX_LS_reg_csr_addr);
//atomic:
FF_D_without_asyn_rst #(1)  u_atomic_valid  (clk,EX_ID_decode_ready,ID_EX_reg_atomic_valid, EX_LS_reg_atomic_valid);
FF_D_without_asyn_rst #(1)  u_matomic_word  (clk,EX_ID_decode_ready,ID_EX_reg_atomic_word,  EX_LS_reg_atomic_word);
FF_D_without_asyn_rst #(1)  u_atomic_lr     (clk,EX_ID_decode_ready,ID_EX_reg_atomic_lr,    EX_LS_reg_atomic_lr);
FF_D_without_asyn_rst #(1)  u_atomic_sc     (clk,EX_ID_decode_ready,ID_EX_reg_atomic_sc,    EX_LS_reg_atomic_sc);
FF_D_without_asyn_rst #(1)  u_atomic_swap   (clk,EX_ID_decode_ready,ID_EX_reg_atomic_swap,  EX_LS_reg_atomic_swap);
FF_D_without_asyn_rst #(1)  u_atomic_add    (clk,EX_ID_decode_ready,ID_EX_reg_atomic_add,   EX_LS_reg_atomic_add);
FF_D_without_asyn_rst #(1)  u_atomic_xor    (clk,EX_ID_decode_ready,ID_EX_reg_atomic_xor,   EX_LS_reg_atomic_xor);
FF_D_without_asyn_rst #(1)  u_atomic_and    (clk,EX_ID_decode_ready,ID_EX_reg_atomic_and,   EX_LS_reg_atomic_and);
FF_D_without_asyn_rst #(1)  u_atomic_or     (clk,EX_ID_decode_ready,ID_EX_reg_atomic_or,    EX_LS_reg_atomic_or);
FF_D_without_asyn_rst #(1)  u_atomic_min    (clk,EX_ID_decode_ready,ID_EX_reg_atomic_min,   EX_LS_reg_atomic_min);
FF_D_without_asyn_rst #(1)  u_atomic_max    (clk,EX_ID_decode_ready,ID_EX_reg_atomic_max,   EX_LS_reg_atomic_max);
FF_D_without_asyn_rst #(1)  u_atomic_signed (clk,EX_ID_decode_ready,ID_EX_reg_atomic_signed,EX_LS_reg_atomic_signed);
//trap:
FF_D_without_asyn_rst #(1)  u_trap_valid    (clk,EX_ID_decode_ready,ID_EX_reg_trap_valid,EX_LS_reg_trap_valid);
FF_D_without_asyn_rst #(1)  u_mret_valid    (clk,EX_ID_decode_ready,ID_EX_reg_mret_valid,EX_LS_reg_mret_valid);
FF_D_without_asyn_rst #(1)  u_sret_valid    (clk,EX_ID_decode_ready,ID_EX_reg_sret_valid,EX_LS_reg_sret_valid);
FF_D_without_asyn_rst #(1)  u_dret_valid    (clk,EX_ID_decode_ready,ID_EX_reg_dret_valid,EX_LS_reg_dret_valid);
FF_D_without_asyn_rst #(64) u_trap_cause    (clk,EX_ID_decode_ready,ID_EX_reg_trap_cause,EX_LS_reg_trap_cause);
FF_D_without_asyn_rst #(64) u_trap_tval     (clk,EX_ID_decode_ready,ID_EX_reg_trap_tval, EX_LS_reg_trap_tval);
//operand
FF_D_without_asyn_rst #(64) u_operand       (clk,EX_ID_decode_ready,res,EX_LS_reg_operand);

//**********************************************************************


endmodule //exu
