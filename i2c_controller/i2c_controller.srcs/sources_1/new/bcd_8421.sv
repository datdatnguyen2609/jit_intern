module bcd_8421
(
    input  wire        i_sys_clk,
    input  wire        i_rst,          // reset dong bo, active-HIGH
    input  wire [26:0] i_data,

    output reg  [3:0]  o_units,          // don vi
    output reg  [3:0]  o_tens,           // chuc
    output reg  [3:0]  o_hundreds,       // tram
    output reg  [3:0]  o_thousands,      // nghin
    output reg  [3:0]  o_ten_thousands,  // chuc nghin
    output reg  [3:0]  o_hun_thousands,  // tram nghin
    output reg  [3:0]  o_millions,       // trieu
    output reg  [3:0]  o_ten_millions    // chuc trieu
);

    // ==========================
    // Registers noi bo
    // ==========================
    reg [4:0]  r_cnt_shift;
    reg [58:0] r_data_shift;
    reg        r_shift_flag;

    // ------------------------------------------------------------
    // r_cnt_shift: dem so bit da xu ly (0..28) cho i_data[26:0]
    // ------------------------------------------------------------
    always @(posedge i_sys_clk) begin
        if (i_rst) begin
            r_cnt_shift <= 5'd0;
        end else if ((r_cnt_shift == 5'd28) && r_shift_flag) begin
            r_cnt_shift <= 5'd0;
        end else if (r_shift_flag) begin
            r_cnt_shift <= r_cnt_shift + 1'b1;
        end else begin
            r_cnt_shift <= r_cnt_shift;
        end
    end

    // ------------------------------------------------------------
    // r_data_shift: thuat toan double-dabble (shift-add-3)
    // Layout nibble BCD:
    //   [30:27] units, [34:31] tens, [38:35] hundreds, [42:39] thousands,
    //   [46:43] ten_thousands, [50:47] hun_thousands,
    //   [54:51] millions, [58:55] ten_millions
    // ------------------------------------------------------------
    always @(posedge i_sys_clk) begin
        if (i_rst) begin
            r_data_shift <= 59'd0;
        end else if (r_cnt_shift == 5'd0) begin
            r_data_shift <= {32'b0, i_data};
        end else if ((r_cnt_shift <= 5'd27) && !r_shift_flag) begin
            r_data_shift[30:27] <= (r_data_shift[30:27] > 4) ? (r_data_shift[30:27] + 2'd3) : r_data_shift[30:27];
            r_data_shift[34:31] <= (r_data_shift[34:31] > 4) ? (r_data_shift[34:31] + 2'd3) : r_data_shift[34:31];
            r_data_shift[38:35] <= (r_data_shift[38:35] > 4) ? (r_data_shift[38:35] + 2'd3) : r_data_shift[38:35];
            r_data_shift[42:39] <= (r_data_shift[42:39] > 4) ? (r_data_shift[42:39] + 2'd3) : r_data_shift[42:39];
            r_data_shift[46:43] <= (r_data_shift[46:43] > 4) ? (r_data_shift[46:43] + 2'd3) : r_data_shift[46:43];
            r_data_shift[50:47] <= (r_data_shift[50:47] > 4) ? (r_data_shift[50:47] + 2'd3) : r_data_shift[50:47];
            r_data_shift[54:51] <= (r_data_shift[54:51] > 4) ? (r_data_shift[54:51] + 2'd3) : r_data_shift[54:51];
            r_data_shift[58:55] <= (r_data_shift[58:55] > 4) ? (r_data_shift[58:55] + 2'd3) : r_data_shift[58:55];
        end else if ((r_cnt_shift <= 5'd27) && r_shift_flag) begin
            r_data_shift <= r_data_shift << 1;
        end else begin
            r_data_shift <= r_data_shift;
        end
    end

    // ------------------------------------------------------------
    // r_shift_flag: dao co giua pha "add-3" va pha "shift"
    // ------------------------------------------------------------
    always @(posedge i_sys_clk) begin
        if (i_rst) begin
            r_shift_flag <= 1'b0;
        end else begin
            r_shift_flag <= ~r_shift_flag;
        end
    end

    // ------------------------------------------------------------
    // Xuat BCD sau khi hoan tat 28 buoc (cho 27 bit input)
    // ------------------------------------------------------------
    always @(posedge i_sys_clk) begin
        if (i_rst) begin
            o_units         <= 4'd0;
            o_tens          <= 4'd0;
            o_hundreds      <= 4'd0;
            o_thousands     <= 4'd0;
            o_ten_thousands <= 4'd0;
            o_hun_thousands <= 4'd0;
            o_millions      <= 4'd0;
            o_ten_millions  <= 4'd0;
        end else if (r_cnt_shift == 5'd28) begin
            o_units         <= r_data_shift[30:27];
            o_tens          <= r_data_shift[34:31];
            o_hundreds      <= r_data_shift[38:35];
            o_thousands     <= r_data_shift[42:39];
            o_ten_thousands <= r_data_shift[46:43];
            o_hun_thousands <= r_data_shift[50:47];
            o_millions      <= r_data_shift[54:51];
            o_ten_millions  <= r_data_shift[58:55];
        end
    end

endmodule
