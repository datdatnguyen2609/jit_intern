// ==============================================
// top.v (simple)
// - READY giu muc den khi CSN len (giao dich xong)
// - LED: WRITE -> hien ngay data; READ -> khi o_din_valid
// ==============================================
`timescale 1ns / 1ps
module top (
    input         top_i_clk,
    input         top_i_rst,    // nut reset chua loc (muc cao = reset)
    input         top_i_ready,  // nut start
    input         top_i_mode,   // 1=WRITE, 0=READ

    output        top_o_csn,
    output        top_o_sclk,
    output        top_o_mosi,
    input         top_i_miso,

    output [7:0]  top_o_din,    // 8 LED don
    input  [15:0] top_i_sw      // [15:8]=DATA, [7:0]=ADDR
);

    // =========================
    // 1) Debounce reset / ready / mode
    // =========================
    wire w_rst_sync;
    debounce #(.CLK_FREQ(100_000_000), .DEBOUNCE_TIME_MS(20)) u_db_rst (
        .I_clk(top_i_clk), .I_rst(1'b0), .I_btn_in(top_i_rst), .O_btn_out(w_rst_sync)
    );

    wire w_ready_db, w_mode_db;
    debounce #(.CLK_FREQ(100_000_000), .DEBOUNCE_TIME_MS(20)) u_db_ready (
        .I_clk(top_i_clk), .I_rst(w_rst_sync), .I_btn_in(top_i_ready), .O_btn_out(w_ready_db)
    );
    debounce #(.CLK_FREQ(100_000_000), .DEBOUNCE_TIME_MS(20)) u_db_mode (
        .I_clk(top_i_clk), .I_rst(w_rst_sync), .I_btn_in(top_i_mode), .O_btn_out(w_mode_db)
    );

    // canh len cua READY sau debounce
    reg r_ready_q;
    always @(posedge top_i_clk) begin
        if (w_rst_sync) r_ready_q <= 1'b0;
        else            r_ready_q <= w_ready_db;
    end
    wire w_ready_edge = w_ready_db & ~r_ready_q;

    // =========================
    // 2) SPI controller
    // =========================
    wire        w_csn;
    wire [7:0]  w_din;
    wire        w_din_valid;

    // tham so latched cho moi giao dich
    reg  [7:0] r_addr_l, r_data_l;
    reg        r_mode_l;      // 1=WRITE, 0=READ
    reg        r_req;         // giu muc den khi CSN len

    // phat req khi bam READY o luc CSN dang high (khong ban)
    // xoa req khi CSN len lai
    reg r_csn_q;
    always @(posedge top_i_clk) begin
        if (w_rst_sync) begin
            r_csn_q   <= 1'b1;
            r_req     <= 1'b0;
            r_addr_l  <= 8'h00;
            r_data_l  <= 8'h00;
            r_mode_l  <= 1'b0;
        end else begin
            r_csn_q <= w_csn;

            // khoi tao giao dich
            if (w_ready_edge && w_csn) begin
                r_req    <= 1'b1;
                r_addr_l <= top_i_sw[7:0];
                r_data_l <= top_i_sw[15:8];
                r_mode_l <= w_mode_db;
            end

            // ket thuc giao dich khi CSN len
            if (~r_csn_q && w_csn) begin
                r_req <= 1'b0;
            end
        end
    end

    // ma lenh theo mode da latched
    wire [7:0] w_inst   = r_mode_l ? 8'h0A : 8'h0B; // WRITE/READ
    wire       w_sel_rw = r_mode_l ? 1'b0  : 1'b1;  // 0=WRITE, 1=READ

    spi_adxl362_controller u_spi (
        .i_clk      (top_i_clk),
        .i_rst      (w_rst_sync),
        .o_csn      (w_csn),
        .o_sclk     (top_o_sclk),
        .o_mosi     (top_o_mosi),
        .i_miso     (top_i_miso),
        .i_ready    (r_req),          // level
        .i_inst     (w_inst),
        .i_sel_rw   (w_sel_rw),
        .i_reg_addr (r_addr_l),
        .i_dout     (r_data_l),
        .o_din      (w_din),
        .o_din_valid(w_din_valid)
    );

    // =========================
    // 3) Hien thi LED
    // =========================
    reg [7:0] r_led;
    always @(posedge top_i_clk) begin
        if (w_rst_sync) r_led <= 8'h00;
        else begin
            // WRITE: cap nhat ngay khi bam nut (neu khong ban)
            if (w_ready_edge && w_csn && w_mode_db) r_led <= top_i_sw[15:8];
            // READ: chi cap nhat khi co din_valid
            else if (w_din_valid && ~r_mode_l)      r_led <= w_din;
        end
    end

    // =========================
    // 4) Gan ra ngoai
    // =========================
    assign top_o_csn = w_csn;
    assign top_o_din = r_led;

endmodule
