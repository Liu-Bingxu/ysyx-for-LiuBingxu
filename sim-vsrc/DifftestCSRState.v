//控制和状态寄存器 (CSR)    高电平有效
module DifftestCSRState(
  input  [63:0] io_privilegeMode,		//表示处理器当前运行在哪个特权模式级别
  input  [63:0] io_mstatus,					//保存处理器的状态信息
  input  [63:0] io_sstatus,					//保存处理器的状态信息
  input  [63:0] io_mepc,						//存储异常程序计数器,记录异常处理程序的地址
  input  [63:0] io_sepc,						//存储异常程序计数器,记录异常处理程序的地址
  input  [63:0] io_mtval,						//存储异常值
  input  [63:0] io_stval,						//存储异常值
  input  [63:0] io_mtvec,						//存储中断异常向量表的基地址
  input  [63:0] io_stvec,						//存储中断异常向量表的基地址
  input  [63:0] io_mcause,					//存储导致异常的原因码
  input  [63:0] io_scause,					//存储导致异常的原因码
  input  [63:0] io_satp,						//存储页表基地址，用于虚拟内存管理
  input  [63:0] io_mip,							//存储中断使能和中断状态
  input  [63:0] io_mie,							//存储中断使能和中断状态
  input  [63:0] io_mscratch,				// 临时寄存器
  input  [63:0] io_sscratch,				// 临时寄存器
  input  [63:0] io_mideleg,					//控制中断异常的委托
  input  [63:0] io_medeleg					//控制中断异常的委托
);

// import "DPI-C" function void v_difftest_CSRState (
//   input   longint io_privilegeMode,
//   input   longint io_mstatus,
//   input   longint io_sstatus,
//   input   longint io_mepc,
//   input   longint io_sepc,
//   input   longint io_mtval,
//   input   longint io_stval,
//   input   longint io_mtvec,
//   input   longint io_stvec,
//   input   longint io_mcause,
//   input   longint io_scause,
//   input   longint io_satp,
//   input   longint io_mip,
//   input   longint io_mie,
//   input   longint io_mscratch,
//   input   longint io_sscratch,
//   input   longint io_mideleg,
//   input   longint io_medeleg,
//   input      byte io_coreid
// );

export "DPI-C" task difftest_CSRState;

task difftest_CSRState;
    output   longint out_io_privilegeMode,
    output   longint out_io_mstatus,
    output   longint out_io_sstatus,
    output   longint out_io_mepc,
    output   longint out_io_sepc,
    output   longint out_io_mtval,
    output   longint out_io_stval,
    output   longint out_io_mtvec,
    output   longint out_io_stvec,
    output   longint out_io_mcause,
    output   longint out_io_scause,
    output   longint out_io_satp,
    output   longint out_io_mip,
    output   longint out_io_mie,
    output   longint out_io_mscratch,
    output   longint out_io_sscratch,
    output   longint out_io_mideleg,
    output   longint out_io_medeleg

    out_io_privilegeMode    = io_privilegeMode;
    out_io_mstatus          = io_mstatus      ;
    out_io_sstatus          = io_sstatus      ;
    out_io_mepc             = io_mepc         ;
    out_io_sepc             = io_sepc         ;
    out_io_mtval            = io_mtval        ;
    out_io_stval            = io_stval        ;
    out_io_mtvec            = io_mtvec        ;
    out_io_stvec            = io_stvec        ;
    out_io_mcause           = io_mcause       ;
    out_io_scause           = io_scause       ;
    out_io_satp             = io_satp         ;
    out_io_mip              = io_mip          ;
    out_io_mie              = io_mie          ;
    out_io_mscratch         = io_mscratch     ;
    out_io_sscratch         = io_sscratch     ;
    out_io_mideleg          = io_mideleg      ;
    out_io_medeleg          = io_medeleg      ;
endtask


endmodule
