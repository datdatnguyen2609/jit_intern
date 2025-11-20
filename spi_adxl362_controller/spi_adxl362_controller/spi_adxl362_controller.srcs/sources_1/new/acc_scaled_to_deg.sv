module acc_scaled_to_deg (
    input  wire [10:0] ACC_IN,  // gia tri ACC 11 bit
    output reg  [6:0]  DEG      // goc 0..90
);

always @* begin
    case (1'b1)

        (ACC_IN <= 11'd10 )   : DEG = 7'd0;
        (ACC_IN <= 11'd18 )   : DEG = 7'd1;
        (ACC_IN <= 11'd36 )   : DEG = 7'd2;
        (ACC_IN <= 11'd54 )   : DEG = 7'd3;
        (ACC_IN <= 11'd71 )   : DEG = 7'd4;
        (ACC_IN <= 11'd89 )   : DEG = 7'd5;
        (ACC_IN <= 11'd107 )  : DEG = 7'd6;
        (ACC_IN <= 11'd125 )  : DEG = 7'd7;
        (ACC_IN <= 11'd143 )  : DEG = 7'd8;
        (ACC_IN <= 11'd160 )  : DEG = 7'd9;

        (ACC_IN <= 11'd178 )  : DEG = 7'd10;
        (ACC_IN <= 11'd195 )  : DEG = 7'd11;
        (ACC_IN <= 11'd213 )  : DEG = 7'd12;
        (ACC_IN <= 11'd230 )  : DEG = 7'd13;
        (ACC_IN <= 11'd248 )  : DEG = 7'd14;
        (ACC_IN <= 11'd265 )  : DEG = 7'd15;
        (ACC_IN <= 11'd282 )  : DEG = 7'd16;
        (ACC_IN <= 11'd299 )  : DEG = 7'd17;
        (ACC_IN <= 11'd316 )  : DEG = 7'd18;
        (ACC_IN <= 11'd333 )  : DEG = 7'd19;

        (ACC_IN <= 11'd350 )  : DEG = 7'd20;
        (ACC_IN <= 11'd367 )  : DEG = 7'd21;
        (ACC_IN <= 11'd384 )  : DEG = 7'd22;
        (ACC_IN <= 11'd400 )  : DEG = 7'd23;
        (ACC_IN <= 11'd416 )  : DEG = 7'd24;
        (ACC_IN <= 11'd433 )  : DEG = 7'd25;
        (ACC_IN <= 11'd449 )  : DEG = 7'd26;
        (ACC_IN <= 11'd465 )  : DEG = 7'd27;
        (ACC_IN <= 11'd481 )  : DEG = 7'd28;
        (ACC_IN <= 11'd496 )  : DEG = 7'd29;

        (ACC_IN <= 11'd512 )  : DEG = 7'd30;
        (ACC_IN <= 11'd527 )  : DEG = 7'd31;
        (ACC_IN <= 11'd543 )  : DEG = 7'd32;
        (ACC_IN <= 11'd558 )  : DEG = 7'd33;
        (ACC_IN <= 11'd573 )  : DEG = 7'd34;
        (ACC_IN <= 11'd587 )  : DEG = 7'd35;
        (ACC_IN <= 11'd602 )  : DEG = 7'd36;
        (ACC_IN <= 11'd616 )  : DEG = 7'd37;
        (ACC_IN <= 11'd630 )  : DEG = 7'd38;
        (ACC_IN <= 11'd644 )  : DEG = 7'd39;

        (ACC_IN <= 11'd658 )  : DEG = 7'd40;
        (ACC_IN <= 11'd672 )  : DEG = 7'd41;
        (ACC_IN <= 11'd685 )  : DEG = 7'd42;
        (ACC_IN <= 11'd698 )  : DEG = 7'd43;
        (ACC_IN <= 11'd711 )  : DEG = 7'd44;
        (ACC_IN <= 11'd724 )  : DEG = 7'd45;
        (ACC_IN <= 11'd737 )  : DEG = 7'd46;
        (ACC_IN <= 11'd749 )  : DEG = 7'd47;
        (ACC_IN <= 11'd761 )  : DEG = 7'd48;
        (ACC_IN <= 11'd773 )  : DEG = 7'd49;

        (ACC_IN <= 11'd784 )  : DEG = 7'd50;
        (ACC_IN <= 11'd796 )  : DEG = 7'd51;
        (ACC_IN <= 11'd807 )  : DEG = 7'd52;
        (ACC_IN <= 11'd818 )  : DEG = 7'd53;
        (ACC_IN <= 11'd828 )  : DEG = 7'd54;
        (ACC_IN <= 11'd839 )  : DEG = 7'd55;
        (ACC_IN <= 11'd849 )  : DEG = 7'd56;
        (ACC_IN <= 11'd859 )  : DEG = 7'd57;
        (ACC_IN <= 11'd868 )  : DEG = 7'd58;
        (ACC_IN <= 11'd878 )  : DEG = 7'd59;

        (ACC_IN <= 11'd887 )  : DEG = 7'd60;
        (ACC_IN <= 11'd896 )  : DEG = 7'd61;
        (ACC_IN <= 11'd904 )  : DEG = 7'd62;
        (ACC_IN <= 11'd912 )  : DEG = 7'd63;
        (ACC_IN <= 11'd920 )  : DEG = 7'd64;
        (ACC_IN <= 11'd928 )  : DEG = 7'd65;
        (ACC_IN <= 11'd935 )  : DEG = 7'd66;
        (ACC_IN <= 11'd943 )  : DEG = 7'd67;
        (ACC_IN <= 11'd949 )  : DEG = 7'd68;
        (ACC_IN <= 11'd956 )  : DEG = 7'd69;

        (ACC_IN <= 11'd962 )  : DEG = 7'd70;
        (ACC_IN <= 11'd968 )  : DEG = 7'd71;
        (ACC_IN <= 11'd974 )  : DEG = 7'd72;
        (ACC_IN <= 11'd979 )  : DEG = 7'd73;
        (ACC_IN <= 11'd984 )  : DEG = 7'd74;
        (ACC_IN <= 11'd989 )  : DEG = 7'd75;
        (ACC_IN <= 11'd994 )  : DEG = 7'd76;
        (ACC_IN <= 11'd998 )  : DEG = 7'd77;
        (ACC_IN <= 11'd1002)  : DEG = 7'd78;
        (ACC_IN <= 11'd1005)  : DEG = 7'd79;

        (ACC_IN <= 11'd1008)  : DEG = 7'd80;
        (ACC_IN <= 11'd1011)  : DEG = 7'd81;
        (ACC_IN <= 11'd1014)  : DEG = 7'd82;
        (ACC_IN <= 11'd1016)  : DEG = 7'd83;
        (ACC_IN <= 11'd1018)  : DEG = 7'd84;
        (ACC_IN <= 11'd1020)  : DEG = 7'd85;
        (ACC_IN <= 11'd1022)  : DEG = 7'd86;
        (ACC_IN <= 11'd1023)  : DEG = 7'd87;

        default               : DEG = 7'd90;

    endcase
end

endmodule
