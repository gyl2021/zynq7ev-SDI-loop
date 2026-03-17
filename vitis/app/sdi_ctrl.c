#include "sdi_ctrl.h"
#include "xil_printf.h"
#include "sleep.h"

static const char *g_mode_str[4] = {"SD-SDI", "HD-SDI", "3G-SDI", "UNKNOWN"};

/* Assert and release reset on the SDI RX core. */
void sdi_rx_reset(void)
{
    SDI_WR(SDI_RX_BASE_ADDR, SDI_RX_RST_CTRL_OFFSET, SDI_CTRL_BIT_RESET);
    usleep(SDI_RESET_ASSERT_DELAY_US);
    SDI_WR(SDI_RX_BASE_ADDR, SDI_RX_RST_CTRL_OFFSET, 0U);
    usleep(SDI_RESET_RELEASE_DELAY_US);
}

/* Assert and release reset on the SDI TX core. */
void sdi_tx_reset(void)
{
    SDI_WR(SDI_TX_BASE_ADDR, SDI_TX_RST_CTRL_OFFSET, SDI_CTRL_BIT_RESET);
    usleep(SDI_RESET_ASSERT_DELAY_US);
    SDI_WR(SDI_TX_BASE_ADDR, SDI_TX_RST_CTRL_OFFSET, 0U);
    usleep(SDI_RESET_RELEASE_DELAY_US);
}

/* Enable the SDI RX datapath. */
void sdi_rx_enable(void)
{
    SDI_WR(SDI_RX_BASE_ADDR, SDI_RX_MDL_CTRL_OFFSET, SDI_CTRL_BIT_ENABLE);
}

/* Enable the SDI TX datapath and output driver. */
void sdi_tx_enable(void)
{
    SDI_WR(SDI_TX_BASE_ADDR, SDI_TX_MDL_CTRL_OFFSET, SDI_CTRL_BIT_ENABLE | SDI_CTRL_BIT_TX_OUT_EN);
}

/* Wait for SDI RX lock and mode lock within timeout in milliseconds. */
int sdi_rx_wait_locked(u32 timeout_ms)
{
    u32 elapsed_ms;
    for (elapsed_ms = 0U; elapsed_ms < timeout_ms; ++elapsed_ms) {
        u32 stat;
        stat = SDI_RD(SDI_RX_BASE_ADDR, SDI_RX_STAT_OFFSET);
        if ((stat & (SDI_RX_STAT_BIT_LOCKED | SDI_RX_STAT_BIT_MODE_LOCKED)) ==
            (SDI_RX_STAT_BIT_LOCKED | SDI_RX_STAT_BIT_MODE_LOCKED)) {
            return SDI_OK;
        }
        usleep(SDI_POLL_INTERVAL_US);
    }
    return SDI_ERR_TIMEOUT;
}

/* Wait for SDI TX lock within timeout in milliseconds. */
int sdi_tx_wait_locked(u32 timeout_ms)
{
    u32 elapsed_ms;
    for (elapsed_ms = 0U; elapsed_ms < timeout_ms; ++elapsed_ms) {
        u32 stat;
        stat = SDI_RD(SDI_TX_BASE_ADDR, SDI_TX_STAT_OFFSET);
        if ((stat & SDI_TX_STAT_BIT_LOCKED) != 0U) {
            return SDI_OK;
        }
        usleep(SDI_POLL_INTERVAL_US);
    }
    return SDI_ERR_TIMEOUT;
}

/* Read SDI RX detected mode and clamp unknown values. */
u32 sdi_rx_get_mode(void)
{
    u32 mode;
    mode = SDI_RD(SDI_RX_BASE_ADDR, SDI_RX_MODE_OFFSET) & SDI_MODE_MASK;
    if (mode > SDI_MODE_3G) {
        return SDI_MODE_UNKNOWN;
    }
    return mode;
}

/* Program SDI TX output mode after validating mode value. */
int sdi_tx_set_mode(u32 mode)
{
    if (mode > SDI_MODE_3G) {
        return SDI_ERR_MODE;
    }
    SDI_WR(SDI_TX_BASE_ADDR, SDI_TX_MODE_OFFSET, mode);
    return SDI_OK;
}

/* Print one-line RX/TX lock and mode status to UART. */
void sdi_print_status(void)
{
    u32 gpio;
    u32 mode;

    gpio = GPIO_RD();
    mode = sdi_rx_get_mode();
    xil_printf("RX:%s TX:%s CE:%s MODELCK:%s MODE:%s GPIO:0x%02X\r\n",
               ((gpio & GPIO_BIT_RX_LOCK) != 0U) ? "LOCK" : "----",
               ((gpio & GPIO_BIT_TX_LOCK) != 0U) ? "LOCK" : "----",
               ((gpio & GPIO_BIT_RX_CE) != 0U) ? "ON" : "OFF",
               ((gpio & GPIO_BIT_MODE_LOCK) != 0U) ? "YES" : "NO",
               g_mode_str[mode],
               gpio);
}
