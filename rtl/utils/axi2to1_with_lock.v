module axi2to1_with_lock#(
    parameter AXI_ID_I = 1, 
    parameter AXI_ID_D = 2,
    // Address width in bits
    parameter AXI_ADDR_W = 64,
    // ID width in bits
    parameter AXI_ID_W = 4,
    // Data width in bits
    parameter AXI_DATA_W = 64
)(
    input                           clk,
    input                           rst_n,
//interface with icache/ifu
    //read addr channel
    input                           icache_arvalid,
    output                          icache_arready,
    input  [AXI_ADDR_W    -1:0]     icache_araddr,
    input  [8             -1:0]     icache_arlen,
    input  [3             -1:0]     icache_arsize,
    input  [2             -1:0]     icache_arburst,
    input  [AXI_ID_W      -1:0]     icache_arid,
    //read data channel
    output                          icache_rvalid,
    input                           icache_rready,
    output [AXI_ID_W      -1:0]     icache_rid,
    output [2             -1:0]     icache_rresp,
    output [AXI_DATA_W    -1:0]     icache_rdata,
    output                          icache_rlast,
//interface with dcache/lsu
    //read addr channel
    input                           dcache_arvalid,
    output                          dcache_arready,
    input  [AXI_ADDR_W    -1:0]     dcache_araddr,
    input  [8             -1:0]     dcache_arlen,
    input  [3             -1:0]     dcache_arsize,
    input  [2             -1:0]     dcache_arburst,
    input                           dcache_arlock,
    input  [AXI_ID_W      -1:0]     dcache_arid,
    //read data channel
    output                          dcache_rvalid,
    input                           dcache_rready,
    output [AXI_ID_W      -1:0]     dcache_rid,
    output [2             -1:0]     dcache_rresp,
    output [AXI_DATA_W    -1:0]     dcache_rdata,
    output                          dcache_rlast,
    //write addr channel
    input                           dcache_awvalid,
    output                          dcache_awready,
    input  [AXI_ADDR_W    -1:0]     dcache_awaddr,
    input  [8             -1:0]     dcache_awlen,
    input  [3             -1:0]     dcache_awsize,
    input  [2             -1:0]     dcache_awburst,
    input                           dcache_awlock,
    input  [AXI_ID_W      -1:0]     dcache_awid,
    //write data channel
    input                           dcache_wvalid,
    output                          dcache_wready,
    input                           dcache_wlast,
    input  [AXI_DATA_W    -1:0]     dcache_wdata,
    input  [AXI_DATA_W/8  -1:0]     dcache_wstrb,
    //write resp channel
    output                          dcache_bvalid,
    input                           dcache_bready,
    output [AXI_ID_W      -1:0]     dcache_bid,
    output [2             -1:0]     dcache_bresp,
//interface with ysyxsoc
    //write addr channel
    output                          io_master_awvalid,
    input                           io_master_awready,
    output [31:0]                   io_master_awaddr ,
    output [3:0]                    io_master_awid   ,
    output [7:0]                    io_master_awlen  ,
    output [2:0]                    io_master_awsize ,
    output [1:0]                    io_master_awburst,
    //write data channel
    output                          io_master_wvalid ,
    input                           io_master_wready ,
    output [31:0]                   io_master_wdata  ,
    output [3:0]                    io_master_wstrb  ,
    output                          io_master_wlast  ,
    //write resp channel
    input                           io_master_bvalid ,
    output                          io_master_bready ,
    input  [1:0]                    io_master_bresp  ,
    input  [3:0]                    io_master_bid    ,
    //read addr channel
    output                          io_master_arvalid,
    input                           io_master_arready,
    output [31:0]                   io_master_araddr ,
    output [3:0]                    io_master_arid   ,
    output [7:0]                    io_master_arlen  ,
    output [2:0]                    io_master_arsize ,
    output [1:0]                    io_master_arburst,
    //read data channel
    input                           io_master_rvalid ,
    output                          io_master_rready ,
    input  [1:0]                    io_master_rresp  ,
    input  [31:0]                   io_master_rdata  ,
    input                           io_master_rlast  ,
    input  [3:0]                    io_master_rid    
);

