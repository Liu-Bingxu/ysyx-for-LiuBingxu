module icache#(parameter IMMU_WAY = 2, IMMU_GROUP = 1, ICACHE_WAY = 2, ICACHE_GROUP = 2)(
    input                   clk,
    input                   rst_n,
//interface with wbu 
    input  [1:0]            current_priv_status,
    input  [3:0]            satp_mode,
    input  [15:0]           satp_asid,
    input  [43:0]           satp_ppn,
//all flush flag 
    input                   flush_flag,
    input                   flush_i_valid,
    output                  flush_i_ready,
    input                   sflush_vma_valid,
    output                  sflush_vma_ready,
//interface with ifu
    //read addr channel
    output                  ifu_arready,
    input                   ifu_arvalid,
    input  [63:0]           ifu_araddr,
    //read data channel
    output                  ifu_rvalid,
    input                   ifu_rready,
    output [1:0]            ifu_rresp,
    output [31:0]           ifu_rdata,
//interface with dcache
    //read addr channel
    input                   immu_arready,
    output                  immu_arvalid,
    output                  immu_arlock,
    output [2:0]            immu_arsize,
    output [63:0]           immu_araddr,
    //read data channel
    output                  immu_rready,
    input                   immu_rvalid,
    input  [1:0]            immu_rresp,
    input  [63:0]           immu_rdata,
//interface with axi
    //read addr channel
    input                   icache_arready,
    output                  icache_arvalid,
    output [63:0]           icache_araddr,
    output [3:0]            icache_arid,
    output [7:0]            icache_arlen,
    output [2:0]            icache_arsize,
    output [1:0]            icache_arburst,
    //read data channel
    output                  icache_rready,
    input                   icache_rvalid,
    input  [1:0]            icache_rresp,
    input  [63:0]           icache_rdata,
    input                   icache_rlast,
    input  [3:0]            icache_rid
);

localparam ICACHE_TAG_GROUP = (ICACHE_GROUP % 2 == 0) ? ICACHE_GROUP / 2 : (ICACHE_GROUP / 2 + 1);
localparam ICACHE_GROUP_LEN = $clog2(ICACHE_GROUP);
localparam ICACHE_WAY_LEN   = $clog2(ICACHE_WAY);
localparam ICACHE_TAG_SIE   = 64 - 10 - ICACHE_GROUP_LEN;

//sram interface
wire [63:0]                 icache_line_valid[0:ICACHE_GROUP-1][0:ICACHE_WAY-1];
wire [127:0]                sram_tag_rdata[0:ICACHE_TAG_GROUP-1][0:ICACHE_WAY-1];
wire [63:0]                 sram_tag[0:ICACHE_GROUP-1][0:ICACHE_WAY-1];
wire                        sram_tag_cen[0:ICACHE_GROUP-1];
wire                        sram_tag_wen[0:ICACHE_GROUP-1][0:ICACHE_WAY-1];
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
reg                         paddr_ready;
wire [63:0]                 paddr;
wire                        paddr_error;

//icache fsm sign
localparam IDLE         = 3'b000;
localparam GET_DATA     = 3'b001;
localparam WAIT_IMMU    = 3'b011;
localparam WAIT_ARREADY = 3'b010;
localparam WAIT_RVALID  = 3'b110;
localparam WRITE_CACHE  = 3'b111;
reg  [2:0]                  icache_fsm;
reg  [127:0]                sram_tag_wdata;
reg  [127:0]                sram_data_wdata;
reg                         icache_line_wen;
reg  [63:0]                 icache_line_waddr;
reg                         data_cnt;

