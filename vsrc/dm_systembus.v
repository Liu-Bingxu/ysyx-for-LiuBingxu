module dm_systembus #(
    parameter ABITS = 7,
    parameter AXI_ID_SB = 3,

    // Address width in bits
    parameter AXI_ADDR_W = 64,
    // ID width in bits
    parameter AXI_ID_W = 8,
    // Data width in bits
    parameter AXI_DATA_W = 64
)(
    input                           dm_clk,
    input                           dm_rst_n,

    input                           dmactive,
    output [32            -1:0]     dm_sbcs,
    output [32            -1:0]     dm_sbaddress0,
    output [32            -1:0]     dm_sbaddress1,
    output [32            -1:0]     dm_sbaddress2,
    output [32            -1:0]     dm_sbaddress3,
    output [32            -1:0]     dm_sbdata0,
    output [32            -1:0]     dm_sbdata1,
    output [32            -1:0]     dm_sbdata2,
    output [32            -1:0]     dm_sbdata3,

    input                           dm_reg_wen,
    input                           dm_reg_ren,
    input  [ABITS         -1:0]     dm_reg_addr,
    input  [32            -1:0]     dm_reg_data,

    output                          slv_awvalid,
    input                           slv_awready,
    output [AXI_ADDR_W    -1:0]     slv_awaddr,
    output [8             -1:0]     slv_awlen,
    output [3             -1:0]     slv_awsize,
    output [2             -1:0]     slv_awburst,
    output                          slv_awlock,
    output [4             -1:0]     slv_awcache,
    output [3             -1:0]     slv_awprot,
    output [4             -1:0]     slv_awqos,
    output [4             -1:0]     slv_awregion,
    output [AXI_ID_W      -1:0]     slv_awid,
    output                          slv_wvalid,
    input                           slv_wready,
    output                          slv_wlast, 
    output [AXI_DATA_W    -1:0]     slv_wdata,
    output [AXI_DATA_W/8  -1:0]     slv_wstrb,
    input                           slv_bvalid,
    output                          slv_bready,
    input  [AXI_ID_W      -1:0]     slv_bid,
    input  [2             -1:0]     slv_bresp,
    output                          slv_arvalid,
    input                           slv_arready,
    output [AXI_ADDR_W    -1:0]     slv_araddr,
    output [8             -1:0]     slv_arlen,
    output [3             -1:0]     slv_arsize,
    output [2             -1:0]     slv_arburst,
    output                          slv_arlock,
    output [4             -1:0]     slv_arcache,
    output [3             -1:0]     slv_arprot,
    output [4             -1:0]     slv_arqos,
    output [4             -1:0]     slv_arregion,
    output [AXI_ID_W      -1:0]     slv_arid,
    input                           slv_rvalid,
    output                          slv_rready,
    input  [AXI_ID_W      -1:0]     slv_rid,
    input  [2             -1:0]     slv_rresp,
    input  [AXI_DATA_W    -1:0]     slv_rdata,
    input                           slv_rlast
);

localparam AXI_IDLE         = 3'h0;
localparam AXI_WAIT_AR      = 3'h1;
localparam AXI_WAIT_R       = 3'h2;
localparam AXI_WAIT_AW_W    = 3'h3;
localparam AXI_WAIT_AW      = 3'h4;
localparam AXI_WAIT_W       = 3'h5;
localparam AXI_WAIT_B       = 3'h6;

