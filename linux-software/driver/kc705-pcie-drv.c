/**
 * KC705 PCIe Vivado Project General   Linux driver
 * Project Name:
 * Design Name:
 * Linux Device Driver
 * PCI Device Id: 76
 * FW Version
 * working  with kernel 4.9.0-8-amd64
 *
 * Copyright 2014 - 2019 IPFN-Instituto Superior Tecnico, Portugal
 * Creation Date  2014-02-10
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

#include "kc705-unlocked-ioctl.h"

/* Check macros and kernel version first */
#ifndef KERNEL_VERSION
#error "No KERNEL_VERSION macro! Stopping."
#endif

#ifndef LINUX_VERSION_CODE
#error "No LINUX_VERSION_CODE macro! Stopping."
#endif

#if LINUX_VERSION_CODE < KERNEL_VERSION(4, 9, 0)
#error "This driver has been tested only for Kernel 4.9.0 or above."
#endif

/* #if LINUX_VERSION_CODE >= KERNEL_VERSION(2,6,32) */
/* #ifndef init_MUTEX */
/* #define init_MUTEX(_m) sema_init(_m,1); */
/* #endif // #ifndef init_MUTEX#endif */
/* #endif */

/*
 * Global variables
 */

int device_major = 0;

static struct pci_device_id ids[] = {
    {PCI_DEVICE(PCI_VENDOR_ID_XILINX, PCI_DEVICE_ID_FPGA)},
    {
        0,
    },
};

MODULE_DEVICE_TABLE(pci, ids);

struct class *kc705_pcie_class;

/*function prototypes*/
int _probe(struct pci_dev *pdev, const struct pci_device_id *id);
void _remove(struct pci_dev *pdev);

static struct pci_driver _pcie_pci = {
    .name = DRV_NAME, .id_table = ids, .probe = _probe, .remove = _remove};

static const struct file_operations _fops;

/**
 * _pcie_open
 */
int _pcie_open(struct inode *inode, struct file *filp) {
  PCIE_DEV *pcieDev; /* device information */

  /** retrieve the device information  */

  pcieDev = container_of(inode->i_cdev, PCIE_DEV, cdev);

  if (down_interruptible(&pcieDev->open_sem))
    return -ERESTARTSYS;

  filp->private_data = pcieDev;          // for other methods
  atomic_set(&pcieDev->rd_condition, 0); // prepare to read
  // *****************************
  up(&pcieDev->open_sem);

  return 0;
}

/**
 * _pcie_release
 *  		called by close() sys call
 */
int _pcie_release(struct inode *inode, struct file *filp) {
  PCIE_DEV *pcieDev; /* device information */

  /**    retrieve the device information  */

  pcieDev = container_of(inode->i_cdev, PCIE_DEV, cdev);
  down(&pcieDev->open_sem);
  filp->private_data = NULL;
  up(&pcieDev->open_sem);

  return 0;
}

/**
 * _pcie_read
 */
ssize_t _pcie_read(struct file *filp, char *buf, size_t count, loff_t *f_pos) {
  u32 *data;
  u32 maxByteSize;
  int rv;
  ssize_t retval = 0;
  COMMAND_REG cReg;

  PCIE_DEV *pcieDev = (PCIE_DEV *)filp->private_data; /* device information */

  PDEBUG("_pcie_read  count %d \n", (int)count);
  maxByteSize = ioread32((void *)&pcieDev->pModDmaHregs->dmaByteSize);

  /*check size ligned, if not return error, also alloc memory */
  if ((count > maxByteSize)) { // DMA_MAX_BYTES
    PDEBUG("_pcie_read  error count %d, dmaByteSize %d\n", (int)count,
           maxByteSize);
    retval = -1;
    goto out;
  }
  cReg.reg32 = ioread32((void *)&pcieDev->pModDmaHregs->dmaControl);
  PDEBUG("_pcie_read command 0x%08x\n", cReg.reg32);
  cReg.cmdFlds.DmaE = 1;
  /*cReg.cmdFlds.AcqE = 1;*/
  //
  iowrite32(cReg.reg32, (void *)&pcieDev->pModDmaHregs->dmaControl);

  if (atomic_read(&pcieDev->rd_condition) == 0) {
    if (wait_event_interruptible_timeout(
            pcieDev->rd_q, atomic_read(&pcieDev->rd_condition) != 0,
            pcieDev->wt_tmout) == 0) {
      printk(KERN_ALERT "_pcie read: wait_q timeout\n");
      goto out;
    }
  }
  printk(KERN_INFO "_pcie read: wait_q received\n");

  /* Copy buffer in buf with copy_to_user */
  data = pcieDev->dmaIO.buf[pcieDev->curr_buf].addr_v;
  rv = copy_to_user(buf, data, count);
  if (rv) {
    printk(KERN_ERR "_pcie_read: copy_to_user error:%d\n", rv);
    return -EFAULT;
  }

  *f_pos += count;
  retval = count;

  atomic_dec(&pcieDev->rd_condition);
  if (pcieDev->curr_buf == (DMA_BUFFS - 1))
    pcieDev->curr_buf = 0;
  else
    pcieDev->curr_buf++;
out:
  cReg.cmdFlds.DmaE = 0;
  iowrite32(cReg.reg32, (void *)&pcieDev->pModDmaHregs->dmaControl);
  return retval;
}