integer                     iter_index;
reg  [127:0]                sram_data_way_reg[0:ICACHE_WAY-1];
reg  [63:0]                 sram_tag_way_reg[0:ICACHE_WAY-1];
reg  [63:0]                 icache_line_valid_way_reg[0:ICACHE_WAY-1];

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
                assign sram_data_wen[icache_group_index][icache_way_index]          = (!icache_line_wen) | (!(icache_way_index == rand_way));
                assign sram_data_way[icache_way_index]                              = sram_data_rdata[icache_group_index][icache_way_index];
                assign sram_tag_way[icache_way_index]                               = sram_tag[icache_group_index][icache_way_index];
                assign icache_line_valid_way[icache_way_index]                      = icache_line_valid[icache_group_index][icache_way_index];
            end
            else begin
                assign sram_data_wen[icache_group_index][icache_way_index]          = (!icache_line_wen) | (!(icache_way_index == rand_way)) | 
                                                                                        (!(icache_group_index == icache_line_waddr[9 + ICACHE_GROUP_LEN:10]));
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
                    assign sram_tag_cen[icache_group_index/2]                       = sram_data_cen[icache_group_index]                     | sram_data_cen[icache_group_index+1];
                    assign sram_tag_wen[icache_group_index/2][icache_way_index]     = sram_data_wen[icache_group_index][icache_way_index]   | sram_data_wen[icache_group_index+1][icache_way_index];
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
            )u_tlb_valid(
                .clk        ( clk                                                       ),
                .rst_n      ( rst_n                                                     ),
                .syn_rst    ( flush_i_valid                                             ),
                .wen        ( !sram_data_wen[icache_group_index][icache_way_index]      ),
                .addr       ( sram_addr                                                 ),
                .data_in    ( 1'b1                                                      ),
                .data_out   ( icache_line_valid[icache_group_index][icache_way_index]   )
            );
            if(icache_group_index == 0)begin
                assign sram_way_sel[icache_way_index]                           = (sram_tag_way_reg[icache_way_index][63:64-ICACHE_TAG_SIE] == paddr[63:64-ICACHE_TAG_SIE]) & 
                                                                                    icache_line_valid_way_reg[icache_way_index][icache_line_waddr[9:4]]; 
            end
        end
        if(ICACHE_GROUP == 1)begin
            assign sram_data_cen[icache_group_index]                            = (!icache_line_wen) & (rch_fifo_empty);
        end
        else begin
            assign sram_data_cen[icache_group_index]                            = (!icache_line_wen) & ((rch_fifo_empty) | (!(icache_group_index == rch_fifo_rdata[9 + ICACHE_GROUP_LEN:10])));
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
assign sram_addr                = (icache_line_wen) ? icache_line_waddr[9:4] : rch_fifo_rdata[9:4];
if(ICACHE_GROUP == 1)begin
    assign sram_tag_bwen        = 128'h0;
end
else begin
    assign sram_tag_bwen        = (icache_line_waddr[10]) ? {{64{1'b0}}, {64{1'b1}}} : {{64{1'b1}}, {64{1'b0}}};
end
assign sram_data_sel            = icache_line_sel(sram_way_sel, sram_data_way_reg);
//**********************************************************************************************
ifu_fifo #(
    .DATA_LEN   	( 64  ),
    .AddR_Width 	( 2   ))
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
    .AddR_Width 	( 2   ))
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
    .AddR_Width 	( 2   ))
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
        // sram_tag_wdata      <= 128'h0;
        // sram_data_wdata     <= 128'h0;
        icache_line_wen     <= 1'b0;
        rch_fifo_ren        <= 1'b0;
        paddr_ready         <= 1'b0;
        // icache_line_waddr   <= 64'h0;
        // data_cnt            <= 1'b0;
    end
    else if(flush_flag)begin
        icache_fsm          <= IDLE;
        // sram_tag_wdata      <= 128'h0;
        // sram_data_wdata     <= 128'h0;
        icache_line_wen     <= 1'b0;
        rch_fifo_ren        <= 1'b0;
        paddr_ready         <= 1'b0;
        // icache_line_waddr   <= 64'h0;
        // data_cnt            <= 1'b0;
    end
    else begin
        case (icache_fsm)
            IDLE: begin
                if((out_fifo_cnt <= 3'h3) & (!rch_fifo_empty))begin
                    icache_fsm          <= GET_DATA;
                    icache_line_waddr   <= rch_fifo_rdata;
                    rch_fifo_ren        <= 1'b1;
                end
            end
            GET_DATA: begin
                icache_fsm                                  <= WAIT_IMMU;
                rch_fifo_ren                                <= 1'b0;
                for(iter_index = 0; iter_index < ICACHE_WAY; iter_index = iter_index + 1)begin
                    sram_data_way_reg[iter_index]           <=  sram_data_way[iter_index];
                    sram_tag_way_reg[iter_index]            <=  sram_tag_way[iter_index];
                    icache_line_valid_way_reg[iter_index]   <=  icache_line_valid_way[iter_index];
                end
            end
            WAIT_IMMU: begin
                if(paddr_valid)begin
                end
            end
            WAIT_ARREADY: begin
            end
            WAIT_RVALID: begin
            end
            WRITE_CACHE: begin
            end
            default: begin
            end
        endcase
    end
end

assign fifo_wen     = ifu_arvalid & ifu_arready;
assign fifo_wdata   = ifu_araddr;

immu #(
    .IMMU_WAY       ( IMMU_WAY      ), 
    .IMMU_GROUP     ( IMMU_GROUP    ))
u_immu(
    .clk                    ( clk                   ),
    .rst_n                  ( rst_n                 ),
    .current_priv_status    ( current_priv_status   ),
    .satp_mode              ( satp_mode             ),
    .satp_asid              ( satp_asid             ),
    .satp_ppn               ( satp_ppn              ),
    .flush_flag             ( flush_flag            ),
    .sflush_vma_valid       ( sflush_vma_valid      ),
    .sflush_vma_ready       ( sflush_vma_ready      ),
    .immu_arready           ( immu_arready          ),
    .immu_arvalid           ( immu_arvalid          ),
    .immu_arlock            ( immu_arlock           ),
    .immu_arsize            ( immu_arsize           ),
    .immu_araddr            ( immu_araddr           ),
    .immu_rready            ( immu_rready           ),
    .immu_rvalid            ( immu_rvalid           ),
    .immu_rresp             ( immu_rresp            ),
    .immu_rdata             ( immu_rdata            ),
    .mmu_fifo_valid         ( !mmu_fifo_empty       ),
    .mmu_fifo_ready         ( mmu_fifo_ren          ),
    .vaddr                  ( mmu_fifo_rdata        ),
    .paddr_valid            ( paddr_valid           ),
    .paddr_ready            ( paddr_ready           ),
    .paddr                  ( paddr                 ),
    .paddr_error            ( paddr_error           )
);

//**********************************************************************************************
//?out sign
assign flush_i_ready    = 1'b1;
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
