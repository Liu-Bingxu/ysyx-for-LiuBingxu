module plru_16 (
    input                   clk,
    input                   rst_n,

    input                   hit,
    input  [15:0]           hit_sel,
    input                   plru_wen,
    output [15:0]           wen
);

reg  [14:0]             plru_status;

wire [1:0]              plru_l1_wen;
wire [3:0]              plru_l2_wen;
wire [7:0]              plru_l3_wen;

always @(posedge clk or negedge rst_n) begin
    if(!rst_n)begin
        plru_status <= 15'h0;
    end
    else if(plru_wen)begin
                        plru_status[0 ] <= ~plru_status[0 ];

        if(|wen[7:0  ]) plru_status[1 ] <= ~plru_status[1 ];
        if(|wen[15:8 ]) plru_status[2 ] <= ~plru_status[2 ];

        if(|wen[3:0  ]) plru_status[3 ] <= ~plru_status[3 ];
        if(|wen[7:4  ]) plru_status[4 ] <= ~plru_status[4 ];
        if(|wen[11:8 ]) plru_status[5 ] <= ~plru_status[5 ];
        if(|wen[15:12]) plru_status[6 ] <= ~plru_status[6 ];

        if(|wen[1:0  ]) plru_status[7 ] <= ~plru_status[7 ];
        if(|wen[3:2  ]) plru_status[8 ] <= ~plru_status[8 ];
        if(|wen[5:4  ]) plru_status[9 ] <= ~plru_status[9 ];
        if(|wen[7:6  ]) plru_status[10] <= ~plru_status[10];
        if(|wen[9:8  ]) plru_status[11] <= ~plru_status[11];
        if(|wen[11:10]) plru_status[12] <= ~plru_status[12];
        if(|wen[13:12]) plru_status[13] <= ~plru_status[13];
        if(|wen[15:14]) plru_status[14] <= ~plru_status[14];
    end
    else if(hit)begin
        if(|hit_sel[7:0  ])      plru_status[0 ] <= 1'b1;
        else                     plru_status[0 ] <= 1'b0;

        if(|hit_sel[3:0 ])       plru_status[1 ] <= 1'b1;
        else if(|hit_sel[7:4  ]) plru_status[1 ] <= 1'b0;
        if(|hit_sel[11:8  ])      plru_status[2 ] <= 1'b1;
        else if(|hit_sel[15:12]) plru_status[2 ] <= 1'b0;

        if(|hit_sel[1:0  ])      plru_status[3 ] <= 1'b1;
        else if(|hit_sel[3:2  ]) plru_status[3 ] <= 1'b0;
        if(|hit_sel[5:4  ])      plru_status[4 ] <= 1'b1;
        else if(|hit_sel[7:6  ]) plru_status[4 ] <= 1'b0;
        if(|hit_sel[9:8  ])      plru_status[5 ] <= 1'b1;
        else if(|hit_sel[11:10]) plru_status[5 ] <= 1'b0;
        if(|hit_sel[13:12])      plru_status[6 ] <= 1'b1;
        else if(|hit_sel[15:14]) plru_status[6 ] <= 1'b0;

        if(|hit_sel[0    ])      plru_status[7 ] <= 1'b1;
        else if(|hit_sel[1    ]) plru_status[7 ] <= 1'b0;
        if(|hit_sel[2    ])      plru_status[8 ] <= 1'b1;
        else if(|hit_sel[3    ]) plru_status[8 ] <= 1'b0;
        if(|hit_sel[4    ])      plru_status[9 ] <= 1'b1;
        else if(|hit_sel[5    ]) plru_status[9 ] <= 1'b0;
        if(|hit_sel[6    ])      plru_status[10] <= 1'b1;
        else if(|hit_sel[7    ]) plru_status[10] <= 1'b0;
        if(|hit_sel[8    ])      plru_status[11] <= 1'b1;
        else if(|hit_sel[9    ]) plru_status[11] <= 1'b0;
        if(|hit_sel[10   ])      plru_status[12] <= 1'b1;
        else if(|hit_sel[11   ]) plru_status[12] <= 1'b0;
        if(|hit_sel[12   ])      plru_status[13] <= 1'b1;
        else if(|hit_sel[13   ]) plru_status[13] <= 1'b0;
        if(|hit_sel[14   ])      plru_status[14] <= 1'b1;
        else if(|hit_sel[15   ]) plru_status[14] <= 1'b0;
    end
end

assign plru_l1_wen[0]   = plru_wen        & (!plru_status[0] );
assign plru_l1_wen[1]   = plru_wen        & ( plru_status[0] );
assign plru_l2_wen[0]   = plru_l1_wen[0]  & (!plru_status[1] );
assign plru_l2_wen[1]   = plru_l1_wen[0]  & ( plru_status[1] );
assign plru_l2_wen[2]   = plru_l1_wen[1]  & (!plru_status[2] );
assign plru_l2_wen[3]   = plru_l1_wen[1]  & ( plru_status[2] );
assign plru_l3_wen[0]   = plru_l2_wen[0]  & (!plru_status[3] );
assign plru_l3_wen[1]   = plru_l2_wen[0]  & ( plru_status[3] );
assign plru_l3_wen[2]   = plru_l2_wen[1]  & (!plru_status[4] );
assign plru_l3_wen[3]   = plru_l2_wen[1]  & ( plru_status[4] );
assign plru_l3_wen[4]   = plru_l2_wen[2]  & (!plru_status[5] );
assign plru_l3_wen[5]   = plru_l2_wen[2]  & ( plru_status[5] );
assign plru_l3_wen[6]   = plru_l2_wen[3]  & (!plru_status[6] );
assign plru_l3_wen[7]   = plru_l2_wen[3]  & ( plru_status[6] );
assign wen[0]           = plru_l3_wen[0]  & (!plru_status[7] );
assign wen[1]           = plru_l3_wen[0]  & ( plru_status[7] );
assign wen[2]           = plru_l3_wen[1]  & (!plru_status[8] );
assign wen[3]           = plru_l3_wen[1]  & ( plru_status[8] );
assign wen[4]           = plru_l3_wen[2]  & (!plru_status[9] );
assign wen[5]           = plru_l3_wen[2]  & ( plru_status[9] );
assign wen[6]           = plru_l3_wen[3]  & (!plru_status[10]);
assign wen[7]           = plru_l3_wen[3]  & ( plru_status[10]);
assign wen[8]           = plru_l3_wen[4]  & (!plru_status[11]);
assign wen[9]           = plru_l3_wen[4]  & ( plru_status[11]);
assign wen[10]          = plru_l3_wen[5]  & (!plru_status[12]);
assign wen[11]          = plru_l3_wen[5]  & ( plru_status[12]);
assign wen[12]          = plru_l3_wen[6]  & (!plru_status[13]);
assign wen[13]          = plru_l3_wen[6]  & ( plru_status[13]);
assign wen[14]          = plru_l3_wen[7]  & (!plru_status[14]);
assign wen[15]          = plru_l3_wen[7]  & ( plru_status[14]);

endmodule //plru_16
