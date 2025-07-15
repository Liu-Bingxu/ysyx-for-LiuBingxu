
module DifftestTrapEvent(
    input         clock,
    input         enable,
    input         io_hasTrap,
    input  [63:0] io_cycleCnt,
    input  [63:0] io_instrCnt,
    input         io_hasWFI,
    input  [63:0] io_code,
    input  [63:0] io_pc,
    input  [ 7:0] io_coreid
);

import "DPI-C" function void difftest_TrapEvent (
    input       bit io_hasTrap,
    input   longint io_cycleCnt,
    input   longint io_instrCnt,
    input       bit io_hasWFI,
    input   longint io_code,
    input   longint io_pc,
    input      byte io_coreid
);


always @(posedge clock) begin
    if (enable)
        difftest_TrapEvent (io_hasTrap, io_cycleCnt, io_instrCnt, io_hasWFI, io_code, io_pc, io_coreid);
end

endmodule