/**
 * _pcie_write
 */
ssize_t _pcie_write(struct file *file, const char *buf, size_t count,
                    loff_t *ppos) {
  printk(KERN_WARNING "_pcie_write: not implemented\n");
  return 0;
}

/* maps the PCIe BAR into user space for memory-like access using mmap() */
int _bridge_mmap(struct file *filp, struct vm_area_struct *vma) {
  // struct xdma_dev *xdev;
  // struct xdma_cdev *xcdev = (struct xdma_cdev *)file->private_data;
  // https://github.com/claudioscordino/mmap_alloc/blob/master/mmap_alloc.c
  PCIE_DEV *pcieDev = (PCIE_DEV *)filp->private_data; /* device information */
  unsigned long bar_idx = 1;
  unsigned long off;
  unsigned long phys;
  unsigned long vsize;
  unsigned long psize;
  int rv;

  /*rv = xcdev_check(__func__, xcdev, 0);*/
  /*if (rv < 0)*/
  /*return rv;*/
  /*xdev = xcdev->xdev;*/
  printk(KERN_INFO "off=%ld, has DMA: %d\n", vma->vm_pgoff, 0);

  off = vma->vm_pgoff << PAGE_SHIFT;
  /* BAR physical address */
  /*phys = pci_resource_start(pcieDev->pdev, bar_idx) + off;*/
  phys = pcieDev->memIO[bar_idx].phys;
  psize = pcieDev->memIO[bar_idx].psize;
  vsize = vma->vm_end - vma->vm_start;
  /* complete resource */
  /*psize = pci_resource_end(pcieDev->pdev, bar_idx) -*/
  /*pci_resource_start(pcieDev->pdev, bar_idx) + 1 - off;*/
  if (vsize > psize) {
    printk(KERN_ALERT "mmap  vsize %ld, psize %ld", vsize, psize);
    /*return -EINVAL;*/
  }
  /*
   * pages must not be cached as this would result in cache line sized
   * accesses to the end point
   */
  vma->vm_page_prot = pgprot_noncached(vma->vm_page_prot);
  /*
   * prevent touching the pages (byte access) for swap-in,
   * and prevent the pages from being swapped out
   */
  vma->vm_flags |= VMEM_FLAGS;
  /* make MMIO accessible to user space */
  rv = io_remap_pfn_range(vma, vma->vm_start, phys >> PAGE_SHIFT, vsize,
                          vma->vm_page_prot);
  printk(KERN_INFO "vma=0x%p, vma->vm_start=0x%lx, phys=0x%lx, size=%lu = %d\n",
         vma, vma->vm_start, phys >> PAGE_SHIFT, vsize, rv);
  if (rv)
    return -EAGAIN;
  return 0;
}

static const struct file_operations _fops = {
    .owner = THIS_MODULE,
    .open = _pcie_open,
    .read = _pcie_read,
    .write = _pcie_write,
    .mmap = _bridge_mmap,
    .unlocked_ioctl = _unlocked_ioctl,
    .release = _pcie_release,
};

/**
 * _irq_handler
 */
