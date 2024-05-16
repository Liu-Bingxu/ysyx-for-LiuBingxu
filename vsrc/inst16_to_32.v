// Module that converts compression instructions into normal instructions
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
module inst16_to_32 (
    input [15:0]    input_inst,
    output [31:0]   output_inst
);

wire [2:0] funt3;
wire [1:0] op;

reg [31:0]  output_inst_reg;

always @(*) begin
    case (op)
        2'h0: begin
            case (funt3)
                3'h0: begin
                    if(input_inst[12:5]==8'h0)begin
                        if(input_inst[4:2]==3'h0)begin
                            //illegal instruction
                            output_inst_reg = 32'h0;
                        end
                        else begin
                            //RES for c.addi4spn
                            output_inst_reg = 32'h0;
                        end
                    end
                    else begin
                        //c.addi4spn -> addi rd, x2, uimm
                        output_inst_reg = {{2'h0,input_inst[10:7],input_inst[12:11],input_inst[5],input_inst[6],2'h0},5'h2,3'h0,{2'h1,input_inst[4:2]},7'h13};
                    end
                end
                3'h2:begin
                    //c.lw -> lw rd, uimm(rs1)
                    output_inst_reg = {{5'h0,input_inst[5],input_inst[12:10],input_inst[6],2'h0},{2'h1,input_inst[9:7]},3'h2,{2'h1,input_inst[4:2]},7'h03};
                end
                3'h3:begin
                    //c.ld -> ld rd, uimm(rs1)
                    output_inst_reg = {{4'h0,input_inst[6:5],input_inst[12:10],3'h0},{2'h1,input_inst[9:7]},3'h3,{2'h1,input_inst[4:2]},7'h03};
                end
                3'h6:begin
                    //c.sw -> sw rs2, uimm(rs1)
                    output_inst_reg = {{5'h0,input_inst[5],input_inst[12]},{2'h1,input_inst[4:2]},{2'h1,input_inst[9:7]},3'h2,{input_inst[11:10],input_inst[6],2'h0},7'h23};
                end
                3'h7:begin
                    //c.sd -> sd rs2, uimm(rs1)
                    output_inst_reg = {{4'h0,input_inst[6:5],input_inst[12]},{2'h1,input_inst[4:2]},{2'h1,input_inst[9:7]},3'h3,{input_inst[11:10],3'h0},7'h23};
                end
                default: begin
                    output_inst_reg = 32'h0;
                end
            endcase
        end
        2'h1:begin
            case (funt3)
                3'h0: begin
                    if({input_inst[12],input_inst[6:2]}==6'h0)begin
                        //HINT for c.addi
                        output_inst_reg = `NOP;
                    end
                    else begin
                        //c.addi -> addi rd, rd, imm
                        output_inst_reg = {{{6{input_inst[12]}},input_inst[12],input_inst[6:2]},{input_inst[11:7]},3'h0,{input_inst[11:7]},7'h13};
                    end
                end
                3'h1:begin
                    if(input_inst[11:7]==5'h0) begin
                        //RES for c.addiw
                        output_inst_reg = 32'h0;
                    end
                    else begin
                        //c.addiw -> addiw rd, rd, imm
                        output_inst_reg = {{{6{input_inst[12]}},input_inst[12],input_inst[6:2]},{input_inst[11:7]},3'h0,{input_inst[11:7]},7'h1b};
                    end
                end
                3'h2:begin
                    //c.li -> addi rd, x0, imm
                    output_inst_reg = {{{6{input_inst[12]}},input_inst[12],input_inst[6:2]},5'h0,3'h0,{input_inst[11:7]},7'h13};
                end
                3'h3:begin
                    if(input_inst[11:7]==5'h0)begin
                        //HINT for c.lui
                        output_inst_reg = `NOP;
                    end
                    else if(input_inst[11:7]==5'h2)begin
                        if({input_inst[12],input_inst[6:2]}==6'h0) begin
                            //RES for c.addi16sp
                            output_inst_reg = 32'h0;
                        end
                        else begin
                            //c.addi16sp -> addi x2, x2, imm
                            output_inst_reg = {{{2{input_inst[12]}},input_inst[12],input_inst[4:3],input_inst[5],input_inst[2],input_inst[6],4'h0},5'h2,3'h0,5'h2,7'h13};
                        end
                    end
                    else begin
                        if({input_inst[12],input_inst[6:2]}==6'h0) begin
                            //RES for c.lui
                            output_inst_reg = 32'h0;
                        end
                        else begin
                            //c.lui -> lui rd, imm
                            output_inst_reg = {{{14{input_inst[12]}},input_inst[12],input_inst[6:2]},{input_inst[11:7]},7'h37};
                        end
                    end
                end
                3'h4:begin
                    case (input_inst[11:10])
                        2'h0: begin
                            if({input_inst[12],input_inst[6:2]}==6'h0)begin
                                //HINT for c.srli
                                output_inst_reg = `NOP;
                            end
                            else begin
                                //c.srli -> srli rd, rd, imm
                                output_inst_reg = {{6'h0,input_inst[12],input_inst[6:2]},{2'h1,input_inst[9:7]},3'h5,{2'h1,input_inst[9:7]},7'h13};
                            end
                        end
                        2'h1: begin
                            if({input_inst[12],input_inst[6:2]}==6'h0)begin
                                //HINT for c.srai
                                output_inst_reg = `NOP;
                            end
                            else begin
                                //c.srai -> srai rd, rd, imm
                                output_inst_reg = {{6'h10,input_inst[12],input_inst[6:2]},{2'h1,input_inst[9:7]},3'h5,{2'h1,input_inst[9:7]},7'h13};
                            end
                        end
                        2'h2:begin
                            //c.andi -> andi rd, rd, imm
                            output_inst_reg = {{{6{input_inst[12]}},input_inst[12],input_inst[6:2]},{2'h1,input_inst[9:7]},3'h7,{2'h1,input_inst[9:7]},7'h13};
                        end
                        2'h3:begin
                            case ({input_inst[12],input_inst[6:5]})
                                3'h0: begin
                                    //c.sub -> sub rd, rd, rs2
                                    output_inst_reg = {7'h20,{2'h1,input_inst[4:2]},{2'h1,input_inst[9:7]},3'h0,{2'h1,input_inst[9:7]},7'h33};
                                end
                                3'h1: begin
                                    //c.xor -> xor rd, rd, rs2
                                    output_inst_reg = {7'h0,{2'h1,input_inst[4:2]},{2'h1,input_inst[9:7]},3'h4,{2'h1,input_inst[9:7]},7'h33};
                                end
                                3'h2: begin
                                    //c.or -> or rd, rd, rs2
                                    output_inst_reg = {7'h0,{2'h1,input_inst[4:2]},{2'h1,input_inst[9:7]},3'h6,{2'h1,input_inst[9:7]},7'h33};
                                end
                                3'h3: begin
                                    //c.and -> and rd, rd, rs2
                                    output_inst_reg = {7'h0,{2'h1,input_inst[4:2]},{2'h1,input_inst[9:7]},3'h7,{2'h1,input_inst[9:7]},7'h33};
                                end
                                3'h4: begin
                                    //c.subw -> subw rd, rd, rs2
                                    output_inst_reg = {7'h20,{2'h1,input_inst[4:2]},{2'h1,input_inst[9:7]},3'h0,{2'h1,input_inst[9:7]},7'h3b};
                                end
                                3'h5: begin
                                    //c.addw -> addw rd, rd, rs2
                                    output_inst_reg = {7'h0,{2'h1,input_inst[4:2]},{2'h1,input_inst[9:7]},3'h0,{2'h1,input_inst[9:7]},7'h3b};
                                end
                                default: begin
                                    output_inst_reg = 32'h0;
                                end
                            endcase
                        end
                        default: begin
                            output_inst_reg = 32'h0;
                        end 
                    endcase
                end
                3'h5:begin
                    //c.j -> jal x0, offset
                    output_inst_reg = {{{input_inst[12]},input_inst[8],input_inst[10:9],input_inst[6],input_inst[7],input_inst[2],input_inst[11],input_inst[5:3],input_inst[12],{8{input_inst[12]}}},12'h6f};
                end
                3'h6:begin
                    //c.beqz -> beq rs1, x0, offset
                    output_inst_reg = {{{4{input_inst[12]}},input_inst[6:5],{input_inst[2]}},{2'h1,input_inst[9:7]},8'h0,{input_inst[11:10],input_inst[4:3],input_inst[12]},7'h63};
                end
                3'h7:begin
                    //c.bnez -> bne rs1, x0, offset
                    output_inst_reg = {{{4{input_inst[12]}},input_inst[6:5],{input_inst[2]}},{2'h1,input_inst[9:7]},8'h1,{input_inst[11:10],input_inst[4:3],input_inst[12]},7'h63};
                end
                default: begin
                    output_inst_reg = 32'h0;
                end
            endcase
        end
        2'h2:begin
            case (funt3)
                3'h0: begin
                    if(({input_inst[12],input_inst[6:2]}==6'h0)|(input_inst[11:7]==5'h0))begin
                        //HINT for c.slli
                        output_inst_reg = `NOP;
                    end
                    else begin
                        //c.slli -> slli rd, rd, imm
                        output_inst_reg = {6'h0,{input_inst[12],input_inst[6:2]},{input_inst[11:7]},3'h1,{input_inst[11:7]},7'h13};
                    end
                end
                3'h2:begin
                    if(input_inst[11:7]==5'h0)begin
                        //RES for c.lwsp
                        output_inst_reg = 32'h0;
                    end
                    else begin
                        //c.lwsp -> lw rd, uimm(x2)
                        output_inst_reg = {{4'h0,input_inst[3:2],input_inst[12],input_inst[6:4],2'h0},5'h2,3'h2,input_inst[11:7],7'h03};
                    end
                end
                3'h3:begin
                    if(input_inst[11:7]==5'h0)begin
                        //RES for c.ldsp
                        output_inst_reg = 32'h0;
                    end
                    else begin
                        //c.ldsp -> ld rd, uimm(x2)
                        output_inst_reg = {{3'h0,input_inst[4:2],input_inst[12],input_inst[6:5],3'h0},5'h2,3'h3,input_inst[11:7],7'h03};
                    end
                end
                3'h4:begin
                    if(input_inst[12]==1'b1)begin
                        if(input_inst[11:2]==10'h0)begin
                            //c.ebreak -> ebreak
                            output_inst_reg = {12'h1,20'h73};
                        end
                        else if(input_inst[6:2]==5'h0)begin
                            //c.jalr -> jalr x1, 0(rs1)
                            output_inst_reg = {12'h0,input_inst[11:7],3'h0,5'h1,7'h6f};
                        end
                        else if(input_inst[11:7]==5'h0)begin
                            //HINT for c.add
                            output_inst_reg = `NOP;
                        end
                        else begin
                            //c.add -> add rd, rd, rs2
                            output_inst_reg = {7'h0,input_inst[6:2],input_inst[11:7],3'h0,input_inst[11:7],7'h33};
                        end
                    end
                    else begin
                        if(input_inst[11:2]==10'h0)begin
                            //RES for c.jr
                            output_inst_reg = 32'h0;
                        end
                        else if(input_inst[6:2]==5'h0)begin
                            //c.jr -> jalr x0, 0(rs1)
                            output_inst_reg = {12'h0,input_inst[11:7],3'h0,5'h0,7'h6f};
                        end
                        else if(input_inst[11:7]==5'h0)begin
                            //HINT for c.mv
                            output_inst_reg = `NOP;
                        end
                        else begin
                            //c.mv -> add rd, x0, rs2
                            output_inst_reg = {7'h0,input_inst[6:2],5'h0,3'h0,input_inst[11:7],7'h33};
                        end
                    end
                end
                3'h6:begin
                    //c.swsp -> sw rs2, uimm(x2)
                    output_inst_reg = {{4'h0,input_inst[8:7],input_inst[12]},input_inst[6:2],5'h2,3'h2,{input_inst[11:9],2'h0},7'h23};
                end
                3'h7:begin
                    //c.sdsp -> sd rs2, uimm(x2)
                    output_inst_reg = {{3'h0,input_inst[9:7],input_inst[12]},input_inst[6:2],5'h2,3'h3,{input_inst[11:10],3'h0},7'h23};
                end
                default: begin
                    output_inst_reg = 32'h0;
                end
            endcase
        end
        default:begin
            output_inst_reg = 32'h0;
        end 
    endcase
end

assign funt3 = input_inst[15:13];
assign op = input_inst[1:0];

assign output_inst = output_inst_reg;

endmodule //inst32_to_64
