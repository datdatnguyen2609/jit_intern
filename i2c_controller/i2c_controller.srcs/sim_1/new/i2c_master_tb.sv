`timescale 1ns/1ps

module i2c_master_tb;

  // ================= Clock & Reset =================
  reg i_sys_clk   = 1'b0;  // 100 MHz
  reg i_sys_rst_n = 1'b0;
  always #5 i_sys_clk = ~i_sys_clk; // 10 ns period

  // ================= I2C bus (open-drain) =================
  tri1 io_sda;                   // pull-up mac dinh la '1'
  pullup PUSDA (io_sda);

  wire o_scl;                    // SCL tu DUT

  // Slave open-drain drive: chi keo 0 hoac nha Z
  reg sda_drv_en = 1'b0;         // 1->keo 0; 0->Z
  assign io_sda = sda_drv_en ? 1'b0 : 1'bz;

  // ================= DUT =================
  wire [26:0] o_rd_data;

  // Tang SCL lên 1 MHz de giam thoi gian choi o IDLE (khong dung defparam)
  i2c_master #(
    .DEVICE_ADDR  (7'b1001_011),     // 0x4B
    .SYS_CLK_FREQ ('d100_000_000),
    .SCL_FREQ     ('d1_000_000)      // ? nhanh hon de mo phong nhanh
  ) dut (
    .i_sys_clk  (i_sys_clk),
    .i_sys_rst_n(i_sys_rst_n),
    .io_i2c_sda (io_sda),
    .o_i2c_scl  (o_scl),
    .o_rd_data  (o_rd_data)
  );

  // ================= Simple ADT7420 Slave Model =================
  // - ACK o cac vi tri 9, 18, 27 (sau 8b addrW, 8b reg, 8b addrR)
  // - Tra ve 2 byte: MSB=0x1A, LSB=0x90 (?26.5625°C)
  // - Cap nhat SDA o canh xuong SCL (on-dinh truoc canh len SCL)
  integer bit_cnt = 0;

  localparam [7:0] TEMP_MSB = 8'h1A;
  localparam [7:0] TEMP_LSB = 8'h90;

  // Dem bit theo posedge SCL
  always @(posedge o_scl or negedge i_sys_rst_n) begin
    if (!i_sys_rst_n)
      bit_cnt <= 0;
    else if (bit_cnt < 200)
      bit_cnt <= bit_cnt + 1;
  end

  // Chuan bi SDA o negedge SCL cho bit ke tiep
  always @(negedge o_scl or negedge i_sys_rst_n) begin
    if (!i_sys_rst_n) begin
      sda_drv_en <= 1'b0; // release
    end else begin
      sda_drv_en <= 1'b0; // mac dinh release

      // ACK o bit 9,18,27
      if (bit_cnt + 1 == 9  ||
          bit_cnt + 1 == 18 ||
          bit_cnt + 1 == 27) begin
        sda_drv_en <= 1'b1; // keo 0 de ACK
      end

      // DATA_MSB: bit 28..35 (MSB->LSB)
      if (bit_cnt + 1 >= 28 && bit_cnt + 1 <= 35) begin
        integer idx;
        idx = (bit_cnt + 1) - 28;
        sda_drv_en <= (TEMP_MSB[7 - idx] == 1'b0) ? 1'b1 : 1'b0;
      end

      // bit 36: Master ACK -> slave release (giu default)

      // DATA_LSB: bit 37..44 (MSB->LSB)
      if (bit_cnt + 1 >= 37 && bit_cnt + 1 <= 44) begin
        integer idx2;
        idx2 = (bit_cnt + 1) - 37;
        sda_drv_en <= (TEMP_LSB[7 - idx2] == 1'b0) ? 1'b1 : 1'b0;
      end

      // bit 45: Master NACK -> slave release (giu default)
    end
  end

  // ================= Stimulus & Monitor =================
  initial begin
    // // Mo VCD neu can
    // $dumpfile("i2c_master_tb.vcd");
    // $dumpvars(0, i2c_master_tb);

    // Reset
    i_sys_rst_n = 1'b0;
    repeat (5) @(posedge i_sys_clk);
    i_sys_rst_n = 1'b1;

    // Cho den khi co du lieu doc ra
    wait (o_rd_data != 27'd0);

    $display("[TB] o_rd_data = %0d (milli-deg C?)", o_rd_data);

    repeat (2000) @(posedge i_sys_clk);
    $finish;
  end

endmodule
