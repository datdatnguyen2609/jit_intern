`timescale 1ns/1ps

module scl_gen_tb;
  localparam CLK_FREQ      = 100_000_000;
  localparam SCL_FREQ      = 100_000;
  localparam CLK_PERIOD_NS = 1_000_000_000/CLK_FREQ;

  reg I_CLK;
  reg I_RST;
  reg I_EN;
  wire O_SCL;

  scl_gen #(
    .CLK_FREQ(CLK_FREQ),
    .SCL_FREQ(SCL_FREQ)
  ) dut (
    .I_CLK(I_CLK),
    .I_RST(I_RST),
    .I_EN(I_EN),
    .O_SCL(O_SCL)
  );

  initial I_CLK = 1'b0;
  always #(CLK_PERIOD_NS/2) I_CLK = ~I_CLK;

  initial begin
    I_RST = 1'b1;
    I_EN  = 1'b0;
    #100;
    I_RST = 1'b0;
    I_EN  = 1'b1;
    #2_000_000;
    $finish;
  end
endmodule
