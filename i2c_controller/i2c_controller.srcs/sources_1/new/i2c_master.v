module i2c_master (
    input i_CLK,
    input i_RST,
    inout io_SDA,
    output [7:0] o_temp_data,
    output o_SDA_dir,
    output o_SCL
  );
  //==========================================================
  // Khai bao bien
  reg [3:0] r_counter = 4'b0;
  reg r_subCLK = 1'b1;

  //==========================================================
  // Tao subclk
  always @(posedge i_CLK)
  begin
    if (i_RST)
    begin
      r_counter <= 4'b0;
      r_subCLK <= 1'b0;
    end
  end
  else
    if (r_counter == 9)
    begin
      r_counter <= 4'd0;
      r_subCLK <= ~r_subCLK;
    end
    else
      r_counter <= r_counter + 1;
  assign o_SCL = r_subCLK;

  //===========================================================
  // Khai bao bien MSB, LSB de nhan du lieu
  parameter [7:0] address_plus_read = 8'h97;
  reg [7:0] r_MSB = 8'b0;
  reg [7:0] r_LSB = 8'b0;
  reg r_obit = 1'b1;
  reg [11:0] r_count = 12'b0;
  reg [7:0] r_temp_data
      //===========================================================
      // Khai bao FSM
      localparam [4:0] POWER_UP   = 5'h00,
      START      = 5'h01,
      SEND_ADDR6 = 5'h02,
      SEND_ADDR5 = 5'h03,
      SEND_ADDR4 = 5'h04,
      SEND_ADDR3 = 5'h05,
      SEND_ADDR2 = 5'h06,
      SEND_ADDR1 = 5'h07,
      SEND_ADDR0 = 5'h08,
      SEND_RW    = 5'h09,
      REC_ACK    = 5'h0A,
      REC_MSB7   = 5'h0B,
      REC_MSB6	= 5'h0C,
      REC_MSB5	= 5'h0D,
      REC_MSB4	= 5'h0E,
      REC_MSB3	= 5'h0F,
      REC_MSB2	= 5'h10,
      REC_MSB1	= 5'h11,
      REC_MSB0	= 5'h12,
      SEND_ACK   = 5'h13,
      REC_LSB7   = 5'h14,
      REC_LSB6	= 5'h15,
      REC_LSB5	= 5'h16,
      REC_LSB4	= 5'h17,
      REC_LSB3	= 5'h18,
      REC_LSB2	= 5'h19,
      REC_LSB1	= 5'h1A,
      REC_LSB0	= 5'h1B,
      NACK       = 5'h1C;

  reg [4:0] r_stage = POWER_UP;
  //===========================================================
  //
  always @(posedge i_CLK)
  begin
    if (i_RST)
    begin
      r_stage <= START;
      r_count <= 12'd2000;
    end
    else
    begin
      r_count <= r_count + 1;
      case (r_stage)
        POWER_UP    :
        begin
          if(r_count == 12'd1999)
            r_state <= START;
        end
        START       :
        begin
          if(r_count == 12'd2004)
            r_obit <= 1'b0;          // send START condition 1/4 clock after SCL goes high
          if(r_count == 12'd2013)
            r_state <= SEND_ADDR6;
        end
        SEND_ADDR6  :
        begin
          r_obit <= sensor_address_plus_read[7];
          if(r_count == 12'd2033)
            r_state <= SEND_ADDR5;
        end
        SEND_ADDR5  :
        begin
          r_obit <= sensor_address_plus_read[6];
          if(r_count == 12'd2053)
            r_state <= SEND_ADDR4;
        end
        SEND_ADDR4  :
        begin
          r_obit <= sensor_address_plus_read[5];
          if(r_count == 12'd2073)
            r_state <= SEND_ADDR3;
        end
        SEND_ADDR3  :
        begin
          r_obit <= sensor_address_plus_read[4];
          if(r_count == 12'd2093)
            r_state <= SEND_ADDR2;
        end
        SEND_ADDR2  :
        begin
          r_obit <= sensor_address_plus_read[3];
          if(r_count == 12'd2113)
            r_state <= SEND_ADDR1;
        end
        SEND_ADDR1  :
        begin
          r_obit <= sensor_address_plus_read[2];
          if(r_count == 12'd2133)
            r_state <= SEND_ADDR0;
        end
        SEND_ADDR0  :
        begin
          r_obit <= sensor_address_plus_read[1];
          if(r_count == 12'd2153)
            r_state <= SEND_RW;
        end
        SEND_RW     :
        begin
          r_obit <= sensor_address_plus_read[0];
          if(r_count == 12'd2169)
            r_state <= REC_ACK;
        end
        REC_ACK     :
        begin
          if(r_count == 12'd2189)
            r_state <= REC_MSB7;
        end
        REC_MSB7     :
        begin
          r_MSB[7] <= i_bit;
          if(r_count == 12'd2209)
            r_state <= REC_MSB6;

        end
        REC_MSB6     :
        begin
          r_MSB[6] <= i_bit;
          if(r_count == 12'd2229)
            r_state <= REC_MSB5;

        end
        REC_MSB5     :
        begin
          r_MSB[5] <= i_bit;
          if(r_count == 12'd2249)
            r_state <= REC_MSB4;

        end
        REC_MSB4     :
        begin
          r_MSB[4] <= i_bit;
          if(r_count == 12'd2269)
            r_state <= REC_MSB3;

        end
        REC_MSB3     :
        begin
          r_MSB[3] <= i_bit;
          if(r_count == 12'd2289)
            r_state <= REC_MSB2;

        end
        REC_MSB2     :
        begin
          r_MSB[2] <= i_bit;
          if(r_count == 12'd2309)
            r_state <= REC_MSB1;

        end
        REC_MSB1     :
        begin
          r_MSB[1] <= i_bit;
          if(r_count == 12'd2329)
            r_state <= REC_MSB0;

        end
        REC_MSB0     :
        begin
          r_obit <= 1'b0;
          r_MSB[0] <= i_bit;
          if(r_count == 12'd2349)
            r_state <= SEND_ACK;

        end
        SEND_ACK   :
        begin
          if(r_count == 12'd2369)
            r_state <= REC_LSB7;
        end
        REC_LSB7    :
        begin
          r_LSB[7] <= i_bit;
          if(r_count == 12'd2389)
            r_state <= REC_LSB6;
        end
        REC_LSB6    :
        begin
          r_LSB[6] <= i_bit;
          if(r_count == 12'd2409)
            r_state <= REC_LSB5;
        end
        REC_LSB5    :
        begin
          r_LSB[5] <= i_bit;
          if(r_count == 12'd2429)
            r_state <= REC_LSB4;
        end
        REC_LSB4    :
        begin
          r_LSB[4] <= i_bit;
          if(r_count == 12'd2449)
            r_state <= REC_LSB3;
        end
        REC_LSB3    :
        begin
          r_LSB[3] <= i_bit;
          if(r_count == 12'd2469)
            r_state <= REC_LSB2;
        end
        REC_LSB2    :
        begin
          r_LSB[2] <= i_bit;
          if(r_count == 12'd2489)
            r_state <= REC_LSB1;
        end
        REC_LSB1    :
        begin
          r_LSB[1] <= i_bit;
          if(r_count == 12'd2509)
            r_state <= REC_LSB0;
        end
        REC_LSB0    :
        begin
          r_obit <= 1'b1;
          r_LSB[0] <= i_bit;
          if(r_count == 12'd2529)
            r_state <= NACK;
        end
        NACK        :
        begin
          if(r_count == 12'd2559)
          begin
            r_count <= 12'd2000;
            r_state <= START;
          end
        end
      endcase
    end
  end
  //===========================================================
  //
  // Buffer for temperature data
  always @(posedge i_CLK)
    if(r_stage == NACK)
      r_temp_data <= { r_MSB[6:0], r_LSB[7] };

  // Control direction of SDA bidirectional inout signal
  assign r_SDA_dir = (r_stage == POWER_UP || r_stage == START || r_stage == SEND_ADDR6 || r_stage == SEND_ADDR5 ||
                      r_stage == SEND_ADDR4 || r_stage == SEND_ADDR3 || r_stage == SEND_ADDR2 || r_stage == SEND_ADDR1 ||
                      r_stage == SEND_ADDR0 || r_stage == SEND_RW || r_stage == SEND_ACK || r_stage == NACK) ? 1 : 0;
  // Set the value of SDA for output - from master to sensor
  assign io_SDA = r_SDA_dir ? r_obit : 1'bz;
  // Set value of input wire when SDA is used as an input - from sensor to master
  assign i_bit = io_SDA;
  // Outputted temperature data
  assign o_temp_data = r_temp_data;
  //============================================================
endmodule

