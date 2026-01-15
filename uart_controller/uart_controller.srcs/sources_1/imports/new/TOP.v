`timescale 1ns / 1ps

module integrated_system (
    // Clock & Reset
    input         clk,              // 100 MHz
    input         rst_n,            // Active LOW reset (CPU_RESETN - C12)
    
    // Mode buttons (Active HIGH)
    input         btn0,             // BTNU - Mode 0: Accelerometer
    input         btn1,             // BTNL - Mode 1: Temperature  
    input         btn2,             // BTNR - Mode 2: Switch → LED/PC
    input         btn3,             // BTND - Mode 3: PC → LED/7Seg
    input         btn4,             // BTNC - Mode 4: Combined All
    
    // Switch inputs
    input  [15:0] sw,               // 16 switches
    
    // SPI - ADXL362 Accelerometer
    output        spi_csn,
    output        spi_sclk,
    output        spi_mosi,
    input         spi_miso,
    
    // I2C - ADT7420 Temperature
    inout         i2c_sda,
    output        i2c_scl,
    
    // UART - PC Communication
    input         uart_rx,
    output        uart_tx,
    
    // Output displays
    output [15:0] led,              // 16 LEDs
    output [6:0]  seg,              // 7-segment cathodes
    output        dp,               // Decimal point
    output [7:0]  an,               // 7-segment anodes
    output        heartbeat         // Status LED (RGB Green)
);

    // ========================================
    // Đảo tín hiệu Reset (Active LOW → Active HIGH)
    // ========================================
    wire rst = ~rst_n;

    // ========================================
    // Parameters
    // ========================================
    localparam CLK_FREQ     = 100_000_000;
    localparam UART_BAUD    = 115200;
    localparam CLKS_PER_BIT = CLK_FREQ / UART_BAUD;  // 868

    // ========================================
    // Internal Signals
    // ========================================
    wire w_rst;
    wire w_btn0, w_btn1, w_btn2, w_btn3, w_btn4;
    wire [15:0] w_sw;
    wire w_btn0_pulse, w_btn1_pulse, w_btn2_pulse, w_btn3_pulse, w_btn4_pulse;
    
    reg [2:0] r_mode;
    reg [15:0] r_accel_x, r_accel_y, r_accel_z;
    wire [7:0] w_temp_data;
    wire w_uart_rx_valid;
    wire [7:0] w_uart_rx_data;
    reg [15:0] r_pc_led_data;

    // ========================================
    // 1. Debounce All Inputs
    // ========================================
    debounce #(.CLK_FREQ(CLK_FREQ), .STABLE_MS(20)) 
    u_deb_rst (. clk(clk), .rst(1'b0), .in(rst), .out(w_rst));
    
    debounce #(.CLK_FREQ(CLK_FREQ), .STABLE_MS(20)) 
    u_deb_btn0 (.clk(clk), .rst(w_rst), .in(btn0), .out(w_btn0));
    
    debounce #(.CLK_FREQ(CLK_FREQ), .STABLE_MS(20)) 
    u_deb_btn1 (.clk(clk), .rst(w_rst), .in(btn1), .out(w_btn1));
    
    debounce #(.CLK_FREQ(CLK_FREQ), .STABLE_MS(20)) 
    u_deb_btn2 (.clk(clk), .rst(w_rst), .in(btn2), .out(w_btn2));
    
    debounce #(. CLK_FREQ(CLK_FREQ), .STABLE_MS(20)) 
    u_deb_btn3 (.clk(clk), .rst(w_rst), .in(btn3), .out(w_btn3));
    
    debounce #(.CLK_FREQ(CLK_FREQ), .STABLE_MS(20)) 
    u_deb_btn4 (. clk(clk), .rst(w_rst), .in(btn4), .out(w_btn4));
    
    // Switch debounce
    genvar i;
    generate
        for (i = 0; i < 16; i = i + 1) begin : GEN_SW_DEB
            debounce #(.CLK_FREQ(CLK_FREQ), .STABLE_MS(50)) 
            u_deb_sw (. clk(clk), .rst(w_rst), .in(sw[i]), .out(w_sw[i]));
        end
    endgenerate

    // ========================================
    // 2. Edge Detection for Buttons
    // ========================================
    edge_detect u_edge0 (. clk(clk), .rst(w_rst), .in(w_btn0), .rise(w_btn0_pulse));
    edge_detect u_edge1 (.clk(clk), .rst(w_rst), .in(w_btn1), .rise(w_btn1_pulse));
    edge_detect u_edge2 (.clk(clk), .rst(w_rst), .in(w_btn2), .rise(w_btn2_pulse));
    edge_detect u_edge3 (. clk(clk), .rst(w_rst), .in(w_btn3), .rise(w_btn3_pulse));
    edge_detect u_edge4 (.clk(clk), .rst(w_rst), .in(w_btn4), .rise(w_btn4_pulse));

    // ========================================
    // 3. Mode Selection
    // ========================================
    always @(posedge clk) begin
        if (w_rst) begin
            r_mode <= 3'd0;
        end else begin
            if (w_btn0_pulse)      r_mode <= 3'd0;
            else if (w_btn1_pulse) r_mode <= 3'd1;
            else if (w_btn2_pulse) r_mode <= 3'd2;
            else if (w_btn3_pulse) r_mode <= 3'd3;
            else if (w_btn4_pulse) r_mode <= 3'd4;
        end
    end

    // ========================================
    // 4. Heartbeat LED (~1.3s period)
    // ========================================
    reg [26:0] r_hb_cnt;
    always @(posedge clk) begin
        if (w_rst) r_hb_cnt <= 0;
        else       r_hb_cnt <= r_hb_cnt + 1;
    end
    assign heartbeat = r_hb_cnt[26];

    // ========================================
    // 5. SPI Controller - ADXL362
    // ========================================
    wire w_spi_csn;
    wire [7:0] w_spi_rx_data;
    wire w_spi_rx_valid;
    
    reg r_spi_start;
    reg [7:0] r_spi_cmd;
    reg [7:0] r_spi_addr;
    reg [7:0] r_spi_tx_data;
    reg r_spi_rw;

    spi_adxl362_controller u_spi (
        .i_clk      (clk),
        .i_rst      (w_rst),
        .o_csn      (w_spi_csn),
        .o_sclk     (spi_sclk),
        .o_mosi     (spi_mosi),
        .i_miso     (spi_miso),
        .i_ready    (r_spi_start),
        .i_inst     (r_spi_cmd),
        .i_sel_rw   (r_spi_rw),
        .i_reg_addr (r_spi_addr),
        .i_dout     (r_spi_tx_data),
        .o_din      (w_spi_rx_data),
        .o_din_valid(w_spi_rx_valid)
    );
    
    assign spi_csn = w_spi_csn;

    // CSN rising edge
    reg r_csn_prev;
    wire w_csn_rise = ~r_csn_prev & w_spi_csn;
    always @(posedge clk) begin
        if (w_rst) r_csn_prev <= 1'b1;
        else       r_csn_prev <= w_spi_csn;
    end

    // ========================================
    // 6. SPI FSM - Read Accelerometer
    // ========================================
    localparam SPI_INIT_POWER  = 4'd0;
    localparam SPI_WAIT_POWER  = 4'd1;
    localparam SPI_INIT_FILTER = 4'd2;
    localparam SPI_WAIT_FILTER = 4'd3;
    localparam SPI_IDLE        = 4'd4;
    localparam SPI_READ_XL     = 4'd5;
    localparam SPI_READ_XH     = 4'd6;
    localparam SPI_READ_YL     = 4'd7;
    localparam SPI_READ_YH     = 4'd8;
    localparam SPI_READ_ZL     = 4'd9;
    localparam SPI_READ_ZH     = 4'd10;
    localparam SPI_DONE        = 4'd11;

    reg [3:0] r_spi_state;
    reg [26:0] r_spi_timer;
    reg [15:0] r_temp_axis;

    always @(posedge clk) begin
        if (w_rst) begin
            r_spi_state   <= SPI_INIT_POWER;
            r_spi_start   <= 1'b0;
            r_spi_cmd     <= 8'h0A;
            r_spi_rw      <= 1'b0;
            r_spi_addr    <= 8'h00;
            r_spi_tx_data <= 8'h00;
            r_spi_timer   <= 0;
            r_accel_x     <= 16'd0;
            r_accel_y     <= 16'd0;
            r_accel_z     <= 16'd0;
            r_temp_axis   <= 16'd0;
        end else begin
            r_spi_start <= 1'b0;

            case (r_spi_state)
                SPI_INIT_POWER: begin
                    r_spi_cmd     <= 8'h0A;
                    r_spi_rw      <= 1'b0;
                    r_spi_addr    <= 8'h2D;
                    r_spi_tx_data <= 8'h02;
                    r_spi_start   <= 1'b1;
                    r_spi_state   <= SPI_WAIT_POWER;
                end

                SPI_WAIT_POWER:  begin
                    if (w_csn_rise) r_spi_state <= SPI_INIT_FILTER;
                end

                SPI_INIT_FILTER: begin
                    r_spi_cmd     <= 8'h0A;
                    r_spi_rw      <= 1'b0;
                    r_spi_addr    <= 8'h2C;
                    r_spi_tx_data <= 8'h13;
                    r_spi_start   <= 1'b1;
                    r_spi_state   <= SPI_WAIT_FILTER;
                end

                SPI_WAIT_FILTER: begin
                    if (w_csn_rise) begin
                        r_spi_state <= SPI_IDLE;
                        r_spi_timer <= 0;
                    end
                end

                SPI_IDLE: begin
                    r_spi_timer <= r_spi_timer + 1;
                    if (r_spi_timer == 27'd50_000_000) begin
                        r_spi_timer <= 0;
                        r_spi_state <= SPI_READ_XL;
                        r_spi_cmd   <= 8'h0B;
                        r_spi_rw    <= 1'b1;
                        r_spi_addr  <= 8'h0E;
                        r_spi_start <= 1'b1;
                    end
                end

                SPI_READ_XL: begin
                    if (w_spi_rx_valid) r_temp_axis[7:0] <= w_spi_rx_data;
                    if (w_csn_rise) begin
                        r_spi_addr  <= 8'h0F;
                        r_spi_start <= 1'b1;
                        r_spi_state <= SPI_READ_XH;
                    end
                end

                SPI_READ_XH: begin
                    if (w_spi_rx_valid) r_temp_axis[15:8] <= w_spi_rx_data;
                    if (w_csn_rise) begin
                        r_accel_x   <= r_temp_axis;
                        r_spi_addr  <= 8'h10;
                        r_spi_start <= 1'b1;
                        r_spi_state <= SPI_READ_YL;
                    end
                end

                SPI_READ_YL: begin
                    if (w_spi_rx_valid) r_temp_axis[7:0] <= w_spi_rx_data;
                    if (w_csn_rise) begin
                        r_spi_addr  <= 8'h11;
                        r_spi_start <= 1'b1;
                        r_spi_state <= SPI_READ_YH;
                    end
                end

                SPI_READ_YH: begin
                    if (w_spi_rx_valid) r_temp_axis[15:8] <= w_spi_rx_data;
                    if (w_csn_rise) begin
                        r_accel_y   <= r_temp_axis;
                        r_spi_addr  <= 8'h12;
                        r_spi_start <= 1'b1;
                        r_spi_state <= SPI_READ_ZL;
                    end
                end

                SPI_READ_ZL:  begin
                    if (w_spi_rx_valid) r_temp_axis[7:0] <= w_spi_rx_data;
                    if (w_csn_rise) begin
                        r_spi_addr  <= 8'h13;
                        r_spi_start <= 1'b1;
                        r_spi_state <= SPI_READ_ZH;
                    end
                end

                SPI_READ_ZH: begin
                    if (w_spi_rx_valid) r_temp_axis[15:8] <= w_spi_rx_data;
                    if (w_csn_rise) begin
                        r_accel_z   <= r_temp_axis;
                        r_spi_state <= SPI_DONE;
                    end
                end

                SPI_DONE: r_spi_state <= SPI_IDLE;

                default: r_spi_state <= SPI_INIT_POWER;
            endcase
        end
    end

    // ========================================
    // 7. I2C Controller - ADT7420
    // ========================================
    i2c_adt7420_controller #(
        . DEVICE_ADDR (7'b1001011),
        .SYS_CLK_FREQ(CLK_FREQ),
        .SCL_FREQ    (200_000)
    ) u_i2c (
        .sys_clk (clk),
        .sys_rst (w_rst),
        .i2c_sda (i2c_sda),
        .i2c_scl (i2c_scl),
        .rd_data (w_temp_data),
        .seg     (),
        .dp      (),
        .an      ()
    );

    // ========================================
    // 8. UART RX
    // ========================================
    uart_rx #(. CLKS_PER_BIT(CLKS_PER_BIT)) u_uart_rx (
        .clk     (clk),
        .rst     (w_rst),
        .rx      (uart_rx),
        .rx_valid(w_uart_rx_valid),
        .rx_data (w_uart_rx_data)
    );

    // ========================================
    // 9. PC LED Control (2-byte protocol)
    // ========================================
    reg r_pc_byte_sel;
    reg [7:0] r_pc_last_rx;

    always @(posedge clk) begin
        if (w_rst) begin
            r_pc_led_data <= 16'h0000;
            r_pc_byte_sel <= 1'b0;
            r_pc_last_rx  <= 8'h00;
        end else if (w_uart_rx_valid) begin
            r_pc_last_rx <= w_uart_rx_data;
            if (r_pc_byte_sel == 1'b0) begin
                r_pc_led_data[7:0] <= w_uart_rx_data;
                r_pc_byte_sel      <= 1'b1;
            end else begin
                r_pc_led_data[15:8] <= w_uart_rx_data;
                r_pc_byte_sel       <= 1'b0;
            end
        end
    end

    // ========================================
    // 10. UART TX
    // ========================================
    wire w_tx_busy;
    wire w_tx_done;
    reg r_tx_start;
    reg [7:0] r_tx_data;

    uart_tx #(. CLKS_PER_BIT(CLKS_PER_BIT)) u_uart_tx (
        .clk     (clk),
        .rst     (w_rst),
        .tx_start(r_tx_start),
        .tx_data (r_tx_data),
        .tx      (uart_tx),
        .tx_busy (w_tx_busy),
        .tx_done (w_tx_done)
    );

    // ========================================
    // 11. Pre-calculated Values (Fix Timing)
    // ========================================
    wire signed [11:0] w_x_signed = {r_accel_x[11:8], r_accel_x[7:0]};
    wire signed [11:0] w_y_signed = {r_accel_y[11:8], r_accel_y[7:0]};
    wire signed [11:0] w_z_signed = {r_accel_z[11:8], r_accel_z[7:0]};
    
    wire [11:0] w_x_abs = w_x_signed[11] ? (~w_x_signed + 1) : w_x_signed;
    wire [11:0] w_y_abs = w_y_signed[11] ? (~w_y_signed + 1) : w_y_signed;
    wire [11:0] w_z_abs = w_z_signed[11] ? (~w_z_signed + 1) : w_z_signed;

    // Registered BCD values
    reg [3:0] r_x_hundreds, r_x_tens, r_x_ones;
    reg [3:0] r_y_hundreds, r_y_tens, r_y_ones;
    reg [3:0] r_z_hundreds, r_z_tens, r_z_ones;
    reg r_x_neg, r_y_neg, r_z_neg;
    reg [3:0] r_temp_int_tens, r_temp_int_ones;
    reg [3:0] r_temp_frac_tens, r_temp_frac_ones;
    
    always @(posedge clk) begin
        if (w_rst) begin
            r_x_hundreds <= 0; r_x_tens <= 0; r_x_ones <= 0; r_x_neg <= 0;
            r_y_hundreds <= 0; r_y_tens <= 0; r_y_ones <= 0; r_y_neg <= 0;
            r_z_hundreds <= 0; r_z_tens <= 0; r_z_ones <= 0; r_z_neg <= 0;
            r_temp_int_tens <= 0; r_temp_int_ones <= 0;
            r_temp_frac_tens <= 0; r_temp_frac_ones <= 0;
        end else begin
            r_x_neg      <= w_x_signed[11];
            r_x_hundreds <= (w_x_abs / 100) % 10;
            r_x_tens     <= (w_x_abs / 10) % 10;
            r_x_ones     <= w_x_abs % 10;
            
            r_y_neg      <= w_y_signed[11];
            r_y_hundreds <= (w_y_abs / 100) % 10;
            r_y_tens     <= (w_y_abs / 10) % 10;
            r_y_ones     <= w_y_abs % 10;
            
            r_z_neg      <= w_z_signed[11];
            r_z_hundreds <= (w_z_abs / 100) % 10;
            r_z_tens     <= (w_z_abs / 10) % 10;
            r_z_ones     <= w_z_abs % 10;
            
            r_temp_int_tens  <= (w_temp_data / 4) / 10;
            r_temp_int_ones  <= (w_temp_data / 4) % 10;
            r_temp_frac_tens <= ((w_temp_data % 4) * 25) / 10;
            r_temp_frac_ones <= ((w_temp_data % 4) * 25) % 10;
        end
    end

    // ========================================
    // 12. TX Message Builder
    // ========================================
    reg [7:0] r_tx_buffer [0:63];
    reg [5:0] r_tx_len;
    reg [5:0] r_tx_idx;
    reg [2:0] r_tx_state;
    reg [26:0] r_tx_timer;
    reg r_sw_changed;
    reg [15:0] r_sw_prev;

    localparam TX_IDLE = 3'd0;
    localparam TX_LOAD = 3'd1;
    localparam TX_SEND = 3'd2;
    localparam TX_WAIT = 3'd3;
    localparam TX_NEXT = 3'd4;

    always @(posedge clk) begin
        if (w_rst) begin
            r_sw_prev    <= 16'h0000;
            r_sw_changed <= 1'b0;
        end else begin
            r_sw_prev    <= w_sw;
            r_sw_changed <= (w_sw != r_sw_prev);
        end
    end

    function [7:0] hex2ascii;
        input [3:0] hex;
        hex2ascii = (hex < 10) ? (8'd48 + hex) : (8'd55 + hex);
    endfunction

    function [7:0] dig2ascii;
        input [3:0] dig;
        dig2ascii = 8'd48 + dig;
    endfunction

    always @(posedge clk) begin
        if (w_rst) begin
            r_tx_state <= TX_IDLE;
            r_tx_start <= 1'b0;
            r_tx_idx   <= 0;
            r_tx_len   <= 0;
            r_tx_timer <= 0;
            r_tx_data  <= 0;
        end else begin
            r_tx_start <= 1'b0;

            case (r_tx_state)
                TX_IDLE: begin
                    r_tx_timer <= r_tx_timer + 1;
                    
                    if ((r_tx_timer == 27'd50_000_000) ||
                        (r_sw_changed && r_mode == 3'd2) ||
                        (w_uart_rx_valid && (r_mode == 3'd3 || r_mode == 3'd4))) begin
                        r_tx_timer <= 0;
                        r_tx_state <= TX_LOAD;
                    end
                end

                TX_LOAD: begin
                    r_tx_idx <= 0;
                    
                    case (r_mode)
                        3'd0: begin
                            r_tx_buffer[0]  <= "M";
                            r_tx_buffer[1]  <= "0";
                            r_tx_buffer[2]  <= ": ";
                            r_tx_buffer[3]  <= "X";
                            r_tx_buffer[4]  <= "=";
                            r_tx_buffer[5]  <= r_x_neg ? "-" : "+";
                            r_tx_buffer[6]  <= dig2ascii(r_x_hundreds);
                            r_tx_buffer[7]  <= dig2ascii(r_x_tens);
                            r_tx_buffer[8]  <= dig2ascii(r_x_ones);
                            r_tx_buffer[9]  <= " ";
                            r_tx_buffer[10] <= "Y";
                            r_tx_buffer[11] <= "=";
                            r_tx_buffer[12] <= r_y_neg ?  "-" : "+";
                            r_tx_buffer[13] <= dig2ascii(r_y_hundreds);
                            r_tx_buffer[14] <= dig2ascii(r_y_tens);
                            r_tx_buffer[15] <= dig2ascii(r_y_ones);
                            r_tx_buffer[16] <= " ";
                            r_tx_buffer[17] <= "Z";
                            r_tx_buffer[18] <= "=";
                            r_tx_buffer[19] <= r_z_neg ? "-" : "+";
                            r_tx_buffer[20] <= dig2ascii(r_z_hundreds);
                            r_tx_buffer[21] <= dig2ascii(r_z_tens);
                            r_tx_buffer[22] <= dig2ascii(r_z_ones);
                            r_tx_buffer[23] <= 8'h0D;
                            r_tx_buffer[24] <= 8'h0A;
                            r_tx_len <= 6'd25;
                        end

                        3'd1: begin
                            r_tx_buffer[0]  <= "M";
                            r_tx_buffer[1]  <= "1";
                            r_tx_buffer[2]  <= ":";
                            r_tx_buffer[3]  <= "T";
                            r_tx_buffer[4]  <= "=";
                            r_tx_buffer[5]  <= dig2ascii(r_temp_int_tens);
                            r_tx_buffer[6]  <= dig2ascii(r_temp_int_ones);
                            r_tx_buffer[7]  <= ". ";
                            r_tx_buffer[8]  <= dig2ascii(r_temp_frac_tens);
                            r_tx_buffer[9]  <= dig2ascii(r_temp_frac_ones);
                            r_tx_buffer[10] <= "C";
                            r_tx_buffer[11] <= 8'h0D;
                            r_tx_buffer[12] <= 8'h0A;
                            r_tx_len <= 6'd13;
                        end

                        3'd2: begin
                            r_tx_buffer[0]  <= "M";
                            r_tx_buffer[1]  <= "2";
                            r_tx_buffer[2]  <= ": ";
                            r_tx_buffer[3]  <= "S";
                            r_tx_buffer[4]  <= "W";
                            r_tx_buffer[5]  <= "=";
                            r_tx_buffer[6]  <= hex2ascii(w_sw[15:12]);
                            r_tx_buffer[7]  <= hex2ascii(w_sw[11:8]);
                            r_tx_buffer[8]  <= hex2ascii(w_sw[7:4]);
                            r_tx_buffer[9]  <= hex2ascii(w_sw[3:0]);
                            r_tx_buffer[10] <= 8'h0D;
                            r_tx_buffer[11] <= 8'h0A;
                            r_tx_len <= 6'd12;
                        end

                        3'd3: begin
                            r_tx_buffer[0]  <= "M";
                            r_tx_buffer[1]  <= "3";
                            r_tx_buffer[2]  <= ": ";
                            r_tx_buffer[3]  <= "R";
                            r_tx_buffer[4]  <= "X";
                            r_tx_buffer[5]  <= "=";
                            r_tx_buffer[6]  <= hex2ascii(r_pc_last_rx[7:4]);
                            r_tx_buffer[7]  <= hex2ascii(r_pc_last_rx[3:0]);
                            r_tx_buffer[8]  <= " ";
                            r_tx_buffer[9]  <= "L";
                            r_tx_buffer[10] <= "=";
                            r_tx_buffer[11] <= hex2ascii(r_pc_led_data[15:12]);
                            r_tx_buffer[12] <= hex2ascii(r_pc_led_data[11:8]);
                            r_tx_buffer[13] <= hex2ascii(r_pc_led_data[7:4]);
                            r_tx_buffer[14] <= hex2ascii(r_pc_led_data[3:0]);
                            r_tx_buffer[15] <= 8'h0D;
                            r_tx_buffer[16] <= 8'h0A;
                            r_tx_len <= 6'd17;
                        end

                        3'd4: begin
                            r_tx_buffer[0]  <= "M";
                            r_tx_buffer[1]  <= "4";
                            r_tx_buffer[2]  <= ":";
                            r_tx_buffer[3]  <= "X";
                            r_tx_buffer[4]  <= "=";
                            r_tx_buffer[5]  <= r_x_neg ?  "-" : "+";
                            r_tx_buffer[6]  <= dig2ascii(r_x_hundreds);
                            r_tx_buffer[7]  <= dig2ascii(r_x_tens);
                            r_tx_buffer[8]  <= dig2ascii(r_x_ones);
                            r_tx_buffer[9]  <= " ";
                            r_tx_buffer[10] <= "T";
                            r_tx_buffer[11] <= "=";
                            r_tx_buffer[12] <= dig2ascii(r_temp_int_tens);
                            r_tx_buffer[13] <= dig2ascii(r_temp_int_ones);
                            r_tx_buffer[14] <= "C";
                            r_tx_buffer[15] <= " ";
                            r_tx_buffer[16] <= "S";
                            r_tx_buffer[17] <= "=";
                            r_tx_buffer[18] <= hex2ascii(w_sw[15:12]);
                            r_tx_buffer[19] <= hex2ascii(w_sw[11:8]);
                            r_tx_buffer[20] <= hex2ascii(w_sw[7:4]);
                            r_tx_buffer[21] <= hex2ascii(w_sw[3:0]);
                            r_tx_buffer[22] <= 8'h0D;
                            r_tx_buffer[23] <= 8'h0A;
                            r_tx_len <= 6'd24;
                        end

                        default: r_tx_len <= 0;
                    endcase
                    
                    r_tx_state <= TX_SEND;
                end

                TX_SEND:  begin
                    if (! w_tx_busy && r_tx_len > 0) begin
                        r_tx_data  <= r_tx_buffer[r_tx_idx];
                        r_tx_start <= 1'b1;
                        r_tx_state <= TX_WAIT;
                    end else if (r_tx_len == 0) begin
                        r_tx_state <= TX_IDLE;
                    end
                end

                TX_WAIT:  begin
                    if (w_tx_done) r_tx_state <= TX_NEXT;
                end

                TX_NEXT: begin
                    if (r_tx_idx < r_tx_len - 1) begin
                        r_tx_idx   <= r_tx_idx + 1;
                        r_tx_state <= TX_SEND;
                    end else begin
                        r_tx_state <= TX_IDLE;
                    end
                end

                default: r_tx_state <= TX_IDLE;
            endcase
        end
    end

    // ========================================
    // 13. LED Output Multiplexer
    // ========================================
    reg [15:0] r_led_output;
    reg [27:0] r_rotate_cnt;
    
    always @(posedge clk) begin
        if (w_rst) begin
            r_led_output <= 16'h0000;
            r_rotate_cnt <= 0;
        end else begin
            r_rotate_cnt <= r_rotate_cnt + 1;
            
            case (r_mode)
                3'd0: r_led_output <= r_accel_x;
                3'd1: r_led_output <= {8'h00, w_temp_data};
                3'd2: r_led_output <= w_sw;
                3'd3: r_led_output <= r_pc_led_data;
                3'd4: begin
                    case (r_rotate_cnt[27:25])
                        3'd0: r_led_output <= r_accel_x;
                        3'd1: r_led_output <= r_accel_y;
                        3'd2: r_led_output <= r_accel_z;
                        3'd3: r_led_output <= {8'h00, w_temp_data};
                        3'd4: r_led_output <= w_sw;
                        3'd5: r_led_output <= r_pc_led_data;
                        default: r_led_output <= 16'hFFFF;
                    endcase
                end
                default: r_led_output <= 16'h0000;
            endcase
        end
    end
    
    assign led = r_led_output;

    // ========================================
    // 14. 7-Segment Display Controller
    // ========================================
    seg7_controller u_seg7 (
        .clk       (clk),
        .rst       (w_rst),
        .mode      (r_mode),
        .accel_x   (r_accel_x),
        .accel_y   (r_accel_y),
        .accel_z   (r_accel_z),
        .temp_data (w_temp_data),
        .sw_data   (w_sw),
        .pc_data   (r_pc_led_data),
        .seg       (seg),
        .dp        (dp),
        .an        (an)
    );

endmodule