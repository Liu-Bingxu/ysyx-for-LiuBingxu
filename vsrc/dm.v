`include "define.v"
module dm#(
    parameter ABITS = 7,
    parameter READ_THROUGH  = "TRUE",
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

    input                           dm_core_rst_n,

    output                          halt_req,
    output                          hartreset,
    output                          ndmreset,

    input                           dm2dtm_full,
    output                          dm2dtm_wen,
    output [ ABITS + 33 : 0 ]       dm2dtm_data_in,

    input                           dtm2dm_empty,
    output                          dtm2dm_ren,
    input  [ ABITS + 33 : 0 ]       dtm2dm_data_out,

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
    input                           slv_rlast,

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

localparam impebreak = 1'b0;

localparam IDLE      = 2'h0;
localparam TEMP      = 2'h1;
localparam WRITE     = 2'h2;
localparam READ      = 2'h3;

wire                            dmactive;
wire                            dmactive_data_in;
wire                            dmcontrol_wen;

wire                            dm_havereset;
wire                            dm_havereset_data_in;

wire [32            -1:0]       dm_control;
wire [32            -1:0]       dm_status;

wire                            dm_reg_wen;
wire                            dm_reg_ren;
wire  [ABITS         -1:0]      dm_reg_addr;
wire  [32            -1:0]      dm_reg_data;
wire  [2             -1:0]      dm_reg_op;

wire                            dm_sel_dmcontrol;
wire                            dm_sel_dmstatus;
wire                            dm_sel_dmhartinfo;
wire                            dm_sel_dmabstractcs;
wire                            dm_sel_dmcommand;
wire                            dm_sel_dmabstractauto;
wire                            dm_sel_dmdata;
wire                            dm_sel_dmprogbuf;
wire                            dm_sel_dmsbcs;
wire                            dm_sel_dmsbaddress0;
wire                            dm_sel_dmsbaddress1;
wire                            dm_sel_dmsbaddress2;
wire                            dm_sel_dmsbaddress3;
wire                            dm_sel_dmsbdata0;
wire                            dm_sel_dmsbdata1;
wire                            dm_sel_dmsbdata2;
wire                            dm_sel_dmsbdata3;
wire                            dm_success_read;
wire                            dm_success_write;
wire  [32            -1:0]      dm_reg_data_out;
wire  [ABITS        +33:0]      dm2dtm_read_data_out;
wire  [ABITS        +33:0]      dm2dtm_write_data_out;
wire  [ABITS        +33:0]      dm2dtm_data_in_temp;

reg   [2             -1:0]      dm_trans_state;
reg                             dtm2dm_ren_reg;

// dm_abstract outports wire
wire                    	    allresumeack;
wire                    	    anyresumeack;
wire                    	    allhalt;
wire                    	    anyhalt;
wire [32            -1:0]       dm_hartinfo;
wire [32            -1:0]       dm_abstractcs;
wire [32            -1:0]       dm_command;
wire [32            -1:0]       dm_abstractauto;
wire [32            -1:0]       dm_data;
wire [32            -1:0]       dm_progbuf;

// dm_systembus outports wire
wire [32            -1:0]       dm_sbcs;
wire [32            -1:0]       dm_sbaddress0;
wire [32            -1:0]       dm_sbaddress1;
wire [32            -1:0]       dm_sbaddress2;
wire [32            -1:0]       dm_sbaddress3;
wire [32            -1:0]       dm_sbdata0;
wire [32            -1:0]       dm_sbdata1;
wire [32            -1:0]       dm_sbdata2;
wire [32            -1:0]       dm_sbdata3;

FF_D_with_syn_rst #(
    .DATA_LEN 	( 1    ),
    .RST_DATA 	( 0    ))
u_halt_req(
    .clk      	( dm_clk                            ),
    .rst_n    	( dm_rst_n                          ),
    .syn_rst  	( dmcontrol_wen & dm_reg_data[0]    ),
    .wen      	( dmcontrol_wen                     ),
    .data_in  	( dm_reg_data[31]                   ),
    .data_out 	( halt_req                          )
);

FF_D_with_syn_rst #(
    .DATA_LEN 	( 1    ),
    .RST_DATA 	( 0    ))
u_hartreset(
    .clk      	( dm_clk                            ),
    .rst_n    	( dm_rst_n                          ),
    .syn_rst  	( dmcontrol_wen & dm_reg_data[0]    ),
    .wen      	( dmcontrol_wen                     ),
    .data_in  	( dm_reg_data[29]                   ),
    .data_out 	( hartreset                         )
);

FF_D_with_syn_rst #(
    .DATA_LEN 	( 1    ),
    .RST_DATA 	( 0    ))
u_ndmreset(
    .clk      	( dm_clk                            ),
    .rst_n    	( dm_rst_n                          ),
    .syn_rst  	( dmcontrol_wen & dm_reg_data[0]    ),
    .wen      	( dmcontrol_wen                     ),
    .data_in  	( dm_reg_data[1]                    ),
    .data_out 	( ndmreset                          )
);

FF_D_without_wen #(
    .DATA_LEN 	( 1    ),
    .RST_DATA 	( 0    ))
u_dmactive(
    .clk      	( dm_clk            ),
    .rst_n    	( dm_rst_n          ),
    .data_in  	( dmactive_data_in  ),
    .data_out 	( dmactive          )
);

assign dmcontrol_wen    = ((dm_reg_addr == {{(ABITS - 5){1'b0}}, 5'h10}) & dm_reg_wen);
assign dmactive_data_in = (dmcontrol_wen) ? dm_reg_data[0] : dmactive;

FF_D_without_wen #(
    .DATA_LEN 	( 1    ),
    .RST_DATA 	( 1    ))
u_havereset(
    .clk      	( dm_clk                ),
    .rst_n    	( dm_core_rst_n         ),
    .data_in  	( dm_havereset_data_in  ),
    .data_out 	( dm_havereset          )
);

assign dm_havereset_data_in = (dmcontrol_wen & dm_reg_data[28] & dm_reg_data[0]) ? 1'b0 : dm_havereset;

assign dm_control    = {halt_req, 1'b0, hartreset, 1'b0, 1'b0, 1'b0, 10'h0, 10'h0, 1'b0, 1'b0, 1'b0, 1'b0, ndmreset, dmactive};
assign dm_status     = {7'h0, ndmreset, 1'b0, impebreak, 2'h0, dm_havereset, dm_havereset, allresumeack, anyresumeack, 2'h0, 2'h0,
                        (!anyhalt), (!allhalt), allhalt, anyhalt, 1'b1, 1'b0, 1'b0, 1'b0, 4'h2};

generate 
    if(READ_THROUGH == "TRUE") begin : read_through
        reg [ABITS + 33 : 0] trans_data_reg;
        always @(posedge dm_clk) begin
            if(!dtm2dm_empty)begin
                trans_data_reg      <= dtm2dm_data_out;
            end
        end
        assign dm_reg_addr = trans_data_reg[ABITS + 33:34];
        assign dm_reg_data = trans_data_reg[33:2];
        assign dm_reg_op   = trans_data_reg[1:0];
    end
    else begin : read_tick
        assign dm_reg_addr = dtm2dm_data_out[ABITS + 33:34];
        assign dm_reg_data = dtm2dm_data_out[33:2];
        assign dm_reg_op   = dtm2dm_data_out[1:0];
    end
endgenerate


assign dm_sel_dmcontrol         = (dm_reg_addr == {{(ABITS - 5){1'b0}}, 5'h10});
assign dm_sel_dmstatus          = (dm_reg_addr == {{(ABITS - 5){1'b0}}, 5'h11});
assign dm_sel_dmhartinfo        = (dm_reg_addr == {{(ABITS - 5){1'b0}}, 5'h12});
assign dm_sel_dmabstractcs      = (dm_reg_addr == {{(ABITS - 5){1'b0}}, 5'h16});
assign dm_sel_dmcommand         = (dm_reg_addr == {{(ABITS - 5){1'b0}}, 5'h17});
assign dm_sel_dmabstractauto    = (dm_reg_addr == {{(ABITS - 5){1'b0}}, 5'h18});
assign dm_sel_dmdata            = (dm_reg_addr[ABITS - 1:4] == {{(ABITS - 4){1'b0}}} & (dm_reg_addr[3:2] != 2'h0));
assign dm_sel_dmprogbuf         = (dm_reg_addr[ABITS - 1:4] == {{(ABITS - 6){1'b0}}, 2'h2});
assign dm_sel_dmsbcs            = (dm_reg_addr == {{(ABITS - 6){1'b0}}, 6'h38});
assign dm_sel_dmsbaddress0      = (dm_reg_addr == {{(ABITS - 6){1'b0}}, 6'h39});
assign dm_sel_dmsbaddress1      = (dm_reg_addr == {{(ABITS - 6){1'b0}}, 6'h3a});
assign dm_sel_dmsbaddress2      = (dm_reg_addr == {{(ABITS - 6){1'b0}}, 6'h3b});
assign dm_sel_dmsbaddress3      = (dm_reg_addr == {{(ABITS - 6){1'b0}}, 6'h37});
assign dm_sel_dmsbdata0         = (dm_reg_addr == {{(ABITS - 6){1'b0}}, 6'h3c});
assign dm_sel_dmsbdata1         = (dm_reg_addr == {{(ABITS - 6){1'b0}}, 6'h3d});
assign dm_sel_dmsbdata2         = (dm_reg_addr == {{(ABITS - 6){1'b0}}, 6'h3e});
assign dm_sel_dmsbdata3         = (dm_reg_addr == {{(ABITS - 6){1'b0}}, 6'h3f});
assign dm_success_read          = dm_sel_dmcontrol | dm_sel_dmstatus | dm_sel_dmhartinfo | dm_sel_dmabstractcs | dm_sel_dmcommand
                                    | dm_sel_dmabstractauto | dm_sel_dmdata | dm_sel_dmprogbuf | dm_sel_dmsbcs | dm_sel_dmsbaddress0
                                    | dm_sel_dmsbaddress1 | dm_sel_dmsbaddress2 | dm_sel_dmsbaddress3 | dm_sel_dmsbdata0 | dm_sel_dmsbdata1
                                    | dm_sel_dmsbdata2 | dm_sel_dmsbdata3;
assign dm_success_write         = dm_sel_dmcontrol | dm_sel_dmabstractcs | dm_sel_dmcommand| dm_sel_dmabstractauto | dm_sel_dmdata 
                                    | dm_sel_dmprogbuf | dm_sel_dmsbcs | dm_sel_dmsbaddress0| dm_sel_dmsbaddress1 | dm_sel_dmsbaddress2 
                                    | dm_sel_dmsbaddress3 | dm_sel_dmsbdata0 | dm_sel_dmsbdata1| dm_sel_dmsbdata2 | dm_sel_dmsbdata3;
assign dm_reg_data_out          = {32{1'b0}}
                | ({32{dm_sel_dmcontrol         }} & dm_control         )
                | ({32{dm_sel_dmstatus          }} & dm_status          )
                | ({32{dm_sel_dmhartinfo        }} & dm_hartinfo        )
                | ({32{dm_sel_dmabstractcs      }} & dm_abstractcs      ) 
                | ({32{dm_sel_dmcommand         }} & dm_command         )
                | ({32{dm_sel_dmabstractauto    }} & dm_abstractauto    )
                | ({32{dm_sel_dmdata            }} & dm_data            )
                | ({32{dm_sel_dmprogbuf         }} & dm_progbuf         ) 
                | ({32{dm_sel_dmsbcs            }} & dm_sbcs            )
                | ({32{dm_sel_dmsbaddress0      }} & dm_sbaddress0      )
                | ({32{dm_sel_dmsbaddress1      }} & dm_sbaddress1      )
                | ({32{dm_sel_dmsbaddress2      }} & dm_sbaddress2      ) 
                | ({32{dm_sel_dmsbaddress3      }} & dm_sbaddress3      ) 
                | ({32{dm_sel_dmsbdata0         }} & dm_sbdata0         )
                | ({32{dm_sel_dmsbdata1         }} & dm_sbdata1         )
                | ({32{dm_sel_dmsbdata2         }} & dm_sbdata2         )
                | ({32{dm_sel_dmsbdata3         }} & dm_sbdata3         )
                ;

assign dm2dtm_read_data_out     = (dm_success_read ) ? {dm_reg_addr, dm_reg_data_out, 2'h0} : {dm_reg_addr, dm_reg_data_out, 2'h2};
assign dm2dtm_write_data_out    = (dm_success_write) ? {dm_reg_addr, dm_reg_data, 2'h0} : {dm_reg_addr, dm_reg_data, 2'h2};

always @(posedge dm_clk or negedge dm_rst_n) begin
    if(!dm_rst_n)begin
        dm_trans_state <= IDLE;
    end
    else begin
        case (dm_trans_state)
            IDLE: begin
                if(dtm2dm_ren_reg == 1'b1)begin
                    dm_trans_state      <= TEMP;
                end
            end
            TEMP: begin
                case (dm_reg_op)
                    2'h1: begin
                        dm_trans_state <= READ;
                    end
                    2'h2: begin
                        dm_trans_state <= WRITE;
                    end
                    default: begin
                        dm_trans_state <= IDLE;
                    end
                endcase
            end
            WRITE: begin
                dm_trans_state <= IDLE;
            end
            READ: begin
                dm_trans_state <= IDLE;
            end
            default: begin
                dm_trans_state <= IDLE;
            end
        endcase
    end
end

assign dm_reg_wen = dm_trans_state == WRITE;
assign dm_reg_ren = dm_trans_state == READ;

assign dm2dtm_data_in_temp = {(ABITS + 34){1'b0}}
                | ({(ABITS + 34){dm_reg_wen   }} & dm2dtm_write_data_out)
                | ({(ABITS + 34){dm_reg_ren   }} & dm2dtm_read_data_out );

wire dm2dtm_wen_in = (dm2dtm_wen) ? 1'b0 : ((dm_trans_state == WRITE) | (dm_trans_state == READ) | ((dm_trans_state == TEMP) & ((dm_reg_op == 2'h0) | (dm_reg_op == 2'h3))));
FF_D_without_wen #(
    .DATA_LEN 	( 1   ),
    .RST_DATA 	( 0   ))
u_dm2dtm_wen(
    .clk      	( dm_clk        ),
    .rst_n    	( dm_rst_n      ),
    .data_in  	( dm2dtm_wen_in ),
    .data_out 	( dm2dtm_wen    )
);

wire [ ABITS + 33 : 0 ] dm2dtm_data = ((dm_trans_state == WRITE) | (dm_trans_state == READ) | ((dm_trans_state == TEMP) & ((dm_reg_op == 2'h0) | (dm_reg_op == 2'h3)))) ? dm2dtm_data_in_temp : dm2dtm_data_in;
FF_D_without_wen #(
    .DATA_LEN 	( ABITS + 34   ),
    .RST_DATA 	( 0            ))
u_dm2dtm_data_in(
    .clk      	( dm_clk            ),
    .rst_n    	( dm_rst_n          ),
    .data_in  	( dm2dtm_data       ),
    .data_out 	( dm2dtm_data_in    )
);

always @(posedge dm_clk or negedge dm_rst_n) begin
    if(!dm_rst_n)begin
        dtm2dm_ren_reg      <= 1'b0;
    end
    else if(dtm2dm_ren_reg)begin
        dtm2dm_ren_reg      <= 1'b0;
    end
    else if(!dtm2dm_empty)begin
        dtm2dm_ren_reg      <= 1'b1;
    end
end

assign dtm2dm_ren = dtm2dm_ren_reg;

dm_abstract #(
    .ABITS      	( ABITS         ),
    .AXI_ADDR_W 	( AXI_ADDR_W    ),
    .AXI_ID_W   	( AXI_ID_W      ),
    .AXI_DATA_W 	( AXI_DATA_W    ))
u_dm_abstract(
    .dm_clk          	( dm_clk           ),
    .dm_rst_n        	( dm_rst_n         ),
    .dmactive        	( dmactive         ),
    .allresumeack    	( allresumeack     ),
    .anyresumeack    	( anyresumeack     ),
    .allhalt         	( allhalt          ),
    .anyhalt         	( anyhalt          ),
    .dm_hartinfo        ( dm_hartinfo      ),
    .dm_abstractcs   	( dm_abstractcs    ),
    .dm_command      	( dm_command       ),
    .dm_abstractauto 	( dm_abstractauto  ),
    .dm_data         	( dm_data          ),
    .dm_progbuf      	( dm_progbuf       ),
    .dm_reg_wen      	( dm_reg_wen       ),
    .dm_reg_ren      	( dm_reg_ren       ),
    .dm_reg_addr     	( dm_reg_addr      ),
    .dm_reg_data     	( dm_reg_data      ),
    .mst_awvalid     	( mst_awvalid      ),
    .mst_awready     	( mst_awready      ),
    .mst_awaddr      	( mst_awaddr       ),
    .mst_awlen       	( mst_awlen        ),
    .mst_awsize      	( mst_awsize       ),
    .mst_awburst     	( mst_awburst      ),
    .mst_awlock      	( mst_awlock       ),
    .mst_awcache     	( mst_awcache      ),
    .mst_awprot      	( mst_awprot       ),
    .mst_awqos       	( mst_awqos        ),
    .mst_awregion    	( mst_awregion     ),
    .mst_awid        	( mst_awid         ),
    .mst_wvalid      	( mst_wvalid       ),
    .mst_wready      	( mst_wready       ),
    .mst_wlast       	( mst_wlast        ),
    .mst_wdata       	( mst_wdata        ),
    .mst_wstrb       	( mst_wstrb        ),
    .mst_bvalid      	( mst_bvalid       ),
    .mst_bready      	( mst_bready       ),
    .mst_bid         	( mst_bid          ),
    .mst_bresp       	( mst_bresp        ),
    .mst_arvalid     	( mst_arvalid      ),
    .mst_arready     	( mst_arready      ),
    .mst_araddr      	( mst_araddr       ),
    .mst_arlen       	( mst_arlen        ),
    .mst_arsize      	( mst_arsize       ),
    .mst_arburst     	( mst_arburst      ),
    .mst_arlock      	( mst_arlock       ),
    .mst_arcache     	( mst_arcache      ),
    .mst_arprot      	( mst_arprot       ),
    .mst_arqos       	( mst_arqos        ),
    .mst_arregion    	( mst_arregion     ),
    .mst_arid        	( mst_arid         ),
    .mst_rvalid      	( mst_rvalid       ),
    .mst_rready      	( mst_rready       ),
    .mst_rid         	( mst_rid          ),
    .mst_rresp       	( mst_rresp        ),
    .mst_rdata       	( mst_rdata        ),
    .mst_rlast       	( mst_rlast        )
);

dm_systembus #(
    .ABITS      	( ABITS         ),
    .AXI_ID_SB      ( AXI_ID_SB     ),
    .AXI_ADDR_W 	( AXI_ADDR_W    ),
    .AXI_ID_W   	( AXI_ID_W      ),
    .AXI_DATA_W 	( AXI_DATA_W    ))
u_dm_systembus(
    .dm_clk          	( dm_clk           ),
    .dm_rst_n        	( dm_rst_n         ),
    .dmactive        	( dmactive         ),
    .dm_sbcs    	    ( dm_sbcs          ),
    .dm_sbaddress0    	( dm_sbaddress0    ),
    .dm_sbaddress1      ( dm_sbaddress1    ),
    .dm_sbaddress2      ( dm_sbaddress2    ),
    .dm_sbaddress3      ( dm_sbaddress3    ),
    .dm_sbdata0   	    ( dm_sbdata0       ),
    .dm_sbdata1      	( dm_sbdata1       ),
    .dm_sbdata2 	    ( dm_sbdata2       ),
    .dm_sbdata3         ( dm_sbdata3       ),
    .dm_reg_wen      	( dm_reg_wen       ),
    .dm_reg_ren      	( dm_reg_ren       ),
    .dm_reg_addr     	( dm_reg_addr      ),
    .dm_reg_data     	( dm_reg_data      ),
    .slv_awvalid     	( slv_awvalid      ),
    .slv_awready     	( slv_awready      ),
    .slv_awaddr      	( slv_awaddr       ),
    .slv_awlen       	( slv_awlen        ),
    .slv_awsize      	( slv_awsize       ),
    .slv_awburst     	( slv_awburst      ),
    .slv_awlock      	( slv_awlock       ),
    .slv_awcache     	( slv_awcache      ),
    .slv_awprot      	( slv_awprot       ),
    .slv_awqos       	( slv_awqos        ),
    .slv_awregion    	( slv_awregion     ),
    .slv_awid        	( slv_awid         ),
    .slv_wvalid      	( slv_wvalid       ),
    .slv_wready      	( slv_wready       ),
    .slv_wlast       	( slv_wlast        ),
    .slv_wdata       	( slv_wdata        ),
    .slv_wstrb       	( slv_wstrb        ),
    .slv_bvalid      	( slv_bvalid       ),
    .slv_bready      	( slv_bready       ),
    .slv_bid         	( slv_bid          ),
    .slv_bresp       	( slv_bresp        ),
    .slv_arvalid     	( slv_arvalid      ),
    .slv_arready     	( slv_arready      ),
    .slv_araddr      	( slv_araddr       ),
    .slv_arlen       	( slv_arlen        ),
    .slv_arsize      	( slv_arsize       ),
    .slv_arburst     	( slv_arburst      ),
    .slv_arlock      	( slv_arlock       ),
    .slv_arcache     	( slv_arcache      ),
    .slv_arprot      	( slv_arprot       ),
    .slv_arqos       	( slv_arqos        ),
    .slv_arregion    	( slv_arregion     ),
    .slv_arid        	( slv_arid         ),
    .slv_rvalid      	( slv_rvalid       ),
    .slv_rready      	( slv_rready       ),
    .slv_rid         	( slv_rid          ),
    .slv_rresp       	( slv_rresp        ),
    .slv_rdata       	( slv_rdata        ),
    .slv_rlast       	( slv_rlast        )
);

endmodule //dm
