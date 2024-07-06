gui_open_window Wave
gui_sg_create System_clock_input_group
gui_list_add_group -id Wave.1 {System_clock_input_group}
gui_sg_addsignal -group System_clock_input_group {System_clock_input_tb.test_phase}
gui_set_radix -radix {ascii} -signals {System_clock_input_tb.test_phase}
gui_sg_addsignal -group System_clock_input_group {{Input_clocks}} -divider
gui_sg_addsignal -group System_clock_input_group {System_clock_input_tb.CLK_IN1}
gui_sg_addsignal -group System_clock_input_group {{Output_clocks}} -divider
gui_sg_addsignal -group System_clock_input_group {System_clock_input_tb.dut.clk}
gui_list_expand -id Wave.1 System_clock_input_tb.dut.clk
gui_sg_addsignal -group System_clock_input_group {{Counters}} -divider
gui_sg_addsignal -group System_clock_input_group {System_clock_input_tb.COUNT}
gui_sg_addsignal -group System_clock_input_group {System_clock_input_tb.dut.counter}
gui_list_expand -id Wave.1 System_clock_input_tb.dut.counter
gui_zoom -window Wave.1 -full
