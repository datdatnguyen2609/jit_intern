`timescale 1ns/1ps

module i2c_master #(
  parameter integer CLK_HZ = 100_000_000,
  parameter integer SCL_HZ = 400_000
)(
  input  wire        i_clk,
  input  wire        i_rst_n,       // reset dong bo, active-low

  // Yeu cau giao dich
  input  wire        i_start,       // xung 1 chu ky -> bat dau giao dich
  input  wire        i_op,          // 0=write, 1=read
  input  wire [7:0]  i_reg_addr,    // thanh ghi trong ADT7420 (vd 8'h00)
  input  wire [15:0] i_wr_data,     // du lieu ghi (neu write)
  input  wire [7:0]  i_read_len,    // so byte doc (1 hoac 2)

  // Trang thai / ket qua
  output reg         o_busy,
  output reg         o_done,
  output reg         o_nack,
  output reg         o_rd_valid,
  output reg [7:0]   o_rd_byte,
  output reg [15:0]  o_rd_word,

  // Bus I2C
  inout  wire        io_sda,        // SDA open-drain
  output wire        o_scl          // SCL push-pull (master)
);

  // ---------------- Hang so ADT7420 ----------------
  localparam [6:0] DEV7   = 7'h48;            // 7-bit addr
  localparam [7:0] ADDR_W = {DEV7,1'b0};      // 0x90
  localparam [7:0] ADDR_R = {DEV7,1'b1};      // 0x91

  // ---------------- CLOG2 cho Verilog 2001 ----------------
  function integer CLOG2;
    input integer v;
    integer i;
    begin
      v = v - 1;
      for (i=0; v>0; i=i+1) v = v >> 1;
      CLOG2 = i;
    end
  endfunction

  // ---------------- Bo tao SCL 4 pha (dong bo) ----------------
  localparam integer DIV4  = (CLK_HZ / (SCL_HZ*4));
  localparam integer CNT_W = (DIV4>1) ? CLOG2(DIV4) : 1;

  reg [CNT_W-1:0] r_div_cnt;
  reg [1:0]       r_phase;        // 0..3
  reg             r_phase_tick;   // len 1 moi khi doi pha
  reg             r_bit_tick;     // len 1 o cuoi pha 3 (ranh gioi 1 bit)
  reg             r_scl_q;

  wire            w_scl = r_scl_q;
  assign o_scl = w_scl;

  always @(posedge i_clk) begin
    if (!i_rst_n) begin
      r_div_cnt    <= {CNT_W{1'b0}};
      r_phase      <= 2'd0;
      r_phase_tick <= 1'b0;
      r_bit_tick   <= 1'b0;
      r_scl_q      <= 1'b1;   // idle high
    end else begin
      r_phase_tick <= 1'b0;
      r_bit_tick   <= 1'b0;

      if (o_busy) begin
        if (r_div_cnt == DIV4-1) begin
          r_div_cnt    <= {CNT_W{1'b0}};
          r_phase      <= r_phase + 2'd1;
          r_phase_tick <= 1'b1;
          case (r_phase)
            2'd0: r_scl_q <= 1'b0;
            2'd1: r_scl_q <= 1'b1;  // sang HIGH (phase 2)
            2'd2: r_scl_q <= 1'b1;
            2'd3: begin
              r_scl_q    <= 1'b0;   // ve LOW (phase 0)
              r_bit_tick <= 1'b1;   // xong 1 bit
            end
          endcase
        end else begin
          r_div_cnt <= r_div_cnt + {{(CNT_W-1){1'b0}},1'b1};
        end
      end else begin
        r_div_cnt    <= {CNT_W{1'b0}};
        r_phase      <= 2'd0;
        r_phase_tick <= 1'b0;
        r_bit_tick   <= 1'b0;
        r_scl_q      <= 1'b1;
      end
    end
  end

  // ---------------- SDA open-drain ----------------
  reg  r_sda_drive0;               // 1 => keo 0; 0 => Z
  assign io_sda = r_sda_drive0 ? 1'b0 : 1'bz;

  // ---------------- FSM ma trang thai ----------------
  localparam [4:0]
    S_IDLE        = 5'd0,
    S_START       = 5'd1,
    S_ADDR_W      = 5'd2,
    S_ACK1        = 5'd3,
    S_REG         = 5'd4,
    S_ACK2        = 5'd5,
    S_REP_START   = 5'd6,
    S_ADDR_R      = 5'd7,
    S_ACK3        = 5'd8,
    S_READ        = 5'd9,
    S_MACK        = 5'd10,
    S_MNACK       = 5'd11,
    S_WRITE       = 5'd12,
    S_ACKW        = 5'd13,
    S_STOP        = 5'd14;

  // ---------------- Thanh ghi trang thai & du lieu ----------------
  reg [4:0]  r_state, r_state_nxt;

  reg [7:0]  r_tx_byte, r_tx_byte_nxt;
  reg [7:0]  r_rx_byte, r_rx_byte_nxt;
  reg [2:0]  r_bit_cnt, r_bit_cnt_nxt;   // 7..0
  reg [7:0]  r_rd_left, r_rd_left_nxt;   // so byte con lai de doc
  reg [1:0]  r_wr_left, r_wr_left_nxt;   // so byte con lai de ghi (0..2)
  reg        r_ack_sampled;              // mau SDA o phase==2
  reg        r_ack_err_nxt;
  reg [15:0] r_word_acc, r_word_acc_nxt; // ghep MSB:LSB khi doc 2 byte

  // ------------ Mau ACK/NACK (SCL HIGH) ------------
  always @(posedge i_clk) begin
    if (!i_rst_n) begin
      r_ack_sampled <= 1'b1;
    end else if (o_busy && (r_phase==2'd2) && r_phase_tick) begin
      r_ack_sampled <= io_sda;   // 0=ACK, 1=NACK
    end
  end

  // ---------------- FSM + dieu khien SDA (combinational) ----------------
  reg r_sda_drive0_nxt;
  wire w_tx_bit_is0 = (r_tx_byte[r_bit_cnt]==1'b0);
  wire w_scl_low    = (r_phase==2'd0) || (r_phase==2'd1);

  always @* begin
    // Mac dinh giu nguyen
    r_state_nxt     = r_state;
    r_tx_byte_nxt   = r_tx_byte;
    r_rx_byte_nxt   = r_rx_byte;
    r_bit_cnt_nxt   = r_bit_cnt;
    r_rd_left_nxt   = r_rd_left;
    r_wr_left_nxt   = r_wr_left;
    r_word_acc_nxt  = r_word_acc;
    r_ack_err_nxt   = o_nack;
    r_sda_drive0_nxt= 1'b0;            // tha Z mac dinh

    case (r_state)
      // -------------------------------------------------------
      S_IDLE: begin
        r_sda_drive0_nxt = 1'b0;
        if (i_start) begin
          r_rd_left_nxt = i_read_len;
          r_wr_left_nxt = (i_op==1'b0) ? 2'd2 : 2'd0;
          r_bit_cnt_nxt = 3'd7;
          r_state_nxt   = S_START;
        end
      end

      // -------------------------------------------------------
      S_START: begin
        // START: SDA=0 khi SCL=1
        r_sda_drive0_nxt = 1'b1;
        if (r_bit_tick) begin
          r_tx_byte_nxt = ADDR_W;
          r_bit_cnt_nxt = 3'd7;
          r_state_nxt   = S_ADDR_W;
        end
      end

      // -------------------------------------------------------
      S_ADDR_W: begin
        // Phat bit: keo 0 neu bit=0 va SCL dang LOW
        r_sda_drive0_nxt = (w_scl_low && w_tx_bit_is0);
        if (r_bit_tick) begin
          if (r_bit_cnt==3'd0) r_state_nxt = S_ACK1;
          else                 r_bit_cnt_nxt = r_bit_cnt - 3'd1;
        end
      end

      // -------------------------------------------------------
      S_ACK1: begin
        // Tha Z de slave ACK
        r_sda_drive0_nxt = 1'b0;
        if ((r_phase==2'd2) && r_phase_tick && (r_ack_sampled==1'b1)) begin
          r_ack_err_nxt = 1'b1;        // NACK
          r_state_nxt   = S_STOP;
        end
        if (r_bit_tick) begin
          r_tx_byte_nxt = i_reg_addr;
          r_bit_cnt_nxt = 3'd7;
          r_state_nxt   = S_REG;
        end
      end

      // -------------------------------------------------------
      S_REG: begin
        r_sda_drive0_nxt = (w_scl_low && (r_tx_byte[r_bit_cnt]==1'b0));
        if (r_bit_tick) begin
          if (r_bit_cnt==3'd0) r_state_nxt = S_ACK2;
          else                 r_bit_cnt_nxt = r_bit_cnt - 3'd1;
        end
      end

      // -------------------------------------------------------
      S_ACK2: begin
        r_sda_drive0_nxt = 1'b0;
        if ((r_phase==2'd2) && r_phase_tick && (r_ack_sampled==1'b1)) begin
          r_ack_err_nxt = 1'b1;
          r_state_nxt   = S_STOP;
        end
        if (r_bit_tick) begin
          if (i_op==1'b1) begin
            r_state_nxt = S_REP_START;       // doc -> repeated START
          end else begin
            r_tx_byte_nxt = i_wr_data[15:8]; // ghi MSB truoc (vi du 16b)
            r_bit_cnt_nxt = 3'd7;
            r_state_nxt   = S_WRITE;
          end
        end
      end

      // -------------------------------------------------------
      S_REP_START: begin
        r_sda_drive0_nxt = 1'b1;             // START lai
        if (r_bit_tick) begin
          r_tx_byte_nxt = ADDR_R;
          r_bit_cnt_nxt = 3'd7;
          r_state_nxt   = S_ADDR_R;
        end
      end

      // -------------------------------------------------------
      S_ADDR_R: begin
        r_sda_drive0_nxt = (w_scl_low && (r_tx_byte[r_bit_cnt]==1'b0));
        if (r_bit_tick) begin
          if (r_bit_cnt==3'd0) r_state_nxt = S_ACK3;
          else                 r_bit_cnt_nxt = r_bit_cnt - 3'd1;
        end
      end

      // -------------------------------------------------------
      S_ACK3: begin
        r_sda_drive0_nxt = 1'b0;
        if ((r_phase==2'd2) && r_phase_tick && (r_ack_sampled==1'b1)) begin
          r_ack_err_nxt = 1'b1;
          r_state_nxt   = S_STOP;
        end
        if (r_bit_tick) begin
          r_bit_cnt_nxt = 3'd7;
          r_rx_byte_nxt = 8'h00;
          r_state_nxt   = S_READ;
        end
      end

      // -------------------------------------------------------
      S_READ: begin
        // Master tha SDA, sample o khoi sync ben duoi
        r_sda_drive0_nxt = 1'b0;
        if (r_bit_tick) begin
          if (r_bit_cnt==3'd0) begin
            // Ghep word
            if (r_rd_left==8'd2)       r_word_acc_nxt = {r_rx_byte, r_word_acc[7:0]};
            else if (r_rd_left==8'd1)  r_word_acc_nxt = {r_word_acc[15:8], r_rx_byte};
            // Quy dinh ACK/NACK
            r_state_nxt = (r_rd_left>8'd1) ? S_MACK : S_MNACK;
          end else begin
            r_bit_cnt_nxt = r_bit_cnt - 3'd1;
          end
        end
      end

      // -------------------------------------------------------
      S_MACK: begin
        r_sda_drive0_nxt = 1'b1;             // master ACK (keo 0)
        if (r_bit_tick) begin
          r_rd_left_nxt  = r_rd_left - 8'd1;
          r_bit_cnt_nxt  = 3'd7;
          r_rx_byte_nxt  = 8'h00;
          r_state_nxt    = S_READ;
        end
      end

      // -------------------------------------------------------
      S_MNACK: begin
        r_sda_drive0_nxt = 1'b0;             // master NACK (tha)
        if (r_bit_tick) begin
          r_rd_left_nxt = r_rd_left - 8'd1;
          r_state_nxt   = S_STOP;
        end
      end

      // -------------------------------------------------------
      S_WRITE: begin
        r_sda_drive0_nxt = (w_scl_low && (r_tx_byte[r_bit_cnt]==1'b0));
        if (r_bit_tick) begin
          if (r_bit_cnt==3'd0) r_state_nxt = S_ACKW;
          else                 r_bit_cnt_nxt = r_bit_cnt - 3'd1;
        end
      end

      // -------------------------------------------------------
      S_ACKW: begin
        r_sda_drive0_nxt = 1'b0;
        if ((r_phase==2'd2) && r_phase_tick && (r_ack_sampled==1'b1)) begin
          r_ack_err_nxt = 1'b1;
          r_state_nxt   = S_STOP;
        end
        if (r_bit_tick) begin
          if (r_wr_left>2'd1) begin
            r_tx_byte_nxt = i_wr_data[7:0];  // gui LSB
            r_bit_cnt_nxt = 3'd7;
            r_wr_left_nxt = r_wr_left - 2'd1;
            r_state_nxt   = S_WRITE;
          end else begin
            r_state_nxt   = S_STOP;
          end
        end
      end

      // -------------------------------------------------------
      S_STOP: begin
        r_sda_drive0_nxt = 1'b0;             // STOP: SDA len 1 khi SCL=1
        if (r_bit_tick) r_state_nxt = S_IDLE;
      end

      default: begin
        r_state_nxt = S_IDLE;
      end
    endcase
  end

  // ---------------- Cap nhat sync cac thanh ghi & output ----------------
  always @(posedge i_clk) begin
    if (!i_rst_n) begin
      r_state      <= S_IDLE;
      r_tx_byte    <= 8'h00;
      r_rx_byte    <= 8'h00;
      r_bit_cnt    <= 3'd7;
      r_rd_left    <= 8'd0;
      r_wr_left    <= 2'd0;
      r_word_acc   <= 16'h0000;

      r_sda_drive0 <= 1'b0;

      o_busy       <= 1'b0;
      o_done       <= 1'b0;
      o_nack       <= 1'b0;
      o_rd_valid   <= 1'b0;
      o_rd_byte    <= 8'h00;
      o_rd_word    <= 16'h0000;
    end else begin
      r_state      <= r_state_nxt;
      r_tx_byte    <= r_tx_byte_nxt;
      r_rx_byte    <= r_rx_byte_nxt;
      r_bit_cnt    <= r_bit_cnt_nxt;
      r_rd_left    <= r_rd_left_nxt;
      r_wr_left    <= r_wr_left_nxt;
      r_word_acc   <= r_word_acc_nxt;

      r_sda_drive0 <= r_sda_drive0_nxt;

      o_busy     <= (r_state_nxt != S_IDLE);
      o_done     <= (r_state==S_STOP && r_state_nxt==S_IDLE) ? 1'b1 : 1'b0;
      o_nack     <= r_ack_err_nxt;

      // o_rd_valid: khi vua hoan tat 1 byte o READ va sap chuyen sang MACK/MNACK
      o_rd_valid <= (r_state==S_READ && (r_bit_cnt==3'd0) && r_bit_tick &&
                     (r_state_nxt==S_MACK || r_state_nxt==S_MNACK));
      if (o_rd_valid) o_rd_byte <= r_rx_byte_nxt;
      o_rd_word <= r_word_acc_nxt;
    end
  end

  // ---------------- Ghi bit nhan khi SCL HIGH (dong bo) ----------------
  always @(posedge i_clk) begin
    if (!i_rst_n) begin
      r_rx_byte <= 8'h00;
    end else if (o_busy && r_state==S_READ && (r_phase==2'd2) && r_phase_tick) begin
      r_rx_byte[r_bit_cnt] <= io_sda;
    end
  end

endmodule
