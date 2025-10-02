`timescale 1ns/1ps

module i2c_master #
(
  parameter [7:0] P_ADDR_R   = 8'h97, // 7-bit addr<<1 | 1 (read)
  parameter [7:0] P_REG_ADDR = 8'h00  // thanh ghi can doc (1 byte)
)
(
  input  wire       i_clk_200k,     // clock he thong 200 kHz
  input  wire       i_rst,          // RESET dong bo, active-HIGH
  inout  wire       io_sda,         // I2C SDA (open-drain)
  output wire       o_scl,          // I2C SCL (10 kHz)
  output wire [7:0] o_temp_data     // {tMSB[6:0], tLSB[7]}
);

  // ==============================
  // Tao SCL 10 kHz tu 200 kHz
  // ==============================
  reg  [3:0] r_div10   = 4'd0;
  reg        r_scl     = 1'b1;      // idle high
  assign o_scl = r_scl;

  always @(posedge i_clk_200k) begin
    if (i_rst) begin
      r_div10 <= 4'd0;
      r_scl   <= 1'b1;              // giu idle high sau reset
    end else begin
      if (r_div10 == 4'd9) begin
        r_div10 <= 4'd0;
        r_scl   <= ~r_scl;
      end else begin
        r_div10 <= r_div10 + 4'd1;
      end
    end
  end

  // Canh len/xuong SCL de dong bo FSM
  reg  r_scl_d;
  wire w_scl_rise = ( o_scl==1'b1 && r_scl_d==1'b0 );
  wire w_scl_fall = ( o_scl==1'b0 && r_scl_d==1'b1 );
  always @(posedge i_clk_200k) begin
    if (i_rst) r_scl_d <= 1'b1;     // khop voi idle SCL=1
    else       r_scl_d <= o_scl;
  end

  // ==============================
  // SDA open-drain: keo 0 hoac tha Z
  // ==============================
  reg  r_sda_drive0;                 // 1: keo 0, 0: Z
  assign io_sda = r_sda_drive0 ? 1'b0 : 1'bz;
  wire w_sda_in = io_sda;           
        // luc nao gui di thi sda co gia tri 0 hoac 1, khi doc ve thi thi keo ve 1'bz, luc output la 0 hoac 1, input = 1'bz, de input = 1'bz, co the kiem tra gia tri qua chan nay luon
  // ==============================
  // Thanh ghi du lieu
  // ==============================
  reg  [7:0] r_tmsb = 8'h00;
  reg  [7:0] r_tlsb = 8'h00;
  reg  [7:0] r_temp_data;
  assign o_temp_data = r_temp_data;

  // Tinh ADDR+W tu P_ADDR_R
  wire [7:0] w_addr_w = {P_ADDR_R[7:1], 1'b0};

  // ==============================
  // FSM I2C co pha ghi reg truoc khi doc
  // ==============================
  localparam [3:0]
    S_POWERUP = 4'd0,   // doi khoi dong ~10ms
    S_STARTW  = 4'd1,   // START pha WRITE
    S_ADDRW   = 4'd2,   // gui addr+W
    S_ACKAW   = 4'd3,   // nhan ACK cho addr+W
    S_REG     = 4'd4,   // gui byte thanh ghi
    S_ACKR    = 4'd5,   // nhan ACK cho REG
    S_RSTART  = 4'd6,   // repeated START
    S_ADDRR   = 4'd7,   // gui addr+R
    S_ACKAR   = 4'd8,   // nhan ACK cho addr+R
    S_RMSB    = 4'd9,   // nhan 8 bit MSB
    S_MACK    = 4'd10,  // master ACK sau MSB
    S_RLSB    = 4'd11,  // nhan 8 bit LSB
    S_MNACK   = 4'd12,  // master NACK sau LSB
    S_STOP    = 4'd13;  // STOP logic (lap lai)

  reg [3:0]  r_state = S_POWERUP;
  reg [2:0]  r_bitc  = 3'd7;         // dem bit 7..0
  reg [7:0]  r_txb;                  // byte dang phat
  reg [13:0] r_puc  = 14'd0;         // dem power-up: 2000 tick ~10ms @200k

  // ==============================
  // FSM: thiet lap SDA khi SCL LOW, lay mau khi SCL HIGH
  // ==============================
  always @(posedge i_clk_200k) begin
    if (i_rst) begin
      // Reset tat ca thanh ghi noi bo
      r_sda_drive0 <= 1'b0; // tha SDA
      r_tmsb       <= 8'h00;
      r_tlsb       <= 8'h00;
      r_temp_data  <= 8'h00;
      r_state      <= S_POWERUP;
      r_bitc       <= 3'd7;
      r_txb        <= 8'h00;
      r_puc        <= 14'd0;
    end else begin
      case (r_state)
        // --------- POWERUP ---------
        S_POWERUP: begin
          r_sda_drive0 <= 1'b0;       // tha SDA (high)
          if (r_puc == 14'd1999) begin
            r_puc   <= 14'd0;
            r_state <= S_STARTW;
          end else begin
            r_puc <= r_puc + 14'd1;
          end
        end

        // --------- START (WRITE) ---------
        S_STARTW: begin
          r_sda_drive0 <= 1'b1;       // SDA=0 khi SCL=1 -> START
          if (w_scl_fall) begin
            r_state <= S_ADDRW;
            r_bitc  <= 3'd7;
            r_txb   <= w_addr_w;
          end
        end

        // --------- SEND ADDR+W ---------
        S_ADDRW: begin
          if (w_scl_fall) r_sda_drive0 <= (r_txb[r_bitc]==1'b0); // 0->keo 0, 1->Z
          if (w_scl_rise) begin
            if (r_bitc == 3'd0) begin
              r_state      <= S_ACKAW;
              r_sda_drive0 <= 1'b0;   // tha de slave ACK
            end else begin
              r_bitc <= r_bitc - 3'd1;
            end
          end
        end

        // --------- ACK cho ADDR+W ---------
        S_ACKAW: begin
          if (w_scl_rise) begin       // bo qua check NACK de don gian
            r_bitc <= 3'd7;
            r_state<= S_REG;
          end
        end

        // --------- GUI BYTE REG ---------
        S_REG: begin
          if (w_scl_fall) r_sda_drive0 <= (P_REG_ADDR[r_bitc]==1'b0);
          if (w_scl_rise) begin
            if (r_bitc==3'd0) begin
              r_state      <= S_ACKR;
              r_sda_drive0 <= 1'b0;   // tha de slave ACK
            end else begin
              r_bitc <= r_bitc - 3'd1;
            end
          end
        end

        // --------- ACK cho REG ---------
        S_ACKR: begin
          if (w_scl_rise) begin
            r_state <= S_RSTART;
          end
        end

        // --------- REPEATED START ---------
        S_RSTART: begin
          r_sda_drive0 <= 1'b1;       // SDA=0 khi SCL=1
          if (w_scl_fall) begin
            r_state <= S_ADDRR;
            r_bitc  <= 3'd7;
            r_txb   <= P_ADDR_R;
          end
        end

        // --------- SEND ADDR+R ---------
        S_ADDRR: begin
          if (w_scl_fall) r_sda_drive0 <= (r_txb[r_bitc]==1'b0);
          if (w_scl_rise) begin
            if (r_bitc == 3'd0) begin
              r_state      <= S_ACKAR;
              r_sda_drive0 <= 1'b0;   // tha de slave ACK
            end else begin
              r_bitc <= r_bitc - 3'd1;
            end
          end
        end

        // --------- ACK cho ADDR+R ---------
        S_ACKAR: begin
          if (w_scl_rise) begin
            r_bitc <= 3'd7;
            r_state<= S_RMSB;
          end
        end

        // --------- DOC MSB ---------
        S_RMSB: begin
          r_sda_drive0 <= 1'b0;       // tha de slave day du lieu
          if (w_scl_rise) begin
            r_tmsb[r_bitc] <= w_sda_in;
            if (r_bitc==3'd0) r_state <= S_MACK;
            else              r_bitc  <= r_bitc - 3'd1;
          end
        end

        // --------- MASTER ACK sau MSB ---------
        S_MACK: begin
          if (w_scl_fall) r_sda_drive0 <= 1'b1; // keo 0 trong bit ACK
          if (w_scl_rise) begin
            r_sda_drive0 <= 1'b0;
            r_bitc <= 3'd7;
            r_state <= S_RLSB;
          end
        end

        // --------- DOC LSB ---------
        S_RLSB: begin
          r_sda_drive0 <= 1'b0;
          if (w_scl_rise) begin
            r_tlsb[r_bitc] <= w_sda_in;
            if (r_bitc==3'd0) r_state <= S_MNACK;
            else              r_bitc  <= r_bitc - 3'd1;
          end
        end

        // --------- MASTER NACK sau LSB ---------
        S_MNACK: begin
          r_sda_drive0 <= 1'b0;       // NACK = tha
          if (w_scl_rise) r_state <= S_STOP;
        end

        // --------- STOP + cap nhat du lieu ---------
        S_STOP: begin
          r_sda_drive0 <= 1'b0;       // tha SDA (khong tao STOP thuc su)
          r_temp_data  <= { r_tmsb[6:0], r_tlsb[7] };
          r_state      <= S_STARTW;   // lap lai: viet reg -> doc
        end

        default: r_state <= S_POWERUP;
      endcase
    end
  end

endmodule
