module rename_intfreelist
import decode_pkg::*;
import rename_pkg::*;
import regfile_pkg::*;
import core_setting_pkg::*;
(
    input                                               clk,
    input                                               rst_n,

    input                                               redirect,

    input                                               rename_fire,
    input               [decode_width - 1 : 0]          rename_int_req,
    output rename_resp_t[decode_width - 1 : 0]          rename_int_resp,

    input                [commit_width - 1 :0]          commit_int_need_free,
    input  pint_regdest_t[commit_width - 1 :0]          commit_int_old_pdest
);

pint_regsrc_t       [int_free_list_NUM - 1:0]   int_free_list;
int_free_list_ptr_t                             int_free_list_head;
int_free_list_ptr_t                             int_free_list_arch_tail;

int_free_list_ptr_t [decode_width - 1 : 0]      int_free_list_resp_point/* verilator split_var */;
int_free_list_ptr_t [commit_width - 1 : 0]      int_free_list_commit_point/* verilator split_var */;

logic                                           int_free_list_arch_wen;

int_free_list_ptr_t                             int_free_list_head_nxt;
int_free_list_ptr_t                             int_free_list_arch_tail_nxt;

int_free_list_ptr_t                             commit_num;
//! 由于不好作参数化，所以用此行为级建模
integer i;
always_comb begin : cal_commit_num
    commit_num = 0;
    for(i = 0; i < commit_width; i = i + 1)begin
        commit_num = commit_num + {{(int_free_list_w){1'b0}}, commit_int_need_free[i]};
    end
end

assign int_free_list_arch_wen       = (|commit_int_need_free);

assign int_free_list_head_nxt       = (redirect) ? 
                    (int_free_list_arch_wen ? 
                    {(!int_free_list_arch_tail_nxt[int_free_list_w]), int_free_list_arch_tail_nxt[int_free_list_w - 1: 0]} : 
                    {(!int_free_list_arch_tail[int_free_list_w]), int_free_list_arch_tail[int_free_list_w - 1: 0]}) : 
                    (rename_int_req[decode_width - 1] ? (int_free_list_resp_point[decode_width - 1] + 1) : int_free_list_resp_point[decode_width - 1]);

assign int_free_list_arch_tail_nxt  = int_free_list_arch_tail + commit_num;

FF_D_with_wen #(
	.DATA_LEN 	( int_free_list_w + 1   ),
	.RST_DATA 	( 0                     ))
u_int_free_list_head(
	.clk      	( clk                       ),
	.rst_n    	( rst_n                     ),
	.wen      	( rename_fire | redirect    ),
	.data_in  	( int_free_list_head_nxt    ),
	.data_out 	( int_free_list_head        )
);

FF_D_with_wen #(
	.DATA_LEN 	( int_free_list_w + 1               ),
	.RST_DATA 	( {1'b1, {int_free_list_w{1'b0}}}   ))
u_int_free_list_arch_tail(
	.clk      	( clk                           ),
	.rst_n    	( rst_n                         ),
	.wen      	( int_free_list_arch_wen        ),
	.data_in  	( int_free_list_arch_tail_nxt   ),
	.data_out 	( int_free_list_arch_tail       )
);

genvar resp_index;
generate for(resp_index = 0 ; resp_index < decode_width; resp_index = resp_index + 1) begin : U_gen_resp
    if(resp_index == 0)begin:u_gen_resp_point_0
        assign int_free_list_resp_point[resp_index] = int_free_list_head;
    end
    else begin:u_gen_resp_point_another
        assign int_free_list_resp_point[resp_index] = rename_int_req[resp_index - 1] ? (int_free_list_resp_point[resp_index - 1] + 1) : int_free_list_resp_point[resp_index - 1];
    end
    assign rename_int_resp[resp_index].rename_valid = (int_free_list_resp_point[resp_index] != int_free_list_arch_tail);
    assign rename_int_resp[resp_index].rename_dest = int_free_list[int_free_list_resp_point[resp_index][int_free_list_w - 1:0]];
end
endgenerate

genvar commit_index;
generate for(commit_index = 0 ; commit_index < commit_width; commit_index = commit_index + 1) begin : U_gen_commit_point
    if(commit_index == 0)begin:u_gen_commit_point_0
        assign int_free_list_commit_point[commit_index] = int_free_list_arch_tail;
    end
    else begin:u_gen_commit_point_another
        assign int_free_list_commit_point[commit_index] = (commit_int_need_free[commit_index - 1]) ? 
                                                        (int_free_list_commit_point[commit_index - 1] + 1) : 
                                                        int_free_list_commit_point[commit_index - 1];
    end
end
endgenerate

genvar free_list_index;
generate for(free_list_index = 0 ; free_list_index < int_free_list_NUM; free_list_index = free_list_index + 1) begin : U_gen_free_list
    logic                                        int_free_list_wen;
    pint_regdest_t                               int_free_list_nxt;
    always_comb begin : u_gen_free_list_wen_wdata
        int_free_one(
            free_list_index, 
            commit_int_need_free,
            int_free_list_commit_point, 
            commit_int_old_pdest, 
            int_free_list_wen, 
            int_free_list_nxt
        );
    end
    localparam [int_preg_width - 1:0] free_list_rst = 32 + free_list_index[int_preg_width - 1:0];
    FF_D_with_wen #(
        .DATA_LEN 	( int_preg_width  ),
        .RST_DATA 	( free_list_rst   ))
    u_int_free_list(
        .clk      	( clk                               ),
        .rst_n    	( rst_n                             ),
        .wen      	( int_free_list_wen                 ),
        .data_in  	( int_free_list_nxt                 ),
        .data_out 	( int_free_list[free_list_index]    )
    );
end
endgenerate

endmodule // rename_intfreelist
