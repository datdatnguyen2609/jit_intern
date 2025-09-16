`timescale 1ns/1ps

module i2c_master_tb;

  // ================= System clock & reset =================
  parameter CLK_HZ  = 100_000_000;
  real      TCLK_NS = 1.0e9 / CLK_HZ;

  reg i_clk, i_rst_n;
  initial begin
    i_clk = 1'b0;
    forever #(TCLK_NS/2.0) i_clk = ~i_clk;  // 100 MHz
  end
  initial begin
    i_rst_n = 1'b0;
    repeat (10) @(posedge i_clk);
    i_rst_n = 1'b1;
  end

  // ================= DUT I/O =================
  reg         i_start;
  reg  [6:0]  i_dev_addr;
  reg  [7:0]  i_reg_addr;
  reg  [7:0]  i_wr_data;
  reg  [7:0]  i_read_len;

  wire        o_busy, o_done, o_nack;
  wire [7:0]  o_rd_data;
  wire        o_rd_valid;

  // I2C lines (open-drain) v?i pull-up m?c ??nh
  tri1 io_SDA;
  tri1 io_SCL;

  // ================= DUT =================
  i2c_master #(
    .CLK_HZ (CLK_HZ),
    .SCL_HZ (100_000)
  ) dut (
    .i_clk(i_clk),
    .i_rst_n(i_rst_n),
    .i_start(i_start),
    .i_dev_addr(i_dev_addr),
    .i_reg_addr(i_reg_addr),
    .i_wr_data(i_wr_data),
    .i_read_len(i_read_len),
    .o_busy(o_busy),
    .o_done(o_done),
    .o_nack(o_nack),
    .o_rd_data(o_rd_data),
    .o_rd_valid(o_rd_valid),
    .io_SDA(io_SDA),
    .io_SCL(io_SCL)
  );

  // ============== ADT7420 slave ??n gi?n (7'h4B) ==============
  localparam [6:0] ADT_ADDR = 7'h4B;

  // Open-drain t? slave
  reg sda_lo_slv;                     // 1 => kéo th?p, 0 => th?
  assign io_SDA = sda_lo_slv ? 1'b0 : 1'bz;

  // C?m nh?n bus
  wire SDA = io_SDA;
  wire SCL = io_SCL;

  // B?t c?nh & START/STOP
  reg sda_q, scl_q;
  always @(posedge i_clk) begin
    sda_q <= SDA;  scl_q <= SCL;
  end
  wire scl_rise   = (SCL==1'b1 && scl_q==1'b0);
  wire scl_fall   = (SCL==1'b0 && scl_q==1'b1);
  wire start_cond = (sda_q==1'b1 && SDA==1'b0 && SCL==1'b1);
  wire stop_cond  = (sda_q==1'b0 && SDA==1'b1 && SCL==1'b1);

  // Tr?ng thái r?t g?n
  localparam [2:0]
    S_IDLE       = 3'd0,
    S_ADDR       = 3'd1,
    S_ADDR_ACK   = 3'd2,
    S_WPTR_BYTE  = 3'd3,   // nh?n 1 byte con tr? thanh ghi
    S_WPTR_ACK   = 3'd4,
    S_READ_BYTE  = 3'd5,   // phát 2 byte: 0x0C, 0x80
    S_READ_ACK   = 3'd6;

  reg [2:0] sst;
  reg [7:0] shreg;
  reg [2:0] bitcnt;
  reg       rw;
  reg       addr_ok;
  reg [7:0] reg_ptr;
  reg [1:0] rd_left;       // còn bao nhiêu byte ?? phát

  // Giá tr? nhi?t ?? c? ??nh
  localparam [7:0] TEMP_MSB = 8'h0C;
  localparam [7:0] TEMP_LSB = 8'h80;

  initial begin
    sda_lo_slv = 1'b0;
    sst        = S_IDLE;
    bitcnt     = 3'd7;
    shreg      = 8'h00;
    rw         = 1'b0;
    addr_ok    = 1'b0;
    reg_ptr    = 8'h00;
    rd_left    = 2'd0;
  end

  // FSM c?c ng?n g?n: ch? h? tr? ghi con tr? (1 byte) và ??c 2 byte t? 0x00
  always @(posedge i_clk) begin
    // Th? SDA m?c ??nh gi?a các bit (tr? lúc ACK/?ang phát)
    if (scl_fall) begin
      if (sst != S_READ_BYTE && sst != S_ADDR_ACK && sst != S_WPTR_ACK)
        sda_lo_slv <= 1'b0;
    end

    if (start_cond) begin
      sst     <= S_ADDR;
      bitcnt  <= 3'd7;
      shreg   <= 8'h00;
      addr_ok <= 1'b0;
    end
    else if (stop_cond) begin
      sst       <= S_IDLE;
      sda_lo_slv<= 1'b0;
    end
    else begin
      case (sst)
        // Nh?n 7-bit addr + R/W (bit thu th? 8 là R/W)
        S_ADDR: begin
          if (scl_rise) begin
            shreg[bitcnt] <= SDA;
            if (bitcnt == 3'd0) begin
              rw      <= SDA;
              addr_ok <= (shreg[7:1] == ADT_ADDR);   // <<< S?A: b? slice trên concatenation
              sst     <= S_ADDR_ACK;
              bitcnt  <= 3'd7;
            end else bitcnt <= bitcnt - 3'd1;
          end
        end

        // ACK ??a ch?
        S_ADDR_ACK: begin
          if (scl_fall) sda_lo_slv <= addr_ok ? 1'b1 : 1'b0; // ACK n?u ?úng ??a ch?
          if (scl_rise) begin
            sda_lo_slv <= 1'b0;
            if (!addr_ok)        sst <= S_IDLE;
            else if (rw) begin
              // B?t ??u ??c 2 byte t? con tr? hi?n t?i
              rd_left <= 2'd2;
              shreg   <= (reg_ptr==8'h00) ? TEMP_MSB : TEMP_LSB;
              sst     <= S_READ_BYTE;
              bitcnt  <= 3'd7;
            end else begin
              // Vi?t 1 byte con tr?
              sst    <= S_WPTR_BYTE;
              bitcnt <= 3'd7;
              shreg  <= 8'h00;
            end
          end
        end

        // Nh?n 1 byte con tr? thanh ghi
        S_WPTR_BYTE: begin
          if (scl_rise) begin
            shreg[bitcnt] <= SDA;
            if (bitcnt == 3'd0) begin
              reg_ptr <= {shreg[7:1], SDA};         // OK trong Verilog-2001
              sst     <= S_WPTR_ACK;
              bitcnt  <= 3'd7;
            end else bitcnt <= bitcnt - 3'd1;
          end
        end

        // ACK con tr?
        S_WPTR_ACK: begin
          if (scl_fall) sda_lo_slv <= 1'b1;   // ACK
          if (scl_rise) begin
            sda_lo_slv <= 1'b0;               // ??i repeated START
            sst        <= S_WPTR_BYTE;        // v?n s?n sàng n?u master g?i thêm
          end
        end

        // Phát 1 byte d? li?u ??c
        S_READ_BYTE: begin
          if (scl_fall) sda_lo_slv <= ~shreg[7];  // bit=0 kéo th?p, bit=1 th?
          if (scl_rise) begin
            if (bitcnt == 3'd0) begin
              sda_lo_slv <= 1'b0;               // nh??ng ACK/NACK c?a master
              sst        <= S_READ_ACK;
              bitcnt     <= 3'd7;
            end else begin
              shreg  <= {shreg[6:0],1'b0};
              bitcnt <= bitcnt - 3'd1;
            end
          end
        end

        // Quan sát ACK/NACK c?a master
        S_READ_ACK: begin
          if (scl_rise) begin
            if (SDA == 1'b0 && rd_left > 1) begin
              // Master ACK: chu?n b? byte ti?p theo
              rd_left <= rd_left - 1'b1;
              if (reg_ptr == 8'h00) begin
                reg_ptr <= 8'h01;
                shreg   <= TEMP_LSB;
              end else begin
                shreg   <= TEMP_LSB; // an toàn
              end
              sst <= S_READ_BYTE;
            end else begin
              // NACK ho?c h?t d? li?u -> ch? STOP
              sst <= S_IDLE;
            end
          end
        end

        default: sst <= S_IDLE;
      endcase
    end
  end

  // ================= Kích thích ??n gi?n =================
  reg [7:0] rd_bytes [0:1];
  integer   rd_cnt;

  initial begin
    // init inputs
    i_start    = 1'b0;
    i_dev_addr = 7'd0;
    i_reg_addr = 8'd0;
    i_wr_data  = 8'd0;
    i_read_len = 8'd0;
    rd_cnt     = 0;

    @(posedge i_rst_n);

    // (1) ??c 2 byte t? 0x00:
    // Master: START + (addrW) + reg=0x00 + RESTART + (addrR) + ??c 2 byte
    drive_request(7'h4B, 8'h00, 8'h00, 8'd2);
    wait (o_busy==1'b1);
    wait (o_done==1'b1);
    @(posedge i_clk);

    // In k?t qu?
    if (rd_cnt==2)
      $display("[TB] Read bytes: %02h %02h (expect 0C 80)", rd_bytes[0], rd_bytes[1]);
    else
      $display("[TB][ERR] expected 2 bytes, got %0d", rd_cnt);

    repeat (10000) @(posedge i_clk);
    $finish;
  end

  // Thu 2 byte t? o_rd_valid (dùng counter, không d?a vào so sánh == 0x00)
  always @(posedge i_clk) begin
    if (o_rd_valid && rd_cnt < 2) begin
      rd_bytes[rd_cnt] <= o_rd_data;
      rd_cnt <= rd_cnt + 1;
      $display("[%0t ns] o_rd_valid data=0x%02h", $time, o_rd_data);
    end
  end

  // Task phát 1 request
  task drive_request;
    input [6:0] dev7;
    input [7:0] reg8;
    input [7:0] wr8;
    input [7:0] read_len;
  begin
    @(posedge i_clk);
    i_dev_addr <= dev7;
    i_reg_addr <= reg8;
    i_wr_data  <= wr8;
    i_read_len <= read_len;
    i_start    <= 1'b1;
    @(posedge i_clk);
    i_start    <= 1'b0;
  end
  endtask

endmodule
