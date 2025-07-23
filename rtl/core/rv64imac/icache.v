module icache#(
    parameter AXI_ID_SB = 3, 

    // Address width in bits
    parameter AXI_ADDR_W = 64,
    // ID width in bits
    parameter AXI_ID_W = 8,
    // Data width in bits
    parameter AXI_DATA_W = 64,

    parameter ICACHE_WAY = 2, 
    parameter ICACHE_GROUP = 2,
    parameter PMEM_START = 64'h8000_0000,
    parameter PMEM_END = 64'hFFFF_FFFF
)(
    input                           clk,
    input                           rst_n,
//interface with wbu 
    input  [1:0]                    current_priv_status,
    input  [3:0]                    satp_mode,
    input  [15:0]                   satp_asid,
//all flush flag 
    input                           flush_flag,
    input                           flush_i_valid,
    input                           sflush_vma_valid,
//interface with ifu
    //read addr channel
    output                          ifu_arready,
    input                           ifu_arvalid,
    input  [63:0]                   ifu_araddr,
    //read data channel
    output                          ifu_rvalid,
    input                           ifu_rready,
    output [1:0]                    ifu_rresp,
    output [63:0]                   ifu_rdata,
//interface with l2tlb
    output                          immu_miss_valid,
    input                           immu_miss_ready,
    output [63:0]                   vaddr_i,
    input                           pte_valid,
    output                          pte_ready_i,
    input  [127:0]                  pte,
    input                           pte_error,
//interface with axi
    //read addr channel
    output                          icache_arvalid,
    input                           icache_arready,
    output [AXI_ADDR_W    -1:0]     icache_araddr,
    output [8             -1:0]     icache_arlen,
    output [3             -1:0]     icache_arsize,
    output [2             -1:0]     icache_arburst,
    output [AXI_ID_W      -1:0]     icache_arid,
    //read data channel
    input                           icache_rvalid,
    output                          icache_rready,
    input  [AXI_ID_W      -1:0]     icache_rid,
    input  [2             -1:0]     icache_rresp,
    input  [AXI_DATA_W    -1:0]     icache_rdata,
    input                           icache_rlast
);

localparam ICACHE_TAG_GROUP = (ICACHE_GROUP % 2 == 0) ? ICACHE_GROUP / 2 : (ICACHE_GROUP / 2 + 1);
localparam ICACHE_GROUP_LEN = $clog2(ICACHE_GROUP);
localparam ICACHE_WAY_LEN   = $clog2(ICACHE_WAY);
localparam ICACHE_TAG_SIZE  = 64 - 10 - ICACHE_GROUP_LEN;

//sram interface
wire [63:0]                 icache_line_valid[0:ICACHE_GROUP-1][0:ICACHE_WAY-1];
wire [127:0]                sram_tag_rdata[0:ICACHE_TAG_GROUP-1][0:ICACHE_WAY-1];
wire [63:0]                 sram_tag[0:ICACHE_GROUP-1][0:ICACHE_WAY-1];
wire                        sram_tag_cen[0:ICACHE_TAG_GROUP-1];
wire                        sram_tag_wen[0:ICACHE_TAG_GROUP-1][0:ICACHE_WAY-1];
wire [127:0]                sram_tag_bwen;
wire [127:0]                sram_data_rdata[0:ICACHE_GROUP-1][0:ICACHE_WAY-1];
wire                        sram_data_cen[0:ICACHE_GROUP-1];
wire                        sram_data_wen[0:ICACHE_GROUP-1][0:ICACHE_WAY-1];
wire [5:0]                  sram_addr;
wire [ICACHE_WAY_LEN-1:0]   rand_way;

