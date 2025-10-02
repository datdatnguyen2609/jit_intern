`timescale 1ns/1ps

module seg7_display_tb;

  reg clk;
  reg rst;
  reg signed [15:0] val_in;

  wire [3:0] an;
  wire [6:0] seg;
  wire dp;

  // tao clock 100kHz (10us chu ky)
  initial clk = 0;
  always #5000 clk = ~clk; // 5000ns = 5us -> 10us chu ky

  // khoi tao DUT
  seg7_display dut (
    .i_clk(clk),
    .i_rst(rst),
    .i_val(val_in),
    .o_an(an),
    .o_seg(seg),
    .o_dp(dp)
  );

  initial begin
    // reset
    rst = 1;
    val_in = 0;
    #20000; // 20us
    rst = 0;

    // test so duong 25.34 -> val_in=2534
    #100000;
    val_in = 16'sd2534;

    // test so am -9.87 -> val_in=-987
    #200000;
    val_in = -16'sd987;

    // test max -> 99.99
    #200000;
    val_in = 16'sd9999;

    // test min -> -99.99
    #200000;
    val_in = -16'sd9999;

    // ket thuc mo phong
    #200000;
    $finish;
  end

endmodule
