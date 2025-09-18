module i2c_master (
  input i_clk,
  input i_rst,

  output reg o_i2c_scl,
  output reg o_i2c_sda_out,
  input      i_i2c_sda_in,
  output reg o_i2c_sda_oe,

  input [6:0] i_dev_addr, // device address
  input [7:0] i_reg_addr, // register address
  input       i_rdh_wrl, // 1 is read, 0 is write
  input       i_ready    // write and read ready
  input [7:0] i_dout     // write data
  output reg  o_dout_ack // write data acknowledge by slave device
  input [3:0] i_dout_length // the number of bytes of write and read data
  output reg [7:0] o_din,
  output reg  o_din_valid 
);
  // SCL clock generator, 100Mhz => 200khz
  reg [7:0] r_i2c_scl_counter;
  reg r_i2c_scl_en;
  reg r_i2c_scl_d;
  wire w_i2c_scl_pos;
  wire w_i2c_scl_neg;

  always @(posedge clk) begin
    if (rst | ~(r_i2c_scl_en)) begin
      r_i2c_scl_counter <= 8'd0;
      o_i2c_scl <= 1'b1;
    end
    else if (r_i2c_scl_counter < 8'd250) begin
      r_i2c_scl_counter <= r_i2c_scl_counter + 8'd1;
    end
    else begin
      r_i2c_scl_counter <= 8'd0;
      o_i2c_scl <= ~o_i2c_scl;
    end
  end

  // Detection of falling edge of SCL
  always @(posedge clk) begin
      r_i2c_scl_d <= o_i2c_scl;
  end

  assign w_i2c_scl_neg = ({r_i2c_scl_d, o_i2c_scl} == 2'b10) ? 1'b1 : 1'b0;
  assign w_i2c_scl_pos = ({r_i2c_scl_d, o_i2c_scl} == 2'b01) ? 1'b1 : 1'b0;

  // Ready rising edge detection
  reg r_ready_d;
  wire w_ready_posedge;
  always @(posedge clk) begin
    r_ready_d <= i_ready
  end
  
  assign w_ready_posedge = ({r_ready_d, i_ready} == 2'b01) ? 1'b1 : 1'b0;

  // State Machine
  parameter [3:0] IDLE = 0;
  parameter [3:0] WAIT = 1;
  parameter [3:0] ADDR_DEV_WRITE = 2;
  parameter [3:0] ADDR_REG = 3;
  parameter [3:0] REPEAT_START = 4;
  parameter [3:0] ADDR_DEV_READ = 5;
  parameter [3:0] WRITE = 6;
  parameter [3:0] READ = 7;
  parameter [3:0] ENDING = 8;

  reg [3:0] r_stage;
  reg [3:0] r_next_state;
  reg [3:0] r_i2c_scl_count;
  reg [3:0] r_dout_buf;
  reg [3:0] r_dout_count;
  reg [3:0] r_din_buf;
  reg [3:0] r_end_count;

  always @(posedge i_clk) begin
    if (i_rst) begin
      r_state <= IDLE;
    end
    else begin
      r_state <= r_next_state;
    end
  end

  always @(posedge i_clk) begin
    case (r_stage)
      IDLE: begin
        o_dout_ack <= 1'b0;
        r_i2c_scl_counter <= 4'd0;
        o_din <= 8'h00;
        o_din_valid <= 1'b0;
        o_i2c_sda_out <= 1'b1;
        o_i2c_sda_oe  <= 1'b1;
        r_next_state <= WAIT;
        r_dout_buf <= 8'h00;
        r_i2c_scl_en <= 1'b0;
        r_dout_count <= 4'd0;
        r_end_count <= 8'd0;
      end 
      WAIT: begin
        if (w_ready_posedge) begin
          r_next_state <= ADDR_DEV_WRITE;
          r_dout_buf <= {i_dev_addr, 1'b0};
          o_i2c_sda_out <= 1'b0;
          o_i2c_sda_oe <= 1'b1;
          r_i2c_scl_en <= 1'b1;
        end
      end
      ADDR_DEV_WRITE: begin
        if (w_i2c_scl_neg  && (r_i2c_scl_count < 4'd8)) begin
          r_i2c_scl_count <= r_i2c_scl_count + 4'd1;
          {o_i2c_sda_out, r_dout_buf} <= {r_dout_buf, 1'b0};
          o_i2c_sda_oe <= 1'b1;
        end
        else if (w_i2c_scl_neg && (r_i2c_scl_count == 4'd8)) begin
          r_i2c_scl_count <= r_i2c_scl_count + 4'd1;
          o_i2c_sda_oe <= 1'b0;
        end
        else if (w_i2c_scl_neg && (r_i2c_scl_count == 4'd9)) begin
          r_i2c_scl_count <= 4'd0;
          r_dout_buf <= i_reg_addr;
          if (~i_i2c_sda_in) begin
            r_next_state <= ADDR_REG;
          end
          else begin
            r_next_state <= ENDING;
          end
        end
      end
      ADDR_REG: begin
        if (w_i2c_scl_neg && (r_i2c_scl_count < 4'd8)) begin
          r_i2c_scl_count <= r_i2c_scl_count + 4'd1;
          {o_i2c_sda_out, r_dout_buf} <= {r_dout_buf, 1'b0};
          o_i2c_sda_oe <= 1'b1;
        end
        else if (w_i2c_scl_neg && (r_i2c_scl_count == 4'd8)) begin
          r_i2c_scl_count <= r_i2c_scl_count + 4'd1;
          o_i2c_sda_oe <= 1'b0;
        end
        else if (w_i2c_scl_neg && (r_i2c_scl_count == 4'd9)) begin
          r_i2c_scl_count <= 4'd0;
            if (i_rdh_wrl && ~i_i2c_sda_in) begin
              r_next_state <= REPEAT_START;
              r_dout_buf <= {i_dev_addr, 1'b1};
            end
            else if (~i_rdh_wrl && ~i_i2c_sda_in) begin
              r_next_state <= WRITE;
              r_dout_buf <= i_dout;
            end
            else begin
              r_next_state <= ENDING;
        end
      end
      end
      REPEAT_START: begin
        if (w_i2c_scl_neg) begin
          o_i2c_sda_oe <= 1'b1;
          o_i2c_sda_out <= 1'b1;
        end
        else if (w_i2c_scl_pos) begin
          r_i2c_scl_en <= 1'b0;
        end
        else if (~r_i2c_scl_en && (r_end_count < 8'd250)) begin
          r_end_count <= r_end_count + 8'd1;
        end
        else if (~r_i2c_scl_en) begin
          r_end_count <= 8'd0;
          o_i2c_sda_out <= 1'b0;
          r_i2c_scl_en <= 1'b1;
          r_next_state <= ADDR_DEV_READ;
        end
      end
      ADDR_DEV_READ: begin
        if (w_i2c_scl_neg && (r_i2c_scl_count < 4'd8)) begin
          r_i2c_scl_count <= r_i2c_scl_count + 4'd1;
          {o_i2c_sda_out, r_dout_buf} <= {r_dout_buf, 1'b0};
          o_i2c_sda_oe <= 1'b1;
        end
        else if (w_i2c_scl_neg && (r_i2c_scl_count == 4'd8)) begin
          r_i2c_scl_count <= r_i2c_scl_count + 4'd1;
          o_i2c_sda_oe <= 1'b0;
        end
        else if (w_i2c_scl_pos && (r_i2c_scl_count == 4'd9)) begin
          r_i2c_scl_count <= 4'd0;
          if (~i_i2c_sda_in) begin
            r_next_state <= READ;
          end
          else begin
            r_next_state <= ENDING;
          end
        end
      end
        WRITE: begin
          if (w_i2c_scl_neg && (r_i2c_scl_count < 4'd8)) begin
            r_i2c_scl_count <= r_i2c_scl_count + 4'd1;
            {o_i2c_sda_out, r_dout_buf} <= {r_dout_buf, 1'b0};
            o_dout_ack <= 1'b0;
            o_i2c_sda_oe <= 1'b1;
          end
          else if (w_i2c_scl_neg && (r_i2c_scl_count == 4'd8)) begin
            r_i2c_scl_count <= r_i2c_scl_count + 4'd1;
            o_dout_ack <= 1'b1;
            o_i2c_sda_oe <= 1'b0;
          end
          else if (w_i2c_scl_neg && (r_i2c_scl_count == 4'd9)) begin
            r_dout_buf <= i_dout;
            r_i2c_scl_count <= 4'd0;
            if (~i_i2c_sda_in && (r_dout_count == (i_dout_length - 4'd1))) begin
              r_next_state <= ENDING;
              r_dout_count <= 4'd0;
            end
            else if (~i_i2c_sda_in) begin
              r_next_state <= WRITE;
              r_dout_count <= r_dout_count + 4'd1;
            end
            else begin
              r_next_state <= ENDING;
              r_dout_count <= 4'd0;
            end
          end
          else begin
            o_dout_ack <= 1'b0;
          end
          READ: begin
            if (w_i2c_scl_pos && (r_i2c_scl_count < 4'd8)) begin
             r_i2c_scl_count <= r_i2c_scl_count + 4'd1;
             r_din_buf <= {r_din_buf[6:0], i_i2c_sda_in};
             o_din_valid <= 1'b0;
             o_i2c_sda_oe <= 1'b0; 
            end
            else if (w_i2c_scl_neg && (r_i2c_scl_count == 4'd8)) begin
              r_i2c_scl_count <= r_i2c_scl_count + 4'd1;
              o_din <= r_din_buf;
              o_din_valid <= 1'b1;
              o_i2c_sda_oe <= 1'b1;
              if (r_dout_count == (i_dout_length - 4'd1)) begin
                o_i2c_sda_out <= 1'b1;
              end
              else begin
                o_i2c_sda_out <= 1'b0;
              end
            end
            else if (w_i2c_scl_neg && (r_i2c_scl_count == 4'd9)) begin
              r_i2c_scl_count <= 4'd0;
              o_i2c_sda_oe <= 1'b0;
              if (r_dout_count == (i_dout_length - 4'd1)) begin
                r_next_state <= ENDING;
                r_dout_count <= 4'd0;
              end
              else begin
                r_next_state <= READ;
                r_dout_count <= r_dout_count + 4'd1;
              end
            end
            else begin
              o_din_valid <= 1'b0;
            end
          end
        end
  ENDING: begin
    if (w_i2c_scl_pos) begin
      r_i2c_scl_en <= 1'b0;
      o_i2c_sda_oe <= 1'b1;
      o_i2c_sda_out <= 1'b0;
    end

    if (~r_i2c_scl_en && (r_end_count < 8'd250)) begin
    r_end_count <= r_end_count + 8'd1;
    end

    else if (~r_i2c_scl_en) begin
      o_i2c_sda_out <= 1'b1;
      r_next_state <= IDLE;
    end
    end
    endcase
  end
endmodule