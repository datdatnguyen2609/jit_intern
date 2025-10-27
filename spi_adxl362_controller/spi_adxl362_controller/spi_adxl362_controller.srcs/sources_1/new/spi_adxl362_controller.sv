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
