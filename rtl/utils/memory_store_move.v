// The module that will correctly shift the storeed data when storeing data
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

module memory_store_move#(
    parameter DATA_WIDTH = 64,
    parameter OFF_WIDTH  = DATA_WIDTH / 32
)(
    input   [DATA_WIDTH -1:0]   pre_data,
    input   [OFF_WIDTH    :0]   data_offset,
    output  [DATA_WIDTH -1:0]   data
);

wire [DATA_WIDTH -1:0] pre_data_temp[OFF_WIDTH + 1 : 0]/* verilator split_var */;

genvar off_index;
generate 
    for(off_index = 0 ; off_index <= OFF_WIDTH; off_index = off_index + 1) begin : buck_shift
        assign pre_data_temp[off_index + 1] = (!data_offset[off_index]) ? pre_data_temp[off_index] 
                                        : {pre_data_temp[off_index][DATA_WIDTH -1 - (8 * (2 **off_index)): 0], {(8 * (2 **off_index)){1'b0}}};
    end
endgenerate

assign  pre_data_temp[0] = pre_data;

assign data = pre_data_temp[OFF_WIDTH + 1];

endmodule //memory_store_move
