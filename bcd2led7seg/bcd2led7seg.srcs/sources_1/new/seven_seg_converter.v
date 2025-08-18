module seven_seg_converter(
    input  wire       I_clk,
    input  wire       I_rst,
    input  wire [3:0] I_value,
    output reg  [7:0] O_seg_out
);
    // Active-low 7-seg (bit[7] thường là DP)
    always @(posedge I_clk) begin
        if (I_rst) begin
            O_seg_out <= ~8'b00000000; // off
        end else begin
            case (I_value)
                4'd0:  O_seg_out <= ~8'b00111111; // 0
                4'd1:  O_seg_out <= ~8'b00000110; // 1
                4'd2:  O_seg_out <= ~8'b01011011; // 2
                4'd3:  O_seg_out <= ~8'b01001111; // 3
                4'd4:  O_seg_out <= ~8'b01100110; // 4
                4'd5:  O_seg_out <= ~8'b01101101; // 5
                4'd6:  O_seg_out <= ~8'b01111101; // 6
                4'd7:  O_seg_out <= ~8'b00000111; // 7
                4'd8:  O_seg_out <= ~8'b01111111; // 8
                4'd9:  O_seg_out <= ~8'b01101111; // 9
                4'd10: O_seg_out <= ~8'b01110111; // A
                4'd11: O_seg_out <= ~8'b01111100; // b
                4'd12: O_seg_out <= ~8'b00111001; // C
                4'd13: O_seg_out <= ~8'b01011110; // d
                4'd14: O_seg_out <= ~8'b01111001; // E
                4'd15: O_seg_out <= ~8'b01110001; // F
                default: O_seg_out <= ~8'b00000000; // off
            endcase
        end
    end
endmodule
