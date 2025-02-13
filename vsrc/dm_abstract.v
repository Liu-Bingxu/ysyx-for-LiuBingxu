`include "define.v"
module dm_abstract #(
    parameter ABITS = 7,

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
    output                          allresumeack,
    output                          anyresumeack,
    output                          allhalt,
    output                          anyhalt,
    output [32            -1:0]     dm_hartinfo,
    output [32            -1:0]     dm_abstractcs,
    output [32            -1:0]     dm_command,
    output [32            -1:0]     dm_abstractauto,
    output [32            -1:0]     dm_data,
    output [32            -1:0]     dm_progbuf,

    input                           dm_reg_wen,
    input                           dm_reg_ren,
    input  [ABITS         -1:0]     dm_reg_addr,
    input  [32            -1:0]     dm_reg_data,

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
//! set full use data and progbuf
localparam DATA_COUNT = 12;
localparam PROGBUF_COUNT = 16;
localparam NSCRATCH_COUNT = 2;
localparam DATA_ACCESS = 1; //? data register in mem space

localparam IDLE     = 1'h0;
localparam RUNING   = 1'b1;

localparam AXI_IDLE         = 3'h0;
localparam AXI_READ         = 3'h1;
localparam AXI_WRITE        = 3'h2;
localparam AXI_WRITE_ERROR  = 3'h4;
localparam AXI_WIRTE_BACK   = 3'h3;

localparam AXI_ADDR_END     = (AXI_DATA_W == 64) ? 3 : 2;

wire [31:0]               dm_abstract_data[DATA_COUNT +3:4];
wire [31:0]               dm_abstract_data_w[DATA_COUNT +3:4];
wire [31:0]               dm_abstract_data_axi_w[DATA_COUNT +3:4];
wire                      dm_abstract_data_wen[DATA_COUNT +3:4];
wire                      dm_abstract_data_dtm_wen[DATA_COUNT +3:4];
wire                      dm_abstract_data_axi_wen[DATA_COUNT +3:4] /* verilator split_var */;
wire [DATA_COUNT    +3:4] dm_abstract_data_dtm_visit;
wire [DATA_COUNT    +3:4] dm_abstract_data_dtm_accsee;
wire [31:0]               dm_abstract_progbuf[PROGBUF_COUNT -1:0];
wire [31:0]               dm_abstract_progbuf_w[PROGBUF_COUNT -1:0];
wire [31:0]               dm_abstract_progbuf_axi_w[PROGBUF_COUNT -1:0];
wire                      dm_abstract_progbuf_wen[PROGBUF_COUNT -1:0];
wire                      dm_abstract_progbuf_dtm_wen[PROGBUF_COUNT -1:0];
wire                      dm_abstract_progbuf_axi_wen[PROGBUF_COUNT -1:0] /* verilator split_var */;
wire [PROGBUF_COUNT -1:0] dm_abstract_progbuf_dtm_visit;
wire [PROGBUF_COUNT -1:0] dm_abstract_progbuf_dtm_accsee;
wire [PROGBUF_COUNT -1:0] dm_autoexec_progbuf;
wire [DATA_COUNT    +3:4] dm_autoexec_data;
wire                      dm_abstractauto_wen;
wire                      dm_abstractauto_visit;

wire [31:0]               dm_abstract_commad;
wire [31:0]               dm_abstract_commad_w;
wire [7:0]                cmd_type   = dm_abstract_commad[31:24];
wire [2:0]                aarsize    = dm_abstract_commad[22:20];
wire                      postexec   = dm_abstract_commad[18];
wire                      transfer   = dm_abstract_commad[17];
wire                      write      = dm_abstract_commad[16];
wire [15:0]               regno      = dm_abstract_commad[15:0];
wire [7:0]                cmd_type_w = dm_reg_data[31:24];
wire [2:0]                aarsize_w  = dm_reg_data[22:20];
wire [15:0]               regno_w    = dm_reg_data[15:0];
wire                      dm_abstract_commad_wen;
wire                      dm_abstract_commad_finish;
wire                      dm_abstract_commad_visit;
wire                      dm_abstract_commad_legal;
wire                      dm_abstract_commad_write_legal;

reg                       dm_going_flag;
reg                       dm_resume_flag;

reg                       dm_core_halted;
reg                       dm_core_resumeack;

reg                       dm_abstract_state;
reg  [2:0]                dm_abstract_cmderr;
wire                      dm_abstractcs_visit;
wire                      busy = (dm_abstract_state != IDLE);

reg  [2:0]                axi_state;

reg  [AXI_ADDR_W    -1:0] mst_awaddr_reg;

reg  [8             -1:0] mst_rlen_reg;

reg  [AXI_ID_W      -1:0] mst_id_reg;
reg                       mst_resp_reg;

reg                       mst_wready_reg;
reg                       mst_bvalid_reg;
reg                       mst_rvalid_reg;
reg  [AXI_DATA_W    -1:0] mst_rdata_reg;
reg                       mst_rlast_reg;

wire [AXI_DATA_W    -1:0] mst_wmask;

wire [AXI_DATA_W    -1:0] mst_rdata_sel;

wire                      mst_rsel_rom          = ({mst_araddr[AXI_ADDR_W - 1 : 7], 7'h0} == {{(AXI_ADDR_W - 12){1'b0}}, `DEBUG_ROM_START});
wire [AXI_DATA_W    -1:0] mst_rdata_rom;
wire                      mst_rsel_flag         = (mst_araddr == {{(AXI_ADDR_W - 12){1'b0}}, `DEBUG_FLAG_START});
wire [AXI_DATA_W    -1:0] mst_rdata_flag        = {{(AXI_DATA_W - 2){1'b0}}, dm_resume_flag, dm_going_flag};
wire                      mst_rsel_data         = (({mst_araddr[AXI_ADDR_W - 1 : 6], 6'h0} == {{(AXI_ADDR_W - 12){1'b0}}, `DEBUG_DATA_START}) 
                                                    & (mst_araddr[5:4] != 2'h3));
wire [AXI_DATA_W    -1:0] mst_rdata_data;
wire                      mst_rsel_progbuf      = ({mst_araddr[AXI_ADDR_W - 1 : 6], 6'h0} == {{(AXI_ADDR_W - 12){1'b0}}, `DEBUG_PROGBUF_START});
wire [AXI_DATA_W    -1:0] mst_rdata_progbuf;
wire                      mst_rsel_sbstract     = (({mst_araddr[AXI_ADDR_W - 1 : 6], 6'h0} == {{(AXI_ADDR_W - 12){1'b0}}, `DEBUG_ROM_WHERETO}) 
                                                    & (mst_araddr[5:4] != 2'h0));
wire [AXI_DATA_W    -1:0] mst_rdata_abstract;
wire                      mst_rsel_rom_whereto  = ({mst_araddr[AXI_ADDR_W - 1 : 2], 2'h0} == {{(AXI_ADDR_W - 12){1'b0}}, `DEBUG_ROM_WHERETO});
wire [AXI_DATA_W    -1:0] mst_rdata_rom_whereto = {{(AXI_DATA_W - 32){1'b0}}, 32'h0100006f};

wire                      mst_wsel_data         = (({mst_awaddr[AXI_ADDR_W - 1 : 6], 6'h0} == {{(AXI_ADDR_W - 12){1'b0}}, `DEBUG_DATA_START}) 
                                                & (mst_awaddr[5:4] != 2'h3));
wire                      mst_wsel_data_reg     = (({mst_awaddr_reg[AXI_ADDR_W - 1 : 6], 6'h0} == {{(AXI_ADDR_W - 12){1'b0}}, `DEBUG_DATA_START}) 
                                                & (mst_awaddr_reg[5:4] != 2'h3));
wire                      mst_wsel_flag         = ({mst_awaddr[AXI_ADDR_W - 1 : 4], 2'h0, mst_awaddr[1:0]} == {{(AXI_ADDR_W - 12){1'b0}}, `DEBUG_HALT_START});
wire                      mst_wsel_progbuf      = ({mst_awaddr[AXI_ADDR_W - 1 : 6], 6'h0} == {{(AXI_ADDR_W - 12){1'b0}}, `DEBUG_PROGBUF_START});
wire                      mst_wsel_progbuf_reg  = ({mst_awaddr_reg[AXI_ADDR_W - 1 : 6], 6'h0} == {{(AXI_ADDR_W - 12){1'b0}}, `DEBUG_PROGBUF_START});

assign mst_rdata_sel = {AXI_DATA_W{1'b0}}
                | ({AXI_DATA_W{mst_rsel_rom          }} & mst_rdata_rom         )
                | ({AXI_DATA_W{mst_rsel_flag         }} & mst_rdata_flag        )
                | ({AXI_DATA_W{mst_rsel_data         }} & mst_rdata_data        )
                | ({AXI_DATA_W{mst_rsel_progbuf      }} & mst_rdata_progbuf     )
                | ({AXI_DATA_W{mst_rsel_sbstract     }} & mst_rdata_abstract    )
                | ({AXI_DATA_W{mst_rsel_rom_whereto  }} & mst_rdata_rom_whereto )
                ;

dm_debug_rom #(
    .AXI_DATA_W 	( AXI_DATA_W  ))
u_dm_debug_rom(
    .addr      	( mst_araddr[6:AXI_ADDR_END]),
    .rom_rdata 	( mst_rdata_rom             )
);

generate 
    if(AXI_DATA_W == 64) begin : gen_64bit_axi_data_progbuf
        assign mst_rdata_data    = (&mst_araddr[5:4]) ? 64'h0 : {dm_abstract_data[{mst_araddr[5:3], 1'b1}], dm_abstract_data[{mst_araddr[5:3], 1'b0}]};
        assign mst_rdata_progbuf = {dm_abstract_progbuf[{mst_araddr[5:3], 1'b1}], dm_abstract_progbuf[{mst_araddr[5:3], 1'b0}]};
    end
    else if(AXI_DATA_W == 32) begin : gen_32bit_axi_data_progbuf
        assign mst_rdata_data    = (&mst_araddr[5:4]) ? 32'h0 : dm_abstract_data[mst_araddr[5:2]];
        assign mst_rdata_progbuf = dm_abstract_progbuf[mst_araddr[5:2]];
    end
    else begin : gen_error_messge
        $error("data width error");
    end
endgenerate

generate 
    if(AXI_DATA_W == 64) begin : gen_64bit_legal_abstract_commad
        assign dm_abstract_commad_legal         = (cmd_type == 8'h0) & ((aarsize == 3'h2) | (aarsize == 3'h3)) & (regno < 16'h1040);
        assign dm_abstract_commad_write_legal   = (cmd_type_w == 8'h0) & ((aarsize_w == 3'h2) | (aarsize_w == 3'h3)) & (regno_w < 16'h1040);
    end
    else if(AXI_DATA_W == 32) begin : gen_32bit_legal_abstract_commad
        assign dm_abstract_commad_legal         = (cmd_type == 8'h0) & (aarsize == 3'h2) & (regno < 16'h1040);
        assign dm_abstract_commad_write_legal   = (cmd_type_w == 8'h0) & (aarsize_w == 3'h2) & (regno_w < 16'h1040);
    end
    else begin : gen_error_messge
        $error("data width error");
    end
endgenerate

dm_abstract_inst #(
    .AXI_DATA_W 	( AXI_DATA_W  ))
u_dm_abstract_inst(
    .aarsize        	( aarsize                       ),
    .postexec       	( postexec                      ),
    .transfer       	( transfer                      ),
    .write          	( write                         ),
    .regno          	( regno                         ),
    .addr           	( mst_araddr[5:AXI_ADDR_END]    ),
    .abstract_rdata 	( mst_rdata_abstract            )
);


always @(posedge dm_clk or negedge dm_rst_n) begin
    if(!dm_rst_n)begin
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
                    else if(mst_wsel_data | mst_wsel_flag | mst_wsel_progbuf)begin
                        axi_state       <= AXI_WRITE;
                        mst_resp_reg    <= 1'b0;
                        mst_awaddr_reg  <= mst_awaddr;
                    end
                    else begin
                        axi_state       <= AXI_WRITE_ERROR;
                        mst_resp_reg    <= 1'b1;
                    end
                end
                else if(mst_arvalid & mst_arready)begin
                    axi_state           <= AXI_READ;
                    mst_id_reg          <= mst_arid;
                    mst_rlen_reg        <= mst_arlen;
                    mst_rvalid_reg      <= 1'b1;
                    if((|mst_arcache) | (|mst_arlen) | (|mst_arprot) | mst_arlock | (|mst_arqos) | (|mst_arregion))begin
                        mst_resp_reg    <= 1'b1;
                    end
                    else if(mst_rsel_rom | mst_rsel_flag | mst_rsel_data | mst_rsel_progbuf | mst_rsel_sbstract | mst_rsel_rom_whereto)begin
                        mst_resp_reg    <= 1'b0;
                        mst_rdata_reg   <= mst_rdata_sel;
                    end
                    else begin
                        mst_resp_reg    <= 1'b1;
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
            AXI_WRITE, AXI_WRITE_ERROR: begin
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

genvar mask_index;
generate for(mask_index = 0 ; mask_index < (AXI_DATA_W/8); mask_index = mask_index + 1) begin : gen_wmask
    assign mst_wmask[8 * mask_index + 7 : 8 * mask_index] = {8{mst_wstrb[mask_index]}};
end
endgenerate

always @(posedge dm_clk or negedge dm_rst_n) begin
    if(!dm_rst_n)begin
        dm_abstract_state <= IDLE;
    end
    else if(!dmactive)begin
        dm_abstract_state <= IDLE;
    end
    else begin
        case (dm_abstract_state)
            IDLE: begin
                if((dm_abstract_cmderr == 3'h0) & dm_core_halted & ((|dm_abstract_data_dtm_accsee) | (|dm_abstract_progbuf_dtm_accsee)) & dm_abstract_commad_legal)begin
                    dm_abstract_state <= RUNING;
                end
                else if((dm_abstract_cmderr == 3'h0) & dm_core_halted & dm_abstract_commad_wen & dm_abstract_commad_write_legal)begin
                    dm_abstract_state <= RUNING;
                end
            end
            RUNING: begin
                if((axi_state == AXI_WRITE) & (mst_awaddr_reg == {{(AXI_ADDR_W - 12){1'b0}}, `DEBUG_HALT_START}) & (!dm_going_flag))begin
                    dm_abstract_state <= IDLE;
                end
            end
            default: begin
                dm_abstract_state <= IDLE;
            end
        endcase
    end
end

always @(posedge dm_clk or negedge dm_rst_n) begin
    if(!dm_rst_n)begin
        dm_going_flag <= 1'b0;
    end
    else if((axi_state == AXI_WRITE) & (mst_awaddr_reg == {{(AXI_ADDR_W - 12){1'b0}}, `DEBUG_GOING_START}))begin
        dm_going_flag <= 1'b0;
    end
    else if((!busy) & (dm_abstract_cmderr == 3'h0) & dm_core_halted & ((|dm_abstract_data_dtm_accsee) | (|dm_abstract_progbuf_dtm_accsee)) & dm_abstract_commad_legal)begin
        dm_going_flag <= 1'b1;
    end
    else if((!busy) & (dm_abstract_cmderr == 3'h0) & dm_core_halted & dm_abstract_commad_wen & dm_abstract_commad_write_legal)begin
        dm_going_flag <= 1'b1;
    end
end

always @(posedge dm_clk or negedge dm_rst_n) begin
    if(!dm_rst_n)begin
        dm_resume_flag <= 1'b0;
    end
    else if((axi_state == AXI_WRITE) & (mst_awaddr_reg == {{(AXI_ADDR_W - 12){1'b0}}, `DEBUG_RESUMING_START}))begin
        dm_resume_flag <= 1'b0;
    end
    else if((dm_reg_addr == {{(ABITS - 5){1'b0}}, 5'h10}) & dm_reg_wen & dm_reg_data[30] & dm_reg_data[0])begin
        dm_resume_flag <= 1'b1;
    end
end

always @(posedge dm_clk or negedge dm_rst_n) begin
    if(!dm_rst_n)begin
        dm_core_halted <= 1'b0;
    end
    else if((axi_state == AXI_WRITE) & (mst_awaddr_reg == {{(AXI_ADDR_W - 12){1'b0}}, `DEBUG_HALT_START}))begin
        dm_core_halted <= 1'b1;
    end
    else if((axi_state == AXI_WRITE) & (mst_awaddr_reg == {{(AXI_ADDR_W - 12){1'b0}}, `DEBUG_RESUMING_START}))begin
        dm_core_halted <= 1'b0;
    end
    else if((dm_reg_addr == {{(ABITS - 5){1'b0}}, 5'h10}) & dm_reg_wen & (dm_reg_data[29] | dm_reg_data[1]) & dm_reg_data[0])begin
        dm_core_halted <= 1'b0;
    end
end

always @(posedge dm_clk or negedge dm_rst_n) begin
    if(!dm_rst_n)begin
        dm_core_resumeack <= 1'b0;
    end
    else if((axi_state == AXI_WRITE) & (mst_awaddr_reg == {{(AXI_ADDR_W - 12){1'b0}}, `DEBUG_RESUMING_START}))begin
        dm_core_resumeack <= 1'b1;
    end
    else if((dm_reg_addr == {{(ABITS - 5){1'b0}}, 5'h10}) & dm_reg_wen & dm_reg_data[30] & dm_reg_data[0])begin
        dm_core_resumeack <= 1'b0;
    end
end

assign dm_abstractcs_visit = (dm_reg_addr == {{(ABITS - 5){1'b0}}, 5'h16}) & dm_reg_wen;
always @(posedge dm_clk or negedge dm_rst_n) begin
    if(!dm_rst_n)begin
        dm_abstract_cmderr <= 3'h0; //? CMDERR_NONE
    end
    else if((!busy) & dm_abstractcs_visit)begin
        dm_abstract_cmderr <= dm_abstract_cmderr & (~dm_reg_data[10:8]);
    end
    else if((dm_abstract_cmderr == 3'h0) & (axi_state == AXI_WRITE) & (mst_awaddr_reg == {{(AXI_ADDR_W - 12){1'b0}}, `DEBUG_EXCEPTION_START}))begin
        dm_abstract_cmderr <= 3'h3; //? CMDERR_EXCEPTION
    end
    else if((dm_abstract_cmderr == 3'h0) & busy & ((|dm_abstract_data_dtm_visit) | (|dm_abstract_progbuf_dtm_visit) | dm_abstractauto_visit | dm_abstract_commad_visit | dm_abstractcs_visit))begin
        dm_abstract_cmderr <= 3'h1; //? CMDERR_BUSY
    end
    else if((!busy) & (dm_abstract_cmderr == 3'h0) & (!dm_core_halted) & ((|dm_abstract_data_dtm_accsee) | (|dm_abstract_progbuf_dtm_accsee)) & dm_abstract_commad_legal)begin
        dm_abstract_cmderr <= 3'h4; //? CMDERR_HALTRESUME
    end
    else if((!busy) & (dm_abstract_cmderr == 3'h0) & (!dm_core_halted) & dm_abstract_commad_wen & dm_abstract_commad_write_legal)begin
        dm_abstract_cmderr <= 3'h4; //? CMDERR_HALTRESUME
    end
    else if((!busy) & (dm_abstract_cmderr == 3'h0) & dm_core_halted & ((|dm_abstract_data_dtm_accsee) | (|dm_abstract_progbuf_dtm_accsee)) & (!dm_abstract_commad_legal))begin
        dm_abstract_cmderr <= 3'h2; //? CMDERR_NOTSUP
    end
    else if((!busy) & (dm_abstract_cmderr == 3'h0) & dm_core_halted & dm_abstract_commad_wen & (!dm_abstract_commad_write_legal))begin
        dm_abstract_cmderr <= 3'h2; //? CMDERR_NOTSUP
    end
end

genvar data_index;
generate for(data_index = 4 ; data_index < (DATA_COUNT + 4); data_index = data_index + 1) begin : gen_abstract_data
    assign dm_abstract_data_wen[data_index]     = dm_abstract_data_dtm_wen[data_index] | dm_abstract_data_axi_wen[data_index];
    assign dm_abstract_data_dtm_wen[data_index] = (!busy) & (dm_reg_addr == {{(ABITS - 5){1'b0}}, data_index[4:0]}) & dm_reg_wen;
    if(AXI_DATA_W == 64) begin : gen_64bit_axi_data_axi
        assign dm_abstract_data_axi_wen[data_index] = (data_index % 2 == 1) ? dm_abstract_data_axi_wen[data_index - 1] 
                                                        : (axi_state == AXI_WRITE) & mst_wvalid & mst_wready & mst_wsel_data_reg 
                                                        & ({mst_awaddr_reg[5:3], 1'b0} == (data_index - 4'h4));
        assign dm_abstract_data_axi_w[data_index]   = (data_index % 2 == 1) ? ((dm_abstract_data[data_index] & (~mst_wmask[63:32])) | (mst_wdata[63:32] & mst_wmask[63:32])) 
                                                        : ((dm_abstract_data[data_index] & (~mst_wmask[31:0])) | (mst_wdata[31:0] & mst_wmask[31:0]));
    end
    else if(AXI_DATA_W == 32) begin : gen_32bit_axi_data_axi
        assign dm_abstract_data_axi_wen[data_index] = (axi_state == AXI_WRITE) & mst_wvalid & mst_wready & mst_wsel_data_reg 
                                                        & (mst_awaddr_reg[5:2] == (data_index - 4'h4));
        assign dm_abstract_data_axi_w[data_index]   = ((dm_abstract_data[data_index] & (~mst_wmask)) | (mst_wdata & mst_wmask));
    end
    else begin : gen_error_messge
        $error("data width error");
    end
    assign dm_abstract_data_w[data_index]       = (dm_abstract_data_dtm_wen[data_index]) ? dm_reg_data : dm_abstract_data_axi_w[data_index];
    assign dm_abstract_data_dtm_visit[data_index]  = (dm_reg_addr == {{(ABITS - 5){1'b0}}, data_index[4:0]}) & (dm_reg_wen | dm_reg_ren);
    assign dm_abstract_data_dtm_accsee[data_index] = (dm_reg_addr == {{(ABITS - 5){1'b0}}, data_index[4:0]}) & (dm_reg_wen | dm_reg_ren) & dm_autoexec_data[data_index];
    FF_D_with_syn_rst #(
        .DATA_LEN 	( 32  ),
        .RST_DATA 	( 0   ))
    u_abstract_data(
        .clk      	( dm_clk                            ),
        .rst_n    	( dm_rst_n                          ),
        .syn_rst  	( !dmactive                         ),
        .wen      	( dm_abstract_data_wen[data_index]  ),
        .data_in  	( dm_abstract_data_w[data_index]    ),
        .data_out 	( dm_abstract_data[data_index]      )
    );
end
endgenerate

genvar pbuf_index;
generate for(pbuf_index = 0 ; pbuf_index < PROGBUF_COUNT; pbuf_index = pbuf_index + 1) begin : gen_abstract_progbuf
    assign dm_abstract_progbuf_wen[pbuf_index]     = dm_abstract_progbuf_dtm_wen[pbuf_index] | dm_abstract_progbuf_axi_wen[pbuf_index];
    assign dm_abstract_progbuf_dtm_wen[pbuf_index] = (!busy) & (dm_reg_addr == {{(ABITS - 6){1'b0}}, 2'h2, pbuf_index[3:0]}) & dm_reg_wen;
    if(AXI_DATA_W == 64) begin : gen_64bit_axi_progbuf_axi
        assign dm_abstract_progbuf_axi_wen[pbuf_index] = (pbuf_index % 2 == 1) ? dm_abstract_progbuf_axi_wen[pbuf_index - 1] 
                                                        : (axi_state == AXI_WRITE) & mst_wvalid & mst_wready & mst_wsel_progbuf_reg 
                                                        & ({mst_awaddr_reg[5:3], 1'b0} == pbuf_index);
        assign dm_abstract_progbuf_axi_w[pbuf_index]   = (pbuf_index % 2 == 1) ? ((dm_abstract_progbuf[pbuf_index] & (~mst_wmask[63:32])) | (mst_wdata[63:32] & mst_wmask[63:32])) 
                                                        : ((dm_abstract_progbuf[pbuf_index] & (~mst_wmask[31:0])) | (mst_wdata[31:0] & mst_wmask[31:0]));
    end
    else if(AXI_DATA_W == 32) begin : gen_32bit_axi_progbuf_axi
        assign dm_abstract_progbuf_axi_wen[pbuf_index] = (axi_state == AXI_WRITE) & mst_wvalid & mst_wready & mst_wsel_progbuf_reg 
                                                        & (mst_awaddr_reg[5:2] == pbuf_index);
        assign dm_abstract_progbuf_axi_w[pbuf_index]   = ((dm_abstract_progbuf[pbuf_index] & (~mst_wmask)) | (mst_wdata & mst_wmask));
    end
    else begin : gen_error_messge
        $error("data width error");
    end
    assign dm_abstract_progbuf_w[pbuf_index]       = (dm_abstract_progbuf_dtm_wen[pbuf_index]) ? dm_reg_data : dm_abstract_progbuf_axi_w[pbuf_index];
    assign dm_abstract_progbuf_dtm_visit[pbuf_index]  = (dm_reg_addr == {{(ABITS - 6){1'b0}}, 2'h2, pbuf_index[3:0]}) & (dm_reg_wen | dm_reg_ren);
    assign dm_abstract_progbuf_dtm_accsee[pbuf_index] = (dm_reg_addr == {{(ABITS - 6){1'b0}}, 2'h2, pbuf_index[3:0]}) & (dm_reg_wen | dm_reg_ren) & dm_autoexec_progbuf[pbuf_index];
    FF_D_with_syn_rst #(
        .DATA_LEN 	( 32  ),
        .RST_DATA 	( 0   ))
    u_abstract_progbuf(
        .clk      	( dm_clk                                ),
        .rst_n    	( dm_rst_n                              ),
        .syn_rst  	( !dmactive                             ),
        .wen      	( dm_abstract_progbuf_wen[pbuf_index]   ),
        .data_in  	( dm_abstract_progbuf_w[pbuf_index]     ),
        .data_out 	( dm_abstract_progbuf[pbuf_index]       )
    );
end
endgenerate

assign dm_abstractauto_wen      = (!busy) & (dm_reg_addr == {{(ABITS - 5){1'b0}}, 5'h18}) & dm_reg_wen;
assign dm_abstractauto_visit    = (dm_reg_addr == {{(ABITS - 5){1'b0}}, 5'h18}) & dm_reg_wen;
FF_D_with_syn_rst #(
    .DATA_LEN 	( PROGBUF_COUNT + DATA_COUNT    ),
    .RST_DATA 	( 0                             ))
u_abstractauto(
    .clk      	( dm_clk                                                            ),
    .rst_n    	( dm_rst_n                                                          ),
    .syn_rst  	( !dmactive                                                         ),
    .wen      	( dm_abstractauto_wen                                               ),
    .data_in  	( {dm_reg_data[PROGBUF_COUNT+15:16], dm_reg_data[DATA_COUNT-1:0]}   ),
    .data_out 	( {dm_autoexec_progbuf, dm_autoexec_data}                           )
);

assign dm_abstract_commad_wen       = ((!busy) & (dm_reg_addr == {{(ABITS - 5){1'b0}}, 5'h17}) & dm_reg_wen) | (dm_abstract_commad_finish & dm_abstract_commad[19]);
assign dm_abstract_commad_visit     = (dm_reg_addr == {{(ABITS - 5){1'b0}}, 5'h17}) & dm_reg_wen;
assign dm_abstract_commad_finish    = (axi_state == AXI_WRITE) & (mst_awaddr_reg == {{(AXI_ADDR_W - 12){1'b0}}, `DEBUG_HALT_START}) & (!dm_going_flag) & (dm_abstract_state == RUNING);
assign dm_abstract_commad_w         = (dm_abstract_commad_finish) ? {dm_abstract_commad[31:16], (dm_abstract_commad[15:0] + 1'b1)} : dm_reg_data;
FF_D_with_syn_rst #(
    .DATA_LEN 	( 32  ),
    .RST_DATA 	( 0   ))
u_abstract_commad(
    .clk      	( dm_clk                    ),
    .rst_n    	( dm_rst_n                  ),
    .syn_rst  	( !dmactive                 ),
    .wen      	( dm_abstract_commad_wen    ),
    .data_in  	( dm_abstract_commad_w      ),
    .data_out 	( dm_abstract_commad        )
);

assign allresumeack = dm_core_resumeack;
assign anyresumeack = dm_core_resumeack;
assign allhalt = dm_core_halted;
assign anyhalt = dm_core_halted;
assign dm_hartinfo = {8'h0, NSCRATCH_COUNT[3:0], 3'h0, DATA_ACCESS[0], DATA_COUNT[3:0], `DEBUG_DATA_START};
assign dm_abstractcs = {3'h0, PROGBUF_COUNT[4:0], 11'h0, busy, 1'b0, dm_abstract_cmderr, 4'h0, DATA_COUNT[3:0]};
assign dm_command = dm_abstract_commad;
assign dm_abstractauto = {{(16 - PROGBUF_COUNT){1'b0}}, dm_autoexec_progbuf, 4'h0, {(12 - DATA_COUNT){1'b0}}, dm_autoexec_data};
assign dm_data = (dm_reg_addr[3:2] == 2'h0) ? 32'h0 : dm_abstract_data[dm_reg_addr[3:0]];
assign dm_progbuf = dm_abstract_progbuf[dm_reg_addr[3:0]];

endmodule //dm_abstract
