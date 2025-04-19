module mdio_if (
    input               clk,
    input               rst_n,

    input               sync_rst,

    input               eir_wen,
    input               mmfr_wen,
    input               mscr_wen,
    input  [31:0]       reg_wdata,

    output              mii,
    output [31:0]       mmfr,
    output [31:0]       mscr,

    output              mdc,
    input               mdi,
    output              mdo,
    output              mdo_en
);

reg             mii_reg;
reg [31:0]      mmfr_reg;
reg [17:0]      mdio_rdata;
reg             dis_pre;
reg [5:0]       speed;

localparam IDLE      = 3'h0;
localparam SEND_PRE  = 3'h1;
localparam SEND_ST   = 3'h2;
localparam SEND_DATA = 3'h3;
localparam RECV_DATA = 3'h4;
localparam RECV_TEMP = 3'h5;
reg [2:0]       mdio_state;
reg [5:0]       mdio_cnt;

reg [6:0]       mdc_cnt;

wire            op_done;

reg             mdc_reg;
reg             mdo_reg;
reg             mdo_en_reg;

assign op_done = ((mdio_state == RECV_TEMP) & (mdio_cnt == speed)) | 
                    ((mdio_state == SEND_DATA) & (mdc_cnt == {speed, 1'b1}) & (mdio_cnt == 6'd31));

always @(posedge clk or negedge rst_n) begin
    if(!rst_n)begin
        mii_reg <= 1'b0;
    end
    else if(sync_rst)begin
        mii_reg <= 1'b0;
    end
    else if(op_done)begin
        mii_reg <= 1'b1;
    end
    else if(eir_wen & reg_wdata[23])begin
        mii_reg <= 1'b0;
    end
end

always @(posedge clk or negedge rst_n) begin
    if(!rst_n)begin
        mmfr_reg <= 32'b0;
    end
    else if(sync_rst)begin
        mmfr_reg <= 32'b0;
    end
    else if(op_done & mmfr_reg[29])begin
        mmfr_reg <= {mmfr_reg[31:18], mdio_rdata};
    end
    else if(mmfr_wen)begin
        mmfr_reg <= reg_wdata;
    end
end

always @(posedge clk or negedge rst_n) begin
    if(!rst_n)begin
        dis_pre <= 1'b0;
    end
    else if(sync_rst)begin
        dis_pre <= 1'b0;
    end
    else if(mscr_wen)begin
        dis_pre <= reg_wdata[7];
    end
end

always @(posedge clk or negedge rst_n) begin
    if(!rst_n)begin
        speed <= 6'b0;
    end
    else if(sync_rst)begin
        speed <= 6'b0;
    end
    else if(mscr_wen)begin
        speed <= reg_wdata[6:1];
    end
end

always @(posedge clk or negedge rst_n) begin
    if(!rst_n)begin
        mdc_reg     <= 1'b1;
        mdc_cnt     <= 7'h0;
    end
    else if(sync_rst)begin
        mdc_reg     <= 1'b1;
        mdc_cnt     <= 7'h0;
    end
    else if((mdio_state == IDLE) | (mdio_state == RECV_TEMP))begin
        mdc_reg     <= 1'b1;
        mdc_cnt     <= 7'h0;
    end
    else begin
        if(mdc_cnt == {1'b0, speed})begin
            mdc_reg     <= 1'b0;
            mdc_cnt     <= mdc_cnt + 1'b1;
        end
        else if(mdc_cnt == {speed, 1'b1})begin
            mdc_reg     <= 1'b1;
            mdc_cnt     <= 7'h0;
        end
        else begin
            mdc_cnt     <= mdc_cnt + 1'b1;
        end
    end
end

always @(posedge clk or negedge rst_n) begin
    if(!rst_n)begin
        mdio_state  <= IDLE;
        mdio_cnt    <= 6'h0;
        mdo_reg     <= 1'b0;
        mdo_en_reg  <= 1'b0;
    end
    else if(sync_rst)begin
        mdio_state  <= IDLE;
        mdio_cnt    <= 6'h0;
        mdo_reg     <= 1'b0;
        mdo_en_reg  <= 1'b0;
    end
    else begin
        case(mdio_state)
            IDLE: begin
                if(mmfr_wen & (|speed))begin
                    mdo_en_reg  <= 1'b1;
                    if(!dis_pre)begin
                        mdio_state  <= SEND_ST;
                    end
                    else begin
                        mdio_state  <= SEND_PRE;
                    end
                end
            end
            SEND_PRE: begin
                if(mdc_cnt == {1'b0, speed})begin
                    mdo_reg     <= 1'b1;
                end
                else if((mdc_cnt == {speed, 1'b1}) & (mdio_cnt == 6'd31))begin
                    mdio_state  <= SEND_ST;
                    mdio_cnt    <= 6'h0;
                end
                else if(mdc_cnt == {speed, 1'b1})begin
                    mdio_cnt    <= mdio_cnt + 1'b1;
                end
            end
            SEND_ST: begin
                if(mdc_cnt == {1'b0, speed})begin
                    mdo_reg     <= mmfr_reg[mdio_cnt[4:0]];
                end
                else if((mdc_cnt == {speed, 1'b1}) & (mdio_cnt == 6'd13) & mmfr[29])begin
                    mdio_state  <= RECV_DATA;
                    mdo_en_reg  <= 1'b0;
                end
                else if((mdc_cnt == {speed, 1'b1}) & (mdio_cnt == 6'd13) & (!mmfr[29]))begin
                    mdio_state  <= SEND_DATA;
                end
                else if(mdc_cnt == {speed, 1'b1})begin
                    mdio_cnt    <= mdio_cnt + 1'b1;
                end
            end
            SEND_DATA: begin
                if(mdc_cnt == {1'b0, speed})begin
                    mdo_reg     <= mmfr_reg[mdio_cnt[4:0]];
                end
                else if((mdc_cnt == {speed, 1'b1}) & (mdio_cnt == 6'd31))begin
                    mdio_state  <= IDLE;
                    mdio_cnt    <= 6'h0;
                    mdo_en_reg  <= 1'b0;
                end
                else if(mdc_cnt == {speed, 1'b1})begin
                    mdio_cnt    <= mdio_cnt + 1'b1;
                end
            end
            RECV_DATA: begin
                if((mdc_cnt == {speed, 1'b1}) & (mdio_cnt == 6'd31))begin
                    mdio_state  <= RECV_TEMP;
                    mdio_cnt    <= 6'h0;
                end
                else if(mdc_cnt == {speed, 1'b1})begin
                    mdio_cnt    <= mdio_cnt + 1'b1;
                end
            end
            RECV_TEMP: begin
                if(mdio_cnt == speed)begin
                    mdio_state  <= IDLE;
                    mdio_cnt    <= 6'h0;
                end
                else begin
                    mdio_cnt    <= mdio_cnt + 1'b1;
                end
            end
            default: begin
                mdio_state  <= IDLE;
                mdio_cnt    <= 6'h0;
                mdo_reg     <= 1'b0;
                mdo_en_reg  <= 1'b0;
            end
        endcase
    end
end

always @(posedge clk or negedge rst_n) begin
    if(!rst_n)begin
        mdio_rdata      <= 18'h0;
    end
    else if(sync_rst)begin
        mdio_rdata      <= 18'h0;
    end
    else if(mdio_state == RECV_DATA)begin
        if(mdc_cnt == {1'b0, speed})begin
            mdio_rdata  <= {mdio_rdata[17:1], mdi};
        end
    end
    else if(mdio_state == RECV_TEMP)begin
        if(mdio_cnt == speed)begin
            mdio_rdata  <= {mdio_rdata[17:1], mdi};
        end
    end
end

assign mii      = mii_reg;
assign mmfr     = mmfr_reg;
assign mscr     = {24'h0, dis_pre, speed, 1'b0};

assign mdc      = mdc_reg;
assign mdo      = mdo_reg;
assign mdo_en   = mdo_en_reg;

endmodule //mdio_if
