// ==============================================
// top.v
// Top level: nut READY -> yeu cau giao dich
// - Debounce reset, ready, mode
// - READY duoc giu muc 1 (req) den khi CSN keo xuong (ack)
// - WRITE: LED hien DATA (SW[15:8]) tai thoi diem bat dau
// - READ : LED latched khi o_din_valid=1
// ==============================================
`timescale 1ns / 1ps
module top (
    input         top_i_clk,
    input         top_i_rst,     // nut reset chua loc (muc cao = reset)
    input         top_i_ready,   // nut start chua loc
    input         top_i_mode,    // 1=WRITE, 0=READ

    output        top_o_csn,
    output        top_o_sclk,
    output        top_o_mosi,
    input         top_i_miso,

    output [7:0]  top_o_din,     // 8 LED don
    input  [15:0] top_i_sw       // [15:8]=DATA, [7:0]=ADDR
);

    // ------------------------------------------
    // Debounce RESET
    // ------------------------------------------
    wire w_rst_sync;
    debounce #(
        .CLK_FREQ(100_000_000),
        .DEBOUNCE_TIME_MS(20)
    ) u_db_rst (
        .I_clk     (top_i_clk),
        .I_rst     (1'b0),
        .I_btn_in  (top_i_rst),
        .O_btn_out (w_rst_sync)
    );

    // ------------------------------------------
    // Debounce READY + tao edge
    // ------------------------------------------
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

    // ------------------------------------------
    // Debounce MODE
    // ------------------------------------------
    wire w_mode_db;   // 1=WRITE, 0=READ
    debounce #(
        .CLK_FREQ(100_000_000),
        .DEBOUNCE_TIME_MS(20)
    ) u_db_mode (
        .I_clk     (top_i_clk),
        .I_rst     (w_rst_sync),
        .I_btn_in  (top_i_mode),
        .O_btn_out (w_mode_db)
    );

    // ------------------------------------------
    // Busy gating + req/ack giu muc
    // ------------------------------------------
    wire w_csn_int;
    wire w_spi_busy = (w_csn_int == 1'b0);

    reg [7:0] r_reg_addr_latched;  // SW[7:0]
    reg [7:0] r_data_latched;      // SW[15:8]
    reg       r_mode_latched;      // 1=WRITE, 0=READ

    // req giu muc 1 den khi controller ack (CSN keo xuong)
    reg r_req;
    always @(posedge top_i_clk) begin
        if (w_rst_sync) begin
            r_req           <= 1'b0;
            r_reg_addr_latched <= 8'h00;
            r_data_latched     <= 8'h00;
            r_mode_latched     <= 1'b0;
        end else begin
            // nhan nut: set req neu khong busy, dong thoi chot tham so
            if (w_ready_edge && !w_spi_busy) begin
                r_req               <= 1'b1;
                r_reg_addr_latched  <= top_i_sw[7:0];
                r_data_latched      <= top_i_sw[15:8];
                r_mode_latched      <= w_mode_db;
            end
            // controller ack: CSN=0 -> xoa req
            if (!w_csn_int) begin
                r_req <= 1'b0;
            end
        end
    end

    // Chon lenh va sel_rw dua theo mode tai thoi diem bat dau
    wire [7:0] w_inst   = r_mode_latched ? 8'h0A : 8'h0B; // 0x0A WRITE, 0x0B READ
    wire       w_sel_rw = r_mode_latched ? 1'b0   : 1'b1; // 0=WRITE, 1=READ

    // ------------------------------------------
    // SPI controller
    // ------------------------------------------
    wire [7:0] w_din;
    wire       w_din_valid;

    spi_adxl362_controller u_spi (
        .i_clk      (top_i_clk),
        .i_rst      (w_rst_sync),

        .o_csn      (w_csn_int),
        .o_sclk     (top_o_sclk),
        .o_mosi     (top_o_mosi),
        .i_miso     (top_i_miso),

        .i_ready    (r_req),                // level req -> se duoc latch ben trong
        .i_inst     (w_inst),
        .i_sel_rw   (w_sel_rw),
        .i_reg_addr (r_reg_addr_latched),
        .i_dout     (r_data_latched),
        .o_din      (w_din),
        .o_din_valid(w_din_valid)
    );

    // ------------------------------------------
    // LED hien thi
    // - WRITE: hien data da latched tai thoi diem nhan nut
    // - READ : hien byte doc duoc khi o_din_valid=1
    // ------------------------------------------
    reg [7:0] r_led_data;
    always @(posedge top_i_clk) begin
        if (w_rst_sync) begin
            r_led_data <= 8'h00;
        end else begin
            // write: hien ngay khi chot tham so (nhan nut)
            if (w_ready_edge && !w_spi_busy && w_mode_db) begin
                r_led_data <= top_i_sw[15:8];
            end
            // read: hien khi o_din_valid
            else if (w_din_valid && (r_mode_latched == 1'b0)) begin
                r_led_data <= w_din;
            end
        end
    end

    // Map ra cong top
    assign top_o_csn = w_csn_int;
    assign top_o_din = r_led_data;

endmodule
