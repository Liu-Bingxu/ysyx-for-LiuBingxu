module gen_redirect(
    // interface with rob
    input                   rob_commit_valid,
    input  [63:0]           rob_commit_next_pc,

    input                   rob_gen_redirect_valid,
    input                   rob_gen_redirect_bp_miss,
    input                   rob_gen_redirect_call,
    input                   rob_gen_redirect_ret,
    input                   rob_gen_redirect_end,
    input  [63:0]           rob_gen_redirect_target,

    //interface with csr
    input                   interrupt_happen,
    input                   csr_jump_flag,
    input  [63:0]           csr_jump_addr,

    output                  redirect,

    output                  commit_ftq_valid,
    output                  commit_end,
    output                  jump_restore_valid,
    output                  jump_other_valid,
    output                  jump_call,
    output                  jump_ret,
    output [63:0]           jump_target,
    output [63:0]           jump_push_pc
);

assign redirect             = (rob_gen_redirect_valid | csr_jump_flag);
assign commit_ftq_valid     = rob_commit_valid & (!interrupt_happen);
assign commit_end           = rob_gen_redirect_end;
assign jump_restore_valid   = (rob_gen_redirect_valid & rob_gen_redirect_bp_miss & (!csr_jump_flag));
assign jump_other_valid     = ((rob_gen_redirect_valid & (!rob_gen_redirect_bp_miss)) | csr_jump_flag);
assign jump_call            = rob_gen_redirect_call;
assign jump_ret             = rob_gen_redirect_ret;
assign jump_target          = (csr_jump_flag) ? csr_jump_addr : rob_gen_redirect_target;
assign jump_push_pc         = rob_commit_next_pc;

endmodule //gen_redirect
