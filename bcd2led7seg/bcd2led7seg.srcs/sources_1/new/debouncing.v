module debounce #(
    parameter integer CLK_FREQ          = 100_000_000,
    parameter integer DEBOUNCE_TIME_MS  = 20
  )(
    input  wire I_clk,
    input  wire I_rst,      // reset đồng bộ
    input  wire I_btn_in,
    output reg  O_btn_out
  );
  // Số chu kỳ cần ổn định liên tục để chấp nhận trạng thái mới
  localparam integer COUNT_MAX      = (CLK_FREQ / 1000) * DEBOUNCE_TIME_MS;
  localparam integer COUNTER_WIDTH  = (COUNT_MAX <= 1) ? 1 : $clog2(COUNT_MAX);

  // Đồng bộ hóa tín hiệu async vào clock domain
  reg R_btn_sync_0 = 1'b0, R_btn_sync_1 = 1'b0;

  // Trạng thái đã debounce + bộ đếm thời gian ổn định
  reg [COUNTER_WIDTH:0] R_counter   = { (COUNTER_WIDTH+1){1'b0} };
  reg                   R_btn_state = 1'b0;

  // 2-flop synchronizer (reset đồng bộ)
  always @(posedge I_clk)
  begin
    if (I_rst)
    begin
      R_btn_sync_0 <= 1'b0;
      R_btn_sync_1 <= 1'b0;
    end
    else
    begin
      R_btn_sync_0 <= I_btn_in;
      R_btn_sync_1 <= R_btn_sync_0;
    end
  end

  // Debounce: yêu cầu mức mới phải giữ ổn định COUNT_MAX chu kỳ
  always @(posedge I_clk)
  begin
    if (I_rst)
    begin
      R_counter   <= { (COUNTER_WIDTH+1){1'b0} };
      R_btn_state <= 1'b0;
      O_btn_out   <= 1'b0;
    end
    else
    begin
      if (R_btn_sync_1 != R_btn_state)
      begin
        // Đang có xu hướng đổi trạng thái: đếm thời gian ổn định
        if (R_counter >= COUNT_MAX-1)
        begin
          R_btn_state <= R_btn_sync_1;
          O_btn_out   <= R_btn_sync_1;  // cập nhật đầu ra khi đủ lâu
          R_counter   <= { (COUNTER_WIDTH+1){1'b0} };
        end
        else
        begin
          R_counter <= R_counter + {{COUNTER_WIDTH{1'b0}}, 1'b1};
        end
      end
      else
      begin
        // Không đổi trạng thái: reset bộ đếm, giữ đầu ra bằng trạng thái ổn định
        R_counter <= { (COUNTER_WIDTH+1){1'b0} };
        O_btn_out <= R_btn_state;
      end
    end
  end
endmodule
