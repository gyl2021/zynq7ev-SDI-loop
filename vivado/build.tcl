puts "=== SDI loopthrough build: start ==="

puts "=== Step 0: Close open project if any (idempotent) ==="
if {[llength [get_projects -quiet]] > 0} {
  close_project
}

set script_dir [file dirname [file normalize [info script]]]
set proj_dir [file normalize [file join $script_dir sdi_loopthrough]]
set xsa_out [file normalize [file join $script_dir sdi_loopthrough.xsa]]
set constraints_file [file normalize [file join $script_dir constraints top.xdc]]


proc pick_latest_ip_vlnv {ip_name} {
  set defs [get_ipdefs -all -quiet -filter "VLNV =~ xilinx.com:ip:${ip_name}:*"]
  if {[llength $defs] == 0} {
    return ""
  }
  set sorted [lsort -dictionary $defs]
  return [lindex $sorted end]
}

proc pick_first_available_ip_vlnv {ip_name_list} {
  foreach ip_name $ip_name_list {
    set vlnv [pick_latest_ip_vlnv $ip_name]
    if {$vlnv ne ""} {
      return $vlnv
    }
  }
  return ""
}

proc print_sdi_ip_catalog_hint {} {
  set all_sdi [lsort -dictionary [get_ipdefs -all -quiet -filter {VLNV =~ xilinx.com:ip:*sdi*}]]
  puts "Available xilinx.com SDI-related IPs:"
  if {[llength $all_sdi] == 0} {
    puts "  (none found)"
  } else {
    foreach d $all_sdi {
      puts "  $d"
    }
  }
}


proc set_config_if_exists {cell_name prop_name prop_value} {
  set obj [get_bd_cells $cell_name]
  set prop_path "CONFIG.${prop_name}"
  set props [list_property $obj]
  if {[lsearch -exact $props $prop_path] >= 0} {
    if {[catch {set_property -dict [list $prop_path $prop_value] $obj} err]} {
      puts "WARNING: Failed to set ${cell_name}.${prop_name}=${prop_value}: $err"
    } else {
      puts "Configured ${cell_name}.${prop_name}=${prop_value}"
    }
  } else {
    puts "INFO: ${cell_name}.${prop_name} not present for this IP variant; skipping"
  }
}

proc configure_sdi_rx {cell_name ip_vlnv} {
  set is_uhd [expr {[string first "uhdsdi" $ip_vlnv] >= 0}]
  if {$is_uhd} {
    puts "Applying UHD-SDI RX configuration profile"
    set_config_if_exists $cell_name C_LINE_RATE {3G_SDI}
    set_config_if_exists $cell_name C_SDI_MODE {3G_SDI}
  } else {
    puts "Applying SMPTE-SDI RX configuration profile"
    set_config_if_exists $cell_name C_SDI_MODE {3G_SDI}
    set_config_if_exists $cell_name C_INCLUDE_RX {1}
    set_config_if_exists $cell_name C_RX_TDATA_WIDTH {20}
    set_config_if_exists $cell_name C_LINE_RATE {2970}
    set_config_if_exists $cell_name C_INCLUDE_VID_OVER_AXI {1}
  }
}

proc configure_sdi_tx {cell_name ip_vlnv} {
  set is_uhd [expr {[string first "uhdsdi" $ip_vlnv] >= 0}]
  if {$is_uhd} {
    puts "Applying UHD-SDI TX configuration profile"
    set_config_if_exists $cell_name C_LINE_RATE {3G_SDI}
    set_config_if_exists $cell_name C_SDI_MODE {3G_SDI}
  } else {
    puts "Applying SMPTE-SDI TX configuration profile"
    set_config_if_exists $cell_name C_SDI_MODE {3G_SDI}
    set_config_if_exists $cell_name C_INCLUDE_TX {1}
    set_config_if_exists $cell_name C_TX_TDATA_WIDTH {20}
    set_config_if_exists $cell_name C_LINE_RATE {2970}
    set_config_if_exists $cell_name C_INCLUDE_VID_OVER_AXI {1}
  }
}


