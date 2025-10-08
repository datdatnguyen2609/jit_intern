`timescale 1ns/1ps

module top_tb;

  // =======================
  // Clock / Reset
  // =======================
  reg  i_sys_clk = 1'b0;          // 100 MHz
  reg  i_rst     = 1'b1;          // active-HIGH, dong bo

  always #5 i_sys_clk = ~i_sys_clk; // 10 ns period

  initial begin
    // reset trong ~500 ns
    repeat (50) @(posedge i_sys_clk);
    i_rst <= 1'b0;
  end

  // =======================
  // I2C bus (open-drain)
  // =======================
  tri1        io_i2c_sda;         // SDA co pull-up
  pullup      PU_SDA(io_i2c_sda);

  wire        o_i2c_scl;          // SCL tu DUT (push-pull/gated)
  wire [7:0]  o_sel;
  wire [7:0]  o_seg;

  // =======================
  // DUT
  // =======================
  top dut (
    .i_sys_clk (i_sys_clk),
    .i_rst     (i_rst),
    .io_i2c_sda(io_i2c_sda),
    .o_i2c_scl (o_i2c_scl),
    .o_sel     (o_sel),
    .o_seg     (o_seg)
  );

  // ============================================================
  // ADT7420 "very-light" behavioral slave
  // - Phat hien START: SDA giam trong khi SCL = 1
  // - Dem so canh len cua SCL de biet vi tri bit (1..9, 10..18, ...)
  // - ACK o bit 9, 18, 27 (sau 3 byte dau tien)
  // - Sau do, xuat 16 bit du lieu (MSB truoc) tren 16 xung SCL tiep theo
  //   (master se ACK byte MSB va NACK byte LSB)
  //
  // Chu y: Model nay la heuristic, du cho FSM "phi chuan" van chay duoc.
  // ============================================================

  // Open-drain drive tu slave: chi keo 0 hoac nha Z
  reg  sda_drv_en = 1'b0;   // 1->keo 0, 0->Z (pull-up)
  assign io_i2c_sda = sda_drv_en ? 1'b0 : 1'bz;

  // Theo datasheet ADT7420, nhiet do 16-bit: 
  // (vi du) 0x1A90 = 26.5625°C (format 13-bit + 3 LSB)
  localparam [15:0] TEMP_WORD = 16'h1A90;

  // Detect START/STOP + counter tren SCL
  reg sda_q, scl_q;
  always @(posedge i_sys_clk) begin
    sda_q <= io_i2c_sda;
    scl_q <= o_i2c_scl;
  end

  wire w_scl_high = (o_i2c_scl == 1'b1);
  wire w_start    = (sda_q == 1'b1) && (io_i2c_sda == 1'b0) && w_scl_high; // SDA: 1->0 khi SCL=1
  wire w_stop     = (sda_q == 1'b0) && (io_i2c_sda == 1'b1) && w_scl_high; // SDA: 0->1 khi SCL=1

  // Dem canh len SCL trong mot giao dich
  integer bit_count = 0;
  reg in_xfer = 1'b0;

  // Con tro bit khi xuat data doc (16 bit)
  integer rd_bit_idx = 15; // MSB->LSB

  // Trang thai nho de phan biet giai doan
  //  - 3 byte dau: [addrW], [reg], [addrR]  -> ACK tai 9,18,27
  //  - tiep: 16 bit data doc
  always @(posedge i_sys_clk) begin
    if (i_rst) begin
      in_xfer     <= 1'b0;
      bit_count   <= 0;
      sda_drv_en  <= 1'b0;
      rd_bit_idx  <= 15;
    end else begin
      // START: reset dem
      if (w_start) begin
        in_xfer    <= 1'b1;
        bit_count  <= 0;
        sda_drv_en <= 1'b0;
        rd_bit_idx <= 15;
      end

      // STOP: ket thuc giao dich
      if (w_stop) begin
        in_xfer    <= 1'b0;
        bit_count  <= 0;
        sda_drv_en <= 1'b0;
        rd_bit_idx <= 15;
      end

      // Heuristic I2C timing:
      // - ACK phai keo SDA=0 khi SCL dang HIGH o chu ky thu 9, 18, 27
      // - Data out: set SDA trong pha SCL=LOW truoc canh len
      // Dem canh len SCL khi dang trong giao dich
      if (in_xfer && (o_i2c_scl === 1'b1) && (scl_q === 1'b0)) begin
        bit_count <= bit_count + 1;
        // Sau canh len SCL, nha SDA neu vua ACK
        // (de tranh giu 0 qua lau)
        if (bit_count == 9 || bit_count == 18 || bit_count == 27) begin
          // vua di qua canh len cua bit ACK -> nha Z sau HIGH time
          // cho den luc SCL xuong thi nha ve Z (se lam o canh xuong)
        end
      end

      // Tai canh xuong SCL, thay doi SDA cho bit tiep theo
      if (in_xfer && (o_i2c_scl === 1'b0) && (scl_q === 1'b1)) begin
        // Mac dinh nha Z
        sda_drv_en <= 1'b0;

        // ACK o bit 9,18,27
        if (bit_count == 8 || bit_count == 17 || bit_count == 26) begin
          // Vao pha ACK (bit thu 9,18,27) -> keo 0
          sda_drv_en <= 1'b1;
        end
        // Sau 27 canh len (3 byte), bat dau xuat 16 bit data
        else if (bit_count >= 27 && bit_count < 27 + 16) begin
          // Xuat data MSB->LSB
          if (TEMP_WORD[rd_bit_idx] == 1'b0) begin
            sda_drv_en <= 1'b1; // keo 0 de gui '0'
          end else begin
            sda_drv_en <= 1'b0; // nha Z de gui '1' (pull-up)
          end
          if (rd_bit_idx > 0) rd_bit_idx <= rd_bit_idx - 1;
        end
        else begin
          // ngoai cac cua so ACK + data -> nha Z
          sda_drv_en <= 1'b0;
        end
      end
    end
  end

  // =======================
  // Quan sat & ket thuc
  // =======================
  initial begin
    // Chay trong mot thoi gian du dai de hoan tat 1-2 chu ky doc nhiet do
    // (SCL=250 kHz => 4 us/bit; 40-60 bit ~ 160-240 us; cong chuyen trang thai -> ~10 ms OK)
    #(20_000_000); // 20 ms
    $display("Simulation finished.");
    $finish;
  end

  // In thong tin debug ve 7-seg (khong bat buoc)
  always @(posedge i_sys_clk) begin
    if (!i_rst) begin
      // hien ra gia tri seg + sel de tham khao
      // $display("%t o_sel=%b o_seg=%b", $time, o_sel, o_seg);
    end
  end

endmodule
