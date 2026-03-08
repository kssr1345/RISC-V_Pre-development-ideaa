module dma_mem2mem (
  input  logic        clk,
  input  logic        rst_n,
  input  logic        wr_en,
  input  logic        rd_en,
  input  logic [31:0] addr,
  input  logic [31:0] wdata,
  output logic [31:0] rdata,
  output logic        irq_done,
  output logic        irq_err
);
  logic start, irq_en_done, irq_en_err;
  logic [31:0] src, dst, len;
  logic busy, done;
  logic [1:0] err;
  logic [7:0] countdown;

  localparam logic [7:0] CTRL_OFS   = 8'h00;
  localparam logic [7:0] SRC_OFS    = 8'h04;
  localparam logic [7:0] DST_OFS    = 8'h08;
  localparam logic [7:0] LEN_OFS    = 8'h0C;
  localparam logic [7:0] STATUS_OFS = 8'h10;
  localparam logic [7:0] IRQCLR_OFS = 8'h14;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      start <= 1'b0; irq_en_done <= 1'b0; irq_en_err <= 1'b0;
      src <= '0; dst <= '0; len <= '0; busy <= 1'b0; done <= 1'b0; err <= 2'd0; countdown <= '0;
    end else begin
      if (wr_en) begin
        unique case (addr[7:0])
          CTRL_OFS: begin
            start       <= wdata[0];
            irq_en_done <= wdata[1];
            irq_en_err  <= wdata[2];
          end
          SRC_OFS: src <= wdata;
          DST_OFS: dst <= wdata;
          LEN_OFS: len <= wdata;
          IRQCLR_OFS: begin
            if (wdata[0]) done <= 1'b0;
            if (wdata[1]) err  <= 2'd0;
          end
          default: ;
        endcase
      end

      if (start && !busy) begin
        done <= 1'b0;
        if ((src[1:0] != 2'b0) || (dst[1:0] != 2'b0) || (len[1:0] != 2'b0)) begin
          err <= 2'd1;
          start <= 1'b0;
        end else begin
          busy <= 1'b1;
          countdown <= (len[9:2] == 0) ? 8'd1 : len[9:2];
          err <= 2'd0;
        end
      end

      if (busy) begin
        if (countdown == 8'd0) begin
          busy <= 1'b0;
          done <= 1'b1;
          start <= 1'b0;
        end else begin
          countdown <= countdown - 8'd1;
        end
      end
    end
  end

  always_comb begin
    rdata = 32'h0;
    if (rd_en) begin
      unique case (addr[7:0])
        CTRL_OFS:   rdata = {29'h0, irq_en_err, irq_en_done, start};
        SRC_OFS:    rdata = src;
        DST_OFS:    rdata = dst;
        LEN_OFS:    rdata = len;
        STATUS_OFS: rdata = {28'h0, err, done, busy};
        default: ;
      endcase
    end
  end

  assign irq_done = done & irq_en_done;
  assign irq_err  = (err != 2'd0) & irq_en_err;
endmodule
