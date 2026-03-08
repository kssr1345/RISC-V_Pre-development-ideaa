`timescale 1ns/1ps
module tb_soc_top;
  logic clk = 0;
  logic rst_n = 0;
  logic wr_en, rd_en;
  logic [31:0] addr, wdata, rdata;
  logic cpu_ext_irq;

  soc_top dut (
    .clk(clk), .rst_n(rst_n),
    .bus_wr_en(wr_en), .bus_rd_en(rd_en),
    .bus_addr(addr), .bus_wdata(wdata),
    .bus_rdata(rdata), .cpu_ext_irq(cpu_ext_irq)
  );

  always #5 clk = ~clk;

  task mmio_write(input [31:0] a, input [31:0] d);
    begin
      @(negedge clk);
      addr <= a; wdata <= d; wr_en <= 1'b1; rd_en <= 1'b0;
      @(negedge clk);
      wr_en <= 1'b0;
    end
  endtask

  task mmio_read(input [31:0] a);
    begin
      @(negedge clk);
      addr <= a; rd_en <= 1'b1; wr_en <= 1'b0;
      @(negedge clk);
      rd_en <= 1'b0;
    end
  endtask

  initial begin
    wr_en = 0; rd_en = 0; addr = 0; wdata = 0;
    repeat (5) @(negedge clk);
    rst_n = 1'b1;

    // Enable counter interrupt source in INTC.
    mmio_write(32'h2000_1000, 32'h1);

    // Counter compare=10, enable+irq_en+auto_reload
    mmio_write(32'h2000_0008, 32'd10);
    mmio_write(32'h2000_0000, 32'h7);

    repeat (40) @(negedge clk);
    if (!cpu_ext_irq) begin
      $error("Expected cpu_ext_irq to assert from counter path");
      $fatal;
    end

    // Clear pending in INTC and counter status
    mmio_write(32'h2000_1004, 32'h1);
    mmio_write(32'h2000_0010, 32'h1);

    repeat (10) @(negedge clk);
    $display("TB PASS");
    $finish;
  end
endmodule
