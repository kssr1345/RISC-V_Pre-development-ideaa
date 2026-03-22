# RISC-V Counter + INTC + DMA Bootstrap

This repository now includes a concrete starter scaffold for the SoC plan:
- RTL blocks in `rtl/` (`counter_ip`, `intc`, `dma_mem2mem`, `soc_top`).
- Verilator smoke testbench in `tb/tb_soc_top.sv`.
- Simulation flow in `sim/Makefile`.
- Bare-metal firmware bootstrap artifacts in `fw/` (`linker.ld`, `start.S`, `soc_mmio.h`).

## Quick start
```bash
cd sim
make lint
make run
```

The current testbench validates an end-to-end counter interrupt path through INTC to `cpu_ext_irq`.
