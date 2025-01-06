// The module that will correctly shift the loaded data when loading data
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

module memory_load_move#(
    parameter DATA_WIDTH = 64,
    parameter HAS_SIGN   = 1,
    parameter OFF_WIDTH  = DATA_WIDTH / 32
)(
    input   [DATA_WIDTH -1:0]   pre_data,
    input   [OFF_WIDTH    :0]   data_offset,
    input                       is_byte,
    input                       is_half,
    input                       is_word,
    input                       is_double,
    input                       is_sign,
    output  [DATA_WIDTH -1:0]   data
);

localparam FILLER_LEN_BYTE      = DATA_WIDTH - 8;
localparam FILLER_LEN_HALF      = DATA_WIDTH - 16;
localparam FILLER_LEN_DOUBLE    = DATA_WIDTH - 32;

wire                   use_sign;

wire [DATA_WIDTH -1:0] data_byte;
wire [DATA_WIDTH -1:0] data_half;
wire [DATA_WIDTH -1:0] data_word;
wire [DATA_WIDTH -1:0] data_double;
wire [DATA_WIDTH -1:0] data_signed_byte;
wire [DATA_WIDTH -1:0] data_signed_half;
wire [DATA_WIDTH -1:0] data_signed_word;
wire [DATA_WIDTH -1:0] data_unsigned_byte;
wire [DATA_WIDTH -1:0] data_unsigned_half;
wire [DATA_WIDTH -1:0] data_unsigned_word;

wire [DATA_WIDTH -1:0] pre_data_out;
wire [DATA_WIDTH -1:0] pre_data_temp[OFF_WIDTH + 1 : 0]/* verilator split_var */;

genvar off_index;
generate 
    for(off_index = 0 ; off_index <= OFF_WIDTH; off_index = off_index + 1) begin : buck_shift
        assign pre_data_temp[off_index + 1] = (!data_offset[off_index]) ? pre_data_temp[off_index] 
                                        : {{(8 * (2 **off_index)){1'b0}}, pre_data_temp[off_index][DATA_WIDTH -1 : 8 * (2 **off_index)]};
    end
endgenerate

generate 
    if(HAS_SIGN == 0) begin : no_sign
        assign use_sign = 1'b0;
    end
    else begin
        if(DATA_WIDTH == 64) begin : gen_64bit_use_sign
            assign use_sign = is_sign;
        end
        else if(DATA_WIDTH == 32) begin : gen_32bit_use_sign
            assign use_sign = (!is_word) & is_sign;
        end
        else begin : gen_error_messge
            $error("data width error");
        end
    end
endgenerate

generate 
    if(DATA_WIDTH == 64) begin : gen_64bit_data
        assign data = {DATA_WIDTH{1'b0}}
                | ({DATA_WIDTH{is_byte  }} & data_byte  )
                | ({DATA_WIDTH{is_half  }} & data_half  )
                | ({DATA_WIDTH{is_word  }} & data_word  )
                | ({DATA_WIDTH{is_double}} & data_double) 
                ;
    end
    else if(DATA_WIDTH == 32) begin : gen_32bit_data
        assign data = {DATA_WIDTH{1'b0}}
                | ({DATA_WIDTH{is_byte  }} & data_byte  )
                | ({DATA_WIDTH{is_half  }} & data_half  )
                | ({DATA_WIDTH{is_word  }} & data_word  )
                ;
    end
    else begin : gen_error_messge
        $error("data width error");
    end
endgenerate

assign  pre_data_temp[0] = pre_data;

assign pre_data_out = pre_data_temp[OFF_WIDTH + 1];

assign data_signed_byte = {{FILLER_LEN_BYTE{pre_data_out[7]} },pre_data_out[7:0] };
assign data_signed_half = {{FILLER_LEN_HALF{pre_data_out[15]}},pre_data_out[15:0]};

assign data_unsigned_byte = {{FILLER_LEN_BYTE{1'b0}},pre_data_out[7:0] };
assign data_unsigned_half = {{FILLER_LEN_HALF{1'b0}},pre_data_out[15:0]};

assign data_signed_word   = {{FILLER_LEN_DOUBLE{pre_data_out[31]}},pre_data_out[31:0] };
assign data_unsigned_word = {{FILLER_LEN_DOUBLE{1'b0}},pre_data_out[31:0]};

assign data_byte    = (use_sign)?data_signed_byte:data_unsigned_byte;
assign data_half    = (use_sign)?data_signed_half:data_unsigned_half;
assign data_word    = (use_sign)?data_signed_word:data_unsigned_word;
assign data_double  = pre_data_out;

// assign data = (is_byte)?data_byte:((is_half)?data_half:((is_word)?data_word:((is_double)?data_double:{64{1'b0}})));

endmodule //memory_load_move