wire [31:0]                   dm_systembus_addr[AXI_ADDR_W/32 -1 : 0];
wire [31:0]                   dm_systembus_addr_w[AXI_ADDR_W/32 -1 : 0];
wire [31:0]                   dm_systembus_addr_increment[AXI_ADDR_W/32 -1 : 0];
wire                          dm_systembus_addr_wen[AXI_ADDR_W/32 -1 : 0];
wire                          dm_systembus_addr_dtm_wen[AXI_ADDR_W/32 -1 : 0];
wire                          dm_systembus_addr_increment_wen[AXI_ADDR_W/32 -1 : 0];
wire                          dm_systembus_addr_dtm_access[AXI_ADDR_W/32 -1 : 0];
wire [31:0]                   dm_systembus_data[AXI_DATA_W/32 -1 : 0];
wire [31:0]                   dm_systembus_data_w[AXI_DATA_W/32 -1 : 0];
wire [31:0]                   dm_systembus_data_axi_w[AXI_DATA_W/32 -1 : 0];
wire                          dm_systembus_data_wen[AXI_DATA_W/32 -1 : 0];
wire                          dm_systembus_data_dtm_wen[AXI_DATA_W/32 -1 : 0];
wire                          dm_systembus_data_axi_wen[AXI_DATA_W/32 -1 : 0];
wire                          dm_systembus_data_dtm_access[AXI_DATA_W/32 -1 : 0];
wire                          dm_systembus_data_dtm_ren[0 : 0];

wire [AXI_ADDR_W    -1:0]     slv_addr;
wire [AXI_DATA_W    -1:0]     slv_wdata_prev;
wire [AXI_DATA_W    -1:0]     slv_load_data;
reg                           slv_awvalid_reg;
reg                           slv_wvalid_reg;
reg                           slv_arvalid_reg;

reg  [2:0]                    systembus_axi_state;

reg                           sbbusyerror;
wire                          sbbusy;
wire                          sbreadonaddr;
wire [2:0]                    sbaccess;
wire                          sbautoincrement;
wire                          sbreadondata;
reg  [2:0]                    sberror;
wire                          sbaccess64;
wire                          dm_systembus_sbcs_wen;

