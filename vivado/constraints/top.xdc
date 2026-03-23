# ============================================================
# 3G-SDI GTH reference clock: 148.5 MHz
# 3G-SDI line rate 2.97 Gbps = 148.5 MHz x 20
# Must use dedicated MGTREFCLK-capable package pins.
# ============================================================
set_property PACKAGE_PIN Y8 [get_ports sdi_refclk_p]
set_property PACKAGE_PIN Y7 [get_ports sdi_refclk_n]
create_clock -name sdi_refclk -period 6.734 [get_ports sdi_refclk_p]

# ============================================================
# 3G-SDI GTH RX serial data pins
# Must use MGTHRXP/MGTHRXN-capable package pins.
# No IOSTANDARD constraint required for MGT pins.
# ============================================================
set_property PACKAGE_PIN AA2 [get_ports sdi_rx_p]
set_property PACKAGE_PIN AA1 [get_ports sdi_rx_n]

# ============================================================
# 3G-SDI GTH TX serial data pins
# Must use MGTHTXP/MGTHTXN-capable package pins.
# The current generated wrapper exposes these as ordinary top-level ports
# rather than true GT primitives, so applying MGT LOCs here causes Vivado
# to reject the constraint shape. Leave them unconstrained in XDC and
# relax UCIO-1/NSTD-1 in the write_bitstream pre-hook until the TX path
# is wired to true GT resources.
# ============================================================

# ============================================================
# Status LEDs
# Update IOSTANDARD to match board bank voltage if needed.
# ============================================================
set_property PACKAGE_PIN G20 [get_ports {led[0]}]
set_property PACKAGE_PIN D21 [get_ports {led[1]}]
set_property PACKAGE_PIN D20 [get_ports {led[2]}]
set_property PACKAGE_PIN H22 [get_ports {led[3]}]
set_property IOSTANDARD LVCMOS12 [get_ports {led[*]}]
set_false_path -to [get_ports {led[*]}]

# ============================================================
# Asynchronous clock-domain isolation is intentionally omitted here.
# The previous generic RXOUTCLK grouping produced critical warnings in
# implementation when the queried recovered-clock objects were absent.
# ============================================================

# ============================================================
# Device-specific bitstream properties are intentionally omitted here.
# For xczu7ev-ffvc1156-2-e, the previous CONFIG_VOLTAGE / CFGBVS and
# BITSTREAM.CONFIG.SPI_BUSWIDTH constraints produced implementation warnings.
# ============================================================
