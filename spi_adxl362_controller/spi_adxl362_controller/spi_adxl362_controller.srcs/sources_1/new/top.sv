`timescale 1ns / 1ps
module top (
    input         top_i_clk,
    input         top_i_rst,      // nut reset chua loc (muc cao = reset)
    input         top_i_ready,    // nut start chua loc (nhan de bat dau giao dich)
    input         top_i_mode,     // nut chon che do: 1=WRITE, 0=READ  (nut moi)

    output        top_o_csn,
    output        top_o_sclk,
    output        top_o_mosi,
    input         top_i_miso,

    output [7:0]  top_o_din,      // 8 LED don
    input  [15:0] top_i_sw        // [15:8]=DATA, [7:0]=ADDR
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
    // 2b) Debounce MODE (nut moi) -> muc on dinh
    // =========================
    wire w_mode_db;   // 1=WRITE, 0=READ (da debounce)
    debounce #(
        .CLK_FREQ(100_000_000),
        .DEBOUNCE_TIME_MS(20)
    ) u_db_mode (
        .I_clk     (top_i_clk),
        .I_rst     (w_rst_sync),
        .I_btn_in  (top_i_mode),
        .O_btn_out (w_mode_db)
    );

    // =========================
    // 3) Busy gating + latch truoc khi giao dich
    // =========================
    wire w_csn_int;
    wire w_spi_busy = (w_csn_int == 1'b0);

    reg [7:0] r_reg_addr_latched;   // ADDR = SW[7:0]
    reg [7:0] r_data_latched;       // DATA = SW[15:8]
    reg       r_mode_latched;       // 1=WRITE, 0=READ (lay tai thoi diem bat dau)
    reg       r_spi_ready_pulse;    // xung 1 chu ky de kick controller

    // latched lenh/che do gui xuong controller
    reg [7:0] r_inst;               // 0x0A (WRITE) hoac 0x0B (READ)
    reg       r_sel_rw;             // 0=WRITE, 1=READ

    always @(posedge top_i_clk) begin
        if (w_rst_sync) begin
            r_reg_addr_latched <= 8'h00;
            r_data_latched     <= 8'h00;
            r_mode_latched     <= 1'b0;
            r_spi_ready_pulse  <= 1'b0;
            r_inst             <= 8'h0B;
            r_sel_rw           <= 1'b1;
        end else begin
            r_spi_ready_pulse <= 1'b0; // mac dinh
            if (w_ready_edge && !w_spi_busy) begin
                // chot tham so giao dich tai thoi diem bat dau
                r_reg_addr_latched <= top_i_sw[7:0];
                r_data_latched     <= top_i_sw[15:8];
                r_mode_latched     <= w_mode_db;

                // chon lenh READ/WRITE theo mode
                if (w_mode_db) begin
                    // WRITE
                    r_inst   <= 8'h0A;
                    r_sel_rw <= 1'b0;
                end else begin
                    // READ
                    r_inst   <= 8'h0B;
                    r_sel_rw <= 1'b1;
                end

                // phat xung start
                r_spi_ready_pulse <= 1'b1;
            end
        end
    end

    // =========================
    // 4) SPI controller (READ/WRITE 1 BYTE)
    // =========================
    wire [7:0] w_din;
    wire       w_din_valid;

    spi_adxl362_controller u_spi (
        .i_clk      (top_i_clk),
        .i_rst      (w_rst_sync),

        .o_csn      (w_csn_int),
        .o_sclk     (top_o_sclk),
        .o_mosi     (top_o_mosi),
        .i_miso     (top_i_miso),

        .i_ready    (r_spi_ready_pulse),   // xung start 1 chu ky
        .i_inst     (r_inst),              // 0x0A hoac 0x0B
        .i_sel_rw   (r_sel_rw),            // 0=WRITE, 1=READ
        .i_reg_addr (r_reg_addr_latched),
        .i_dout     (r_data_latched),
        .o_din      (w_din),
        .o_din_valid(w_din_valid)
    );

    // =========================
    // 5) LED: WRITE -> hien DATA; READ -> hien byte doc duoc
    // =========================
    reg [7:0] r_led_data;
    always @(posedge top_i_clk) begin
        if (w_rst_sync) begin
            r_led_data <= 8'h00;
        end else begin
            // neu la WRITE: latch ngay khi bat dau (de xem nhanh gia tri se ghi)
            if (w_ready_edge && !w_spi_busy && w_mode_db) begin
                r_led_data <= top_i_sw[15:8];
            end
            // neu la READ: latch khi o_din_valid=1
            else if (w_din_valid && (r_mode_latched == 1'b0)) begin
                r_led_data <= w_din;
            end
        end
    end

    // =========================
    // 6) Map ra cong top
    // =========================
    assign top_o_csn = w_csn_int;
    assign top_o_din = r_led_data;

endmodule
