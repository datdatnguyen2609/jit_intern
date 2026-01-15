`timescale 1ns / 1ps

module edge_detect (
    input  wire clk,
    input  wire rst,
    input  wire in,
    output wire rise,
    output wire fall
);
    reg in_d;
    
    always @(posedge clk) begin
        if (rst) in_d <= 0;
        else     in_d <= in;
    end
    
    assign rise = in & ~in_d;
    assign fall = ~in & in_d;
endmodule