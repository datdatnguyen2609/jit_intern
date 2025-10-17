## =========================
## Nexys A7 constraints (template - s? fill PIN khi b?n xác nh?n PMOD)
## =========================

## ---- Clock 100 MHz (fixed on E3) ----
set_property PACKAGE_PIN E3 [get_ports { i_clk }]
set_property IOSTANDARD  LVCMOS33 [get_ports { i_clk }]
create_clock -name sys_clk -period 10.000 [get_ports { i_clk }]

## ---- Reset (active-HIGH) ----
set_property PACKAGE_PIN <PIN_RST> [get_ports { i_rst }]
set_property IOSTANDARD  LVCMOS33  [get_ports { i_rst }]
#set_property PULLUP     true       [get_ports { i_rst }]

## ---- SPI (choose PMOD: JA/JB/JC/JD) ----
## If JA: tell mình ?? mình ?i?n C17/D18/E18/G17/... chính xác theo manual
## o_csn
set_property PACKAGE_PIN <PIN_CSN>  [get_ports { o_csn  }]
set_property IOSTANDARD  LVCMOS33   [get_ports { o_csn  }]
set_property DRIVE       8          [get_ports { o_csn  }]
set_property SLEW        FAST       [get_ports { o_csn  }]

## o_sclk
set_property PACKAGE_PIN <PIN_SCLK> [get_ports { o_sclk }]
set_property IOSTANDARD  LVCMOS33   [get_ports { o_sclk }]
set_property DRIVE       8          [get_ports { o_sclk }]
set_property SLEW        FAST       [get_ports { o_sclk }]

## o_mosi
set_property PACKAGE_PIN <PIN_MOSI> [get_ports { o_mosi }]
set_property IOSTANDARD  LVCMOS33   [get_ports { o_mosi }]
set_property DRIVE       8          [get_ports { o_mosi }]
set_property SLEW        FAST       [get_ports { o_mosi }]

## i_miso
set_property PACKAGE_PIN <PIN_MISO> [get_ports { i_miso }]
set_property IOSTANDARD  LVCMOS33   [get_ports { i_miso }]
#set_property PULLUP     true        [get_ports { i_miso }]

## ---- 7-seg (active-LOW): o_seg[6:0] = {a,b,c,d,e,f,g}, o_an[3:0] ----
## Mình s? ?i?n các PIN th?t khi b?n xác nh?n board/rev; d??i ?ây là attributes chu?n.
## Segments a..g
set_property PACKAGE_PIN <PIN_SEGa> [get_ports { o_seg[6] }]
set_property PACKAGE_PIN <PIN_SEGb> [get_ports { o_seg[5] }]
set_property PACKAGE_PIN <PIN_SEGc> [get_ports { o_seg[4] }]
set_property PACKAGE_PIN <PIN_SEGd> [get_ports { o_seg[3] }]
set_property PACKAGE_PIN <PIN_SEGe> [get_ports { o_seg[2] }]
set_property PACKAGE_PIN <PIN_SEGf> [get_ports { o_seg[1] }]
set_property PACKAGE_PIN <PIN_SEGg> [get_ports { o_seg[0] }]
set_property IOSTANDARD  LVCMOS33    [get_ports { o_seg[*] }]
set_property DRIVE       8           [get_ports { o_seg[*] }]
set_property SLEW        SLOW        [get_ports { o_seg[*] }]

## Digit enables an[3:0] (active-LOW)
set_property PACKAGE_PIN <PIN_AN3>  [get_ports { o_an[3] }]
set_property PACKAGE_PIN <PIN_AN2>  [get_ports { o_an[2] }]
set_property PACKAGE_PIN <PIN_AN1>  [get_ports { o_an[1] }]
set_property PACKAGE_PIN <PIN_AN0>  [get_ports { o_an[0] }]
set_property IOSTANDARD  LVCMOS33   [get_ports { o_an[*] }]
set_property DRIVE       8          [get_ports { o_an[*] }]
set_property SLEW        SLOW       [get_ports { o_an[*] }]

## Optional timing
# set_false_path -from [get_ports i_rst]
