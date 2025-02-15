module sram_top#(
    // Address width in bits
    parameter AXI_ADDR_W = 64,
    // ID width in bits
    parameter AXI_ID_W = 8,
    // Data width in bits
    parameter AXI_DATA_W = 64,

    parameter RAM_START_ADDR    = 64'h8000_0000,
    parameter RAM_END_ADDR      = 64'h9fff_ffff
) (
    input                           aclk,
    input                           arst_n,

    input                           mst_awvalid,
    output                          mst_awready,
    input  [AXI_ADDR_W    -1:0]     mst_awaddr,
    input  [8             -1:0]     mst_awlen,
    input  [3             -1:0]     mst_awsize,
    input  [2             -1:0]     mst_awburst,
    input                           mst_awlock,
    input  [4             -1:0]     mst_awcache,
    input  [3             -1:0]     mst_awprot,
    input  [4             -1:0]     mst_awqos,
    input  [4             -1:0]     mst_awregion,
    input  [AXI_ID_W      -1:0]     mst_awid,
    input                           mst_wvalid,
    output                          mst_wready,
    input                           mst_wlast,
    input  [AXI_DATA_W    -1:0]     mst_wdata,
    input  [AXI_DATA_W/8  -1:0]     mst_wstrb,
    output                          mst_bvalid,
    input                           mst_bready,
    output [AXI_ID_W      -1:0]     mst_bid,
    output [2             -1:0]     mst_bresp,
    input                           mst_arvalid,
    output                          mst_arready,
    input  [AXI_ADDR_W    -1:0]     mst_araddr,
    input  [8             -1:0]     mst_arlen,
    input  [3             -1:0]     mst_arsize,
    input  [2             -1:0]     mst_arburst,
    input                           mst_arlock,
    input  [4             -1:0]     mst_arcache,
    input  [3             -1:0]     mst_arprot,
    input  [4             -1:0]     mst_arqos,
    input  [4             -1:0]     mst_arregion,
    input  [AXI_ID_W      -1:0]     mst_arid,
    output                          mst_rvalid,
    input                           mst_rready,
    output [AXI_ID_W      -1:0]     mst_rid,
    output [2             -1:0]     mst_rresp,
    output [AXI_DATA_W    -1:0]     mst_rdata,
    output                          mst_rlast
);

reg  [AXI_ID_W      -1:0]     mst_id;
reg  [AXI_ADDR_W    -1:0]     mst_awaddr_reg;
wire [AXI_ADDR_W    -1:0]     mst_awaddr_next;
wire [AXI_ADDR_W    -1:0]     mst_awaddr_increment;
reg  [8             -1:0]     mst_awlen_reg;
reg  [3             -1:0]     mst_awsize_reg;
reg                           mst_wready_reg;

reg  [AXI_ADDR_W    -1:0]     mst_araddr_reg;
wire [AXI_ADDR_W    -1:0]     mst_araddr_increment;
reg  [8             -1:0]     mst_arlen_reg;
reg  [3             -1:0]     mst_arsize_reg;

reg                          mst_resp_reg;

reg [2:0]                    state;
reg                          mst_bvalid_reg;
reg                          mst_rvalid_reg;
localparam  IDLE        = 3'h0;
localparam  READ_PAUSE  = 3'h1;
localparam  READ        = 3'h5;
localparam  WRITE       = 3'h2;
localparam  WRITE_ERROR = 3'h4;
localparam  WBACK       = 3'h3;

localparam ADDR_WIDTH = $clog2(((RAM_END_ADDR - RAM_START_ADDR + 1) * 8) / AXI_DATA_W);
wire                        cs;
wire                        we;
wire [ADDR_WIDTH   -1:0]    addr;

