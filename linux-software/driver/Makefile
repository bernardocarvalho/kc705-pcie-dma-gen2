################################################################################
# $HeadURL: http://metis.ipfn.ist.utl.pt:8888/svn/cdaq/Users/Bernardo/FPGA/Vivado/KC705/Software/trunk/driver/Makefile $
# $Id: Makefile 7931 2015-11-06 16:46:06Z bernardo $
#
# KC705 PCIe Vivado Project General   Linux driver
# This program is free software; you can redistribute it and/or modify it
# under the terms and conditions of the GNU General Public License,
# version 2, as published by the Free Software Foundation.
#
# This program is distributed in the hope it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
# more details.
#
# You should have received a copy of the GNU General Public License along with
# this program; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin St - Fifth Floor, Boston, MA 02110-1301 USA.
#
# The full GNU General Public License is included in this distribution in
# the file called "COPYING".
#
# Tested with Linux: 3.10.0-229.rt56.147.el6rt.x86_64
# Contact Information:
#
# Instituto de Plasmas e Fusao Nuclear, Instituto Superior Tecnico,
# Universidade  de Lisboa, 1049-001 Lisboa, Portugal.
#
################################################################################

###########################################################################
# Driver files

# core driver files

DRIVER_NAME := kc705_pcie
#atca_ioc_w7x_intrlck

TARGET := $(DRIVER_NAME).ko
CFILES :=  kc705-pcie-drv.c kc705-unlocked-ioctl.c

KVER = $(shell uname -r)
KDIR = /lib/modules/$(KVER)/build
PWD = $(shell pwd)
#DEST = /lib/modules/$(KVER)/kernel/$(MDIR)


$(DRIVER_NAME)-objs := $(CFILES:.c=.o)
obj-m := $(DRIVER_NAME).o

# set the install path
INSTDIR := /lib/modules/$(KVER)/kernel/drivers/atca

# Comment/uncomment the following line to disable/enable debugging
DEBUG = y

# Add your debugging flag (or not) to CFLAGS
ifeq ($(DEBUG),y)
  DEBFLAGS = -O -g -DATCA_DEBUG # "-O" is needed to expand inlines
else
  DEBFLAGS = -O2
endif

EXTRA_CFLAGS += -I$(LDDINC)
EXTRA_CFLAGS += $(DEBFLAGS)

#all:
default:
	$(MAKE) -C $(KDIR) M=$(PWD) LDDINC=$(PWD)/../include modules
clean:
	rm -f *.o *.ko .*.cmd .*.flags *.mod.c

install: default #
#         # remove all old versions of the driver
	find /lib/modules/$(KVER) -name $(TARGET) -exec rm -f {} \; || true
	install -D -m 644 $(TARGET) $(INSTDIR)/$(TARGET)
	/sbin/depmod -a || true
	install -m 0644   kc705_pcie.rules /etc/udev/rules.d

uninstall: clean
	find /lib/modules/$(KVER) -name $(TARGET) -exec rm -f {} \; || true
	/sbin/depmod -a || true
	find /etc/udev/rules.d -name kc705_pcie -exec rm -f {} \; || true
