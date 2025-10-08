module seg_dynamic
#(
    parameter CNT_MAX = 17'd99_999  // ~1ms @ 100 MHz (tuy theo clock thuc te)
)
(
    input  wire        i_sys_clk,
    input  wire        i_rst,        // reset dong bo, active-HIGH
    input  wire [26:0] i_data,

    output reg  [7:0]  o_sel,
    output reg  [7:0]  o_seg
);

    // ------------------------------
    // Wires tu bo chuyen BCD
    // ------------------------------
    wire [3:0] w_units;             // don vi
    wire [3:0] w_tens;              // chuc
    wire [3:0] w_hundreds;          // tram
    wire [3:0] w_thousands;         // nghin
    wire [3:0] w_ten_thousands;     // chuc nghin
    wire [3:0] w_hundred_thousands; // tram nghin
    wire [3:0] w_millions;          // trieu
    wire [3:0] w_ten_millions;      // chuc trieu

    // ------------------------------
    // Registers noi bo
    // ------------------------------
    reg  [3:0]  r_seg_data;   // gia tri BCD cua digit dang hien
    reg  [2:0]  r_cnt_sel;    // quay vong 0..7 chon digit

    reg  [16:0] r_cnt_1ms;
    reg         r_flag_1ms;

    // ------------------------------------------------------------
    // r_cnt_1ms: dem chu ky -> tao co 1ms (tuy theo CNT_MAX)
    // ------------------------------------------------------------
    always @(posedge i_sys_clk) begin
        if (i_rst) begin
            r_cnt_1ms <= 17'd0;
        end else if (r_cnt_1ms == CNT_MAX) begin
            r_cnt_1ms <= 17'd0;
        end else begin
            r_cnt_1ms <= r_cnt_1ms + 1'b1;
        end
    end

    // ------------------------------------------------------------
    // r_flag_1ms: xung 1 chu ky moi 1ms
    // ------------------------------------------------------------
    always @(posedge i_sys_clk) begin
        if (i_rst) begin
            r_flag_1ms <= 1'b0;
        end else if (r_cnt_1ms == CNT_MAX - 1'b1) begin
            r_flag_1ms <= 1'b1;
        end else begin
            r_flag_1ms <= 1'b0;
        end
    end

    // ------------------------------------------------------------
    // r_cnt_sel: 0..7, chon digit hien thi
    // ------------------------------------------------------------
    always @(posedge i_sys_clk) begin
        if (i_rst) begin
            r_cnt_sel <= 3'd0;
        end else if ((r_cnt_sel == 3'd7) && r_flag_1ms) begin
            r_cnt_sel <= 3'd0;
        end else if (r_flag_1ms) begin
            r_cnt_sel <= r_cnt_sel + 1'b1;
        end else begin
            r_cnt_sel <= r_cnt_sel;
        end
    end

    // ------------------------------------------------------------
    // Chon BCD cho digit hien tai
    // ------------------------------------------------------------
    always @(posedge i_sys_clk) begin
        if (i_rst) begin
            r_seg_data <= 4'd0;
        end else begin
            case (r_cnt_sel)
                3'd0: r_seg_data <= w_units;
                3'd1: r_seg_data <= w_tens;
                3'd2: r_seg_data <= w_hundreds;
                3'd3: r_seg_data <= w_thousands;
                3'd4: r_seg_data <= w_ten_thousands;
                3'd5: r_seg_data <= w_hundred_thousands;
                3'd6: r_seg_data <= w_millions;
                3'd7: r_seg_data <= w_ten_millions;
                default: r_seg_data <= 4'd0;
            endcase
        end
    end

    // ------------------------------------------------------------
    // o_sel: kich hoat tung LED 7 doan (active-low)
    // ------------------------------------------------------------
    always @(posedge i_sys_clk) begin
        if (i_rst) begin
            o_sel <= 8'b0111_1111;
        end else if (r_flag_1ms) begin
            case (r_cnt_sel)
                3'd0: o_sel <= 8'b0111_1110;
                3'd1: o_sel <= 8'b1111_1101;
                3'd2: o_sel <= 8'b1111_1011;
                3'd3: o_sel <= 8'b1111_0111;
                3'd4: o_sel <= 8'b1110_1111;
                3'd5: o_sel <= 8'b1101_1111;
                3'd6: o_sel <= 8'b1011_1111;
                3'd7: o_sel <= 8'b0111_1111;
                default: o_sel <= 8'b0111_1111;
            endcase
        end
    end

    // ------------------------------------------------------------
    // o_seg: ma hoa 7 doan (active-low) theo r_seg_data (BCD)
    // ------------------------------------------------------------
    always @(posedge i_sys_clk) begin
        if (i_rst) begin
            o_seg <= 8'b0000_0011; // '0'
        end else if (r_flag_1ms) begin
            case (r_seg_data)
                4'd0: o_seg <= 8'b0000_0011;
                4'd1: o_seg <= 8'b1001_1111;
                4'd2: o_seg <= 8'b0010_0101;
                4'd3: o_seg <= 8'b0000_1101;
                4'd4: o_seg <= 8'b1001_1001;
                4'd5: o_seg <= 8'b0100_1001;
                4'd6: o_seg <= 8'b0100_0001;
                4'd7: o_seg <= 8'b0001_1111;
                4'd8: o_seg <= 8'b0000_0001;
                4'd9: o_seg <= 8'b0000_1001;
                default: o_seg <= 8'b1111_1111; // tat tat ca neu ngoai 0..9
            endcase
        end
    end

    // ------------------------------------------------------------
    // Bo chuyen BCD 8421 (dat ten cong theo quy uoc i_/o_)
    // Ky vong module con ho tro cac cong nay.
    // ------------------------------------------------------------
    bcd_8421 bcd_8421_inst (
        .i_sys_clk        (i_sys_clk),
        .i_rst            (i_rst),
        .i_data           (i_data),

        .o_units          (w_units),             // don vi
        .o_tens           (w_tens),              // chuc
        .o_hundreds       (w_hundreds),          // tram
        .o_thousands      (w_thousands),         // nghin
        .o_ten_thousands  (w_ten_thousands),     // chuc nghin
        .o_hun_thousands  (w_hundred_thousands), // tram nghin
        .o_millions       (w_millions),          // trieu
        .o_ten_millions   (w_ten_millions)       // chuc trieu
    );

endmodule