// read addr
wire                                    cache_ar_fifo_ren;
wire                                    cache_ar_fifo_wen;
wire                                    cache_ar_fifo_empty;
wire [AXI_ID_W + 44 : 0]                cache_ar_fifo_wdata;
wire [AXI_ID_W + 44 : 0]                cache_ar_fifo_rdata;

wire [8              - 1 : 0]           icache_ar_fifo_rdata_arlen;
wire [3              - 1 : 0]           icache_ar_fifo_rdata_arsize;
wire [AXI_ID_W + 44 : 0]                icache_ar_fifo_wdata;
wire [8              - 1 : 0]           dcache_ar_fifo_rdata_arlen;
wire [3              - 1 : 0]           dcache_ar_fifo_rdata_arsize;
wire [AXI_ID_W + 44 : 0]                dcache_ar_fifo_wdata;

wire [32             - 1 : 0]           cache_ar_fifo_rdata_araddr;
wire [8              - 1 : 0]           cache_ar_fifo_rdata_arlen;
wire [3              - 1 : 0]           cache_ar_fifo_rdata_arsize;
wire [2              - 1 : 0]           cache_ar_fifo_rdata_arburst;
wire [AXI_ID_W       - 1 : 0]           cache_ar_fifo_rdata_arid;

wire                                    dcache_ar_lock;

ifu_fifo #(
    .DATA_LEN   	( 32 + 8 + 3 + 2 + AXI_ID_W ),
    .AddR_Width 	( 2   ))
