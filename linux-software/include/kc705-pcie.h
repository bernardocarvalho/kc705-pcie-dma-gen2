/**
 * KC705_PCIE barebone device driver
 * Definitions for the Linux Device Driver
 *
 * SVN keywords
 * $Date: 2015-11-06 16:46:06 +0000 (Fri, 06 Nov 2015) $
 * $Revision: 7931 $
 * $URL:
 * http://metis.ipfn.ist.utl.pt:8888/svn/cdaq/Users/Bernardo/FPGA/Vivado/KC705/Software/trunk/include/kc705-pcie.h
 * $
 *
 */
#ifndef _KC705_PCIE_H_
#define _KC705_PCIE_H_

#ifndef __KERNEL__
#define u32 unsigned int
#endif

//#define DMA_MAX_BYTES 2048 // Difeine in FPGA

// TOD : to be used.
#ifdef __BIG_ENDIAN_BTFLD
#define BTFLD(a, b) b, a
#else
#define BTFLD(a, b) a, b
#endif

#ifndef VM_RESERVED
#define VMEM_FLAGS (VM_IO | VM_DONTEXPAND | VM_DONTDUMP)
#else
#define VMEM_FLAGS (VM_IO | VM_RESERVED)
#endif
/*
typedef struct _OFFSET_REGS {
  u32 offset[16];
} OFFSET_REGS;


typedef struct _DRIFT_REGS {
  u32 drift[16];
} DRIFT_REGS;
*/

#undef PDEBUG /* undef it, just in case */
#ifdef ATCA_DEBUG
#ifdef __KERNEL__
/* This one if debugging is on, and kernel space */
#define PDEBUG(fmt, args...) printk(KERN_DEBUG "kc705: " fmt, ##args)
#else
/* This one for user space */
#define PDEBUG(fmt, args...) fprintf(stderr, fmt, ##args)
#endif
#else
#define PDEBUG(fmt, args...) /* not debugging: nothing */
#endif

#undef PDEBUGG
#define PDEBUGG(fmt, args...) /* nothing: it's a placeholder */

#endif /* _KC705_PCIE_H_ */
