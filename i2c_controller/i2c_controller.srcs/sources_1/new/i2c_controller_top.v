`timescale 1ns/1ps

module i2c_controller_top
(
  input              i_clk,            // 100 MHz
  input              reset_n,

  input       [7:0]  i_addr_w_rw,      // 7b dia chi + bit R/W (LSB)
  input      [15:0]  i_sub_addr,       // sub addr
  input              i_sub_len,        // 0: 8b, 1: 16b
  input      [23:0]  i_byte_len,       // so byte doc/ghi
  input       [7:0]  i_data_write,     // du lieu ghi (cap theo tung byte)
  input              req_trans,        // yeu cau bat dau giao dich

  // read out
  output reg  [7:0]  data_out,
  output reg         valid_out,

  // i2c lines (open drain)
  inout              scl_o,
  inout              sda_o,

  // handshakes / trang thai
  output reg         req_data_chunk,   // xin master cap tiep 1 byte i_data_write
  output reg         busy,
  output reg         nack
);

  // ====== tham so ======
  // 100MHz -> 400kHz: 100e6 / (2 * 400e3) = 125
  localparam integer DIV_100MHZ       = 125;

  // ====== trang thai toi gian ======
  typedef enum logic [3:0] {
    S_IDLE       = 4'd0,
    S_START      = 4'd1,
    S_SEND_BYTE  = 4'd2,
    S_RECV_BYTE  = 4'd3,
    S_ACK_RX     = 4'd4,   // nhan ack/nack tu slave (sau khi gui byte)
    S_ACK_TX     = 4'd5,   // phat ack/nack toi slave (sau khi nhan byte)
    S_RESTART    = 4'd6,
    S_STOP       = 4'd7,
    S_RELEASE    = 4'd8
  } state_t;

  state_t state, next_state;

  // ====== dong ho 400kHz ======
  reg        en_scl;
  reg [15:0] div_cnt;
  reg        clk_i2c;            // xung SCL noi bo (day ra scl_o khi en_scl = 1)

  // ====== open-drain ======
  reg sda_drv_oe;                // 1: keo xuong 0, 0: nha bus (Z -> bi keo len bang pull-up)
  wire sda_in = sda_o;           // doc SDA (slave keo)
  assign sda_o = sda_drv_oe ? 1'b0 : 1'bz;
  assign scl_o = en_scl ? clk_i2c : 1'bz;

  // ====== thanh ghi dieu khien giao dich ======
  reg  [7:0]  addr;              // addr + rw
  reg         rw;                // 0: write, 1: read (ban dau theo i_addr_w_rw[0])
  reg  [15:0] sub_addr_r;        // sub address (MSB -> LSB)
  reg         sub16_pending;     // con 1 byte MSB chua gui (neu i_sub_len = 1)
  reg  [23:0] byte_total;        // tong so byte can doc/ghi
  reg  [23:0] byte_cnt;          // dem so byte da xu ly

  // ====== shifter / dem bit ======
  reg  [7:0]  tx_sr;
  reg  [7:0]  rx_sr;
  reg  [3:0]  bit_cnt;           // 0..7: data, 8: slot ack
  reg         last_byte;         // danh dau byte cuoi o pha doc de phat NACK

  // ====== dong bo canh SCL ======
  reg scl_q;                     // giu gia tri truoc cua clk_i2c de phat hien posedge/negedge
  wire scl_pos = ( clk_i2c & ~scl_q);
  wire scl_neg = (~clk_i2c &  scl_q);

  // ====== FSM tuan tu ======
  // Tien trinh: START -> gui (addrW) -> ACK_RX -> gui (sub) -> ACK_RX
  //  neu doc: RESTART -> gui (addrR) -> ACK_RX -> nhan bytes (ACK_TX giua cac byte, NACK o byte cuoi)
  //  neu ghi: gui cac bytes (ACK_RX sau moi byte) -> STOP -> RELEASE
  //  ca 2: ket thuc STOP -> RELEASE
  // Chu y: thay doi SDA o canh SCL xuong, lay mau SDA o canh SCL len.

  // ====== tach dong ho 400kHz ======
  always @(posedge i_clk or negedge reset_n) begin
    if (!reset_n) begin
      div_cnt <= 0;
      clk_i2c <= 1'b1;
    end else if (!en_scl) begin
      div_cnt <= 0;
      clk_i2c <= 1'b1;
    end else begin
      if (div_cnt == DIV_100MHZ-1) begin
        div_cnt <= 0;
        clk_i2c <= ~clk_i2c;
      end else begin
        div_cnt <= div_cnt + 1;
      end
    end
  end

  // ====== ghi nho SCL de tao posedge/negedge noi bo ======
  always @(posedge i_clk or negedge reset_n) begin
    if (!reset_n) scl_q <= 1'b1;
    else          scl_q <= clk_i2c;
  end

  // ====== FSM chinh ======
  always @(posedge i_clk or negedge reset_n) begin
    if (!reset_n) begin
      state           <= S_IDLE;
      next_state      <= S_IDLE;

      en_scl          <= 1'b0;
      sda_drv_oe      <= 1'b0;

      valid_out       <= 1'b0;
      req_data_chunk  <= 1'b0;
      busy            <= 1'b0;
      nack            <= 1'b0;

      addr            <= 8'd0;
      rw              <= 1'b0;
      sub_addr_r      <= 16'd0;
      sub16_pending   <= 1'b0;
      byte_total      <= 24'd0;
      byte_cnt        <= 24'd0;

      tx_sr           <= 8'd0;
      rx_sr           <= 8'd0;
      bit_cnt         <= 4'd0;
      last_byte       <= 1'b0;
      data_out        <= 8'd0;
    end
    else begin
      // mac dinh: giam nhieu xung khong can thiet
      valid_out      <= 1'b0;
      req_data_chunk <= 1'b0;

      case (state)
        // ========= IDLE =========
        S_IDLE: begin
          if (req_trans && !busy) begin
            busy          <= 1'b1;
            en_scl        <= 1'b1;
            sda_drv_oe    <= 1'b1;      // giu SDA = 0 o canh SCL cao -> START
            addr          <= i_addr_w_rw;
            rw            <= i_addr_w_rw[0];
            sub_addr_r    <= i_sub_len ? i_sub_addr : {8'h00, i_sub_addr[7:0]};
            sub16_pending <= i_sub_len; // neu 16b -> se gui MSB truoc
            byte_total    <= i_byte_len;
            byte_cnt      <= 24'd0;
            bit_cnt       <= 4'd0;
            // START: doi canh SCL xuong de bat dau gui bit 7..0
            state         <= S_START;
          end
        end

        // ========= START =========
        // Tao dieu kien START: SDA keo xuong khi SCL dang cao, sau do doi SCL xuong de shift data
        S_START: begin
          if (scl_neg) begin
            // sau START -> gui addr write (bat buoc) de set sub_addr
            tx_sr      <= {addr[7:1], 1'b0}; // ep WR khi gui lan 1
            bit_cnt    <= 4'd0;
            sda_drv_oe <= tx_sr[7];          // dat truoc cho bit MSB
            state      <= S_SEND_BYTE;
            next_state <= S_ACK_RX;
          end
        end

        // ========= SEND_BYTE =========
        // Gui 8 bit MSB->LSB, doi canh SCL xuong de dat SDA, canh SCL len de "chot"
        S_SEND_BYTE: begin
          if (scl_neg) begin
            // dat SDA = bit MSB
            sda_drv_oe <= tx_sr[7];
          end
          if (scl_pos) begin
            // da "chot" 1 bit
            tx_sr   <= {tx_sr[6:0], 1'b0};
            bit_cnt <= bit_cnt + 1;
            if (bit_cnt == 4'd7) begin
              // sau 8 bit -> nha SDA de slave phat ACK
              bit_cnt    <= 4'd0;
              sda_drv_oe <= 1'b0;   // nha bus (Z)
              state      <= next_state; // -> S_ACK_RX
            end
          end
        end

        // ========= ACK_NACK_RX =========
        // Slave keo SDA=0 -> ACK; SDA=1 -> NACK
        S_ACK_RX: begin
          if (scl_pos) begin
            if (sda_in == 1'b0) begin
              // ACK -> quyet dinh buoc tiep
              // thu tu: (1) gui sub MSB neu con, (2) gui sub LSB, (3) neu rw==1 -> RESTART + addrR, (4) else ghi data
              if (sub16_pending) begin
                // gui MSB truoc
                sub16_pending <= 1'b0;
                tx_sr      <= sub_addr_r[15:8];
                sda_drv_oe <= 1'b1;     // de san de dat bit o canh SCL xuong tiep theo
                state      <= S_SEND_BYTE;
                next_state <= S_ACK_RX;
              end
              else if (sub_addr_r[7:0] !== 8'hxx && sub_addr_r[7:0] !== 8'hzz && sub_addr_r[7:0] !== 8'h00) begin
                // gui LSB neu khac 0 (voi che do 8b hoac 16b sau khi da gui MSB)
                tx_sr         <= sub_addr_r[7:0];
                sub_addr_r[7:0] <= 8'h00; // danh dau da gui
                sda_drv_oe    <= 1'b1;
                state         <= S_SEND_BYTE;
                next_state    <= S_ACK_RX;
              end
              else begin
                // da gui xong sub addr
                if (rw) begin
                  // doc: RESTART -> gui addrR -> ACK_RX -> nhan byte
                  state      <= S_RESTART;
                end
                else begin
                  // ghi: gui byte data dau tien
                  tx_sr      <= i_data_write;
                  sda_drv_oe <= 1'b1;
                  state      <= S_SEND_BYTE;
                  next_state <= S_ACK_RX;
                end
              end
            end
            else begin
              // NACK -> dung luon
              nack       <= 1'b1;
              en_scl     <= 1'b0;
              sda_drv_oe <= 1'b0;
              busy       <= 1'b0;
              state      <= S_IDLE;
            end
          end
          else if (scl_neg) begin
            // sau khi nhan ACK xong:
            if (!rw && sub_addr_r == 16'h0000) begin
              // che do ghi data (sau khi gui xong sub), moi khi nhan ACK tu slave:
              if (byte_cnt < byte_total) begin
                // da gui 1 byte xong, xin byte moi neu chua day
                req_data_chunk <= 1'b1;
                byte_cnt       <= byte_cnt + 1;
                // nap lai du lieu moi vao tx_sr o chu ky tiep
              end
              else begin
                // het du lieu -> STOP
                state <= S_STOP;
              end
            end
            else if (rw && (sub_addr_r == 16'h0000) && !sub16_pending) begin
              // che do doc: sau RESTART + addrR + ACK_RX xong -> RECV
              // nhay sang nhan byte
              if (byte_cnt < byte_total) begin
                bit_cnt    <= 4'd0;
                last_byte  <= (byte_cnt == byte_total-1);
                state      <= S_RECV_BYTE;
              end else begin
                state <= S_STOP;
              end
            end
          end

          // nap du lieu ghi moi (neu vua yeu cau)
          if (req_data_chunk) begin
            // pulsing 1 chu ky
            req_data_chunk <= 1'b0;
            // gan du lieu moi vao tx_sr de gui tiep
            tx_sr      <= i_data_write;
            sda_drv_oe <= 1'b1;
            state      <= S_SEND_BYTE;
            next_state <= S_ACK_RX;
          end
        end

        // ========= RESTART =========
        // SDA len 1 (nha bus) -> SCL len 1 -> keo SDA=0 khi SCL cao -> bat dau gui addrR
        S_RESTART: begin
          // nha SDA truoc
          sda_drv_oe <= 1'b0;
          if (scl_pos) begin
            // khi SCL len -> keo lai START (SDA=0 trong luc SCL cao)
            sda_drv_oe <= 1'b1; // keo 0
            // sau do o canh SCL xuong -> bat dau shift addrR
          end
          if (scl_neg) begin
            tx_sr      <= {addr[7:1], 1'b1}; // addr + R
            bit_cnt    <= 4'd0;
            sda_drv_oe <= tx_sr[7];
            state      <= S_SEND_BYTE;
            next_state <= S_ACK_RX;
          end
        end

        // ========= RECV_BYTE =========
        // Nhan 8 bit MSB->LSB o canh SCL len; SDA nha bus
        S_RECV_BYTE: begin
          sda_drv_oe <= 1'b0; // nha bus de slave day du lieu
          if (scl_pos) begin
            rx_sr   <= {rx_sr[6:0], sda_in};
            bit_cnt <= bit_cnt + 1;
            if (bit_cnt == 4'd7) begin
              // doc xong 8 bit -> phat ACK/NACK o canh SCL xuong tiep theo
              bit_cnt    <= 4'd0;
              state      <= S_ACK_TX;
            end
          end
        end

        // ========= ACK_NACK_TX =========
        // Phat ACK (keo 0) neu chua phai byte cuoi, NACK (nha) neu la byte cuoi
        S_ACK_TX: begin
          if (scl_neg) begin
            sda_drv_oe <= last_byte ? 1'b0 : 1'b1; // ACK: 0, NACK: Z
          end
          if (scl_pos) begin
            // hoan tat phat ack/nack -> xuat du lieu ra, tang dem, quyet dinh tiep
            data_out  <= rx_sr;
            valid_out <= 1'b1;
            byte_cnt  <= byte_cnt + 1;

            if (last_byte) begin
              // da nhan xong -> STOP
              sda_drv_oe <= 1'b0;
              state      <= S_STOP;
            end else begin
              // nhan tiep
              last_byte  <= (byte_cnt + 1 == byte_total);
              state      <= S_RECV_BYTE;
            end
          end
        end

        // ========= STOP =========
        // keo SDA=0 khi SCL thap, doi SCL len, nha SDA -> stop
        S_STOP: begin
          if (scl_neg) begin
            sda_drv_oe <= 1'b1; // keo 0 truoc
          end
          if (scl_pos) begin
            sda_drv_oe <= 1'b0; // nha -> SDA len 1 (nhho pull-up) khi SCL dang cao -> STOP
            state      <= S_RELEASE;
          end
        end

        // ========= RELEASE =========
        // nha bus, tat 400k, ve idle
        S_RELEASE: begin
          en_scl     <= 1'b0;
          busy       <= 1'b0;
          sda_drv_oe <= 1'b0;
          state      <= S_IDLE;
        end

        default: state <= S_IDLE;
      endcase
    end
  end

endmodule
