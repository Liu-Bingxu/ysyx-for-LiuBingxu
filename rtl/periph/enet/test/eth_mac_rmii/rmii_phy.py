import logging, random

import cocotb
from cocotb.queue import Queue, QueueFull
from cocotb.triggers import Timer, First, Event
from cocotb.triggers import RisingEdge, FallingEdge
from cocotb.utils import get_sim_time, get_sim_steps

from cocotbext.eth import GmiiFrame

import enum

__version__ = "1.0"

# Ethernet frame
class EthPre(enum.IntEnum):
    PRE = 0x55
    SFD = 0xD5

class Reset:
    def _init_reset(self, reset_signal=None, active_level=True):
        self._local_reset = False
        self._ext_reset = False
        self._reset_state = True

        if reset_signal is not None:
            cocotb.start_soon(self._run_reset(reset_signal, bool(active_level)))

        self._update_reset()

    def assert_reset(self, val=None):
        if val is None:
            self.assert_reset(True)
            self.assert_reset(False)
        else:
            self._local_reset = bool(val)
            self._update_reset()

    def _update_reset(self):
        new_state = self._local_reset or self._ext_reset
        if self._reset_state != new_state:
            self._reset_state = new_state
            self._handle_reset(new_state)

    def _handle_reset(self, state):
        pass

    async def _run_reset(self, reset_signal, active_level):
        while True:
            if bool(reset_signal.value):
                await FallingEdge(reset_signal)
                self._ext_reset = not active_level
                self._update_reset()
            else:
                await RisingEdge(reset_signal)
                self._ext_reset = active_level
                self._update_reset()


