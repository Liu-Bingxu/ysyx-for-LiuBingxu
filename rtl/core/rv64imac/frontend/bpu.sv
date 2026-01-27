`include "./struct.sv"
module bpu#(parameter RST_PC=64'h0)(
    input                           clk,
    input                           rst_n,

    // uftb interface
    input                           predict,

    input                           redirect,
    input  [63:0]                   redirect_pc,

    input                           update,
    input                           update_hit,
    input  [UFTB_ENTRY_NUM - 1 : 0] update_sel,
    input  [TAG_BIT_NUM - 1: 0]     update_tag,
    input  uftb_entry               update_entry,

    output ftq_entry                enqueue_entry,

    // return addr stack interface
    input                           precheck_restore,
    input                           precheck_push,
    input  [63:0]                   precheck_push_pc,
    input                           precheck_pop,
    input  [63:0]                   precheck_pop_pc_i,
    output [63:0]                   precheck_pop_pc,

    input                           commit_restore,
    input                           commit_push,
    input  [63:0]                   commit_push_pc,
    input                           commit_pop
);

// output declaration of module uftb
wire        pred_push;
wire [63:0] pred_push_pc;
wire        pred_pop;
wire [63:0] pred_pop_pc_i;


// output declaration of module ras
wire [63:0] pred_pop_pc;

uftb #(
    .RST_PC 	(RST_PC  ))
u_uftb(
    .clk           	(clk            ),
    .rst_n         	(rst_n          ),
    .predict       	(predict        ),
	.pred_push      (pred_push      ),
	.pred_push_pc   (pred_push_pc   ),
	.pred_pop       (pred_pop       ),
    .pred_pop_pc   	(pred_pop_pc    ),
    .pred_pop_pc_i 	(pred_pop_pc_i  ),
    .redirect      	(redirect       ),
    .redirect_pc   	(redirect_pc    ),
    .update        	(update         ),
    .update_hit    	(update_hit     ),
    .update_sel    	(update_sel     ),
    .update_tag    	(update_tag     ),
    .update_entry  	(update_entry   ),
    .enqueue_entry 	(enqueue_entry  )
);


ras u_ras(
    .clk               	(clk                ),
    .rst_n             	(rst_n              ),
    .pred_push         	(pred_push          ),
    .pred_push_pc      	(pred_push_pc       ),
    .pred_pop          	(pred_pop           ),
    .pred_pop_pc_i     	(pred_pop_pc_i      ),
    .pred_pop_pc       	(pred_pop_pc        ),
    .precheck_restore  	(precheck_restore   ),
    .precheck_push     	(precheck_push      ),
    .precheck_push_pc  	(precheck_push_pc   ),
    .precheck_pop      	(precheck_pop       ),
    .precheck_pop_pc_i 	(precheck_pop_pc_i  ),
    .precheck_pop_pc   	(precheck_pop_pc    ),
    .commit_restore    	(commit_restore     ),
    .commit_push       	(commit_push        ),
    .commit_push_pc    	(commit_push_pc     ),
    .commit_pop        	(commit_pop         )
);


endmodule //bpu
