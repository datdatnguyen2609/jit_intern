module acc_scaled_to_deg_z_neg (
    input  wire [10:0] ACC_IN,  
    output reg  [6:0]  DEG      
);

always @* begin
    case (1'b1)

        (ACC_IN <= 11'd0   ) : DEG = 7'd0;
        (ACC_IN <= 11'd16  ) : DEG = 7'd1;
        (ACC_IN <= 11'd31  ) : DEG = 7'd2;
        (ACC_IN <= 11'd47  ) : DEG = 7'd3;
        (ACC_IN <= 11'd62  ) : DEG = 7'd4;
        (ACC_IN <= 11'd78  ) : DEG = 7'd5;
        (ACC_IN <= 11'd93  ) : DEG = 7'd6;
        (ACC_IN <= 11'd108 ) : DEG = 7'd7;
        (ACC_IN <= 11'd124 ) : DEG = 7'd8;
        (ACC_IN <= 11'd139 ) : DEG = 7'd9;

        (ACC_IN <= 11'd155 ) : DEG = 7'd10;
        (ACC_IN <= 11'd170 ) : DEG = 7'd11;
        (ACC_IN <= 11'd185 ) : DEG = 7'd12;
        (ACC_IN <= 11'd200 ) : DEG = 7'd13;
        (ACC_IN <= 11'd215 ) : DEG = 7'd14;
        (ACC_IN <= 11'd230 ) : DEG = 7'd15;
        (ACC_IN <= 11'd245 ) : DEG = 7'd16;
        (ACC_IN <= 11'd260 ) : DEG = 7'd17;
        (ACC_IN <= 11'd275 ) : DEG = 7'd18;
        (ACC_IN <= 11'd290 ) : DEG = 7'd19;

        (ACC_IN <= 11'd304 ) : DEG = 7'd20;
        (ACC_IN <= 11'd319 ) : DEG = 7'd21;
        (ACC_IN <= 11'd333 ) : DEG = 7'd22;
        (ACC_IN <= 11'd348 ) : DEG = 7'd23;
        (ACC_IN <= 11'd362 ) : DEG = 7'd24;
        (ACC_IN <= 11'd376 ) : DEG = 7'd25;
        (ACC_IN <= 11'd390 ) : DEG = 7'd26;
        (ACC_IN <= 11'd404 ) : DEG = 7'd27;
        (ACC_IN <= 11'd418 ) : DEG = 7'd28;
        (ACC_IN <= 11'd431 ) : DEG = 7'd29;

        (ACC_IN <= 11'd445 ) : DEG = 7'd30;
        (ACC_IN <= 11'd458 ) : DEG = 7'd31;
        (ACC_IN <= 11'd472 ) : DEG = 7'd32;
        (ACC_IN <= 11'd485 ) : DEG = 7'd33;
        (ACC_IN <= 11'd498 ) : DEG = 7'd34;
        (ACC_IN <= 11'd510 ) : DEG = 7'd35;
        (ACC_IN <= 11'd523 ) : DEG = 7'd36;
        (ACC_IN <= 11'd536 ) : DEG = 7'd37;
        (ACC_IN <= 11'd548 ) : DEG = 7'd38;
        (ACC_IN <= 11'd560 ) : DEG = 7'd39;

        (ACC_IN <= 11'd572 ) : DEG = 7'd40;
        (ACC_IN <= 11'd584 ) : DEG = 7'd41;
        (ACC_IN <= 11'd596 ) : DEG = 7'd42;
        (ACC_IN <= 11'd607 ) : DEG = 7'd43;
        (ACC_IN <= 11'd618 ) : DEG = 7'd44;
        (ACC_IN <= 11'd629 ) : DEG = 7'd45;
        (ACC_IN <= 11'd640 ) : DEG = 7'd46;
        (ACC_IN <= 11'd651 ) : DEG = 7'd47;
        (ACC_IN <= 11'd661 ) : DEG = 7'd48;
        (ACC_IN <= 11'd672 ) : DEG = 7'd49;

        (ACC_IN <= 11'd682 ) : DEG = 7'd50;
        (ACC_IN <= 11'd692 ) : DEG = 7'd51;
        (ACC_IN <= 11'd701 ) : DEG = 7'd52;
        (ACC_IN <= 11'd711 ) : DEG = 7'd53;
        (ACC_IN <= 11'd720 ) : DEG = 7'd54;
        (ACC_IN <= 11'd729 ) : DEG = 7'd55;
        (ACC_IN <= 11'd738 ) : DEG = 7'd56;
        (ACC_IN <= 11'd746 ) : DEG = 7'd57;
        (ACC_IN <= 11'd755 ) : DEG = 7'd58;
        (ACC_IN <= 11'd763 ) : DEG = 7'd59;

        (ACC_IN <= 11'd771 ) : DEG = 7'd60;
        (ACC_IN <= 11'd778 ) : DEG = 7'd61;
        (ACC_IN <= 11'd786 ) : DEG = 7'd62;
        (ACC_IN <= 11'd793 ) : DEG = 7'd63;
        (ACC_IN <= 11'd800 ) : DEG = 7'd64;
        (ACC_IN <= 11'd807 ) : DEG = 7'd65;
        (ACC_IN <= 11'd813 ) : DEG = 7'd66;
        (ACC_IN <= 11'd819 ) : DEG = 7'd67;
        (ACC_IN <= 11'd825 ) : DEG = 7'd68;
        (ACC_IN <= 11'd831 ) : DEG = 7'd69;

        (ACC_IN <= 11'd836 ) : DEG = 7'd70;
        (ACC_IN <= 11'd842 ) : DEG = 7'd71;
        (ACC_IN <= 11'd846 ) : DEG = 7'd72;
        (ACC_IN <= 11'd851 ) : DEG = 7'd73;
        (ACC_IN <= 11'd856 ) : DEG = 7'd74;
        (ACC_IN <= 11'd860 ) : DEG = 7'd75;
        (ACC_IN <= 11'd864 ) : DEG = 7'd76;
        (ACC_IN <= 11'd867 ) : DEG = 7'd77;
        (ACC_IN <= 11'd871 ) : DEG = 7'd78;
        (ACC_IN <= 11'd874 ) : DEG = 7'd79;

        (ACC_IN <= 11'd876 ) : DEG = 7'd80;
        (ACC_IN <= 11'd879 ) : DEG = 7'd81;
        (ACC_IN <= 11'd881 ) : DEG = 7'd82;
        (ACC_IN <= 11'd883 ) : DEG = 7'd83;
        (ACC_IN <= 11'd885 ) : DEG = 7'd84;
        (ACC_IN <= 11'd887 ) : DEG = 7'd85;
        (ACC_IN <= 11'd888 ) : DEG = 7'd86;
        (ACC_IN <= 11'd889 ) : DEG = 7'd87;
        // 87 va 88 cung nguong 889
        (ACC_IN <= 11'd889 ) : DEG = 7'd88;
        (ACC_IN <= 11'd890 ) : DEG = 7'd89;

        default              : DEG = 7'd90;

    endcase
end

endmodule
