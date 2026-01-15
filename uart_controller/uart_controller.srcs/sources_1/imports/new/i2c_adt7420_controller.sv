`timescale 1ns/1ps

module i2c_adt7420_controller
#(
    parameter   DEVICE_ADDR  = 7'b1001_011  ,
    parameter   SYS_CLK_FREQ = 'd100_000_000,
    parameter   SCL_FREQ     = 'd200_000
)
(
    input   wire            sys_clk     ,
    input   wire            sys_rst     ,   // reset muc cao

    inout   wire            i2c_sda     ,

    output  reg             i2c_scl     ,
    output  reg     [7:0]   rd_data     ,

    // Hien thi tren Nexys A7: 8 digit 7 thanh, dung 6 digit dau
    output  reg     [6:0]   seg         ,   // gfedcba, active low
    output  reg             dp          ,   // dau cham thap phan, active low
    output  reg     [7:0]   an              // AN7..AN0, active low
);

    wire rst = sys_rst;

    // --------------------------------------------------------------------
    localparam CNT_CLK_MAX    = (SYS_CLK_FREQ / SCL_FREQ) >> 3;
    localparam CNT_DELAY_MAX  = 20'd125000;

    localparam   IDLE         = 4'd0,
                 START        = 4'd1,
                 SEND_D_ADDR  = 4'd2,
                 ACK_1        = 4'd3,
                 SEND_R_ADDR  = 4'd4,
                 ACK_2        = 4'd5,
                 RE_START     = 4'd6,
                 RSEND_D_ADDR = 4'd7,
                 ACK_3        = 4'd8,
                 RD_DATA_MSB  = 4'd9,
                 MASTER_ACK   = 4'd10,
                 RD_DATA_LSB  = 4'd11,
                 NO_ACK       = 4'd12,
                 STOP         = 4'd13;

    reg     [19:0]  cnt_delay;
    reg     [7:0]   cnt_clk;
    reg             i2c_clk;
    reg     [3:0]   state;
    reg     [1:0]   cnt_i2c_clk;
    reg             cnt_i2c_clk_en;
    reg     [3:0]   cnt_bit;

    wire            sda_in;
    reg             sda_out;
    wire            sda_en;

    reg     [15:0]  rd_data_reg;
    reg             ack;

    // --------------------------------------------------------------------
    // Tao i2c_clk tu sys_clk
    // --------------------------------------------------------------------
    always @(posedge sys_clk or posedge rst) begin
        if (rst)
            cnt_clk <= 0;
        else if (cnt_clk == CNT_CLK_MAX - 1)
            cnt_clk <= 0;
        else
            cnt_clk <= cnt_clk + 1;
    end

    always @(posedge sys_clk or posedge rst) begin
        if (rst)
            i2c_clk <= 1;
        else if (cnt_clk == CNT_CLK_MAX - 1)
            i2c_clk <= ~i2c_clk;
    end

    // --------------------------------------------------------------------
    // Delay khoi dong
    // --------------------------------------------------------------------
    always @(posedge i2c_clk or posedge rst) begin
        if (rst)
            cnt_delay <= 0;
        else if (cnt_delay == CNT_DELAY_MAX - 1)
            cnt_delay <= 0;
        else if (cnt_i2c_clk == 3 && state == IDLE)
            cnt_delay <= cnt_delay + 1;
    end

    // --------------------------------------------------------------------
    // FSM I2C
    // --------------------------------------------------------------------
    always @(posedge i2c_clk or posedge rst) begin
        if (rst)
            state <= IDLE;
        else begin
            case (state)
                IDLE:
                    state <= (cnt_delay == CNT_DELAY_MAX - 1) ? START : IDLE;

                START:
                    state <= (cnt_i2c_clk == 3) ? SEND_D_ADDR : START;

                SEND_D_ADDR:
                    state <= (cnt_i2c_clk == 3 && cnt_bit == 7) ? ACK_1 : SEND_D_ADDR;

                ACK_1:
                    state <= (cnt_i2c_clk == 3 && ack == 0) ? SEND_R_ADDR : ACK_1;

                SEND_R_ADDR:
                    state <= (cnt_i2c_clk == 3 && cnt_bit == 7) ? ACK_2 : SEND_R_ADDR;

                ACK_2:
                    state <= (cnt_i2c_clk == 3 && ack == 0) ? RE_START : ACK_2;

                RE_START:
                    state <= (cnt_i2c_clk == 3) ? RSEND_D_ADDR : RE_START;

                RSEND_D_ADDR:
                    state <= (cnt_i2c_clk == 3 && cnt_bit == 7) ? ACK_3 : RSEND_D_ADDR;

                ACK_3:
                    state <= (cnt_i2c_clk == 3 && ack == 0) ? RD_DATA_MSB : ACK_3;

                RD_DATA_MSB:
                    state <= (cnt_i2c_clk == 3 && cnt_bit == 7) ? MASTER_ACK : RD_DATA_MSB;

                MASTER_ACK:
                    state <= (cnt_i2c_clk == 3) ? RD_DATA_LSB : MASTER_ACK;

                RD_DATA_LSB:
                    state <= (cnt_i2c_clk == 3 && cnt_bit == 7) ? NO_ACK : RD_DATA_LSB;

                NO_ACK:
                    state <= (cnt_i2c_clk == 3) ? STOP : NO_ACK;

                STOP:
                    state <= (cnt_i2c_clk == 3 && cnt_bit == 3) ? IDLE : STOP;
            endcase
        end
    end

    // --------------------------------------------------------------------
    // Pha I2C
    // --------------------------------------------------------------------
    always @(posedge i2c_clk or posedge rst) begin
        if (rst)
            cnt_i2c_clk <= 0;
        else if (state == STOP && cnt_i2c_clk == 3 && cnt_bit == 3)
            cnt_i2c_clk <= 0;
        else
            cnt_i2c_clk <= cnt_i2c_clk + 1;
    end

    always @(posedge i2c_clk or posedge rst) begin
        if (rst)
            cnt_i2c_clk_en <= 0;
        else if (state == STOP && cnt_i2c_clk == 3 && cnt_bit == 3)
            cnt_i2c_clk_en <= 0;
        else if (state == IDLE && cnt_i2c_clk == 3)
            cnt_i2c_clk_en <= 1;
    end

    // --------------------------------------------------------------------
    // Dem bit data
    // --------------------------------------------------------------------
    always @(posedge i2c_clk or posedge rst) begin
        if (rst)
            cnt_bit <= 0;
        else if (state == IDLE || state == START || state == ACK_1 || state == ACK_2 ||
                 state == RE_START || state == ACK_3 || state == MASTER_ACK || state == NO_ACK)
            cnt_bit <= 0;
        else if (cnt_bit == 7 && cnt_i2c_clk == 3)
            cnt_bit <= 0;
        else if (cnt_i2c_clk == 3)
            cnt_bit <= cnt_bit + 1;
    end

    // --------------------------------------------------------------------
    // SDA open drain
    // --------------------------------------------------------------------
    assign i2c_sda = sda_en ? 1'bz : sda_out;
    assign sda_in  = i2c_sda;

    always @(*) begin
        case (state)
            IDLE:           sda_out = 1;
            START:          sda_out = (cnt_i2c_clk == 0) ? 1 : 0;
            SEND_D_ADDR:    sda_out = (cnt_bit == 7) ? 0 : DEVICE_ADDR[6 - cnt_bit];
            ACK_1:          sda_out = 0;
            SEND_R_ADDR:    sda_out = 0;
            ACK_2:          sda_out = 1;
            RE_START:       sda_out = (cnt_i2c_clk <= 1) ? 1 : 0;
            RSEND_D_ADDR:   sda_out = (cnt_bit == 7) ? 1 : DEVICE_ADDR[6 - cnt_bit];
            ACK_3:          sda_out = 1;
            RD_DATA_MSB:    sda_out = 1;
            MASTER_ACK:     sda_out = 0;
            RD_DATA_LSB:    sda_out = 1;
            NO_ACK:         sda_out = 1;
            STOP:           sda_out = (cnt_bit == 0 && cnt_i2c_clk < 3) ? 0 : 1;
            default:        sda_out = 1;
        endcase
    end

    assign sda_en = (state == ACK_1 || state == ACK_2 || state == ACK_3 ||
                     state == RD_DATA_MSB || state == RD_DATA_LSB);

    // --------------------------------------------------------------------
    // Bat data tu SDA
    // --------------------------------------------------------------------
    always @(posedge i2c_clk or posedge rst) begin
        if (rst)
            rd_data_reg <= 0;
        else begin
            if (state == RD_DATA_MSB && cnt_i2c_clk == 1)
                rd_data_reg[15 - cnt_bit] <= sda_in;
            if (state == RD_DATA_LSB && cnt_i2c_clk == 1)
                rd_data_reg[7 - cnt_bit]  <= sda_in;
        end
    end

    // --------------------------------------------------------------------
    // Chuyen sang Q6.2 va luu vao rd_data
    // rd_data: [7:2] phan nguyen, [1:0] phan thap phan 0.25
    // --------------------------------------------------------------------
    wire [11:0] temp_raw     = rd_data_reg[14:3];  // 0.0625°C/LSB
    wire [9:0]  temp_q62_10  = temp_raw >> 2;      // 0.25°C/LSB

    always @(posedge i2c_clk or posedge rst) begin
        if (rst)
            rd_data <= 0;
        else if (state == RD_DATA_LSB && cnt_bit == 7 && cnt_i2c_clk == 3)
            rd_data <= (temp_q62_10 > 255) ? 8'hFF : temp_q62_10[7:0];
    end

    // --------------------------------------------------------------------
    // Tao SCL tu i2c_clk
    // --------------------------------------------------------------------
    always @(posedge i2c_clk or posedge rst) begin
        if (rst)
            i2c_scl <= 1;
        else if ((cnt_i2c_clk == 2 || cnt_i2c_clk == 3) && state != STOP && state != IDLE)
            i2c_scl <= 0;
        else
            i2c_scl <= 1;
    end

    // --------------------------------------------------------------------
    // Lay ACK
    // --------------------------------------------------------------------
    always @(*) begin
        case (state)
            ACK_1, ACK_2, ACK_3:
                if (cnt_i2c_clk == 0)
                    ack = sda_in;
                else
                    ack = ack;
            default:
                ack = 1;
        endcase
    end

    // ========================================================
    // Hien thi xx.xx°C tren 6 digit
    //
    // Q6.2  1 LSB = 0.25°C
    // nhiet do * 100 = rd_data * 25  (centi degree)
    // vi du: 27.50°C -> rd_data = 110  (vi 27.5 / 0.25 = 110)
    // temp_centi = 110 * 25 = 2750  -> 27.50°C
    // ========================================================

    // 255 * 25 = 6375 < 2^13, du 13 bit, dung 14 bit cho du
    wire [13:0] temp_centi = rd_data * 8'd25;

    wire [6:0] temp_int  = temp_centi / 14'd100;  // 0..63
    wire [6:0] temp_frac = temp_centi % 14'd100;  // 0..99

    wire [3:0] int_tens  = temp_int  / 10;
    wire [3:0] int_ones  = temp_int  % 10;
    wire [3:0] frac_tens = temp_frac / 10;
    wire [3:0] frac_ones = temp_frac % 10;

    // Encoder so
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
                default: seg7_encode_digit = 7'b1111111;
            endcase
        end
    endfunction

    // Chu C
    function [6:0] seg7_encode_C;
        input dummy;
        begin
            seg7_encode_C = 7'b1000110; // C
        end
    endfunction

    // Ky hieu do
    function [6:0] seg7_degree;
        input dummy;
        begin
            // mot "o" nho phia tren trai, co the chinh lai neu muon
            seg7_degree = 7'b0011100;
        end
    endfunction

    // --------------------------------------------------------------------
    // Scan 8 digit, dung 6 digit dau tien (AN0..AN5), AN6..AN7 luon tat
    // --------------------------------------------------------------------
    reg [17:0] scan_cnt;

    always @(posedge sys_clk or posedge rst) begin
        if (rst)
            scan_cnt <= 0;
        else
            scan_cnt <= scan_cnt + 1;
    end

    wire [2:0] digit_sel = scan_cnt[17:15];   // 0..7, ta chi dung 0..5

    reg [6:0] seg_next;
    reg [7:0] an_next;
    reg       dp_next;

    always @(*) begin
        seg_next = 7'b1111111;
        an_next  = 8'b1111_1111;
        dp_next  = 1;  // active low

        case (digit_sel)
            3'd0: begin
                // D0: C
                seg_next = seg7_encode_C(1'b0);
                an_next  = 8'b1111_1110;  // AN0
                dp_next  = 1;
            end
            3'd1: begin
                // D1: ky hieu do
                seg_next = seg7_degree(1'b0);
                an_next  = 8'b1111_1101;  // AN1
                dp_next  = 1;
            end
            3'd2: begin
                // D2: frac ones
                seg_next = seg7_encode_digit(frac_ones);
                an_next  = 8'b1111_1011;  // AN2
                dp_next  = 1;
            end
            3'd3: begin
                // D3: frac tens
                seg_next = seg7_encode_digit(frac_tens);
                an_next  = 8'b1111_0111;  // AN3
                dp_next  = 1;
            end
            3'd4: begin
                // D4: int ones + dau cham thap phan
                seg_next = seg7_encode_digit(int_ones);
                an_next  = 8'b1110_1111;  // AN4
                dp_next  = 0;             // bat DP tai digit nay
            end
            3'd5: begin
                // D5: int tens
                seg_next = seg7_encode_digit(int_tens);
                an_next  = 8'b1101_1111;  // AN5
                dp_next  = 1;
            end

            default: begin
                // AN6, AN7 tat
                seg_next = 7'b1111111;
                an_next  = 8'b1111_1111;
                dp_next  = 1;
            end
        endcase
    end

    always @(posedge sys_clk or posedge rst) begin
        if (rst) begin
            seg <= 7'b1111111;
            an  <= 8'b1111_1111;
            dp  <= 1;
        end else begin
            seg <= seg_next;
            an  <= an_next;
            dp  <= dp_next;
        end
    end

endmodule
