module net_fifo #(parameter DATA_WIDTH = 32,ADDR_WIDTH = 6)(
    input                   clk,
    input                   rst_n,
    input                   Wready,
    input                   Rready,
    input                   flush,
    input  [DATA_WIDTH-1:0] wdata,
    output [ADDR_WIDTH-1:0] data_cnt,
    output [DATA_WIDTH-1:0] rdata
);

localparam DATA_DEPTH = 2** ADDR_WIDTH;

reg [ADDR_WIDTH - 1 : 0] wdata_poi, rdata_poi, data_cnt_reg;
reg [DATA_WIDTH - 1 : 0] fifo_sram[0 : DATA_DEPTH-1];
assign rdata    = fifo_sram[rdata_poi];
assign data_cnt = data_cnt_reg;

always @(posedge clk or negedge rst_n) begin
    if(!rst_n)begin
        wdata_poi       <= {(ADDR_WIDTH){1'b0}};
        rdata_poi       <= {(ADDR_WIDTH){1'b0}};
        data_cnt_reg    <= {(ADDR_WIDTH){1'b0}};
    end
    else begin
        if(flush)begin
            wdata_poi       <= rdata_poi;
            data_cnt_reg    <= {(ADDR_WIDTH){1'b0}};
        end
        else begin
            case ({Wready,Rready})
                2'b11:begin
                    fifo_sram[wdata_poi]    <= wdata;
                    wdata_poi               <= wdata_poi+1'b1;
                    rdata_poi               <= rdata_poi+1'b1;
                end
                2'b10:begin
                    fifo_sram[wdata_poi]    <= wdata;
                    wdata_poi               <= wdata_poi+1'b1;
                    data_cnt_reg            <= data_cnt_reg + 1'b1;
                end
                2'b01:begin
                    rdata_poi               <= rdata_poi+1'b1;
                    data_cnt_reg            <= data_cnt_reg - 1'b1;
                end
                default ;
            endcase
        end
    end
end

endmodule //net_fifo
