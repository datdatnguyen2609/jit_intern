`timescale 1ns/1ps

module i2c_master_tb;

  // -------- Clock 100 MHz & reset --------
  reg clk, rst_n;
  initial begin
    clk = 1'b0;
    forever #5 clk = ~clk; // 10ns -> 100 MHz
  end
  initial begin
    rst_n = 1'b0;
    repeat (10) @(posedge clk);
    rst_n = 1'b1;
  end

  // -------- DUT I/O --------
  reg        i_start;
  reg        i_op;           // 1 = read
  reg [7:0]  i_reg_addr;
  reg [15:0] i_wr_data;
  reg [7:0]  i_read_len;

  wire       o_busy, o_done, o_nack, o_rd_valid;
  wire [7:0] o_rd_byte;
  wire [15:0] o_rd_word;

  wire scl;          // from DUT
  wire sda_wire;     // shared SDA
  pullup(sda_wire);  // pull-up cho SDA (mô ph?ng open-drain)

  // -------- DUT (??i tên module n?u b?n dùng tên khác) --------
  i2c_master #(
    .CLK_HZ(100_000_000),
    .SCL_HZ(400_000)
  ) dut (
    .clk        (clk),
    .rst_n      (rst_n),
    .i_start    (i_start),
    .i_op       (i_op),
    .i_reg_addr (i_reg_addr),
    .i_wr_data  (i_wr_data),
    .i_read_len (i_read_len),
    .o_busy     (o_busy),
    .o_done     (o_done),
    .o_nack     (o_nack),
    .o_rd_valid (o_rd_valid),
    .o_rd_byte  (o_rd_byte),
    .o_rd_word  (o_rd_word),
    .io_sda     (sda_wire),
    .o_scl      (scl)
  );

  // ============================================================
  //      SLAVE ADT7420 C?C G?N (ACK + tr? 0x1A, 0xC0)
  // ============================================================
  localparam [7:0] ADDR_W = 8'h90, ADDR_R = 8'h91;
  localparam [7:0] MSB    = 8'h1A,  LSB   = 8'hC0;

  reg slave_drive0;              // 1 => kéo SDA = 0; 0 => th? Z
  assign sda_wire = slave_drive0 ? 1'b0 : 1'bz;

  // phát hi?n START/STOP (??n gi?n)
  reg sda_q, scl_q;
  always @(posedge clk) begin
    sda_q <= sda_wire;
    scl_q <= scl;
  end
  wire start_cond = (sda_q==1'b1 && sda_wire==1'b0 && scl==1'b1);
  // wire stop_cond  = (sda_q==1'b0 && sda_wire==1'b1 && scl==1'b1);

  // ??m c?nh lên c?a SCL trong 1 phiên giao d?ch (reset khi START)
  integer pos_cnt;
  always @(posedge clk) begin
    if (!rst_n)                  pos_cnt <= 0;
    else if (start_cond)         pos_cnt <= 0;
    else if (scl==1'b1 && scl_q==1'b0) pos_cnt <= pos_cnt + 1;
  end

  // ACK ba l?n: sau 8 bit ADDR_W, sau 8 bit REG_PTR, sau 8 bit ADDR_R
  // Drive ACK tr??c c?nh lên th? 9/18/9 (t??ng ?ng) và nh? sau c?nh xu?ng k? ti?p
  always @(negedge scl or negedge rst_n) begin
    if (!rst_n) begin
      slave_drive0 <= 1'b0;
    end else begin
      // phiên th? nh?t (ADDR_W + REG_PTR): pos_cnt ??m t? START
      // ACK1 t?i bit 9
      if (pos_cnt==8)  slave_drive0 <= 1'b1; // chu?n b? ACK1
      else if (pos_cnt==9) slave_drive0 <= 1'b0;

      // ACK2 t?i bit 18
      if (pos_cnt==17) slave_drive0 <= 1'b1; // chu?n b? ACK2
      else if (pos_cnt==18) slave_drive0 <= 1'b0;
    end
  end

  // Repeated START s? ??a pos_cnt v? 0 (do start_cond)
  // Sau ADDR_R (8 bit), ACK3 t??ng t?:
  always @(negedge scl) begin
    if (pos_cnt==8)    slave_drive0 <= 1'b1; // chu?n b? ACK3 (sau repeated START)
    else if (pos_cnt==9) slave_drive0 <= 1'b0;
  end

  // G?i d? li?u: 8 bit MSB r?i 8 bit LSB
  // ??n gi?n: khi ?ã qua ADDR_R + ACK3, ta l?n l??t lái bit trên m?i pha SCL th?p.
  // C? th?: sau ACK3 (pos_cnt==9), 8 l?n ti?p theo là d? li?u MSB (pos_cnt 10..17),
  // r?i m?t bit ACK c?a master (pos_cnt==18, slave th?), sau ?ó 8 bit LSB (pos_cnt 19..26).
  reg [7:0] msb = MSB, lsb = LSB;
  integer bit_idx;

  // ??t bit khi SCL xu?ng th?p tr??c m?i l?n và master s? sample ? c?nh lên k? ti?p
  always @(negedge scl or negedge rst_n) begin
    if (!rst_n) begin
      bit_idx      <= 7;
      slave_drive0 <= 1'b0;
    end else begin
      // MSB: pos_cnt 10..17
      if (pos_cnt>=10 && pos_cnt<=17) begin
        slave_drive0 <= (msb[bit_idx]==1'b0); // 0 => kéo, 1 => th?
        bit_idx      <= bit_idx - 1;
      end
      // Sau MSB xong, th? ? ACK c?a master (pos_cnt==18)
      if (pos_cnt==18) begin
        slave_drive0 <= 1'b0; // th? ?? master ACK
        bit_idx      <= 7;    // reset cho LSB
      end
      // LSB: pos_cnt 19..26
      if (pos_cnt>=19 && pos_cnt<=26) begin
        slave_drive0 <= (lsb[bit_idx]==1'b0);
        bit_idx      <= bit_idx - 1;
      end
      // Master s? NACK sau LSB, slave th? ???ng dây
      if (pos_cnt>=27) begin
        slave_drive0 <= 1'b0;
      end
    end
  end

  // -------- Stimulus: ??c 2 byte t? reg 0x00 --------
  initial begin
    // $dumpfile("tb.vcd"); $dumpvars(0, i2c_master_basic_tb);
    i_start    = 1'b0;
    i_op       = 1'b1;      // READ
    i_reg_addr = 8'h00;     // temperature MSB ptr
    i_wr_data  = 16'h0000;
    i_read_len = 8'd2;      // read 2 bytes

    @(posedge rst_n);
    repeat (20) @(posedge clk);

    @(posedge clk) i_start = 1'b1;
    @(posedge clk) i_start = 1'b0;

    wait (o_done==1'b1);
    $display("DONE: nack=%0d, last_byte=%02h, word=%04h", o_nack, o_rd_byte, o_rd_word);
    repeat (20) @(posedge clk);
    $finish;
  end

  // In ra byte ??c ???c
  always @(posedge clk) if (o_rd_valid) $display("[%0t] RD_BYTE=0x%02h", $time, o_rd_byte);

endmodule
