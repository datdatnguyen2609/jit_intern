`timescale 1ns/1ps
// ===================================================================
// I2C Master (Open-Drain) - sync-only reset, single-if style per state
// - START / RESTART / STOP
// - Write 1 register, optional Read N bytes (0 => write only)
// - NACK detect, busy/done flags
// - Read stream: (o_rd_valid, o_rd_data)
// ===================================================================
module i2c_master #(
  parameter integer CLK_HZ = 100_000_000,
  parameter integer SCL_HZ = 100_000
)(
  input  wire        i_clk,
  input  wire        i_rst_n,        // sync active-low reset

  // Request (pulse i_start for 1 clk)
  input  wire        i_start,
  input  wire [6:0]  i_dev_addr,
  input  wire [7:0]  i_reg_addr,
  input  wire [7:0]  i_wr_data,
  input  wire [7:0]  i_read_len,

  // Status / result
  output reg         o_busy,
  output reg         o_done,
  output reg         o_nack,

  // Read stream
  output reg  [7:0]  o_rd_data,
  output reg         o_rd_valid,

  // I2C bus (OPEN-DRAIN) - external pull-ups required
  inout  wire        io_SDA,
  inout  wire        io_SCL
);

  // ========================= Open-Drain ============================
  reg  r_sda_lo, r_scl_lo;     // 1 => pull LOW, 0 => release (Z)
  assign io_SDA = r_sda_lo ? 1'b0 : 1'bz;
  assign io_SCL = r_scl_lo ? 1'b0 : 1'bz;

  wire w_sda_in = io_SDA;      // sample SDA
  wire w_scl_in = io_SCL;      // (clock stretching not handled)

  // ========================= Bit Phasing ===========================
  localparam integer PHASES_PER_BIT      = 4;
  localparam integer TICKS_PER_PHASE_INT = (CLK_HZ / (SCL_HZ * PHASES_PER_BIT));
  localparam integer TICKS_PER_PHASE     = (TICKS_PER_PHASE_INT < 1) ? 1 : TICKS_PER_PHASE_INT;
  localparam integer TICK_W              = (TICKS_PER_PHASE <= 1) ? 1 : $clog2(TICKS_PER_PHASE);

  reg [TICK_W-1:0] r_tick_cnt;
  reg [1:0]        r_phase;      // 0..3
  reg              r_phase_en;   // 1-clk pulse per phase advance

  // Pha d?ng c? ?? "single-if per state"
  wire p0      = (r_phase == 2'd0);
  wire p1      = (r_phase == 2'd1);
  wire p2      = (r_phase == 2'd2);
  wire p3      = (r_phase == 2'd3);
  wire last_p  = p3;

  // ========================= FSM ===============================
  localparam [4:0]
    ST_IDLE        = 5'd0,
    ST_START_A     = 5'd1,
    ST_ADDRW_BIT   = 5'd2,
    ST_ADDRW_ACK   = 5'd3,
    ST_REG_BIT     = 5'd4,
    ST_REG_ACK     = 5'd5,
    ST_RESTART_A   = 5'd6,
    ST_RESTART_B   = 5'd7,
    ST_ADDRR_BIT   = 5'd8,
    ST_ADDRR_ACK   = 5'd9,
    ST_READ_BIT    = 5'd10,
    ST_READ_ACK    = 5'd11,
    ST_DATAW_BIT   = 5'd12,
    ST_DATAW_ACK   = 5'd13,
    ST_STOP_A      = 5'd14,
    ST_DONE        = 5'd16,
    ST_ERROR       = 5'd17;

  reg [4:0] r_state;

  // Shift/Data regs
  reg [7:0] r_shifter;
  reg [2:0] r_bit_cnt;          // 7..0
  reg [7:0] r_rd_byte;
  reg [7:0] r_rd_target;        // latched i_read_len
  reg [7:0] r_rd_idx;

  // Latched inputs
  reg [6:0] r_dev_addr_q;
  reg [7:0] r_reg_addr_q;
  reg [7:0] r_wr_data_q;

  // ========================= Sequential Core =======================
  always @(posedge i_clk) begin
    // -------- default pulses --------
    o_done     <= 1'b0;
    o_rd_valid <= 1'b0;

    // ======= synchronous reset =======
    if (!i_rst_n) begin
      // Phase generator
      r_tick_cnt <= {TICK_W{1'b0}};
      r_phase_en <= 1'b0;
      r_phase    <= 2'd0;

      // I2C lines (idle released -> HIGH via pull-ups)
      r_sda_lo   <= 1'b0;
      r_scl_lo   <= 1'b0;

      // Outputs / flags
      o_busy     <= 1'b0;
      o_done     <= 1'b0;
      o_nack     <= 1'b0;
      o_rd_data  <= 8'h00;

      // FSM/data
      r_state      <= ST_IDLE;
      r_shifter    <= 8'h00;
      r_bit_cnt    <= 3'd7;
      r_rd_byte    <= 8'h00;
      r_rd_target  <= 8'd0;
      r_rd_idx     <= 8'd0;
      r_dev_addr_q <= 7'd0;
      r_reg_addr_q <= 8'd0;
      r_wr_data_q  <= 8'd0;

    end else begin
      // -------- phase tick --------
      if (r_tick_cnt == TICKS_PER_PHASE-1) begin
        r_tick_cnt <= {TICK_W{1'b0}};
        r_phase_en <= 1'b1;
      end else begin
        r_tick_cnt <= r_tick_cnt + {{(TICK_W-1){1'b0}},1'b1};
        r_phase_en <= 1'b0;
      end

      // -------- SCL waveform per phase (??ng b?) --------
      if (r_phase_en) begin
        // single-if theo pha: n?u không ph?i p0/p1/p3 thì gi? nguyên
        if (p0 || p1 || p3) begin
          r_scl_lo <= p0 ? 1'b1 : (p1 ? 1'b0 : 1'b1);
        end
      end

      // -------------------- FSM --------------------
      if (r_phase_en) begin
        case (r_state)

          // ===================== IDLE =====================
          ST_IDLE: begin
            // single-if per state
            if (i_start) begin
              o_busy       <= 1'b1;
              o_nack       <= 1'b0;
              r_dev_addr_q <= i_dev_addr;
              r_reg_addr_q <= i_reg_addr;
              r_wr_data_q  <= i_wr_data;
              r_rd_target  <= i_read_len;
              r_bit_cnt    <= 3'd7;
              r_rd_idx     <= 8'd0;
              r_sda_lo     <= 1'b1;          // START window (SCL high)
              r_state      <= ST_START_A;
              r_phase      <= 2'd0;          // re-align minor phase
            end else begin
              o_busy   <= 1'b0;
              r_sda_lo <= 1'b0;              // release
              r_scl_lo <= 1'b0;              // release
            end
          end

          // ===================== START ====================
          ST_START_A: begin
            if (last_p) begin
              r_shifter <= {r_dev_addr_q,1'b0}; // addr + W
              r_bit_cnt <= 3'd7;
              r_state   <= ST_ADDRW_BIT;
            end else begin
              r_sda_lo <= 1'b1;               // keep SDA low across START
            end
          end

          // ===== send 8 bits: (addr+W) =====
          ST_ADDRW_BIT: begin
            if (last_p) begin
              r_shifter <= {r_shifter[6:0],1'b0};
              r_state   <= (r_bit_cnt == 3'd0) ? ST_ADDRW_ACK : ST_ADDRW_BIT;
              r_sda_lo  <= (r_bit_cnt == 3'd0) ? 1'b0 : r_sda_lo; // release for ACK
              r_bit_cnt <= (r_bit_cnt == 3'd0) ? 3'd0 : (r_bit_cnt - 3'd1);
            end else begin
              // p0: drive MSB; các pha khác gi? nguyên
              r_sda_lo <= p0 ? ~r_shifter[7] : r_sda_lo;
            end
          end

          // ===== ACK after (addr+W) =====
          ST_ADDRW_ACK: begin
            if (last_p) begin
              r_state   <= o_nack ? ST_ERROR : ST_REG_BIT;
              r_shifter <= o_nack ? r_shifter : r_reg_addr_q;
              r_bit_cnt <= o_nack ? r_bit_cnt : 3'd7;
            end else begin
              // p2 sample ACK; release SDA
              o_nack  <= (p2 && (w_sda_in == 1'b1)) ? 1'b1 : o_nack;
              r_sda_lo <= 1'b0;
            end
          end

          // ===== send 8 bits: register address =====
          ST_REG_BIT: begin
            if (last_p) begin
              r_shifter <= {r_shifter[6:0],1'b0};
              r_state   <= (r_bit_cnt == 3'd0) ? ST_REG_ACK : ST_REG_BIT;
              r_sda_lo  <= (r_bit_cnt == 3'd0) ? 1'b0 : r_sda_lo; // release for ACK
              r_bit_cnt <= (r_bit_cnt == 3'd0) ? 3'd0 : (r_bit_cnt - 3'd1);
            end else begin
              r_sda_lo <= p0 ? ~r_shifter[7] : r_sda_lo;
            end
          end

          // ===== ACK after register address =====
          ST_REG_ACK: begin
            if (last_p) begin
              r_state   <= o_nack ? ST_ERROR :
                           ((r_rd_target != 8'd0) ? ST_RESTART_A : ST_DATAW_BIT);
              r_sda_lo  <= (o_nack) ? r_sda_lo :
                           ((r_rd_target != 8'd0) ? 1'b1 : r_sda_lo); // prepare repeated START if read
              r_shifter <= (o_nack || (r_rd_target != 8'd0)) ? r_shifter : r_wr_data_q;
              r_bit_cnt <= (o_nack || (r_rd_target != 8'd0)) ? r_bit_cnt : 3'd7;
            end else begin
              o_nack  <= (p2 && (w_sda_in == 1'b1)) ? 1'b1 : o_nack;
              r_sda_lo <= 1'b0;
            end
          end

          // ===== RESTART =====
          ST_RESTART_A: begin
            if (last_p) begin
              r_state <= ST_RESTART_B;
            end else begin
              r_sda_lo <= p1 ? 1'b1 : r_sda_lo; // hold low through window
            end
          end

          ST_RESTART_B: begin
            if (last_p) begin
              r_shifter <= {r_dev_addr_q,1'b1}; // addr + R
              r_bit_cnt <= 3'd7;
              r_state   <= ST_ADDRR_BIT;
            end else begin
              r_sda_lo <= p0 ? ~r_shifter[7] : r_sda_lo;
            end
          end

          // ===== send 8 bits: (addr+R) =====
          ST_ADDRR_BIT: begin
            if (last_p) begin
              r_shifter <= {r_shifter[6:0],1'b0};
              r_state   <= (r_bit_cnt == 3'd0) ? ST_ADDRR_ACK : ST_ADDRR_BIT;
              r_sda_lo  <= (r_bit_cnt == 3'd0) ? 1'b0 : r_sda_lo; // release for ACK
              r_bit_cnt <= (r_bit_cnt == 3'd0) ? 3'd0 : (r_bit_cnt - 3'd1);
            end else begin
              r_sda_lo <= p0 ? ~r_shifter[7] : r_sda_lo;
            end
          end

          // ===== ACK after (addr+R) =====
          ST_ADDRR_ACK: begin
            if (last_p) begin
              r_state   <= o_nack ? ST_ERROR : ST_READ_BIT;
              r_bit_cnt <= o_nack ? r_bit_cnt : 3'd7;
              r_rd_byte <= o_nack ? r_rd_byte : 8'h00;
              r_rd_idx  <= o_nack ? r_rd_idx  : 8'd0;
            end else begin
              o_nack  <= (p2 && (w_sda_in == 1'b1)) ? 1'b1 : o_nack;
              r_sda_lo <= 1'b0;
            end
          end

          // ===== READ 8 bits =====
          ST_READ_BIT: begin
            if (last_p) begin
              if (r_bit_cnt == 3'd0) begin
                o_rd_data  <= r_rd_byte;
                o_rd_valid <= 1'b1;
                r_state    <= ST_READ_ACK;
              end else begin
                r_bit_cnt <= r_bit_cnt - 3'd1;
              end
            end else begin
              // p0: release SDA for slave drive; p2: sample
              r_sda_lo  <= p0 ? 1'b0 : r_sda_lo;
              r_rd_byte <= p2 ? {r_rd_byte[6:0], w_sda_in} : r_rd_byte;
            end
          end

          // ===== Master ACK/NACK =====
          ST_READ_ACK: begin
            if (last_p) begin
              r_rd_idx <= r_rd_idx + 8'd1;
              if (r_rd_idx + 8'd1 < r_rd_target) begin
                r_bit_cnt <= 3'd7;
                r_rd_byte <= 8'h00;
                r_state   <= ST_READ_BIT;
              end else begin
                r_sda_lo  <= 1'b1;      // prepare STOP
                r_state   <= ST_STOP_A;
              end
            end else begin
              // p0: drive ACK(0) if còn ??c; NACK(1) n?u là byte cu?i
              r_sda_lo <= p0 ? ((r_rd_idx + 8'd1 < r_rd_target) ? 1'b1 : 1'b0) : r_sda_lo;
            end
          end

          // ===== WRITE data byte =====
          ST_DATAW_BIT: begin
            if (last_p) begin
              r_shifter <= {r_shifter[6:0],1'b0};
              r_state   <= (r_bit_cnt == 3'd0) ? ST_DATAW_ACK : ST_DATAW_BIT;
              r_sda_lo  <= (r_bit_cnt == 3'd0) ? 1'b0 : r_sda_lo; // release for ACK
              r_bit_cnt <= (r_bit_cnt == 3'd0) ? 3'd0 : (r_bit_cnt - 3'd1);
            end else begin
              r_sda_lo <= p0 ? ~r_shifter[7] : r_sda_lo;
            end
          end

          ST_DATAW_ACK: begin
            if (last_p) begin
              if (o_nack) begin
                r_state <= ST_ERROR;
              end else begin
                r_sda_lo <= 1'b1;                 // pull low before STOP window
                r_state  <= ST_STOP_A;
              end
            end else begin
              o_nack <= (p2 && (w_sda_in == 1'b1)) ? 1'b1 : o_nack;
            end
          end

          // ===== STOP: SDA rising while SCL HIGH =====
          ST_STOP_A: begin
            if (last_p) begin
              r_state <= ST_DONE;
            end else begin
              // p1: release SCL(high), p2: release SDA (rising)
              r_scl_lo <= p1 ? 1'b0 : r_scl_lo;
              r_sda_lo <= p2 ? 1'b0 : r_sda_lo;
            end
          end

          // ===== DONE =====
          ST_DONE: begin
            if (1'b1) begin // single-if gi? form
              o_busy  <= 1'b0;
              o_done  <= 1'b1;
              r_state <= ST_IDLE;
            end
          end

          // ===== ERROR -> STOP safely =====
          ST_ERROR: begin
            if (last_p) begin
              o_busy  <= 1'b0;
              o_done  <= 1'b1;
              r_state <= ST_IDLE;
            end else begin
              // p0: both low, p1: release SCL, p2: release SDA
              r_sda_lo <= p0 ? 1'b1 : (p2 ? 1'b0 : r_sda_lo);
              r_scl_lo <= p0 ? 1'b1 : (p1 ? 1'b0 : r_scl_lo);
            end
          end

          default: begin
            if (1'b1) r_state <= ST_IDLE;
          end
        endcase

        // advance minor phase
        r_phase <= r_phase + 2'd1;
      end
    end
  end
endmodule
