CC=clang
LDIR=/opt/local/Cellar/libev/4.15/lib
IDIR=/opt/local/Cellar/libev/4.15/include
CFLAGS=-I$(IDIR) -I.
LIBS=-lev

all: chearch 

chearch:
	chpl --print-passes --no-local --fast tcp/tcp_server.h tcp/tcp_server.c tcp/callbacks.h tcp/callbacks.c -I$(IDIR) -L$(LDIR) $(LIBS) -o bin/chearch chearch.chpl search.chpl tcp/libev.chpl

chearch_test:
	chpl --print-passes --no-local --fast -o bin/chearch_test test/chearch_test.chpl search.chpl

clean:
	rm -f bin/*
