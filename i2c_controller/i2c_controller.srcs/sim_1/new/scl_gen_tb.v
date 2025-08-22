`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 08/22/2025 02:19:41 PM
// Design Name: 
// Module Name: scl_gen_tb
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module scl_gen_tb;
    localparam TB_CLK_FREQ = 100_000_000;
    localparam TB_SCL_FREQ = 100_000;
    localparam TB_CLK_PERIOD_NS = 1e9 / TB_CLK_FREQ;
    reg TB_I_CLK;
    reg TB_I_RST;
    wire TB_O_SCL;

    scl_gen #(
        .CLK_FREQ(TB_CLK_FREQ),
        .SCL_FREQ(TB_SCL_FREQ)
    ) dut (
        .I_CLK(TB_I_CLK),
        .I_RST(TB_I_RST),
        .O_SCL(TB_O_SCL)
    );

    initial TB_I_CLK = 1'b1;
    always #(TB_CLK_PERIOD_NS/2.0) TB_I_CLK = ~TB_I_CLK;
      initial begin
    TB_I_RST = 1'b1;

    repeat (5) @(posedge TB_I_CLK);
    TB_I_RST = 1'b0;

    #(2_000_000);
    $finish;
  end
endmodule
