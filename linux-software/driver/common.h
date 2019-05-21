/**
 * ATCA IO CONTROL Integrator
 * Linux Device Driver
 * Internal definitions for all parts (prototypes, data, macros)
 *
 * SVN keywords
 * $Date: 2016-01-05 17:01:20 +0000 (Tue, 05 Jan 2016) $
 * $Revision: 8127 $
 * $URL:
 * http://metis.ipfn.ist.utl.pt:8888/svn/cdaq/Users/Bernardo/FPGA/Vivado/KC705/Software/trunk/driver/common.h
 * $
 *
 */
#ifndef _DRIVER_COMMON_H
#define _DRIVER_COMMON_H

#include <linux/cdev.h>
#include <linux/errno.h>
#include <linux/fs.h>
#include <linux/interrupt.h>
#include <linux/kernel.h>
#include <linux/module.h>
#include <linux/pci.h>
#include <linux/stat.h>
#include <linux/types.h>
#include <linux/version.h>
//#include <linux/list.h>
#include <linux/sched.h>
#include <linux/spinlock.h>
#include <linux/wait.h>

#include <asm/atomic.h>
#include <asm/msr.h>
#include <asm/uaccess.h>
#include <linux/dma-mapping.h>

#include "../include/kc705-pcie.h"

/*************************************************************************/
/* Private data types and structures */

typedef struct _BAR_STRUCT {
  unsigned long phys;
  // unsigned long end;
  unsigned long psize;
  // unsigned long flags;
  void *vaddr;
} BAR_STRUCT;

typedef struct _DMA_BUF {
  void *addr_v;
  dma_addr_t addr_hw;
} DMA_BUF;

typedef struct _DMA_STRUCT {
  unsigned int buf_size;
  unsigned int buf_actv;
  dma_addr_t hw_actv;
  u32 *daddr_actv; // ptr to data on active buffer
  DMA_BUF buf[DMA_BUFFS];
} DMA_STRUCT;

typedef struct _READ_BUF {
  int count;
  int total;
  u32 *buf; // assume that ADC data is 32bit wide
} READ_BUF;

/*
   typedef struct _DMA_REG {
   union
   {
   u32 reg32;
   struct  {

   } dmaFlds;
   };
   } DMA_REG;
   */

/*
 * 32 bit field
 */
typedef struct _STATUS_FLDS {
  u32 RevId : 8, rsv0 : 22, DmaC : 1, rsv1 : 1; // msb
} STATUS_FLDS;

typedef struct _STATUS_REG {
  union {
    u32 reg32;
    STATUS_FLDS statFlds;
  };
} STATUS_REG;

typedef struct _COMMAND_REG {
  union {
    u32 reg32;
    struct {
      u32 Dma1 : 1, Dma2 : 1, rsv0 : 21, AcqE : 1, rsv1 : 3, DmaE : 1, rsv2 : 2,
          DmaIntE : 1, rsv3 : 1;
    } cmdFlds;
  };
} COMMAND_REG;

typedef struct _DMA_CURR_BUFF {
  union {
    u32 reg32;
    struct {
      u32 DmaBuffNum : 3, DmaSel : 1, rsv0 : 28;
    } dmaFlds;
  };
} DMA_CURR_BUFF;
typedef struct _PCIE_SHAPI_HREGS {
  volatile u32 shapiVersion;       /*Offset 0x00 ro */
  volatile u32 firstModAddress;    /*Offset 0x04 ro */
  volatile u32 hwIDhwVendorID;     /*Offset 0x08 ro*/
  volatile u32 devFwIDdevVendorID; /*Offset 0x0C ro */
  volatile u32 fwVersion;          /*Offset 0x10 ro */
  volatile u32 fwTimeStamp;        /*Offset 0x14 ro*/
  volatile u32 fwName[3];          /*Offset 0x18 ro*/
  volatile u32 devCapab;           /*Offset 0x24 ro*/
  volatile u32 devStatus;          /*Offset 0x28 ro*/
  volatile u32 devControl;         /*Offset 0x2C rw*/
  volatile u32 devIntMask;         /*Offset 0x30 rw*/
  volatile u32 devIntFlag;         /*Offset 0x34 ro*/
  volatile u32 devIntActive;       /*Offset 0x38 ro*/
  volatile u32 scratchReg;         /*Offset 0x3C rw*/
} PCIE_SHAPI_HREGS;

