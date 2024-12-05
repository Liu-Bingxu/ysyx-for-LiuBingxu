module async_fifo #(
    parameter DATA_LEN      = 64,
    parameter ADDR_LEN      = 3,
    parameter READ_THROUGH  = "TRUE"
) (
    input                       clk_w,
    input                       rstn_w,
    output                      full_f,
    output                      empty_t,
    input                       wen,
    input  [ DATA_LEN - 1 : 0 ] data_in,

    input                       clk_r,
    input                       rstn_r,
    output                      full_t,
    output                      empty_f,
    input                       ren,
    output [ DATA_LEN - 1 : 0 ] data_out
);

localparam RAM_SIZE = 2 ** ADDR_LEN;

reg  [ ADDR_LEN : 0] w_ptr, r_ptr;
wire [ ADDR_LEN : 0] w_ptr_gray, r_ptr_gray;
wire [ ADDR_LEN : 0] w_ptr_gray_temp, r_ptr_gray_temp;
wire [ ADDR_LEN : 0] w_ptr_gray_sync, r_ptr_gray_sync;

reg  [DATA_LEN - 1 : 0] ram [RAM_SIZE - 1 : 0];

always @(posedge clk_w or negedge rstn_w) begin
    if(!rstn_w)begin
        w_ptr   <= {(ADDR_LEN + 1){1'b0}};
    end
    else if(wen & (!full_f))begin
        w_ptr   <= w_ptr + 1'b1;
    end
end

always @(posedge clk_r or negedge rstn_r) begin
    if(!rstn_r)begin
        r_ptr   <= {(ADDR_LEN + 1){1'b0}};
    end
    else if(ren & (!empty_f))begin
        r_ptr   <= r_ptr + 1'b1;
    end
end

always @(posedge clk_w) begin
    if(wen & (!full_f))begin
        ram[w_ptr[ADDR_LEN - 1 : 0]] <= data_in;
    end
end

generate 
    if(READ_THROUGH == "TRUE") begin : read_through
        assign data_out = ram[r_ptr[ADDR_LEN - 1 : 0]];
    end
    else begin : read_tick
        reg [DATA_LEN -1 : 0] data_r;
        always @(posedge clk_r) begin
            if(ren & (!empty_f))begin
                data_r  <= ram[r_ptr[ADDR_LEN - 1 : 0]];
            end
        end
        assign data_out = data_r;
    end
endgenerate

FF_D_without_wen #(.DATA_LEN ( ADDR_LEN + 1 ), .RST_DATA ( 0 ))                  w_ptr_gray_ff  (.clk ( clk_w ), .rst_n ( rstn_w ), .data_in ( w_ptr_gray      ), .data_out ( w_ptr_gray_temp ) );
general_sync     #(.DATA_LEN ( ADDR_LEN + 1 ), .RST_DATA ( 0 ), .CHAIN_LV ( 2 )) w_gray_sync    (.clk ( clk_r ), .rst_n ( rstn_r ), .data_in ( w_ptr_gray_temp ), .data_out ( w_ptr_gray_sync ) );
FF_D_without_wen #(.DATA_LEN ( ADDR_LEN + 1 ), .RST_DATA ( 0 ))                  r_ptr_gray_ff  (.clk ( clk_r ), .rst_n ( rstn_r ), .data_in ( r_ptr_gray      ), .data_out ( r_ptr_gray_temp ) );
general_sync     #(.DATA_LEN ( ADDR_LEN + 1 ), .RST_DATA ( 0 ), .CHAIN_LV ( 2 )) r_gray_sync    (.clk ( clk_w ), .rst_n ( rstn_w ), .data_in ( r_ptr_gray_temp ), .data_out ( r_ptr_gray_sync ) );

assign w_ptr_gray = {w_ptr[ADDR_LEN], (w_ptr[ ADDR_LEN -1 : 0 ] ^ w_ptr[ ADDR_LEN : 1])};
assign r_ptr_gray = {r_ptr[ADDR_LEN], (r_ptr[ ADDR_LEN -1 : 0 ] ^ r_ptr[ ADDR_LEN : 1])};

generate 
    if(ADDR_LEN == 1) begin : full_gen_special
        assign full_t = (w_ptr_gray_sync[ADDR_LEN : ADDR_LEN - 1] == ~r_ptr_gray[ADDR_LEN : ADDR_LEN - 1]); 
        assign full_f = (r_ptr_gray_sync[ADDR_LEN : ADDR_LEN - 1] == ~w_ptr_gray[ADDR_LEN : ADDR_LEN - 1]); 
    end
    else begin : full_gen_normal
        assign full_t = ((w_ptr_gray_sync[ADDR_LEN : ADDR_LEN - 1] == ~r_ptr_gray[ADDR_LEN : ADDR_LEN - 1]) & (w_ptr_gray_sync[ADDR_LEN - 2 : 0] == r_ptr_gray[ADDR_LEN - 2 : 0])); 
        assign full_f = ((r_ptr_gray_sync[ADDR_LEN : ADDR_LEN - 1] == ~w_ptr_gray[ADDR_LEN : ADDR_LEN - 1]) & (r_ptr_gray_sync[ADDR_LEN - 2 : 0] == w_ptr_gray[ADDR_LEN - 2 : 0])); 
    end
endgenerate
assign empty_t = (r_ptr_gray_sync == w_ptr_gray);
assign empty_f = (w_ptr_gray_sync == r_ptr_gray);

endmodule //async_fifo
