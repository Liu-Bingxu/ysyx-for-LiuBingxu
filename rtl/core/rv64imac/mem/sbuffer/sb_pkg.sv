package sb_pkg;

localparam sb_line_bit  = 3;
localparam sb_line      = 2 ** sb_line_bit;
localparam sb_send_th   = 4;

localparam SB_LINE_W = 60 + 16 + 128;
typedef struct packed {
    logic [59:0]    line_addr;
    logic [15:0]    line_strb;
    logic [127:0]   line;
} StoreBufferline;

endpackage
