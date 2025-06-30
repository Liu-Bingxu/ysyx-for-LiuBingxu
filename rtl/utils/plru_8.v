module plru_8 (
    input                   clk,
    input                   rst_n,

    input                   hit,
    input  [7:0]            hit_sel,
    input                   plru_wen,
    output [7:0]            wen
);

reg  [6:0]              plru_status;

wire [1:0]              plru_l1_wen;
wire [3:0]              plru_l2_wen;

always @(posedge clk or negedge rst_n) begin
    if(!rst_n)begin
        plru_status <= 7'h0;
    end
    else if(plru_wen)begin
                        plru_status[0 ] <= ~plru_status[0 ];

        if(|wen[3:0])   plru_status[1 ] <= ~plru_status[1 ];
        if(|wen[7:4])   plru_status[2 ] <= ~plru_status[2 ];

        if(|wen[1:0])   plru_status[3 ] <= ~plru_status[3 ];
        if(|wen[3:2])   plru_status[4 ] <= ~plru_status[4 ];
        if(|wen[5:4])   plru_status[5 ] <= ~plru_status[5 ];
        if(|wen[7:6])   plru_status[6 ] <= ~plru_status[6 ];
    end
    else if(hit)begin
        if(|hit_sel[3:0 ])      plru_status[0 ] <= 1'b1;
        else                    plru_status[0 ] <= 1'b0;

        if(|hit_sel[1:0])       plru_status[1 ] <= 1'b1;
        else if(|hit_sel[3:2])  plru_status[1 ] <= 1'b0;
        if(|hit_sel[5:4])       plru_status[2 ] <= 1'b1;
        else if(|hit_sel[7:6])  plru_status[2 ] <= 1'b0;

        if(hit_sel[0])          plru_status[3 ] <= 1'b1;
        else if(hit_sel[1])     plru_status[3 ] <= 1'b0;
        if(hit_sel[2])          plru_status[4 ] <= 1'b1;
        else if(hit_sel[3])     plru_status[4 ] <= 1'b0;
        if(hit_sel[4])          plru_status[5 ] <= 1'b1;
        else if(hit_sel[5])     plru_status[5 ] <= 1'b0;
        if(hit_sel[6])          plru_status[6 ] <= 1'b1;
        else if(hit_sel[7])     plru_status[6 ] <= 1'b0;
    end
end

assign plru_l1_wen[0]   = plru_wen        & (!plru_status[0]);
assign plru_l1_wen[1]   = plru_wen        & ( plru_status[0]);
assign plru_l2_wen[0]   = plru_l1_wen[0]  & (!plru_status[1]);
assign plru_l2_wen[1]   = plru_l1_wen[0]  & ( plru_status[1]);
assign plru_l2_wen[2]   = plru_l1_wen[1]  & (!plru_status[2]);
assign plru_l2_wen[3]   = plru_l1_wen[1]  & ( plru_status[2]);
assign wen[0]           = plru_l2_wen[0]  & (!plru_status[3]);
assign wen[1]           = plru_l2_wen[0]  & ( plru_status[3]);
assign wen[2]           = plru_l2_wen[1]  & (!plru_status[4]);
assign wen[3]           = plru_l2_wen[1]  & ( plru_status[4]);
assign wen[4]           = plru_l2_wen[2]  & (!plru_status[5]);
assign wen[5]           = plru_l2_wen[2]  & ( plru_status[5]);
assign wen[6]           = plru_l2_wen[3]  & (!plru_status[6]);
assign wen[7]           = plru_l2_wen[3]  & ( plru_status[6]);

endmodule //plru_8