static irqreturn_t _irq_handler(int irq, void *dev_id) {
  PCIE_DEV *pcieDev;
  unsigned long flags;
  int tmp;
  irqreturn_t rv = IRQ_HANDLED;
  int buffer_number;
  /*int dma_channel_active;*/
  /*STATUS_REG sReg;*/
  COMMAND_REG cReg;

  pcieDev = (PCIE_DEV *)pci_get_drvdata(dev_id);
  spin_lock_irqsave(&pcieDev->irq_lock, flags);

  // No need to Ack MSI IRQs
  /*sReg.reg32 = ioread32((void *)&pcieDev->pHregs->status);*/
  /*if (sReg.statFlds.DmaC == 1) {*/
  /*//    sReg.statFlds.DmaC==1*/
  /*iowrite32(sReg.reg32, (void *)&pcieDev->pHregs->status);*/
  /*}*/

  cReg.reg32 = ioread32((void *)&pcieDev->pModDmaHregs->dmaControl);
  cReg.cmdFlds.DmaE = 0;
  // AcqE
  iowrite32(cReg.reg32, (void *)&pcieDev->pModDmaHregs->dmaControl);

  buffer_number = ioread32((void *)&pcieDev->pModDmaHregs->dmaStatus);
  PDEBUG("_irq_handler status 0x%X \n", buffer_number);
  /*dma_channel_active = (0x8 & buffer_number) >> 3; // dma channel active*/
  /*buffer_number = (0x00000007 & buffer_number);*/
  /*pcieDev->curr_buf = (0x07 & (buffer_number >> 1));*/
  pcieDev->curr_buf = (0x07 & buffer_number);
  PDEBUG("_irq_handler curr_buf 0x%X \n", pcieDev->curr_buf);

  tmp = atomic_read(&pcieDev->rd_condition);
  if (tmp > pcieDev->max_buffer_count)
    pcieDev->max_buffer_count = tmp;
  if (tmp != 0)
    pcieDev->mismatches++;

  atomic_inc(&pcieDev->rd_condition);

  if (waitqueue_active(&pcieDev->rd_q)) {
    wake_up_interruptible(&pcieDev->rd_q);
  }

  spin_unlock_irqrestore(&pcieDev->irq_lock, flags);
  return rv;
}

/**
 *
 * DMA management functions *
 */
int set_dma_mask(struct pci_dev *pdev) {
  int rv = 0;

#if LINUX_VERSION_CODE <= KERNEL_VERSION(4, 0, 0)
  rv = pci_dma_supported(pdev, DMA_BIT_MASK(32));
  if (!rv) {
    printk(KERN_ERR "_pcie_probe DMA not supported. EXIT\n");
    return rv;
  }
#endif
  /* enabling DMA transfers */
  rv = pci_set_dma_mask(pdev, DMA_BIT_MASK(32));
  if (rv) {
    printk(KERN_ERR "_pcie_probe pci_set_dma_mask error(%d). EXIT\n", rv);
    return rv;
  }
  rv = pci_set_consistent_dma_mask(pdev, DMA_BIT_MASK(32));
  if (rv) {
    printk(KERN_ERR "_pcie_probe pci_set_consistent_dma_mask error(%d). EXIT\n",
           rv);
    return rv;
  }
  /*  rv = pci_set_mwi(pdev);
      if (rv) {
      printk(KERN_ERR "_pcie_probe pci_set_mwi error(%d). EXIT\n", rv);
      return rv;
      }
      */
  return rv;
}

