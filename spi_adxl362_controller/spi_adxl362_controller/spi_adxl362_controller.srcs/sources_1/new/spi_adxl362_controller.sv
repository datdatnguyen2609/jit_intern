`timescale 1ns / 1ps
module spi_adxl362_controller(
    input i_clk,
    input i_rst,
    
    output reg o_csn,
    output reg o_sclk,
    output reg o_mosi,
    input      i_miso,

    input i_ready,
    input [7:0] i_inst,
    input i_sel_rw,
    input [7:0] i_reg_addr,
    input [7:0] i_dout,
    output reg [7:0] o_din,
    output reg       o_din_valid
    );

    // o_sclk gen, 5Mhz output

    reg r_sclk_en;
    reg r_sclk_d;
    reg [7:0] r_sclk_count;
    wire w_sclk_posedge;
    wire w_sclk_negedge;  

    always @(posedge i_clk) begin
        if (i_rst || ~r_sclk_en) begin
            o_sclk <= 1'b0;
            r_sclk_count <= 8'd0;
        end
        else if (r_sclk_en && (r_sclk_count < 8'd10)) begin
            r_sclk_count <= r_sclk_count + 8'd1;
        end else begin
            o_sclk <= ~o_sclk;
            r_sclk_count <= 8'd0;
        end
    end

    // determine edge of o_sclk

    always @(posedge i_clk) begin
        if (i_rst) begin
            r_sclk_d <= o_sclk;
        end else r_sclk_d <= o_sclk;
    end

    assign w_sclk_posedge = ({r_sclk_d, o_sclk} == 2'b01) ? 1'b1 : 1'b0;
    assign w_sclk_negedge = ({r_sclk_d, o_sclk} == 2'b10) ? 1'b1 : 1'b0;

    // determine edge of ready

    reg r_ready_d;
    wire w_ready_posedge;
    always @(posedge i_clk) begin
        r_ready_d <= i_ready;
    end
    assign w_ready_posedge = ({r_ready_d, i_ready} == 2'b01) ? 1'b1 : 1'b0;

    // state machine 

    reg [2:0] r_state;
    reg [2:0] r_next_state;
    
    parameter IDLE = 3'd0;
    parameter START = 3'd1;
    parameter INST_OUT = 3'd2;
    parameter ADDR_OUT = 3'd3;
    parameter WRITE_DATA = 3'd4;
    parameter READ_DATA = 3'd5;
    parameter ENDING = 3'd6;

    reg [7:0] r_mosi_buf;
    reg [6:0] r_miso_buf;
    reg [2:0] r_bitcount;

    always @(posedge i_clk) begin
        if (i_rst) begin
            r_state <= IDLE;
        end else begin
            r_state <= r_next_state;
        end
    end

    always @(posedge i_clk) begin
        case (r_state)
            IDLE:begin
                r_next_state <= START;
                o_mosi <= 1'b0;
                o_csn <= 1'b1;
                r_sclk_en <= 1'b0;
                r_mosi_buf <= i_inst;
                r_bitcount <= 3'd0;
                o_din <= 8'd0;
                o_din_valid <= 1'b0;
            end 
            START: begin
                if (w_ready_posedge) begin
                    o_csn <= 1'b0;
                    r_sclk_en <= 1'b1;
                    r_mosi_buf <= {i_inst[6:0], 1'b0};
                    o_mosi <= i_inst[7];
                    r_next_state <= INST_OUT;
                end
            end
            INST_OUT: begin
                if (w_sclk_negedge &&  (r_bitcount < 3'd7)) begin
                    {o_mosi, r_mosi_buf} <= {r_mosi_buf, 1'b0};
                    r_bitcount <= r_bitcount + 3'd1;
                end
                else if (w_sclk_negedge) begin
                    {o_mosi, r_mosi_buf} <= {i_reg_addr, 1'b0};
                    r_bitcount <= 3'd0;
                    r_next_state <= ADDR_OUT;
                end
            end
            ADDR_OUT: begin
                if (w_sclk_negedge && (r_bitcount < 3'd7)) begin
                    {o_mosi, r_mosi_buf} <= {r_mosi_buf, 1'b0};
                    r_bitcount <= r_bitcount + 3'd1;
                end
                else if (w_sclk_negedge) begin
                    {o_mosi, r_mosi_buf} <= {i_dout, 1'b0};
                    r_bitcount <= 3'd0;
                    if (i_sel_rw) begin
                        r_next_state <= READ_DATA;
                    end else begin
                        r_next_state <= WRITE_DATA;
                    end
                end
            end
            WRITE_DATA:
            begin
                if (w_sclk_negedge && (r_bitcount < 3'd7)) begin
                    {o_mosi, r_mosi_buf} <= {r_mosi_buf, 1'b0};
                    r_bitcount <= r_bitcount + 4'd1;
                end
                else if (w_sclk_negedge) begin
                    {o_mosi, r_mosi_buf} <= 9'h0;
                    r_bitcount <= 3'd0;
                    r_next_state <= ENDING;
                end
            end
            READ_DATA:
            begin
                if (w_sclk_posedge && (r_bitcount < 4'd7)) begin
                    r_miso_buf <= {r_miso_buf[5:0], i_miso};
                    r_bitcount <= r_bitcount + 3'd1;
                end
                else if (w_sclk_posedge) begin
                    r_bitcount <= 3'd0;
                    o_din <= {r_miso_buf, i_miso};
                    o_din_valid <= 1'b1;
                    r_next_state <= ENDING;
                end
                else begin
                    o_din_valid <= 1'b0;
                end
            end
            ENDING:
            begin
                if (w_sclk_negedge) begin
                    o_csn <= 1'b1;
                    r_sclk_en <= 1'b0;
                    r_next_state <= IDLE;
                end
            end
            default: r_next_state <= r_state;
        endcase
    end
endmodule 