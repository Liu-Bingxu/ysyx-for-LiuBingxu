module load_bypass_helper 
import mem_pkg::*;
import rob_pkg::*;
(
    input                                               clk,
    input                                               rst_n,

    input                                               redirect,

    input                                               loadUnit_arvalid,
    output                                              loadUnit_arready,
    input  [2:0]                                        loadUnit_arsize,
    input  [63:0]                                       loadUnit_araddr,
    input  ls_rob_entry_ptr_t                           loadUnit_rob_ptr,

    // query interface with dcache
    output [63:0]                                       dcache_load_paddr,
    input                                               dcache_load_hit,
    input  [63:0]                                       dcache_load_data,

    // query interface with storequeue
    output [63:0]                                       load_paddr2sq,
    output [7:0]                                        load_rstrb2sq,
    output ls_rob_entry_ptr_t                           load_rob_ptr,
    input  [63:0]                                       sq_load_data,
    input  [7:0]                                        sq_load_rstrb,
    input                                               sq_wait,

    // query interface with storebuffer
    output [63:0]                                       load_paddr2sb,
    output [7:0]                                        load_rstrb2sb,
    input  [63:0]                                       sb_load_data,
    input  [7:0]                                        sb_load_rstrb,

    output                                              loadUnit_rvalid,
    input                                               loadUnit_rready,
    output [1:0]                                        loadUnit_rresp,
    output [63:0]                                       loadUnit_rdata,

    output                                              load_arvalid,
    input                                               load_arready,
    output [2:0]                                        load_arsize,
    output [63:0]                                       load_araddr,

    input                                               load_rvalid,
    output                                              load_rready,
    input  [1:0]                                        load_rresp,
    input  [63:0]                                       load_rdata,

    output                                              load_uncache_arvalid,
    input                                               load_uncache_arready,
    output [2:0]                                        load_uncache_arsize,
    output [63:0]                                       load_uncache_araddr,

    input                                               load_uncache_rvalid,
    output                                              load_uncache_rready,
    input  [1:0]                                        load_uncache_rresp,
    input  [63:0]                                       load_uncache_rdata
);
logic          recv_stage_valid;
logic          recv_stage_ready;

logic [7:0]    load_rstrb;
logic          sq_sb_can_cover;
logic          sq_sb_can_cover_reg;

logic          loaduncache_reg;

logic          dcache_load_hit_reg;
logic  [63:0]  dcache_load_data_reg;

logic  [63:0]  sq_load_data_reg;
logic  [7:0]   sq_load_rstrb_reg;

logic  [63:0]  sb_load_data_reg;
logic  [7:0]   sb_load_rstrb_reg;

assign sq_sb_can_cover      = (load_rstrb == (sq_load_rstrb | sb_load_rstrb));

assign loadUnit_arready = ((!recv_stage_valid) | recv_stage_ready) & (!sq_wait) & (sq_sb_can_cover | dcache_load_hit | (addrcache(loadUnit_araddr) ? load_arready : load_uncache_arready));
assign recv_stage_ready = loadUnit_rvalid & loadUnit_rready;

logic recv_valid;
assign recv_valid = loadUnit_arvalid & loadUnit_arready;
FF_D_with_syn_rst #(
    .DATA_LEN 	( 1  ),
    .RST_DATA 	( 0  )
)u_recv_stage_valid
(
    .clk      	( clk                                       ),
    .rst_n    	( rst_n                                     ),
    .syn_rst    ( redirect                                  ),
    .wen        ( ((!recv_stage_valid) | recv_stage_ready)  ),
    .data_in  	( recv_valid                                ),
    .data_out 	( recv_stage_valid                          )
);

FF_D_without_asyn_rst #(1 ) u_loaduncache_reg_o         (clk,recv_valid, addrcache(loadUnit_araddr),loaduncache_reg);
FF_D_without_asyn_rst #(1 ) u_sq_sb_can_cover_reg_o     (clk,recv_valid, sq_sb_can_cover,           sq_sb_can_cover_reg);
FF_D_without_asyn_rst #(1 ) u_dcache_load_hit_reg_o     (clk,recv_valid, dcache_load_hit,           dcache_load_hit_reg);
FF_D_without_asyn_rst #(64) u_dcache_load_data_reg_o    (clk,recv_valid, dcache_load_data,          dcache_load_data_reg);
FF_D_without_asyn_rst #(64) u_sq_load_data_reg_o        (clk,recv_valid, sq_load_data,              sq_load_data_reg);
FF_D_without_asyn_rst #(8 ) u_sq_load_rstrb_reg_o       (clk,recv_valid, sq_load_rstrb,             sq_load_rstrb_reg);
FF_D_without_asyn_rst #(64) u_sb_load_data_reg_o        (clk,recv_valid, sb_load_data,              sb_load_data_reg);
FF_D_without_asyn_rst #(8 ) u_sb_load_rstrb_reg_o       (clk,recv_valid, sb_load_rstrb,             sb_load_rstrb_reg);