proc get_first_bd_pin {cell_name pin_name_list} {
  foreach pin_name $pin_name_list {
    set p [get_bd_pins -quiet ${cell_name}/${pin_name}]
    if {[llength $p] > 0} {
      return [lindex $p 0]
    }
  }
  return ""
}

proc get_first_bd_pin_by_pattern {cell_name pattern_list} {
  set pin_list [get_bd_pins -quiet -of_objects [get_bd_cells $cell_name]]
  foreach pat $pattern_list {
    foreach pin $pin_list {
      set n [get_property NAME $pin]
      if {[regexp -nocase $pat $n]} {
        return $pin
      }
    }
  }
  return ""
}

proc get_first_bd_intf_pin {cell_name intf_name_list} {
  foreach intf_name $intf_name_list {
    set p [get_bd_intf_pins -quiet ${cell_name}/${intf_name}]
    if {[llength $p] > 0} {
      return [lindex $p 0]
    }
  }
  return ""
}

proc get_first_bd_intf_pin_by_pattern {cell_name pattern_list} {
  set intf_list [get_bd_intf_pins -quiet -of_objects [get_bd_cells $cell_name]]
  foreach pat $pattern_list {
    foreach intf $intf_list {
      set n [get_property NAME $intf]
      if {[regexp -nocase $pat $n]} {
        return $intf
      }
    }
  }
  return ""
}

proc find_axis_prefix {cell_name prefix_list} {
  foreach pref $prefix_list {
    set p [get_bd_pins -quiet ${cell_name}/${pref}_tvalid]
    if {[llength $p] > 0} {
      return $pref
    }
  }
  return ""
}

proc connect_axis_stream_by_prefix {src_cell src_pref dst_cell dst_pref} {
  set sigs [list tdata tvalid tready tlast tuser tkeep]
  foreach s $sigs {
    set sp [get_bd_pins -quiet ${src_cell}/${src_pref}_${s}]
    set dp [get_bd_pins -quiet ${dst_cell}/${dst_pref}_${s}]
    if {[llength $sp] > 0 && [llength $dp] > 0} {
      connect_bd_net [lindex $sp 0] [lindex $dp 0]
    }
  }
}

proc connect_intf_if_present {src_intf dst_intf desc} {
  if {$src_intf eq "" || $dst_intf eq ""} {
    puts "WARNING: Skipping interface connection (${desc}) due to missing interface pin"
    return
  }
  connect_bd_intf_net $src_intf $dst_intf
}

proc connect_net_list {pin_list net_desc} {
  set valid_pins {}
  foreach p $pin_list {
    if {$p ne ""} {
      lappend valid_pins $p
    }
  }
  if {[llength $valid_pins] < 2} {
    puts "WARNING: Skipping net connection for ${net_desc}; not enough pins"
    return
  }
  set root_pin [lindex $valid_pins 0]
  foreach p [lrange $valid_pins 1 end] {
    connect_bd_net $root_pin $p
  }
}

proc connect_optional_pin_to_net {src_pin dst_cell pin_candidates desc} {
  set matched 0
  foreach pin_name $pin_candidates {
    set p [get_bd_pins -quiet ${dst_cell}/${pin_name}]
    if {[llength $p] > 0} {
      set matched 1
      if {[catch {connect_bd_net $src_pin [lindex $p 0]} err]} {
        puts "INFO: ${desc} (${dst_cell}/${pin_name}) not connected: $err"
      } else {
        puts "Connected ${desc}: ${src_pin} -> ${dst_cell}/${pin_name}"
      }
    }
  }
  if {!$matched} {
    puts "INFO: ${desc} not present on ${dst_cell}; skipping"
  }
}

proc assign_fixed_addr_if_present {addr_seg_path base_addr range_bytes} {
  set seg [get_bd_addr_segs -quiet $addr_seg_path]
  if {[llength $seg] > 0} {
    if {[catch {assign_bd_address -offset $base_addr -range $range_bytes $seg} err]} {
      puts "WARNING: Failed fixed assign for ${addr_seg_path} @ ${base_addr} (${range_bytes}): $err"
      assign_bd_address $seg
    }
  } else {
    puts "WARNING: Address segment not found (${addr_seg_path}); skipping fixed mapping"
  }
}

