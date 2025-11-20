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
    reg        r_spi_sel_rw;   // 0=WRITE, 1=READ
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
        .i_sel_rw   (r_spi_sel_rw),  // 0=WRITE, 1=READ
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
    // 3) FSM dieu khien doc tung kenh, sau do hold 0.5s
    // =========================================
    localparam S_INIT_POWER_START = 3'd0;
    localparam S_INIT_POWER_WAIT  = 3'd1;
    localparam S_READ_LOW_START   = 3'd2;
    localparam S_READ_LOW_WAIT    = 3'd3;
    localparam S_READ_HIGH_START  = 3'd4;
    localparam S_READ_HIGH_WAIT   = 3'd5;
    localparam S_HOLD_ANGLE       = 3'd6;   // giu goc 0.5 s

    reg [2:0]  r_state;

    localparam AXIS_X = 2'd0;
    localparam AXIS_Y = 2'd1;
    localparam AXIS_Z = 2'd2;
    localparam AXIS_T = 2'd3;

    reg [1:0]  r_axis_sel;        // kenh sap doc
    reg [1:0]  r_disp_axis;       // kenh dang hien thi
    reg [15:0] r_axis_data;       // du lieu tam thoi trong lan doc hien tai

    // Luu du lieu tung kenh (gia tri moi nhat doc duoc)
    reg [15:0] r_data_x;
    reg [15:0] r_data_y;
    reg [15:0] r_data_z;
    reg [15:0] r_data_t;

    // base address cho byte thap cua tung kenh
    function [7:0] axis_base_addr;
        input [1:0] axis;
        begin
            case (axis)
                AXIS_X: axis_base_addr = 8'h0E; // X_L
                AXIS_Y: axis_base_addr = 8'h10; // Y_L
                AXIS_Z: axis_base_addr = 8'h12; // Z_L
                AXIS_T: axis_base_addr = 8'h14; // TEMP_L
                default:axis_base_addr = 8'h0E;
            endcase
        end
    endfunction

    // dem 0.5 s
    // 100 MHz, 0.5 s = 50 000 000 xung
    reg [25:0] hold_cnt;

    // FSM: doc 1 kenh -> luu -> hien thi 0.5 s -> chuyen kenh -> doc kenh moi
    always @(posedge top_i_clk) begin
        if (w_rst_sync) begin
            r_state       <= S_INIT_POWER_START;

            r_spi_ready   <= 1'b0;
            r_spi_inst    <= 8'h0A;   // mac dinh WRITE
            r_spi_sel_rw  <= 1'b0;
            r_spi_addr    <= 8'h00;
            r_spi_dout    <= 8'h00;

            r_axis_sel    <= AXIS_X;
            r_disp_axis   <= AXIS_X;
            r_axis_data   <= 16'h0000;

            r_data_x      <= 16'h0000;
            r_data_y      <= 16'h0000;
            r_data_z      <= 16'h0000;
            r_data_t      <= 16'h0000;

            hold_cnt      <= 26'd0;
        end else begin
            r_spi_ready <= 1'b0;

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
                        // sau khi init xong, bat dau doc kenh X
                        r_axis_sel  <= AXIS_X;
                        r_state     <= S_READ_LOW_START;
                    end
                end

                // Doc byte LSB cua kenh hien tai
                S_READ_LOW_START: begin
                    r_spi_inst    <= 8'h0B;              // READ
                    r_spi_sel_rw  <= 1'b1;               // 1=READ
                    r_spi_addr    <= axis_base_addr(r_axis_sel);
                    r_spi_dout    <= 8'h00;
                    r_spi_ready   <= 1'b1;
                    r_state       <= S_READ_LOW_WAIT;
                end

                S_READ_LOW_WAIT: begin
                    if (w_din_valid) begin
                        r_axis_data[7:0] <= w_din;       // LSB
                    end
                    if (w_csn_rise) begin
                        r_state <= S_READ_HIGH_START;
                    end
                end

                // Doc byte MSB cua kenh hien tai
                S_READ_HIGH_START: begin
                    r_spi_inst    <= 8'h0B;              // READ
                    r_spi_sel_rw  <= 1'b1;
                    r_spi_addr    <= axis_base_addr(r_axis_sel) + 8'd1;
                    r_spi_dout    <= 8'h00;
                    r_spi_ready   <= 1'b1;
                    r_state       <= S_READ_HIGH_WAIT;
                end

                S_READ_HIGH_WAIT: begin
                    if (w_din_valid) begin
                        r_axis_data[15:8] <= w_din;      // MSB
                    end
                    if (w_csn_rise) begin
                        // Luu du lieu vua doc duoc
                        case (r_axis_sel)
                            AXIS_X: r_data_x <= r_axis_data;
                            AXIS_Y: r_data_y <= r_axis_data;
                            AXIS_Z: r_data_z <= r_axis_data;
                            AXIS_T: r_data_t <= r_axis_data;
                            default: ;
                        endcase

                        // Chon kenh hien thi bang kenh vua doc
                        r_disp_axis <= r_axis_sel;

                        // Reset bo dem 0.5s
                        hold_cnt    <= 26'd0;
                        r_state     <= S_HOLD_ANGLE;
                    end
                end

                // Gi? goc cua kenh vua doc trong 0.5 s, khong doc SPI
                S_HOLD_ANGLE: begin
                    if (hold_cnt == 26'd49_999_999) begin
                        hold_cnt <= 26'd0;

                        // chon kenh tiep theo de lan sau doc
                        if (r_axis_sel == AXIS_T)
                            r_axis_sel <= AXIS_X;
                        else
                            r_axis_sel <= r_axis_sel + 2'd1;

                        // bat dau doc kenh moi
                        r_state <= S_READ_LOW_START;
                    end else begin
                        hold_cnt <= hold_cnt + 26'd1;
                    end
                end

                default: begin
                    r_state <= S_INIT_POWER_START;
                end
            endcase
        end
    end

    // =========================================
    // 4) r_disp_axis -> disp_data -> tach dau + |ACC| 0..1024 -> DEG
    // =========================================
    wire [15:0] disp_data;
    assign disp_data =
        (r_disp_axis == AXIS_X) ? r_data_x :
        (r_disp_axis == AXIS_Y) ? r_data_y :
        (r_disp_axis == AXIS_Z) ? r_data_z :
                                  r_data_t;

    wire [7:0] axis_l = disp_data[7:0];
    wire [7:0] axis_h = disp_data[15:8];

    // ADXL362 12 bit bu 2: [11:0] = {H[3:0], L[7:0]}
    wire signed [11:0] axis_12 = {axis_h[3:0], axis_l};

    // sign extend len 13 bit
    wire signed [12:0] axis_13 = {axis_12[11], axis_12};

    // tach dau: 1 = am, 0 = duong
    wire sign_neg = axis_13[12];

    // tri tuyet doi
    wire [12:0] axis_abs = sign_neg ? (~axis_13 + 13'd1) : axis_13;

    // gioi han ve 0..1024
    wire [10:0] acc_1024 = (axis_abs > 13'd1024) ? 11'd1024
                                                 : axis_abs[10:0];

    // LUT: ACC_IN (0..1024) -> DEG (0..90), do lon goc
    wire [6:0] angle_deg_mag;

    acc_scaled_to_deg u_acc2deg (
        .ACC_IN (acc_1024),
        .DEG    (angle_deg_mag)
    );

    // =========================================
    // 5) Dua goc ra 16 LED (bit 15 lam bit dau, 0 = duong, 1 = am)
    // =========================================
    assign top_o_led = {sign_neg, 8'd0, angle_deg_mag};

    // =========================================
    // 6) Hien thi len 7-seg Nexys A7
    // Dang: X 50, Y-20, Z 00, T-35 ...
    // AN0: don vi, AN1: chuc, AN2: dau (+/- hoac trong), AN3: chu X/Y/Z/T
    // =========================================
    wire [6:0] deg_val = angle_deg_mag; // 0..90

    wire [3:0] bcd_tens = deg_val / 10;
    wire [3:0] bcd_ones = deg_val % 10;

    // Encoder 7-seg so, output gfedcba, active low
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

    // Encode chu X Y Z T tren 7-seg
    function [6:0] seg7_encode_axis;
        input [1:0] axis;
        begin
            case (axis)
                AXIS_X: seg7_encode_axis = 7'b0001001; // X
                AXIS_Y: seg7_encode_axis = 7'b0010001; // Y
                AXIS_Z: seg7_encode_axis = 7'b0100100; // Z (na na so 2)
                AXIS_T: seg7_encode_axis = 7'b0000111; // T
                default:seg7_encode_axis = 7'b1111111;
            endcase
        end
    endfunction

    // Pattern dau tru "-"
    localparam [6:0] SEG_MINUS = 7'b0111111; // chi sang segment g

    // Bo chia tan quet 7-seg, 4 digit dau tien
    reg [16:0] scan_cnt;
    always @(posedge top_i_clk) begin
        if (w_rst_sync)
            scan_cnt <= 17'd0;
        else
            scan_cnt <= scan_cnt + 17'd1;
    end

    wire [1:0] digit_sel = scan_cnt[16:15]; // 0..3

    reg [6:0] seg_out;
    reg [7:0] an_out;

    always @(*) begin
        seg_out = 7'b1111111;
        an_out  = 8'b1111_1111;

        case (digit_sel)
            2'd0: begin
                // AN0: don vi
                seg_out = seg7_encode_digit(bcd_ones);
                an_out  = 8'b1111_1110;   // AN0 on
            end
            2'd1: begin
                // AN1: chuc
                seg_out = seg7_encode_digit(bcd_tens);
                an_out  = 8'b1111_1101;   // AN1 on
            end
            2'd2: begin
                // AN2: dau
                if (sign_neg) begin
                    seg_out = SEG_MINUS;      // dau tru
                    an_out  = 8'b1111_1011;   // AN2 on
                end else begin
                    seg_out = 7'b1111111;     // trong
                    an_out  = 8'b1111_1011;   // AN2 on nhung khong sang
                end
            end
            2'd3: begin
                // AN3: chu X/Y/Z/T
                seg_out = seg7_encode_axis(r_disp_axis);
                an_out  = 8'b1111_0111;   // AN3 on
            end
        endcase
    end

    assign top_o_seg = seg_out;  // gfedcba
    assign top_o_an  = an_out;

endmodule
