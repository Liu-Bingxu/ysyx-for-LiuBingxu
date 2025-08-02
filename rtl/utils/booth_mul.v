// Multiplier using Booth algorithm
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

module booth_mul(
    input               clk,
    input               rst_n,
    input               mul_flush,
    input               mul_valid,
    // output              mul_ready,
    input   [1:0]       mul_signed,
    input   [63:0]      mul_a,
    input   [63:0]      mul_b,
    output  [63:0]      mul_result_hi,
    output  [63:0]      mul_result_lo,
    // output              mul_busy,
    input               mul_o_ready,
    output              mul_o_valid
);

/*
*   | 62'h0 | booth_code0  | 0'h0  |
*   | 60'h0 | booth_code1  | 2'h0  |
*   | 58'h0 | booth_code2  | 4'h0  |
*   | 56'h0 | booth_code3  | 6'h0  |
*   | 54'h0 | booth_code4  | 8'h0  |
*   | 52'h0 | booth_code5  | 10'h0 |
*   | 50'h0 | booth_code6  | 12'h0 |
*   | 48'h0 | booth_code7  | 14'h0 |
*   | 46'h0 | booth_code8  | 16'h0 |
*   | 44'h0 | booth_code9  | 18'h0 |
*   | 42'h0 | booth_code10 | 20'h0 |
*   | 40'h0 | booth_code11 | 22'h0 |
*   | 38'h0 | booth_code12 | 24'h0 |
*   | 36'h0 | booth_code13 | 26'h0 |
*   | 34'h0 | booth_code14 | 28'h0 |
*   | 32'h0 | booth_code15 | 30'h0 |
*   | 30'h0 | booth_code16 | 32'h0 |
*   | 28'h0 | booth_code17 | 34'h0 |
*   | 26'h0 | booth_code18 | 36'h0 |
*   | 24'h0 | booth_code19 | 38'h0 |
*   | 22'h0 | booth_code20 | 40'h0 |
*   | 20'h0 | booth_code21 | 42'h0 |
*   | 18'h0 | booth_code22 | 44'h0 |
*   | 16'h0 | booth_code23 | 46'h0 |
*   | 14'h0 | booth_code24 | 48'h0 |
*   | 12'h0 | booth_code25 | 50'h0 |
*   | 10'h0 | booth_code26 | 52'h0 |
*   |  8'h0 | booth_code27 | 54'h0 |
*   |  6'h0 | booth_code28 | 56'h0 |
*   |  4'h0 | booth_code29 | 58'h0 |
*   |  2'h0 | booth_code30 | 60'h0 |
*   |  0'h0 | booth_code31 | 62'h0 |
*   | -2'h0 | booth_code32 | 64'h0 |
*
*/

wire [64:0] mul_a_sign;
wire [64:0] mul_b_sign;

wire [65:0] booth_code0,  booth_code1,  booth_code2,  booth_code3,  booth_code4,  booth_code5;
wire [65:0] booth_code6,  booth_code7,  booth_code8,  booth_code9,  booth_code10, booth_code11;
wire [65:0] booth_code12, booth_code13, booth_code14, booth_code15, booth_code16, booth_code17;
wire [65:0] booth_code18, booth_code19, booth_code20, booth_code21, booth_code22, booth_code23;
wire [65:0] booth_code24, booth_code25, booth_code26, booth_code27, booth_code28, booth_code29;
wire [65:0] booth_code30, booth_code31, booth_code32;

wire [1:0] h0,  h1,  h2,  h3,  h4,  h5;
wire [1:0] h6,  h7,  h8,  h9,  h10, h11;
wire [1:0] h12, h13, h14, h15, h16, h17;
wire [1:0] h18, h19, h20, h21, h22, h23;
wire [1:0] h24, h25, h26, h27, h28, h29;
wire [1:0] h30, h31, h32;

wire sign0,  sign1,  sign2,  sign3,  sign4,  sign5;
wire sign6,  sign7,  sign8,  sign9,  sign10, sign11;
wire sign12, sign13, sign14, sign15, sign16, sign17;
wire sign18, sign19, sign20, sign21, sign22, sign23;
wire sign24, sign25, sign26, sign27, sign28, sign29;
wire sign30, sign31, sign32;

//? gen booth_2 code

