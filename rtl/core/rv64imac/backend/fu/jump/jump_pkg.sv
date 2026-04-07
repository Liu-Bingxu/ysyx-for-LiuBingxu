package jump_pkg;


typedef enum logic [8:0]{ 
    op_auipc   = 9'b000000_001,
    op_jal     = 9'b000000_010,
    op_jalr    = 9'b000000_100
}jump_optype_t;

// function automatic logic jump_auipc;
//     input jump_optype_t op;
//     jump_auipc = op[0];
// endfunction

// function automatic logic jump_jal;
//     input jump_optype_t op;
//     jump_jal = op[1];
// endfunction

// function automatic logic jump_jalr;
//     input jump_optype_t op;
//     jump_jalr = op[2];
// endfunction

endpackage