class RMiiSource(Reset):

    def __init__(self, data, er, dv, clock, reset=None, enable=None, reset_active_level=True, *args, **kwargs):
        self.log = logging.getLogger(f"cocotb.{data._path}")
        self.data = data
        self.er = er
        self.dv = dv
        self.clock = clock
        self.reset = reset
        self.enable = enable

        self.log.info("RMII source")
        self.log.info("cocotbext-eth-rmii version %s", __version__)
        self.log.info("Copyright (c) 2026 LiuBingxu")

        super().__init__(*args, **kwargs)

        self.active = False
        self.queue = Queue()
        self.dequeue_event = Event()
        self.current_frame = None
        self.idle_event = Event()
        self.idle_event.set()
        self.active_event = Event()

        self.ifg = 12

        self.queue_occupancy_bytes = 0
        self.queue_occupancy_frames = 0

        self.queue_occupancy_limit_bytes = -1
        self.queue_occupancy_limit_frames = -1

        self.width = 2
        self.byte_width = 1

        assert len(self.data) == 2
        self.data.setimmediatevalue(0)
        if self.er is not None:
            assert len(self.er) == 1
            self.er.setimmediatevalue(0)
        assert len(self.dv) == 1
        self.dv.setimmediatevalue(0)

        self._run_cr = None

        self._init_reset(reset, reset_active_level)

    def set_speed(self, speed):
        if speed in (10e6, 100e6):
            self.speed = speed
        else:
            raise ValueError("Invalid speed selection")
        
    def set_no_mode(self, no_mode:bool = False):
        self.no_mode = no_mode

    async def send(self, frame):
        while self.full():
            self.dequeue_event.clear()
            await self.dequeue_event.wait()
        frame = GmiiFrame(frame)
        await self.queue.put(frame)
        self.idle_event.clear()
        self.active_event.set()
        self.queue_occupancy_bytes += len(frame)
        self.queue_occupancy_frames += 1

    def send_nowait(self, frame):
        if self.full():
            raise QueueFull()
        frame = GmiiFrame(frame)
        self.queue.put_nowait(frame)
        self.idle_event.clear()
        self.active_event.set()
        self.queue_occupancy_bytes += len(frame)
        self.queue_occupancy_frames += 1

    def count(self):
        return self.queue.qsize()

    def empty(self):
        return self.queue.empty()

    def full(self):
        if self.queue_occupancy_limit_bytes > 0 and self.queue_occupancy_bytes > self.queue_occupancy_limit_bytes:
            return True
        elif self.queue_occupancy_limit_frames > 0 and self.queue_occupancy_frames > self.queue_occupancy_limit_frames:
            return True
        else:
            return False

    def idle(self):
        return self.empty() and not self.active

    def clear(self):
        while not self.queue.empty():
            frame = self.queue.get_nowait()
            frame.sim_time_end = None
            frame.handle_tx_complete()
        self.dequeue_event.set()
        self.idle_event.set()
        self.active_event.clear()
        self.queue_occupancy_bytes = 0
        self.queue_occupancy_frames = 0

    async def wait(self):
        await self.idle_event.wait()

    def _handle_reset(self, state):
        if state:
            self.log.info("Reset asserted")
            if self._run_cr is not None:
                self._run_cr.kill()
                self._run_cr = None

            self.active = False
            self.data.value = 0
            if self.er is not None:
                self.er.value = 0
            self.dv.value = 0

            if self.current_frame:
                self.log.warning("Flushed transmit frame during reset: %s", self.current_frame)
                self.current_frame.handle_tx_complete()
                self.current_frame = None

            if self.queue.empty():
                self.idle_event.set()
                self.active_event.clear()
        else:
            self.log.info("Reset de-asserted")
            if self._run_cr is None:
                self._run_cr = cocotb.start_soon(self._run())

    async def _run(self):
        frame = None
        frame_offset = 0
        frame_data = None
        frame_error = None
        ifg_cnt = 0
        self.active = False

        clock_edge_event = RisingEdge(self.clock)

        enable_event = None
        if self.enable is not None:
            enable_event = RisingEdge(self.enable)

        while True:
            await clock_edge_event

            if self.enable is None or self.enable.value:
                if ifg_cnt > 0:
                    # in IFG
                    ifg_cnt -= 1

                elif frame is None and not self.queue.empty():
                    # send frame
                    frame = self.queue.get_nowait()
                    self.dequeue_event.set()
                    self.queue_occupancy_bytes -= len(frame)
                    self.queue_occupancy_frames -= 1
                    self.current_frame = frame
                    frame.sim_time_start = get_sim_time()
                    frame.sim_time_sfd = None
                    frame.sim_time_end = None
                    self.log.info("TX frame: %s", frame)
                    frame.normalize()

                    # convert to RMII
                    frame_data = []
                    frame_error = []
                    sel = random.randint(30, (len(frame.data) - 1))
                    for i, [b, e] in enumerate(zip(frame.data, frame.error)):
                        if (self.no_mode == True) and (i == sel):
                            frame_data.append(b & 0x03)
                            frame_data.append((b >> 2) & 0x03)
                            frame_error.append(e)
                            frame_error.append(e)
                            break
                        else:
                            frame_data.append((b >> 0) & 0x03)
                            frame_data.append((b >> 2) & 0x03)
                            frame_data.append((b >> 4) & 0x03)
                            frame_data.append(b >> 6)
                            frame_error.append(e)
                            frame_error.append(e)
                            frame_error.append(e)
                            frame_error.append(e)

                    self.active = True
                    frame_offset = 0

                    self.sel = random.randint(9, len(frame.data) - 10) * 4
                    self.cnt = 0

                if frame is not None:
                    d = frame_data[frame_offset]
                    if frame.sim_time_sfd is None and d == 0x3:
                        frame.sim_time_sfd = get_sim_time()
                    self.data.value = d
                    if self.er is not None:
                        self.er.value = frame_error[frame_offset]
                        if frame_error[frame_offset] == 1:
                            self.data.value = 1

                    self.cnt += 1
                    if (self.cnt >= self.sel) and (self.cnt % 2 == 1):
                        self.dv.value = 0
                    else:
                        self.dv.value = 1
                    frame_offset += 1

                    if self.speed == 10e6:
                        for _ in range(9):
                            await clock_edge_event

                    if frame_offset >= len(frame_data):
                        ifg_cnt = max(self.ifg, 1)
                        frame.sim_time_end = get_sim_time()
                        frame.handle_tx_complete()
                        frame = None
                        self.current_frame = None
                else:
                    self.data.value = 0
                    if self.er is not None:
                        self.er.value = 0
                    self.dv.value = 0
                    self.active = False

                    if ifg_cnt == 0 and self.queue.empty():
                        self.idle_event.set()
                        self.active_event.clear()
                        await self.active_event.wait()

            elif self.enable is not None and not self.enable.value:
                await enable_event


