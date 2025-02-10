//执行的指令,处理器的指令提交状态   高电平有效
module DifftestInstrCommit(
  input         clock,
  input         io_valid,		//指示输入数据是否有效
  input         io_skip,		//表示是否跳过当前指令的提交(通过mmio访问串口等外设时跳过)
  input         io_isRVC,		//是否为压缩指令
  input         io_rfwen,		//整数寄存器写使能
  input         io_fpwen,		//浮点寄存器写使能
  input         io_vecwen,	//向量寄存器写使能
  input  [ 4:0] io_wpdest,	//写入的物理寄存器目标
  input  [ 7:0] io_wdest,		//写入的虚拟寄存器目标
  input  [63:0] io_pc,			//当前的程序计数器PC
  input  [31:0] io_instr,		//当前的指令内容
  input  [ 9:0] io_robIdx,	//ROB重排序缓冲区索引
  input  [ 6:0] io_lqIdx,		//LQ负载队列索引
  input  [ 6:0] io_sqIdx,		//SQ存储队列索引
  input         io_isLoad,	//是否为加载指令
  input         io_isStore,	//是否为存储指令
  input  [ 7:0] io_nFused,	//融合指令的数量
  input  [ 7:0] io_special,	//特殊指令标志
  input  [ 7:0] io_coreid,	//处理器的核心标识,单核处理器置零即可
  input  [ 7:0] io_index		//指令提交的索引
);

import "DPI-C" function void difftest_InstrCommit (
  input       bit io_skip,
  input       bit io_isRVC,
  input       bit io_rfwen,
  input       bit io_fpwen,
  input       bit io_vecwen,
  input      byte io_wpdest,
  input      byte io_wdest,
  input   longint io_pc,
  input       int io_instr,
  input       int io_robIdx,
  input      byte io_lqIdx,
  input      byte io_sqIdx,
  input       bit io_isLoad,
  input       bit io_isStore,
  input      byte io_nFused,
  input      byte io_special,
  input      byte io_coreid,
  input      byte io_index
);


always @(posedge clock) begin
    if (io_valid)
        difftest_InstrCommit (io_skip, io_isRVC, io_rfwen, io_fpwen, io_vecwen, 
        {3'h0, io_wpdest}, io_wdest, io_pc, io_instr, {22'h0, io_robIdx}, {1'b0, io_lqIdx}, {1'b0, io_sqIdx}, io_isLoad, io_isStore, io_nFused, io_special, io_coreid, io_index);
end

endmodule
