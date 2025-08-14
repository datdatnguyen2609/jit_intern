module seven_seg_converter(
    input [3:0] value,
    output reg [7:0] seg_out
);
    always @(*) begin
        case (value)
            4'd0:  seg_out = ~8'b00111111; // 0
            4'd1:  seg_out = ~8'b00000110; // 1
            4'd2:  seg_out = ~8'b01011011; // 2
            4'd3:  seg_out = ~8'b01001111; // 3
            4'd4:  seg_out = ~8'b01100110; // 4
            4'd5:  seg_out = ~8'b01101101; // 5
            4'd6:  seg_out = ~8'b01111101; // 6
            4'd7:  seg_out = ~8'b00000111; // 7
            4'd8:  seg_out = ~8'b01111111; // 8
            4'd9:  seg_out = ~8'b01101111; // 9
            4'd10: seg_out = ~8'b01110111; // A (10)
            4'd11: seg_out = ~8'b01111100; // B (11)
            4'd12: seg_out = ~8'b00111001; // C (12)
            4'd13: seg_out = ~8'b01011110; // D (13)
            4'd14: seg_out = ~8'b01111001; // E (14)
            4'd15: seg_out = ~8'b01110001; // F (15)
            default: seg_out = ~8'b00000000; // off
        endcase
    end
endmodule