int configurePCI(PCIE_DEV *pcieDev) {
  /*u16 reg16 = 0;*/
  int i = 0;
  int rv = 0;
  resource_size_t bar_start, bar_len; //, bar_end;
  unsigned long bar_flags;
  u32 shapiMagic;
  /*
  // set PCI command register
  pci_read_config_word(pcieDev->pdev, PCI_COMMAND, &reg16);
  reg16 &= ~PCI_COMMAND_IO;    // disable IO port access
  reg16 |= PCI_COMMAND_PARITY; // enable parity error hangs
  reg16 |= PCI_COMMAND_SERR;   // enable addr parity error
  pci_write_config_word(pcieDev->pdev, PCI_COMMAND, reg16);
  */
  rv = pci_request_regions(pcieDev->pdev, DRV_NAME);
  /* could not request all regions? */
  if (rv) {
    printk(KERN_ERR
           "_pcie: error in could not request all regions§ [%d]. Aborting.\n",
           rv);
    return -ENOMEM;
  }
  pcieDev->got_regions = 1;
  // PCI reading IO memory spaces and set virtual addresses
  for (i = 0; i < NUM_BARS; i++) {
    bar_start = pci_resource_start(pcieDev->pdev, i);
    bar_len = pci_resource_len(pcieDev->pdev, i);
    /* TODO BAR size exceeds maximum desired mapping? */
    bar_flags = pci_resource_flags(pcieDev->pdev, i);
    // virtual addr
    pcieDev->memIO[i].vaddr = pci_iomap(pcieDev->pdev, i, bar_len);
    /*ioremap_nocache(pcieDev->memIO[i].start, pcieDev->memIO[i].len);*/
    pcieDev->memIO[i].phys = bar_start;
    pcieDev->memIO[i].psize = bar_len;
    PDEBUG("_pcie_probe start 0x%X, len 0x%X, flags 0x%X \n", (int)bar_start,
           (int)bar_len, (int)bar_flags);

    if (!pcieDev->memIO[i].vaddr) {
      printk(KERN_ERR "_pcie: error in iomap region  [%d]. Aborting.\n", i);
      return -ENOMEM;
    }
  }
  // virtual pointer to board registers
  pcieDev->pShapiHregs = (PCIE_SHAPI_HREGS *)pcieDev->memIO[1].vaddr;
  shapiMagic = ioread32((void *)&pcieDev->pShapiHregs->shapiVersion);
  PDEBUG("shapiVersion Reg 0x%08x\n", shapiMagic);
  if (shapiMagic != 0x1234)
    return -1;
  pcieDev->pModDmaHregs =
      (SHAPI_MOD_DMA_HREGS *)(pcieDev->memIO[1].vaddr +
                              ioread32((void *)&pcieDev->pShapiHregs
                                           ->firstModAddress));

  return rv;
}

int setupDMA(PCIE_DEV *pcieDev) {
  int i = 0;
  u8 *buffer_virt;
  dma_addr_t buffer_bus; /* bus address */
  u32 byteSize;

  /**
    setting DMA regions */
  /*pcieDev->dmaIO.buf_size = DMA_MAX_BYTES; // PAGE_SIZE * (1 << GFPORDER);//*/
  byteSize = ioread32((void *)&pcieDev->pModDmaHregs->dmaMaxBytes);
  pcieDev->dmaIO.buf_size = byteSize; // Set to the FPGA Maximum
  PDEBUG("setupDMA MAX  0x%08x\n", byteSize);
  /* write the buffer size to the FPGA*/
  iowrite32(byteSize, // set to Maximum for now
            (void *)&pcieDev->pModDmaHregs->dmaByteSize);

  /*PDEBUG("setupDMA MAX  0x%08x, dmaByteSize 0x%08x\n", DMA_MAX_BYTES,*/
  /*ioread32((void *)&pcieDev->pModDmaHregs->dmaByteSize));*/
  // https://stackoverflow.com/questions/27677452/difference-between-pci-alloc-consistent-and-dma-alloc-coherent
  /* set up a coherent mapping through PCI subsystem */
  for (i = 0; i < DMA_BUFFS; i++) {

    /*pcieDev->dmaIO.buf[i].addr_v =*/
    /*buffer_virt = pci_alloc_consistent(pcieDev->pdev,
     * pcieDev->dmaIO.buf_size,*/
    /*&buffer_bus);*/
    buffer_virt = dma_alloc_coherent(
        &pcieDev->pdev->dev, pcieDev->dmaIO.buf_size, &buffer_bus, GFP_KERNEL);
    /*&(pcieDev->dmaIO.buf[i].addr_hw));*/
    if (!buffer_virt || !buffer_bus) {
      printk(KERN_ERR "setupDMA dma_alloc_coherent error(v:%p hw:%p). EXIT\n",
             /*(void *)pcieDev->dmaIO.buf[i].addr_v,*/
             buffer_virt, (void *)buffer_bus);
      return -ENOMEM;
    }
    /*memset((void *)(pcieDev->dmaIO.buf[i].addr_v), 0,
     * pcieDev->dmaIO.buf_size);*/
    memset(buffer_virt, 0, pcieDev->dmaIO.buf_size);
    // for (i = 0; i < DMA_BUFFS; i++)
    // WRITE pci MA registers
    /*iowrite32(buffer_bus, (void *)&pcieDev->pHregs->HwDma1Addr[i]);*/
    iowrite32(buffer_bus, (void *)&pcieDev->pModDmaHregs->dmaBusAddr[i]);
    pcieDev->dmaIO.buf[i].addr_v = buffer_virt;
    pcieDev->dmaIO.buf[i].addr_hw = buffer_bus;
  }

  pcieDev->dmaIO.buf_actv = 0;
  pcieDev->dmaIO.hw_actv = pcieDev->dmaIO.buf[0].addr_hw;

  return 0;
}

