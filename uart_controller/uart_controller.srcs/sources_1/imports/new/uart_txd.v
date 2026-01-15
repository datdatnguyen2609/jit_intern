`timescale 1ns / 1ps

module uart_tx #(
    parameter CLKS_PER_BIT = 868
)(
    input  wire       clk,
    input  wire       rst,
    input  wire       tx_start,
    input  wire [7:0] tx_data,
    output reg        tx,
    output reg        tx_busy,
    output reg        tx_done
);
    localparam IDLE  = 3'd0;
    localparam START = 3'd1;
    localparam DATA  = 3'd2;
    localparam STOP  = 3'd3;
    localparam DONE  = 3'd4;

    reg [2:0]  state;
    reg [15:0] clk_cnt;
    reg [2:0]  bit_idx;
    reg [7:0]  tx_shift;

    always @(posedge clk) begin
        if (rst) begin
            state    <= IDLE;
            tx       <= 1'b1;
            tx_busy  <= 1'b0;
            tx_done  <= 1'b0;
            clk_cnt  <= 0;
            bit_idx  <= 0;
            tx_shift <= 0;
        end else begin
            tx_done <= 1'b0;

            case (state)
                IDLE:  begin
                    tx      <= 1'b1;
                    tx_busy <= 1'b0;
                    clk_cnt <= 0;
                    bit_idx <= 0;
                    if (tx_start) begin
                        tx_shift <= tx_data;
                        tx_busy  <= 1'b1;
                        state    <= START;
                    end
                end

                START: begin
                    tx <= 1'b0;  // Start bit
                    if (clk_cnt < CLKS_PER_BIT - 1) begin
                        clk_cnt <= clk_cnt + 1;
                    end else begin
                        clk_cnt <= 0;
                        state   <= DATA;
                    end
                end

                DATA:  begin
                    tx <= tx_shift[bit_idx];
                    if (clk_cnt < CLKS_PER_BIT - 1) begin
                        clk_cnt <= clk_cnt + 1;
                    end else begin
                        clk_cnt <= 0;
                        if (bit_idx < 7) bit_idx <= bit_idx + 1;
                        else             state <= STOP;
                    end
                end

                STOP: begin
                    tx <= 1'b1;  // Stop bit
                    if (clk_cnt < CLKS_PER_BIT - 1) begin
                        clk_cnt <= clk_cnt + 1;
                    end else begin
                        clk_cnt <= 0;
                        tx_done <= 1'b1;
                        tx_busy <= 1'b0;
                        state   <= DONE;
                    end
                end

                DONE: state <= IDLE;
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule