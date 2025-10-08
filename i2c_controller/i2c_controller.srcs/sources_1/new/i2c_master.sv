module i2c_master
#(
    parameter   DEVICE_ADDR   = 7'b1001_011  ,
    parameter   SYS_CLK_FREQ  = 'd100_000_000,
    parameter   SCL_FREQ      = 'd200_000
)
(
    input   wire            i_sys_clk ,
    input   wire            i_rst     ,  // reset dong bo, active-HIGH

    inout   wire            io_i2c_sda,

    output  reg             o_i2c_scl,
    output  reg     [26:0]  o_rd_data
);

    // ==========================
    // Tham so noi bo
    // ==========================
    parameter   CNT_CLK_MAX   = (SYS_CLK_FREQ / SCL_FREQ) >> 3;
    parameter   CNT_DELAY_MAX = 20'd125_000;

    localparam  S_IDLE         = 4'd0,
                S_START        = 4'd1,
                S_SEND_D_ADDR  = 4'd2,
                S_ACK_1        = 4'd3,
                S_SEND_R_ADDR  = 4'd4,
                S_ACK_2        = 4'd5,
                S_RE_START     = 4'd6,
                S_RSEND_D_ADDR = 4'd7,
                S_ACK_3        = 4'd8,
                S_RD_DATA_MSB  = 4'd9,
                S_MASTER_ACK   = 4'd10,
                S_RD_DATA_LSB  = 4'd11,
                S_NO_ACK       = 4'd12,
                S_STOP         = 4'd13;

    // ==========================
    // Thanh ghi / wire
    // ==========================
    reg     [19:0]  r_cnt_delay;
    reg             r_i2c_scl;
    reg     [7:0]   r_cnt_clk;
    reg             r_i2c_clk;
    reg     [3:0]   r_state;
    reg     [1:0]   r_cnt_i2c_clk;
    reg             r_cnt_i2c_clk_en;
    reg     [3:0]   r_cnt_bit;
    wire            w_sda_in;
    reg             r_sda_out;
    wire            w_sda_en;
    reg     [15:0]  r_rd_data_reg;
    reg             r_ack;

    // ==========================
    // T tao i2c_clk tu sys_clk
    // ==========================
    always @(posedge i_sys_clk) begin
        if (i_rst) begin
            r_cnt_clk <= 8'd0;
        end else if (r_cnt_clk == CNT_CLK_MAX - 1) begin
            r_cnt_clk <= 8'd0;
        end else begin
            r_cnt_clk <= r_cnt_clk + 1'b1;
        end
    end

    always @(posedge i_sys_clk) begin
        if (i_rst) begin
            r_i2c_clk <= 1'b1;
        end else if (r_cnt_clk == CNT_CLK_MAX - 1) begin
            r_i2c_clk <= ~r_i2c_clk;
        end
    end

    // ==========================
    // Delay 500ms (cho chuyen doi nhiet do)
    // ==========================
    always @(posedge r_i2c_clk) begin
        if (i_rst) begin
            r_cnt_delay <= 20'd0;
        end else if (r_cnt_delay == CNT_DELAY_MAX - 1) begin
            r_cnt_delay <= 20'd0;
        end else if (r_cnt_i2c_clk == 2'd3 && r_state == S_IDLE) begin
            r_cnt_delay <= r_cnt_delay + 1'b1;
        end
    end

    // ==========================
    // FSM trang thai
    // ==========================
    always @(posedge r_i2c_clk) begin
        if (i_rst) begin
            r_state <= S_IDLE;
        end else begin
            case (r_state)
                S_IDLE :
                    r_state <= (r_cnt_delay == CNT_DELAY_MAX - 1) ? S_START : S_IDLE;

                S_START :
                    r_state <= (r_cnt_i2c_clk == 2'd3) ? S_SEND_D_ADDR : S_START;

                S_SEND_D_ADDR :
                    r_state <= (r_cnt_i2c_clk == 2'd3 && r_cnt_bit == 3'd7) ? S_ACK_1 : S_SEND_D_ADDR;

                S_ACK_1 :
                    r_state <= (r_cnt_i2c_clk == 2'd3 && r_ack == 1'b0) ? S_SEND_R_ADDR : S_ACK_1;

                S_SEND_R_ADDR :
                    r_state <= (r_cnt_i2c_clk == 2'd3 && r_cnt_bit == 3'd7) ? S_ACK_2 : S_SEND_R_ADDR;

                S_ACK_2 :
                    r_state <= (r_cnt_i2c_clk == 2'd3 && r_ack == 1'b0) ? S_RE_START : S_ACK_2;

                S_RE_START :
                    r_state <= (r_cnt_i2c_clk == 2'd3) ? S_RSEND_D_ADDR : S_RE_START;

                S_RSEND_D_ADDR :
                    r_state <= (r_cnt_i2c_clk == 2'd3 && r_cnt_bit == 3'd7) ? S_ACK_3 : S_RSEND_D_ADDR;

                S_ACK_3 :
                    r_state <= (r_cnt_i2c_clk == 2'd3 && r_ack == 1'b0) ? S_RD_DATA_MSB : S_ACK_3;

                S_RD_DATA_MSB :
                    r_state <= (r_cnt_i2c_clk == 2'd3 && r_cnt_bit == 3'd7) ? S_MASTER_ACK : S_RD_DATA_MSB;

                S_MASTER_ACK :
                    r_state <= (r_cnt_i2c_clk == 2'd3) ? S_RD_DATA_LSB : S_MASTER_ACK;

                S_RD_DATA_LSB :
                    r_state <= (r_cnt_i2c_clk == 2'd3 && r_cnt_bit == 3'd7) ? S_NO_ACK : S_RD_DATA_LSB;

                S_NO_ACK :
                    r_state <= (r_cnt_i2c_clk == 2'd3) ? S_STOP : S_NO_ACK;

                S_STOP :
                    if (r_cnt_i2c_clk == 2'd3 && r_cnt_bit == 3'd3) begin
                        r_state <= S_IDLE;
                    end else begin
                        r_state <= S_STOP;
                    end

                default: r_state <= S_IDLE;
            endcase
        end
    end

    // ==========================
    // Dem pha i2c (0..3)
    // ==========================
    always @(posedge r_i2c_clk) begin
        if (i_rst) begin
            r_cnt_i2c_clk <= 2'd0;
        end else if (r_state == S_STOP && r_cnt_i2c_clk == 2'd3 && r_cnt_bit == 3'd3) begin
            r_cnt_i2c_clk <= 2'd0;
        end else begin
            r_cnt_i2c_clk <= r_cnt_i2c_clk + 1'b1;
        end
    end

    // Enable (khong dung trong logic hien tai nhung van giu nguyen)
    always @(posedge r_i2c_clk) begin
        if (i_rst) begin
            r_cnt_i2c_clk_en <= 1'b0;
        end else if (r_state == S_STOP && r_cnt_i2c_clk == 2'd3 && r_cnt_bit == 3'd3) begin
            r_cnt_i2c_clk_en <= 1'b0;
        end else if (r_state == S_IDLE && r_cnt_i2c_clk == 2'd3) begin
            r_cnt_i2c_clk_en <= 1'b1;
        end
    end

    // ==========================
    // Dem bit (0..7)
    // ==========================
    always @(posedge r_i2c_clk) begin
        if (i_rst) begin
            r_cnt_bit <= 3'd0;
        end else if (r_state == S_IDLE || r_state == S_START || r_state == S_ACK_1 || r_state == S_ACK_2 ||
                     r_state == S_RE_START || r_state == S_ACK_3 || r_state == S_MASTER_ACK ||
                     r_state == S_NO_ACK) begin
            r_cnt_bit <= 3'd0;
        end else if ((r_cnt_bit == 3'd7) && (r_cnt_i2c_clk == 2'd3)) begin
            r_cnt_bit <= 3'd0;
        end else if ((r_cnt_i2c_clk == 2'd3) && (r_state != S_IDLE)) begin
            r_cnt_bit <= r_cnt_bit + 1'b1;
        end
    end

    // ==========================
    // I2C SDA (open-drain)
    // ==========================
    assign  io_i2c_sda = (w_sda_en == 1'b1) ? r_sda_out : 1'bz; // drive 0/1 hoac nha Z
    assign  w_sda_in   = io_i2c_sda;

    always @(*) begin
        case (r_state)
            S_IDLE : begin
                r_sda_out = 1'b1;
            end
            S_START : begin
                r_sda_out = (r_cnt_i2c_clk == 2'd0) ? 1'b1 : 1'b0;
            end
            S_SEND_D_ADDR : begin
                r_sda_out = (r_cnt_bit == 3'd7) ? 1'b0 : DEVICE_ADDR[6 - r_cnt_bit];
            end
            S_ACK_1 : begin
                r_sda_out = 1'b0;
            end
            S_SEND_R_ADDR : begin
                r_sda_out = 1'b0;
            end
            S_ACK_2 : begin
                r_sda_out = 1'b1;
            end
            S_RE_START : begin
                r_sda_out = (r_cnt_i2c_clk <= 2'd1) ? 1'b1 : 1'b0;
            end
            S_RSEND_D_ADDR : begin
                r_sda_out = (r_cnt_bit == 3'd7) ? 1'b1 : DEVICE_ADDR[6 - r_cnt_bit];
            end
            S_ACK_3 : begin
                r_sda_out = 1'b1;
            end
            S_RD_DATA_MSB : begin
                r_sda_out = 1'b1;
            end
            S_MASTER_ACK : begin
                r_sda_out = 1'b0;
            end
            S_RD_DATA_LSB : begin
                r_sda_out = 1'b1;
            end
            S_NO_ACK : begin
                r_sda_out = 1'b1;
            end
            S_STOP : begin
                if (r_cnt_bit == 3'd0 && r_cnt_i2c_clk < 2'd3)
                    r_sda_out = 1'b0;
                else
                    r_sda_out = 1'b1;
            end
            default : begin
                r_sda_out = 1'b1;
            end
        endcase
    end

    assign  w_sda_en = (r_state == S_ACK_1 || r_state == S_ACK_2 || r_state == S_ACK_3 ||
                        r_state == S_RD_DATA_MSB || r_state == S_RD_DATA_LSB) ? 1'b0 : 1'b1;

    // ==========================
    // Doc du lieu 16 bit tu slave
    // ==========================
    always @(posedge r_i2c_clk) begin
        if (i_rst) begin
            r_rd_data_reg <= 16'd0;
        end else begin
            case (r_state)
                S_RD_DATA_MSB : begin
                    if (r_cnt_i2c_clk == 2'b01)
                        r_rd_data_reg[15 - r_cnt_bit] <= w_sda_in;
                end
                S_RD_DATA_LSB : begin
                    if (r_cnt_i2c_clk == 2'b01)
                        r_rd_data_reg[7 - r_cnt_bit] <= w_sda_in;
                end
                default: ;
            endcase
        end
    end

    // ==========================
    // Tinh o_rd_data (27 bit) tu r_rd_data_reg
    // ==========================
    always @(posedge r_i2c_clk) begin
        if (i_rst) begin
            o_rd_data <= 27'd0;
        end else if (r_state == S_RD_DATA_LSB && r_cnt_bit == 3'd7 && r_cnt_i2c_clk == 2'd3) begin
            o_rd_data <= r_rd_data_reg[14:3] * 625;
        end
    end

    // ==========================
    // I2C SCL (open-drain level high by pull-up, o day ta tao xung)
    // ==========================
    always @(posedge r_i2c_clk) begin
        if (i_rst) begin
            r_i2c_scl <= 1'b1;
        end else if ( (r_cnt_i2c_clk == 2'd2 || r_cnt_i2c_clk == 2'd3) &&
                      (r_state != S_STOP) && (r_state != S_IDLE) ) begin
            r_i2c_scl <= 1'b0;
        end else begin
            r_i2c_scl <= 1'b1;
        end
    end

    always @(posedge r_i2c_clk) begin
        if (i_rst) begin
            o_i2c_scl <= 1'b1;
        end else begin
            o_i2c_scl <= r_i2c_scl;
        end
    end

    // ==========================
    // ACK tu slave
    // ==========================
    always @(*) begin
        case (r_state)
            S_ACK_1, S_ACK_2, S_ACK_3 : begin
                if (r_cnt_i2c_clk == 2'b00)
                    r_ack = w_sda_in;
                else
                    r_ack = r_ack;
            end
            default: r_ack = 1'b1;
        endcase
    end

endmodule
