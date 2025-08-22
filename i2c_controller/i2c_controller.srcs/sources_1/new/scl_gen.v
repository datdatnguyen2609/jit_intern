`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 08/22/2025 01:27:21 PM
// Design Name: 
// Module Name: scl_gen
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


module scl_gen#(
    parameter integer CLK_FREQ = 100_000_000,
    parameter integer SCL_FREQ = 100_000
)(
    input wire I_CLK,
    input wire I_RST,
    output reg O_SCL
    );
    localparam integer CNT_WIDTH  = $clog2(CLK_FREQ) ;
    localparam integer HALF_PERIOD = (CLK_FREQ / (2 * SCL_FREQ));
    reg [CNT_WIDTH - 1 : 0] R_SCL_COUNTER ;
    always @(posedge I_CLK) begin
        if(I_RST) begin
            R_SCL_COUNTER <= {CNT_WIDTH{1'd0}};
            O_SCL <= 1'd1;
        end else if (R_SCL_COUNTER == (HALF_PERIOD - 1)) begin
            R_SCL_COUNTER <= {CNT_WIDTH{1'd0}};
            O_SCL <= ~O_SCL;
        end else begin
            R_SCL_COUNTER <= R_SCL_COUNTER + 1;
        end
    end
endmodule
