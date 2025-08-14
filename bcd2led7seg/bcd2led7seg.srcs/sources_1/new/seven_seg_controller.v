module seven_seg_controller (
    input  wire        clk,
    input  wire        rst,
    input  wire        rate_sel_2hz,              // 0: 240 Hz, 1: 2 Hz
    input  wire [3:0]  bcd0, bcd1, bcd2, bcd3, bcd4,  // 5 BCD Digits
    output reg  [4:0]  anode,                     // active-low
    output reg  [2:0]  bcd_sel,                   // 0..4 -> 0
    output reg  [3:0]  bcd_out                    // bcd selected
);
    // parameter
    parameter integer CLK_FREQ      = 100_000_000;
    parameter integer ACTIVE_DIGITS = 5;           // scan (0..4)
    // 2 mode refresh rate
    localparam integer FAST_HZ = 240;
    localparam integer SLOW_HZ = 2;

    // Calculated the clock that need to counting Hz
    localparam integer COUNT_MAX_FAST = CLK_FREQ / (FAST_HZ * ACTIVE_DIGITS);
    localparam integer COUNT_MAX_SLOW = CLK_FREQ / (SLOW_HZ * ACTIVE_DIGITS);

    // Width of the counter
    localparam integer CNTR_BITS = (COUNT_MAX_SLOW <= 1) ? 1 : $clog2(COUNT_MAX_SLOW);

    reg  [CNTR_BITS-1:0] refresh_counter = {CNTR_BITS{1'b0}};
    reg  [2:0]           digit_index     = 3'd0;   // 0..ACTIVE_DIGITS-1

    // Select counter
    wire [CNTR_BITS-1:0] count_max_cur =
            rate_sel_2hz ? COUNT_MAX_SLOW[CNTR_BITS-1:0] : COUNT_MAX_FAST[CNTR_BITS-1:0];

    // Tick 
    wire tick = (refresh_counter >= (count_max_cur - 1));

    // Next digit (0..ACTIVE_DIGITS-1)
    wire [2:0] next_idx =
            (digit_index == ACTIVE_DIGITS-1) ? 3'd0 : (digit_index + 3'd1);

    // Counter + digit select
    always @(posedge clk) begin
        if (rst) begin
            refresh_counter <= {CNTR_BITS{1'b0}};
            digit_index     <= 3'd0;
            bcd_sel         <= 3'd0;
            bcd_out         <= bcd0;
        end else begin
            if (tick) begin
                refresh_counter <= {CNTR_BITS{1'b0}};
                digit_index     <= next_idx;
                bcd_sel         <= next_idx;

                // bcd_out case
                case (next_idx)
                    3'd0: bcd_out <= bcd0;
                    3'd1: bcd_out <= bcd1;
                    3'd2: bcd_out <= bcd2;
                    3'd3: bcd_out <= bcd3;
                    3'd4: bcd_out <= bcd4;
                    default: bcd_out <= 4'd0; // not use
                endcase
            end else begin
                refresh_counter <= refresh_counter + {{(CNTR_BITS-1){1'b0}}, 1'b1};
            end
        end
    end

    // Anode's chooosing
    always @* begin
        anode = 5'b11111;
        anode[digit_index] = 1'b0;   // only ON 1 7seg_led in a moment
    end

endmodule
