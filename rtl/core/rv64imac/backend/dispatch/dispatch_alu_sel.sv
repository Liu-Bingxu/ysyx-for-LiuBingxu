module dispatch_alu_sel
import iq_pkg::*;
(
    input                   alu_valid,
    input  [IQ_W - 1 : 0]   alu_mul_exu_iq_enq_num,
    input  [IQ_W - 1 : 0]   alu_div_exu_iq_enq_num,
    input  [IQ_W - 1 : 0]   alu_bru_jump_exu_iq_enq_num,
    input  [IQ_W - 1 : 0]   alu_csr_fence_exu_iq_enq_num,
    input  [2        : 0]   index,
    output [2        : 0]   index_next,
    output                  alu_mul_exu_iq_enq_valid,
    output                  alu_div_exu_iq_enq_valid,
    output                  alu_bru_jump_exu_iq_enq_valid,
    output                  alu_csr_fence_exu_iq_enq_valid
);

//**********************alu_mul_exu_iq_index***********************************
logic [1 : 0] alu_mul_exu_iq_index;
assign alu_mul_exu_iq_index =   {1'b0, (alu_mul_exu_iq_enq_num > alu_div_exu_iq_enq_num)} + 
                                {1'b0, (alu_mul_exu_iq_enq_num > alu_bru_jump_exu_iq_enq_num)} + 
                                {1'b0, (alu_mul_exu_iq_enq_num > alu_csr_fence_exu_iq_enq_num)};
//**********************alu_mul_exu_iq_index***********************************

//**********************alu_div_exu_iq_index***********************************
logic [1 : 0] alu_div_exu_iq_index;
assign alu_div_exu_iq_index =   {1'b0, (alu_div_exu_iq_enq_num >= alu_mul_exu_iq_enq_num)} + 
                                {1'b0, (alu_div_exu_iq_enq_num > alu_bru_jump_exu_iq_enq_num)} + 
                                {1'b0, (alu_div_exu_iq_enq_num > alu_csr_fence_exu_iq_enq_num)};
//**********************alu_div_exu_iq_index***********************************

//**********************alu_bru_jmp_exu_iq_index*******************************
logic [1 : 0] alu_bru_jmp_exu_iq_index;
assign alu_bru_jmp_exu_iq_index =   {1'b0, (alu_bru_jump_exu_iq_enq_num >= alu_mul_exu_iq_enq_num)} + 
                                    {1'b0, (alu_bru_jump_exu_iq_enq_num >= alu_div_exu_iq_enq_num)} + 
                                    {1'b0, (alu_bru_jump_exu_iq_enq_num > alu_csr_fence_exu_iq_enq_num)};
//**********************alu_bru_jmp_exu_iq_index*******************************

//**********************alu_csr_fence_exu_iq_index*****************************
logic [1 : 0] alu_csr_fence_exu_iq_index;
assign alu_csr_fence_exu_iq_index = {1'b0, (alu_csr_fence_exu_iq_enq_num >= alu_mul_exu_iq_enq_num)} + 
                                    {1'b0, (alu_csr_fence_exu_iq_enq_num >= alu_div_exu_iq_enq_num)} + 
                                    {1'b0, (alu_csr_fence_exu_iq_enq_num >= alu_bru_jump_exu_iq_enq_num)};
//**********************alu_csr_fence_exu_iq_index*****************************

assign index_next                       = (alu_valid & (!index[2])) ? (index + 3'h1) : index;

assign alu_mul_exu_iq_enq_valid         = alu_valid & (!index[2]) & (index[1:0] == alu_mul_exu_iq_index);
assign alu_div_exu_iq_enq_valid         = alu_valid & (!index[2]) & (index[1:0] == alu_div_exu_iq_index);
assign alu_bru_jump_exu_iq_enq_valid    = alu_valid & (!index[2]) & (index[1:0] == alu_bru_jmp_exu_iq_index);
assign alu_csr_fence_exu_iq_enq_valid   = alu_valid & (!index[2]) & (index[1:0] == alu_csr_fence_exu_iq_index);

endmodule //dispatch_alu_sel
