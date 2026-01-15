module acc_scaled_to_deg_z_pos (
    input  wire [10:0] ACC_IN,
    output reg  [6:0]  DEG
);

always @* begin
    case (1'b1)

        (ACC_IN <= 11'd0   ) : DEG = 7'd0;
        (ACC_IN <= 11'd21  ) : DEG = 7'd1;
        (ACC_IN <= 11'd42  ) : DEG = 7'd2;
        (ACC_IN <= 11'd63  ) : DEG = 7'd3;
        (ACC_IN <= 11'd84  ) : DEG = 7'd4;
        (ACC_IN <= 11'd105 ) : DEG = 7'd5;
        (ACC_IN <= 11'd125 ) : DEG = 7'd6;
        (ACC_IN <= 11'd146 ) : DEG = 7'd7;
        (ACC_IN <= 11'd167 ) : DEG = 7'd8;
        (ACC_IN <= 11'd188 ) : DEG = 7'd9;

        (ACC_IN <= 11'd208 ) : DEG = 7'd10;
        (ACC_IN <= 11'd229 ) : DEG = 7'd11;
        (ACC_IN <= 11'd249 ) : DEG = 7'd12;
        (ACC_IN <= 11'd270 ) : DEG = 7'd13;
        (ACC_IN <= 11'd290 ) : DEG = 7'd14;
        (ACC_IN <= 11'd311 ) : DEG = 7'd15;
        (ACC_IN <= 11'd331 ) : DEG = 7'd16;
        (ACC_IN <= 11'd351 ) : DEG = 7'd17;
        (ACC_IN <= 11'd371 ) : DEG = 7'd18;
        (ACC_IN <= 11'd391 ) : DEG = 7'd19;

        (ACC_IN <= 11'd410 ) : DEG = 7'd20;
        (ACC_IN <= 11'd430 ) : DEG = 7'd21;
        (ACC_IN <= 11'd450 ) : DEG = 7'd22;
        (ACC_IN <= 11'd469 ) : DEG = 7'd23;
        (ACC_IN <= 11'd488 ) : DEG = 7'd24;
        (ACC_IN <= 11'd507 ) : DEG = 7'd25;
        (ACC_IN <= 11'd526 ) : DEG = 7'd26;
        (ACC_IN <= 11'd545 ) : DEG = 7'd27;
        (ACC_IN <= 11'd563 ) : DEG = 7'd28;
        (ACC_IN <= 11'd582 ) : DEG = 7'd29;

        (ACC_IN <= 11'd600 ) : DEG = 7'd30;
        (ACC_IN <= 11'd618 ) : DEG = 7'd31;
        (ACC_IN <= 11'd636 ) : DEG = 7'd32;
        (ACC_IN <= 11'd654 ) : DEG = 7'd33;
        (ACC_IN <= 11'd671 ) : DEG = 7'd34;
        (ACC_IN <= 11'd688 ) : DEG = 7'd35;
        (ACC_IN <= 11'd705 ) : DEG = 7'd36;
        (ACC_IN <= 11'd722 ) : DEG = 7'd37;
        (ACC_IN <= 11'd739 ) : DEG = 7'd38;
        (ACC_IN <= 11'd755 ) : DEG = 7'd39;

        (ACC_IN <= 11'd771 ) : DEG = 7'd40;
        (ACC_IN <= 11'd787 ) : DEG = 7'd41;
        (ACC_IN <= 11'd803 ) : DEG = 7'd42;
        (ACC_IN <= 11'd818 ) : DEG = 7'd43;
        (ACC_IN <= 11'd834 ) : DEG = 7'd44;
        (ACC_IN <= 11'd849 ) : DEG = 7'd45;
        (ACC_IN <= 11'd863 ) : DEG = 7'd46;
        (ACC_IN <= 11'd878 ) : DEG = 7'd47;
        (ACC_IN <= 11'd892 ) : DEG = 7'd48;
        (ACC_IN <= 11'd906 ) : DEG = 7'd49;

        (ACC_IN <= 11'd919 ) : DEG = 7'd50;
        (ACC_IN <= 11'd933 ) : DEG = 7'd51;
        (ACC_IN <= 11'd946 ) : DEG = 7'd52;
        (ACC_IN <= 11'd958 ) : DEG = 7'd53;
        (ACC_IN <= 11'd971 ) : DEG = 7'd54;
        (ACC_IN <= 11'd983 ) : DEG = 7'd55;
        (ACC_IN <= 11'd995 ) : DEG = 7'd56;
        (ACC_IN <= 11'd1006) : DEG = 7'd57;
        (ACC_IN <= 11'd1018) : DEG = 7'd58;
        (ACC_IN <= 11'd1029) : DEG = 7'd59;

        (ACC_IN <= 11'd1039) : DEG = 7'd60;
        (ACC_IN <= 11'd1050) : DEG = 7'd61;
        (ACC_IN <= 11'd1060) : DEG = 7'd62;
        (ACC_IN <= 11'd1069) : DEG = 7'd63;
        (ACC_IN <= 11'd1079) : DEG = 7'd64;
        (ACC_IN <= 11'd1088) : DEG = 7'd65;
        (ACC_IN <= 11'd1096) : DEG = 7'd66;
        (ACC_IN <= 11'd1105) : DEG = 7'd67;
        (ACC_IN <= 11'd1113) : DEG = 7'd68;
        (ACC_IN <= 11'd1120) : DEG = 7'd69;

        (ACC_IN <= 11'd1128) : DEG = 7'd70;
        (ACC_IN <= 11'd1135) : DEG = 7'd71;
        (ACC_IN <= 11'd1141) : DEG = 7'd72;
        (ACC_IN <= 11'd1148) : DEG = 7'd73;
        (ACC_IN <= 11'd1154) : DEG = 7'd74;
        (ACC_IN <= 11'd1159) : DEG = 7'd75;
        (ACC_IN <= 11'd1164) : DEG = 7'd76;
        (ACC_IN <= 11'd1169) : DEG = 7'd77;
        (ACC_IN <= 11'd1174) : DEG = 7'd78;
        (ACC_IN <= 11'd1178) : DEG = 7'd79;

        (ACC_IN <= 11'd1182) : DEG = 7'd80;
        (ACC_IN <= 11'd1185) : DEG = 7'd81;
        (ACC_IN <= 11'd1188) : DEG = 7'd82;
        (ACC_IN <= 11'd1191) : DEG = 7'd83;
        (ACC_IN <= 11'd1193) : DEG = 7'd84;
        (ACC_IN <= 11'd1195) : DEG = 7'd85;
        (ACC_IN <= 11'd1197) : DEG = 7'd86;
        (ACC_IN <= 11'd1198) : DEG = 7'd87;
        (ACC_IN <= 11'd1199) : DEG = 7'd88;
        (ACC_IN <= 11'd1200) : DEG = 7'd89;

        default              : DEG = 7'd90;

    endcase
end

endmodule