proc assign_addr_if_present {addr_seg_path} {
  set seg [get_bd_addr_segs -quiet $addr_seg_path]
  if {[llength $seg] > 0} {
    assign_bd_address $seg
  } else {
    puts "WARNING: Address segment not found (${addr_seg_path}); skipping"
  }
}

puts "=== Step 1: Create project ==="
create_project sdi_loopthrough $proj_dir \
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
set sdi_rx_vlnv [pick_first_available_ip_vlnv [list \
  "v_smpte_sdi_rx_ss" \
  "v_smpte_uhdsdi_rx_ss" \
]]
if {$sdi_rx_vlnv eq ""} {
  print_sdi_ip_catalog_hint
  error "No SDI RX subsystem IP found in catalog (tried: v_smpte_sdi_rx_ss, v_smpte_uhdsdi_rx_ss)."
}
puts "Using SDI RX IP: $sdi_rx_vlnv"
create_bd_cell -type ip \
  -vlnv $sdi_rx_vlnv sdi_rx_ss
configure_sdi_rx sdi_rx_ss $sdi_rx_vlnv

puts "=== Step 5: Create SDI TX Subsystem ==="
set sdi_tx_vlnv [pick_first_available_ip_vlnv [list \
  "v_smpte_sdi_tx_ss" \
  "v_smpte_uhdsdi_tx_ss" \
]]
if {$sdi_tx_vlnv eq ""} {
  print_sdi_ip_catalog_hint
  error "No SDI TX subsystem IP found in catalog (tried: v_smpte_sdi_tx_ss, v_smpte_uhdsdi_tx_ss)."
}
puts "Using SDI TX IP: $sdi_tx_vlnv"
create_bd_cell -type ip \
  -vlnv $sdi_tx_vlnv sdi_tx_ss
configure_sdi_tx sdi_tx_ss $sdi_tx_vlnv

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
set rx_axi_aclk [get_first_bd_pin sdi_rx_ss [list s_axi_aclk s_axi_ctrl_aclk]]
set tx_axi_aclk [get_first_bd_pin sdi_tx_ss [list s_axi_aclk s_axi_ctrl_aclk]]
set clk_nets [list   [get_bd_pins zynq_ps/pl_clk0]   [get_bd_pins zynq_ps/maxihpm0_fpd_aclk]   [get_bd_pins axi_ic/ACLK]   [get_bd_pins axi_ic/S00_ACLK]   [get_bd_pins axi_ic/M00_ACLK]   [get_bd_pins axi_ic/M01_ACLK]   [get_bd_pins axi_ic/M02_ACLK]   [get_bd_pins axi_gpio_0/s_axi_aclk]   [get_bd_pins proc_sys_reset_0/slowest_sync_clk] ]
if {$rx_axi_aclk ne ""} { lappend clk_nets $rx_axi_aclk }
if {$tx_axi_aclk ne ""} { lappend clk_nets $tx_axi_aclk }
connect_net_list $clk_nets "PL/AXI clocks"

# UHD-SDI variants can expose additional local clock pins that must be driven.
connect_optional_pin_to_net [get_bd_pins zynq_ps/pl_clk0] sdi_rx_ss [list sdi_rx_clk video_out_clk] "RX local clock"
connect_optional_pin_to_net [get_bd_pins zynq_ps/pl_clk0] sdi_tx_ss [list sdi_tx_clk video_in_clk] "TX local clock"

puts "=== Step 10: Connect resets ==="
connect_bd_net [get_bd_pins zynq_ps/pl_resetn0]   [get_bd_pins proc_sys_reset_0/ext_reset_in]
connect_bd_net   [get_bd_pins proc_sys_reset_0/interconnect_aresetn]   [get_bd_pins axi_ic/ARESETN]   [get_bd_pins axi_ic/S00_ARESETN]   [get_bd_pins axi_ic/M00_ARESETN]   [get_bd_pins axi_ic/M01_ARESETN]   [get_bd_pins axi_ic/M02_ARESETN]
set rx_axi_aresetn [get_first_bd_pin sdi_rx_ss [list s_axi_aresetn s_axi_ctrl_aresetn]]
set tx_axi_aresetn [get_first_bd_pin sdi_tx_ss [list s_axi_aresetn s_axi_ctrl_aresetn]]
set periph_rst_nets [list   [get_bd_pins proc_sys_reset_0/peripheral_aresetn]   [get_bd_pins axi_gpio_0/s_axi_aresetn] ]
if {$rx_axi_aresetn ne ""} { lappend periph_rst_nets $rx_axi_aresetn }
if {$tx_axi_aresetn ne ""} { lappend periph_rst_nets $tx_axi_aresetn }
connect_net_list $periph_rst_nets "peripheral resets"

