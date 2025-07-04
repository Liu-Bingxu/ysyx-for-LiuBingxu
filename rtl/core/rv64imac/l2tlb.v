`include "./define.v"
module l2tlb#(parameter MMU_WAY = 2, MMU_GROUP = 1)(
    input                   clk,
    input                   rst_n,
//interface with wbu
    input  [15:0]           satp_asid,
    input  [43:0]           satp_ppn,
//all flush flag 
    input                   flush_flag,
    input                   sflush_vma_valid,
    output                  sflush_vma_ready,
//interface with dcache
    //read addr channel
    input                   mmu_arready,
    output                  mmu_arvalid,
    output [63:0]           mmu_araddr,
    //read data channel
    output                  mmu_rready,
    input                   mmu_rvalid,
    input  [1:0]            mmu_rresp,
    input  [63:0]           mmu_rdata,
//interface with immu
    input                   immu_miss_valid,
    output                  immu_miss_ready,
    input  [63:0]           vaddr_i,
//interface with dmmu
    input                   dmmu_miss_valid,
    output                  dmmu_miss_ready,
    input  [63:0]           vaddr_d,
//interface with immu/dmmu
    output                  pte_valid,
    input                   pte_ready,
    output [127:0]          pte,
    output                  pte_error
);

localparam MMU_TAG_SIZE    = 21 - $clog2(MMU_GROUP);
localparam MMU_GROUP_LEN   = $clog2(MMU_GROUP);
localparam MMU_WAY_LEN     = $clog2(MMU_WAY);

//sram interface
wire [63:0]             tlb_page_valid[0:MMU_GROUP-1][0:MMU_WAY-1];
wire [63:0]             tlb_page_valid_way[0:MMU_WAY-1];
wire [127:0]            sram_rdata[0:MMU_GROUP-1][0:MMU_WAY-1];
wire                    sram_cen[0:MMU_GROUP-1];
wire                    sram_wen[0:MMU_GROUP-1][0:MMU_WAY-1];
wire [5:0]              sram_addr;
wire [127:0]            sram_wdata;
wire [127:0]            sram_1G_rdata;
wire [127:0]            sram_2M_rdata;
wire                    sram_sp_cen;
reg                     sram_1G_wen;
reg                     sram_2M_wen;
wire [5:0]              sram_1G_addr;
wire [5:0]              sram_2M_addr;
wire [127:0]            sram_1G_wdata;
wire [127:0]            sram_2M_wdata;
wire [127:0]            tlb_page;
wire [63:0]             tlb_1G_page_valid;
wire [63:0]             tlb_2M_page_valid;
wire [15:0]             tlb_page_asid[0:MMU_WAY-1];
wire [9:0]              tlb_page_attr[0:MMU_WAY-1];
wire [MMU_TAG_SIZE-1:0] tlb_page_tag [0:MMU_WAY-1];
wire [127:0]            tlb_rdata[0:MMU_WAY-1];
wire [MMU_WAY-1:0]      tlb_hit_way_sel;
wire                    tlb_hit_1G;
wire                    tlb_hit_2M;
wire                    tlb_hit_flag;
reg                     tlb_page_wen;

wire [MMU_WAY_LEN-1:0]  rand_way;

//stage
localparam IDLE         = 3'h0;
localparam SEARCH_TLB   = 3'h1;
localparam PAGE_WALK_1G = 3'h3;
localparam PAGE_WALK_2M = 3'h2;
localparam PAGE_WALK_4K = 3'h6;
localparam OUT          = 3'h4;
reg  [2:0]              stage_status;
reg  [63:0]             stage_vaddr;
reg                     out_error;
reg  [127:0]            out_pte;

//axi interface
reg                     mmu_arvalid_reg;
wire [63:0]             mmu_araddr_wire;
reg  [43:0]             mmu_araddr_ppn;
reg  [8:0]              mmu_araddr_offset;
wire [43:0]             mmu_rdata_page_ppn;
wire                    mmu_rdata_page_A;
wire                    mmu_rdata_page_W;
wire                    mmu_rdata_page_R;
wire                    mmu_rdata_page_V;

//**********************************************************************************************
//?tlb
//+---------------------------------------------------------------+
//|                      sram_rdata                               |
//|_______________________________________________________________|
//|127|...|112|111|...|68|67|...|58|57|...|31|30|...|3| 2 | 1 | 0 |
//|   ASID    |    PPN   |  ATTR   |   TAG   | UNUSED | page size |
//+-----------|----------|---------|---------|--------|-----------|
genvar tlb_group_index;
genvar tlb_way_index;
generate
    for(tlb_group_index = 0; tlb_group_index < MMU_GROUP; tlb_group_index = tlb_group_index + 1)begin: tlb_group_sram
        for(tlb_way_index = 0; tlb_way_index < MMU_WAY; tlb_way_index = tlb_way_index + 1)begin: tlb_way_sram
            S011HD1P_X32Y2D128_BW u_S011HD1P_X32Y2D128_BW_small_tlb(
                .Q    	( sram_rdata[tlb_group_index][tlb_way_index]    ),
                .CLK  	( clk                                           ),
                .CEN  	( sram_cen[tlb_group_index]                     ),
                .WEN  	( sram_wen[tlb_group_index][tlb_way_index]      ),
                .BWEN 	( 128'h0                                        ),
                .A    	( sram_addr                                     ),
                .D    	( sram_wdata                                    )
            );
            FF_D_with_addr #(
                .ADDR_LEN   ( 6 ),
                .RST_DATA   ( 0 )
            )u_tlb_valid(
                .clk        ( clk                                               ),
                .rst_n      ( rst_n                                             ),
                .syn_rst    ( sflush_vma_valid                                  ),
                .wen        ( !sram_wen[tlb_group_index][tlb_way_index]         ),
                .addr       ( sram_addr                                         ),
                .data_in    ( 1'b1                                              ),
                .data_out   ( tlb_page_valid[tlb_group_index][tlb_way_index]    )
            );
            if(MMU_GROUP == 1)begin
                assign sram_wen[tlb_group_index][tlb_way_index] = (!tlb_page_wen) | (tlb_way_index != rand_way);
                if(tlb_group_index == 0)begin
                    assign tlb_rdata[tlb_way_index]             = sram_rdata[tlb_group_index][tlb_way_index];
                    assign tlb_page_valid_way[tlb_way_index]    = tlb_page_valid[tlb_group_index][tlb_way_index];
                end 
            end
            else begin
                assign sram_wen[tlb_group_index][tlb_way_index] = ((!tlb_page_wen) | (tlb_way_index != rand_way) | (tlb_group_index != stage_vaddr[17 + MMU_GROUP_LEN:18]));
                if(tlb_group_index == 0)begin
                    assign tlb_rdata[tlb_way_index] = sram_rdata[stage_vaddr[17 + MMU_GROUP_LEN:18]][tlb_way_index];
                    assign tlb_page_valid_way[tlb_way_index]    = tlb_page_valid[stage_vaddr[17 + MMU_GROUP_LEN:18]][tlb_way_index];
                end 
            end
            if(tlb_group_index == 0)begin
                assign tlb_page_asid[tlb_way_index]                 = tlb_rdata[tlb_way_index][127:112];
                assign tlb_page_attr[tlb_way_index]                 = tlb_rdata[tlb_way_index][67:58];
                assign tlb_page_tag [tlb_way_index]                 = tlb_rdata[tlb_way_index][57:58 - MMU_TAG_SIZE];
                assign tlb_hit_way_sel[tlb_way_index]               = (tlb_page_valid_way[tlb_way_index][stage_vaddr[17:12]]) & 
                                                                        ((tlb_page_asid[tlb_way_index] == satp_asid) | tlb_page_attr[tlb_way_index][5]) & 
                                                                        ( tlb_page_tag [tlb_way_index] == stage_vaddr[38:39-MMU_TAG_SIZE]);
            end
        end
        if(MMU_GROUP == 1)begin
            assign sram_cen[tlb_group_index]                     = (!immu_miss_valid) & (!dmmu_miss_valid) & (stage_status == IDLE);
        end
        else begin
            assign sram_cen[tlb_group_index]                     = ((!(immu_miss_valid & immu_miss_ready)) | (tlb_group_index != vaddr_i[17 + MMU_GROUP_LEN:18])) & 
                                                                    ((!(dmmu_miss_valid & dmmu_miss_ready)) | (tlb_group_index != vaddr_d[17 + MMU_GROUP_LEN:18])) & 
                                                                    ((stage_status == IDLE) | (tlb_group_index != stage_vaddr[17 + MMU_GROUP_LEN:18]));
        end
    end
endgenerate
S011HD1P_X32Y2D128_BW u_S011HD1P_X32Y2D128_BW_1G_tlb(
    .Q    	( sram_1G_rdata ),
    .CLK  	( clk           ),
    .CEN  	( sram_sp_cen   ),
    .WEN  	( sram_1G_wen   ),
    .BWEN 	( 128'h0        ),
    .A    	( sram_1G_addr  ),
    .D    	( sram_1G_wdata )
);
FF_D_with_addr #(
    .ADDR_LEN   ( 6 ),
    .RST_DATA   ( 0 )
)u_tlb_1G_valid(
    .clk        ( clk               ),
    .rst_n      ( rst_n             ),
    .syn_rst    ( sflush_vma_valid  ),
    .wen        ( !sram_1G_wen      ),
    .addr       ( sram_1G_addr      ),
    .data_in    ( 1'b1              ),
    .data_out   ( tlb_1G_page_valid )
);
assign sram_1G_addr = ((stage_status != IDLE) ? stage_vaddr[35:30] : (immu_miss_valid) ? vaddr_i[35:30] : vaddr_d[35:30]);
assign tlb_hit_1G = (tlb_1G_page_valid[stage_vaddr[17:12]]) & ((sram_1G_rdata[127:112] == satp_asid) | sram_1G_rdata[63]) & (sram_1G_rdata[57:55] == stage_vaddr[38:36]);
S011HD1P_X32Y2D128_BW u_S011HD1P_X32Y2D128_BW_2M_tlb(
    .Q    	( sram_2M_rdata ),
    .CLK  	( clk           ),
    .CEN  	( sram_sp_cen   ),
    .WEN  	( sram_2M_wen   ),
    .BWEN 	( 128'h0        ),
    .A    	( sram_2M_addr  ),
    .D    	( sram_2M_wdata )
);
FF_D_with_addr #(
    .ADDR_LEN   ( 6 ),
    .RST_DATA   ( 0 )
)u_tlb_2M_valid(
    .clk        ( clk               ),
    .rst_n      ( rst_n             ),
    .syn_rst    ( sflush_vma_valid  ),
    .wen        ( !sram_2M_wen      ),
    .addr       ( sram_2M_addr      ),
    .data_in    ( 1'b1              ),
    .data_out   ( tlb_2M_page_valid )
);
assign sram_2M_addr = ((stage_status != IDLE) ? stage_vaddr[26:21] : (immu_miss_valid) ? vaddr_i[26:21] : vaddr_d[26:21]);
assign tlb_hit_2M = (tlb_2M_page_valid[stage_vaddr[17:12]]) & ((sram_2M_rdata[127:112] == satp_asid) | sram_2M_rdata[63]) & (sram_2M_rdata[57:46] == stage_vaddr[38:27]);
assign sram_sp_cen = (!immu_miss_valid) & (!dmmu_miss_valid) & (stage_status == IDLE);
rand_lfsr_8_bit #(
    .USING_LEN(MMU_WAY_LEN)
)u_rand_lfsr_8_bit_get_rand_way_num(
    .clk   	( clk           ),
    .rst_n 	( rst_n         ),
    .out   	( rand_way      )
);
assign tlb_page                     = tlb_page_sel(tlb_hit_way_sel, tlb_rdata) | 
                                        ({128{tlb_hit_1G}} & sram_1G_rdata) | 
                                        ({128{tlb_hit_2M}} & sram_2M_rdata);
assign sram_addr                    = ((stage_status != IDLE) ? stage_vaddr[17:12] : (immu_miss_valid) ? vaddr_i[17:12] : vaddr_d[17:12]);
assign sram_wdata                   = out_pte;
assign sram_1G_wdata                = out_pte;
assign sram_2M_wdata                = out_pte;
assign tlb_hit_flag                 = (|tlb_hit_way_sel) | tlb_hit_1G | tlb_hit_2M;
//**********************************************************************************************
//!fsm
always @(posedge clk or negedge rst_n) begin
    if(!rst_n)begin
        stage_status        <= IDLE;
        stage_vaddr         <= 64'h0;
        out_error           <= 1'b0;
        out_pte             <= 128'h0;
        mmu_arvalid_reg     <= 1'b0;
        mmu_araddr_ppn      <= 44'h0;
        mmu_araddr_offset   <= 9'h0;
        tlb_page_wen        <= 1'b0;
        sram_1G_wen         <= 1'b1;
        sram_2M_wen         <= 1'b1;
    end
    else if(flush_flag)begin
        stage_status        <= IDLE;
        stage_vaddr         <= 64'h0;
        out_error           <= 1'b0;
        out_pte             <= 128'h0;
        mmu_arvalid_reg     <= 1'b0;
        mmu_araddr_ppn      <= 44'h0;
        mmu_araddr_offset   <= 9'h0;
        tlb_page_wen        <= 1'b0;
        sram_1G_wen         <= 1'b1;
        sram_2M_wen         <= 1'b1;
    end
    else begin
        case (stage_status)
            IDLE: begin
                if(immu_miss_valid & immu_miss_ready & (vaddr_i[63:39] != {25{vaddr_i[38]}}))begin
                    stage_status <= OUT;
                    out_error    <= 1'b1;
                end
                else if(immu_miss_valid & immu_miss_ready)begin
                    stage_status <= SEARCH_TLB;
                    stage_vaddr  <= vaddr_i;
                end
                if(dmmu_miss_valid & dmmu_miss_ready & (vaddr_d[63:39] != {25{vaddr_d[38]}}))begin
                    stage_status <= OUT;
                    out_error    <= 1'b1;
                end
                else if(dmmu_miss_valid & dmmu_miss_ready)begin
                    stage_status <= SEARCH_TLB;
                    stage_vaddr  <= vaddr_d;
                end
            end
            SEARCH_TLB: begin
                if(tlb_hit_flag)begin
                    stage_status <= OUT;
                    out_error    <= 1'b0;
                    out_pte      <= tlb_page;
                end
                else begin
                    stage_status        <= PAGE_WALK_1G;
                    mmu_arvalid_reg     <= 1'b1;
                    mmu_araddr_ppn      <= satp_ppn;
                    mmu_araddr_offset   <= stage_vaddr[38:30];
                end
            end
            PAGE_WALK_1G: begin
                if(mmu_arvalid & mmu_arready)begin
                    mmu_arvalid_reg     <= 1'b0;
                end
                else if(mmu_rvalid & mmu_rready & (mmu_rresp != 2'h0))begin
                    stage_status <= OUT;
                    out_error    <= 1'b1;
                end
                else if(mmu_rvalid & mmu_rready)begin
                    //! high 10 bit is not zero
                    if(mmu_rdata[63:54] != 10'h0)begin
                        stage_status <= OUT;
                        out_error    <= 1'b1;
                    end
                    //! pte invalid
                    else if(mmu_rdata_page_V == 1'h0)begin
                        stage_status <= OUT;
                        out_error    <= 1'b1;
                    end
                    //! when r=0 but write=1
                    else if((mmu_rdata_page_R == 1'h0) & (mmu_rdata_page_W == 1'h1))begin
                        stage_status <= OUT;
                        out_error    <= 1'b1;
                    end
                    //! rwx == 0
                    else if(mmu_rdata[3:1] == 3'h0)begin
                        stage_status        <= PAGE_WALK_2M;
                        mmu_arvalid_reg     <= 1'b1;
                        mmu_araddr_ppn      <= mmu_rdata_page_ppn;
                        mmu_araddr_offset   <= stage_vaddr[29:21];
                    end
                    //! no align super page
                    else if(mmu_rdata[27:10] != 18'h0)begin
                        stage_status <= OUT;
                        out_error    <= 1'b1;
                    end
                    //! A control while A is zero
                    else if(mmu_rdata_page_A == 1'h0)begin
                        stage_status <= OUT;
                        out_error    <= 1'b1;
                    end
                    //! get a 1G super page
                    else begin
                        stage_status <= OUT;
                        sram_1G_wen  <= 1'b0;
                        out_error    <= 1'b0;
                        out_pte      <= {satp_asid, mmu_rdata_page_ppn, mmu_rdata[9:0], stage_vaddr[38:12], 28'h0, 3'h2};
                    end
                end
            end
            PAGE_WALK_2M: begin
                if(mmu_arvalid & mmu_arready)begin
                    mmu_arvalid_reg     <= 1'b0;
                end
                else if(mmu_rvalid & mmu_rready & (mmu_rresp != 2'h0))begin
                    stage_status <= OUT;
                    out_error    <= 1'b1;
                end
                else if(mmu_rvalid & mmu_rready)begin
                    //! high 10 bit is not zero
                    if(mmu_rdata[63:54] != 10'h0)begin
                        stage_status <= OUT;
                        out_error    <= 1'b1;
                    end
                    //! pte invalid
                    else if(mmu_rdata_page_V == 1'h0)begin
                        stage_status <= OUT;
                        out_error    <= 1'b1;
                    end
                    //! when r=0 but write=1
                    else if((mmu_rdata_page_R == 1'h0) & (mmu_rdata_page_W == 1'h1))begin
                        stage_status <= OUT;
                        out_error    <= 1'b1;
                    end
                    //! rwx == 0
                    else if(mmu_rdata[3:1] == 3'h0)begin
                        stage_status        <= PAGE_WALK_4K;
                        mmu_arvalid_reg     <= 1'b1;
                        mmu_araddr_ppn      <= mmu_rdata_page_ppn;
                        mmu_araddr_offset   <= stage_vaddr[20:12];
                    end
                    //! no align super page
                    else if(mmu_rdata[18:10] != 9'h0)begin
                        stage_status <= OUT;
                        out_error    <= 1'b1;
                    end
                    //! A control while A is zero
                    else if(mmu_rdata_page_A == 1'h0)begin
                        stage_status <= OUT;
                        out_error    <= 1'b1;
                    end
                    //! get a 2M super page
                    else begin
                        stage_status <= OUT;
                        sram_2M_wen  <= 1'b0;
                        out_error    <= 1'b0;
                        out_pte      <= {satp_asid, mmu_rdata_page_ppn, mmu_rdata[9:0], stage_vaddr[38:12], 28'h0, 3'h1};
                    end
                end
            end
            PAGE_WALK_4K: begin
                if(mmu_arvalid & mmu_arready)begin
                    mmu_arvalid_reg     <= 1'b0;
                end
                else if(mmu_rvalid & mmu_rready & (mmu_rresp != 2'h0))begin
                    stage_status <= OUT;
                    out_error    <= 1'b1;
                end
                else if(mmu_rvalid & mmu_rready)begin
                    //! high 10 bit is not zero
                    if(mmu_rdata[63:54] != 10'h0)begin
                        stage_status <= OUT;
                        out_error    <= 1'b1;
                    end
                    //! pte invalid
                    else if(mmu_rdata_page_V == 1'h0)begin
                        stage_status <= OUT;
                        out_error    <= 1'b1;
                    end
                    //! when r=0 but write=1
                    else if((mmu_rdata_page_R == 1'h0) & (mmu_rdata_page_W == 1'h1))begin
                        stage_status <= OUT;
                        out_error    <= 1'b1;
                    end
                    //! rwx == 0
                    else if(mmu_rdata[3:1] == 3'h0)begin
                        stage_status <= OUT;
                        out_error    <= 1'b1;
                    end
                    //! A control while A is zero
                    else if(mmu_rdata_page_A == 1'h0)begin
                        stage_status <= OUT;
                        out_error    <= 1'b1;
                    end
                    //! get a 4K page
                    else begin
                        stage_status <= OUT;
                        tlb_page_wen <= 1'b1;
                        out_error    <= 1'b0;
                        out_pte      <= {satp_asid, mmu_rdata_page_ppn, mmu_rdata[9:0], stage_vaddr[38:12], 28'h0, 3'h0};
                    end
                end
            end
            OUT: begin
                tlb_page_wen        <= 1'b0;
                sram_1G_wen         <= 1'b1;
                sram_2M_wen         <= 1'b1;
                if(pte_valid & pte_ready)begin
                    stage_status    <= IDLE;
                end
            end
            default: begin
                stage_status        <= IDLE;
                stage_vaddr         <= 64'h0;
                out_error           <= 1'b0;
                out_pte             <= 128'h0;
                mmu_arvalid_reg     <= 1'b0;
                mmu_araddr_ppn      <= 44'h0;
                mmu_araddr_offset   <= 9'h0;
                tlb_page_wen        <= 1'b0;
                sram_1G_wen         <= 1'b1;
                sram_2M_wen         <= 1'b1;
            end
        endcase
    end
end
assign mmu_rdata_page_ppn      = mmu_rdata[53:10];
assign mmu_rdata_page_A        = mmu_rdata[6];
assign mmu_rdata_page_W        = mmu_rdata[2];
assign mmu_rdata_page_R        = mmu_rdata[1];
assign mmu_rdata_page_V        = mmu_rdata[0];
assign mmu_araddr_wire         = {8'h0, mmu_araddr_ppn, mmu_araddr_offset, 3'h0};
//**********************************************************************************************
//?output
assign sflush_vma_ready = 1'b1;
assign mmu_arvalid      = mmu_arvalid_reg;
assign mmu_araddr       = mmu_araddr_wire;
assign mmu_rready       = 1'b1;
assign immu_miss_ready  = (stage_status == IDLE);
assign dmmu_miss_ready  = (stage_status == IDLE) & (!immu_miss_valid);
assign pte_valid        = (stage_status == OUT);
assign pte              = out_pte;
assign pte_error        = out_error;
//**********************************************************************************************
//?function
function [127:0] tlb_page_sel;
    input [MMU_WAY-1:0] sel;
    input [127:0]        tlb_page_rdata[0:MMU_WAY-1];
    integer index;
    begin
        tlb_page_sel = 128'h0;
        for (index = 0; index < MMU_WAY; index = index + 1) begin
            if(sel[index] == 1'b1)begin
                tlb_page_sel = tlb_page_sel | tlb_page_rdata[index];
            end
        end
    end
endfunction

endmodule //l2tlb
