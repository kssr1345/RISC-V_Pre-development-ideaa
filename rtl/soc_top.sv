`timescale 1ns/1ps
module soc_top (
  input  logic        clk,
  input  logic        rst_n,
  input  logic        bus_wr_en,
  input  logic        bus_rd_en,
  input  logic [31:0] bus_addr,
  input  logic [31:0] bus_wdata,
  output logic [31:0] bus_rdata,
  output logic        cpu_ext_irq
);
  import soc_pkg::*;

  logic [31:0] counter_rdata, intc_rdata, dma_rdata;
  logic counter_irq, dma_irq_done, dma_irq_err;
  logic [2:0] src_irq;
  logic [2:0] pending;

  logic hit_counter, hit_intc, hit_dma;
  assign hit_counter = (bus_addr[31:12] == COUNTER_BASE[31:12]);
  assign hit_intc    = (bus_addr[31:12] == INTC_BASE[31:12]);
  assign hit_dma     = (bus_addr[31:12] == DMA_BASE[31:12]);

  counter_ip u_counter (
    .clk   (clk),
    .rst_n (rst_n),
    .wr_en (bus_wr_en & hit_counter),
    .rd_en (bus_rd_en & hit_counter),
    .addr  (bus_addr),
    .wdata (bus_wdata),
    .rdata (counter_rdata),
    .irq   (counter_irq)
  );

  dma_mem2mem u_dma (
    .clk      (clk),
    .rst_n    (rst_n),
    .wr_en    (bus_wr_en & hit_dma),
    .rd_en    (bus_rd_en & hit_dma),
    .addr     (bus_addr),
    .wdata    (bus_wdata),
    .rdata    (dma_rdata),
    .irq_done (dma_irq_done),
    .irq_err  (dma_irq_err)
  );

  assign src_irq = {dma_irq_err, dma_irq_done, counter_irq};

  intc #(.N_SRC(3)) u_intc (
    .clk        (clk),
    .rst_n      (rst_n),
    .wr_en      (bus_wr_en & hit_intc),
    .rd_en      (bus_rd_en & hit_intc),
    .addr       (bus_addr),
    .wdata      (bus_wdata),
    .rdata      (intc_rdata),
    .src_irq    (src_irq),
    .cpu_ext_irq(cpu_ext_irq),
    .pending_o  (pending)
  );

  always_comb begin
    unique case (1'b1)
      hit_counter: bus_rdata = counter_rdata;
      hit_intc:    bus_rdata = intc_rdata;
      hit_dma:     bus_rdata = dma_rdata;
      default:     bus_rdata = 32'hDEAD_BEEF;
    endcase
  end
endmodule
