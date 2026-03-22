module counter_ip (
  input  logic        clk,
  input  logic        rst_n,
  input  logic        wr_en,
  input  logic        rd_en,
  input  logic [31:0] addr,
  input  logic [31:0] wdata,
  output logic [31:0] rdata,
  output logic        irq
);
  logic        en, irq_en, auto_reload;
  logic [31:0] value, compare;
  logic        match;

  localparam logic [7:0] CTRL_OFS    = 8'h00;
  localparam logic [7:0] VALUE_OFS   = 8'h04;
  localparam logic [7:0] COMPARE_OFS = 8'h08;
  localparam logic [7:0] STATUS_OFS  = 8'h0C;
  localparam logic [7:0] IRQCLR_OFS  = 8'h10;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      en <= 1'b0; irq_en <= 1'b0; auto_reload <= 1'b0;
      value <= '0; compare <= 32'd100; match <= 1'b0;
    end else begin
      if (en) begin
        value <= value + 32'd1;
        if (value == compare) begin
          match <= 1'b1;
          if (auto_reload) value <= 32'd0;
        end
      end
      if (wr_en) begin
        unique case (addr[7:0])
          CTRL_OFS: begin
            en          <= wdata[0];
            irq_en      <= wdata[1];
            auto_reload <= wdata[2];
          end
          VALUE_OFS:   value   <= wdata;
          COMPARE_OFS: compare <= wdata;
          IRQCLR_OFS:  if (wdata[0]) match <= 1'b0;
          default: ;
        endcase
      end
    end
  end

  always_comb begin
    rdata = 32'h0;
    if (rd_en) begin
      unique case (addr[7:0])
        CTRL_OFS:    rdata = {29'h0, auto_reload, irq_en, en};
        VALUE_OFS:   rdata = value;
        COMPARE_OFS: rdata = compare;
        STATUS_OFS:  rdata = {31'h0, match};
        default:     rdata = 32'h0;
      endcase
    end
  end

  assign irq = match & irq_en;
endmodule
