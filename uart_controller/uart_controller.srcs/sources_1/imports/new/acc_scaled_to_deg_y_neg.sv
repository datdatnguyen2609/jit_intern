module acc_scaled_to_deg_y_neg (
    input  wire [10:0] ACC_IN,  // gia tri ACC 11 bit
    output reg  [6:0]  DEG      // goc 0..90
);

always @* begin
    case (1'b1)

        (ACC_IN <= 11'd16 )   : DEG = 7'd0;
        (ACC_IN <= 11'd32 )   : DEG = 7'd1;
        (ACC_IN <= 11'd48 )   : DEG = 7'd2;
        (ACC_IN <= 11'd63 )   : DEG = 7'd3;
        (ACC_IN <= 11'd79 )   : DEG = 7'd4;
        (ACC_IN <= 11'd95 )   : DEG = 7'd5;
        (ACC_IN <= 11'd111 )  : DEG = 7'd6;
        (ACC_IN <= 11'd127 )  : DEG = 7'd7;
        (ACC_IN <= 11'd142 )  : DEG = 7'd8;
        (ACC_IN <= 11'd158 )  : DEG = 7'd9;

        (ACC_IN <= 11'd174 )  : DEG = 7'd10;
        (ACC_IN <= 11'd189 )  : DEG = 7'd11;
        (ACC_IN <= 11'd205 )  : DEG = 7'd12;
        (ACC_IN <= 11'd220 )  : DEG = 7'd13;
        (ACC_IN <= 11'd236 )  : DEG = 7'd14;
        (ACC_IN <= 11'd251 )  : DEG = 7'd15;
        (ACC_IN <= 11'd266 )  : DEG = 7'd16;
        (ACC_IN <= 11'd281 )  : DEG = 7'd17;
        (ACC_IN <= 11'd296 )  : DEG = 7'd18;
        (ACC_IN <= 11'd311 )  : DEG = 7'd19;

        (ACC_IN <= 11'd326 )  : DEG = 7'd20;
        (ACC_IN <= 11'd341 )  : DEG = 7'd21;
        (ACC_IN <= 11'd356 )  : DEG = 7'd22;
        (ACC_IN <= 11'd370 )  : DEG = 7'd23;
        (ACC_IN <= 11'd385 )  : DEG = 7'd24;
        (ACC_IN <= 11'd399 )  : DEG = 7'd25;
        (ACC_IN <= 11'd413 )  : DEG = 7'd26;
        (ACC_IN <= 11'd427 )  : DEG = 7'd27;
        (ACC_IN <= 11'd441 )  : DEG = 7'd28;
        (ACC_IN <= 11'd455 )  : DEG = 7'd29;

        (ACC_IN <= 11'd469 )  : DEG = 7'd30;
        (ACC_IN <= 11'd482 )  : DEG = 7'd31;
        (ACC_IN <= 11'd496 )  : DEG = 7'd32;
        (ACC_IN <= 11'd509 )  : DEG = 7'd33;
        (ACC_IN <= 11'd522 )  : DEG = 7'd34;
        (ACC_IN <= 11'd535 )  : DEG = 7'd35;
        (ACC_IN <= 11'd548 )  : DEG = 7'd36;
        (ACC_IN <= 11'd560 )  : DEG = 7'd37;
        (ACC_IN <= 11'd573 )  : DEG = 7'd38;
        (ACC_IN <= 11'd585 )  : DEG = 7'd39;

        (ACC_IN <= 11'd597 )  : DEG = 7'd40;
        (ACC_IN <= 11'd609 )  : DEG = 7'd41;
        (ACC_IN <= 11'd621 )  : DEG = 7'd42;
        (ACC_IN <= 11'd632 )  : DEG = 7'd43;
        (ACC_IN <= 11'd643 )  : DEG = 7'd44;
        (ACC_IN <= 11'd655 )  : DEG = 7'd45;
        (ACC_IN <= 11'd666 )  : DEG = 7'd46;
        (ACC_IN <= 11'd676 )  : DEG = 7'd47;
        (ACC_IN <= 11'd687 )  : DEG = 7'd48;
        (ACC_IN <= 11'd697 )  : DEG = 7'd49;

        (ACC_IN <= 11'd707 )  : DEG = 7'd50;
        (ACC_IN <= 11'd717 )  : DEG = 7'd51;
        (ACC_IN <= 11'd727 )  : DEG = 7'd52;
        (ACC_IN <= 11'd736 )  : DEG = 7'd53;
        (ACC_IN <= 11'd745 )  : DEG = 7'd54;
        (ACC_IN <= 11'd754 )  : DEG = 7'd55;
        (ACC_IN <= 11'd763 )  : DEG = 7'd56;
        (ACC_IN <= 11'd772 )  : DEG = 7'd57;
        (ACC_IN <= 11'd780 )  : DEG = 7'd58;
        (ACC_IN <= 11'd788 )  : DEG = 7'd59;

        (ACC_IN <= 11'd796 )  : DEG = 7'd60;
        (ACC_IN <= 11'd803 )  : DEG = 7'd61;
        (ACC_IN <= 11'd811 )  : DEG = 7'd62;
        (ACC_IN <= 11'd818 )  : DEG = 7'd63;
        (ACC_IN <= 11'd825 )  : DEG = 7'd64;
        (ACC_IN <= 11'd831 )  : DEG = 7'd65;
        (ACC_IN <= 11'd838 )  : DEG = 7'd66;
        (ACC_IN <= 11'd844 )  : DEG = 7'd67;
        (ACC_IN <= 11'd850 )  : DEG = 7'd68;
        (ACC_IN <= 11'd855 )  : DEG = 7'd69;

        (ACC_IN <= 11'd860 )  : DEG = 7'd70;
        (ACC_IN <= 11'd865 )  : DEG = 7'd71;
        (ACC_IN <= 11'd870 )  : DEG = 7'd72;
        (ACC_IN <= 11'd875 )  : DEG = 7'd73;
        (ACC_IN <= 11'd879 )  : DEG = 7'd74;
        (ACC_IN <= 11'd883 )  : DEG = 7'd75;
        (ACC_IN <= 11'd887 )  : DEG = 7'd76;
        (ACC_IN <= 11'd890 )  : DEG = 7'd77;
        (ACC_IN <= 11'd893 )  : DEG = 7'd78;
        (ACC_IN <= 11'd896 )  : DEG = 7'd79;

        (ACC_IN <= 11'd899 )  : DEG = 7'd80;
        (ACC_IN <= 11'd901 )  : DEG = 7'd81;
        (ACC_IN <= 11'd903 )  : DEG = 7'd82;
        (ACC_IN <= 11'd905 )  : DEG = 7'd83;
        (ACC_IN <= 11'd907 )  : DEG = 7'd84;
        (ACC_IN <= 11'd908 )  : DEG = 7'd85;
        (ACC_IN <= 11'd909 )  : DEG = 7'd86;
        (ACC_IN <= 11'd909 )  : DEG = 7'd87;  // Note: same value for 87 and 88
        (ACC_IN <= 11'd910 )  : DEG = 7'd88;
        (ACC_IN <= 11'd910 )  : DEG = 7'd89;  // Note: same value for 89 and 90

        default               : DEG = 7'd90;

    endcase
end

endmodule
