#include "xil_printf.h"
#include "sleep.h"
#include "sdi_ctrl.h"

/* Run SDI RX-to-TX loopthrough control and periodic status monitoring. */
int main(void)
{
    u32 mode;
    u32 tick_sec;

    xil_printf("\r\n=== XCZU7EV 3G-SDI Loopthrough (Standalone) ===\r\n");

    xil_printf("[1] Reset SDI cores...\r\n");
    sdi_rx_reset();
    sdi_tx_reset();

    xil_printf("[2] Enable RX and wait lock...\r\n");
    sdi_rx_enable();
    if (sdi_rx_wait_locked(5000U) != SDI_OK) {
        xil_printf("ERROR: RX lock timeout. Check SDI input source.\r\n");
        return SDI_ERR_TIMEOUT;
    }
    xil_printf("    RX LOCKED\r\n");

    mode = sdi_rx_get_mode();
    xil_printf("[3] Detected mode code: %u\r\n", mode);
    if (sdi_tx_set_mode(mode) != SDI_OK) {
        xil_printf("ERROR: Invalid RX mode for TX setup.\r\n");
        return SDI_ERR_MODE;
    }

    xil_printf("[4] Enable TX and wait lock...\r\n");
    sdi_tx_enable();
    if (sdi_tx_wait_locked(3000U) != SDI_OK) {
        xil_printf("ERROR: TX lock timeout. Check reference clock and TX path.\r\n");
        return SDI_ERR_TIMEOUT;
    }
    xil_printf("    TX LOCKED\r\n");

    xil_printf("=== Loopthrough ACTIVE ===\r\n");

    tick_sec = 0U;
    while (1) {
        sleep(1U);
        ++tick_sec;
        xil_printf("[%4lu s] ", (unsigned long)tick_sec);
        sdi_print_status();

        if ((GPIO_RD() & GPIO_BIT_RX_LOCK) == 0U) {
            xil_printf("WARN: RX lock lost; restarting RX/TX pipeline...\r\n");
            sdi_rx_reset();
            sdi_tx_reset();
            sdi_rx_enable();
            if (sdi_rx_wait_locked(2000U) == SDI_OK) {
                mode = sdi_rx_get_mode();
                if (sdi_tx_set_mode(mode) == SDI_OK) {
                    sdi_tx_enable();
                    if (sdi_tx_wait_locked(2000U) == SDI_OK) {
                        xil_printf("INFO: RX/TX relock success.\r\n");
                    } else {
                        xil_printf("ERROR: TX relock timeout.\r\n");
                    }
                } else {
                    xil_printf("ERROR: Unsupported mode during relock.\r\n");
                }
            } else {
                xil_printf("ERROR: RX relock timeout.\r\n");
            }
        }
    }
}
