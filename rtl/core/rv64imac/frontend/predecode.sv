`include "./struct.sv"
module predecode(
    input  [32 * IFU_INST_MAX_NUM - 1:0]    i_predecode_inst,
    input  [63:0]                           start_pc,
    input                                   rvi_valid,

    output                                  has_one_branch,
    output                                  has_two_branch,
    output                                  has_three_branch,
    output                                  has_jump,

    output [IFU_INST_MAX_NUM * 1 - 1 : 0]   o_is_valid,
    output [IFU_INST_MAX_NUM * 1 - 1 : 0]   o_decode_eqa,
    output [32 * IFU_INST_MAX_NUM - 1:0]    o_inst,
    output [64 * IFU_INST_MAX_NUM - 1:0]    o_inst_pc,

    output                          one_br_is_rvc,
    output [63:0]                   one_br_bracnch_addr,
    output [BLOCK_BIT_NUM - 1: 0]   one_br_offset,

    output                          two_br_is_rvc,
    output [63:0]                   two_br_bracnch_addr,
    output [BLOCK_BIT_NUM - 1: 0]   two_br_offset,

    output [BLOCK_BIT_NUM - 1: 0]   three_br_offset,

    output                          jump_is_call,
    output                          jump_is_ret,
    output                          jump_is_jalr,
    output                          jump_is_rvc,
    output [63:0]                   jump_bracnch_addr,
    output [BLOCK_BIT_NUM - 1: 0]   jump_offset,

    output                          last_rvi_valid
);

logic [31:0]                   predecode_inst[IFU_INST_MAX_NUM -1 :0];
logic                          is_valid[IFU_INST_MAX_NUM -1 :0];
logic                          decode_eqa[IFU_INST_MAX_NUM -1 :0];
logic                          is_rvc[IFU_INST_MAX_NUM -1 :0];
logic [31:0]                   inst[IFU_INST_MAX_NUM -1 :0];
logic [63:0]                   inst_pc[IFU_INST_MAX_NUM -1 :0];
genvar packed_index;
generate for(packed_index = 0 ; packed_index < IFU_INST_MAX_NUM; packed_index = packed_index + 1) begin : U_gen_packed_index
    assign predecode_inst[packed_index] = i_predecode_inst[32 * packed_index + 31 : 32 * packed_index];
    assign o_is_valid[packed_index]      = is_valid  [packed_index];
    assign o_decode_eqa[packed_index]    = decode_eqa[packed_index];
    assign o_inst[32 * packed_index + 31 : 32 * packed_index]        = inst      [packed_index];
    assign o_inst_pc[64 * packed_index + 63 : 64 * packed_index]     = inst_pc   [packed_index];
end
endgenerate

//don't need export it
logic [BLOCK_BIT_NUM - 2 : 0]  one_branch_index;
logic [BLOCK_BIT_NUM - 2 : 0]  two_branch_index;
logic [BLOCK_BIT_NUM - 2 : 0]  three_branch_index;
logic [BLOCK_BIT_NUM - 2 : 0]  jump_index;

logic                           is_bracnch[IFU_INST_MAX_NUM -1 :0];
logic                           is_jal[IFU_INST_MAX_NUM -1 :0];
logic                           is_call[IFU_INST_MAX_NUM -1 :0];
logic                           is_ret[IFU_INST_MAX_NUM -1 :0];
logic                           is_jalr[IFU_INST_MAX_NUM -1 :0];
logic [63:0]                    bracnch_addr[IFU_INST_MAX_NUM -1 :0];
logic [BLOCK_BIT_NUM - 1: 0]    offset[IFU_INST_MAX_NUM -1 :0];

logic [2:0]                     funct3[IFU_INST_MAX_NUM -1 :0];

logic [63:0]                    imm_I[IFU_INST_MAX_NUM -1 :0];
logic [63:0]                    imm_J[IFU_INST_MAX_NUM -1 :0];
logic [63:0]                    imm_B[IFU_INST_MAX_NUM -1 :0];
logic [63:0]                    imm_cJ[IFU_INST_MAX_NUM -1 :0];
logic [63:0]                    imm_cB[IFU_INST_MAX_NUM -1 :0];
logic [63:0]                    imm[IFU_INST_MAX_NUM -1 :0];

logic                           jal[IFU_INST_MAX_NUM -1 :0];
logic                           jalr[IFU_INST_MAX_NUM -1 :0];
logic                           beq[IFU_INST_MAX_NUM -1 :0];
logic                           bne[IFU_INST_MAX_NUM -1 :0];
logic                           blt[IFU_INST_MAX_NUM -1 :0];
logic                           bltu[IFU_INST_MAX_NUM -1 :0];
logic                           bge[IFU_INST_MAX_NUM -1 :0];
logic                           bgeu[IFU_INST_MAX_NUM -1 :0];
logic                           cj[IFU_INST_MAX_NUM -1 :0];
logic                           cjr[IFU_INST_MAX_NUM -1 :0];
logic                           cjalr[IFU_INST_MAX_NUM -1 :0];
logic                           cbeqz[IFU_INST_MAX_NUM -1 :0];
logic                           cbnez[IFU_INST_MAX_NUM -1 :0];

logic                           B_flag[IFU_INST_MAX_NUM -1 :0];

logic                           jal_call[IFU_INST_MAX_NUM -1 :0];
logic                           jalr_call[IFU_INST_MAX_NUM -1 :0];
logic                           jalr_ret[IFU_INST_MAX_NUM -1 :0];
logic                           cjr_ret[IFU_INST_MAX_NUM -1 :0];

logic                           inst_has_one_branch[IFU_INST_MAX_NUM -1 :0]/* verilator split_var */;
logic [BLOCK_BIT_NUM - 2 : 0]   inst_one_branch_index[IFU_INST_MAX_NUM -1 :0]/* verilator split_var */;
logic                           inst_has_two_branch[IFU_INST_MAX_NUM -1 :0]/* verilator split_var */;
logic [BLOCK_BIT_NUM - 2 : 0]   inst_two_branch_index[IFU_INST_MAX_NUM -1 :0]/* verilator split_var */;
logic                           inst_has_three_branch[IFU_INST_MAX_NUM -1 :0]/* verilator split_var */;
logic [BLOCK_BIT_NUM - 2 : 0]   inst_three_branch_index[IFU_INST_MAX_NUM -1 :0]/* verilator split_var */;
logic                           inst_has_jump[IFU_INST_MAX_NUM -1 :0]/* verilator split_var */;
logic [BLOCK_BIT_NUM - 2 : 0]   inst_jump_index[IFU_INST_MAX_NUM -1 :0]/* verilator split_var */;

logic                           inst_is_valid[IFU_INST_MAX_NUM -1 :0]/* verilator split_var */;
logic                           inst_decode_eqa[IFU_INST_MAX_NUM -1 :0]/* verilator split_var */;
logic                           inst_is_bracnch[IFU_INST_MAX_NUM -1 :0];
logic                           inst_is_jal[IFU_INST_MAX_NUM -1 :0];
logic                           inst_is_call[IFU_INST_MAX_NUM -1 :0];
logic                           inst_is_ret[IFU_INST_MAX_NUM -1 :0];
logic                           inst_is_jalr[IFU_INST_MAX_NUM -1 :0];
logic                           inst_is_rvc[IFU_INST_MAX_NUM -1 :0];
logic [63:0]                    inst_bracnch_addr[IFU_INST_MAX_NUM -1 :0];
logic [BLOCK_BIT_NUM - 1: 0]    inst_offset[IFU_INST_MAX_NUM -1 :0];
logic [31:0]                    inst_inst[IFU_INST_MAX_NUM -1 :0];

genvar inst_index;
generate for(inst_index = 0 ; inst_index < IFU_INST_MAX_NUM; inst_index = inst_index + 1) begin : U_gen_inst_index_decode

    assign funct3[inst_index]       = predecode_inst[inst_index][14:12];
    assign B_flag[inst_index]       = (predecode_inst[inst_index][6:0]==7'b1100011);

    assign jal[inst_index]          =   (predecode_inst[inst_index][6:0]                        ==      7'b1101111  );
    assign jalr[inst_index]         =   ({funct3[inst_index],predecode_inst[inst_index][6:0]}   ==  10'b0001100111  );
    assign cj[inst_index]           =   ({predecode_inst[inst_index][15:13], predecode_inst[inst_index][1:0]} == 5'b10101);
    assign cjr[inst_index]          =   (({predecode_inst[inst_index][15:12], predecode_inst[inst_index][6:0]} == 11'h402) & 
                                        (predecode_inst[inst_index][11:7] != 5'h0));
    assign cjalr[inst_index]        =   (({predecode_inst[inst_index][15:12], predecode_inst[inst_index][6:0]} == 11'h482) & 
                                        (predecode_inst[inst_index][11:7] != 5'h0));

    assign beq[inst_index]          =   (B_flag[inst_index]&(funct3[inst_index]==3'b000));
    assign bne[inst_index]          =   (B_flag[inst_index]&(funct3[inst_index]==3'b001));
    assign blt[inst_index]          =   (B_flag[inst_index]&(funct3[inst_index]==3'b100));
    assign bge[inst_index]          =   (B_flag[inst_index]&(funct3[inst_index]==3'b101));
    assign bltu[inst_index]         =   (B_flag[inst_index]&(funct3[inst_index]==3'b110));
    assign bgeu[inst_index]         =   (B_flag[inst_index]&(funct3[inst_index]==3'b111));

    assign cbeqz[inst_index]        =   ({predecode_inst[inst_index][15:13], predecode_inst[inst_index][1:0]} == 5'b11001);
    assign cbnez[inst_index]        =   ({predecode_inst[inst_index][15:13], predecode_inst[inst_index][1:0]} == 5'b11101);

    assign jal_call[inst_index]     =   (jal[inst_index]  & (predecode_inst[inst_index][11:7] == 5'h1));
    assign jalr_call[inst_index]    =   (jalr[inst_index] & (predecode_inst[inst_index][11:7] == 5'h1));
    assign jalr_ret[inst_index]     =   (predecode_inst[inst_index]       == 32'h8067);
    assign cjr_ret[inst_index]      =   (predecode_inst[inst_index][15:0] == 16'h8082);

    assign imm_I[inst_index]  = {{(52){predecode_inst[inst_index][31]}},predecode_inst[inst_index][31:20]};
    assign imm_B[inst_index]  = {{(52){predecode_inst[inst_index][31]}},predecode_inst[inst_index][7],predecode_inst[inst_index][30:25],predecode_inst[inst_index][11:8],1'b0};
    assign imm_J[inst_index]  = {{(44){predecode_inst[inst_index][31]}},predecode_inst[inst_index][19:12],predecode_inst[inst_index][20],predecode_inst[inst_index][30:21],1'b0};
    assign imm_cB[inst_index] = {{(56){predecode_inst[inst_index][12]}},predecode_inst[inst_index][6:5],predecode_inst[inst_index][2],predecode_inst[inst_index][11:10],predecode_inst[inst_index][4:3],1'b0};
    assign imm_cJ[inst_index] = {{(53){predecode_inst[inst_index][12]}},predecode_inst[inst_index][8],predecode_inst[inst_index][10:9],predecode_inst[inst_index][6],
                                predecode_inst[inst_index][7],predecode_inst[inst_index][2],predecode_inst[inst_index][11],predecode_inst[inst_index][5:3],1'b0};

    assign imm[inst_index] = (jalr[inst_index])?imm_I[inst_index]:(
        (jal[inst_index])?imm_J[inst_index]:(
            (B_flag[inst_index]) ? imm_B[inst_index] : (
                (cj[inst_index]) ? imm_cJ[inst_index] : (
                    (cbeqz[inst_index] | cbnez[inst_index]) ? imm_cB[inst_index] : 64'h0
                )
            )
        )
    );

    if(inst_index == 0)begin: U_gen_valid_0
        assign inst_is_valid[inst_index]        = (rvi_valid) ? 1'b0 : 1'b1;
        assign inst_decode_eqa[inst_index]      = 1'b1;
    end
    else begin: U_gen_valid_another
        assign inst_is_valid[inst_index]        = (inst_is_valid[inst_index - 1] & (!inst_is_rvc[inst_index - 1])) ? 1'b0 : 1'b1;
        assign inst_decode_eqa[inst_index]      = (!inst_has_three_branch[inst_index]) & (!inst_has_jump[inst_index - 1]) & inst_decode_eqa[inst_index - 1];
    end
    assign inst_is_bracnch[inst_index]      = (beq[inst_index] | bne[inst_index] | blt[inst_index] | bge[inst_index] | bltu[inst_index] | bgeu[inst_index] | cbeqz[inst_index] | cbnez[inst_index]);
    assign inst_is_jal[inst_index]          = ((jal[inst_index] & (!jal_call[inst_index])) | cj[inst_index]);
    assign inst_is_call[inst_index]         = (jal_call[inst_index] | jalr_call[inst_index] | cjalr[inst_index]);
    assign inst_is_ret[inst_index]          = (jalr_ret[inst_index] | cjr_ret[inst_index]);
    assign inst_is_jalr[inst_index]         = ((jalr[inst_index] & (!jalr_call[inst_index]) & (!jalr_ret[inst_index])) | (cjr[inst_index] & (!cjr_ret[inst_index])));
    assign inst_is_rvc[inst_index]          = (predecode_inst[inst_index][1:0] != 2'h3);
    assign inst_bracnch_addr[inst_index]    = start_pc + ((!jalr[inst_index]) ? imm[inst_index] : 64'h0) + {{(64 - BLOCK_BIT_NUM){1'b0}}, inst_offset[inst_index]};
    assign inst_offset[inst_index]          = {inst_index[BLOCK_BIT_NUM - 2: 0], 1'b0};
    assign inst_inst[inst_index]            = predecode_inst[inst_index];

    assign is_valid[inst_index]        = inst_is_valid[inst_index]          ;
    assign decode_eqa[inst_index]      = inst_decode_eqa[inst_index]        ;
    assign is_bracnch[inst_index]      = inst_is_bracnch[inst_index]        ;
    assign is_jal[inst_index]          = inst_is_jal[inst_index]            ;
    assign is_call[inst_index]         = inst_is_call[inst_index]           ;
    assign is_ret[inst_index]          = inst_is_ret[inst_index]            ;
    assign is_jalr[inst_index]         = inst_is_jalr[inst_index]           ;
    assign is_rvc[inst_index]          = inst_is_rvc[inst_index]            ;
    assign bracnch_addr[inst_index]    = inst_bracnch_addr[inst_index]      ;
    assign offset[inst_index]          = inst_offset[inst_index]            ;
    assign inst[inst_index]            = inst_inst[inst_index]              ;
    assign inst_pc[inst_index]         = start_pc + {{(64 - BLOCK_BIT_NUM){1'b0}}, inst_offset[inst_index]};

    if(inst_index == 0)begin: U_gen_br_0
        assign inst_has_one_branch[inst_index]      = (is_bracnch[inst_index] & is_valid[inst_index]);
        assign inst_one_branch_index[inst_index]    = inst_index;
        assign inst_has_two_branch[inst_index]      = 1'b0;
        assign inst_two_branch_index[inst_index]    = inst_index;
        assign inst_has_three_branch[inst_index]    = 1'b0;
        assign inst_three_branch_index[inst_index]  = inst_index;
        assign inst_has_jump[inst_index]            = ((is_jal[inst_index] | is_call[inst_index] | is_ret[inst_index] | is_jalr[inst_index]) & is_valid[inst_index]);
        assign inst_jump_index[inst_index]          = inst_index;
    end
    else begin: U_gen_br_another
        assign inst_has_one_branch[inst_index]      = ((is_bracnch[inst_index] & (!inst_has_jump[inst_index - 1]) & is_valid[inst_index]) | inst_has_one_branch[inst_index - 1]);
        assign inst_one_branch_index[inst_index]    = (inst_has_one_branch[inst_index - 1]) ? inst_one_branch_index[inst_index - 1] : inst_index;
        assign inst_has_two_branch[inst_index]      = ((is_bracnch[inst_index] & (!inst_has_jump[inst_index - 1]) & inst_has_one_branch[inst_index - 1] & is_valid[inst_index]) | inst_has_two_branch[inst_index - 1]);
        assign inst_two_branch_index[inst_index]    = (inst_has_two_branch[inst_index - 1]) ? inst_two_branch_index[inst_index - 1] : inst_index;
        assign inst_has_three_branch[inst_index]    = (inst_has_three_branch[inst_index - 1] | 
        ((is_bracnch[inst_index] | is_jal[inst_index] | is_call[inst_index] | is_ret[inst_index] | is_jalr[inst_index]) & (!inst_has_jump[inst_index - 1]) & inst_has_two_branch[inst_index - 1] & is_valid[inst_index]));
        assign inst_three_branch_index[inst_index]  = (inst_has_three_branch[inst_index - 1]) ? inst_three_branch_index[inst_index - 1] : inst_index;
        assign inst_has_jump[inst_index]            = (((is_jal[inst_index] | is_call[inst_index] | is_ret[inst_index] | is_jalr[inst_index]) & (!inst_has_two_branch[inst_index - 1]) & is_valid[inst_index]) |
                                                        inst_has_jump[inst_index - 1]);
        assign inst_jump_index[inst_index]          = (inst_has_jump[inst_index - 1]) ? inst_jump_index[inst_index - 1] : inst_index;
    end
end
endgenerate

assign has_one_branch       = inst_has_one_branch     [IFU_INST_MAX_NUM -1];
assign one_branch_index     = inst_one_branch_index   [IFU_INST_MAX_NUM -1];
assign has_two_branch       = inst_has_two_branch     [IFU_INST_MAX_NUM -1];
assign two_branch_index     = inst_two_branch_index   [IFU_INST_MAX_NUM -1];
assign has_three_branch     = inst_has_three_branch   [IFU_INST_MAX_NUM -1];
assign three_branch_index   = inst_three_branch_index [IFU_INST_MAX_NUM -1];
assign has_jump             = inst_has_jump           [IFU_INST_MAX_NUM -1];
assign jump_index           = inst_jump_index         [IFU_INST_MAX_NUM -1];

assign one_br_is_rvc       = is_rvc[one_branch_index];
assign one_br_bracnch_addr = bracnch_addr[one_branch_index];
assign one_br_offset       = offset[one_branch_index];

assign two_br_is_rvc       = is_rvc[two_branch_index];
assign two_br_bracnch_addr = bracnch_addr[two_branch_index];
assign two_br_offset       = offset[two_branch_index];

assign three_br_offset     = offset[three_branch_index];

assign jump_is_call        = is_call[jump_index];
assign jump_is_ret         = is_ret[jump_index];
assign jump_is_jalr        = is_jalr[jump_index];
assign jump_is_rvc         = is_rvc[jump_index];
assign jump_bracnch_addr   = bracnch_addr[jump_index];
assign jump_offset         = offset[jump_index];

assign last_rvi_valid      = (is_valid[IFU_INST_MAX_NUM -1] & (!is_rvc[IFU_INST_MAX_NUM -1]));

endmodule //predecode
