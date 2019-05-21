###############################################################################
#
# program_fpga.tcl: Tcl script for programming bit file
# Usage:
# source /home/Xilinx/Vivado/201x.x/settings64.sh
# vivado -mode tcl vivado -mode tcl -nojournal -nolog -source program_fpga.tcl
#
#https://www.xilinx.com/support/documentation/sw_manuals/xilinx2014_4/ug908-vivado-programming-debugging.pdf
#http://eng.umb.edu/~cuckov/classes/engin341/Labs/Debug%20Tutorial/Vivado%20Debugging%20Tutorial.pdf
#
################################################################################
#set DEBUG_CORE true
set DEBUG_CORE false

set hw_device xc7k325t_0

open_hw

# Connect to the Digilent Cable on localhost:3121

connect_hw_server -url localhost:3121
#refresh_hw_server
#current_hw_target [get_hw_targets */xilinx_tcf/Digilent/210203341302A]
current_hw_target [get_hw_targets */xilinx_tcf/Digilent/2102033*]
open_hw_target

# Program and Refresh the XC7K325T Device

#set bit_file "vivado_project/vivado_project.runs/impl_1/xilinx_pcie_2_1_ep_7x.bit"
set bit_file "../out/kc705"
#current_hw_device [lindex [get_hw_devices xc7k325t_1] 0]
current_hw_device [get_hw_devices $hw_device]
#current_hw_device [lindex [get_hw_devices] $hw_dev]
#refresh_hw_device -update_hw_probes false [lindex [get_hw_devices] $hw_dev]
refresh_hw_device -update_hw_probes false [lindex [get_hw_devices xc7k325t_0] 0]
#refresh_hw_device -update_hw_probes false [lindex [get_hw_devices xc7k325t_1] 0]
#refresh_hw_device -update_hw_probes false [lindex [get_hw_devices] $hw_dev]
set_property PROGRAM.FILE "$bit_file.bit" [lindex [get_hw_devices $hw_device] 0]

if {$DEBUG_CORE == true} {
    set_property PROBES.FILE  {out/kc705.ltx} [lindex [get_hw_devices $hw_device] 0]
} else {
    set_property PROBES.FILE  {} [lindex [get_hw_devices $hw_device] 0]
}

program_hw_devices [get_hw_devices $hw_device]
refresh_hw_device [lindex [get_hw_devices $hw_device] 0]

exit
