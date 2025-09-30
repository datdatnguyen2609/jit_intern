`timescale 1ns/1ps

module i2c_master_tb;

  // --------------------------------
  // Clock 200 kHz (T = 5 us) + reset
  // --------------------------------
  reg i_clk_200k = 1'b0;
  always #2500 i_clk_200k = ~i_clk_200k;

  reg i_rst = 1'b1;
  initial begin
    // Gi? reset ~100 us cho ch?c
    repeat (20) @(posedge i_clk_200k);
    i_rst = 1'b0;
  end

  // --------------------------------
  // Bus I2C
  // --------------------------------
  wire       o_scl;        // t? DUT
  tri1       io_sda;       // SDA có pull-up
  pullup     PU_SDA(io_sda);

  wire [7:0] o_temp_data;

  // --------------------------------
  // DUT
  // --------------------------------
  i2c_master #(
    .P_ADDR_R  (8'h97),    // 0x4B ??c
    .P_REG_ADDR(8'h00)
  ) dut (
    .i_clk_200k (i_clk_200k),
    .i_rst      (i_rst),
    .io_sda     (io_sda),
    .o_scl      (o_scl),
    .o_temp_data(o_temp_data)
  );

  // --------------------------------
  // Slave mô ph?ng "siêu ng?n": ACK & tr? 2 byte
  // - Open-drain: ch? kéo 0 khi c?n
  // - M?c ?ích: giúp DUT ?i qua các stage
  // --------------------------------
  reg sda_drive0 = 1'b0;   // 1: kéo 0, 0: th? (pull-up = 1)
  assign io_sda = sda_drive0 ? 1'b0 : 1'bz;

  // M?u d? li?u tr? v?
  reg [7:0] data_msb = 8'hA5;
  reg [7:0] data_lsb = 8'h5A;

  // L?c START ??n gi?n (SDA: 1->0 khi SCL=1)
  reg sda_q = 1'b1, scl_q = 1'b1;
  always @(posedge i_clk_200k) begin
    sda_q <= io_sda;
    scl_q <= o_scl;
  end
  wire start_cond = (sda_q==1'b1 && io_sda==1'b0 && o_scl==1'b1);

  // B? ??m và pha nh? g?n:
  // 0: nh?n ADDR+W (8 bit) -> ACKa
  // 1: nh?n REG (8 bit)    -> ACKr
  // 2: nh?n ADDR+R (8 bit) -> ACKr2
  // 3: g?i MSB (8 bit)     -> ch? ACK master
  // 4: g?i LSB (8 bit)     -> ch? NACK master
  integer bit_cnt;
  reg [2:0] phase = 3'd0;
  reg in_frame = 1'b0;
  reg [7:0] sh;       // shifter RX/TX

  // Ti?n ích ACK 1 bit: kéo 0 tr?n bit ACK
  task ack_1bit;
    begin
      // ??t khi SCL low, gi? qua c?nh lên, th? khi SCL v? low
      if (scl_q==1'b1 && o_scl==1'b0) sda_drive0 <= 1'b1; // chu?n b?
      if (scl_q==1'b0 && o_scl==1'b1) sda_drive0 <= 1'b1; // gi?
      if (scl_q==1'b1 && o_scl==1'b0) sda_drive0 <= 1'b0; // k?t thúc
    end
  endtask

  // Logic c?c g?n: d?a trên c?nh c?a SCL ngay trong TB
  always @(posedge i_clk_200k) begin
    if (start_cond) begin
      in_frame  <= 1'b1;
      phase     <= 3'd0;
      bit_cnt   <= 7;
      sda_drive0<= 1'b0;
    end

    if (in_frame) begin
      // ===== NH?N 8 BIT (ADDR/REG/ADDRR) =====
      if (phase<=3'd2) begin
        // M?u d? li?u RX ? c?nh lên SCL
        if (scl_q==1'b0 && o_scl==1'b1) begin
          sh[bit_cnt] <= io_sda;
          if (bit_cnt==0) begin
            // Xong 8 bit -> ACK
            phase   <= phase + 3'd1;
            bit_cnt <= 7;
          end else begin
            bit_cnt <= bit_cnt - 1;
          end
        end
        // Phát ACK cho 3 byte ??u tiên
        if ((phase==0 || phase==1 || phase==2)) ack_1bit();
        // Khi v?a k?t thúc ACK c?a ADDR+R (phase==2 -> 3)
        if (phase==3'd3) begin
          sh        <= data_msb; // chu?n b? TX MSB
          sda_drive0<= 1'b0;
        end
      end
      // ===== G?I 8 BIT MSB =====
      else if (phase==3'd3) begin
        // ??t bit ? c?nh xu?ng SCL
        if (scl_q==1'b1 && o_scl==1'b0) sda_drive0 <= (sh[bit_cnt]==1'b0);
        // Master m?u ? c?nh lên
        if (scl_q==1'b0 && o_scl==1'b1) begin
          if (bit_cnt==0) begin
            sda_drive0<= 1'b0;   // nh??ng bus cho ACK c?a master
            phase     <= 3'd4;
            bit_cnt   <= 7;
            sh        <= data_lsb;
          end else bit_cnt <= bit_cnt - 1;
        end
      end
      // ===== CH? ACK MASTER SAU MSB =====
      else if (phase==3'd4) begin
        // Ch? ??i 1 bit (master kéo 0 n?u ACK), slave th? bus
        if (scl_q==1'b1 && o_scl==1'b0) phase <= 3'd5; // sang g?i LSB
      end
      // ===== G?I 8 BIT LSB =====
      else if (phase==3'd5) begin
        if (scl_q==1'b1 && o_scl==1'b0) sda_drive0 <= (sh[bit_cnt]==1'b0);
        if (scl_q==1'b0 && o_scl==1'b1) begin
          if (bit_cnt==0) begin
            sda_drive0<= 1'b0;   // nh??ng bus cho NACK master
            phase     <= 3'd6;   // xong
          end else bit_cnt <= bit_cnt - 1;
        end
      end
      // ===== K?T THÚC KHUNG =====
      else if (phase==3'd6) begin
        if (scl_q==1'b1 && o_scl==1'b0) begin
          in_frame   <= 1'b0;     // k?t thúc sau bit NACK
          sda_drive0 <= 1'b0;
        end
      end
    end
  end

  // --------------------------------
  // In tên state khi DUT ??i state
  // --------------------------------
  function [127:0] f_state_name(input [3:0] s);
    case (s)
      4'd0:  f_state_name = "S_POWERUP";
      4'd1:  f_state_name = "S_STARTW";
      4'd2:  f_state_name = "S_ADDRW";
      4'd3:  f_state_name = "S_ACKAW";
      4'd4:  f_state_name = "S_REG";
      4'd5:  f_state_name = "S_ACKR";
      4'd6:  f_state_name = "S_RSTART";
      4'd7:  f_state_name = "S_ADDRR";
      4'd8:  f_state_name = "S_ACKAR";
      4'd9:  f_state_name = "S_RMSB";
      4'd10: f_state_name = "S_MACK";
      4'd11: f_state_name = "S_RLSB";
      4'd12: f_state_name = "S_MNACK";
      4'd13: f_state_name = "S_STOP";
      default: f_state_name = "UNKNOWN";
    endcase
  endfunction

  reg [3:0] prev_state = 4'hF;
  always @(posedge i_clk_200k) begin
    if (!i_rst && dut.r_state !== prev_state) begin
      $display("[%0t ns] STATE: %s, o_temp_data=0x%02h",
               $time, f_state_name(dut.r_state), o_temp_data);
      prev_state <= dut.r_state;
    end
  end

  // --------------------------------
  // Dump và k?t thúc nhanh g?n
  // --------------------------------
  initial begin
    // ch?y ~40 ms: ?? qua POWERUP (10 ms) + 1 vòng giao d?ch
    #40_000_000;
    $display("Finish at %0t ns", $time);
    $finish;
  end

endmodule