# UHD-SDI variants can expose additional active-low reset pins for local domains.
connect_optional_pin_to_net [get_bd_pins proc_sys_reset_0/peripheral_aresetn] sdi_rx_ss [list s_axi_arstn video_out_arstn] "RX local resetn"
connect_optional_pin_to_net [get_bd_pins proc_sys_reset_0/peripheral_aresetn] sdi_tx_ss [list s_axi_arstn video_in_arstn] "TX local resetn"
connect_optional_pin_to_net [get_bd_pins proc_sys_reset_0/peripheral_reset] sdi_rx_ss [list sdi_rx_rst] "RX local reset (active-high)"
connect_optional_pin_to_net [get_bd_pins proc_sys_reset_0/peripheral_reset] sdi_tx_ss [list sdi_tx_rst] "TX local reset (active-high)"

puts "=== Step 11: Connect AXI interfaces ==="
connect_bd_intf_net   [get_bd_intf_pins zynq_ps/M_AXI_HPM0_FPD]   [get_bd_intf_pins axi_ic/S00_AXI]
set rx_s_axi [get_first_bd_intf_pin sdi_rx_ss [list S_AXI S_AXI_CTRL S_AXI_CTRL_REG]]
set tx_s_axi [get_first_bd_intf_pin sdi_tx_ss [list S_AXI S_AXI_CTRL S_AXI_CTRL_REG]]
connect_intf_if_present [get_bd_intf_pins axi_ic/M00_AXI] $rx_s_axi "AXI IC M00 -> SDI RX control"
connect_intf_if_present [get_bd_intf_pins axi_ic/M01_AXI] $tx_s_axi "AXI IC M01 -> SDI TX control"
connect_bd_intf_net   [get_bd_intf_pins axi_ic/M02_AXI]   [get_bd_intf_pins axi_gpio_0/S_AXI]

puts "=== Step 12: Connect SDI RX to SDI TX video stream ==="
set rx_vid_out [get_first_bd_intf_pin sdi_rx_ss [list M_AXIS_VIDEO M_AXIS M_AXIS_RX VIDEO_OUT]]
set tx_vid_in  [get_first_bd_intf_pin sdi_tx_ss [list S_AXIS_VIDEO S_AXIS S_AXIS_TX VIDEO_IN]]
if {$rx_vid_out eq ""} {
  set rx_vid_out [get_first_bd_intf_pin_by_pattern sdi_rx_ss [list {M_AXIS.*VIDEO} {M_AXIS} {VIDEO_OUT}]]
}
if {$tx_vid_in eq ""} {
  set tx_vid_in [get_first_bd_intf_pin_by_pattern sdi_tx_ss [list {S_AXIS.*VIDEO} {S_AXIS} {VIDEO_IN}]]
}
if {$rx_vid_out ne "" && $tx_vid_in ne ""} {
  connect_bd_intf_net $rx_vid_out $tx_vid_in
} else {
  set rx_pref [find_axis_prefix sdi_rx_ss [list VIDEO_OUT M_AXIS_VIDEO M_AXIS_RX M_AXIS S_AXIS_RX]]
  set tx_pref [find_axis_prefix sdi_tx_ss [list VIDEO_IN S_AXIS_VIDEO S_AXIS_TX S_AXIS M_AXIS_TX]]
  if {$rx_pref ne "" && $tx_pref ne ""} {
    puts "INFO: Using pin-level AXI4-Stream fallback: ${rx_pref}_* -> ${tx_pref}_*"
    connect_axis_stream_by_prefix sdi_rx_ss $rx_pref sdi_tx_ss $tx_pref
  } else {
    puts "WARNING: Unable to find compatible RX->TX AXI4-Stream interfaces or pin groups; skipping direct stream connection for this SDI IP variant"
  }
}