dcache_ar_fifo(
    .clk    	( clk                   ),
    .rst_n  	( rst_n                 ),
    .Wready 	( cache_ar_fifo_wen     ),
    .Rready 	( cache_ar_fifo_ren     ),
    .flush  	( 1'b0                  ),
    .wdata  	( cache_ar_fifo_wdata   ),
    .empty  	( cache_ar_fifo_empty   ),
    .rdata  	( cache_ar_fifo_rdata   )
);

FF_D_without_asyn_rst #(1)   u_arlock       (clk,dcache_arvalid & dcache_arready,dcache_arlock,dcache_ar_lock);

assign cache_ar_fifo_ren           = io_master_arvalid & io_master_arready;
assign cache_ar_fifo_wen           = ((icache_arvalid & icache_arready) | (dcache_arvalid & dcache_arready));
assign cache_ar_fifo_wdata         = (icache_arvalid & icache_arready) ? icache_ar_fifo_wdata : dcache_ar_fifo_wdata;

assign icache_ar_fifo_rdata_arlen  = (icache_arsize == 3'h3) ? (icache_arlen + icache_arlen + 1'b1) : icache_arlen;
assign icache_ar_fifo_rdata_arsize = (icache_arsize == 3'h3) ? 3'h2 : icache_arsize;
assign icache_ar_fifo_wdata        = {icache_arid, icache_arburst, icache_ar_fifo_rdata_arsize, icache_ar_fifo_rdata_arlen, icache_araddr[31:0]};
assign dcache_ar_fifo_rdata_arlen  = (dcache_arsize == 3'h3) ? (dcache_arlen + dcache_arlen + 1'b1) : dcache_arlen;
assign dcache_ar_fifo_rdata_arsize = (dcache_arsize == 3'h3) ? 3'h2 : dcache_arsize;
assign dcache_ar_fifo_wdata        = {dcache_arid, dcache_arburst, dcache_ar_fifo_rdata_arsize, dcache_ar_fifo_rdata_arlen, dcache_araddr[31:0]};

assign cache_ar_fifo_rdata_araddr  = cache_ar_fifo_rdata[31:0];
assign cache_ar_fifo_rdata_arlen   = cache_ar_fifo_rdata[39:32];
assign cache_ar_fifo_rdata_arsize  = cache_ar_fifo_rdata[42:40];
assign cache_ar_fifo_rdata_arburst = cache_ar_fifo_rdata[44:43];
assign cache_ar_fifo_rdata_arid    = cache_ar_fifo_rdata[AXI_ID_W + 44 : 45];

// read data
reg                                     cache_r_valid_i;
wire [31:0]                             cache_r_data_i;
wire [1:0]                              cache_r_resp_i;

wire [AXI_DATA_W    -1:0]               cache_r_data_ret_i;

always @(posedge clk or negedge rst_n) begin
    if(!rst_n)begin
        cache_r_valid_i <= 1'b0;
    end
    else if(io_master_rvalid & io_master_rready & (!io_master_rlast) & (!cache_r_valid_i) & (io_master_rid == AXI_ID_I))begin
        cache_r_valid_i <= 1'b1;
    end
    else if(io_master_rvalid & io_master_rready & cache_r_valid_i & (io_master_rid == AXI_ID_I))begin
        cache_r_valid_i <= 1'b0;
    end
end
FF_D_without_asyn_rst #(32)  u_r_data_i   (clk,io_master_rvalid & io_master_rready & (!io_master_rlast) & (!cache_r_valid_i) & (io_master_rid == AXI_ID_I),io_master_rdata,cache_r_data_i);
FF_D_without_asyn_rst #(2)   u_r_resp_i   (clk,io_master_rvalid & io_master_rready & (!io_master_rlast) & (!cache_r_valid_i) & (io_master_rid == AXI_ID_I),io_master_rresp,cache_r_resp_i);

assign cache_r_data_ret_i = (cache_r_valid_i) ? {io_master_rdata, cache_r_data_i} : {io_master_rdata, io_master_rdata};

reg                                     cache_r_valid_d;
wire [31:0]                             cache_r_data_d;
wire [1:0]                              cache_r_resp_d;

wire [AXI_DATA_W    -1:0]               cache_r_data_ret_d;

always @(posedge clk or negedge rst_n) begin
    if(!rst_n)begin
        cache_r_valid_d <= 1'b0;
    end
    else if(io_master_rvalid & io_master_rready & (!io_master_rlast) & (!cache_r_valid_d) & (io_master_rid == AXI_ID_D))begin
        cache_r_valid_d <= 1'b1;
    end
    else if(io_master_rvalid & io_master_rready & cache_r_valid_d & (io_master_rid == AXI_ID_D))begin
        cache_r_valid_d <= 1'b0;
    end
end
FF_D_without_asyn_rst #(32)  u_r_data_d  (clk,io_master_rvalid & io_master_rready & (!io_master_rlast) & (!cache_r_valid_d) & (io_master_rid == AXI_ID_D),io_master_rdata,cache_r_data_d);
FF_D_without_asyn_rst #(2)   u_r_resp_d  (clk,io_master_rvalid & io_master_rready & (!io_master_rlast) & (!cache_r_valid_d) & (io_master_rid == AXI_ID_D),io_master_rresp,cache_r_resp_d);

assign cache_r_data_ret_d = (cache_r_valid_d) ? {io_master_rdata, cache_r_data_d} : {io_master_rdata, io_master_rdata};

// atomic table
reg                           reservation_valid;
wire [AXI_ADDR_W    -1:0]     reservation_addr;
wire [3             -1:0]     reservation_size;
always @(posedge clk or negedge rst_n) begin
    if(!rst_n)begin
        reservation_valid <= 1'b0;
    end
    else if(dcache_arvalid & dcache_arready & dcache_arlock)begin
        reservation_valid <= 1'b1;
    end
    else if(io_master_awvalid & io_master_awready & dcache_awlock)begin
        reservation_valid <= 1'b0;
    end
end
FF_D_without_asyn_rst #(AXI_ADDR_W)  u_reservation_addr (clk,dcache_arvalid & dcache_arready & dcache_arlock,dcache_araddr,reservation_addr);
FF_D_without_asyn_rst #(3)           u_reservation_size (clk,dcache_arvalid & dcache_arready & dcache_arlock,dcache_arsize,reservation_size);

localparam IDLE   = 2'h0;
localparam ERROR  = 2'h1;
localparam REPORT = 2'h3;
reg  [1:0]  lock_fsm;
always @(posedge clk or negedge rst_n) begin
    if(!rst_n)begin
        lock_fsm <= IDLE;
    end
    else begin
        case (lock_fsm)
            IDLE: begin
                if(dcache_awvalid & dcache_awready & dcache_awlock & (!(reservation_valid & (dcache_awaddr == reservation_addr) & (dcache_awsize == reservation_size))))begin
                    lock_fsm <= ERROR;
                end
            end
            ERROR: begin
                if(dcache_wvalid & dcache_wready & dcache_wlast)begin
                    lock_fsm <= REPORT;
                end
            end
            REPORT: begin
                if(dcache_bvalid & dcache_bready)begin
                    lock_fsm <= IDLE;
                end
            end
            default: begin
                lock_fsm <= IDLE;
            end
        endcase
    end
end

// write addr
reg                                     dcache_aw_valid;
wire [31:0]                             dcache_aw_addr;
wire [3:0]                              dcache_aw_id;
wire [7:0]                              dcache_aw_len;
wire [2:0]                              dcache_aw_size;
wire [2:0]                              dcache_awsize_get;
wire [1:0]                              dcache_aw_burst;
wire                                    dcache_aw_lock;
always @(posedge clk or negedge rst_n) begin
    if(!rst_n)begin
        dcache_aw_valid <= 1'b0;
    end
    else if(dcache_awvalid & dcache_awready & (!dcache_awlock))begin
        dcache_aw_valid <= 1'b1;
    end
    else if(dcache_awvalid & dcache_awready & dcache_awlock & reservation_valid & (dcache_awaddr == reservation_addr) & (dcache_awsize == reservation_size))begin
        dcache_aw_valid <= 1'b1;
    end
    else if(io_master_awvalid & io_master_awready)begin
        dcache_aw_valid <= 1'b0;
    end
end
wire [7:0] awlen    = (dcache_awsize == 3'h3) ? (dcache_awlen + dcache_awlen + 1'b1) : dcache_awlen;
wire [2:0] awsize   = (dcache_awsize == 3'h3) ? 3'h2 : dcache_awsize;
FF_D_without_asyn_rst #(32)  u_aw_addr      (clk,dcache_awvalid & dcache_awready,dcache_awaddr[31:0],dcache_aw_addr);
FF_D_without_asyn_rst #(4)   u_aw_id        (clk,dcache_awvalid & dcache_awready,dcache_awid,dcache_aw_id);
FF_D_without_asyn_rst #(8)   u_aw_len       (clk,dcache_awvalid & dcache_awready,awlen,dcache_aw_len);
FF_D_without_asyn_rst #(3)   u_aw_size      (clk,dcache_awvalid & dcache_awready,awsize,dcache_aw_size);
FF_D_without_asyn_rst #(3)   u_aw_size_get  (clk,dcache_awvalid & dcache_awready,dcache_awsize,dcache_awsize_get);
FF_D_without_asyn_rst #(2)   u_awburst      (clk,dcache_awvalid & dcache_awready,dcache_awburst,dcache_aw_burst);
FF_D_without_asyn_rst #(1)   u_awlock       (clk,dcache_awvalid & dcache_awready,dcache_awlock,dcache_aw_lock);

// write data
wire                                    dcache_w_fifo_ren;
wire                                    dcache_w_fifo_wen;
wire                                    dcache_w_fifo_empty;
wire [AXI_DATA_W + (AXI_DATA_W/8) : 0]  dcache_w_fifo_wdata;
wire [AXI_DATA_W + (AXI_DATA_W/8) : 0]  dcache_w_fifo_rdata;

wire [AXI_DATA_W     - 1 : 0]           dcache_w_fifo_rdata_wdata;
wire [(AXI_DATA_W/8) - 1 : 0]           dcache_w_fifo_rdata_wstrb;
wire                                    dcache_w_fifo_rdata_last;

reg                                     dcache_data_sel_reg;
wire                                    dcache_data_sel;
always @(posedge clk or negedge rst_n) begin
    if(!rst_n)begin
        dcache_data_sel_reg <= 1'b0;
    end
    else if(io_master_wvalid & io_master_wready & (dcache_awsize_get == 3'h3))begin
        dcache_data_sel_reg <= ~dcache_data_sel_reg;
    end
end
assign dcache_data_sel = dcache_data_sel_reg | ((dcache_awsize_get != 3'h3) & dcache_aw_addr[2]);

ifu_fifo #(
    .DATA_LEN   	( AXI_DATA_W + (AXI_DATA_W/8) + 1 ),
    .AddR_Width 	( 2   ))
dcache_w_fifo(
    .clk    	( clk                   ),
    .rst_n  	( rst_n                 ),
    .Wready 	( dcache_w_fifo_wen     ),
    .Rready 	( dcache_w_fifo_ren     ),
    .flush  	( 1'b0                  ),
    .wdata  	( dcache_w_fifo_wdata   ),
    .empty  	( dcache_w_fifo_empty   ),
    .rdata  	( dcache_w_fifo_rdata   )
);
assign dcache_w_fifo_ren   = io_master_wvalid & io_master_wready & (dcache_data_sel_reg | (dcache_awsize_get != 3'h3));
assign dcache_w_fifo_wen   = dcache_wvalid & dcache_wready & (lock_fsm != ERROR);
assign dcache_w_fifo_wdata = {dcache_wlast, dcache_wstrb, dcache_wdata};

assign dcache_w_fifo_rdata_wdata = dcache_w_fifo_rdata[AXI_DATA_W     - 1 : 0];
assign dcache_w_fifo_rdata_wstrb = dcache_w_fifo_rdata[AXI_DATA_W + (AXI_DATA_W/8) - 1 : AXI_DATA_W];
assign dcache_w_fifo_rdata_last  = dcache_w_fifo_rdata[AXI_DATA_W + (AXI_DATA_W/8)];

//***********************************************
//! output
assign icache_arready    = (!dcache_arvalid);

assign icache_rvalid     = (io_master_rid == AXI_ID_I) & io_master_rvalid & (cache_r_valid_i | io_master_rlast);
assign icache_rid        = io_master_rid;
assign icache_rresp      = (cache_r_valid_i) ? (cache_r_resp_i | io_master_rresp) : io_master_rresp;
assign icache_rdata      = cache_r_data_ret_i;
assign icache_rlast      = io_master_rlast;

assign dcache_arready    = 1'b1;

assign dcache_rvalid     = (io_master_rid == AXI_ID_D) & io_master_rvalid & (cache_r_valid_d | io_master_rlast);
assign dcache_rid        = io_master_rid;
assign dcache_rresp      = (dcache_ar_lock) ? ((cache_r_valid_d) ? (cache_r_resp_d | io_master_rresp | 2'h1) : (io_master_rresp | 2'h1)) : ((cache_r_valid_d) ? (cache_r_resp_d | io_master_rresp) : io_master_rresp);
assign dcache_rdata      = cache_r_data_ret_d;
assign dcache_rlast      = io_master_rlast;

assign dcache_awready    = 1'b1;

assign dcache_wready     = (!(dcache_awvalid & dcache_awready & dcache_awlock));

assign dcache_bvalid     = (io_master_bvalid | (lock_fsm == REPORT));
assign dcache_bid        = (lock_fsm == REPORT) ? AXI_ID_D : io_master_bid;
assign dcache_bresp      = (lock_fsm == REPORT) ? 2'h3 : ((dcache_aw_lock) ? 2'h1 : io_master_bresp);

assign io_master_awvalid = dcache_aw_valid;
assign io_master_awaddr  = dcache_aw_addr;
assign io_master_awid    = dcache_aw_id;
assign io_master_awlen   = dcache_aw_len;
assign io_master_awsize  = dcache_aw_size;
assign io_master_awburst = dcache_aw_burst;

assign io_master_wvalid  = (!dcache_w_fifo_empty);
assign io_master_wdata   = (dcache_data_sel) ? dcache_w_fifo_rdata_wdata[63:32] : dcache_w_fifo_rdata_wdata[31:0];
assign io_master_wstrb   = (dcache_data_sel) ? dcache_w_fifo_rdata_wstrb[7:4] : dcache_w_fifo_rdata_wstrb[3:0];
assign io_master_wlast   = (dcache_data_sel_reg | (dcache_awsize_get != 3'h3)) & dcache_w_fifo_rdata_last;

assign io_master_bready  = dcache_bready;

assign io_master_arvalid = (!cache_ar_fifo_empty);
assign io_master_araddr  = cache_ar_fifo_rdata_araddr  ;
assign io_master_arlen   = cache_ar_fifo_rdata_arlen   ;
assign io_master_arsize  = cache_ar_fifo_rdata_arsize  ;
assign io_master_arburst = cache_ar_fifo_rdata_arburst ;
assign io_master_arid    = cache_ar_fifo_rdata_arid    ;

assign io_master_rready  =  (io_master_rid == AXI_ID_I) ? (icache_rready | (!(cache_r_valid_i | io_master_rlast))) : (dcache_rready | (!(cache_r_valid_d | io_master_rlast)));

endmodule //axi2to1_with_lock
