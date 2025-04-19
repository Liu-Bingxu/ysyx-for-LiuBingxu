module crc32 (
    input           clk,
    input           rst_n,
    input           flush,
    input           data_en,
    input  [7:0]    data_in,
    output [31:0]   crc_out_next,
    output [31:0]   crc_out
);

wire [7:0]  data_t;

reg  [31:0] crc;
wire [31:0] crc_next;

assign data_t = {data_in[0], data_in[1], data_in[2], data_in[3], 
                data_in[4], data_in[5], data_in[6], data_in[7]};

//CRC32的生成多项式为：G(x)= x^32 + x^26 + x^23 + x^22 + x^16 + x^12 + x^11 
//+ x^10 + x^8 + x^7 + x^5 + x^4 + x^2 + x^1 + 1

assign crc_next[0] = crc[24] ^ crc[30] ^ data_t[0] ^ data_t[6];
assign crc_next[1] = crc[24] ^ crc[25] ^ crc[30] ^ crc[31] 
                        ^ data_t[0] ^ data_t[1] ^ data_t[6] ^ data_t[7];
assign crc_next[2] = crc[24] ^ crc[25] ^ crc[26] ^ crc[30] 
                        ^ crc[31] ^ data_t[0] ^ data_t[1] ^ data_t[2] ^ data_t[6] 
                        ^ data_t[7];
assign crc_next[3] = crc[25] ^ crc[26] ^ crc[27] ^ crc[31] 
                        ^ data_t[1] ^ data_t[2] ^ data_t[3] ^ data_t[7];
assign crc_next[4] = crc[24] ^ crc[26] ^ crc[27] ^ crc[28] 
                        ^ crc[30] ^ data_t[0] ^ data_t[2] ^ data_t[3] ^ data_t[4] 
                        ^ data_t[6];
assign crc_next[5] = crc[24] ^ crc[25] ^ crc[27] ^ crc[28] 
                        ^ crc[29] ^ crc[30] ^ crc[31] ^ data_t[0] 
                        ^ data_t[1] ^ data_t[3] ^ data_t[4] ^ data_t[5] ^ data_t[6] 
                        ^ data_t[7];
assign crc_next[6] = crc[25] ^ crc[26] ^ crc[28] ^ crc[29] 
                        ^ crc[30] ^ crc[31] ^ data_t[1] ^ data_t[2] ^ data_t[4] 
                        ^ data_t[5] ^ data_t[6] ^ data_t[7];
assign crc_next[7] = crc[24] ^ crc[26] ^ crc[27] ^ crc[29] 
                        ^ crc[31] ^ data_t[0] ^ data_t[2] ^ data_t[3] ^ data_t[5] 
                        ^ data_t[7];
assign crc_next[8] = crc[0] ^ crc[24] ^ crc[25] ^ crc[27] 
                        ^ crc[28] ^ data_t[0] ^ data_t[1] ^ data_t[3] ^ data_t[4];
assign crc_next[9] = crc[1] ^ crc[25] ^ crc[26] ^ crc[28] 
                        ^ crc[29] ^ data_t[1] ^ data_t[2] ^ data_t[4] ^ data_t[5];
assign crc_next[10] = crc[2] ^ crc[24] ^ crc[26] ^ crc[27] 
                        ^ crc[29] ^ data_t[0] ^ data_t[2] ^ data_t[3] ^ data_t[5];
assign crc_next[11] = crc[3] ^ crc[24] ^ crc[25] ^ crc[27] 
                        ^ crc[28] ^ data_t[0] ^ data_t[1] ^ data_t[3] ^ data_t[4];
assign crc_next[12] = crc[4] ^ crc[24] ^ crc[25] ^ crc[26] 
                        ^ crc[28] ^ crc[29] ^ crc[30] ^ data_t[0] 
                        ^ data_t[1] ^ data_t[2] ^ data_t[4] ^ data_t[5] ^ data_t[6];
assign crc_next[13] = crc[5] ^ crc[25] ^ crc[26] ^ crc[27] 
                        ^ crc[29] ^ crc[30] ^ crc[31] ^ data_t[1] 
                        ^ data_t[2] ^ data_t[3] ^ data_t[5] ^ data_t[6] ^ data_t[7];
assign crc_next[14] = crc[6] ^ crc[26] ^ crc[27] ^ crc[28] 
                        ^ crc[30] ^ crc[31] ^ data_t[2] ^ data_t[3] ^ data_t[4]
                        ^ data_t[6] ^ data_t[7];
