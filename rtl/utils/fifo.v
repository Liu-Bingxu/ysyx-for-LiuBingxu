// the fifo used by inst fetch unit
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

module fifo#(parameter DATA_W=32,AddR_W=6)(
    input clk,rst_n,Wready,Rready,flush,
    input [DATA_W-1:0] wdata,
    output empty,full,
    output [DATA_W-1:0] rdata
);

localparam Word_Depth = 2** AddR_W;

reg [AddR_W:0] wdata_poi,rdata_poi;
reg [DATA_W-1:0] fifo_sram[0:Word_Depth-1];
assign rdata=fifo_sram[rdata_poi[AddR_W-1:0]];
assign empty = wdata_poi==rdata_poi;
assign full  = (wdata_poi[AddR_W-1:0]==rdata_poi[AddR_W-1:0]) & (wdata_poi[AddR_W]!=rdata_poi[AddR_W]);

always @(posedge clk) begin
    if(Wready)begin
        fifo_sram[wdata_poi[AddR_W-1:0]]<=wdata;
    end
end

always @(posedge clk or negedge rst_n) begin
    if(!rst_n)begin
        wdata_poi<={(AddR_W+1){1'b0}};
        rdata_poi<={(AddR_W+1){1'b0}};
    end
    else begin
        if(flush)begin
            wdata_poi<=rdata_poi;
        end
        else begin
            case ({Wready,Rready})
                2'b11:begin
                    wdata_poi<=wdata_poi+1'b1;
                    rdata_poi<=rdata_poi+1'b1;
                end
                2'b10:begin
                    wdata_poi<=wdata_poi+1'b1;
                end
                2'b01:begin
                    rdata_poi<=rdata_poi+1'b1;
                end
                default ;
            endcase
        end
    end
end

endmodule //ifu_fifo
