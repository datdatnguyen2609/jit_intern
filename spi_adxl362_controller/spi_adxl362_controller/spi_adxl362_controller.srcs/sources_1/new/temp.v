module top (
    input        top_i_clk,
    input        top_i_rst,    // nut reset chua loc (muc cao = reset)
    input        top_i_ready,  // nut start chua loc (nhan de bat dau giao dich)

    output       top_o_csn,
    output       top_o_sclk,
    output       top_o_mosi,
    input        top_i_miso,

    output [7:0] top_o_din,    // -> 8 LED don
    input  [7:0] top_i_sw      // -> chon dia chi thanh ghi
);

    // =========================
    // 1) Debounce RESET -> w_rst_sync (active-HIGH)
    // =========================
    wire w_rst_sync;

    debounce #(
        .CLK_FREQ(100_000_000),
        .DEBOUNCE_TIME_MS(20)
    ) u_db_rst (
        .I_clk     (top_i_clk),
        .I_rst     (1'b0),          // khong reset bo loc
        .I_btn_in  (top_i_rst),
        .O_btn_out (w_rst_sync)
    );

    // =========================
    // 2) Debounce READY + edge detect
    // =========================
    wire w_ready_db;
    reg  r_ready_db_d;

    debounce #(
        .CLK_FREQ(100_000_000),
        .DEBOUNCE_TIME_MS(20)
    ) u_db_ready (
        .I_clk     (top_i_clk),
        .I_rst     (w_rst_sync),
        .I_btn_in  (top_i_ready),
        .O_btn_out (w_ready_db)
    );

    always @(posedge top_i_clk) begin
        if (w_rst_sync) r_ready_db_d <= 1'b0;
        else            r_ready_db_d <= w_ready_db;
    end

    wire w_ready_edge = w_ready_db & ~r_ready_db_d; // xung 1 chu ky

    // =========================
    // 3) Busy gating + latch dia chi
    // =========================
    wire w_csn_int;
    wire w_spi_busy = (w_csn_int == 1'b0);

    reg [7:0] r_reg_addr_latched;
    reg       r_spi_ready_pulse;     // xung 1 chu ky

    always @(posedge top_i_clk) begin
        if (w_rst_sync) begin
            r_reg_addr_latched <= 8'h00;
            r_spi_ready_pulse  <= 1'b0;
        end else begin
            r_spi_ready_pulse <= 1'b0;
            if (w_ready_edge && !w_spi_busy) begin
                r_reg_addr_latched <= top_i_sw;
                r_spi_ready_pulse  <= 1'b1;
            end
        end
    end

    // =========================
    // 4) SPI controller (READ 1 BYTE)
    // =========================
    wire [7:0] w_din;
    wire       w_din_valid;  // <- LAY RA DE BAT LED

    spi_adxl362_controller u_spi (
        .i_clk      (top_i_clk),
        .i_rst      (w_rst_sync),

        .o_csn      (w_csn_int),
        .o_sclk     (top_o_sclk),
        .o_mosi     (top_o_mosi),
        .i_miso     (top_i_miso),

        .i_ready    (r_spi_ready_pulse), // xung start 1 chu ky
        .i_inst     (8'h0B),             // LEN doc (0x0B)
        .i_sel_rw   (1'b1),              // 1 = READ
        .i_reg_addr (r_reg_addr_latched),
        .i_dout     (8'h00),             // khong dung khi READ
        .o_din      (w_din),
        .o_din_valid(w_din_valid)        // *** DUNG DE LATCH LEN LED
    );

    // =========================
    // 5) Latch du lieu len LED khi o_din_valid = 1
    // =========================
    reg [7:0] r_led_data;
    always @(posedge top_i_clk) begin
        if (w_rst_sync) begin
            r_led_data <= 8'h00;
        end else if (w_din_valid) begin
            r_led_data <= w_din;        // giu lai gia tri vua doc
        end
    end

    // =========================
    // 6) Map ra cong top
    // =========================
    assign top_o_csn = w_csn_int;
    assign top_o_din = r_led_data;      // -> LED hien gia tri da latch

endmodule // thay đổi module này để đọc giá trị nhiệt độ, hiển thị nó ra 8 led, (không thay đổi in/out nhe) 