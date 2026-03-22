package mem_pkg;

typedef enum logic [8:0]{ 
    // | unsigned flag 1 bit | load size 2 bit |
    op_lb  = 9'b000000_000,
    op_lh  = 9'b000000_001,
    op_lw  = 9'b000000_010,
    op_ld  = 9'b000000_011,
    op_lbu = 9'b000000_100,
    op_lhu = 9'b000000_101,
    op_lwu = 9'b000000_110
}load_optype_t;

typedef enum logic [8:0]{ 
    // store size 
    op_sb = 9'b000000_000,
    op_sh = 9'b000000_001,
    op_sw = 9'b000000_010,
    op_sd = 9'b000000_011
}store_optype_t;

typedef enum logic [8:0]{ 
    // | encoding | amo size |
    op_lr_w         = 9'b000_0000_10,
    op_sc_w         = 9'b000_0001_10,
    op_amoswap_w    = 9'b000_0010_10,
    op_amoadd_w     = 9'b000_0011_10,
    op_amoxor_w     = 9'b000_0100_10,
    op_amoand_w     = 9'b000_0101_10,
    op_amoor_w      = 9'b000_0110_10,
    op_amomin_w     = 9'b000_0111_10,
    op_amomax_w     = 9'b000_1000_10,
    op_amominu_w    = 9'b000_1001_10,
    op_amomaxu_w    = 9'b000_1010_10,
    op_lr_d         = 9'b000_0000_11,
    op_sc_d         = 9'b000_0001_11,
    op_amoswap_d    = 9'b000_0010_11,
    op_amoadd_d     = 9'b000_0011_11,
    op_amoxor_d     = 9'b000_0100_11,
    op_amoand_d     = 9'b000_0101_11,
    op_amoor_d      = 9'b000_0110_11,
    op_amomin_d     = 9'b000_0111_11,
    op_amomax_d     = 9'b000_1000_11,
    op_amominu_d    = 9'b000_1001_11,
    op_amomaxu_d    = 9'b000_1010_11
}amo_optype_t;

`define load_byte(load_op) (load_op[1:0] == 2'h0)

`define load_half(load_op) (load_op[1:0] == 2'h1)

`define load_word(load_op) (load_op[1:0] == 2'h2)

`define load_double(load_op) (load_op[1:0] == 2'h3)

`define load_signed(load_op) (!load_op[2])

`define load_size(load_op) {1'b0, load_op[1:0]}

`define store_byte(store_op) (store_op[1:0] == 2'h0)

`define store_half(store_op) (store_op[1:0] == 2'h1)

`define store_word(store_op) (store_op[1:0] == 2'h2)

`define store_double(store_op) (store_op[1:0] == 2'h3)

`define store_size(store_op) {1'b0, store_op[1:0]}

`define atomic_word(atomic_op) (atomic_op[1:0] == 2'h2)

`define atomic_double(atomic_op) (atomic_op[1:0] == 2'h3)

`define atomic_size(atomic_op) {1'b0, atomic_op[1:0]}

`define atomic_lr(atomic_op) (atomic_op[5:2] == 4'h0)

`define atomic_sc(atomic_op) (atomic_op[5:2] == 4'h1)

`define atomic_swap(atomic_op) (atomic_op[5:2] == 4'h2)

`define atomic_add(atomic_op) (atomic_op[5:2] == 4'h3)

`define atomic_xor(atomic_op) (atomic_op[5:2] == 4'h4)

`define atomic_and(atomic_op) (atomic_op[5:2] == 4'h5)

`define atomic_or(atomic_op) (atomic_op[5:2] == 4'h6)

`define atomic_min(atomic_op) (atomic_op[5:2] == 4'h7)

`define atomic_max(atomic_op) (atomic_op[5:2] == 4'h8)

`define atomic_minu(atomic_op) (atomic_op[5:2] == 4'h9)

`define atomic_maxu(atomic_op) (atomic_op[5:2] == 4'hA)

`define addrcache(addr) ((addr >= 64'h8000_0000) & (addr < 64'h9fff_ffff))

function automatic logic [63:0] data_splicing_64;
    input logic [63:0] data_init;
    input logic [63:0] data_merge;
    input logic [7:0]  data_strb;

        //! 由于不好作参数化，所以用此行为级建模
    integer i;
    data_splicing_64 = 0;
    for(i = 0; i < 8; i = i + 1)begin
        data_splicing_64[8 * i + 7 -: 8] = (data_strb[i]) ? data_merge[8 * i + 7 -: 8] : data_init[8 * i + 7 -: 8];
    end

endfunction


endpackage
