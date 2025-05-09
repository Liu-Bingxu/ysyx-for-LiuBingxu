module enet_axi2reg#(
    // Address width in bits
    parameter AXI_ADDR_W = 32,
    // ID width in bits
    parameter AXI_ID_W = 8,
    // Data width in bits
    parameter AXI_DATA_W = 32
)(
    input                           clk,
    input                           rst_n,

    output                          eir_wen,
    output                          eimr_wen,
    output                          rdar_wen,
    output                          tdar_wen,
    output                          ecr_wen,
    output                          mmfr_wen,
    output                          mscr_wen,
    output                          tcr_wen,
    output                          rcr_wen,
    output                          palr_wen,
    output                          paur_wen,
    output                          opd_wen,
    output                          txic_wen,
    output                          rxic_wen,
    output                          ialr_wen,
    output                          iaur_wen,
    output                          galr_wen,
    output                          gaur_wen,
    output                          rdsr_wen,
    output                          tdsr_wen,
    output                          rsfl_wen,
    output                          rsem_wen,
    output                          rafl_wen,
    output                          raem_wen,
    output                          tfwr_wen,
    output                          tsem_wen,
    output                          tafl_wen,
    output                          taem_wen,
    output                          tipg_wen,
    output                          ftrl_wen,
    input                           write_success,

    output                          rdar_ren,
    output                          tdar_ren,
    output                          tcr_ren,
    output                          rcr_ren,
    input                           read_done,

    output [11:0]                   reg_addr,
    output [31:0]                   reg_wdata,

    input  [31:0]                   eir,
    input  [31:0]                   eimr,
    input  [31:0]                   ecr,
    input  [31:0]                   mmfr,
    input  [31:0]                   mscr,
    input  [31:0]                   tcr,
    input  [31:0]                   tdar,
    input  [31:0]                   rcr,
    input  [31:0]                   rdar,
    input  [31:0]                   palr,
    input  [31:0]                   paur,
    input  [31:0]                   opd,
    input  [31:0]                   txic,
    input  [31:0]                   rxic,
    input  [31:0]                   ialr,
    input  [31:0]                   iaur,
    input  [31:0]                   galr,
    input  [31:0]                   gaur,
    input  [31:0]                   rdsr,
    input  [31:0]                   tdsr,
    input  [31:0]                   rsfl,
    input  [31:0]                   rsem,
    input  [31:0]                   rafl,
    input  [31:0]                   raem,
    input  [31:0]                   tfwr,
    input  [31:0]                   tsem,
    input  [31:0]                   tafl,
    input  [31:0]                   taem,
    input  [31:0]                   tipg,
    input  [31:0]                   ftrl,

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
localparam AXI_READ_WAIT    = 3'h2;
localparam AXI_WRITE        = 3'h3;
localparam AXI_WRITE_ERROR  = 3'h4;
localparam AXI_WIRTE_BACK   = 3'h5;

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

reg  [11:0]               mst_awaddr_reg;
reg  [11:0]               mst_araddr_reg;

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

wire [11:0]               mst_addr_use;
wire                      enet_sel_eir;
wire                      enet_sel_eimr;
wire                      enet_sel_ecr;
wire                      enet_sel_mmfr;
wire                      enet_sel_mscr;
wire                      enet_sel_tcr;
wire                      enet_sel_tdar;
wire                      enet_sel_rcr;
wire                      enet_sel_rdar;
wire                      enet_sel_palr;
wire                      enet_sel_paur;
wire                      enet_sel_opd;
wire                      enet_sel_txic;
wire                      enet_sel_rxic;
wire                      enet_sel_ialr;
wire                      enet_sel_iaur;
wire                      enet_sel_galr;
wire                      enet_sel_gaur;
wire                      enet_sel_rdsr;
wire                      enet_sel_tdsr;
wire                      enet_sel_rsfl;
wire                      enet_sel_rsem;
wire                      enet_sel_rafl;
wire                      enet_sel_raem;
wire                      enet_sel_tfwr;
wire                      enet_sel_tsem;
wire                      enet_sel_tafl;
wire                      enet_sel_taem;
wire                      enet_sel_tipg;
wire                      enet_sel_ftrl;
wire                      enet_success_read;
wire                      enet_success_write;

genvar mask_index;
generate for(mask_index = 0 ; mask_index < (AXI_DATA_W/8); mask_index = mask_index + 1) begin : gen_wmask
    assign mst_wmask[8 * mask_index + 7 : 8 * mask_index] = {8{mst_wstrb[mask_index]}};
end
endgenerate

assign enet_sel_eir            = (mst_addr_use == 12'h004);
assign enet_sel_eimr           = (mst_addr_use == 12'h008);
assign enet_sel_rdar           = (mst_addr_use == 12'h010);
assign enet_sel_tdar           = (mst_addr_use == 12'h014);
assign enet_sel_ecr            = (mst_addr_use == 12'h024);
assign enet_sel_mmfr           = (mst_addr_use == 12'h040);
assign enet_sel_mscr           = (mst_addr_use == 12'h044);
assign enet_sel_rcr            = (mst_addr_use == 12'h084);
assign enet_sel_tcr            = (mst_addr_use == 12'h0C4);
assign enet_sel_palr           = (mst_addr_use == 12'h0E4);
assign enet_sel_paur           = (mst_addr_use == 12'h0E8);
assign enet_sel_opd            = (mst_addr_use == 12'h0EC);
assign enet_sel_txic           = (mst_addr_use == 12'h0F0);
assign enet_sel_rxic           = (mst_addr_use == 12'h100);
assign enet_sel_iaur           = (mst_addr_use == 12'h118);
assign enet_sel_ialr           = (mst_addr_use == 12'h11C);
assign enet_sel_gaur           = (mst_addr_use == 12'h120);
assign enet_sel_galr           = (mst_addr_use == 12'h124);
assign enet_sel_tfwr           = (mst_addr_use == 12'h144);
assign enet_sel_rdsr           = (mst_addr_use == 12'h180);
assign enet_sel_tdsr           = (mst_addr_use == 12'h184);
assign enet_sel_rsfl           = (mst_addr_use == 12'h190);
assign enet_sel_rsem           = (mst_addr_use == 12'h194);
assign enet_sel_raem           = (mst_addr_use == 12'h198);
assign enet_sel_rafl           = (mst_addr_use == 12'h19C);
assign enet_sel_tsem           = (mst_addr_use == 12'h1A0);
assign enet_sel_taem           = (mst_addr_use == 12'h1A4);
assign enet_sel_tafl           = (mst_addr_use == 12'h1A8);
assign enet_sel_tipg           = (mst_addr_use == 12'h1AC);
assign enet_sel_ftrl           = (mst_addr_use == 12'h1B0);
assign mst_addr_use            = mst_awvalid ? mst_awaddr[11:0] : mst_araddr[11:0];
assign enet_success_read       = enet_sel_eir | enet_sel_eimr | enet_sel_ecr | enet_sel_mmfr | enet_sel_mscr
                                | enet_sel_palr | enet_sel_paur | enet_sel_opd | enet_sel_txic | enet_sel_rxic 
                                | enet_sel_ialr | enet_sel_iaur | enet_sel_galr | enet_sel_gaur | enet_sel_rdsr 
                                | enet_sel_tdsr | enet_sel_rsfl | enet_sel_rsem | enet_sel_rafl | enet_sel_raem 
                                | enet_sel_tfwr | enet_sel_tsem | enet_sel_tafl | enet_sel_taem | enet_sel_tipg 
                                | enet_sel_ftrl;
assign enet_success_write      = enet_sel_eir | enet_sel_eimr | enet_sel_ecr | enet_sel_mmfr | enet_sel_mscr
                                | enet_sel_tcr | enet_sel_tdar | enet_sel_rcr | enet_sel_rdar | enet_sel_palr
                                | enet_sel_paur | enet_sel_opd | enet_sel_txic | enet_sel_rxic | enet_sel_ialr
                                | enet_sel_iaur | enet_sel_galr | enet_sel_gaur | enet_sel_rdsr | enet_sel_tdsr
                                | enet_sel_rsfl | enet_sel_rsem | enet_sel_rafl | enet_sel_raem | enet_sel_tfwr
                                | enet_sel_tsem | enet_sel_tafl | enet_sel_taem | enet_sel_tipg | enet_sel_ftrl;

assign mst_rdata_sel =  {AXI_DATA_W{1'b0}} |
                        ({AXI_DATA_W{enet_sel_eir   & (axi_state == AXI_IDLE)}} & eir  )  |
                        ({AXI_DATA_W{enet_sel_eimr  & (axi_state == AXI_IDLE)}} & eimr )  |
                        ({AXI_DATA_W{enet_sel_ecr   & (axi_state == AXI_IDLE)}} & ecr  )  |
                        ({AXI_DATA_W{enet_sel_mmfr  & (axi_state == AXI_IDLE)}} & mmfr )  |
                        ({AXI_DATA_W{enet_sel_mscr  & (axi_state == AXI_IDLE)}} & mscr )  |
                        ({AXI_DATA_W{tcr_ren   & (axi_state == AXI_READ_WAIT)}} & tcr  )  |
                        ({AXI_DATA_W{tdar_ren  & (axi_state == AXI_READ_WAIT)}} & tdar )  |
                        ({AXI_DATA_W{rcr_ren   & (axi_state == AXI_READ_WAIT)}} & rcr  )  |
                        ({AXI_DATA_W{rdar_ren  & (axi_state == AXI_READ_WAIT)}} & rdar )  |
                        ({AXI_DATA_W{enet_sel_palr  & (axi_state == AXI_IDLE)}} & palr )  |
                        ({AXI_DATA_W{enet_sel_paur  & (axi_state == AXI_IDLE)}} & paur )  |
                        ({AXI_DATA_W{enet_sel_opd   & (axi_state == AXI_IDLE)}} & opd  )  |
                        ({AXI_DATA_W{enet_sel_txic  & (axi_state == AXI_IDLE)}} & txic )  |
                        ({AXI_DATA_W{enet_sel_rxic  & (axi_state == AXI_IDLE)}} & rxic )  |
                        ({AXI_DATA_W{enet_sel_ialr  & (axi_state == AXI_IDLE)}} & ialr )  |
                        ({AXI_DATA_W{enet_sel_iaur  & (axi_state == AXI_IDLE)}} & iaur )  |
                        ({AXI_DATA_W{enet_sel_galr  & (axi_state == AXI_IDLE)}} & galr )  |
                        ({AXI_DATA_W{enet_sel_gaur  & (axi_state == AXI_IDLE)}} & gaur )  |
                        ({AXI_DATA_W{enet_sel_rdsr  & (axi_state == AXI_IDLE)}} & rdsr )  |
                        ({AXI_DATA_W{enet_sel_tdsr  & (axi_state == AXI_IDLE)}} & tdsr )  |
                        ({AXI_DATA_W{enet_sel_rsfl  & (axi_state == AXI_IDLE)}} & rsfl )  |
                        ({AXI_DATA_W{enet_sel_rsem  & (axi_state == AXI_IDLE)}} & rsem )  |
                        ({AXI_DATA_W{enet_sel_rafl  & (axi_state == AXI_IDLE)}} & rafl )  |
                        ({AXI_DATA_W{enet_sel_raem  & (axi_state == AXI_IDLE)}} & raem )  |
                        ({AXI_DATA_W{enet_sel_tfwr  & (axi_state == AXI_IDLE)}} & tfwr )  |
                        ({AXI_DATA_W{enet_sel_tsem  & (axi_state == AXI_IDLE)}} & tsem )  |
                        ({AXI_DATA_W{enet_sel_tafl  & (axi_state == AXI_IDLE)}} & tafl )  |
                        ({AXI_DATA_W{enet_sel_taem  & (axi_state == AXI_IDLE)}} & taem )  |
                        ({AXI_DATA_W{enet_sel_tipg  & (axi_state == AXI_IDLE)}} & tipg )  |
                        ({AXI_DATA_W{enet_sel_ftrl  & (axi_state == AXI_IDLE)}} & ftrl )  ;

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
                    else if(enet_success_write)begin
                        axi_state       <= AXI_WRITE;
                        mst_resp_reg    <= 1'b0;
                        mst_awaddr_reg  <= mst_awaddr[11:0];
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
                    else if(enet_sel_tcr | enet_sel_tdar | enet_sel_rcr | enet_sel_rdar)begin
                        mst_resp_reg    <= 1'b0;
                        mst_rvalid_reg  <= 1'b0;
                        mst_araddr_reg  <= mst_araddr[11:0];
                        axi_state       <= AXI_READ_WAIT;
                    end
                    else if(enet_success_read)begin
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
            AXI_READ_WAIT: begin
                if(read_done)begin
                    axi_state           <= AXI_READ;
                    mst_rvalid_reg      <= 1'b1;
                    mst_rdata_reg       <= mst_rdata_sel;
                end
            end
            AXI_WRITE: begin
                if(mst_wvalid & mst_wready & mst_wlast)begin
                    axi_state           <= AXI_WIRTE_BACK;
                    mst_wready_reg      <= 1'b0;
                    mst_bvalid_reg      <= 1'b1;
                    if(eir_wen | eimr_wen | ecr_wen | mmfr_wen | mscr_wen | txic_wen | rxic_wen | write_success)begin
                        mst_resp_reg    <= 1'b0;
                    end
                    else begin
                        mst_resp_reg    <= 1'b1;
                    end
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

assign eir_wen      = ((mst_awaddr_reg == 12'h004) & (axi_state == AXI_WRITE));
assign eimr_wen     = ((mst_awaddr_reg == 12'h008) & (axi_state == AXI_WRITE));
assign rdar_wen     = ((mst_awaddr_reg == 12'h010) & (axi_state == AXI_WRITE));
assign tdar_wen     = ((mst_awaddr_reg == 12'h014) & (axi_state == AXI_WRITE));
assign ecr_wen      = ((mst_awaddr_reg == 12'h024) & (axi_state == AXI_WRITE));
assign mmfr_wen     = ((mst_awaddr_reg == 12'h040) & (axi_state == AXI_WRITE));
assign mscr_wen     = ((mst_awaddr_reg == 12'h044) & (axi_state == AXI_WRITE));
assign rcr_wen      = ((mst_awaddr_reg == 12'h084) & (axi_state == AXI_WRITE));
assign tcr_wen      = ((mst_awaddr_reg == 12'h0C4) & (axi_state == AXI_WRITE));
assign palr_wen     = ((mst_awaddr_reg == 12'h0E4) & (axi_state == AXI_WRITE));
assign paur_wen     = ((mst_awaddr_reg == 12'h0E8) & (axi_state == AXI_WRITE));
assign opd_wen      = ((mst_awaddr_reg == 12'h0EC) & (axi_state == AXI_WRITE));
assign txic_wen     = ((mst_awaddr_reg == 12'h0F0) & (axi_state == AXI_WRITE));
assign rxic_wen     = ((mst_awaddr_reg == 12'h100) & (axi_state == AXI_WRITE));
assign iaur_wen     = ((mst_awaddr_reg == 12'h118) & (axi_state == AXI_WRITE));
assign ialr_wen     = ((mst_awaddr_reg == 12'h11C) & (axi_state == AXI_WRITE));
assign gaur_wen     = ((mst_awaddr_reg == 12'h120) & (axi_state == AXI_WRITE));
assign galr_wen     = ((mst_awaddr_reg == 12'h124) & (axi_state == AXI_WRITE));
assign tfwr_wen     = ((mst_awaddr_reg == 12'h144) & (axi_state == AXI_WRITE));
assign rdsr_wen     = ((mst_awaddr_reg == 12'h180) & (axi_state == AXI_WRITE));
assign tdsr_wen     = ((mst_awaddr_reg == 12'h184) & (axi_state == AXI_WRITE));
assign rsfl_wen     = ((mst_awaddr_reg == 12'h190) & (axi_state == AXI_WRITE));
assign rsem_wen     = ((mst_awaddr_reg == 12'h194) & (axi_state == AXI_WRITE));
assign raem_wen     = ((mst_awaddr_reg == 12'h198) & (axi_state == AXI_WRITE));
assign rafl_wen     = ((mst_awaddr_reg == 12'h19C) & (axi_state == AXI_WRITE));
assign tsem_wen     = ((mst_awaddr_reg == 12'h1A0) & (axi_state == AXI_WRITE));
assign taem_wen     = ((mst_awaddr_reg == 12'h1A4) & (axi_state == AXI_WRITE));
assign tafl_wen     = ((mst_awaddr_reg == 12'h1A8) & (axi_state == AXI_WRITE));
assign tipg_wen     = ((mst_awaddr_reg == 12'h1AC) & (axi_state == AXI_WRITE));
assign ftrl_wen     = ((mst_awaddr_reg == 12'h1B0) & (axi_state == AXI_WRITE));

assign tcr_ren      = ((mst_araddr_reg == 12'h0C4) & (axi_state == AXI_READ_WAIT));
assign rcr_ren      = ((mst_araddr_reg == 12'h084) & (axi_state == AXI_READ_WAIT));
assign tdar_ren     = ((mst_araddr_reg == 12'h014) & (axi_state == AXI_READ_WAIT));
assign rdar_ren     = ((mst_araddr_reg == 12'h010) & (axi_state == AXI_READ_WAIT));

assign reg_addr     = (axi_state == AXI_READ_WAIT) ? mst_araddr_reg : mst_awaddr_reg;
assign reg_wdata    =   {AXI_DATA_W{1'b0}} |
                        ({AXI_DATA_W{eir_wen  }} & ((eir  & (~mst_wmask)) | (mst_wdata & mst_wmask)))  |
                        ({AXI_DATA_W{eimr_wen }} & ((eimr & (~mst_wmask)) | (mst_wdata & mst_wmask)))  |
                        ({AXI_DATA_W{rdar_wen }} & ((ecr  & (~mst_wmask)) | (mst_wdata & mst_wmask)))  |
                        ({AXI_DATA_W{tdar_wen }} & ((mmfr & (~mst_wmask)) | (mst_wdata & mst_wmask)))  |
                        ({AXI_DATA_W{ecr_wen  }} & ((mscr & (~mst_wmask)) | (mst_wdata & mst_wmask)))  |
                        ({AXI_DATA_W{mmfr_wen }} & ((tcr  & (~mst_wmask)) | (mst_wdata & mst_wmask)))  |
                        ({AXI_DATA_W{mscr_wen }} & ((tdar & (~mst_wmask)) | (mst_wdata & mst_wmask)))  |
                        ({AXI_DATA_W{rcr_wen  }} & ((rcr  & (~mst_wmask)) | (mst_wdata & mst_wmask)))  |
                        ({AXI_DATA_W{tcr_wen  }} & ((rdar & (~mst_wmask)) | (mst_wdata & mst_wmask)))  |
                        ({AXI_DATA_W{palr_wen }} & ((palr & (~mst_wmask)) | (mst_wdata & mst_wmask)))  |
                        ({AXI_DATA_W{paur_wen }} & ((paur & (~mst_wmask)) | (mst_wdata & mst_wmask)))  |
                        ({AXI_DATA_W{opd_wen  }} & ((opd  & (~mst_wmask)) | (mst_wdata & mst_wmask)))  |
                        ({AXI_DATA_W{txic_wen }} & ((txic & (~mst_wmask)) | (mst_wdata & mst_wmask)))  |
                        ({AXI_DATA_W{rxic_wen }} & ((rxic & (~mst_wmask)) | (mst_wdata & mst_wmask)))  |
                        ({AXI_DATA_W{iaur_wen }} & ((ialr & (~mst_wmask)) | (mst_wdata & mst_wmask)))  |
                        ({AXI_DATA_W{ialr_wen }} & ((iaur & (~mst_wmask)) | (mst_wdata & mst_wmask)))  |
                        ({AXI_DATA_W{gaur_wen }} & ((galr & (~mst_wmask)) | (mst_wdata & mst_wmask)))  |
                        ({AXI_DATA_W{galr_wen }} & ((gaur & (~mst_wmask)) | (mst_wdata & mst_wmask)))  |
                        ({AXI_DATA_W{tfwr_wen }} & ((rdsr & (~mst_wmask)) | (mst_wdata & mst_wmask)))  |
                        ({AXI_DATA_W{rdsr_wen }} & ((tdsr & (~mst_wmask)) | (mst_wdata & mst_wmask)))  |
                        ({AXI_DATA_W{tdsr_wen }} & ((rsfl & (~mst_wmask)) | (mst_wdata & mst_wmask)))  |
                        ({AXI_DATA_W{rsfl_wen }} & ((rsem & (~mst_wmask)) | (mst_wdata & mst_wmask)))  |
                        ({AXI_DATA_W{rsem_wen }} & ((rafl & (~mst_wmask)) | (mst_wdata & mst_wmask)))  |
                        ({AXI_DATA_W{raem_wen }} & ((raem & (~mst_wmask)) | (mst_wdata & mst_wmask)))  |
                        ({AXI_DATA_W{rafl_wen }} & ((tfwr & (~mst_wmask)) | (mst_wdata & mst_wmask)))  |
                        ({AXI_DATA_W{tsem_wen }} & ((tsem & (~mst_wmask)) | (mst_wdata & mst_wmask)))  |
                        ({AXI_DATA_W{taem_wen }} & ((tafl & (~mst_wmask)) | (mst_wdata & mst_wmask)))  |
                        ({AXI_DATA_W{tafl_wen }} & ((taem & (~mst_wmask)) | (mst_wdata & mst_wmask)))  |
                        ({AXI_DATA_W{tipg_wen }} & ((tipg & (~mst_wmask)) | (mst_wdata & mst_wmask)))  |
                        ({AXI_DATA_W{ftrl_wen }} & ((ftrl & (~mst_wmask)) | (mst_wdata & mst_wmask)))  ;

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

endmodule //enet_axi2reg
