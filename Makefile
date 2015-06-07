CC=clang
LDIR=/opt/local/Cellar/libev/4.15/lib
IDIR=/opt/local/Cellar/libev/4.15/include
CFLAGS=-I$(IDIR) -I.
LIBS=-lev

CHEARCH_FILES=chearch.chpl search.chpl batchindexer.chpl logging.chpl searchindex.chpl chasm.chpl documentid.chpl operands.chpl memorysegment.chpl documentidpool.chpl genhashkey32.chpl

all: chearch 

helloworld:
	chpl --print-passes --no-local --fast -o bin/helloworld test/helloworld.chpl search.chpl

chearch:
	chpl --print-passes --no-local --fast -o bin/chearch $(CHEARCH_FILES)

chearch_srv:
	chpl --print-passes --no-local --fast tcp/tcp_server.h tcp/tcp_server.c tcp/callbacks.h tcp/callbacks.c -I$(IDIR) -L$(LDIR) $(LIBS) -o bin/chearch libev.chpl $(CHEARCH_FILES)

chearch_test:
	chpl --print-passes --no-local -o bin/chearch_test test/chearch_test.chpl search.chpl

clean:
	rm -f bin/*