/*
 * probe
 */
int _probe(struct pci_dev *pdev, const struct pci_device_id *id) {
  int rv;
  PCIE_DEV *pcieDev = NULL;
  STATUS_REG sReg;
  COMMAND_REG cReg;
  u32 _minor;
  void *bar0_vaddr;
  void *bar1_vaddr;

  /* allocate the device instance block */
  pcieDev = kzalloc(sizeof(PCIE_DEV), GFP_KERNEL);
  if (!pcieDev) {
    return -ENOMEM;
  }
  pcieDev->pdev = pdev;
  pcieDev->wt_tmout = 2 * HZ; /*time out in sec*/
  pci_set_drvdata(pdev, pcieDev);

  sema_init(&pcieDev->open_sem, 1);
  /* enabling PCI board */
  rv = pci_enable_device(pdev);
  if (rv) {
    printk(KERN_ERR "_pcie_probe pci_enable_device error(%d). EXIT\n", rv);
    return rv;
  }
  /* force MRRS to be 512 */
  rv = pcie_set_readrq(pdev, 512);
  if (rv) {
    printk(KERN_ERR " device %s, error set PCI_SET_READRQ: %d.\n",
           dev_name(&pdev->dev), rv);
    return rv;
  }
  /* enable bus master capability */
  pci_set_master(pdev);
  /*enable DMA transfers */
  rv = set_dma_mask(pdev);
  if (rv != 0) {
    printk(KERN_ERR "_pcie: error in DMA initialization. Aborting.\n");
    return rv;
  }

  /* configure PCI and remap I/O */
  rv = configurePCI(pcieDev);
  if (rv != 0) {
    printk("KERN_ERR _pcie: error in PCI configuration. Aborting.\n");
    return rv;
  }
  // Set up DMA
  /*
   *rv = setupDMA(pcieDev);
   *if (rv != 0) {
   *  printk("KERN_ERR _pcie: error in DMA setup. Aborting.\n");
   *  return rv;
   *}
   */

  cReg.reg32 = 0;
  iowrite32(cReg.reg32, (void *)&pcieDev->pModDmaHregs->dmaControl);

  sReg.reg32 = ioread32((void *)&pcieDev->pModDmaHregs->dmaStatus);
  /*ioread32((void *)&pcieDev->pHregs->status);*/
  PDEBUG("status Reg:0x%X, \n", sReg.reg32);

  bar0_vaddr = pcieDev->memIO[0].vaddr;
  bar1_vaddr = pcieDev->memIO[1].vaddr;

  PDEBUG("shapiVersion Reg 0x%08x\n",
         ioread32((void *)&pcieDev->pShapiHregs->shapiVersion));
  PDEBUG("firstModAddress Reg 0x%08x\n",
         ioread32((void *)&pcieDev->pShapiHregs->firstModAddress));
  PDEBUG("shapiVersion Time Stamp 0x%08x\n",
         ioread32((void *)&pcieDev->pShapiHregs->fwTimeStamp));
  PDEBUG("scratchReg Reg 0x%08x\n",
         ioread32((void *)&pcieDev->pShapiHregs->scratchReg));
  PDEBUG("Mod shapiVersion Reg 0x%08x\n",
         ioread32((void *)&pcieDev->pModDmaHregs->shapiVersion));
  PDEBUG("Mod modFwIDmodVendorIDReg 0x%08x\n",
         ioread32((void *)&pcieDev->pModDmaHregs->modFwIDmodVendorID));
  PDEBUG("Mod dmaMaxBytes 0x%08x\n",
         ioread32((void *)&pcieDev->pModDmaHregs->dmaMaxBytes));
  PDEBUG("Mod dmaBusAddr 0x%08x\n",
         ioread32((void *)&pcieDev->pModDmaHregs->dmaBusAddr[0]));

  PDEBUG("_pcie_probe Bar 1 address 0 0x%08x\n", ioread32(bar1_vaddr));
  /*iowrite32(0xA5, bar1_vaddr);*/
  PDEBUG("_pcie_probe Bar 1 address 8 0x%08x\n", ioread32(bar1_vaddr + 8));
  /*iowrite32(0x4, pcieDev->memIO[0].vaddr + 4);*/
  /*PDEBUG("_pcie_probe Bar 1 address 4 0x%08x\n", ioread32(bar1_vaddr + 4));*/
  /*PDEBUG("_pcie_probe Bar 1 address 16 0x%08x\n", ioread32(bar1_vaddr +
   * 0x10));*/
  /*PDEBUG("_pcie_probe Bar 1 address 20 %d\n", ioread32(bar1_vaddr + 0x14));*/
  /*PDEBUG("_pcie_probe Bar 1 address 24 0x%08x\n", ioread32(bar1_vaddr +
   * 24));*/
  /*PDEBUG("_pcie_probe Bar 1 address 60 0x%08x\n", ioread32(bar1_vaddr +
   * 60));*/
  /*PDEBUG("_pcie_probe Bar 0 address 0 0x%08x\n", ioread32(bar0_vaddr));*/
  /*[>PDEBUG("_pcie_probe Bar 0 address 4 0x%08x\n", ioread32(bar0_vaddr +
   * 4));<]*/
  /*PDEBUG("_pcie_probe Bar 1 devScratch 0x%08x\n",*/
  /*ioread32((void *)&pcieDev->pHregs->devScratch));*/
  /*PDEBUG("_pcie_probe Bar 1 command 0x%08x\n",*/
  /*ioread32((void *)&pcieDev->pModDmaHregs->dmaControl));*/
  /*PDEBUG("_pcie_probe Bar 1 HwDma1Addr[0] 0x%08x\n",*/
  /*ioread32((void *)&pcieDev->pHregs->HwDma1Addr[0]));*/

  // ----- ----- ----- ----- ----- ----- DEVICE SPECIFIC CODE ----- ----- -----
  // ----- ----- -----
  /* Install board IRQ */

  rv = pci_enable_msi(pdev);

  if (rv) {
    printk(KERN_ERR "pci_enable_msi %d error[%d]\n", pdev->irq, rv);
    return rv;
  }
  pcieDev->msi_enabled = 1;
  pcieDev->irq = pdev->irq;

  // rv = request_irq(pdev->irq, _irq_handler, IRQF_SHARED, DRV_NAME, (void*)
  // pdev);
  rv = request_irq(pdev->irq, _irq_handler, 0, DRV_NAME, (void *)pdev);

  if (rv) {
    printk(KERN_ERR "request_linux_irq irq %d error[%d]\n", pdev->irq, rv);
    return rv;
  }
  PDEBUG("_pcie irq %d handler installed\n", pdev->irq);

  spin_lock_init(&pcieDev->irq_lock);
  init_waitqueue_head(&pcieDev->rd_q);
  _minor = 1; // TODO Change
  pcieDev->devno = MKDEV(device_major, _minor);

  cdev_init(&pcieDev->cdev, &_fops);
  pcieDev->cdev.owner = THIS_MODULE;
  pcieDev->cdev.ops = &_fops;

  rv = cdev_add(&pcieDev->cdev, pcieDev->devno, 1);
  // rv=0;
  if (rv) {
    printk(KERN_ERR "Error %d adding _pcie device", rv);
    return -EIO;
  }

  pcieDev->dev = device_create(kc705_pcie_class, NULL, pcieDev->devno, NULL,
                               NODENAMEFMT, _minor);
  /*
     cReg.cmdFlds.ACQE=0;
     cReg.cmdFlds.STREAME=0;

     PCIE_WRITE32(cReg.reg32, (void*) &pcieDev->pModDmaHregs->dmaControl);
     */
  cReg.cmdFlds.DmaIntE = 1;
  iowrite32(cReg.reg32, (void *)&pcieDev->pModDmaHregs->dmaControl);
  /*cReg.reg32 = ioread32((void *)&pcieDev->pModDmaHregs->dmaControl);
    sReg.reg32 = ioread32((void *)&pcieDev->pHregs->status);*/
  printk(KERN_NOTICE "%s installed, major:%d\n", DRV_NAME, device_major);

  PDEBUG("Mod Status 0x%08x\n",
         ioread32((void *)&pcieDev->pModDmaHregs->dmaStatus));
  PDEBUG("Mod dmaControl 0x%08x\n",
         ioread32((void *)&pcieDev->pModDmaHregs->dmaControl));
  return 0;
}

