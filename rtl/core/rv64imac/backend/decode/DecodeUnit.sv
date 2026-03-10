module DecodeUnit
import frontend_pkg::*;
import decode_pkg::*;
import alu_pkg::*;
import bru_pkg::*;
import jump_pkg::*;
import mul_pkg::*;
import div_pkg::*;
import csr_pkg::*;
import fence_pkg::*;
import mem_pkg::*;
import core_setting_pkg::*;
(
    input                                           clk,
    input                                           rst_n,

    input                                           redirect,

    input                                           debug_mode,
    input  [1:0]                                    current_priv_status,

    // csr ctrl io
    input                                           TSR,
    input                                           TW,
    input                                           TVM,

    input  ibuf_inst_o_entry[decode_width - 1 :0]   ibuf_inst_o,
    output [decode_width - 1 :0]                    inst_out_valid,
    output [decode_width - 1 :0]                    decode_inst_ready,

    output regsrc_t [decode_width - 1 :0]           int_src1_torat,
    output regsrc_t [decode_width - 1 :0]           int_src2_torat,
    output regdest_t[decode_width - 1 :0]           int_dest_torat,

    output             [decode_width - 1 : 0]       decode_out_valid,
    output decode_out_t[decode_width - 1 : 0]       decode_out,
    input                                           rename_ready
);

logic [31:0] inst_tran[decode_width - 1 :0];
decode_out_t[decode_width - 1 : 0]  decode;
logic       [decode_width - 1 : 0]  decode_valid_reg;
decode_out_t[decode_width - 1 : 0]  decode_reg;

