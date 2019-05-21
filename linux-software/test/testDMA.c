/**
 * KC705 PCIe Vivado Project General  Test DMA
 * Project Name:
 * Design Name:
 * FW Version
 * working  with kernel 3.10.58
 *
 * SVN keywords
 * $Date: 2015-11-06 16:46:06 +0000 (Fri, 06 Nov 2015) $
 * $Revision: 7931 $
 * $URL:
 * http://metis.ipfn.ist.utl.pt:8888/svn/cdaq/Users/Bernardo/FPGA/Vivado/KC705/Software/trunk/driver/kc705-pcie-drv.c
 * $
 *
 * Copyright 2014 - 2015 IPFN-Instituto Superior Tecnico, Portugal
 * Creation Date  2014-02-10
 *
 * Licensed under the EUPL, Version 1.1 or - as soon they
 * will be approved by the European Commission - subsequent
 * versions of the EUPL (the "Licence");
 * You may not use this work except in compliance with the
 * Licence.
 * You may obtain a copy of the Licence at:
 *
 * http://ec.europa.eu/idabc/eupl
 *
 * Unless required by applicable law or agreed to in
 * writing, software distributed under the Licence is
 * distributed on an "AS IS" basis,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either
 * express or implied.
 * See the Licence for the specific language governing
 * permissions and limitations under the Licence.
 *
 */

#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <unistd.h>
//#include <sys/types.h>
//#include <sys/stat.h>
#include <fcntl.h>
#include <sys/ioctl.h>
//#include <linux/types.h>
#include <math.h>
//#include <signal.h>
#include "kc705-pcie-ioctl.h"
#include <string.h>

#define DMA_ACQ_SIZE 2048

char DEVNAME[] = "/dev/kc705_pcie1";

int main(int argc, char **argv) {

  int i, ii, rc, fd;
  char *devn;
  int flags = 0;
  FILE *fdi;
  int32_t *dataBuff; //[DMA_ACQ_SIZE / sizeof(int16_t) ]; // user space buffer
                     // for data
  unsigned int Npackets = 1;
  int32_t *pAdcData;
  int32_t *pAdcDataWr;
  if (argc > 2)
    devn = argv[2];
  else
    devn = DEVNAME;
  if (argc > 1) {
    Npackets = atoi(argv[1]);
  } else {
    printf("%s  [Npackets dev_name]\n", argv[0]);
    return -1;
  }
  pAdcData = (int32_t *)malloc(DMA_ACQ_SIZE * Npackets);
  pAdcDataWr = pAdcData;
  flags |= O_RDONLY;
  printf("opening device\t");
  extern int errno;
  fd = open(devn, flags);

  if (fd < 0) {
    fprintf(stderr, "Error: cannot open device %s \n", devn);
    fprintf(stderr, " errno = %i\n", errno);
    printf("open error : %s\n", strerror(errno));
    exit(1);
  }
  printf("device opened: \n"); // /Opening the device
  rc = ioctl(fd, KC705_PCIE_IOCT_ACQ_ENABLE);

  dataBuff = (int32_t *)malloc(DMA_ACQ_SIZE);
  for (i = 0; i < Npackets; i++) {
    rc = read(fd, dataBuff, DMA_ACQ_SIZE); // loop read.
    memcpy(pAdcDataWr, dataBuff, DMA_ACQ_SIZE);
    pAdcDataWr += DMA_ACQ_SIZE / sizeof(int32_t);

    /*
        for (ii=0; ii <  DMA_ACQ_SIZE/sizeof(int32_t); ii++) {
            if  ((dataBuff[2*ii+1] & 0xFFF) != 0xA59)
                printf("NOK %d d:%X, ", ii, dataBuff[2*ii+1]);
        }
        printf("\n");
    */
    for (ii = 0; ii < 10; ii++) {
      printf("%d d:%X, ", ii, dataBuff[2 * ii]);
    }
    printf("\n");
    for (ii = 0; ii < 10; ii++) {
      printf("0x%08X, ", dataBuff[2 * ii + 1]);
    }
    printf(" \n");
  }
  rc = ioctl(fd, KC705_PCIE_IOCT_ACQ_DISABLE);
  printf("read OK: %d Npackets %d \n", rc, Npackets);

  close(fd);

  fdi = fopen("data.bin", "wb"); /*Test if can open files to write */
  pAdcDataWr = pAdcData;

  for (i = 0; i < Npackets; i++) {
    fwrite(pAdcDataWr, 1, DMA_ACQ_SIZE, fdi);
    pAdcDataWr += DMA_ACQ_SIZE / sizeof(int32_t);
  }

  fclose(fdi);
  free(dataBuff);
  free(pAdcData);
  //    printf("Acquired %d packets, %d samples, chanNumb: %d\n", Npackets,
  //    SAMP_PER_PACKET * Npackets, chanNumb );
  return 0;
}
