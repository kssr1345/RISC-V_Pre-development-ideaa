# Industrial Draft Plan: RISC-V + Counter IP + Interrupt Controller + DMA (Mem2Mem)

## 1) Scope and Goals
Design a small SoC subsystem around an existing RISC-V core that integrates:
- A memory-mapped **Counter IP**.
- A centralized **Interrupt Controller** and processor interrupt path.
- A **DMA engine** with memory-to-memory transfer capability.
- Dedicated DMA-accessible memory regions (source/destination buffers).
- Firmware interrupt handlers and driver model.

Primary objective: provide a production-style reference architecture that is simple enough to implement quickly, but robust enough to scale into an industrial embedded platform.

---

## 2) Assumptions and Baseline
- Existing single-core RISC-V processor (RV32/64) with machine-mode interrupt support.
- A standard on-chip bus fabric (AXI4-Lite + AXI4, AHB, or Wishbone). This draft uses generic terms and maps cleanly to AXI.
- On-chip SRAM and optional external memory interface.
- Single clock domain for first implementation (multi-clock optional in phase 2).

---

## 2.1 Recommended RISC-V Core Selection
For this project, use **lowRISC Ibex** as the baseline core (RV32IMC configuration).

Why Ibex for your setup:
- **Industrial credibility**: widely used open-source core with strong verification pedigree.
- **Interrupt-friendly**: clean machine-mode interrupt model (`irq_external_i`) that fits the INTC path in this draft.
- **Tool compatibility**: straightforward Verilator simulation flow and good signal visibility for GTKWave debug.
- **Complexity balance**: significantly more production-like than ultra-minimal cores while still manageable for first integration.

If you want a faster "first light" bring-up at minimal integration cost, `picorv32` is a fallback option, but for your stated interrupt/DMA roadmap Ibex is the better long-term anchor.

## 3) Top-Level Architecture

### 3.1 Functional Blocks
1. **RISC-V CPU subsystem**
   - Instruction/data access to system memory map.
   - External interrupt input from interrupt controller.

2. **Counter IP**
   - Programmable period/threshold.
   - Free-running and compare mode.
   - Optional auto-reload.
   - Interrupt generation on threshold event.

3. **Interrupt Controller (INTC)**
   - Aggregates interrupt sources (Counter, DMA done/error, optional GPIO/UART).
   - Per-source enable/mask/pending/priority registers.
   - Single external interrupt line to CPU (expandable to PLIC-like design).

4. **DMA Engine (Mem2Mem)**
   - Register-programmed source address, destination address, transfer length.
   - Burst support and alignment handling.
   - Interrupt on completion and error.

5. **Memory Subsystem**
   - Instruction/data memory for CPU.
   - DMA-visible source/destination regions.
   - Arbiter/QoS policy to prevent CPU starvation.

### 3.2 Reference Data/Control Paths
- **Control path:** CPU programs Counter, INTC, DMA via memory-mapped CSRs.
- **Interrupt path:** Counter/DMA -> INTC -> CPU external interrupt -> ISR dispatch.
- **Data path:** DMA reads source memory, writes destination memory, independent of CPU datapath.

---

## 4) Proposed Memory Map (Example)
| Region | Base Address | Size | Notes |
|---|---:|---:|---|
| Boot ROM | 0x0000_0000 | 64 KB | Reset vector |
| On-chip SRAM | 0x1000_0000 | 512 KB | Code/data/stack |
| Counter IP regs | 0x2000_0000 | 4 KB | MMIO |
| INTC regs | 0x2000_1000 | 4 KB | MMIO |
| DMA regs | 0x2000_2000 | 4 KB | MMIO |
| DMA Src Buffer | 0x3000_0000 | 64 KB | DMA-readable |
| DMA Dst Buffer | 0x3001_0000 | 64 KB | DMA-writable |

Keep these symbolic in RTL headers (`soc_memory_map.svh`) and firmware headers (`soc_mmio.h`) to avoid drift.

---

## 4.1 SRAM Architecture (Detailed Draft)

To make DMA + CPU integration practical, SRAM needs an explicit micro-architecture, not just a base address.

### A) Recommended SRAM Partitioning
- **TCM/Low-latency SRAM (optional):** tightly-coupled block for ISR-critical code/data.
- **System SRAM:** shared by CPU and DMA for general data.
- **DMA Buffers in SRAM:** reserve explicit linker sections for DMA source/destination in non-cacheable regions (or use cache maintenance).

Example partition inside `0x1000_0000` 512 KB SRAM:
- `0x1000_0000 - 0x1001_FFFF` (128 KB): firmware `.text/.rodata`
- `0x1002_0000 - 0x1005_FFFF` (256 KB): firmware `.data/.bss/heap/stack`
- `0x1006_0000 - 0x1006_FFFF` (64 KB): DMA source buffer
- `0x1007_0000 - 0x1007_FFFF` (64 KB): DMA destination buffer

