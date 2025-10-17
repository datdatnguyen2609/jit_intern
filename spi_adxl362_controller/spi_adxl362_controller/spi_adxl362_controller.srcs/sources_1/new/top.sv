`timescale 1ns/1ps
module top
#(
    parameter CLK_FREQ_HZ = 100_000_000   // clock h? th?ng (Hz)
)
(
    input  wire        i_clk,
    input  wire        i_rst,

    // SPI t?i ADXL362
    output wire        o_csn,
    output wire        o_sclk,
    output wire        o_mosi,
    input  wire        i_miso,

    // 7-seg active-LOW: an[0] = digit0 (LSD), an[3] = digit3 (MSD)
    output reg  [6:0]  o_seg,  // {a,b,c,d,e,f,g}, dp luôn t?t trong ví d? này
    output reg  [3:0]  o_an
);

    // -----------------------------
    // Wires/regs k?t n?i controller
    // -----------------------------
    reg        c_ready;
    reg [7:0]  c_inst;        // 0x0B = READ
    reg        c_sel_rw;      // 1 = READ
    reg [7:0]  c_addr;
    reg [7:0]  c_dout;        // không dùng khi READ

    wire [7:0] c_din;
    wire       c_din_valid;

    // -----------------------------
    // G?n module SPI controller c?a b?n
    // -----------------------------
    spi_adxl362_controller u_spi (
        .i_clk      (i_clk),
        .i_rst      (i_rst),
        .o_csn      (o_csn),
        .o_sclk     (o_sclk),
        .o_mosi     (o_mosi),
        .i_miso     (i_miso),

        .i_ready    (c_ready),
        .i_inst     (c_inst),
        .i_sel_rw   (c_sel_rw),
        .i_reg_addr (c_addr),
        .i_dout     (c_dout),
        .o_din      (c_din),
        .o_din_valid(c_din_valid)
    );

    // -----------------------------
    // Trình t? ??c 0x14 r?i 0x15
    // -----------------------------
    localparam T_IDLE       = 3'd0,
               T_RD_L_PULSE = 3'd1,
               T_RD_L_WAIT  = 3'd2,
               T_RD_H_PULSE = 3'd3,
               T_RD_H_WAIT  = 3'd4,
               T_HOLD       = 3'd5;

    reg [2:0] t_state, t_next;
    reg [7:0] temp_l, temp_h;
    reg [15:0] temp16;

    // simple hold delay gi?a các vòng ??c (ví d? ~10ms)
    localparam integer HOLD_MS = 10;
    localparam integer HOLD_TICKS = (CLK_FREQ_HZ/1000)*HOLD_MS;
    reg [$clog2(HOLD_TICKS):0] hold_cnt;

    // state reg
    always @(posedge i_clk) begin
        if (i_rst) t_state <= T_IDLE;
        else       t_state <= t_next;
    end

    // next-state + control
    always @(*) begin
        // m?c ??nh
        t_next = t_state;
        case (t_state)
            T_IDLE:       t_next = T_RD_L_PULSE;
            T_RD_L_PULSE: t_next = T_RD_L_WAIT;
            T_RD_L_WAIT:  t_next = (c_din_valid ? T_RD_H_PULSE : T_RD_L_WAIT);
            T_RD_H_PULSE: t_next = T_RD_H_WAIT;
            T_RD_H_WAIT:  t_next = (c_din_valid ? T_HOLD : T_RD_H_WAIT);
            T_HOLD:       t_next = (hold_cnt == HOLD_TICKS-1) ? T_RD_L_PULSE : T_HOLD;
            default:      t_next = T_IDLE;
        endcase
    end

    // outputs / datapath
    always @(posedge i_clk) begin
        if (i_rst) begin
            c_ready   <= 1'b0;
            c_inst    <= 8'h0B;     // READ
            c_sel_rw  <= 1'b1;      // READ
            c_addr    <= 8'h00;
            c_dout    <= 8'h00;
            temp_l    <= 8'h00;
            temp_h    <= 8'h00;
            temp16    <= 16'h0000;
            hold_cnt  <= 0;
        end else begin
            c_ready <= 1'b0; // m?c ??nh: không pulse

            case (t_state)
                T_IDLE: begin
                    // không làm gì
                    hold_cnt <= 0;
                end

                T_RD_L_PULSE: begin
                    c_inst   <= 8'h0B;    // READ
                    c_sel_rw <= 1'b1;     // READ
                    c_addr   <= 8'h14;    // TEMP_L
                    c_ready  <= 1'b1;     // nhá 1 chu k?
                end

                T_RD_L_WAIT: begin
                    if (c_din_valid) begin
                        temp_l <= c_din;
                    end
                end

                T_RD_H_PULSE: begin
                    c_inst   <= 8'h0B;    // READ
                    c_sel_rw <= 1'b1;     // READ
                    c_addr   <= 8'h15;    // TEMP_H
                    c_ready  <= 1'b1;     // nhá 1 chu k?
                end

                T_RD_H_WAIT: begin
                    if (c_din_valid) begin
                        temp_h <= c_din;
                    end
                end

                T_HOLD: begin
                    temp16   <= {temp_h, temp_l}; // ghép 16-bit ?? hi?n th?
                    if (hold_cnt < HOLD_TICKS-1) hold_cnt <= hold_cnt + 1;
                    else                          hold_cnt <= 0;
                end
            endcase
        end
    end

    // -----------------------------
    // 7-Segment: quét 4 digits, hi?n th? HEX c?a temp16
    // -----------------------------
    // T?o tick quét ~1 kHz/digit (4 kHz t?ng) t? 100 MHz
    localparam integer SCAN_HZ      = 4000; // t?ng 4 digits
    localparam integer SCAN_DIV     = CLK_FREQ_HZ / SCAN_HZ;
    reg [$clog2(SCAN_DIV):0] scan_cnt;
    reg [1:0]                scan_sel;   // 0..3

    always @(posedge i_clk) begin
        if (i_rst) begin
            scan_cnt <= 0;
            scan_sel <= 0;
        end else begin
            if (scan_cnt == SCAN_DIV-1) begin
                scan_cnt <= 0;
                scan_sel <= scan_sel + 2'd1;
            end else begin
                scan_cnt <= scan_cnt + 1'd1;
            end
        end
    end

    // ch?n nibble theo scan_sel
    wire [3:0] nibble0 = temp16[3:0];
    wire [3:0] nibble1 = temp16[7:4];
    wire [3:0] nibble2 = temp16[11:8];
    wire [3:0] nibble3 = temp16[15:12];

    reg [3:0] cur_nibble;
    always @(*) begin
        case (scan_sel)
            2'd0: cur_nibble = nibble0; // LSD
            2'd1: cur_nibble = nibble1;
            2'd2: cur_nibble = nibble2;
            2'd3: cur_nibble = nibble3; // MSD
            default: cur_nibble = 4'h0;
        endcase
    end

    // mã 7-seg cho HEX, active-LOW (0 = sáng)
    function [6:0] seg_hex_active_low;
        input [3:0] x;
        begin
            case (x)
                4'h0: seg_hex_active_low = 7'b1000000; // 0
                4'h1: seg_hex_active_low = 7'b1111001; // 1
                4'h2: seg_hex_active_low = 7'b0100100; // 2
                4'h3: seg_hex_active_low = 7'b0110000; // 3
                4'h4: seg_hex_active_low = 7'b0011001; // 4
                4'h5: seg_hex_active_low = 7'b0010010; // 5
                4'h6: seg_hex_active_low = 7'b0000010; // 6
                4'h7: seg_hex_active_low = 7'b1111000; // 7
                4'h8: seg_hex_active_low = 7'b0000000; // 8
                4'h9: seg_hex_active_low = 7'b0010000; // 9
                4'hA: seg_hex_active_low = 7'b0001000; // A
                4'hB: seg_hex_active_low = 7'b0000011; // b
                4'hC: seg_hex_active_low = 7'b1000110; // C
                4'hD: seg_hex_active_low = 7'b0100001; // d
                4'hE: seg_hex_active_low = 7'b0000110; // E
                4'hF: seg_hex_active_low = 7'b0001110; // F
                default: seg_hex_active_low = 7'b1111111; // all off
            endcase
        end
    endfunction

    // drive seg/an (active-LOW)
    always @(*) begin
        // segments
        o_seg = seg_hex_active_low(cur_nibble); // dp t?t (không có bit dp ? ?ây)

        // digit enables
        // an[0] sáng digit0 (LSD), an[3] sáng digit3 (MSD)
        o_an = 4'b1111; // t?t h?t
        case (scan_sel)
            2'd0: o_an = 4'b1110;
            2'd1: o_an = 4'b1101;
            2'd2: o_an = 4'b1011;
            2'd3: o_an = 4'b0111;
        endcase
    end

endmodule
