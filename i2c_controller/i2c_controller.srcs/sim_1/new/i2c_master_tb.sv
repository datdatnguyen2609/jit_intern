`timescale 1ms/1ns

module i2c_master_tb;

  // ---------------- Clock & Reset ----------------
  reg i_sys_clk = 1'b0;           // 100 MHz
  reg i_rst     = 1'b1;           // active-HIGH (??ng b? trong DUT)
  always #5 i_sys_clk = ~i_sys_clk;

  initial begin
    repeat (10) @(posedge i_sys_clk);
    i_rst = 1'b0;
  end

  // ---------------- I2C bus ----------------
  tri1 io_i2c_sda;                // SDA có pull-up
  pullup PU_SDA(io_i2c_sda);

  wire        o_i2c_scl;          // SCL t? DUT
  wire [26:0] o_rd_data;

  // ---------------- DUT ----------------
  localparam SYS_CLK_FREQ = 100_000_000;
  localparam SCL_FREQ     = 200_000;
  localparam DEVICE_ADDR  = 7'b1001_011;

  i2c_master #(
    .DEVICE_ADDR  (DEVICE_ADDR),
    .SYS_CLK_FREQ (SYS_CLK_FREQ),
    .SCL_FREQ     (SCL_FREQ)
  ) dut (
    .i_sys_clk (i_sys_clk),
    .i_rst     (i_rst),
    .io_i2c_sda(io_i2c_sda),
    .o_i2c_scl (o_i2c_scl),
    .o_rd_data (o_rd_data)
  );

  // ---------------- Slave ADT7420 t?i gi?n ----------------
  // Open-drain t? slave: ch? kéo 0 ho?c th? Z
  reg sda_drv_en = 1'b0;          // 1 -> kéo 0; 0 -> Z (pull-up)
  assign io_i2c_sda = sda_drv_en ? 1'b0 : 1'bz;

  // Nhi?t ?? m?u (tr? v? sau 3 byte ??u): MSB tr??c
  localparam [15:0] TEMP_WORD = 16'h1A90;

  // START/STOP detect (SDA ??i khi SCL=1)
  reg sda_q, scl_q;
  always @(posedge i_sys_clk) begin
    sda_q <= io_i2c_sda;
    scl_q <= o_i2c_scl;
  end

  wire w_start = (sda_q==1'b1) && (io_i2c_sda==1'b0) && (o_i2c_scl==1'b1);
  wire w_stop  = (sda_q==1'b0) && (io_i2c_sda==1'b1) && (o_i2c_scl==1'b1);

  integer bit_count = 0;          // ??m c?nh lên SCL trong 1 giao d?ch
  integer rd_bit    = 15;         // phát MSB->LSB
  reg     in_xfer   = 1'b0;

  always @(posedge i_sys_clk) begin
    if (i_rst) begin
      in_xfer    <= 1'b0;
      bit_count  <= 0;
      rd_bit     <= 15;
      sda_drv_en <= 1'b0;
    end else begin
      // START: b?t ??u khung m?i
      if (w_start) begin
        in_xfer    <= 1'b1;
        bit_count  <= 0;
        rd_bit     <= 15;
        sda_drv_en <= 1'b0;
      end
      // STOP: k?t thúc khung
      if (w_stop) begin
        in_xfer    <= 1'b0;
        bit_count  <= 0;
        rd_bit     <= 15;
        sda_drv_en <= 1'b0;
      end

      // ??m bit ? c?nh lên SCL
      if (in_xfer && (o_i2c_scl===1'b1) && (scl_q===1'b0))
        bit_count <= bit_count + 1;

      // Chu?n b? SDA ? c?nh xu?ng SCL
      if (in_xfer && (o_i2c_scl===1'b0) && (scl_q===1'b1)) begin
        sda_drv_en <= 1'b0; // m?c ??nh th? Z

        // ACK ? bit th? 9, 18, 27 (sau 3 byte ??u c?a master)
        if (bit_count==8 || bit_count==17 || bit_count==26) begin
          sda_drv_en <= 1'b1; // kéo 0 ?? ACK
        end
        // Sau ?ó tr? 16 bit d? li?u ??c (MSB -> LSB)
        else if (bit_count>=27 && bit_count<43) begin
          sda_drv_en <= (TEMP_WORD[rd_bit]==1'b0); // '0' -> kéo 0; '1' -> Z
          if (rd_bit>0) rd_bit <= rd_bit - 1;
        end
      end
    end
  end

  // ---------------- K?t thúc mô ph?ng ----------------
  initial begin
    // RTL có ch? ~0.6 s tr??c khi START; ch?y ?? dài ?? th?y 1 giao d?ch
    #(800_000_000); // 800 ms
    $display("Done. o_rd_data = %0d", o_rd_data);
    $finish;
  end

endmodule