### B) Access and Arbitration
- If feasible, use **dual-port SRAM** (or banked SRAM) so CPU and DMA can access concurrently.
- If single-port SRAM is used, bus arbitration must guarantee forward progress for CPU fetch/load-store during long DMA bursts.
- Cap DMA burst length (e.g., INCR4/INCR8) to reduce latency spikes seen by ISR paths.

### C) Data Integrity / Safety
- Prefer SRAM with **SECDED ECC** for industrial reliability targets.
- Expose ECC status/error counters through diagnostic registers if platform safety goals require traceability.
- Define behavior on uncorrectable error (NMI, machine check, or logged fatal error policy).

### D) Cache/Coherency Policy
- If core has D-cache and DMA is non-coherent:
  - Mark DMA SRAM windows as non-cacheable, **or**
  - Enforce `clean/invalidate` before and after DMA transactions.
- Include memory barriers around descriptor/data ownership transfer in firmware.

### E) Firmware and Linker Constraints
- Reserve DMA regions in linker script and place buffers with alignment attributes (e.g., 64-byte).
- Add compile-time checks for section overflow and runtime checks for address-range validity before starting DMA.

---

## 5) Register-Level Draft

### 5.1 Counter IP Registers
- `COUNTER_CTRL` (enable, mode, irq_enable, auto_reload)
- `COUNTER_VALUE` (current count)
- `COUNTER_COMPARE` (threshold/period)
- `COUNTER_STATUS` (match flag, overflow flag)
- `COUNTER_IRQ_CLR` (W1C)

### 5.2 Interrupt Controller Registers
- `INTC_ENABLE[n]`
- `INTC_PENDING[n]` (W1C)
- `INTC_PRIORITY[n]`
- `INTC_THRESHOLD`
- `INTC_CLAIM_COMPLETE` (optional PLIC-style flow)

### 5.3 DMA Registers
- `DMA_CTRL` (start, irq_en_done, irq_en_err, soft_reset)
- `DMA_SRC_ADDR`
- `DMA_DST_ADDR`
- `DMA_LEN_BYTES`
- `DMA_STATUS` (busy, done, err_code)
- `DMA_IRQ_CLR` (W1C)

Industrial recommendation: define all register behavior in a machine-readable spec (YAML/SystemRDL/IP-XACT), then auto-generate RTL register shells and C headers.

---

## 6) Interrupt Architecture Draft

### 6.1 Interrupt Sources
- `irq_counter_match`
- `irq_dma_done`
- `irq_dma_error`

### 6.2 CPU Handling Model
- Route INTC output to RISC-V machine external interrupt.
- In trap handler:
  1. Read `mcause` and verify external interrupt.
  2. Query INTC pending/claim register.
  3. Dispatch source-specific ISR.
  4. Clear peripheral and/or INTC pending bits.

### 6.3 Latency/Robustness Targets
- ISR entry latency budget: define target in cycles (e.g., <150 cycles from irq assert to ISR first instruction in typical configuration).
- Ensure level-triggered signals are deasserted only after proper W1C handling.
- Include interrupt storm protection and optional source rate limiting.

---

## 7) DMA Mem2Mem Transfer Flow

### 7.1 Firmware Sequence
1. Fill source buffer with pattern.
2. Program `SRC`, `DST`, `LEN`.
3. Enable DMA done/error interrupts.
4. Set `DMA_CTRL.start`.
5. CPU may sleep (`wfi`) or continue work.
6. ISR on `done/error`, clear IRQ, set software flag.
7. Verify destination data and optional checksum.

### 7.2 Hardware Safeguards
- Address alignment checks.
- Region boundary checks to prevent illegal access.
- Max transfer length cap.
- Error codes (alignment, decode error, bus timeout).

---

## 8) Firmware Architecture Draft

### 8.1 Layering
- `hal_mmio`: generic read/write helpers + barriers.
- `drv_counter`: init/start/stop/set_compare/clear_irq.
- `drv_intc`: register source handlers, enable/disable IRQs.
- `drv_dma`: configure/start/status/clear_irq.
- `isr.c`: trap entry + interrupt dispatch table.
- `app_main.c`: demo scenario (counter ticks + DMA transfer).

### 8.2 Interrupt Handler Pseudocode
```c
void machine_external_interrupt_handler(void) {
    uint32_t id = intc_claim();
    switch (id) {
        case IRQ_COUNTER:
            counter_clear_irq();
            g_counter_ticks++;
            break;
        case IRQ_DMA_DONE:
            dma_clear_done();
            g_dma_done = 1;
            break;
        case IRQ_DMA_ERROR:
            g_dma_err = dma_get_error();
            dma_clear_error();
            break;
        default:
            /* spurious */
            break;
    }
    intc_complete(id);
}
```

