# Copyright (c) 2020 Alex Forencich
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

TOPLEVEL_LANG = verilog

SIM ?= icarus
# SIM ?= verilator
WAVES ?= 0

COCOTB_HDL_TIMEUNIT = 1ns
COCOTB_HDL_TIMEPRECISION = 1ps

DUT      = test_tb
TOPLEVEL = $(DUT)
MODULE   = test_eth_mac_rmii

VERILOG_SOURCES += test_tb.v
VERILOG_SOURCES += ../../rtl/enet_rx_dma.v
VERILOG_SOURCES += ../../rtl/enet_rmii_to_mii.v
VERILOG_SOURCES += ../../rtl/enet_tx_dma.v
VERILOG_SOURCES += ../../rtl/enet_chclk.v
VERILOG_SOURCES += ../../rtl/mac_tx.v
VERILOG_SOURCES += ../../rtl/net_fifo.v
VERILOG_SOURCES += ../../rtl/enet_rgmii_to_gmii_xlinx.v
VERILOG_SOURCES += ../../rtl/enet_intr_coalesce.v
VERILOG_SOURCES += ../../rtl/enet_normal_reg_tx.v
VERILOG_SOURCES += ../../rtl/enet_axi2reg.v
VERILOG_SOURCES += ../../rtl/mac_rx.v
VERILOG_SOURCES += ../../rtl/enet_rgmii_to_gmii_tx_xlinx.v
VERILOG_SOURCES += ../../rtl/enet_rmii_to_mii_tx.v
VERILOG_SOURCES += ../../rtl/enet_chclk_path.v
VERILOG_SOURCES += ../../rtl/enet_rmii_to_mii_rx.v
VERILOG_SOURCES += ../../rtl/enet_normal_reg_rx.v
VERILOG_SOURCES += ../../rtl/enet_rcr.v
VERILOG_SOURCES += ../../rtl/mdio_if.v
VERILOG_SOURCES += ../../rtl/enet_rgmii_to_gmii_dummy.v
VERILOG_SOURCES += ../../rtl/gmii_rx.v
VERILOG_SOURCES += ../../rtl/enet_core.v
VERILOG_SOURCES += ../../rtl/gmii_tx.v
VERILOG_SOURCES += ../../rtl/enet_ecr.v
# VERILOG_SOURCES += ../../rtl/enet_rgmii_to_gmii_rx_xlinx.v
VERILOG_SOURCES += ../../rtl/enet_tcr.v
VERILOG_SOURCES += ../../rtl/enet_normal_reg.v
VERILOG_SOURCES += ../../rtl/crc32.v
VERILOG_SOURCES += ../../rtl/enet_rgmii_to_gmii.v
VERILOG_SOURCES += ../../../../utils/FF_D_without_wen.v
VERILOG_SOURCES += ../../../../utils/FF_D_without_asyn_rst.v
VERILOG_SOURCES += ../../../../utils/FF_D_with_wen.v
VERILOG_SOURCES += ../../../../utils/FF_D_with_syn_rst.v
VERILOG_SOURCES += ../../../../utils/general_sync.v
VERILOG_SOURCES += ../../../../utils/async_fifo_my.v
VERILOG_SOURCES += ../../../../utils/buck_shift.v
VERILOG_SOURCES += ../../../../utils/cdc_handle.v
VERILOG_SOURCES += ../../../../utils/shift_base.v

ifeq ($(SIM), icarus)
	PLUSARGS += -fst 
else ifeq ($(SIM), verilator)
	COMPILE_ARGS += -Wno-SELRANGE -Wno-WIDTH -I../../../../utils

	ifeq ($(WAVES), 1)
		COMPILE_ARGS += --trace --trace-fst --trace-structs
		EXTRA_ARGS   += --trace --trace-fst --trace-structs
	endif
endif

include $(shell cocotb-config --makefiles)/Makefile.sim

clean::
	@rm -rf iverilog_dump.v
	@rm -rf dump.fst $(TOPLEVEL).fst

