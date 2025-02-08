//处理器的32个整数通用寄存器   高电平有效
module DifftestArchIntRegState(
  input  [63:0] io_value_0,			
  input  [63:0] io_value_1,			
  input  [63:0] io_value_2,			
  input  [63:0] io_value_3,
  input  [63:0] io_value_4,
  input  [63:0] io_value_5,
  input  [63:0] io_value_6,
  input  [63:0] io_value_7,
  input  [63:0] io_value_8,
  input  [63:0] io_value_9,
  input  [63:0] io_value_10,
  input  [63:0] io_value_11,
  input  [63:0] io_value_12,
  input  [63:0] io_value_13,
  input  [63:0] io_value_14,
  input  [63:0] io_value_15,
  input  [63:0] io_value_16,
  input  [63:0] io_value_17,
  input  [63:0] io_value_18,
  input  [63:0] io_value_19,
  input  [63:0] io_value_20,
  input  [63:0] io_value_21,
  input  [63:0] io_value_22,
  input  [63:0] io_value_23,
  input  [63:0] io_value_24,
  input  [63:0] io_value_25,
  input  [63:0] io_value_26,
  input  [63:0] io_value_27,
  input  [63:0] io_value_28,
  input  [63:0] io_value_29,
  input  [63:0] io_value_30,
  input  [63:0] io_value_31
);

// import "DPI-C" function void difftest_ArchIntRegState (
//     input   longint io_value_0,
//     input   longint io_value_1,
//     input   longint io_value_2,
//     input   longint io_value_3,
//     input   longint io_value_4,
//     input   longint io_value_5,
//     input   longint io_value_6,
//     input   longint io_value_7,
//     input   longint io_value_8,
//     input   longint io_value_9,
//     input   longint io_value_10,
//     input   longint io_value_11,
//     input   longint io_value_12,
//     input   longint io_value_13,
//     input   longint io_value_14,
//     input   longint io_value_15,
//     input   longint io_value_16,
//     input   longint io_value_17,
//     input   longint io_value_18,
//     input   longint io_value_19,
//     input   longint io_value_20,
//     input   longint io_value_21,
//     input   longint io_value_22,
//     input   longint io_value_23,
//     input   longint io_value_24,
//     input   longint io_value_25,
//     input   longint io_value_26,
//     input   longint io_value_27,
//     input   longint io_value_28,
//     input   longint io_value_29,
//     input   longint io_value_30,
//     input   longint io_value_31,
//     input      byte io_coreid
// );

export "DPI-C" task difftest_ArchIntRegState;

task difftest_ArchIntRegState;
    output  longint out_io_value_0;
    output  longint out_io_value_1;
    output  longint out_io_value_2;
    output  longint out_io_value_3;
    output  longint out_io_value_4;
    output  longint out_io_value_5;
    output  longint out_io_value_6;
    output  longint out_io_value_7;
    output  longint out_io_value_8;
    output  longint out_io_value_9;
    output  longint out_io_value_10;
    output  longint out_io_value_11;
    output  longint out_io_value_12;
    output  longint out_io_value_13;
    output  longint out_io_value_14;
    output  longint out_io_value_15;
    output  longint out_io_value_16;
    output  longint out_io_value_17;
    output  longint out_io_value_18;
    output  longint out_io_value_19;
    output  longint out_io_value_20;
    output  longint out_io_value_21;
    output  longint out_io_value_22;
    output  longint out_io_value_23;
    output  longint out_io_value_24;
    output  longint out_io_value_25;
    output  longint out_io_value_26;
    output  longint out_io_value_27;
    output  longint out_io_value_28;
    output  longint out_io_value_29;
    output  longint out_io_value_30;
    output  longint out_io_value_31;

    out_io_value_0  = io_value_0;
    out_io_value_1  = io_value_1;
    out_io_value_2  = io_value_2;
    out_io_value_3  = io_value_3;
    out_io_value_4  = io_value_4;
    out_io_value_5  = io_value_5;
    out_io_value_6  = io_value_6;
    out_io_value_7  = io_value_7;
    out_io_value_8  = io_value_8;
    out_io_value_9  = io_value_9;
    out_io_value_10 = io_value_10;
    out_io_value_11 = io_value_11;
    out_io_value_12 = io_value_12;
    out_io_value_13 = io_value_13;
    out_io_value_14 = io_value_14;
    out_io_value_15 = io_value_15;
    out_io_value_16 = io_value_16;
    out_io_value_17 = io_value_17;
    out_io_value_18 = io_value_18;
    out_io_value_19 = io_value_19;
    out_io_value_20 = io_value_20;
    out_io_value_21 = io_value_21;
    out_io_value_22 = io_value_22;
    out_io_value_23 = io_value_23;
    out_io_value_24 = io_value_24;
    out_io_value_25 = io_value_25;
    out_io_value_26 = io_value_26;
    out_io_value_27 = io_value_27;
    out_io_value_28 = io_value_28;
    out_io_value_29 = io_value_29;
    out_io_value_30 = io_value_30;
    out_io_value_31 = io_value_31;
endtask

endmodule
