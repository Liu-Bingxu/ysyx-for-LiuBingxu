`ifndef __MACRO_FUNC_DEFINE__
`define __MACRO_FUNC_DEFINE__

//============================fu_type_macro=======================================================
`define send2alu(fu_type) (fu_type == fu_alu)

`define send2csr(fu_type) ((fu_type == fu_csr) | (fu_type == fu_fence))

`define send2jmp(fu_type) ((fu_type == fu_bru) | (fu_type == fu_jump))

`define send2mul(fu_type) (fu_type == fu_mul)

`define send2div(fu_type) (fu_type == fu_div)

`define send2load(fu_type) (fu_type == fu_load)

`define send2store(fu_type) (fu_type == fu_store)

`define send2amo(fu_type) (fu_type == fu_amo)

//! 移除对load的提前完成，考虑load不写入的情况下，可能会出现异常和对mmio读取产生副作用
`define use_wdest(fu_type) ((fu_type == fu_alu) | (fu_type == fu_div) | (fu_type == fu_mul))
//============================fu_type_macro=======================================================

//============================alu_op_macro========================================================
`define shift_word(alu_op) alu_op[2]

`define shift_al(alu_op) alu_op[1]

`define shift_lr(alu_op) alu_op[0]

`define logic_and(alu_op) alu_op[0]

`define logic_or(alu_op) alu_op[1]

`define logic_xor(alu_op) alu_op[2]

`define sub_flag(alu_op) alu_op[5]

`define shift_flag(alu_op) alu_op[3]

`define logic_flag(alu_op) alu_op[4]

`define set_flag(alu_op) ((!alu_op[6]) & (alu_op[5]))

`define add_sub_flag(alu_op) alu_op[6]

`define set_signed(alu_op) alu_op[0]

`define add_sub_word(alu_op) alu_op[2]
//============================alu_op_macro========================================================

//============================bru_op_macro========================================================
`define branch_eq(bru_op) bru_op[0]

`define branch_lt(bru_op) bru_op[1]

`define branch_ltu(bru_op) bru_op[2]

`define branch_reverse(bru_op) bru_op[3]
//============================bru_op_macro========================================================

//============================csr_op_macro========================================================
`define csr_mret_flag(csr_op) csr_op[8]

`define csr_sret_flag(csr_op) csr_op[7]

`define csr_dret_flag(csr_op) csr_op[6]

`define csr_acc_flag(csr_op) csr_op[3]

`define csr_swap(csr_op) csr_op[0]

`define csr_set(csr_op) csr_op[1]

`define csr_clear(csr_op) csr_op[2]
//============================csr_op_macro========================================================

//============================div_op_macro========================================================
`define div_word(div_op) div_op[3]

`define div_unsign(div_op) div_op[0]

`define div_rem(div_op) div_op[1]
//============================div_op_macro========================================================

//============================fence_op_macro======================================================
`define fence_flag(fence_op) fence_op[2]

`define fence_i_flag(fence_op) fence_op[1]

`define sfence_flag(fence_op) fence_op[0]
//============================fence_op_macro======================================================

//============================jump_op_macro=======================================================
`define jump_auipc(jump_op) jump_op[0]

`define jump_jal(jump_op) jump_op[1]

`define jump_jalr(jump_op) jump_op[2]
//============================jump_op_macro=======================================================

//============================mul_op_macro========================================================
`define mul_sign(mul_op) mul_op[1:0]

`define mul_low(mul_op) mul_op[2]

`define mul_high(mul_op) mul_op[3]

`define mul_word(mul_op) mul_op[4]
//============================mul_op_macro========================================================

