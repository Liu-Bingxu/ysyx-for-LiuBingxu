package frontend_pkg;

localparam RAS_ENTRY_BIT_NUM   = 4 ;
localparam SQ_ENTRY_BIT_NUM    = 4 ;
localparam ENTRY_RECURSION_BIT = 8 ;
localparam UFTB_ENTRY_BIT_NUM  = 4 ;
localparam TAG_START_BIT       = 1 ;
localparam TAG_BIT_NUM         = 20;
localparam BLOCK_BIT_NUM       = 4 ;

localparam FTQ_ENTRY_BIT_NUM   = 3;
localparam FTQ_ENTRY_NUM       = 2 ** FTQ_ENTRY_BIT_NUM;

localparam RAS_ENTRY_NUM = 2 ** RAS_ENTRY_BIT_NUM;
localparam SQ_ENTRY_NUM  = 2 ** SQ_ENTRY_BIT_NUM ;

localparam UFTB_ENTRY_NUM = 2 ** UFTB_ENTRY_BIT_NUM;
localparam BLOCK_SIZE     = 2 ** BLOCK_BIT_NUM;

localparam IFU_SEND_ADDR_NUM   = 1 + (BLOCK_SIZE / 8);
localparam IFU_SEND_ADDR_BIT   = (BLOCK_BIT_NUM - 2);
localparam IFU_INST_MAX_NUM    = (BLOCK_SIZE / 2);

localparam UFTB_ENTRY_BIT      = 52 + TAG_BIT_NUM + (BLOCK_BIT_NUM * 3);
localparam FTQ_ENTRY_BIT       = UFTB_ENTRY_BIT + UFTB_ENTRY_NUM + 132;

typedef struct packed{
    logic [63:0]                       addr;
    logic [ENTRY_RECURSION_BIT - 1:0]  cnt;
    logic [ENTRY_RECURSION_BIT - 1:0]  pred_cnt;
    logic [ENTRY_RECURSION_BIT - 1:0]  precheck_cnt;
}stack_entry;
typedef struct packed{
    logic [63:0]                        addr;
    logic [ENTRY_RECURSION_BIT - 1:0]   pred_cnt;
    logic [ENTRY_RECURSION_BIT - 1:0]   precheck_cnt;
    logic [SQ_ENTRY_BIT_NUM - 1:0]      nos;
}queue_entry;
typedef struct packed{
    stack_entry [RAS_ENTRY_NUM - 1: 0]  entry;
    logic [RAS_ENTRY_BIT_NUM - 1:0]     nsp; // 提交栈指针
    logic [RAS_ENTRY_BIT_NUM - 1:0]     ssp; // 预测栈指针
    logic [RAS_ENTRY_BIT_NUM - 1:0]     psp; // 预译码栈指针
    logic [RAS_ENTRY_BIT_NUM - 1:0]     bos; // 栈底
}stack;
typedef struct packed{
    queue_entry [SQ_ENTRY_NUM - 1: 0]   entry;
    logic [SQ_ENTRY_BIT_NUM - 1:0]      tosr;  // 预测队读指针
    logic [SQ_ENTRY_BIT_NUM - 1:0]      tosw;  // 预测队写指针
    logic [SQ_ENTRY_BIT_NUM - 1:0]      ptosr; // 预译码队读指针
    logic [SQ_ENTRY_BIT_NUM - 1:0]      ptosw; // 预译码队写指针
    logic [SQ_ENTRY_BIT_NUM - 1:0]      bos;   // 队尾指针
}queue;

typedef struct packed {
    logic                           valid;
    logic [BLOCK_BIT_NUM - 1: 0]    offset;
    logic                           is_rvc;
    logic [1:0]                     carry;
    logic [11:0]                    next_low;
    logic [1:0]                     bit2_cnt;
} uftb_entry_br_slot;

typedef struct packed {
    logic                           valid;
    logic [BLOCK_BIT_NUM - 1: 0]    offset;
    logic                           is_rvc;
    logic [1:0]                     carry;
    logic [19:0]                    next_low;
    logic [1:0]                     bit2_cnt;
} uftb_entry_tail_slot;

typedef struct packed {
    logic                           valid;
    logic [TAG_BIT_NUM - 1: 0]      tag;
    uftb_entry_br_slot              br_slot;
    uftb_entry_tail_slot            tail_slot;
    logic                           carry;
    logic [BLOCK_BIT_NUM - 1: 0]    next_low;
    logic                           is_branch;
    logic                           is_call;
    logic                           is_ret;
    logic                           is_jalr;
    logic [1:0]                     always_token;
} uftb_entry;

typedef struct packed {
    logic [63:0]                        start_pc;
    logic [63:0]                        next_pc;
    logic                               first_pred_flag;
    logic                               hit;
    logic                               token;
    logic                               is_tail;
    logic [UFTB_ENTRY_NUM - 1 : 0]      hit_sel;
    uftb_entry                          old_entry;
} ftq_entry;


typedef struct packed {
    logic                          is_valid;
    logic                          decode_eqa;
    logic [31:0]                   inst;
    logic [BLOCK_BIT_NUM - 1: 0]   inst_offset;
} decode_result;

typedef struct packed {
    logic                       is_valid;
    logic                       eqa;
    logic                       tval_flag;
    logic [1:0]                 rresp;
    logic [31:0]                inst;
    logic [BLOCK_BIT_NUM - 1:0] inst_offset;
} ibuf_inst_entry;

typedef struct packed {
    logic                               is_valid;
    logic                               tval_flag;
    logic                               end_flag;
    logic [1:0]                         rresp;
    logic [FTQ_ENTRY_BIT_NUM - 1 : 0]   ifu_dequeue_ptr;
    logic [31:0]                        inst;
    logic [BLOCK_BIT_NUM - 1:0]         inst_offset;
} ibuf_inst_o_entry;

localparam IBUF_ADDR_W = FTQ_ENTRY_BIT_NUM + IFU_SEND_ADDR_BIT;
localparam IBUF_Depth = 2 ** IBUF_ADDR_W;

typedef logic [IBUF_ADDR_W:0]                               ibuf_point;
typedef logic [BLOCK_BIT_NUM + FTQ_ENTRY_BIT_NUM + 35 : 0]  ibuf_data;

endpackage
