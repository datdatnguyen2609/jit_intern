module i2c_master (
    input I_CLK,
    input I_RST,
    inout IO_SDA,
    output [7:0] O_temp_data,
    output O_SCL
);
    reg [3:0] R_counter = 4'b0;
    reg R_CLK = 1'b1;

    always @(posedge I_CLK) begin
        if (I_RST) begin
            R_counter <= 4'b0;
            R_CLK <= 1'b0;
        end
    end
    else
        
    
endmodule