//fifo signs 
reg  [2:0]                  rch_fifo_cnt;
reg  [2:0]                  mmu_fifo_cnt;
wire                        fifo_wen;
reg                         rch_fifo_ren;
wire                        mmu_fifo_ren;
wire [63:0]                 fifo_wdata;
wire                	    rch_fifo_empty;
wire [63:0] 	            rch_fifo_rdata;
wire                	    mmu_fifo_empty;
wire [63:0] 	            mmu_fifo_rdata;
wire                        out_fifo_wen;
wire                        out_fifo_ren;
wire [65:0]                 out_fifo_wdata;
wire                	    out_fifo_empty;
wire [65:0] 	            out_fifo_rdata;
reg  [2:0]                  out_fifo_cnt;

//immu signs 
wire                        paddr_valid;
wire                        paddr_ready;
wire [63:0]                 paddr;
wire                        paddr_error;

//icache fsm sign
localparam IDLE         = 3'b000;
localparam WAIT_ARREADY = 3'b010;
localparam WAIT_RVALID0 = 3'b110;
localparam DATA0_ERROR  = 3'b001;
localparam WAIT_RVALID1 = 3'b111;
localparam WRITE_CACHE  = 3'b101;
localparam SEND_DATA    = 3'b100;
reg  [2:0]                  icache_fsm;
reg  [1:0]                  icache_ifu_resp_reg;
reg                         icache_arvalid_reg;
wire [127:0]                sram_tag_wdata;
reg  [127:0]                sram_data_wdata;
reg                         icache_line_wen;
wire [63:0]                 icache_line_waddr;

reg                         icache_send_not_recv_flag;

//first stage register
wire                        first_stage_valid;
wire                        first_stage_ready;
wire [127:0]                sram_data_way_reg[0:ICACHE_WAY-1];
wire [63:0]                 sram_tag_way_reg[0:ICACHE_WAY-1];
wire [63:0]                 icache_line_valid_way_reg[0:ICACHE_WAY-1];

wire                        way_flag_set;
wire                        way_flag_clr;
wire                        way_flag_wen;
wire                        way_flag_nxt;
wire                        way_flag;
wire [127:0]                sram_data_way_use[0:ICACHE_WAY-1];
wire [63:0]                 sram_tag_way_use[0:ICACHE_WAY-1];
wire [63:0]                 icache_line_valid_way_use[0:ICACHE_WAY-1];

wire [127:0]                sram_data_way[0:ICACHE_WAY-1];
wire [63:0]                 sram_tag_way[0:ICACHE_WAY-1];
wire [63:0]                 icache_line_valid_way[0:ICACHE_WAY-1];

