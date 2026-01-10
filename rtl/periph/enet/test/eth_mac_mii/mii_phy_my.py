import cocotb
from cocotb.clock import Clock, Timer
from cocotb.triggers import RisingEdge, Event
from cocotbext.eth import MiiSource, MiiSink
from cocotb.utils import get_sim_time, get_sim_steps

import random

class MiiSource_my(MiiSource):
    def set_no_mode(self, no_mode:bool = False):
        self.no_mode = no_mode
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

                    # convert to MII
                    frame_data = []
                    frame_error = []
                    sel = random.randint(30, (len(frame.data) - 1))
                    for i, [b, e] in enumerate(zip(frame.data, frame.error)):
                        if (self.no_mode == True) and (i == sel):
                            frame_data.append(b & 0x0F)
                            frame_error.append(e)
                            break
                        else:
                            frame_data.append(b & 0x0F)
                            frame_data.append(b >> 4)
                            frame_error.append(e)
                            frame_error.append(e)

                    self.active = True
                    frame_offset = 0

                if frame is not None:
                    d = frame_data[frame_offset]
                    if frame.sim_time_sfd is None and d == 0xD:
                        frame.sim_time_sfd = get_sim_time()
                    self.data.value = d
                    if self.er is not None:
                        self.er.value = frame_error[frame_offset]
                    self.dv.value = 1
                    frame_offset += 1

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


class MiiPhy_my:
    def __init__(self, txd, tx_er, tx_en, tx_clk, rxd, rx_er, rx_dv, rx_clk, reset=None,
            reset_active_level=True, speed=100e6, *args, **kwargs):

        self.tx_clk = tx_clk
        self.rx_clk = rx_clk

        super().__init__(*args, **kwargs)

        self.tx = MiiSink(txd, tx_er, tx_en, tx_clk, reset, reset_active_level=reset_active_level)
        self.rx = MiiSource_my(rxd, rx_er, rx_dv, rx_clk, reset, reset_active_level=reset_active_level)

        self.rx.set_no_mode()

        self.tx_clk.setimmediatevalue(0)
        self.rx_clk.setimmediatevalue(0)

        self._clock_cr = None
        self.set_speed(speed)

    def set_speed(self, speed):
        if speed in (10e6, 100e6):
            self.speed = speed
        else:
            raise ValueError("Invalid speed selection")

        if self._clock_cr is not None:
            self._clock_cr.kill()

        self._clock_cr = cocotb.start_soon(self._run_clocks(4*1e9/self.speed))

    async def _run_clocks(self, period):
        half_period = get_sim_steps(period / 2.0, 'ns')
        t = Timer(half_period)

        while True:
            await t
            self.tx_clk.value = 1
            self.rx_clk.value = 1
            await t
            self.tx_clk.value = 0
            self.rx_clk.value = 0