puts "=== Step 13: Assign addresses ==="
if {$rx_s_axi ne ""} {
  assign_fixed_addr_if_present "sdi_rx_ss/[get_property NAME $rx_s_axi]/Reg" 0xA0000000 64K
} else {
  puts "WARNING: SDI RX control AXI interface not present; skipping RX address assignment"
}
if {$tx_s_axi ne ""} {
  assign_fixed_addr_if_present "sdi_tx_ss/[get_property NAME $tx_s_axi]/Reg" 0xA0010000 64K
} else {
  puts "WARNING: SDI TX control AXI interface not present; skipping TX address assignment"
}
assign_fixed_addr_if_present "axi_gpio_0/S_AXI/Reg" 0xA0020000 64K

puts "=== Step 14: Build GPIO status vector ==="
create_bd_cell -type ip   -vlnv xilinx.com:ip:xlconcat:2.1 xlconcat_0
set_property CONFIG.NUM_PORTS {8} [get_bd_cells xlconcat_0]

create_bd_cell -type ip   -vlnv xilinx.com:ip:xlslice:1.0 xlslice_rx_locked
create_bd_cell -type ip   -vlnv xilinx.com:ip:xlslice:1.0 xlslice_tx_locked
create_bd_cell -type ip   -vlnv xilinx.com:ip:xlslice:1.0 xlslice_rx_ce
create_bd_cell -type ip   -vlnv xilinx.com:ip:xlslice:1.0 xlslice_rx_mode_locked
set_property -dict [list CONFIG.DIN_FROM {0} CONFIG.DIN_TO {0} CONFIG.DIN_WIDTH {32} CONFIG.DOUT_WIDTH {1}] [get_bd_cells xlslice_rx_locked]
set_property -dict [list CONFIG.DIN_FROM {0} CONFIG.DIN_TO {0} CONFIG.DIN_WIDTH {32} CONFIG.DOUT_WIDTH {1}] [get_bd_cells xlslice_tx_locked]
set_property -dict [list CONFIG.DIN_FROM {0} CONFIG.DIN_TO {0} CONFIG.DIN_WIDTH {32} CONFIG.DOUT_WIDTH {1}] [get_bd_cells xlslice_rx_ce]
set_property -dict [list CONFIG.DIN_FROM {0} CONFIG.DIN_TO {0} CONFIG.DIN_WIDTH {32} CONFIG.DOUT_WIDTH {1}] [get_bd_cells xlslice_rx_mode_locked]

create_bd_cell -type ip   -vlnv xilinx.com:ip:xlconstant:1.1 xlconstant_stat0
create_bd_cell -type ip   -vlnv xilinx.com:ip:xlconstant:1.1 xlconstant_statvec0
set_property -dict [list CONFIG.CONST_WIDTH {1} CONFIG.CONST_VAL {0}] [get_bd_cells xlconstant_stat0]
set_property -dict [list CONFIG.CONST_WIDTH {32} CONFIG.CONST_VAL {0}] [get_bd_cells xlconstant_statvec0]

set rx_locked_pin [get_first_bd_pin sdi_rx_ss [list rx_locked rx_mode_locked]]
set tx_locked_pin [get_first_bd_pin sdi_tx_ss [list tx_locked tx_mode_locked]]
set rx_ce_pin [get_first_bd_pin sdi_rx_ss [list rx_ce]]
set rx_mode_lock_pin [get_first_bd_pin sdi_rx_ss [list sdi_rx_mode_locked rx_mode_locked]]

