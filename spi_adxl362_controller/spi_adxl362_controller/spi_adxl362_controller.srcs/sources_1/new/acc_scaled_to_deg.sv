module acc_scaled_to_deg (
    input  wire [10:0] ACC_IN,   // 0..1024 (g?c)
    output reg  [6:0]  DEG       // 0..90
);

    // scale ACC lên 0..102400
    wire [16:0] ACC = ACC_IN * 17'd100;

always @(*) begin
    case (1'b1)

        // 0 degree
        (ACC < 17'd1138):  DEG = 7'd0;

        // 1 degree
        (ACC < 17'd2276):  DEG = 7'd1;

        // 2 degree
        (ACC < 17'd3414):  DEG = 7'd2;

        // 3 degree
        (ACC < 17'd4552):  DEG = 7'd3;

        // 4 degree
        (ACC < 17'd5690):  DEG = 7'd4;

        // 5 degree
        (ACC < 17'd6828):  DEG = 7'd5;

        // 6 degree
        (ACC < 17'd7966):  DEG = 7'd6;

        // 7 degree
        (ACC < 17'd9104):  DEG = 7'd7;

        // 8 degree
        (ACC < 17'd10242): DEG = 7'd8;

        // 9 degree
        (ACC < 17'd11380): DEG = 7'd9;

        // 10 degree
        (ACC < 17'd12518): DEG = 7'd10;

        // 11 degree
        (ACC < 17'd13656): DEG = 7'd11;

        // 12 degree
        (ACC < 17'd14794): DEG = 7'd12;

        // 13 degree
        (ACC < 17'd15932): DEG = 7'd13;

        // 14 degree
        (ACC < 17'd17070): DEG = 7'd14;

        // 15 degree
        (ACC < 17'd18208): DEG = 7'd15;

        // 16 degree
        (ACC < 17'd19346): DEG = 7'd16;

        // 17 degree
        (ACC < 17'd20484): DEG = 7'd17;

        // 18 degree
        (ACC < 17'd21622): DEG = 7'd18;

        // 19 degree
        (ACC < 17'd22760): DEG = 7'd19;

        // 20 degree
        (ACC < 17'd23898): DEG = 7'd20;

        // 21 degree
        (ACC < 17'd25036): DEG = 7'd21;

        // 22 degree
        (ACC < 17'd26174): DEG = 7'd22;

        // 23 degree
        (ACC < 17'd27312): DEG = 7'd23;

        // 24 degree
        (ACC < 17'd28450): DEG = 7'd24;

        // 25 degree
        (ACC < 17'd29588): DEG = 7'd25;

        // 26 degree
        (ACC < 17'd30726): DEG = 7'd26;

        // 27 degree
        (ACC < 17'd31864): DEG = 7'd27;

        // 28 degree
        (ACC < 17'd33002): DEG = 7'd28;

        // 29 degree
        (ACC < 17'd34140): DEG = 7'd29;

        // 30 degree
        (ACC < 17'd35278): DEG = 7'd30;

        // 31 degree
        (ACC < 17'd36416): DEG = 7'd31;

        // 32 degree
        (ACC < 17'd37554): DEG = 7'd32;

        // 33 degree
        (ACC < 17'd38692): DEG = 7'd33;

        // 34 degree
        (ACC < 17'd39830): DEG = 7'd34;

        // 35 degree
        (ACC < 17'd40968): DEG = 7'd35;

        // 36 degree
        (ACC < 17'd42106): DEG = 7'd36;

        // 37 degree
        (ACC < 17'd43244): DEG = 7'd37;

        // 38 degree
        (ACC < 17'd44382): DEG = 7'd38;

        // 39 degree
        (ACC < 17'd45520): DEG = 7'd39;

        // 40 degree
        (ACC < 17'd46658): DEG = 7'd40;

        // 41 degree
        (ACC < 17'd47796): DEG = 7'd41;

        // 42 degree
        (ACC < 17'd48934): DEG = 7'd42;

        // 43 degree
        (ACC < 17'd50072): DEG = 7'd43;

        // 44 degree
        (ACC < 17'd51210): DEG = 7'd44;

        // 45 degree
        (ACC < 17'd52348): DEG = 7'd45;

        // 46 degree
        (ACC < 17'd53486): DEG = 7'd46;

        // 47 degree
        (ACC < 17'd54624): DEG = 7'd47;

        // 48 degree
        (ACC < 17'd55762): DEG = 7'd48;

        // 49 degree
        (ACC < 17'd56900): DEG = 7'd49;

        // 50 degree
        (ACC < 17'd58038): DEG = 7'd50;

        // 51 degree
        (ACC < 17'd59176): DEG = 7'd51;

        // 52 degree
        (ACC < 17'd60314): DEG = 7'd52;

        // 53 degree
        (ACC < 17'd61452): DEG = 7'd53;

        // 54 degree
        (ACC < 17'd62590): DEG = 7'd54;

        // 55 degree
        (ACC < 17'd63728): DEG = 7'd55;

        // 56 degree
        (ACC < 17'd64866): DEG = 7'd56;

        // 57 degree
        (ACC < 17'd66004): DEG = 7'd57;

        // 58 degree
        (ACC < 17'd67142): DEG = 7'd58;

        // 59 degree
        (ACC < 17'd68280): DEG = 7'd59;

        // 60 degree
        (ACC < 17'd69418): DEG = 7'd60;

        // 61 degree
        (ACC < 17'd70556): DEG = 7'd61;

        // 62 degree
        (ACC < 17'd71694): DEG = 7'd62;

        // 63 degree
        (ACC < 17'd72832): DEG = 7'd63;

        // 64 degree
        (ACC < 17'd73970): DEG = 7'd64;

        // 65 degree
        (ACC < 17'd75108): DEG = 7'd65;

        // 66 degree
        (ACC < 17'd76246): DEG = 7'd66;

        // 67 degree
        (ACC < 17'd77384): DEG = 7'd67;

        // 68 degree
        (ACC < 17'd78522): DEG = 7'd68;

        // 69 degree
        (ACC < 17'd79660): DEG = 7'd69;

        // 70 degree
        (ACC < 17'd80798): DEG = 7'd70;

        // 71 degree
        (ACC < 17'd81936): DEG = 7'd71;

        // 72 degree
        (ACC < 17'd83074): DEG = 7'd72;

        // 73 degree
        (ACC < 17'd84212): DEG = 7'd73;

        // 74 degree
        (ACC < 17'd85350): DEG = 7'd74;

        // 75 degree
        (ACC < 17'd86488): DEG = 7'd75;

        // 76 degree
        (ACC < 17'd87626): DEG = 7'd76;

        // 77 degree
        (ACC < 17'd88764): DEG = 7'd77;

        // 78 degree
        (ACC < 17'd89902): DEG = 7'd78;

        // 79 degree
        (ACC < 17'd91040): DEG = 7'd79;

        // 80 degree
        (ACC < 17'd92178): DEG = 7'd80;

        // 81 degree
        (ACC < 17'd93316): DEG = 7'd81;

        // 82 degree
        (ACC < 17'd94454): DEG = 7'd82;

        // 83 degree
        (ACC < 17'd95592): DEG = 7'd83;

        // 84 degree
        (ACC < 17'd96730): DEG = 7'd84;

        // 85 degree
        (ACC < 17'd97868): DEG = 7'd85;

        // 86 degree
        (ACC < 17'd99006): DEG = 7'd86;

        // 87 degree
        (ACC < 17'd100144): DEG = 7'd87;

        // 88 degree
        (ACC < 17'd101282): DEG = 7'd88;

        // 89 degree
        (ACC < 17'd102420): DEG = 7'd89;

        // 90 degree
        default: DEG = 7'd90;

    endcase
end

endmodule