//get wstrb by control sign 
logic [7:0] byte_rstrb, half_rstrb, word_rstrb, double_rstrb;
always_comb begin
    case (loadUnit_araddr[2:0])
        3'b000: byte_rstrb=8'b00000001;
        3'b001: byte_rstrb=8'b00000010;
        3'b010: byte_rstrb=8'b00000100;
        3'b011: byte_rstrb=8'b00001000;
        3'b100: byte_rstrb=8'b00010000;
        3'b101: byte_rstrb=8'b00100000;
        3'b110: byte_rstrb=8'b01000000;
        3'b111: byte_rstrb=8'b10000000;
        default: byte_rstrb=8'b00000000;
    endcase
end
always_comb begin
    case (loadUnit_araddr[2:0])
        3'b000: half_rstrb=8'b00000011;
        3'b010: half_rstrb=8'b00001100;
        3'b100: half_rstrb=8'b00110000;
        3'b110: half_rstrb=8'b11000000;
        default: half_rstrb=8'b00000000;
    endcase
end
always_comb begin
    case (loadUnit_araddr[2:0])
        3'b000: word_rstrb=8'b00001111;
        3'b100: word_rstrb=8'b11110000;
        default: word_rstrb=8'b00000000;
    endcase
end
always_comb begin
    case (loadUnit_araddr[2:0])
        3'b000: double_rstrb=8'b11111111;
        default: double_rstrb=8'b00000000;
    endcase
end

assign load_rstrb = 8'h0 |
                    ({8{(loadUnit_arsize == 3'h0)}} & byte_rstrb   ) | 
                    ({8{(loadUnit_arsize == 3'h1)}} & half_rstrb   ) |
                    ({8{(loadUnit_arsize == 3'h2)}} & word_rstrb   ) |
                    ({8{(loadUnit_arsize == 3'h3)}} & double_rstrb ) ;

assign dcache_load_paddr = loadUnit_araddr;

assign load_paddr2sq = loadUnit_araddr;
assign load_rstrb2sq = load_rstrb;
assign load_rob_ptr  = loadUnit_rob_ptr;

assign load_paddr2sb = loadUnit_araddr;
assign load_rstrb2sb = load_rstrb;

assign loadUnit_rvalid  = recv_stage_valid & (sq_sb_can_cover_reg | dcache_load_hit_reg | (loaduncache_reg ? load_rvalid : load_uncache_rvalid));
assign loadUnit_rresp   = (sq_sb_can_cover_reg | dcache_load_hit_reg) ? 2'h0 : loaduncache_reg ? load_rresp : load_uncache_rresp;
logic [63:0] rdata_inner1;
logic [63:0] rdata_inner2;
logic [63:0] rdata_inner3;
assign rdata_inner1 = data_splicing_64(loaduncache_reg ? load_rdata : load_uncache_rdata, dcache_load_data_reg, {8{dcache_load_hit_reg}});
assign rdata_inner2 = data_splicing_64(rdata_inner1, sb_load_data_reg, sb_load_rstrb_reg);
assign rdata_inner3 = data_splicing_64(rdata_inner2, sq_load_data_reg, sq_load_rstrb_reg);
assign loadUnit_rdata   = rdata_inner3;

assign load_arvalid         = ((!recv_stage_valid) | recv_stage_ready) & (!sq_wait) & (!sq_sb_can_cover) & (!dcache_load_hit) & addrcache(loadUnit_araddr) & loadUnit_arvalid;
assign load_arsize          = loadUnit_arsize;
assign load_araddr          = loadUnit_araddr;

assign load_uncache_arvalid = ((!recv_stage_valid) | recv_stage_ready) & (!sq_wait) & (!sq_sb_can_cover) & (!dcache_load_hit) & (!addrcache(loadUnit_araddr)) & loadUnit_arvalid;
assign load_uncache_arsize  = loadUnit_arsize;
assign load_uncache_araddr  = loadUnit_araddr;

assign load_rready          = recv_stage_valid & (!sq_sb_can_cover_reg) & (!dcache_load_hit_reg) & loaduncache_reg;
assign load_uncache_rready  = recv_stage_valid & (!sq_sb_can_cover_reg) & (!dcache_load_hit_reg) & (!loaduncache_reg);

endmodule
