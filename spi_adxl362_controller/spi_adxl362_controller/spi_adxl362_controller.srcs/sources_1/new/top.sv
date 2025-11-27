`timescale 1ns / 1ps

module top (
    input         top_i_clk,
    input         top_i_rst,      // nut reset muc cao

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
    debounce #(
        .CLK_FREQ(100_000_000),
        .DEBOUNCE_TIME_MS(20)
    ) u_db_rst (
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

        .i_ready    (r_spi_ready),
        .i_inst     (r_spi_inst),
        .i_sel_rw   (r_spi_sel_rw),
        .i_reg_addr (r_spi_addr),
        .i_dout     (r_spi_dout),
        .o_din      (w_din),
        .o_din_valid(w_din_valid)
    );

    assign top_o_csn = w_csn;

    // Phat hien canh len CSN
    reg w_csn_d;
    always @(posedge top_i_clk) begin
        if (w_rst_sync) begin
            w_csn_d <= 1'b1;
        end else begin
            w_csn_d <= w_csn;
        end
    end
    wire w_csn_rise = (w_csn_d == 1'b0) && (w_csn == 1'b1);

    // =========================================
    // 3) FSM cau hinh ADXL362 va doc du lieu X Y Z
    // =========================================
    localparam S_INIT_POWER_START   = 4'd0;
    localparam S_INIT_POWER_WAIT    = 4'd1;
    localparam S_INIT_RANGE_START   = 4'd2;
    localparam S_INIT_RANGE_WAIT    = 4'd3;
    localparam S_WAIT_HOLD          = 4'd4;
    localparam S_READ_X_LOW_WAIT    = 4'd5;
    localparam S_READ_X_HIGH_WAIT   = 4'd6;
    localparam S_READ_Y_LOW_WAIT    = 4'd7;
    localparam S_READ_Y_HIGH_WAIT   = 4'd8;
    localparam S_READ_Z_LOW_WAIT    = 4'd9;
    localparam S_READ_Z_HIGH_WAIT   = 4'd10;

    reg [3:0]  r_state;

    reg [15:0] r_data_x;
    reg [15:0] r_data_y;
    reg [15:0] r_data_z;
    reg [15:0] r_axis_data;

    reg [26:0] hold_cnt;
    reg        r_disp_mode;   // 0 hien X, 1 hien Y va Z

    always @(posedge top_i_clk) begin
        if (w_rst_sync) begin
            r_state       <= S_INIT_POWER_START;

            r_spi_ready   <= 1'b0;
            r_spi_inst    <= 8'h0A;
            r_spi_sel_rw  <= 1'b0;
            r_spi_addr    <= 8'h00;
            r_spi_dout    <= 8'h00;

            r_data_x      <= 16'h0000;
            r_data_y      <= 16'h0000;
            r_data_z      <= 16'h0000;
            r_axis_data   <= 16'h0000;

            hold_cnt      <= 27'd0;
            r_disp_mode   <= 1'b0;
        end else begin
            r_spi_ready <= 1'b0;

            case (r_state)
                // Cau hinh POWER_CTL
                S_INIT_POWER_START: begin
                    r_spi_inst    <= 8'h0A;      // WRITE
                    r_spi_sel_rw  <= 1'b0;
                    r_spi_addr    <= 8'h2D;      // POWER_CTL
                    r_spi_dout    <= 8'h02;      // Measurement mode
                    r_spi_ready   <= 1'b1;
                    r_state       <= S_INIT_POWER_WAIT;
                end

                S_INIT_POWER_WAIT: begin
                    if (w_csn_rise) begin
                        r_state <= S_INIT_RANGE_START;
                    end
                end

                // Cau hinh RANGE, FILTER_CTL
                S_INIT_RANGE_START: begin
                    r_spi_inst    <= 8'h0A;      // WRITE
                    r_spi_sel_rw  <= 1'b0;
                    r_spi_addr    <= 8'h2C;      // FILTER_CTL
                    r_spi_dout    <= 8'h13;      // 2 g, 100 Hz
                    r_spi_ready   <= 1'b1;
                    r_state       <= S_INIT_RANGE_WAIT;
                end

                S_INIT_RANGE_WAIT: begin
                    if (w_csn_rise) begin
                        r_state   <= S_WAIT_HOLD;
                        hold_cnt  <= 27'd0;
                    end
                end

                // Cho 1 s roi doc lai X Y Z
                S_WAIT_HOLD: begin
                    hold_cnt <= hold_cnt + 1'b1;
                    if (hold_cnt == 27'd100_000_000) begin
                        hold_cnt    <= 27'd0;
                        r_disp_mode <= ~r_disp_mode;

                        // Bat dau doc X_L
                        r_spi_inst    <= 8'h0B;  // READ
                        r_spi_sel_rw  <= 1'b1;
                        r_spi_addr    <= 8'h0E;  // X_L
                        r_spi_dout    <= 8'h00;
                        r_spi_ready   <= 1'b1;
                        r_state       <= S_READ_X_LOW_WAIT;
                    end
                end

                // Doc X
                S_READ_X_LOW_WAIT: begin
                    if (w_din_valid) begin
                        r_axis_data[7:0] <= w_din;
                    end
                    if (w_csn_rise) begin
                        r_spi_inst    <= 8'h0B;
                        r_spi_sel_rw  <= 1'b1;
                        r_spi_addr    <= 8'h0F;  // X_H
                        r_spi_dout    <= 8'h00;
                        r_spi_ready   <= 1'b1;
                        r_state       <= S_READ_X_HIGH_WAIT;
                    end
                end

                S_READ_X_HIGH_WAIT: begin
                    if (w_din_valid) begin
                        r_axis_data[15:8] <= w_din;
                    end
                    if (w_csn_rise) begin
                        r_data_x    <= r_axis_data;
                        // doc Y_L
                        r_spi_inst    <= 8'h0B;
                        r_spi_sel_rw  <= 1'b1;
                        r_spi_addr    <= 8'h10;  // Y_L
                        r_spi_dout    <= 8'h00;
                        r_spi_ready   <= 1'b1;
                        r_state       <= S_READ_Y_LOW_WAIT;
                    end
                end

                // Doc Y
                S_READ_Y_LOW_WAIT: begin
                    if (w_din_valid) begin
                        r_axis_data[7:0] <= w_din;
                    end
                    if (w_csn_rise) begin
                        r_spi_inst    <= 8'h0B;
                        r_spi_sel_rw  <= 1'b1;
                        r_spi_addr    <= 8'h11;  // Y_H
                        r_spi_dout    <= 8'h00;
                        r_spi_ready   <= 1'b1;
                        r_state       <= S_READ_Y_HIGH_WAIT;
                    end
                end

                S_READ_Y_HIGH_WAIT: begin
                    if (w_din_valid) begin
                        r_axis_data[15:8] <= w_din;
                    end
                    if (w_csn_rise) begin
                        r_data_y    <= r_axis_data;
                        // doc Z_L
                        r_spi_inst    <= 8'h0B;
                        r_spi_sel_rw  <= 1'b1;
                        r_spi_addr    <= 8'h12;  // Z_L
                        r_spi_dout    <= 8'h00;
                        r_spi_ready   <= 1'b1;
                        r_state       <= S_READ_Z_LOW_WAIT;
                    end
                end

                // Doc Z
                S_READ_Z_LOW_WAIT: begin
                    if (w_din_valid) begin
                        r_axis_data[7:0] <= w_din;
                    end
                    if (w_csn_rise) begin
                        r_spi_inst    <= 8'h0B;
                        r_spi_sel_rw  <= 1'b1;
                        r_spi_addr    <= 8'h13;  // Z_H
                        r_spi_dout    <= 8'h00;
                        r_spi_ready   <= 1'b1;
                        r_state       <= S_READ_Z_HIGH_WAIT;
                    end
                end

                S_READ_Z_HIGH_WAIT: begin
                    if (w_din_valid) begin
                        r_axis_data[15:8] <= w_din;
                    end
                    if (w_csn_rise) begin
                        r_data_z    <= r_axis_data;
                        r_state     <= S_WAIT_HOLD;
                    end
                end

                default: begin
                    r_state <= S_INIT_POWER_START;
                end
            endcase
        end
    end

    // =========================================
    // 4) Chuyen doi X Y Z 16 bit bu 2 -> |ACC| (clip 1312) -> LUT goc
    // =========================================

    // X
    wire [7:0]  x_l   = r_data_x[7:0];
    wire [7:0]  x_h   = r_data_x[15:8];
    wire signed [11:0] x_12 = {x_h[3:0], x_l};
    wire signed [12:0] x_13 = {x_12[11], x_12};
    wire               x_sign_neg = x_13[12];
    wire [12:0]        x_abs = x_sign_neg ? (~x_13 + 13'd1) : x_13;

    // clip len 1312
    wire [10:0]        x_acc_1312 = (x_abs > 13'd1312) ? 11'd1312
                                                       : x_abs[10:0];

    wire [6:0] x_angle_xy_pos;
    wire [6:0] x_angle_x_neg;
    wire [6:0] x_angle_mag;

    acc_scaled_to_deg_xy_pos u_acc2deg_x_pos (
        .ACC_IN (x_acc_1312),
        .DEG    (x_angle_xy_pos)
    );

    acc_scaled_to_deg_x_neg u_acc2deg_x_neg (
        .ACC_IN (x_acc_1312),
        .DEG    (x_angle_x_neg)
    );

    assign x_angle_mag = x_sign_neg ? x_angle_x_neg : x_angle_xy_pos;

    // Y
    wire [7:0]  y_l   = r_data_y[7:0];
    wire [7:0]  y_h   = r_data_y[15:8];
    wire signed [11:0] y_12 = {y_h[3:0], y_l};
    wire signed [12:0] y_13 = {y_12[11], y_12};
    wire               y_sign_neg = y_13[12];
    wire [12:0]        y_abs = y_sign_neg ? (~y_13 + 13'd1) : y_13;

    wire [10:0]        y_acc_1312 = (y_abs > 13'd1312) ? 11'd1312
                                                       : y_abs[10:0];

    wire [6:0] y_angle_xy_pos;
    wire [6:0] y_angle_y_neg;
    wire [6:0] y_angle_mag;

    acc_scaled_to_deg_xy_pos u_acc2deg_y_pos (
        .ACC_IN (y_acc_1312),
        .DEG    (y_angle_xy_pos)
    );

    acc_scaled_to_deg_y_neg u_acc2deg_y_neg (
        .ACC_IN (y_acc_1312),
        .DEG    (y_angle_y_neg)
    );

    assign y_angle_mag = y_sign_neg ? y_angle_y_neg : y_angle_xy_pos;

    // Z
    wire [7:0]  z_l   = r_data_z[7:0];
    wire [7:0]  z_h   = r_data_z[15:8];
    wire signed [11:0] z_12 = {z_h[3:0], z_l};
    wire signed [12:0] z_13 = {z_12[11], z_12};
    wire               z_sign_neg = z_13[12];
    wire [12:0]        z_abs = z_sign_neg ? (~z_13 + 13'd1) : z_13;

    wire [10:0]        z_acc_1312 = (z_abs > 13'd1312) ? 11'd1312
                                                       : z_abs[10:0];

    wire [6:0] z_angle_pos;
    wire [6:0] z_angle_neg;
    wire [6:0] z_angle_mag;

    acc_scaled_to_deg_z_pos u_acc2deg_z_pos (
        .ACC_IN (z_acc_1312),
        .DEG    (z_angle_pos)
    );

    acc_scaled_to_deg_z_neg u_acc2deg_z_neg (
        .ACC_IN (z_acc_1312),
        .DEG    (z_angle_neg)
    );

    assign z_angle_mag = z_sign_neg ? z_angle_neg : z_angle_pos;

    // =========================================
    // 5) Dua goc X ra 16 LED
    // bit 15 la dau X
    // =========================================
    assign top_o_led = {x_sign_neg, 8'd0, x_angle_mag};

    // =========================================
    // 6) Hien thi tren 8 led 7 thanh
    // Mode 0 trong 1 s: hien X tren 4 digit phai
    // Mode 1 trong 1 s: hien Y tren 4 digit trai, Z tren 4 digit phai
    // =========================================

    wire [6:0] x_deg_val = x_angle_mag;
    wire [6:0] y_deg_val = y_angle_mag;
    wire [6:0] z_deg_val = z_angle_mag;

    wire [3:0] x_tens = x_deg_val / 10;
    wire [3:0] x_ones = x_deg_val % 10;
    wire [3:0] y_tens = y_deg_val / 10;
    wire [3:0] y_ones = y_deg_val % 10;
    wire [3:0] z_tens = z_deg_val / 10;
    wire [3:0] z_ones = z_deg_val % 10;

    reg [15:0] disp_cnt;
    always @(posedge top_i_clk) begin
        if (w_rst_sync) begin
            disp_cnt <= 16'd0;
        end else begin
            disp_cnt <= disp_cnt + 1'b1;
        end
    end

    wire [2:0] scan_sel = disp_cnt[15:13];

    // ma ky tu tren 4 bit
    localparam [3:0] CODE_MINUS = 4'd10;
    localparam [3:0] CODE_BLANK = 4'd11;
    localparam [3:0] CODE_X     = 4'd12;
    localparam [3:0] CODE_Y     = 4'd13;
    localparam [3:0] CODE_Z     = 4'd14;

    // ham ma hoa 7 doan, active low
    function [6:0] seg7_encode;
        input [3:0] code;
        begin
            case (code)
                4'd0:  seg7_encode = 7'b1000000;
                4'd1:  seg7_encode = 7'b1111001;
                4'd2:  seg7_encode = 7'b0100100;
                4'd3:  seg7_encode = 7'b0110000;
                4'd4:  seg7_encode = 7'b0011001;
                4'd5:  seg7_encode = 7'b0010010;
                4'd6:  seg7_encode = 7'b0000010;
                4'd7:  seg7_encode = 7'b1111000;
                4'd8:  seg7_encode = 7'b0000000;
                4'd9:  seg7_encode = 7'b0010000;
                4'd10: seg7_encode = 7'b0111111; // dau -
                4'd11: seg7_encode = 7'b1111111; // blank
                4'd12: seg7_encode = 7'b0100101; // X gan giong H
                4'd13: seg7_encode = 7'b0010001; // Y
                4'd14: seg7_encode = 7'b0100100; // Z gan giong 2
                default: seg7_encode = 7'b1111111;
            endcase
        end
    endfunction

    reg [6:0] seg_out;
    reg [7:0] an_out;

    always @* begin
        seg_out = 7'b1111111;
        an_out  = 8'b11111111;

        case (scan_sel)
            3'd0: begin
                // AN0
                an_out = 8'b11111110;
                if (r_disp_mode == 1'b0) begin
                    seg_out = seg7_encode(x_ones);
                end else begin
                    seg_out = seg7_encode(z_ones);
                end
            end

            3'd1: begin
                // AN1
                an_out = 8'b11111101;
                if (r_disp_mode == 1'b0) begin
                    seg_out = seg7_encode(x_tens);
                end else begin
                    seg_out = seg7_encode(z_tens);
                end
            end

            3'd2: begin
                // AN2 dau
                an_out = 8'b11111011;
                if (r_disp_mode == 1'b0) begin
                    seg_out = x_sign_neg ? seg7_encode(CODE_MINUS)
                                         : seg7_encode(CODE_BLANK);
                end else begin
                    seg_out = z_sign_neg ? seg7_encode(CODE_MINUS)
                                         : seg7_encode(CODE_BLANK);
                end
            end

            3'd3: begin
                // AN3 chu X hoac Z
                an_out = 8'b11110111;
                if (r_disp_mode == 1'b0) begin
                    seg_out = seg7_encode(CODE_X);
                end else begin
                    seg_out = seg7_encode(CODE_Z);
                end
            end

            3'd4: begin
                // AN4 don vi Y
                an_out = 8'b11101111;
                if (r_disp_mode == 1'b1) begin
                    seg_out = seg7_encode(y_ones);
                end else begin
                    seg_out = seg7_encode(CODE_BLANK);
                end
            end

            3'd5: begin
                // AN5 chuc Y
                an_out = 8'b11011111;
                if (r_disp_mode == 1'b1) begin
                    seg_out = seg7_encode(y_tens);
                end else begin
                    seg_out = seg7_encode(CODE_BLANK);
                end
            end

            3'd6: begin
                // AN6 dau Y
                an_out = 8'b10111111;
                if (r_disp_mode == 1'b1) begin
                    seg_out = y_sign_neg ? seg7_encode(CODE_MINUS)
                                         : seg7_encode(CODE_BLANK);
                end else begin
                    seg_out = seg7_encode(CODE_BLANK);
                end
            end

            3'd7: begin
                // AN7 chu Y
                an_out = 8'b01111111;
                if (r_disp_mode == 1'b1) begin
                    seg_out = seg7_encode(CODE_Y);
                end else begin
                    seg_out = seg7_encode(CODE_BLANK);
                end
            end

            default: begin
                an_out  = 8'b11111111;
                seg_out = 7'b1111111;
            end
        endcase
    end

    assign top_o_seg = seg_out;
    assign top_o_an  = an_out;

endmodule