wire [ICACHE_WAY-1:0]       sram_way_sel;
wire [127:0]                sram_data_sel;
//**********************************************************************************************
//?icache sram
genvar icache_group_index;
genvar icache_way_index;
generate
    for(icache_group_index = 0; icache_group_index < ICACHE_GROUP; icache_group_index = icache_group_index + 1)begin: icache_group_sram
        for(icache_way_index = 0; icache_way_index < ICACHE_WAY; icache_way_index = icache_way_index + 1)begin: icache_way_sram
            S011HD1P_X32Y2D128_BW u_S011HD1P_X32Y2D128_BW_data(
                .Q    	( sram_data_rdata[icache_group_index][icache_way_index]     ),
                .CLK  	( clk                                                       ),
                .CEN  	( sram_data_cen[icache_group_index]                         ),
                .WEN  	( sram_data_wen[icache_group_index][icache_way_index]       ),
                .BWEN 	( 128'h0                                                    ),
                .A    	( sram_addr                                                 ),
                .D    	( sram_data_wdata                                           )
            );
            if(ICACHE_GROUP == 1)begin
                assign sram_data_wen[icache_group_index][icache_way_index]          = (!icache_line_wen) | (icache_way_index != rand_way);
                assign sram_data_way[icache_way_index]                              = sram_data_rdata[icache_group_index][icache_way_index];
                assign sram_tag_way[icache_way_index]                               = sram_tag[icache_group_index][icache_way_index];
                assign icache_line_valid_way[icache_way_index]                      = icache_line_valid[icache_group_index][icache_way_index];
            end
            else begin
                assign sram_data_wen[icache_group_index][icache_way_index]          = (!icache_line_wen) | (icache_way_index != rand_way) | 
                                                                                        (icache_group_index != icache_line_waddr[9 + ICACHE_GROUP_LEN:10]);
                assign sram_data_way[icache_way_index]                              = sram_data_rdata[icache_line_waddr[9 + ICACHE_GROUP_LEN:10]][icache_way_index];
                assign sram_tag_way[icache_way_index]                               = sram_tag[icache_line_waddr[9 + ICACHE_GROUP_LEN:10]][icache_way_index];
                assign icache_line_valid_way[icache_way_index]                      = icache_line_valid[icache_line_waddr[9 + ICACHE_GROUP_LEN:10]][icache_way_index];
            end
            if(icache_group_index % 2 == 0)begin
                S011HD1P_X32Y2D128_BW u_S011HD1P_X32Y2D128_BW_tag(
                    .Q    	( sram_tag_rdata[icache_group_index/2][icache_way_index]    ),
                    .CLK  	( clk                                                       ),
                    .CEN  	( sram_tag_cen[icache_group_index/2]                        ),
                    .WEN  	( sram_tag_wen[icache_group_index/2][icache_way_index]      ),
                    .BWEN 	( sram_tag_bwen                                             ),
                    .A    	( sram_addr                                                 ),
                    .D    	( sram_tag_wdata                                            )
                );
                if((icache_group_index + 1) >= ICACHE_GROUP)begin
                    assign sram_tag_cen[icache_group_index/2]                       = sram_data_cen[icache_group_index];
                    assign sram_tag_wen[icache_group_index/2][icache_way_index]     = sram_data_wen[icache_group_index][icache_way_index];
                end
                else begin
                    assign sram_tag_cen[icache_group_index/2]                       = sram_data_cen[icache_group_index]                     & sram_data_cen[icache_group_index+1];
                    assign sram_tag_wen[icache_group_index/2][icache_way_index]     = sram_data_wen[icache_group_index][icache_way_index]   & sram_data_wen[icache_group_index+1][icache_way_index];
                end
            end
            if(icache_group_index % 2 == 0)begin
                assign sram_tag[icache_group_index][icache_way_index]               = sram_tag_rdata[icache_group_index/2][icache_way_index][63:0];
            end
            else begin
                assign sram_tag[icache_group_index][icache_way_index]               = sram_tag_rdata[icache_group_index/2][icache_way_index][127:64];
            end
            FF_D_with_addr #(
                .ADDR_LEN   ( 6 ),
                .RST_DATA   ( 0 )
            )u_icache_line_valid(
                .clk        ( clk                                                       ),
                .rst_n      ( rst_n                                                     ),
                .syn_rst    ( flush_i_valid                                             ),
                .wen        ( !sram_data_wen[icache_group_index][icache_way_index]      ),
                .addr       ( sram_addr                                                 ),
                .data_in    ( 1'b1                                                      ),
                .data_out   ( icache_line_valid[icache_group_index][icache_way_index]   )
            );
            if(icache_group_index == 0)begin
                assign sram_way_sel[icache_way_index]                           = (sram_tag_way_use[icache_way_index][63:64-ICACHE_TAG_SIZE] == paddr[63:64-ICACHE_TAG_SIZE]) & 
                                                                                    icache_line_valid_way_use[icache_way_index][icache_line_waddr[9:4]]; 
            end
            if(icache_group_index == 0)begin
                FF_D_without_asyn_rst #(128)  u_sram_data_way            (clk,way_flag_set,sram_data_way[icache_way_index],sram_data_way_reg[icache_way_index]);
                FF_D_without_asyn_rst #(64)   u_sram_tag_way             (clk,way_flag_set,sram_tag_way[icache_way_index] ,sram_tag_way_reg[icache_way_index] );
                FF_D_without_asyn_rst #(64)   u_icache_line_valid_way    (clk,way_flag_set,icache_line_valid_way[icache_way_index],icache_line_valid_way_reg[icache_way_index]);
                assign sram_data_way_use[icache_way_index]            = (way_flag) ? sram_data_way_reg[icache_way_index] : sram_data_way[icache_way_index];
                assign sram_tag_way_use[icache_way_index]             = (way_flag) ? sram_tag_way_reg[icache_way_index] : sram_tag_way[icache_way_index];
                assign icache_line_valid_way_use[icache_way_index]    = (way_flag) ? icache_line_valid_way_reg[icache_way_index] : icache_line_valid_way[icache_way_index];
            end
        end
        if(ICACHE_GROUP == 1)begin
            assign sram_data_cen[icache_group_index]                            =   (!icache_line_wen) & (rch_fifo_empty);
        end
        else begin
            assign sram_data_cen[icache_group_index]                            =   (( rch_fifo_empty ) | (icache_group_index != rch_fifo_rdata[9 + ICACHE_GROUP_LEN:10]) | icache_line_wen) & 
                                                                                    ((!icache_line_wen) | (icache_group_index != icache_line_waddr[9 + ICACHE_GROUP_LEN:10])) ;
        end
    end
endgenerate
rand_lfsr_8_bit #(
    .USING_LEN(ICACHE_WAY_LEN)
)u_rand_lfsr_8_bit_get_rand_way_num(
    .clk   	( clk           ),
    .rst_n 	( rst_n         ),
    .out   	( rand_way      )
);
FF_D_without_asyn_rst #(64)   u_icache_line_waddr           (clk,rch_fifo_ren,rch_fifo_rdata,icache_line_waddr);
assign sram_addr                = (icache_line_wen) ? icache_line_waddr[9:4] : rch_fifo_rdata[9:4];
assign sram_tag_wdata           = {paddr, paddr};
if(ICACHE_GROUP == 1)begin
    assign sram_tag_bwen        = 128'h0;
