module dtm#(
    parameter ABITS = 7,
    parameter READ_THROUGH  = "TRUE"
)(
    input 				        tck,
    input				        trst_n,
    input				        tms,
    input				        tdi,
    output	reg			        tdo,

    //TODO
    input                       dtm2dm_full,
    output                      dtm2dm_wen,
    output [ ABITS + 33 : 0 ]   dtm2dm_data_in,

    input                       dm2dtm_empty,
    output                      dm2dtm_ren,
    input  [ ABITS + 33 : 0 ]   dm2dtm_data_out
);

// JTAG State Machine
localparam TEST_LOGIC_RESET  = 4'h0;
localparam RUN_TEST_IDLE     = 4'h1;
localparam SELECT_DR         = 4'h2;
localparam CAPTURE_DR        = 4'h3;
localparam SHIFT_DR          = 4'h4;
localparam EXIT1_DR          = 4'h5;
localparam PAUSE_DR          = 4'h6;
localparam EXIT2_DR          = 4'h7;
localparam UPDATE_DR         = 4'h8;
localparam SELECT_IR         = 4'h9;
localparam CAPTURE_IR        = 4'hA;
localparam SHIFT_IR          = 4'hB;
localparam EXIT1_IR          = 4'hC;
localparam PAUSE_IR          = 4'hD;
localparam EXIT2_IR          = 4'hE;
localparam UPDATE_IR         = 4'hF;

//ir 
localparam IR_IDCODE         = 5'h1;
localparam IR_DTMCS          = 5'h10;
localparam IR_DBUS           = 5'h11;

localparam JTAG_VERISON      = 4'h1;
localparam JTAG_PART_NUMBER  = 16'h445A; //DZ ascii码
localparam JTAG_MANUFLD      = 11'h0;

localparam IDLE_CYCLE        = 3'h7;
localparam DEBUG_VERSION     = 4'h1;

localparam SHIFT_REG_LEN     = ABITS + 32 + 2;

wire [1:0]  dmisata;

reg  [3:0]  jtag_tap_state;

wire [SHIFT_REG_LEN - 1 : 0] transfer_res;
reg                          dtm2dm_wen_reg;
reg                          dm2dtm_ren_reg;
reg [ ABITS + 33 : 0 ]       dtm2dm_data_in_reg;

reg  [4:0]  ir_reg;

reg  [SHIFT_REG_LEN - 1 : 0] shift_reg;

