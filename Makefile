CC=clang
LDIR=/opt/local/Cellar/libev/4.15/lib
IDIR=/opt/local/Cellar/libev/4.15/include
CFLAGS=-I$(IDIR) -I.
LIBS=-lev

CHEARCH_FILES=search.chpl synthdataindexer.chpl logging.chpl searchindex.chpl chasm.chpl documentid.chpl operands.chpl memorysegment.chpl documentidpool.chpl genhashkey32.chpl

all: chearch 

tcp_server:
	$(CC) $(CFLAGS) -c -o tcp_server.o tcp/tcp_server.c

helloworld:
	chpl --print-passes --fast -o bin/helloworld test/helloworld.chpl search.chpl

chearch:
	chpl --print-passes --fast -o bin/chearch chearch.chpl $(CHEARCH_FILES)

chearch_srv: tcp_server.o
	chpl --print-passes --fast tcp/tcp_server.h tcp_server.o tcp/callbacks.h tcp/callbacks.c -I$(IDIR) -L$(LDIR) $(LIBS) -o bin/chearch_srv tcp/libev.chpl chearch_srv.chpl  $(CHEARCH_FILES)

chearch_test:
	chpl --print-passes --no-local -o bin/chearch_test test/chearch_test.chpl search.chpl

clean:
	rm -f bin/*
