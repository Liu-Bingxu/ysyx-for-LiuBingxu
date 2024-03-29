module ifu#(parameter ADDR_LEN = 32)(
    //clock and reset
    input                   clk,
    input                   rst_n,

    //jump interface
    input                   jump_flag,
    input  [ADDR_LEN-1:0]   jump_addr,

    //axi-lite clock and resetn
    // input                   aclk,
    // input                   aresetn,

    //ar channel
    input                   arready,
    output                  arvaild,
    output [ADDR_LEN-1:0]   araddr,

    //read data channel
    input                   rvaild,
    output                  rready,
    output [1:0]            rresp,
    input  [31:0]           rdata,

    //ifu - idu interface
    output                  ifu_idu_reg_inst_vaild,
    input                   inst_ready,
    output [31:0]           ifu_idu_reg_inst
);

//pc part
reg [ADDR_LEN-1:0]  pc;
always @(posedge clk or negedge rst_n) begin
    if(!rst_n)begin
        pc <= {ADDR_LEN{1'b0}};
    end
    else begin
        if(jump_flag)begin
            pc <= jump_addr;
        end
        else if(arvaild & arready)begin
            pc <= pc + 4;
        end
    end
end

//ar part
assign araddr = pc;
reg arvaild_reg;
always @(posedge clk or negedge rst_n) begin
    if(!rst_n)begin
        arvaild_reg <= 1'b0;
    end
    else begin
        if(arvaild & arready & (~inst_ready))begin
            arvaild_reg <= 1'b0;
        end
        else if((~arvaild) & inst_ready) begin
            arvaild_reg <= 1'b1;
        end
    end
end
assign arvaild = arvaild_reg;

//read data part


//ifu - idu interface part
reg inst_vaild;


endmodule //ifu