//============================load_op_macro=======================================================
`define load_byte(load_op) (load_op[1:0] == 2'h0)

`define load_half(load_op) (load_op[1:0] == 2'h1)

`define load_word(load_op) (load_op[1:0] == 2'h2)

`define load_double(load_op) (load_op[1:0] == 2'h3)

`define load_signed(load_op) (!load_op[2])

`define load_size(load_op) {1'b0, load_op[1:0]}
//============================load_op_macro=======================================================

//============================store_op_macro======================================================
`define store_byte(store_op) (store_op[1:0] == 2'h0)

`define store_half(store_op) (store_op[1:0] == 2'h1)

`define store_word(store_op) (store_op[1:0] == 2'h2)

`define store_double(store_op) (store_op[1:0] == 2'h3)

`define store_size(store_op) {1'b0, store_op[1:0]}
//============================store_op_macro======================================================

//============================atomic_op_macro=====================================================
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
//============================atomic_op_macro=====================================================

`define addrcache(addr) ((addr >= 64'h8000_0000) & (addr < 64'h9fff_ffff))

//==================================Rob_macro=====================================================
`define RobQueueValid(func_rob_r_ptr, func_rob_w_ptr, func_test_rob_ptr) \
    ((func_rob_r_ptr[rob_entry_w] == func_rob_w_ptr[rob_entry_w]) ?  \
    ((func_test_rob_ptr >= func_rob_r_ptr[rob_entry_w - 1 : 0]) & (func_test_rob_ptr < func_rob_w_ptr[rob_entry_w - 1 : 0])) : \
    ((func_test_rob_ptr >= func_rob_r_ptr[rob_entry_w - 1 : 0]) | (func_test_rob_ptr < func_rob_w_ptr[rob_entry_w - 1 : 0])))

`define rob_is_older(func_a_ptr, func_b_ptr, func_deq_rob_ptr) \
    (((func_a_ptr[rob_entry_w] == func_b_ptr[rob_entry_w]) & (func_a_ptr[rob_entry_w - 1 : 0] < func_b_ptr[rob_entry_w - 1 : 0]  )) | \
    (((func_a_ptr[rob_entry_w] != func_b_ptr[rob_entry_w]) & (func_a_ptr[rob_entry_w - 1 : 0] != func_b_ptr[rob_entry_w - 1 : 0])) &  \
    ({(!func_a_ptr[rob_entry_w]), func_a_ptr[rob_entry_w - 1 : 0]} > func_b_ptr)) |                                                   \
    (((func_a_ptr[rob_entry_w] != func_b_ptr[rob_entry_w]) & (func_a_ptr[rob_entry_w - 1 : 0] == func_b_ptr[rob_entry_w - 1 : 0])) &  \
    (func_a_ptr == func_deq_rob_ptr)))
//==================================Rob_macro=====================================================

//==================================LSQ_macro=====================================================
`define LoadQueueValid(func_lq_r_ptr, func_lq_w_ptr, func_test_lq_ptr) \
    ((func_lq_r_ptr[LQ_entry_w] == func_lq_w_ptr[LQ_entry_w]) ?  \
    ((func_test_lq_ptr >= func_lq_r_ptr[LQ_entry_w - 1 : 0]) & (func_test_lq_ptr < func_lq_w_ptr[LQ_entry_w - 1 : 0])) : \
    ((func_test_lq_ptr >= func_lq_r_ptr[LQ_entry_w - 1 : 0]) | (func_test_lq_ptr < func_lq_w_ptr[LQ_entry_w - 1 : 0])))

`define StoreQueueValid(func_sq_r_ptr, func_sq_w_ptr, func_test_sq_ptr) \
    ((func_sq_r_ptr[SQ_entry_w] == func_sq_w_ptr[SQ_entry_w]) ?  \
    ((func_test_sq_ptr >= func_sq_r_ptr[SQ_entry_w - 1 : 0]) & (func_test_sq_ptr < func_sq_w_ptr[SQ_entry_w - 1 : 0])) : \
    ((func_test_sq_ptr >= func_sq_r_ptr[SQ_entry_w - 1 : 0]) | (func_test_sq_ptr < func_sq_w_ptr[SQ_entry_w - 1 : 0])))
//==================================LSQ_macro=====================================================

`endif
