`timescale 1ns/1ps

module i2c_adt7420_controller
#(
    parameter   DEVICE_ADDR  = 7'b1001_011  ,  // 7-bit (ví d? ADT7420 = 0x48..0x4B)
    parameter   SYS_CLK_FREQ = 'd100_000_000,
    parameter   SCL_FREQ     = 'd200_000
)
(
    input   wire            sys_clk     ,
    input   wire            sys_rst_n   ,   // active-LOW

    inout   wire            i2c_sda     ,

    output  reg             i2c_scl     ,
    output  reg     [7:0]   rd_data         // Q6.2: {6-bit int, 2-bit frac}
);

    // =========================
    // Tham s? n?i b?
    // =========================
    localparam CNT_CLK_MAX    = (SYS_CLK_FREQ / SCL_FREQ) >> 3; // chia 8 ?? t?o 4 pha cho i2c_clk
    localparam CNT_DELAY_MAX  = 20'd125_000;

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

    // =========================
    // Thanh ghi / dây
    // =========================
    reg     [19:0]  cnt_delay;
    reg     [7:0]   cnt_clk;
    reg             i2c_clk;        // clock ch?m h?n sys_clk ~ SCL*2
    reg     [3:0]   state;
    reg     [1:0]   cnt_i2c_clk;    // 4 pha (00,01,10,11)
    reg             cnt_i2c_clk_en;
    reg     [3:0]   cnt_bit;        // ??m bit 0..7
    wire            sda_in;
    reg             sda_out;
    wire            sda_en;
    reg     [15:0]  rd_data_reg;
    reg             ack;

    // =========================
    // T?o i2c_clk t? sys_clk
    // =========================
    always @(posedge sys_clk or negedge sys_rst_n) begin
        if (!sys_rst_n)
            cnt_clk <= 8'd0;
        else if (cnt_clk == CNT_CLK_MAX - 1)
            cnt_clk <= 8'd0;
        else
            cnt_clk <= cnt_clk + 8'd1;
    end

    always @(posedge sys_clk or negedge sys_rst_n) begin
        if (!sys_rst_n)
            i2c_clk <= 1'b1;
        else if (cnt_clk == CNT_CLK_MAX - 1)
            i2c_clk <= ~i2c_clk;
    end

    // =========================
    // B? ??m ch? delay / kh?i ??ng l?i
    // =========================
    always @(posedge i2c_clk or negedge sys_rst_n) begin
        if (!sys_rst_n)
            cnt_delay <= 20'd0;
        else if (cnt_delay == CNT_DELAY_MAX - 1)
            cnt_delay <= 20'd0;
        else if (cnt_i2c_clk == 2'd3 && state == IDLE)
            cnt_delay <= cnt_delay + 20'd1;
    end

    // =========================
    // FSM tr?ng thái
    // =========================
    always @(posedge i2c_clk or negedge sys_rst_n) begin
        if (!sys_rst_n)
            state <= IDLE;
        else begin
            case (state)
                IDLE :
                    state <= (cnt_delay == CNT_DELAY_MAX - 1) ? START : IDLE;

                START :
                    state <= (cnt_i2c_clk == 2'd3) ? SEND_D_ADDR : START;

                SEND_D_ADDR :
                    state <= (cnt_i2c_clk == 2'd3 && cnt_bit == 3'd7) ? ACK_1 : SEND_D_ADDR;

                ACK_1 :
                    state <= (cnt_i2c_clk == 2'd3 && ack == 1'b0) ? SEND_R_ADDR : ACK_1;

                SEND_R_ADDR :
                    state <= (cnt_i2c_clk == 2'd3 && cnt_bit == 3'd7) ? ACK_2 : SEND_R_ADDR;

                ACK_2 :
                    state <= (cnt_i2c_clk == 2'd3 && ack == 1'b0) ? RE_START : ACK_2;

                RE_START :
                    state <= (cnt_i2c_clk == 2'd3) ? RSEND_D_ADDR : RE_START;

                RSEND_D_ADDR :
                    state <= (cnt_i2c_clk == 2'd3 && cnt_bit == 3'd7) ? ACK_3 : RSEND_D_ADDR;

                ACK_3 :
                    state <= (cnt_i2c_clk == 2'd3 && ack == 1'b0) ? RD_DATA_MSB : ACK_3;

                RD_DATA_MSB :
                    state <= (cnt_i2c_clk == 2'd3 && cnt_bit == 3'd7) ? MASTER_ACK : RD_DATA_MSB;

                MASTER_ACK :
                    state <= (cnt_i2c_clk == 2'd3) ? RD_DATA_LSB : MASTER_ACK;

                RD_DATA_LSB :
                    state <= (cnt_i2c_clk == 2'd3 && cnt_bit == 3'd7) ? NO_ACK : RD_DATA_LSB;

                NO_ACK :
                    state <= (cnt_i2c_clk == 2'd3) ? STOP : NO_ACK;

                STOP :
                    state <= (cnt_i2c_clk == 2'd3 && cnt_bit == 3'd3) ? IDLE : STOP;

                default:
                    state <= IDLE;
            endcase
        end
    end

    // =========================
    // Pha I2C (00,01,10,11)
    // =========================
    always @(posedge i2c_clk or negedge sys_rst_n) begin
        if (!sys_rst_n)
            cnt_i2c_clk <= 2'd0;
        else if (state == STOP && cnt_i2c_clk == 2'd3 && cnt_bit == 3'd3)
            cnt_i2c_clk <= 2'd0;
        else
            cnt_i2c_clk <= cnt_i2c_clk + 2'd1;
    end

    // =========================
    // Enable ??m pha (tu? ý)
    // =========================
    always @(posedge i2c_clk or negedge sys_rst_n) begin
        if (!sys_rst_n)
            cnt_i2c_clk_en <= 1'b0;
        else if (state == STOP && cnt_i2c_clk == 2'd3 && cnt_bit == 3'd3)
            cnt_i2c_clk_en <= 1'b0;
        else if (state == IDLE && cnt_i2c_clk == 2'd3)
            cnt_i2c_clk_en <= 1'b1;
    end

    // =========================
    // ??m bit d? li?u 0..7
    // =========================
    always @(posedge i2c_clk or negedge sys_rst_n) begin
        if (!sys_rst_n)
            cnt_bit <= 3'd0;
        else if (state == IDLE || state == START || state == ACK_1 || state == ACK_2 ||
                 state == RE_START || state == ACK_3 || state == MASTER_ACK || state == NO_ACK)
            cnt_bit <= 3'd0;
        else if ((cnt_bit == 3'd7) && (cnt_i2c_clk == 2'd3))
            cnt_bit <= 3'd0;
        else if ((cnt_i2c_clk == 2'd3) && (state != IDLE))
            cnt_bit <= cnt_bit + 3'd1;
    end

    // =========================
    // SDA: open-drain
    // =========================
    assign  i2c_sda = (sda_en == 1'b1) ? 1'bz : sda_out;  // en=1 -> input (Z), en=0 -> drive 0/1 (test)
    assign  sda_in  = i2c_sda;

    // L?u ý: I2C th?c t? ch? "kéo th?p" (0), còn m?c 1 nh? pull-up. ? ?ây gi? nguyên theo code g?c.

    // =========================
    // T?o m?u SDA theo tr?ng thái
    // =========================
    always @(*) begin
        case (state)
            IDLE :          sda_out = 1'b1;

            // START: SDA t? 1 -> 0 khi SCL ?ang 1
            START :         sda_out = (cnt_i2c_clk == 2'd0) ? 1'b1 : 1'b0;

            // G?i ??a ch? thi?t b? (WRITE = 0) -> bit R/W=0 là bit cu?i (cnt_bit==7)
            SEND_D_ADDR :   sda_out = (cnt_bit == 3'd7) ? 1'b0 : DEVICE_ADDR[6 - cnt_bit];

            // Ch? ACK t? slave (th? SDA)
            ACK_1 :         sda_out = 1'b0; // không quan tr?ng vì sda_en=1 ? pha ACK

            // G?i ??a ch? thanh ghi mu?n ??c (ví d? RegAddr=0x00) - ? code g?c set 0
            SEND_R_ADDR :   sda_out = 1'b0; // b?n có th? thay b?ng bi?n RegAddr[7-cnt_bit]

            ACK_2 :         sda_out = 1'b1;

            // Re-START
            RE_START :      sda_out = (cnt_i2c_clk <= 2'd1) ? 1'b1 : 1'b0;

            // G?i l?i ??a ch? thi?t b? v?i R/W=1 (??c)
            RSEND_D_ADDR :  sda_out = (cnt_bit == 3'd7) ? 1'b1 : DEVICE_ADDR[6 - cnt_bit];

            ACK_3 :         sda_out = 1'b1;

            // ??c MSB: th? SDA
            RD_DATA_MSB :   sda_out = 1'b1;

            // Master ACK sau byte MSB (kéo 0)
            MASTER_ACK :    sda_out = 1'b0;

            // ??c LSB: th? SDA
            RD_DATA_LSB :   sda_out = 1'b1;

            // Master NACK sau byte LSB (th? 1)
            NO_ACK :        sda_out = 1'b1;

            // STOP: SDA t? 0 -> 1 khi SCL ?ang 1
            STOP :          sda_out = (cnt_bit == 3'd0 && cnt_i2c_clk < 2'd3) ? 1'b0 : 1'b1;

            default :       sda_out = 1'b1;
        endcase
    end

    // Th?i ?i?m tri-state SDA: th? (input) khi slave lái (ACK/ d? li?u), còn l?i master lái
    assign  sda_en = (state == ACK_1 || state == ACK_2 || state == ACK_3 ||
                      state == RD_DATA_MSB || state == RD_DATA_LSB) ? 1'b1 : 1'b0;

    // =========================
    // B?t d? li?u ??c t? SDA
    // =========================
    always @(posedge i2c_clk or negedge sys_rst_n) begin
        if (!sys_rst_n) begin
            rd_data_reg <= 16'd0;
        end else begin
            case (state)
                RD_DATA_MSB : begin
                    if (cnt_i2c_clk == 2'b01) // sample ? pha 01 (SCL high)
                        rd_data_reg[15 - cnt_bit] <= sda_in;
                end
                RD_DATA_LSB : begin
                    if (cnt_i2c_clk == 2'b01)
                        rd_data_reg[7 - cnt_bit]  <= sda_in;
                end
                default: begin
                    // gi? nguyên
                end
            endcase
        end
    end

    // =========================
    // Chuy?n ??i sang 8-bit Q6.2
    // ADT7420: d? li?u 16-bit, 0.0625 °C/LSB t?i [14:3]
    // -> Q6.2 (0.25 °C/LSB) = (rd_data_reg[14:3] >> 2), bão hoà 8-bit
    // =========================
    wire [11:0] temp_raw     = rd_data_reg[14:3];   // 12-bit, 0.0625°C/LSB
    wire [9:0]  temp_q62_10  = temp_raw >> 2;       // chia 4 => 0.25°C/LSB

    always @(posedge i2c_clk or negedge sys_rst_n) begin
        if (!sys_rst_n) begin
            rd_data <= 8'd0;
        end else if (state == RD_DATA_LSB && cnt_bit == 3'd7 && cnt_i2c_clk == 2'd3) begin
            rd_data <= (temp_q62_10 > 10'd255) ? 8'hFF : temp_q62_10[7:0];
            // rd_data[7:2] = ph?n nguyên (0..63), rd_data[1:0] = ph?n th?p phân theo 0.25
        end
    end

    // =========================
    // T?o SCL (kéo th?p ? pha 2/3, tr? STOP/IDLE)
    // =========================
    always @(posedge i2c_clk or negedge sys_rst_n) begin
        if (!sys_rst_n)
            i2c_scl <= 1'b1;
        else if ((cnt_i2c_clk == 2'd2 || cnt_i2c_clk == 2'd3) && (state != STOP) && (state != IDLE))
            i2c_scl <= 1'b0;
        else
            i2c_scl <= 1'b1;
    end

    // =========================
    // L?y ACK t? slave (m?u SDA ? ??u pha 00)
    // =========================
    always @(*) begin
        case (state)
            ACK_1, ACK_2, ACK_3 : begin
                if (cnt_i2c_clk == 2'b00)
                    ack = sda_in;
                else
                    ack = ack;
            end
            default : ack = 1'b1; // m?c ??nh không ACK
        endcase
    end

endmodule
