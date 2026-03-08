TOP=tb_soc_top
RTL=../rtl/soc_pkg.sv ../rtl/counter_ip.sv ../rtl/intc.sv ../rtl/dma_mem2mem.sv ../rtl/soc_top.sv
TB=../tb/tb_soc_top.sv

all: run

lint:
	verilator --lint-only -Wall --timing $(RTL) $(TB)

build:
	verilator -Wall --timing --binary -Wno-fatal --top-module $(TOP) $(RTL) $(TB)

run: build
	./obj_dir/V$(TOP)

clean:
	rm -rf obj_dir logs *.vcd *.fst