end
else begin
    assign sram_tag_bwen        = (icache_line_waddr[10]) ? {{64{1'b0}}, {64{1'b1}}} : {{64{1'b1}}, {64{1'b0}}};
end
assign way_flag_set = first_stage_valid & (!first_stage_ready) & (!way_flag);
assign way_flag_clr = first_stage_ready;
assign way_flag_wen = (way_flag_set | way_flag_clr);
assign way_flag_nxt = (way_flag_set | (!way_flag_clr));
FF_D_with_syn_rst #(
    .DATA_LEN 	(1  ),
    .RST_DATA 	(0  ))
u_way_flag(
    .clk      	(clk            ),
    .rst_n    	(rst_n          ),
    .syn_rst  	(flush_flag     ),
    .wen      	(way_flag_wen   ),
    .data_in  	(way_flag_nxt   ),
    .data_out 	(way_flag       )
);
assign sram_data_sel            = icache_line_sel(sram_way_sel, sram_data_way_use);
//**********************************************************************************************
ifu_fifo #(
    .DATA_LEN   	( 64  ),
    .AddR_Width 	( 3   ))
rch_fifo(
    .clk    	( clk               ),
    .rst_n  	( rst_n             ),
    .Wready 	( fifo_wen          ),
    .Rready 	( rch_fifo_ren      ),
    .flush  	( flush_flag        ),
    .wdata  	( fifo_wdata        ),
    .empty  	( rch_fifo_empty    ),
    .rdata  	( rch_fifo_rdata    )
);

ifu_fifo #(
    .DATA_LEN   	( 64  ),
    .AddR_Width 	( 3   ))
mmu_fifo(
    .clk    	( clk               ),
    .rst_n  	( rst_n             ),
    .Wready 	( fifo_wen          ),
    .Rready 	( mmu_fifo_ren      ),
    .flush  	( flush_flag        ),
    .wdata  	( fifo_wdata        ),
    .empty  	( mmu_fifo_empty    ),
    .rdata  	( mmu_fifo_rdata    )
);

