CC=clang
LDIR=/opt/local/Cellar/libev/4.15/lib
IDIR=/opt/local/Cellar/libev/4.15/include
CHICKEN_IDIR=/opt/local/Cellar/chicken/4.9.0.1/include/chicken
CFLAGS=-I$(IDIR) -I.
LIBS=-lev

all: chearch 

tcp_server: tcp_server.o
	$(CC) $(CFLAGS) -c -o bin/tcp_server.o tcp_server.c

chearch: tcp_server
	chpl --print-passes --fast tcp_server.h bin/tcp_server.o callbacks.h callbacks.c -I$(IDIR) -L$(LDIR) $(LIBS) -o bin/chearch chearch.chpl search.chpl logging.chpl genhashkey32.chpl genhashkey64.chpl  libev.chpl

clean:
	rm -f bin/*
