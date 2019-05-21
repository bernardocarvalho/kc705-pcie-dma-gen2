/**
 * KC705_PCIE barebone device driver
 * IOCTL Definitions for the Linux Device Driver
 *
 * SVN keywords
 * $Date: 2016-01-05 17:01:20 +0000 (Tue, 05 Jan 2016) $
 * $Revision: 8127 $
 * $URL:
 * http://metis.ipfn.ist.utl.pt:8888/svn/cdaq/Users/Bernardo/FPGA/Vivado/KC705/Software/trunk/include/kc705-pcie-ioctl.h
 * $
 *
 */

#ifndef _KC705_PCIE_IOCTL_H_
#define _KC705_PCIE_IOCTL_H_

#include "kc705-pcie.h"

/*
 * IOCTL definitions
 */

#define KC705_PCIE_IOC_MAGIC                                                   \
  'j' // /* Please use a different 8-bit number in your code */
      /*See  /Documentation/ioctl-number.txt*/

/* S means "Set": thru a pointer
 * T means "Tell": directly with the argument value
 * G menas "Get": reply by setting thru a pointer
 * Q means "Qry": response is on the return value
 * X means "eXchange": G and S atomically
 * H means "sHift": T and Q atomically
 */

/**********************************************************************
 *                         IOCTL FUNCTIONS                            *
 *********************************************************************/
#define KC705_PCIE_IOCT_INT_ENABLE _IO(KC705_PCIE_IOC_MAGIC, 1)
#define KC705_PCIE_IOCT_INT_DISABLE _IO(KC705_PCIE_IOC_MAGIC, 2)
#define KC705_PCIE_IOCT_ACQ_ENABLE _IO(KC705_PCIE_IOC_MAGIC, 3)
#define KC705_PCIE_IOCT_ACQ_DISABLE _IO(KC705_PCIE_IOC_MAGIC, 4)
#define KC705_PCIE_IOCT_DMA_ENABLE _IO(KC705_PCIE_IOC_MAGIC, 5)
#define KC705_PCIE_IOCT_DMA_DISABLE _IO(KC705_PCIE_IOC_MAGIC, 6)
#define KC705_PCIE_IOCT_SOFT_TRIG _IO(KC705_PCIE_IOC_MAGIC, 7)
#define KC705_PCIE_IOCG_STATUS _IOR(KC705_PCIE_IOC_MAGIC, 8, u_int32_t)
#define KC705_PCIE_IOCS_RDTMOUT _IOW(KC705_PCIE_IOC_MAGIC, 9, u_int32_t)
#define KC705_PCIE_IOCS_DMA_SIZE _IOW(KC705_PCIE_IOC_MAGIC, 10, u_int32_t)
#define KC705_PCIE_IOCG_DMA_SIZE _IOR(KC705_PCIE_IOC_MAGIC, 11, u_int32_t)

/*
 *#define KC705_PCIE_IOCS_TMRGATE       _IOW(KC705_PCIE_IOC_MAGIC, 12,
 *u_int32_t)
 *#define KC705_PCIE_IOCG_TMRGATE       _IOR(KC705_PCIE_IOC_MAGIC, 13,
 *u_int32_t)
 *
 *#define KC705_PCIE_IOCS_TMR0CTRL      _IOW(KC705_PCIE_IOC_MAGIC, 14,
 *u_int32_t)
 *#define KC705_PCIE_IOCG_TMR0CTRL      _IOR(KC705_PCIE_IOC_MAGIC, 15,
 *u_int32_t)
 *#define KC705_PCIE_IOCS_TMR0COUNT     _IOW(KC705_PCIE_IOC_MAGIC, 16,
 *u_int32_t)
 *#define KC705_PCIE_IOCG_TMR0COUNT     _IOR(KC705_PCIE_IOC_MAGIC, 17,
 *u_int32_t)
 *
 *#define KC705_PCIE_IOCS_TMR1CTRL      _IOW(KC705_PCIE_IOC_MAGIC, 18,
 *u_int32_t)
 *#define KC705_PCIE_IOCG_TMR1CTRL      _IOR(KC705_PCIE_IOC_MAGIC, 19,
 *u_int32_t)
 *#define KC705_PCIE_IOCS_TMR1COUNT     _IOW(KC705_PCIE_IOC_MAGIC, 20,
 *u_int32_t)
 *#define KC705_PCIE_IOCG_TMR1COUNT     _IOR(KC705_PCIE_IOC_MAGIC, 21,
 *u_int32_t)
 *
 *#define KC705_PCIE_IOCS_TMR2CTRL      _IOW(KC705_PCIE_IOC_MAGIC, 22,
 *u_int32_t)
 *#define KC705_PCIE_IOCG_TMR2CTRL      _IOR(KC705_PCIE_IOC_MAGIC, 23,
 *u_int32_t)
 *#define KC705_PCIE_IOCS_TMR2COUNT     _IOW(KC705_PCIE_IOC_MAGIC, 24,
 *u_int32_t)
 *#define KC705_PCIE_IOCG_TMR2COUNT     _IOR(KC705_PCIE_IOC_MAGIC, 25,
 *u_int32_t)
 *
 *#define KC705_PCIE_IOCS_TMR3CTRL      _IOW(KC705_PCIE_IOC_MAGIC, 26,
 *u_int32_t)
 *#define KC705_PCIE_IOCG_TMR3CTRL      _IOR(KC705_PCIE_IOC_MAGIC, 27,
 *u_int32_t)
 *#define KC705_PCIE_IOCS_TMR3COUNT     _IOW(KC705_PCIE_IOC_MAGIC, 28,
 *u_int32_t)
 *#define KC705_PCIE_IOCG_TMR3COUNT     _IOR(KC705_PCIE_IOC_MAGIC, 29,
 *u_int32_t)
 *
 */
#define KC705_PCIE_IOC_MAXNR 11

/*
#define KC705_PCIE_IOCS_CONFIG_ACQ _IOW(KC705_PCIE_IOC_MAGIC, 2, u_int32_t)
#define KC705_PCIE_IOCT_DSP_HOLD _IO(KC705_PCIE_IOC_MAGIC, 1)
#define KC705_PCIE_IOCS_BAR1_WREG _IOW(KC705_PCIE_IOC_MAGIC, 5, uint32_t)
#define KC705_PCIE_IOCG_BAR1_RREG _IOR(KC705_PCIE_IOC_MAGIC, 6, uint32_t)
#define KC705_PCIE_IOCG_IRQ_CNT _IOR(KC705_PCIE_IOC_MAGIC, 7, u_int32_t)
#define KC705_PCIE_IOCT_SOFT_TRIG _IO(KC705_PCIE_IOC_MAGIC, 8)
#define KC705_PCIE_IOCS_TMOUT      _IOW(KC705_PCIE_IOC_MAGIC, 11, u_int32_t)
#define KC705_PCIE_IOCS_CHAN       _IOW(PCIE_ADC_IOC_MAGIC, 12, u_int32_t)
*/
#endif /* _KC705_PCIE_IOCTL_H_ */
