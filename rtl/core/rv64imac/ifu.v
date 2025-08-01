// the inst fetch Unit for a cpu core
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
module ifu#(parameter RST_PC=64'h0)(
    //clock and reset
    input                   clk,
    input                   rst_n,

    //jump interface
    // input                   flush_flag,
    input                   jump_flag,
    input  [63:0]           jump_addr,

    //axi-lite clock and resetn
    // input                   aclk,
    // input                   aresetn,

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
    input                   ID_IF_flush_flag,
    output                  IF_ID_reg_inst_compress_flag,
    output [1:0]            IF_ID_reg_rresp,
    output [15:0]           IF_ID_reg_inst_compress,
    output [31:0]           IF_ID_reg_inst,
    output [63:0]           IF_ID_reg_tval,
    output [63:0]           IF_ID_reg_PC
);

//仍未接收inst计数器
reg  [2:0]          inst_cnt;

//有效已发未取pc计数器
reg  [2:0]          pc_cnt;

//已发未收pc计数器
reg  [2:0]          pc_all_cnt;

//无效数据握手计数器
reg  [3:0]          invalid_cnt;

//ifu_arvalid实际寄存器
reg                 ifu_arvalid_reg;

//fifo读使能
wire                fifo_ren;

//fifo写使能
wire                fifo_wen;

//fifo 指令读出数据
wire [63:0]         inst_rdata;

//fifo 回应数据
wire [1:0]          rresp_rdata;

//inst fifo空标志
wire                inst_empty;

reg  [63:0]         my_reg_PC_reg;
wire [15:0]         inst_rdata_reg;
wire [1:0]          rresp_rdata_reg;
wire                inst_my_reg_valid;

reg  [31:0]         inst_rdata_reg_get;
wire [31:0]         inst_rdata_reg_tran;
wire [31:0]         inst_to_idu;
reg  [1:0]          rresp_to_idu;
reg  [63:0]         tval_to_idu;

wire                inst_compress_flag;

wire                status1_can_conver_flag;
wire                status2_can_conver_flag;
wire                status3_can_conver_flag;
wire                status4_can_conver_flag;
wire                status4_after_jump_flag;
wire                reg_can_cover_flag;
wire                reg_can_change_flag;
wire                flush_flag;

reg [1:0]           status;
localparam STATUS1 = 2'h0;
localparam STATUS2 = 2'h1;
localparam STATUS3 = 2'h3;
localparam STATUS4 = 2'h2;

wire                  reg1_can_cover_flag;
wire                  reg1_can_change_flag;
wire                  IF_ID_reg_inst_valid_1;
wire                  IF_ID_reg_inst_compress_flag_1;
wire [1:0]            IF_ID_reg_rresp_1;
wire [15:0]           IF_ID_reg_inst_compress_1;
wire [31:0]           IF_ID_reg_inst_1;
wire [63:0]           IF_ID_reg_PC_1;
wire [63:0]           IF_ID_reg_tval_1;

wire                  reg2_can_cover_flag;
wire                  reg2_can_change_flag;
wire                  IF_ID_reg_inst_valid_2;
wire                  IF_ID_reg_inst_compress_flag_2;
wire [1:0]            IF_ID_reg_rresp_2;
wire [15:0]           IF_ID_reg_inst_compress_2;
wire [31:0]           IF_ID_reg_inst_2;
wire [63:0]           IF_ID_reg_PC_2;
wire [63:0]           IF_ID_reg_tval_2;

wire                  IF_ID_reg_sel_reg;

//pc part
reg [63:0]          pc;
always @(posedge clk or negedge rst_n) begin
    if(!rst_n)begin
        pc <= RST_PC;
    end
    else begin
        if(jump_flag)begin
            pc <= jump_addr;
        end
        else if(ifu_arvalid & ifu_arready)begin
            pc <= pc + 8;
        end
    end
end

//ar part
always @(posedge clk or negedge rst_n) begin
    if(!rst_n)begin
        ifu_arvalid_reg <= 1'b0;
    end
    else begin
        if(flush_flag)begin
            ifu_arvalid_reg <= 1'b0;
        end
        else if(ifu_arvalid_reg)begin
            if(ifu_arvalid & ifu_arready & (((pc_cnt == 3'h3) & (!fifo_ren))|((pc_all_cnt == 3'h3) & (!(ifu_rvalid&ifu_rready)))))begin
                ifu_arvalid_reg <= 1'b0;
            end
        end
        else begin
            if((pc_cnt!=3'h4) & (pc_all_cnt != 3'h4)) begin
                ifu_arvalid_reg <= 1'b1;
            end
        end
    end