//* 0x1445A001
wire [31:0] idcode = {JTAG_VERISON, JTAG_PART_NUMBER, JTAG_MANUFLD, 1'b1};

wire [31:0] dtmcs  = {11'h0, 3'h0, 1'h0, 1'h0, 1'h0, IDLE_CYCLE, dmisata, ABITS[5:0], DEBUG_VERSION};

reg         in_busy;
reg         busy_sticky;
// wire        in_busy = (!(dtm2dm_full_f | dtm2dm_empty_t));

assign      dmisata = (in_busy | busy_sticky) ? 2'h3 : transfer_res[1:0];

wire        dmi_rst     = (jtag_tap_state == UPDATE_IR) & shift_reg[16];
wire        dmihard_rst = (jtag_tap_state == UPDATE_IR) & shift_reg[17];

always @(posedge tck or negedge trst_n) begin
    if(!trst_n)begin
        jtag_tap_state <= TEST_LOGIC_RESET;
    end
    else if(dmihard_rst)begin
        jtag_tap_state <= TEST_LOGIC_RESET;
    end
    else begin
        case (jtag_tap_state)
            TEST_LOGIC_RESET : jtag_tap_state <= tms ? TEST_LOGIC_RESET : RUN_TEST_IDLE;
            RUN_TEST_IDLE    : jtag_tap_state <= tms ? SELECT_DR        : RUN_TEST_IDLE;
            SELECT_DR        : jtag_tap_state <= tms ? SELECT_IR        : CAPTURE_DR;
            CAPTURE_DR       : jtag_tap_state <= tms ? EXIT1_DR         : SHIFT_DR;
            SHIFT_DR         : jtag_tap_state <= tms ? EXIT1_DR         : SHIFT_DR;
            EXIT1_DR         : jtag_tap_state <= tms ? UPDATE_DR        : PAUSE_DR;
            PAUSE_DR         : jtag_tap_state <= tms ? EXIT2_DR         : PAUSE_DR;
            EXIT2_DR         : jtag_tap_state <= tms ? UPDATE_DR        : SHIFT_DR;
            UPDATE_DR        : jtag_tap_state <= tms ? SELECT_DR        : RUN_TEST_IDLE;
            SELECT_IR        : jtag_tap_state <= tms ? TEST_LOGIC_RESET : CAPTURE_IR;
            CAPTURE_IR       : jtag_tap_state <= tms ? EXIT1_IR         : SHIFT_IR;
            SHIFT_IR         : jtag_tap_state <= tms ? EXIT1_IR         : SHIFT_IR;
            EXIT1_IR         : jtag_tap_state <= tms ? UPDATE_IR        : PAUSE_IR;
            PAUSE_IR         : jtag_tap_state <= tms ? EXIT2_IR         : PAUSE_IR;
            EXIT2_IR         : jtag_tap_state <= tms ? UPDATE_IR        : SHIFT_IR;
            UPDATE_IR        : jtag_tap_state <= tms ? SELECT_DR        : RUN_TEST_IDLE;
            default          : jtag_tap_state <= TEST_LOGIC_RESET;
        endcase
    end
end

always @(posedge tck or negedge trst_n) begin
    if(!trst_n)begin
        ir_reg <= IR_IDCODE;
    end
    else if(dmihard_rst)begin
        ir_reg <= IR_IDCODE;
    end
    else if(jtag_tap_state == TEST_LOGIC_RESET)begin
        ir_reg <= IR_IDCODE;
    end
    else if(jtag_tap_state == SHIFT_IR)begin
        ir_reg <= {tdi, ir_reg[4:1]};
    end
end

always @(posedge tck) begin
    if(jtag_tap_state == CAPTURE_DR)begin
        case (ir_reg)
            IR_IDCODE: shift_reg <= {{(SHIFT_REG_LEN - 32){1'b0}}, idcode};
            IR_DTMCS:  shift_reg <= {{(SHIFT_REG_LEN - 32){1'b0}}, dtmcs};
            IR_DBUS:   shift_reg <= (in_busy | busy_sticky) ? {{(SHIFT_REG_LEN - 2 ){1'b0}}, 2'h3} : transfer_res;
            default:   shift_reg <= {{(SHIFT_REG_LEN - 1 ){1'b0}}, 1'b0};
        endcase
    end
    else if(jtag_tap_state == SHIFT_DR)begin
        case (ir_reg)
            IR_IDCODE: shift_reg <= {{(SHIFT_REG_LEN - 32){1'b0}}, tdi, shift_reg[31:1]};
            IR_DTMCS:  shift_reg <= {{(SHIFT_REG_LEN - 32){1'b0}}, tdi, shift_reg[31:1]};
            IR_DBUS:   shift_reg <= {tdi, shift_reg[SHIFT_REG_LEN - 1 : 1]};
            default:   shift_reg <= {{(SHIFT_REG_LEN - 1 ){1'b0}}, tdi};
        endcase
    end
end

always @(negedge tck or negedge trst_n) begin
    if(!trst_n)begin
        tdo <= 1'b0;
    end
    else if(dmihard_rst)begin
        tdo <= 1'b0;
    end
    else if(jtag_tap_state == SHIFT_IR)begin
        tdo <= ir_reg[0];
    end
    else if(jtag_tap_state == SHIFT_DR)begin
        tdo <= shift_reg[0];
    end
end

always @(posedge tck or negedge trst_n) begin
    if(!trst_n)begin
        dtm2dm_wen_reg      <= 1'b0;
    end
    else if(dmihard_rst)begin
        dtm2dm_wen_reg      <= 1'b0;
    end
    else if((jtag_tap_state == UPDATE_DR) & (ir_reg == IR_DBUS) & (!in_busy) & (!busy_sticky))begin
        dtm2dm_wen_reg      <= 1'b1;
    end
    else begin
        dtm2dm_wen_reg      <= 1'b0;
    end
end

always @(posedge tck) begin
    if((jtag_tap_state == UPDATE_DR) & (ir_reg == IR_DBUS) & (!in_busy) & (!busy_sticky))begin
        dtm2dm_data_in_reg  <= shift_reg;
    end
end

always @(posedge tck or negedge trst_n) begin
    if(!trst_n)begin
        in_busy         <= 1'b0;
    end
    else if((dtm2dm_wen_reg == 1'b1) & (!dtm2dm_full))begin
        in_busy         <= 1'b1;
    end
    else if(dm2dtm_ren_reg == 1'b1)begin
        in_busy         <= 1'b0;
    end
end

always @(posedge tck or negedge trst_n) begin
    if(!trst_n)begin
        busy_sticky         <= 1'b0;
    end
    else if(dmihard_rst | dmi_rst)begin
        busy_sticky         <= 1'b0;
    end
    else if((jtag_tap_state == CAPTURE_DR) & (ir_reg == IR_DBUS) & (in_busy | busy_sticky))begin
        busy_sticky         <= 1'b1;
    end
end

always @(posedge tck or negedge trst_n) begin
    if(!trst_n)begin
        dm2dtm_ren_reg      <= 1'b0;
    end
    else if(dmihard_rst)begin
        dm2dtm_ren_reg      <= 1'b0;
    end
    else if(dm2dtm_ren_reg)begin
        dm2dtm_ren_reg      <= 1'b0;
    end
    else if(!dm2dtm_empty)begin
        dm2dtm_ren_reg      <= 1'b1;
    end
    else begin
        dm2dtm_ren_reg      <= 1'b0;
    end
end

generate 
    if(READ_THROUGH == "TRUE") begin : read_through
        reg [SHIFT_REG_LEN - 1 : 0] transfer_res_reg;
        always @(posedge tck or negedge trst_n) begin
            if(!trst_n)begin
                transfer_res_reg      <= {SHIFT_REG_LEN{1'b0}};
            end
            else if(!dm2dtm_empty)begin
                transfer_res_reg      <= dm2dtm_data_out;
            end
        end
        assign transfer_res = transfer_res_reg;
    end
    else begin : read_tick
        assign transfer_res = dm2dtm_data_out;
    end
endgenerate

assign dtm2dm_wen       = dtm2dm_wen_reg;
assign dm2dtm_ren       = dm2dtm_ren_reg;
assign dtm2dm_data_in   = dtm2dm_data_in_reg;

endmodule //dtm