typedef struct _SHAPI_MOD_DMA_HREGS {
  volatile u32 shapiVersion;       /*Offset 0x00 ro */
  volatile u32 nextModAddress;     /*Offset 0x04 ro */
  volatile u32 modFwIDmodVendorID; /*Offset 0x08 ro*/
  volatile u32 modVersion;         /*Offset 0x0C ro */
  volatile u32 modName[2];         /*Offset 0x10 ro*/
  volatile u32 modCapab;           /*Offset 0x18 ro*/
  volatile u32 modStatus;          /*Offset 0x1C ro*/
  volatile u32 modControl;         /*Offset 0x20 rw*/
  volatile u32 modIntID;           /*Offset 0x24 rw*/
  volatile u32 modIntFlagClear;    /*Offset 0x28 ro*/
  volatile u32 modIntMask;         /*Offset 0x2C rw*/
  volatile u32 modIntFlag;         /*Offset 0x30 ro*/
  volatile u32 modIntActive;       /*Offset 0x34 ro*/
  volatile u32 _reserved1[2];      /*Offset 0x38 - 0x40 na */
  volatile u32 dmaStatus;          /* Offset 0x40 ro */
  volatile u32 dmaControl;         /* Offset 0x44 rw */
  volatile u32 dmaByteSize;        /* Offset 0x48 rw */
  volatile u32 dmaMaxBytes;        /* Offset 0x4C ro */
  volatile u32 dmaTlpPayload;      /* Offset 0x50 ro */
  volatile u32 _reserved2[11];     /* Offset 0x54 na */
  volatile u32 dmaBusAddr[8];      /* Offset 0x80 rw */

  ////  EVENT_REGS                timingRegs[NUM_TIMERS];
} SHAPI_MOD_DMA_HREGS;

typedef struct _PCIE_HREGS {
  volatile u32 shapiRegs[15]; /* Offsets 0x00 - 0x3C */
  volatile u32 devScratch;    /* Offset 0x3C */
  volatile u32 _reserved0;
  volatile u32 _reserved00;
  // volatile STATUS_REG status; [> Offset 0x40 <]
  // volatile COMMAND_REG command;
  volatile u32 dmaNbytes;                  /*Offset 0x48*/
  volatile u32 _reserved1[13];             /*Offset 0x4C -  SPIUpd_Addr */
  volatile u32 HwDma1Addr[8];              /*Offsets 0x80 - 0x9C*/
  volatile u32 HwDma2Addr[8];              /*Offsets 0xA0 - 0x*/
  volatile u32 _reserved2; /*Offset 0x03*/ // SPI file
  // volatile DMA_CURR_BUFF dmaCurrBuff; [>Offset 0x05<]
  // volatile u32 timersGate;            [>Offset 0x6 <]
  // volatile u32 _reserved3;            [>Offset 0x07<]
  // volatile u32 timer0Control;         [>Offset 0x24<]
  // volatile u32 timer0Count;           [>Offset 0x25<]
  // volatile u32 timer1Control;         [>Offset 0x26<]
  // volatile u32 timer1Count;           [>Offset 0x27<]
  // volatile u32 timer2Control;         [>Offset 0x28<]
  // volatile u32 timer2Count;           [>Offset 0x29<]
  // volatile u32 timer3Control;         [>Offset 0x30<]
  // volatile u32 timer3Count;           [>Offset 0x31<]
} PCIE_HREGS;

/*Structure for pcie access*/
typedef struct _PCIE_DEV {
  /* char device */
  struct cdev cdev;     /* linux char device structure   */
  struct pci_dev *pdev; /* pci device */
  dev_t devno;          /* char device number */
  struct device *dev;
  unsigned char irq;
  spinlock_t irq_lock; // static
  unsigned int got_regions;
  unsigned int msi_enabled;
  unsigned int counter;
  unsigned int counter_hw;
  unsigned int open_count;
  struct semaphore open_sem; // mutual exclusion semaphore
  wait_queue_head_t rd_q;    // read  queues
  long wt_tmout;             // read timeout
  atomic_t rd_condition;
  unsigned int mismatches;
  unsigned int max_buffer_count;
  unsigned int curr_buf;

  BAR_STRUCT memIO[2];
  DMA_STRUCT dmaIO;
  // READ_BUF bufRD;               // buffer struct for read() ops
  // PCIE_HREGS *pHregs;

  PCIE_SHAPI_HREGS *pShapiHregs;
  SHAPI_MOD_DMA_HREGS *pModDmaHregs;
} PCIE_DEV;

/*I/O Macros*/

#define PCIE_READ32(addr) ioread32(addr)
#define PCIE_WRITE32(value, addr) iowrite32(value, addr)
#define PCIE_FLUSH32() PCIE_READ32()

/*************************************************************************/
/* Some nice defines that make code more readable */
/* This is to print nice info in the log

#ifdef DEBUG
#define mod_info( args... ) \
do { printk( KERN_INFO "%s - %s : ", MODNAME , __FUNCTION__ );\
printk( args ); } while(0)
#define mod_info_dbg( args... ) \
do { printk( KERN_INFO "%s - %s : ", MODNAME , __FUNCTION__ );\
printk( args ); } while(0)
#else
#define mod_info( args... ) \
do { printk( KERN_INFO "%s: ", MODNAME );\
printk( args ); } while(0)
#define mod_info_dbg( args... )
#endif

#define mod_crit( args... ) \
do { printk( KERN_CRIT "%s: ", MODNAME );\
printk( args ); } while(0)

#define MIN(a, b) ((a) < (b) ? (a) : (b))

 **/

#endif // _DRIVER_COMMON_H