class RMiiSink(Reset):

    def __init__(self, data, er, dv, clock, reset=None, enable=None, reset_active_level=True, *args, **kwargs):
        self.log = logging.getLogger(f"cocotb.{data._path}")
        self.data = data
        self.er = er
        self.dv = dv
        self.clock = clock
        self.reset = reset
        self.enable = enable

        self.log.info("RMII sink")
        self.log.info("cocotbext-eth-rmii version %s", __version__)
        self.log.info("Copyright (c) 2026 LiuBingxu")

        super().__init__(*args, **kwargs)

        self.active = False
        self.queue = Queue()
        self.active_event = Event()

        self.queue_occupancy_bytes = 0
        self.queue_occupancy_frames = 0

        self.width = 2
        self.byte_width = 1

        assert len(self.data) == 2
        if self.er is not None:
            assert len(self.er) == 1
        if self.dv is not None:
            assert len(self.dv) == 1

        self._run_cr = None

        self._init_reset(reset, reset_active_level)

    def set_speed(self, speed):
        if speed in (10e6, 100e6):
            self.speed = speed
        else:
            raise ValueError("Invalid speed selection")

    def _recv(self, frame, compact=True):
        if self.queue.empty():
            self.active_event.clear()
        self.queue_occupancy_bytes -= len(frame)
        self.queue_occupancy_frames -= 1
        if compact:
            frame.compact()
        return frame

    async def recv(self, compact=True):
        frame = await self.queue.get()
        return self._recv(frame, compact)

    def recv_nowait(self, compact=True):
        frame = self.queue.get_nowait()
        return self._recv(frame, compact)

    def count(self):
        return self.queue.qsize()

    def empty(self):
        return self.queue.empty()

    def idle(self):
        return not self.active

    def clear(self):
        while not self.queue.empty():
            self.queue.get_nowait()
        self.active_event.clear()
        self.queue_occupancy_bytes = 0
        self.queue_occupancy_frames = 0

    async def wait(self, timeout=0, timeout_unit=None):
        if not self.empty():
            return
        if timeout:
            await First(self.active_event.wait(), Timer(timeout, timeout_unit))
        else:
            await self.active_event.wait()

    def _handle_reset(self, state):
        if state:
            self.log.info("Reset asserted")
            if self._run_cr is not None:
                self._run_cr.kill()
                self._run_cr = None

            self.active = False
        else:
            self.log.info("Reset de-asserted")
            if self._run_cr is None:
                self._run_cr = cocotb.start_soon(self._run())

    async def _run(self):
        frame = None
        self.active = False

        clock_edge_event = RisingEdge(self.clock)

        active_event = RisingEdge(self.dv)

        enable_event = None
        if self.enable is not None:
            enable_event = RisingEdge(self.enable)

        while True:
            await clock_edge_event

            if self.enable is None or self.enable.value:
                d_val = self.data.value.integer
                dv_val = self.dv.value.integer
                er_val = 0 if self.er is None else self.er.value.integer

                if frame is None:
                    if dv_val:
                        # start of frame
                        frame = GmiiFrame(bytearray(), [])
                        frame.sim_time_start = get_sim_time()
                else:
                    if not dv_val:
                        # end of frame
                        odd = 0
                        sync = False
                        b = 0
                        be = 0
                        data = bytearray()
                        error = []
                        for n, e in zip(frame.data, frame.error):
                            odd += 1
                            b = (n & 0x03) << 6 | b >> 2
                            be |= e
                            if not sync and b == EthPre.SFD:
                                odd = 4
                                sync = True
                            if odd == 4:
                                data.append(b)
                                error.append(be)
                                be = 0
                                odd = 0
                        frame.data = data
                        frame.error = error

                        frame.compact()
                        frame.sim_time_end = get_sim_time()
                        self.log.info("RX frame: %s", frame)

                        self.queue_occupancy_bytes += len(frame)
                        self.queue_occupancy_frames += 1

                        self.queue.put_nowait(frame)
                        self.active_event.set()

                        frame = None

                if frame is not None:
                    if frame.sim_time_sfd is None and d_val == 0xD:
                        frame.sim_time_sfd = get_sim_time()

                    frame.data.append(d_val)
                    frame.error.append(er_val)

                    if self.speed == 10e6:
                        for _ in range(9):
                            await clock_edge_event

                if not dv_val:
                    await active_event

            elif self.enable is not None and not self.enable.value:
                await enable_event


class RMiiPhy:
    def __init__(self, txd, tx_er, tx_en, rxd, rx_er, rx_dv, ref_clk, reset=None,
            reset_active_level=True, speed=100e6, *args, **kwargs):

        self.ref_clk = ref_clk

        super().__init__(*args, **kwargs)

        self.tx = RMiiSink(txd, tx_er, tx_en, ref_clk, reset, reset_active_level=reset_active_level)
        self.rx = RMiiSource(rxd, rx_er, rx_dv, ref_clk, reset, reset_active_level=reset_active_level)

        self.rx.set_no_mode()

        self.ref_clk.setimmediatevalue(0)

        self._clock_cr = None
        self.set_speed(speed)

    def set_speed(self, speed):
        if speed in (10e6, 100e6):
            self.speed = speed
        else:
            raise ValueError("Invalid speed selection")
        
        self.tx.set_speed(speed)
        self.rx.set_speed(speed)

        if self._clock_cr is not None:
            self._clock_cr.kill()

        self._clock_cr = cocotb.start_soon(self._run_clocks(20 // int(100e6 // speed)))

    async def _run_clocks(self, period):
        half_period = get_sim_steps(period / 2.0, units='ps')
        t = Timer(half_period)

        while True:
            await t
            self.ref_clk.value = 1
            await t
            self.ref_clk.value = 0


