// ==============================================
// spi_adxl362_controller.v (fixed)
// - CPOL=0, CPHA=0
// - MOSI doi o canh xuong + tre 1/4 T_sclk (MOSI_DELAY)
// - MISO lay mau o canh len
// - READ: phat dummy 0x00 moi bit trong READ_DATA
// - Ket thuc: keo CSN len o canh xuong, sau do tat SCLK
// ==============================================
module spi_adxl362_controller(
    input        i_clk,
    input        i_rst,

    output reg   o_csn,
    output reg   o_sclk,
    output reg   o_mosi,
    input        i_miso,

    input        i_ready,     // co the pulse/level, se duoc latch lai
    input  [7:0] i_inst,      // 0x0A WRITE, 0x0B READ
    input        i_sel_rw,    // 0=WRITE, 1=READ
    input  [7:0] i_reg_addr,  // dia chi thanh ghi
    input  [7:0] i_dout,      // du lieu ghi
    output reg [7:0] o_din,   // du lieu doc
    output reg       o_din_valid
);
    // 100MHz -> 5MHz: T/2 = 10 xung i_clk, T = 20
    localparam [7:0] SCLK_TOGGLE = 8'd10;
    localparam [7:0] MOSI_DELAY  = 8'd5;  // ~1/4 chu ky SCLK

    // SCLK generator
    reg       r_sclk_en;
    reg [7:0] r_sclk_count;
    reg       r_sclk_d;

    always @(posedge i_clk) begin
        if (i_rst || ~r_sclk_en) begin
            o_sclk       <= 1'b0;       // CPOL=0
            r_sclk_count <= 8'd0;
        end else if (r_sclk_count < (SCLK_TOGGLE - 1)) begin
            r_sclk_count <= r_sclk_count + 8'd1;
        end else begin
            o_sclk       <= ~o_sclk;
            r_sclk_count <= 8'd0;
        end
    end

    // Detect canh SCLK
    always @(posedge i_clk) begin
        if (i_rst) r_sclk_d <= 1'b0;
        else       r_sclk_d <= o_sclk;
    end
    wire w_sclk_posedge = (~r_sclk_d) &  o_sclk; // lay mau MISO
    wire w_sclk_negedge =  (r_sclk_d) & ~o_sclk; // doi MOSI

    // MOSI strobe: tre 1/4 chu ky sau canh xuong
    reg       r_mosi_wait;
    reg [7:0] r_mosi_delay_cnt;
    reg       r_mosi_strobe;

    always @(posedge i_clk) begin
        if (i_rst || ~r_sclk_en) begin
            r_mosi_wait      <= 1'b0;
            r_mosi_delay_cnt <= 8'd0;
            r_mosi_strobe    <= 1'b0;
        end else begin
            r_mosi_strobe <= 1'b0;
            if (w_sclk_negedge) begin
                r_mosi_wait      <= 1'b1;
                r_mosi_delay_cnt <= 8'd0;
            end else if (r_mosi_wait) begin
                if (r_mosi_delay_cnt == (MOSI_DELAY - 1)) begin
                    r_mosi_wait   <= 1'b0;
                    r_mosi_strobe <= 1'b1;   // thoi diem dat bit MOSI
                end else begin
                    r_mosi_delay_cnt <= r_mosi_delay_cnt + 8'd1;
                end
            end
        end
    end
    wire w_mosi_strobe = r_mosi_strobe;

    // Latch start (chong mat xung READY)
    reg r_ready_d, r_kick;
    always @(posedge i_clk) begin
        if (i_rst) r_ready_d <= 1'b0;
        else       r_ready_d <= i_ready;
    end
    wire w_ready_posedge = (~r_ready_d) & i_ready;

    always @(posedge i_clk) begin
        if (i_rst) r_kick <= 1'b0;
        else begin
            if (w_ready_posedge) r_kick <= 1'b1;
            // xoa khi bat dau giao dich (CSN=0 va SCLK bat)
            if ((o_csn==1'b0) && r_sclk_en) r_kick <= 1'b0;
        end
    end

    // FSM
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

    // next-state + outputs
    always @(posedge i_clk) begin
        if (i_rst) begin
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
            o_din_valid <= 1'b0; // mac dinh

            case (r_state)
                IDLE: begin
                    o_csn     <= 1'b1;
                    r_sclk_en <= 1'b0;
                    o_mosi    <= 1'b0;
                    r_bitcount<= 3'd0;
                    if (r_kick) begin
                        // CSN xuong truoc, SCLK bat -> co thoi gian setup
                        o_csn      <= 1'b0;
                        r_sclk_en  <= 1'b1;
                        r_mosi_buf <= {i_inst[6:0], 1'b0};
                        o_mosi     <= i_inst[7];   // MSB truoc
                        r_next_state <= INST_OUT;
                    end else begin
                        r_next_state <= IDLE;
                    end
                end

                // xuat 8 bit INST
                INST_OUT: begin
                    if (w_mosi_strobe && (r_bitcount < 3'd7)) begin
                        {o_mosi, r_mosi_buf} <= {r_mosi_buf, 1'b0};
                        r_bitcount <= r_bitcount + 3'd1;
                    end else if (w_mosi_strobe) begin
                        // chuyen sang ADDR
                        {o_mosi, r_mosi_buf} <= {i_reg_addr, 1'b0};
                        r_bitcount  <= 3'd0;
                        r_next_state<= ADDR_OUT;
                    end
                end

                // xuat 8 bit ADDR
                ADDR_OUT: begin
                    if (w_mosi_strobe && (r_bitcount < 3'd7)) begin
                        {o_mosi, r_mosi_buf} <= {r_mosi_buf, 1'b0};
                        r_bitcount <= r_bitcount + 3'd1;
                    end else if (w_mosi_strobe) begin
                        r_bitcount <= 3'd0;
                        if (i_sel_rw) begin
                            // READ: bat dau doc -> MOSI phat dummy 0
                            o_mosi      <= 1'b0;
                            r_mosi_buf  <= 8'h00;
                            r_next_state<= READ_DATA;
                        end else begin
                            // WRITE: nap du lieu ghi
                            {o_mosi, r_mosi_buf} <= {i_dout, 1'b0};
                            r_next_state <= WRITE_DATA;
                        end
                    end
                end

                // ghi 8 bit data
                WRITE_DATA: begin
                    if (w_mosi_strobe && (r_bitcount < 3'd7)) begin
                        {o_mosi, r_mosi_buf} <= {r_mosi_buf, 1'b0};
                        r_bitcount <= r_bitcount + 3'd1;
                    end else if (w_mosi_strobe) begin
                        o_mosi     <= 1'b0;
                        r_mosi_buf <= 8'h00;
                        r_bitcount <= 3'd0;
                        r_next_state <= ENDING;
                    end
                end

                // doc 8 bit MISO; dong thoi phat dummy 0x00 o canh MOSI_STROBE
                READ_DATA: begin
                    // phat dummy 0 de duy tri clock chuan
                    if (w_mosi_strobe) begin
                        o_mosi <= 1'b0;
                    end
                    if (w_sclk_posedge && (r_bitcount < 3'd7)) begin
                        r_miso_buf <= {r_miso_buf[5:0], i_miso};
                        r_bitcount <= r_bitcount + 3'd1;
                    end else if (w_sclk_posedge) begin
                        o_din       <= {r_miso_buf, i_miso};
                        o_din_valid <= 1'b1;    // xung 1 chu ky
                        r_bitcount  <= 3'd0;
                        r_next_state<= ENDING;
                    end
                end

                // keo CSN len o canh xuong, sau do tat SCLK
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