assign mul_a_sign = (mul_signed[1]) ? {mul_a[63], mul_a} : {1'b0, mul_a};
assign mul_b_sign = (mul_signed[0]) ? {mul_b[63], mul_b} : {1'b0, mul_b};

booth2_code_gen#(65) u_booth_code0 (.A(mul_a_sign), .code({mul_b_sign[1:0], 1'b0            }), .product(booth_code0 ), .h(h0 ), .sign_not(sign0 ));
booth2_code_gen#(65) u_booth_code1 (.A(mul_a_sign), .code({mul_b_sign[3:1]                  }), .product(booth_code1 ), .h(h1 ), .sign_not(sign1 ));
booth2_code_gen#(65) u_booth_code2 (.A(mul_a_sign), .code({mul_b_sign[5:3]                  }), .product(booth_code2 ), .h(h2 ), .sign_not(sign2 ));
booth2_code_gen#(65) u_booth_code3 (.A(mul_a_sign), .code({mul_b_sign[7:5]                  }), .product(booth_code3 ), .h(h3 ), .sign_not(sign3 ));
booth2_code_gen#(65) u_booth_code4 (.A(mul_a_sign), .code({mul_b_sign[9:7]                  }), .product(booth_code4 ), .h(h4 ), .sign_not(sign4 ));
booth2_code_gen#(65) u_booth_code5 (.A(mul_a_sign), .code({mul_b_sign[11:9]                 }), .product(booth_code5 ), .h(h5 ), .sign_not(sign5 ));
booth2_code_gen#(65) u_booth_code6 (.A(mul_a_sign), .code({mul_b_sign[13:11]                }), .product(booth_code6 ), .h(h6 ), .sign_not(sign6 ));
booth2_code_gen#(65) u_booth_code7 (.A(mul_a_sign), .code({mul_b_sign[15:13]                }), .product(booth_code7 ), .h(h7 ), .sign_not(sign7 ));
booth2_code_gen#(65) u_booth_code8 (.A(mul_a_sign), .code({mul_b_sign[17:15]                }), .product(booth_code8 ), .h(h8 ), .sign_not(sign8 ));
booth2_code_gen#(65) u_booth_code9 (.A(mul_a_sign), .code({mul_b_sign[19:17]                }), .product(booth_code9 ), .h(h9 ), .sign_not(sign9 ));
booth2_code_gen#(65) u_booth_code10(.A(mul_a_sign), .code({mul_b_sign[21:19]                }), .product(booth_code10), .h(h10), .sign_not(sign10));
booth2_code_gen#(65) u_booth_code11(.A(mul_a_sign), .code({mul_b_sign[23:21]                }), .product(booth_code11), .h(h11), .sign_not(sign11));
booth2_code_gen#(65) u_booth_code12(.A(mul_a_sign), .code({mul_b_sign[25:23]                }), .product(booth_code12), .h(h12), .sign_not(sign12));
booth2_code_gen#(65) u_booth_code13(.A(mul_a_sign), .code({mul_b_sign[27:25]                }), .product(booth_code13), .h(h13), .sign_not(sign13));
booth2_code_gen#(65) u_booth_code14(.A(mul_a_sign), .code({mul_b_sign[29:27]                }), .product(booth_code14), .h(h14), .sign_not(sign14));
booth2_code_gen#(65) u_booth_code15(.A(mul_a_sign), .code({mul_b_sign[31:29]                }), .product(booth_code15), .h(h15), .sign_not(sign15));
booth2_code_gen#(65) u_booth_code16(.A(mul_a_sign), .code({mul_b_sign[33:31]                }), .product(booth_code16), .h(h16), .sign_not(sign16));
booth2_code_gen#(65) u_booth_code17(.A(mul_a_sign), .code({mul_b_sign[35:33]                }), .product(booth_code17), .h(h17), .sign_not(sign17));
booth2_code_gen#(65) u_booth_code18(.A(mul_a_sign), .code({mul_b_sign[37:35]                }), .product(booth_code18), .h(h18), .sign_not(sign18));
booth2_code_gen#(65) u_booth_code19(.A(mul_a_sign), .code({mul_b_sign[39:37]                }), .product(booth_code19), .h(h19), .sign_not(sign19));
booth2_code_gen#(65) u_booth_code20(.A(mul_a_sign), .code({mul_b_sign[41:39]                }), .product(booth_code20), .h(h20), .sign_not(sign20));
booth2_code_gen#(65) u_booth_code21(.A(mul_a_sign), .code({mul_b_sign[43:41]                }), .product(booth_code21), .h(h21), .sign_not(sign21));
booth2_code_gen#(65) u_booth_code22(.A(mul_a_sign), .code({mul_b_sign[45:43]                }), .product(booth_code22), .h(h22), .sign_not(sign22));
booth2_code_gen#(65) u_booth_code23(.A(mul_a_sign), .code({mul_b_sign[47:45]                }), .product(booth_code23), .h(h23), .sign_not(sign23));
booth2_code_gen#(65) u_booth_code24(.A(mul_a_sign), .code({mul_b_sign[49:47]                }), .product(booth_code24), .h(h24), .sign_not(sign24));
booth2_code_gen#(65) u_booth_code25(.A(mul_a_sign), .code({mul_b_sign[51:49]                }), .product(booth_code25), .h(h25), .sign_not(sign25));
booth2_code_gen#(65) u_booth_code26(.A(mul_a_sign), .code({mul_b_sign[53:51]                }), .product(booth_code26), .h(h26), .sign_not(sign26));
booth2_code_gen#(65) u_booth_code27(.A(mul_a_sign), .code({mul_b_sign[55:53]                }), .product(booth_code27), .h(h27), .sign_not(sign27));
booth2_code_gen#(65) u_booth_code28(.A(mul_a_sign), .code({mul_b_sign[57:55]                }), .product(booth_code28), .h(h28), .sign_not(sign28));
booth2_code_gen#(65) u_booth_code29(.A(mul_a_sign), .code({mul_b_sign[59:57]                }), .product(booth_code29), .h(h29), .sign_not(sign29));
booth2_code_gen#(65) u_booth_code30(.A(mul_a_sign), .code({mul_b_sign[61:59]                }), .product(booth_code30), .h(h30), .sign_not(sign30));
booth2_code_gen#(65) u_booth_code31(.A(mul_a_sign), .code({mul_b_sign[63:61]                }), .product(booth_code31), .h(h31), .sign_not(sign31));
booth2_code_gen#(65) u_booth_code32(.A(mul_a_sign), .code({mul_b_sign[64], mul_b_sign[64:63]}), .product(booth_code32), .h(h32), .sign_not(sign32));

//? L1 compressor42 34 -> 18
wire [71:0] l1_0,  l1_1,  l1_2,  l1_3;
wire [73:0] l1_4,  l1_5;
wire [73:0] l1_6,  l1_7,  l1_8,  l1_9,  l1_10, l1_11;
wire [73:0] l1_12, l1_13, l1_14, l1_15, l1_16, l1_17;
wire [73:0] l1_18, l1_19, l1_20, l1_21, l1_22, l1_23;
wire [73:0] l1_24, l1_25, l1_26, l1_27, l1_28, l1_29;
wire [73:0] l1_30, l1_31;
wire [65:0] l1_32, l1_33;

wire [71:0] sum1_0;
wire [73:0] sum1_1,  sum1_2,  sum1_3,  sum1_4,  sum1_5, sum1_6,  sum1_7;

wire [72:0] carry1_0;
wire [74:0] carry1_1,  carry1_2,  carry1_3,  carry1_4,  carry1_5, carry1_6,  carry1_7;

/*
*   | 56'h0 | sum1_0    | 0'h0  |
*   | 55'h0 | carry1_0  | 0'h0  |
*   | 48'h0 | sum1_1    | 6'h0  |

*   | 47'h0 | carry1_1  | 6'h0  |
*   | 40'h0 | sum1_2    | 14'h0 |
*   | 39'h0 | carry1_2  | 14'h0 |

*   | 32'h0 | sum1_3    | 22'h0 |
*   | 31'h0 | carry1_3  | 22'h0 |
*   | 24'h0 | sum1_4    | 30'h0 |

*   | 23'h0 | carry1_4  | 30'h0 |
*   | 16'h0 | sum1_5    | 38'h0 |
*   | 15'h0 | carry1_5  | 38'h0 |

*   |  8'h0 | sum1_6    | 46'h0 |
*   |  7'h0 | carry1_6  | 46'h0 |
*   |  0'h0 | sum1_7    | 54'h0 |

*   | -1'h0 | carry1_7  | 54'h0 |
*   |  0'h0 | l1_32     | 62'h0 |
*   |  0'h0 | l1_33     | 62'h0 |
*/

assign l1_0 = {3'h0, sign0, {2{~sign0}}, booth_code0};
assign l1_1 = {2'h0, 1'b1,  sign1, booth_code1, h0};
assign l1_2 = {1'h1, sign2,booth_code2, h1, 2'h0};
assign l1_3 = {booth_code3, h2, 4'h0};

assign l1_4 = {4'h0, 1'b1,  sign4, booth_code4, h3};
assign l1_5 = {2'h0, 1'b1,  sign5, booth_code5, h4, 2'h0};
assign l1_6 = {1'h1, sign6,booth_code6, h5, 4'h0};
assign l1_7 = {booth_code7, h6, 6'h0};

assign l1_8  = {4'h0, 1'b1,  sign8, booth_code8, h7};
assign l1_9  = {2'h0, 1'b1,  sign9, booth_code9, h8, 2'h0};
assign l1_10 = {1'h1, sign10,booth_code10, h9, 4'h0};
assign l1_11 = {booth_code11, h10, 6'h0};

assign l1_12 = {4'h0, 1'b1,  sign12, booth_code12, h11};
assign l1_13 = {2'h0, 1'b1,  sign13, booth_code13, h12, 2'h0};
assign l1_14 = {1'h1, sign14,booth_code14, h13, 4'h0};
assign l1_15 = {booth_code15, h14, 6'h0};

assign l1_16 = {4'h0, 1'b1,  sign16, booth_code16, h15};
assign l1_17 = {2'h0, 1'b1,  sign17, booth_code17, h16, 2'h0};
assign l1_18 = {1'h1, sign18,booth_code18, h17, 4'h0};
assign l1_19 = {booth_code19, h18, 6'h0};

assign l1_20 = {4'h0, 1'b1,  sign20, booth_code20, h19};
assign l1_21 = {2'h0, 1'b1,  sign21, booth_code21, h20, 2'h0};
assign l1_22 = {1'h1, sign22,booth_code22, h21, 4'h0};
assign l1_23 = {booth_code23, h22, 6'h0};

assign l1_24 = {4'h0, 1'b1,  sign24, booth_code24, h23};
assign l1_25 = {2'h0, 1'b1,  sign25, booth_code25, h24, 2'h0};
assign l1_26 = {1'h1, sign26,booth_code26, h25, 4'h0};
assign l1_27 = {booth_code27, h26, 6'h0};

assign l1_28 = {4'h0, 1'b1,  sign28, booth_code28, h27};
assign l1_29 = {2'h0, 1'b1,  sign29, booth_code29, h28, 2'h0};
assign l1_30 = {1'h1, sign30,booth_code30, h29, 4'h0};
assign l1_31 = {booth_code31, h30, 6'h0};

assign l1_32 = {booth_code32[63:0], h31};
assign l1_33 = {62'h0, h32, 2'h0};

compressor_42#(72) l1_compressor_42_0 ( .data0(l1_0 ), .data1(l1_1 ), .data2(l1_2 ), .data3(l1_3 ), .sum(sum1_0 ), .carry_o(carry1_0 ));
compressor_42#(74) l1_compressor_42_1 ( .data0(l1_4 ), .data1(l1_5 ), .data2(l1_6 ), .data3(l1_7 ), .sum(sum1_1 ), .carry_o(carry1_1 ));
compressor_42#(74) l1_compressor_42_2 ( .data0(l1_8 ), .data1(l1_9 ), .data2(l1_10), .data3(l1_11), .sum(sum1_2 ), .carry_o(carry1_2 ));
compressor_42#(74) l1_compressor_42_3 ( .data0(l1_12), .data1(l1_13), .data2(l1_14), .data3(l1_15), .sum(sum1_3 ), .carry_o(carry1_3 ));
compressor_42#(74) l1_compressor_42_4 ( .data0(l1_16), .data1(l1_17), .data2(l1_18), .data3(l1_19), .sum(sum1_4 ), .carry_o(carry1_4 ));
compressor_42#(74) l1_compressor_42_5 ( .data0(l1_20), .data1(l1_21), .data2(l1_22), .data3(l1_23), .sum(sum1_5 ), .carry_o(carry1_5 ));
compressor_42#(74) l1_compressor_42_6 ( .data0(l1_24), .data1(l1_25), .data2(l1_26), .data3(l1_27), .sum(sum1_6 ), .carry_o(carry1_6 ));
compressor_42#(74) l1_compressor_42_7 ( .data0(l1_28), .data1(l1_29), .data2(l1_30), .data3(l1_31), .sum(sum1_7 ), .carry_o(carry1_7 ));

//? L2 compressor32 18 -> 12
wire [81:0] l2_0,  l2_1,  l2_2;
wire [83:0] l2_3,  l2_4,  l2_5;
wire [83:0] l2_6,  l2_7,  l2_8,  l2_9,  l2_10, l2_11;
wire [81:0] l2_12, l2_13, l2_14;
wire [73:0] l2_15, l2_16, l2_17;

wire [81:0] sum2_0;
wire [83:0] sum2_1,  sum2_2,  sum2_3;
wire [81:0] sum2_4;
wire [73:0] sum2_5;

wire [82:0] carry2_0;
wire [84:0] carry2_1,  carry2_2,  carry2_3;
wire [82:0] carry2_4;
wire [74:0] carry2_5;

/*
*   | 46'h0 | sum2_0    | 0'h0  |
*   | 45'h0 | carry2_0  | 0'h0  |
*   | 38'h0 | sum2_1    | 6'h0  |
*   | 37'h0 | carry2_1  | 6'h0  |

*   | 22'h0 | sum2_2    | 22'h0 |
*   | 21'h0 | carry2_2  | 22'h0 |
*   | 14'h0 | sum2_3    | 30'h0 |
*   | 13'h0 | carry2_3  | 30'h0 |

*   |  0'h0 | sum2_4    | 46'h0 |
*   | -1'h0 | carry2_4  | 46'h0 |
*   |  0'h0 | sum2_5    | 54'h0 |
*   | -1'h0 | carry2_5  | 54'h0 |
*/

assign l2_0  = {8'h0, 1'h1, sign3, sum1_0};
assign l2_1  = {9'h0, carry1_0};
assign l2_2  = {1'h1, sign7, sum1_1, 6'h0};

assign l2_3  = {9'h0, carry1_1};
assign l2_4  = {1'b1, sign11, sum1_2, 8'h0};
assign l2_5  = {1'b0, carry1_2, 8'h0};

assign l2_6  = {8'h0, 1'b1, sign15, sum1_3};
assign l2_7  = {9'h0, carry1_3};
assign l2_8  = {1'b1, sign19, sum1_4, 8'h0};

assign l2_9  = {9'h0, carry1_4};
assign l2_10 = {1'b1, sign23, sum1_5, 8'h0};
assign l2_11 = {1'b0, carry1_5, 8'h0};

assign l2_12 = {6'h0, 1'b1, sign27, sum1_6};
assign l2_13 = {7'h0, carry1_6};
assign l2_14 = {sum1_7, 8'h0};

assign l2_15 = {carry1_7[73:0]};
assign l2_16 = {l1_32, 8'h0};
assign l2_17 = {l1_33, 8'h0};

compressor_32#(82) l2_compressor_32_0 ( .data0(l2_0 ), .data1(l2_1 ), .data2(l2_2 ), .sum(sum2_0 ), .carry_o(carry2_0 ));
compressor_32#(84) l2_compressor_32_1 ( .data0(l2_3 ), .data1(l2_4 ), .data2(l2_5 ), .sum(sum2_1 ), .carry_o(carry2_1 ));
compressor_32#(84) l2_compressor_32_2 ( .data0(l2_6 ), .data1(l2_7 ), .data2(l2_8 ), .sum(sum2_2 ), .carry_o(carry2_2 ));
compressor_32#(84) l2_compressor_32_3 ( .data0(l2_9 ), .data1(l2_10), .data2(l2_11), .sum(sum2_3 ), .carry_o(carry2_3 ));
compressor_32#(82) l2_compressor_32_4 ( .data0(l2_12), .data1(l2_13), .data2(l2_14), .sum(sum2_4 ), .carry_o(carry2_4 ));
compressor_32#(74) l2_compressor_32_5 ( .data0(l2_15), .data1(l2_16), .data2(l2_17), .sum(sum2_5 ), .carry_o(carry2_5 ));


//! TODO pipeline
wire [81:0] sum2_0_reg = sum2_0;
wire [83:0] sum2_1_reg = sum2_1;
wire [83:0] sum2_2_reg = sum2_2;
wire [83:0] sum2_3_reg = sum2_3;
wire [81:0] sum2_4_reg = sum2_4;
wire [73:0] sum2_5_reg = sum2_5;

wire [82:0] carry2_0_reg = carry2_0;
wire [84:0] carry2_1_reg = carry2_1;
wire [84:0] carry2_2_reg = carry2_2;
wire [84:0] carry2_3_reg = carry2_3;
wire [81:0] carry2_4_reg = carry2_4[81:0];
wire [73:0] carry2_5_reg = carry2_5[73:0];

//? L3 compressor42 12 -> 6
wire [90:0] l3_0,  l3_1,  l3_2, l3_3;
wire [92:0] l3_4,  l3_5, l3_6,  l3_7;
wire [81:0] l3_8,  l3_9,  l3_10, l3_11;

wire [90:0] sum3_0;
wire [92:0] sum3_1;
wire [81:0] sum3_2;

wire [91:0] carry3_0;
wire [93:0] carry3_1;
wire [82:0] carry3_2;

/*
*   | 37'h0 | sum3_0    | 0'h0  |
*   | 36'h0 | carry3_0  | 0'h0  |
*   | 13'h0 | sum3_1    | 22'h0 |

*   | 12'h0 | carry3_1  | 22'h0 |
*   |  0'h0 | sum3_2    | 46'h0 |
*   | -1'h0 | carry3_2  | 46'h0 |
*/

assign l3_0 = {9'h0, sum2_0_reg};
assign l3_1 = {8'h0, carry2_0_reg};
assign l3_2 = {1'h0, sum2_1_reg, 6'h0};
assign l3_3 = {carry2_1_reg, 6'h0};

assign l3_4 = {9'h0, sum2_2_reg};
assign l3_5 = {8'h0, carry2_2_reg};
assign l3_6 = {1'h0, sum2_3_reg, 8'h0};
assign l3_7 = {carry2_3_reg, 8'h0};

assign l3_8  = {sum2_4_reg};
assign l3_9  = {carry2_4_reg[81:0]};
assign l3_10 = {sum2_5_reg, 8'h0};
assign l3_11 = {carry2_5_reg, 8'h0};

compressor_42#(91) l3_compressor_42_0 ( .data0(l3_0 ), .data1(l3_1 ), .data2(l3_2 ), .data3(l3_3 ), .sum(sum3_0 ), .carry_o(carry3_0 ));
compressor_42#(93) l3_compressor_42_1 ( .data0(l3_4 ), .data1(l3_5 ), .data2(l3_6 ), .data3(l3_7 ), .sum(sum3_1 ), .carry_o(carry3_1 ));
compressor_42#(82) l3_compressor_42_2 ( .data0(l3_8 ), .data1(l3_9 ), .data2(l3_10), .data3(l3_11), .sum(sum3_2 ), .carry_o(carry3_2 ));

//? L4 compressor32 6 -> 4
wire [114:0] l4_0,  l4_1,  l4_2;
wire [105:0] l4_3,  l4_4,  l4_5;

wire [114:0] sum4_0;
wire [105:0] sum4_1;

wire [115:0] carry4_0;
wire [106:0] carry4_1;

/*
*   | 13'h0 | sum4_0    | 0'h0  |
*   | 12'h0 | carry4_0  | 0'h0  |
*   |  0'h0 | sum4_1    | 22'h0 |
*   | -1'h0 | carry4_1  | 22'h0 |
*/

assign l4_0  = {24'h0, sum3_0};
assign l4_1  = {23'h0, carry3_0};
assign l4_2  = {sum3_1, 22'h0};

assign l4_3  = {12'h0, carry3_1};
assign l4_4  = {sum3_2, 24'h0};
assign l4_5  = {carry3_2[81:0], 24'h0};

compressor_32#(115) l4_compressor_32_0 ( .data0(l4_0 ), .data1(l4_1 ), .data2(l4_2 ), .sum(sum4_0 ), .carry_o(carry4_0 ));
compressor_32#(106) l4_compressor_32_1 ( .data0(l4_3 ), .data1(l4_4 ), .data2(l4_5 ), .sum(sum4_1 ), .carry_o(carry4_1 ));

//? L5 compressor42 4 -> 2
wire [127:0] l5_0,  l5_1, l5_2,  l5_3;

wire [127:0] sum5_0;

wire [128:0] carry5_0;

assign l5_0  = {13'h0, sum4_0};
assign l5_1  = {12'h0, carry4_0};
assign l5_2  = {sum4_1, 22'h0};
assign l5_3  = {carry4_1[105:0], 22'h0};

compressor_42#(128) l5_compressor_42_0 ( .data0(l5_0 ), .data1(l5_1 ), .data2(l5_2 ), .data3(l5_3 ), .sum(sum5_0 ), .carry_o(carry5_0 ));

//! TODO pipeline
wire [127:0] sum5_0_reg = sum5_0;
wire [127:0] carry5_0_reg = carry5_0[127:0];

wire [127:0] res = sum5_0_reg + carry5_0_reg;
assign mul_result_hi = res[127:64];
assign mul_result_lo = res[63:0];

assign mul_o_valid = mul_valid;

endmodule //booth_mul
