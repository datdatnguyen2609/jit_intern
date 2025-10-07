module  i2c_master
#(
    parameter   DEVICE_ADDR  = 7'b1001_011  ,
    parameter   SYS_CLK_FREQ = 'd100_000_000,
    parameter   SCL_FREQ     = 'd200_000    
)
(
    input   wire            i_sys_clk     ,
    input   wire            i_sys_rst_n   ,

    inout   wire            io_i2c_sda    ,
    
    output  reg             o_i2c_scl     ,
    output  reg     [26:0]  o_rd_data     

);

parameter   CNT_CLK_MAX   = (SYS_CLK_FREQ / SCL_FREQ) >> 3;
parameter   CNT_DELAY_MAX = 20'd125_000;

parameter   IDLE         = 4'd0,
            START        = 4'd1,
            SEND_D_ADDR  = 4'd2,
            ACK_1        = 4'd3,
            SEND_R_ADDR  = 4'd4,
            ACK_2        = 4'd5,
            RE_START     = 4'd6,
            RSEND_D_ADDR = 4'd7,
            ACK_3        = 4'd8,
            RD_DATA_MSB  = 4'd9,
            MASTER_ACK   = 4'd10,
            RD_DATA_LSB  = 4'd11,
            NO_ACK       = 4'd12,
            STOP         = 4'd13;

// ---------------- Internal signals ----------------
reg     [19:0]  r_cnt_delay       ;
reg             r_i2c_scl_reg     ;
reg     [7:0]   r_cnt_clk         ;
reg             r_i2c_clk         ;
reg     [3:0]   r_state           ;
reg     [1:0]   r_cnt_i2c_clk     ;
reg             r_cnt_i2c_clk_en  ;
reg     [3:0]   r_cnt_bit         ;
wire            w_sda_in          ;
reg             r_sda_out         ;
wire            w_sda_en          ;
reg     [15:0]  r_rd_data_reg     ;
reg             r_ack             ;