if {$rx_locked_pin ne ""} { connect_bd_net $rx_locked_pin [get_bd_pins xlslice_rx_locked/Din] } else { connect_bd_net [get_bd_pins xlconstant_statvec0/dout] [get_bd_pins xlslice_rx_locked/Din] }
if {$tx_locked_pin ne ""} { connect_bd_net $tx_locked_pin [get_bd_pins xlslice_tx_locked/Din] } else { connect_bd_net [get_bd_pins xlconstant_statvec0/dout] [get_bd_pins xlslice_tx_locked/Din] }
if {$rx_ce_pin ne ""} { connect_bd_net $rx_ce_pin [get_bd_pins xlslice_rx_ce/Din] } else { connect_bd_net [get_bd_pins xlconstant_statvec0/dout] [get_bd_pins xlslice_rx_ce/Din] }
if {$rx_mode_lock_pin ne ""} { connect_bd_net $rx_mode_lock_pin [get_bd_pins xlslice_rx_mode_locked/Din] } else { connect_bd_net [get_bd_pins xlconstant_statvec0/dout] [get_bd_pins xlslice_rx_mode_locked/Din] }

connect_bd_net [get_bd_pins xlslice_rx_locked/Dout] [get_bd_pins xlconcat_0/In0]
connect_bd_net [get_bd_pins xlslice_tx_locked/Dout] [get_bd_pins xlconcat_0/In1]
connect_bd_net [get_bd_pins xlslice_rx_ce/Dout] [get_bd_pins xlconcat_0/In2]
connect_bd_net [get_bd_pins xlslice_rx_mode_locked/Dout] [get_bd_pins xlconcat_0/In3]
connect_bd_net [get_bd_pins xlconstant_stat0/dout] [get_bd_pins xlconcat_0/In4]
connect_bd_net [get_bd_pins xlconstant_stat0/dout] [get_bd_pins xlconcat_0/In5]
connect_bd_net [get_bd_pins xlconstant_stat0/dout] [get_bd_pins xlconcat_0/In6]
connect_bd_net [get_bd_pins xlconstant_stat0/dout] [get_bd_pins xlconcat_0/In7]

connect_bd_net [get_bd_pins xlconcat_0/dout]   [get_bd_pins axi_gpio_0/gpio_io_i]

puts "=== Step 15: Create top-level external ports ==="
create_bd_port -dir I sdi_rx_p
create_bd_port -dir I sdi_rx_n
create_bd_port -dir O sdi_tx_p
create_bd_port -dir O sdi_tx_n
create_bd_port -dir I sdi_refclk_p
create_bd_port -dir I sdi_refclk_n

set rx_gt_p_pin [get_first_bd_pin sdi_rx_ss [list rx_gt_p rxp rxp_in gt_rxp gt_rxp_in gthrxp_in mgt_rx_p mgt_rxp]]
set rx_gt_n_pin [get_first_bd_pin sdi_rx_ss [list rx_gt_n rxn rxn_in gt_rxn gt_rxn_in gthrxn_in mgt_rx_n mgt_rxn]]
set tx_gt_p_pin [get_first_bd_pin sdi_tx_ss [list tx_gt_p txp txp_out gt_txp gt_txp_out gthtxp_out mgt_tx_p mgt_txp]]
set tx_gt_n_pin [get_first_bd_pin sdi_tx_ss [list tx_gt_n txn txn_out gt_txn gt_txn_out gthtxn_out mgt_tx_n mgt_txn]]
set rx_refclk_p_pin [get_first_bd_pin sdi_rx_ss [list rx_gt_refclk_p gt_refclk_p refclk_p gt_refclk_p_in mgt_refclk_p]]
set rx_refclk_n_pin [get_first_bd_pin sdi_rx_ss [list rx_gt_refclk_n gt_refclk_n refclk_n gt_refclk_n_in mgt_refclk_n]]
set tx_refclk_p_pin [get_first_bd_pin sdi_tx_ss [list tx_gt_refclk_p gt_refclk_p refclk_p gt_refclk_p_in mgt_refclk_p]]
set tx_refclk_n_pin [get_first_bd_pin sdi_tx_ss [list tx_gt_refclk_n gt_refclk_n refclk_n gt_refclk_n_in mgt_refclk_n]]