/*
 * remove
 */
void _remove(struct pci_dev *pdev) {
  unsigned long flags;
  int i;
  PCIE_DEV *pcieDev;

  /* get the device information data */
  pcieDev = (PCIE_DEV *)pci_get_drvdata(pdev);

  /*  Reset  Device */
  /*iowrite32(0x00, (void *)&pcieDev->pModDmaHregs->dmaControl);*/

  if (pcieDev->irq) {
    /* disable registered IRQ */
    free_irq(pcieDev->irq, pdev);
  }
  if (pcieDev->msi_enabled) {
    // deregistering OS ISR and restore MSI
    pci_disable_msi(pdev);
  }
  spin_lock_irqsave(&pcieDev->irq_lock, flags);
  // ----- ----- ----- ----- ----- ----- DEVICE SPECIFIC CODE ----- ----- -----
  // ----- ----- -----
  /*  Reset  Device */
  /*PCIE_WRITE32(0, (void *)&pcieDev->pModDmaHregs->dmaControl);*/
  //  PCIE_WRITE32(0, (void*) &pcieDev->pHregs1~->dmaReg );	/* WRITE pci MA
  //  register */
  // ----- ----- ----- ----- ----- ----- DEVICE SPECIFIC CODE ----- ----- -----
  // ----- ----- -----
  spin_unlock_irqrestore(&pcieDev->irq_lock, flags);
  cdev_del(&pcieDev->cdev);
  //  unregister_chrdev_region(pcieDev->devno,1);
  device_destroy(kc705_pcie_class, pcieDev->devno);

  /* deregistering DMAable areas and virtual addresses for the board */
  /*
   *for (i = 0; i < DMA_BUFFS; i++){
   *  [>pci_free_consistent(pdev, pcieDev->dmaIO.buf_size,<]
   *  dma_free_coherent(&pcieDev->pdev->dev, pcieDev->dmaIO.buf_size,
   *                    pcieDev->dmaIO.buf[i].addr_v,
   *                    pcieDev->dmaIO.buf[i].addr_hw);
   *                    }
   */
  for (i = 0; i < NUM_BARS; i++)
    iounmap(pcieDev->memIO[i].vaddr);
  if (pcieDev->got_regions) {
    /*dbg_init("pci_release_regions 0x%p.\n", pdev);*/
    pci_release_regions(pdev);
  }
  /* disable PCI board */
  kfree(pcieDev);
  pci_set_drvdata(pdev, NULL);
  pci_clear_mwi(pdev);
  pci_disable_device(pdev);
  printk(KERN_NOTICE "%s removed. \n", DRV_NAME);
  return;
}

