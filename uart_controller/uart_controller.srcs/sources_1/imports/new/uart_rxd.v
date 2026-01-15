`timescale 1ns / 1ps

module uart_rx #(
    parameter CLKS_PER_BIT = 868
)(
    input  wire       clk,
    input  wire       rst,
    input  wire       rx,
    output reg        rx_valid,
    output reg  [7:0] rx_data
);
    localparam IDLE  = 3'd0;
    localparam START = 3'd1;
    localparam DATA  = 3'd2;
    localparam STOP  = 3'd3;
    localparam DONE  = 3'd4;

    reg [2:0]  state;
    reg [15:0] clk_cnt;
    reg [2:0]  bit_idx;
    reg [7:0]  rx_shift;
    reg        rx_sync1, rx_sync2;

    // Double-flop synchronizer
    always @(posedge clk) begin
        if (rst) begin
            rx_sync1 <= 1'b1;
            rx_sync2 <= 1'b1;
        end else begin
            rx_sync1 <= rx;
            rx_sync2 <= rx_sync1;
        end
    end

    always @(posedge clk) begin
        if (rst) begin
            state    <= IDLE;
            clk_cnt  <= 0;
            bit_idx  <= 0;
            rx_shift <= 0;
            rx_valid <= 0;
            rx_data  <= 0;
        end else begin
            rx_valid <= 0;

            case (state)
                IDLE:  begin
                    clk_cnt <= 0;
                    bit_idx <= 0;
                    if (rx_sync2 == 1'b0) state <= START;
                end

                START:  begin
                    if (clk_cnt < (CLKS_PER_BIT - 1) / 2) begin
                        clk_cnt <= clk_cnt + 1;
                    end else begin
                        clk_cnt <= 0;
                        state   <= (rx_sync2 == 1'b0) ? DATA : IDLE;
                    end
                end

                DATA:  begin
                    if (clk_cnt < CLKS_PER_BIT - 1) begin
                        clk_cnt <= clk_cnt + 1;
                    end else begin
                        clk_cnt <= 0;
                        rx_shift[bit_idx] <= rx_sync2;
                        if (bit_idx < 7) bit_idx <= bit_idx + 1;
                        else             state <= STOP;
                    end
                end

                STOP: begin
                    if (clk_cnt < CLKS_PER_BIT - 1) begin
                        clk_cnt <= clk_cnt + 1;
                    end else begin
                        clk_cnt  <= 0;
                        rx_valid <= 1'b1;
                        rx_data  <= rx_shift;
                        state    <= DONE;
                    end
                end

                DONE: state <= IDLE;
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule