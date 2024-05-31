`include "./define.v"
module immu#(parameter IMMU_WAY = 2, IMMU_GROUP = 1)(
    input                   clk,
    input                   rst_n,
//interface with wbu 
    input  [1:0]            current_priv_status,
    input  [3:0]            satp_mode,
    input  [15:0]           satp_asid,
    input  [43:0]           satp_ppn,
//all flush flag 
    input                   flush_flag,
    input                   sflush_vma_valid,
    output                  sflush_vma_ready,
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
//interface with fifo
    input                   mmu_fifo_valid,
    output                  mmu_fifo_ready,
    input  [63:0]           vaddr,
//interface with icache
    output                  paddr_valid,
    input                   paddr_ready,
    output [63:0]           paddr,
    output                  paddr_error
);

localparam IMMU_TAG_SIZE    = 21 - $clog2(IMMU_GROUP);
localparam IMMU_GROUP_LEN   = $clog2(IMMU_GROUP);
localparam IMMU_WAY_LEN     = $clog2(IMMU_WAY);
localparam IMMU_TLB_FILL    = 42 - $clog2(IMMU_GROUP);

//sram interface
reg  [63:0]             tlb_page_valid[0:IMMU_GROUP-1][0:IMMU_WAY-1];
reg  [63:0]             tlb_page_valid_way[0:IMMU_WAY-1];
wire [127:0]            sram_rdata[0:IMMU_GROUP-1][0:IMMU_WAY-1];
wire                    sram_cen[0:IMMU_GROUP-1];
wire                    sram_wen[0:IMMU_GROUP-1][0:IMMU_WAY-1];
wire [5:0]              sram_addr;
reg  [127:0]            sram_wdata;
wire [127:0]            tlb_page;
wire [2:0]              tlb_page_size[0:IMMU_WAY-1];
wire [15:0]             tlb_page_asid[0:IMMU_WAY-1];
wire [43:0]             tlb_page_ppn               ;
wire [1:0]              tlb_page_attr[0:IMMU_WAY-1];
wire [IMMU_TAG_SIZE-1:0]tlb_page_tag [0:IMMU_WAY-1];
wire [127:0]            tlb_rdata[0:IMMU_WAY-1];
wire [IMMU_WAY-1:0]     tlb_hit_way_sel;
wire                    tlb_hit_flag;
wire [IMMU_WAY-1:0]     tlb_error_way_sel;
wire                    tlb_error_flag;
wire                    tlb_search_super_page_flag;
wire                    tlb_search_super_page_2M_flag;
reg                     tlb_search_super_page_2M_flag_reg;
wire                    tlb_search_super_page_1G_flag;
reg                     tlb_search_super_page_1G_flag_reg;
wire                    tlb_write_super_page_flag;
reg                     tlb_write_super_page_2M_flag;
reg                     tlb_write_super_page_1G_flag;
// reg                     tlb_page_cen;
reg                     tlb_page_wen;
wire [IMMU_WAY_LEN-1:0] rand_way;

//stage
localparam IDLE         = 3'h0;
localparam SEARCH_2M    = 3'h1;
localparam SEARCH_1G    = 3'h3;
localparam WAIT_ARREADY = 3'h2;
localparam WAIT_RVALID  = 3'h6;
localparam OUT          = 3'h4;
reg  [2:0]              stage_status;
reg  [2:0]              tlb_size_reg;
wire                    stage_valid;
wire [63:0]             stage_vaddr;
wire [20:0]             stage_vaddr_2M_tag;
wire [20:0]             stage_vaddr_1G_tag;
//跳过mmu阶段
wire                    stage_jump_mmu;

//axi interface
reg                     immu_arvalid_reg;
wire [63:0]             immu_araddr_wire;
reg  [43:0]             immu_araddr_ppn;
reg  [8:0]              immu_araddr_offset;
wire [43:0]             immu_rdata_page_ppn;
// wire                    immu_rdata_page_D;
wire                    immu_rdata_page_A;
wire                    immu_rdata_page_G;
wire                    immu_rdata_page_U;
wire                    immu_rdata_page_X;
wire                    immu_rdata_page_W;
wire                    immu_rdata_page_R;
wire                    immu_rdata_page_V;

//out fifo
wire                    fifo_wen;
wire                    fifo_ren;
wire [64:0]             fifo_wdata;
wire                	fifo_empty;
wire [64:0] 	        fifo_rdata;
wire [63:0]             fifo_paddr;
wire                    fifo_error;
reg                     fifo_error_reg;

//icache interface
// wire                    stage_ready;
reg  					mmu_fifo_ready_reg;
reg [2:0]				fifo_cnt;

//**********************************************************************************************
//?tlb
genvar tlb_group_index;
genvar tlb_way_index;
generate
    for(tlb_group_index = 0; tlb_group_index < IMMU_GROUP; tlb_group_index = tlb_group_index + 1)begin: tlb_group_sram
        for(tlb_way_index = 0; tlb_way_index < IMMU_WAY; tlb_way_index = tlb_way_index + 1)begin: tlb_way_sram
            S011HD1P_X32Y2D128_BW u_S011HD1P_X32Y2D128_BW(
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
            if(IMMU_GROUP == 1)begin
                assign sram_wen[tlb_group_index][tlb_way_index] = (!tlb_page_wen) | (!(tlb_way_index == rand_way));
                if(tlb_group_index == 0)begin
                    assign tlb_rdata[tlb_way_index]             = sram_rdata[tlb_group_index][tlb_way_index];
                    assign tlb_page_valid_way[tlb_way_index]    = tlb_page_valid[tlb_group_index][tlb_way_index];
                end 
            end
            else if(IMMU_GROUP >= 8192)begin
                assign sram_wen[tlb_group_index][tlb_way_index] = (tlb_write_super_page_1G_flag) ? ((!tlb_page_wen) | (!(tlb_way_index == rand_way)) | (!(tlb_group_index == {stage_vaddr[17 + IMMU_GROUP_LEN:30], 12'h0}))) : 
                                                    ((tlb_write_super_page_2M_flag) ? ((!tlb_page_wen) | (!(tlb_way_index == rand_way)) | (!(tlb_group_index == {stage_vaddr[17 + IMMU_GROUP_LEN:21], 3'h0}))) : 
                                                    ((!tlb_page_wen) | (!(tlb_way_index == rand_way)) | (!(tlb_group_index == stage_vaddr[17 + IMMU_GROUP_LEN:18]))));
                if(tlb_group_index == 0)begin
                    assign tlb_rdata[tlb_way_index]             = (tlb_search_super_page_1G_flag_reg) ? sram_rdata[{stage_vaddr[17 + IMMU_GROUP_LEN:30], 12'h0}][tlb_way_index] : 
                                                    ((tlb_search_super_page_2M_flag_reg) ? sram_rdata[{stage_vaddr[17 + IMMU_GROUP_LEN:21], 3'h0}][tlb_way_index] : 
                                                    sram_rdata[stage_vaddr[17 + IMMU_GROUP_LEN:18]][tlb_way_index]);
                    assign tlb_page_valid_way[tlb_way_index]    = (tlb_search_super_page_1G_flag_reg) ? tlb_page_valid[{stage_vaddr[17 + IMMU_GROUP_LEN:30], 12'h0}][tlb_way_index] : 
                                                    ((tlb_search_super_page_2M_flag_reg) ? tlb_page_valid[{stage_vaddr[17 + IMMU_GROUP_LEN:21], 3'h0}][tlb_way_index] : 
                                                    tlb_page_valid[stage_vaddr[17 + IMMU_GROUP_LEN:18]][tlb_way_index]);
                end 
            end
            else if(IMMU_GROUP >= 16)begin
                assign sram_wen[tlb_group_index][tlb_way_index] = (tlb_write_super_page_1G_flag) ? ((!tlb_page_wen) | (!(tlb_way_index == rand_way)) | (!(tlb_group_index == 0))) : 
                                                    ((tlb_write_super_page_2M_flag) ? ((!tlb_page_wen) | (!(tlb_way_index == rand_way)) | (!(tlb_group_index == {stage_vaddr[17 + IMMU_GROUP_LEN:21], 3'h0}))) : 
                                                    ((!tlb_page_wen) | (!(tlb_way_index == rand_way)) | (!(tlb_group_index == stage_vaddr[17 + IMMU_GROUP_LEN:18]))));
                if(tlb_group_index == 0)begin
                    assign tlb_rdata[tlb_way_index]             = (tlb_search_super_page_1G_flag_reg) ? sram_rdata[0][tlb_way_index] : 
                                                    ((tlb_search_super_page_2M_flag_reg) ? sram_rdata[{stage_vaddr[17 + IMMU_GROUP_LEN:21], 3'h0}][tlb_way_index] : 
                                                    sram_rdata[stage_vaddr[17 + IMMU_GROUP_LEN:18]][tlb_way_index]);
                    assign tlb_page_valid_way[tlb_way_index]    = (tlb_search_super_page_1G_flag_reg) ? tlb_page_valid[0][tlb_way_index] : 
                                                    ((tlb_search_super_page_2M_flag_reg) ? tlb_page_valid[{stage_vaddr[17 + IMMU_GROUP_LEN:21], 3'h0}][tlb_way_index] : 
                                                    tlb_page_valid[stage_vaddr[17 + IMMU_GROUP_LEN:18]][tlb_way_index]);
                end 
            end
            else begin
                assign sram_wen[tlb_group_index][tlb_way_index] = (tlb_write_super_page_flag) ? ((!tlb_page_wen) | (!(tlb_way_index == rand_way)) | (!(tlb_group_index == 0))) : 
                                                    ((!tlb_page_wen) | (!(tlb_way_index == rand_way)) | (!(tlb_group_index == stage_vaddr[17 + IMMU_GROUP_LEN:18])));
                if(tlb_group_index == 0)begin
                    assign tlb_rdata[tlb_way_index]             = (tlb_search_super_page_1G_flag_reg | tlb_search_super_page_2M_flag_reg) ? sram_rdata[0][tlb_way_index] : 
                                                    sram_rdata[stage_vaddr[17 + IMMU_GROUP_LEN:18]][tlb_way_index];
                    assign tlb_page_valid_way[tlb_way_index]    = (tlb_search_super_page_1G_flag_reg | tlb_search_super_page_2M_flag_reg) ? tlb_page_valid[0][tlb_way_index] : 
                                                    tlb_page_valid[stage_vaddr[17 + IMMU_GROUP_LEN:18]][tlb_way_index];
                end 
            end
            if(tlb_group_index == 0)begin
                assign tlb_page_size[tlb_way_index]                 = tlb_rdata[tlb_way_index][127:125];
                assign tlb_page_asid[tlb_way_index]                 = tlb_rdata[tlb_way_index][124:109];
                assign tlb_page_ppn                                 = tlb_page[108:65];
                assign tlb_page_attr[tlb_way_index]                 = tlb_rdata[tlb_way_index][64:63];
                assign tlb_page_tag [tlb_way_index]                 = tlb_rdata[tlb_way_index][62:63 - IMMU_TAG_SIZE];
                assign tlb_hit_way_sel[tlb_way_index]               = (!(tlb_search_super_page_1G_flag_reg & (tlb_page_size[tlb_way_index] < 3'h2))) & 
                                                                        (!(tlb_search_super_page_2M_flag_reg & (tlb_page_size[tlb_way_index] < 3'h1))) & 
                                                                        ((tlb_search_super_page_1G_flag_reg | tlb_search_super_page_2M_flag_reg) ? tlb_page_valid_way[tlb_way_index][0] : tlb_page_valid_way[tlb_way_index][stage_vaddr[17:12]]) & 
                                                                        ((tlb_page_asid[tlb_way_index] == satp_asid) | tlb_page_attr[tlb_way_index][1]) & (
                                                                            (tlb_search_super_page_1G_flag_reg & (tlb_page_tag [tlb_way_index] == stage_vaddr_1G_tag[20:21-IMMU_TAG_SIZE])) | 
                                                                            (tlb_search_super_page_2M_flag_reg & (tlb_page_tag [tlb_way_index] == stage_vaddr_2M_tag[20:21-IMMU_TAG_SIZE])) | 
                                                                            (tlb_page_tag [tlb_way_index] == stage_vaddr[38:39-IMMU_TAG_SIZE])
                                                                        );
                assign tlb_error_way_sel[tlb_way_index]             = tlb_hit_way_sel[tlb_way_index] & (current_priv_status[0] == tlb_page_attr[tlb_way_index][0]);
            end
        end
        if(IMMU_GROUP == 1)begin
            assign sram_cen[tlb_group_index]                     = (!tlb_search_super_page_flag) & (!tlb_page_wen) & (!mmu_fifo_valid);
        end
        else begin
            assign sram_cen[tlb_group_index]                     = (!tlb_search_super_page_flag) & (!tlb_page_wen) & ((!mmu_fifo_valid) | (!(tlb_group_index == vaddr[17 + IMMU_GROUP_LEN:18])));
        end
    end
endgenerate
rand_lfsr_8_bit #(
    .USING_LEN(IMMU_WAY_LEN)
)u_rand_lfsr_8_bit_get_rand_way_num(
    .clk   	( clk           ),
    .rst_n 	( rst_n         ),
    .out   	( rand_way      )
);
assign tlb_page                     = tlb_page_sel(tlb_hit_way_sel, tlb_rdata);
assign sram_addr                    = (tlb_search_super_page_flag | tlb_write_super_page_flag) ? 6'h0 : vaddr[17:12];
assign tlb_hit_flag                 = (|tlb_hit_way_sel) & ((stage_status == IDLE) | (stage_status == SEARCH_2M) | (stage_status == SEARCH_1G));
assign tlb_error_flag               = (|tlb_error_way_sel) & ((stage_status == IDLE) | (stage_status == SEARCH_2M) | (stage_status == SEARCH_1G));
assign tlb_search_super_page_flag   = tlb_search_super_page_2M_flag | tlb_search_super_page_1G_flag;
assign tlb_search_super_page_2M_flag= (!tlb_search_super_page_2M_flag_reg) & (!tlb_hit_flag) & stage_valid & (!stage_jump_mmu) & (!fifo_error);
assign tlb_search_super_page_1G_flag= (!tlb_search_super_page_1G_flag_reg) & (!tlb_hit_flag) & stage_valid & (!stage_jump_mmu) & (!fifo_error) & tlb_search_super_page_2M_flag_reg;
assign tlb_write_super_page_flag    = tlb_write_super_page_2M_flag | tlb_write_super_page_1G_flag;
assign stage_jump_mmu               = (current_priv_status == `PRV_M) | (satp_mode == 4'h0);
assign stage_vaddr_2M_tag           = {stage_vaddr[38:42-IMMU_TAG_SIZE], 3'h0};
assign stage_vaddr_1G_tag           = {stage_vaddr[38:51-IMMU_TAG_SIZE], 12'h0};
//**********************************************************************************************
FF_D_with_syn_rst #(
    .DATA_LEN 	( 1  ),
    .RST_DATA 	( 0  )
)u_stage_valid
(
    .clk      	( clk                                                               ),
    .rst_n    	( rst_n                                                             ),
    .syn_rst    ( flush_flag                                                        ),
    .wen        ( (fifo_wen) | (mmu_fifo_valid & mmu_fifo_ready)                    ),
    .data_in  	( ((stage_status == OUT) ? (!tlb_page_wen) : 1'b1) & mmu_fifo_valid ),
    .data_out 	( stage_valid                                                       )
);
FF_D_without_asyn_rst #(64)  u_stage_vaddr            (clk,mmu_fifo_valid & mmu_fifo_ready,vaddr,stage_vaddr);
ifu_fifo #(
    .DATA_LEN   	( 65  ),
    .AddR_Width 	( 2   )
)out_fifo(
    .clk    	( clk           ),
    .rst_n  	( rst_n         ),
    .Wready 	( fifo_wen      ),
    .Rready 	( fifo_ren      ),
    .flush  	( flush_flag    ),
    .wdata  	( fifo_wdata    ),
    .empty  	( fifo_empty    ),
    .rdata  	( fifo_rdata    )
);
always @(posedge clk or negedge rst_n) begin
	if(!rst_n)begin
		mmu_fifo_ready_reg <= 1'b1;
	end
	else if(flush_flag)begin
		mmu_fifo_ready_reg <= 1'b1;
	end
	else if(mmu_fifo_valid & mmu_fifo_ready & (fifo_cnt >= 3'h2))begin
		mmu_fifo_ready_reg <= 1'b0;
	end
	else if(fifo_cnt <= 3'h2)begin
		mmu_fifo_ready_reg <= 1'b1;
	end
end
always @(posedge clk or negedge rst_n) begin
	if(!rst_n)begin
		fifo_cnt			<= 3'h0;
	end
	else if(flush_flag)begin
		fifo_cnt			<= 3'h0;
	end
	else if(fifo_wen & fifo_ren)begin
		fifo_cnt			<= fifo_cnt;
	end
	else if(fifo_wen)begin
		fifo_cnt			<= fifo_cnt + 3'h1;
	end
	else if(fifo_ren)begin
		fifo_cnt			<= fifo_cnt + 3'h7;
	end
end
//!fsm
always @(posedge clk or negedge rst_n) begin
    if(!rst_n)begin
        stage_status                        <= IDLE;
        // tlb_size_reg                        <= 3'h2;
        // sram_wdata                  <= 128'h0;
        tlb_page_wen                        <= 1'b0;
        // immu_araddr_ppn             <= 44'h0;
        fifo_error_reg                      <= 1'b0;
        immu_arvalid_reg                    <= 1'b0;
        // immu_araddr_offset          <= 9'h0;
        tlb_search_super_page_2M_flag_reg   <= 1'b0;
        tlb_search_super_page_1G_flag_reg   <= 1'b0;
        tlb_write_super_page_2M_flag        <= 1'b0;
        tlb_write_super_page_1G_flag        <= 1'b0;
    end
    else if(flush_flag)begin
        stage_status                        <= IDLE;
        // tlb_size_reg                        <= 3'h2;
        // sram_wdata                  <= 128'h0;
        tlb_page_wen                        <= 1'b0;
        // immu_araddr_ppn             <= 44'h0;
        fifo_error_reg                      <= 1'b0;
        immu_arvalid_reg                    <= 1'b0;
        // immu_araddr_offset          <= 9'h0;
        tlb_search_super_page_2M_flag_reg   <= 1'b0;
        tlb_search_super_page_1G_flag_reg   <= 1'b0;
        tlb_write_super_page_2M_flag        <= 1'b0;
        tlb_write_super_page_1G_flag        <= 1'b0;
    end
    else begin
        case (stage_status)
            IDLE: begin
                if(tlb_search_super_page_2M_flag)begin
                    stage_status                        <= SEARCH_2M;
                    tlb_search_super_page_2M_flag_reg   <= 1'b1;
                end
            end
            SEARCH_2M: begin
                if(tlb_search_super_page_1G_flag)begin
                    stage_status                        <= SEARCH_1G;
                    tlb_search_super_page_1G_flag_reg   <= 1'b1;
                end
                else begin
                    stage_status                        <= IDLE;
                    tlb_search_super_page_2M_flag_reg   <= 1'b0;
                end
            end
            SEARCH_1G: begin
                if(tlb_search_super_page_1G_flag)begin
                    stage_status                        <= WAIT_ARREADY;
                    immu_arvalid_reg                    <= 1'b1;
                    tlb_size_reg                        <= 3'h2;
                    immu_araddr_ppn                     <= satp_ppn;
                    immu_araddr_offset                  <= stage_vaddr[38:30];
                end
                else begin
                    stage_status                        <= IDLE;
                    tlb_search_super_page_2M_flag_reg   <= 1'b0;
                    tlb_search_super_page_1G_flag_reg   <= 1'b0;
                end
            end
            WAIT_ARREADY: begin
                if(immu_arready)begin
                    stage_status                        <= WAIT_RVALID;
                    immu_arvalid_reg                    <= 1'b0;
                end
            end
            WAIT_RVALID: begin
                if(immu_rvalid)begin
                    if(immu_rresp != 2'h0)begin
                        stage_status                    <= OUT;
                        fifo_error_reg                  <= 1'b1;
                    end
                    else if(immu_rdata[63:54] != 10'h0)begin
                        stage_status                    <= OUT;
                        fifo_error_reg                  <= 1'b1;
                    end
                    else if(!immu_rdata_page_V)begin
                        stage_status                    <= OUT;
                        fifo_error_reg                  <= 1'b1;
                    end
                    else if(!immu_rdata_page_A)begin
                        stage_status                    <= OUT;
                        fifo_error_reg                  <= 1'b1;
                    end
                    else if(immu_rdata_page_W & (!immu_rdata_page_R))begin
                        stage_status                    <= OUT;
                        fifo_error_reg                  <= 1'b1;
                    end
                    else if(!(immu_rdata_page_X | immu_rdata_page_W | immu_rdata_page_R))begin
                        if(tlb_size_reg == 3'h0)begin
                            stage_status                <= OUT;
                            fifo_error_reg              <= 1'b1;
                        end
                        else begin
                            stage_status                <= WAIT_ARREADY;
                            immu_arvalid_reg            <= 1'b1;
                            tlb_size_reg                <= tlb_size_reg + 3'h7;
                            immu_araddr_ppn             <= immu_rdata_page_ppn;
                            if(tlb_size_reg == 3'h2)begin
                                immu_araddr_offset      <= stage_vaddr[29:21];
                            end
                            else if(tlb_size_reg == 3'h1)begin
                                immu_araddr_offset      <= stage_vaddr[20:12];
                            end
                        end
                    end
                    else if(immu_rdata_page_X)begin
                        if(current_priv_status[0] == immu_rdata_page_U)begin
                            stage_status                <= OUT;
                            fifo_error_reg              <= 1'b1;
                        end
                        else if((tlb_size_reg == 3'h2) & (immu_rdata_page_ppn[17:0] != 18'h0))begin
                            stage_status                <= OUT;
                            fifo_error_reg              <= 1'b1;
                        end
                        else if((tlb_size_reg == 3'h1) & (immu_rdata_page_ppn[8:0] != 9'h0))begin
                            stage_status                <= OUT;
                            fifo_error_reg              <= 1'b1;
                        end
                        else begin
                            //?get tlb
                            stage_status                        <= OUT;
                            tlb_page_wen                        <= 1'b1;
                            if(tlb_size_reg == 3'h2)begin
                                tlb_write_super_page_1G_flag    <= 1'b1;
                                sram_wdata                      <= {tlb_size_reg, satp_asid, immu_rdata_page_ppn, immu_rdata_page_G, immu_rdata_page_U, stage_vaddr_1G_tag[20:21-IMMU_TAG_SIZE], {IMMU_TLB_FILL{1'b0}}};
                            end
                            else if(tlb_size_reg == 3'h1)begin
                                tlb_write_super_page_2M_flag    <= 1'b1;
                                sram_wdata                      <= {tlb_size_reg, satp_asid, immu_rdata_page_ppn, immu_rdata_page_G, immu_rdata_page_U, stage_vaddr_2M_tag[20:21-IMMU_TAG_SIZE], {IMMU_TLB_FILL{1'b0}}};
                            end
                            else 
                                sram_wdata                      <= {tlb_size_reg, satp_asid, immu_rdata_page_ppn, immu_rdata_page_G, immu_rdata_page_U, stage_vaddr[38:39-IMMU_TAG_SIZE], {IMMU_TLB_FILL{1'b0}}};
                        end
                    end
                end
            end
            OUT: begin
                stage_status                            <= IDLE;
                tlb_page_wen                            <= 1'b0;
                fifo_error_reg                          <= 1'b0;
                tlb_search_super_page_2M_flag_reg       <= 1'b0;
                tlb_search_super_page_1G_flag_reg       <= 1'b0;
                tlb_write_super_page_1G_flag            <= 1'b0;
                tlb_write_super_page_2M_flag            <= 1'b0;
            end
            default: begin
                stage_status                        <= IDLE;
                tlb_page_wen                        <= 1'b0;
                fifo_error_reg                      <= 1'b0;
                immu_arvalid_reg                    <= 1'b0;
                tlb_search_super_page_2M_flag_reg   <= 1'b0;
                tlb_search_super_page_1G_flag_reg   <= 1'b0;
                tlb_write_super_page_2M_flag        <= 1'b0;
                tlb_write_super_page_1G_flag        <= 1'b0;
            end
        endcase
    end
end
assign immu_rdata_page_ppn      = immu_rdata[53:10];
// assign immu_rdata_page_D        = immu_rdata[7];
assign immu_rdata_page_A        = immu_rdata[6];
assign immu_rdata_page_G        = immu_rdata[5];
assign immu_rdata_page_U        = immu_rdata[4];
assign immu_rdata_page_X        = immu_rdata[3];
assign immu_rdata_page_W        = immu_rdata[2];
assign immu_rdata_page_R        = immu_rdata[1];
assign immu_rdata_page_V        = immu_rdata[0];
assign fifo_wen                 = stage_valid & (tlb_hit_flag | fifo_error | (stage_status == OUT) | stage_jump_mmu);
assign fifo_ren                 = paddr_valid & paddr_ready;
assign fifo_wdata               = {fifo_error, fifo_paddr};
assign fifo_error               = (!stage_jump_mmu) & (fifo_error_reg | ((stage_vaddr[63:38] != 26'h0) & (stage_vaddr[63:38]!= 26'h3ffffff)) | tlb_error_flag);
assign fifo_paddr               = (stage_jump_mmu) ? stage_vaddr : (
                                    ((stage_status == OUT) & (tlb_size_reg == 3'h2)) ? {8'h0, sram_wdata[108:83], stage_vaddr[29:0]} : (
                                        ((stage_status == OUT) & (tlb_size_reg == 3'h1)) ? {8'h0, sram_wdata[108:74], stage_vaddr[20:0]} : (
                                            ((stage_status == OUT) & (tlb_size_reg == 3'h0)) ? {8'h0, sram_wdata[108:65], stage_vaddr[11:0]} : (
                                                (stage_status == SEARCH_1G) ? {8'h0, tlb_page_ppn[43:18], stage_vaddr[29:0]} : (
                                                    (stage_status == SEARCH_2M) ? {8'h0, tlb_page_ppn[43:9], stage_vaddr[20:0]} : {8'h0, tlb_page_ppn, stage_vaddr[11:0]}
                                                )
                                            )
                                        )
                                    )
                                );
assign immu_araddr_wire         = {8'h0, immu_araddr_ppn, immu_araddr_offset, 3'h0};
//**********************************************************************************************
//?output
assign sflush_vma_ready = 1'b1;
assign immu_arvalid     = immu_arvalid_reg;
assign immu_arlock      = 1'b0;
assign immu_arsize      = 3'h3;
assign immu_araddr      = immu_araddr_wire;
assign immu_rready      = 1'b1;
assign mmu_fifo_ready   = mmu_fifo_ready_reg & (stage_jump_mmu | tlb_hit_flag | (!stage_valid));
assign paddr_valid      = (!fifo_empty);
assign paddr            = fifo_rdata[63:0];
assign paddr_error      = fifo_rdata[64];
//**********************************************************************************************
//?function
function [127:0] tlb_page_sel;
    input [IMMU_WAY-1:0] sel;
    input [127:0]        tlb_page_rdata[0:IMMU_WAY-1];
    integer index;
    begin
        tlb_page_sel = 128'h0;
        for (index = 0; index < IMMU_WAY; index = index + 1) begin
            if(sel[index] == 1'b1)begin
                tlb_page_sel = tlb_page_sel | tlb_page_rdata[index];
            end
        end
    end
endfunction

endmodule //immu
