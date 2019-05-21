###############################################################################
#
# project_implement_all.tcl: Tcl script for creating the VIVADO project
#
# Usage:
# source /home/Xilinx/Vivado/2018.3/settings64.sh
# vivado -mode batch -source project_implement_all.tcl
# See https://github.com/Digilent/digilent-vivado-scripts
################################################################################
#set DEBUG_CORE true
set DEBUG_CORE false
set WRITE_MCS true
#set PCIE_GEN 1

set top_file xilinx_pcie_2_1_ep_7x

# Set the reference directory to where the script is
set origin_dir [file dirname [info script]]

cd $origin_dir
#
################################################################################
# install UltraFast Design Methodology from TCL Store
#################################################################################

tclapp::install -quiet ultrafast

#
################################################################################
# define paths
################################################################################

set path_rtl ../src/hdl
set path_ip  ../src/ip
set path_sdc ../src/constraints

set path_out ../out

file mkdir $path_out
################################################################################
# setup the project
################################################################################

set part xc7k325tffg900-2
### xc7k325tfbg676-2

## Create project
create_project -in_memory -part $part

set_property board_part xilinx.com:kc705:part0:1.5 [current_project]
################################################################################
# read files:
# 1. RTL design sources
# 2. IP database files
# 3. constraints
################################################################################

add_files              $path_rtl

set_property top_file {$path_rtl/$top_file} [current_fileset]
#read_ip                $path_ip/dma_fifo/dma_fifo.xci
#read_ip    $path_ip/pcie_7x_gen2/pcie_7x_0.xci
read_ip    $path_ip/pcie_7x_gen2_id76/pcie_7x_gen2_id76.xci

##generate_target  all [get_ips] -force
#https://www.xilinx.com/support/answers/58526.html
#generate_target  {synthesis implementation instantiation_template} [get_ips]
generate_target  {synthesis instantiation_template} [get_ips]

read_xdc   $path_sdc/xilinx_pcie_7x_ep_x4g2.xdc

# Optional: to implement put on Tcl Console
################################################################################
# run synthesis
# report utilization and timing estimates
# write checkpoint design (open_checkpoint filename)
################################################################################

set_param general.maxThreads 8

synth_design -top $top_file
#synth_design -top red_pitaya_top -flatten_hierarchy none -bufg 16 -keep_equivalent_registers

write_checkpoint         -force   $path_out/post_synth
report_timing_summary    -file    $path_out/post_synth_timing_summary.rpt
report_power             -file    $path_out/post_synth_power.rpt

################################################################################
# insert debug core
#
################################################################################
if {$DEBUG_CORE == true} {
    source debug_core.tcl
}

################################################################################
# run placement and logic optimization
# report utilization and timing estimates
# write checkpoint design
################################################################################

opt_design
power_opt_design
place_design
phys_opt_design
write_checkpoint         -force   $path_out/post_place
report_timing_summary    -file    $path_out/post_place_timing_summary.rpt
#write_hwdef              -file    $path_sdk/red_pitaya.hwdef

################################################################################
# run router
# report actual utilization and timing,
# write checkpoint design
# run drc, write verilog and xdc out
################################################################################

route_design
write_checkpoint         -force   $path_out/post_route
report_timing_summary    -file    $path_out/post_route_timing_summary.rpt
report_timing            -file    $path_out/post_route_timing.rpt -sort_by group -max_paths 100 -path_type summary
report_clock_utilization -file    $path_out/clock_util.rpt
report_utilization       -file    $path_out/post_route_util.rpt
report_power             -file    $path_out/post_route_power.rpt
report_drc               -file    $path_out/post_imp_drc.rpt
report_io                -file    $path_out/post_imp_io.rpt
#write_verilog            -force   $path_out/bft_impl_netlist.v
#write_xdc -no_fixed_only -force   $path_out/bft_impl.xdc

xilinx::ultrafast::report_io_reg -verbose -file $path_out/post_route_iob.rpt

################################################################################
# generate a bitstream and debug probes
################################################################################

if {$DEBUG_CORE == true} {
    write_debug_probes -force            $path_out/kc705.ltx
}

write_bitstream -force            $path_out/kc705.bit

close_project

if {$WRITE_MCS == true} {
    write_cfgmem -force -format MCS -size 128 -interface BPIx16 -loadbit "up 0x0 $path_out/kc705.bit" -verbose $path_out/kc705.mcs
}
exit