if {$rx_gt_p_pin eq ""} { set rx_gt_p_pin [get_first_bd_pin_by_pattern sdi_rx_ss [list {(^|/).*(rx|gthrx|mgt_rx).*(^|_|/)p($|_|/)} {(^|/).*rxp.*}]] }
if {$rx_gt_n_pin eq ""} { set rx_gt_n_pin [get_first_bd_pin_by_pattern sdi_rx_ss [list {(^|/).*(rx|gthrx|mgt_rx).*(^|_|/)n($|_|/)} {(^|/).*rxn.*}]] }
if {$tx_gt_p_pin eq ""} { set tx_gt_p_pin [get_first_bd_pin_by_pattern sdi_tx_ss [list {(^|/).*(tx|gthtx|mgt_tx).*(^|_|/)p($|_|/)} {(^|/).*txp.*}]] }
if {$tx_gt_n_pin eq ""} { set tx_gt_n_pin [get_first_bd_pin_by_pattern sdi_tx_ss [list {(^|/).*(tx|gthtx|mgt_tx).*(^|_|/)n($|_|/)} {(^|/).*txn.*}]] }

if {$rx_gt_p_pin ne ""} { connect_bd_net $rx_gt_p_pin [get_bd_ports sdi_rx_p] } else { puts "WARNING: RX P serial pin not found on RX subsystem (available pins: [join [get_bd_pins -quiet -of_objects [get_bd_cells sdi_rx_ss]] , ])" }
if {$rx_gt_n_pin ne ""} { connect_bd_net $rx_gt_n_pin [get_bd_ports sdi_rx_n] } else { puts "WARNING: RX N serial pin not found on RX subsystem" }
if {$tx_gt_p_pin ne ""} { connect_bd_net $tx_gt_p_pin [get_bd_ports sdi_tx_p] } else { puts "WARNING: TX P serial pin not found on TX subsystem" }
if {$tx_gt_n_pin ne ""} { connect_bd_net $tx_gt_n_pin [get_bd_ports sdi_tx_n] } else { puts "WARNING: TX N serial pin not found on TX subsystem" }
if {$rx_refclk_p_pin ne ""} { connect_bd_net $rx_refclk_p_pin [get_bd_ports sdi_refclk_p] } else { puts "WARNING: RX refclk P pin not found on RX subsystem" }
if {$rx_refclk_n_pin ne ""} { connect_bd_net $rx_refclk_n_pin [get_bd_ports sdi_refclk_n] } else { puts "WARNING: RX refclk N pin not found on RX subsystem" }
if {$tx_refclk_p_pin ne ""} { connect_bd_net $tx_refclk_p_pin [get_bd_ports sdi_refclk_p] } else { puts "WARNING: TX refclk P pin not found on TX subsystem" }
if {$tx_refclk_n_pin ne ""} { connect_bd_net $tx_refclk_n_pin [get_bd_ports sdi_refclk_n] } else { puts "WARNING: TX refclk N pin not found on TX subsystem" }

puts "=== Step 16: Validate design and generate wrapper ==="
set bd_file [get_files system.bd]
validate_bd_design
save_bd_design
generate_target all $bd_file

# Build the BD in the top synthesis run to avoid a large fanout of OOC block runs.
if {[catch {set_property synth_checkpoint_mode None $bd_file} err]} {
  puts "WARNING: Failed to set synth_checkpoint_mode=None on system.bd: $err"
} else {
  puts "Configured system.bd synth_checkpoint_mode=None"
}

make_wrapper -files $bd_file -top
add_files -norecurse \
  $proj_dir/sdi_loopthrough.gen/sources_1/bd/system/hdl/system_wrapper.v
set_property top system_wrapper [current_fileset]
update_compile_order -fileset sources_1

puts "=== Step 16b: Add constraints (if present) ==="
if {[file exists $constraints_file]} {
  add_files -fileset constrs_1 -norecurse $constraints_file
} else {
  puts "WARNING: ${constraints_file} not found; skipping constraints add"
}

puts "=== Step 17: Run synthesis/implementation and export XSA ==="
launch_runs synth_1 -jobs 8
wait_on_run synth_1
launch_runs impl_1 -to_step write_bitstream -jobs 8
wait_on_run impl_1
write_hw_platform -fixed -include_bit -file $xsa_out

puts "=== DONE: sdi_loopthrough.xsa ==="
