`timescale 1ns / 1ps

module top (
    input         top_i_clk,
    input         top_i_rst,      // nut reset (muc cao = reset)

    output        top_o_csn,
    output        top_o_sclk,
    output        top_o_mosi,
    input         top_i_miso,

    output [15:0] top_o_led,      // 16 LED don
    output [6:0]  top_o_seg,      // {g,f,e,d,c,b,a}, active low
    output [7:0]  top_o_an        // AN7..AN0, active low
);

    // =========================================
    // 1) Debounce reset
    // =========================================
    wire w_rst_sync;
    debounce #(.CLK_FREQ(100_000_000), .DEBOUNCE_TIME_MS(20)) u_db_rst (
        .I_clk    (top_i_clk),
        .I_rst    (1'b0),
        .I_btn_in (top_i_rst),
        .O_btn_out(w_rst_sync)
    );

    // =========================================
    // 2) SPI controller ADXL362
    // =========================================
    wire       w_csn;
    wire [7:0] w_din;
    wire       w_din_valid;

    reg        r_spi_ready;
    reg [7:0]  r_spi_inst;
    reg        r_spi_sel_rw;   // 0 = WRITE, 1 = READ
    reg [7:0]  r_spi_addr;
    reg [7:0]  r_spi_dout;

    spi_adxl362_controller u_spi (
        .i_clk      (top_i_clk),
        .i_rst      (w_rst_sync),
        .o_csn      (w_csn),
        .o_sclk     (top_o_sclk),
        .o_mosi     (top_o_mosi),
        .i_miso     (top_i_miso),

        .i_ready    (r_spi_ready),   // pulse
        .i_inst     (r_spi_inst),    // 0x0A WRITE, 0x0B READ
        .i_sel_rw   (r_spi_sel_rw),  // 0 = WRITE, 1 = READ
        .i_reg_addr (r_spi_addr),
        .i_dout     (r_spi_dout),
        .o_din      (w_din),
        .o_din_valid(w_din_valid)
    );

    assign top_o_csn = w_csn;

    // Theo doi canh CSN de biet giao dich xong
    reg r_csn_q;
    always @(posedge top_i_clk) begin
        if (w_rst_sync) r_csn_q <= 1'b1;
        else            r_csn_q <= w_csn;
    end
    wire w_csn_rise = (~r_csn_q) & w_csn;   // CSN 0->1

    // =========================================
    // 3) FSM doc X Y Z, sau do hien thi
    //     1 s hien X
    //     1 s hien Y va Z dong thoi
    // =========================================
    localparam S_INIT_POWER_START  = 4'd0;
    localparam S_INIT_POWER_WAIT   = 4'd1;
    localparam S_READ_X_LOW_START  = 4'd2;
    localparam S_READ_X_LOW_WAIT   = 4'd3;
    localparam S_READ_X_HIGH_START = 4'd4;
    localparam S_READ_X_HIGH_WAIT  = 4'd5;
    localparam S_READ_Y_LOW_START  = 4'd6;
    localparam S_READ_Y_LOW_WAIT   = 4'd7;
    localparam S_READ_Y_HIGH_START = 4'd8;
    localparam S_READ_Y_HIGH_WAIT  = 4'd9;
    localparam S_READ_Z_LOW_START  = 4'd10;
    localparam S_READ_Z_LOW_WAIT   = 4'd11;
    localparam S_READ_Z_HIGH_START = 4'd12;
    localparam S_READ_Z_HIGH_WAIT  = 4'd13;
    localparam S_HOLD_X            = 4'd14;
    localparam S_HOLD_YZ           = 4'd15;

    reg [3:0]  r_state;

    // Ma truc de encode chu X Y Z
    localparam [1:0] AXIS_X = 2'd0;
    localparam [1:0] AXIS_Y = 2'd1;
    localparam [1:0] AXIS_Z = 2'd2;

    // Du lieu moi nhat cua tung kenh
    reg [15:0] r_data_x;
    reg [15:0] r_data_y;
    reg [15:0] r_data_z;

    // Thanh ghi tam doc SPI 16 bit
    reg [15:0] r_axis_data;

    // dem 1 s
    // 100 MHz, 1 s = 100 000 000 xung
    reg [26:0] hold_cnt;

    // che do hien thi
    // 0  hien thi X
    // 1  hien thi Y va Z dong thoi
    reg        r_disp_mode;

    // FSM
    always @(posedge top_i_clk) begin
        if (w_rst_sync) begin
            r_state       <= S_INIT_POWER_START;

            r_spi_ready   <= 1'b0;
            r_spi_inst    <= 8'h0A;   // mac dinh WRITE
            r_spi_sel_rw  <= 1'b0;
            r_spi_addr    <= 8'h00;
            r_spi_dout    <= 8'h00;

            r_data_x      <= 16'h0000;
            r_data_y      <= 16'h0000;
            r_data_z      <= 16'h0000;
            r_axis_data   <= 16'h0000;

            hold_cnt      <= 27'd0;
            r_disp_mode   <= 1'b0;   // hien X truoc
        end else begin
            r_spi_ready <= 1'b0;     // mac dinh 0, chi set 1 trong state START

            case (r_state)
                // Cau hinh POWER_CTL
                S_INIT_POWER_START: begin
                    r_spi_inst    <= 8'h0A;      // WRITE
                    r_spi_sel_rw  <= 1'b0;
                    r_spi_addr    <= 8'h2D;      // POWER_CTL
                    r_spi_dout    <= 8'h02;      // Measurement mode
                    r_spi_ready   <= 1'b1;       // pulse 1 chu ky
                    r_state       <= S_INIT_POWER_WAIT;
                end

                S_INIT_POWER_WAIT: begin
                    if (w_csn_rise) begin
                        r_state <= S_READ_X_LOW_START;
                    end
                end

                // Doc X_L (0x0E)
                S_READ_X_LOW_START: begin
                    r_spi_inst    <= 8'h0B;      // READ
                    r_spi_sel_rw  <= 1'b1;
                    r_spi_addr    <= 8'h0E;      // X_L
                    r_spi_dout    <= 8'h00;
                    r_spi_ready   <= 1'b1;
                    r_state       <= S_READ_X_LOW_WAIT;
                end

                S_READ_X_LOW_WAIT: begin
                    if (w_din_valid) begin
                        r_axis_data[7:0] <= w_din;
                    end
                    if (w_csn_rise) begin
                        r_state <= S_READ_X_HIGH_START;
                    end
                end

                // Doc X_H (0x0F)
                S_READ_X_HIGH_START: begin
                    r_spi_inst    <= 8'h0B;      // READ
                    r_spi_sel_rw  <= 1'b1;
                    r_spi_addr    <= 8'h0F;      // X_H
                    r_spi_dout    <= 8'h00;
                    r_spi_ready   <= 1'b1;
                    r_state       <= S_READ_X_HIGH_WAIT;
                end

                S_READ_X_HIGH_WAIT: begin
                    if (w_din_valid) begin
                        r_axis_data[15:8] <= w_din;
                    end
                    if (w_csn_rise) begin
                        r_data_x <= r_axis_data;
                        r_state  <= S_READ_Y_LOW_START;
                    end
                end

                // Doc Y_L (0x10)
                S_READ_Y_LOW_START: begin
                    r_spi_inst    <= 8'h0B;      // READ
                    r_spi_sel_rw  <= 1'b1;
                    r_spi_addr    <= 8'h10;      // Y_L
                    r_spi_dout    <= 8'h00;
                    r_spi_ready   <= 1'b1;
                    r_state       <= S_READ_Y_LOW_WAIT;
                end

                S_READ_Y_LOW_WAIT: begin
                    if (w_din_valid) begin
                        r_axis_data[7:0] <= w_din;
                    end
                    if (w_csn_rise) begin
                        r_state <= S_READ_Y_HIGH_START;
                    end
                end

                // Doc Y_H (0x11)
                S_READ_Y_HIGH_START: begin
                    r_spi_inst    <= 8'h0B;      // READ
                    r_spi_sel_rw  <= 1'b1;
                    r_spi_addr    <= 8'h11;      // Y_H
                    r_spi_dout    <= 8'h00;
                    r_spi_ready   <= 1'b1;
                    r_state       <= S_READ_Y_HIGH_WAIT;
                end

                S_READ_Y_HIGH_WAIT: begin
                    if (w_din_valid) begin
                        r_axis_data[15:8] <= w_din;
                    end
                    if (w_csn_rise) begin
                        r_data_y <= r_axis_data;
                        r_state  <= S_READ_Z_LOW_START;
                    end
                end

                // Doc Z_L (0x12)
                S_READ_Z_LOW_START: begin
                    r_spi_inst    <= 8'h0B;      // READ
                    r_spi_sel_rw  <= 1'b1;
                    r_spi_addr    <= 8'h12;      // Z_L
                    r_spi_dout    <= 8'h00;
                    r_spi_ready   <= 1'b1;
                    r_state       <= S_READ_Z_LOW_WAIT;
                end

                S_READ_Z_LOW_WAIT: begin
                    if (w_din_valid) begin
                        r_axis_data[7:0] <= w_din;
                    end
                    if (w_csn_rise) begin
                        r_state <= S_READ_Z_HIGH_START;
                    end
                end

                // Doc Z_H (0x13)
                S_READ_Z_HIGH_START: begin
                    r_spi_inst    <= 8'h0B;      // READ
                    r_spi_sel_rw  <= 1'b1;
                    r_spi_addr    <= 8'h13;      // Z_H
                    r_spi_dout    <= 8'h00;
                    r_spi_ready   <= 1'b1;
                    r_state       <= S_READ_Z_HIGH_WAIT;
                end

                S_READ_Z_HIGH_WAIT: begin
                    if (w_din_valid) begin
                        r_axis_data[15:8] <= w_din;
                    end
                    if (w_csn_rise) begin
                        r_data_z    <= r_axis_data;
                        hold_cnt    <= 27'd0;
                        r_disp_mode <= 1'b0;     // bat dau hien X
                        r_state     <= S_HOLD_X;
                    end
                end

                // Giu X trong 1 s
                S_HOLD_X: begin
                    if (hold_cnt == 27'd99_999_999) begin
                        hold_cnt    <= 27'd0;
                        r_disp_mode <= 1'b1;     // chuyen sang hien Y va Z
                        r_state     <= S_HOLD_YZ;
                    end else begin
                        hold_cnt    <= hold_cnt + 27'd1;
                    end
                end

                // Giu Y va Z trong 1 s
                S_HOLD_YZ: begin
                    if (hold_cnt == 27'd99_999_999) begin
                        hold_cnt    <= 27'd0;
                        r_disp_mode <= 1'b0;     // lan sau lai bat dau bang X
                        r_state     <= S_READ_X_LOW_START;
                    end else begin
                        hold_cnt    <= hold_cnt + 27'd1;
                    end
                end

                default: begin
                    r_state <= S_INIT_POWER_START;
                end
            endcase
        end
    end

    // =========================================
    // 4) Chuyen doi X Y Z 16 bit bu 2 -> sign + |ACC| 0..1024 -> goc do 0..90
    //    Lap lai cho 3 kenh, dung 3 LUT
    // =========================================

    // X
    wire [7:0]  x_l   = r_data_x[7:0];
    wire [7:0]  x_h   = r_data_x[15:8];
    wire signed [11:0] x_12 = {x_h[3:0], x_l};           // 12 bit bu 2
    wire signed [12:0] x_13 = {x_12[11], x_12};          // sign extend
    wire               x_sign_neg = x_13[12];
    wire [12:0]        x_abs = x_sign_neg ? (~x_13 + 13'd1) : x_13;
    wire [10:0]        x_acc_1024 = (x_abs > 13'd1024) ? 11'd1024
                                                       : x_abs[10:0];
    wire [6:0]         x_angle_mag;

    acc_scaled_to_deg u_acc2deg_x (
        .ACC_IN (x_acc_1024),
        .DEG    (x_angle_mag)
    );

    // Y
    wire [7:0]  y_l   = r_data_y[7:0];
    wire [7:0]  y_h   = r_data_y[15:8];
    wire signed [11:0] y_12 = {y_h[3:0], y_l};
    wire signed [12:0] y_13 = {y_12[11], y_12};
    wire               y_sign_neg = y_13[12];
    wire [12:0]        y_abs = y_sign_neg ? (~y_13 + 13'd1) : y_13;
    wire [10:0]        y_acc_1024 = (y_abs > 13'd1024) ? 11'd1024
                                                       : y_abs[10:0];
    wire [6:0]         y_angle_mag;

    acc_scaled_to_deg u_acc2deg_y (
        .ACC_IN (y_acc_1024),
        .DEG    (y_angle_mag)
    );

    // Z
    wire [7:0]  z_l   = r_data_z[7:0];
    wire [7:0]  z_h   = r_data_z[15:8];
    wire signed [11:0] z_12 = {z_h[3:0], z_l};
    wire signed [12:0] z_13 = {z_12[11], z_12};
    wire               z_sign_neg = z_13[12];
    wire [12:0]        z_abs = z_sign_neg ? (~z_13 + 13'd1) : z_13;
    wire [10:0]        z_acc_1024 = (z_abs > 13'd1024) ? 11'd1024
                                                       : z_abs[10:0];
    wire [6:0]         z_angle_mag;

    acc_scaled_to_deg u_acc2deg_z (
        .ACC_IN (z_acc_1024),
        .DEG    (z_angle_mag)
    );

    // =========================================
    // 5) Dua goc X ra 16 LED
    // bit 15 lam bit dau X 0 = duong 1 = am
    // =========================================
    assign top_o_led = {x_sign_neg, 8'd0, x_angle_mag};

    // =========================================
    // 6) Hien thi len 8 led 7 thanh Nexys A7
    // Giai doan 1  1 s  hien X tren 4 digit phai
    //   AN0  don vi X
    //   AN1  chuc X
    //   AN2  dau X
    //   AN3  chu X
    //   AN4..AN7 tat
    //
    // Giai doan 2  1 s  hien Y va Z dong thoi
    //   AN7..AN4 hien Y   [Y][dau][chuc][don vi]
    //   AN3..AN0 hien Z   [Z][dau][chuc][don vi]
    // =========================================
    wire [6:0] x_deg_val = x_angle_mag; // 0..90
    wire [6:0] y_deg_val = y_angle_mag;
    wire [6:0] z_deg_val = z_angle_mag;

    wire [3:0] x_bcd_tens = x_deg_val / 10;
    wire [3:0] x_bcd_ones = x_deg_val % 10;

    wire [3:0] y_bcd_tens = y_deg_val / 10;
    wire [3:0] y_bcd_ones = y_deg_val % 10;

    wire [3:0] z_bcd_tens = z_deg_val / 10;
    wire [3:0] z_bcd_ones = z_deg_val % 10;

    // Encoder 7 seg so, output gfedcba, active low
    function [6:0] seg7_encode_digit;
        input [3:0] b;
        begin
            case (b)
                4'd0: seg7_encode_digit = 7'b1000000; // 0
                4'd1: seg7_encode_digit = 7'b1111001; // 1
                4'd2: seg7_encode_digit = 7'b0100100; // 2
                4'd3: seg7_encode_digit = 7'b0110000; // 3
                4'd4: seg7_encode_digit = 7'b0011001; // 4
                4'd5: seg7_encode_digit = 7'b0010010; // 5
                4'd6: seg7_encode_digit = 7'b0000010; // 6
                4'd7: seg7_encode_digit = 7'b1111000; // 7
                4'd8: seg7_encode_digit = 7'b0000000; // 8
                4'd9: seg7_encode_digit = 7'b0010000; // 9
                default: seg7_encode_digit = 7'b1111111; // tat
            endcase
        end
    endfunction

    // Encode chu X Y Z tren 7 seg
    function [6:0] seg7_encode_axis;
        input [1:0] axis;
        begin
            case (axis)
                AXIS_X: seg7_encode_axis = 7'b0001001; // X
                AXIS_Y: seg7_encode_axis = 7'b0010001; // Y
                AXIS_Z: seg7_encode_axis = 7'b0100100; // Z na na so 2
                default:seg7_encode_axis = 7'b1111111;
            endcase
        end
    endfunction

    // Pattern dau tru "-"
    localparam [6:0] SEG_MINUS = 7'b0111111; // chi sang segment g

    // Bo chia tan quet 7 seg, 8 digit
    reg [16:0] scan_cnt;
    always @(posedge top_i_clk) begin
        if (w_rst_sync)
            scan_cnt <= 17'd0;
        else
            scan_cnt <= scan_cnt + 17'd1;
    end

    wire [2:0] digit_sel = scan_cnt[16:14]; // 0..7

    reg [6:0] seg_out;
    reg [7:0] an_out;

    always @(*) begin
        seg_out = 7'b1111111;
        an_out  = 8'b1111_1111;

        if (r_disp_mode == 1'b0) begin
            // Che do hien X 4 digit phai
            case (digit_sel)
                3'd0: begin
                    // AN0  don vi X
                    seg_out = seg7_encode_digit(x_bcd_ones);
                    an_out  = 8'b1111_1110;
                end
                3'd1: begin
                    // AN1  chuc X
                    seg_out = seg7_encode_digit(x_bcd_tens);
                    an_out  = 8'b1111_1101;
                end
                3'd2: begin
                    // AN2  dau X
                    if (x_sign_neg) begin
                        seg_out = SEG_MINUS;
                    end else begin
                        seg_out = 7'b1111111; // trong
                    end
                    an_out  = 8'b1111_1011;
                end
                3'd3: begin
                    // AN3  chu X
                    seg_out = seg7_encode_axis(AXIS_X);
                    an_out  = 8'b1111_0111;
                end
                default: begin
                    seg_out = 7'b1111111;
                    an_out  = 8'b1111_1111;
                end
            endcase
        end else begin
            // Che do hien Y va Z dong thoi
            case (digit_sel)
                // Z ben phai  AN3..AN0  [Z][dau][chuc][don vi]
                3'd0: begin
                    // AN0  don vi Z
                    seg_out = seg7_encode_digit(z_bcd_ones);
                    an_out  = 8'b1111_1110;
                end
                3'd1: begin
                    // AN1  chuc Z
                    seg_out = seg7_encode_digit(z_bcd_tens);
                    an_out  = 8'b1111_1101;
                end
                3'd2: begin
                    // AN2  dau Z
                    if (z_sign_neg) begin
                        seg_out = SEG_MINUS;
                    end else begin
                        seg_out = 7'b1111111;
                    end
                    an_out  = 8'b1111_1011;
                end
                3'd3: begin
                    // AN3  chu Z
                    seg_out = seg7_encode_axis(AXIS_Z);
                    an_out  = 8'b1111_0111;
                end

                // Y ben trai  AN7..AN4  [Y][dau][chuc][don vi]
                3'd4: begin
                    // AN4  don vi Y
                    seg_out = seg7_encode_digit(y_bcd_ones);
                    an_out  = 8'b1110_1111;
                end
                3'd5: begin
                    // AN5  chuc Y
                    seg_out = seg7_encode_digit(y_bcd_tens);
                    an_out  = 8'b1101_1111;
                end
                3'd6: begin
                    // AN6  dau Y
                    if (y_sign_neg) begin
                        seg_out = SEG_MINUS;
                    end else begin
                        seg_out = 7'b1111111;
                    end
                    an_out  = 8'b1011_1111;
                end
                3'd7: begin
                    // AN7  chu Y
                    seg_out = seg7_encode_axis(AXIS_Y);
                    an_out  = 8'b0111_1111;
                end
            endcase
        end
    end

    assign top_o_seg = seg_out;  // gfedcba
    assign top_o_an  = an_out;

endmodule
