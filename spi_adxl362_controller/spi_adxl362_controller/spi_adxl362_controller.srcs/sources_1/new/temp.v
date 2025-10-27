module spi_adxl362_controller(
    input        i_clk,
    input        i_rst,

    output reg   o_csn,
    output reg   o_sclk,
    output reg   o_mosi,
    input        i_miso,

    input        i_ready,
    input  [7:0] i_inst,
    input        i_sel_rw,
    input  [7:0] i_reg_addr,
    input  [7:0] i_dout,
    output reg [7:0] o_din,
    output reg       o_din_valid
);

    // =========================
    // Tham so tao SCLK (100MHz -> 5MHz)
    // =========================
    // Toggle SCLK moi 10 xung i_clk => T_sclk/2 = 10, T_sclk = 20 xung i_clk
    // Delay MOSI = 1/4 chu ky SCLK = 5 xung i_clk
    localparam [7:0] SCLK_TOGGLE = 8'd10; // so xung i_clk giua 2 lan dao SCLK
    localparam [7:0] MOSI_DELAY  = 8'd5;  // 1/4 chu ky SCLK (20/4=5)

    // =========================
    // SCLK gen
    // =========================
    reg       r_sclk_en;
    reg [7:0] r_sclk_count;
    reg       r_sclk_d;

    always @(posedge i_clk) begin
        if (i_rst || ~r_sclk_en) begin
            o_sclk       <= 1'b0;
            r_sclk_count <= 8'd0;
        end
        else if (r_sclk_en && (r_sclk_count < (SCLK_TOGGLE - 1) )) begin
            r_sclk_count <= r_sclk_count + 8'd1;
        end
        else begin
            o_sclk       <= ~o_sclk;
            r_sclk_count <= 8'd0;
        end
    end

    // Edge detect SCLK
    always @(posedge i_clk) begin
        if (i_rst) r_sclk_d <= 1'b0;
        else       r_sclk_d <= o_sclk;
    end

    wire w_sclk_posedge = (r_sclk_d == 1'b0) && (o_sclk == 1'b1);
    wire w_sclk_negedge = (r_sclk_d == 1'b1) && (o_sclk == 1'b0);

    // =========================
    // Delay 1/4 SCLK sau canh xuong de cap nhat MOSI
    // =========================
    reg       r_mosi_wait;               // dang cho den moc delay
    reg [7:0] r_mosi_delay_cnt;
    reg       r_mosi_strobe;             // xung 1 chu ky tai moc delay

    always @(posedge i_clk) begin
        if (i_rst || ~r_sclk_en) begin
            r_mosi_wait      <= 1'b0;
            r_mosi_delay_cnt <= 8'd0;
            r_mosi_strobe    <= 1'b0;
        end else begin
            r_mosi_strobe <= 1'b0; // mac dinh
            if (w_sclk_negedge) begin
                // bat dau dem sau canh xuong SCLK
                r_mosi_wait      <= 1'b1;
                r_mosi_delay_cnt <= 8'd0;
            end else if (r_mosi_wait) begin
                if (r_mosi_delay_cnt == (MOSI_DELAY - 1)) begin
                    r_mosi_wait   <= 1'b0;
                    r_mosi_strobe <= 1'b1; // den moc 1/4 chu ky SCLK -> phat xung
                end else begin
                    r_mosi_delay_cnt <= r_mosi_delay_cnt + 8'd1;
                end
            end
        end
    end

    wire w_mosi_strobe = r_mosi_strobe; // dung thay cho w_sclk_negedge khi shift MOSI

    // =========================
    // Edge detect i_ready
    // =========================
    reg r_ready_d;
    always @(posedge i_clk) begin
        if (i_rst) r_ready_d <= 1'b0;
        else       r_ready_d <= i_ready;
    end
    wire w_ready_posedge = (~r_ready_d) & i_ready;

    // =========================
    // FSM
    // =========================
    reg [2:0] r_state, r_next_state;
    localparam IDLE       = 3'd0;
    localparam START      = 3'd1;
    localparam INST_OUT   = 3'd2;
    localparam ADDR_OUT   = 3'd3;
    localparam WRITE_DATA = 3'd4;
    localparam READ_DATA  = 3'd5;
    localparam ENDING     = 3'd6;

    reg [7:0] r_mosi_buf;
    reg [6:0] r_miso_buf;
    reg [2:0] r_bitcount;

    // state reg
    always @(posedge i_clk) begin
        if (i_rst) r_state <= IDLE;
        else       r_state <= r_next_state;
    end

    // FSM next/outputs
    always @(posedge i_clk) begin
        case (r_state)
            IDLE: begin
                r_next_state <= START;
                o_mosi       <= 1'b0;
                o_csn        <= 1'b1;
                r_sclk_en    <= 1'b0;
                r_mosi_buf   <= i_inst;
                r_bitcount   <= 3'd0;
                o_din        <= 8'd0;
                o_din_valid  <= 1'b0;
            end

            START: begin
                if (w_ready_posedge) begin
                    o_csn      <= 1'b0;
                    r_sclk_en  <= 1'b1;
                    r_mosi_buf <= {i_inst[6:0], 1'b0};
                    o_mosi     <= i_inst[7]; // xuat bit MSB truoc
                    r_bitcount <= 3'd0;
                    r_next_state <= INST_OUT;
                end
            end

            // ========== MOSI shift sau 1/4 SCLK ==========
            INST_OUT: begin
                if (w_mosi_strobe && (r_bitcount < 3'd7)) begin
                    {o_mosi, r_mosi_buf} <= {r_mosi_buf, 1'b0};
                    r_bitcount <= r_bitcount + 3'd1;
                end
                else if (w_mosi_strobe) begin
                    {o_mosi, r_mosi_buf} <= {i_reg_addr, 1'b0}; // nap dia chi
                    r_bitcount   <= 3'd0;
                    r_next_state <= ADDR_OUT;
                end
            end

            ADDR_OUT: begin
                if (w_mosi_strobe && (r_bitcount < 3'd7)) begin
                    {o_mosi, r_mosi_buf} <= {r_mosi_buf, 1'b0};
                    r_bitcount <= r_bitcount + 3'd1;
                end
                else if (w_mosi_strobe) begin
                    {o_mosi, r_mosi_buf} <= {i_dout, 1'b0}; // nap data ghi
                    r_bitcount <= 3'd0;
                    if (i_sel_rw) r_next_state <= READ_DATA;
                    else          r_next_state <= WRITE_DATA;
                end
            end

            WRITE_DATA: begin
                if (w_mosi_strobe && (r_bitcount < 3'd7)) begin
                    {o_mosi, r_mosi_buf} <= {r_mosi_buf, 1'b0};
                    r_bitcount <= r_bitcount + 3'd1; // sua dung 3'd1
                end
                else if (w_mosi_strobe) begin
                    {o_mosi, r_mosi_buf} <= 9'h0;
                    r_bitcount   <= 3'd0;
                    r_next_state <= ENDING;
                end
            end

            // MISO sample o canh len SCLK (giu nguyen)
            READ_DATA: begin
                if (w_sclk_posedge && (r_bitcount < 3'd7)) begin
                    r_miso_buf <= {r_miso_buf[5:0], i_miso};
                    r_bitcount <= r_bitcount + 3'd1;
                end
                else if (w_sclk_posedge) begin
                    r_bitcount  <= 3'd0;
                    o_din       <= {r_miso_buf, i_miso};
                    o_din_valid <= 1'b1;
                    r_next_state<= ENDING;
                end
                else begin
                    o_din_valid <= 1'b0;
                end
            end

            ENDING: begin
                if (w_sclk_negedge) begin
                    o_csn     <= 1'b1;
                    r_sclk_en <= 1'b0;
                    r_next_state <= IDLE;
                end
            end

            default: r_next_state <= r_state;
        endcase
    end

endmodule 

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
