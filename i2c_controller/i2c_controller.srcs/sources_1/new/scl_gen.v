`timescale 1ns/1ps

module scl_gen#(
    parameter integer CLK_FREQ = 100_000_000,
    parameter integer SCL_FREQ = 200_000
)(
    input  wire I_CLK,
    input  wire I_RST,
    input  wire I_EN,
    output reg  O_SCL
);

    localparam integer CNT_WIDTH   = $clog2(CLK_FREQ);
    localparam integer HALF_PERIOD = (CLK_FREQ / (2 * SCL_FREQ));

    reg [CNT_WIDTH-1:0] R_SCL_COUNTER;

    always @(posedge I_CLK) begin
        if (I_RST) begin
            R_SCL_COUNTER <= {CNT_WIDTH{1'b0}};
            O_SCL <= 1'b1;
        end else if (!I_EN) begin
            R_SCL_COUNTER <= {CNT_WIDTH{1'b0}};
            O_SCL <= 1'b1;
        end else if (R_SCL_COUNTER == (HALF_PERIOD-1)) begin
            R_SCL_COUNTER <= {CNT_WIDTH{1'b0}};
            O_SCL <= ~O_SCL;
        end else begin
            R_SCL_COUNTER <= R_SCL_COUNTER + 1'b1;
        end
    end
endmodule
