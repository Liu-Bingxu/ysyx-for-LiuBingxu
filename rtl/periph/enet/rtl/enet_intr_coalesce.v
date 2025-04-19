module enet_intr_coalesce (
    input                           clk,
    input                           rst_n,

    input                           eir_in,
    input                           intr_coal_wen,

    input [31:0]                    reg_wdata,

    output [31:0]                   intr_coal,

    input                           intr_in,

    output                          intr
);

localparam INTR_IDLE = 1'b0;
localparam INTR_WAIT = 1'b1;

reg         intr_status;
wire        icen;
wire [7:0]  icft;
wire [15:0] ictt;

reg  [7:0]  icft_cnt;
reg  [20:0] ictt_cnt;

FF_D_with_wen #(
    .DATA_LEN 	(1  ),
    .RST_DATA 	(0  ))
u_icen(
    .clk      	(clk                ),
    .rst_n    	(rst_n              ),
    .wen      	(intr_coal_wen      ),
    .data_in  	(reg_wdata[31]      ),
    .data_out 	(icen               )
);
FF_D_with_wen #(
    .DATA_LEN 	(8  ),
    .RST_DATA 	(0  ))
u_icft(
    .clk      	(clk                ),
    .rst_n    	(rst_n              ),
    .wen      	(intr_coal_wen      ),
    .data_in  	(reg_wdata[27:20]   ),
    .data_out 	(icft               )
);
FF_D_with_wen #(
    .DATA_LEN 	(16 ),
    .RST_DATA 	(0  ))
u_ictt(
    .clk      	(clk                ),
    .rst_n    	(rst_n              ),
    .wen      	(intr_coal_wen      ),
    .data_in  	(reg_wdata[15:0]    ),
    .data_out 	(ictt               )
);
assign intr_coal = {icen, 3'h0, icft, 4'h0, ictt};

always @(posedge clk or negedge rst_n) begin
    if(!rst_n)begin
        intr_status <= INTR_IDLE;
    end
    else begin
        case (intr_status)
            INTR_IDLE: begin
                if (icen & intr_in) begin
                    intr_status <= INTR_WAIT;
                end
            end
            INTR_WAIT: begin
                if ((ictt_cnt == {ictt, 5'h0}) | (icft_cnt == icft)) begin
                    intr_status <= INTR_IDLE;
                end
            end
            default: begin
                intr_status <= INTR_IDLE;
            end
        endcase
    end
end
always @(posedge clk) begin
    case (intr_status)
        INTR_IDLE: begin
            if (icen & intr_in) begin
                icft_cnt    <= 8'h1;
                ictt_cnt    <= 21'h1;
            end
        end
        INTR_WAIT: begin
            ictt_cnt    <= ictt_cnt + 21'h1;
            if (intr_in) begin
                icft_cnt    <= icft_cnt + 8'h1;
            end
        end
    endcase
end
wire intr_set = (icen) ? ((intr_status == INTR_WAIT) & ((ictt_cnt == {ictt, 5'h0}) | (icft_cnt == icft))) : intr_in;
wire intr_clr = eir_in;
wire intr_wen = (intr_set | intr_clr);
wire intr_nxt = (intr_set | (!intr_clr));
FF_D_with_wen #(
    .DATA_LEN 	(1  ),
    .RST_DATA 	(0  ))
u_eir_frame(
    .clk      	(clk        ),
    .rst_n    	(rst_n      ),
    .wen      	(intr_wen   ),
    .data_in  	(intr_nxt   ),
    .data_out 	(intr       )
);

endmodule //enet_intr_coalesce
