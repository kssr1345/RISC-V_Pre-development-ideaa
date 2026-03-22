# RISC-V Counter + INTC + DMA Bootstrap

This repository now includes a concrete starter scaffold for the SoC plan:
- RTL blocks in `rtl/` (`counter_ip`, `intc`, `dma_mem2mem`, `soc_top`).
- Verilator smoke testbench in `tb/tb_soc_top.sv`.
- Simulation flow in `sim/Makefile`.
- Bare-metal firmware bootstrap artifacts in `fw/` (`linker.ld`, `start.S`, `soc_mmio.h`).

## Simple Block Diagram
```text
                    +-----------------------------------+
                    |           RISC-V CPU              |
                    |      (recommended: Ibex)          |
                    |                                   |
                    |  instruction/data bus master      |
                    |  external interrupt input         |
                    +----------------+------------------+
                                     |
                                     | MMIO + memory access
                   +-----------------+------------------+
                   |         Interconnect / Decoder     |
                   +--------+--------------+------------+
                            |              |            |
                            |              |            |
                  +---------v--+   +------v------+   +--v-----------+
                  | Counter IP |   | Interrupt   |   | DMA Mem2Mem  |
                  | compare    |-->| Controller  |<--| done/error   |
                  | irq source |   | (enable /   |   | irq outputs  |
                  +------------+   | pending /   |   +------+-------+
                                   | claim)      |          |
                                   +------+------+          |
                                          |                 |
                                          +--------+--------+
                                                   |
                                          +--------v--------+
                                          | SRAM / Memory   |
                                          | code, data, DMA |
                                          | src/dst buffers |
                                          +-----------------+
```

## What Each Block Does
- **RISC-V CPU**: runs firmware, programs peripherals through MMIO, and services interrupts.
- **Counter IP**: raises a periodic interrupt after reaching a programmed compare value.
- **Interrupt Controller (INTC)**: collects interrupt sources and presents one CPU interrupt line.
- **DMA Mem2Mem**: copies data between memory regions without CPU moving every word.
- **SRAM**: stores code/data and the DMA source/destination buffers.

## Development Plan Reset
If you feel lost, restart with these milestones.

### Phase 1: Prove the Bus and MMIO Path
Goal: make sure the CPU/testbench can read and write registers.
1. Keep only `soc_top`, address decode, and one simple peripheral.
2. Read/write `COUNTER_COMPARE` and read it back.
3. Return a decode error value for unmapped addresses.

**Done when:** register writes and reads behave exactly as expected in simulation.

### Phase 2: Prove Interrupts with Only Counter + INTC
Goal: get the first full hardware event into the CPU side.
1. Enable counter compare interrupt.
2. Latch it in INTC pending register.
3. Assert `cpu_ext_irq`.
4. Clear the interrupt from both counter and INTC.

**Done when:** the testbench sees `cpu_ext_irq` go high and clear cleanly.

### Phase 3: Add Minimal Firmware Bring-Up
Goal: replace testbench-only behavior with real bare-metal flow.
1. Add startup code and linker script.
2. Add MMIO helper macros/functions.
3. Add trap handler.
4. Program counter from `main()`.

**Done when:** firmware can boot and handle at least one interrupt path.

### Phase 4: Add DMA in Polling Mode First
Goal: keep DMA simple before adding interrupts.
1. Add `SRC`, `DST`, `LEN`, `START`, `STATUS` registers.
2. Implement a simple transfer FSM.
3. Poll `STATUS.done` from firmware/testbench.

**Done when:** destination buffer matches source buffer for a few simple test cases.

### Phase 5: Add DMA Interrupts
Goal: integrate DMA with the same interrupt path already proven by Counter.
1. Add DMA done/error interrupt outputs.
2. Feed them into INTC.
3. Extend ISR dispatch.

**Done when:** both counter and DMA interrupts can occur and be serviced correctly.

### Phase 6: Stress and Clean-Up
Goal: make it stable enough to build on.
1. Run counter while DMA is active.
2. Check pending/clear race behavior.
3. Add alignment and illegal-address error cases.
4. Improve docs and wave debug views.

**Done when:** no deadlocks, no stuck interrupts, and expected error reporting.

## What You Should Code First
If you start coding again today, do it in this exact order:
1. `rtl/soc_pkg.sv`
2. `rtl/soc_top.sv`
3. `rtl/counter_ip.sv`
4. `rtl/intc.sv`
5. `tb/tb_soc_top.sv`
6. `fw/start.S` + `fw/linker.ld`
7. `rtl/dma_mem2mem.sv`

## Quick start
```bash
cd sim
make lint
make run
```

The current testbench validates an end-to-end counter interrupt path through INTC to `cpu_ext_irq`.
