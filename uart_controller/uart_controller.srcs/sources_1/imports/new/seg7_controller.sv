`timescale 1ns / 1ps

module seg7_controller (
    input  wire        clk,
    input  wire        rst,
    input  wire [2:0]  mode,
    input  wire [15:0] accel_x,
    input  wire [15:0] accel_y,
    input  wire [15:0] accel_z,
    input  wire [7:0]  temp_data,
    input  wire [15:0] sw_data,
    input  wire [15:0] pc_data,
    output reg  [6:0]  seg,
    output reg         dp,
    output reg  [7:0]  an
);

    // ========================================
    // 7-Segment Encoding (Active Low)
    // ========================================
    //     a
    //    ---
    //   |   | b
    //  f|   |
    //    -g-
    //   |   | c
    //  e|   |
    //    ---
    //     d
    // seg = {g, f, e, d, c, b, a}
    
    function [6:0] encode_digit;
        input [3:0] val;
        begin
            case (val)
                4'd0:    encode_digit = 7'b1000000;  // 0
                4'd1:    encode_digit = 7'b1111001;  // 1
                4'd2:    encode_digit = 7'b0100100;  // 2
                4'd3:    encode_digit = 7'b0110000;  // 3
                4'd4:    encode_digit = 7'b0011001;  // 4
                4'd5:    encode_digit = 7'b0010010;  // 5
                4'd6:    encode_digit = 7'b0000010;  // 6
                4'd7:    encode_digit = 7'b1111000;  // 7
                4'd8:    encode_digit = 7'b0000000;  // 8
                4'd9:    encode_digit = 7'b0010000;  // 9
                4'd10:   encode_digit = 7'b0001000;  // A
                4'd11:   encode_digit = 7'b0000011;  // b
                4'd12:   encode_digit = 7'b1000110;  // C
                4'd13:   encode_digit = 7'b0100001;  // d
                4'd14:   encode_digit = 7'b0000110;  // E
                4'd15:   encode_digit = 7'b0001110;  // F
                default: encode_digit = 7'b1111111;  // Blank
            endcase
        end
    endfunction

    // Special character codes
    localparam [6:0] CHAR_BLANK = 7'b1111111;  // All off
    localparam [6:0] CHAR_MINUS = 7'b0111111;  // -
    localparam [6:0] CHAR_X     = 7'b0001001;  // X (like H)
    localparam [6:0] CHAR_Y     = 7'b0010001;  // Y
    localparam [6:0] CHAR_Z     = 7'b0100100;  // Z (like 2)
    localparam [6:0] CHAR_S     = 7'b0010010;  // S (like 5)
    localparam [6:0] CHAR_P     = 7'b0001100;  // P
    localparam [6:0] CHAR_C     = 7'b1000110;  // C
    localparam [6:0] CHAR_DEG   = 7'b0011100;  // ° (degree)
    localparam [6:0] CHAR_n     = 7'b0101011;  // n
    localparam [6:0] CHAR_o     = 7'b0100011;  // o
    localparam [6:0] CHAR_L     = 7'b1000111;  // L
    localparam [6:0] CHAR_E     = 7'b0000110;  // E
    localparam [6:0] CHAR_d     = 7'b0100001;  // d
    localparam [6:0] CHAR_A     = 7'b0001000;  // A

    // ========================================
    // Scan Counter for Multiplexing
    // ========================================
    // Refresh rate: 100MHz / 2^18 ? 381 Hz per digit
    // Total refresh:  381 / 8 ? 48 Hz (no flicker)
    
    reg [17:0] scan_cnt;
    wire [2:0] digit_sel;
    
    always @(posedge clk) begin
        if (rst)
            scan_cnt <= 18'd0;
        else
            scan_cnt <= scan_cnt + 1'b1;
    end
    
    assign digit_sel = scan_cnt[17:15];

    // ========================================
    // Sub-mode Cycling Counter (500ms period)
    // ========================================
    reg [25:0] cycle_cnt;
    reg [1:0]  sub_mode;
    
    always @(posedge clk) begin
        if (rst) begin
            cycle_cnt <= 26'd0;
            sub_mode  <= 2'd0;
        end else begin
            if (cycle_cnt == 26'd49_999_999) begin  // 500ms at 100MHz
                cycle_cnt <= 26'd0;
                sub_mode  <= sub_mode + 1'b1;
            end else begin
                cycle_cnt <= cycle_cnt + 1'b1;
            end
        end
    end

    // ========================================
    // Accelerometer Data Processing
    // ========================================
    // Convert 12-bit signed to absolute value
    
    wire signed [11:0] x_signed = {accel_x[11:8], accel_x[7:0]};
    wire signed [11:0] y_signed = {accel_y[11:8], accel_y[7:0]};
    wire signed [11:0] z_signed = {accel_z[11:8], accel_z[7:0]};
    
    wire x_negative = x_signed[11];
    wire y_negative = y_signed[11];
    wire z_negative = z_signed[11];
    
    wire [11:0] x_abs = x_negative ? (~x_signed + 1'b1) : x_signed;
    wire [11:0] y_abs = y_negative ? (~y_signed + 1'b1) : y_signed;
    wire [11:0] z_abs = z_negative ? (~z_signed + 1'b1) : z_signed;

    // BCD conversion for accelerometer (0-999)
    wire [3:0] x_hundreds = (x_abs / 100) % 10;
    wire [3:0] x_tens     = (x_abs / 10) % 10;
    wire [3:0] x_ones     = x_abs % 10;
    
    wire [3:0] y_hundreds = (y_abs / 100) % 10;
    wire [3:0] y_tens     = (y_abs / 10) % 10;
    wire [3:0] y_ones     = y_abs % 10;
    
    wire [3:0] z_hundreds = (z_abs / 100) % 10;
    wire [3:0] z_tens     = (z_abs / 10) % 10;
    wire [3:0] z_ones     = z_abs % 10;

    // ========================================
    // Temperature Data Processing
    // ========================================
    // temp_data is Q6.2 format:  0.25°C per LSB
    // Multiply by 25 to get centi-degrees (xx.xx format)
    
    wire [13:0] temp_centi = temp_data * 8'd25;
    wire [6:0]  temp_int   = temp_centi / 100;    // Integer part (0-63)
    wire [6:0]  temp_frac  = temp_centi % 100;    // Fractional part (0-99)
    
    wire [3:0] temp_int_tens  = (temp_int / 10) % 10;
    wire [3:0] temp_int_ones  = temp_int % 10;
    wire [3:0] temp_frac_tens = (temp_frac / 10) % 10;
    wire [3:0] temp_frac_ones = temp_frac % 10;

    // ========================================
    // Display Registers
    // ========================================
    reg [6:0] seg_next;
    reg       dp_next;
    reg [7:0] an_next;

    // ========================================
    // Main Display Logic
    // ========================================
    always @(*) begin
        // Default values
        seg_next = CHAR_BLANK;
        dp_next  = 1'b1;  // DP off (active low)
        an_next  = 8'b11111111;  // All off

        case (mode)
            // ============================================
            // MODE 0: Accelerometer (Cycle X ? Y ? Z)
            // Display format: "0X -xxx" or "0Y -xxx" or "0Z -xxx"
            // ============================================
            3'd0: begin
                case (sub_mode)
                    // --- Show X ---
                    2'd0: begin
                        case (digit_sel)
                            3'd0: begin  // Ones
                                an_next  = 8'b11111110;
                                seg_next = encode_digit(x_ones);
                            end
                            3'd1: begin  // Tens
                                an_next  = 8'b11111101;
                                seg_next = encode_digit(x_tens);
                            end
                            3'd2: begin  // Hundreds
                                an_next  = 8'b11111011;
                                seg_next = encode_digit(x_hundreds);
                            end
                            3'd3: begin  // Sign
                                an_next  = 8'b11110111;
                                seg_next = x_negative ? CHAR_MINUS : CHAR_BLANK;
                            end
                            3'd4: begin  // Blank
                                an_next  = 8'b11101111;
                                seg_next = CHAR_BLANK;
                            end
                            3'd5: begin  // Blank
                                an_next  = 8'b11011111;
                                seg_next = CHAR_BLANK;
                            end
                            3'd6: begin  // 'X'
                                an_next  = 8'b10111111;
                                seg_next = CHAR_X;
                            end
                            3'd7: begin  // Mode '0'
                                an_next  = 8'b01111111;
                                seg_next = encode_digit(4'd0);
                            end
                        endcase
                    end
                    
                    // --- Show Y ---
                    2'd1: begin
                        case (digit_sel)
                            3'd0: begin
                                an_next  = 8'b11111110;
                                seg_next = encode_digit(y_ones);
                            end
                            3'd1: begin
                                an_next  = 8'b11111101;
                                seg_next = encode_digit(y_tens);
                            end
                            3'd2: begin
                                an_next  = 8'b11111011;
                                seg_next = encode_digit(y_hundreds);
                            end
                            3'd3: begin
                                an_next  = 8'b11110111;
                                seg_next = y_negative ?  CHAR_MINUS : CHAR_BLANK;
                            end
                            3'd4: begin
                                an_next  = 8'b11101111;
                                seg_next = CHAR_BLANK;
                            end
                            3'd5: begin
                                an_next  = 8'b11011111;
                                seg_next = CHAR_BLANK;
                            end
                            3'd6: begin
                                an_next  = 8'b10111111;
                                seg_next = CHAR_Y;
                            end
                            3'd7: begin
                                an_next  = 8'b01111111;
                                seg_next = encode_digit(4'd0);
                            end
                        endcase
                    end
                    
                    // --- Show Z ---
                    2'd2, 2'd3: begin
                        case (digit_sel)
                            3'd0: begin
                                an_next  = 8'b11111110;
                                seg_next = encode_digit(z_ones);
                            end
                            3'd1: begin
                                an_next  = 8'b11111101;
                                seg_next = encode_digit(z_tens);
                            end
                            3'd2: begin
                                an_next  = 8'b11111011;
                                seg_next = encode_digit(z_hundreds);
                            end
                            3'd3: begin
                                an_next  = 8'b11110111;
                                seg_next = z_negative ?  CHAR_MINUS :  CHAR_BLANK;
                            end
                            3'd4: begin
                                an_next  = 8'b11101111;
                                seg_next = CHAR_BLANK;
                            end
                            3'd5: begin
                                an_next  = 8'b11011111;
                                seg_next = CHAR_BLANK;
                            end
                            3'd6: begin
                                an_next  = 8'b10111111;
                                seg_next = CHAR_Z;
                            end
                            3'd7: begin
                                an_next  = 8'b01111111;
                                seg_next = encode_digit(4'd0);
                            end
                        endcase
                    end
                endcase
            end

            // ============================================
            // MODE 1: Temperature
            // Display format:  "1  xx.xx°C"
            // ============================================
            3'd1: begin
                case (digit_sel)
                    3'd0: begin  // 'C'
                        an_next  = 8'b11111110;
                        seg_next = CHAR_C;
                    end
                    3'd1: begin  // Degree symbol
                        an_next  = 8'b11111101;
                        seg_next = CHAR_DEG;
                    end
                    3'd2: begin  // Fractional ones
                        an_next  = 8'b11111011;
                        seg_next = encode_digit(temp_frac_ones);
                    end
                    3'd3: begin  // Fractional tens
                        an_next  = 8'b11110111;
                        seg_next = encode_digit(temp_frac_tens);
                    end
                    3'd4: begin  // Integer ones (with decimal point)
                        an_next  = 8'b11101111;
                        seg_next = encode_digit(temp_int_ones);
                        dp_next  = 1'b0;  // DP on
                    end
                    3'd5: begin  // Integer tens
                        an_next  = 8'b11011111;
                        seg_next = encode_digit(temp_int_tens);
                    end
                    3'd6: begin  // Blank
                        an_next  = 8'b10111111;
                        seg_next = CHAR_BLANK;
                    end
                    3'd7: begin  // Mode '1'
                        an_next  = 8'b01111111;
                        seg_next = encode_digit(4'd1);
                    end
                endcase
            end

            // ============================================
            // MODE 2: Switch ? LED
            // Display format: "2S  HHHH" (hex value)
            // ============================================
            3'd2: begin
                case (digit_sel)
                    3'd0: begin  // Hex digit 0 (LSB)
                        an_next  = 8'b11111110;
                        seg_next = encode_digit(sw_data[3:0]);
                    end
                    3'd1: begin  // Hex digit 1
                        an_next  = 8'b11111101;
                        seg_next = encode_digit(sw_data[7:4]);
                    end
                    3'd2: begin  // Hex digit 2
                        an_next  = 8'b11111011;
                        seg_next = encode_digit(sw_data[11:8]);
                    end
                    3'd3: begin  // Hex digit 3 (MSB)
                        an_next  = 8'b11110111;
                        seg_next = encode_digit(sw_data[15:12]);
                    end
                    3'd4: begin  // Blank
                        an_next  = 8'b11101111;
                        seg_next = CHAR_BLANK;
                    end
                    3'd5: begin  // Blank
                        an_next  = 8'b11011111;
                        seg_next = CHAR_BLANK;
                    end
                    3'd6: begin  // 'S' for Switch
                        an_next  = 8'b10111111;
                        seg_next = CHAR_S;
                    end
                    3'd7: begin  // Mode '2'
                        an_next  = 8'b01111111;
                        seg_next = encode_digit(4'd2);
                    end
                endcase
            end

            // ============================================
            // MODE 3: PC ? LED
            // Display format: "3P  HHHH" (hex value from PC)
            // ============================================
            3'd3: begin
                case (digit_sel)
                    3'd0: begin  // Hex digit 0 (LSB)
                        an_next  = 8'b11111110;
                        seg_next = encode_digit(pc_data[3:0]);
                    end
                    3'd1: begin  // Hex digit 1
                        an_next  = 8'b11111101;
                        seg_next = encode_digit(pc_data[7:4]);
                    end
                    3'd2: begin  // Hex digit 2
                        an_next  = 8'b11111011;
                        seg_next = encode_digit(pc_data[11:8]);
                    end
                    3'd3: begin  // Hex digit 3 (MSB)
                        an_next  = 8'b11110111;
                        seg_next = encode_digit(pc_data[15:12]);
                    end
                    3'd4: begin  // Blank
                        an_next  = 8'b11101111;
                        seg_next = CHAR_BLANK;
                    end
                    3'd5: begin  // Blank
                        an_next  = 8'b11011111;
                        seg_next = CHAR_BLANK;
                    end
                    3'd6: begin  // 'P' for PC
                        an_next  = 8'b10111111;
                        seg_next = CHAR_P;
                    end
                    3'd7: begin  // Mode '3'
                        an_next  = 8'b01111111;
                        seg_next = encode_digit(4'd3);
                    end
                endcase
            end

            // ============================================
            // MODE 4: Combined (Auto Cycle All)
            // Cycles:  Accel X ? Accel Y ? Temp ? Switch ? PC
            // ============================================
            3'd4: begin
                case (sub_mode)
                    // --- Show Accelerometer X ---
                    2'd0: begin
                        case (digit_sel)
                            3'd0: begin
                                an_next  = 8'b11111110;
                                seg_next = encode_digit(x_ones);
                            end
                            3'd1: begin
                                an_next  = 8'b11111101;
                                seg_next = encode_digit(x_tens);
                            end
                            3'd2: begin
                                an_next  = 8'b11111011;
                                seg_next = encode_digit(x_hundreds);
                            end
                            3'd3: begin
                                an_next  = 8'b11110111;
                                seg_next = x_negative ? CHAR_MINUS : CHAR_BLANK;
                            end
                            3'd4: begin
                                an_next  = 8'b11101111;
                                seg_next = CHAR_BLANK;
                            end
                            3'd5: begin
                                an_next  = 8'b11011111;
                                seg_next = CHAR_X;
                            end
                            3'd6: begin
                                an_next  = 8'b10111111;
                                seg_next = CHAR_A;  // 'A' for Accel
                            end
                            3'd7: begin
                                an_next  = 8'b01111111;
                                seg_next = encode_digit(4'd4);
                            end
                        endcase
                    end
                    
                    // --- Show Temperature ---
                    2'd1: begin
                        case (digit_sel)
                            3'd0: begin
                                an_next  = 8'b11111110;
                                seg_next = CHAR_C;
                            end
                            3'd1: begin
                                an_next  = 8'b11111101;
                                seg_next = CHAR_DEG;
                            end
                            3'd2: begin
                                an_next  = 8'b11111011;
                                seg_next = encode_digit(temp_frac_ones);
                            end
                            3'd3: begin
                                an_next  = 8'b11110111;
                                seg_next = encode_digit(temp_frac_tens);
                            end
                            3'd4: begin
                                an_next  = 8'b11101111;
                                seg_next = encode_digit(temp_int_ones);
                                dp_next  = 1'b0;
                            end
                            3'd5: begin
                                an_next  = 8'b11011111;
                                seg_next = encode_digit(temp_int_tens);
                            end
                            3'd6: begin
                                an_next  = 8'b10111111;
                                seg_next = CHAR_BLANK;
                            end
                            3'd7: begin
                                an_next  = 8'b01111111;
                                seg_next = encode_digit(4'd4);
                            end
                        endcase
                    end
                    
                    // --- Show Switch ---
                    2'd2: begin
                        case (digit_sel)
                            3'd0: begin
                                an_next  = 8'b11111110;
                                seg_next = encode_digit(sw_data[3:0]);
                            end
                            3'd1: begin
                                an_next  = 8'b11111101;
                                seg_next = encode_digit(sw_data[7:4]);
                            end
                            3'd2: begin
                                an_next  = 8'b11111011;
                                seg_next = encode_digit(sw_data[11:8]);
                            end
                            3'd3: begin
                                an_next  = 8'b11110111;
                                seg_next = encode_digit(sw_data[15:12]);
                            end
                            3'd4: begin
                                an_next  = 8'b11101111;
                                seg_next = CHAR_BLANK;
                            end
                            3'd5: begin
                                an_next  = 8'b11011111;
                                seg_next = CHAR_S;
                            end
                            3'd6: begin
                                an_next  = 8'b10111111;
                                seg_next = CHAR_BLANK;
                            end
                            3'd7: begin
                                an_next  = 8'b01111111;
                                seg_next = encode_digit(4'd4);
                            end
                        endcase
                    end
                    
                    // --- Show PC Data ---
                    2'd3: begin
                        case (digit_sel)
                            3'd0: begin
                                an_next  = 8'b11111110;
                                seg_next = encode_digit(pc_data[3:0]);
                            end
                            3'd1: begin
                                an_next  = 8'b11111101;
                                seg_next = encode_digit(pc_data[7:4]);
                            end
                            3'd2: begin
                                an_next  = 8'b11111011;
                                seg_next = encode_digit(pc_data[11:8]);
                            end
                            3'd3: begin
                                an_next  = 8'b11110111;
                                seg_next = encode_digit(pc_data[15:12]);
                            end
                            3'd4: begin
                                an_next  = 8'b11101111;
                                seg_next = CHAR_BLANK;
                            end
                            3'd5: begin
                                an_next  = 8'b11011111;
                                seg_next = CHAR_P;
                            end
                            3'd6: begin
                                an_next  = 8'b10111111;
                                seg_next = CHAR_BLANK;
                            end
                            3'd7: begin
                                an_next  = 8'b01111111;
                                seg_next = encode_digit(4'd4);
                            end
                        endcase
                    end
                endcase
            end

            // ============================================
            // DEFAULT:  Show "--------"
            // ============================================
            default: begin
                an_next  = ~(8'b1 << digit_sel);
                seg_next = CHAR_MINUS;
            end
        endcase
    end

    // ========================================
    // Output Registers
    // ========================================
    always @(posedge clk) begin
        if (rst) begin
            seg <= CHAR_BLANK;
            dp  <= 1'b1;
            an  <= 8'b11111111;
        end else begin
            seg <= seg_next;
            dp  <= dp_next;
            an  <= an_next;
        end
    end

endmodule