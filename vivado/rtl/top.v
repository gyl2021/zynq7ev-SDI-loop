module top (
    // SDI RX differential input from GTH MGT pins.
    input  wire       sdi_rx_p,
    // SDI RX differential input complement from GTH MGT pins.
    input  wire       sdi_rx_n,

    // SDI TX differential output to GTH MGT pins.
    output wire       sdi_tx_p,
    // SDI TX differential output complement to GTH MGT pins.
    output wire       sdi_tx_n,

    // 148.5 MHz SDI reference clock differential input (P).
    input  wire       sdi_refclk_p,
    // 148.5 MHz SDI reference clock differential input (N).
    input  wire       sdi_refclk_n,

    // LED status outputs: [0]=rx_locked [1]=tx_locked [2]=heartbeat [3]=error.
    output wire [3:0] led
);

// PL fabric clock exported by BD wrapper and used for heartbeat generation.
wire pl_clk0;
// SDI RX lock indication observed from generated BD hierarchy.
wire rx_locked;
// SDI TX lock indication observed from generated BD hierarchy.
wire tx_locked;
// Free-running counter for heartbeat LED generation at approximately 0.5 Hz @ 100 MHz.
reg  [26:0] hb_cnt;

// Instantiate Vivado block-design generated top wrapper.
system_wrapper u_system (
    .sdi_rx_p     (sdi_rx_p),
    .sdi_rx_n     (sdi_rx_n),
    .sdi_tx_p     (sdi_tx_p),
    .sdi_tx_n     (sdi_tx_n),
    .sdi_refclk_p (sdi_refclk_p),
    .sdi_refclk_n (sdi_refclk_n)
);

// Access selected internal BD status/clock nets for board-level indicators.
assign pl_clk0   = u_system.zynq_ps_pl_clk0;
assign rx_locked = u_system.sdi_rx_ss_rx_locked;
assign tx_locked = u_system.sdi_tx_ss_tx_locked;

// Heartbeat counter: synchronous increment on each PL clock edge.
always @(posedge pl_clk0) begin
    hb_cnt <= hb_cnt + 1'b1;
end

// LEDs are active-low on this board: drive high to keep LED off.
// LED[0] turns on only when RX is locked.
assign led[0] = ~rx_locked;
// LED[1] turns on only when TX is locked.
assign led[1] = ~tx_locked;
// LED[2] is the active-low heartbeat output.
assign led[2] = ~hb_cnt[26];
// LED[3] turns on only when either RX or TX is unlocked.
assign led[3] = rx_locked & tx_locked;

endmodule
