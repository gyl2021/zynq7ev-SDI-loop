puts "=== SDI loopthrough build: start ==="

puts "=== Step 0: Close open project if any (idempotent) ==="
if {[llength [get_projects -quiet]] > 0} {
  close_project
}

puts "=== Step 1: Create project ==="
create_project sdi_loopthrough ./sdi_loopthrough \
  -part xczu7ev-ffvc1156-2-e -force
set_property target_language Verilog [current_project]

puts "=== Step 2: Create block design ==="
create_bd_design "system"

puts "=== Step 3: Create Zynq UltraScale+ PS ==="
create_bd_cell -type ip \
  -vlnv xilinx.com:ip:zynq_ultra_ps_e:3.4 zynq_ps
set_property -dict [list \
  CONFIG.PSU__FPGA_PL0_ENABLE                 {1}            \
  CONFIG.PSU__CRL_APB__PL0_REF_CTRL__FREQMHZ  {100}          \
  CONFIG.PSU__UART0__PERIPHERAL__ENABLE       {1}            \
  CONFIG.PSU__UART0__PERIPHERAL__IO           {MIO 18 .. 19} \
  CONFIG.PSU__USE__M_AXI_GP0                  {1}            \
  CONFIG.PSU__MAXIGP0__DATA_WIDTH             {32}           \
  CONFIG.PSU__USE__M_AXI_GP2                  {0}            \
] [get_bd_cells zynq_ps]

puts "=== Step 4: Create SDI RX Subsystem ==="
create_bd_cell -type ip \
  -vlnv xilinx.com:ip:v_smpte_sdi_rx_ss:2.0 sdi_rx_ss
set_property -dict [list \
  CONFIG.C_SDI_MODE               {3G_SDI} \
  CONFIG.C_INCLUDE_RX             {1}      \
  CONFIG.C_RX_TDATA_WIDTH         {20}     \
  CONFIG.C_LINE_RATE              {2970}   \
  CONFIG.C_INCLUDE_VID_OVER_AXI   {1}      \
] [get_bd_cells sdi_rx_ss]

puts "=== Step 5: Create SDI TX Subsystem ==="
create_bd_cell -type ip \
  -vlnv xilinx.com:ip:v_smpte_sdi_tx_ss:2.0 sdi_tx_ss
set_property -dict [list \
  CONFIG.C_SDI_MODE               {3G_SDI} \
  CONFIG.C_INCLUDE_TX             {1}      \
  CONFIG.C_TX_TDATA_WIDTH         {20}     \
  CONFIG.C_LINE_RATE              {2970}   \
  CONFIG.C_INCLUDE_VID_OVER_AXI   {1}      \
] [get_bd_cells sdi_tx_ss]

puts "=== Step 6: Create AXI Interconnect ==="
create_bd_cell -type ip \
  -vlnv xilinx.com:ip:axi_interconnect:2.1 axi_ic
set_property CONFIG.NUM_MI {3} [get_bd_cells axi_ic]

puts "=== Step 7: Create Processor System Reset ==="
create_bd_cell -type ip \
  -vlnv xilinx.com:ip:proc_sys_reset:5.0 proc_sys_reset_0

puts "=== Step 8: Create AXI GPIO ==="
create_bd_cell -type ip \
  -vlnv xilinx.com:ip:axi_gpio:2.0 axi_gpio_0
set_property -dict [list \
  CONFIG.C_GPIO_WIDTH {8} \
  CONFIG.C_ALL_INPUTS {1} \
] [get_bd_cells axi_gpio_0]

puts "=== Step 9: Connect clocks ==="
connect_bd_net [get_bd_pins zynq_ps/pl_clk0] \
  [get_bd_pins zynq_ps/maxihpm0_fpd_aclk] \
  [get_bd_pins axi_ic/ACLK] \
  [get_bd_pins axi_ic/S00_ACLK] \
  [get_bd_pins axi_ic/M00_ACLK] \
  [get_bd_pins axi_ic/M01_ACLK] \
  [get_bd_pins axi_ic/M02_ACLK] \
  [get_bd_pins sdi_rx_ss/s_axi_aclk] \
  [get_bd_pins sdi_tx_ss/s_axi_aclk] \
  [get_bd_pins axi_gpio_0/s_axi_aclk] \
  [get_bd_pins proc_sys_reset_0/slowest_sync_clk]

puts "=== Step 10: Connect resets ==="
connect_bd_net [get_bd_pins zynq_ps/pl_resetn0] \
  [get_bd_pins proc_sys_reset_0/ext_reset_in]
connect_bd_net \
  [get_bd_pins proc_sys_reset_0/interconnect_aresetn] \
  [get_bd_pins axi_ic/ARESETN] \
  [get_bd_pins axi_ic/S00_ARESETN] \
  [get_bd_pins axi_ic/M00_ARESETN] \
  [get_bd_pins axi_ic/M01_ARESETN] \
  [get_bd_pins axi_ic/M02_ARESETN]
connect_bd_net \
  [get_bd_pins proc_sys_reset_0/peripheral_aresetn] \
  [get_bd_pins sdi_rx_ss/s_axi_aresetn] \
  [get_bd_pins sdi_tx_ss/s_axi_aresetn] \
  [get_bd_pins axi_gpio_0/s_axi_aresetn]

