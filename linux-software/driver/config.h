/*******************************/
/* Configuration of the driver */
/*******************************/

/* Enable/disable IRQ handling */ //#define ENABLE_IRQ

/* The name of the module */
//#define MODNAME "atca_ioc_int"

/* Major number is allocated dynamically */

/* Minor  number is set to 0  */

/* The number of available minor numbers */
#define MINOR_NUMBERS 2 // 0xffff

/* Node name of the char device */
//#define NODENAME "atcaiopint-"
//#define NODENAMEFMT "atca_ioc_int%d"

//#define DRV_NAME "atca_ioc_int_stream"
#define NODENAMEFMT "kc705_pcie%d"

#define DRV_NAME "kc705_pcie_drv"

/* Maximum number of devices*/
#define MAXDEVICES 2

#define DMA_BUFFS 8 // Number of DMA Buffs

/* board PCI id */
#define PCI_DEVICE_ID_FPGA 0x0076 // 0x7014

#define NUM_BARS 2
