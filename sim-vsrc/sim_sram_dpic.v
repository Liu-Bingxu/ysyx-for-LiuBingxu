import "DPI-C" function void sim_sram_read (
    input   longint raddr,
    output  longint rdata
);

import "DPI-C" function void sim_sram_write (
    input   longint waddr,
    input   longint wdata,
    input      byte wmask
);

module sim_sram_dpic#(
    // Address width in bits
    parameter AXI_ADDR_W = 64,
    // ID width in bits
    parameter AXI_ID_W = 8,
    // Data width in bits
    parameter AXI_DATA_W = 64
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

reg [AXI_ID_W      -1:0]     mst_id;
reg [AXI_ADDR_W    -1:0]     mst_awaddr_reg;
reg [8             -1:0]     mst_awlen_reg;

reg [AXI_ADDR_W    -1:0]     mst_araddr_reg;
reg [8             -1:0]     mst_arlen_reg;
reg [AXI_DATA_W    -1:0]     mst_rdata_reg;

reg [1:0]                    state;
reg                          mst_bvalid_reg;
reg                          mst_rvalid_reg;
localparam  IDLE  = 2'h0;
localparam  READ  = 2'h1;
localparam  WRITE = 2'h2;
localparam  WBACK = 2'h3;

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
    end
    else if(mst_awvalid & mst_awready)begin
        mst_awaddr_reg  <= mst_awaddr;
        mst_awlen_reg   <= mst_awlen;
    end
    else if(mst_wvalid & mst_wready)begin
        mst_awaddr_reg  <= mst_awaddr_reg + {{(AXI_ADDR_W - 4){1'b0}}, 4'h8};
        mst_awlen_reg   <= mst_awlen_reg - 8'h1;
    end
end

always @(posedge aclk or negedge arst_n) begin
    if(!arst_n)begin
        mst_araddr_reg  <= {AXI_ADDR_W{1'b0}};
        mst_arlen_reg   <= 8'h0;
    end
    else if(mst_awvalid & mst_awready)begin
        mst_araddr_reg  <= mst_araddr + {{(AXI_ADDR_W - 4){1'b0}}, 4'h8};
        mst_arlen_reg   <= mst_arlen;
    end
    else if(mst_rvalid & mst_rready)begin
        mst_araddr_reg  <= mst_araddr_reg + {{(AXI_ADDR_W - 4){1'b0}}, 4'h8};
        mst_arlen_reg   <= mst_arlen_reg - 8'h1;
    end
end

always @(posedge aclk or negedge arst_n) begin
    if(!arst_n)begin
        state           <= IDLE;
        mst_bvalid_reg  <= 1'b0;
        mst_rvalid_reg  <= 1'b0;
    end
    else begin
        case (state)
            IDLE: begin
                if(mst_awvalid & mst_awready)begin
                    state           <= WRITE;
                end
                else if(mst_arvalid & mst_arready)begin
                    state           <= READ;
                    mst_rvalid_reg  <= 1'b1;
                    sim_sram_read(mst_araddr, mst_rdata_reg);
                end
            end
            READ: begin
                if(mst_rvalid & mst_rready)begin
                    sim_sram_read(mst_araddr_reg, mst_rdata_reg);
                    if(mst_rlast)begin
                        state           <= IDLE;
                        mst_rvalid_reg  <= 1'b0;
                    end
                end
            end
            WRITE: begin
                if(mst_wvalid & mst_wready)begin
                    sim_sram_write(mst_awaddr_reg, mst_wdata, mst_wstrb);
                    if(mst_wlast)begin
                        state           <= WBACK;
                        mst_bvalid_reg  <= 1'b1;
                    end
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
                mst_rdata_reg   <= {AXI_DATA_W{1'b0}};
                mst_bvalid_reg  <= 1'b0;
                mst_rvalid_reg  <= 1'b0;
            end
        endcase
    end
end

always @(posedge aclk) begin
    if(mst_awvalid & mst_awready)begin
    // input  [3             -1:0]     mst_awsize,
    // input  [2             -1:0]     mst_awburst,
    // input                           mst_awlock,
    // input  [4             -1:0]     mst_awcache,
    // input  [3             -1:0]     mst_awprot,
    // input  [4             -1:0]     mst_awqos,
    // input  [4             -1:0]     mst_awregion,
        if(mst_awburst != 2'h1)begin
            $display("now mst_awburst != 2'h1");
            $stop;
        end
        else if(mst_awlock != 1'h0)begin
            $display("now mst_awlock != 1'h0");
            $stop;
        end
        else if(mst_awcache != 4'h0)begin
            $display("now mst_awcache != 4'h0");
            $stop;
        end
        else if(mst_awprot != 3'h0)begin
            $display("now mst_awprot != 3'h0");
            $stop;
        end
        else if(mst_awqos != 4'h0)begin
            $display("now mst_awqos != 4'h0");
            $stop;
        end
        else if(mst_awregion != 4'h0)begin
            $display("now mst_awregion != 4'h0");
            $stop;
        end
    end
end

always @(posedge aclk) begin
    if(mst_arvalid & mst_arready)begin
    // input  [3             -1:0]     mst_arsize,
    // input  [2             -1:0]     mst_arburst,
    // input                           mst_arlock,
    // input  [4             -1:0]     mst_arcache,
    // input  [3             -1:0]     mst_arprot,
    // input  [4             -1:0]     mst_arqos,
    // input  [4             -1:0]     mst_arregion,
        if(mst_arburst != 2'h1)begin
            $display("now mst_arburst != 2'h1");
            $stop;
        end
        else if(mst_arlock != 1'h0)begin
            $display("now mst_arlock != 1'h0");
            $stop;
        end
        else if(mst_arcache != 4'h0)begin
            $display("now mst_arcache != 4'h0");
            $stop;
        end
        else if(mst_arprot != 3'h0)begin
            $display("now mst_arprot != 3'h0");
            $stop;
        end
        else if(mst_arqos != 4'h0)begin
            $display("now mst_arqos != 4'h0");
            $stop;
        end
        else if(mst_arregion != 4'h0)begin
            $display("now mst_arregion != 4'h0");
            $stop;
        end
    end
end

assign mst_awready = (state == IDLE) & (!mst_arvalid);
assign mst_wready  = (state == WRITE);
assign mst_bvalid  = mst_bvalid_reg;
assign mst_bid     = mst_id;
assign mst_bresp   = 2'h0;
assign mst_arready = (state == IDLE);
assign mst_rvalid  = mst_rvalid_reg;
assign mst_rid     = mst_id;
assign mst_rresp   = 2'h0;
assign mst_rdata   = mst_rdata_reg;
assign mst_rlast   = (mst_arlen_reg == 8'h0);

endmodule //sim_sram_dpic
