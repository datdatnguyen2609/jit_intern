`timescale 1ns/1ps

module bcd2led7seg_top_tb;
  // ===== Tham s? mô ph?ng nhanh =====
  localparam integer TB_CLK_FREQ       = 1_000_000;   // 1 MHz
  localparam integer TB_DEBOUNCE_MS    = 1;           // 1 ms
  localparam integer CLK_PERIOD_NS     = 1_000_000_000 / TB_CLK_FREQ; // 1000 ns
  localparam integer MS                = 1_000_000;   // 1 ms = 1,000,000 ns

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
    .DEBOUNCE_TIME_MS (TB_DEBOUNCE_MS)
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
    forever #(CLK_PERIOD_NS/2) I_clk = ~I_clk; // 1 MHz
  end

  // ===== Quan sát thay ??i ?? in log g?n =====
  reg [4:0] anode_q;
  reg [7:0] seg_q;
  initial begin anode_q = 5'bxxxxx; seg_q = 8'hxx; end

  always @(posedge I_clk) begin
    if (O_anode !== anode_q || O_seg_out !== seg_q) begin
      $display("[%0t ns] anode=%b seg=%b anode_off=%b",
               $time, O_anode, O_seg_out, O_anode_off);
      anode_q <= O_anode;
      seg_q   <= O_seg_out;
    end
  end

  // ===== Stimulus =====
  initial begin
//    $dumpfile("tb_bcd2led7seg_top.vcd");
//    $dumpvars(0, tb_bcd2led7seg_top);

    // Kh?i t?o
    I_rst                 = 1'b1;
    I_sw                  = 16'd0;
    I_btn_brightness_up   = 1'b0;
    I_btn_brightness_down = 1'b0;

    // Gi? reset m?t lúc
    #(10*CLK_PERIOD_NS);
    I_rst = 1'b0;

    // ??t d? li?u hi?n th?: 12345, quét nhanh (sw[15]=0)
    I_sw[14:0] = 15'd12345;
    I_sw[15]   = 1'b0;
    #(5*MS); // ch? qua debounce

    // Nh?n t?ng sáng 2 l?n (m?i l?n gi? > debounce)
    press_up_ms(3);
    #(3*MS);
    press_up_ms(3);
    #(3*MS);

    // Nh?n gi?m sáng 1 l?n
    press_dn_ms(3);
    #(3*MS);

    // Chuy?n sang quét ch?m
    I_sw[15] = 1'b1;
    #(5*MS);

    // ??i d? li?u hi?n th?: 9876
    I_sw[14:0] = 15'd9876;
    #(5*MS);

    // Quay l?i quét nhanh
    I_sw[15] = 1'b0;
    #(5*MS);

    // Nh?n t?ng sáng thêm 1 l?n
    press_up_ms(2);
    #(10*MS);

    $display("TB finished.");
    $finish;
  end

  // ===== Tasks =====
  task press_up_ms(input integer ms);
    integer k;
    begin
      I_btn_brightness_up = 1'b1;
      for (k = 0; k < ms; k = k + 1) #(MS);
      I_btn_brightness_up = 1'b0;
    end
  endtask

  task press_dn_ms(input integer ms);
    integer k;
    begin
      I_btn_brightness_down = 1'b1;
      for (k = 0; k < ms; k = k + 1) #(MS);
      I_btn_brightness_down = 1'b0;
    end
  endtask

endmodule
