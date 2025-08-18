module seven_seg_controller #(
    // ===== Parameters =====
    parameter integer CLK_FREQ           = 100_000_000,
    parameter integer ACTIVE_DIGITS      = 5,      // số chữ số quét (5)
    // Tốc độ quét cụm
    parameter integer FAST_HZ            = 240,
    parameter integer SLOW_HZ            = 2,
    // PWM
    parameter integer PWM_FREQ           = 1000,   // 1 kHz
    parameter integer PWM_BITS           = 8,      // độ phân giải 8-bit
    // Số mức sáng
    parameter integer BRIGHTNESS_LEVELS  = 4
  )(
    input  wire                          I_clk,
    input  wire                          I_rst,                   // reset đồng bộ
    input  wire                          I_rate_sel_2hz,          // 0: 240 Hz, 1: 2 Hz
    input  wire                          I_btn_brightness_up,     // nút tăng sáng (đã debounced)
    input  wire                          I_btn_brightness_down,   // nút giảm sáng (đã debounced)
    input  wire [3:0]                    I_bcd0, I_bcd1, I_bcd2, I_bcd3, I_bcd4,  // 5 digit BCD
    output reg  [ACTIVE_DIGITS-1:0]      O_anode,       // active-low with PWM
    output reg  [2:0]                    O_bcd_sel,     // 0..4
    output reg  [3:0]                    O_bcd_out      // bcd được chọn
  );
  // ===== Derived constants =====
  localparam integer COUNT_MAX_FAST = CLK_FREQ / (FAST_HZ * ACTIVE_DIGITS);
  localparam integer COUNT_MAX_SLOW = CLK_FREQ / (SLOW_HZ * ACTIVE_DIGITS);

  // Bề rộng counter (chọn theo nhánh chậm để đủ bit)
  localparam integer CNTR_BITS =
             (COUNT_MAX_SLOW <= 1) ? 1 : $clog2(COUNT_MAX_SLOW);

  // PWM
  localparam integer PWM_COUNT_MAX = CLK_FREQ / PWM_FREQ; // 100_000 với 100MHz/1kHz
  localparam integer PWM_CNT_BITS  =
             (PWM_COUNT_MAX <= 1) ? 1 : $clog2(PWM_COUNT_MAX);

  // ===== Registers / wires =====
  reg  [CNTR_BITS-1:0]          R_refresh_counter = {CNTR_BITS{1'b0}};
  reg  [2:0]                    R_digit_index     = 3'd0; // 0..ACTIVE_DIGITS-1

  // One-shot cho nút
  reg                           R_up_d1, R_dn_d1;
  wire                          W_up_rise = I_btn_brightness_up   & ~R_up_d1;
  wire                          W_dn_rise = I_btn_brightness_down & ~R_dn_d1;

  // Độ sáng
  reg  [1:0]                    R_brightness_level = 2'd3;          // 0..3 (mặc định MAX)
  reg  [PWM_BITS-1:0]           R_brightness_duty  = {PWM_BITS{1'b1}}; // 0..255

  // PWM counter
  reg  [PWM_CNT_BITS-1:0]       R_pwm_counter = {PWM_CNT_BITS{1'b0}};

  // Chọn count_max hiện tại theo mode
  wire [CNTR_BITS-1:0]          W_count_max_cur =
       I_rate_sel_2hz ? COUNT_MAX_SLOW[CNTR_BITS-1:0]
       : COUNT_MAX_FAST[CNTR_BITS-1:0];

  // Tick quét chữ số (>= để an toàn khi đổi mode giữa chừng)
  wire                          W_tick     = (R_refresh_counter >= (W_count_max_cur - 1));
  wire [2:0]                    W_next_idx = (R_digit_index == ACTIVE_DIGITS-1) ? 3'd0
       : (R_digit_index + 3'd1);

  // Nhân để tính duty_count theo duty 0..(2^PWM_BITS-1)
  wire [PWM_CNT_BITS+PWM_BITS-1:0] W_mult_full  = R_brightness_duty * PWM_COUNT_MAX;
  wire [PWM_CNT_BITS-1:0]          W_duty_count = W_mult_full >> PWM_BITS;

  // PWM output: high khi trong khoảng duty
  wire                          W_pwm_out = (R_pwm_counter < W_duty_count);

  // Blanking tại ranh giới chuyển digit để giảm ghosting
  reg                           R_blanking = 1'b0;

  // anode_select: one-hot active-low tại digit_index
  reg  [ACTIVE_DIGITS-1:0]      R_anode_select;

  // =========================
  // PWM counter (đồng bộ)
  // =========================
  always @(posedge I_clk)
  begin
    if (I_rst)
    begin
      R_pwm_counter <= {PWM_CNT_BITS{1'b0}};
    end
    else
    begin
      if (R_pwm_counter >= (PWM_COUNT_MAX - 1))
        R_pwm_counter <= {PWM_CNT_BITS{1'b0}};
      else
        R_pwm_counter <= R_pwm_counter + {{(PWM_CNT_BITS-1){1'b0}},1'b1};
    end
  end

  // ===================================
  // Điều khiển mức sáng + one-shot nút
  // ===================================
  always @(posedge I_clk)
  begin
    if (I_rst)
    begin
      R_up_d1            <= 1'b0;
      R_dn_d1            <= 1'b0;
      R_brightness_level <= 2'd3;
      R_brightness_duty  <= {PWM_BITS{1'b1}}; // 8'hFF
    end
    else
    begin
      // chốt trạng thái nút (edge detect)
      R_up_d1 <= I_btn_brightness_up;
      R_dn_d1 <= I_btn_brightness_down;

      // tăng/giảm theo sườn lên
      if (W_up_rise && (R_brightness_level < BRIGHTNESS_LEVELS-1))
        R_brightness_level <= R_brightness_level + 2'd1;
      else if (W_dn_rise && (R_brightness_level > 2'd0))
        R_brightness_level <= R_brightness_level - 2'd1;

      // ánh xạ level -> duty (25/50/75/100%)
      case (R_brightness_level)
        2'd0:
          R_brightness_duty <= (1<<PWM_BITS)/4;        // ~25%  (64 với 8-bit)
        2'd1:
          R_brightness_duty <= (1<<PWM_BITS)/2;        // ~50%  (128)
        2'd2:
          R_brightness_duty <= (3*(1<<PWM_BITS))/4;    // ~75%  (192)
        2'd3:
          R_brightness_duty <= {PWM_BITS{1'b1}};       // 100%  (255)
        default:
          R_brightness_duty <= {PWM_BITS{1'b1}};
      endcase
    end
  end

  // =========================
  // Quét & chọn BCD (đồng bộ)
  // =========================
  always @(posedge I_clk)
  begin
    if (I_rst)
    begin
      R_refresh_counter <= {CNTR_BITS{1'b0}};
      R_digit_index     <= 3'd0;
      O_bcd_sel         <= 3'd0;
      O_bcd_out         <= I_bcd0;
      R_blanking        <= 1'b0;
    end
    else
    begin
      if (W_tick)
      begin
        R_refresh_counter <= {CNTR_BITS{1'b0}};
        R_digit_index     <= W_next_idx;
        O_bcd_sel         <= W_next_idx;

        // Ánh xạ BCD theo next_idx
        case (W_next_idx)
          3'd0:
            O_bcd_out <= I_bcd0;
          3'd1:
            O_bcd_out <= I_bcd1;
          3'd2:
            O_bcd_out <= I_bcd2;
          3'd3:
            O_bcd_out <= I_bcd3;
          3'd4:
            O_bcd_out <= I_bcd4;
          default:
            O_bcd_out <= 4'd0;
        endcase

        R_blanking <= 1'b1; // bật blanking đúng 1 chu kỳ clock
      end
      else
      begin
        R_refresh_counter <= R_refresh_counter + {{(CNTR_BITS-1){1'b0}},1'b1};
        R_blanking        <= 1'b0;
      end
    end
  end

  // ==========================================
  // Tạo anode_select one-hot (đồng bộ)
  // ==========================================
  always @(posedge I_clk)
  begin
    if (I_rst)
    begin
      R_anode_select <= {ACTIVE_DIGITS{1'b1}};
    end
    else
    begin
      R_anode_select <= {ACTIVE_DIGITS{1'b1}};          // tất cả off (active-low)
      if (R_digit_index < ACTIVE_DIGITS)
        R_anode_select[R_digit_index] <= 1'b0;        // bật digit đang quét
    end
  end

  // ==========================================
  // Áp PWM + blanking để tạo O_anode (đồng bộ)
  // ==========================================
  always @(posedge I_clk)
  begin
    if (I_rst)
    begin
      O_anode <= {ACTIVE_DIGITS{1'b1}};
    end
    else
    begin
      if (!R_blanking && W_pwm_out)
        O_anode <= R_anode_select;
      else
        O_anode <= {ACTIVE_DIGITS{1'b1}};
    end
  end

endmodule
