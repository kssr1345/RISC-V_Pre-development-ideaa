module intc #(
  parameter int N_SRC = 3
) (
  input  logic              clk,
  input  logic              rst_n,
  input  logic              wr_en,
  input  logic              rd_en,
  input  logic [31:0]       addr,
  input  logic [31:0]       wdata,
  output logic [31:0]       rdata,
  input  logic [N_SRC-1:0]  src_irq,
  output logic              cpu_ext_irq,
  output logic [N_SRC-1:0]  pending_o
);
  logic [N_SRC-1:0] enable;
  logic [N_SRC-1:0] pending;

  localparam logic [7:0] ENABLE_OFS  = 8'h00;
  localparam logic [7:0] PENDING_OFS = 8'h04;
  localparam logic [7:0] CLAIM_OFS   = 8'h08;

  integer i;
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      enable <= '0;
      pending <= '0;
    end else begin
      pending <= pending | src_irq;
      if (wr_en) begin
        unique case (addr[7:0])
          ENABLE_OFS:  enable <= wdata[N_SRC-1:0];
          PENDING_OFS: pending <= pending & ~wdata[N_SRC-1:0]; // W1C
          default: ;
        endcase
      end
    end
  end

  always_comb begin
    rdata = 32'h0;
    if (rd_en) begin
      unique case (addr[7:0])
        ENABLE_OFS:  rdata = {{(32-N_SRC){1'b0}}, enable};
        PENDING_OFS: rdata = {{(32-N_SRC){1'b0}}, pending};
        CLAIM_OFS: begin
          rdata = 32'hFFFF_FFFF;
          for (i = 0; i < N_SRC; i++) begin
            if ((pending[i] & enable[i]) && rdata == 32'hFFFF_FFFF) rdata = i;
          end
        end
        default: ;
      endcase
    end
  end

  assign cpu_ext_irq = |(pending & enable);
  assign pending_o   = pending;
endmodule
