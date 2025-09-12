`timescale 1ns/1ps

module scl_gen#(
    parameter integer CLK_FREQ = 100_000_000,
    parameter integer SCL_FREQ = 200_000
  )(
    input  wire i_CLK,
    input  wire i_RST,
    input  wire i_EN,
    output reg  o_SCL
  );

  localparam integer CNT_WIDTH   = $clog2(CLK_FREQ);
  localparam integer HALF_PERIOD = (CLK_FREQ / (2 * SCL_FREQ));

  reg [CNT_WIDTH-1:0] r_SCL_COUNTER;

  always @(posedge i_CLK)
  begin
    if (i_RST)
    begin
      r_SCL_COUNTER <= {CNT_WIDTH{1'b0}};
      o_SCL <= 1'b1;
    end
    else if (!I_EN)
    begin
      r_SCL_COUNTER <= {CNT_WIDTH{1'b0}};
      o_SCL <= 1'b1;
    end
    else if (r_SCL_COUNTER == (HALF_PERIOD-1))
    begin
      r_SCL_COUNTER <= {CNT_WIDTH{1'b0}};
      o_SCL <= ~o_SCL;
    end
    else
    begin
      r_SCL_COUNTER <= r_SCL_COUNTER + 1'b1;
    end
  end
endmodule