// cnt_clk
always @(posedge i_sys_clk or negedge i_sys_rst_n) 
    if(i_sys_rst_n == 1'b0)
        r_cnt_clk <= 8'd0;
    else if(r_cnt_clk == CNT_CLK_MAX - 1)
        r_cnt_clk <= 8'd0;
    else
        r_cnt_clk <= r_cnt_clk + 1'b1;

// i2c_clk
always @(posedge i_sys_clk or negedge i_sys_rst_n) 
    if(i_sys_rst_n == 1'b0)
        r_i2c_clk <= 1'b1;
    else if(r_cnt_clk == CNT_CLK_MAX - 1)
        r_i2c_clk <= ~r_i2c_clk;

// cnt_delay (??500ms, ????????)
always @(posedge r_i2c_clk or negedge i_sys_rst_n) 
    if(i_sys_rst_n == 1'b0)
        r_cnt_delay <= 20'd0;
    else if(r_cnt_delay == CNT_DELAY_MAX - 1)
        r_cnt_delay <= 20'd0;
    else if(r_cnt_i2c_clk == 2'd3 && r_state == IDLE)
        r_cnt_delay <= r_cnt_delay + 1'b1;

// state
always @(posedge r_i2c_clk or negedge i_sys_rst_n) 
    if(i_sys_rst_n == 1'b0)
        r_state <= IDLE;
    else case(r_state)
        IDLE :
            if(r_cnt_delay == CNT_DELAY_MAX - 1)
                r_state <= START;
            else
                r_state <= r_state;
        START :
            if(r_cnt_i2c_clk == 2'd3)
                r_state <= SEND_D_ADDR;
            else
                r_state <= r_state;
        SEND_D_ADDR :
            if(r_cnt_i2c_clk == 2'd3 && r_cnt_bit == 3'd7)
                r_state <= ACK_1;
            else
                r_state <= r_state;
        ACK_1 :
            if(r_cnt_i2c_clk == 2'd3 && r_ack == 1'b0)
                r_state <= SEND_R_ADDR;
            else
                r_state <= r_state;
        SEND_R_ADDR :
            if(r_cnt_i2c_clk == 2'd3 && r_cnt_bit == 3'd7)
                r_state <= ACK_2;
            else
                r_state <= r_state;
        ACK_2 :
            if(r_cnt_i2c_clk == 2'd3 && r_ack == 1'b0)
                r_state <= RE_START;
            else
                r_state <= r_state;
        RE_START :
            if(r_cnt_i2c_clk == 2'd3)
                r_state <= RSEND_D_ADDR;
            else
                r_state <= r_state;
        RSEND_D_ADDR :
            if(r_cnt_i2c_clk == 2'd3 && r_cnt_bit == 3'd7)
                r_state <= ACK_3;
            else
                r_state <= r_state;
        ACK_3 :
            if(r_cnt_i2c_clk == 2'd3 && r_ack == 1'b0)
                r_state <= RD_DATA_MSB;
            else
                r_state <= r_state;
        RD_DATA_MSB :
            if(r_cnt_i2c_clk == 2'd3 && r_cnt_bit == 3'd7)
                r_state <= MASTER_ACK;
            else
                r_state <= r_state;
        MASTER_ACK :
            if(r_cnt_i2c_clk == 2'd3)
                r_state <= RD_DATA_LSB;
            else
                r_state <= r_state;
        RD_DATA_LSB :
            if(r_cnt_i2c_clk == 2'd3 && r_cnt_bit == 3'd7)
                r_state <= NO_ACK;
            else
                r_state <= r_state;
        NO_ACK :
            if(r_cnt_i2c_clk == 2'd3)
                r_state <= STOP;
            else
                r_state <= r_state;
        STOP :
            if(r_cnt_i2c_clk == 2'd3 && r_cnt_bit == 3'd3) begin
                r_state <= IDLE;
                // r_cnt_bit <= 3'd0;
            end else
                r_state <= r_state;
        default : r_state <= IDLE;
    endcase

// cnt_i2c_clk
always @(posedge r_i2c_clk or negedge i_sys_rst_n) 
    if(i_sys_rst_n == 1'b0)
        r_cnt_i2c_clk <= 2'd0;
    else if(r_state == STOP && r_cnt_i2c_clk == 2'd3 && r_cnt_bit == 3'd3)
        r_cnt_i2c_clk <= 2'd0;
    else
        r_cnt_i2c_clk <= r_cnt_i2c_clk + 1'b1;

// cnt_i2c_clk_en
always @(posedge r_i2c_clk or negedge i_sys_rst_n) 
    if(i_sys_rst_n == 1'b0)
        r_cnt_i2c_clk_en <= 1'b0;
    else if(r_state == STOP && r_cnt_i2c_clk == 2'd3 && r_cnt_bit == 3'd3)
        r_cnt_i2c_clk_en <= 1'b0;
    else if(r_state == IDLE && r_cnt_i2c_clk == 2'd3)
        r_cnt_i2c_clk_en <= 1'b1;

// cnt_bit
always @(posedge r_i2c_clk or negedge i_sys_rst_n) 
    if(i_sys_rst_n == 1'b0)
        r_cnt_bit <= 3'd0;
    else if(r_state == IDLE || r_state == START || r_state == ACK_1 || r_state == ACK_2 ||
            r_state == RE_START || r_state == ACK_3 || r_state == MASTER_ACK || 
            r_state == NO_ACK)
        r_cnt_bit <= 3'd0;
    else if((r_cnt_bit == 3'd7) && (r_cnt_i2c_clk == 2'd3))
        r_cnt_bit <= 3'd0;
    else if((r_cnt_i2c_clk == 2'd3) && (r_state != IDLE))
        r_cnt_bit <= r_cnt_bit + 1'b1;

// i2c_sda (tristate)
assign  io_i2c_sda = (w_sda_en == 1'b1) ? r_sda_out : 1'bz;

// sda_in
assign  w_sda_in = io_i2c_sda;

// sda_out
always @(*)
    case(r_state)
        IDLE :
            r_sda_out <= 1'b1;
        START :
            if(r_cnt_i2c_clk == 2'd0)
                r_sda_out <= 1'b1;
            else
                r_sda_out <= 1'b0;
        SEND_D_ADDR :
            if(r_cnt_bit == 3'd7)
                r_sda_out <= 1'b0;
            else    
                r_sda_out <= DEVICE_ADDR[6 - r_cnt_bit];
        ACK_1 :
            r_sda_out <= 1'b0;
        SEND_R_ADDR :
            r_sda_out <= 1'b0;
        ACK_2 :
            r_sda_out <= 1'b1;
        RE_START :
            if(r_cnt_i2c_clk <= 2'd1)
                r_sda_out <= 1'b1;
            else
                r_sda_out <= 1'b0;
        RSEND_D_ADDR :
            if(r_cnt_bit == 3'd7)
                r_sda_out <= 1'b1;
            else    
                r_sda_out <= DEVICE_ADDR[6 - r_cnt_bit];
        ACK_3 :
            r_sda_out <= 1'b1;
        RD_DATA_MSB :
            r_sda_out <= 1'b1;
        MASTER_ACK :
            r_sda_out <= 1'b0;
        RD_DATA_LSB :
            r_sda_out <= 1'b1;
        NO_ACK :
            r_sda_out <= 1'b1;
        STOP :
            if(r_cnt_bit == 3'd0 && r_cnt_i2c_clk < 2'd3)
                r_sda_out <= 1'b0;
            else
                r_sda_out <= 1'b1;
        default : r_sda_out <= 1'b1;
    endcase

// sda_en
assign  w_sda_en = (r_state == ACK_1 || r_state == ACK_2 || r_state == ACK_3 ||
                    r_state == RD_DATA_MSB || r_state == RD_DATA_LSB) ? 1'b0 : 1'b1;

// rd_data_reg[15:0]
always @(posedge r_i2c_clk or negedge i_sys_rst_n) 
    if(i_sys_rst_n == 1'b0)
        r_rd_data_reg <= 16'd0;
    else case(r_state)
        RD_DATA_MSB :
            if(r_cnt_i2c_clk == 2'b1)
                r_rd_data_reg[15 - r_cnt_bit] <= w_sda_in;
            else
                r_rd_data_reg <= r_rd_data_reg;
        RD_DATA_LSB :
            if(r_cnt_i2c_clk == 2'b1)
                r_rd_data_reg[7 - r_cnt_bit] <= w_sda_in;
            else
                r_rd_data_reg <= r_rd_data_reg;
    endcase

// rd_data
always @(posedge r_i2c_clk or negedge i_sys_rst_n) 
    if(i_sys_rst_n == 1'b0)
        o_rd_data <= 27'd0;
    else if(r_state == RD_DATA_LSB && r_cnt_bit == 3'd7 && r_cnt_i2c_clk == 2'd3)
        o_rd_data <= r_rd_data_reg[14:3] * 625;

// i2c_scl
always @(posedge r_i2c_clk or negedge i_sys_rst_n) 
    if(i_sys_rst_n == 1'b0)
        o_i2c_scl <= 1'b1;
    else if((r_cnt_i2c_clk == 2'd2 || r_cnt_i2c_clk == 2'd3) && (r_state != STOP)
             && (r_state != IDLE))
        o_i2c_scl <= 1'b0;
    else
        o_i2c_scl <= 1'b1;

// ack
always @(*)
    case(r_state) 
        ACK_1, ACK_2, ACK_3 :
            if(r_cnt_i2c_clk == 2'b0)
                r_ack <= w_sda_in;
            else
                r_ack <= r_ack;
        default : r_ack <= 1'b1;
    endcase

endmodule
