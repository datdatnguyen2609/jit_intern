// ==============================================
// spi_adxl362_controller.v
// Controller SPI ADXL362, 100MHz -> 5MHz SCLK
// - Co latched start r_kick de khong mat xung i_ready
// - MOSI shift sau 1/4 chu ky SCLK (sau canh xuong)
// - MISO lay mau tai canh len SCLK (CPHA=0, CPOL=0)
// ==============================================
module spi_adxl362_controller(
    input        i_clk,
    input        i_rst,

    output reg   o_csn,
    output reg   o_sclk,
    output reg   o_mosi,
    input        i_miso,

    input        i_ready,     // co the la pulse hoac level, se duoc latch lai
    input  [7:0] i_inst,      // 0x0A WRITE, 0x0B READ
    input        i_sel_rw,    // 0=WRITE, 1=READ
    input  [7:0] i_reg_addr,  // dia chi thanh ghi
    input  [7:0] i_dout,      // du lieu ghi
    output reg [7:0] o_din,   // du lieu doc
    output reg       o_din_valid
);
    // =========================================
    // Tham so SCLK: 100MHz -> 5MHz
    // Toggle moi 10 xung i_clk -> T/2 = 10 -> T = 20 xung
    // MOSI_DELAY = 5 (1/4 chu ky SCLK)
    // =========================================
    localparam [7:0] SCLK_TOGGLE = 8'd10;
    localparam [7:0] MOSI_DELAY  = 8'd5;

    // =========================================
    // SCLK generator, bat tat bang r_sclk_en
    // =========================================
    reg       r_sclk_en;
    reg [7:0] r_sclk_count;
    reg       r_sclk_d;

    always @(posedge i_clk) begin
        if (i_rst || ~r_sclk_en) begin
            o_sclk       <= 1'b0;
            r_sclk_count <= 8'd0;
        end else if (r_sclk_count < (SCLK_TOGGLE - 1)) begin
            r_sclk_count <= r_sclk_count + 8'd1;
        end else begin
            o_sclk       <= ~o_sclk;
            r_sclk_count <= 8'd0;
        end
    end

    // Edge detect SCLK
    always @(posedge i_clk) begin
        if (i_rst) r_sclk_d <= 1'b0;
        else       r_sclk_d <= o_sclk;
    end
    wire w_sclk_posedge = (~r_sclk_d) &  o_sclk;
    wire w_sclk_negedge =  (r_sclk_d) & ~o_sclk;

    // =========================================
    // MOSI strobe: tre 1/4 chu ky sau canh xuong SCLK
    // =========================================
    reg       r_mosi_wait;
    reg [7:0] r_mosi_delay_cnt;
    reg       r_mosi_strobe;

    always @(posedge i_clk) begin
        if (i_rst || ~r_sclk_en) begin
            r_mosi_wait      <= 1'b0;
            r_mosi_delay_cnt <= 8'd0;
            r_mosi_strobe    <= 1'b0;
        end else begin
            r_mosi_strobe <= 1'b0; // mac dinh
            if (w_sclk_negedge) begin
                r_mosi_wait      <= 1'b1;
                r_mosi_delay_cnt <= 8'd0;
            end else if (r_mosi_wait) begin
                if (r_mosi_delay_cnt == (MOSI_DELAY - 1)) begin
                    r_mosi_wait   <= 1'b0;
                    r_mosi_strobe <= 1'b1;
                end else begin
                    r_mosi_delay_cnt <= r_mosi_delay_cnt + 8'd1;
                end
            end
        end
    end
    wire w_mosi_strobe = r_mosi_strobe;

    // =========================================
    // Edge detect i_ready + latched start r_kick
    // =========================================
    reg r_ready_d, r_kick;
    always @(posedge i_clk) begin
        if (i_rst) r_ready_d <= 1'b0;
        else       r_ready_d <= i_ready;
    end
    wire w_ready_posedge = (~r_ready_d) & i_ready;

    // r_kick duoc bat khi thay posedge i_ready, giu den khi bat dau giao dich
    always @(posedge i_clk) begin
        if (i_rst) r_kick <= 1'b0;
        else begin
            if (w_ready_posedge) r_kick <= 1'b1;
            // xoa khi da keo CSN xuong va bat SCLK (bat dau giao dich thuc su)
            if ((o_csn==1'b0) && r_sclk_en) r_kick <= 1'b0;
        end
    end

    // =========================================
    // FSM
    // =========================================
    localparam IDLE       = 3'd0;
    localparam INST_OUT   = 3'd1;
    localparam ADDR_OUT   = 3'd2;
    localparam WRITE_DATA = 3'd3;
    localparam READ_DATA  = 3'd4;
    localparam ENDING     = 3'd5;

    reg [2:0] r_state, r_next_state;
    reg [7:0] r_mosi_buf;
    reg [6:0] r_miso_buf;
    reg [2:0] r_bitcount;

    // state reg
    always @(posedge i_clk) begin
        if (i_rst) r_state <= IDLE;
        else       r_state <= r_next_state;
    end

    // FSM next + outputs
    always @(posedge i_clk) begin
        if (i_rst) begin
            // reset mac dinh
            o_csn       <= 1'b1;
            r_sclk_en   <= 1'b0;
            o_mosi      <= 1'b0;
            o_din       <= 8'd0;
            o_din_valid <= 1'b0;
            r_bitcount  <= 3'd0;
            r_mosi_buf  <= 8'd0;
            r_miso_buf  <= 7'd0;
            r_next_state<= IDLE;
        end else begin
            // mac dinh
            o_din_valid <= 1'b0;

            case (r_state)
                // ---------------------------------
                // Cho r_kick -> bat dau giao dich ngay trong IDLE
                // ---------------------------------
                IDLE: begin
                    o_csn     <= 1'b1;
                    r_sclk_en <= 1'b0;
                    o_mosi    <= 1'b0;
                    r_bitcount<= 3'd0;

                    if (r_kick) begin
                        // bat dau giao dich: CSN=0, bat SCLK, nap INST
                        o_csn      <= 1'b0;
                        r_sclk_en  <= 1'b1;
                        r_mosi_buf <= {i_inst[6:0], 1'b0};
                        o_mosi     <= i_inst[7];     // xuat bit MSB truoc
                        r_next_state <= INST_OUT;
                    end else begin
                        r_next_state <= IDLE;
                    end
                end

                // ---------------------------------
                // Shift 8 bit INST -> nap sang ADDR
                // ---------------------------------
                INST_OUT: begin
                    if (w_mosi_strobe && (r_bitcount < 3'd7)) begin
                        {o_mosi, r_mosi_buf} <= {r_mosi_buf, 1'b0};
                        r_bitcount <= r_bitcount + 3'd1;
                    end else if (w_mosi_strobe) begin
                        // hoan thanh 8 bit INST, nap ADDR
                        {o_mosi, r_mosi_buf} <= {i_reg_addr, 1'b0};
                        r_bitcount <= 3'd0;
                        r_next_state <= ADDR_OUT;
                    end
                end

                // ---------------------------------
                // Shift 8 bit ADDR -> chuyen sang WRITE/READ
                // ---------------------------------
                ADDR_OUT: begin
                    if (w_mosi_strobe && (r_bitcount < 3'd7)) begin
                        {o_mosi, r_mosi_buf} <= {r_mosi_buf, 1'b0};
                        r_bitcount <= r_bitcount + 3'd1;
                    end else if (w_mosi_strobe) begin
                        r_bitcount <= 3'd0;
                        if (i_sel_rw) begin
                            // READ: chuyen sang doc MISO
                            r_next_state <= READ_DATA;
                        end else begin
                            // WRITE: nap data ghi
                            {o_mosi, r_mosi_buf} <= {i_dout, 1'b0};
                            r_next_state <= WRITE_DATA;
                        end
                    end
                end

                // ---------------------------------
                // Ghi 8 bit du lieu qua MOSI
                // ---------------------------------
                WRITE_DATA: begin
                    if (w_mosi_strobe && (r_bitcount < 3'd7)) begin
                        {o_mosi, r_mosi_buf} <= {r_mosi_buf, 1'b0};
                        r_bitcount <= r_bitcount + 3'd1;
                    end else if (w_mosi_strobe) begin
                        {o_mosi, r_mosi_buf} <= 9'b0;
                        r_bitcount   <= 3'd0;
                        r_next_state <= ENDING;
                    end
                end

                // ---------------------------------
                // Doc 8 bit MISO tai canh len SCLK
                // ---------------------------------
                READ_DATA: begin
                    if (w_sclk_posedge && (r_bitcount < 3'd7)) begin
                        r_miso_buf <= {r_miso_buf[5:0], i_miso};
                        r_bitcount <= r_bitcount + 3'd1;
                    end else if (w_sclk_posedge) begin
                        r_bitcount  <= 3'd0;
                        o_din       <= {r_miso_buf, i_miso};
                        o_din_valid <= 1'b1;        // xung 1 chu ky
                        r_next_state<= ENDING;
                    end
                end

                // ---------------------------------
                // Ket thuc: keo CSN len 1 o canh xuong SCLK
                // ---------------------------------
                ENDING: begin
                    if (w_sclk_negedge) begin
                        o_csn     <= 1'b1;
                        r_sclk_en <= 1'b0;
                        r_next_state <= IDLE;
                    end
                end

                default: r_next_state <= IDLE;
            endcase
        end
    end

endmodule
