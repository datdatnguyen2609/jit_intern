`timescale 1ns / 1ps
module spi_adxl362_controller_tb;

  // -----------------------
  // DUT ports
  // -----------------------
  reg         i_clk;
  reg         i_rst;

  wire        o_csn;
  wire        o_sclk;
  wire        o_mosi;
  reg         i_miso;

  reg         i_ready;
  reg  [7:0]  i_inst;
  reg         i_sel_rw;     // 0: WRITE, 1: READ
  reg  [7:0]  i_reg_addr;
  reg  [7:0]  i_dout;
  wire [7:0]  o_din;
  wire        o_din_valid;

  // -----------------------
  // Instantiate DUT
  // -----------------------
  spi_adxl362_controller dut (
    .i_clk      (i_clk),
    .i_rst      (i_rst),
    .o_csn      (o_csn),
    .o_sclk     (o_sclk),
    .o_mosi     (o_mosi),
    .i_miso     (i_miso),
    .i_ready    (i_ready),
    .i_inst     (i_inst),
    .i_sel_rw   (i_sel_rw),
    .i_reg_addr (i_reg_addr),
    .i_dout     (i_dout),
    .o_din      (o_din),
    .o_din_valid(o_din_valid)
  );

  // -----------------------
  // Clock: 100 MHz
  // -----------------------
  initial i_clk = 1'b0;
  always  #5 i_clk = ~i_clk;

  // -----------------------
  // VCD (tùy ch?n)
  // -----------------------
  initial begin
    $dumpfile("spi_tx1byte.vcd");
    $dumpvars(0, spi_adxl362_controller_tb);
  end

  // -----------------------
  // Monitor s? ki?n (tùy ch?n)
  // -----------------------
  always @(negedge o_csn)  $display("[%0t] CSN FALL (frame start)", $time);
  always @(posedge o_csn)  $display("[%0t] CSN RISE  (frame end)",   $time);

  // -----------------------
  // B?t MOSI trong 1 frame ghi 24 bit (INST+ADDR+DATA)
  // -----------------------
  reg [23:0] mosi_stream;  // ch?a 24 bit ?ã thu
  integer    bit_cnt;

  // Thu bit MOSI ? c?nh xu?ng SCLK khi CSN=0 (SPI mode 0)
  always @(negedge o_sclk) begin
    if (o_csn == 1'b0) begin
      mosi_stream <= {mosi_stream[22:0], o_mosi}; // d?ch trái, thêm bit m?i vào LSB
      bit_cnt     <= bit_cnt + 1;
    end
  end

  // -----------------------
  // Reset & 1 giao d?ch WRITE (1 byte)
  // -----------------------
  initial begin
    // defaults
    i_miso     = 1'b0;
    i_ready    = 1'b0;
    i_inst     = 8'h00;
    i_sel_rw   = 1'b0;       // WRITE
    i_reg_addr = 8'h00;
    i_dout     = 8'h00;

    mosi_stream = 24'h0;
    bit_cnt     = 0;

    // reset
    i_rst = 1'b1;
    repeat (10) @(posedge i_clk);
    i_rst = 1'b0;

    // chu?n b? n?i dung giao d?ch: WRITE 0x02 vào addr 0x2D
    @(posedge i_clk);
    i_inst     <= 8'h0A;     // ADXL362 WRITE
    i_sel_rw   <= 1'b0;      // WRITE
    i_reg_addr <= 8'h2D;
    i_dout     <= 8'h02;

    // nhá i_ready ?úng 1 chu k?
    @(posedge i_clk);
    i_ready <= 1'b1;
    @(posedge i_clk);
    i_ready <= 1'b0;

    // ch? b?t ??u frame
    @(negedge o_csn);
    // reset b? ??m/buffer tr??c khi thu 24 bit
    mosi_stream = 24'h0;
    bit_cnt     = 0;

    // ch? ?? 24 c?nh xu?ng (8b INST + 8b ADDR + 8b DATA)
    wait (bit_cnt >= 24);

    // ch? k?t thúc frame (CSN lên l?i)
    @(posedge o_csn);

    // K? v?ng: MSB-first, ta ?ã thu theo th? t? MSB->LSB vào mosi_stream b?ng d?ch trái
    // nên mosi_stream ph?i b?ng {INST, ADDR, DATA}
    #1; // nh? ?? ??m b?o c?p nh?t non-blocking xong
    $display("[%0t] Collected 24 MOSI bits: 0x%06h", $time, mosi_stream);
    $display("Expected                 : 0x%06h", {i_inst, i_reg_addr, i_dout});

    if (mosi_stream === {i_inst, i_reg_addr, i_dout})
      $display("RESULT: PASS (MOSI matches INST|ADDR|DATA)");
    else
      $display("RESULT: FAIL (MOSI mismatch)");

    // k?t thúc
    #(2000);
    $display("[%0t] Test finished.", $time);
    $finish;
  end

endmodule
