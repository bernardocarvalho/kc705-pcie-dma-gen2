CC=gcc
IDIR=../include

CFLAGS=-O2 -Wall
CFLAGS += -I$(IDIR)

#OBJ = atca-ioc-int-lib.o
#DEPS = atca-ioc-int-lib.h common.h
LDFLAGS =    -lm

default: testDMA

%.o: %.c $(DEPS)
	$(CC) -c -o $@ $< $(CFLAGS) -I$(IDIR)

testDMA: $(OBJ) testDMA.o
	$(CC) -o $@ $^ $(CFLAGS) -I$(IDIR)

testTimers: $(OBJ) testTimers.o
	$(CC) -o $@ $^ $(CFLAGS) -I$(IDIR)

pcimem: $(OBJ) pcimem.o
	$(CC) -o $@ $^ $(CFLAGS) -I$(IDIR)

reg_rw: reg_rw.o
	$(CC) -o $@ $<
#%.o: %.c
#$(CC) -c -std=c99 -o $@ $< -D_FILE_OFFSET_BITS=64 -D_GNU_SOURCE -D_LARGE_FILE_SOURCE

clean:
	rm -f  *.o *~
