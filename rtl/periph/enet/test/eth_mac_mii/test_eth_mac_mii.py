#!/usr/bin/env python
"""

Copyright (c) 2020 Alex Forencich

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.

"""

import itertools
import logging
import os
import random
import struct
import zlib

from typing import List, Dict, Optional, Tuple

import cocotb_test.simulator

import cocotb
from cocotb.clock import Clock, Timer
from cocotb.triggers import RisingEdge, Event
from cocotb.regression import TestFactory

from cocotbext.eth import GmiiFrame, MiiPhy
from cocotbext.axi import AxiBus, AxiSlave, AxiMaster

from mii_phy_my import MiiPhy_my

class SRAM_target:
    """SRAM memory model with configurable address mapping"""

    def __init__(self, name:str = None, w_delay:int = 0 , r_delay:int = 0):
        self.log = logging.getLogger("cocotb.tb." + name)
        self.addrmap:Dict[int:bytearray] = {}
        self.log.setLevel(logging.INFO)
        self.w_delay = w_delay
        self.r_delay = r_delay

    def add_memory_block(self, addr:int, data:bytearray) -> None :
        """Add a memory block to the address map"""
        if addr in self.addrmap:
            self.log.warning(f"Overwriting existing block at 0x{addr:X}")
        self.addrmap[addr] = bytearray(data)

    async def write(self, address : int, data : bytes) -> None :
        """Write data to SRAM starting at specified address"""
        self.log.debug(f"WRITE @ 0x{address:08X}, {len(data)} bytes")
        if self.w_delay != 0:
            await Timer(self.w_delay, units="ns")
        for i, byte in enumerate(data):
            abs_addr = address + i
            base, block = self._find_block(abs_addr)
            
            if block is None:
                self.log.error(f"Write to unmapped address: 0x{abs_addr:08X}")
                continue
                
            offset = abs_addr - base
            if offset < len(block):
                block[offset] = byte
                self.log.debug(f"  [0x{abs_addr:08X}] = 0x{byte:02X}")
            else:
                self.log.error(f"Write out-of-block: 0x{abs_addr:08X} (block size: 0x{len(block):X})")

    async def read(self, address : int, length : int) -> bytes :
        """Read data from SRAM starting at specified address"""
        self.log.debug(f"READ @ 0x{address:08X}, {length} bytes")
        if self.r_delay != 0:
            await Timer(self.r_delay, units="ns")
        result = bytearray()
        
        for i in range(length):
            abs_addr = address + i
            base, block = self._find_block(abs_addr)
            
            if block is None:
                result.append(0)
                await Timer(20000, units="ns")
                self.log.warning(f"Read from unmapped address: 0x{abs_addr:08X}, returning 0")
                continue
                
            offset = abs_addr - base
            if offset < len(block):
                result.append(block[offset])
                self.log.debug(f"  [0x{abs_addr:08X}] = 0x{block[offset]:02X}")
            else:
                result.append(0)
                self.log.error(f"Read out-of-block: 0x{abs_addr:08X} (block size: 0x{len(block):X})")
        
        return bytes(result)

    def _find_block(self, address: int) -> Tuple[int, Optional[bytearray]]:
        """Find the memory block containing the given address"""
        for base, block in self.addrmap.items():
            if base <= address < base + len(block):
                return base, block
        return address, None

class TB:
    def __init__(self, dut, speed=100e6, tx_w_delay = 0, tx_r_delay = 0, rx_w_delay = 0, rx_r_delay = 0):
        self.dut = dut

        self.log = logging.getLogger("cocotb.tb")
        self.log.setLevel(logging.DEBUG)

        cocotb.start_soon(Clock(dut.clk, 20, units="ns").start())

        self.mii_phy = MiiPhy(
            dut.enet_txd,
            dut.enet_tx_er,
            dut.enet_tx_en,
            dut.enet_tx_clk,
            dut.enet_rxd,
            dut.enet_rx_er,
            dut.enet_rx_dv,
            dut.enet_rx_clk,
            speed=speed,
        )

        self.tx_sram = SRAM_target("tx_sram", w_delay=tx_w_delay, r_delay=tx_r_delay)
        self.rx_sram = SRAM_target("rx_sram", w_delay=rx_w_delay, r_delay=rx_r_delay)

        self.axis_cfg = AxiMaster(AxiBus.from_prefix(dut, "mst"), dut.clk, dut.rst_n, reset_active_level=False)
        self.axis_tx_dma = AxiSlave(AxiBus.from_prefix(dut, "slv_tx"), dut.tx_clk, dut.tx_rst_n, target = self.tx_sram, reset_active_level=False)
        self.axis_rx_dma = AxiSlave(AxiBus.from_prefix(dut, "slv_rx"), dut.rx_clk, dut.rx_rst_n, target = self.rx_sram, reset_active_level=False)

    async def reset(self):
        self.dut.enet_rst_n.setimmediatevalue(0)
        await RisingEdge(self.dut.clk)
        await RisingEdge(self.dut.clk)
        self.dut.enet_rst_n.value = 0
        await RisingEdge(self.dut.clk)
        await RisingEdge(self.dut.clk)
        self.dut.enet_rst_n.value = 1
        await RisingEdge(self.dut.clk)
        await RisingEdge(self.dut.clk)

    def set_speed(self, speed):
        pass

def generate_mac(unicast: bool = True, multicast: bool = False, broadcast: bool = False) -> bytes:
    """
    生成MAC地址
    
    参数:
        unicast: 单播地址 (第一个字节最低位为0)
        multicast: 多播地址 (第一个字节最低位为1)
        broadcast: 广播地址 (全1)
    
    返回:
        6字节的MAC地址
    """
    if broadcast:
        return b'\xFF\xFF\xFF\xFF\xFF\xFF'
    
    mac = os.urandom(6)
    
    if multicast:
        # 多播地址: 第一个字节的最低有效位为1
        mac = bytes([mac[0] | 0x01]) + mac[1:]
    elif unicast:
        # 单播地址: 第一个字节的最低有效位为0
        mac = bytes([mac[0] & 0xFE]) + mac[1:]
    
    return mac

def get_crc32_hash(mac: bytes, bits: int = 6) -> int:
    """
    计算MAC地址的CRC32校验码并取指定位数作为hash地址
    
    参数:
        mac: MAC地址字节
        bits: 要取的位数
    
    返回:
        hash地址
    """
    # 使用zlib计算CRC32
    crc_value = zlib.crc32(mac) & 0xFFFFFFFF
    
    # 取高bits位
    hash_value = (crc_value >> (32 - bits)) & ((1 << bits) - 1)
    return hash_value

def generate_pause_frame(src_mac: bytes, pause_time: int = 65535) -> bytes:
    """
    生成IEEE 802.3x PAUSE帧（流量控制帧）
    
    PAUSE帧用于以太网流量控制，告诉对方停止发送数据一段时间
    
    参数:
        src_mac: 源MAC地址 (6字节)
        pause_time: 暂停时间，以512位时间为单位 (0-65535)
    
    返回:
        完整的PAUSE帧字节数据
    
    参考:
        IEEE 802.3x - 全双工流量控制
    """
    if len(src_mac) != 6:
        raise ValueError("源MAC地址必须是6字节")
    
    if pause_time < 0 or pause_time > 65535:
        raise ValueError("暂停时间必须在0-65535范围内")
    
    # 1. 目的MAC地址: 固定的组播地址 01-80-C2-00-00-01
    dst_mac = b'\x01\x80\xc2\x00\x00\x01'
    
    # 2. 源MAC地址: 传入的源MAC
    # src_mac = src_mac (已传入)
    
    # 3. 以太网类型: 0x8808 表示控制帧
    ether_type = b'\x88\x08'
    
    # 4. MAC控制操作码: 0x0001 表示PAUSE操作
    opcode = b'\x00\x01'
    
    # 5. 暂停时间: 2字节大端序
    pause_time_bytes = struct.pack('>H', pause_time)
    
    # 6. 保留字段: 42字节，全部为0
    reserved = b'\x00' * 42
    
    # 7. 组装帧 (不包括FCS)
    frame_without_fcs = dst_mac + src_mac + ether_type + opcode + pause_time_bytes + reserved
    
    # 8. 计算CRC32帧校验序列
    crc_value = zlib.crc32(frame_without_fcs) & 0xFFFFFFFF
    fcs = struct.pack('<I', crc_value)
    
    # 9. 完整的PAUSE帧
    pause_frame = frame_without_fcs + fcs
    
    return pause_frame

def check_data(crcfwd:bool, recv_data:bytes, test_data:bytes):
    if crcfwd :
        assert recv_data[0:len(test_data)] == test_data[0:-4] + (b'\x00' * 4)
    else:
        assert recv_data[0:len(test_data)]     == test_data

