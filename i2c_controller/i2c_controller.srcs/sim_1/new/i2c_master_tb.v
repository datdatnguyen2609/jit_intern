`timescale 1ns/1ps

module i2c_master_tb;

  // -------- Clock 100 MHz & reset --------
  reg i_clk, i_rst_n;
  initial begin
    i_clk = 1'b0;
    forever #5 i_clk = ~i_clk; // 10ns -> 100 MHz
  end
  initial begin
    i_rst_n = 1'b0;
    repeat (10) @(posedge i_clk);
    i_rst_n = 1'b1;
  end

  // -------- DUT I/O --------
  reg        i_start;
  reg        i_op;           // 1 = read, 0 = write
  reg [7:0]  i_reg_addr;
  reg [15:0] i_wr_data;
  reg [7:0]  i_read_len;

  wire       o_busy, o_done, o_nack, o_rd_valid;
  wire [7:0] o_rd_byte;
  wire [15:0] o_rd_word;

  wire o_scl;              // SCL from DUT (push-pull)
  tri  sda_wire;           // SDA shared bus (open-drain)
  pullup(sda_wire);        // pull-up cho SDA

  // -------- DUT --------
  i2c_master #(
    .CLK_HZ(100_000_000),
    .SCL_HZ(400_000)
  ) dut (
    .i_clk      (i_clk),
    .i_rst_n    (i_rst_n),
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
    .o_scl      (o_scl)
  );

  // ============================================================
  //      SLAVE ADT7420 DON GIAN (ACK + tra ve 0x1A, 0xC0)
  // ============================================================
  localparam [7:0] ADDR_W = 8'h90, ADDR_R = 8'h91;
  localparam [7:0] MSB    = 8'h1A,  LSB   = 8'hC0;

  // Slave chi keo 0 hoac tha Z tren SDA
  reg slave_drive0;                 // 1 => keo SDA = 0; 0 => tha Z
  assign sda_wire = slave_drive0 ? 1'b0 : 1'bz;

  // Dong bo SCL/SDA de phat hien START
  reg sda_q, scl_q;
  always @(posedge i_clk) begin
    sda_q <= sda_wire;
    scl_q <= o_scl;
  end
  wire start_cond = (sda_q==1'b1 && sda_wire==1'b0 && o_scl==1'b1);

  // Dem canh len SCL; quan ly phase 0/1
  integer pos_cnt;
  reg phase;          // 0: phien 1 (ADDR_W+REG), 1: phien 2 (ADDR_R+READ)
  reg saw_start;      // da thay START lan dau

  always @(posedge i_clk) begin
    if (!i_rst_n) begin
      pos_cnt   <= 0;
      phase     <= 1'b0;
      saw_start <= 1'b0;
    end else if (start_cond) begin
      pos_cnt <= 0;
      if (!saw_start) begin
        saw_start <= 1'b1;  // START dau tien -> phase 0
        phase     <= 1'b0;
      end else begin
        phase     <= 1'b1;  // repeated START -> phase 1
      end
    end else if (o_scl==1'b1 && scl_q==1'b0) begin
      pos_cnt <= pos_cnt + 1;
    end
  end

  // Chi so bit (4-bit) de tranh X; khoi tao trong reset
  reg [3:0] idx_msb, idx_lsb;

  // Dap ung ACK va phat data bang 1 always
  // Phase 0 (write): ACK1 @8, tha @9; ACK2 @17, tha @18
  // Phase 1 (read):  ACK3 @8, tha @9
  //  MSB bits @10..17 (7..0), master ACK @18 (slave tha)
  //  LSB bits @19..26 (7..0), master NACK @27 (slave tha)
  always @(negedge o_scl or negedge i_rst_n) begin
    if (!i_rst_n) begin
      slave_drive0 <= 1'b0;
      idx_msb      <= 4'd7;
      idx_lsb      <= 4'd7;
    end else begin
      // mac dinh tha
      slave_drive0 <= 1'b0;

      if (phase==1'b0) begin
        // Phase 0: ADDR_W + REG_PTR
        if (pos_cnt==8)  slave_drive0 <= 1'b1;  // ACK1
        if (pos_cnt==9)  slave_drive0 <= 1'b0;  // tha
        if (pos_cnt==17) slave_drive0 <= 1'b1;  // ACK2
        if (pos_cnt==18) slave_drive0 <= 1'b0;  // tha
      end
      else begin
        // Phase 1: ADDR_R + READ
        if (pos_cnt==8)  slave_drive0 <= 1'b1;  // ACK3
        if (pos_cnt==9)  begin
          slave_drive0 <= 1'b0;                 // tha
          idx_msb      <= 4'd7;                 // chuan bi phat MSB
        end

        // Phat MSB bit 7..0 @10..17
        if (pos_cnt>=10 && pos_cnt<=17) begin
          slave_drive0 <= (MSB[idx_msb]==1'b0); // 0: keo, 1: tha
          idx_msb      <= idx_msb - 1'b1;
        end

        // Master ACK sau MSB
        if (pos_cnt==18) begin
          slave_drive0 <= 1'b0;
          idx_lsb      <= 4'd7;                 // chuan bi phat LSB
        end

        // Phat LSB bit 7..0 @19..26
        if (pos_cnt>=19 && pos_cnt<=26) begin
          slave_drive0 <= (LSB[idx_lsb]==1'b0);
          idx_lsb      <= idx_lsb - 1'b1;
        end

        // Sau do master NACK @27, slave tha
        if (pos_cnt>=27) begin
          slave_drive0 <= 1'b0;
        end
      end
    end
  end

  // -------- Stimulus: doc 2 byte tu reg 0x00 --------
  initial begin
    // $dumpfile("tb.vcd"); $dumpvars(0, i2c_master_tb);
    i_start    = 1'b0;
    i_op       = 1'b1;      // READ
    i_reg_addr = 8'h00;     // temperature MSB ptr
    i_wr_data  = 16'h0000;
    i_read_len = 8'd2;      // doc 2 byte

    @(posedge i_rst_n);
    repeat (20) @(posedge i_clk);

    @(posedge i_clk) i_start = 1'b1;
    @(posedge i_clk) i_start = 1'b0;

    wait (o_done==1'b1);
    $display("DONE: nack=%0d, last_byte=%02h, word=%04h", o_nack, o_rd_byte, o_rd_word);
    repeat (20) @(posedge i_clk);
    $finish;
  end

  // In ra tung byte doc duoc
  always @(posedge i_clk) if (o_rd_valid) $display("[%0t] RD_BYTE=0x%02h", $time, o_rd_byte);

endmodule
