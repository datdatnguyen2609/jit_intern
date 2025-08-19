`timescale 1ns/1ps
// Testbench ng?n g?n, Verilog-2001 thu?n

module bcd2led7seg_top_tb;

  // ===== Tham s? mô ph?ng nhanh =====
  parameter TB_CLK_FREQ     = 1_000_000;                 // 1 MHz
  parameter TB_DEB_MS       = 1;                         // 1 ms
  parameter CLK_PERIOD_NS   = 1_000_000_000 / TB_CLK_FREQ;
  parameter MS              = 1_000_000;                 // 1 ms = 1,000,000 ns

  // ===== I/O =====
  reg         I_clk;
  reg         I_rst;
  reg  [15:0] I_sw;
  reg         I_btn_brightness_up;
  reg         I_btn_brightness_down;
  wire [7:0]  O_seg_out;
  wire [4:0]  O_anode;
  wire [2:0]  O_anode_off;

  // ===== DUT =====
  bcd2led7seg_top #(
    .CLK_FREQ         (TB_CLK_FREQ),
    .DEBOUNCE_TIME_MS (TB_DEB_MS)
  ) dut (
    .I_clk                 (I_clk),
    .I_rst                 (I_rst),
    .I_sw                  (I_sw),
    .I_btn_brightness_up   (I_btn_brightness_up),
    .I_btn_brightness_down (I_btn_brightness_down),
    .O_seg_out             (O_seg_out),
    .O_anode               (O_anode),
    .O_anode_off           (O_anode_off)
  );

  // ===== Clock =====
  initial begin
    I_clk = 1'b0;
    forever #(CLK_PERIOD_NS/2) I_clk = ~I_clk;
  end

  // ===== Log g?n khi ngõ ra ??i =====
  reg [4:0] anode_q; reg [7:0] seg_q;
  initial begin anode_q = 5'bxxxxx; seg_q = 8'hxx; end
  always @(posedge I_clk) begin
    if (O_anode !== anode_q || O_seg_out !== seg_q) begin
      $display("[%0t ns] anode=%b seg=%b anode_off=%b",
               $time, O_anode, O_seg_out, O_anode_off);
      anode_q <= O_anode; seg_q <= O_seg_out;
    end
  end

  // ===== Tasks c? b?n =====
  task wait_ms; input integer ms; integer k; begin for (k=0;k<ms;k=k+1) #(MS); end endtask
  task press_up_ms; input integer ms; begin I_btn_brightness_up=1;  wait_ms(ms); I_btn_brightness_up=0;  end endtask
  task press_dn_ms; input integer ms; begin I_btn_brightness_down=1;wait_ms(ms); I_btn_brightness_down=0; end endtask

  // Bounce ??n gi?n: nh?p nhanh < debounce
  task press_up_bounce; input integer total_ms; input integer pulse_ns;
    integer t; begin
      t = total_ms*MS;
      while (t>0) begin I_btn_brightness_up=~I_btn_brightness_up; #(pulse_ns); t=t-pulse_ns; end
      I_btn_brightness_up=0;
    end
  endtask
  task press_dn_bounce; input integer total_ms; input integer pulse_ns;
    integer t; begin
      t = total_ms*MS;
      while (t>0) begin I_btn_brightness_down=~I_btn_brightness_down; #(pulse_ns); t=t-pulse_ns; end
      I_btn_brightness_down=0;
    end
  endtask

  // ===== Stimulus =====
  initial begin
    // Kh?i t?o
    I_rst = 1; I_sw = 16'd0;
    I_btn_brightness_up = 0; I_btn_brightness_down = 0;
    #(10*CLK_PERIOD_NS); I_rst = 0;
    wait_ms(2);

    // Hi?n th? 12345, quét nhanh
    I_sw[14:0] = 15'd12345; I_sw[15] = 0; wait_ms(5);

    // T?ng sáng 2 l?n (> debounce), r?i gi?m 1 l?n
    press_up_ms(TB_DEB_MS+2); wait_ms(2);
    press_up_ms(TB_DEB_MS+2); wait_ms(2);
    press_dn_ms(TB_DEB_MS+2); wait_ms(2);

    // Bounce (không nên tác d?ng vì < debounce)
    press_up_bounce(TB_DEB_MS, CLK_PERIOD_NS/4); wait_ms(2);
    press_dn_bounce(TB_DEB_MS, CLK_PERIOD_NS/3); wait_ms(2);

    // Chuy?n sang quét ch?m
    I_sw[15] = 1; wait_ms(5);

    // ??i d? li?u trong khi ?ang quét ch?m
    I_sw[14:0] = 15'd9876; wait_ms(5);

    // Quay l?i quét nhanh, th? max biên
    I_sw[15] = 0; wait_ms(3);
    I_sw[14:0] = 15'd0;    wait_ms(3);
    I_sw[14:0] = 15'd9999; wait_ms(3);
    I_sw[14:0] = 15'd32767;wait_ms(3);

    // Nh?n ??ng th?i hai nút
    I_btn_brightness_up = 1; I_btn_brightness_down = 1;
    wait_ms(TB_DEB_MS+2);
    I_btn_brightness_up = 0; I_btn_brightness_down = 0;
    wait_ms(3);

    // Reset gi?a ch?ng
    I_rst = 1; wait_ms(2); I_rst = 0; wait_ms(3);

    // M?t vài m?u ng?u nhiên (dùng $random)
    begin : RAND_LOOP
      integer i; reg [14:0] r; reg mode;
      for (i=0;i<6;i=i+1) begin
        r = $random; mode = $random;
        I_sw[14:0] = r; I_sw[15] = mode;
        wait_ms(4);
      end
    end

    $display("TB finished.");
    $finish;
  end

endmodule
