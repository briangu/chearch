CC=clang
LDIR=/opt/local/Cellar/libev/4.15/lib
IDIR=/opt/local/Cellar/libev/4.15/include
CHICKEN_IDIR=/opt/local/Cellar/chicken/4.9.0.1/include/chicken
CFLAGS=-I$(IDIR) -I.
LIBS=-lev

all: chearch 

tcp_server: tcp_server.o
	$(CC) $(CFLAGS) -c -o tcp_server.o tcp_server.c

chearch: tcp_server.o
	chpl --fast --print-passes tcp_server.h tcp_server.o callbacks.h callbacks.c -I$(IDIR) -L$(LDIR) $(LIBS) -o bin/chearch chearch.chpl search.chpl common.chpl logging.chpl partitions.chpl genhashkey32.chpl genhashkey64.chpl  libev.chpl

crosstalk:
	chpl --fast --print-passes -o bin/crosstalk crosstalk.chpl common.chpl logging.chpl partitions.chpl genhashkey32.chpl

crosstalk_hash:
	chpl --fast --print-passes -o bin/crosstalk_hash crosstalk_hash.chpl common.chpl logging.chpl partitions.chpl genhashkey32.chpl genhashkey64.chpl 

crosstalk_replicated:
	chpl --fast --print-passes -o bin/crosstalk_replicated test/crosstalk_replicated.chpl common.chpl logging.chpl partitions.chpl genhashkey32.chpl

fanout:
	chpl --fast --print-passes -o bin/fanout fanout.chpl common.chpl logging.chpl partitions.chpl genhashkey32.chpl

clean:
	rm -f *.o
	rm -f bin/*
