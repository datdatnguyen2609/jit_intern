module acc_scaled_to_deg_x_neg (
    input  wire [10:0] ACC_IN,  // gia tri ACC 11 bit
    output reg  [6:0]  DEG      // goc 0..90
);

always @* begin
    case (1'b1)

        (ACC_IN <= 11'd18 )   : DEG = 7'd0;
        (ACC_IN <= 11'd37 )   : DEG = 7'd1;
        (ACC_IN <= 11'd55 )   : DEG = 7'd2;
        (ACC_IN <= 11'd74 )   : DEG = 7'd3;
        (ACC_IN <= 11'd92 )   : DEG = 7'd4;
        (ACC_IN <= 11'd111 )  : DEG = 7'd5;
        (ACC_IN <= 11'd129 )  : DEG = 7'd6;
        (ACC_IN <= 11'd147 )  : DEG = 7'd7;
        (ACC_IN <= 11'd166 )  : DEG = 7'd8;
        (ACC_IN <= 11'd184 )  : DEG = 7'd9;

        (ACC_IN <= 11'd202 )  : DEG = 7'd10;
        (ACC_IN <= 11'd220 )  : DEG = 7'd11;
        (ACC_IN <= 11'd238 )  : DEG = 7'd12;
        (ACC_IN <= 11'd256 )  : DEG = 7'd13;
        (ACC_IN <= 11'd274 )  : DEG = 7'd14;
        (ACC_IN <= 11'd292 )  : DEG = 7'd15;
        (ACC_IN <= 11'd310 )  : DEG = 7'd16;
        (ACC_IN <= 11'd327 )  : DEG = 7'd17;
        (ACC_IN <= 11'd345 )  : DEG = 7'd18;
        (ACC_IN <= 11'd362 )  : DEG = 7'd19;

        (ACC_IN <= 11'd380 )  : DEG = 7'd20;
        (ACC_IN <= 11'd397 )  : DEG = 7'd21;
        (ACC_IN <= 11'd414 )  : DEG = 7'd22;
        (ACC_IN <= 11'd431 )  : DEG = 7'd23;
        (ACC_IN <= 11'd448 )  : DEG = 7'd24;
        (ACC_IN <= 11'd464 )  : DEG = 7'd25;
        (ACC_IN <= 11'd481 )  : DEG = 7'd26;
        (ACC_IN <= 11'd497 )  : DEG = 7'd27;
        (ACC_IN <= 11'd513 )  : DEG = 7'd28;
        (ACC_IN <= 11'd530 )  : DEG = 7'd29;

        (ACC_IN <= 11'd545 )  : DEG = 7'd30;
        (ACC_IN <= 11'd561 )  : DEG = 7'd31;
        (ACC_IN <= 11'd577 )  : DEG = 7'd32;
        (ACC_IN <= 11'd592 )  : DEG = 7'd33;
        (ACC_IN <= 11'd607 )  : DEG = 7'd34;
        (ACC_IN <= 11'd622 )  : DEG = 7'd35;
        (ACC_IN <= 11'd637 )  : DEG = 7'd36;
        (ACC_IN <= 11'd652 )  : DEG = 7'd37;
        (ACC_IN <= 11'd666 )  : DEG = 7'd38;
        (ACC_IN <= 11'd681 )  : DEG = 7'd39;

        (ACC_IN <= 11'd695 )  : DEG = 7'd40;
        (ACC_IN <= 11'd709 )  : DEG = 7'd41;
        (ACC_IN <= 11'd722 )  : DEG = 7'd42;
        (ACC_IN <= 11'd736 )  : DEG = 7'd43;
        (ACC_IN <= 11'd749 )  : DEG = 7'd44;
        (ACC_IN <= 11'd762 )  : DEG = 7'd45;
        (ACC_IN <= 11'd775 )  : DEG = 7'd46;
        (ACC_IN <= 11'd787 )  : DEG = 7'd47;
        (ACC_IN <= 11'd799 )  : DEG = 7'd48;
        (ACC_IN <= 11'd811 )  : DEG = 7'd49;

        (ACC_IN <= 11'd823 )  : DEG = 7'd50;
        (ACC_IN <= 11'd835 )  : DEG = 7'd51;
        (ACC_IN <= 11'd846 )  : DEG = 7'd52;
        (ACC_IN <= 11'd857 )  : DEG = 7'd53;
        (ACC_IN <= 11'd867 )  : DEG = 7'd54;
        (ACC_IN <= 11'd878 )  : DEG = 7'd55;
        (ACC_IN <= 11'd888 )  : DEG = 7'd56;
        (ACC_IN <= 11'd898 )  : DEG = 7'd57;
        (ACC_IN <= 11'd908 )  : DEG = 7'd58;
        (ACC_IN <= 11'd917 )  : DEG = 7'd59;

        (ACC_IN <= 11'd926 )  : DEG = 7'd60;
        (ACC_IN <= 11'd935 )  : DEG = 7'd61;
        (ACC_IN <= 11'd944 )  : DEG = 7'd62;
        (ACC_IN <= 11'd952 )  : DEG = 7'd63;
        (ACC_IN <= 11'd960 )  : DEG = 7'd64;
        (ACC_IN <= 11'd967 )  : DEG = 7'd65;
        (ACC_IN <= 11'd975 )  : DEG = 7'd66;
        (ACC_IN <= 11'd982 )  : DEG = 7'd67;
        (ACC_IN <= 11'd989 )  : DEG = 7'd68;
        (ACC_IN <= 11'd995 )  : DEG = 7'd69;

        (ACC_IN <= 11'd1001)  : DEG = 7'd70;
        (ACC_IN <= 11'd1007)  : DEG = 7'd71;
        (ACC_IN <= 11'd1013)  : DEG = 7'd72;
        (ACC_IN <= 11'd1018)  : DEG = 7'd73;
        (ACC_IN <= 11'd1023)  : DEG = 7'd74;
        (ACC_IN <= 11'd1028)  : DEG = 7'd75;
        (ACC_IN <= 11'd1032)  : DEG = 7'd76;
        (ACC_IN <= 11'd1036)  : DEG = 7'd77;
        (ACC_IN <= 11'd1040)  : DEG = 7'd78;
        (ACC_IN <= 11'd1043)  : DEG = 7'd79;

        (ACC_IN <= 11'd1046)  : DEG = 7'd80;
        (ACC_IN <= 11'd1049)  : DEG = 7'd81;
        (ACC_IN <= 11'd1051)  : DEG = 7'd82;
        (ACC_IN <= 11'd1053)  : DEG = 7'd83;
        (ACC_IN <= 11'd1055)  : DEG = 7'd84;
        (ACC_IN <= 11'd1056)  : DEG = 7'd85;
        (ACC_IN <= 11'd1058)  : DEG = 7'd86;
        (ACC_IN <= 11'd1058)  : DEG = 7'd87;  // Note: same value for 87 and 88
        (ACC_IN <= 11'd1059)  : DEG = 7'd88;
        (ACC_IN <= 11'd1059)  : DEG = 7'd89;  // Note: same value for 89 and 90

        default               : DEG = 7'd90;

    endcase
end

endmodule