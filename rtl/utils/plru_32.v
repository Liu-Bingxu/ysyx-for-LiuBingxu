module plru_32 (
    input                   clk,
    input                   rst_n,

    input                   hit,
    input  [31:0]           hit_sel,
    input                   plru_wen,
    output [31:0]           wen
);

reg  [30:0]             plru_status;

wire [1:0]              plru_l1_wen;
wire [3:0]              plru_l2_wen;
wire [7:0]              plru_l3_wen;
wire [15:0]             plru_l4_wen;

always @(posedge clk or negedge rst_n) begin
    if(!rst_n)begin
        plru_status <= 31'h0;
    end
    else if(plru_wen)begin
                        plru_status[0 ] <= ~plru_status[0 ];

        if(|wen[15:0 ]) plru_status[1 ] <= ~plru_status[1 ];
        if(|wen[31:16]) plru_status[2 ] <= ~plru_status[2 ];

        if(|wen[7:0  ]) plru_status[3 ] <= ~plru_status[3 ];
        if(|wen[15:8 ]) plru_status[4 ] <= ~plru_status[4 ];
        if(|wen[23:16]) plru_status[5 ] <= ~plru_status[5 ];
        if(|wen[31:24]) plru_status[6 ] <= ~plru_status[6 ];

        if(|wen[3:0  ]) plru_status[7 ] <= ~plru_status[7 ];
        if(|wen[7:4  ]) plru_status[8 ] <= ~plru_status[8 ];
        if(|wen[11:8 ]) plru_status[9 ] <= ~plru_status[9 ];
        if(|wen[15:12]) plru_status[10] <= ~plru_status[10];
        if(|wen[19:16]) plru_status[11] <= ~plru_status[11];
        if(|wen[23:20]) plru_status[12] <= ~plru_status[12];
        if(|wen[27:24]) plru_status[13] <= ~plru_status[13];
        if(|wen[31:28]) plru_status[14] <= ~plru_status[14];

        if(|wen[1:0  ]) plru_status[15] <= ~plru_status[15];
        if(|wen[3:2  ]) plru_status[16] <= ~plru_status[16];
        if(|wen[5:4  ]) plru_status[17] <= ~plru_status[17];
        if(|wen[7:6  ]) plru_status[18] <= ~plru_status[18];
        if(|wen[9:8  ]) plru_status[19] <= ~plru_status[19];
        if(|wen[11:10]) plru_status[20] <= ~plru_status[20];
        if(|wen[13:12]) plru_status[21] <= ~plru_status[21];
        if(|wen[15:14]) plru_status[22] <= ~plru_status[22];
        if(|wen[17:16]) plru_status[23] <= ~plru_status[23];
        if(|wen[19:18]) plru_status[24] <= ~plru_status[24];
        if(|wen[21:20]) plru_status[25] <= ~plru_status[25];
        if(|wen[23:22]) plru_status[26] <= ~plru_status[26];
        if(|wen[25:24]) plru_status[27] <= ~plru_status[27];
        if(|wen[27:26]) plru_status[28] <= ~plru_status[28];
        if(|wen[29:28]) plru_status[29] <= ~plru_status[29];
        if(|wen[31:30]) plru_status[30] <= ~plru_status[30];
    end
    else if(hit)begin
        if(|hit_sel[15:0 ])      plru_status[0 ] <= 1'b1;
        else                     plru_status[0 ] <= 1'b0;

        if(|hit_sel[7:0 ])       plru_status[1 ] <= 1'b1;
        else if(|hit_sel[15:8 ]) plru_status[1 ] <= 1'b0;
        if(|hit_sel[23:16])      plru_status[2 ] <= 1'b1;
        else if(|hit_sel[31:24]) plru_status[2 ] <= 1'b0;

        if(|hit_sel[3:0  ])      plru_status[3 ] <= 1'b1;
        else if(|hit_sel[7:4  ]) plru_status[3 ] <= 1'b0;
        if(|hit_sel[11:8 ])      plru_status[4 ] <= 1'b1;
        else if(|hit_sel[15:12]) plru_status[4 ] <= 1'b0;
        if(|hit_sel[19:16])      plru_status[5 ] <= 1'b1;
        else if(|hit_sel[23:20]) plru_status[5 ] <= 1'b0;
        if(|hit_sel[27:24])      plru_status[6 ] <= 1'b1;
        else if(|hit_sel[31:28]) plru_status[6 ] <= 1'b0;

        if(|hit_sel[1:0  ])      plru_status[7 ] <= 1'b1;
        else if(|hit_sel[3:2  ]) plru_status[7 ] <= 1'b0;
        if(|hit_sel[5:4  ])      plru_status[8 ] <= 1'b1;
        else if(|hit_sel[7:6  ]) plru_status[8 ] <= 1'b0;
        if(|hit_sel[9:8  ])      plru_status[9 ] <= 1'b1;
        else if(|hit_sel[11:10]) plru_status[9 ] <= 1'b0;
        if(|hit_sel[13:12])      plru_status[10] <= 1'b1;
        else if(|hit_sel[15:14]) plru_status[10] <= 1'b0;
        if(|hit_sel[17:16])      plru_status[11] <= 1'b1;
        else if(|hit_sel[19:18]) plru_status[11] <= 1'b0;
        if(|hit_sel[21:20])      plru_status[12] <= 1'b1;
        else if(|hit_sel[23:22]) plru_status[12] <= 1'b0;
        if(|hit_sel[25:24])      plru_status[13] <= 1'b1;
        else if(|hit_sel[27:26]) plru_status[13] <= 1'b0;
        if(|hit_sel[29:28])      plru_status[14] <= 1'b1;
        else if(|hit_sel[31:30]) plru_status[14] <= 1'b0;

        if(|hit_sel[0    ])      plru_status[15] <= 1'b1;
        else if(|hit_sel[1    ]) plru_status[15] <= 1'b0;
        if(|hit_sel[2    ])      plru_status[16] <= 1'b1;
        else if(|hit_sel[3    ]) plru_status[16] <= 1'b0;
        if(|hit_sel[4    ])      plru_status[17] <= 1'b1;
        else if(|hit_sel[5    ]) plru_status[17] <= 1'b0;
        if(|hit_sel[6    ])      plru_status[18] <= 1'b1;
        else if(|hit_sel[7    ]) plru_status[18] <= 1'b0;
        if(|hit_sel[8    ])      plru_status[19] <= 1'b1;
        else if(|hit_sel[9    ]) plru_status[19] <= 1'b0;
        if(|hit_sel[10   ])      plru_status[20] <= 1'b1;
        else if(|hit_sel[11   ]) plru_status[20] <= 1'b0;
        if(|hit_sel[12   ])      plru_status[21] <= 1'b1;
        else if(|hit_sel[13   ]) plru_status[21] <= 1'b0;
        if(|hit_sel[14   ])      plru_status[22] <= 1'b1;
        else if(|hit_sel[15   ]) plru_status[22] <= 1'b0;
        if(|hit_sel[16   ])      plru_status[23] <= 1'b1;
        else if(|hit_sel[17   ]) plru_status[23] <= 1'b0;
        if(|hit_sel[18   ])      plru_status[24] <= 1'b1;
        else if(|hit_sel[19   ]) plru_status[24] <= 1'b0;
        if(|hit_sel[20   ])      plru_status[25] <= 1'b1;
        else if(|hit_sel[21   ]) plru_status[25] <= 1'b0;
        if(|hit_sel[22   ])      plru_status[26] <= 1'b1;
        else if(|hit_sel[23   ]) plru_status[26] <= 1'b0;
        if(|hit_sel[24   ])      plru_status[27] <= 1'b1;
        else if(|hit_sel[25   ]) plru_status[27] <= 1'b0;
        if(|hit_sel[26   ])      plru_status[28] <= 1'b1;
        else if(|hit_sel[27   ]) plru_status[28] <= 1'b0;
        if(|hit_sel[28   ])      plru_status[29] <= 1'b1;
        else if(|hit_sel[29   ]) plru_status[29] <= 1'b0;
        if(|hit_sel[30   ])      plru_status[30] <= 1'b1;
        else if(|hit_sel[31   ]) plru_status[30] <= 1'b0;
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
assign plru_l4_wen[0]   = plru_l3_wen[0]  & (!plru_status[7] );
assign plru_l4_wen[1]   = plru_l3_wen[0]  & ( plru_status[7] );
assign plru_l4_wen[2]   = plru_l3_wen[1]  & (!plru_status[8] );
assign plru_l4_wen[3]   = plru_l3_wen[1]  & ( plru_status[8] );
assign plru_l4_wen[4]   = plru_l3_wen[2]  & (!plru_status[9] );
assign plru_l4_wen[5]   = plru_l3_wen[2]  & ( plru_status[9] );
assign plru_l4_wen[6]   = plru_l3_wen[3]  & (!plru_status[10]);
assign plru_l4_wen[7]   = plru_l3_wen[3]  & ( plru_status[10]);
assign plru_l4_wen[8]   = plru_l3_wen[4]  & (!plru_status[11]);
assign plru_l4_wen[9]   = plru_l3_wen[4]  & ( plru_status[11]);
assign plru_l4_wen[10]  = plru_l3_wen[5]  & (!plru_status[12]);
assign plru_l4_wen[11]  = plru_l3_wen[5]  & ( plru_status[12]);
assign plru_l4_wen[12]  = plru_l3_wen[6]  & (!plru_status[13]);
assign plru_l4_wen[13]  = plru_l3_wen[6]  & ( plru_status[13]);
assign plru_l4_wen[14]  = plru_l3_wen[7]  & (!plru_status[14]);
assign plru_l4_wen[15]  = plru_l3_wen[7]  & ( plru_status[14]);
assign wen[0]           = plru_l4_wen[0]  & (!plru_status[15]);
assign wen[1]           = plru_l4_wen[0]  & ( plru_status[15]);
assign wen[2]           = plru_l4_wen[1]  & (!plru_status[16]);
assign wen[3]           = plru_l4_wen[1]  & ( plru_status[16]);
assign wen[4]           = plru_l4_wen[2]  & (!plru_status[17]);
assign wen[5]           = plru_l4_wen[2]  & ( plru_status[17]);
assign wen[6]           = plru_l4_wen[3]  & (!plru_status[18]);
assign wen[7]           = plru_l4_wen[3]  & ( plru_status[18]);
assign wen[8]           = plru_l4_wen[4]  & (!plru_status[19]);
assign wen[9]           = plru_l4_wen[4]  & ( plru_status[19]);
assign wen[10]          = plru_l4_wen[5]  & (!plru_status[20]);
assign wen[11]          = plru_l4_wen[5]  & ( plru_status[20]);
assign wen[12]          = plru_l4_wen[6]  & (!plru_status[21]);
assign wen[13]          = plru_l4_wen[6]  & ( plru_status[21]);
assign wen[14]          = plru_l4_wen[7]  & (!plru_status[22]);
assign wen[15]          = plru_l4_wen[7]  & ( plru_status[22]);
assign wen[16]          = plru_l4_wen[8]  & (!plru_status[23]);
assign wen[17]          = plru_l4_wen[8]  & ( plru_status[23]);
assign wen[18]          = plru_l4_wen[9]  & (!plru_status[24]);
assign wen[19]          = plru_l4_wen[9]  & ( plru_status[24]);
assign wen[20]          = plru_l4_wen[10] & (!plru_status[25]);
assign wen[21]          = plru_l4_wen[10] & ( plru_status[25]);
assign wen[22]          = plru_l4_wen[11] & (!plru_status[26]);
assign wen[23]          = plru_l4_wen[11] & ( plru_status[26]);
assign wen[24]          = plru_l4_wen[12] & (!plru_status[27]);
assign wen[25]          = plru_l4_wen[12] & ( plru_status[27]);
assign wen[26]          = plru_l4_wen[13] & (!plru_status[28]);
assign wen[27]          = plru_l4_wen[13] & ( plru_status[28]);
assign wen[28]          = plru_l4_wen[14] & (!plru_status[29]);
assign wen[29]          = plru_l4_wen[14] & ( plru_status[29]);
assign wen[30]          = plru_l4_wen[15] & (!plru_status[30]);
assign wen[31]          = plru_l4_wen[15] & ( plru_status[30]);

endmodule //plru_32