async def run_test_rx(dut, crcfwd = False, send_through = False, payload_lengths=None, payload_data=None, ifg=12, speed=100e6):

    logging.disable(logging.INFO)

    tb = TB(dut, speed)

    tb.mii_phy.rx.ifg = ifg

    tb.set_speed(speed)

    await tb.reset()

    for k in range(100):
        await RisingEdge(dut.enet_rx_clk)

    test_max_num = 2 ** 22
    test_desc_addr = random.getrandbits(22)
    assert test_desc_addr < test_max_num
    test_desc = bytearray(b'\x00' * 1024)
    tb.rx_sram.add_memory_block(test_desc_addr * 1024, test_desc)
    test_buf_list = []
    for i in range(128):
        test_buf_addr = random.getrandbits(21)
        assert test_buf_addr * 2 < test_max_num
        while test_buf_addr * 2 * 1024 in tb.rx_sram.addrmap:
            test_buf_addr = random.getrandbits(21)
            assert test_buf_addr * 2 < test_max_num
        test_buf = bytearray(b'\x00' * 2048)
        tb.rx_sram.add_memory_block(test_buf_addr * 2 * 1024, test_buf)
        test_buf_list.append(test_buf_addr * 2)
        tb.rx_sram.addrmap[test_desc_addr * 1024][8 * i + 0] = 0
        tb.rx_sram.addrmap[test_desc_addr * 1024][8 * i + 1] = 0
        tb.rx_sram.addrmap[test_desc_addr * 1024][8 * i + 2] = 0
        tb.rx_sram.addrmap[test_desc_addr * 1024][8 * i + 3] = 128
        tb.rx_sram.addrmap[test_desc_addr * 1024][8 * i + 4] = 0
        tb.rx_sram.addrmap[test_desc_addr * 1024][8 * i + 5] = test_buf_addr * 2 * 4 % 256
        tb.rx_sram.addrmap[test_desc_addr * 1024][8 * i + 6] = test_buf_addr * 2 * 4 // 256 % 256
        tb.rx_sram.addrmap[test_desc_addr * 1024][8 * i + 7] = test_buf_addr * 2 * 4 // 256 // 256 % 256
    tb.rx_sram.addrmap[test_desc_addr * 1024][8 * 127 + 3] = 160

    rdsr:int = test_desc_addr * 1024
    await tb.axis_cfg.write(0x180, rdsr.to_bytes(length=4, byteorder='little', signed=False), awid = 0x30, size = 0x2, cache = 0x0, prot = 0x0)

    rcr:int = 8 | (1 << 14 if crcfwd else 0)
    await tb.axis_cfg.write(0x84, rcr.to_bytes(length=4, byteorder='little', signed=False), awid = 0x30, size = 0x2, cache = 0x0, prot = 0x0)

    ecr:int = 0x5EE * 256 * 256 + 0xB
    await tb.axis_cfg.write(0x24, ecr.to_bytes(length=4, byteorder='little', signed=False), awid = 0x30, size = 0x2, cache = 0x0, prot = 0x0)

    await tb.axis_cfg.write(0x10, (0).to_bytes(length=4, byteorder='little', signed=False), awid = 0x30, size = 0x2, cache = 0x0, prot = 0x0)

    if send_through:
        await tb.axis_cfg.write(0x190, (5).to_bytes(length=4, byteorder='little', signed=False), awid = 0x30, size = 0x2, cache = 0x0, prot = 0x0)

    await Timer(1000 * (100e6 // speed), units="ns")

    test_frames:List[bytearray, Event, int] = [[payload_data(x), Event(), x] for x in payload_lengths()]

    for i, [test_data, event, length] in enumerate(test_frames):
        test_frame = GmiiFrame.from_raw_payload(test_data, tx_complete = event)
        await tb.mii_phy.rx.send(test_frame)
        await event.wait()
        await Timer(len(test_data) * 20 * (100e6 // speed), units="ns")
        check_data(crcfwd, tb.rx_sram.addrmap[test_buf_list[i] * 1024], test_data)
        if crcfwd:
            assert tb.rx_sram.addrmap[test_desc_addr * 1024][8 * i + 0] == (max(length, 46) + 14) % 256
            assert tb.rx_sram.addrmap[test_desc_addr * 1024][8 * i + 1] == (max(length, 46) + 14) // 256 % 256
        else:
            assert tb.rx_sram.addrmap[test_desc_addr * 1024][8 * i + 0] == (max(length, 46) + 18) % 256
            assert tb.rx_sram.addrmap[test_desc_addr * 1024][8 * i + 1] == (max(length, 46) + 18) // 256 % 256

    await RisingEdge(dut.enet_rx_clk)
    await RisingEdge(dut.enet_rx_clk)

    logging.disable(logging.DEBUG)

async def run_test_tx(dut, crcfwd:bool, tc:bool, addins:bool, strfwd:bool, payload_lengths=None, payload_data=None, ifg=12, speed=100e6):

    logging.disable(logging.INFO)

    def random_mac():
        return bytes([random.randint(0x00, 0xff) for _ in range(6)])

    src_mac = random_mac()  # 源MAC地址

    tb = TB(dut, speed)

    tb.mii_phy.rx.ifg = ifg

    tb.set_speed(speed)

    await tb.reset()

    for k in range(100):
        await RisingEdge(dut.enet_tx_clk)

    if addins:
        test_frames:List[bytearray, Event, int] = [[payload_data(x, use_mac=True, mac_addr=src_mac), Event(), x] for x in payload_lengths()]
    else:
        test_frames:List[bytearray, Event, int] = [[payload_data(x), Event(), x] for x in payload_lengths()]

    test_max_num = 2 ** 22
    test_desc_addr = random.getrandbits(22)
    assert test_desc_addr < test_max_num
    test_desc = bytearray(b'\x00' * 1024)
    tb.tx_sram.add_memory_block(test_desc_addr * 1024, test_desc)
    test_buf_list = []
    for i in range(len(test_frames)):
        test_buf_addr = random.getrandbits(21)
        assert test_buf_addr * 2 < test_max_num
        while test_buf_addr * 2 * 1024 in tb.tx_sram.addrmap:
            test_buf_addr = random.getrandbits(21)
            assert test_buf_addr * 2 < test_max_num
        test_buf:bytearray = bytearray(test_frames[i][0]) + bytearray(b'\x00' * (8 - ((test_frames[i][2] + 18) % 8)))
        tb.tx_sram.add_memory_block(test_buf_addr * 2 * 1024, test_buf)
        test_buf_list.append(test_buf_addr * 2)
        tb.tx_sram.addrmap[test_desc_addr * 1024][8 * i + 0] = (test_frames[i][2] + 14 + (4 if (tc | crcfwd) else 0)) % 256
        tb.tx_sram.addrmap[test_desc_addr * 1024][8 * i + 1] = (test_frames[i][2] + 14 + (4 if (tc | crcfwd) else 0)) // 256 % 256
        tb.tx_sram.addrmap[test_desc_addr * 1024][8 * i + 2] = 0
        tb.tx_sram.addrmap[test_desc_addr * 1024][8 * i + 3] = 0x8C if tc else 0x88
        tb.tx_sram.addrmap[test_desc_addr * 1024][8 * i + 4] = 0
        tb.tx_sram.addrmap[test_desc_addr * 1024][8 * i + 5] = test_buf_addr * 2 * 4 % 256
        tb.tx_sram.addrmap[test_desc_addr * 1024][8 * i + 6] = test_buf_addr * 2 * 4 // 256 % 256
        tb.tx_sram.addrmap[test_desc_addr * 1024][8 * i + 7] = test_buf_addr * 2 * 4 // 256 // 256 % 256
    tb.tx_sram.addrmap[test_desc_addr * 1024][8 * (len(test_frames) - 1) + 3] = 0xAC if tc else 0xA8

    tdsr:int = test_desc_addr * 1024
    await tb.axis_cfg.write(0x184, tdsr.to_bytes(length=4, byteorder='little', signed=False), awid = 0x30, size = 0x2, cache = 0x0, prot = 0x0)

    tcr:int = (1 << 8 if addins else 0) | (1 << 9 if crcfwd else 0)
    await tb.axis_cfg.write(0xC4, tcr.to_bytes(length=4, byteorder='little', signed=False), awid = 0x30, size = 0x2, cache = 0x0, prot = 0x0)

    tfwr:int = (1 << 8 if strfwd else 0)
    await tb.axis_cfg.write(0x144, tfwr.to_bytes(length=4, byteorder='little', signed=False), awid = 0x30, size = 0x2, cache = 0x0, prot = 0x0)

    ecr:int = 0x5EE * 256 * 256 + 0xB
    await tb.axis_cfg.write(0x24, ecr.to_bytes(length=4, byteorder='little', signed=False), awid = 0x30, size = 0x2, cache = 0x0, prot = 0x0)

    await tb.axis_cfg.write(0xE4, bytes(src_mac[3::-1]), awid = 0x30, size = 0x2, cache = 0x0, prot = 0x0)
    await tb.axis_cfg.write(0xE8, bytes((b'\x00' * 2) + src_mac[5:3:-1]), awid = 0x30, size = 0x2, cache = 0x0, prot = 0x0)

    await tb.axis_cfg.write(0x14, (0).to_bytes(length=4, byteorder='little', signed=False), awid = 0x30, size = 0x2, cache = 0x0, prot = 0x0)

    await Timer(1000 * 20, units="ns")

    for i, [test_data, event, _] in enumerate(test_frames):
        rx_frame:GmiiFrame = await tb.mii_phy.tx.recv()

        assert rx_frame.get_payload(strip_fcs=False) == test_data
        assert rx_frame.check_fcs()
        assert rx_frame.error is None
        # check_data(crcfwd, paden, tb.rx_sram.addrmap[test_buf_list[i] * 1024], test_data)

    assert tb.mii_phy.tx.empty()

    await RisingEdge(dut.enet_tx_clk)
    await RisingEdge(dut.enet_tx_clk)

    logging.disable(logging.DEBUG)

async def run_test_rx_paden(dut, use_8023: bool = False, payload_lengths=None, payload_data=None, ifg=12, speed=100e6):

    logging.disable(logging.INFO)

    tb = TB(dut, speed)

    tb.mii_phy.rx.ifg = ifg

    tb.set_speed(speed)

    await tb.reset()

    for k in range(100):
        await RisingEdge(dut.enet_rx_clk)

    test_max_num = 2 ** 22
    test_desc_addr = random.getrandbits(22)
    assert test_desc_addr < test_max_num
    test_desc = bytearray(b'\x00' * 1024)
    tb.rx_sram.add_memory_block(test_desc_addr * 1024, test_desc)
    test_buf_list = []
    for i in range(128):
        test_buf_addr = random.getrandbits(21)
        assert test_buf_addr * 2 < test_max_num
        while test_buf_addr * 2 * 1024 in tb.rx_sram.addrmap:
            test_buf_addr = random.getrandbits(21)
            assert test_buf_addr * 2 < test_max_num
        test_buf = bytearray(b'\x00' * 2048)
        tb.rx_sram.add_memory_block(test_buf_addr * 2 * 1024, test_buf)
        test_buf_list.append(test_buf_addr * 2)
        tb.rx_sram.addrmap[test_desc_addr * 1024][8 * i + 0] = 0
        tb.rx_sram.addrmap[test_desc_addr * 1024][8 * i + 1] = 0
        tb.rx_sram.addrmap[test_desc_addr * 1024][8 * i + 2] = 0
        tb.rx_sram.addrmap[test_desc_addr * 1024][8 * i + 3] = 128
        tb.rx_sram.addrmap[test_desc_addr * 1024][8 * i + 4] = 0
        tb.rx_sram.addrmap[test_desc_addr * 1024][8 * i + 5] = test_buf_addr * 2 * 4 % 256
        tb.rx_sram.addrmap[test_desc_addr * 1024][8 * i + 6] = test_buf_addr * 2 * 4 // 256 % 256
        tb.rx_sram.addrmap[test_desc_addr * 1024][8 * i + 7] = test_buf_addr * 2 * 4 // 256 // 256 % 256
    tb.rx_sram.addrmap[test_desc_addr * 1024][8 * 127 + 3] = 160

    rdsr:int = test_desc_addr * 1024
    await tb.axis_cfg.write(0x180, rdsr.to_bytes(length=4, byteorder='little', signed=False), awid = 0x30, size = 0x2, cache = 0x0, prot = 0x0)

    rcr:int = 8 | 1 << 12
    await tb.axis_cfg.write(0x84, rcr.to_bytes(length=4, byteorder='little', signed=False), awid = 0x30, size = 0x2, cache = 0x0, prot = 0x0)

    ecr:int = 0x5EE * 256 * 256 + 0xB
    await tb.axis_cfg.write(0x24, ecr.to_bytes(length=4, byteorder='little', signed=False), awid = 0x30, size = 0x2, cache = 0x0, prot = 0x0)

    await tb.axis_cfg.write(0x10, (0).to_bytes(length=4, byteorder='little', signed=False), awid = 0x30, size = 0x2, cache = 0x0, prot = 0x0)

    await Timer(1000 * 20, units="ns")

    test_frames:List[bytearray, Event, int] = [[payload_data(x, use_8023=use_8023), Event(), x] for x in (payload_lengths() + list(range(1, 47)))]

    for i, [test_data, event, length] in enumerate(test_frames):
        test_frame = GmiiFrame.from_raw_payload(test_data, tx_complete = event)
        await tb.mii_phy.rx.send(test_frame)
        await event.wait()
        await Timer(len(test_data) * 20 * (100e6 // speed), units="ns")
        if use_8023:
            assert tb.rx_sram.addrmap[test_buf_list[i] * 1024][0:len(test_data)] == (test_data[0:length + 14] + (b'\x00' * (len(test_data) - length - 14)))
            assert tb.rx_sram.addrmap[test_desc_addr * 1024][8 * i + 0] == (length + 14) % 256
            assert tb.rx_sram.addrmap[test_desc_addr * 1024][8 * i + 1] == (length + 14) // 256 % 256
        else:
            assert tb.rx_sram.addrmap[test_buf_list[i] * 1024][0:len(test_data)] == (test_data[0:len(test_data) - 4] + (b'\x00' * 4))
            assert tb.rx_sram.addrmap[test_desc_addr * 1024][8 * i + 0] == (max(length, 46) + 14) % 256
            assert tb.rx_sram.addrmap[test_desc_addr * 1024][8 * i + 1] == (max(length, 46) + 14) // 256 % 256

    await RisingEdge(dut.enet_rx_clk)
    await RisingEdge(dut.enet_rx_clk)

    logging.disable(logging.DEBUG)

async def run_test_rx_cast(dut, bc_rej: bool = False, payload_lengths=None, payload_data=None, ifg=12, speed=1000e6):

    logging.disable(logging.INFO)

    tb = TB(dut, speed)

    self_mac = generate_mac()  # 源MAC地址

    tb.mii_phy.rx.ifg = ifg

    tb.set_speed(speed)

    await tb.reset()

    for k in range(100):
        await RisingEdge(dut.enet_rx_clk)

    def operation_1(payload_size: int) -> Tuple[bytes]:
        """操作1: 单播判断，生成给定MAC地址为目标的以太网帧"""
        dst_mac = self_mac
        src_mac = generate_mac(unicast=True)
        
        frame = payload_data(payload_size, dst_mac = dst_mac, use_mac = True, mac_addr = src_mac)
        
        return frame

    def operation_2(payload_size: int) -> Tuple[bytes, int]:
        """操作2: 单播判断，随机生成单播MAC地址，计算hash地址"""
        dst_mac = generate_mac(unicast=True)
        while self_mac == dst_mac:
            dst_mac = generate_mac(unicast=True)
        src_mac = generate_mac(unicast=True)
        
        frame = payload_data(payload_size, dst_mac = dst_mac, use_mac = True, mac_addr = src_mac)
        hash_addr = get_crc32_hash(dst_mac, 6)
        
        return frame, hash_addr

    def operation_3(payload_size: int) -> Tuple[bytes, int]:
        """操作3: 组播判断，随机生成多播MAC地址，计算hash地址"""
        dst_mac = generate_mac(multicast=True)
        src_mac = generate_mac(unicast=True)
        
        frame = payload_data(payload_size, dst_mac = dst_mac, use_mac = True, mac_addr = src_mac)
        hash_addr = get_crc32_hash(dst_mac, 6)
        
        return frame, hash_addr

    def operation_4(payload_size: int) -> Tuple[bytes]:
        """操作5: 广播判断，生成广播MAC地址为目标的以太网帧"""
        dst_mac = generate_mac(broadcast=True)
        src_mac = generate_mac(unicast=True)
        
        frame = payload_data(payload_size, dst_mac = dst_mac, use_mac = True, mac_addr = src_mac)
        
        return frame

    test_max_num = 2 ** 22
    test_desc_addr = random.getrandbits(22)
    assert test_desc_addr < test_max_num
    test_desc = bytearray(b'\x00' * 1024)
    tb.rx_sram.add_memory_block(test_desc_addr * 1024, test_desc)
    test_buf_list = []
    for i in range(128):
        test_buf_addr = random.getrandbits(21)
        assert test_buf_addr * 2 < test_max_num
        while test_buf_addr * 2 * 1024 in tb.rx_sram.addrmap:
            test_buf_addr = random.getrandbits(21)
            assert test_buf_addr * 2 < test_max_num
        test_buf = bytearray(b'\x00' * 2048)
        tb.rx_sram.add_memory_block(test_buf_addr * 2 * 1024, test_buf)
        test_buf_list.append(test_buf_addr * 2)
        tb.rx_sram.addrmap[test_desc_addr * 1024][8 * i + 0] = 0
        tb.rx_sram.addrmap[test_desc_addr * 1024][8 * i + 1] = 0
        tb.rx_sram.addrmap[test_desc_addr * 1024][8 * i + 2] = 0
        tb.rx_sram.addrmap[test_desc_addr * 1024][8 * i + 3] = 128
        tb.rx_sram.addrmap[test_desc_addr * 1024][8 * i + 4] = 0
        tb.rx_sram.addrmap[test_desc_addr * 1024][8 * i + 5] = test_buf_addr * 2 * 4 % 256
        tb.rx_sram.addrmap[test_desc_addr * 1024][8 * i + 6] = test_buf_addr * 2 * 4 // 256 % 256
        tb.rx_sram.addrmap[test_desc_addr * 1024][8 * i + 7] = test_buf_addr * 2 * 4 // 256 // 256 % 256
    tb.rx_sram.addrmap[test_desc_addr * 1024][8 * 127 + 3] = 160

    rdsr:int = test_desc_addr * 1024
    await tb.axis_cfg.write(0x180, rdsr.to_bytes(length=4, byteorder='little', signed=False), awid = 0x30, size = 0x2, cache = 0x0, prot = 0x0)

    rcr:int = 0x1 << 4 if bc_rej else 0x0
    await tb.axis_cfg.write(0x84, rcr.to_bytes(length=4, byteorder='little', signed=False), awid = 0x30, size = 0x2, cache = 0x0, prot = 0x0)

    ecr:int = 0x5EE * 256 * 256 + 0xB
    await tb.axis_cfg.write(0x24, ecr.to_bytes(length=4, byteorder='little', signed=False), awid = 0x30, size = 0x2, cache = 0x0, prot = 0x0)

    await tb.axis_cfg.write(0xE4, bytes(self_mac[3::-1]), awid = 0x30, size = 0x2, cache = 0x0, prot = 0x0)
    await tb.axis_cfg.write(0xE8, bytes((b'\x00' * 2) + self_mac[5:3:-1]), awid = 0x30, size = 0x2, cache = 0x0, prot = 0x0)

    await tb.axis_cfg.write(0x10, (0).to_bytes(length=4, byteorder='little', signed=False), awid = 0x30, size = 0x2, cache = 0x0, prot = 0x0)

    await Timer(1000 * (100e6 // speed), units="ns")

    i = 0
    iaur = 0
    ialr = 0
    gaur = 0
    galr = 0
    for x in payload_lengths():
        while(True):
            operation = random.randint(0, 5)
        
            if operation == 0:
                # 操作1: 单播判断，给定MAC地址
                frame = operation_1(x)
                
                event = Event()
                test_frame = GmiiFrame.from_raw_payload(frame, tx_complete = event)
                await tb.mii_phy.rx.send(test_frame)
                await event.wait()
                await Timer(len(frame) * 20 * int(100e6 // speed), units="ns")
                assert tb.rx_sram.addrmap[test_buf_list[i] * 1024][0:len(frame)] == frame
                assert tb.rx_sram.addrmap[test_desc_addr * 1024][8 * i + 0] == (max(x, 46) + 18) % 256
                assert tb.rx_sram.addrmap[test_desc_addr * 1024][8 * i + 1] == (max(x, 46) + 18) // 256 % 256
                
                i = i + 1
                break
            elif operation == 1:
                # 操作2: 单播判断成功，随机单播MAC地址
                frame, hash_addr = operation_2(x)
                
                if hash_addr >= 32:
                    ialr |= (1 << (hash_addr - 32))
                else:
                    iaur |= (1 << hash_addr)

                await tb.axis_cfg.write(0x118, iaur.to_bytes(length=4, byteorder='little', signed=False), awid = 0x30, size = 0x2, cache = 0x0, prot = 0x0)
                await tb.axis_cfg.write(0x11C, ialr.to_bytes(length=4, byteorder='little', signed=False), awid = 0x30, size = 0x2, cache = 0x0, prot = 0x0)

                await Timer(1000 * (100e6 // speed), units="ns")
                
                event = Event()
                test_frame = GmiiFrame.from_raw_payload(frame, tx_complete = event)
                await tb.mii_phy.rx.send(test_frame)
                await event.wait()
                await Timer(len(frame) * 20 * int(100e6 // speed), units="ns")
                assert tb.rx_sram.addrmap[test_buf_list[i] * 1024][0:len(frame)] == frame
                assert tb.rx_sram.addrmap[test_desc_addr * 1024][8 * i + 0] == (max(x, 46) + 18) % 256
                assert tb.rx_sram.addrmap[test_desc_addr * 1024][8 * i + 1] == (max(x, 46) + 18) // 256 % 256
                
                i = i + 1
                break
            elif operation == 2:
                # 操作2: 单播判断失败，随机单播MAC地址
                frame, hash_addr = operation_2(x)
                
                if hash_addr >= 32:
                    ialr &= (~(1 << (hash_addr - 32)))
                else:
                    iaur &= (~(1 << hash_addr))

                await tb.axis_cfg.write(0x118, iaur.to_bytes(length=4, byteorder='little', signed=False), awid = 0x30, size = 0x2, cache = 0x0, prot = 0x0)
                await tb.axis_cfg.write(0x11C, ialr.to_bytes(length=4, byteorder='little', signed=False), awid = 0x30, size = 0x2, cache = 0x0, prot = 0x0)

                await Timer(1000 * (100e6 // speed), units="ns")
                
                event = Event()
                test_frame = GmiiFrame.from_raw_payload(frame, tx_complete = event)
                await tb.mii_phy.rx.send(test_frame)
                await event.wait()
                await Timer(len(frame) * 20 * int(100e6 // speed), units="ns")
                assert tb.rx_sram.addrmap[test_buf_list[i] * 1024][0:len(frame)] == (b'\x00' * len(frame))
                assert tb.rx_sram.addrmap[test_desc_addr * 1024][8 * i + 0] == 0
                assert tb.rx_sram.addrmap[test_desc_addr * 1024][8 * i + 1] == 0
            elif operation == 3:
                # 操作3: 组播判断成功
                frame, hash_addr = operation_3(x)
                
                if hash_addr >= 32:
                    galr |= (1 << (hash_addr - 32))
                else:
                    gaur |= (1 << hash_addr)
                
                await tb.axis_cfg.write(0x120, gaur.to_bytes(length=4, byteorder='little', signed=False), awid = 0x30, size = 0x2, cache = 0x0, prot = 0x0)
                await tb.axis_cfg.write(0x124, galr.to_bytes(length=4, byteorder='little', signed=False), awid = 0x30, size = 0x2, cache = 0x0, prot = 0x0)

                await Timer(1000 * (100e6 // speed), units="ns")
                
                event = Event()
                test_frame = GmiiFrame.from_raw_payload(frame, tx_complete = event)
                await tb.mii_phy.rx.send(test_frame)
                await event.wait()
                await Timer(len(frame) * 20 * int(100e6 // speed), units="ns")
                assert tb.rx_sram.addrmap[test_buf_list[i] * 1024][0:len(frame)] == frame
                assert tb.rx_sram.addrmap[test_desc_addr * 1024][8 * i + 0] == (max(x, 46) + 18) % 256
                assert tb.rx_sram.addrmap[test_desc_addr * 1024][8 * i + 1] == (max(x, 46) + 18) // 256 % 256
                
                i = i + 1
                break
            elif operation == 4:
                # 操作4: 组播判断失败
                frame, hash_addr = operation_3(x)
                
                if hash_addr >= 32:
                    galr &= (~(1 << (hash_addr - 32)))
                else:
                    gaur &= (~(1 << hash_addr))
                
                await tb.axis_cfg.write(0x120, gaur.to_bytes(length=4, byteorder='little', signed=False), awid = 0x30, size = 0x2, cache = 0x0, prot = 0x0)
                await tb.axis_cfg.write(0x124, galr.to_bytes(length=4, byteorder='little', signed=False), awid = 0x30, size = 0x2, cache = 0x0, prot = 0x0)

                await Timer(1000 * (100e6 // speed), units="ns")
                
                event = Event()
                test_frame = GmiiFrame.from_raw_payload(frame, tx_complete = event)
                await tb.mii_phy.rx.send(test_frame)
                await event.wait()
                await Timer(len(frame) * 20 * int(100e6 // speed), units="ns")
                assert tb.rx_sram.addrmap[test_buf_list[i] * 1024][0:len(frame)] == (b'\x00' * len(frame))
                assert tb.rx_sram.addrmap[test_desc_addr * 1024][8 * i + 0] == 0
                assert tb.rx_sram.addrmap[test_desc_addr * 1024][8 * i + 1] == 0
            else:  # operation == 5
                # 操作5: 广播判断
                frame = operation_4(x)
                if bc_rej:
                    event = Event()
                    test_frame = GmiiFrame.from_raw_payload(frame, tx_complete = event)
                    await tb.mii_phy.rx.send(test_frame)
                    await event.wait()
                    await Timer(len(frame) * 20 * int(100e6 // speed), units="ns")
                    assert tb.rx_sram.addrmap[test_buf_list[i] * 1024][0:len(frame)] == (b'\x00' * len(frame))
                    assert tb.rx_sram.addrmap[test_desc_addr * 1024][8 * i + 0] == 0
                    assert tb.rx_sram.addrmap[test_desc_addr * 1024][8 * i + 1] == 0
                else:
                    event = Event()
                    test_frame = GmiiFrame.from_raw_payload(frame, tx_complete = event)
                    await tb.mii_phy.rx.send(test_frame)
                    await event.wait()
                    await Timer(len(frame) * 20 * int(100e6 // speed), units="ns")
                    assert tb.rx_sram.addrmap[test_buf_list[i] * 1024][0:len(frame)] == frame
                    assert tb.rx_sram.addrmap[test_desc_addr * 1024][8 * i + 0] == (max(x, 46) + 18) % 256
                    assert tb.rx_sram.addrmap[test_desc_addr * 1024][8 * i + 1] == (max(x, 46) + 18) // 256 % 256
                    
                    i = i + 1
                    break

    await RisingEdge(dut.enet_rx_clk)
    await RisingEdge(dut.enet_rx_clk)

    logging.disable(logging.DEBUG)

async def run_test_tx_pause(dut, ifg=12, speed=1000e6):

    logging.disable(logging.INFO)

    dst_mac = b'\x01\x80\xC2\x00\x00\x01'
    src_mac = generate_mac()  # 源MAC地址
    length_type = b'\x88\x08'
    pause_opcode = b'\x00\x01'
    padding = bytes(b'\x00' * 42)

    tb = TB(dut, speed)

    tb.mii_phy.rx.ifg = ifg

    tb.set_speed(speed)

    await tb.reset()

    for k in range(100):
        await RisingEdge(dut.enet_tx_clk)

    ecr:int = 0x5EE * 256 * 256 + 0xB
    await tb.axis_cfg.write(0x24, ecr.to_bytes(length=4, byteorder='little', signed=False), awid = 0x30, size = 0x2, cache = 0x0, prot = 0x0)

    await tb.axis_cfg.write(0xE4, bytes(src_mac[3::-1]), awid = 0x30, size = 0x2, cache = 0x0, prot = 0x0)
    await tb.axis_cfg.write(0xE8, bytes((b'\x00' * 2) + src_mac[5:3:-1]), awid = 0x30, size = 0x2, cache = 0x0, prot = 0x0)

    for _ in range(100):
        hi = bytes([random.randint(0, 255)])
        lo = bytes([random.randint(0, 255)])
        await tb.axis_cfg.write(0xEC, (lo + hi + (b'\x00' * 2)), awid = 0x30, size = 0x2, cache = 0x0, prot = 0x0)

        frame_without_fcs = dst_mac + src_mac + length_type + pause_opcode + hi + lo + padding
        fcs = struct.pack('<L', zlib.crc32(frame_without_fcs))
        ethernet_frame = frame_without_fcs + fcs

        tcr:int = (1 << 3)
        await tb.axis_cfg.write(0xC4, tcr.to_bytes(length=4, byteorder='little', signed=False), awid = 0x30, size = 0x2, cache = 0x0, prot = 0x0)
        rx_frame:GmiiFrame = await tb.mii_phy.tx.recv()

        assert rx_frame.get_payload(strip_fcs=False) == ethernet_frame
        assert rx_frame.check_fcs()
        assert rx_frame.error is None

    assert tb.mii_phy.tx.empty()

    await RisingEdge(dut.enet_tx_clk)
    await RisingEdge(dut.enet_tx_clk)

    logging.disable(logging.DEBUG)

async def run_test_rpc_pause(dut, ifg=12, speed=1000e6):

    logging.disable(logging.INFO)

    dst_mac = b'\x01\x80\xC2\x00\x00\x01'
    src_mac = generate_mac()  # 源MAC地址
    length_type = b'\x88\x08'
    pause_opcode = b'\x00\x01'
    padding = bytes(b'\x00' * 42)

    tb = TB(dut, speed)

    tb.mii_phy.rx.ifg = ifg

    tb.set_speed(speed)

    await tb.reset()

    for k in range(100):
        await RisingEdge(dut.enet_tx_clk)

    rcr:int = 8 | 1 << 12 | 1 << 5
    await tb.axis_cfg.write(0x84, rcr.to_bytes(length=4, byteorder='little', signed=False), awid = 0x30, size = 0x2, cache = 0x0, prot = 0x0)

    ecr:int = 0x5EE * 256 * 256 + 0xB
    await tb.axis_cfg.write(0x24, ecr.to_bytes(length=4, byteorder='little', signed=False), awid = 0x30, size = 0x2, cache = 0x0, prot = 0x0)

    await Timer(1000 * (100e6 // speed), units="ns")

    test_seq = []

    for _ in range(5):
        test_seq += [[bytes([random.randint(0, 1)]), bytes([random.randint(1, 255)])]]

    test_seq = [[bytes([0]), bytes([1])]] + [[bytes([3]), bytes([255])]] + test_seq

    for [hi,lo] in test_seq:

        frame_without_fcs = dst_mac + src_mac + length_type + pause_opcode + hi + lo + padding
        fcs = struct.pack('<L', zlib.crc32(frame_without_fcs))
        ethernet_frame = frame_without_fcs + fcs

        event = Event()
        test_frame = GmiiFrame.from_raw_payload(ethernet_frame, tx_complete = event)
        await tb.mii_phy.rx.send(test_frame)
        await event.wait()
        await Timer(1000 * (100e6  // speed), units="ns")

        eir = await tb.axis_cfg.read(0x4, 4, arid = 0x30, size = 0x2, cache = 0x0, prot = 0x0)
        assert eir.data == (0x1 << 28).to_bytes(length=4, byteorder='little', signed=False)
        await tb.axis_cfg.write(0x4, (0x1 << 28).to_bytes(length=4, byteorder='little', signed=False), awid = 0x30, size = 0x2, cache = 0x0, prot = 0x0)

        tcr = await tb.axis_cfg.read(0xC4, 4, arid = 0x30, size = 0x2, cache = 0x0, prot = 0x0)
        assert (int.from_bytes(tcr.data, byteorder="little") & (0x1 << 4)) == (0x1 << 4)

        first_time = 60 * 8 * 10 * (int.from_bytes(hi, byteorder="little") * 256 + int.from_bytes(lo, byteorder="little")) * (100e6  // speed)
        if first_time > (1000 * (100e6  // speed)):
            await Timer(first_time - (1000 * (100e6  // speed)), units="ns")
        tcr = await tb.axis_cfg.read(0xC4, 4, arid = 0x30, size = 0x2, cache = 0x0, prot = 0x0)
        assert (int.from_bytes(tcr.data, byteorder="little") & (0x1 << 4)) == (0x1 << 4)

        await Timer(4 * 8 * 10 * (int.from_bytes(hi, byteorder="little") * 256 + int.from_bytes(lo, byteorder="little")) * (100e6  // speed), units="ns")
        tcr = await tb.axis_cfg.read(0xC4, 4, arid = 0x30, size = 0x2, cache = 0x0, prot = 0x0)
        assert (int.from_bytes(tcr.data, byteorder="little") & (0x1 << 4)) == 0

    for [hi,lo] in test_seq:

        frame_without_fcs = dst_mac + src_mac + length_type + pause_opcode + hi + lo + padding
        fcs = struct.pack('<L', zlib.crc32(frame_without_fcs))
        ethernet_frame = frame_without_fcs + fcs

        event = Event()
        test_frame = GmiiFrame.from_raw_payload(ethernet_frame, tx_complete = event)
        await tb.mii_phy.rx.send(test_frame)
        await event.wait()
        await Timer(1000 * (100e6  // speed), units="ns")

        eir = await tb.axis_cfg.read(0x4, 4, arid = 0x30, size = 0x2, cache = 0x0, prot = 0x0)
        assert eir.data == (0x1 << 28).to_bytes(length=4, byteorder='little', signed=False)
        await tb.axis_cfg.write(0x4, (0x1 << 28).to_bytes(length=4, byteorder='little', signed=False), awid = 0x30, size = 0x2, cache = 0x0, prot = 0x0)

        tcr = await tb.axis_cfg.read(0xC4, 4, arid = 0x30, size = 0x2, cache = 0x0, prot = 0x0)
        assert (int.from_bytes(tcr.data, byteorder="little") & (0x1 << 4)) == (0x1 << 4)

        frame_without_fcs = dst_mac + src_mac + length_type + pause_opcode + (b'\x00' * 2) + padding
        fcs = struct.pack('<L', zlib.crc32(frame_without_fcs))
        ethernet_frame = frame_without_fcs + fcs

        event = Event()
        test_frame = GmiiFrame.from_raw_payload(ethernet_frame, tx_complete = event)
        await tb.mii_phy.rx.send(test_frame)
        await event.wait()
        await Timer(1000 * (100e6  // speed), units="ns")

        tcr = await tb.axis_cfg.read(0xC4, 4, arid = 0x30, size = 0x2, cache = 0x0, prot = 0x0)
        assert (int.from_bytes(tcr.data, byteorder="little") & (0x1 << 4)) == 0

    assert tb.mii_phy.tx.empty()

    await RisingEdge(dut.enet_tx_clk)
    await RisingEdge(dut.enet_tx_clk)

    logging.disable(logging.DEBUG)

async def run_test_payload_pad(dut, ifg=12, speed=1000e6):

    logging.disable(logging.INFO)

    dst_mac = generate_mac()
    src_mac = generate_mac()  # 源MAC地址
    length_type = b'\x08\x00'

    tb = TB(dut, speed)

    tb.mii_phy.rx.ifg = ifg

    tb.set_speed(speed)

    await tb.reset()

    for k in range(100):
        await RisingEdge(dut.enet_tx_clk)

    test_max_num = 2 ** 22
    test_desc_addr = random.getrandbits(22)
    assert test_desc_addr < test_max_num
    test_desc = bytearray(b'\x00' * 1024)
    tb.tx_sram.add_memory_block(test_desc_addr * 1024, test_desc)
    for i in range(128):
        tb.tx_sram.addrmap[test_desc_addr * 1024][8 * i + 2] = 0
        tb.tx_sram.addrmap[test_desc_addr * 1024][8 * i + 3] = 0x18
        tb.tx_sram.addrmap[test_desc_addr * 1024][8 * i + 4] = 0
    tb.tx_sram.addrmap[test_desc_addr * 1024][8 * 127 + 3] = 0x38

    tdsr:int = test_desc_addr * 1024
    await tb.axis_cfg.write(0x184, tdsr.to_bytes(length=4, byteorder='little', signed=False), awid = 0x30, size = 0x2, cache = 0x0, prot = 0x0)

    tcr:int = 0
    await tb.axis_cfg.write(0xC4, tcr.to_bytes(length=4, byteorder='little', signed=False), awid = 0x30, size = 0x2, cache = 0x0, prot = 0x0)

    rcr:int = 8 | 1 << 12 | 1 << 5
    await tb.axis_cfg.write(0x84, rcr.to_bytes(length=4, byteorder='little', signed=False), awid = 0x30, size = 0x2, cache = 0x0, prot = 0x0)

    ecr:int = 0x5EE * 256 * 256 + 0xB
    await tb.axis_cfg.write(0x24, ecr.to_bytes(length=4, byteorder='little', signed=False), awid = 0x30, size = 0x2, cache = 0x0, prot = 0x0)

    for i in range(47):
        frame_without_fcs = dst_mac + src_mac + length_type
        for _ in range(i):
            frame_without_fcs += bytes([random.randint(0, 255)])

        test_buf_addr = random.getrandbits(21)
        assert test_buf_addr * 2 < test_max_num
        while test_buf_addr * 2 * 1024 in tb.tx_sram.addrmap:
            test_buf_addr = random.getrandbits(21)
            assert test_buf_addr * 2 < test_max_num
        test_buf:bytearray = bytearray(frame_without_fcs) + bytearray(b'\x00' * ((8 - (len(frame_without_fcs) % 8)) % 8))
        tb.tx_sram.add_memory_block(test_buf_addr * 2 * 1024, test_buf)
        tb.tx_sram.addrmap[test_desc_addr * 1024][8 * i + 0] = len(frame_without_fcs) % 256
        tb.tx_sram.addrmap[test_desc_addr * 1024][8 * i + 1] = len(frame_without_fcs) // 256 % 256
        tb.tx_sram.addrmap[test_desc_addr * 1024][8 * i + 3] |= 0x80
        tb.tx_sram.addrmap[test_desc_addr * 1024][8 * i + 5] = test_buf_addr * 2 * 4 % 256
        tb.tx_sram.addrmap[test_desc_addr * 1024][8 * i + 6] = test_buf_addr * 2 * 4 // 256 % 256
        tb.tx_sram.addrmap[test_desc_addr * 1024][8 * i + 7] = test_buf_addr * 2 * 4 // 256 // 256 % 256
        await tb.axis_cfg.write(0x14, (0).to_bytes(length=4, byteorder='little', signed=False), awid = 0x30, size = 0x2, cache = 0x0, prot = 0x0)

        ethernet_frame_without_fcs = frame_without_fcs + (b'\x00' * (46 - i))
        fcs = struct.pack('<L', zlib.crc32(ethernet_frame_without_fcs))
        ethernet_frame = ethernet_frame_without_fcs + fcs

        rx_frame:GmiiFrame = await tb.mii_phy.tx.recv()

        assert rx_frame.get_payload(strip_fcs=False) == ethernet_frame
        assert rx_frame.check_fcs()
        assert rx_frame.error is None

    assert tb.mii_phy.tx.empty()

    await RisingEdge(dut.enet_tx_clk)
    await RisingEdge(dut.enet_tx_clk)

    logging.disable(logging.DEBUG)

async def run_test_rx_pausefwd(dut, pausefwd: bool = False, ifg=12, speed=1000e6):

    logging.disable(logging.INFO)

    tb = TB(dut, speed)

    tb.mii_phy.rx.ifg = ifg

    tb.set_speed(speed)

    await tb.reset()

    for k in range(100):
        await RisingEdge(dut.enet_rx_clk)

    test_max_num = 2 ** 22
    test_desc_addr = random.getrandbits(22)
    assert test_desc_addr < test_max_num
    test_desc = bytearray(b'\x00' * 1024)
    tb.rx_sram.add_memory_block(test_desc_addr * 1024, test_desc)
    test_buf_list = []
    for i in range(128):
        test_buf_addr = random.getrandbits(21)
        assert test_buf_addr * 2 < test_max_num
        while test_buf_addr * 2 * 1024 in tb.rx_sram.addrmap:
            test_buf_addr = random.getrandbits(21)
            assert test_buf_addr * 2 < test_max_num
        test_buf = bytearray(b'\x00' * 2048)
        tb.rx_sram.add_memory_block(test_buf_addr * 2 * 1024, test_buf)
        test_buf_list.append(test_buf_addr * 2)
        tb.rx_sram.addrmap[test_desc_addr * 1024][8 * i + 0] = 0
        tb.rx_sram.addrmap[test_desc_addr * 1024][8 * i + 1] = 0
        tb.rx_sram.addrmap[test_desc_addr * 1024][8 * i + 2] = 0
        tb.rx_sram.addrmap[test_desc_addr * 1024][8 * i + 3] = 128
        tb.rx_sram.addrmap[test_desc_addr * 1024][8 * i + 4] = 0
        tb.rx_sram.addrmap[test_desc_addr * 1024][8 * i + 5] = test_buf_addr * 2 * 4 % 256
        tb.rx_sram.addrmap[test_desc_addr * 1024][8 * i + 6] = test_buf_addr * 2 * 4 // 256 % 256
        tb.rx_sram.addrmap[test_desc_addr * 1024][8 * i + 7] = test_buf_addr * 2 * 4 // 256 // 256 % 256
    tb.rx_sram.addrmap[test_desc_addr * 1024][8 * 127 + 3] = 160

    rdsr:int = test_desc_addr * 1024
    await tb.axis_cfg.write(0x180, rdsr.to_bytes(length=4, byteorder='little', signed=False), awid = 0x30, size = 0x2, cache = 0x0, prot = 0x0)

    rcr:int = 8 | (1 << 13 if pausefwd else 0x0)
    await tb.axis_cfg.write(0x84, rcr.to_bytes(length=4, byteorder='little', signed=False), awid = 0x30, size = 0x2, cache = 0x0, prot = 0x0)

    ecr:int = 0x5EE * 256 * 256 + 0xB
    await tb.axis_cfg.write(0x24, ecr.to_bytes(length=4, byteorder='little', signed=False), awid = 0x30, size = 0x2, cache = 0x0, prot = 0x0)

    await tb.axis_cfg.write(0x10, (0).to_bytes(length=4, byteorder='little', signed=False), awid = 0x30, size = 0x2, cache = 0x0, prot = 0x0)

    await Timer(1000 * (100e6 // speed), units="ns")

    for i in range(128):
        frame = generate_pause_frame(generate_mac(), pause_time = random.randint(0, 65535))
        event = Event()
        test_frame = GmiiFrame.from_raw_payload(frame, tx_complete = event)
        await tb.mii_phy.rx.send(test_frame)
        await event.wait()
        await Timer(len(frame) * 20 * (100e6 // speed), units="ns")
        if pausefwd:
            assert tb.rx_sram.addrmap[test_buf_list[i] * 1024][0:len(frame)] == frame
            assert tb.rx_sram.addrmap[test_desc_addr * 1024][8 * i + 0] == len(frame)
            assert tb.rx_sram.addrmap[test_desc_addr * 1024][8 * i + 1] == 0
        else:
            assert tb.rx_sram.addrmap[test_buf_list[i] * 1024][0:len(frame)] == (b'\x00' * len(frame))
            assert tb.rx_sram.addrmap[test_desc_addr * 1024][8 * i + 0] == 0
            assert tb.rx_sram.addrmap[test_desc_addr * 1024][8 * i + 1] == 0

    await RisingEdge(dut.enet_rx_clk)
    await RisingEdge(dut.enet_rx_clk)

    logging.disable(logging.DEBUG)

async def run_test_rx_lencheck(dut, lencheck: bool = False, payload_lengths=None, payload_data=None, ifg=12, speed=1000e6):

    logging.disable(logging.INFO)

    tb = TB(dut, speed)

    tb.mii_phy.rx.ifg = ifg

    tb.set_speed(speed)

    await tb.reset()

    for k in range(100):
        await RisingEdge(dut.enet_rx_clk)

    def operation_1(payload_size: int) -> Tuple[bytes]:
        """操作1: 单播判断，生成给定MAC地址为目标的以太网帧"""
        dst_mac = generate_mac(unicast=True)
        src_mac = generate_mac(unicast=True)
        
        frame = payload_data(payload_size, dst_mac = dst_mac, use_mac = True, mac_addr = src_mac, use_8023 = True)
        
        return frame

    test_max_num = 2 ** 22
    test_desc_addr = random.getrandbits(22)
    assert test_desc_addr < test_max_num
    test_desc = bytearray(b'\x00' * 1024)
    tb.rx_sram.add_memory_block(test_desc_addr * 1024, test_desc)
    test_buf_list = []
    for i in range(128):
        test_buf_addr = random.getrandbits(21)
        assert test_buf_addr * 2 < test_max_num
        while test_buf_addr * 2 * 1024 in tb.rx_sram.addrmap:
            test_buf_addr = random.getrandbits(21)
            assert test_buf_addr * 2 < test_max_num
        test_buf = bytearray(b'\x00' * 2048)
        tb.rx_sram.add_memory_block(test_buf_addr * 2 * 1024, test_buf)
        test_buf_list.append(test_buf_addr * 2)
        tb.rx_sram.addrmap[test_desc_addr * 1024][8 * i + 0] = 0
        tb.rx_sram.addrmap[test_desc_addr * 1024][8 * i + 1] = 0
        tb.rx_sram.addrmap[test_desc_addr * 1024][8 * i + 2] = 0
        tb.rx_sram.addrmap[test_desc_addr * 1024][8 * i + 3] = 128
        tb.rx_sram.addrmap[test_desc_addr * 1024][8 * i + 4] = 0
        tb.rx_sram.addrmap[test_desc_addr * 1024][8 * i + 5] = test_buf_addr * 2 * 4 % 256
        tb.rx_sram.addrmap[test_desc_addr * 1024][8 * i + 6] = test_buf_addr * 2 * 4 // 256 % 256
        tb.rx_sram.addrmap[test_desc_addr * 1024][8 * i + 7] = test_buf_addr * 2 * 4 // 256 // 256 % 256
    tb.rx_sram.addrmap[test_desc_addr * 1024][8 * 127 + 3] = 160

    rdsr:int = test_desc_addr * 1024
    await tb.axis_cfg.write(0x180, rdsr.to_bytes(length=4, byteorder='little', signed=False), awid = 0x30, size = 0x2, cache = 0x0, prot = 0x0)

    rcr:int = 0x8 | (0x1 << 30 if lencheck else 0x0)
    await tb.axis_cfg.write(0x84, rcr.to_bytes(length=4, byteorder='little', signed=False), awid = 0x30, size = 0x2, cache = 0x0, prot = 0x0)

    ecr:int = 0x5EE * 256 * 256 + 0xB
    await tb.axis_cfg.write(0x24, ecr.to_bytes(length=4, byteorder='little', signed=False), awid = 0x30, size = 0x2, cache = 0x0, prot = 0x0)

    await tb.axis_cfg.write(0x10, (0).to_bytes(length=4, byteorder='little', signed=False), awid = 0x30, size = 0x2, cache = 0x0, prot = 0x0)

    await Timer(1000 * (100e6 // speed), units="ns")

    i = 0
    for x in payload_lengths():
        while(True):
            operation = random.randint(0, 1)
        
            if operation == 0:
                # 操作1: 正常发送
                frame = operation_1(x)
                
                event = Event()
                test_frame = GmiiFrame.from_raw_payload(frame, tx_complete = event)
                await tb.mii_phy.rx.send(test_frame)
                await event.wait()
                await Timer(len(frame) * 20 * (100e6 // speed), units="ns")
                assert tb.rx_sram.addrmap[test_buf_list[i] * 1024][0:len(frame)] == frame
                assert tb.rx_sram.addrmap[test_desc_addr * 1024][8 * i + 0] == (max(x, 46) + 18) % 256
                assert tb.rx_sram.addrmap[test_desc_addr * 1024][8 * i + 1] == (max(x, 46) + 18) // 256 % 256
                
                i = i + 1
                break
            else:  # operation == 1
                # 操作2: 修改length为不正确的值
                frame = operation_1(x)
                # 1. 解析帧结构
                dst_mac = frame[0:6]
                src_mac = frame[6:12]
                length_type_field = frame[12:14]  # 原始的长度/类型字段
                payload_and_fcs = frame[14:]
                
                # 2. 确定原始长度/类型字段的值
                original_value = struct.unpack('>H', length_type_field)[0]
                new_value = original_value - 10  # 一个不常见的类型值
                
                # 4. 创建新的长度/类型字段
                new_length_type = struct.pack('>H', new_value)
                
                # 5. 组装新的帧（不包括FCS）
                # 注意：payload_and_fcs包含了原始负载和FCS，我们需要去掉原始FCS
                original_payload = payload_and_fcs[:-4]
                new_frame_without_fcs = dst_mac + src_mac + new_length_type + original_payload
                
                # 6. 计算新的CRC32
                new_crc = zlib.crc32(new_frame_without_fcs) & 0xFFFFFFFF
                new_fcs = struct.pack('<I', new_crc)
                
                # 7. 组装完整的修改后的帧
                frame = new_frame_without_fcs + new_fcs
                if lencheck:
                    event = Event()
                    test_frame = GmiiFrame.from_raw_payload(frame, tx_complete = event)
                    await tb.mii_phy.rx.send(test_frame)
                    await event.wait()
                    await Timer(len(frame) * 20 * (100e6 // speed), units="ns")
                    assert tb.rx_sram.addrmap[test_buf_list[i] * 1024][0:len(frame)] == frame
                    assert tb.rx_sram.addrmap[test_desc_addr * 1024][8 * i + 0] == (max(x, 46) + 18) % 256
                    assert tb.rx_sram.addrmap[test_desc_addr * 1024][8 * i + 1] == (max(x, 46) + 18) // 256 % 256
                    
                    eir = await tb.axis_cfg.read(0x4, 4, arid = 0x30, size = 0x2, cache = 0x0, prot = 0x0)
                    assert eir.data == ((0x1 << 25) | (0x1 << 18)).to_bytes(length=4, byteorder='little', signed=False)
                    i = i + 1
                    break
                else:
                    event = Event()
                    test_frame = GmiiFrame.from_raw_payload(frame, tx_complete = event)
                    await tb.mii_phy.rx.send(test_frame)
                    await event.wait()
                    await Timer(len(frame) * 20 * (100e6 // speed), units="ns")
                    assert tb.rx_sram.addrmap[test_buf_list[i] * 1024][0:len(frame)] == frame
                    assert tb.rx_sram.addrmap[test_desc_addr * 1024][8 * i + 0] == (max(x, 46) + 18) % 256
                    assert tb.rx_sram.addrmap[test_desc_addr * 1024][8 * i + 1] == (max(x, 46) + 18) // 256 % 256
                    
                    i = i + 1
                    break

    await RisingEdge(dut.enet_rx_clk)
    await RisingEdge(dut.enet_rx_clk)

    logging.disable(logging.DEBUG)

async def run_test_rx_coalesce(dut, func:str, payload_lengths=None, payload_data=None, ifg=12, speed=1000e6):

    logging.disable(logging.INFO)

    tb = TB(dut, speed)

    tb.mii_phy.rx.ifg = ifg

    tb.set_speed(speed)

    await tb.reset()

    for k in range(100):
        await RisingEdge(dut.enet_rx_clk)

    test_max_num = 2 ** 22
    test_desc_addr = random.getrandbits(22)
    assert test_desc_addr < test_max_num
    test_desc = bytearray(b'\x00' * 1024)
    tb.rx_sram.add_memory_block(test_desc_addr * 1024, test_desc)
    test_buf_list = []
    for i in range(128):
        test_buf_addr = random.getrandbits(21)
        assert test_buf_addr * 2 < test_max_num
        while test_buf_addr * 2 * 1024 in tb.rx_sram.addrmap:
            test_buf_addr = random.getrandbits(21)
            assert test_buf_addr * 2 < test_max_num
        test_buf = bytearray(b'\x00' * 2048)
        tb.rx_sram.add_memory_block(test_buf_addr * 2 * 1024, test_buf)
        test_buf_list.append(test_buf_addr * 2)
        tb.rx_sram.addrmap[test_desc_addr * 1024][8 * i + 0] = 0
        tb.rx_sram.addrmap[test_desc_addr * 1024][8 * i + 1] = 0
        tb.rx_sram.addrmap[test_desc_addr * 1024][8 * i + 2] = 0
        tb.rx_sram.addrmap[test_desc_addr * 1024][8 * i + 3] = 128
        tb.rx_sram.addrmap[test_desc_addr * 1024][8 * i + 4] = 0
        tb.rx_sram.addrmap[test_desc_addr * 1024][8 * i + 5] = test_buf_addr * 2 * 4 % 256
        tb.rx_sram.addrmap[test_desc_addr * 1024][8 * i + 6] = test_buf_addr * 2 * 4 // 256 % 256
        tb.rx_sram.addrmap[test_desc_addr * 1024][8 * i + 7] = test_buf_addr * 2 * 4 // 256 // 256 % 256
    tb.rx_sram.addrmap[test_desc_addr * 1024][8 * 127 + 3] = 160

    rdsr:int = test_desc_addr * 1024
    await tb.axis_cfg.write(0x180, rdsr.to_bytes(length=4, byteorder='little', signed=False), awid = 0x30, size = 0x2, cache = 0x0, prot = 0x0)

    rcr:int = 8
    await tb.axis_cfg.write(0x84, rcr.to_bytes(length=4, byteorder='little', signed=False), awid = 0x30, size = 0x2, cache = 0x0, prot = 0x0)

    ecr:int = 0x5EE * 256 * 256 + 0xB
    await tb.axis_cfg.write(0x24, ecr.to_bytes(length=4, byteorder='little', signed=False), awid = 0x30, size = 0x2, cache = 0x0, prot = 0x0)

    await tb.axis_cfg.write(0x10, (0).to_bytes(length=4, byteorder='little', signed=False), awid = 0x30, size = 0x2, cache = 0x0, prot = 0x0)

    if func == 'time':
        await tb.axis_cfg.write(0x100, (0x8ff00000 + (8 * 8 * int(100e6 // speed))).to_bytes(length=4, byteorder='little', signed=False), awid = 0x30, size = 0x2, cache = 0x0, prot = 0x0)
    elif func == 'number':
        await tb.axis_cfg.write(0x100, (0x8020ffff).to_bytes(length=4, byteorder='little', signed=False), awid = 0x30, size = 0x2, cache = 0x0, prot = 0x0)
    else:
        raise ValueError(f"func error {func = }")
    
    await Timer(1000 * (100e6 // speed), units="ns")

    test_frames:List[bytearray, Event, int] = [[payload_data(x), Event(), x] for x in payload_lengths()]

    for i, [test_data, event, length] in enumerate(test_frames):
        test_frame = GmiiFrame.from_raw_payload(test_data, tx_complete = event)
        await tb.mii_phy.rx.send(test_frame)
        await event.wait()
        await Timer(len(test_data) * 20 * (100e6 // speed), units="ns")
        assert tb.rx_sram.addrmap[test_buf_list[i] * 1024][0:len(test_data)] == test_data
        assert tb.rx_sram.addrmap[test_desc_addr * 1024][8 * i + 0] == (max(length, 46) + 18) % 256
        assert tb.rx_sram.addrmap[test_desc_addr * 1024][8 * i + 1] == (max(length, 46) + 18) // 256 % 256
        if func == 'time':
            eir = await tb.axis_cfg.read(0x4, 4, arid = 0x30, size = 0x2, cache = 0x0, prot = 0x0)
            assert eir.data == (0).to_bytes(length=4, byteorder='little', signed=False)
            for k in range(1100):
                await RisingEdge(dut.enet_rx_clk)
            eir = await tb.axis_cfg.read(0x4, 4, arid = 0x30, size = 0x2, cache = 0x0, prot = 0x0)
            assert eir.data == (0x1 << 25).to_bytes(length=4, byteorder='little', signed=False)
            await tb.axis_cfg.write(0x4, (0x1 << 25).to_bytes(length=4, byteorder='little', signed=False), awid = 0x30, size = 0x2, cache = 0x0, prot = 0x0)
        elif func == 'number':
            if i % 2 == 0: 
                eir = await tb.axis_cfg.read(0x4, 4, arid = 0x30, size = 0x2, cache = 0x0, prot = 0x0)
                assert eir.data == (0).to_bytes(length=4, byteorder='little', signed=False)
            else:
                for k in range(100):
                    await RisingEdge(dut.enet_rx_clk)
                eir = await tb.axis_cfg.read(0x4, 4, arid = 0x30, size = 0x2, cache = 0x0, prot = 0x0)
                assert eir.data == (0x1 << 25).to_bytes(length=4, byteorder='little', signed=False)
                await tb.axis_cfg.write(0x4, (0x1 << 25).to_bytes(length=4, byteorder='little', signed=False), awid = 0x30, size = 0x2, cache = 0x0, prot = 0x0)

    await RisingEdge(dut.enet_rx_clk)
    await RisingEdge(dut.enet_rx_clk)

    logging.disable(logging.DEBUG)

async def run_test_tx_coalesce(dut, func:str, payload_lengths=None, payload_data=None, ifg=12, speed=1000e6):

    logging.disable(logging.INFO)

    src_mac = generate_mac()  # 源MAC地址

    tb = TB(dut, speed)

    tb.mii_phy.rx.ifg = ifg

    tb.set_speed(speed)

    await tb.reset()

    for k in range(100):
        await RisingEdge(dut.enet_tx_clk)

    test_frames:List[bytearray, Event, int] = [[payload_data(x), Event(), x] for x in payload_lengths()]

    test_max_num = 2 ** 22
    test_desc_addr = random.getrandbits(22)
    assert test_desc_addr < test_max_num
    test_desc = bytearray(b'\x00' * 1024)
    tb.tx_sram.add_memory_block(test_desc_addr * 1024, test_desc)
    test_buf_list = []
    for i in range(len(test_frames)):
        test_buf_addr = random.getrandbits(21)
        assert test_buf_addr * 2 < test_max_num
        while test_buf_addr * 2 * 1024 in tb.tx_sram.addrmap:
            test_buf_addr = random.getrandbits(21)
            assert test_buf_addr * 2 < test_max_num
        test_buf:bytearray = bytearray(test_frames[i][0]) + bytearray(b'\x00' * (8 - ((test_frames[i][2] + 18) % 8)))
        tb.tx_sram.add_memory_block(test_buf_addr * 2 * 1024, test_buf)
        test_buf_list.append(test_buf_addr * 2)
        tb.tx_sram.addrmap[test_desc_addr * 1024][8 * i + 0] = (test_frames[i][2] + 18) % 256
        tb.tx_sram.addrmap[test_desc_addr * 1024][8 * i + 1] = (test_frames[i][2] + 18) // 256 % 256
        tb.tx_sram.addrmap[test_desc_addr * 1024][8 * i + 2] = 0
        tb.tx_sram.addrmap[test_desc_addr * 1024][8 * i + 3] = 0x1C
        tb.tx_sram.addrmap[test_desc_addr * 1024][8 * i + 4] = 0
        tb.tx_sram.addrmap[test_desc_addr * 1024][8 * i + 5] = test_buf_addr * 2 * 4 % 256
        tb.tx_sram.addrmap[test_desc_addr * 1024][8 * i + 6] = test_buf_addr * 2 * 4 // 256 % 256
        tb.tx_sram.addrmap[test_desc_addr * 1024][8 * i + 7] = test_buf_addr * 2 * 4 // 256 // 256 % 256
    tb.tx_sram.addrmap[test_desc_addr * 1024][8 * (len(test_frames) - 1) + 3] = 0x3C

    tdsr:int = test_desc_addr * 1024
    await tb.axis_cfg.write(0x184, tdsr.to_bytes(length=4, byteorder='little', signed=False), awid = 0x30, size = 0x2, cache = 0x0, prot = 0x0)

    tcr:int = 1 << 9
    await tb.axis_cfg.write(0xC4, tcr.to_bytes(length=4, byteorder='little', signed=False), awid = 0x30, size = 0x2, cache = 0x0, prot = 0x0)

    tfwr:int = 1 << 8
    await tb.axis_cfg.write(0x144, tfwr.to_bytes(length=4, byteorder='little', signed=False), awid = 0x30, size = 0x2, cache = 0x0, prot = 0x0)

    ecr:int = 0x5EE * 256 * 256 + 0xB
    await tb.axis_cfg.write(0x24, ecr.to_bytes(length=4, byteorder='little', signed=False), awid = 0x30, size = 0x2, cache = 0x0, prot = 0x0)

    await tb.axis_cfg.write(0xE4, bytes(src_mac[3::-1]), awid = 0x30, size = 0x2, cache = 0x0, prot = 0x0)
    await tb.axis_cfg.write(0xE8, bytes((b'\x00' * 2) + src_mac[5:3:-1]), awid = 0x30, size = 0x2, cache = 0x0, prot = 0x0)

    await tb.axis_cfg.write(0x14, (0).to_bytes(length=4, byteorder='little', signed=False), awid = 0x30, size = 0x2, cache = 0x0, prot = 0x0)

    if func == 'time':
        await tb.axis_cfg.write(0xF0, (0x8ff00008).to_bytes(length=4, byteorder='little', signed=False), awid = 0x30, size = 0x2, cache = 0x0, prot = 0x0)
    elif func == 'number':
        await tb.axis_cfg.write(0xF0, (0x8020ffff).to_bytes(length=4, byteorder='little', signed=False), awid = 0x30, size = 0x2, cache = 0x0, prot = 0x0)
    else:
        raise ValueError(f"func error {func = }")

    for i, [test_data, event, _] in enumerate(test_frames):
        tb.tx_sram.addrmap[test_desc_addr * 1024][8 * i + 3] = 0x9C
        await tb.axis_cfg.write(0x14, (0).to_bytes(length=4, byteorder='little', signed=False), awid = 0x30, size = 0x2, cache = 0x0, prot = 0x0)
        rx_frame:GmiiFrame = await tb.mii_phy.tx.recv()

        assert rx_frame.get_payload(strip_fcs=False) == test_data
        assert rx_frame.check_fcs()
        assert rx_frame.error is None
        if func == 'time':
            eir = await tb.axis_cfg.read(0x4, 4, arid = 0x30, size = 0x2, cache = 0x0, prot = 0x0)
            assert eir.data == (0).to_bytes(length=4, byteorder='little', signed=False)
            for k in range(1000):
                await RisingEdge(dut.enet_tx_clk)
            eir = await tb.axis_cfg.read(0x4, 4, arid = 0x30, size = 0x2, cache = 0x0, prot = 0x0)
            assert eir.data == (0x1 << 27).to_bytes(length=4, byteorder='little', signed=False)
            await tb.axis_cfg.write(0x4, (0x1 << 27).to_bytes(length=4, byteorder='little', signed=False), awid = 0x30, size = 0x2, cache = 0x0, prot = 0x0)
        elif func == 'number':
            if i % 2 == 0: 
                eir = await tb.axis_cfg.read(0x4, 4, arid = 0x30, size = 0x2, cache = 0x0, prot = 0x0)
                assert eir.data == (0).to_bytes(length=4, byteorder='little', signed=False)
            else:
                for k in range(100):
                    await RisingEdge(dut.enet_tx_clk)
                eir = await tb.axis_cfg.read(0x4, 4, arid = 0x30, size = 0x2, cache = 0x0, prot = 0x0)
                assert eir.data == (0x1 << 27).to_bytes(length=4, byteorder='little', signed=False)
                await tb.axis_cfg.write(0x4, (0x1 << 27).to_bytes(length=4, byteorder='little', signed=False), awid = 0x30, size = 0x2, cache = 0x0, prot = 0x0)

    assert tb.mii_phy.tx.empty()

    await RisingEdge(dut.enet_tx_clk)
    await RisingEdge(dut.enet_tx_clk)

    logging.disable(logging.DEBUG)

async def run_test_tx_stop(dut, payload_lengths=None, payload_data=None, ifg=12, speed=1000e6):

    logging.disable(logging.INFO)

    src_mac = generate_mac()  # 源MAC地址

    tb = TB(dut, speed)

    tb.mii_phy.rx.ifg = ifg

    tb.set_speed(speed)

    await tb.reset()

    for k in range(100):
        await RisingEdge(dut.enet_tx_clk)

    test_frames:List[bytearray, Event, int] = [[payload_data(x), Event(), x] for x in payload_lengths()]

    test_max_num = 2 ** 22
    test_desc_addr = random.getrandbits(22)
    assert test_desc_addr < test_max_num
    test_desc = bytearray(b'\x00' * 1024)
    tb.tx_sram.add_memory_block(test_desc_addr * 1024, test_desc)
    test_buf_list = []
    for i in range(len(test_frames)):
        test_buf_addr = random.getrandbits(21)
        assert test_buf_addr * 2 < test_max_num
        while test_buf_addr * 2 * 1024 in tb.tx_sram.addrmap:
            test_buf_addr = random.getrandbits(21)
            assert test_buf_addr * 2 < test_max_num
        test_buf:bytearray = bytearray(test_frames[i][0]) + bytearray(b'\x00' * (8 - ((test_frames[i][2] + 18) % 8)))
        tb.tx_sram.add_memory_block(test_buf_addr * 2 * 1024, test_buf)
        test_buf_list.append(test_buf_addr * 2)
        tb.tx_sram.addrmap[test_desc_addr * 1024][8 * i + 0] = (test_frames[i][2] + 18) % 256
        tb.tx_sram.addrmap[test_desc_addr * 1024][8 * i + 1] = (test_frames[i][2] + 18) // 256 % 256
        tb.tx_sram.addrmap[test_desc_addr * 1024][8 * i + 2] = 0
        tb.tx_sram.addrmap[test_desc_addr * 1024][8 * i + 3] = 0x9C
        tb.tx_sram.addrmap[test_desc_addr * 1024][8 * i + 4] = 0
        tb.tx_sram.addrmap[test_desc_addr * 1024][8 * i + 5] = test_buf_addr * 2 * 4 % 256
        tb.tx_sram.addrmap[test_desc_addr * 1024][8 * i + 6] = test_buf_addr * 2 * 4 // 256 % 256
        tb.tx_sram.addrmap[test_desc_addr * 1024][8 * i + 7] = test_buf_addr * 2 * 4 // 256 // 256 % 256
    tb.tx_sram.addrmap[test_desc_addr * 1024][8 * (len(test_frames) - 1) + 3] = 0xBC

    tdsr:int = test_desc_addr * 1024
    await tb.axis_cfg.write(0x184, tdsr.to_bytes(length=4, byteorder='little', signed=False), awid = 0x30, size = 0x2, cache = 0x0, prot = 0x0)

    tcr:int = 1 << 9
    await tb.axis_cfg.write(0xC4, tcr.to_bytes(length=4, byteorder='little', signed=False), awid = 0x30, size = 0x2, cache = 0x0, prot = 0x0)

    tfwr:int = 1 << 8
    await tb.axis_cfg.write(0x144, tfwr.to_bytes(length=4, byteorder='little', signed=False), awid = 0x30, size = 0x2, cache = 0x0, prot = 0x0)

    ecr:int = 0x5EE * 256 * 256 + 0xB
    await tb.axis_cfg.write(0x24, ecr.to_bytes(length=4, byteorder='little', signed=False), awid = 0x30, size = 0x2, cache = 0x0, prot = 0x0)

    await tb.axis_cfg.write(0xE4, bytes(src_mac[3::-1]), awid = 0x30, size = 0x2, cache = 0x0, prot = 0x0)
    await tb.axis_cfg.write(0xE8, bytes((b'\x00' * 2) + src_mac[5:3:-1]), awid = 0x30, size = 0x2, cache = 0x0, prot = 0x0)

    await Timer(1000 * (100e6 // speed), units="ns")

    await tb.axis_cfg.write(0x14, (0).to_bytes(length=4, byteorder='little', signed=False), awid = 0x30, size = 0x2, cache = 0x0, prot = 0x0)

    for i, [test_data, event, _] in enumerate(test_frames):
        for k in range(100):
            await RisingEdge(dut.enet_tx_clk)
        await tb.axis_cfg.write(0xC4, (tcr | 0x1).to_bytes(length=4, byteorder='little', signed=False), awid = 0x30, size = 0x2, cache = 0x0, prot = 0x0)
        rx_frame:GmiiFrame = await tb.mii_phy.tx.recv()

        assert rx_frame.get_payload(strip_fcs=False) == test_data
        assert rx_frame.check_fcs()
        assert rx_frame.error is None
        
        for k in range(100 * int(100e6 // speed)):
            await RisingEdge(dut.enet_tx_clk)
        eir = await tb.axis_cfg.read(0x4, 4, arid = 0x30, size = 0x2, cache = 0x0, prot = 0x0)
        assert eir.data == (0x3 << 27).to_bytes(length=4, byteorder='little', signed=False)
        await tb.axis_cfg.write(0x4, (0x3 << 27).to_bytes(length=4, byteorder='little', signed=False), awid = 0x30, size = 0x2, cache = 0x0, prot = 0x0)
        for k in range(random.randint(100, 200)):
            await RisingEdge(dut.enet_tx_clk)
        eir = await tb.axis_cfg.read(0x4, 4, arid = 0x30, size = 0x2, cache = 0x0, prot = 0x0)
        assert eir.data == (0).to_bytes(length=4, byteorder='little', signed=False)

        await tb.axis_cfg.write(0xC4, (tcr).to_bytes(length=4, byteorder='little', signed=False), awid = 0x30, size = 0x2, cache = 0x0, prot = 0x0)
        await tb.axis_cfg.write(0x14, (0).to_bytes(length=4, byteorder='little', signed=False), awid = 0x30, size = 0x2, cache = 0x0, prot = 0x0)

    assert tb.mii_phy.tx.empty()

    await RisingEdge(dut.enet_tx_clk)
    await RisingEdge(dut.enet_tx_clk)

    logging.disable(logging.DEBUG)

async def run_test_tx_warp(dut, payload_data=None, ifg=12, speed=1000e6):

    logging.disable(logging.INFO)

    src_mac = generate_mac()  # 源MAC地址

    tb = TB(dut, speed)

    tb.mii_phy.rx.ifg = ifg

    tb.set_speed(speed)

    await tb.reset()

    for k in range(100):
        await RisingEdge(dut.enet_tx_clk)

    frames = []

    test_max_num = 2 ** 22
    test_desc_addr = random.getrandbits(22)
    assert test_desc_addr < test_max_num
    test_desc = bytearray(b'\x00' * 1024)
    tb.tx_sram.add_memory_block(test_desc_addr * 1024, test_desc)
    test_buf_list = []
    for i in range(128):
        frame = payload_data(64 + i)
        frames.append(frame)
        test_buf_addr = random.getrandbits(21)
        assert test_buf_addr * 2 < test_max_num
        while test_buf_addr * 2 * 1024 in tb.tx_sram.addrmap:
            test_buf_addr = random.getrandbits(21)
            assert test_buf_addr * 2 < test_max_num
        test_buf:bytearray = bytearray(frame) + bytearray(b'\x00' * (8 - ((64 + i + 18) % 8)))
        tb.tx_sram.add_memory_block(test_buf_addr * 2 * 1024, test_buf)
        test_buf_list.append(test_buf_addr * 2)
        tb.tx_sram.addrmap[test_desc_addr * 1024][8 * i + 0] = (64 + i + 18) % 256
        tb.tx_sram.addrmap[test_desc_addr * 1024][8 * i + 1] = (64 + i + 18) // 256 % 256
        tb.tx_sram.addrmap[test_desc_addr * 1024][8 * i + 2] = 0
        tb.tx_sram.addrmap[test_desc_addr * 1024][8 * i + 3] = 0x9C
        tb.tx_sram.addrmap[test_desc_addr * 1024][8 * i + 4] = 0
        tb.tx_sram.addrmap[test_desc_addr * 1024][8 * i + 5] = test_buf_addr * 2 * 4 % 256
        tb.tx_sram.addrmap[test_desc_addr * 1024][8 * i + 6] = test_buf_addr * 2 * 4 // 256 % 256
        tb.tx_sram.addrmap[test_desc_addr * 1024][8 * i + 7] = test_buf_addr * 2 * 4 // 256 // 256 % 256
    tb.tx_sram.addrmap[test_desc_addr * 1024][8 * 127 + 3] = 0xBC

    tdsr:int = test_desc_addr * 1024
    await tb.axis_cfg.write(0x184, tdsr.to_bytes(length=4, byteorder='little', signed=False), awid = 0x30, size = 0x2, cache = 0x0, prot = 0x0)

    tcr:int = 1 << 9
    await tb.axis_cfg.write(0xC4, tcr.to_bytes(length=4, byteorder='little', signed=False), awid = 0x30, size = 0x2, cache = 0x0, prot = 0x0)

    tfwr:int = 1 << 8
    await tb.axis_cfg.write(0x144, tfwr.to_bytes(length=4, byteorder='little', signed=False), awid = 0x30, size = 0x2, cache = 0x0, prot = 0x0)

    ecr:int = 0x5EE * 256 * 256 + 0xB
    await tb.axis_cfg.write(0x24, ecr.to_bytes(length=4, byteorder='little', signed=False), awid = 0x30, size = 0x2, cache = 0x0, prot = 0x0)

    await tb.axis_cfg.write(0xE4, bytes(src_mac[3::-1]), awid = 0x30, size = 0x2, cache = 0x0, prot = 0x0)
    await tb.axis_cfg.write(0xE8, bytes((b'\x00' * 2) + src_mac[5:3:-1]), awid = 0x30, size = 0x2, cache = 0x0, prot = 0x0)

    await tb.axis_cfg.write(0x14, (0).to_bytes(length=4, byteorder='little', signed=False), awid = 0x30, size = 0x2, cache = 0x0, prot = 0x0)

    for y in range(3):
        for i in range(128):
            rx_frame:GmiiFrame = await tb.mii_phy.tx.recv()

            assert rx_frame.get_payload(strip_fcs=False) == frames[i + 128 * y]
            assert rx_frame.check_fcs()
            assert rx_frame.error is None

            if y != 2:
                for _ in range(100):
                    await RisingEdge(dut.enet_tx_clk)

                frame = payload_data(128 + i + y)
                frames.append(frame)
                test_buf_addr = random.getrandbits(21)
                assert test_buf_addr * 2 < test_max_num
                while test_buf_addr * 2 * 1024 in tb.tx_sram.addrmap:
                    test_buf_addr = random.getrandbits(21)
                    assert test_buf_addr * 2 < test_max_num
                test_buf:bytearray = bytearray(frame) + bytearray(b'\x00' * (8 - ((128 + i + y + 18) % 8)))
                tb.tx_sram.add_memory_block(test_buf_addr * 2 * 1024, test_buf)
                test_buf_list.append(test_buf_addr * 2)
                tb.tx_sram.addrmap[test_desc_addr * 1024][8 * i + 0] = (128 + i + y + 18) % 256
                tb.tx_sram.addrmap[test_desc_addr * 1024][8 * i + 1] = (128 + i + y + 18) // 256 % 256
                tb.tx_sram.addrmap[test_desc_addr * 1024][8 * i + 2] = 0
                tb.tx_sram.addrmap[test_desc_addr * 1024][8 * i + 3] = 0xBC if (i == 127) else 0x9C
                tb.tx_sram.addrmap[test_desc_addr * 1024][8 * i + 4] = 0
                tb.tx_sram.addrmap[test_desc_addr * 1024][8 * i + 5] = test_buf_addr * 2 * 4 % 256
                tb.tx_sram.addrmap[test_desc_addr * 1024][8 * i + 6] = test_buf_addr * 2 * 4 // 256 % 256
                tb.tx_sram.addrmap[test_desc_addr * 1024][8 * i + 7] = test_buf_addr * 2 * 4 // 256 // 256 % 256

    assert tb.mii_phy.tx.empty()

    await RisingEdge(dut.enet_tx_clk)
    await RisingEdge(dut.enet_tx_clk)

    logging.disable(logging.DEBUG)

async def run_test_rx_warp(dut, payload_data=None, ifg=12, speed=1000e6):

    logging.disable(logging.INFO)

    tb = TB(dut, speed)

    tb.mii_phy.rx.ifg = ifg

    tb.set_speed(speed)

    await tb.reset()

    for k in range(100):
        await RisingEdge(dut.enet_rx_clk)

    test_max_num = 2 ** 22
    test_desc_addr = random.getrandbits(22)
    assert test_desc_addr < test_max_num
    test_desc = bytearray(b'\x00' * 1024)
    tb.rx_sram.add_memory_block(test_desc_addr * 1024, test_desc)
    test_buf_list = []
    for i in range(128):
        test_buf_addr = random.getrandbits(21)
        assert test_buf_addr * 2 < test_max_num
        while test_buf_addr * 2 * 1024 in tb.rx_sram.addrmap:
            test_buf_addr = random.getrandbits(21)
            assert test_buf_addr * 2 < test_max_num
        test_buf = bytearray(b'\x00' * 2048)
        tb.rx_sram.add_memory_block(test_buf_addr * 2 * 1024, test_buf)
        test_buf_list.append(test_buf_addr * 2)
        tb.rx_sram.addrmap[test_desc_addr * 1024][8 * i + 0] = 0
        tb.rx_sram.addrmap[test_desc_addr * 1024][8 * i + 1] = 0
        tb.rx_sram.addrmap[test_desc_addr * 1024][8 * i + 2] = 0
        tb.rx_sram.addrmap[test_desc_addr * 1024][8 * i + 3] = 128
        tb.rx_sram.addrmap[test_desc_addr * 1024][8 * i + 4] = 0
        tb.rx_sram.addrmap[test_desc_addr * 1024][8 * i + 5] = test_buf_addr * 2 * 4 % 256
        tb.rx_sram.addrmap[test_desc_addr * 1024][8 * i + 6] = test_buf_addr * 2 * 4 // 256 % 256
        tb.rx_sram.addrmap[test_desc_addr * 1024][8 * i + 7] = test_buf_addr * 2 * 4 // 256 // 256 % 256
    tb.rx_sram.addrmap[test_desc_addr * 1024][8 * 127 + 3] = 160

    rdsr:int = test_desc_addr * 1024
    await tb.axis_cfg.write(0x180, rdsr.to_bytes(length=4, byteorder='little', signed=False), awid = 0x30, size = 0x2, cache = 0x0, prot = 0x0)

    rcr:int = 8
    await tb.axis_cfg.write(0x84, rcr.to_bytes(length=4, byteorder='little', signed=False), awid = 0x30, size = 0x2, cache = 0x0, prot = 0x0)

    ecr:int = 0x5EE * 256 * 256 + 0xB
    await tb.axis_cfg.write(0x24, ecr.to_bytes(length=4, byteorder='little', signed=False), awid = 0x30, size = 0x2, cache = 0x0, prot = 0x0)

    await tb.axis_cfg.write(0x10, (0).to_bytes(length=4, byteorder='little', signed=False), awid = 0x30, size = 0x2, cache = 0x0, prot = 0x0)

    await Timer(1000 * (100e6 // speed), units="ns")

    for y in range(3):
        for i in range(128):
            event = Event()
            test_data = payload_data(64 + i + y)
            test_frame = GmiiFrame.from_raw_payload(test_data, tx_complete = event)
            await tb.mii_phy.rx.send(test_frame)
            await event.wait()
            await Timer(len(test_data) * 20 * (100e6 // speed), units="ns")
            assert tb.rx_sram.addrmap[test_buf_list[i] * 1024][0:len(test_data)] == test_data
            assert tb.rx_sram.addrmap[test_desc_addr * 1024][8 * i + 0] == (64 + i + y + 18) % 256
            assert tb.rx_sram.addrmap[test_desc_addr * 1024][8 * i + 1] == (64 + i + y + 18) // 256 % 256
            tb.rx_sram.addrmap[test_desc_addr * 1024][8 * i + 3] = 160 if (i == 127) else 128

    await RisingEdge(dut.enet_rx_clk)
    await RisingEdge(dut.enet_rx_clk)

    logging.disable(logging.DEBUG)

async def run_test_rx_error_toolong(dut, payload_data=None, ifg=12, speed=1000e6):

    logging.disable(logging.INFO)

    tb = TB(dut, speed)

    tb.mii_phy.rx.ifg = ifg

    tb.set_speed(speed)

    await tb.reset()

    for k in range(100):
        await RisingEdge(dut.enet_rx_clk)

    test_max_num = 2 ** 22
    test_desc_addr = random.getrandbits(22)
    assert test_desc_addr < test_max_num
    test_desc = bytearray(b'\x00' * 1024)
    tb.rx_sram.add_memory_block(test_desc_addr * 1024, test_desc)
    test_buf_list = []
    for i in range(128):
        test_buf_addr = random.getrandbits(21)
        assert test_buf_addr * 2 < test_max_num
        while test_buf_addr * 2 * 1024 in tb.rx_sram.addrmap:
            test_buf_addr = random.getrandbits(21)
            assert test_buf_addr * 2 < test_max_num
        test_buf = bytearray(b'\x00' * 2048)
        tb.rx_sram.add_memory_block(test_buf_addr * 2 * 1024, test_buf)
        test_buf_list.append(test_buf_addr * 2)
        tb.rx_sram.addrmap[test_desc_addr * 1024][8 * i + 0] = 0
        tb.rx_sram.addrmap[test_desc_addr * 1024][8 * i + 1] = 0
        tb.rx_sram.addrmap[test_desc_addr * 1024][8 * i + 2] = 0
        tb.rx_sram.addrmap[test_desc_addr * 1024][8 * i + 3] = 128
        tb.rx_sram.addrmap[test_desc_addr * 1024][8 * i + 4] = 0
        tb.rx_sram.addrmap[test_desc_addr * 1024][8 * i + 5] = test_buf_addr * 2 * 4 % 256
        tb.rx_sram.addrmap[test_desc_addr * 1024][8 * i + 6] = test_buf_addr * 2 * 4 // 256 % 256
        tb.rx_sram.addrmap[test_desc_addr * 1024][8 * i + 7] = test_buf_addr * 2 * 4 // 256 // 256 % 256
    tb.rx_sram.addrmap[test_desc_addr * 1024][8 * 127 + 3] = 160

    rdsr:int = test_desc_addr * 1024
    await tb.axis_cfg.write(0x180, rdsr.to_bytes(length=4, byteorder='little', signed=False), awid = 0x30, size = 0x2, cache = 0x0, prot = 0x0)

    rcr:int = 8
    await tb.axis_cfg.write(0x84, rcr.to_bytes(length=4, byteorder='little', signed=False), awid = 0x30, size = 0x2, cache = 0x0, prot = 0x0)

    ecr:int = 0x7FF * 256 * 256 + 0xB
    await tb.axis_cfg.write(0x24, ecr.to_bytes(length=4, byteorder='little', signed=False), awid = 0x30, size = 0x2, cache = 0x0, prot = 0x0)

    ftrl:int = 0x5EE
    await tb.axis_cfg.write(0x1B0, ftrl.to_bytes(length=4, byteorder='little', signed=False), awid = 0x30, size = 0x2, cache = 0x0, prot = 0x0)

    await tb.axis_cfg.write(0x10, (0).to_bytes(length=4, byteorder='little', signed=False), awid = 0x30, size = 0x2, cache = 0x0, prot = 0x0)

    await Timer(1000 * (100e6 // speed), units="ns")

    for i in range(128):
        event = Event()
        optaretion = random.randint(0,1)
        if optaretion == 0:# toolong error frame
            test_data = payload_data(1501 + i)
            test_frame = GmiiFrame.from_raw_payload(test_data, tx_complete = event)
            await tb.mii_phy.rx.send(test_frame)
            await event.wait()
            await Timer(len(test_data) * 20 * (100e6 // speed), units="ns")
            assert (tb.rx_sram.addrmap[test_desc_addr * 1024][8 * i + 2] & 0x1) == 0x1
        else:# normal frame
            test_data = payload_data(128 + i)
            test_frame = GmiiFrame.from_raw_payload(test_data, tx_complete = event)
            await tb.mii_phy.rx.send(test_frame)
            await event.wait()
            await Timer(len(test_data) * 20 * (100e6 // speed), units="ns")
            assert tb.rx_sram.addrmap[test_buf_list[i] * 1024][0:len(test_data)] == test_data
            assert tb.rx_sram.addrmap[test_desc_addr * 1024][8 * i + 0] == (128 + i + 18) % 256
            assert tb.rx_sram.addrmap[test_desc_addr * 1024][8 * i + 1] == (128 + i + 18) // 256 % 256

    await RisingEdge(dut.enet_rx_clk)
    await RisingEdge(dut.enet_rx_clk)

    logging.disable(logging.DEBUG)

async def run_test_rx_error_babr(dut, payload_data=None, ifg=12, speed=1000e6):

    logging.disable(logging.INFO)

    tb = TB(dut, speed)

    tb.mii_phy.rx.ifg = ifg

    tb.set_speed(speed)

    await tb.reset()

    for k in range(100):
        await RisingEdge(dut.enet_rx_clk)

    test_max_num = 2 ** 22
    test_desc_addr = random.getrandbits(22)
    assert test_desc_addr < test_max_num
    test_desc = bytearray(b'\x00' * 1024)
    tb.rx_sram.add_memory_block(test_desc_addr * 1024, test_desc)
    test_buf_list = []
    for i in range(128):
        test_buf_addr = random.getrandbits(21)
        assert test_buf_addr * 2 < test_max_num
        while test_buf_addr * 2 * 1024 in tb.rx_sram.addrmap:
            test_buf_addr = random.getrandbits(21)
            assert test_buf_addr * 2 < test_max_num
        test_buf = bytearray(b'\x00' * 2048)
        tb.rx_sram.add_memory_block(test_buf_addr * 2 * 1024, test_buf)
        test_buf_list.append(test_buf_addr * 2)
        tb.rx_sram.addrmap[test_desc_addr * 1024][8 * i + 0] = 0
        tb.rx_sram.addrmap[test_desc_addr * 1024][8 * i + 1] = 0
        tb.rx_sram.addrmap[test_desc_addr * 1024][8 * i + 2] = 0
        tb.rx_sram.addrmap[test_desc_addr * 1024][8 * i + 3] = 128
        tb.rx_sram.addrmap[test_desc_addr * 1024][8 * i + 4] = 0
        tb.rx_sram.addrmap[test_desc_addr * 1024][8 * i + 5] = test_buf_addr * 2 * 4 % 256
        tb.rx_sram.addrmap[test_desc_addr * 1024][8 * i + 6] = test_buf_addr * 2 * 4 // 256 % 256
        tb.rx_sram.addrmap[test_desc_addr * 1024][8 * i + 7] = test_buf_addr * 2 * 4 // 256 // 256 % 256
    tb.rx_sram.addrmap[test_desc_addr * 1024][8 * 127 + 3] = 160

    rdsr:int = test_desc_addr * 1024
    await tb.axis_cfg.write(0x180, rdsr.to_bytes(length=4, byteorder='little', signed=False), awid = 0x30, size = 0x2, cache = 0x0, prot = 0x0)

    rcr:int = 8
    await tb.axis_cfg.write(0x84, rcr.to_bytes(length=4, byteorder='little', signed=False), awid = 0x30, size = 0x2, cache = 0x0, prot = 0x0)

    ecr:int = 0x5EE * 256 * 256 + 0xB
    await tb.axis_cfg.write(0x24, ecr.to_bytes(length=4, byteorder='little', signed=False), awid = 0x30, size = 0x2, cache = 0x0, prot = 0x0)

    await tb.axis_cfg.write(0x10, (0).to_bytes(length=4, byteorder='little', signed=False), awid = 0x30, size = 0x2, cache = 0x0, prot = 0x0)

    await Timer(1000 * (100e6 // speed), units="ns")

    for i in range(128):
        event = Event()
        test_data = payload_data(1501 + i)
        test_frame = GmiiFrame.from_raw_payload(test_data, tx_complete = event)
        await tb.mii_phy.rx.send(test_frame)
        await event.wait()
        await Timer(len(test_data) * 20 * (100e6 // speed), units="ns")
        assert (tb.rx_sram.addrmap[test_desc_addr * 1024][8 * i + 2] & (0x1 << 5)) == (0x1 << 5)
        eir = await tb.axis_cfg.read(0x4, 4, arid = 0x30, size = 0x2, cache = 0x0, prot = 0x0)
        assert eir.data == ((0x1 << 30) | (0x1 << 25)).to_bytes(length=4, byteorder='little', signed=False)
        await tb.axis_cfg.write(0x4, ((0x1 << 30) | (0x1 << 25)).to_bytes(length=4, byteorder='little', signed=False), awid = 0x30, size = 0x2, cache = 0x0, prot = 0x0)

    await RisingEdge(dut.enet_rx_clk)
    await RisingEdge(dut.enet_rx_clk)

    logging.disable(logging.DEBUG)

async def run_test_tx_error_babt(dut, payload_data=None, ifg=12, speed=1000e6):

    logging.disable(logging.INFO)

    src_mac = generate_mac()  # 源MAC地址

    tb = TB(dut, speed)

    tb.mii_phy.rx.ifg = ifg

    tb.set_speed(speed)

    await tb.reset()

    for k in range(100):
        await RisingEdge(dut.enet_tx_clk)

    frames = []

    test_max_num = 2 ** 22
    test_desc_addr = random.getrandbits(22)
    assert test_desc_addr < test_max_num
    test_desc = bytearray(b'\x00' * 1024)
    tb.tx_sram.add_memory_block(test_desc_addr * 1024, test_desc)
    test_buf_list = []
    for i in range(128):
        frame = payload_data(1501 + i)
        frames.append(frame)
        test_buf_addr = random.getrandbits(21)
        assert test_buf_addr * 2 < test_max_num
        while test_buf_addr * 2 * 1024 in tb.tx_sram.addrmap:
            test_buf_addr = random.getrandbits(21)
            assert test_buf_addr * 2 < test_max_num
        test_buf:bytearray = bytearray(frame) + bytearray(b'\x00' * (8 - ((1519 + i) % 8)))
        tb.tx_sram.add_memory_block(test_buf_addr * 2 * 1024, test_buf)
        test_buf_list.append(test_buf_addr * 2)
        tb.tx_sram.addrmap[test_desc_addr * 1024][8 * i + 0] = (1519 + i) % 256
        tb.tx_sram.addrmap[test_desc_addr * 1024][8 * i + 1] = (1519 + i) // 256 % 256
        tb.tx_sram.addrmap[test_desc_addr * 1024][8 * i + 2] = 0
        tb.tx_sram.addrmap[test_desc_addr * 1024][8 * i + 3] = 0x9C
        tb.tx_sram.addrmap[test_desc_addr * 1024][8 * i + 4] = 0
        tb.tx_sram.addrmap[test_desc_addr * 1024][8 * i + 5] = test_buf_addr * 2 * 4 % 256
        tb.tx_sram.addrmap[test_desc_addr * 1024][8 * i + 6] = test_buf_addr * 2 * 4 // 256 % 256
        tb.tx_sram.addrmap[test_desc_addr * 1024][8 * i + 7] = test_buf_addr * 2 * 4 // 256 // 256 % 256
    tb.tx_sram.addrmap[test_desc_addr * 1024][8 * 127 + 3] = 0xBC

    tdsr:int = test_desc_addr * 1024
    await tb.axis_cfg.write(0x184, tdsr.to_bytes(length=4, byteorder='little', signed=False), awid = 0x30, size = 0x2, cache = 0x0, prot = 0x0)

    tcr:int = 1 << 9
    await tb.axis_cfg.write(0xC4, tcr.to_bytes(length=4, byteorder='little', signed=False), awid = 0x30, size = 0x2, cache = 0x0, prot = 0x0)

    tfwr:int = 1 << 8
    await tb.axis_cfg.write(0x144, tfwr.to_bytes(length=4, byteorder='little', signed=False), awid = 0x30, size = 0x2, cache = 0x0, prot = 0x0)

    ecr:int = 0x5EE * 256 * 256 + 0xB
    await tb.axis_cfg.write(0x24, ecr.to_bytes(length=4, byteorder='little', signed=False), awid = 0x30, size = 0x2, cache = 0x0, prot = 0x0)

    await tb.axis_cfg.write(0xE4, bytes(src_mac[3::-1]), awid = 0x30, size = 0x2, cache = 0x0, prot = 0x0)
    await tb.axis_cfg.write(0xE8, bytes((b'\x00' * 2) + src_mac[5:3:-1]), awid = 0x30, size = 0x2, cache = 0x0, prot = 0x0)

    await tb.axis_cfg.write(0x14, (0).to_bytes(length=4, byteorder='little', signed=False), awid = 0x30, size = 0x2, cache = 0x0, prot = 0x0)

    for i in range(128):
        rx_frame:GmiiFrame = await tb.mii_phy.tx.recv()

        assert rx_frame.get_payload(strip_fcs=False) == frames[i]
        assert rx_frame.check_fcs()
        assert rx_frame.error is None
        await Timer(len(frames[i]) * 2, units="ns")
        eir = await tb.axis_cfg.read(0x4, 4, arid = 0x30, size = 0x2, cache = 0x0, prot = 0x0)
        assert eir.data == ((0x1 << 29) | (0x1 << 27)).to_bytes(length=4, byteorder='little', signed=False)
        await tb.axis_cfg.write(0x4, ((0x1 << 29) | (0x1 << 27)).to_bytes(length=4, byteorder='little', signed=False), awid = 0x30, size = 0x2, cache = 0x0, prot = 0x0)

    assert tb.mii_phy.tx.empty()

    await RisingEdge(dut.enet_tx_clk)
    await RisingEdge(dut.enet_tx_clk)

    logging.disable(logging.DEBUG)

async def run_test_tx_sgdma(dut, strfwd:bool, payload_data=None, ifg=12, speed=1000e6):

    logging.disable(logging.INFO)

    def split_bytearray_equal_parts(data: bytearray, n: int) -> List[bytearray]:
        """
        将bytearray等分为n份，最后一个块可以小于其他块
        
        参数:
            data: 要分割的bytearray
            n: 要分割成的份数
        
        返回:
            List[bytearray]: 包含n个bytearray的列表
        """
        if n <= 0:
            return []
        
        if not data or n == 1:
            return [data]
        
        length = len(data)
        result = []
        
        # 计算每份的基本大小
        base_size = length // n
        
        start = 0
        for i in range(n - 1):
            end = start + base_size
            result.append(data[start:end])
            start = end
        
        # 最后一块包含剩余的所有数据
        result.append(data[start:])
        
        return result
    
    def split_bytearray_random_parts(data: bytearray, n: int) -> List[bytearray]:
        """
        将bytearray随机分割为n份，每份大小随机
        
        参数:
            data: 要分割的bytearray
            n: 要分割成的份数
        
        返回:
            List[bytearray]: 包含n个bytearray的列表，每份大小随机
        """
        if n <= 0:
            return []
        
        if not data or n == 1:
            return [data]
        
        length = len(data)
        result = []
        remaining = length
        remaining_parts = n
        
        # 生成n-1个随机分割点
        for i in range(n - 1):
            # 为当前块随机分配大小，但确保每个块至少1字节且剩余部分足够分配
            max_size = remaining - (remaining_parts - 1)
            if max_size <= 0:
                # 剩余部分不够分配，所有剩余块为空
                chunk_size = 0
            else:
                # 随机分配大小，倾向于更均匀但保持随机性
                chunk_size = random.randint(1, max_size)
            
            # 提取当前块
            start_index = length - remaining
            result.append(data[start_index:start_index + chunk_size])
            
            # 更新剩余数据和剩余块数
            remaining -= chunk_size
            remaining_parts -= 1
        
        # 最后一块包含剩余的所有数据
        start_index = length - remaining
        result.append(data[start_index:])
        
        return result

    src_mac = generate_mac()  # 源MAC地址

    tb = TB(dut, speed)

    tb.mii_phy.rx.ifg = ifg

    tb.set_speed(speed)

    await tb.reset()

    for k in range(100):
        await RisingEdge(dut.enet_tx_clk)

    test_max_num = 2 ** 22
    test_desc_addr = random.getrandbits(22)
    assert test_desc_addr < test_max_num
    test_desc = bytearray(b'\x00' * 1024)
    tb.tx_sram.add_memory_block(test_desc_addr * 1024, test_desc)
    tb.tx_sram.addrmap[test_desc_addr * 1024][8 * 127 + 3] |= 0x20

    tdsr:int = test_desc_addr * 1024
    await tb.axis_cfg.write(0x184, tdsr.to_bytes(length=4, byteorder='little', signed=False), awid = 0x30, size = 0x2, cache = 0x0, prot = 0x0)

    tfwr:int = (1 << 8 if strfwd else 0)
    await tb.axis_cfg.write(0x144, tfwr.to_bytes(length=4, byteorder='little', signed=False), awid = 0x30, size = 0x2, cache = 0x0, prot = 0x0)

    tcr:int = 1 << 9
    await tb.axis_cfg.write(0xC4, tcr.to_bytes(length=4, byteorder='little', signed=False), awid = 0x30, size = 0x2, cache = 0x0, prot = 0x0)

    ecr:int = 0x5EE * 256 * 256 + 0xB
    await tb.axis_cfg.write(0x24, ecr.to_bytes(length=4, byteorder='little', signed=False), awid = 0x30, size = 0x2, cache = 0x0, prot = 0x0)

    await tb.axis_cfg.write(0xE4, bytes(src_mac[3::-1]), awid = 0x30, size = 0x2, cache = 0x0, prot = 0x0)
    await tb.axis_cfg.write(0xE8, bytes((b'\x00' * 2) + src_mac[5:3:-1]), awid = 0x30, size = 0x2, cache = 0x0, prot = 0x0)

    for func in [split_bytearray_equal_parts, split_bytearray_random_parts]:
        for i in range(128):
            x = random.randint(2, 63)
            frame = payload_data(1024 + i)
            get_data = func(frame, x)
            for y in range(len(get_data)):
                test_buf_addr = random.getrandbits(21)
                assert test_buf_addr * 2 < test_max_num
                while test_buf_addr * 2 * 1024 in tb.tx_sram.addrmap:
                    test_buf_addr = random.getrandbits(21)
                    assert test_buf_addr * 2 < test_max_num
                test_buf:bytearray = bytearray(get_data[y]) + bytearray(b'\x00' * ((8 - (len(get_data[y]) % 8)) % 8))
                tb.tx_sram.add_memory_block(test_buf_addr * 2 * 1024, test_buf)
                tb.tx_sram.addrmap[test_desc_addr * 1024][8 * y + 0] = (len(get_data[y])) % 256
                tb.tx_sram.addrmap[test_desc_addr * 1024][8 * y + 1] = (len(get_data[y])) // 256 % 256
                tb.tx_sram.addrmap[test_desc_addr * 1024][8 * y + 2] = 0
                tb.tx_sram.addrmap[test_desc_addr * 1024][8 * y + 3] = 0x84
                tb.tx_sram.addrmap[test_desc_addr * 1024][8 * y + 4] = 0
                tb.tx_sram.addrmap[test_desc_addr * 1024][8 * y + 5] = test_buf_addr * 2 * 4 % 256
                tb.tx_sram.addrmap[test_desc_addr * 1024][8 * y + 6] = test_buf_addr * 2 * 4 // 256 % 256
                tb.tx_sram.addrmap[test_desc_addr * 1024][8 * y + 7] = test_buf_addr * 2 * 4 // 256 // 256 % 256
            tb.tx_sram.addrmap[test_desc_addr * 1024][8 * (len(get_data) - 1) + 3] = 0xBC
            await tb.axis_cfg.write(0x14, (0).to_bytes(length=4, byteorder='little', signed=False), awid = 0x30, size = 0x2, cache = 0x0, prot = 0x0)

            rx_frame:GmiiFrame = await tb.mii_phy.tx.recv()

            assert rx_frame.get_payload(strip_fcs=False) == frame
            assert rx_frame.check_fcs()
            assert rx_frame.error is None
            await Timer(len(frame) * 10 * (100e6 // speed), units="ns")
            eir = await tb.axis_cfg.read(0x4, 4, arid = 0x30, size = 0x2, cache = 0x0, prot = 0x0)
            assert eir.data == (0x1 << 27).to_bytes(length=4, byteorder='little', signed=False)
            await tb.axis_cfg.write(0x4, (0x1 << 27).to_bytes(length=4, byteorder='little', signed=False), awid = 0x30, size = 0x2, cache = 0x0, prot = 0x0)

    assert tb.mii_phy.tx.empty()

    await RisingEdge(dut.enet_tx_clk)
    await RisingEdge(dut.enet_tx_clk)

    logging.disable(logging.DEBUG)

async def run_test_rx_error_fifo_protect(dut, payload_data=None, ifg=12, speed=1000e6):

    logging.disable(logging.INFO)

    tb = TB(dut, speed, rx_w_delay=1200 * (100e6 // speed))

    tb.mii_phy.rx.ifg = ifg

    tb.set_speed(speed)

    await tb.reset()

    for k in range(100):
        await RisingEdge(dut.enet_rx_clk)

    test_max_num = 2 ** 22
    test_desc_addr = random.getrandbits(22)
    assert test_desc_addr < test_max_num
    test_desc = bytearray(b'\x00' * 1024)
    tb.rx_sram.add_memory_block(test_desc_addr * 1024, test_desc)
    test_buf_list = []
    for i in range(128):
        test_buf_addr = random.getrandbits(21)
        assert test_buf_addr * 2 < test_max_num
        while test_buf_addr * 2 * 1024 in tb.rx_sram.addrmap:
            test_buf_addr = random.getrandbits(21)
            assert test_buf_addr * 2 < test_max_num
        test_buf = bytearray(b'\x00' * 2048)
        tb.rx_sram.add_memory_block(test_buf_addr * 2 * 1024, test_buf)
        test_buf_list.append(test_buf_addr * 2)
        tb.rx_sram.addrmap[test_desc_addr * 1024][8 * i + 0] = 0
        tb.rx_sram.addrmap[test_desc_addr * 1024][8 * i + 1] = 0
        tb.rx_sram.addrmap[test_desc_addr * 1024][8 * i + 2] = 0
        tb.rx_sram.addrmap[test_desc_addr * 1024][8 * i + 3] = 128
        tb.rx_sram.addrmap[test_desc_addr * 1024][8 * i + 4] = 0
        tb.rx_sram.addrmap[test_desc_addr * 1024][8 * i + 5] = test_buf_addr * 2 * 4 % 256
        tb.rx_sram.addrmap[test_desc_addr * 1024][8 * i + 6] = test_buf_addr * 2 * 4 // 256 % 256
        tb.rx_sram.addrmap[test_desc_addr * 1024][8 * i + 7] = test_buf_addr * 2 * 4 // 256 // 256 % 256
    tb.rx_sram.addrmap[test_desc_addr * 1024][8 * 127 + 3] = 160

    rdsr:int = test_desc_addr * 1024
    await tb.axis_cfg.write(0x180, rdsr.to_bytes(length=4, byteorder='little', signed=False), awid = 0x30, size = 0x2, cache = 0x0, prot = 0x0)

    rcr:int = 8
    await tb.axis_cfg.write(0x84, rcr.to_bytes(length=4, byteorder='little', signed=False), awid = 0x30, size = 0x2, cache = 0x0, prot = 0x0)

    ecr:int = 0x7FF * 256 * 256 + 0xB
    await tb.axis_cfg.write(0x24, ecr.to_bytes(length=4, byteorder='little', signed=False), awid = 0x30, size = 0x2, cache = 0x0, prot = 0x0)

    ftrl:int = 0x5EE
    await tb.axis_cfg.write(0x1B0, ftrl.to_bytes(length=4, byteorder='little', signed=False), awid = 0x30, size = 0x2, cache = 0x0, prot = 0x0)

    await tb.axis_cfg.write(0x10, (0).to_bytes(length=4, byteorder='little', signed=False), awid = 0x30, size = 0x2, cache = 0x0, prot = 0x0)

    await Timer(1000 * (100e6 // speed), units="ns")

    for i in range(64):
        event0 = Event()
        event1 = Event()
        optaretion = random.randint(0,1)
        test_data0 = payload_data(1500)
        test_frame = GmiiFrame.from_raw_payload(test_data0, tx_complete = event0)
        await tb.mii_phy.rx.send(test_frame)
        await event0.wait()
        if optaretion == 0:# fifo protect error frame
            test_data = payload_data(1300 + i)
            test_frame = GmiiFrame.from_raw_payload(test_data, tx_complete = event1)
            await tb.mii_phy.rx.send(test_frame)
            await event1.wait()
            await Timer(len(test_data0) * 200 * (100e6 // speed), units="ns")
            assert tb.rx_sram.addrmap[test_buf_list[i * 2] * 1024][0:len(test_data0)] == test_data0
            assert tb.rx_sram.addrmap[test_desc_addr * 1024][16 * i + 0] == (1518) % 256
            assert tb.rx_sram.addrmap[test_desc_addr * 1024][16 * i + 1] == (1518) // 256 % 256
            assert (tb.rx_sram.addrmap[test_desc_addr * 1024][16 * i + 10] & 0x2) == 0x2
        else:# normal frame
            await Timer(len(test_data0) * 200 * (100e6 // speed), units="ns")
            assert tb.rx_sram.addrmap[test_buf_list[i * 2] * 1024][0:len(test_data0)] == test_data0
            assert tb.rx_sram.addrmap[test_desc_addr * 1024][16 * i + 0] == (1518) % 256
            assert tb.rx_sram.addrmap[test_desc_addr * 1024][16 * i + 1] == (1518) // 256 % 256
            test_data = payload_data(1300 + i)
            test_frame = GmiiFrame.from_raw_payload(test_data, tx_complete = event1)
            await tb.mii_phy.rx.send(test_frame)
            await event1.wait()
            await Timer(len(test_data) * 200 * (100e6 // speed), units="ns")
            assert tb.rx_sram.addrmap[test_buf_list[i * 2 + 1] * 1024][0:len(test_data)] == test_data
            assert tb.rx_sram.addrmap[test_desc_addr * 1024][16 * i + 8] == (1300 + i + 18) % 256
            assert tb.rx_sram.addrmap[test_desc_addr * 1024][16 * i + 9] == (1300 + i + 18) // 256 % 256

    await RisingEdge(dut.enet_rx_clk)
    await RisingEdge(dut.enet_rx_clk)

    logging.disable(logging.DEBUG)

async def run_test_rx_pause_gen(dut, payload_data=None, ifg=12, speed=1000e6):

    logging.disable(logging.INFO)

    dst_mac = b'\x01\x80\xC2\x00\x00\x01'
    src_mac = generate_mac()  # 源MAC地址
    length_type = b'\x88\x08'
    pause_opcode = b'\x00\x01'
    padding = bytes(b'\x00' * 42)

    tb = TB(dut, speed)

    tb.mii_phy.rx.ifg = ifg

    tb.set_speed(speed)

    await tb.reset()

    for k in range(100):
        await RisingEdge(dut.enet_rx_clk)

    test_max_num = 2 ** 22
    test_desc_addr = random.getrandbits(22)
    assert test_desc_addr < test_max_num
    test_desc = bytearray(b'\x00' * 1024)
    tb.rx_sram.add_memory_block(test_desc_addr * 1024, test_desc)
    test_buf_list = []
    for i in range(128):
        test_buf_addr = random.getrandbits(21)
        assert test_buf_addr * 2 < test_max_num
        while test_buf_addr * 2 * 1024 in tb.rx_sram.addrmap:
            test_buf_addr = random.getrandbits(21)
            assert test_buf_addr * 2 < test_max_num
        test_buf = bytearray(b'\x00' * 2048)
        tb.rx_sram.add_memory_block(test_buf_addr * 2 * 1024, test_buf)
        test_buf_list.append(test_buf_addr * 2)
        tb.rx_sram.addrmap[test_desc_addr * 1024][8 * i + 0] = 0
        tb.rx_sram.addrmap[test_desc_addr * 1024][8 * i + 1] = 0
        tb.rx_sram.addrmap[test_desc_addr * 1024][8 * i + 2] = 0
        tb.rx_sram.addrmap[test_desc_addr * 1024][8 * i + 3] = 128
        tb.rx_sram.addrmap[test_desc_addr * 1024][8 * i + 4] = 0
        tb.rx_sram.addrmap[test_desc_addr * 1024][8 * i + 5] = test_buf_addr * 2 * 4 % 256
        tb.rx_sram.addrmap[test_desc_addr * 1024][8 * i + 6] = test_buf_addr * 2 * 4 // 256 % 256
        tb.rx_sram.addrmap[test_desc_addr * 1024][8 * i + 7] = test_buf_addr * 2 * 4 // 256 // 256 % 256
    tb.rx_sram.addrmap[test_desc_addr * 1024][8 * 127 + 3] = 160

    rdsr:int = test_desc_addr * 1024
    await tb.axis_cfg.write(0x180, rdsr.to_bytes(length=4, byteorder='little', signed=False), awid = 0x30, size = 0x2, cache = 0x0, prot = 0x0)

    rcr:int = 8
    await tb.axis_cfg.write(0x84, rcr.to_bytes(length=4, byteorder='little', signed=False), awid = 0x30, size = 0x2, cache = 0x0, prot = 0x0)

    ecr:int = 0x7FF * 256 * 256 + 0xB
    await tb.axis_cfg.write(0x24, ecr.to_bytes(length=4, byteorder='little', signed=False), awid = 0x30, size = 0x2, cache = 0x0, prot = 0x0)

    ftrl:int = 0x5EE
    await tb.axis_cfg.write(0x1B0, ftrl.to_bytes(length=4, byteorder='little', signed=False), awid = 0x30, size = 0x2, cache = 0x0, prot = 0x0)

    rsem:int = 0x84
    await tb.axis_cfg.write(0x194, rsem.to_bytes(length=4, byteorder='little', signed=False), awid = 0x30, size = 0x2, cache = 0x0, prot = 0x0)

    await tb.axis_cfg.write(0xE4, bytes(src_mac[3::-1]), awid = 0x30, size = 0x2, cache = 0x0, prot = 0x0)
    await tb.axis_cfg.write(0xE8, bytes((b'\x00' * 2) + src_mac[5:3:-1]), awid = 0x30, size = 0x2, cache = 0x0, prot = 0x0)

    await tb.axis_cfg.write(0x10, (0).to_bytes(length=4, byteorder='little', signed=False), awid = 0x30, size = 0x2, cache = 0x0, prot = 0x0)

    for i in range(128):
        event0 = Event()
        hi = bytes([random.randint(0, 255)])
        lo = bytes([random.randint(0, 255)])
        await tb.axis_cfg.write(0xEC, (lo + hi + (b'\x00' * 2)), awid = 0x30, size = 0x2, cache = 0x0, prot = 0x0)
        await Timer(1000 * (100e6 // speed), units="ns")
        test_data0 = payload_data(1300 + i)
        test_frame = GmiiFrame.from_raw_payload(test_data0, tx_complete = event0)
        await tb.mii_phy.rx.send(test_frame)
        await event0.wait()

        frame_without_fcs = dst_mac + src_mac + length_type + pause_opcode + hi + lo + padding
        fcs = struct.pack('<L', zlib.crc32(frame_without_fcs))
        ethernet_frame = frame_without_fcs + fcs
        rx_frame:GmiiFrame = await tb.mii_phy.tx.recv()
        assert rx_frame.get_payload(strip_fcs=False) == ethernet_frame
        assert rx_frame.check_fcs()
        assert rx_frame.error is None

        frame_without_fcs = dst_mac + src_mac + length_type + pause_opcode + (b'\x00' * 2) + padding
        fcs = struct.pack('<L', zlib.crc32(frame_without_fcs))
        ethernet_frame = frame_without_fcs + fcs
        rx_frame:GmiiFrame = await tb.mii_phy.tx.recv()
        assert rx_frame.get_payload(strip_fcs=False) == ethernet_frame
        assert rx_frame.check_fcs()
        assert rx_frame.error is None

        await Timer(len(test_data0) * 2, units="ns")
        assert tb.rx_sram.addrmap[test_buf_list[i] * 1024][0:len(test_data0)] == test_data0
        assert tb.rx_sram.addrmap[test_desc_addr * 1024][8 * i + 0] == (1318 + i) % 256
        assert tb.rx_sram.addrmap[test_desc_addr * 1024][8 * i + 1] == (1318 + i) // 256 % 256

    await RisingEdge(dut.enet_rx_clk)
    await RisingEdge(dut.enet_rx_clk)

    logging.disable(logging.DEBUG)

async def run_test_tx_underrun(dut, payload_lengths=None, payload_data=None, ifg=12, speed=1000e6):

    logging.disable(logging.INFO)

    src_mac = generate_mac()  # 源MAC地址

    tb = TB(dut, speed)

    tb.mii_phy.rx.ifg = ifg

    tb.set_speed(speed)

    await tb.reset()

    for k in range(100):
        await RisingEdge(dut.enet_tx_clk)

    test_frames:List[bytearray, Event, int] = [[payload_data(x), Event(), x] for x in payload_lengths()]

    test_max_num = 2 ** 22
    test_desc_addr = random.getrandbits(22)
    assert test_desc_addr < test_max_num
    test_desc = bytearray(b'\x00' * 1024)
    tb.tx_sram.add_memory_block(test_desc_addr * 1024, test_desc)
    test_buf_list = []
    for i in range(len(test_frames)):
        test_buf_addr = random.getrandbits(21)
        assert test_buf_addr * 2 < test_max_num
        while test_buf_addr * 2 * 1024 in tb.tx_sram.addrmap:
            test_buf_addr = random.getrandbits(21)
            assert test_buf_addr * 2 < test_max_num
        test_buf:bytearray = bytearray(test_frames[i][0]) + bytearray(b'\x00' * (8 - ((test_frames[i][2] + 18) % 8)))
        tb.tx_sram.add_memory_block(test_buf_addr * 2 * 1024, test_buf)
        test_buf_list.append(test_buf_addr * 2)
        tb.tx_sram.addrmap[test_desc_addr * 1024][8 * i + 0] = (test_frames[i][2] + 18) % 256
        tb.tx_sram.addrmap[test_desc_addr * 1024][8 * i + 1] = (test_frames[i][2] + 18) // 256 % 256
        tb.tx_sram.addrmap[test_desc_addr * 1024][8 * i + 2] = 0
        tb.tx_sram.addrmap[test_desc_addr * 1024][8 * i + 3] = 0x1C
        tb.tx_sram.addrmap[test_desc_addr * 1024][8 * i + 4] = 0
        tb.tx_sram.addrmap[test_desc_addr * 1024][8 * i + 5] = test_buf_addr * 2 * 4 % 256
        tb.tx_sram.addrmap[test_desc_addr * 1024][8 * i + 6] = test_buf_addr * 2 * 4 // 256 % 256
        tb.tx_sram.addrmap[test_desc_addr * 1024][8 * i + 7] = test_buf_addr * 2 * 4 // 256 // 256 % 256
    tb.tx_sram.addrmap[test_desc_addr * 1024][8 * 127 + 3] |= 0x20

    tdsr:int = test_desc_addr * 1024
    await tb.axis_cfg.write(0x184, tdsr.to_bytes(length=4, byteorder='little', signed=False), awid = 0x30, size = 0x2, cache = 0x0, prot = 0x0)

    tcr:int = 1 << 9
    await tb.axis_cfg.write(0xC4, tcr.to_bytes(length=4, byteorder='little', signed=False), awid = 0x30, size = 0x2, cache = 0x0, prot = 0x0)

    tfwr:int = 0
    await tb.axis_cfg.write(0x144, tfwr.to_bytes(length=4, byteorder='little', signed=False), awid = 0x30, size = 0x2, cache = 0x0, prot = 0x0)

    ecr:int = 0x7EE * 256 * 256 + 0xB
    await tb.axis_cfg.write(0x24, ecr.to_bytes(length=4, byteorder='little', signed=False), awid = 0x30, size = 0x2, cache = 0x0, prot = 0x0)

    await tb.axis_cfg.write(0xE4, bytes(src_mac[3::-1]), awid = 0x30, size = 0x2, cache = 0x0, prot = 0x0)
    await tb.axis_cfg.write(0xE8, bytes((b'\x00' * 2) + src_mac[5:3:-1]), awid = 0x30, size = 0x2, cache = 0x0, prot = 0x0)

    await tb.axis_cfg.write(0x14, (0).to_bytes(length=4, byteorder='little', signed=False), awid = 0x30, size = 0x2, cache = 0x0, prot = 0x0)

    for i, [test_data, event, _] in enumerate(test_frames):
        operation = random.randint(0, 1)
        if operation == 0:
            # underrun error
            tb.tx_sram.addrmap[test_desc_addr * 1024][8 * i + 0] = (test_frames[i][2] + (30 + (len(test_data) // 10))) % 256
            tb.tx_sram.addrmap[test_desc_addr * 1024][8 * i + 1] = (test_frames[i][2] + (30 + (len(test_data) // 10))) // 256 % 256
        else: # operation == 1
            # underrun no happen
            pass
        tb.tx_sram.addrmap[test_desc_addr * 1024][8 * i + 3] = 0x9C
        tb.tx_sram.addrmap[test_desc_addr * 1024][8 * 127 + 3] |= 0x20
        await tb.axis_cfg.write(0x14, (0).to_bytes(length=4, byteorder='little', signed=False), awid = 0x30, size = 0x2, cache = 0x0, prot = 0x0)
        rx_frame:GmiiFrame = await tb.mii_phy.tx.recv()

        if operation == 0:
            # underrun error
            assert rx_frame.error[-1] == 1
            await Timer(40000 * int(1000e6 // speed) * ((len(test_data) // 100) if len(test_data) > 200 else 2), units="ns")
            assert (tb.tx_sram.addrmap[test_desc_addr * 1024][8 * i + 2] & 0x2) == 0x2
            eir = await tb.axis_cfg.read(0x4, 4, arid = 0x30, size = 0x2, cache = 0x0, prot = 0x0)
            assert (int.from_bytes(eir.data, byteorder='little') & ((0x1 << 19) | (0x1 << 27))) == ((0x1 << 19) | (0x1 << 27))
            await tb.axis_cfg.write(0x4, ((0x1 << 19) | (0x1 << 27)).to_bytes(length=4, byteorder='little', signed=False), awid = 0x30, size = 0x2, cache = 0x0, prot = 0x0)
        else: # operation == 1
            assert rx_frame.get_payload(strip_fcs=False) == test_data
            assert rx_frame.check_fcs()
            assert rx_frame.error is None

    assert tb.mii_phy.tx.empty()

    await RisingEdge(dut.enet_tx_clk)
    await RisingEdge(dut.enet_tx_clk)

    logging.disable(logging.DEBUG)

async def run_test_rx_vlan(dut, payload_lengths=None, payload_data=None, ifg=12, speed=1000e6):

    logging.disable(logging.INFO)

    tb = TB(dut, speed)

    tb.mii_phy.rx.ifg = ifg

    tb.set_speed(speed)

    await tb.reset()

    for k in range(100):
        await RisingEdge(dut.enet_rx_clk)

    test_max_num = 2 ** 22
    test_desc_addr = random.getrandbits(22)
    assert test_desc_addr < test_max_num
    test_desc = bytearray(b'\x00' * 1024)
    tb.rx_sram.add_memory_block(test_desc_addr * 1024, test_desc)
    test_buf_list = []
    for i in range(128):
        test_buf_addr = random.getrandbits(21)
        assert test_buf_addr * 2 < test_max_num
        while test_buf_addr * 2 * 1024 in tb.rx_sram.addrmap:
            test_buf_addr = random.getrandbits(21)
            assert test_buf_addr * 2 < test_max_num
        test_buf = bytearray(b'\x00' * 2048)
        tb.rx_sram.add_memory_block(test_buf_addr * 2 * 1024, test_buf)
        test_buf_list.append(test_buf_addr * 2)
        tb.rx_sram.addrmap[test_desc_addr * 1024][8 * i + 0] = 0
        tb.rx_sram.addrmap[test_desc_addr * 1024][8 * i + 1] = 0
        tb.rx_sram.addrmap[test_desc_addr * 1024][8 * i + 2] = 0
        tb.rx_sram.addrmap[test_desc_addr * 1024][8 * i + 3] = 128
        tb.rx_sram.addrmap[test_desc_addr * 1024][8 * i + 4] = 0
        tb.rx_sram.addrmap[test_desc_addr * 1024][8 * i + 5] = test_buf_addr * 2 * 4 % 256
        tb.rx_sram.addrmap[test_desc_addr * 1024][8 * i + 6] = test_buf_addr * 2 * 4 // 256 % 256
        tb.rx_sram.addrmap[test_desc_addr * 1024][8 * i + 7] = test_buf_addr * 2 * 4 // 256 // 256 % 256
    tb.rx_sram.addrmap[test_desc_addr * 1024][8 * 127 + 3] = 160

    rdsr:int = test_desc_addr * 1024
    await tb.axis_cfg.write(0x180, rdsr.to_bytes(length=4, byteorder='little', signed=False), awid = 0x30, size = 0x2, cache = 0x0, prot = 0x0)

    rcr:int = 8
    await tb.axis_cfg.write(0x84, rcr.to_bytes(length=4, byteorder='little', signed=False), awid = 0x30, size = 0x2, cache = 0x0, prot = 0x0)

    ecr:int = 0x5EE * 256 * 256 + 0xB
    await tb.axis_cfg.write(0x24, ecr.to_bytes(length=4, byteorder='little', signed=False), awid = 0x30, size = 0x2, cache = 0x0, prot = 0x0)

    await tb.axis_cfg.write(0x10, (0).to_bytes(length=4, byteorder='little', signed=False), awid = 0x30, size = 0x2, cache = 0x0, prot = 0x0)

    await Timer(1000 * (100e6 // speed), units="ns")

    for i, x in enumerate(payload_lengths()):
        event = Event()
        frame = payload_data(x)
        # 1. 解析帧结构
        dst_mac = frame[0:6]
        src_mac = frame[6:12]
        payload_and_fcs = frame[14:]
        
        # 2. 确定原始长度/类型字段的值
        new_value = 0x8100
        
        # 4. 创建新的长度/类型字段
        new_length_type = struct.pack('>H', new_value)
        
        # 5. 组装新的帧（不包括FCS）
        # 注意：payload_and_fcs包含了原始负载和FCS，我们需要去掉原始FCS
        original_payload = payload_and_fcs[:-4]
        new_frame_without_fcs = dst_mac + src_mac + new_length_type + original_payload
        
        # 6. 计算新的CRC32
        new_crc = zlib.crc32(new_frame_without_fcs) & 0xFFFFFFFF
        new_fcs = struct.pack('<I', new_crc)
        
        # 7. 组装完整的修改后的帧
        test_data = new_frame_without_fcs + new_fcs
        test_frame = GmiiFrame.from_raw_payload(test_data, tx_complete = event)
        await tb.mii_phy.rx.send(test_frame)
        await event.wait()
        await Timer(len(test_data) * 20 * (100e6 // speed), units="ns")
        assert tb.rx_sram.addrmap[test_buf_list[i] * 1024][0:len(test_data)] == test_data
        assert tb.rx_sram.addrmap[test_desc_addr * 1024][8 * i + 0] == (len(test_data)) % 256
        assert tb.rx_sram.addrmap[test_desc_addr * 1024][8 * i + 1] == (len(test_data)) // 256 % 256
        assert (tb.rx_sram.addrmap[test_desc_addr * 1024][8 * i + 3] & (0x1 << 6)) == (0x1 << 6)

    await RisingEdge(dut.enet_rx_clk)
    await RisingEdge(dut.enet_rx_clk)

    logging.disable(logging.DEBUG)

async def run_test_rx_error_er(dut, payload_lengths=None, payload_data=None, ifg=12, speed=1000e6):

    logging.disable(logging.INFO)

    tb = TB(dut, speed)

    tb.mii_phy.rx.ifg = ifg

    tb.set_speed(speed)

    await tb.reset()

    for k in range(100):
        await RisingEdge(dut.enet_rx_clk)

    test_max_num = 2 ** 22
    test_desc_addr = random.getrandbits(22)
    assert test_desc_addr < test_max_num
    test_desc = bytearray(b'\x00' * 1024)
    tb.rx_sram.add_memory_block(test_desc_addr * 1024, test_desc)
    test_buf_list = []
    for i in range(128):
        test_buf_addr = random.getrandbits(21)
        assert test_buf_addr * 2 < test_max_num
        while test_buf_addr * 2 * 1024 in tb.rx_sram.addrmap:
            test_buf_addr = random.getrandbits(21)
            assert test_buf_addr * 2 < test_max_num
        test_buf = bytearray(b'\x00' * 2048)
        tb.rx_sram.add_memory_block(test_buf_addr * 2 * 1024, test_buf)
        test_buf_list.append(test_buf_addr * 2)
        tb.rx_sram.addrmap[test_desc_addr * 1024][8 * i + 0] = 0
        tb.rx_sram.addrmap[test_desc_addr * 1024][8 * i + 1] = 0
        tb.rx_sram.addrmap[test_desc_addr * 1024][8 * i + 2] = 0
        tb.rx_sram.addrmap[test_desc_addr * 1024][8 * i + 3] = 128
        tb.rx_sram.addrmap[test_desc_addr * 1024][8 * i + 4] = 0
        tb.rx_sram.addrmap[test_desc_addr * 1024][8 * i + 5] = test_buf_addr * 2 * 4 % 256
        tb.rx_sram.addrmap[test_desc_addr * 1024][8 * i + 6] = test_buf_addr * 2 * 4 // 256 % 256
        tb.rx_sram.addrmap[test_desc_addr * 1024][8 * i + 7] = test_buf_addr * 2 * 4 // 256 // 256 % 256
    tb.rx_sram.addrmap[test_desc_addr * 1024][8 * 127 + 3] = 160

    rdsr:int = test_desc_addr * 1024
    await tb.axis_cfg.write(0x180, rdsr.to_bytes(length=4, byteorder='little', signed=False), awid = 0x30, size = 0x2, cache = 0x0, prot = 0x0)

    rcr:int = 8
    await tb.axis_cfg.write(0x84, rcr.to_bytes(length=4, byteorder='little', signed=False), awid = 0x30, size = 0x2, cache = 0x0, prot = 0x0)

    ecr:int = 0x5EE * 256 * 256 + 0xB
    await tb.axis_cfg.write(0x24, ecr.to_bytes(length=4, byteorder='little', signed=False), awid = 0x30, size = 0x2, cache = 0x0, prot = 0x0)

    await tb.axis_cfg.write(0x10, (0).to_bytes(length=4, byteorder='little', signed=False), awid = 0x30, size = 0x2, cache = 0x0, prot = 0x0)

    await Timer(1000 * (100e6 // speed), units="ns")

    for i,x in enumerate(payload_lengths()):
        event = Event()
        test_data = payload_data(x)
        test_frame = GmiiFrame.from_raw_payload(test_data, tx_complete = event)
        optaretion = random.randint(0,1)
        if optaretion == 0:# er signal error frame
            test_frame.error = (([0] * (len(test_data) - 2)) + ([1] * 2))
            await tb.mii_phy.rx.send(test_frame)
            await event.wait()
            await Timer(len(test_data) * 20 * (100e6 // speed), units="ns")
            assert (tb.rx_sram.addrmap[test_desc_addr * 1024][8 * i + 3] & 0x10) == 0x10
        else:# normal frame
            await tb.mii_phy.rx.send(test_frame)
            await event.wait()
            await Timer(len(test_data) * 20 * (100e6 // speed), units="ns")
            assert tb.rx_sram.addrmap[test_buf_list[i] * 1024][0:len(test_data)] == test_data
            assert tb.rx_sram.addrmap[test_desc_addr * 1024][8 * i + 0] == (max(x, 46) + 18) % 256
            assert tb.rx_sram.addrmap[test_desc_addr * 1024][8 * i + 1] == (max(x, 46) + 18) // 256 % 256

    await RisingEdge(dut.enet_rx_clk)
    await RisingEdge(dut.enet_rx_clk)

    logging.disable(logging.DEBUG)

async def run_test_rx_error_crc(dut, payload_lengths=None, payload_data=None, ifg=12, speed=1000e6):

    logging.disable(logging.INFO)

    tb = TB(dut, speed)

    tb.mii_phy.rx.ifg = ifg

    tb.set_speed(speed)

    await tb.reset()

    for k in range(100):
        await RisingEdge(dut.enet_rx_clk)

    test_max_num = 2 ** 22
    test_desc_addr = random.getrandbits(22)
    assert test_desc_addr < test_max_num
    test_desc = bytearray(b'\x00' * 1024)
    tb.rx_sram.add_memory_block(test_desc_addr * 1024, test_desc)
    test_buf_list = []
    for i in range(128):
        test_buf_addr = random.getrandbits(21)
        assert test_buf_addr * 2 < test_max_num
        while test_buf_addr * 2 * 1024 in tb.rx_sram.addrmap:
            test_buf_addr = random.getrandbits(21)
            assert test_buf_addr * 2 < test_max_num
        test_buf = bytearray(b'\x00' * 2048)
        tb.rx_sram.add_memory_block(test_buf_addr * 2 * 1024, test_buf)
        test_buf_list.append(test_buf_addr * 2)
        tb.rx_sram.addrmap[test_desc_addr * 1024][8 * i + 0] = 0
        tb.rx_sram.addrmap[test_desc_addr * 1024][8 * i + 1] = 0
        tb.rx_sram.addrmap[test_desc_addr * 1024][8 * i + 2] = 0
        tb.rx_sram.addrmap[test_desc_addr * 1024][8 * i + 3] = 128
        tb.rx_sram.addrmap[test_desc_addr * 1024][8 * i + 4] = 0
        tb.rx_sram.addrmap[test_desc_addr * 1024][8 * i + 5] = test_buf_addr * 2 * 4 % 256
        tb.rx_sram.addrmap[test_desc_addr * 1024][8 * i + 6] = test_buf_addr * 2 * 4 // 256 % 256
        tb.rx_sram.addrmap[test_desc_addr * 1024][8 * i + 7] = test_buf_addr * 2 * 4 // 256 // 256 % 256
    tb.rx_sram.addrmap[test_desc_addr * 1024][8 * 127 + 3] = 160

    rdsr:int = test_desc_addr * 1024
    await tb.axis_cfg.write(0x180, rdsr.to_bytes(length=4, byteorder='little', signed=False), awid = 0x30, size = 0x2, cache = 0x0, prot = 0x0)

    rcr:int = 8
    await tb.axis_cfg.write(0x84, rcr.to_bytes(length=4, byteorder='little', signed=False), awid = 0x30, size = 0x2, cache = 0x0, prot = 0x0)

    ecr:int = 0x5EE * 256 * 256 + 0xB
    await tb.axis_cfg.write(0x24, ecr.to_bytes(length=4, byteorder='little', signed=False), awid = 0x30, size = 0x2, cache = 0x0, prot = 0x0)

    await tb.axis_cfg.write(0x10, (0).to_bytes(length=4, byteorder='little', signed=False), awid = 0x30, size = 0x2, cache = 0x0, prot = 0x0)

    await Timer(1000 * (100e6 // speed), units="ns")

    for i, x in enumerate(payload_lengths()):
        event = Event()
        frame = payload_data(x)
        optaretion = random.randint(0,1)
        if optaretion == 0:# crc error frame
            # 1. 解析帧结构
            dst_mac = frame[0:6]
            src_mac = frame[6:12]
            payload_and_fcs = frame[14:]
            
            # 2. 确定原始长度/类型字段的值
            new_value = 0x8100
            
            # 4. 创建新的长度/类型字段
            new_length_type = struct.pack('>H', new_value)
            
            # 5. 组装新的帧（不包括FCS）
            # 注意：payload_and_fcs包含了原始负载和FCS，我们需要去掉原始FCS
            original_payload = payload_and_fcs[:-4]
            new_frame_without_fcs = dst_mac + src_mac + new_length_type + original_payload
            
            # 6. 计算新的CRC32
            new_crc = zlib.crc32(new_frame_without_fcs) & 0xFFFFFFFF
            new_crc = ~new_crc & 0xFFFFFFFF #生成错误crc
            new_fcs = struct.pack('<I', new_crc)
            
            # 7. 组装完整的修改后的帧
            test_data = new_frame_without_fcs + new_fcs
            test_frame = GmiiFrame.from_raw_payload(test_data, tx_complete = event)
            await tb.mii_phy.rx.send(test_frame)
            await event.wait()
            await Timer(len(test_data) * 20 * (100e6 // speed), units="ns")
            assert (tb.rx_sram.addrmap[test_desc_addr * 1024][8 * i + 2] & (0x1 << 2)) == (0x1 << 2)
        else:# normal frame
            test_frame = GmiiFrame.from_raw_payload(frame, tx_complete = event)
            await tb.mii_phy.rx.send(test_frame)
            await event.wait()
            await Timer(len(frame) * 20 * (100e6 // speed), units="ns")
            assert tb.rx_sram.addrmap[test_buf_list[i] * 1024][0:len(frame)] == frame
            assert tb.rx_sram.addrmap[test_desc_addr * 1024][8 * i + 0] == (max(x, 46) + 18) % 256
            assert tb.rx_sram.addrmap[test_desc_addr * 1024][8 * i + 1] == (max(x, 46) + 18) // 256 % 256

    await RisingEdge(dut.enet_rx_clk)
    await RisingEdge(dut.enet_rx_clk)

    logging.disable(logging.DEBUG)

async def run_test_rx_error_no(dut, payload_lengths=None, payload_data=None, ifg=12, speed=1000e6):

    logging.disable(logging.INFO)

    cocotb.start_soon(Clock(dut.clk, 20, units="ns").start())

    mii_phy = MiiPhy_my(
        dut.enet_txd,
        dut.enet_tx_er,
        dut.enet_tx_en,
        dut.enet_tx_clk,
        dut.enet_rxd,
        dut.enet_rx_er,
        dut.enet_rx_dv,
        dut.enet_rx_clk,
        speed=speed,
    )

    tx_sram = SRAM_target("tx_sram")
    rx_sram = SRAM_target("rx_sram")

    axis_cfg = AxiMaster(AxiBus.from_prefix(dut, "mst"), dut.clk, dut.rst_n, reset_active_level=False)
    axis_tx_dma = AxiSlave(AxiBus.from_prefix(dut, "slv_tx"), dut.tx_clk, dut.tx_rst_n, target = tx_sram, reset_active_level=False)
    axis_rx_dma = AxiSlave(AxiBus.from_prefix(dut, "slv_rx"), dut.rx_clk, dut.rx_rst_n, target = rx_sram, reset_active_level=False)

    mii_phy.rx.ifg = ifg

    dut.enet_rst_n.setimmediatevalue(0)
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.enet_rst_n.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.enet_rst_n.value = 1
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)

    for k in range(100):
        await RisingEdge(dut.enet_rx_clk)

    test_max_num = 2 ** 22
    test_desc_addr = random.getrandbits(22)
    assert test_desc_addr < test_max_num
    test_desc = bytearray(b'\x00' * 1024)
    rx_sram.add_memory_block(test_desc_addr * 1024, test_desc)
    test_buf_list = []
    for i in range(128):
        test_buf_addr = random.getrandbits(21)
        assert test_buf_addr * 2 < test_max_num
        while test_buf_addr * 2 * 1024 in rx_sram.addrmap:
            test_buf_addr = random.getrandbits(21)
            assert test_buf_addr * 2 < test_max_num
        test_buf = bytearray(b'\x00' * 2048)
        rx_sram.add_memory_block(test_buf_addr * 2 * 1024, test_buf)
        test_buf_list.append(test_buf_addr * 2)
        rx_sram.addrmap[test_desc_addr * 1024][8 * i + 0] = 0
        rx_sram.addrmap[test_desc_addr * 1024][8 * i + 1] = 0
        rx_sram.addrmap[test_desc_addr * 1024][8 * i + 2] = 0
        rx_sram.addrmap[test_desc_addr * 1024][8 * i + 3] = 128
        rx_sram.addrmap[test_desc_addr * 1024][8 * i + 4] = 0
        rx_sram.addrmap[test_desc_addr * 1024][8 * i + 5] = test_buf_addr * 2 * 4 % 256
        rx_sram.addrmap[test_desc_addr * 1024][8 * i + 6] = test_buf_addr * 2 * 4 // 256 % 256
        rx_sram.addrmap[test_desc_addr * 1024][8 * i + 7] = test_buf_addr * 2 * 4 // 256 // 256 % 256
    rx_sram.addrmap[test_desc_addr * 1024][8 * 127 + 3] = 160

    rdsr:int = test_desc_addr * 1024
    await axis_cfg.write(0x180, rdsr.to_bytes(length=4, byteorder='little', signed=False), awid = 0x30, size = 0x2, cache = 0x0, prot = 0x0)

    rcr:int = 8
    await axis_cfg.write(0x84, rcr.to_bytes(length=4, byteorder='little', signed=False), awid = 0x30, size = 0x2, cache = 0x0, prot = 0x0)

    ecr:int = 0x7EE * 256 * 256 + 0xB
    await axis_cfg.write(0x24, ecr.to_bytes(length=4, byteorder='little', signed=False), awid = 0x30, size = 0x2, cache = 0x0, prot = 0x0)

    await axis_cfg.write(0x10, (0).to_bytes(length=4, byteorder='little', signed=False), awid = 0x30, size = 0x2, cache = 0x0, prot = 0x0)

    await Timer(1000 * (100e6 // speed), units="ns")

    for i, x in enumerate(payload_lengths()):
        event = Event()
        frame = payload_data(x)
        optaretion = random.randint(0,1)
        if optaretion == 0:# no error frame
            mii_phy.rx.set_no_mode(True)
            test_frame = GmiiFrame.from_raw_payload(frame, tx_complete = event)
            await mii_phy.rx.send(test_frame)
            await event.wait()
            await Timer(len(frame) * 20 * (100e6 // speed), units="ns")
            assert (rx_sram.addrmap[test_desc_addr * 1024][8 * i + 2] & (0x1 << 4)) == (0x1 << 4)
        else:# normal frame
            mii_phy.rx.set_no_mode(False)
            test_frame = GmiiFrame.from_raw_payload(frame, tx_complete = event)
            await mii_phy.rx.send(test_frame)
            await event.wait()
            await Timer(len(frame) * 20 * (100e6 // speed), units="ns")
            assert rx_sram.addrmap[test_buf_list[i] * 1024][0:len(frame)] == frame
            assert rx_sram.addrmap[test_desc_addr * 1024][8 * i + 0] == (max(x, 46) + 18) % 256
            assert rx_sram.addrmap[test_desc_addr * 1024][8 * i + 1] == (max(x, 46) + 18) // 256 % 256

    await RisingEdge(dut.enet_rx_clk)
    await RisingEdge(dut.enet_rx_clk)

    logging.disable(logging.DEBUG)

def size_list():
    return list(range(60, 128)) + [512, 1500] + [60]*10

def incrementing_payload(length, dst_mac: Optional[bytes] = None, use_mac:bool = False, mac_addr:bytes = None, use_8023: bool = False):

    if use_8023:
        # IEEE 802.3标准 - 长度字段
        # 最大长度限制为1500 (0x05DC)
        if length > 1500:
            actual_size = 1500
            print(f"警告: IEEE 802.3负载大小限制为1500字节，已截断为1500字节 {length =}")
        else:
            actual_size = length
        
        # 长度字段为2字节大端序
        length_type = struct.pack('>H', actual_size)
        
        # IEEE 802.3要求最小帧为64字节（包括14字节头部和4字节FCS）
        min_payload = 46  # 64 - 14 - 4 = 46字节
    else:
        # 以太网II标准 - 类型字段
        length_type = b'\x08\x00'  # 0x0800 = IPv4
        actual_size = length
        min_payload = 46  # 同样要求最小帧大小

    if dst_mac is None:
        dst_mac = bytearray(itertools.islice(itertools.cycle(range(256)), 6))

    if use_mac:
        frame_mac = dst_mac + mac_addr
    else:
        frame_mac = dst_mac + bytearray(itertools.islice(itertools.cycle(range(256)), 6))

    padding = b''
    if actual_size < min_payload:
        padding = os.urandom(min_payload - actual_size)

    frame_without_fcs = frame_mac + length_type + bytearray(itertools.islice(itertools.cycle(range(256)), actual_size)) + padding 

    fcs = struct.pack('<L', zlib.crc32(frame_without_fcs))
    ethernet_frame = frame_without_fcs + fcs
    return ethernet_frame

def generate_ethernet_frame(payload_size: int, dst_mac: Optional[bytes] = None, use_mac:bool = False, mac_addr:bytes = None, use_8023: bool = False) -> bytes:
    """
    生成完整的以太网帧，支持以太网II和IEEE 802.3标准
    
    参数:
        payload_size: 数据负载部分的字节大小
        use_8023: 如果为True，使用IEEE 802.3标准（长度字段代替类型字段）
    
    返回:
        tuple: (以太网帧字节数据, 源MAC地址字符串)
    """
    # 1. 生成随机MAC地址 (源和目的)
    if dst_mac is None:
        dst_mac = generate_mac()  # 目的MAC地址
    if use_mac:
        src_mac = mac_addr
    else:
        src_mac = generate_mac()  # 源MAC地址

    # 2. 处理以太网类型/长度字段
    if use_8023:
        # IEEE 802.3标准 - 长度字段
        # 最大长度限制为1500 (0x05DC)
        if payload_size > 1500:
            actual_size = 1500
            print(f"警告: IEEE 802.3负载大小限制为1500字节，已截断为1500字节 {payload_size =}")
        else:
            actual_size = payload_size
        
        # 长度字段为2字节大端序
        length_type = struct.pack('>H', actual_size)
        
        # IEEE 802.3要求最小帧为64字节（包括14字节头部和4字节FCS）
        min_payload = 46  # 64 - 14 - 4 = 46字节
    else:
        # 以太网II标准 - 类型字段
        length_type = b'\x08\x00'  # 0x0800 = IPv4
        actual_size = payload_size
        min_payload = 46  # 同样要求最小帧大小
    
    # 3. 生成数据负载 (随机内容)
    payload = os.urandom(actual_size)
    
    # 4. 添加零填充以满足最小帧要求
    padding = b''
    if actual_size < min_payload:
        padding = os.urandom(min_payload - actual_size)
    
    # 5. 组装帧 (不包括FCS)
    frame_without_fcs = dst_mac + src_mac + length_type + payload + padding
    
    # 6. 计算CRC32帧校验序列ethernet_frame
    fcs = struct.pack('<L', zlib.crc32(frame_without_fcs))
    
    # 7. 完整的以太网帧
    ethernet_frame = frame_without_fcs + fcs
    
    return ethernet_frame

if cocotb.SIM_NAME:

    factory = TestFactory(run_test_rx)
    factory.add_option("crcfwd", [True, False])
    factory.add_option("send_through", [True, False])
    factory.add_option("payload_lengths", [size_list])
    factory.add_option("payload_data", [incrementing_payload, generate_ethernet_frame])
    factory.add_option("ifg", [12])
    factory.add_option("speed", [10e6, 100e6])
    factory.generate_tests()

    factory = TestFactory(run_test_tx)
    factory.add_option("crcfwd", [True, False])
    factory.add_option("tc", [True, False])
    factory.add_option("addins", [True, False])
    factory.add_option("strfwd", [True, False])
    factory.add_option("payload_lengths", [size_list])
    factory.add_option("payload_data", [incrementing_payload, generate_ethernet_frame])
    factory.add_option("ifg", [12])
    factory.add_option("speed", [10e6, 100e6])
    factory.generate_tests()

    factory = TestFactory(run_test_rx_paden)
    factory.add_option("use_8023", [True, False])
    factory.add_option("payload_lengths", [size_list])
    factory.add_option("payload_data", [incrementing_payload, generate_ethernet_frame])
    factory.add_option("ifg", [12])
    factory.add_option("speed", [10e6, 100e6])
    factory.generate_tests()

    factory = TestFactory(run_test_rx_cast)
    factory.add_option("bc_rej", [True, False])
    factory.add_option("payload_lengths", [size_list])
    factory.add_option("payload_data", [incrementing_payload, generate_ethernet_frame])
    factory.add_option("ifg", [12])
    factory.add_option("speed", [10e6, 100e6])
    factory.generate_tests()

    for test in [run_test_tx_pause, run_test_rpc_pause, run_test_payload_pad]:
        factory = TestFactory(test)
        factory.add_option("ifg", [12])
        factory.add_option("speed", [10e6, 100e6])
        factory.generate_tests()

    factory = TestFactory(run_test_rx_pausefwd)
    factory.add_option("pausefwd", [True, False])
    factory.add_option("ifg", [12])
    factory.add_option("speed", [10e6, 100e6])
    factory.generate_tests()

    factory = TestFactory(run_test_rx_lencheck)
    factory.add_option("lencheck", [True, False])
    factory.add_option("payload_lengths", [size_list])
    factory.add_option("payload_data", [incrementing_payload, generate_ethernet_frame])
    factory.add_option("ifg", [12])
    factory.add_option("speed", [10e6, 100e6])
    factory.generate_tests()

    for test in [run_test_rx_coalesce, run_test_tx_coalesce]:
        factory = TestFactory(test)
        factory.add_option("func", ["time", 'number'])
        factory.add_option("payload_lengths", [size_list])
        factory.add_option("payload_data", [incrementing_payload, generate_ethernet_frame])
        factory.add_option("ifg", [12])
        factory.add_option("speed", [10e6, 100e6])
        factory.generate_tests()

    factory = TestFactory(run_test_tx_sgdma)
    factory.add_option("strfwd", [True, False])
    factory.add_option("payload_data", [incrementing_payload, generate_ethernet_frame])
    factory.add_option("ifg", [12])
    factory.add_option("speed", [10e6, 100e6])
    factory.generate_tests()

    for test in [run_test_tx_warp, run_test_rx_warp, run_test_rx_error_toolong, run_test_rx_error_babr, run_test_tx_error_babt, run_test_rx_error_fifo_protect, run_test_rx_pause_gen]:
        factory = TestFactory(test)
        factory.add_option("payload_data", [incrementing_payload, generate_ethernet_frame])
        factory.add_option("ifg", [12])
        factory.add_option("speed", [10e6, 100e6])
        factory.generate_tests()

    for test in [run_test_tx_stop, run_test_tx_underrun, run_test_rx_vlan, run_test_rx_error_er, run_test_rx_error_crc, run_test_rx_error_no]:
        factory = TestFactory(test)
        factory.add_option("payload_lengths", [size_list])
        factory.add_option("payload_data", [generate_ethernet_frame])
        factory.add_option("ifg", [12])
        factory.add_option("speed", [100e6])
        factory.generate_tests()


# cocotb-test

tests_dir = os.path.abspath(os.path.dirname(__file__))
rtl_dir = os.path.abspath(os.path.join(tests_dir, "..", "..", "rtl"))


def test_eth_mac_mii(request):
    dut = "enet_core"
    module = os.path.splitext(os.path.basename(__file__))[0]
    toplevel = dut

    verilog_sources = [
        os.path.join(rtl_dir, "enet_rx_dma.v"),
        os.path.join(rtl_dir, "enet_rmii_to_mii.v"),
        os.path.join(rtl_dir, "enet_tx_dma.v"),
        os.path.join(rtl_dir, "enet_chclk.v"),
        os.path.join(rtl_dir, "mac_tx.v"),
        os.path.join(rtl_dir, "net_fifo.v"),
        os.path.join(rtl_dir, "enet_rgmii_to_gmii_xlinx.v"),
        os.path.join(rtl_dir, "enet_intr_coalesce.v"),
        os.path.join(rtl_dir, "enet_normal_reg_tx.v"),
        os.path.join(rtl_dir, "enet_axi2reg.v"),
        os.path.join(rtl_dir, "mac_rx.v"),
        os.path.join(rtl_dir, "enet_rgmii_to_gmii_tx_xlinx.v"),
        os.path.join(rtl_dir, "enet_rmii_to_mii_tx.v"),
        os.path.join(rtl_dir, "enet_chclk_path.v"),
        os.path.join(rtl_dir, "enet_rmii_to_mii_rx.v"),
        os.path.join(rtl_dir, "enet_normal_reg_rx.v"),
        os.path.join(rtl_dir, "enet_rcr.v"),
        os.path.join(rtl_dir, "mdio_if.v"),
        os.path.join(rtl_dir, "enet_rgmii_to_gmii_dummy.v"),
        os.path.join(rtl_dir, "gmii_rx.v"),
        os.path.join(rtl_dir, "enet_core.v"),
        os.path.join(rtl_dir, "gmii_tx.v"),
        os.path.join(rtl_dir, "enet_ecr.v"),
        os.path.join(rtl_dir, "enet_rgmii_to_gmii_rx_xlinx.v"),
        os.path.join(rtl_dir, "enet_tcr.v"),
        os.path.join(rtl_dir, "enet_normal_reg.v"),
        os.path.join(rtl_dir, "crc32.v"),
        os.path.join(rtl_dir, "enet_rgmii_to_gmii.v"),
    ]

    sim_build = os.path.join(
        tests_dir, "sim_build", request.node.name.replace("[", "-").replace("]", "")
    )

    cocotb_test.simulator.run(
        python_search=[tests_dir],
        verilog_sources=verilog_sources,
        toplevel=toplevel,
        module=module,
        sim_build=sim_build,
    )
