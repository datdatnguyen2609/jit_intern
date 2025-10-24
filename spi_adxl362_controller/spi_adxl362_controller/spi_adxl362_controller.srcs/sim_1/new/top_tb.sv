`timescale 1ns/1ps

module top_tb;

  // ---------------------------------
  // DUT ports
  // ---------------------------------
  reg         top_i_clk;
  reg         top_i_rst;
  reg         top_i_ready;

  wire        top_o_csn;
  wire        top_o_sclk;
  wire        top_o_mosi;
  reg         top_i_miso;

  wire [7:0]  top_o_din;
  reg  [7:0]  top_i_sw;

  // ---------------------------------
  // Instantiate DUT
  // ---------------------------------
  top dut (
    .top_i_clk   (top_i_clk),
    .top_i_rst   (top_i_rst),
    .top_i_ready (top_i_ready),

    .top_o_csn   (top_o_csn),
    .top_o_sclk  (top_o_sclk),
    .top_o_mosi  (top_o_mosi),
    .top_i_miso  (top_i_miso),

    .top_o_din   (top_o_din),
    .top_i_sw    (top_i_sw)
  );

  // Giam thoi gian debounce xuong 1ms de mo phong nhanh
  // (giu nguyen CLK_FREQ=100MHz => COUNT_MAX = 100_000)
  defparam dut.u_db_rst.DEBOUNCE_TIME_MS   = 1;
  defparam dut.u_db_ready.DEBOUNCE_TIME_MS = 1;

  // ---------------------------------
  // Clock 100 MHz (period = 10 ns)
  // ---------------------------------
  initial top_i_clk = 1'b0;
  always  #5 top_i_clk = ~top_i_clk;

  // ---------------------------------
  // Simple SPI "slave" tao MISO = 8'hA5 trong pha READ
  // - Master lay mau MISO tai canh len SCLK (mode 0)
  // - Slave doi MISO o canh xuong de on truoc canh len
  // - Dem so canh len de xac dinh 8 bit READ (sau 1 byte INST + 1 byte ADDR)
  // ---------------------------------
  reg [7:0] MISO_BYTE = 8'hA5;
  integer   poscnt;

  // dem canh len SCLK khi CSN dang keo thap
  always @(posedge top_o_sclk or posedge top_o_csn) begin
    if (top_o_csn) poscnt <= 0;
    else           poscnt <= poscnt + 1;
  end

  // cap nhat MISO o canh xuong SCLK
  //  - Byte doc se bi master lay mau tai posedge #16..#23 (tinh tu luc CSN keo thap)
  //  - O negedge truoc posedge #k, poscnt dang = k-1 => dung next_pos = poscnt+1
  always @(negedge top_o_sclk or posedge top_o_csn) begin
    if (top_o_csn) begin
      top_i_miso <= 1'b0;
    end else begin
      integer next_pos;
      integer bit_index;
      next_pos  = poscnt + 1;
      // chi phat byte du lieu trong cua so posedge 16..23 (8 bit)
      if (next_pos >= 16 && next_pos <= 23) begin
        bit_index = 7 - (next_pos - 16); // MSB truoc
        top_i_miso <= MISO_BYTE[bit_index];
      end else begin
        top_i_miso <= 1'b0; // ngoai pha READ: de 0
      end
    end
  end

  // ---------------------------------
  // Stimulus
  // ---------------------------------
  initial begin
    // dump wave (neu dung iverilog/gtkwave). Bo qua neu dung ModelSim.
    $dumpfile("top_tb.vcd");
    $dumpvars(0, top_tb);

    // khoi tao
    top_i_rst   = 1'b0;
    top_i_ready = 1'b0;
    top_i_sw    = 8'h0E;   // vi du: doc XDATA_L = 0x0E

    // Bam RESET (giu > 1ms de qua debounce)
    #100_000;              // 0.1 ms
    top_i_rst = 1'b1;
    #2_000_000;            // 2.0 ms
    top_i_rst = 1'b0;

    // doi he thong on dinh 0.5ms
    #500_000;

    // Bam READY (giu > 1ms de qua debounce) -> tao giao dich READ
    top_i_ready = 1'b1;
    #2_000_000;            // 2.0 ms
    top_i_ready = 1'b0;

    // doi 2ms cho giao dich ket thuc
    #2_000_000;

    // Thu 1 giao dich nua, doc REG khac (vi du 0x0F)
    top_i_sw = 8'h0F;
    #300_000;
    top_i_ready = 1'b1;
    #2_000_000;
    top_i_ready = 1'b0;

    // doi 2ms va ket thuc
    #2_000_000;

    $finish;
  end

  // ---------------------------------
  // Monitor ket qua: in ra moi khi data thay doi va khi CSN keo len ket thuc
  // ---------------------------------
  reg [7:0] last_din;
  always @(top_o_din) begin
    if (top_o_csn == 1'b0) begin
      $display("[%0t ns] DIN change while CSN=0: 0x%02h", $time, top_o_din);
    end
    last_din = top_o_din;
  end

  // In ra khi ket thuc giao dich (CSN len 1)
  always @(posedge top_o_csn) begin
    $display("[%0t ns] CSN=1, DONE. Latch DIN = 0x%02h (SW=0x%02h)", $time, last_din, top_i_sw);
  end

endmodule
