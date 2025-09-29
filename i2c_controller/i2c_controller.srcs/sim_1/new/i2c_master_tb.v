`timescale 1ns/1ps

module i2c_master_tb;

  // --------------------------------
  // Clock 200 kHz (T = 5 us)
  // --------------------------------
  reg i_clk_200k = 1'b0;
  always #2500 i_clk_200k = ~i_clk_200k; // 2.5 us half-period

  // --------------------------------
  // Bus I2C
  // --------------------------------
  wire       o_scl;        // tu DUT
  tri1       io_sda;       // SDA co pull-up
  pullup     PU_SDA(io_sda);

  wire [7:0] o_temp_data;

  // --------------------------------
  // DUT
  // --------------------------------
  i2c_master #(
    .P_ADDR_R(8'h97)
  ) dut (
    .i_clk_200k (i_clk_200k),
    .io_sda     (io_sda),
    .o_scl      (o_scl),
    .o_temp_data(o_temp_data)
  );

  // --------------------------------
  // Slave mo phong cuc ngan: ACK + tra 2 byte
  // - Open-drain: chi keo 0 khi can
  // - Muc dich: giup DUT di qua cac stage
  // --------------------------------
  reg sda_drive0 = 1'b0; // 1: keo 0, 0: tha (pull-up = 1)
  assign io_sda = sda_drive0 ? 1'b0 : 1'bz;

  // Mau du lieu
  reg [7:0] data_msb = 8'hA5;
  reg [7:0] data_lsb = 8'h5A;

  // Phat hien START (SDA xuong khi SCL=1)
  reg sda_q, scl_q;
  always @(posedge i_clk_200k) begin
    sda_q <= io_sda;
    scl_q <= o_scl;
  end
  wire start_cond = (sda_q==1'b1 && io_sda==1'b0 && o_scl==1'b1);

  // Dem canh len SCL sau START de canh vi tri ACK/DATA
  integer bit_idx;
  reg     in_frame = 1'b0;
  reg [7:0] sh_data;
  reg [3:0] data_phase; // 0: addr, 1: ACKa, 2: D0, 3: ACK0, 4: D1, 5: ACK1

  initial begin
    sh_data    = data_msb;
    data_phase = 0;
  end

  // Logic don: 
  // - Khi START: vao frame, reset dem
  // - Sau 8 canh len SCL dau (ADDR), o bit ACK -> keo 0 (ACK)
  // - Sau do 8 bit du lieu: dat bit khi SCL LOW (truoc canh len), tha/keo tuy theo bit
  // - Sau MSB: de master ACK (tha), Sau LSB: de master NACK (tha)
  always @(posedge i_clk_200k) begin
    if (start_cond) begin
      in_frame  <= 1'b1;
      bit_idx   <= 0;
      data_phase<= 0;
      sda_drive0<= 1'b0;  // de DUT gui addr
    end

    if (in_frame) begin
      // ACK cho dia chi sau 8 canh len
      if (data_phase==0 && scl_q==1'b0 && o_scl==1'b1) begin
        bit_idx <= bit_idx + 1;
        if (bit_idx==7) data_phase <= 1; // chuan bi ACKa
      end

      // Phat ACKa: keo 0 trong 1 bit ACK
      if (data_phase==1) begin
        if (scl_q==1'b1 && o_scl==1'b0) sda_drive0 <= 1'b1; // bat dau ACK
        if (scl_q==1'b0 && o_scl==1'b1) sda_drive0 <= 1'b1; // giu
        if (scl_q==1'b1 && o_scl==1'b0) begin               // ket thuc ACK
          sda_drive0 <= 1'b0;
          data_phase <= 2;
          bit_idx    <= 7;
          sh_data    <= data_msb;
        end
      end

      // Gui 8 bit MSB: dat bit khi SCL LOW
      if (data_phase==2) begin
        if (scl_q==1'b1 && o_scl==1'b0) begin // falling
          sda_drive0 <= (sh_data[bit_idx]==1'b0) ? 1'b1 : 1'b0;
        end
        if (scl_q==1'b0 && o_scl==1'b1) begin // rising
          if (bit_idx==0) begin
            sda_drive0 <= 1'b0; // tha de master ACK
            data_phase <= 3;
          end else bit_idx <= bit_idx - 1;
        end
      end

      // ACK0 cua master (slave chi tha)
      if (data_phase==3 && scl_q==1'b1 && o_scl==1'b0) begin
        data_phase <= 4;
        bit_idx    <= 7;
        sh_data    <= data_lsb;
      end

      // Gui 8 bit LSB
      if (data_phase==4) begin
        if (scl_q==1'b1 && o_scl==1'b0) sda_drive0 <= (sh_data[bit_idx]==1'b0) ? 1'b1 : 1'b0;
        if (scl_q==1'b0 && o_scl==1'b1) begin
          if (bit_idx==0) begin
            sda_drive0 <= 1'b0; // tha de master NACK
            data_phase <= 5;
          end else bit_idx <= bit_idx - 1;
        end
      end

      // ACK1 (NACK) cua master (slave tha) xong la ket thuc
      if (data_phase==5 && scl_q==1'b1 && o_scl==1'b0) begin
        in_frame   <= 1'b0;
        sda_drive0 <= 1'b0;
      end
    end
  end

  // --------------------------------
  // In ten stage khi DUT doi state
  // --------------------------------
  reg [3:0] prev_state;
  function [127:0] f_state_name(input [3:0] s);
    case (s)
      4'd0:  f_state_name = "S_POWERUP";
      4'd1:  f_state_name = "S_START";
      4'd2:  f_state_name = "S_ADDR";
      4'd3:  f_state_name = "S_ACKA";
      4'd4:  f_state_name = "S_RMSB";
      4'd5:  f_state_name = "S_MACK";
      4'd6:  f_state_name = "S_RLSB";
      4'd7:  f_state_name = "S_MNACK";
      4'd8:  f_state_name = "S_STOP";
      default: f_state_name = "UNKNOWN";
    endcase
  endfunction

  initial begin
    prev_state = 4'hF;
    // chay ~50 ms la du thay vong lap
    #50_000_000;
    $finish;
  end

  // Theo doi r_state (tham chieu phan cap)
  always @(posedge i_clk_200k) begin
    if (dut.r_state !== prev_state) begin
      $display("[%0t ns] STATE: %s, o_temp_data=0x%0h",
               $time, f_state_name(dut.r_state), o_temp_data);
      prev_state <= dut.r_state;
    end
  end

endmodule
