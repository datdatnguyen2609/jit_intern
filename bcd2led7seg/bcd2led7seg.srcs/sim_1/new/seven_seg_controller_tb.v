`timescale 1ns/1ps

module seven_seg_controller_tb;

  // ==== Tham s? testbench ====
  localparam CLK_FREQ    = 1_000_000;   // dùng t?n s? th?p h?n ?? simulate nhanh (1 MHz)
  localparam CLK_PERIOD  = 1_000;       // ns (1 MHz -> chu k? 1000ns)
  localparam ACTIVE_DIGITS = 5;

  // ==== Tín hi?u testbench ====
  reg tb_clk;
  reg tb_rst;
  reg tb_rate_sel_2hz;       // ch?n t?c ?? quét
  reg tb_btn_brightness_up;
  reg tb_btn_brightness_down;

  reg [3:0] tb_bcd0, tb_bcd1, tb_bcd2, tb_bcd3, tb_bcd4;
  wire [ACTIVE_DIGITS-1:0] tb_anode;
  wire [2:0] tb_bcd_sel;
  wire [3:0] tb_bcd_out;

  // ==== DUT ====
  seven_seg_controller #(
    .CLK_FREQ(CLK_FREQ),
    .ACTIVE_DIGITS(ACTIVE_DIGITS),
    .FAST_HZ(240),
    .SLOW_HZ(2),
    .PWM_FREQ(1000),
    .PWM_BITS(8),
    .BRIGHTNESS_LEVELS(4)
  ) dut (
    .I_clk(tb_clk),
    .I_rst(tb_rst),
    .I_rate_sel_2hz(tb_rate_sel_2hz),
    .I_btn_brightness_up(tb_btn_brightness_up),
    .I_btn_brightness_down(tb_btn_brightness_down),
    .I_bcd0(tb_bcd0), .I_bcd1(tb_bcd1), .I_bcd2(tb_bcd2), .I_bcd3(tb_bcd3), .I_bcd4(tb_bcd4),
    .O_anode(tb_anode),
    .O_bcd_sel(tb_bcd_sel),
    .O_bcd_out(tb_bcd_out)
  );

  // ==== Clock generate ====
  always #(CLK_PERIOD/2) tb_clk = ~tb_clk;

  // ==== Task h? tr? ====
  task press_up;
    begin
      tb_btn_brightness_up = 1; # (10*CLK_PERIOD);
      tb_btn_brightness_up = 0; # (10*CLK_PERIOD);
    end
  endtask

  task press_down;
    begin
      tb_btn_brightness_down = 1; # (10*CLK_PERIOD);
      tb_btn_brightness_down = 0; # (10*CLK_PERIOD);
    end
  endtask

  // ==== Test sequence ====
  initial begin
    // Kh?i t?o
    tb_clk = 0;
    tb_rst = 1;
    tb_rate_sel_2hz = 0;
    tb_btn_brightness_up = 0;
    tb_btn_brightness_down = 0;
    tb_bcd0 = 4'd0; tb_bcd1 = 4'd1; tb_bcd2 = 4'd2; tb_bcd3 = 4'd3; tb_bcd4 = 4'd4;

    # (20*CLK_PERIOD);
    tb_rst = 0;

    // ===== 1. Test quét nhanh 240Hz =====
    $display("=== TEST: Fast scanning (240 Hz) ===");
    #(5_000*CLK_PERIOD);

    // ===== 2. Test quét ch?m 2Hz =====
    $display("=== TEST: Slow scanning (2 Hz) ===");
    tb_rate_sel_2hz = 1;
    #(5_000*CLK_PERIOD);
    tb_rate_sel_2hz = 0;

    // ===== 3. Test t?ng gi?m ?? sáng =====
    $display("=== TEST: Brightness control ===");
    press_down(); #(2_000*CLK_PERIOD);
    press_down(); #(2_000*CLK_PERIOD);
    press_down(); #(2_000*CLK_PERIOD);
    press_up();   #(2_000*CLK_PERIOD);
    press_up();   #(2_000*CLK_PERIOD);

    // ===== 4. Thay ??i d? li?u BCD =====
    $display("=== TEST: Change BCD values ===");
    tb_bcd0 = 4'd9;
    tb_bcd1 = 4'd8;
    tb_bcd2 = 4'd7;
    tb_bcd3 = 4'd6;
    tb_bcd4 = 4'd5;
    #(5_000*CLK_PERIOD);

    // ===== 5. Reset trong khi ch?y =====
    $display("=== TEST: Reset mid-way ===");
    tb_rst = 1;
    #(20*CLK_PERIOD);
    tb_rst = 0;
    #(5_000*CLK_PERIOD);

    $display("=== TEST DONE ===");
    $stop;
  end

endmodule
