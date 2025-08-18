`timescale 1ns/1ps

module seven_seg_controller_tb;
  // ==== Tham s? mô ph?ng nhanh ====
  localparam integer CLK_FREQ       = 1_000_000;  // 1 MHz ?? ch?y nhanh
  localparam integer ACTIVE_DIGITS  = 5;
  localparam integer FAST_HZ        = 10;         // quét c?m 10 Hz
  localparam integer SLOW_HZ        = 2;          // 2 Hz (gi? nguyên ý ngh?a)
  localparam integer PWM_FREQ       = 200;        // 200 Hz ?? th?y ???c PWM
  localparam integer PWM_BITS       = 8;

  // Chu k? clock 1 MHz = 1000 ns
  localparam real CLK_PERIOD_NS = 1000.0;

  // ==== I/O ====
  reg                     clk;
  reg                     rst;
  reg                     rate_sel_2hz;
  reg                     btn_brightness_up;
  reg                     btn_brightness_down;
  reg  [3:0]              bcd0, bcd1, bcd2, bcd3, bcd4;
  wire [ACTIVE_DIGITS-1:0] anode;     // [4:0]
  wire [2:0]              bcd_sel;
  wire [3:0]              bcd_out;

  // ==== DUT ====
  seven_seg_controller #(
    .CLK_FREQ        (CLK_FREQ),
    .ACTIVE_DIGITS   (ACTIVE_DIGITS),
    .FAST_HZ         (FAST_HZ),
    .SLOW_HZ         (SLOW_HZ),
    .PWM_FREQ        (PWM_FREQ),
    .PWM_BITS        (PWM_BITS),
    .BRIGHTNESS_LEVELS(4)
  ) dut (
    .clk                 (clk),
    .rst                 (rst),
    .rate_sel_2hz        (rate_sel_2hz),
    .btn_brightness_up   (btn_brightness_up),
    .btn_brightness_down (btn_brightness_down),
    .bcd0                (bcd0),
    .bcd1                (bcd1),
    .bcd2                (bcd2),
    .bcd3                (bcd3),
    .bcd4                (bcd4),
    .anode               (anode),
    .bcd_sel             (bcd_sel),
    .bcd_out             (bcd_out)
  );

  // ==== Clock ====
  initial begin
    clk = 1'b0;
    forever #(CLK_PERIOD_NS/2.0) clk = ~clk;
  end

  // ==== Stimulus ====
  initial begin
    // dump waves
//    $dumpfile("tb_seven_seg_controller.vcd");
//    $dumpvars(0, tb_seven_seg_controller);

    // init
    rst                  = 1'b1;
    rate_sel_2hz         = 1'b0;  // b?t ??u ? ch? ?? nhanh 10 Hz
    btn_brightness_up    = 1'b0;
    btn_brightness_down  = 1'b0;

    // set d? li?u BCD hi?n th?: 1 2 3 4 5
    bcd0 = 4'd1;
    bcd1 = 4'd2;
    bcd2 = 4'd3;
    bcd3 = 4'd4;
    bcd4 = 4'd5;

    // gi? reset m?t lúc
    #(10*CLK_PERIOD_NS);
    rst = 1'b0;

    // Ch? m?t lúc cho quét/PWM ch?y
    #(200_000); // 200 us

    // Nh?n t?ng sáng 2 l?n (one-shot bên trong controller, không c?n gi? lâu)
    press_up();
    #(50_000);
    press_up();
    #(100_000);

    // Nh?n gi?m sáng 1 l?n
    press_dn();
    #(100_000);

    // ??i sang ch? ?? ch?m (2 Hz)
    rate_sel_2hz = 1'b1;
    #(500_000); // 0.5 ms

    // ??i l?i nhanh
    rate_sel_2hz = 1'b0;
    #(500_000);

    // Thay ??i các digit m?t chút
    bcd0 = 4'd9;
    bcd1 = 4'd0;
    bcd2 = 4'd1;
    bcd3 = 4'd2;
    bcd4 = 4'd3;

    #(2_000_000); // 2 ms
    $display("TB finished");
    $finish;
  end

  // ==== Tasks ====
  task press_up();
    begin
      btn_brightness_up = 1'b1;
      #(3*CLK_PERIOD_NS);   // one-shot, không c?n dài
      btn_brightness_up = 1'b0;
    end
  endtask

  task press_dn();
    begin
      btn_brightness_down = 1'b1;
      #(3*CLK_PERIOD_NS);
      btn_brightness_down = 1'b0;
    end
  endtask

endmodule
