`timescale 1ns / 1ps

module top (
    input         top_i_clk,
    input         top_i_rst,      // nut reset (muc cao = reset)

    input         top_i_btn_x,    // doc X: reg 0x0E (L), 0x0F (H)
    input         top_i_btn_y,    // doc Y: reg 0x10 (L), 0x11 (H)
    input         top_i_btn_z,    // doc Z: reg 0x12 (L), 0x13 (H)
    input         top_i_btn_t,    // doc TEMP: reg 0x14 (L), 0x15 (H)

    output        top_o_csn,
    output        top_o_sclk,
    output        top_o_mosi,
    input         top_i_miso,

    output [15:0] top_o_led,      // 16 LED don
    output [6:0]  top_o_seg,      // {g,f,e,d,c,b,a}, active low
    output [7:0]  top_o_an        // AN7..AN0, active low
);

    // =========================================
    // 1) Debounce reset + 4 nut bam
    // =========================================
    wire w_rst_sync;
    debounce #(.CLK_FREQ(100_000_000), .DEBOUNCE_TIME_MS(20)) u_db_rst (
        .I_clk    (top_i_clk),
        .I_rst    (1'b0),
        .I_btn_in (top_i_rst),
        .O_btn_out(w_rst_sync)
    );

    wire w_btn_x_db, w_btn_y_db, w_btn_z_db, w_btn_t_db;

    debounce #(.CLK_FREQ(100_000_000), .DEBOUNCE_TIME_MS(20)) u_db_btn_x (
        .I_clk    (top_i_clk),
        .I_rst    (w_rst_sync),
        .I_btn_in (top_i_btn_x),
        .O_btn_out(w_btn_x_db)
    );
    debounce #(.CLK_FREQ(100_000_000), .DEBOUNCE_TIME_MS(20)) u_db_btn_y (
        .I_clk    (top_i_clk),
        .I_rst    (w_rst_sync),
        .I_btn_in (top_i_btn_y),
        .O_btn_out(w_btn_y_db)
    );
    debounce #(.CLK_FREQ(100_000_000), .DEBOUNCE_TIME_MS(20)) u_db_btn_z (
        .I_clk    (top_i_clk),
        .I_rst    (w_rst_sync),
        .I_btn_in (top_i_btn_z),
        .O_btn_out(w_btn_z_db)
    );
    debounce #(.CLK_FREQ(100_000_000), .DEBOUNCE_TIME_MS(20)) u_db_btn_t (
        .I_clk    (top_i_clk),
        .I_rst    (w_rst_sync),
        .I_btn_in (top_i_btn_t),
        .O_btn_out(w_btn_t_db)
    );

    // Canh len cua cac nut sau debounce
    reg r_btn_x_q, r_btn_y_q, r_btn_z_q, r_btn_t_q;
    always @(posedge top_i_clk) begin
        if (w_rst_sync) begin
            r_btn_x_q <= 1'b0;
            r_btn_y_q <= 1'b0;
            r_btn_z_q <= 1'b0;
            r_btn_t_q <= 1'b0;
        end else begin
            r_btn_x_q <= w_btn_x_db;
            r_btn_y_q <= w_btn_y_db;
            r_btn_z_q <= w_btn_z_db;
            r_btn_t_q <= w_btn_t_db;
        end
    end

    wire w_btn_x_edge = w_btn_x_db & ~r_btn_x_q;
    wire w_btn_y_edge = w_btn_y_db & ~r_btn_y_q;
    wire w_btn_z_edge = w_btn_z_db & ~r_btn_z_q;
    wire w_btn_t_edge = w_btn_t_db & ~r_btn_t_q;

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
    // 3) FSM dieu khien
    // =========================================
    localparam S_INIT_POWER_START = 3'd0;
    localparam S_INIT_POWER_WAIT  = 3'd1;
    localparam S_IDLE             = 3'd2;
    localparam S_READ_LOW_START   = 3'd3;
    localparam S_READ_LOW_WAIT    = 3'd4;
    localparam S_READ_HIGH_START  = 3'd5;
    localparam S_READ_HIGH_WAIT   = 3'd6;

    reg [2:0]  r_state;

    localparam AXIS_X = 2'd0;
    localparam AXIS_Y = 2'd1;
    localparam AXIS_Z = 2'd2;
    localparam AXIS_T = 2'd3;

    reg [1:0]  r_axis_sel;
    reg [15:0] r_axis_data;     // 16 bit doc duoc (H:L)

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

    // FSM
    always @(posedge top_i_clk) begin
        if (w_rst_sync) begin
            r_state       <= S_INIT_POWER_START;

            r_spi_ready   <= 1'b0;
            r_spi_inst    <= 8'h0A;   // mac dinh WRITE
            r_spi_sel_rw  <= 1'b0;
            r_spi_addr    <= 8'h00;
            r_spi_dout    <= 8'h00;

            r_axis_sel    <= AXIS_X;
            r_axis_data   <= 16'h0000;
        end else begin
            r_spi_ready <= 1'b0;

            case (r_state)
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
                        r_state <= S_IDLE;
                    end
                end

                S_IDLE: begin
                    if (w_btn_x_edge) begin
                        r_axis_sel <= AXIS_X;
                        r_state    <= S_READ_LOW_START;
                    end else if (w_btn_y_edge) begin
                        r_axis_sel <= AXIS_Y;
                        r_state    <= S_READ_LOW_START;
                    end else if (w_btn_z_edge) begin
                        r_axis_sel <= AXIS_Z;
                        r_state    <= S_READ_LOW_START;
                    end else if (w_btn_t_edge) begin
                        r_axis_sel <= AXIS_T;
                        r_state    <= S_READ_LOW_START;
                    end
                end

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
                        r_state   <= S_IDLE;
                    end
                end

                default: begin
                    r_state <= S_IDLE;
                end
            endcase
        end
    end

    // =========================================
    // 4) r_axis_data -> |ACC| 0..1024 -> DEG
    // =========================================
    wire [7:0] axis_l = r_axis_data[7:0];
    wire [7:0] axis_h = r_axis_data[15:8];

    // ADXL362 12 bit bu 2: [11:0] = {H[3:0], L[7:0]}
    wire signed [11:0] axis_12 = {axis_h[3:0], axis_l};

    // sign extend len 13 bit
    wire signed [12:0] axis_13 = {axis_12[11], axis_12};

    // tri tuyet doi
    wire [12:0] axis_abs = axis_13[12] ? (~axis_13 + 13'd1) : axis_13;

    // gioi han ve 0..1024
    wire [10:0] acc_1024 = (axis_abs > 13'd1024) ? 11'd1024
                                                 : axis_abs[10:0];

    // LUT: ACC_IN (0..1024) -> DEG (0..90)
    wire [6:0] angle_deg;

    acc_scaled_to_deg u_acc2deg (
        .ACC_IN (acc_1024),
        .DEG    (angle_deg)
    );

    // =========================================
    // 5) Dua goc ra 16 LED (7 bit thap)
    // =========================================
    assign top_o_led = {9'd0, angle_deg};

    // =========================================
    // 6) Hien thi len 7-seg Nexys A7
    // top_o_seg[6:0] = {g,f,e,d,c,b,a}, active low
    // top_o_an[7:0]  = AN7..AN0, active low
    // =========================================
    wire [6:0] deg_val = angle_deg; // 0..90

    wire [3:0] bcd_hund = (deg_val >= 7'd100) ? 4'd1 : 4'd0;
    wire [3:0] bcd_tens = deg_val / 10;
    wire [3:0] bcd_ones = deg_val % 10;

    // Encoder 7-seg, output gfedcba, active low
    function [6:0] seg7_encode;
        input [3:0] b;
        begin
            case (b)
                4'd0: seg7_encode = 7'b1000000; // 0
                4'd1: seg7_encode = 7'b1111001; // 1
                4'd2: seg7_encode = 7'b0100100; // 2
                4'd3: seg7_encode = 7'b0110000; // 3
                4'd4: seg7_encode = 7'b0011001; // 4
                4'd5: seg7_encode = 7'b0010010; // 5
                4'd6: seg7_encode = 7'b0000010; // 6
                4'd7: seg7_encode = 7'b1111000; // 7
                4'd8: seg7_encode = 7'b0000000; // 8
                4'd9: seg7_encode = 7'b0010000; // 9
                default: seg7_encode = 7'b1111111; // tat
            endcase
        end
    endfunction

    // Bo chia tan quet 7-seg
    reg [16:0] scan_cnt;
    always @(posedge top_i_clk or posedge w_rst_sync) begin
        if (w_rst_sync)
            scan_cnt <= 17'd0;
        else
            scan_cnt <= scan_cnt + 17'd1;
    end

    wire [1:0] digit_sel = scan_cnt[16:15];

    reg [6:0] seg_out;
    reg [7:0] an_out;
    reg [3:0] cur_bcd;

    always @(*) begin
        seg_out = 7'b1111111;
        an_out  = 8'b1111_1111;
        cur_bcd = 4'd0;

        case (digit_sel)
            2'd0: begin
                cur_bcd = bcd_ones;
                an_out  = 8'b1111_1110;   // AN0
            end
            2'd1: begin
                cur_bcd = bcd_tens;
                an_out  = 8'b1111_1101;   // AN1
            end
            2'd2: begin
                if (deg_val >= 7'd100) begin
                    cur_bcd = bcd_hund;
                    an_out  = 8'b1111_1011;   // AN2
                end else begin
                    cur_bcd = 4'd0;
                    an_out  = 8'b1111_1111;   // tat digit nay
                end
            end
            default: begin
                cur_bcd = 4'd0;
                an_out  = 8'b1111_1111;
            end
        endcase

        seg_out = seg7_encode(cur_bcd);
    end

    assign top_o_seg = seg_out;  // gfedcba
    assign top_o_an  = an_out;

endmodule
