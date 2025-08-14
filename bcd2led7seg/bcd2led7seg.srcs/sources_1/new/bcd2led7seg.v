module bcd2led7seg (
    input clk,
    input rst,
    input [15:0] sw,
    output [7:0] seg_out,
    output [4:0] anode,
    output [2:0] anode_off
  );
  // Signals
  wire [15:0] bout;
  wire [3:0] bcd0, bcd1, bcd2, bcd3, bcd4;
  wire [3:0] bin;
  wire [2:0] bcd_sel;  
  assign anode_off = 3'b111;
  // Generate debounce cho all sw
  genvar i;
  generate
    for (i = 0; i < 16; i = i + 1)
    begin : gen_debounce
      debounce #(
                 .CLK_FREQ(100_000_000),
                 .DEBOUNCE_TIME_MS(20)
               ) u_debounce (
                 .clk(clk),
                 .rst(rst),
                 .btn_in(sw[i]),
                 .btn_out(bout[i])
               );
    end
  endgenerate

  // Binary to BCD conversion 
  bin_to_bcd btb1(
               .data(bout[14:0]),  // Debounced input
               .bit0(bcd0),
               .bit1(bcd1),
               .bit2(bcd2),
               .bit3(bcd3),
               .bit4(bcd4)
             );

  // Seven segment controller 
  seven_seg_controller ssc1(
                         .clk(clk),
                         .rst(rst),
                         .rate_sel_2hz(bout[15]),  // selection refresh rate
                         .bcd0(bcd0),
                         .bcd1(bcd1),
                         .bcd2(bcd2),
                         .bcd3(bcd3),
                         .bcd4(bcd4),
                         .anode(anode),
                         .bcd_sel(bcd_sel), 
                         .bcd_out(bin)
                       );

  // Seven segment converter
  seven_seg_converter ssc2(
                        .value(bin),
                        .seg_out(seg_out)
                      );

endmodule
