module StoreUncache
(
    input                                               clk,
    input                                               rst_n,

    output                                              StoreQueue_can_write_uc,
    input                                               StoreQueue2Uncache_valid,
    input  [63:0]                                       StoreQueue_Uncache_waddr_o,
    input  [63:0]                                       StoreQueue_Uncache_wdata_o,
    input  [ 7:0]                                       StoreQueue_Uncache_wstrb_o,

    output                                              Uncache_awvalid,
    input                                               Uncache_awready,
    output  [2:0]                                       Uncache_awsize,
    output  [63:0]                                      Uncache_awaddr,

    output                                              Uncache_wvalid,
    input                                               Uncache_wready,
    output [7:0]                                        Uncache_wstrb,
    output [63:0]                                       Uncache_wdata,

    input                                               Uncache_bvalid,
    output                                              Uncache_bready,
    input  [1:0]                                        Uncache_bresp
);

typedef enum logic[2:0] {  
    uc_idle        = 'h0,
    uc_wait_aw_w_0 = 'h1,
    uc_wait_aw_0   = 'h2,
    uc_wait_w_0    = 'h3,
    uc_wait_b_0    = 'h4
} uc_fsm_t;
uc_fsm_t                    uc_fsm;
logic                       uc_send_awvalid;
logic  [63:0]               uc_send_awaddr;
logic                       uc_send_wvalid;
logic [7:0]                 uc_send_wstrb;
logic [63:0]                uc_send_wdata;

always_ff @(posedge clk or negedge rst_n) begin
    if(!rst_n)begin
        uc_fsm          <= uc_idle;
        uc_send_awvalid <= 0;
        uc_send_awaddr  <= 0;
        uc_send_wvalid  <= 0;
        uc_send_wstrb   <= 0;
        uc_send_wdata   <= 0;
    end
    else begin
        case (uc_fsm)
            uc_idle: begin
                if(StoreQueue2Uncache_valid)begin
                    uc_fsm          <= uc_wait_aw_w_0;
                    uc_send_awvalid <= 1;
                    uc_send_awaddr  <= StoreQueue_Uncache_waddr_o;
                    uc_send_wvalid  <= 1;
                    uc_send_wstrb   <= StoreQueue_Uncache_wstrb_o;
                    uc_send_wdata   <= StoreQueue_Uncache_wdata_o;
                end
            end
            uc_wait_aw_w_0 : begin
                if(Uncache_awvalid & Uncache_awready & Uncache_wvalid & Uncache_wready)begin
                    uc_fsm          <= uc_wait_b_0;
                    uc_send_awvalid <= 0;
                    uc_send_wvalid  <= 0;
                end
                else if(Uncache_awvalid & Uncache_awready)begin
                    uc_fsm          <= uc_wait_w_0;
                    uc_send_awvalid <= 0;
                end
                else if(Uncache_wvalid & Uncache_wready)begin
                    uc_fsm          <= uc_wait_aw_0;
                    uc_send_wvalid  <= 0;
                end
            end
            uc_wait_aw_0   : begin
                if(Uncache_awvalid & Uncache_awready)begin
                    uc_fsm          <= uc_wait_b_0;
                    uc_send_awvalid <= 0;
                end
            end
            uc_wait_w_0    : begin
                if(Uncache_wvalid & Uncache_wready)begin
                    uc_fsm          <= uc_wait_b_0;
                    uc_send_wvalid  <= 0;
                end
            end
            uc_wait_b_0    : begin
                if(Uncache_bvalid & Uncache_bready & (Uncache_bresp == 2'h0))begin
                    uc_fsm          <= uc_idle;
                end
            end
            default: begin
                uc_fsm          <= uc_idle;
                uc_send_awvalid <= 0;
                uc_send_awaddr  <= 0;
                uc_send_wvalid  <= 0;
                uc_send_wstrb   <= 0;
                uc_send_wdata   <= 0;
            end
        endcase
    end
end

assign StoreQueue_can_write_uc  = (uc_fsm == uc_idle);

assign Uncache_awvalid          = uc_send_awvalid;
assign Uncache_awsize           = 3'h3;
assign Uncache_awaddr           = uc_send_awaddr;
assign Uncache_wvalid           = uc_send_wvalid;
assign Uncache_wstrb            = uc_send_wstrb;
assign Uncache_wdata            = uc_send_wdata;
assign Uncache_bready           = 1'b1;

endmodule //StoreUncache