ifu_fifo #(
    .DATA_LEN   	( 66  ),
    .AddR_Width 	( 3   ))
out_fifo(
    .clk    	( clk               ),
    .rst_n  	( rst_n             ),
    .Wready 	( out_fifo_wen      ),
    .Rready 	( out_fifo_ren      ),
    .flush  	( flush_flag        ),
    .wdata  	( out_fifo_wdata    ),
    .empty  	( out_fifo_empty    ),
    .rdata  	( out_fifo_rdata    )
);

FF_D_with_syn_rst #(
    .DATA_LEN 	(1  ),
    .RST_DATA 	(0  ))
u_first_stage_valid(
    .clk      	(clk                                        ),
    .rst_n    	(rst_n                                      ),
    .syn_rst  	(flush_flag                                 ),
    .wen      	(first_stage_ready | (!first_stage_valid)   ),
    .data_in  	(rch_fifo_ren                               ),
    .data_out 	(first_stage_valid                          )
);
assign first_stage_ready = out_fifo_wen;

always @(posedge clk or negedge rst_n) begin
    if(!rst_n)begin
        rch_fifo_cnt <= 3'h0;
    end
    else if(flush_flag)begin
        rch_fifo_cnt <= 3'h0;
    end
    else if(rch_fifo_ren & (!fifo_wen))begin
        rch_fifo_cnt <= rch_fifo_cnt + 3'h7;
    end
    else if((!rch_fifo_ren) & fifo_wen)begin
        rch_fifo_cnt <= rch_fifo_cnt + 3'h1;
    end
end
always @(posedge clk or negedge rst_n) begin
    if(!rst_n)begin
        mmu_fifo_cnt <= 3'h0;
    end
    else if(flush_flag)begin
        mmu_fifo_cnt <= 3'h0;
    end
    else if(mmu_fifo_ren & (!fifo_wen))begin
        mmu_fifo_cnt <= mmu_fifo_cnt + 3'h7;
    end
    else if((!mmu_fifo_ren) & fifo_wen)begin
        mmu_fifo_cnt <= mmu_fifo_cnt + 3'h1;
    end
end
always @(posedge clk or negedge rst_n) begin
    if(!rst_n)begin
        out_fifo_cnt <= 3'h0;
    end
    else if(flush_flag)begin
        out_fifo_cnt <= 3'h0;
    end
    else if(out_fifo_ren & (!out_fifo_wen))begin
        out_fifo_cnt <= out_fifo_cnt + 3'h7;
    end
    else if((!out_fifo_ren) & out_fifo_wen)begin
        out_fifo_cnt <= out_fifo_cnt + 3'h1;
    end
end

