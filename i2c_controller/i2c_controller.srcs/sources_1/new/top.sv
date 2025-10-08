module top
(
    input  wire        i_sys_clk,
    input  wire        i_rst,        // reset dong bo, active-HIGH

    inout  wire        io_i2c_sda,

    output wire        o_i2c_scl,
    output wire [7:0]  o_sel,
    output wire [7:0]  o_seg
);

    // ==============================
    // Wiring
    // ==============================
    wire [26:0] w_rd_data;

    // ==============================
    // I2C ADT7420 master
    // ==============================
    i2c_master #(
        .DEVICE_ADDR   (7'b1001_011),     // ADT7420 7-bit address (0x49)
        .SYS_CLK_FREQ  ('d100_000_000),   // 100 MHz
        .SCL_FREQ      ('d250_000)        // 250 kHz
    ) u_i2c_master (
        .i_sys_clk (i_sys_clk),
        .i_rst     (i_rst),

        .io_i2c_sda(io_i2c_sda),

        .o_i2c_scl (o_i2c_scl),
        .o_rd_data (w_rd_data)
    );

    // ==============================
    // 7-seg dynamic display
    // ==============================
    seg_dynamic #(
        .CNT_MAX(17'd99_999)              // ~1ms @ 100 MHz
    ) u_seg_dynamic (
        .i_sys_clk (i_sys_clk),
        .i_rst     (i_rst),
        .i_data    (w_rd_data),

        .o_sel     (o_sel),
        .o_seg     (o_seg)
    );

endmodule
