# ============================================================
# 3G-SDI GTH reference clock: 148.5 MHz
# 3G-SDI line rate 2.97 Gbps = 148.5 MHz x 20
# Must use dedicated MGTREFCLK-capable package pins.
# ============================================================
set_property PACKAGE_PIN XX [get_ports sdi_refclk_p]
set_property PACKAGE_PIN XX [get_ports sdi_refclk_n]
create_clock -name sdi_refclk -period 6.734 [get_ports sdi_refclk_p]

# ============================================================
# 3G-SDI GTH RX serial data pins
# Must use MGTHRXP/MGTHRXN-capable package pins.
# No IOSTANDARD constraint required for MGT pins.
# ============================================================
set_property PACKAGE_PIN XX [get_ports sdi_rx_p]
set_property PACKAGE_PIN XX [get_ports sdi_rx_n]

# ============================================================
# 3G-SDI GTH TX serial data pins
# Must use MGTHTXP/MGTHTXN-capable package pins.
# No IOSTANDARD constraint required for MGT pins.
# ============================================================
set_property PACKAGE_PIN XX [get_ports sdi_tx_p]
set_property PACKAGE_PIN XX [get_ports sdi_tx_n]

# ============================================================
# Status LEDs
# Update IOSTANDARD to match board bank voltage if needed.
# ============================================================
set_property PACKAGE_PIN XX [get_ports {led[0]}]
set_property PACKAGE_PIN XX [get_ports {led[1]}]
set_property PACKAGE_PIN XX [get_ports {led[2]}]
set_property PACKAGE_PIN XX [get_ports {led[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[*]}]
set_false_path -to [get_ports {led[*]}]

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
