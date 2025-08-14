module bin_to_bcd(
    input  wire [14:0] data,
    output reg  [3:0]  bit0, bit1, bit2, bit3, bit4, // LSD -> MSD
    output reg  [19:0] BCD                            // {bit4,bit3,bit2,bit1,bit0}
);
    integer i;
    reg [34:0] shift_reg;  // {BCD[19:0], BIN[14:0]} - shift reg to shift BIN to BCD

    always @* begin
        // init with BCD = 0 and BIN = data
        shift_reg = {20'd0, data};

        // Repeat 15 times with each bit of the input
        for (i = 0; i < 15; i = i + 1) begin
            // Add-3 for each nibble if >= 5
            if (shift_reg[18:15] >= 5) shift_reg[18:15] = shift_reg[18:15] + 4'd3;
            if (shift_reg[22:19] >= 5) shift_reg[22:19] = shift_reg[22:19] + 4'd3;
            if (shift_reg[26:23] >= 5) shift_reg[26:23] = shift_reg[26:23] + 4'd3;
            if (shift_reg[30:27] >= 5) shift_reg[30:27] = shift_reg[30:27] + 4'd3;
            if (shift_reg[34:31] >= 5) shift_reg[34:31] = shift_reg[34:31] + 4'd3;

            // Shift left 1 bit for all the reg
            shift_reg = shift_reg << 1;
        end

        // Get the BCD output 
        BCD  = shift_reg[34:15];     // All the BCD reg
        bit0 = shift_reg[18:15];     // 10^0
        bit1 = shift_reg[22:19];     // 10^1
        bit2 = shift_reg[26:23];     // 10^2
        bit3 = shift_reg[30:27];     // 10^3
        bit4 = shift_reg[34:31];     // 10^4
    end
endmodule