puts "=== Step 11: Connect AXI interfaces ==="
connect_bd_intf_net \
  [get_bd_intf_pins zynq_ps/M_AXI_HPM0_FPD] \
  [get_bd_intf_pins axi_ic/S00_AXI]
connect_bd_intf_net \
  [get_bd_intf_pins axi_ic/M00_AXI] \
  [get_bd_intf_pins sdi_rx_ss/S_AXI]
connect_bd_intf_net \
  [get_bd_intf_pins axi_ic/M01_AXI] \
  [get_bd_intf_pins sdi_tx_ss/S_AXI]
connect_bd_intf_net \
  [get_bd_intf_pins axi_ic/M02_AXI] \
  [get_bd_intf_pins axi_gpio_0/S_AXI]

puts "=== Step 12: Connect SDI RX to SDI TX video stream ==="
connect_bd_intf_net \
  [get_bd_intf_pins sdi_rx_ss/M_AXIS_VIDEO] \
  [get_bd_intf_pins sdi_tx_ss/S_AXIS_VIDEO]

puts "=== Step 13: Assign addresses ==="
assign_bd_address [get_bd_addr_segs {sdi_rx_ss/S_AXI/Reg}]
assign_bd_address [get_bd_addr_segs {sdi_tx_ss/S_AXI/Reg}]
assign_bd_address [get_bd_addr_segs {axi_gpio_0/S_AXI/Reg}]

puts "=== Step 14: Build GPIO status vector ==="
create_bd_cell -type ip \
  -vlnv xilinx.com:ip:xlconcat:2.1 xlconcat_0
set_property CONFIG.NUM_PORTS {8} [get_bd_cells xlconcat_0]
connect_bd_net [get_bd_pins sdi_rx_ss/rx_locked] \
  [get_bd_pins xlconcat_0/In0]
connect_bd_net [get_bd_pins sdi_tx_ss/tx_locked] \
  [get_bd_pins xlconcat_0/In1]
connect_bd_net [get_bd_pins sdi_rx_ss/rx_ce] \
  [get_bd_pins xlconcat_0/In2]
connect_bd_net [get_bd_pins sdi_rx_ss/sdi_rx_mode_locked] \
  [get_bd_pins xlconcat_0/In3]
create_bd_cell -type ip \
  -vlnv xilinx.com:ip:xlconstant:1.1 xlconstant_0
set_property -dict [list \
  CONFIG.CONST_WIDTH {4} \
  CONFIG.CONST_VAL   {0} \
] [get_bd_cells xlconstant_0]
connect_bd_net [get_bd_pins xlconstant_0/dout] \
  [get_bd_pins xlconcat_0/In4]
connect_bd_net [get_bd_pins xlconcat_0/dout] \
  [get_bd_pins axi_gpio_0/gpio_io_i]

puts "=== Step 15: Create top-level external ports ==="
create_bd_port -dir I sdi_rx_p
create_bd_port -dir I sdi_rx_n
create_bd_port -dir O sdi_tx_p
create_bd_port -dir O sdi_tx_n
create_bd_port -dir I sdi_refclk_p
create_bd_port -dir I sdi_refclk_n

connect_bd_net [get_bd_pins sdi_rx_ss/rx_gt_p] \
  [get_bd_ports sdi_rx_p]
connect_bd_net [get_bd_pins sdi_rx_ss/rx_gt_n] \
  [get_bd_ports sdi_rx_n]
connect_bd_net [get_bd_pins sdi_tx_ss/tx_gt_p] \
  [get_bd_ports sdi_tx_p]
connect_bd_net [get_bd_pins sdi_tx_ss/tx_gt_n] \
  [get_bd_ports sdi_tx_n]
connect_bd_net [get_bd_pins sdi_rx_ss/rx_gt_refclk_p] \
  [get_bd_ports sdi_refclk_p]
connect_bd_net [get_bd_pins sdi_rx_ss/rx_gt_refclk_n] \
  [get_bd_ports sdi_refclk_n]
connect_bd_net [get_bd_pins sdi_tx_ss/tx_gt_refclk_p] \
  [get_bd_ports sdi_refclk_p]
connect_bd_net [get_bd_pins sdi_tx_ss/tx_gt_refclk_n] \
  [get_bd_ports sdi_refclk_n]

puts "=== Step 16: Validate design and generate wrapper ==="
validate_bd_design
save_bd_design
generate_target all [get_files system.bd]
make_wrapper -files [get_files system.bd] -top
add_files -norecurse \
  ./sdi_loopthrough.gen/sources_1/bd/system/hdl/system_wrapper.v
set_property top system_wrapper [current_fileset]

puts "=== Step 16b: Add constraints (if present) ==="
if {[file exists ./vivado/constraints/top.xdc]} {
  add_files -fileset constrs_1 -norecurse ./vivado/constraints/top.xdc
} else {
  puts "WARNING: ./vivado/constraints/top.xdc not found; skipping constraints add"
}

puts "=== Step 17: Run synthesis/implementation and export XSA ==="
launch_runs synth_1 -jobs 8
wait_on_run synth_1
launch_runs impl_1 -to_step write_bitstream -jobs 8
wait_on_run impl_1
write_hw_platform -fixed -include_bit -file ./sdi_loopthrough.xsa

puts "=== DONE: sdi_loopthrough.xsa ==="