//!fsm
always @(posedge clk or negedge rst_n) begin
    if(!rst_n)begin
        icache_fsm          <= IDLE;
        icache_arvalid_reg  <= 1'b0;
        icache_line_wen     <= 1'b0;
        icache_ifu_resp_reg <= 2'h0;
    end
    else if(flush_flag)begin
        icache_fsm          <= IDLE;
        icache_arvalid_reg  <= 1'b0;
        icache_line_wen     <= 1'b0;
        icache_ifu_resp_reg <= 2'h0;
    end
    else begin
        case (icache_fsm)
            IDLE: begin
                if(first_stage_valid & paddr_valid & (!(|sram_way_sel)) & (!paddr_error) & (!icache_send_not_recv_flag))begin
                    icache_fsm          <= WAIT_ARREADY;
                    icache_arvalid_reg  <= 1'b1;
                end
            end
            WAIT_ARREADY: begin
                if(icache_arvalid & icache_arready)begin
                    icache_fsm          <= WAIT_RVALID0;
                    icache_arvalid_reg  <= 1'b0;
                end
            end
            WAIT_RVALID0: begin
                if(icache_rvalid & icache_rready & (icache_rid == AXI_ID_SB) & (icache_rresp != 2'h0))begin
                    icache_fsm          <= DATA0_ERROR;
                    icache_ifu_resp_reg <= 2'h3;
                end
                else if(icache_rvalid & icache_rready & (icache_rid == AXI_ID_SB) & icache_rlast)begin
                    icache_fsm          <= SEND_DATA;
                    icache_ifu_resp_reg <= 2'h3;
                end
                else if(icache_rvalid & icache_rready & (icache_rid == AXI_ID_SB))begin
                    icache_fsm          <= WAIT_RVALID1;
                end
            end
            DATA0_ERROR: begin
                if(icache_rvalid & icache_rready & (icache_rid == AXI_ID_SB) & icache_rlast)begin
                    icache_fsm          <= SEND_DATA;
                end
            end
            WAIT_RVALID1: begin
                if(icache_rvalid & icache_rready & (icache_rid == AXI_ID_SB) & (icache_rresp != 2'h0))begin
                    icache_fsm          <= SEND_DATA;
                    icache_ifu_resp_reg <= 2'h3;
                end
                else if(icache_rvalid & icache_rready & (icache_rid == AXI_ID_SB) & (!icache_rlast))begin
                    icache_fsm          <= DATA0_ERROR;
                    icache_ifu_resp_reg <= 2'h3;
                end
                else if(icache_rvalid & icache_rready & (icache_rid == AXI_ID_SB) & ((paddr > PMEM_END) | (paddr < PMEM_START)))begin
                    icache_fsm          <= SEND_DATA;
                    icache_ifu_resp_reg <= 2'h0;
                end
                else if(icache_rvalid & icache_rready & (icache_rid == AXI_ID_SB))begin
                    icache_fsm          <= WRITE_CACHE;
                    icache_line_wen     <= 1'b1;
                    icache_ifu_resp_reg <= 2'h0;
                end
            end
            WRITE_CACHE: begin
                icache_fsm          <= SEND_DATA;
                icache_line_wen     <= 1'b0;
            end
            SEND_DATA: begin
                if(out_fifo_wen)begin
                    icache_fsm      <= IDLE;
                end
            end
            default: begin
                icache_fsm          <= IDLE;
                icache_arvalid_reg  <= 1'b0;
                icache_line_wen     <= 1'b0;
                icache_ifu_resp_reg <= 2'h0;
            end
        endcase
    end
end
always @(posedge clk) begin
    if((icache_fsm == WAIT_RVALID0) & icache_rvalid & icache_rready & (icache_rid == AXI_ID_SB) & (icache_rresp == 2'h0) & (!icache_rlast))begin
        sram_data_wdata[63:0]          <= icache_rdata;
    end
    if((icache_fsm == WAIT_RVALID1) & icache_rvalid & icache_rready & (icache_rid == AXI_ID_SB) & (icache_rresp == 2'h0) & icache_rlast)begin
        sram_data_wdata[127:64]        <= icache_rdata;
    end
end
always @(posedge clk or negedge rst_n) begin
    if(!rst_n)begin
        icache_send_not_recv_flag       <= 1'b0;
    end
    else if(icache_send_not_recv_flag)begin
        if(icache_rvalid & icache_rready & (icache_rid == AXI_ID_SB) & icache_rlast)begin
            icache_send_not_recv_flag   <= 1'b0;
        end
    end
    else if(flush_flag & (icache_fsm == WAIT_ARREADY) & icache_arvalid & icache_arready)begin
        icache_send_not_recv_flag       <= 1'b1;
    end
    else if(flush_flag & (icache_fsm == WAIT_RVALID0) & (!(icache_rvalid & icache_rready & (icache_rid == AXI_ID_SB) & icache_rlast)))begin
        icache_send_not_recv_flag       <= 1'b1;
    end
    else if(flush_flag & (icache_fsm == DATA0_ERROR) & (!(icache_rvalid & icache_rready & (icache_rid == AXI_ID_SB) & icache_rlast)))begin
        icache_send_not_recv_flag       <= 1'b1;
    end
    else if(flush_flag & (icache_fsm == WAIT_RVALID1) & (!(icache_rvalid & icache_rready & (icache_rid == AXI_ID_SB) & icache_rlast)))begin
        icache_send_not_recv_flag       <= 1'b1;
    end
end

assign rch_fifo_ren     = (!rch_fifo_empty) & (first_stage_ready | (!first_stage_valid));
assign fifo_wen         = ifu_arvalid & ifu_arready;
assign fifo_wdata       = ifu_araddr;
assign out_fifo_ren     = ifu_rvalid & ifu_rready;
assign out_fifo_wen     = ((first_stage_valid & paddr_valid & ((|sram_way_sel) | paddr_error)) | (icache_fsm == SEND_DATA)) & (out_fifo_cnt != 3'h7);
assign out_fifo_wdata   = (icache_fsm == SEND_DATA) ? ((icache_line_waddr[3]) ? {icache_ifu_resp_reg, sram_data_wdata[127:64]} : {icache_ifu_resp_reg, sram_data_wdata[63:0]}) 
                                                    : ((icache_line_waddr[3]) ? {paddr_error, 1'b0, sram_data_sel[127:64]} : {paddr_error, 1'b0, sram_data_sel[63:0]});

immu u_immu(
    .clk                 	(clk                  ),
    .rst_n               	(rst_n                ),
    .current_priv_status 	(current_priv_status  ),
    .satp_mode           	(satp_mode            ),
    .satp_asid           	(satp_asid            ),
    .flush_flag          	(flush_flag           ),
    .sflush_vma_valid    	(sflush_vma_valid     ),
    .immu_miss_valid     	(immu_miss_valid      ),
    .immu_miss_ready     	(immu_miss_ready      ),
    .vaddr_i             	(vaddr_i              ),
    .pte_valid           	(pte_valid            ),
    .pte_ready_i         	(pte_ready_i          ),
    .pte                 	(pte                  ),
    .pte_error           	(pte_error            ),
    .mmu_fifo_valid      	(!mmu_fifo_empty      ),
    .mmu_fifo_ready      	(mmu_fifo_ren         ),
    .vaddr               	(mmu_fifo_rdata       ),
    .paddr_valid         	(paddr_valid          ),
    .paddr_ready         	(paddr_ready          ),
    .paddr               	(paddr                ),
    .paddr_error         	(paddr_error          )
);
assign paddr_ready      = out_fifo_wen;
//**********************************************************************************************
//?out sign
assign ifu_arready      = (rch_fifo_cnt != 3'h7) & (mmu_fifo_cnt != 3'h7);
assign ifu_rvalid       = (!out_fifo_empty);
assign ifu_rresp        = out_fifo_rdata[65:64];
assign ifu_rdata        = out_fifo_rdata[63:0];
assign icache_arvalid   = icache_arvalid_reg;
assign icache_araddr    = {paddr[63:4], 4'h0};
assign icache_arid      = AXI_ID_SB;
assign icache_arlen     = 8'h1;
assign icache_arsize    = 3'h3;
assign icache_arburst   = 2'h1;
assign icache_rready    = 1'b1;
//**********************************************************************************************
//?function
function [127:0] icache_line_sel;
    input [ICACHE_WAY-1:0]  sel;
    input [127:0]           icache_line_rdata[0:ICACHE_WAY-1];
    integer index;
    begin
        icache_line_sel = 128'h0;
        for (index = 0; index < ICACHE_WAY; index = index + 1) begin
            if(sel[index] == 1'b1)begin
                icache_line_sel = icache_line_sel | icache_line_rdata[index];
            end
        end
    end
endfunction

endmodule //icache
