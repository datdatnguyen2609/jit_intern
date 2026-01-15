`timescale 1ns / 1ps

module debounce #(
    parameter CLK_FREQ  = 100_000_000,
    parameter STABLE_MS = 20
)(
    input  wire clk,
    input  wire rst,
    input  wire in,
    output reg  out
);
    localparam CNT_MAX = (CLK_FREQ / 1000) * STABLE_MS;
    localparam CNT_W   = $clog2(CNT_MAX + 1);

    reg [CNT_W-1:0] cnt;
    reg             in_sync;

    always @(posedge clk) begin
        if (rst) begin
            cnt     <= 0;
            in_sync <= 0;
            out     <= 0;
        end else begin
            if (in != in_sync) begin
                in_sync <= in;
                cnt     <= 0;
            end else if (cnt < CNT_MAX) begin
                cnt <= cnt + 1;
            end else begin
                out <= in_sync;
            end
        end
    end
endmodule