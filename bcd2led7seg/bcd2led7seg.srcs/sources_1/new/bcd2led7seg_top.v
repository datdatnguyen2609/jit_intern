module bcd2led7seg_top #(
    parameter integer CLK_FREQ          = 100_000_000,
    parameter integer DEBOUNCE_TIME_MS  = 20
)(
    input  wire        I_clk,
    input  wire        I_rst,
    input  wire [15:0] I_sw,
    input  wire        I_btn_brightness_up,
    input  wire        I_btn_brightness_down,
    output reg  [7:0]  O_seg_out,   // <- reg để chốt đồng bộ
    output reg  [4:0]  O_anode,     // <- reg để chốt đồng bộ
    output reg  [2:0]  O_anode_off  // reg để điều khiển trong always
);
  // ============================================================================
  // Tín hiệu nội bộ
  // ============================================================================
  wire [15:0] W_sw_db;
  wire        W_btn_up_db, W_btn_dn_db;
  wire [3:0]  W_bcd0, W_bcd1, W_bcd2, W_bcd3, W_bcd4;
  wire [3:0]  W_bcd_digit;
  wire [2:0]  W_bcd_sel;
  wire [19:0] W_bcd_bus;

  // Tín hiệu thô từ controller/converter trước khi chốt ra cổng
  wire [4:0]  W_anode_raw;
  wire [7:0]  W_seg_out_raw;

  // ============================================================================
  // O_anode_off đồng bộ (giữ 3'b111 - active-low: tắt 3 anode phụ nếu cần)
  // ============================================================================
  always @(posedge I_clk) begin
    if (I_rst)
      O_anode_off <= 3'b111;
    else
      O_anode_off <= 3'b111; // luôn giữ mức này; thay đổi tại đây nếu muốn logic khác
  end

  // ============================================================================
  // Debounce cho 16 công tắc I_sw[15:0]
  // ============================================================================
  genvar i;
  generate
    for (i = 0; i < 16; i = i + 1) begin : GEN_SW_DB
      debounce #(
        .CLK_FREQ         (CLK_FREQ),
        .DEBOUNCE_TIME_MS (DEBOUNCE_TIME_MS)
      ) u_db_sw (
        .I_clk     (I_clk),
        .I_rst     (I_rst),
        .I_btn_in  (I_sw[i]),
        .O_btn_out (W_sw_db[i])
      );
    end
  endgenerate

  // Debounce cho 2 nút tăng/giảm độ sáng
  debounce #(
    .CLK_FREQ         (CLK_FREQ),
    .DEBOUNCE_TIME_MS (DEBOUNCE_TIME_MS)
  ) u_db_up (
    .I_clk     (I_clk),
    .I_rst     (I_rst),
    .I_btn_in  (I_btn_brightness_up),
    .O_btn_out (W_btn_up_db)
  );

  debounce #(
    .CLK_FREQ         (CLK_FREQ),
    .DEBOUNCE_TIME_MS (DEBOUNCE_TIME_MS)
  ) u_db_dn (
    .I_clk     (I_clk),
    .I_rst     (I_rst),
    .I_btn_in  (I_btn_brightness_down),
    .O_btn_out (W_btn_dn_db)
  );

  // ============================================================================
  // Binary -> 5 BCD digits (dùng 15 bit dữ liệu: W_sw_db[14:0])
  // ============================================================================
  bin_to_bcd u_bin_to_bcd (
    .I_clk (I_clk),
    .I_rst (I_rst),
    .I_data(W_sw_db[14:0]),
    .O_bit0(W_bcd0),
    .O_bit1(W_bcd1),
    .O_bit2(W_bcd2),
    .O_bit3(W_bcd3),
    .O_bit4(W_bcd4),
    .O_BCD (W_bcd_bus)
  );

  // ============================================================================
  // Seven-seg controller (PWM 8-bit + one-shot nút bên trong)
  // ============================================================================
  seven_seg_controller #(
    .CLK_FREQ          (CLK_FREQ),
    .ACTIVE_DIGITS     (5),
    .FAST_HZ           (240),
    .SLOW_HZ           (2),
    .PWM_FREQ          (1000),
    .PWM_BITS          (8),
    .BRIGHTNESS_LEVELS (4)
  ) u_ssc (
    .I_clk                 (I_clk),
    .I_rst                 (I_rst),
    .I_rate_sel_2hz        (W_sw_db[15]),    // 0=240Hz, 1=2Hz
    .I_btn_brightness_up   (W_btn_up_db),
    .I_btn_brightness_down (W_btn_dn_db),
    .I_bcd0                (W_bcd0),
    .I_bcd1                (W_bcd1),
    .I_bcd2                (W_bcd2),
    .I_bcd3                (W_bcd3),
    .I_bcd4                (W_bcd4),
    .O_anode               (W_anode_raw),    // ra wire thô
    .O_bcd_sel             (W_bcd_sel),
    .O_bcd_out             (W_bcd_digit)
  );

  // ============================================================================
  // BCD 4-bit -> 7-seg (active-low)
  // ============================================================================
  seven_seg_converter u_seg_conv (
    .I_clk    (I_clk),
    .I_rst    (I_rst),
    .I_value  (W_bcd_digit),
    .O_seg_out(W_seg_out_raw)        // ra wire thô
  );

  // ============================================================================
  // Chốt đồng bộ ra cổng: O_anode, O_seg_out
  // ============================================================================
  always @(posedge I_clk) begin
    if (I_rst) begin
      O_anode   <= 5'b11111;         // tắt hết (active-low)
      O_seg_out <= ~8'b00000000;     // off
    end else begin
      O_anode   <= W_anode_raw;
      O_seg_out <= W_seg_out_raw;
    end
  end

endmodule
