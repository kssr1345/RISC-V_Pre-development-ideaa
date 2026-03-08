package soc_pkg;
  localparam logic [31:0] COUNTER_BASE = 32'h2000_0000;
  localparam logic [31:0] INTC_BASE    = 32'h2000_1000;
  localparam logic [31:0] DMA_BASE     = 32'h2000_2000;

  localparam int IRQ_COUNTER   = 0;
  localparam int IRQ_DMA_DONE  = 1;
  localparam int IRQ_DMA_ERROR = 2;

  localparam logic [1:0] DMA_ERR_NONE   = 2'd0;
  localparam logic [1:0] DMA_ERR_ALIGN  = 2'd1;
  localparam logic [1:0] DMA_ERR_BOUNDS = 2'd2;
endpackage