---

## 9) Verification and Validation Plan

### 9.1 RTL Verification
- Unit-level testbenches:
  - Counter modes and corner cases.
  - DMA transfer sizes, alignments, error responses.
  - INTC masking/priorities/pending clear behavior.
- SoC-level integration tests:
  - Counter interrupt reaches CPU and ISR executes.
  - DMA done/error interrupts correctly routed.
  - Concurrent interrupts and priority resolution.
  - CPU+DMA contention on SRAM under worst-case burst traffic.
  - SRAM ECC injection (if enabled) and interrupt/error handling path.

### 9.2 Firmware Validation
- Bare-metal smoke tests:
  - Counter periodic interrupt count accuracy.
  - DMA memory copy correctness for random lengths.
  - Stress test with repeated DMA + counter interrupts.

### 9.3 Coverage/Signoff Targets
- Functional coverage: interrupt source/mask/clear transitions, DMA boundary scenarios.
- Code coverage targets for RTL (line/toggle/branch/FSM as applicable).
- Regression pass criteria and bug bar definitions.

---

## 10) Physical Design and Productization Considerations
- Clock/reset strategy: synchronous resets preferred, clearly sequenced deassertion.
- DFT hooks for DMA/INTC observability.
- Power: clock-gating idle DMA/counter blocks.
- Safety/reliability: watchdog interaction, bus error recovery path.
- Documentation: programmer’s guide + register map + bring-up checklist.

---

## 11) Phased Execution Plan

### Phase 0 — Architecture Freeze (1 week)
- Finalize memory map, register definitions, interrupt IDs.
- Confirm bus protocol and addressing constraints.

### Phase 1 — RTL + Basic Firmware Bring-up (2–3 weeks)
- Implement Counter, INTC (basic), DMA mem2mem.
- Integrate with CPU and run first ISR + DMA demo.

### Phase 2 — Verification Expansion (2 weeks)
- Add constrained-random scenarios and error injection.
- Add firmware stress suite.

### Phase 3 — Hardening (1–2 weeks)
- Performance tuning (burst lengths/arbitration).
- Robust reset/error handling.
- Documentation and handoff package.

---

## 12) Risks and Mitigations
- **Interrupt race conditions**: enforce clear claim/complete protocol and W1C discipline.
- **DMA coherency issues**: define cache policy (non-cacheable DMA buffers or explicit flush/invalidate).
- **Bus contention**: tune arbitration and DMA burst caps.
- **Spec drift between RTL/FW**: auto-generate headers from one source of truth.

---

## 13) Immediate Next Actions
1. Choose exact bus standard and adapt register interface templates.
2. Lock memory map, IRQ numbering, and SRAM partition/linker regions.
3. Create register spec source file and auto-generated artifacts.
4. Define DMA coherency policy (non-cacheable SRAM windows vs cache maintenance).
5. Build minimum firmware demo: counter interrupt + one DMA copy + ISR logs.
6. Stand up CI regression for RTL simulation and firmware tests.

This draft is intentionally implementation-ready: it can be turned into tickets for architecture, RTL, verification, firmware, and integration teams.

---

## 14) How to Design with Verilator + GTKWave (Practical Execution)

Given your current toolchain, use a simulation-first methodology with strict milestones.

### 14.1 Recommended Repository Structure
- `rtl/`
  - `soc_top.sv`
  - `ibex_wrapper.sv`
  - `counter_ip.sv`
  - `intc.sv`
  - `dma_mem2mem.sv`
  - `sram_model.sv` (behavioral model for simulation)
- `tb/`
  - `tb_soc_top.cpp` (Verilator C++ testbench)
  - `tb_mem_init.hex`
  - `scenarios/` (directed test scripts/vectors)
- `fw/`
  - linker script, startup, ISR, drivers
  - bare-metal tests that emit pass/fail signature
- `sim/`
  - `Makefile` (Verilator build/run targets)
  - waveform outputs (`.fst`/`.vcd`)

### 14.2 Bring-up Sequence (Order Matters)
1. **CPU + SRAM only**: boot from ROM/SRAM, execute a small firmware loop.
2. **Add MMIO decode**: read/write sanity for Counter/INTC/DMA register blocks.
3. **Counter interrupt path**: Counter -> INTC -> Ibex external IRQ -> ISR increment counter.
4. **DMA mem2mem without interrupts**: polling mode copy + memory signature check.
5. **DMA interrupts**: done/error IRQ routing and ISR handling.
6. **Concurrency stress**: Counter IRQs while DMA is active with SRAM contention.