genvar decode_index;
generate for(decode_index = 0 ; decode_index < decode_width; decode_index = decode_index + 1) begin : U_gen_decode
    logic [31:0]            decode_inst;

    regsrc_t                rs1;
    regsrc_t                rs2;
    regsrc_t                rd;

    logic [31:0]            imm_I,imm_J,imm_U,imm_B,imm_S;

    logic [6:0]             funct7;
    logic [2:0]             funct3;

    logic I_flag,J_flag,U_flag,B_flag,S_flag,R_flag,A_flag,RW_flag,CSR_flag;
    logic load_flag,arith_flag,arith_w_flag;

    //rv64i instruction sign
    logic lui, auipc;
    logic jal, jalr;
    logic beq, bne, blt, bltu, bge, bgeu;
    logic lb, lbu, lh, lhu, lw, lwu, ld;
    logic sb, sh, sw, sd;
    logic slti, sltiu, xori, ori, andi, addi;
    logic sll,srl,sra,slli,srli,srai;
    logic sub, slt,sltu, add;
    logic OR, XOR, AND;
    logic ecall, ebreak, fence, fence_i, sfence_vma;
    logic addiw, addw, subw;
    logic sllw,srlw,sraw,slliw,srliw,sraiw;

    //rv64 Zicsr
    logic csrrw,csrrwi;
    logic csrrs,csrrsi;
    logic csrrc,csrrci;

    //rv64m instruction sign
    logic mul, mulh, mulhsu, mulhu, mulw;
    logic div, divu, rem, remu;
    logic divw, divuw, remw, remuw;

    //rv64a instruction sign
    logic lr_w, sc_w, amoswap_w, amoadd_w, amoxor_w, amoand_w, amoor_w, amomin_w, amomax_w, amominu_w, amomaxu_w;
    logic lr_d, sc_d, amoswap_d, amoadd_d, amoxor_d, amoand_d, amoor_d, amomin_d, amomax_d, amominu_d, amomaxu_d;

    //rv64 privileged
    logic mret, sret, dret;
    logic wfi;

    //alu_sign:
    logic                               alu_valid;
    //arith_sign:
    logic                               arith_valid;
    //logic_sign:
    logic                               logic_valid;
    //load_sign:
    logic                               load_valid;
    //store_sign:
    logic                               store_valid;
    //branch:
    logic                               branch_valid;
    //shift:
    logic                               shift_valid;
    //set:
    logic                               set_valid;
    //jump:
    logic                               jump_valid;
    //Zicsr:
    logic                               csr_valid;
    logic                               csr_wen;
    logic                               csr_ren;
    logic [11:0]                        csr_addr;
    logic                               csr_addr_legal;
    logic                               csrr;
    logic                               csrr_mstatus;
    logic                               csrr_sstatus;
    logic                               csrr_dcsr;
    //mul:
    logic                               mul_valid;
    //div
    logic                               div_valid;
    //atomic:
    logic                               atomic_valid;

    //illegal instruction 
    logic                               illegal_instruction;

    FuType_t                            futype;             // 该指令执行fu类型号
    fence_optype_t                      fence_op;
    csr_optype_t                        csr_op;
    jump_optype_t                       jump_op;
    bru_optype_t                        bru_op;
    div_optype_t                        div_op;
    mul_optype_t                        mul_op;
    alu_optype_t                        alu_op;
    load_optype_t                       load_op;
    store_optype_t                      store_op;
    amo_optype_t                        amo_op;
    FuOpType_t                          fuoptype;           // 该指令fu操作符

    regsrc_t                            src1;               // 源逻辑寄存器号1
    src_type_t                          src1_type;          // 源操作数1类型
    regsrc_t                            src2;               // 源逻辑寄存器号2
    src_type_t                          src2_type;          // 源操作数2类型
    logic                               rfwen;              // 整数寄存器写使能
    logic                               csrwen;             // 控制寄存器写使能
    regdest_t                           wdest;              // 目的逻辑寄存器号

    logic [31:0]                        imm;                // 32位需符号拓展立即数

    logic                               no_spec_exec;       // 不可乱序执行标志
    logic                               no_intr_exec;       // 不可中断执行标志
    logic                               block_forward_flag; // 阻塞后面指令标志
    logic                               rvc_flag;           // 双字节指令标志

    logic                               call;               // call指令标志
    logic                               ret;                // ret指令标志

    logic                               trap_flag;          // 异常发生标志
    logic [3:0]                         trap_cause;         // 异常号，目前异常号不超过15
    logic [31:0]                        trap_tval;          // 异常补充信息，cause为1时，代表pc+2是否为异常pc；cause为2时tval为异常指令

    logic                               end_flag;           // 作为取值块最后一条指令标志
    logic [FTQ_ENTRY_BIT_NUM - 1 : 0]   ftq_ptr;            // 指令在ftq中的指针 
    logic [BLOCK_BIT_NUM - 1:0]         inst_offset;        // 指令与ftq中起始pc的偏移

    inst16_to_32 u_inst16_to_32(
        .input_inst 	( ibuf_inst_o[decode_index].inst[15:0]  ),
        .output_inst 	( inst_tran[decode_index]               )
    );
    assign decode_inst = (rvc_flag) ? inst_tran[decode_index] : ibuf_inst_o[decode_index].inst;

    assign rs1              = decode_inst[19:15];
    assign rs2              = decode_inst[24:20];
    assign rd               = decode_inst[11:7 ];

    assign funct3 = decode_inst[14:12];
    assign funct7 = decode_inst[31:25];

    //imm decode
    assign imm_I    = {{(20){decode_inst[31]}}, decode_inst[31:20]};
    assign imm_S    = {{(20){decode_inst[31]}}, decode_inst[31:25], decode_inst[11:7]};
    assign imm_B    = {{(20){decode_inst[31]}}, decode_inst[7], decode_inst[30:25], decode_inst[11:8],1'b0};
    assign imm_U    = {{( 1){decode_inst[31]}}, decode_inst[30:12], 12'h0};
    assign imm_J    = {{(12){decode_inst[31]}}, decode_inst[19:12], decode_inst[20], decode_inst[30:21],1'b0};

    //type decode
    assign R_flag   = (decode_inst[6:0] == 7'b0110011);
    assign A_flag   = (decode_inst[6:0] == 7'b0101111);
    assign RW_flag  = (decode_inst[6:0] == 7'b0111011);
    assign S_flag   = (decode_inst[6:0] == 7'b0100011);
    assign I_flag   = (load_flag | arith_flag | arith_w_flag | jalr);
    assign B_flag   = (decode_inst[6:0] == 7'b1100011);
    assign U_flag   = (lui | auipc);
    assign J_flag   = jal;

    assign load_flag    = (decode_inst[6:0] == 7'b0000011);
    assign arith_flag   = (decode_inst[6:0] == 7'b0010011);
    assign arith_w_flag = (decode_inst[6:0] == 7'b0011011);
    assign CSR_flag     = (decode_inst[6:0] == 7'b1110011);
    //**********************************************************************************************
    //!instruction decode
    //rv64i decode
    assign lui          =   (decode_inst[6:0]            ==      7'b0110111  );
    assign auipc        =   (decode_inst[6:0]            ==      7'b0010111  );
    assign jal          =   (decode_inst[6:0]            ==      7'b1101111  );
    assign jalr         =   ({funct3,decode_inst[6:0]}   ==  10'b0001100111  );

    assign beq          =   (B_flag & (funct3 == 3'b000));
    assign bne          =   (B_flag & (funct3 == 3'b001));
    assign blt          =   (B_flag & (funct3 == 3'b100));
    assign bge          =   (B_flag & (funct3 == 3'b101));
    assign bltu         =   (B_flag & (funct3 == 3'b110));
    assign bgeu         =   (B_flag & (funct3 == 3'b111));

    assign lb           =   (load_flag & (funct3 == 3'b000));
    assign lbu          =   (load_flag & (funct3 == 3'b100));
    assign lh           =   (load_flag & (funct3 == 3'b001));
    assign lhu          =   (load_flag & (funct3 == 3'b101));
    assign lw           =   (load_flag & (funct3 == 3'b010));
    assign lwu          =   (load_flag & (funct3 == 3'b110));
    assign ld           =   (load_flag & (funct3 == 3'b011));

    assign sb           =   (S_flag & (funct3 == 3'b000));
    assign sh           =   (S_flag & (funct3 == 3'b001));
    assign sw           =   (S_flag & (funct3 == 3'b010));
    assign sd           =   (S_flag & (funct3 == 3'b011));

    assign addi         =   (arith_flag & (funct3 == 3'b0));
    assign slti         =   (arith_flag & (funct3 == 3'h2));
    assign sltiu        =   (arith_flag & (funct3 == 3'h3));
    assign xori         =   (arith_flag & (funct3 == 3'h4));
    assign ori          =   (arith_flag & (funct3 == 3'h6)); 
    assign andi         =   (arith_flag & (funct3 == 3'h7)); 
    assign slli         =   (arith_flag & ({decode_inst[31:26], funct3} == 9'h001));
    assign srli         =   (arith_flag & ({decode_inst[31:26], funct3} == 9'h005));
    assign srai         =   (arith_flag & ({decode_inst[31:26], funct3} == 9'h085));

    assign add          =   (R_flag &({funct7, funct3} == 10'h000));
    assign sub          =   (R_flag &({funct7, funct3} == 10'h100));
    assign sll          =   (R_flag &({funct7, funct3} == 10'h001));
    assign slt          =   (R_flag &({funct7, funct3} == 10'h002));
    assign sltu         =   (R_flag &({funct7, funct3} == 10'h003));
    assign XOR          =   (R_flag &({funct7, funct3} == 10'h004));
    assign srl          =   (R_flag &({funct7, funct3} == 10'h005));
    assign sra          =   (R_flag &({funct7, funct3} == 10'h105));
    assign OR           =   (R_flag &({funct7, funct3} == 10'h006));
    assign AND          =   (R_flag &({funct7, funct3} == 10'h007));

    assign addiw        =   (arith_w_flag & (funct3 == 3'b0));
    assign slliw        =   (arith_w_flag & ({decode_inst[31:25], funct3} == 10'h001));
    assign srliw        =   (arith_w_flag & ({decode_inst[31:25], funct3} == 10'h005));
    assign sraiw        =   (arith_w_flag & ({decode_inst[31:25], funct3} == 10'h105));
    assign addw         =   (RW_flag & ({funct7, funct3} == 10'h000));
    assign subw         =   (RW_flag & ({funct7, funct3} == 10'h100));
    assign sllw         =   (RW_flag & ({funct7, funct3} == 10'h001));
    assign srlw         =   (RW_flag & ({funct7, funct3} == 10'h005));
    assign sraw         =   (RW_flag & ({funct7, funct3} == 10'h105));

    assign fence        =   ({funct3, decode_inst[6:0]} == 10'h00F);
    assign fence_i      =   ({funct3, decode_inst[6:0]} == 10'h08F);
    assign sfence_vma   =   ({funct7, decode_inst[14:0]} == 22'h048073);
    assign ecall        =   (decode_inst ==  32'h00000073);
    assign ebreak       =   (decode_inst ==  32'h00100073);

    //rv64 Zicsr decode
    assign csrrw        =   (CSR_flag & (funct3 == 3'b001));
    assign csrrs        =   (CSR_flag & (funct3 == 3'b010));
    assign csrrc        =   (CSR_flag & (funct3 == 3'b011));
    assign csrrwi       =   (CSR_flag & (funct3 == 3'b101));
    assign csrrsi       =   (CSR_flag & (funct3 == 3'b110));
    assign csrrci       =   (CSR_flag & (funct3 == 3'b111));

    //rv64m decode
    assign mul          =   (R_flag  & ({funct7, funct3} == 10'h008));
    assign mulh         =   (R_flag  & ({funct7, funct3} == 10'h009));
    assign mulhsu       =   (R_flag  & ({funct7, funct3} == 10'h00A));
    assign mulhu        =   (R_flag  & ({funct7, funct3} == 10'h00B));
    assign div          =   (R_flag  & ({funct7, funct3} == 10'h00C));
    assign divu         =   (R_flag  & ({funct7, funct3} == 10'h00D));
    assign rem          =   (R_flag  & ({funct7, funct3} == 10'h00E));
    assign remu         =   (R_flag  & ({funct7, funct3} == 10'h00F));
    assign mulw         =   (RW_flag & ({funct7, funct3} == 10'h008));
    assign divw         =   (RW_flag & ({funct7, funct3} == 10'h00C));
    assign divuw        =   (RW_flag & ({funct7, funct3} == 10'h00D));
    assign remw         =   (RW_flag & ({funct7, funct3} == 10'h00E));
    assign remuw        =   (RW_flag & ({funct7, funct3} == 10'h00F));

    //rv64a decode
    assign lr_w         =   (A_flag & (funct3 == 3'h2) & ({decode_inst[31:27],rs2} == 10'h040));
    assign sc_w         =   (A_flag & (funct3 == 3'h2) & ({decode_inst[31:27]} == 5'h03));
    assign amoswap_w    =   (A_flag & (funct3 == 3'h2) & ({decode_inst[31:27]} == 5'h01));
    assign amoadd_w     =   (A_flag & (funct3 == 3'h2) & ({decode_inst[31:27]} == 5'h00));
    assign amoxor_w     =   (A_flag & (funct3 == 3'h2) & ({decode_inst[31:27]} == 5'h04));
    assign amoand_w     =   (A_flag & (funct3 == 3'h2) & ({decode_inst[31:27]} == 5'h0C));
    assign amoor_w      =   (A_flag & (funct3 == 3'h2) & ({decode_inst[31:27]} == 5'h08));
    assign amomin_w     =   (A_flag & (funct3 == 3'h2) & ({decode_inst[31:27]} == 5'h10));
    assign amomax_w     =   (A_flag & (funct3 == 3'h2) & ({decode_inst[31:27]} == 5'h14));
    assign amominu_w    =   (A_flag & (funct3 == 3'h2) & ({decode_inst[31:27]} == 5'h18));
    assign amomaxu_w    =   (A_flag & (funct3 == 3'h2) & ({decode_inst[31:27]} == 5'h1C));
    assign lr_d         =   (A_flag & (funct3 == 3'h3) & ({decode_inst[31:27],rs2} == 10'h040));
    assign sc_d         =   (A_flag & (funct3 == 3'h3) & ({decode_inst[31:27]} == 5'h03));
    assign amoswap_d    =   (A_flag & (funct3 == 3'h3) & ({decode_inst[31:27]} == 5'h01));
    assign amoadd_d     =   (A_flag & (funct3 == 3'h3) & ({decode_inst[31:27]} == 5'h00));
    assign amoxor_d     =   (A_flag & (funct3 == 3'h3) & ({decode_inst[31:27]} == 5'h04));
    assign amoand_d     =   (A_flag & (funct3 == 3'h3) & ({decode_inst[31:27]} == 5'h0C));
    assign amoor_d      =   (A_flag & (funct3 == 3'h3) & ({decode_inst[31:27]} == 5'h08));
    assign amomin_d     =   (A_flag & (funct3 == 3'h3) & ({decode_inst[31:27]} == 5'h10));
    assign amomax_d     =   (A_flag & (funct3 == 3'h3) & ({decode_inst[31:27]} == 5'h14));
    assign amominu_d    =   (A_flag & (funct3 == 3'h3) & ({decode_inst[31:27]} == 5'h18));
    assign amomaxu_d    =   (A_flag & (funct3 == 3'h3) & ({decode_inst[31:27]} == 5'h1C));

    assign mret         =   (decode_inst ==  32'h30200073);
    assign sret         =   (decode_inst ==  32'h10200073);
    assign dret         =   (decode_inst ==  32'h7b200073);
    assign wfi          =   (decode_inst ==  32'h10500073);


    //alu_sign:
    assign alu_valid        = (logic_valid | shift_valid | set_valid | arith_valid);
    // arith_sign
    assign arith_valid      = (lui | add | addi | addw | addiw | sub | subw);
    //logic_sign:
    assign logic_valid      = (OR | XOR | AND | ori | xori | andi);
    //load_sign:
    assign load_valid       = (lb | lbu | lh | lhu | lw | lwu | ld);
    //store_sign:
    assign store_valid      = (sb | sh | sw | sd);
    //branch:
    assign branch_valid     = (bne | beq | blt | bltu | bge | bgeu);
    //shift:
    assign shift_valid      = (sll | slli | sllw | slliw | sra | srai | sraw | sraiw | srl | srli | srlw | srliw);
    //set:
    assign set_valid        = (slt | sltu | slti | sltiu);
    //jump:
    assign jump_valid       = (jal | jalr);
    //Zicsr:
    assign csr_valid        = (csrrw | csrrwi | csrrc | csrrci | csrrs | csrrsi);
    assign csr_ren          = (csrrc | csrrci | csrrs | csrrsi | ((csrrw | csrrwi) & (rd != 5'h0)));
    assign csr_wen          = (((csrrc | csrrci | csrrs | csrrsi) & (rs1 != 5'h0)) | csrrw | csrrwi);
    assign csr_addr         = decode_inst[31:20];
    assign csr_addr_legal   = ( (csr_addr == MISA          ) |
                                (csr_addr == MVENDORID     ) |
                                (csr_addr == MARCHID       ) |
                                (csr_addr == MIMPID        ) |
                                (csr_addr == MHARTID       ) |
                                (csr_addr == MSTATUS       ) |
                                (csr_addr == MTVEC         ) |
                                (csr_addr == MEDELEG       ) |
                                (csr_addr == MIDELEG       ) |
                                (csr_addr == MIP           ) |
                                (csr_addr == MIE           ) |
                                (csr_addr == MCYCLE        ) |
                                (csr_addr == MINSTRET      ) |
                                (csr_addr == MHPMCOUNTER3  ) |
                                (csr_addr == MHPMCOUNTER4  ) |
                                (csr_addr == MHPMCOUNTER5  ) |
                                (csr_addr == MHPMCOUNTER6  ) |
                                (csr_addr == MHPMCOUNTER7  ) |
                                (csr_addr == MHPMCOUNTER8  ) |
                                (csr_addr == MHPMCOUNTER9  ) |
                                (csr_addr == MHPMCOUNTER10 ) |
                                (csr_addr == MHPMCOUNTER11 ) |
                                (csr_addr == MHPMCOUNTER12 ) |
                                (csr_addr == MHPMCOUNTER13 ) |
                                (csr_addr == MHPMCOUNTER14 ) |
                                (csr_addr == MHPMCOUNTER15 ) |
                                (csr_addr == MHPMCOUNTER16 ) |
                                (csr_addr == MHPMCOUNTER17 ) |
                                (csr_addr == MHPMCOUNTER18 ) |
                                (csr_addr == MHPMCOUNTER19 ) |
                                (csr_addr == MHPMCOUNTER20 ) |
                                (csr_addr == MHPMCOUNTER21 ) |
                                (csr_addr == MHPMCOUNTER22 ) |
                                (csr_addr == MHPMCOUNTER23 ) |
                                (csr_addr == MHPMCOUNTER24 ) |
                                (csr_addr == MHPMCOUNTER25 ) |
                                (csr_addr == MHPMCOUNTER26 ) |
                                (csr_addr == MHPMCOUNTER27 ) |
                                (csr_addr == MHPMCOUNTER28 ) |
                                (csr_addr == MHPMCOUNTER29 ) |
                                (csr_addr == MHPMCOUNTER30 ) |
                                (csr_addr == MHPMCOUNTER31 ) |
                                (csr_addr == MHPMEVENT3    ) |
                                (csr_addr == MHPMEVENT4    ) |
                                (csr_addr == MHPMEVENT5    ) |
                                (csr_addr == MHPMEVENT6    ) |
                                (csr_addr == MHPMEVENT7    ) |
                                (csr_addr == MHPMEVENT8    ) |
                                (csr_addr == MHPMEVENT9    ) |
                                (csr_addr == MHPMEVENT10   ) |
                                (csr_addr == MHPMEVENT11   ) |
                                (csr_addr == MHPMEVENT12   ) |
                                (csr_addr == MHPMEVENT13   ) |
                                (csr_addr == MHPMEVENT14   ) |
                                (csr_addr == MHPMEVENT15   ) |
                                (csr_addr == MHPMEVENT16   ) |
                                (csr_addr == MHPMEVENT17   ) |
                                (csr_addr == MHPMEVENT18   ) |
                                (csr_addr == MHPMEVENT19   ) |
                                (csr_addr == MHPMEVENT20   ) |
                                (csr_addr == MHPMEVENT21   ) |
                                (csr_addr == MHPMEVENT22   ) |
                                (csr_addr == MHPMEVENT23   ) |
                                (csr_addr == MHPMEVENT24   ) |
                                (csr_addr == MHPMEVENT25   ) |
                                (csr_addr == MHPMEVENT26   ) |
                                (csr_addr == MHPMEVENT27   ) |
                                (csr_addr == MHPMEVENT28   ) |
                                (csr_addr == MHPMEVENT29   ) |
                                (csr_addr == MHPMEVENT30   ) |
                                (csr_addr == MHPMEVENT31   ) |
                                (csr_addr == MCOUNTEREN    ) |
                                (csr_addr == MCOUNTINHIBIT ) |
                                (csr_addr == MSCRATCH      ) |
                                (csr_addr == MEPC          ) |
                                (csr_addr == MCAUSE        ) |
                                (csr_addr == MTVAL         ) |
                                (csr_addr == MCONFIGPTR    ) |
                                (csr_addr == MENVCFG       ) |
                                (csr_addr == MSECCFG       ) |
                                (csr_addr == SSTATUS       ) |
                                (csr_addr == STVEC         ) |
                                (csr_addr == SIP           ) |
                                (csr_addr == SIE           ) |
                                (csr_addr == SCOUNTEREN    ) |
                                (csr_addr == SSCRATCH      ) |
                                (csr_addr == SEPC          ) |
                                (csr_addr == SCAUSE        ) |
                                (csr_addr == STVAL         ) |
                                (csr_addr == SENVCFG       ) |
                                (csr_addr == SATP          ) |
                                (csr_addr == CYCLE         ) |
                                (csr_addr == INSTRET       ) |
                                (csr_addr == HPMCOUNTER3   ) |
                                (csr_addr == HPMCOUNTER4   ) |
                                (csr_addr == HPMCOUNTER5   ) |
                                (csr_addr == HPMCOUNTER6   ) |
                                (csr_addr == HPMCOUNTER7   ) |
                                (csr_addr == HPMCOUNTER8   ) |
                                (csr_addr == HPMCOUNTER9   ) |
                                (csr_addr == HPMCOUNTER10  ) |
                                (csr_addr == HPMCOUNTER11  ) |
                                (csr_addr == HPMCOUNTER12  ) |
                                (csr_addr == HPMCOUNTER13  ) |
                                (csr_addr == HPMCOUNTER14  ) |
                                (csr_addr == HPMCOUNTER15  ) |
                                (csr_addr == HPMCOUNTER16  ) |
                                (csr_addr == HPMCOUNTER17  ) |
                                (csr_addr == HPMCOUNTER18  ) |
                                (csr_addr == HPMCOUNTER19  ) |
                                (csr_addr == HPMCOUNTER20  ) |
                                (csr_addr == HPMCOUNTER21  ) |
                                (csr_addr == HPMCOUNTER22  ) |
                                (csr_addr == HPMCOUNTER23  ) |
                                (csr_addr == HPMCOUNTER24  ) |
                                (csr_addr == HPMCOUNTER25  ) |
                                (csr_addr == HPMCOUNTER26  ) |
                                (csr_addr == HPMCOUNTER27  ) |
                                (csr_addr == HPMCOUNTER28  ) |
                                (csr_addr == HPMCOUNTER29  ) |
                                (csr_addr == HPMCOUNTER30  ) |
                                (csr_addr == HPMCOUNTER31  ) |
                                ((csr_addr == DCSR         ) & debug_mode) |
                                ((csr_addr == DPC          ) & debug_mode) |
                                ((csr_addr == DSCRATCH0    ) & debug_mode) |
                                ((csr_addr == DSCRATCH1    ) & debug_mode));
    assign csrr             = (csr_valid & (!csr_wen));
    assign csrr_mstatus     = (csrr & (csr_addr == MSTATUS));
    assign csrr_sstatus     = (csrr & (csr_addr == SSTATUS));
    assign csrr_dcsr        = (csrr & (csr_addr == DCSR));
    //mul:
    assign mul_valid        = (mul | mulh | mulhsu | mulhu | mulw);
    assign div_valid        = (div | divu | rem | remu | divw | divuw | remw | remuw);
    //atomic:
    assign atomic_valid     =   (lr_w | sc_w | amoswap_w | amoadd_w | amoxor_w | amoand_w | amoor_w | amomin_w | amominu_w | amomax_w | amomaxu_w) | 
                                (lr_d | sc_d | amoswap_d | amoadd_d | amoxor_d | amoand_d | amoor_d | amomin_d | amominu_d | amomax_d | amomaxu_d);

    //illegal instruction judge
    assign illegal_instruction = ((!(logic_valid | load_valid | store_valid | branch_valid | shift_valid | 
                                    set_valid | jump_valid | csr_valid | mul_valid | div_valid | atomic_valid | mret | 
                                    sret | dret | wfi | lui | auipc | add | addi | sub | addw | addiw | subw | ecall | 
                                    ebreak | fence | fence_i | sfence_vma)) | 
                                    (csr_valid & ((csr_addr[9:8] > current_priv_status) | (csr_wen & (csr_addr[11:10] == 2'h3)) | (!csr_addr_legal))) | 
                                    /*disable all access csr form U*/(csr_valid & (current_priv_status == U_LEVEL)) | 
                                    /*disable access tlb form U*/    (sfence_vma & (current_priv_status == U_LEVEL)) | 
                                    /*disable access tlb form S*/    (sfence_vma & (current_priv_status == S_LEVEL) & TVM) | 
                                    /*disable wfi time form S&U*/    (wfi & (current_priv_status < M_LEVEL) & TW) | 
                                    /*disable access satp form S*/   (csr_valid & (current_priv_status == S_LEVEL) & (csr_addr == 12'h180) & TVM) | 
                                    /*disable dret on no debug*/     (dret & (!debug_mode)) |
                                    /*disable sret form S*/          (sret & (current_priv_status == S_LEVEL) & TSR) | 
                                    /*disable mret form S*/          (mret & (current_priv_status == S_LEVEL)) | 
                                    /*disable sret form U*/          (sret & (current_priv_status == U_LEVEL)) | 
                                    /*disable mret form U*/          (mret & (current_priv_status == U_LEVEL)));
    //**********************************************************************************************
    //!output sign decode
    /*verilator lint_off ENUMVALUE*/
    assign futype               =   ({4{alu_valid                               }} & fu_alu     ) | 
                                    ({4{fence | fence_i | sfence_vma            }} & fu_fence   ) | 
                                    ({4{csr_valid | mret | sret | dret | wfi    }} & fu_csr     ) | 
                                    ({4{jump_valid | auipc                      }} & fu_jump    ) | 
                                    ({4{branch_valid                            }} & fu_bru     ) | 
                                    ({4{div_valid                               }} & fu_div     ) | 
                                    ({4{mul_valid                               }} & fu_mul     ) | 
                                    ({4{load_valid                              }} & fu_load    ) | 
                                    ({4{store_valid                             }} & fu_store   ) | 
                                    ({4{atomic_valid                            }} & fu_amo     );
    // 3条指令
    assign fence_op             =   ({9{sfence_vma  }} & op_sfence  ) | 
                                    ({9{fence_i     }} & op_fence_i ) | 
                                    ({9{fence       }} & op_fence   );
    // 10条指令
    assign csr_op               =   ({9{mret  }} & op_mret   ) | 
                                    ({9{sret  }} & op_sret   ) | 
                                    ({9{dret  }} & op_dret   ) | 
                                    ({9{wfi   }} & op_wfi    ) | 
                                    ({9{csrrw }} & op_csrrw  ) | 
                                    ({9{csrrs }} & op_csrrs  ) | 
                                    ({9{csrrc }} & op_csrrc  ) | 
                                    ({9{csrrwi}} & op_csrrwi ) | 
                                    ({9{csrrsi}} & op_csrrsi ) | 
                                    ({9{csrrci}} & op_csrrci );
    // 3条指令
    assign jump_op              =   ({9{auipc}} & op_auipc ) | 
                                    ({9{jal  }} & op_jal   ) | 
                                    ({9{jalr }} & op_jalr  );
    // 6条指令
    assign bru_op               =   ({9{beq }} & op_beq  ) | 
                                    ({9{bne }} & op_bne  ) | 
                                    ({9{blt }} & op_blt  ) | 
                                    ({9{bge }} & op_bge  ) | 
                                    ({9{bltu}} & op_bltu ) | 
                                    ({9{bgeu}} & op_bgeu );   
    // 8条指令
    assign div_op               =   ({9{div  }} & op_div   ) | 
                                    ({9{divu }} & op_divu  ) | 
                                    ({9{rem  }} & op_rem   ) | 
                                    ({9{remu }} & op_remu  ) | 
                                    ({9{divw }} & op_divw  ) | 
                                    ({9{divuw}} & op_divuw ) | 
                                    ({9{remw }} & op_remw  ) | 
                                    ({9{remuw}} & op_remuw );
    // 5条指令
    assign mul_op               =   ({9{mul   }} & op_mul    ) | 
                                    ({9{mulh  }} & op_mulh   ) | 
                                    ({9{mulhsu}} & op_mulhsu ) | 
                                    ({9{mulhu }} & op_mulhu  ) | 
                                    ({9{mulw  }} & op_mulw   );
    // 29条指令
    assign alu_op               =   ({9{sll  | slli         }} & op_sll  ) | 
                                    ({9{srl  | srli         }} & op_srl  ) | 
                                    ({9{sra  | srai         }} & op_sra  ) | 
                                    ({9{sllw | slliw        }} & op_sllw ) | 
                                    ({9{srlw | srliw        }} & op_srlw ) | 
                                    ({9{sraw | sraiw        }} & op_sraw ) | 
                                    ({9{AND  | andi         }} & op_and  ) | 
                                    ({9{OR   | ori          }} & op_or   ) | 
                                    ({9{XOR  | xori         }} & op_xor  ) | 
                                    ({9{sub                 }} & op_sub  ) | 
                                    ({9{subw                }} & op_subw ) | 
                                    ({9{slt  | slti         }} & op_slt  ) | 
                                    ({9{sltu | sltiu        }} & op_sltu ) | 
                                    ({9{add  | addi  | lui  }} & op_add  ) | 
                                    ({9{addw | addiw        }} & op_addw );
    // 7条指令
    assign load_op              =   ({9{lb }} & op_lb  ) | 
                                    ({9{lh }} & op_lh  ) | 
                                    ({9{lw }} & op_lw  ) | 
                                    ({9{ld }} & op_ld  ) | 
                                    ({9{lbu}} & op_lbu ) | 
                                    ({9{lhu}} & op_lhu ) | 
                                    ({9{lwu}} & op_lwu );
    // 4条指令
    assign store_op             =   ({9{sb}} & op_sb ) | 
                                    ({9{sh}} & op_sh ) | 
                                    ({9{sw}} & op_sw ) | 
                                    ({9{sd}} & op_sd );
    // 22条指令
    assign amo_op               =   ({9{lr_w     }} & op_lr_w      ) | 
                                    ({9{sc_w     }} & op_sc_w      ) | 
                                    ({9{amoswap_w}} & op_amoswap_w ) | 
                                    ({9{amoadd_w }} & op_amoadd_w  ) | 
                                    ({9{amoxor_w }} & op_amoxor_w  ) | 
                                    ({9{amoand_w }} & op_amoand_w  ) | 
                                    ({9{amoor_w  }} & op_amoor_w   ) | 
                                    ({9{amomin_w }} & op_amomin_w  ) | 
                                    ({9{amomax_w }} & op_amomax_w  ) | 
                                    ({9{amominu_w}} & op_amominu_w ) | 
                                    ({9{amomaxu_w}} & op_amomaxu_w ) | 
                                    ({9{lr_d     }} & op_lr_d      ) | 
                                    ({9{sc_d     }} & op_sc_d      ) | 
                                    ({9{amoswap_d}} & op_amoswap_d ) | 
                                    ({9{amoadd_d }} & op_amoadd_d  ) | 
                                    ({9{amoxor_d }} & op_amoxor_d  ) | 
                                    ({9{amoand_d }} & op_amoand_d  ) | 
                                    ({9{amoor_d  }} & op_amoor_d   ) | 
                                    ({9{amomin_d }} & op_amomin_d  ) | 
                                    ({9{amomax_d }} & op_amomax_d  ) | 
                                    ({9{amominu_d}} & op_amominu_d ) | 
                                    ({9{amomaxu_d}} & op_amomaxu_d );
    assign fuoptype             =   ({9{alu_valid                               }} & alu_op     ) | 
                                    ({9{fence | fence_i | sfence_vma            }} & fence_op   ) | 
                                    ({9{csr_valid | mret | sret | dret | wfi    }} & csr_op     ) | 
                                    ({9{jump_valid | auipc                      }} & jump_op    ) | 
                                    ({9{branch_valid                            }} & bru_op     ) | 
                                    ({9{div_valid                               }} & div_op     ) | 
                                    ({9{mul_valid                               }} & mul_op     ) | 
                                    ({9{load_valid                              }} & load_op    ) | 
                                    ({9{store_valid                             }} & store_op   ) | 
                                    ({9{atomic_valid                            }} & amo_op     );
    /*verilator lint_on ENUMVALUE*/

    assign src1                 = rs1;
    assign src1_type            =   (csrrwi | csrrci | csrrsi | auipc | jal) ? src_imm : 
                                    ((src1 == 5'h0) | lui) ? src_zero : src_reg;
    assign src2                 = rs2;
    assign src2_type            =   (U_flag | J_flag | I_flag | S_flag | arith_w_flag | csrrc | csrrs | csrrci | csrrsi) ? src_imm :
                                    ((src2 == 5'h0) | csrrw | csrrwi) ? src_zero : src_reg;
    assign rfwen                = ((I_flag | U_flag | A_flag | R_flag | RW_flag | J_flag | csr_ren) & (rd != 5'h0));
    assign csrwen               = csr_wen;
    assign wdest                = rd;
    assign imm                  =   ({32{I_flag | CSR_flag  }} & imm_I) | 
                                    ({32{U_flag             }} & imm_U) | 
                                    ({32{J_flag             }} & imm_J) | 
                                    ({32{S_flag             }} & imm_S) | 
                                    ({32{B_flag             }} & imm_B);
    assign no_spec_exec         = (atomic_valid | fence | fence_i | sfence_vma | sret | mret | dret | 
                                    (csr_valid & ((!csrr) | csrr_mstatus | csrr_sstatus | csrr_dcsr)));
    assign no_intr_exec         = (atomic_valid | fence | fence_i | sfence_vma | store_valid);
    assign block_forward_flag   = (atomic_valid | fence | fence_i | sfence_vma | sret | mret | dret | 
                                    (csr_valid & (!csrr)));
    assign call                 = ((jal | jalr) & (rd == 5'h1));
    assign ret                  = (jalr & (rd == 5'h0) & (rs1 == 5'h1));
    assign rvc_flag             = (ibuf_inst_o[decode_index].inst[1:0] != 2'h3);
    assign trap_flag            = (ecall | ebreak | (ibuf_inst_o[decode_index].rresp != 2'h0) | illegal_instruction);
    assign trap_cause           = ((ibuf_inst_o[decode_index].rresp == 2'h2) ? 4'hC : (
                                    (ibuf_inst_o[decode_index].rresp == 2'h3) ? 4'h1 :(
                                        (illegal_instruction) ? 4'h2 :(
                                            (ebreak) ? 4'h3 : (
                                                (ecall & (current_priv_status == M_LEVEL)) ? 4'hB : (
                                                    (ecall & (current_priv_status == S_LEVEL)) ? 4'h9 : (
                                                        (ecall & (current_priv_status == U_LEVEL)) ? 4'h8 : 4'h0
                                                    )
                                                )
                                            )
                                        )
                                    ) 
                                ));
    assign trap_tval            = ((ibuf_inst_o[decode_index].rresp != 2'h0) ? {31'h0, ibuf_inst_o[decode_index].tval_flag} :
                                    (illegal_instruction & rvc_flag) ? {16'h0, ibuf_inst_o[decode_index].inst[15:0]} :(
                                        (illegal_instruction & (!rvc_flag)) ? ibuf_inst_o[decode_index].inst : 32'h0
                                ));
    assign end_flag             = ibuf_inst_o[decode_index].end_flag;
    assign ftq_ptr              = ibuf_inst_o[decode_index].ifu_dequeue_ptr;
    assign inst_offset          = ibuf_inst_o[decode_index].inst_offset;

    assign decode[decode_index].futype             = futype            ;
    assign decode[decode_index].fuoptype           = fuoptype          ;
    assign decode[decode_index].src1               = src1              ;
    assign decode[decode_index].src1_type          = src1_type         ;
    assign decode[decode_index].src2               = src2              ;
    assign decode[decode_index].src2_type          = src2_type         ;
    assign decode[decode_index].rfwen              = rfwen             ;
    assign decode[decode_index].csrwen             = csrwen            ;
    assign decode[decode_index].wdest              = wdest             ;
    assign decode[decode_index].imm                = imm               ;
    assign decode[decode_index].no_spec_exec       = no_spec_exec      ;
    assign decode[decode_index].no_intr_exec       = no_intr_exec      ;
    assign decode[decode_index].block_forward_flag = block_forward_flag;
    assign decode[decode_index].call               = call              ;
    assign decode[decode_index].ret                = ret               ;
    assign decode[decode_index].rvc_flag           = rvc_flag          ;
    assign decode[decode_index].trap_flag          = trap_flag         ;
    assign decode[decode_index].trap_cause         = trap_cause        ;
    assign decode[decode_index].trap_tval          = trap_tval         ;
    assign decode[decode_index].end_flag           = end_flag          ;
    assign decode[decode_index].ftq_ptr            = ftq_ptr           ;
    assign decode[decode_index].inst_offset        = inst_offset       ;
    //**********************************************************************************************
    //!output
    // valid
    FF_D_with_syn_rst #(
        .DATA_LEN 	( 1  ),
        .RST_DATA 	( 0  )
    )u_decode_valid
    (
        .clk      	( clk                                       ),
        .rst_n    	( rst_n                                     ),
        .syn_rst    ( redirect                                  ),
        .wen        ( ((!(|decode_valid_reg)) | rename_ready)   ),
        .data_in  	( ibuf_inst_o[decode_index].is_valid        ),
        .data_out 	( decode_valid_reg[decode_index]            )
    );
    FF_D_without_asyn_rst #(DECODE_O_W) u_decode_o (clk,ibuf_inst_o[decode_index].is_valid & decode_inst_ready[decode_index],decode[decode_index],decode_reg[decode_index]);

    assign inst_out_valid[decode_index]     = ibuf_inst_o[decode_index].is_valid;
    assign decode_inst_ready[decode_index] = ((!(|decode_valid_reg)) | rename_ready);
    assign int_src1_torat[decode_index] = rs1;
    assign int_src2_torat[decode_index] = rs2;
    assign int_dest_torat[decode_index] = rd;
end
endgenerate

assign decode_out_valid = decode_valid_reg;
assign decode_out       = decode_reg;


endmodule //DecodeUnit
