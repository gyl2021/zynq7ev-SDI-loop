puts "=== write_bitstream pre-hook: relax unconstrained placeholder IO DRCs ==="
set_property SEVERITY {Warning} [get_drc_checks NSTD-1]
set_property SEVERITY {Warning} [get_drc_checks UCIO-1]
