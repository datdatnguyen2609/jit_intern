module i2c_master (
  input i_clk,
  input i_rst,
  input i_newd,
  input i_op,
  input [7:0] i_addr,
  input [15:0] i_d,

  inout io_sda,
  
  output reg [15:0] o_d,
  output reg o_busy, o_ack_err, o_done, 
  output o_scl,

);
//----------------------------------------------
// FSM Define
//----------------------------------------------
  reg r_scl_t, r_sda_t;

  localparam [3:0] 
    S_IDLE                = 4'd0,
    S_START               = 4'd1,
    S_INITIALIZE          = 4'd2,
    S_ACK_FOR_INIT        = 4'd3,
    S_WRITE_ADDR_POINT_REG= 4'd4,
    S_ACK_ADDR_POINT_REG  = 4'd5,
    S_READ_DATA           = 4'd6,
    S_WRITE_DATA          = 4'd7,
    S_ACK_DATA            = 4'd8,
    S_MASTER_ACK          = 4'd9,
    S_MASTER_NO_ACK       = 4'd10,
    S_STOP                = 4'd11;

  reg [3:0] r_state;

//----------------------------------------------
// Reg Define
//----------------------------------------------
  parameter P_TEMP_VALUE = 8'h0 ;
  parameter P_TEMP_HIGH = 8'h04;
  parameter P_TEMP_LOW = 8'h06;
  parameter P_TEMP_CRIT = 8'h08;

  reg [7:0] r_init_write = 8'b10010000;
  reg [7:0] r_init_read  = 8'b10010001;

  parameter P_SYS_FREQ = 100_000_000;
  parameter P_I2C_FREQ = 1_000_000;
  parameter P_CLK_COUNT = (P_SYS_FREQ/P_I2C_FREQ);

  reg r_count;
  reg [3:0] r_bit_count;
  reg [3:0] r_data_bytes;
  reg [1:0] r_pulse;

  always @(posedge i_clk) begin
    if (i_rst) begin
      r_scl_t <= 1;
      r_sda_t <= 1;
      o_busy <= 0;
      o_ack_err <= 0;
      o_done <= 0;
      r_state <= S_IDLE;
      r_pulse <= 0;
      r_count <= 0;
      r_bit_count <= 0;
    end
  end


//----------------------------------------------
// SCL generator
//----------------------------------------------

  

  always @(posedge i_clk) begin
    if (i_rst | ~(i_en)) begin
      
    end
  end
endmodule