### 14.3 Verilator-Specific Design Guidance
- Keep RTL synthesizable and avoid simulator-only behavior in design files.
- Use `--trace-fst` for smaller/faster wave dumps when available.
- Add lightweight assertions in RTL (SystemVerilog assertions or explicit error flags) for protocol/CSR invariants.
- Expose debug signals at `soc_top` boundary (current IRQ ID, DMA FSM state, bus arbitration grant) to speed waveform triage.

### 14.4 GTKWave Debug Playbook
Create saved views for recurring debug sessions:
- **Interrupt view**: `irq_*`, INTC pending/enable/claim/complete, CPU trap entry signals.
- **DMA view**: SRC/DST/LEN regs, DMA FSM state, bus handshakes, done/error causes.
- **Memory contention view**: CPU memory requests vs DMA requests, arbitration/grant, wait states.

### 14.5 Minimum Verilator Regression Set
- `test_boot_smoke`
- `test_counter_irq_periodic`
- `test_dma_mem2mem_basic`
- `test_dma_mem2mem_unaligned_error`
- `test_dma_irq_done_error`
- `test_irq_dma_concurrency`

Pass criteria: all tests return pass signature, no unexpected assertion failures, and stable waveforms for key handshake/IRQ events.

### 14.6 Industrial Next Step After Verilator
Once stable in Verilator, run the same firmware tests on FPGA prototype (if available) to validate timing-sensitive behavior (interrupt latency/jitter, bus contention realism) before any tape-out-oriented signoff flow.


---

## 15) Where to Start Coding (Implementation Bootstrap)

If you are starting implementation now, follow this order to de-risk integration.

### 15.1 Day-0 Setup (Project Skeleton)
Create a minimal but strict structure first:
- `rtl/` for synthesizable blocks
- `tb/` for Verilator testbench
- `fw/` for bare-metal code and linker script
- `sim/Makefile` for build/run orchestration

Initial coding artifacts:
1. `rtl/soc_pkg.sv` with base addresses, IRQ IDs, DMA error codes.
2. `rtl/soc_top.sv` with clock/reset, bus fabric stub, and module placeholders.
3. `tb/tb_soc_top.cpp` with reset sequencing + timeout + pass/fail exit code.
4. `fw/linker.ld` and `fw/start.S` for a deterministic boot flow.

### 15.2 First RTL You Should Write
Start with components that unblock everything else:
1. **MMIO interconnect/decode (minimal)**
   - Address decode for Counter/INTC/DMA register windows.
   - Read/write response correctness and default decode-error response.
2. **Counter IP (simple compare mode first)**
   - `CTRL`, `VALUE`, `COMPARE`, `STATUS`, `IRQ_CLR`.
   - Generate one interrupt source when compare match occurs.
3. **INTC (minimal, no priority at first)**
   - Source enable + pending + claim/complete path to CPU external IRQ.

Why this order: it gives you an end-to-end interrupt demo early, before DMA complexity is introduced.

### 15.3 First Firmware You Should Write
Implement these in order:
1. `hal_mmio.c/h`: raw CSR/MMIO accessors + barriers.
2. `drv_counter.c/h`: set compare, enable irq, clear irq.
3. `drv_intc.c/h`: enable source, claim, complete.
4. `isr.c`: machine external interrupt handler and source dispatch.
5. `app_main.c`: periodic counter interrupt increments a global tick.

**Milestone-1 success condition:**
- Firmware boots, programs counter, CPU receives periodic interrupts, ISR count matches expected window.

### 15.4 Then Implement DMA in Two Steps
Step A (polling mode first):
- RTL: DMA source/destination/length + start + busy/done/error status.
- FW: configure DMA and poll `done`.
- Test: memory signature compare source vs destination.

Step B (interrupt mode):
- RTL: DMA done/error interrupt outputs.
- FW: ISR paths for done/error, clear W1C bits, complete INTC claim.
- Test: run DMA transfers while counter interrupts are active.

### 15.5 First 10 Coding Tasks (Ticket-Style)
1. Define unified memory map constants in RTL + FW headers.
2. Build `soc_top` reset/clock and bus decode skeleton.
3. Implement counter register block + counter datapath.
4. Implement INTC enable/pending/claim/complete basics.
5. Hook INTC output to Ibex `irq_external_i`.
6. Build trap vector + machine external ISR in firmware.
7. Add counter interrupt smoke test in Verilator.
8. Implement DMA register block + simple FSM mem2mem copy.
9. Add DMA polling test then DMA interrupt test.
10. Add concurrency regression (counter IRQ + DMA active + SRAM contention).

### 15.6 "Definition of Done" for MVP
Declare MVP complete only when all are true:
- Counter interrupt demo is stable across repeated resets/runs.
- DMA mem2mem passes for multiple lengths/alignment classes.
- DMA done/error interrupts route and clear correctly.
- No deadlock under CPU+DMA SRAM contention scenario.
- Verilator regression tests are scripted and reproducible from one command.
