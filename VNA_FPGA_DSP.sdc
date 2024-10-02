create_clock -name {sys_clk} -period 25 [get_ports sys_clk]
create_clock -name {hs_clk} -period 4 [get_pins PLL/outglobal_o]
create_clock -name {ms_clk} -period 8 [get_pins PLL/outglobalb_o]
