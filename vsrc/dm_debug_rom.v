module dm_debug_rom #(
    parameter AXI_DATA_W = 32, 
    parameter ADDR_END   = (AXI_DATA_W == 64) ? 1 : 0
)(
    input  [4:ADDR_END]             addr,
    output [AXI_DATA_W    -1:0]     rom_rdata
);

wire [31 : 0] debug_rom [0 : 31];

assign debug_rom[0]  = 32'h00c0006f;
assign debug_rom[1]  = 32'h0600006f;
assign debug_rom[2]  = 32'h0380006f;
assign debug_rom[3]  = 32'h0ff0000f;
assign debug_rom[4]  = 32'h7b241073;
assign debug_rom[5]  = 32'hf1402473;
assign debug_rom[6]  = 32'h10802023;
assign debug_rom[7]  = 32'h40044403;
assign debug_rom[8]  = 32'h00147413;
assign debug_rom[9]  = 32'h02041463;
assign debug_rom[10] = 32'hf1402473;
assign debug_rom[11] = 32'h40044403;
assign debug_rom[12] = 32'h00247413;
assign debug_rom[13] = 32'h02041863;
assign debug_rom[14] = 32'h10500073;
assign debug_rom[15] = 32'hfd9ff06f;
assign debug_rom[16] = 32'h7b202473;
assign debug_rom[17] = 32'h10002623;
assign debug_rom[18] = 32'h00100073;
assign debug_rom[19] = 32'hf1402473;
assign debug_rom[20] = 32'h10802223;
assign debug_rom[21] = 32'h7b202473;
assign debug_rom[22] = 32'h0ff0000f;
assign debug_rom[23] = 32'h0000100f;
assign debug_rom[24] = 32'h30000067;
assign debug_rom[25] = 32'hf1402473;
assign debug_rom[26] = 32'h10802423;
assign debug_rom[27] = 32'h7b202473;
assign debug_rom[28] = 32'h7b200073;
assign debug_rom[29] = 32'h0;
assign debug_rom[30] = 32'h0;
assign debug_rom[31] = 32'h0;

generate 
    if(AXI_DATA_W == 64) begin : gen_64bit_rom_rdata
        assign rom_rdata = {debug_rom[{addr, 1'b1}], debug_rom[{addr, 1'b0}]};
    end
    else if(AXI_DATA_W == 32) begin : gen_32bit_rom_rdata
        assign rom_rdata = debug_rom[addr];
    end
    else begin : gen_error_messge
        $error("data width error");
    end
endgenerate

endmodule //dm_debug_rom
