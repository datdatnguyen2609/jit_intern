`timescale 1ns/1ps
module spi_adxl362_controller_tb;

  // =======================
  // DUT I/Os
  // =======================
  reg         i_clk;
  reg         i_rst;

  wire        o_csn;
  wire        o_sclk;
  wire        o_mosi;
  reg         i_miso;

  reg         i_ready;
  reg  [7:0]  i_inst;
  reg         i_sel_rw;      // 0=WRITE, 1=READ
  reg  [7:0]  i_reg_addr;
  reg  [7:0]  i_dout;
  wire [7:0]  o_din;
  wire        o_din_valid;

  // =======================
  // DUT instance
  // =======================
  spi_adxl362_controller dut (
    .i_clk(i_clk),
    .i_rst(i_rst),
    .o_csn(o_csn),
    .o_sclk(o_sclk),
    .o_mosi(o_mosi),
    .i_miso(i_miso),
    .i_ready(i_ready),
    .i_inst(i_inst),
    .i_sel_rw(i_sel_rw),
    .i_reg_addr(i_reg_addr),
    .i_dout(i_dout),
    .o_din(o_din),
    .o_din_valid(o_din_valid)
  );

  // =======================
  // Clock & Reset
  // =======================
  // 100 MHz -> 10 ns period
  initial i_clk = 1'b0;
  always #5 i_clk = ~i_clk;

  task do_reset;
    begin
      i_rst     = 1'b1;
      i_ready   = 1'b0;
      i_inst    = 8'h00;
      i_sel_rw  = 1'b0;
      i_reg_addr= 8'h00;
      i_dout    = 8'h00;
      i_miso    = 1'b0;
      repeat (5) @(posedge i_clk);
      i_rst     = 1'b0;
      repeat (5) @(posedge i_clk);
    end
  endtask

  // =======================
  // Simple SPI "slave" model (MSB-first)
  // - Shifts out data on MISO at each NEGEDGE of o_sclk
  // - Loads a new response byte on CSN falling edge
  // =======================
  reg  [7:0] slave_shift;
  reg  [7:0] slave_next_resp;  // giá tr? s? tr? v? cho l?n READ k? ti?p

  // Khi CSN xu?ng th?p: n?p byte tr? l?i
  always @(negedge o_csn) begin
    slave_shift <= slave_next_resp;
  end

  // Xu?t bit MISO ? m?i NEGEDGE SCLK (DUT sample ? posedge)
  always @(negedge o_sclk) begin
    if (!o_csn) begin
      i_miso      <= slave_shift[7];
      slave_shift <= {slave_shift[6:0], 1'b0};
    end else begin
      i_miso <= 1'b0;
    end
  end

  // =======================
  // Helpers
  // =======================
  // Phát xung ready = 1 chu k? clk
  task pulse_ready;
    begin
      @(posedge i_clk);
      i_ready <= 1'b1;
      @(posedge i_clk);
      i_ready <= 1'b0;
    end
  endtask

  // Ch? 1 giao d?ch SPI k?t thúc (CSN tr? l?i HIGH)
  task wait_done;
    integer guard;
    begin
      guard = 0;
      // ??i CSN kéo xu?ng
      while (o_csn && guard < 100000) begin
        @(posedge i_clk); guard = guard + 1;
      end
      // ??i CSN kéo lên l?i
      while (!o_csn && guard < 200000) begin
        @(posedge i_clk); guard = guard + 1;
      end
      if (guard >= 200000) begin
        $display("[%0t] TIMEOUT waiting transaction done", $time);
      end
      // thêm vài nh?p cho ch?c
      repeat (5) @(posedge i_clk);
    end
  endtask

  // =======================
  // WRITE transaction
  // =======================
  // inst: ví d? 8'h0A (WRITE)
  task do_write(input [7:0] inst, input [7:0] addr, input [7:0] data);
    begin
      $display("[%0t] >>> WRITE: inst=0x%02h addr=0x%02h data=0x%02h", $time, inst, addr, data);
      i_inst     <= inst;
      i_sel_rw   <= 1'b0;   // WRITE
      i_reg_addr <= addr;
      i_dout     <= data;
      pulse_ready();
      wait_done();
    end
  endtask

  // =======================
  // READ transaction
  // =======================
  // inst: ví d? 8'h0B (READ)
  task do_read(input [7:0] inst, input [7:0] addr, input [7:0] resp_byte);
    begin
      // c?u hình byte ph?n h?i MISO c?a "slave"
      slave_next_resp <= resp_byte;

      $display("[%0t] >>> READ : inst=0x%02h addr=0x%02h (slave_resp=0x%02h)",
               $time, inst, addr, resp_byte);

      i_inst     <= inst;
      i_sel_rw   <= 1'b1;   // READ
      i_reg_addr <= addr;
      i_dout     <= 8'h00;

      pulse_ready();
      wait_done();

      if (o_din_valid) begin
        $display("[%0t] <<< READ DONE: o_din=0x%02h (expected 0x%02h)%s",
                 $time, o_din, resp_byte, (o_din==resp_byte) ? " [OK]" : " [MISMATCH]");
      end else begin
        $display("[%0t] <<< READ DONE: o_din_valid=0 (no data)", $time);
      end
    end
  endtask

  // =======================
  // Optional: sniff MOSI for debug
  // Thu th?p 24 bit ??u (INST + ADDR + DATA/READ-DATA) MSB-first
  // =======================
  reg [31:0] mosi_shift_dbg;
  integer    mosi_bitcnt;
  always @(negedge o_csn) begin
    mosi_shift_dbg <= 0;
    mosi_bitcnt    <= 0;
  end

  always @(negedge o_sclk) begin
    if (!o_csn) begin
      mosi_shift_dbg <= {mosi_shift_dbg[30:0], o_mosi};
      mosi_bitcnt    <= mosi_bitcnt + 1;
      if (mosi_bitcnt==7)  $display("[%0t] MOSI INST  = 0x%02h", $time, mosi_shift_dbg[6:0] << 1 | o_mosi);
      if (mosi_bitcnt==15) $display("[%0t] MOSI ADDR  = 0x%02h", $time, mosi_shift_dbg[14:7]);
      if (mosi_bitcnt==23) $display("[%0t] MOSI DATA? = 0x%02h", $time, mosi_shift_dbg[22:15]);
    end
  end

  // =======================
  // Main stimulus
  // =======================
  initial begin
    do_reset();

    // ===== Case 1: WRITE (ví d?: 0x0A, REG 0x2D, DATA 0x02)
    do_write(8'h0A, 8'h2D, 8'h02);

    // ===== Case 2: READ  (ví d?: 0x0B, REG 0x0E), slave tr? 0xA5
    do_read(8'h0B, 8'h0E, 8'hA5);

    // ===== Case 3: READ  khác ?? ki?m tra (tr? 0x5A)
    do_read(8'h0B, 8'h08, 8'h5A);

    $display("[%0t] Simulation finished.", $time);
    #2000 $finish;
  end

endmodule
