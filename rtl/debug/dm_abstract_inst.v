module dm_abstract_inst#(
    parameter AXI_DATA_W = 64, 
    parameter ADDR_END   = (AXI_DATA_W == 64) ? 1 : 0
)(
    input  [2:0]                aarsize,
    input                       postexec,
    input                       transfer,
    input                       write,
    input  [15:0]               regno,
    input  [3:ADDR_END]         addr,
    output [AXI_DATA_W    -1:0] abstract_rdata
);

wire [31:0] abstract_inst[0:15];

wire [31:0] no_transfer;
wire [31:0] csr_r_inst[0:4];
wire [31:0] csr_w_inst[0:4];
wire [31:0] gpr_r_inst[0:1];
wire [31:0] gpr_w_inst[0:1];
wire [31:0] gpr_s0_w_inst[0:2];
wire [31:0] fcsr_r_inst[0:10];
wire [31:0] fcsr_w_inst[0:10];
wire [31:0] fgpr_r_inst[0:9];
wire [31:0] fgpr_w_inst[0:9];

wire        csr_is_fpu          = ((regno == 16'h1) | (regno == 16'h2) | (regno == 16'h3)); 

wire        sel_no_transfer     = (!transfer);
wire        sel_csr_r_inst      = (transfer & (regno[15:12] == 4'h0) & (!write) & (!csr_is_fpu));
wire        sel_csr_w_inst      = (transfer & (regno[15:12] == 4'h0) & write & (!csr_is_fpu));
wire        sel_gpr_r_inst      = (transfer & (regno[15:5]  == 11'h080) & (!write));
wire        sel_gpr_w_inst      = (transfer & (regno[15:5]  == 11'h080) & (regno[15:0]  != 16'h1008) & write);
wire        sel_gpr_s0_w_inst   = (transfer & (regno[15:0]  == 16'h1008) & write);
wire        sel_fcsr_r_inst     = (transfer & (regno[15:12] == 4'h0) & (!write) & csr_is_fpu);
wire        sel_fcsr_w_inst     = (transfer & (regno[15:12] == 4'h0) & write & csr_is_fpu);
wire        sel_fgpr_r_inst     = (transfer & (regno[15:5]  == 11'h081) & (!write));
wire        sel_fgpr_w_inst     = (transfer & (regno[15:5]  == 11'h081) & write);

//* jal x0, 0x30; ebreak
assign no_transfer          = (postexec) ? 32'h0300006f : 32'h00100073;

//* csrrw x0, dscratch0, s0
assign csr_r_inst[0] = 32'h7b241073;
//* csrrs s0, csr, x0
assign csr_r_inst[1] = {regno[11:0], 20'h02473};
//* sw/sd s0, 0x380(x0)
assign csr_r_inst[2] = {16'h3880, 1'b0, aarsize, 12'h023};
//* csrrs s0, dscratch0, x0
assign csr_r_inst[3] = 32'h7b202473;
//* jal x0, 0x20; ebreak
assign csr_r_inst[4] = (postexec) ? 32'h0200006f : 32'h00100073;

//* csrrw x0, dscratch0, s0
assign csr_w_inst[0] = 32'h7b241073;
//* lw/ld s0, 0x380(x0)
assign csr_w_inst[1] = {16'h3800, 1'b0, aarsize, 12'h403};
//* csrrw x0, csr, s0
assign csr_w_inst[2] = {regno[11:0], 20'h41073};
//* csrrs s0, dscratch0, x0
assign csr_w_inst[3] = 32'h7b202473;
//* jal x0, 0x20; ebreak
assign csr_w_inst[4] = (postexec) ? 32'h0200006f : 32'h00100073;

//* sw/sd gpr, 0x380(x0)
assign gpr_r_inst[0] = {7'h1c, regno[4:0], 5'h0, aarsize, 12'h023};
//* jal x0, 0x2C; ebreak
assign gpr_r_inst[1] = (postexec) ? 32'h02c0006f : 32'h00100073;

//* lw/ld gpr, 0x380(x0)
assign gpr_w_inst[0] = {16'h3800, 1'b0, aarsize, regno[4:0], 7'h03};
//* jal x0, 0x2C; ebreak
assign gpr_w_inst[1] = (postexec) ? 32'h02c0006f : 32'h00100073;

//* lw/ld gpr, 0x380(x0)
assign gpr_s0_w_inst[0] = {16'h3800, 1'b0, aarsize, regno[4:0], 7'h03};
//* csrrw x0, dscratch0, s0
assign gpr_s0_w_inst[1] = 32'h7b241073;
//* jal x0, 0x28; ebreak
assign gpr_s0_w_inst[2] = (postexec) ? 32'h0280006f : 32'h00100073;

//* csrrw x0, dscratch0, s0
assign fcsr_r_inst[0]  = 32'h7b241073;
//* csrrs s0, mstatus, x0
assign fcsr_r_inst[1]  = 32'h30002473;
//* csrrw x0, dscratch1, s0
assign fcsr_r_inst[2]  = 32'h7b341073;
//* lui s0, 0x6
assign fcsr_r_inst[3]  = 32'h00006437;
//* csrrs x0, mstatus, s0
assign fcsr_r_inst[4]  = 32'h30042073;
//* csrrs s0, csr, x0
assign fcsr_r_inst[5]  = {regno[11:0], 20'h02473};
//* sw/sd s0, 0x380(x0)
assign fcsr_r_inst[6]  = {16'h3880, 1'b0, aarsize, 12'h023};
//* csrrs s0, dscratch1, x0
assign fcsr_r_inst[7]  = 32'h7b302473;
//* csrrw x0, mstatus, s0
assign fcsr_r_inst[8]  = 32'h30041073;
//* csrrs s0, dscratch0, x0
assign fcsr_r_inst[9]  = 32'h7b202473;
//* jal x0, 0x8; ebreak
assign fcsr_r_inst[10] = (postexec) ? 32'h0080006f : 32'h00100073;

//* csrrw x0, dscratch0, s0
assign fcsr_w_inst[0]  = 32'h7b241073;
//* csrrs s0, mstatus, x0
assign fcsr_w_inst[1]  = 32'h30002473;
//* csrrw x0, dscratch1, s0
assign fcsr_w_inst[2]  = 32'h7b341073;
//* lui s0, 0x6
assign fcsr_w_inst[3]  = 32'h00006437;
//* csrrs x0, mstatus, s0
assign fcsr_w_inst[4]  = 32'h30042073;
//* lw/ld s0, 0x380(x0)
assign fcsr_w_inst[5]  = {16'h3800, 1'b0, aarsize, 12'h403};
//* csrrw x0, csr, s0
assign fcsr_w_inst[6]  = {regno[11:0], 20'h41073};
//* csrrs s0, dscratch1, x0
assign fcsr_w_inst[7]  = 32'h7b302473;
//* csrrw x0, mstatus, s0
assign fcsr_w_inst[8]  = 32'h30041073;
//* csrrs s0, dscratch0, x0
assign fcsr_w_inst[9]  = 32'h7b202473;
//* jal x0, 0x8; ebreak
assign fcsr_w_inst[10] = (postexec) ? 32'h0080006f : 32'h00100073;

//* csrrw x0, dscratch0, s0
assign fgpr_r_inst[0]  = 32'h7b241073;
//* csrrs s0, mstatus, x0
assign fgpr_r_inst[1]  = 32'h30002473;
//* csrrw x0, dscratch1, s0
assign fgpr_r_inst[2]  = 32'h7b341073;
//* lui s0, 0x6
assign fgpr_r_inst[3]  = 32'h00006437;
//* csrrs x0, mstatus, s0
assign fgpr_r_inst[4]  = 32'h30042073;
//* fsw/d fgpr, 0x380(x0)
assign fgpr_r_inst[5]  = {7'h1c, regno[4:0], 5'h0, aarsize, 12'h027};
//* csrrs s0, dscratch1, x0
assign fgpr_r_inst[6]  = 32'h7b302473;
//* csrrw x0, mstatus, s0
assign fgpr_r_inst[7]  = 32'h30041073;
//* csrrs s0, dscratch0, x0
assign fgpr_r_inst[8]  = 32'h7b202473;
//* jal x0, 0xC; ebreak
assign fgpr_r_inst[9]  = (postexec) ? 32'h00c0006f : 32'h00100073;

//* csrrw x0, dscratch0, s0
assign fgpr_w_inst[0]  = 32'h7b241073;
//* csrrs s0, mstatus, x0
assign fgpr_w_inst[1]  = 32'h30002473;
//* csrrw x0, dscratch1, s0
assign fgpr_w_inst[2]  = 32'h7b341073;
//* lui s0, 0x6
assign fgpr_w_inst[3]  = 32'h00006437;
//* csrrs x0, mstatus, s0
assign fgpr_w_inst[4]  = 32'h30042073;
//* flw/d fgpr, 0x380(x0)
assign fgpr_w_inst[5]  = {16'h3800, 1'b0, aarsize, regno[4:0], 7'h07};
//* csrrs s0, dscratch1, x0
assign fgpr_w_inst[6]  = 32'h7b302473;
//* csrrw x0, mstatus, s0
assign fgpr_w_inst[7]  = 32'h30041073;
//* csrrs s0, dscratch0, x0
assign fgpr_w_inst[8]  = 32'h7b202473;
//* jal x0, 0xC; ebreak
assign fgpr_w_inst[9]  = (postexec) ? 32'h00c0006f : 32'h00100073;

genvar inst_index;
generate for(inst_index = 0 ; inst_index < 16; inst_index = inst_index + 1) begin : gen_inst
    if(inst_index == 0)begin
        assign abstract_inst[inst_index + 4] = {32{1'b0}}
                | ({32{sel_no_transfer      }} & no_transfer                )
                | ({32{sel_csr_r_inst       }} & csr_r_inst[inst_index]     )
                | ({32{sel_csr_w_inst       }} & csr_w_inst[inst_index]     )
                | ({32{sel_gpr_r_inst       }} & gpr_r_inst[inst_index]     )
                | ({32{sel_gpr_w_inst       }} & gpr_w_inst[inst_index]     )
                | ({32{sel_gpr_s0_w_inst    }} & gpr_s0_w_inst[inst_index]  )
                | ({32{sel_fcsr_r_inst      }} & fcsr_r_inst[inst_index]    )
                | ({32{sel_fcsr_w_inst      }} & fcsr_w_inst[inst_index]    )
                | ({32{sel_fgpr_r_inst      }} & fgpr_r_inst[inst_index]    )
                | ({32{sel_fgpr_w_inst      }} & fgpr_w_inst[inst_index]    )
                ;
    end
    else if(inst_index == 1)begin
        assign abstract_inst[inst_index + 4] = {32{1'b0}}
                | ({32{sel_csr_r_inst       }} & csr_r_inst[inst_index]     )
                | ({32{sel_csr_w_inst       }} & csr_w_inst[inst_index]     )
                | ({32{sel_gpr_r_inst       }} & gpr_r_inst[inst_index]     )
                | ({32{sel_gpr_w_inst       }} & gpr_w_inst[inst_index]     )
                | ({32{sel_gpr_s0_w_inst    }} & gpr_s0_w_inst[inst_index]  )
                | ({32{sel_fcsr_r_inst      }} & fcsr_r_inst[inst_index]    )
                | ({32{sel_fcsr_w_inst      }} & fcsr_w_inst[inst_index]    )
                | ({32{sel_fgpr_r_inst      }} & fgpr_r_inst[inst_index]    )
                | ({32{sel_fgpr_w_inst      }} & fgpr_w_inst[inst_index]    )
                ;
    end
    else if(inst_index == 2)begin
        assign abstract_inst[inst_index + 4] = {32{1'b0}}
                | ({32{sel_csr_r_inst       }} & csr_r_inst[inst_index]     )
                | ({32{sel_csr_w_inst       }} & csr_w_inst[inst_index]     )
                | ({32{sel_gpr_s0_w_inst    }} & gpr_s0_w_inst[inst_index]  )
                | ({32{sel_fcsr_r_inst      }} & fcsr_r_inst[inst_index]    )
                | ({32{sel_fcsr_w_inst      }} & fcsr_w_inst[inst_index]    )
                | ({32{sel_fgpr_r_inst      }} & fgpr_r_inst[inst_index]    )
                | ({32{sel_fgpr_w_inst      }} & fgpr_w_inst[inst_index]    )
                ;
    end
    else if(inst_index < 5)begin
        assign abstract_inst[inst_index + 4] = {32{1'b0}}
                | ({32{sel_csr_r_inst       }} & csr_r_inst[inst_index]     )
                | ({32{sel_csr_w_inst       }} & csr_w_inst[inst_index]     )
                | ({32{sel_fcsr_r_inst      }} & fcsr_r_inst[inst_index]    )
                | ({32{sel_fcsr_w_inst      }} & fcsr_w_inst[inst_index]    )
                | ({32{sel_fgpr_r_inst      }} & fgpr_r_inst[inst_index]    )
                | ({32{sel_fgpr_w_inst      }} & fgpr_w_inst[inst_index]    )
                ;
    end
    else if(inst_index < 10)begin
        assign abstract_inst[inst_index + 4] = {32{1'b0}}
                | ({32{sel_fcsr_r_inst      }} & fcsr_r_inst[inst_index]    )
                | ({32{sel_fcsr_w_inst      }} & fcsr_w_inst[inst_index]    )
                | ({32{sel_fgpr_r_inst      }} & fgpr_r_inst[inst_index]    )
                | ({32{sel_fgpr_w_inst      }} & fgpr_w_inst[inst_index]    )
                ;
    end
    else if(inst_index == 10)begin
        assign abstract_inst[inst_index + 4] = {32{1'b0}}
                | ({32{sel_fcsr_r_inst      }} & fcsr_r_inst[inst_index]    )
                | ({32{sel_fcsr_w_inst      }} & fcsr_w_inst[inst_index]    )
                ;
    end
    else if(inst_index == 11)begin
        assign abstract_inst[inst_index + 4] = {32{1'b0}};
    end
    else begin
        assign abstract_inst[inst_index - 4'hc] = {32{1'b0}};
    end
end
endgenerate

generate 
    if(AXI_DATA_W == 64) begin : gen_64bit_abstract_rdata
        assign abstract_rdata = {abstract_inst[{addr, 1'b1}], abstract_inst[{addr, 1'b0}]};
    end
    else if(AXI_DATA_W == 32) begin : gen_32bit_abstract_rdata
        assign abstract_rdata = abstract_inst[addr];
    end
    else begin : gen_abstract_rdata_error_messge
        `ifdef MODELSIM_SIM
            static_assert(0, "Error: gen_abstract_rdata_error_messge");
        `else
            $error("addr width error");
        `endif
    end
endgenerate

endmodule //dm_abstract_inst
