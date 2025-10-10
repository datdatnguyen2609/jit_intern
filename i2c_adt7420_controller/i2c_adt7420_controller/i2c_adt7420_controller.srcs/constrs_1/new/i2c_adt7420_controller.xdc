## =========================================================
## Nexys A7 Constraints for i2c_adt7420_controller
## - sys_clk @ 100 MHz
## - sys_rst_n (BTNC Center button, active-LOW)
## - I2C on GPIO (C14/C15)
## - rd_data[7:0] ? Board LEDs LD0..LD7
## =========================================================

## -------------------------
## Clock 100 MHz
## -------------------------
set_property PACKAGE_PIN E3 [get_ports {sys_clk}]
set_property IOSTANDARD LVCMOS33 [get_ports {sys_clk}]
create_clock -name sys_clk -period 10.000 [get_ports {sys_clk}]  ;# 100 MHz

## -------------------------
## Reset (BTNC - active-low)
## BTNC (Center button) = N17
## -------------------------
set_property PACKAGE_PIN N17 [get_ports {sys_rst_n}]
set_property IOSTANDARD LVCMOS33 [get_ports {sys_rst_n}]
set_property PULLUP true [get_ports {sys_rst_n}]

## -------------------------
## I2C (bit-bang/custom controller)
## SDA/SCL c?n pull-up (2.2k-4.7k ngoài); có th? b?t PULLUP n?i ?? th? nghi?m
## -------------------------
set_property PACKAGE_PIN C14 [get_ports {i2c_scl}]
set_property PACKAGE_PIN C15 [get_ports {i2c_sda}]
set_property IOSTANDARD LVCMOS33 [get_ports {i2c_scl i2c_sda}]
# B?t n?u KHÔNG có ?i?n tr? kéo lên ngoài (ch? ?? test lab):
# set_property PULLUP true [get_ports {i2c_scl}]
# set_property PULLUP true [get_ports {i2c_sda}]
# Khuy?n ngh? biên ch?m cho tín hi?u ngo?i vi ch?m:
# set_property SLEW SLOW [get_ports {i2c_scl i2c_sda}]
# set_property DRIVE 8    [get_ports {i2c_scl i2c_sda}]

## -------------------------
## Display rd_data[7:0] on 8 on-board LEDs
## Mapping (LD0..LD7) = H17 K15 J13 N14 R18 V17 U17 U16
## rd_data[7:2] = 6-bit integer, rd_data[1:0] = 2-bit fraction (Q6.2)
## -------------------------
set_property IOSTANDARD LVCMOS33 [get_ports {rd_data[*]}]

set_property PACKAGE_PIN H17 [get_ports {rd_data[0]}]  ;# LD0  (frac LSB, 0.25)
set_property PACKAGE_PIN K15 [get_ports {rd_data[1]}]  ;# LD1  (frac MSB, 0.50)
set_property PACKAGE_PIN J13 [get_ports {rd_data[2]}]  ;# LD2  (int bit0)
set_property PACKAGE_PIN N14 [get_ports {rd_data[3]}]  ;# LD3  (int bit1)
set_property PACKAGE_PIN R18 [get_ports {rd_data[4]}]  ;# LD4  (int bit2)
set_property PACKAGE_PIN V17 [get_ports {rd_data[5]}]  ;# LD5  (int bit3)
set_property PACKAGE_PIN U17 [get_ports {rd_data[6]}]  ;# LD6  (int bit4)
set_property PACKAGE_PIN U16 [get_ports {rd_data[7]}]  ;# LD7  (int bit5)

# Tu? ch?n: làm ch?m biên ?? gi?m nhi?u khi quét LED
# set_property SLEW SLOW [get_ports {rd_data[*]}]
# set_property DRIVE 8    [get_ports {rd_data[*]}]
