`timescale 1ns / 1ps

module i2c_drive(
			clk,rst_n,
			sw1,sw2,
			scl,sda,
			dis_data,
			seg,dig
		);

input  clk;                  // xung he thong 100 MHz
input  rst_n;                // tin hieu reset, active-low
input  sw1,sw2;              // nut bam 1 va 2 (SW1 thuc hien ghi, SW2 thuc hien doc)
output scl;                  // chan SCL ket noi ADT7420
output [7:0] dig;            // tin hieu chon digit cho LED 7 doan
output [6:0] seg;            // tin hieu chon segment cho LED 7 doan
inout  sda;                  // chan SDA ket noi ADT7420 (open-drain)
output [15:0] dis_data;      // du lieu hien thi ra LED

//--------------------------------------------
// Chong rung phim (debounce)
// - Moi 20 ms lay mau SW1, SW2 mot lan
//--------------------------------------------
reg sw1_r,sw2_r;             // gia tri nut sau debounce (cap nhat moi 20 ms)
reg[19:0] cnt_20ms;          // bo dem 20 ms

always @ (posedge clk or negedge rst_n)
	if(rst_n)
	   cnt_20ms <= 20'd0;
	else
	   cnt_20ms <= cnt_20ms+1'b1; // dem len

always @ (posedge clk or negedge rst_n)
	if(rst_n)
		begin
			sw1_r <= 1'b1;   // mac dinh nut tha (1)
			sw2_r <= 1'b1;
		end
	else if(cnt_20ms == 20'hfffff)
		begin
			sw1_r <= sw1;    // lay mau SW1
			sw2_r <= sw2;    // lay mau SW2
		end

//---------------------------------------------
// Tao xung SCL (chia tan so)
// - cnt: pha SCL (0: canh len, 1: giu muc H, 2: canh xuong, 3: giu muc L)
// - cnt_delay: dinh thoi 1 chu ky SCL ~100 kHz
// - clk1: xung cham cho scan LED
//---------------------------------------------
reg[2:0] cnt;                // pha SCL: 0 len, 1 giu H, 2 xuong, 3 giu L
reg[8:0] cnt_delay;          // bo dem dinh thoi cho I2C
reg[31:0] count;
reg clk1='b0;                // xung cham hien thi
reg scl_r;                   // ghi nho trang thai SCL

always @ (posedge clk or negedge rst_n)
	if(rst_n)
	   cnt_delay <= 10'd0;
	else if(cnt_delay == 10'd999)
	   cnt_delay <= 10'd0;   // 1000*10ns = 10us => SCL ~100 kHz
	else
	   cnt_delay <= cnt_delay+1'b1; // dem

// Tao clk1 tu clk he thong (tan so thap cho scan LED)
always @ (posedge clk)
       if(rst_n)
       begin
           count<=0;
       end
       else
       begin
       if(count==32'd100000)
       begin
           clk1<=~clk1;
           count<=0;
       end
       else count<=count+1;
end

// Pha SCL theo cnt_delay
always @ (posedge clk or negedge rst_n) begin
	if(rst_n)
	   cnt <= 3'd5;
	else
	  begin
		 case (cnt_delay)
			9'd124:	cnt <= 3'd1; // SCL giu muc H (co dinh du lieu)
			9'd249:	cnt <= 3'd2; // SCL canh xuong
			9'd374:	cnt <= 3'd3; // SCL giu muc L (doi du lieu thay doi)
			9'd499:	cnt <= 3'd0; // SCL canh len
			default: cnt <= 3'd5;
		  endcase
	  end
end

// Cac macro pha SCL
`define SCL_POS		(cnt==3'd0) // canh len
`define SCL_HIG		(cnt==3'd1) // giu muc H (sample du lieu)
`define SCL_NEG		(cnt==3'd2) // canh xuong
`define SCL_LOW		(cnt==3'd3) // giu muc L (thay doi du lieu)

// Xuat SCL
always @ (posedge clk or negedge rst_n)
	if(rst_n)
	    scl_r <= 1'b0;
	else if(cnt==3'd0)
	    scl_r <= 1'b1; // canh len
   	else if(cnt==3'd2)
        scl_r <= 1'b0; // canh xuong

assign scl = scl_r; // SCL dua ra ngoai
//---------------------------------------------

//---------------------------------------------
// Hang so I2C / ADT7420 (dia chi thiet bi)
// - DEVICE_READ/WRITE: byte dia chi 8 bit (7b + R/W)
// - WRITE_DATA: du lieu ghi demo
// - BYTE_ADDR: thanh ghi dia chi bo nho ben trong
//---------------------------------------------
`define	DEVICE_READ		8'b1001_0111 // dia chi doc (0x97)
`define DEVICE_WRITE	8'b1001_0110 // dia chi ghi (0x96)

`define	WRITE_DATA      8'b0000_0111 // du lieu ghi vao EEPROM (demo)
`define BYTE_ADDR       8'b0000_0000 // thanh ghi dia chi ben trong

reg[7:0]  db_r;               // thanh ghi du lieu truyen tren I2C
reg[15:0] read_data;          // du lieu doc ve (2 byte)

//---------------------------------------------
// FSM giao thuc I2C (ghi/doi dia chi/rep start/doc 2 byte)
//---------------------------------------------
parameter 	IDLE 	= 4'd0;  // cho
parameter 	START1 	= 4'd1;  // start lan 1
parameter 	ADD1 	= 4'd2;  // gui dia chi thiet bi (ghi)
parameter 	ACK1 	= 4'd3;  // cho ACK1 tu slave
parameter 	ADD2 	= 4'd4;  // gui thanh ghi dia chi noi bo
parameter 	ACK2 	= 4'd5;  // cho ACK2
parameter 	START2 	= 4'd6;  // repeated START
parameter 	ADD3 	= 4'd7;  // gui dia chi thiet bi (doc)
parameter 	ACK3	= 4'd8;  // cho ACK3
parameter 	DATA1 	= 4'd9;  // doc byte MSB
parameter 	ACK4	= 4'd10; // master gui ACK sau byte 1
parameter 	DATA2 	= 4'd11; // doc byte LSB
parameter 	NACK	= 4'd12; // master gui NACK sau byte cuoi
parameter 	STOP1 	= 4'd13; // tao STOP (phan 1)
parameter 	STOP2 	= 4'd14; // tao STOP (phan 2)

reg[3:0] cstate;              // trang thai hien tai
reg sda_r;                    // gia tri SDA tu master (keo 0 hay tha)
reg sda_link;                 // 1: master drive SDA (output), 0: tha (input)
reg[3:0] num;                 // dem bit trong 1 byte (0..8)

// FSM trien khai trinh tu I2C co ban
always @ (posedge clk or negedge rst_n) begin
	if(rst_n)
		begin
			cstate   <= IDLE;
			sda_r    <= 1'b1;
			sda_link <= 1'b0;
			num      <= 4'd0;
			read_data<= 16'b0000_0000_0000_0000;
		end
	else
		case (cstate)
			IDLE:
				begin
					sda_link <= 1'b1; // tam thoi dat SDA o che do input (tha Z)
					sda_r    <= 1'b1;
					if(!sw1_r || !sw2_r) begin   // co nut duoc nhan
						  db_r   <= `DEVICE_WRITE; // chuan bi gui dia chi ghi
						  cstate <= START1;
						end
					else
					   cstate <= IDLE;
				end
			START1:
				begin
					if(`SCL_HIG) begin
						  sda_link <= 1'b1; // xuat SDA
						  sda_r    <= 1'b0; // tao START (SDA xuong khi SCL dang H)
						  cstate   <= ADD1;
						  num      <= 4'd0;
						end
					else
					    cstate <= START1; // doi SCL vao pha giu H
				end
			ADD1:
				begin
					if(`SCL_LOW) begin
							if(num == 4'd8) begin
									num      <= 4'd0;
									sda_r    <= 1'b1;
									sda_link <= 1'b0; // tha de slave ACK
									cstate   <= ACK1;
								end
							else begin
									cstate <= ADD1;
									num    <= num+1'b1;
									case (num)
										4'd0: sda_r <= db_r[7];
										4'd1: sda_r <= db_r[6];
										4'd2: sda_r <= db_r[5];
										4'd3: sda_r <= db_r[4];
										4'd4: sda_r <= db_r[3];
										4'd5: sda_r <= db_r[2];
										4'd6: sda_r <= db_r[1];
										4'd7: sda_r <= db_r[0];
										default: ;
									endcase
								end
						end
					else
					   cstate <= ADD1;
				end
			ACK1:
				begin
					if(/*!sda*/`SCL_NEG) begin // gia su luon nhan duoc ACK
							cstate <= ADD2;       // slave da ACK
							db_r   <= `BYTE_ADDR; // gui thanh ghi dia chi noi bo
						end
					else
					   cstate <= ACK1;           // doi ACK
				end
			ADD2:
				begin
					if(`SCL_LOW) begin
							if(num==4'd8) begin
									num      <= 4'd0;
									sda_r    <= 1'b1;
									sda_link <= 1'b0; // tha de slave ACK
									cstate   <= ACK2;
								end
							else begin
									sda_link <= 1'b1; // xuat SDA
									num      <= num+1'b1;
									case (num)
										4'd0: sda_r <= db_r[7];
										4'd1: sda_r <= db_r[6];
										4'd2: sda_r <= db_r[5];
										4'd3: sda_r <= db_r[4];
										4'd4: sda_r <= db_r[3];
										4'd5: sda_r <= db_r[2];
										4'd6: sda_r <= db_r[1];
										4'd7: sda_r <= db_r[0];
										default: ;
									endcase
									cstate <= ADD2;
								end
						end
					else
					    cstate <= ADD2;
				end
			ACK2: begin
					if(/*!sda*/`SCL_NEG) begin // ACK tu slave
						if(!sw1_r) begin
								cstate <= DATA1;        // ghi du lieu (demo)
								db_r   <= `WRITE_DATA; // du lieu ghi
							end
						else if(!sw2_r) begin
								db_r   <= `DEVICE_READ; // chuan bi doc -> gui dia chi doc
								cstate <= START2;       // repeated START
							end
						end
					else cstate <= ACK2; // doi ACK
				end
			START2: begin // repeated START
					if(`SCL_LOW) begin
						sda_link <= 1'b1;
						sda_r    <= 1'b1;
						cstate   <= START2;
						end
					else if(`SCL_HIG) begin // SCL o muc H
						sda_r  <= 1'b0;       // tao START
						cstate <= ADD3;
						end
					else cstate <= START2;
				end
			ADD3: begin // gui dia chi doc
					if(`SCL_LOW) begin
							if(num==4'd8) begin
									num      <= 4'd0;
									sda_r    <= 1'b1;
									sda_link <= 1'b0; // tha de slave ACK
									cstate   <= ACK3;
								end
							else begin
									num    <= num+1'b1;
									case (num)
										4'd0: sda_r <= db_r[7];
										4'd1: sda_r <= db_r[6];
										4'd2: sda_r <= db_r[5];
										4'd3: sda_r <= db_r[4];
										4'd4: sda_r <= db_r[3];
										4'd5: sda_r <= db_r[2];
										4'd6: sda_r <= db_r[1];
										4'd7: sda_r <= db_r[0];
										default: ;
										endcase
									cstate <= ADD3;
								end
						end
					else cstate <= ADD3;
				end
			ACK3: begin
					if(/*!sda*/`SCL_NEG) begin
							cstate   <= DATA1;  // bat dau nhan byte 1
							sda_link <= 1'b0;   // tha SDA de slave truyen du lieu
						end
					else cstate <= ACK3;
				end
			DATA1: begin // doc byte MSB
					if(!sw2_r) begin
							if(num<=4'd7) begin
								cstate <= DATA1;
								if(`SCL_HIG) begin // sample khi SCL H
									num <= num+1'b1;
									case (num)
										4'd0: read_data[15] <= sda;
										4'd1: read_data[14] <= sda;
										4'd2: read_data[13] <= sda;
										4'd3: read_data[12] <= sda;
										4'd4: read_data[11] <= sda;
										4'd5: read_data[10] <= sda;
										4'd6: read_data[9]  <= sda;
										4'd7: read_data[8]  <= sda;
										default: ;
										endcase
									end
								end
							else if((`SCL_LOW) && (num==4'd8)) begin
								num    <= 4'd0;
								cstate <= ACK4; // master se ACK
								end
							else cstate <= DATA1;
						end
				end
			ACK4: begin // master ACK sau byte MSB
					if(/*!sda*/`SCL_HIG) begin
						sda_link <= 1'b1;
						sda_r    <= 1'b0; // keo 0 = ACK
						cstate   <= DATA2;
						end
					else cstate <= ACK4;
				end
		DATA2: begin // doc byte LSB
                        if(!sw2_r) begin
                                if(num<=4'd7) begin
                                    cstate <= DATA2;
                                    if(`SCL_HIG) begin
                                        num <= num+1'b1;
                                        case (num)
                                            4'd0: read_data[7] <= sda;
                                            4'd1: read_data[6] <= sda;
                                            4'd2: read_data[5] <= sda;
                                            4'd3: read_data[4] <= sda;
                                            4'd4: read_data[3] <= sda;
                                            4'd5: read_data[2] <= sda;
                                            4'd6: read_data[1] <= sda;
                                            4'd7: read_data[0] <= sda;
                                            default: ;
                                            endcase
                                        end
                                    end
                                else if((`SCL_LOW) && (num==4'd8)) begin
                                    num    <= 4'd0;
                                    cstate <= NACK; // master se NACK
                                    end
                                else cstate <= DATA2;
                            end
                    end
                NACK: begin // master NACK sau byte cuoi
                        if(/*!sda*/`SCL_HIG) begin
                        sda_link <= 1'b1;
                        sda_r    <= 1'b1; // tha 1 = NACK
                        cstate   <= STOP1;
                            end
                        else cstate <= NACK;
                    end
			STOP1: begin // tao STOP: SDA len khi SCL dang H
					if(`SCL_LOW) begin
							sda_link <= 1'b1;
							sda_r    <= 1'b0;
							cstate   <= STOP1;
						end
					else if(`SCL_HIG) begin
							sda_r  <= 1'b1; // STOP
							cstate <= STOP2;
						end
					else cstate <= STOP1;
				end
			STOP2: begin // cho on dinh roi ve IDLE
					if(`SCL_LOW) sda_r <= 1'b1;
					else if(cnt_20ms==20'hffff0) cstate <= IDLE;
					else cstate <= STOP2;
				end
			default: cstate <= IDLE;
			endcase
end

// SDA open-drain: khi sda_link=1 thi master keo muc theo sda_r, nguoc lai tha Z
assign sda = sda_link ? sda_r:1'bz;
assign dis_data = read_data;

//---------------------------------------------
// Hien thi LED 7 doan (giu nguyen module con)
//---------------------------------------------
scan_led
scan_led_inst(
.clk1(clk1),
.dis_data(dis_data),
.dig(dig),
.seg(seg)
);
endmodule
