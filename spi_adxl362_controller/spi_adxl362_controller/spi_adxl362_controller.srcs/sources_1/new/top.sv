`timescale 1ns / 1ps

module top (
    input         top_i_clk,
    input         top_i_rst,      // nút reset (m?c cao = reset)

    input         top_i_btn_x,    // ??c X: reg 0x0E (L), 0x0F (H)
    input         top_i_btn_y,    // ??c Y: reg 0x10 (L), 0x11 (H)
    input         top_i_btn_z,    // ??c Z: reg 0x12 (L), 0x13 (H)
    input         top_i_btn_t,    // ??c TEMP: reg 0x14 (L), 0x15 (H)

    output        top_o_csn,
    output        top_o_sclk,
    output        top_o_mosi,
    input         top_i_miso,

    output [15:0] top_o_led       // 16 LED ??n
);

    // =========================================
    // 1) Debounce reset + 4 nút b?m
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

    // C?nh lên c?a các nút sau debounce
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

    // Theo dõi c?nh CSN ?? bi?t giao d?ch xong
    reg r_csn_q;
    always @(posedge top_i_clk) begin
        if (w_rst_sync) r_csn_q <= 1'b1;
        else            r_csn_q <= w_csn;
    end
    wire w_csn_rise = (~r_csn_q) & w_csn;   // CSN 0->1

    // =========================================
    // 3) FSM ?i?u khi?n: 
    // - init: ghi POWER_CTL (0x2D) = 0x02
    // - sau ?ó: m?i nút ??c 2 byte (L,H) r?i hi?n th? lên LED
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
    reg [15:0] r_axis_data;     // 16 bit ??c ???c (H:L)
    reg [15:0] r_led_reg;       // d? li?u ??a ra LED

    // base address cho byte th?p c?a t?ng kênh
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
            r_spi_inst    <= 8'h0A;   // m?c ??nh WRITE
            r_spi_sel_rw  <= 1'b0;
            r_spi_addr    <= 8'h00;
            r_spi_dout    <= 8'h00;

            r_axis_sel    <= AXIS_X;
            r_axis_data   <= 16'h0000;
            r_led_reg     <= 16'h0000;
        end else begin
            // m?c ??nh không phát READY
            r_spi_ready <= 1'b0;

            case (r_state)
                //----------------------------------
                // Kh?i ??ng: ghi POWER_CTL = 0x02
                //----------------------------------
                S_INIT_POWER_START: begin
                    // Giao d?ch WRITE: INST=0x0A, sel_rw=0
                    r_spi_inst    <= 8'h0A;      // WRITE
                    r_spi_sel_rw  <= 1'b0;
                    r_spi_addr    <= 8'h2D;      // POWER_CTL
                    r_spi_dout    <= 8'h02;      // Measurement mode
                    r_spi_ready   <= 1'b1;       // pulse 1 chu k?
                    r_state       <= S_INIT_POWER_WAIT;
                end

                S_INIT_POWER_WAIT: begin
                    // ??i giao d?ch xong (CSN lên l?i)
                    if (w_csn_rise) begin
                        r_state <= S_IDLE;
                    end
                end

                //----------------------------------
                // IDLE: ch? 4 nút
                //----------------------------------
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

                //----------------------------------
                // Giao d?ch ??c byte th?p (L)
                //----------------------------------
                S_READ_LOW_START: begin
                    r_spi_inst    <= 8'h0B;              // READ
                    r_spi_sel_rw  <= 1'b1;               // 1=READ
                    r_spi_addr    <= axis_base_addr(r_axis_sel); // addr_L
                    r_spi_dout    <= 8'h00;              // dummy
                    r_spi_ready   <= 1'b1;               // start transaction
                    r_state       <= S_READ_LOW_WAIT;
                end

                S_READ_LOW_WAIT: begin
                    // L?u l?i byte th?p khi có din_valid
                    if (w_din_valid) begin
                        r_axis_data[7:0] <= w_din;       // LSB
                    end
                    // ??i CSN lên => xong giao d?ch
                    if (w_csn_rise) begin
                        r_state <= S_READ_HIGH_START;
                    end
                end

                //----------------------------------
                // Giao d?ch ??c byte cao (H)
                //----------------------------------
                S_READ_HIGH_START: begin
                    r_spi_inst    <= 8'h0B;              // READ
                    r_spi_sel_rw  <= 1'b1;
                    r_spi_addr    <= axis_base_addr(r_axis_sel) + 8'd1; // addr_H
                    r_spi_dout    <= 8'h00;
                    r_spi_ready   <= 1'b1;
                    r_state       <= S_READ_HIGH_WAIT;
                end

                S_READ_HIGH_WAIT: begin
                    // L?u byte cao khi có din_valid
                    if (w_din_valid) begin
                        r_axis_data[15:8] <= w_din;      // MSB
                    end
                    // Khi CSN lên l?i => xong 2 byte, c?p nh?t LED
                    if (w_csn_rise) begin
                        r_led_reg <= r_axis_data;
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
    // 4) ??a d? li?u ra 16 LED
    // =========================================
    assign top_o_led = r_led_reg;

endmodule