/*
 * _pcie_init
 */
static int __init _pcie_init(void) {
  int rv;
  dev_t devno = 0;

  devno = MKDEV(0, 0);
  rv = alloc_chrdev_region(&devno, 0, MINOR_NUMBERS, DRV_NAME);
  if (rv) {
    printk(KERN_ERR "Failed to register device %s with error %d\n", DRV_NAME,
           rv);
    goto fail;
  }
  device_major = MAJOR(devno);
  PDEBUG("_init: device_num:%d\n", device_major);

  kc705_pcie_class = class_create(THIS_MODULE, DRV_NAME);
  if (IS_ERR(kc705_pcie_class)) {
    printk(KERN_ERR "Unable to allocate class\n");
    rv = PTR_ERR(kc705_pcie_class);

    goto unreg_chrdev;
  }

  /* registering the board */
  rv = pci_register_driver(&_pcie_pci);
  if (rv) {
    printk(KERN_ERR "pcieAdc_init pci_register_driver error(%d).\n", rv);
    goto unreg_class;
    //    return rv;
  }
  return rv;
unreg_class:
  class_unregister(kc705_pcie_class);
  class_destroy(kc705_pcie_class);
unreg_chrdev:
  unregister_chrdev_region(MKDEV(device_major, 0), MINOR_NUMBERS);
fail:
  return rv;
}

/*
 * _pcie_exit
 */
static void _pcie_exit(void) {
  /* unregistering the board */
  pci_unregister_driver(&_pcie_pci);
  class_unregister(kc705_pcie_class);
  unregister_chrdev_region(MKDEV(device_major, 0), MINOR_NUMBERS);
}

module_init(_pcie_init);
module_exit(_pcie_exit);

MODULE_LICENSE("Dual BSD/GPL");
MODULE_DESCRIPTION("Module for PCIe KINTEX FPGA ");
MODULE_AUTHOR("Bernardo Carvalho/IST-IPFN");
