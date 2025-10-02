`timescale 1ns/1ps

module seg7_display(
  input  wire        i_clk,        // clock he thong
  input  wire        i_rst,        // reset dong bo active high
  input  wire signed [15:0] i_val, // gia tri da nhan 100

  output reg  [3:0]  o_an,   // anode 4 led (active low)
  output reg  [6:0]  o_seg,  // 7 thanh a..g (active low)
  output reg         o_dp    // dau cham thap phan (active low)
);

  // --------- bo chia clock de quet ---------
  reg [15:0] cnt = 0;
  reg [1:0]  digit_sel = 0;
  always @(posedge i_clk) begin
    if (i_rst) begin
      cnt <= 0;
      digit_sel <= 0;
    end else begin
      cnt <= cnt + 1;
      if (cnt == 5000) begin // doi 5000 tick roi doi digit
        cnt <= 0;
        digit_sel <= digit_sel + 1;
      end
    end
  end

  // --------- gioi han gia tri ---------
  reg signed [15:0] val;
  always @* begin
    if (i_val > 9999) val = 9999;
    else if (i_val < -9999) val = -9999;
    else val = i_val;
  end

  wire is_neg = val < 0;
  wire [15:0] abs_val = is_neg ? -val : val;

  // --------- tach thanh 4 chu so ---------
  wire [3:0] d3 = (abs_val/1000) % 10; // hang nghin
  wire [3:0] d2 = (abs_val/100 ) % 10; // hang tram
  wire [3:0] d1 = (abs_val/10  ) % 10; // hang chuc
  wire [3:0] d0 =  abs_val       % 10; // hang don vi

  // --------- ham ma hoa 7 doan ---------
  function [6:0] seg7_encode;
    input [3:0] bcd;
    begin
      case (bcd)
        4'd0: seg7_encode = 7'b1000000;
        4'd1: seg7_encode = 7'b1111001;
        4'd2: seg7_encode = 7'b0100100;
        4'd3: seg7_encode = 7'b0110000;
        4'd4: seg7_encode = 7'b0011001;
        4'd5: seg7_encode = 7'b0010010;
        4'd6: seg7_encode = 7'b0000010;
        4'd7: seg7_encode = 7'b1111000;
        4'd8: seg7_encode = 7'b0000000;
        4'd9: seg7_encode = 7'b0010000;
        default: seg7_encode = 7'b0111111; // dau -
      endcase
    end
  endfunction

  // --------- cap nhat output dong bo voi clk ---------
  always @(posedge i_clk) begin
    if (i_rst) begin
      o_an  <= 4'b1111;
      o_seg <= 7'b1111111;
      o_dp  <= 1'b1;
    end else if (cnt == 0) begin
      case (digit_sel)
        2'd0: begin
          o_an  <= 4'b1110;
          o_seg <= seg7_encode(d0);
          o_dp  <= 1'b1;
        end
        2'd1: begin
          o_an  <= 4'b1101;
          o_seg <= seg7_encode(d1);
          o_dp  <= 1'b0; // bat dau cham o day -> XX.XX
        end
        2'd2: begin
          o_an  <= 4'b1011;
          o_seg <= seg7_encode(d2);
          o_dp  <= 1'b1;
        end
        2'd3: begin
          o_an  <= 4'b0111;
          if (is_neg && d3==0)
            o_seg <= seg7_encode(4'd15); // hien dau -
          else
            o_seg <= seg7_encode(d3);
          o_dp  <= 1'b1;
        end
      endcase
    end
  end

endmodule
