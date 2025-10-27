module spi_adxl362_controller(
    input      clk,
    input      rst,
    
    // SPI port
    output reg CSN,
    output reg SCLK,
    output reg MOSI,
    input      MISO,
    
    // Control port
    input            ready,
    input      [7:0] inst,
    input            rdh_wrl,
    input      [7:0] reg_addr,
    input      [7:0] dout,
    output reg [7:0] din,
    output reg       din_valid
);
// SCK generator, 5MHz output
reg         SCLK_en;
reg         SCLK_d;
reg  [7:0]  SCLK_count;
wire        SCLK_posedge;
wire        SCLK_negedge;

always @(posedge clk or posedge rst) begin
	if(rst || ~SCLK_en) begin
		SCLK <= 1'b0;
        SCLK_count <= 8'd0;
	end
	else if(SCLK_en && (SCLK_count<8'd10)) begin
        SCLK_count <= SCLK_count + 8'd1;
	end
    else begin
        SCLK <= ~SCLK;
        SCLK_count <= 8'd0;
    end
end
always @(posedge clk) begin
    SCLK_d <= SCLK;
end
assign SCLK_posedge = ({SCLK_d, SCLK}==2'b01) ? 1'b1 : 1'b0;
assign SCLK_negedge = ({SCLK_d, SCLK}==2'b10) ? 1'b1 : 1'b0;
// Ready rising edge detection
reg  ready_d;
wire ready_posedge;
always @(posedge clk) begin
    ready_d <= ready;
end
assign ready_posedge = ({ready_d, ready} == 2'b01) ? 1'b1 : 1'b0;
// State machine
reg  [3:0]  state;
reg  [3:0]  next_state;

parameter IDLE       = 4'd0;
parameter START      = 4'd1;
parameter INST_OUT   = 4'd2;
parameter ADDR_OUT   = 4'd3;
parameter WRITE_DATA = 4'd4;
parameter READ_DATA  = 4'd5;
parameter ENDING     = 4'd6;

reg  [6:0]  MISO_buf;
reg  [7:0]  MOSI_buf;
reg  [3:0]  MOSI_count;

always @(posedge clk or posedge rst) begin
	if(rst) begin
		state <= IDLE;
	end
	else begin
		state <= next_state;
	end
end

always @(posedge clk) begin
	case(state)
	IDLE: 
	begin	// IDLE state
        next_state <= START;
		MOSI <= 1'b0;
        CSN <= 1'b1;
        SCLK_en <= 1'b0;
        MOSI_buf <= inst;
        MOSI_count <= 4'd0;
        din <= 8'h00;
        din_valid <= 1'b0;
	end
	START:
	begin	// enable SCK and CS
        // start the process when ready rise, load instruction
        if(ready_posedge) begin
            next_state <= INST_OUT;
            CSN  <= 1'b0;
            SCLK_en <= 1'b1;
            MOSI_buf <= {inst[6:0], 1'b0};
            MOSI <= inst[7];
        end
	end
	INST_OUT:
	begin	// send out instruction
		if(SCLK_negedge && (MOSI_count < 4'd7)) begin
			{MOSI, MOSI_buf} <= {MOSI_buf, 1'b0};
            MOSI_count <= MOSI_count + 4'd1;
		end
		else if(SCLK_negedge) begin
			{MOSI, MOSI_buf} <= {reg_addr, 1'b0};
            MOSI_count <= 4'd0;
            next_state <= ADDR_OUT;
		end
	end
	ADDR_OUT:
	begin	// send out register address
		if(SCLK_negedge && (MOSI_count < 4'd7)) begin
			{MOSI, MOSI_buf} <= {MOSI_buf, 1'b0};
            MOSI_count <= MOSI_count + 4'd1;
		end
		else if(SCLK_negedge) begin
			{MOSI, MOSI_buf} <= {dout, 1'b0};
            MOSI_count <= 4'd0;
            next_state <= (rdh_wrl) ? READ_DATA : WRITE_DATA;
		end
	end
	WRITE_DATA:
	begin	// send testing data out to flash
		if(SCLK_negedge && (MOSI_count < 4'd7)) begin
			{MOSI, MOSI_buf} <= {MOSI_buf, 1'b0};
            MOSI_count <= MOSI_count + 4'd1;
		end
		else if(SCLK_negedge) begin
			{MOSI, MOSI_buf} <= 9'h0;
            MOSI_count <= 4'd0;
            next_state <= ENDING;
		end
	end
	READ_DATA:
	begin	// get a byte
		if(SCLK_posedge && (MOSI_count < 4'd7)) begin
			MISO_buf <= {MISO_buf[5:0], MISO};
            MOSI_count <= MOSI_count + 4'd1;
		end
		else if(SCLK_posedge) begin
            MOSI_count <= 4'd0;
            next_state <= ENDING;
            din <= {MISO_buf, MISO};
            din_valid <= 1'b1;
		end
        else begin
            din_valid <= 1'b0;
        end
	end
	ENDING:
	begin	//disable SCK and CS
        if(SCLK_negedge) begin
            CSN <= 1'b1;
            next_state <= IDLE;
            SCLK_en <= 1'b0;
        end
	end
	endcase
end

endmodule


module top(
    input  clk,
    input  rst,
    output reg LED_INT1,
    output reg LED_INT2,
    
    // UART port
    output TXD,
    input  RXD,
    output CTS,
    input  RTS,
    
    // SPI port
    output ACL_CSN,
    output ACL_MOSI,
    input  ACL_MISO,
    output ACL_SCLK,
    input  ACL_INT1,
    input  ACL_INT2
);
// Direct connect LED to interrupt pins
always @(posedge clk or posedge rst) begin
    if(rst) begin
        LED_INT1 <= 1'b0;
        LED_INT2 <= 1'b0;
    end
    else begin
        LED_INT1 <= ACL_INT1;
        LED_INT2 <= ACL_INT2;
    end
end
// SPI controller
reg        SPI_ready;
reg  [7:0] SPI_inst;
reg        SPI_rdh_wrl;
reg  [7:0] SPI_reg_addr;
reg  [7:0] SPI_dout;
wire [7:0] SPI_din;
wire       SPI_din_valid;
spi_adxl362_controller SPI_transmitter(
    .clk        (clk),
    .rst        (rst),
    
    // SPI port
    .CSN        (ACL_CSN),
    .SCLK       (ACL_SCLK),
    .MOSI       (ACL_MOSI),
    .MISO       (ACL_MISO),
    
    // Control port
    .ready      (SPI_ready),
    .inst       (SPI_inst),
    .rdh_wrl    (SPI_rdh_wrl),
    .reg_addr   (SPI_reg_addr),
    .dout       (SPI_dout),
    .din        (SPI_din),
    .din_valid  (SPI_din_valid)
);
// Data IO with UART
wire [3:0] uart_din;
reg  [3:0] uart_din_d;
wire       uart_din_valid;
reg  [7:0] uart_dout;
reg        uart_dout_ready;
UART_transmitter UART_transmitter(
    .clk         (clk),
    .rst         (rst),
    
    // UART port
    .TXD         (TXD),
    .RXD         (RXD),
    .CTS         (CTS),
    .RTS         (RTS),
    
    // Control port
    .dout        (uart_dout),
    .dout_ready  (uart_dout_ready),
    .din         (uart_din),
    .din_valid   (uart_din_valid)
);
// Command control
// [27:24] rdh_wrl
// [23:16] inst
// [15: 8] reg_addr
// [ 7: 0] din
reg [27:0] UART_cmd_buf;
reg [3:0]  din_count;
always @(posedge clk) begin
    if(rst) begin
        UART_cmd_buf <= 28'h0000000;
        uart_dout_ready <= 1'b0;
        uart_dout <= 8'h00;
        din_count <= 4'd0;
        SPI_ready <= 1'b0;
        SPI_inst <= 8'h00;
        SPI_rdh_wrl <= 1'b0;
        SPI_reg_addr <= 8'h00;
        SPI_dout <= 8'h00;
    end
    else if(uart_din_valid && din_count < 4'd7) begin
        UART_cmd_buf <= {UART_cmd_buf[23:0], uart_din};
        if(din_count[0]) begin
            uart_dout <= {uart_din_d, uart_din};
            uart_dout_ready <= 1'b1;
        end
        else begin
            uart_din_d <= uart_din;
        end
        din_count <= din_count + 4'd1;
    end
    else if(uart_din_valid && din_count == 4'd7) begin
        uart_dout <= {uart_din_d, uart_din};
        uart_dout_ready <= 1'b1;
        din_count <= 4'd0;
        SPI_ready <= 1'b1;
        SPI_inst <= UART_cmd_buf[19:12];
        if(UART_cmd_buf[23:20] == 4'b0000) begin
            SPI_rdh_wrl <= 1'b0;
        end
        else if(UART_cmd_buf[23:20] == 4'b0001) begin
            SPI_rdh_wrl <= 1'b1;
        end
        SPI_reg_addr <= UART_cmd_buf[11:4];
        SPI_dout <= {UART_cmd_buf[3:0], uart_din};
    end
    else if(SPI_din_valid) begin
        uart_dout <= SPI_din;
        uart_dout_ready <= 1'b1;
    end
    else begin
        uart_dout_ready <= 1'b0;
        SPI_ready <= 1'b0;
    end
end

endmodule
