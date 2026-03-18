# ============================================================
# 3G-SDI GTH reference clock: 148.5 MHz
# 3G-SDI line rate 2.97 Gbps = 148.5 MHz x 20
# Must use dedicated MGTREFCLK-capable package pins.
# ============================================================
set sdi_refclk_p_port [get_ports -quiet sdi_refclk_p]
set sdi_refclk_n_port [get_ports -quiet sdi_refclk_n]
if {[llength $sdi_refclk_p_port] > 0} {
    set_property PACKAGE_PIN Y8 $sdi_refclk_p_port
    create_clock -name sdi_refclk -period 6.734 $sdi_refclk_p_port
}
if {[llength $sdi_refclk_n_port] > 0} {
    set_property PACKAGE_PIN Y7 $sdi_refclk_n_port
}

# ============================================================
# 3G-SDI GTH RX serial data pins
# Must use MGTHRXP/MGTHRXN-capable package pins.
# No IOSTANDARD constraint required for MGT pins.
# ============================================================
set sdi_rx_p_port [get_ports -quiet sdi_rx_p]
set sdi_rx_n_port [get_ports -quiet sdi_rx_n]
if {[llength $sdi_rx_p_port] > 0} {
    set_property PACKAGE_PIN AA2 $sdi_rx_p_port
}
if {[llength $sdi_rx_n_port] > 0} {
    set_property PACKAGE_PIN AA1 $sdi_rx_n_port
}

# ============================================================
# 3G-SDI GTH TX serial data pins
# Must use MGTHTXP/MGTHTXN-capable package pins.
# No IOSTANDARD constraint required for MGT pins.
# ============================================================
set sdi_tx_p_port [get_ports -quiet sdi_tx_p]
set sdi_tx_n_port [get_ports -quiet sdi_tx_n]
if {[llength $sdi_tx_p_port] > 0} {
    set_property PACKAGE_PIN AC6 $sdi_tx_p_port
}
if {[llength $sdi_tx_n_port] > 0} {
    set_property PACKAGE_PIN AC5 $sdi_tx_n_port
}

# ============================================================
# Status LEDs
# Update IOSTANDARD to match board bank voltage if needed.
# ============================================================
set led_ports [get_ports -quiet {led[*]}]
if {[llength $led_ports] > 0} {
    set_property PACKAGE_PIN G20 [get_ports -quiet {led[0]}]
    set_property PACKAGE_PIN D21 [get_ports -quiet {led[1]}]
    set_property PACKAGE_PIN D20 [get_ports -quiet {led[2]}]
    set_property PACKAGE_PIN H22 [get_ports -quiet {led[3]}]
    set_property IOSTANDARD LVCMOS12 $led_ports
    set_false_path -to $led_ports
}

# ============================================================
# Asynchronous clock domain isolation
# - sdi_refclk is external MGT reference clock.
# - RXOUTCLK is recovered clock in transceiver receive path.
# ============================================================
set_clock_groups -asynchronous \
  -group [get_clocks sdi_refclk] \
  -group [get_clocks -of_objects [get_pins -hierarchical -filter {NAME =~ */RXOUTCLK}]]

# ============================================================
# Bitstream/device configuration
# ============================================================
set_property BITSTREAM.CONFIG.SPI_BUSWIDTH 4 [current_design]
set_property CONFIG_VOLTAGE 1.8 [current_design]
set_property CFGBVS GND [current_design]