always @(posedge aclk or negedge arst_n) begin
    if(!arst_n)begin
        mst_id <= {AXI_ID_W{1'b0}};
    end
    else if(mst_awvalid & mst_awready)begin
        mst_id <= mst_awid;
    end
    else if(mst_arvalid & mst_arready)begin
        mst_id <= mst_arid;
    end
end

always @(posedge aclk or negedge arst_n) begin
    if(!arst_n)begin
        mst_awaddr_reg  <= {AXI_ADDR_W{1'b0}};
        mst_awlen_reg   <= 8'h0;
        mst_awsize_reg  <= 3'h0;
    end
    else if(mst_awvalid & mst_awready)begin
        mst_awaddr_reg  <= mst_awaddr;
        mst_awlen_reg   <= mst_awlen;
        mst_awsize_reg  <= mst_awsize;
    end
    else if(mst_wvalid & mst_wready)begin
        mst_awaddr_reg  <= mst_awaddr_reg + mst_awaddr_increment;
        mst_awlen_reg   <= mst_awlen_reg - 8'h1;
    end
end

assign mst_awaddr_next      = mst_awaddr_reg + mst_awaddr_increment;

assign mst_awaddr_increment =   {AXI_ADDR_W{1'b0}} | 
                                ({AXI_ADDR_W{mst_awsize_reg == 3'h0 }} & {{(AXI_ADDR_W - 4){1'b0}}, 4'h1}) |
                                ({AXI_ADDR_W{mst_awsize_reg == 3'h1 }} & {{(AXI_ADDR_W - 4){1'b0}}, 4'h2}) |
                                ({AXI_ADDR_W{mst_awsize_reg == 3'h2 }} & {{(AXI_ADDR_W - 4){1'b0}}, 4'h4}) |
                                ({AXI_ADDR_W{mst_awsize_reg == 3'h3 }} & {{(AXI_ADDR_W - 4){1'b0}}, 4'h8});

always @(posedge aclk or negedge arst_n) begin
    if(!arst_n)begin
        mst_araddr_reg  <= {AXI_ADDR_W{1'b0}};
        mst_arlen_reg   <= 8'h0;
        mst_arsize_reg  <= 3'h0;
    end
    else if(mst_arvalid & mst_arready)begin
        mst_araddr_reg  <= mst_araddr;
        mst_arlen_reg   <= mst_arlen;
        mst_arsize_reg  <= mst_awsize;
    end
    else if((state == READ_PAUSE) & (|mst_arlen_reg))begin
        mst_araddr_reg  <= mst_araddr_reg + mst_araddr_increment;
        mst_arlen_reg   <= mst_arlen_reg - 8'h1;
    end
    else if(mst_rvalid & mst_rready)begin
        mst_araddr_reg  <= mst_araddr_reg + mst_araddr_increment;
        mst_arlen_reg   <= mst_arlen_reg - 8'h1;
    end
end

assign mst_araddr_increment =   {AXI_ADDR_W{1'b0}} | 
                                ({AXI_ADDR_W{mst_arsize_reg == 3'h0 }} & {{(AXI_ADDR_W - 4){1'b0}}, 4'h1}) |
                                ({AXI_ADDR_W{mst_arsize_reg == 3'h1 }} & {{(AXI_ADDR_W - 4){1'b0}}, 4'h2}) |
                                ({AXI_ADDR_W{mst_arsize_reg == 3'h2 }} & {{(AXI_ADDR_W - 4){1'b0}}, 4'h4}) |
                                ({AXI_ADDR_W{mst_arsize_reg == 3'h3 }} & {{(AXI_ADDR_W - 4){1'b0}}, 4'h8});

always @(posedge aclk or negedge arst_n) begin
    if(!arst_n)begin
        state           <= IDLE;
        mst_wready_reg  <= 1'b0;
        mst_bvalid_reg  <= 1'b0;
        mst_rvalid_reg  <= 1'b0;
    end
    else begin
        case (state)
            IDLE: begin
                if(mst_awvalid & mst_awready)begin
                    mst_wready_reg      <= 1'b1;
                    if((|mst_awcache) | (|mst_awprot) | mst_awlock | (|mst_awqos) | (|mst_awregion) | (mst_awburst != 2'h1) | ({{(32 - 3){1'b0}}, mst_awsize} > $clog2(AXI_DATA_W/8)))begin
                        state           <= WRITE_ERROR;
                        mst_resp_reg    <= 1'b1;
                    end
                    else if((mst_awaddr >= RAM_START_ADDR) & (mst_awaddr <= RAM_END_ADDR))begin
                        state           <= WRITE;
                        mst_resp_reg    <= 1'b0;
                    end
                    else begin
                        state           <= WRITE_ERROR;
                        mst_resp_reg    <= 1'b1;
                    end
                end
                else if(mst_arvalid & mst_arready)begin
                    state               <= READ_PAUSE;
                    if((|mst_arcache) | (|mst_arprot) | mst_arlock | (|mst_arqos) | (|mst_arregion) | (mst_arburst != 2'h1) | ({{(32 - 3){1'b0}}, mst_arsize} > $clog2(AXI_DATA_W/8)))begin
                        mst_resp_reg    <= 1'b1;
                    end
                    else if((mst_araddr >= RAM_START_ADDR) & (mst_araddr <= RAM_END_ADDR))begin
                        mst_resp_reg    <= 1'b0;
                    end
                    else begin
                        mst_resp_reg    <= 1'b1;
                    end
                end
            end
            READ_PAUSE: begin
                state           <= READ;
                mst_rvalid_reg  <= 1'b1;
            end
            READ: begin
                if(mst_rvalid & mst_rready & mst_rlast)begin
                    state           <= IDLE;
                    mst_rvalid_reg  <= 1'b0;
                end
                else if(mst_rvalid & mst_rready & ((mst_araddr_reg < RAM_START_ADDR) | (mst_araddr_reg > RAM_END_ADDR)))begin
                    mst_resp_reg    <= 1'b1;
                end
            end
            WRITE: begin
                if(mst_wvalid & mst_wready & mst_wlast)begin
                    state           <= WBACK;
                    mst_wready_reg  <= 1'b0;
                    mst_bvalid_reg  <= 1'b1;
                end
                else if(mst_wvalid & mst_wready & ((mst_awaddr_next < RAM_START_ADDR) | (mst_awaddr_next > RAM_END_ADDR)))begin
                    state           <= WRITE_ERROR;
                    mst_resp_reg    <= 1'b1;
                end
            end
            WRITE_ERROR: begin
                if(mst_wvalid & mst_wready & mst_wlast)begin
                    state           <= WBACK;
                    mst_wready_reg  <= 1'b0;
                    mst_bvalid_reg  <= 1'b1;
                end
            end
            WBACK: begin
                if(mst_bvalid & mst_bready)begin
                    state           <= IDLE;
                    mst_bvalid_reg  <= 1'b0;
                end
            end
            default: begin
                state           <= IDLE;
                mst_wready_reg  <= 1'b0;
                mst_bvalid_reg  <= 1'b0;
                mst_rvalid_reg  <= 1'b0;
            end
        endcase
    end
end

sram#(
    .ADDR_WIDTH( ADDR_WIDTH     ),
    .DATA_WIDTH( AXI_DATA_W     ),
    .MASK_WIDTH( AXI_DATA_W/8   )
)u_sram(
    .clk        ( aclk      ),
    .cs         ( cs        ),
    .we         ( we        ),
    .addr       ( addr      ),
    .data_in    ( mst_wdata ),
    .mask       ( mst_wstrb ),
    .data_out   ( mst_rdata )
);

assign cs   =   (((state == READ) & mst_rvalid & mst_rready) | (state == READ_PAUSE) | ((state == WRITE) & mst_wvalid & mst_wready));
assign we   =   (state == WRITE);
assign addr =   {ADDR_WIDTH{1'b0}} | 
                ({ADDR_WIDTH{state == READ       }} & mst_araddr_reg [ADDR_WIDTH + $clog2(AXI_DATA_W/8) -1:$clog2(AXI_DATA_W/8)]) |
                ({ADDR_WIDTH{state == READ_PAUSE }} & mst_araddr_reg [ADDR_WIDTH + $clog2(AXI_DATA_W/8) -1:$clog2(AXI_DATA_W/8)]) |
                ({ADDR_WIDTH{state == WRITE      }} & mst_awaddr_reg [ADDR_WIDTH + $clog2(AXI_DATA_W/8) -1:$clog2(AXI_DATA_W/8)]);

assign mst_awready = (state == IDLE) & (!mst_arvalid);
assign mst_wready  = mst_wready_reg;
assign mst_bvalid  = mst_bvalid_reg;
assign mst_bid     = mst_id;
assign mst_bresp   = {mst_resp_reg, 1'b0};
assign mst_arready = (state == IDLE);
assign mst_rvalid  = mst_rvalid_reg;
assign mst_rid     = mst_id;
assign mst_rresp   = {mst_resp_reg, 1'b0};
assign mst_rlast   = (mst_arlen_reg == 8'h0);

endmodule //sram_top
