module clint_axi2reg#(
    // Address width in bits
    parameter AXI_ADDR_W = 32,
    // ID width in bits
    parameter AXI_ID_W = 8,
    // Data width in bits
    parameter AXI_DATA_W = 32,

    parameter HART_NUM = 1
)(
    input                           clk,
    input                           rst_n,

    output                          mtime_l_wen,
    output                          mtime_h_wen,
    output [HART_NUM - 1:0]         mtimecmp_l_wen,
    output [HART_NUM - 1:0]         mtimecmp_h_wen,
    output [HART_NUM - 1:0]         msip_wen,

    output [31:0]                   reg_wdata,

    input  [63:0]                   mtime,
    input  [64 * HART_NUM -1:0]     mtimecmp,
    input  [HART_NUM - 1:0]         msip,

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

localparam AXI_IDLE         = 3'h0;
localparam AXI_READ         = 3'h1;
localparam AXI_WRITE        = 3'h2;
localparam AXI_WRITE_ERROR  = 3'h4;
localparam AXI_WIRTE_BACK   = 3'h6;

// bus width assertions
initial begin
    if ((AXI_ADDR_W != 32) & (AXI_ADDR_W != 64)) begin
        $error("Error: Interface addr width must be 64 or 32");
        $finish;
    end

    if (AXI_DATA_W != 32) begin
        $error("Error: Interface data width must be 32");
        $finish;
    end
end

reg  [2:0]                axi_state;

reg  [15:0]               mst_awaddr_reg;

reg  [8             -1:0] mst_rlen_reg;

reg  [AXI_ID_W      -1:0] mst_id_reg;
reg                       mst_resp_reg;

reg                       mst_wready_reg;
reg                       mst_bvalid_reg;
reg                       mst_rvalid_reg;
reg  [AXI_DATA_W    -1:0] mst_rdata_reg;
wire [AXI_DATA_W    -1:0] mst_rdata_sel;
reg                       mst_rlast_reg;

wire [AXI_DATA_W    -1:0] mst_wmask;

wire [63:0]               clint_mtimecmp[0:HART_NUM -1];
wire [31:0]               clint_mtimecmp_l[0:HART_NUM -1];
wire [31:0]               clint_mtimecmp_h[0:HART_NUM -1];

wire [15:0]               mst_addr_use;
wire [HART_NUM - 1:0]     clint_sel_msip;
wire                      clint_sel_mtime_l;
wire                      clint_sel_mtime_h;
wire [HART_NUM - 1:0]     clint_sel_mtimecmp_l;
wire [HART_NUM - 1:0]     clint_sel_mtimecmp_h;
wire                      clint_success_access;

genvar mask_index;
generate for(mask_index = 0 ; mask_index < (AXI_DATA_W/8); mask_index = mask_index + 1) begin : gen_wmask
    assign mst_wmask[8 * mask_index + 7 : 8 * mask_index] = {8{mst_wstrb[mask_index]}};
end
endgenerate

assign clint_sel_mtime_l          = (mst_addr_use == 16'hBFF8);
assign clint_sel_mtime_h          = (mst_addr_use == 16'hBFFC);
assign mtime_l_wen                = ((mst_awaddr_reg == 16'hBFF8) & (axi_state == AXI_WRITE) & mst_wvalid & mst_wready);
assign mtime_h_wen                = ((mst_awaddr_reg == 16'hBFFC) & (axi_state == AXI_WRITE) & mst_wvalid & mst_wready);

genvar reg_sel_index;
generate for(reg_sel_index = 0 ; reg_sel_index < HART_NUM; reg_sel_index = reg_sel_index + 1) begin : reg_sel_gen
    assign clint_sel_msip[reg_sel_index]        = (mst_addr_use == (reg_sel_index * 16'h4));
    assign clint_sel_mtimecmp_l[reg_sel_index]  = (mst_addr_use == (reg_sel_index * 16'h8 + 16'h4000));
    assign clint_sel_mtimecmp_h[reg_sel_index]  = (mst_addr_use == (reg_sel_index * 16'h8 + 16'h4004));

    assign msip_wen[reg_sel_index]              = ((mst_awaddr_reg == (reg_sel_index * 16'h4))            & (axi_state == AXI_WRITE) & mst_wvalid & mst_wready);
    assign mtimecmp_l_wen[reg_sel_index]        = ((mst_awaddr_reg == (reg_sel_index * 16'h8 + 16'h4000)) & (axi_state == AXI_WRITE) & mst_wvalid & mst_wready);
    assign mtimecmp_h_wen[reg_sel_index]        = ((mst_awaddr_reg == (reg_sel_index * 16'h8 + 16'h4004)) & (axi_state == AXI_WRITE) & mst_wvalid & mst_wready);

    assign clint_mtimecmp[reg_sel_index]        = mtimecmp[reg_sel_index * 64 + 63 : reg_sel_index * 64];
    assign clint_mtimecmp_l[reg_sel_index]      = clint_mtimecmp[reg_sel_index][31:0];
    assign clint_mtimecmp_h[reg_sel_index]      = clint_mtimecmp[reg_sel_index][63:32];
end
endgenerate


assign mst_addr_use            = mst_awvalid ? mst_awaddr[15:0] : mst_araddr[15:0];
assign clint_success_access    = clint_sel_mtime_l | clint_sel_mtime_h | (|clint_sel_msip) | (|clint_sel_mtimecmp_l) | (|clint_sel_mtimecmp_h);

assign mst_rdata_sel           = reg_data_sel(clint_sel_mtime_l,
                                                clint_sel_mtime_h, 
                                                clint_sel_msip, 
                                                clint_sel_mtimecmp_l, 
                                                clint_sel_mtimecmp_h, 
                                                mtime[31:0], 
                                                mtime[63:32], 
                                                msip, 
                                                clint_mtimecmp_l, 
                                                clint_mtimecmp_h);

always @(posedge clk or negedge rst_n) begin
    if(!rst_n)begin
        axi_state       <= AXI_IDLE;
        mst_wready_reg  <= 1'b0;
        mst_bvalid_reg  <= 1'b0;
        mst_rvalid_reg  <= 1'b0;
    end
    else begin
        case (axi_state)
            AXI_IDLE: begin
                if(mst_awvalid & mst_awready)begin
                    mst_id_reg          <= mst_awid;
                    mst_wready_reg      <= 1'b1;
                    if((|mst_awcache) | (|mst_awlen) | (|mst_awprot) | mst_awlock | (|mst_awqos) | (|mst_awregion))begin
                        axi_state       <= AXI_WRITE_ERROR;
                        mst_resp_reg    <= 1'b1;
                    end
                    else if(clint_success_access)begin
                        axi_state       <= AXI_WRITE;
                        mst_resp_reg    <= 1'b0;
                        mst_awaddr_reg  <= mst_awaddr[15:0];
                    end
                    else begin
                        axi_state       <= AXI_WRITE_ERROR;
                        mst_resp_reg    <= 1'b1;
                    end
                end
                else if(mst_arvalid & mst_arready)begin
                    mst_id_reg          <= mst_arid;
                    mst_rlen_reg        <= mst_arlen;
                    if((|mst_arcache) | (|mst_arlen) | (|mst_arprot) | mst_arlock | (|mst_arqos) | (|mst_arregion))begin
                        mst_resp_reg    <= 1'b1;
                        mst_rvalid_reg  <= 1'b1;
                        axi_state       <= AXI_READ;
                    end
                    else if(clint_success_access)begin
                        mst_resp_reg    <= 1'b0;
                        mst_rvalid_reg  <= 1'b1;
                        mst_rdata_reg   <= mst_rdata_sel;
                        axi_state       <= AXI_READ;
                    end
                    else begin
                        mst_resp_reg    <= 1'b1;
                        mst_rvalid_reg  <= 1'b1;
                        axi_state       <= AXI_READ;
                    end
                    if(mst_arlen == 8'h0)begin
                        mst_rlast_reg   <= 1'b1;
                    end
                    else begin
                        mst_rlast_reg   <= 1'b0;
                    end
                end
            end
            AXI_READ: begin
                if(mst_rvalid & mst_rready & mst_rlast)begin
                    axi_state           <= AXI_IDLE;
                    mst_rvalid_reg      <= 1'b0;
                end
                else if(mst_rvalid & mst_rready)begin
                    mst_rlen_reg        <= mst_rlen_reg + 8'hff;
                    if(mst_rlen_reg == 8'h1)begin
                        mst_rlast_reg   <= 1'b1;
                    end
                end
            end
            AXI_WRITE: begin
                if(mst_wvalid & mst_wready & mst_wlast)begin
                    axi_state           <= AXI_WIRTE_BACK;
                    mst_wready_reg      <= 1'b0;
                    mst_bvalid_reg      <= 1'b1;
                    mst_resp_reg        <= 1'b0;
                end
            end
            AXI_WRITE_ERROR: begin
                if(mst_wvalid & mst_wready & mst_wlast)begin
                    axi_state           <= AXI_WIRTE_BACK;
                    mst_wready_reg      <= 1'b0;
                    mst_bvalid_reg      <= 1'b1;
                end
            end
            AXI_WIRTE_BACK: begin
                if(mst_bvalid & mst_bready)begin
                    axi_state           <= AXI_IDLE;
                    mst_bvalid_reg      <= 1'b0;
                end
            end
            default: begin
                axi_state       <= AXI_IDLE;
                mst_wready_reg  <= 1'b0;
                mst_bvalid_reg  <= 1'b0;
                mst_rvalid_reg  <= 1'b0;
            end
        endcase
    end
end

assign reg_wdata       = reg_wdata_sel(mtime_l_wen, 
                                        mtime_h_wen, 
                                        msip_wen, 
                                        mtimecmp_l_wen, 
                                        mtimecmp_h_wen, 
                                        mst_wdata, 
                                        mst_wmask, 
                                        mtime[31:0], 
                                        mtime[63:32], 
                                        msip, 
                                        clint_mtimecmp_l, 
                                        clint_mtimecmp_h);

assign mst_awready  = (axi_state == AXI_IDLE);
assign mst_wready   = mst_wready_reg;
assign mst_bvalid   = mst_bvalid_reg;
assign mst_bid      = mst_id_reg;
assign mst_bresp    = {mst_resp_reg, 1'b0};
assign mst_arready  = ((axi_state == AXI_IDLE) & (!mst_awvalid));
assign mst_rvalid   = mst_rvalid_reg;
assign mst_rid      = mst_id_reg;
assign mst_rresp    = {mst_resp_reg, 1'b0};
assign mst_rdata    = mst_rdata_reg;
assign mst_rlast    = mst_rlast_reg;
//**********************************************************************************************
//?function
function [31:0] reg_data_sel;
    input                   mtime_sel_l;
    input                   mtime_sel_h;
    input [HART_NUM-1:0]    msip_sel;
    input [HART_NUM-1:0]    mtimecmp_sel_l;
    input [HART_NUM-1:0]    mtimecmp_sel_h;
    input [31:0]            mtime_get_l;
    input [31:0]            mtime_get_h;
    input [HART_NUM-1:0]    msip_get;
    input [31:0]            mtimecmp_get_l[0:HART_NUM-1];
    input [31:0]            mtimecmp_get_h[0:HART_NUM-1];
    integer msip_index;
    integer mtimecmp_index;
    begin
        reg_data_sel = 32'h0;
        if(mtime_sel_l == 1'b1)begin
            reg_data_sel = reg_data_sel | mtime_get_l;
        end
        if(mtime_sel_h == 1'b1)begin
            reg_data_sel = reg_data_sel | mtime_get_h;
        end
        for (msip_index = 0; msip_index < HART_NUM; msip_index = msip_index + 1) begin
            if(msip_sel[msip_index] == 1'b1)begin
                reg_data_sel = reg_data_sel | {31'h0, msip_get[msip_index]};
            end
        end
        for (mtimecmp_index = 0; mtimecmp_index < HART_NUM; mtimecmp_index = mtimecmp_index + 1) begin
            if(mtimecmp_sel_l[mtimecmp_index] == 1'b1)begin
                reg_data_sel = reg_data_sel | mtimecmp_get_l[mtimecmp_index];
            end
            if(mtimecmp_sel_h[mtimecmp_index] == 1'b1)begin
                reg_data_sel = reg_data_sel | mtimecmp_get_h[mtimecmp_index];
            end
        end
    end
endfunction

function [31:0] reg_wdata_sel;
    input                   mtime_sel_l;
    input                   mtime_sel_h;
    input [HART_NUM-1:0]    msip_sel;
    input [HART_NUM-1:0]    mtimecmp_sel_l;
    input [HART_NUM-1:0]    mtimecmp_sel_h;
    input [31:0]            axi_wdata;
    input [31:0]            wmask;
    input [31:0]            mtime_get_l;
    input [31:0]            mtime_get_h;
    input [HART_NUM-1:0]    msip_get;
    input [31:0]            mtimecmp_get_l[0:HART_NUM-1];
    input [31:0]            mtimecmp_get_h[0:HART_NUM-1];
    integer msip_index;
    integer mtimecmp_index;
    begin
        reg_wdata_sel = 32'h0;
        if(mtime_sel_l == 1'b1)begin
            reg_wdata_sel = reg_wdata_sel | ((mtime_get_l & (~wmask)) | (axi_wdata & wmask));
        end
        if(mtime_sel_h == 1'b1)begin
            reg_wdata_sel = reg_wdata_sel | ((mtime_get_h & (~wmask)) | (axi_wdata & wmask));
        end
        for (msip_index = 0; msip_index < HART_NUM; msip_index = msip_index + 1) begin
            if(msip_sel[msip_index] == 1'b1)begin
                reg_wdata_sel = reg_wdata_sel | (({31'h0, msip_get[msip_index]} & (~wmask)) | (axi_wdata & wmask));
            end
        end
        for (mtimecmp_index = 0; mtimecmp_index < HART_NUM; mtimecmp_index = mtimecmp_index + 1) begin
            if(mtimecmp_sel_l[mtimecmp_index] == 1'b1)begin
                reg_wdata_sel = reg_wdata_sel | ((mtimecmp_get_l[mtimecmp_index] & (~wmask)) | (axi_wdata & wmask));
            end
            if(mtimecmp_sel_h[mtimecmp_index] == 1'b1)begin
                reg_wdata_sel = reg_wdata_sel | ((mtimecmp_get_h[mtimecmp_index] & (~wmask)) | (axi_wdata & wmask));
            end
        end
    end
endfunction


endmodule //clint_axi2reg
