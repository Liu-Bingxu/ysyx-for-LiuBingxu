`include "macro-func-define.sv"
module Fence_fu
import decode_pkg::*;
import regfile_pkg::*;
import fence_pkg::*;
import rob_pkg::*;
(
    input                                               clk,
    input                                               rst_n,

    // fence_i interface
    output logic                                        flush_i_valid,
    input                                               flush_i_ready,
    // sfence_vma interface
    output                                              sflush_vma_valid,

    input                                               fence_valid_i,
    output                                              fence_ready_i,
    /* verilator lint_off UNUSEDSIGNAL */
    input  fence_optype_t                               op,
    /* verilator lint_on UNUSEDSIGNAL */
    input                                               inst_rvc,
    input  [63:0]                                       pc,
    input  rob_entry_ptr_t                              rob_ptr,

    output                                              fence_valid_o,
    input                                               fence_ready_o,
    output rob_entry_ptr_t                              fence_rob_ptr_o,
    output [63:0]                                       fence_addr_o
);

fence_fsm_t     fence_fsm;
logic           fence_i_finish;
logic           fence_valid;
logic [63:0]    fence_addr;

always_ff @(posedge clk or negedge rst_n) begin
    if(!rst_n)begin
        fence_fsm       <= fence_idle;
        flush_i_valid   <= 1'b0;
        fence_i_finish  <= 1'b0;
    end
    else begin
        case (fence_fsm)
            fence_idle: begin
                if(fence_valid_i & fence_ready_i & `fence_i_flag(op))begin
                    fence_fsm       <= fencei_run;
                    flush_i_valid   <= 1'b1;
                end
            end
            fencei_run: begin
                if(flush_i_valid & flush_i_ready)begin
                    fence_fsm       <= fencei_out;
                    flush_i_valid   <= 1'b0;
                    fence_i_finish  <= 1'b1;
                end
            end
            fencei_out: begin
                if(fence_valid_o & fence_ready_o)begin
                    fence_fsm       <= fence_idle;
                    fence_i_finish  <= 1'b0;
                end
            end
            default: begin
                fence_fsm       <= fence_idle;
                flush_i_valid   <= 1'b0;
                fence_i_finish  <= 1'b0;
            end
        endcase
    end
end
assign fence_addr   = pc + (inst_rvc ? 64'h2 : 64'h4);
assign sflush_vma_valid = fence_valid_i & fence_ready_i & `sfence_flag(op);

//*************************************************************************
//!output
assign fence_ready_i = ((!fence_valid_o) | fence_ready_o) & (fence_fsm == fence_idle);

logic send_valid;
assign send_valid = fence_valid_i & fence_ready_i;
FF_D_with_wen #(
    .DATA_LEN 	( 1  ),
    .RST_DATA 	( 0  )
)u_fence_valid
(
    .clk      	( clk                                   ),
    .rst_n    	( rst_n                                 ),
    .wen        ( fence_ready_i                         ),
    .data_in  	( fence_valid_i & (!`fence_i_flag(op))  ),
    .data_out 	( fence_valid                           )
);
assign fence_valid_o = (fence_valid | fence_i_finish);
FF_D_without_asyn_rst #(rob_entry_w)    u_rob_ptr_o(clk,send_valid, rob_ptr, fence_rob_ptr_o);
FF_D_without_asyn_rst #(64)             u_fence_addr_o   (clk,send_valid, fence_addr, fence_addr_o);
//*************************************************************************

endmodule //Fence_fu
