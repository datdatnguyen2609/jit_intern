module bin_to_bcd(
    input  wire        I_clk,
    input  wire        I_rst,
    input  wire [14:0] I_data,
    output reg  [3:0]  O_bit0,  // LSD
    output reg  [3:0]  O_bit1,
    output reg  [3:0]  O_bit2,
    output reg  [3:0]  O_bit3,
    output reg  [3:0]  O_bit4,  // MSD
    output reg  [19:0] O_BCD    // {O_bit4,O_bit3,O_bit2,O_bit1,O_bit0}
  );
  integer i;
  reg [34:0] R_shift;  // {BCD[19:0], BIN[14:0]}

  always @(posedge I_clk)
  begin
    if (I_rst)
    begin
      O_bit0  <= 4'd0;
      O_bit1  <= 4'd0;
      O_bit2  <= 4'd0;
      O_bit3  <= 4'd0;
      O_bit4  <= 4'd0;
      O_BCD   <= 20'd0;
      R_shift <= 35'd0;
    end
    else
    begin
      // Khởi tạo: BCD = 0, BIN = I_data
      R_shift = {20'd0, I_data};

      // Double-Dabble: lặp 15 lần cho 15 bit nhị phân
      for (i = 0; i < 15; i = i + 1)
      begin
        // Cộng 3 cho từng nibble BCD nếu >= 5
        if (R_shift[34:31] >= 5)
          R_shift[34:31] = R_shift[34:31] + 4'd3; // digit 4 (MSD)
        if (R_shift[30:27] >= 5)
          R_shift[30:27] = R_shift[30:27] + 4'd3; // digit 3
        if (R_shift[26:23] >= 5)
          R_shift[26:23] = R_shift[26:23] + 4'd3; // digit 2
        if (R_shift[22:19] >= 5)
          R_shift[22:19] = R_shift[22:19] + 4'd3; // digit 1
        if (R_shift[18:15] >= 5)
          R_shift[18:15] = R_shift[18:15] + 4'd3; // digit 0 (LSD)

        // Dịch trái 1 bit (đưa dần các bit BIN vào vùng BCD)
        R_shift = R_shift << 1;
      end

      // Chốt kết quả ra cổng
      O_BCD  <= R_shift[34:15];  // toàn bộ 5 nibble BCD
      O_bit4 <= R_shift[34:31];  // MSD
      O_bit3 <= R_shift[30:27];
      O_bit2 <= R_shift[26:23];
      O_bit1 <= R_shift[22:19];
      O_bit0 <= R_shift[18:15];  // LSD
    end
  end
endmodule
