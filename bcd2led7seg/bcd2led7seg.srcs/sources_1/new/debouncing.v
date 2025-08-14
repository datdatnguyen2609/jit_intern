module debounce #(
    parameter CLK_FREQ = 100_000_000,
    parameter DEBOUNCE_TIME_MS = 20
)(
    input wire clk,
    input wire rst,
    input wire btn_in,
    output reg btn_out
);

    localparam integer COUNT_MAX = (CLK_FREQ / 1000) * DEBOUNCE_TIME_MS;
    localparam integer COUNTER_WIDTH = $clog2(COUNT_MAX);

    reg [COUNTER_WIDTH:0] counter = 0;
    reg btn_sync_0 = 0, btn_sync_1 = 0;
    reg btn_state = 0;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            btn_sync_0 <= 0;
            btn_sync_1 <= 0;
        end else begin
            btn_sync_0 <= btn_in;
            btn_sync_1 <= btn_sync_0;
        end
    end

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            counter <= 0;
            btn_state <= 0;
            btn_out <= 0;
        end else if (btn_sync_1 != btn_state) begin
            counter <= counter + 1;
            if (counter >= COUNT_MAX) begin
                btn_state <= btn_sync_1;
                btn_out <= btn_sync_1;
                counter <= 0;
            end
        end else begin
            counter <= 0; 
        end
    end

endmodule