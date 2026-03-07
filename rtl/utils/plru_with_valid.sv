module plru_with_valid#(
    parameter way_num = 4
)(
    input  logic                                clk,
    input  logic                                rst_n,

    input  logic   [way_num - 1 : 0]            way_valid,
    input  logic                                way_access,
    input  logic   [$clog2(way_num) - 1 : 0]    way_access_index,
    output logic   [$clog2(way_num)     : 0]    way_replace_index
);

logic plru_tree_status;

generate 
    if(way_num > 2) begin : U_recursion_next
        logic [$clog2(way_num) - 1 : 0]    way_replace_index_left;
        logic [$clog2(way_num) - 1 : 0]    way_replace_index_right;
        plru_with_valid #(
            .way_num(way_num / 2)
        ) U_plru_left (
            .clk                (clk                                                ),
            .rst_n              (rst_n                                              ),
            .way_valid          (way_valid[way_num - 1 : way_num / 2]               ),
            .way_access         (way_access & way_access_index[$clog2(way_num) - 1] ),
            .way_access_index   (way_access_index[$clog2(way_num) - 2 : 0]          ),
            .way_replace_index  (way_replace_index_left                             )
        );
        plru_with_valid #(
            .way_num(way_num / 2)
        ) U_plru_right (
            .clk                (clk                                                    ),
            .rst_n              (rst_n                                                  ),
            .way_valid          (way_valid[way_num / 2 - 1 : 0]                         ),
            .way_access         (way_access & (!way_access_index[$clog2(way_num) - 1])  ),
            .way_access_index   (way_access_index[$clog2(way_num) - 2 : 0]              ),
            .way_replace_index  (way_replace_index_right                                )
        );
        FF_D_with_wen #(
            .DATA_LEN 	(1  ),
            .RST_DATA 	(0  ))
        u_plru_tree_status(
            .clk      	(clk                                    ),
            .rst_n    	(rst_n                                  ),
            .wen      	(way_access                             ),
            .data_in  	(!way_access_index[$clog2(way_num) - 1] ),
            .data_out 	(plru_tree_status                       )
        );
        logic [$clog2(way_num) - 1 : 0] res;
        assign res =    ({($clog2(way_num)){  way_replace_index_left[$clog2(way_num) - 1]  & way_replace_index_right[$clog2(way_num) - 1] & plru_tree_status    }} & {1'b1, way_replace_index_left[$clog2(way_num) - 2 : 0]}) | 
                        ({($clog2(way_num)){  way_replace_index_left[$clog2(way_num) - 1]  & way_replace_index_right[$clog2(way_num) - 1] & (!plru_tree_status) }} & {1'b0, way_replace_index_right[$clog2(way_num) - 2 : 0]}) | 
                        ({($clog2(way_num)){  way_replace_index_left[$clog2(way_num) - 1]  & (!way_replace_index_right[$clog2(way_num) - 1])                    }} & {1'b1, way_replace_index_left[$clog2(way_num) - 2 : 0]}) | 
                        ({($clog2(way_num)){(!way_replace_index_left[$clog2(way_num) - 1]) & way_replace_index_right[$clog2(way_num) - 1]                       }} & {1'b0, way_replace_index_right[$clog2(way_num) - 2 : 0]});
        assign way_replace_index    = {(way_replace_index_left[$clog2(way_num) - 1] | way_replace_index_right[$clog2(way_num) - 1]), res};
    end
    else if(way_num == 2) begin : U_recursion_end
        logic valid_left;
        logic valid_right;
        assign valid_left   = way_valid[1];
        assign valid_right  = way_valid[0];
        FF_D_with_wen #(
            .DATA_LEN 	(1  ),
            .RST_DATA 	(0  ))
        u_plru_tree_status(
            .clk      	(clk                                    ),
            .rst_n    	(rst_n                                  ),
            .wen      	(way_access                             ),
            .data_in  	(!way_access_index[$clog2(way_num) - 1] ),
            .data_out 	(plru_tree_status                       )
        );
        logic res;
        assign res =    ((valid_left & valid_right) & plru_tree_status) | 
                        ((valid_left & (!valid_right)) & 1'b1) | 
                        (((!valid_left) & valid_right) & 1'b0);
        assign way_replace_index    = {(valid_left | valid_right), res};
    end
    else begin : U_error
        initial begin
            $error("Error: way_num should be larger than 1");
        end
    end
endgenerate

endmodule //plru_with_valid
