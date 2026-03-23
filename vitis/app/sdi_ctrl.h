#ifndef SDI_CTRL_H
#define SDI_CTRL_H

#include "xil_io.h"
#include "xil_types.h"

/* SDI RX/TX/GPIO AXI-Lite base addresses (must match Vivado address map). */
#define SDI_RX_BASE_ADDR                 0xA0000000U
#define SDI_TX_BASE_ADDR                 0xA0010000U
#define GPIO_BASE_ADDR                   0xA0020000U

/* SDI RX register offsets. */
#define SDI_RX_RST_CTRL_OFFSET           0x0000U
#define SDI_RX_MDL_CTRL_OFFSET           0x0004U
#define SDI_RX_STAT_OFFSET               0x0060U
#define SDI_RX_MODE_OFFSET               0x0068U

/* SDI TX register offsets. */
#define SDI_TX_RST_CTRL_OFFSET           0x0000U
#define SDI_TX_MDL_CTRL_OFFSET           0x0004U
#define SDI_TX_MODE_OFFSET               0x0050U
#define SDI_TX_STAT_OFFSET               0x0060U

/* AXI GPIO register offsets (channel 1 data). */
#define GPIO_DATA_OFFSET                 0x0000U

/* Common control bit masks. */
#define SDI_CTRL_BIT_ENABLE              (1U << 0)
#define SDI_CTRL_BIT_TX_OUT_EN           (1U << 1)
#define SDI_CTRL_BIT_RESET               (1U << 0)

/* RX/TX status bit masks. */
#define SDI_RX_STAT_BIT_LOCKED           (1U << 0)
#define SDI_RX_STAT_BIT_MODE_LOCKED      (1U << 4)
#define SDI_TX_STAT_BIT_LOCKED           (1U << 0)

/* RX/TX mode values. */
#define SDI_MODE_SD                      0U
#define SDI_MODE_HD                      1U
#define SDI_MODE_3G                      2U
#define SDI_MODE_UNKNOWN                 3U
#define SDI_MODE_MASK                    0x3U

/* GPIO bit mapping from BD status vector. */
#define GPIO_BIT_RX_LOCK                 (1U << 0)
#define GPIO_BIT_TX_LOCK                 (1U << 1)
#define GPIO_BIT_RX_CE                   (1U << 2)
#define GPIO_BIT_MODE_LOCK               (1U << 3)

/* Timing constants for polling/reset delays. */
#define SDI_RESET_ASSERT_DELAY_US        1000U
#define SDI_RESET_RELEASE_DELAY_US       1000U
#define SDI_POLL_INTERVAL_US             1000U

/* Return codes. */
#define SDI_OK                           0
#define SDI_ERR_TIMEOUT                  -1
#define SDI_ERR_MODE                     -2

/* Register access helpers. */
#define SDI_RD(base, off)                Xil_In32((base) + (off))
#define SDI_WR(base, off, val)           Xil_Out32((base) + (off), (val))
#define GPIO_RD()                        Xil_In32(GPIO_BASE_ADDR + GPIO_DATA_OFFSET)

/* Assert and release reset on the SDI RX core. */
void sdi_rx_reset(void);
/* Assert and release reset on the SDI TX core. */
void sdi_tx_reset(void);
/* Enable the SDI RX datapath. */
void sdi_rx_enable(void);
/* Enable the SDI TX datapath and output driver. */
void sdi_tx_enable(void);
/* Wait for SDI RX lock and mode lock within timeout in milliseconds. */
int sdi_rx_wait_locked(u32 timeout_ms);
/* Wait for SDI TX lock within timeout in milliseconds. */
int sdi_tx_wait_locked(u32 timeout_ms);
/* Read SDI RX detected mode and clamp unknown values. */
u32 sdi_rx_get_mode(void);
/* Program SDI TX output mode after validating mode value. */
int sdi_tx_set_mode(u32 mode);
/* Print one-line RX/TX lock and mode status to UART. */
void sdi_print_status(void);

#endif /* SDI_CTRL_H */
