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

/* verilator lint_off UNUSEDSIGNAL */
function automatic logic load_byte;
    input load_optype_t op;
    load_byte = (op[1:0] == 2'h0);
endfunction

function automatic logic load_half;
    input load_optype_t op;
    load_half = (op[1:0] == 2'h1);
endfunction

function automatic logic load_word;
    input load_optype_t op;
    load_word = (op[1:0] == 2'h2);
endfunction

function automatic logic load_double;
    input load_optype_t op;
    load_double = (op[1:0] == 2'h3);
endfunction

function automatic logic load_signed;
    input load_optype_t op;
    load_signed = (!op[2]);
endfunction

function automatic logic[2:0] load_size;
    input load_optype_t op;
    load_size = {1'b0, op[1:0]};
endfunction

function automatic logic store_byte;
    input store_optype_t op;
    store_byte = (op[1:0] == 2'h0);
endfunction

function automatic logic store_half;
    input store_optype_t op;
    store_half = (op[1:0] == 2'h1);
endfunction

function automatic logic store_word;
    input store_optype_t op;
    store_word = (op[1:0] == 2'h2);
endfunction

function automatic logic store_double;
    input store_optype_t op;
    store_double = (op[1:0] == 2'h3);
endfunction

function automatic logic[2:0] store_size;
    input store_optype_t op;
    store_size = {1'b0, op[1:0]};
endfunction

function automatic logic atomic_word;
    input amo_optype_t op;
    atomic_word = (op[1:0] == 2'h2);
endfunction

function automatic logic atomic_double;
    input amo_optype_t op;
    atomic_double = (op[1:0] == 2'h3);
endfunction

function automatic logic[2:0] atomic_size;
    input amo_optype_t op;
    atomic_size = {1'b0, op[1:0]};
endfunction

function automatic logic atomic_lr;
    input amo_optype_t op;
    atomic_lr = (op[5:2] == 4'h0);
endfunction

function automatic logic atomic_sc;
    input amo_optype_t op;
    atomic_sc = (op[5:2] == 4'h1);
endfunction

function automatic logic atomic_swap;
    input amo_optype_t op;
    atomic_swap = (op[5:2] == 4'h2);
endfunction

function automatic logic atomic_add ;
    input amo_optype_t op;
    atomic_add = (op[5:2] == 4'h3);
endfunction

function automatic logic atomic_xor ;
    input amo_optype_t op;
    atomic_xor = (op[5:2] == 4'h4);
endfunction

function automatic logic atomic_and ;
    input amo_optype_t op;
    atomic_and = (op[5:2] == 4'h5);
endfunction

function automatic logic atomic_or  ;
    input amo_optype_t op;
    atomic_or = (op[5:2] == 4'h6);
endfunction

function automatic logic atomic_min ;
    input amo_optype_t op;
    atomic_min = (op[5:2] == 4'h7);
endfunction

function automatic logic atomic_max ;
    input amo_optype_t op;
    atomic_max = (op[5:2] == 4'h8);
endfunction

function automatic logic atomic_minu;
    input amo_optype_t op;
    atomic_minu = (op[5:2] == 4'h9);
endfunction

function automatic logic atomic_maxu;
    input amo_optype_t op;
    atomic_maxu = (op[5:2] == 4'hA);
endfunction


/* verilator lint_on UNUSEDSIGNAL */

function automatic logic addrcache;
    input logic [63:0] waddr;

    assign addrcache = (waddr >= 64'h8000_0000) & (waddr < 64'h9fff_ffff);

endfunction

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