wire [3:0] autoincrement_byte = {4{1'b0}}
                | ({4{sbaccess == 3'h0}} & 4'h1)
                | ({4{sbaccess == 3'h1}} & 4'h2)
                | ({4{sbaccess == 3'h2}} & 4'h4)
                | ({4{sbaccess == 3'h3}} & 4'h8) 
                ;

wire addr_misalign = 1'b0
                | ((sbaccess == 3'h0)                           )
                | ((sbaccess == 3'h1) & (slv_addr[0]   != 1'h0) )
                | ((sbaccess == 3'h2) & (slv_addr[1:0] != 2'h0) )
                | ((sbaccess == 3'h3) & (slv_addr[2:0] != 3'h0) ) 
                ;

wire addr_w_misalign = 1'b0
                | ((sbaccess == 3'h0)                               )
                | ((sbaccess == 3'h1) & (dm_reg_data[0]   != 1'h0)  )
                | ((sbaccess == 3'h2) & (dm_reg_data[1:0] != 2'h0)  )
                | ((sbaccess == 3'h3) & (dm_reg_data[2:0] != 3'h0)  ) 
                ;

wire access_support = 1'b0
                | ((sbaccess == 3'h0)              )
                | ((sbaccess == 3'h1)              )
                | ((sbaccess == 3'h2)              )
                | ((sbaccess == 3'h3) & sbaccess64 ) 
                ;

assign sbbusy = (systembus_axi_state != AXI_IDLE);

always @(posedge dm_clk or negedge dm_rst_n) begin
    if(!dm_rst_n)begin
        systembus_axi_state <= AXI_IDLE;
    end
    else begin
        case (systembus_axi_state)
            AXI_IDLE: begin
                if((!sbbusyerror) & (sberror == 3'h0) & dm_systembus_data_dtm_wen[0] & (!addr_misalign) & access_support)begin
                    systembus_axi_state <= AXI_WAIT_AW_W;
                end
                else if((!sbbusyerror) & (sberror == 3'h0) & dm_systembus_addr_dtm_wen[0] & (!addr_w_misalign) & access_support & sbreadonaddr)begin
                    systembus_axi_state <= AXI_WAIT_AR;
                end
                else if((!sbbusyerror) & (sberror == 3'h0) & dm_systembus_data_dtm_ren[0] & (!addr_misalign) & access_support & sbreadondata)begin
                    systembus_axi_state <= AXI_WAIT_AR;
                end
            end
            AXI_WAIT_AR: begin
                if(slv_arvalid & slv_arready)begin
                    systembus_axi_state <= AXI_WAIT_R;
                end
            end
            AXI_WAIT_R: begin
                if(slv_rvalid & slv_rready & slv_rlast & (slv_rid == AXI_ID_SB))begin
                    systembus_axi_state <= AXI_IDLE;
                end
            end
            AXI_WAIT_AW_W: begin
                if(slv_awvalid & slv_awready & slv_wvalid & slv_wready & slv_wlast)begin
                    systembus_axi_state <= AXI_WAIT_B;
                end
                else if(slv_wvalid & slv_wready & slv_wlast)begin
                    systembus_axi_state <= AXI_WAIT_AW;
                end
                else if(slv_awvalid & slv_awready)begin
                    systembus_axi_state <= AXI_WAIT_W;
                end
            end
            AXI_WAIT_AW: begin
                if(slv_awvalid & slv_awready)begin
                    systembus_axi_state <= AXI_WAIT_B;
                end
            end
            AXI_WAIT_W: begin
                if(slv_wvalid & slv_wready & slv_wlast)begin
                    systembus_axi_state <= AXI_WAIT_B;
                end
            end
            AXI_WAIT_B: begin
                if(slv_bvalid & slv_bready & (slv_bid == AXI_ID_SB))begin
                    systembus_axi_state <= AXI_IDLE;
                end
            end
            default: begin
                systembus_axi_state <= AXI_IDLE;
            end
        endcase
    end
end

always @(posedge dm_clk or negedge dm_rst_n) begin
    if(!dm_rst_n)begin
        slv_awvalid_reg <= 1'b0;
    end
    else if((systembus_axi_state == AXI_IDLE) & (!sbbusyerror) & (sberror == 3'h0) & dm_systembus_data_dtm_wen[0] & (!addr_misalign) & access_support)begin
        slv_awvalid_reg <= 1'b1;
    end
    else if(slv_awvalid & slv_awready)begin
        slv_awvalid_reg <= 1'b0;
    end
end

always @(posedge dm_clk or negedge dm_rst_n) begin
    if(!dm_rst_n)begin
        slv_wvalid_reg <= 1'b0;
    end
    else if((systembus_axi_state == AXI_IDLE) & (!sbbusyerror) & (sberror == 3'h0) & dm_systembus_data_dtm_wen[0] & (!addr_misalign) & access_support)begin
        slv_wvalid_reg <= 1'b1;
    end
    else if(slv_wvalid & slv_wready & slv_wlast)begin
        slv_wvalid_reg <= 1'b0;
    end
end

always @(posedge dm_clk or negedge dm_rst_n) begin
    if(!dm_rst_n)begin
        slv_arvalid_reg <= 1'b0;
    end
    else if((systembus_axi_state == AXI_IDLE) & (!sbbusyerror) & (sberror == 3'h0) & dm_systembus_addr_dtm_wen[0] & (!addr_w_misalign) & access_support & sbreadonaddr)begin
        slv_arvalid_reg <= 1'b1;
    end
    else if((systembus_axi_state == AXI_IDLE) & (!sbbusyerror) & (sberror == 3'h0) & dm_systembus_data_dtm_ren[0] & (!addr_misalign) & access_support & sbreadondata)begin
        slv_arvalid_reg <= 1'b1;
    end
    else if(slv_arvalid & slv_arready)begin
        slv_arvalid_reg <= 1'b0;
    end
end

generate 
    if(AXI_ADDR_W == 64) begin : gen_64bit_axi_addr
        assign slv_addr = {dm_systembus_addr[1], dm_systembus_addr[0]};
        assign {dm_systembus_addr_increment[1], dm_systembus_addr_increment[0]} = 
                                    ({dm_systembus_addr[1], dm_systembus_addr[0]} + {60'h0, autoincrement_byte});
    end
    else if(AXI_ADDR_W == 32) begin : gen_32bit_axi_addr
        assign slv_addr = dm_systembus_addr[0];
        assign dm_systembus_addr_increment[0] = (dm_systembus_addr[0] + {28'h0, autoincrement_byte});
    end
    else begin : gen_error_messge
        $error("addr width error");
    end
endgenerate

generate 
    if(AXI_DATA_W == 64) begin : gen_64bit_axi_data
        assign sbaccess64 = 1'b1;
        assign slv_wdata_prev = {dm_systembus_data[1], dm_systembus_data[0]};
        assign {dm_systembus_data_axi_w[1], dm_systembus_data_axi_w[0]} = slv_load_data;
        assign dm_systembus_data_axi_wen[1] = (systembus_axi_state == AXI_WAIT_R) & slv_rvalid & slv_rready & slv_rlast & (slv_rresp == 2'h0) & (slv_rid == AXI_ID_SB) & (sbaccess == 3'h3);
        assign slv_wstrb = {8{1'b0}}
                | ({8{(sbaccess == 3'h0) & (slv_addr[2:0] == 3'h0)}} & 8'h1  )
                | ({8{(sbaccess == 3'h0) & (slv_addr[2:0] == 3'h1)}} & 8'h2  )
                | ({8{(sbaccess == 3'h0) & (slv_addr[2:0] == 3'h2)}} & 8'h4  )
                | ({8{(sbaccess == 3'h0) & (slv_addr[2:0] == 3'h3)}} & 8'h8  ) 
                | ({8{(sbaccess == 3'h0) & (slv_addr[2:0] == 3'h4)}} & 8'h10 )
                | ({8{(sbaccess == 3'h0) & (slv_addr[2:0] == 3'h5)}} & 8'h20 )
                | ({8{(sbaccess == 3'h0) & (slv_addr[2:0] == 3'h6)}} & 8'h40 )
                | ({8{(sbaccess == 3'h0) & (slv_addr[2:0] == 3'h7)}} & 8'h80 ) 
                | ({8{(sbaccess == 3'h1) & (slv_addr[2:0] == 3'h0)}} & 8'h3  )
                | ({8{(sbaccess == 3'h1) & (slv_addr[2:0] == 3'h2)}} & 8'hC  )
                | ({8{(sbaccess == 3'h1) & (slv_addr[2:0] == 3'h4)}} & 8'h30 )
                | ({8{(sbaccess == 3'h1) & (slv_addr[2:0] == 3'h6)}} & 8'hC0 ) 
                | ({8{(sbaccess == 3'h2) & (slv_addr[2:0] == 3'h0)}} & 8'hf  )
                | ({8{(sbaccess == 3'h2) & (slv_addr[2:0] == 3'h4)}} & 8'hf0 ) 
                | ({8{(sbaccess == 3'h3) & (slv_addr[2:0] == 3'h0)}} & 8'hff )
                ;
    end
    else if(AXI_DATA_W == 32) begin : gen_32bit_axi_data
        assign sbaccess64 = 1'b0;
        assign slv_wdata_prev = dm_systembus_data[0];
        assign dm_systembus_data_axi_w[0] = slv_load_data;
        assign slv_wstrb = {4{1'b0}}
                | ({4{(sbaccess == 3'h0) & (slv_addr[1:0] == 2'h0)}} & 4'h1  )
                | ({4{(sbaccess == 3'h0) & (slv_addr[1:0] == 2'h1)}} & 4'h2  )
                | ({4{(sbaccess == 3'h0) & (slv_addr[1:0] == 2'h2)}} & 4'h4  )
                | ({4{(sbaccess == 3'h0) & (slv_addr[1:0] == 2'h3)}} & 4'h8  ) 
                | ({4{(sbaccess == 3'h1) & (slv_addr[1:0] == 2'h0)}} & 4'h3  )
                | ({4{(sbaccess == 3'h1) & (slv_addr[1:0] == 2'h2)}} & 4'hC  )
                | ({4{(sbaccess == 3'h2) & (slv_addr[1:0] == 2'h0)}} & 4'hf  )
                ;
    end
    else begin : gen_error_messge
        $error("addr width error");
    end
endgenerate
assign dm_systembus_data_axi_wen[0] = (systembus_axi_state == AXI_WAIT_R) & slv_rvalid & slv_rready & slv_rlast & (slv_rresp == 2'h0) & (slv_rid == AXI_ID_SB);

memory_load_move #(
    .DATA_WIDTH ( AXI_DATA_W    ),
    .HAS_SIGN   ( 0             )
)u_memory_load_move(
    .pre_data    	( slv_rdata                 ),
    .data_offset 	( slv_addr[AXI_DATA_W/32:0] ),
    .is_byte     	( sbaccess == 3'h0          ),
    .is_half     	( sbaccess == 3'h1          ),
    .is_word     	( sbaccess == 3'h2          ),
    .is_double   	( sbaccess == 3'h3          ),
    .is_sign     	( 1'b0                      ),
    .data        	( slv_load_data             )
);

memory_store_move #(
    .DATA_WIDTH ( AXI_DATA_W    )
)u_memory_store_move(
    .pre_data    	( slv_wdata_prev            ),
    .data_offset 	( slv_addr[AXI_DATA_W/32:0] ),
    .data        	( slv_wdata                 )
);

FF_D_with_syn_rst #(
    .DATA_LEN 	( 1   ),
    .RST_DATA 	( 0   ))
u_sbreadonaddr(
    .clk      	( dm_clk                    ),
    .rst_n    	( dm_rst_n                  ),
    .syn_rst  	( !dmactive                 ),
    .wen      	( dm_systembus_sbcs_wen     ),
    .data_in  	( dm_reg_data[20]           ),
    .data_out 	( sbreadonaddr              )
);

FF_D_with_syn_rst #(
    .DATA_LEN 	( 3   ),
    .RST_DATA 	( 2   ))
u_sbaccess(
    .clk      	( dm_clk                    ),
    .rst_n    	( dm_rst_n                  ),
    .syn_rst  	( !dmactive                 ),
    .wen      	( dm_systembus_sbcs_wen     ),
    .data_in  	( dm_reg_data[19:17]        ),
    .data_out 	( sbaccess                  )
);

FF_D_with_syn_rst #(
    .DATA_LEN 	( 1   ),
    .RST_DATA 	( 0   ))
u_sbautoincrement(
    .clk      	( dm_clk                    ),
    .rst_n    	( dm_rst_n                  ),
    .syn_rst  	( !dmactive                 ),
    .wen      	( dm_systembus_sbcs_wen     ),
    .data_in  	( dm_reg_data[16]           ),
    .data_out 	( sbautoincrement           )
);

FF_D_with_syn_rst #(
    .DATA_LEN 	( 1   ),
    .RST_DATA 	( 0   ))
u_sbreadondata(
    .clk      	( dm_clk                    ),
    .rst_n    	( dm_rst_n                  ),
    .syn_rst  	( !dmactive                 ),
    .wen      	( dm_systembus_sbcs_wen     ),
    .data_in  	( dm_reg_data[15]           ),
    .data_out 	( sbreadondata              )
);

always @(posedge dm_clk or negedge dm_rst_n) begin
    if(!dm_rst_n)begin
        sbbusyerror <= 1'b0;
    end
    else if(!dmactive)begin
        sbbusyerror <= 1'b0;
    end
    else if(dm_systembus_sbcs_wen & dm_reg_data[22])begin
        sbbusyerror <= 1'b0;
    end
    else if(sbbusy & ((|dm_systembus_addr_dtm_access) | (|dm_systembus_data_dtm_access)))begin
        sbbusyerror <= 1'b1;
    end
end

always @(posedge dm_clk or negedge dm_rst_n) begin
    if(!dm_rst_n)begin
        sberror <= 3'h0;
    end
    else if(!dmactive)begin
        sberror <= 3'h0;
    end
    else if(dm_systembus_sbcs_wen)begin
        sberror <= sberror & (~(dm_reg_data[14:12]));
    end
    else if((systembus_axi_state == AXI_IDLE) & (!sbbusyerror) & (sberror == 3'h0) & dm_systembus_data_dtm_wen[0] & (!access_support))begin
        sberror <= 3'h4; //! size error
    end
    else if((systembus_axi_state == AXI_IDLE) & (!sbbusyerror) & (sberror == 3'h0) & dm_systembus_data_dtm_wen[0] & addr_misalign & access_support)begin
        sberror <= 3'h3; //! align error
    end
    else if((systembus_axi_state == AXI_IDLE) & (!sbbusyerror) & (sberror == 3'h0) & dm_systembus_addr_dtm_wen[0] & (!access_support) & sbreadonaddr)begin
        sberror <= 3'h4; //! size error
    end
    else if((systembus_axi_state == AXI_IDLE) & (!sbbusyerror) & (sberror == 3'h0) & dm_systembus_addr_dtm_wen[0] & addr_w_misalign & access_support & sbreadonaddr)begin
        sberror <= 3'h3; //! align error
    end
    else if((systembus_axi_state == AXI_IDLE) & (!sbbusyerror) & (sberror == 3'h0) & dm_systembus_data_dtm_ren[0] & (!access_support) & sbreadondata)begin
        sberror <= 3'h4; //! size error
    end
    else if((systembus_axi_state == AXI_IDLE) & (!sbbusyerror) & (sberror == 3'h0) & dm_systembus_data_dtm_ren[0] & addr_misalign & sbreadondata)begin
        sberror <= 3'h3; //! align error
    end
    else if((systembus_axi_state == AXI_WAIT_B) & slv_bvalid & slv_bready & (slv_bresp != 2'h0) & (slv_bid == AXI_ID_SB))begin
        sberror <= 3'h2; //! addr error
    end
    else if((systembus_axi_state == AXI_WAIT_R) & slv_rvalid & slv_rready & slv_rlast & (slv_rresp != 2'h0) & (slv_rid == AXI_ID_SB))begin
        sberror <= 3'h2; //! addr error
    end
end

assign dm_systembus_sbcs_wen = (!sbbusy) & (dm_reg_addr == {{(ABITS - 6){1'b0}}, 6'h38}) & dm_reg_wen;

genvar addr_index;
generate for(addr_index = 0 ; addr_index < AXI_ADDR_W/32; addr_index = addr_index + 1) begin : gen_systembus_addr
    assign dm_systembus_addr_wen[addr_index]            = dm_systembus_addr_dtm_wen[addr_index] | dm_systembus_addr_increment_wen[addr_index];
    assign dm_systembus_addr_dtm_wen[addr_index]        = (!sbbusy) & (dm_reg_addr == ({{(ABITS - 6){1'b0}}, 6'h39} + addr_index)) & dm_reg_wen;
    assign dm_systembus_addr_dtm_access[addr_index]     = (dm_reg_addr == ({{(ABITS - 6){1'b0}}, 6'h39} + addr_index)) & dm_reg_wen;
    assign dm_systembus_addr_increment_wen[addr_index]  = sbautoincrement & (((systembus_axi_state == AXI_WAIT_B) & slv_bvalid & slv_bready & (slv_bresp == 2'h0) & (slv_bid == AXI_ID_SB))
                                                                    | ((systembus_axi_state == AXI_WAIT_R) & slv_rvalid & slv_rready & slv_rlast & (slv_rresp == 2'h0) & (slv_rid == AXI_ID_SB)));
    assign dm_systembus_addr_w[addr_index]              = (dm_systembus_addr_dtm_wen[addr_index]) ? dm_reg_data : dm_systembus_addr_increment[addr_index];
    FF_D_with_syn_rst #(
        .DATA_LEN 	( 32  ),
        .RST_DATA 	( 0   ))
    u_abstract_progbuf(
        .clk      	( dm_clk                                ),
        .rst_n    	( dm_rst_n                              ),
        .syn_rst  	( !dmactive                             ),
        .wen      	( dm_systembus_addr_wen[addr_index]     ),
        .data_in  	( dm_systembus_addr_w[addr_index]       ),
        .data_out 	( dm_systembus_addr[addr_index]         )
    );
end
endgenerate

genvar data_index;
generate for(data_index = 0 ; data_index < AXI_DATA_W/32; data_index = data_index + 1) begin : gen_systembus_data
    assign dm_systembus_data_wen[data_index]        = dm_systembus_data_dtm_wen[data_index] | dm_systembus_data_axi_wen[data_index];
    assign dm_systembus_data_dtm_wen[data_index]    = (!sbbusy) & (dm_reg_addr == {{(ABITS - 6){1'b0}}, 4'hf, data_index[1:0]}) & dm_reg_wen;
    assign dm_systembus_data_dtm_access[data_index] = (dm_reg_addr == {{(ABITS - 6){1'b0}}, 4'hf, data_index[1:0]}) & (dm_reg_wen | dm_reg_ren);
    assign dm_systembus_data_w[data_index]          = (dm_systembus_data_dtm_wen[data_index]) ? dm_reg_data : dm_systembus_data_axi_w[data_index];
    FF_D_with_syn_rst #(
        .DATA_LEN 	( 32  ),
        .RST_DATA 	( 0   ))
    u_abstract_data(
        .clk      	( dm_clk                            ),
        .rst_n    	( dm_rst_n                          ),
        .syn_rst  	( !dmactive                         ),
        .wen      	( dm_systembus_data_wen[data_index] ),
        .data_in  	( dm_systembus_data_w[data_index]   ),
        .data_out 	( dm_systembus_data[data_index]     )
    );
end
endgenerate
assign dm_systembus_data_dtm_ren[0] = (dm_reg_addr == {{(ABITS - 6){1'b0}}, 6'h3C}) & dm_reg_ren;

assign dm_sbcs = {3'h1, 6'h0, sbbusyerror, sbbusy, sbreadonaddr, sbaccess, sbautoincrement, 
                    sbreadondata, sberror, AXI_ADDR_W[6:0], 1'b0, sbaccess64, 1'b1, 1'b1, 1'b1};

generate 
    if(AXI_ADDR_W == 64) begin : gen_64bit_sbaddr
        assign dm_sbaddress0 = dm_systembus_addr[0];
        assign dm_sbaddress1 = dm_systembus_addr[1];
    end
    else if(AXI_ADDR_W == 32) begin : gen_32bit_sbaddr
        assign dm_sbaddress0 = dm_systembus_addr[0];
        assign dm_sbaddress1 = 32'h0;
    end
    else begin : gen_error_messge
        $error("addr width error");
    end
endgenerate

generate 
    if(AXI_DATA_W == 64) begin : gen_64bit_sbdata
        assign dm_sbdata0 = dm_systembus_data[0];
        assign dm_sbdata1 = dm_systembus_data[1];
    end
    else if(AXI_DATA_W == 32) begin : gen_32bit_sbdata
        assign dm_sbdata0 = dm_systembus_data[0];
        assign dm_sbdata1 = 32'h0;
    end
    else begin : gen_error_messge
        $error("data width error");
    end
endgenerate

assign dm_sbaddress2 = 32'h0;
assign dm_sbaddress3 = 32'h0;
assign dm_sbdata2 = 32'h0;
assign dm_sbdata3 = 32'h0;

assign slv_awvalid  = slv_awvalid_reg;
assign slv_awaddr   = slv_addr;
assign slv_awlen    = 8'h0;
assign slv_awsize   = sbaccess;
assign slv_awburst  = 2'h1;
assign slv_awlock   = 1'b0;
assign slv_awcache  = 4'h0;
assign slv_awprot   = 3'h0;
assign slv_awqos    = 4'h0;
assign slv_awregion = 4'h0;
assign slv_awid     = AXI_ID_SB;
assign slv_wvalid   = slv_wvalid_reg;
assign slv_wlast    = 1'b1;
assign slv_bready   = 1'b1;
assign slv_arvalid  = slv_arvalid_reg;
assign slv_araddr   = slv_addr;
assign slv_arlen    = 8'h0;
assign slv_arsize   = sbaccess;
assign slv_arburst  = 2'h1;
assign slv_arlock   = 1'b0;
assign slv_arcache  = 4'h0;
assign slv_arprot   = 3'h0;
assign slv_arqos    = 4'h0;
assign slv_arregion = 4'h0;
assign slv_arid     = AXI_ID_SB;
assign slv_rready   = 1'b1;

endmodule //dm_systembus
