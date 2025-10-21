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
  // Monitor (tuy chon)
  // -----------------------
  always @(negedge o_csn)  $display("[%0t] CSN FALL (frame start)", $time);
  always @(posedge  o_csn)  $display("[%0t] CSN RISE  (frame end)",  $time);

  // -----------------------
  // Thu MOSI trong 1 frame ghi 24 bit (INST+ADDR+DATA)
  // -----------------------
  reg [23:0] mosi_stream;
  integer    bit_cnt;
  reg        sample_en;

  // sample MOSI tai posedge SCLK (mode 0)
  always @(posedge o_sclk) begin
    if (o_csn == 1'b0 && sample_en) begin
      mosi_stream <= {mosi_stream[22:0], o_mosi};
      bit_cnt     <= bit_cnt + 1;
      if (bit_cnt == 23) sample_en <= 1'b0; // da lay 24 bit
    end
  end

  // -----------------------
  // "Slave" ADXL362 gia don cho MISO (chi de test READ)
  // - sau 16 canh len: tra 8 bit RESP_BYTE MSB truoc
  // - update o canh xuong (master sample o canh len)
  // -----------------------
  localparam [7:0] RESP_BYTE = 8'hA5;
  integer sclk_rise_cnt;
  reg [7:0] resp_shift;

  // dem canh len SCLK khi CSN=0
  always @(posedge o_sclk or posedge o_csn) begin
    if (o_csn) begin
      sclk_rise_cnt <= 0;
    end else begin
      sclk_rise_cnt <= sclk_rise_cnt + 1;
    end
  end

  // xuat MISO o canh xuong SCLK sau 16 canh len
  always @(negedge o_sclk or posedge o_csn) begin
    if (o_csn) begin
      i_miso     <= 1'b0;       // tha ve 0 khi khong chon
      resp_shift <= RESP_BYTE;  // nap lai byte tra loi
    end else begin
      if (sclk_rise_cnt >= 16 && sclk_rise_cnt <= 23) begin
        i_miso     <= resp_shift[7];
        resp_shift <= {resp_shift[6:0], 1'b0};
      end else begin
        i_miso <= 1'b0;
      end
    end
  end

  // -----------------------
  // Tasks
  // -----------------------
  task pulse_ready_2;
    begin
      @(posedge i_clk); i_ready <= 1'b1;
      @(posedge i_clk); i_ready <= 1'b1;
      @(posedge i_clk); i_ready <= 1'b0;
    end
  endtask

  task capture_mosi_24; // bat dau sau khi CSN ha
    begin
      mosi_stream = 24'h0;
      bit_cnt     = 0;
      sample_en   = 1'b0;
      @(posedge o_sclk); // canh sample dau tien
      sample_en   = 1'b1;
      @(posedge o_csn);  // ket thuc frame
    end
  endtask

  // -----------------------
  // Stimulus
  // -----------------------
  initial begin
    // defaults
    i_ready = 1'b0;
    i_inst  = 8'h00;
    i_sel_rw= 1'b0;
    i_reg_addr = 8'h00;
    i_dout  = 8'h00;
    mosi_stream = 24'h0; bit_cnt = 0; sample_en = 1'b0;

    // reset
    i_rst = 1'b1;
    repeat (10) @(posedge i_clk);
    i_rst = 1'b0;

    // -------------------
    // 1) WRITE: 0x0A, 0x2D, 0x02
    // -------------------
    @(posedge i_clk);
    i_inst     <= 8'h0A;
    i_sel_rw   <= 1'b0;      // WRITE
    i_reg_addr <= 8'h2D;
    i_dout     <= 8'h02;

    pulse_ready_2();
    @(negedge o_csn);
    capture_mosi_24();

    #1;
    $display("WRITE MOSI: got 0x%06h, expect 0x%06h",
              mosi_stream, {i_inst, i_reg_addr, i_dout});

    // -------------------
    // 2) READ: 0x0B, 0x0E, slave tra RESP_BYTE
    // -------------------
    @(posedge i_clk);
    i_inst     <= 8'h0B;
    i_sel_rw   <= 1'b1;      // READ
    i_reg_addr <= 8'h0E;
    i_dout     <= 8'h00;     // khong dung

    pulse_ready_2();

    // doi du lieu hop le
    wait (o_din_valid === 1'b1);
    $display("READ  MISO: o_din=0x%0h (expect 0x%0h)", o_din, RESP_BYTE);

    #200;
    $finish;
  end

endmodule
