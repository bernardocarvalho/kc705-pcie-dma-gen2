/**
 *
 * @file kc705-unlocked-ioctl.c
 * @author Bernardo Carvalho
 * @date 2014-06-27
 * @brief Contains the functions handling the different ioctl calls.
 *
 * Copyright 2014 - 2019 IPFN-Instituto Superior Tecnico, Portugal
 * Creation Date  2014-06-27
 *
 * Licensed under the EUPL, Version 1.2 only (the "Licence");
 * You may not use this work except in compliance with the Licence.
 * You may obtain a copy of the Licence, available in 23 official languages of
 * the European Union, at:
 * https://joinup.ec.europa.eu/community/eupl/og_page/eupl-text-11-12
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the Licence is distributed on an "AS IS" basis,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the Licence for the specific language governing permissions and
 * limitations under the Licence.
 *
 */

/* Configuration for the driver (what should be compiled in, module name,
 * etc...) */
#include "config.h"

/* Internal definitions for all parts (includes, prototypes, data, macros) */
#include "common.h"

#include "../include/kc705-pcie-ioctl.h"

/**
 * _unlocked_ioctl
 */
long _unlocked_ioctl(struct file *filp, unsigned int cmd, unsigned long arg) {

  int err = 0, retval = 0;
  unsigned long flags = 0;
  u32 tmp;
  COMMAND_REG cReg;
  PCIE_DEV *pciDev; /* for device information */
  STATUS_REG sReg;

  /* retrieve the device information  */
  pciDev = (PCIE_DEV *)filp->private_data;

  sReg.reg32 = ioread32((void *)&pciDev->pModDmaHregs->dmaStatus);
  if (sReg.reg32 == 0xFFFFFFFF)
    PDEBUG("ioctl status Reg:0x%X, cmd: 0x%X\n", sReg.reg32, cmd);

  /**
   * extract the type and number bitfields, and don't decode
   * wrong cmds: return ENOTTY (inappropriate ioctl) before access_ok()
   */
  if (_IOC_TYPE(cmd) != KC705_PCIE_IOC_MAGIC)
    return -ENOTTY;
  if (_IOC_NR(cmd) > KC705_PCIE_IOC_MAXNR)
    return -ENOTTY;

  /*
   * the direction is a bitmask, and VERIFY_WRITE catches R/W
   * transfers. `Type' is user-oriented, while
   * access_ok is kernel-oriented, so the concept of "read" and
   * "write" is reversed
   */
  if (_IOC_DIR(cmd) & _IOC_READ)
    err = !access_ok(VERIFY_WRITE, (void __user *)arg, _IOC_SIZE(cmd));
  else if (_IOC_DIR(cmd) & _IOC_WRITE)
    err = !access_ok(VERIFY_READ, (void __user *)arg, _IOC_SIZE(cmd));
  if (err)
    return -EFAULT;
  switch (cmd) {

  case KC705_PCIE_IOCG_STATUS:
    spin_lock_irqsave(&pciDev->irq_lock, flags);
    //  ----- ----- ----- ----- ----- DEVICE SPECIFIC CODE ----- ----- -----
    //  ----- ----- -----
    tmp = PCIE_READ32((void *)&pciDev->pModDmaHregs->dmaStatus);
    //  ----- ----- ----- ----- ----- DEVICE SPECIFIC CODE ----- ----- -----
    //  ----- ----- -----
    spin_unlock_irqrestore(&pciDev->irq_lock, flags);

    if (copy_to_user((void __user *)arg, &tmp, sizeof(u32)))
      return -EFAULT;
    break;

  case KC705_PCIE_IOCT_INT_ENABLE:
    spin_lock_irqsave(&pciDev->irq_lock, flags);
    // ----- ----- ----- ----- ----- ----- DEVICE SPECIFIC CODE ----- -----
    // ----- ----- ----- -----
    cReg.reg32 = PCIE_READ32((void *)&pciDev->pModDmaHregs->dmaControl);
    //    cReg.cmdFlds.ACQ/iE=1;
    cReg.cmdFlds.DmaIntE = 1;
    PCIE_WRITE32(cReg.reg32, (void *)&pciDev->pModDmaHregs->dmaControl);
    // ----- ----- ----- ----- ----- ----- DEVICE SPECIFIC CODE ----- -----
    // ----- ----- ----- -----
    spin_unlock_irqrestore(&pciDev->irq_lock, flags);
    break;

  case KC705_PCIE_IOCT_INT_DISABLE:
    spin_lock_irqsave(&pciDev->irq_lock, flags);
    // ----- ----- ----- ----- ----- ----- DEVICE SPECIFIC CODE ----- -----
    // ----- ----- ----- -----
    cReg.reg32 = PCIE_READ32((void *)&pciDev->pModDmaHregs->dmaControl);
    //    cReg.cmdFlds.A1~E=0;
    cReg.cmdFlds.DmaIntE = 0;
    PCIE_WRITE32(cReg.reg32, (void *)&pciDev->pModDmaHregs->dmaControl);
    // ----- ----- ----- ----- ----- ----- DEVICE SPECIFIC CODE ----- -----
    // ----- ----- ----- -----
    spin_unlock_irqrestore(&pciDev->irq_lock, flags);
    break;

  case KC705_PCIE_IOCT_ACQ_ENABLE:
    spin_lock_irqsave(&pciDev->irq_lock, flags);
    cReg.reg32 = PCIE_READ32((void *)&pciDev->pModDmaHregs->dmaControl);
    pciDev->mismatches = 0;
    pciDev->curr_buf = 0;
    pciDev->max_buffer_count = 0;
    atomic_set(&pciDev->rd_condition, 0);
    cReg.cmdFlds.AcqE = 1;
    PCIE_WRITE32(cReg.reg32, (void *)&pciDev->pModDmaHregs->dmaControl);
    spin_unlock_irqrestore(&pciDev->irq_lock, flags);
    break;

  case KC705_PCIE_IOCT_ACQ_DISABLE:
    retval = pciDev->max_buffer_count;
    spin_lock_irqsave(&pciDev->irq_lock, flags);
    // ----- ----- ----- ----- ----- ----- DEVICE SPECIFIC CODE ----- -----
    // ----- ----- ----- -----
    cReg.reg32 = PCIE_READ32((void *)&pciDev->pModDmaHregs->dmaControl);
    cReg.cmdFlds.AcqE = 0;
    //    cReg.cmdFlds.STRG=0;
    PCIE_WRITE32(cReg.reg32, (void *)&pciDev->pModDmaHregs->dmaControl);
    // ----- ----- ----- ----- ----- ----- DEVICE SPECIFIC CODE ----- -----
    // ----- ----- ----- -----
    spin_unlock_irqrestore(&pciDev->irq_lock, flags);

    break;
  case KC705_PCIE_IOCT_DMA_ENABLE:
    spin_lock_irqsave(&pciDev->irq_lock, flags);
    // ----- ----- ----- ----- ----- ----- DEVICE SPECIFIC CODE ----- -----
    // ----- ----- ----- -----
    cReg.reg32 = PCIE_READ32((void *)&pciDev->pModDmaHregs->dmaControl);
    cReg.cmdFlds.DmaE = 1;
    PCIE_WRITE32(cReg.reg32, (void *)&pciDev->pModDmaHregs->dmaControl);
    // ----- ----- ----- ----- ----- ----- DEVICE SPECIFIC CODE ----- -----
    // ----- ----- ----- -----
    spin_unlock_irqrestore(&pciDev->irq_lock, flags);

    break;
  case KC705_PCIE_IOCT_DMA_DISABLE:
    spin_lock_irqsave(&pciDev->irq_lock, flags);
    // ----- ----- ----- ----- ----- ----- DEVICE SPECIFIC CODE ----- -----
    // ----- ----- ----- -----
    cReg.reg32 = PCIE_READ32((void *)&pciDev->pModDmaHregs->dmaControl);
    cReg.cmdFlds.DmaE = 0;
    PCIE_WRITE32(cReg.reg32, (void *)&pciDev->pModDmaHregs->dmaControl);
    // ----- ----- ----- ----- ----- ----- DEVICE SPECIFIC CODE ----- -----
    // ----- ----- ----- -----
    spin_unlock_irqrestore(&pciDev->irq_lock, flags);

    break;
  /*
case KC705_PCIE_IOCG_COUNTER:
  spin_lock_irqsave(&pciDev->irq_lock, flags);
  tmp = PCIE_READ32((void*) &pciDev->pHregs->hwcounter);
  spin_unlock_irqrestore(&pciDev->irq_lock, flags);
  if(copy_to_user((void __user *)arg, &tmp, sizeof(u32)))
    return -EFAULT;
  break;
  */
  case KC705_PCIE_IOCS_RDTMOUT:
    retval = __get_user(tmp, (int __user *)arg);
    if (!retval)
      pciDev->wt_tmout = tmp * HZ;
    break;

  /**
   ** Not used yet in this Board

case KC705_PCIE_IOCT_SOFT_TRIG:
  spin_lock_irqsave(&pciDev->irq_lock, flags);
  // ----- ----- ----- ----- ----- ----- DEVICE SPECIFIC CODE ----- ----- -----
----- ----- -----
  cReg.reg32=PCIE_READ32((void*) &pciDev->pHregs->command);
  cReg.cmdFlds.STRG=1;
  PCIE_WRITE32(cReg.reg32, (void*) &pciDev->pHregs->command);
  // ----- ----- ----- ----- ----- ----- DEVICE SPECIFIC CODE ----- ----- -----
----- ----- -----
  spin_unlock_irqrestore(&pciDev->irq_lock, flags);
  break;
   */

  case KC705_PCIE_IOCS_DMA_SIZE:
    retval = __get_user(tmp, (int __user *)arg);
    if (!retval) {
      spin_lock_irqsave(&pciDev->irq_lock, flags);
      iowrite32(tmp, (void *)&pciDev->pModDmaHregs
                         ->dmaByteSize); // write the buffer size to the FPGA
      spin_unlock_irqrestore(&pciDev->irq_lock, flags);
    }
    break;

  case KC705_PCIE_IOCG_DMA_SIZE:
    spin_lock_irqsave(&pciDev->irq_lock, flags);
    tmp = ioread32((void *)&pciDev->pModDmaHregs->dmaByteSize);
    spin_unlock_irqrestore(&pciDev->irq_lock, flags);
    if (copy_to_user((void __user *)arg, &tmp, sizeof(u32)))
      return -EFAULT;
    break;

  /*
   *  case  KC705_PCIE_IOCS_TMRGATE:
   *    retval = __get_user(tmp, (int __user *)arg);
   *    if (!retval){
   *      spin_lock_irqsave(&pciDev->irq_lock, flags);
   *      iowrite32(tmp, (void*) &pciDev->pHregs->timersGate);
   *      spin_unlock_irqrestore(&pciDev->irq_lock, flags);
   *    }
   *    break;
   *
   *  case KC705_PCIE_IOCG_TMRGATE:
   *    spin_lock_irqsave(&pciDev->irq_lock, flags);
   *      tmp = ioread32((void*) &pciDev->pHregs->timersGate);
   *    spin_unlock_irqrestore(&pciDev->irq_lock, flags);
   *    if(copy_to_user((void __user *)arg, &tmp, sizeof(u32)))
   *      return -EFAULT;
   *    break;
   *
   *  case  KC705_PCIE_IOCS_TMR0CTRL:
   *    retval = __get_user(tmp, (int __user *)arg);
   *    if (!retval){
   *      spin_lock_irqsave(&pciDev->irq_lock, flags);
   *      iowrite32(tmp, (void*) &pciDev->pHregs->timer0Control);
   *      spin_unlock_irqrestore(&pciDev->irq_lock, flags);
   *    }
   *    break;
   *
   *  case KC705_PCIE_IOCG_TMR0CTRL:
   *    spin_lock_irqsave(&pciDev->irq_lock, flags);
   *      tmp = ioread32((void*) &pciDev->pHregs->timer0Control);
   *    spin_unlock_irqrestore(&pciDev->irq_lock, flags);
   *    if(copy_to_user((void __user *)arg, &tmp, sizeof(u32)))
   *      return -EFAULT;
   *    break;
   *
   *  case  KC705_PCIE_IOCS_TMR0COUNT:
   *    retval = __get_user(tmp, (int __user *)arg);
   *    if (!retval){
   *      spin_lock_irqsave(&pciDev->irq_lock, flags);
   *      iowrite32(tmp, (void*) &pciDev->pHregs->timer0Count);
   *      spin_unlock_irqrestore(&pciDev->irq_lock, flags);
   *    }
   *    break;
   *
   *  case KC705_PCIE_IOCG_TMR0COUNT:
   *    spin_lock_irqsave(&pciDev->irq_lock, flags);
   *      tmp = ioread32((void*) &pciDev->pHregs->timer0Count);
   *    spin_unlock_irqrestore(&pciDev->irq_lock, flags);
   *    if(copy_to_user((void __user *)arg, &tmp, sizeof(u32)))
   *      return -EFAULT;
   *    break;
   *
   *  case  KC705_PCIE_IOCS_TMR1CTRL:
   *    retval = __get_user(tmp, (int __user *)arg);
   *    if (!retval){
   *      spin_lock_irqsave(&pciDev->irq_lock, flags);
   *      iowrite32(tmp, (void*) &pciDev->pHregs->timer1Control);
   *      spin_unlock_irqrestore(&pciDev->irq_lock, flags);
   *    }
   *    break;
   *
   *  case KC705_PCIE_IOCG_TMR1CTRL:
   *    spin_lock_irqsave(&pciDev->irq_lock, flags);
   *      tmp = ioread32((void*) &pciDev->pHregs->timer1Control);
   *    spin_unlock_irqrestore(&pciDev->irq_lock, flags);
   *    if(copy_to_user((void __user *)arg, &tmp, sizeof(u32)))
   *      return -EFAULT;
   *    break;
   *
   *  case  KC705_PCIE_IOCS_TMR1COUNT:
   *    retval = __get_user(tmp, (int __user *)arg);
   *    if (!retval){
   *      spin_lock_irqsave(&pciDev->irq_lock, flags);
   *      iowrite32(tmp, (void*) &pciDev->pHregs->timer1Count);
   *      spin_unlock_irqrestore(&pciDev->irq_lock, flags);
   *    }
   *    break;
   *
   *  case KC705_PCIE_IOCG_TMR1COUNT:
   *    spin_lock_irqsave(&pciDev->irq_lock, flags);
   *      tmp = ioread32((void*) &pciDev->pHregs->timer1Count);
   *    spin_unlock_irqrestore(&pciDev->irq_lock, flags);
   *    if(copy_to_user((void __user *)arg, &tmp, sizeof(u32)))
   *      return -EFAULT;
   *    break;
   *
   *  case  KC705_PCIE_IOCS_TMR2CTRL:
   *    retval = __get_user(tmp, (int __user *)arg);
   *    if (!retval){
   *      spin_lock_irqsave(&pciDev->irq_lock, flags);
   *      iowrite32(tmp, (void*) &pciDev->pHregs->timer2Control);
   *      spin_unlock_irqrestore(&pciDev->irq_lock, flags);
   *    }
   *    break;
   *
   *  case KC705_PCIE_IOCG_TMR2CTRL:
   *    spin_lock_irqsave(&pciDev->irq_lock, flags);
   *      tmp = ioread32((void*) &pciDev->pHregs->timer2Control);
   *    spin_unlock_irqrestore(&pciDev->irq_lock, flags);
   *    if(copy_to_user((void __user *)arg, &tmp, sizeof(u32)))
   *      return -EFAULT;
   *    break;
   *
   *  case  KC705_PCIE_IOCS_TMR2COUNT:
   *    retval = __get_user(tmp, (int __user *)arg);
   *    if (!retval){
   *      spin_lock_irqsave(&pciDev->irq_lock, flags);
   *      iowrite32(tmp, (void*) &pciDev->pHregs->timer2Count);
   *      spin_unlock_irqrestore(&pciDev->irq_lock, flags);
   *    }
   *    break;
   *
   *  case KC705_PCIE_IOCG_TMR2COUNT:
   *    spin_lock_irqsave(&pciDev->irq_lock, flags);
   *      tmp = ioread32((void*) &pciDev->pHregs->timer2Count);
   *    spin_unlock_irqrestore(&pciDev->irq_lock, flags);
   *    if(copy_to_user((void __user *)arg, &tmp, sizeof(u32)))
   *      return -EFAULT;
   *    break;
   *
   *  case  KC705_PCIE_IOCS_TMR3CTRL:
   *    retval = __get_user(tmp, (int __user *)arg);
   *    if (!retval){
   *      spin_lock_irqsave(&pciDev->irq_lock, flags);
   *      iowrite32(tmp, (void*) &pciDev->pHregs->timer3Control);
   *      spin_unlock_irqrestore(&pciDev->irq_lock, flags);
   *    }
   *    break;
   *
   *  case KC705_PCIE_IOCG_TMR3CTRL:
   *    spin_lock_irqsave(&pciDev->irq_lock, flags);
   *      tmp = ioread32((void*) &pciDev->pHregs->timer3Control);
   *    spin_unlock_irqrestore(&pciDev->irq_lock, flags);
   *    if(copy_to_user((void __user *)arg, &tmp, sizeof(u32)))
   *      return -EFAULT;
   *    break;
   *
   *  case  KC705_PCIE_IOCS_TMR3COUNT:
   *    retval = __get_user(tmp, (int __user *)arg);
   *    if (!retval){
   *      spin_lock_irqsave(&pciDev->irq_lock, flags);
   *      iowrite32(tmp, (void*) &pciDev->pHregs->timer3Count);
   *      spin_unlock_irqrestore(&pciDev->irq_lock, flags);
   *    }
   *    break;
   *
   *  case KC705_PCIE_IOCG_TMR3COUNT:
   *    spin_lock_irqsave(&pciDev->irq_lock, flags);
   *      tmp = ioread32((void*) &pciDev->pHregs->timer3Count);
   *    spin_unlock_irqrestore(&pciDev->irq_lock, flags);
   *    if(copy_to_user((void __user *)arg, &tmp, sizeof(u32)))
   *      return -EFAULT;
   *    break;
   *
   */
  default: /* redundant, as cmd was checked against MAXNR */
    return -ENOTTY;
  }
  return retval;
}
