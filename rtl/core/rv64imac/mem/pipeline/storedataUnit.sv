module storedataUnit
import decode_pkg::*;
import regfile_pkg::*;
import rob_pkg::*;
import iq_pkg::*;
import lsq_pkg::*;
import mem_pkg::*;
import core_setting_pkg::*;
(
    input                                               clk,
    input                                               rst_n,

    input                                               redirect,

    input                                               storedataUnit_in_valid,
    output                                              storedataUnit_in_ready,
    input  iq_mem_store_data_in_t                       storedataUnit_in,

    input                [wb_width - 1 : 0]             rfwen,
    input  pint_regdest_t[wb_width - 1 : 0]             pwdest,

    output pint_regsrc_t                                storedataUnit_psrc,
    input  intreg_t                                     storedataUnit_psrc_rdata,

    output                                              storedataUnit_valid_o,
    input                                               storedataUnit_ready_o,
    output SQ_entry_ptr_t                               storedataUnit_sq_ptr_o,
    output [63:0]                                       storedataUnit_mem_wdata_o
);

logic                	out1_valid;
logic                	out1_ready;
iq_mem_store_data_out_t out1;

iq_mem_store_data u_iq_mem_store_data(
	.clk        	( clk                   ),
	.rst_n      	( rst_n                 ),
	.redirect      	( redirect              ),
	.in_valid   	( storedataUnit_in_valid),
	.in_ready   	( storedataUnit_in_ready),
	.in         	( storedataUnit_in      ),
	.rfwen      	( rfwen                 ),
	.pwdest     	( pwdest                ),
	.out1_valid 	( out1_valid            ),
	.out1_ready 	( out1_ready            ),
	.out1       	( out1                  )
);
assign storedataUnit_psrc = out1.psrc2;

//*******************************stage0: to temp storage the preg_data******************************************
assign out1_ready = ((!storedataUnit_valid_o) | storedataUnit_ready_o);

logic send_valid_storedata;
assign send_valid_storedata = out1_valid & out1_ready;
FF_D_with_syn_rst #(
    .DATA_LEN 	( 1  ),
    .RST_DATA 	( 0  )
)u_storedataUnit_valid_o
(
    .clk      	( clk                                                   ),
    .rst_n    	( rst_n                                                 ),
    .syn_rst    ( redirect                                              ),
    .wen        ( ((!storedataUnit_valid_o) | storedataUnit_ready_o)    ),
    .data_in  	( send_valid_storedata                                  ),
    .data_out 	( storedataUnit_valid_o                                 )
);
intreg_t storedata_src2;

assign storedata_src2 = (({64{out1.src2_type == src_reg}}) & storedataUnit_psrc_rdata);

FF_D_without_asyn_rst #(rob_entry_w)    u_storedata_rob_ptr_o (clk,send_valid_storedata, out1.sq_ptr, storedataUnit_sq_ptr_o);
FF_D_without_asyn_rst #(64)             u_storedata_src2_o    (clk,send_valid_storedata, storedata_src2, storedataUnit_mem_wdata_o);


endmodule //storedataUnit