assign crc_next[15] =  crc[7] ^ crc[27] ^ crc[28] ^ crc[29]
                        ^ crc[31] ^ data_t[3] ^ data_t[4] ^ data_t[5] ^ data_t[7];
assign crc_next[16] = crc[8] ^ crc[24] ^ crc[28] ^ crc[29] 
                        ^ data_t[0] ^ data_t[4] ^ data_t[5];
assign crc_next[17] = crc[9] ^ crc[25] ^ crc[29] ^ crc[30] 
                        ^ data_t[1] ^ data_t[5] ^ data_t[6];
assign crc_next[18] = crc[10] ^ crc[26] ^ crc[30] ^ crc[31] 
                        ^ data_t[2] ^ data_t[6] ^ data_t[7];
assign crc_next[19] = crc[11] ^ crc[27] ^ crc[31] ^ data_t[3] ^ data_t[7];
assign crc_next[20] = crc[12] ^ crc[28] ^ data_t[4];
assign crc_next[21] = crc[13] ^ crc[29] ^ data_t[5];
assign crc_next[22] = crc[14] ^ crc[24] ^ data_t[0];
assign crc_next[23] = crc[15] ^ crc[24] ^ crc[25] ^ crc[30] 
                        ^ data_t[0] ^ data_t[1] ^ data_t[6];
assign crc_next[24] = crc[16] ^ crc[25] ^ crc[26] ^ crc[31] 
                        ^ data_t[1] ^ data_t[2] ^ data_t[7];
assign crc_next[25] = crc[17] ^ crc[26] ^ crc[27] ^ data_t[2] ^ data_t[3];
assign crc_next[26] = crc[18] ^ crc[24] ^ crc[27] ^ crc[28] 
                        ^ crc[30] ^ data_t[0] ^ data_t[3] ^ data_t[4] ^ data_t[6];
assign crc_next[27] = crc[19] ^ crc[25] ^ crc[28] ^ crc[29] 
                        ^ crc[31] ^ data_t[1] ^ data_t[4] ^ data_t[5] ^ data_t[7];
assign crc_next[28] = crc[20] ^ crc[26] ^ crc[29] ^ crc[30] 
                        ^ data_t[2] ^ data_t[5] ^ data_t[6];
assign crc_next[29] = crc[21] ^ crc[27] ^ crc[30] ^ crc[31] 
                        ^ data_t[3] ^ data_t[6] ^ data_t[7];
assign crc_next[30] = crc[22] ^ crc[28] ^ crc[31] ^ data_t[4] ^ data_t[7];
assign crc_next[31] = crc[23] ^ crc[29] ^ data_t[5];

always @(posedge clk or negedge rst_n) begin
    if(!rst_n)begin
        crc <= 32'hffff_ffff;
    end
    else if(flush)begin
        crc <= 32'hffff_ffff;
    end
    else if(data_en)begin
        crc <= crc_next;
    end
end

assign crc_out[31:24]   = { ~crc[24], ~crc[25], ~crc[26], ~crc[27], 
                            ~crc[28], ~crc[29], ~crc[30], ~crc[31]};
assign crc_out[23:16]   = { ~crc[16], ~crc[17], ~crc[18], ~crc[19], 
                            ~crc[20], ~crc[21], ~crc[22], ~crc[23]};
assign crc_out[15:8]    = { ~crc[8],  ~crc[9],  ~crc[10], ~crc[11], 
                            ~crc[12], ~crc[13], ~crc[14], ~crc[15]};
assign crc_out[7:0]     = { ~crc[0],  ~crc[1],  ~crc[2],  ~crc[3], 
                            ~crc[4],  ~crc[5],  ~crc[6],  ~crc[7]};

assign crc_out_next[31:24]   = { ~crc_next[24], ~crc_next[25], ~crc_next[26], ~crc_next[27], 
                                ~crc_next[28], ~crc_next[29], ~crc_next[30], ~crc_next[31]};
assign crc_out_next[23:16]   = { ~crc_next[16], ~crc_next[17], ~crc_next[18], ~crc_next[19], 
                                ~crc_next[20], ~crc_next[21], ~crc_next[22], ~crc_next[23]};
assign crc_out_next[15:8]    = { ~crc_next[8],  ~crc_next[9],  ~crc_next[10], ~crc_next[11], 
                                ~crc_next[12], ~crc_next[13], ~crc_next[14], ~crc_next[15]};
assign crc_out_next[7:0]     = { ~crc_next[0],  ~crc_next[1],  ~crc_next[2],  ~crc_next[3], 
                                ~crc_next[4],  ~crc_next[5],  ~crc_next[6],  ~crc_next[7]};

endmodule //crc32