end
always @(posedge clk or negedge rst_n) begin
    if(!rst_n)begin
        pc_cnt<=3'h0;
    end
    else begin
        if(flush_flag)begin
            pc_cnt<=3'h0;
        end
        else if(ifu_arvalid&ifu_arready&fifo_ren)begin
            pc_cnt<=pc_cnt;
        end
        else if(fifo_ren)begin
            pc_cnt<=pc_cnt+3'h7;
        end
        else if(ifu_arvalid&ifu_arready)begin
            pc_cnt<=pc_cnt+1;
        end
    end
end
always @(posedge clk or negedge rst_n) begin
    if(!rst_n)begin
        pc_all_cnt<=3'h0;
    end
    else begin
        `ifdef USE_ICACHE
        if(flush_flag)begin
            pc_all_cnt <= 3'h0;
        end
        else 
        `endif
        if(ifu_arvalid&ifu_arready&ifu_rvalid&ifu_rready)begin
            pc_all_cnt<=pc_all_cnt;
        end
        else if(ifu_rvalid&ifu_rready)begin
            pc_all_cnt<=pc_all_cnt+3'h7;
        end
        else if(ifu_arvalid&ifu_arready)begin
            pc_all_cnt<=pc_all_cnt+1;
        end
    end
end
assign ifu_araddr = {pc[63:3],3'h0};
assign ifu_arvalid = ifu_arvalid_reg;

//read data part
always @(posedge clk or negedge rst_n) begin
    if(!rst_n)begin
        inst_cnt<=3'h0;
    end
    else begin
        if(flush_flag)begin
            inst_cnt <= 3'h0;
        end
        else if(ifu_arvalid&ifu_arready&ifu_rvalid&ifu_rready&(invalid_cnt==4'h0))begin
            inst_cnt<=inst_cnt;
        end
        else if(ifu_arvalid&ifu_arready)begin
            inst_cnt<=inst_cnt+1;
        end
        else if(ifu_rvalid&ifu_rready&(invalid_cnt==4'h0))begin
            inst_cnt<=inst_cnt+3'h7;
        end
    end
end

`ifndef USE_ICACHE
wire [2:0]          inst_cnt_more;
wire [2:0]          inst_cnt_less;
assign inst_cnt_more = inst_cnt + 1;
assign inst_cnt_less = inst_cnt + 3'h7;
always @(posedge clk or negedge rst_n) begin
    if(!rst_n)begin
        invalid_cnt <= 4'h0;
    end
    else begin
        if(invalid_cnt[3])begin
            if(flush_flag)begin
                if(ifu_arvalid&ifu_arready&ifu_rvalid&ifu_rready)begin
                    invalid_cnt[2:0]<=invalid_cnt[2:0] + inst_cnt;
                end
                else if(ifu_arvalid&ifu_arready)begin
                    invalid_cnt[2:0]<=invalid_cnt[2:0] + inst_cnt + 1;
                end
                else if(ifu_rvalid&ifu_rready)begin
                    invalid_cnt[2:0]<=invalid_cnt[2:0] + inst_cnt +3'h7;
                    if((invalid_cnt[2:0] == 3'h1) & (inst_cnt == 3'h0))begin
                        invalid_cnt[3]<=1'b0;
                    end
                end
                else begin
                    invalid_cnt[2:0]<=invalid_cnt[2:0] + inst_cnt;
                end
            end
            else if(ifu_rvalid&ifu_rready)begin
                invalid_cnt[2:0]<=invalid_cnt[2:0]+3'h7;
                if(invalid_cnt[2:0]==3'h1)begin
                    invalid_cnt[3]<=1'b0;
                end
            end
        end
        else begin
            if(flush_flag)begin
                if(ifu_arvalid & ifu_arready & ifu_rvalid & ifu_rready)begin
                    if(inst_cnt != 3'h0)
                        invalid_cnt <= {1'b1,inst_cnt};
                end
                else if(ifu_arvalid & ifu_arready)begin
                    invalid_cnt <= {1'b1,inst_cnt_more};
                end
                else if(ifu_rvalid & ifu_rready)begin
                    if(inst_cnt != 3'h1)
                        invalid_cnt <= {1'b1,inst_cnt_less};
                end
                else begin
                    if(inst_cnt != 3'h0)
                        invalid_cnt <= {1'b1,inst_cnt};
                end
            end
        end
    end
end
`else
always @(*) begin
    invalid_cnt = 4'h0;
end
`endif 

ifu_fifo #(
    .DATA_LEN   	( 66  ),
    .AddR_Width 	( 2   )
) u_ifu_fifo
(
    .clk    	( clk                       ),
    .rst_n  	( rst_n                     ),
    .Wready 	( fifo_wen                  ),
    .empty      ( inst_empty                ),
    .Rready 	( fifo_ren                  ),
    .flush  	( flush_flag                ),
    .wdata  	( {ifu_rresp,ifu_rdata}     ),
    .rdata  	( {rresp_rdata,inst_rdata}  )
);

assign fifo_wen = ifu_rvalid&ifu_rready&(invalid_cnt==4'h0);
assign fifo_ren = status4_after_jump_flag | (status2_can_conver_flag & (inst_rdata_reg_get[1:0] == 2'b11)) | status3_can_conver_flag;
assign ifu_rready   = 1;


//ifu - idu interface part

//使用fifo后半段输出输出  使用fifo中半段输出输出 使用fifo前半段输出输出  使用fifo的前半段和reg的后半段输出
//status1                ->status2            ->status3             ->status4

inst16_to_32 u_inst16_to_32(
    .input_inst 	( inst_rdata_reg_get[15:0]  ),
    .output_inst 	( inst_rdata_reg_tran       )
);

always @(posedge clk or negedge rst_n) begin
    if(!rst_n)begin
        my_reg_PC_reg <= RST_PC;
    end
    else if(jump_flag)begin
        my_reg_PC_reg <= jump_addr;
    end
    else begin
        case (status)
            STATUS1: begin
                if(reg_can_change_flag & (inst_rdata_reg_get[1:0] != 2'b11))begin
                    my_reg_PC_reg <= my_reg_PC_reg + 2;
                end
                else if(reg_can_change_flag)begin
                    my_reg_PC_reg <= my_reg_PC_reg + 4;
                end
            end
            STATUS2: begin
                if(reg_can_change_flag & (inst_rdata_reg_get[1:0]!=2'b11))begin
                    my_reg_PC_reg <= my_reg_PC_reg + 2;
                end
                else if(reg_can_change_flag)begin
                    my_reg_PC_reg <= my_reg_PC_reg + 4;
                end
            end
            STATUS3: begin
                if(reg_can_change_flag & (inst_rdata_reg_get[1:0]!=2'b11))begin
                    my_reg_PC_reg <= my_reg_PC_reg + 2;
                end
                else if(reg_can_change_flag)begin
                    my_reg_PC_reg <= my_reg_PC_reg + 4;
                end
            end
            STATUS4: begin
                if(reg_can_change_flag & (inst_rdata_reg_get[1:0]!=2'b11))begin
                    my_reg_PC_reg <= my_reg_PC_reg + 2;
                end
                else if(reg_can_change_flag)begin
                    my_reg_PC_reg <= my_reg_PC_reg + 4;
                end
            end
            default: begin
                my_reg_PC_reg <= 64'h0;
            end
        endcase
    end
end

always @(*) begin
    case (my_reg_PC_reg[2:1])
        2'h0: begin
            status = STATUS1;
        end
        2'h1: begin
            status = STATUS2;
        end
        2'h2: begin
            status = STATUS3;
        end
        2'h3: begin
            status = STATUS4;
        end
        default: begin
            status = STATUS1;
        end
    endcase
end

//+---------------+-----------------+
//|inst_rdata     |inst_rdata_reg   |
//|_______________|_________________|
//|63|62|61|....|0|15|14|13|12|...|0|
//|               |                 |
//+---------------|-----------------|
always @(*) begin
    case (status)
        STATUS1: begin
            inst_rdata_reg_get = inst_rdata[31:0];
        end
        STATUS2: begin
            inst_rdata_reg_get = inst_rdata[47:16];
        end
        STATUS3: begin
            inst_rdata_reg_get = inst_rdata[63:32];
        end
        STATUS4: begin
            inst_rdata_reg_get = {inst_rdata[15:0], inst_rdata_reg};
        end
        default: begin
            inst_rdata_reg_get = 32'h0;
        end
    endcase
end

FF_D_with_syn_rst_without_asyn #(
    .DATA_LEN 	( 1  ),
    .RST_DATA 	( 0  )
)u_inst_my_reg_valid
(
    .clk      	( clk               ),
    .syn_rst  	( flush_flag        ),
    .wen      	( fifo_ren          ),
    .data_in  	( 1'b1              ),
    .data_out 	( inst_my_reg_valid )
);


FF_D_without_asyn_rst #(
    .DATA_LEN 	( 16  )
)u_inst_rdata_reg
(
    .clk      	( clk               ),
    .wen    	( fifo_ren          ),
    .data_in  	( inst_rdata[63:48] ),
    .data_out 	( inst_rdata_reg    )
);

FF_D_without_asyn_rst #(
    .DATA_LEN 	(  2  )
)u_rresp_rdata_reg
(
    .clk      	( clk               ),
    .wen    	( fifo_ren          ),
    .data_in  	( rresp_rdata       ),
    .data_out 	( rresp_rdata_reg   )
);


FF_D_with_syn_rst #(
    .DATA_LEN 	( 1  ),
    .RST_DATA 	( 0  )
)u_inst_valid_1
(
    .clk      	( clk                   ),
    .rst_n    	( rst_n                 ),
    .syn_rst    ( flush_flag            ),
    .wen        ( reg1_can_cover_flag   ),
    .data_in  	( reg1_can_change_flag  ),
    .data_out 	( IF_ID_reg_inst_valid_1)
);

FF_D_without_asyn_rst #(2)u_rresp_1             (.clk(clk),.wen(reg1_can_change_flag),.data_in(rresp_to_idu),            .data_out(IF_ID_reg_rresp_1));
FF_D_without_asyn_rst #(32)u_inst_1             (.clk(clk),.wen(reg1_can_change_flag),.data_in(inst_to_idu),             .data_out(IF_ID_reg_inst_1));
FF_D_without_asyn_rst #(16)u_inst_compress_1    (.clk(clk),.wen(reg1_can_change_flag),.data_in(inst_rdata_reg_get[15:0]),.data_out(IF_ID_reg_inst_compress_1));
FF_D_without_asyn_rst #(64)u_PC_1               (.clk(clk),.wen(reg1_can_change_flag),.data_in(my_reg_PC_reg),           .data_out(IF_ID_reg_PC_1));
FF_D_without_asyn_rst #(64)u_tval_1             (.clk(clk),.wen(reg1_can_change_flag),.data_in(tval_to_idu),             .data_out(IF_ID_reg_tval_1));
FF_D_without_asyn_rst #(1)u_inst_compress_flag_1(.clk(clk),.wen(reg1_can_change_flag),.data_in(inst_compress_flag),      .data_out(IF_ID_reg_inst_compress_flag_1));
assign reg1_can_cover_flag  = ((!IF_ID_reg_inst_valid_1) | ((!IF_ID_reg_sel_reg) & ID_IF_inst_ready));
assign reg1_can_change_flag = (reg_can_change_flag & (((!IF_ID_reg_sel_reg) & (!IF_ID_reg_inst_valid_1)) | (IF_ID_reg_sel_reg & IF_ID_reg_inst_valid_2)));

FF_D_with_syn_rst #(
    .DATA_LEN 	( 1  ),
    .RST_DATA 	( 0  )
)u_inst_valid_2
(
    .clk      	( clk                    ),
    .rst_n    	( rst_n                  ),
    .syn_rst    ( flush_flag             ),
    .wen        ( reg2_can_cover_flag    ),
    .data_in  	( reg2_can_change_flag   ),
    .data_out 	( IF_ID_reg_inst_valid_2 )
);

FF_D_without_asyn_rst #(2)u_rresp_2             (.clk(clk),.wen(reg2_can_change_flag),.data_in(rresp_to_idu),.data_out(IF_ID_reg_rresp_2));
FF_D_without_asyn_rst #(32)u_inst_2             (.clk(clk),.wen(reg2_can_change_flag),.data_in(inst_to_idu),.data_out(IF_ID_reg_inst_2));
FF_D_without_asyn_rst #(16)u_inst_compress_2    (.clk(clk),.wen(reg2_can_change_flag),.data_in(inst_rdata_reg_get[15:0]),.data_out(IF_ID_reg_inst_compress_2));
FF_D_without_asyn_rst #(64)u_PC_2               (.clk(clk),.wen(reg2_can_change_flag),.data_in(my_reg_PC_reg),.data_out(IF_ID_reg_PC_2));
FF_D_without_asyn_rst #(64)u_tval_2             (.clk(clk),.wen(reg2_can_change_flag),.data_in(tval_to_idu), .data_out(IF_ID_reg_tval_2));
FF_D_without_asyn_rst #(1)u_inst_compress_flag_2(.clk(clk),.wen(reg2_can_change_flag),.data_in(inst_compress_flag),.data_out(IF_ID_reg_inst_compress_flag_2));
assign reg2_can_cover_flag  = ((!IF_ID_reg_inst_valid_2) | (IF_ID_reg_sel_reg & ID_IF_inst_ready));
assign reg2_can_change_flag = (reg_can_change_flag & (((!IF_ID_reg_sel_reg) & IF_ID_reg_inst_valid_1) | (IF_ID_reg_sel_reg & (!IF_ID_reg_inst_valid_2))));

FF_D_with_syn_rst #(
    .DATA_LEN 	( 1  ),
    .RST_DATA 	( 0  )
)u_IF_ID_reg_sel_reg
(
    .clk      	( clk                                       ),
    .rst_n    	( rst_n                                     ),
    .syn_rst    ( flush_flag                                ),
    .wen        ( IF_ID_reg_inst_valid & ID_IF_inst_ready   ),
    .data_in  	( !IF_ID_reg_sel_reg                        ),
    .data_out 	( IF_ID_reg_sel_reg                         )
);

assign IF_ID_reg_inst_valid                 =   (!IF_ID_reg_sel_reg) ?  IF_ID_reg_inst_valid_1 : IF_ID_reg_inst_valid_2;
assign IF_ID_reg_inst_compress_flag         =   (!IF_ID_reg_sel_reg) ?  IF_ID_reg_inst_compress_flag_1 : IF_ID_reg_inst_compress_flag_2;
assign IF_ID_reg_rresp                      =   (!IF_ID_reg_sel_reg) ?  IF_ID_reg_rresp_1 : IF_ID_reg_rresp_2;
assign IF_ID_reg_inst_compress              =   (!IF_ID_reg_sel_reg) ?  IF_ID_reg_inst_compress_1 : IF_ID_reg_inst_compress_2;
assign IF_ID_reg_inst                       =   (!IF_ID_reg_sel_reg) ?  IF_ID_reg_inst_1 : IF_ID_reg_inst_2;
assign IF_ID_reg_PC                         =   (!IF_ID_reg_sel_reg) ?  IF_ID_reg_PC_1 : IF_ID_reg_PC_2;
assign IF_ID_reg_tval                       =   (!IF_ID_reg_sel_reg) ?  IF_ID_reg_tval_1 : IF_ID_reg_tval_2;

assign status1_can_conver_flag              =   (status == STATUS1) & (reg_can_cover_flag) & (!inst_empty);
assign status2_can_conver_flag              =   (status == STATUS2) & (reg_can_cover_flag) & (!inst_empty);
assign status3_can_conver_flag              =   (status == STATUS3) & (reg_can_cover_flag) & (!inst_empty);
assign status4_can_conver_flag              =   (status == STATUS4) & (reg_can_cover_flag) & (!inst_empty) & (inst_my_reg_valid);
assign status4_after_jump_flag              =   (status == STATUS4) & (reg_can_cover_flag) & (!inst_empty) & (!inst_my_reg_valid);
assign reg_can_cover_flag                   =   (!(IF_ID_reg_inst_valid_1 & IF_ID_reg_inst_valid_2));
assign reg_can_change_flag                  =   status1_can_conver_flag | status2_can_conver_flag | status3_can_conver_flag | status4_can_conver_flag;
assign flush_flag                           =   ID_IF_flush_flag | jump_flag;

assign inst_to_idu = (inst_rdata_reg_get[1:0] == 2'b11) ? inst_rdata_reg_get : inst_rdata_reg_tran;
assign inst_compress_flag = (inst_rdata_reg_get[1:0] != 2'b11) ? 1'b1 : 1'b0;

always @(*) begin
    case (status)
        STATUS1, STATUS2, STATUS3: begin
            rresp_to_idu = rresp_rdata;
        end
        STATUS4: begin
            if(inst_rdata_reg_get[1:0] != 2'b11)begin
                rresp_to_idu = rresp_rdata_reg;
            end
            else begin
                rresp_to_idu = (rresp_rdata_reg != 2'b00) ? rresp_rdata_reg : rresp_rdata;
            end
        end
        default: begin
            rresp_to_idu = 2'h0;
        end
    endcase
end

always @(*) begin
    case (status)
        STATUS1, STATUS2, STATUS3: begin
            tval_to_idu = my_reg_PC_reg;
        end
        STATUS4: begin
            if(inst_rdata_reg_get[1:0] != 2'b11)begin
                tval_to_idu = my_reg_PC_reg;
            end
            else begin
                tval_to_idu = (rresp_rdata_reg != 2'b00) ? my_reg_PC_reg : (my_reg_PC_reg + 64'h2);
            end
        end
        default: begin
            tval_to_idu = 64'h0;
        end
    endcase
end

endmodule //ifu
